import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/im_public_client.dart';
import '../../l10n/app_localizations.dart';

class ReportReasonResult {
  const ReportReasonResult({
    required this.reason,
    this.images = const [],
  });

  final String reason;
  final List<ReportImageAttachment> images;

  List<ImPublicFilePart> toImPublicFiles() {
    return images
        .map((image) => ImPublicFilePart(
              filename: image.filename,
              bytes: image.bytes,
              contentType: image.contentType,
            ))
        .toList(growable: false);
  }
}

class ReportImageAttachment {
  const ReportImageAttachment({
    required this.filename,
    required this.bytes,
    this.contentType = 'application/octet-stream',
  });

  final String filename;
  final List<int> bytes;
  final String contentType;
}

class ReportReasonDialog extends StatefulWidget {
  const ReportReasonDialog({
    super.key,
    this.pickImages,
  });

  final Future<List<ReportImageAttachment>> Function()? pickImages;

  @override
  State<ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<ReportReasonDialog> {
  static const _otherReasonValue = '其他';

  String _selected = _otherReasonValue;
  final TextEditingController _otherController = TextEditingController();
  final List<ReportImageAttachment> _images = [];
  bool _pickingImages = false;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  String get _reason {
    if (_selected != _otherReasonValue) return _selected;
    final other = _otherController.text.trim();
    return other.isEmpty ? _otherReasonValue : other;
  }

  Future<void> _pickImages() async {
    if (_pickingImages) return;
    final l10n = _reportReasonL10n(context);
    setState(() => _pickingImages = true);
    try {
      final picker = widget.pickImages ?? _defaultPickImages;
      final picked = await picker();
      if (picked.isEmpty || !mounted) return;
      setState(() {
        _images
          ..clear()
          ..addAll(picked);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            l10n?.reportReasonPickImageFailed('$error') ?? '图片选择失败: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingImages = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _reportReasonL10n(context);
    final t = context.tk;
    final maxDialogHeight = MediaQuery.sizeOf(context).height * 0.88;
    final reasons = [
      _ReportReasonOption(
        value: '骚扰/辱骂',
        label: l10n?.reportReasonHarassment ?? '骚扰/辱骂',
      ),
      _ReportReasonOption(
        value: '垃圾信息/广告',
        label: l10n?.reportReasonSpam ?? '垃圾信息/广告',
      ),
      _ReportReasonOption(
        value: '色情/不当内容',
        label: l10n?.reportReasonSexual ?? '色情/不当内容',
      ),
      _ReportReasonOption(
        value: '暴力内容',
        label: l10n?.reportReasonViolence ?? '暴力内容',
      ),
      _ReportReasonOption(
        value: '欺诈',
        label: l10n?.reportReasonFraud ?? '欺诈',
      ),
      _ReportReasonOption(
        value: _otherReasonValue,
        label: l10n?.reportReasonOther ?? '其他',
      ),
    ];
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor: t.surface.withValues(alpha: 0),
      elevation: 0,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 343,
          maxHeight: maxDialogHeight,
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: BoxDecoration(
          color: t.surfaceHover,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n?.reportReasonDialogTitle ?? '请选择举报原因',
                      style: AppTheme.sans(
                        size: 16,
                        weight: FontWeight.w500,
                        color: t.text,
                      ).copyWith(letterSpacing: -0.4),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(
                        Symbols.close,
                        size: 18,
                        color: t.textMute,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final reason in reasons) ...[
                if (reason.value == _otherReasonValue)
                  _OtherReasonTile(
                    label: reason.label,
                    hintText: l10n?.reportReasonOtherHint ?? '请填写举报原因',
                    selected: _selected == reason.value,
                    controller: _otherController,
                    onTap: () => setState(() => _selected = reason.value),
                  )
                else
                  _ReportReasonTile(
                    label: reason.label,
                    selected: _selected == reason.value,
                    onTap: () => setState(() => _selected = reason.value),
                  ),
                if (reason != reasons.last) const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              _ReportImagePickerRow(
                label: _images.isEmpty
                    ? l10n?.reportReasonPickImages ?? '上传图片'
                    : l10n?.reportReasonImagesSelected(_images.length) ??
                        '已选择${_images.length}张图片',
                picking: _pickingImages,
                onTap: _pickImages,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    ReportReasonResult(
                      reason: _reason,
                      images: List.unmodifiable(_images),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n?.reportReasonSubmit ?? '提交',
                    style: AppTheme.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: t.onAccent,
                    ).copyWith(letterSpacing: -0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

AppLocalizations? _reportReasonL10n(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations);
}

class _ReportReasonOption {
  const _ReportReasonOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

Future<List<ReportImageAttachment>> _defaultPickImages() async {
  final files = await ImagePicker().pickMultiImage(
    imageQuality: 90,
    maxWidth: 1600,
    maxHeight: 1600,
    requestFullMetadata: false,
  );
  final attachments = <ReportImageAttachment>[];
  for (final file in files) {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) continue;
    attachments.add(ReportImageAttachment(
      filename: file.name.trim().isEmpty ? 'report-image.jpg' : file.name,
      bytes: bytes,
      contentType: file.mimeType ?? _imageMimeTypeForName(file.name),
    ));
  }
  return attachments;
}

String _imageMimeTypeForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.bmp')) return 'image/bmp';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  return 'application/octet-stream';
}

class _ReportImagePickerRow extends StatelessWidget {
  const _ReportImagePickerRow({
    required this.label,
    required this.picking,
    required this.onTap,
  });

  final String label;
  final bool picking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: picking ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Symbols.add_photo_alternate, size: 20, color: t.textMute),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: t.text,
                    ).copyWith(letterSpacing: -0.4),
                  ),
                ),
                if (picking)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.accent,
                    ),
                  )
                else
                  Icon(Symbols.chevron_right, size: 22, color: t.textMute),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportReasonTile extends StatelessWidget {
  const _ReportReasonTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: t.text,
                    ).copyWith(letterSpacing: -0.4),
                  ),
                ),
                _ReportRadio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtherReasonTile extends StatelessWidget {
  const _OtherReasonTile({
    required this.label,
    required this.hintText,
    required this.selected,
    required this.controller,
    required this.onTap,
  });

  final String label;
  final String hintText;
  final bool selected;
  final TextEditingController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppTheme.sans(
                        size: 14,
                        weight: FontWeight.w500,
                        color: t.text,
                      ).copyWith(letterSpacing: -0.4),
                    ),
                  ),
                  _ReportRadio(selected: selected),
                ],
              ),
              if (selected) ...[
                const SizedBox(height: 8),
                Container(
                  height: 74,
                  decoration: BoxDecoration(
                    color: t.bg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: AppTheme.sans(
                      size: 12,
                      color: t.text,
                    ).copyWith(letterSpacing: -0.4),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: AppTheme.sans(
                        size: 12,
                        color: t.textMute.withValues(alpha: 0.68),
                      ).copyWith(letterSpacing: -0.4),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportRadio extends StatelessWidget {
  const _ReportRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: selected ? t.accent : t.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? t.accent : t.border.withValues(alpha: 0.55),
          width: selected ? 0 : 1,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: t.onAccent,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

String reportDomainForUserId(String userId, String? domain) {
  final value = domain?.trim() ?? '';
  if (value.isNotEmpty) return value;
  final idx = userId.indexOf(':');
  if (idx >= 0 && idx < userId.length - 1) {
    return userId.substring(idx + 1);
  }
  return userId;
}

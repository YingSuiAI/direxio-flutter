import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

class ReportReasonDialog extends StatefulWidget {
  const ReportReasonDialog({super.key});

  @override
  State<ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<ReportReasonDialog> {
  static const _reasons = [
    '骚扰/辱骂',
    '垃圾信息/广告',
    '色情/不当内容',
    '暴力内容',
    '欺诈',
    '其他',
  ];

  String _selected = '其他';
  final TextEditingController _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  String get _reason {
    if (_selected != '其他') return _selected;
    final other = _otherController.text.trim();
    return other.isEmpty ? '其他' : other;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor: t.surface.withValues(alpha: 0),
      elevation: 0,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 343),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: BoxDecoration(
          color: t.surfaceHover,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '请选择举报原因',
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
            for (final reason in _reasons) ...[
              if (reason == '其他')
                _OtherReasonTile(
                  selected: _selected == reason,
                  controller: _otherController,
                  onTap: () => setState(() => _selected = reason),
                )
              else
                _ReportReasonTile(
                  label: reason,
                  selected: _selected == reason,
                  onTap: () => setState(() => _selected = reason),
                ),
              if (reason != _reasons.last) const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_reason),
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '提交',
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
    required this.selected,
    required this.controller,
    required this.onTap,
  });

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
                      '其他',
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
                      hintText: '请填写举报原因',
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

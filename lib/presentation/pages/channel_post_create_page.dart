import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../providers/as_client_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/auth_provider.dart';

class ChannelPostCreatePage extends ConsumerStatefulWidget {
  const ChannelPostCreatePage({super.key, required this.channelId});

  final String channelId;

  @override
  ConsumerState<ChannelPostCreatePage> createState() =>
      _ChannelPostCreatePageState();
}

class _ChannelPostCreatePageState extends ConsumerState<ChannelPostCreatePage> {
  final _ctrl = TextEditingController();
  bool _posting = false;
  bool _imageUploading = false;
  String _imageUrl = '';
  String _imageName = '';
  String _imageMimeType = '';
  Uint8List? _imagePreviewBytes;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final channelId = widget.channelId.trim();
    final body = _ctrl.text.trim();
    if (channelId.isEmpty || (body.isEmpty && _imageUrl.isEmpty) || _posting) {
      return;
    }
    setState(() => _posting = true);
    try {
      final hasImage = _imageUrl.trim().isNotEmpty;
      final post = await ref.read(asClientProvider).createChannelPost(
            channelId,
            messageType: hasImage ? 'm.image' : 'text',
            body: body.isEmpty ? _imageName : body,
            media: hasImage
                ? {
                    'url': _imageUrl,
                    'name': _imageName,
                    'info': {
                      if (_imageMimeType.isNotEmpty) 'mimetype': _imageMimeType,
                      if (_imagePreviewBytes != null)
                        'size': _imagePreviewBytes!.length,
                    },
                  }
                : const {},
          );
      await ref
          .read(channelPostsProvider(channelId).notifier)
          .upsertLocal(post);
      if (!mounted) return;
      context.pop();
    } catch (err) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发表失败：$err')),
      );
    }
  }

  Future<void> _pickImage() async {
    if (_posting || _imageUploading) return;
    setState(() => _imageUploading = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 86,
        maxWidth: 1800,
        maxHeight: 1800,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw StateError('empty image bytes');
      final mimeType = file.mimeType ?? _imageMimeTypeForName(file.name);
      if (mounted) {
        setState(() {
          _imagePreviewBytes = bytes;
          _imageName =
              file.name.trim().isEmpty ? 'channel-post.jpg' : file.name;
          _imageMimeType = mimeType;
        });
      }
      final uploaded = await ref.read(matrixClientProvider).uploadContent(
            bytes,
            filename: _imageName.isEmpty ? 'channel-post.jpg' : _imageName,
            contentType: mimeType,
          );
      if (!mounted) return;
      setState(() => _imageUrl = uploaded.toString());
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('图片上传失败：$err')),
      );
    } finally {
      if (mounted) setState(() => _imageUploading = false);
    }
  }

  void _removeImage() {
    if (_posting || _imageUploading) return;
    setState(() {
      _imagePreviewBytes = null;
      _imageUrl = '';
      _imageName = '';
      _imageMimeType = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _posting ? null : () => context.pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 40),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(
                        '取消',
                        style: AppTheme.sans(
                          size: 15,
                          weight: FontWeight.w500,
                          color: t.text,
                        ).copyWith(height: 20 / 15),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 63,
                      height: 33,
                      child: FilledButton(
                        onPressed: _posting ? null : _publish,
                        style: FilledButton.styleFrom(
                          backgroundColor: t.accent,
                          foregroundColor: t.onAccent,
                          disabledBackgroundColor:
                              t.accent.withValues(alpha: 0.48),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _posting ? '发表中' : '发表',
                          style: AppTheme.sans(
                            size: 13,
                            weight: FontWeight.w500,
                            color: t.onAccent,
                          ).copyWith(height: 20 / 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                cursorColor: t.accent,
                minLines: null,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w500,
                  color: t.text,
                ).copyWith(height: 20 / 15),
                decoration: InputDecoration(
                  hintText: '发表帖子...',
                  hintStyle: AppTheme.sans(
                    size: 15,
                    weight: FontWeight.w500,
                    color: t.textMute.withValues(alpha: 0.62),
                  ).copyWith(height: 20 / 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(
                    30,
                    topInset > 0 ? 14 : 22,
                    30,
                    24,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              decoration: BoxDecoration(
                color: t.bg,
                border: Border(
                  top: BorderSide(color: t.border.withValues(alpha: 0.48)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '图片',
                    onPressed: _posting || _imageUploading ? null : _pickImage,
                    icon: _imageUploading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: t.accent,
                            ),
                          )
                        : Icon(Icons.image_outlined, color: t.text),
                  ),
                  if (_imagePreviewBytes != null) ...[
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        _imagePreviewBytes!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton(
                      tooltip: '移除图片',
                      onPressed: _removeImage,
                      icon: Icon(Icons.close, color: t.textMute),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _imageMimeTypeForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../channel/channel_post_media.dart';
import '../chat/ordered_chat_image_picker.dart';
import '../chat/product_media_outbox_flow.dart';
import '../providers/as_client_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/media_thumbnail_cache_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/user_profile_directory_provider.dart';

class ChannelPostCreatePage extends ConsumerStatefulWidget {
  const ChannelPostCreatePage({
    super.key,
    required this.channelId,
    this.imagePicker,
  });

  final String channelId;
  final ChatImageAttachmentPicker? imagePicker;

  @override
  ConsumerState<ChannelPostCreatePage> createState() =>
      _ChannelPostCreatePageState();
}

class _ChannelPostCreatePageState extends ConsumerState<ChannelPostCreatePage> {
  final _ctrl = TextEditingController();
  bool _posting = false;
  bool _imageUploading = false;
  final List<_SelectedPostImage> _images = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final channelId = widget.channelId.trim();
    final body = _ctrl.text.trim();
    if (channelId.isEmpty || (body.isEmpty && _images.isEmpty) || _posting) {
      return;
    }
    setState(() => _posting = true);
    try {
      final mediaImages = [
        for (final image in _images)
          ChannelPostMediaImage(
            url: image.url,
            name: image.name,
            mimeType: image.mimeType,
            size: image.bytes.length,
          ),
      ];
      final hasImage = mediaImages.isNotEmpty;
      final post = await ref.read(asClientProvider).createChannelPost(
            channelId,
            messageType: hasImage ? 'm.image' : 'text',
            body: body,
            media: hasImage ? channelPostMediaForImages(mediaImages) : const {},
          );
      await ref
          .read(channelPostsProvider(channelId).notifier)
          .upsertLocal(_withLocalAuthorIdentity(ref, post));
      if (!mounted) return;
      context.pop();
    } catch (err) {
      if (!mounted) return;
      setState(() => _posting = false);
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.channelPostPublishFailed('$err') ?? '发表失败：$err'),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    if (_posting || _imageUploading) return;
    final remaining = channelPostMaxImages - _images.length;
    if (remaining <= 0) return;
    setState(() => _imageUploading = true);
    try {
      final selected =
          await (widget.imagePicker ?? ChatImageAttachmentPicker.platform())
              .pickImages(
        original: false,
        limit: remaining,
      );
      if (selected.isEmpty) return;

      var failedCount = 0;
      for (final image in selected) {
        try {
          final bytes = image.bytes;
          if (bytes.isEmpty) continue;
          final name =
              image.name.trim().isEmpty ? 'channel-post.jpg' : image.name;
          final mimeType =
              image.mimeType.trim().isEmpty ? 'image/jpeg' : image.mimeType;
          final uploaded = await ref.read(matrixClientProvider).uploadContent(
                bytes,
                filename: name,
                contentType: mimeType,
              );
          if (!mounted) return;
          final uploadedUrl = uploaded.toString();
          unawaited(_writeUploadedImageCache(uploadedUrl, bytes));
          setState(() {
            if (_images.length >= channelPostMaxImages) return;
            _images.add(
              _SelectedPostImage(
                bytes: bytes,
                url: uploadedUrl,
                name: name,
                mimeType: mimeType,
              ),
            );
          });
        } on Object {
          failedCount += 1;
        }
      }
      if (failedCount > 0 && mounted) {
        final l10n = Localizations.of<AppLocalizations>(
          context,
          AppLocalizations,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.channelPostImageUploadFailed('$failedCount') ??
                  '$failedCount 张图片上传失败，请重新选择',
            ),
          ),
        );
      }
    } catch (err) {
      if (!mounted) return;
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.channelPostImageUploadFailed('$err') ?? '图片上传失败：$err',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _imageUploading = false);
    }
  }

  Future<void> _writeUploadedImageCache(String url, Uint8List bytes) async {
    if (url.trim().isEmpty || bytes.isEmpty) return;
    try {
      final cache = await ref.read(mediaThumbnailCacheProvider.future);
      await cache.write(url, await localOutboxThumbnailBytes(bytes));
    } on Object {
      // Local thumbnail cache is only a display optimization.
    }
  }

  void _removeImage(int index) {
    if (_posting || _imageUploading) return;
    if (index < 0 || index >= _images.length) return;
    setState(() => _images.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
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
                        l10n?.commonCancel ?? '取消',
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
                          _posting
                              ? l10n?.channelPostPublishing ?? '发表中'
                              : l10n?.channelPostPublish ?? '发表',
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(19, 17, 19, 24),
                children: [
                  _CreatePostImageGrid(
                    images: _images,
                    uploading: _imageUploading,
                    onAdd: _pickImage,
                    onRemove: _removeImage,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    cursorColor: t.accent,
                    minLines: 4,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    style: AppTheme.sans(
                      size: 15,
                      weight: FontWeight.w500,
                      color: t.text,
                    ).copyWith(height: 20 / 15),
                    decoration: InputDecoration(
                      hintText: l10n?.channelPostPlaceholder ?? '发表帖子...',
                      hintStyle: AppTheme.sans(
                        size: 15,
                        weight: FontWeight.w500,
                        color: t.textMute.withValues(alpha: 0.62),
                      ).copyWith(height: 20 / 15),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.only(left: 5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

AsChannelPost _withLocalAuthorIdentity(WidgetRef ref, AsChannelPost post) {
  final currentProfile = ref.read(currentUserProfileProvider).valueOrNull;
  final auth = ref.read(authStateNotifierProvider).valueOrNull;
  final currentUserId = _firstNonEmptyString([
    ref.read(matrixClientProvider).userID,
    currentProfile?.userId,
    auth?.userId,
  ]);
  final authorId = _firstNonEmptyString([post.authorId, currentUserId]);
  final identity = ref.read(userProfileDirectoryProvider).resolve(
        userId: authorId,
        displayName: post.authorName,
        avatarUrl: post.authorAvatarUrl,
      );
  return post.copyWith(
    authorId: authorId,
    authorName: _firstNonEmptyString([
      post.authorName,
      identity.displayName,
      identity.resolvedName,
    ]),
    authorAvatarUrl: _firstNonEmptyString([
      post.authorAvatarUrl,
      identity.avatarUrl,
    ]),
  );
}

String _firstNonEmptyString(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

class _SelectedPostImage {
  const _SelectedPostImage({
    required this.bytes,
    required this.url,
    required this.name,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String url;
  final String name;
  final String mimeType;
}

class _CreatePostImageGrid extends StatelessWidget {
  const _CreatePostImageGrid({
    required this.images,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_SelectedPostImage> images;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemSize = (constraints.maxWidth - 10) / 3;
        return Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (var i = 0; i < images.length; i++)
              SizedBox.square(
                dimension: itemSize,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(images[i].bytes, fit: BoxFit.cover),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Material(
                        color: t.text.withValues(alpha: 0.54),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => onRemove(i),
                          child: Icon(
                            Symbols.close,
                            size: 18,
                            color: t.surface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (images.length < channelPostMaxImages)
              SizedBox.square(
                dimension: itemSize,
                child: Material(
                  key: const ValueKey('channel_post_add_image'),
                  color: t.surfaceHigh.withValues(alpha: 0.56),
                  child: InkWell(
                    onTap: uploading ? null : onAdd,
                    child: Center(
                      child: uploading
                          ? SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: t.accent,
                              ),
                            )
                          : Icon(
                              Symbols.add,
                              size: 34,
                              color: t.textMute.withValues(alpha: 0.72),
                            ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

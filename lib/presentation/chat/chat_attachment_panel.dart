import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/media_thumbnail_cache.dart';
import '../../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/media_thumbnail_cache_provider.dart';
import 'chat_media_send_flow.dart';
import 'ordered_chat_image_picker.dart';
import 'product_media_outbox_flow.dart';
import 'product_room_media_send_flow.dart';
import 'video_thumbnailer.dart';

class ChatAttachmentPanel extends ConsumerWidget {
  const ChatAttachmentPanel({
    super.key,
    required this.room,
    required this.roomId,
    required this.canSend,
    required this.useAsProductMedia,
    required this.onClose,
    required this.onCannotSend,
    this.onImageUploadStarted,
    this.onImageUploadsStarted,
    this.onImageUploadDelivered,
    this.onImageUploadFinished,
    this.onImageUploadFailed,
    this.onFileUploadStarted,
    this.onFileUploadDelivered,
    this.onFileUploadFinished,
    this.onFileUploadFailed,
    this.onVideoUploadStarted,
    this.onVideoUploadDelivered,
    this.onVideoUploadFinished,
    this.onVideoUploadFailed,
    this.onVoiceCall,
    this.onVideoCall,
  });

  final Room? room;
  final String roomId;
  final bool canSend;
  final bool useAsProductMedia;
  final VoidCallback onClose;
  final void Function(BuildContext context) onCannotSend;
  final FutureOr<String?> Function(ChatMediaAttachment attachment)?
      onImageUploadStarted;
  final Future<List<String>> Function(List<ChatMediaAttachment> attachments)?
      onImageUploadsStarted;
  final FutureOr<void> Function(String pendingUploadId, String eventId)?
      onImageUploadDelivered;
  final FutureOr<void> Function(String pendingUploadId)? onImageUploadFinished;
  final FutureOr<void> Function(String pendingUploadId)? onImageUploadFailed;
  final FutureOr<String?> Function(ChatMediaAttachment attachment)?
      onFileUploadStarted;
  final FutureOr<void> Function(String pendingUploadId, String eventId)?
      onFileUploadDelivered;
  final FutureOr<void> Function(String pendingUploadId)? onFileUploadFinished;
  final FutureOr<void> Function(String pendingUploadId)? onFileUploadFailed;
  final FutureOr<String?> Function(ChatMediaAttachment attachment)?
      onVideoUploadStarted;
  final FutureOr<void> Function(String pendingUploadId, String eventId)?
      onVideoUploadDelivered;
  final FutureOr<void> Function(String pendingUploadId)? onVideoUploadFinished;
  final FutureOr<void> Function(String pendingUploadId)? onVideoUploadFailed;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;

  void _showMediaSnack(
    ScaffoldMessengerState messenger,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!messenger.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: duration),
    );
  }

  Future<void> _sendProductAttachment(
    ScaffoldMessengerState messenger,
    ChatMediaAttachment attachment,
    ChatMediaAttachmentSender sendAttachment,
    Future<MediaThumbnailCache>? thumbnailCacheFuture,
    String? pendingUploadId,
    AppLocalizations? l10n,
  ) async {
    await sendProductMediaWithPendingState(
      messenger: messenger,
      attachment: attachment,
      sendAttachment: sendAttachment,
      thumbnailCacheFuture: thumbnailCacheFuture,
      onStarted: () {
        if (pendingUploadId != null) return pendingUploadId;
        return switch (attachment.kind) {
          ChatMediaKind.image => onImageUploadStarted?.call(attachment),
          ChatMediaKind.video => onVideoUploadStarted?.call(attachment),
          ChatMediaKind.audio => onFileUploadStarted?.call(attachment),
          ChatMediaKind.file => onFileUploadStarted?.call(attachment),
        };
      },
      onDelivered: switch (attachment.kind) {
        ChatMediaKind.image => onImageUploadDelivered,
        ChatMediaKind.video => onVideoUploadDelivered,
        ChatMediaKind.audio => onFileUploadDelivered,
        ChatMediaKind.file => onFileUploadDelivered,
      },
      onSucceeded: switch (attachment.kind) {
        ChatMediaKind.image => onImageUploadFinished,
        ChatMediaKind.video => onVideoUploadFinished,
        ChatMediaKind.audio => onFileUploadFinished,
        ChatMediaKind.file => onFileUploadFinished,
      },
      onFailed: switch (attachment.kind) {
        ChatMediaKind.image => onImageUploadFailed,
        ChatMediaKind.video => onVideoUploadFailed,
        ChatMediaKind.audio => onFileUploadFailed,
        ChatMediaKind.file => onFileUploadFailed,
      },
      l10n: l10n,
    );
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    await _pickAndSendImages(
      context,
      ref,
      pickAttachments: () => ChatImageAttachmentPicker.platform().pickImages(
        original: false,
        limit: chatImagePickerMaxSelection,
      ),
      emptySelectionMessage: l10n?.chatAttachmentNoImageSelected ?? '未选择图片',
      debugLabel: 'chat image pick/send',
    );
  }

  Future<void> _takePhoto(BuildContext context, WidgetRef ref) async {
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    await _pickAndSendImages(
      context,
      ref,
      pickAttachments: () async {
        final file = await ImagePicker().pickImage(
          source: ImageSource.camera,
          maxWidth: chatImagePickerCompressedMaxDimension,
          maxHeight: chatImagePickerCompressedMaxDimension,
          imageQuality: chatImagePickerCompressedQuality,
        );
        if (file == null) return const <ChatMediaAttachment>[];
        try {
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) {
            throw StateError('camera image bytes missing');
          }
          final name = file.name.trim().isEmpty
              ? 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg'
              : file.name;
          final dimensions = await tryReadChatImageDimensions(bytes);
          return [
            ChatMediaAttachment.image(
              name: name,
              bytes: bytes,
              mimeType: file.mimeType ?? _imageMimeTypeForName(name),
              width: dimensions?.width ?? 0,
              height: dimensions?.height ?? 0,
            ),
          ];
        } on Object catch (error, stackTrace) {
          throw ChatMediaSendException(
            ChatMediaSendStage.read,
            error,
            stackTrace,
            label: '照片',
          );
        }
      },
      emptySelectionMessage: l10n?.chatAttachmentNoPhotoTaken ?? '未拍摄照片',
      debugLabel: 'chat camera pick/send',
    );
  }

  Future<void> _pickAndSendImages(
    BuildContext context,
    WidgetRef ref, {
    required Future<List<ChatMediaAttachment>> Function() pickAttachments,
    required String emptySelectionMessage,
    required String debugLabel,
  }) async {
    if (!canSend || room == null) {
      onCannotSend(context);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final matrixClient = ref.read(matrixClientProvider);
    final thumbnailCacheFuture = ref.read(mediaThumbnailCacheProvider.future);
    final productMediaSender = createProductRoomMediaSender(
      matrixClient: matrixClient,
      roomId: roomId,
    );
    final pendingImageUploads = <ChatMediaAttachment, String>{};
    try {
      await pickAndSendChatMediaAttachments(
        closePanel: onClose,
        pickAttachments: pickAttachments,
        prepareAttachments: useAsProductMedia
            ? (attachments) async {
                final ids =
                    await onImageUploadsStarted?.call(attachments) ?? const [];
                for (var i = 0; i < attachments.length && i < ids.length; i++) {
                  pendingImageUploads[attachments[i]] = ids[i];
                }
              }
            : null,
        sendAttachment: (attachment) async {
          if (useAsProductMedia) {
            await _sendProductAttachment(
              messenger,
              attachment,
              productMediaSender,
              thumbnailCacheFuture,
              pendingImageUploads[attachment],
              l10n,
            );
            return;
          }
          await room!.sendFileEvent(
            MatrixFile(
              bytes: attachment.bytes,
              name: attachment.name,
              mimeType: attachment.mimeType.isEmpty
                  ? 'image/jpeg'
                  : attachment.mimeType,
            ),
            shrinkImageMaxDimension: attachment.original
                ? null
                : chatImagePickerCompressedMaxDimension.toInt(),
          );
        },
        showNotice: (
          message, {
          duration = const Duration(seconds: 2),
        }) {
          _showMediaSnack(messenger, message, duration: duration);
        },
        emptySelectionMessage: emptySelectionMessage,
      );
    } on ChatMediaSendException catch (e) {
      debugPrint('$debugLabel failed at ${e.stage.name}: ${e.cause}');
      _showMediaSnack(
        messenger,
        e.userMessageFor(l10n),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('$debugLabel failed: $e');
      _showMediaSnack(
        messenger,
        productSendFailureMessage(e, l10n: l10n),
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    if (!canSend || room == null) {
      onCannotSend(context);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final matrixClient = ref.read(matrixClientProvider);
    final productMediaSender = createProductRoomMediaSender(
      matrixClient: matrixClient,
      roomId: roomId,
    );
    try {
      await pickAndSendChatMediaAttachment(
        closePanel: onClose,
        pickAttachment: () async {
          final result = await FilePicker.platform.pickFiles(withData: true);
          if (result == null || result.files.isEmpty) return null;
          final f = result.files.first;
          if (f.bytes == null) {
            throw ChatMediaSendException(
              ChatMediaSendStage.read,
              StateError('file bytes missing'),
              StackTrace.current,
              label: '文件',
            );
          }
          return ChatMediaAttachment.file(name: f.name, bytes: f.bytes!);
        },
        sendAttachment: (attachment) async {
          if (useAsProductMedia) {
            await _sendProductAttachment(
              messenger,
              attachment,
              productMediaSender,
              null,
              null,
              l10n,
            );
            return;
          }
          await room!.sendFileEvent(
            MatrixFile(bytes: attachment.bytes, name: attachment.name),
          );
        },
        showNotice: (
          message, {
          duration = const Duration(seconds: 2),
        }) {
          _showMediaSnack(messenger, message, duration: duration);
        },
        emptySelectionMessage: l10n?.chatAttachmentNoFileSelected ?? '未选择文件',
      );
    } on ChatMediaSendException catch (e) {
      debugPrint('chat file pick/send failed at ${e.stage.name}: ${e.cause}');
      _showMediaSnack(
        messenger,
        e.userMessageFor(l10n),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('chat file pick/send failed: $e');
      _showMediaSnack(
        messenger,
        productSendFailureMessage(e, l10n: l10n),
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _pickVideo(BuildContext context, WidgetRef ref) async {
    if (!canSend || room == null) {
      onCannotSend(context);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final matrixClient = ref.read(matrixClientProvider);
    final thumbnailCacheFuture = ref.read(mediaThumbnailCacheProvider.future);
    final productMediaSender = createProductRoomMediaSender(
      matrixClient: matrixClient,
      roomId: roomId,
    );
    try {
      await pickAndSendChatMediaAttachment(
        closePanel: onClose,
        pickAttachment: () async {
          final file = await ImagePicker().pickVideo(
            source: ImageSource.gallery,
          );
          if (file == null) return null;
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) {
            throw ChatMediaSendException(
              ChatMediaSendStage.read,
              StateError('video bytes missing'),
              StackTrace.current,
              label: '视频',
            );
          }
          final thumb = await createChatVideoThumbnail(file.path);
          return ChatMediaAttachment.video(
            name: file.name.isEmpty ? 'video.mp4' : file.name,
            bytes: bytes,
            mimeType: file.mimeType ?? videoMimeTypeForName(file.name),
            thumbnailBytes: thumb?.bytes,
            thumbnailMimeType: thumb?.mimeType ?? '',
            width: thumb?.width ?? 0,
            height: thumb?.height ?? 0,
            durationMs: thumb?.durationMs ?? 0,
          );
        },
        sendAttachment: (attachment) async {
          if (useAsProductMedia) {
            await _sendProductAttachment(
              messenger,
              attachment,
              productMediaSender,
              thumbnailCacheFuture,
              null,
              l10n,
            );
            return;
          }
          await room!.sendFileEvent(
            _matrixVideoFileForAttachment(attachment),
            thumbnail: _matrixVideoThumbnailForAttachment(attachment),
          );
        },
        showNotice: (
          message, {
          duration = const Duration(seconds: 2),
        }) {
          _showMediaSnack(messenger, message, duration: duration);
        },
        emptySelectionMessage: l10n?.chatAttachmentNoVideoSelected ?? '未选择视频',
      );
    } on ChatMediaSendException catch (e) {
      debugPrint('chat video pick/send failed at ${e.stage.name}: ${e.cause}');
      _showMediaSnack(
        messenger,
        e.userMessageFor(l10n),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('chat video pick/send failed: $e');
      _showMediaSnack(
        messenger,
        productSendFailureMessage(e, l10n: l10n),
        duration: const Duration(seconds: 3),
      );
    }
  }

  MatrixVideoFile _matrixVideoFileForAttachment(
    ChatMediaAttachment attachment,
  ) {
    return MatrixVideoFile(
      bytes: attachment.bytes,
      name: attachment.name,
      mimeType: attachment.mimeType.isEmpty
          ? videoMimeTypeForName(attachment.name)
          : attachment.mimeType,
      width: attachment.width > 0 ? attachment.width : null,
      height: attachment.height > 0 ? attachment.height : null,
      duration: attachment.durationMs > 0 ? attachment.durationMs : null,
    );
  }

  MatrixImageFile? _matrixVideoThumbnailForAttachment(
    ChatMediaAttachment attachment,
  ) {
    final bytes = attachment.thumbnailBytes;
    if (bytes == null || bytes.isEmpty) return null;
    return MatrixImageFile(
      bytes: bytes,
      name: _videoThumbnailName(attachment.name),
      mimeType: attachment.thumbnailMimeType.isEmpty
          ? 'image/jpeg'
          : attachment.thumbnailMimeType,
      width: attachment.width > 0 ? attachment.width : null,
      height: attachment.height > 0 ? attachment.height : null,
    );
  }

  String _videoThumbnailName(String videoName) {
    final trimmed = videoName.trim();
    if (trimmed.isEmpty) return 'video-thumb.jpg';
    final dot = trimmed.lastIndexOf('.');
    final base = dot > 0 ? trimmed.substring(0, dot) : trimmed;
    return '$base-thumb.jpg';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final items = <(IconData, String, VoidCallback?)>[
      (
        Symbols.photo_library,
        l10n?.chatAttachmentAlbum ?? '相册',
        canSend ? () => _pickImage(context, ref) : null,
      ),
      (
        Symbols.photo_camera,
        l10n?.chatAttachmentCamera ?? '拍摄',
        canSend ? () => _takePhoto(context, ref) : null,
      ),
      if (onVoiceCall != null)
        (Symbols.call, l10n?.groupChatVoiceCall ?? '语音通话', onVoiceCall),
      if (onVideoCall != null)
        (Symbols.videocam, l10n?.contactVideoCall ?? '视频通话', onVideoCall),
      (
        Symbols.movie,
        l10n?.chatAttachmentVideo ?? '视频',
        canSend ? () => _pickVideo(context, ref) : null,
      ),
      (
        Symbols.folder_open,
        l10n?.chatAttachmentFile ?? '文件',
        canSend ? () => _pickFile(context, ref) : null,
      ),
    ];
    return Container(
      color: t.surfaceHover,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 20,
            crossAxisSpacing: 8,
            childAspectRatio: 0.82,
            children: items
                .map(
                  (it) => ChatAttachmentPanelButton(
                    icon: it.$1,
                    label: it.$2,
                    onTap: it.$3,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class ChatAttachmentPanelButton extends StatelessWidget {
  const ChatAttachmentPanelButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 26,
              color: enabled ? t.text : t.textMute.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTheme.sans(
              size: 11,
              color: enabled ? t.textMute : t.textMute.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

String _imageMimeTypeForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  return 'image/jpeg';
}

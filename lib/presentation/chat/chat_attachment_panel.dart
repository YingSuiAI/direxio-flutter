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
import '../providers/as_client_provider.dart';
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
    );
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    if (!canSend || room == null) {
      onCannotSend(context);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final matrixClient = ref.read(matrixClientProvider);
    final asClient = ref.read(asClientProvider);
    final thumbnailCacheFuture = ref.read(mediaThumbnailCacheProvider.future);
    final productMediaSender = createProductRoomMediaSender(
      matrixClient: matrixClient,
      asClient: asClient,
      roomId: roomId,
    );
    final pendingImageUploads = <ChatMediaAttachment, String>{};
    try {
      await pickAndSendChatMediaAttachments(
        closePanel: onClose,
        pickAttachments: ChatImageAttachmentPicker.platform().pickImages,
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
            shrinkImageMaxDimension: 1600,
          );
        },
        showNotice: (
          message, {
          duration = const Duration(seconds: 2),
        }) {
          _showMediaSnack(messenger, message, duration: duration);
        },
        emptySelectionMessage: '未选择图片',
      );
    } on ChatMediaSendException catch (e) {
      debugPrint('chat image pick/send failed at ${e.stage.name}: ${e.cause}');
      _showMediaSnack(
        messenger,
        e.userMessage,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('chat image pick/send failed: $e');
      _showMediaSnack(
        messenger,
        productSendFailureMessage(e),
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
    final matrixClient = ref.read(matrixClientProvider);
    final asClient = ref.read(asClientProvider);
    final productMediaSender = createProductRoomMediaSender(
      matrixClient: matrixClient,
      asClient: asClient,
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
        emptySelectionMessage: '未选择文件',
      );
    } on ChatMediaSendException catch (e) {
      debugPrint('chat file pick/send failed at ${e.stage.name}: ${e.cause}');
      _showMediaSnack(
        messenger,
        e.userMessage,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('chat file pick/send failed: $e');
      _showMediaSnack(
        messenger,
        productSendFailureMessage(e),
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
    final matrixClient = ref.read(matrixClientProvider);
    final asClient = ref.read(asClientProvider);
    final thumbnailCacheFuture = ref.read(mediaThumbnailCacheProvider.future);
    final productMediaSender = createProductRoomMediaSender(
      matrixClient: matrixClient,
      asClient: asClient,
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
            );
            return;
          }
          await room!.sendFileEvent(
            MatrixFile(
              bytes: attachment.bytes,
              name: attachment.name,
              mimeType: attachment.mimeType.isEmpty
                  ? videoMimeTypeForName(attachment.name)
                  : attachment.mimeType,
            ),
          );
        },
        showNotice: (
          message, {
          duration = const Duration(seconds: 2),
        }) {
          _showMediaSnack(messenger, message, duration: duration);
        },
        emptySelectionMessage: '未选择视频',
      );
    } on ChatMediaSendException catch (e) {
      debugPrint('chat video pick/send failed at ${e.stage.name}: ${e.cause}');
      _showMediaSnack(
        messenger,
        e.userMessage,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('chat video pick/send failed: $e');
      _showMediaSnack(
        messenger,
        productSendFailureMessage(e),
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final items = <(IconData, String, VoidCallback?)>[
      (
        Symbols.photo_library,
        '相册',
        canSend ? () => _pickImage(context, ref) : null,
      ),
      (
        Symbols.photo_camera,
        '拍摄',
        canSend ? () => _pickImage(context, ref) : null,
      ),
      (Symbols.videocam, '视频通话', onVideoCall),
      (
        Symbols.movie,
        '视频',
        canSend ? () => _pickVideo(context, ref) : null,
      ),
      (Symbols.location_on, '位置', null),
      (Symbols.contact_page, '个人名片', null),
      (
        Symbols.folder_open,
        '文件',
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

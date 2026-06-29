import 'dart:typed_data';
import 'dart:ui';

import '../../data/local_outbox_store.dart';
import '../providers/local_outbox_provider.dart';
import 'chat_media_send_flow.dart';
import 'local_outbox_image_thumb.dart';

Future<List<String>> startImageOutboxItems({
  required LocalOutboxNotifier notifier,
  required String conversationId,
  required LocalOutboxConversationType conversationType,
  required List<ChatMediaAttachment> attachments,
  void Function()? onQueued,
}) async {
  if (attachments.isEmpty) return const [];
  final thumbnails = await Future.wait([
    for (final attachment in attachments)
      localOutboxThumbnailBytes(attachment.bytes),
  ]);
  final ids = await notifier.startItems(
    conversationId: conversationId,
    conversationType: conversationType,
    drafts: [
      for (var i = 0; i < attachments.length; i++)
        mediaOutboxDraftForAttachment(
          attachments[i],
          imageThumbnailBytes: thumbnails[i],
        ),
    ],
  );
  if (ids.isNotEmpty) onQueued?.call();
  return ids;
}

Future<String> startMediaOutboxItem({
  required LocalOutboxNotifier notifier,
  required String conversationId,
  required LocalOutboxConversationType conversationType,
  required ChatMediaAttachment attachment,
  void Function()? onQueued,
}) async {
  final id = await notifier.startItem(
    conversationId: conversationId,
    conversationType: conversationType,
    draft: mediaOutboxDraftForAttachment(
      attachment,
      imageThumbnailBytes: attachment.isImage
          ? await localOutboxThumbnailBytes(attachment.bytes)
          : null,
    ),
  );
  if (id.isNotEmpty) onQueued?.call();
  return id;
}

LocalOutboxDraft mediaOutboxDraftForAttachment(
  ChatMediaAttachment attachment, {
  Uint8List? imageThumbnailBytes,
}) {
  return switch (attachment.kind) {
    ChatMediaKind.image => LocalOutboxDraft.media(
        messageKind: LocalOutboxMessageKind.image,
        filename: attachment.name,
        mimeType:
            attachment.mimeType.isEmpty ? 'image/jpeg' : attachment.mimeType,
        bytes: attachment.bytes,
        thumbnailBytes: imageThumbnailBytes,
        width: attachment.width,
        height: attachment.height,
      ),
    ChatMediaKind.video => LocalOutboxDraft.media(
        messageKind: LocalOutboxMessageKind.video,
        filename: attachment.name,
        mimeType: attachment.mimeType.isEmpty
            ? videoMimeTypeForName(attachment.name)
            : attachment.mimeType,
        bytes: attachment.bytes,
        thumbnailBytes: attachment.thumbnailBytes,
        width: attachment.width,
        height: attachment.height,
        durationMs: attachment.durationMs,
      ),
    ChatMediaKind.file => LocalOutboxDraft.media(
        messageKind: LocalOutboxMessageKind.file,
        filename: attachment.name,
        mimeType: attachment.mimeType,
        bytes: attachment.bytes,
      ),
    ChatMediaKind.audio => LocalOutboxDraft.media(
        messageKind: LocalOutboxMessageKind.file,
        filename: attachment.name,
        mimeType:
            attachment.mimeType.isEmpty ? 'audio/mp4' : attachment.mimeType,
        bytes: attachment.bytes,
        durationMs: attachment.durationMs,
      ),
  };
}

Future<Uint8List> localOutboxThumbnailBytes(Uint8List bytes) async {
  try {
    return await resizeImageForLocalOutboxThumbnail(bytes);
  } on Object {
    return bytes;
  }
}

Future<Uint8List> resizeImageForLocalOutboxThumbnail(Uint8List bytes) async {
  final codec = await instantiateImageCodec(
    bytes,
    targetWidth: LocalOutboxImageThumbDefaults.decodeWidth,
  );
  final frame = await codec.getNextFrame();
  try {
    final data = await frame.image.toByteData(format: ImageByteFormat.png);
    return data?.buffer.asUint8List() ?? bytes;
  } finally {
    frame.image.dispose();
    codec.dispose();
  }
}

String videoMimeTypeForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.m4v')) return 'video/x-m4v';
  if (lower.endsWith('.webm')) return 'video/webm';
  return 'video/mp4';
}

String outboxFileSizeLabel(LocalOutboxItem item) {
  final kind = fileKindLabel(item.mimeType, item.filename);
  return item.byteLength > 0
      ? '$kind · ${formatByteSize(item.byteLength)}'
      : kind;
}

String fileKindLabel(String mime, String name) {
  final m = mime.toLowerCase();
  if (m.contains('pdf')) return 'PDF';
  if (m.contains('word') || m.contains('msword')) return 'DOC';
  if (m.contains('sheet') || m.contains('excel')) return 'XLS';
  if (m.contains('presentation') || m.contains('powerpoint')) return 'PPT';
  if (m.contains('zip') || m.contains('compressed')) return 'ZIP';
  if (m.startsWith('audio/')) return '音频';
  if (m.startsWith('video/')) return '视频';
  final dot = name.lastIndexOf('.');
  if (dot != -1 && dot < name.length - 1) {
    return name.substring(dot + 1).toUpperCase();
  }
  return '文件';
}

String formatByteSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var i = 0;
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  final str = i == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
  return '$str ${units[i]}';
}

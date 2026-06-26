import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../l10n/app_localizations.dart';

enum ChatMediaKind {
  image,
  video,
  file,
  audio,
}

enum ChatMediaSendStage {
  read,
  upload,
  send,
}

class ChatMediaAttachment {
  const ChatMediaAttachment._({
    required this.kind,
    required this.name,
    required this.bytes,
    this.mimeType = '',
    this.original = false,
    this.thumbnailBytes,
    this.thumbnailMimeType = '',
    this.width = 0,
    this.height = 0,
    this.durationMs = 0,
  });

  factory ChatMediaAttachment.image({
    required String name,
    required List<int> bytes,
    String mimeType = '',
    bool original = false,
    int width = 0,
    int height = 0,
  }) {
    return ChatMediaAttachment._(
      kind: ChatMediaKind.image,
      name: name,
      bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      mimeType: mimeType,
      original: original,
      width: width,
      height: height,
    );
  }

  factory ChatMediaAttachment.file({
    required String name,
    required List<int> bytes,
    String mimeType = '',
  }) {
    return ChatMediaAttachment._(
      kind: ChatMediaKind.file,
      name: name,
      bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      mimeType: mimeType,
    );
  }

  factory ChatMediaAttachment.audio({
    required String name,
    required List<int> bytes,
    String mimeType = 'audio/mp4',
    int durationMs = 0,
  }) {
    return ChatMediaAttachment._(
      kind: ChatMediaKind.audio,
      name: name,
      bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      mimeType: mimeType,
      durationMs: durationMs,
    );
  }

  factory ChatMediaAttachment.video({
    required String name,
    required List<int> bytes,
    String mimeType = '',
    List<int>? thumbnailBytes,
    String thumbnailMimeType = '',
    int width = 0,
    int height = 0,
    int durationMs = 0,
  }) {
    return ChatMediaAttachment._(
      kind: ChatMediaKind.video,
      name: name,
      bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      mimeType: mimeType,
      thumbnailBytes: thumbnailBytes == null
          ? null
          : thumbnailBytes is Uint8List
              ? thumbnailBytes
              : Uint8List.fromList(thumbnailBytes),
      thumbnailMimeType: thumbnailMimeType,
      width: width,
      height: height,
      durationMs: durationMs,
    );
  }

  final ChatMediaKind kind;
  final String name;
  final Uint8List bytes;
  final String mimeType;
  final bool original;
  final Uint8List? thumbnailBytes;
  final String thumbnailMimeType;
  final int width;
  final int height;
  final int durationMs;

  bool get isImage => kind == ChatMediaKind.image;
  bool get isVideo => kind == ChatMediaKind.video;
  String get msgType {
    return switch (kind) {
      ChatMediaKind.image => 'm.image',
      ChatMediaKind.video => 'm.video',
      ChatMediaKind.file => 'm.file',
      ChatMediaKind.audio => 'm.audio',
    };
  }

  String get label {
    return switch (kind) {
      ChatMediaKind.image => '图片',
      ChatMediaKind.video => '视频',
      ChatMediaKind.file => '文件',
      ChatMediaKind.audio => '语音',
    };
  }
}

class ChatImageDimensions {
  const ChatImageDimensions({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;
}

Future<ChatImageDimensions> readChatImageDimensions(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  try {
    return ChatImageDimensions(
      width: frame.image.width,
      height: frame.image.height,
    );
  } finally {
    frame.image.dispose();
    codec.dispose();
  }
}

Future<ChatImageDimensions?> tryReadChatImageDimensions(
  Uint8List bytes,
) async {
  try {
    return await readChatImageDimensions(bytes);
  } on Object {
    return null;
  }
}

class ChatMediaSendResult {
  const ChatMediaSendResult({
    required this.eventId,
    required this.mediaUrl,
  });

  final String eventId;
  final Uri mediaUrl;
}

class ChatMediaSendException implements Exception {
  const ChatMediaSendException(
    this.stage,
    this.cause,
    this.stackTrace, {
    this.label = '媒体',
  });

  final ChatMediaSendStage stage;
  final Object cause;
  final StackTrace stackTrace;
  final String label;

  String get userMessage {
    return switch (stage) {
      ChatMediaSendStage.read => '$label读取失败，请重新选择',
      ChatMediaSendStage.upload => '$label上传失败，请检查网络后重试',
      ChatMediaSendStage.send => '发送失败：$cause',
    };
  }

  String userMessageFor(AppLocalizations? l10n) {
    if (l10n == null) return userMessage;
    final localizedLabel = _localizedMediaLabel(label, l10n);
    return switch (stage) {
      ChatMediaSendStage.read => l10n.chatMediaReadFailed(localizedLabel),
      ChatMediaSendStage.upload => l10n.chatMediaUploadFailed(localizedLabel),
      ChatMediaSendStage.send => l10n.groupChatSendFailed('$cause'),
    };
  }

  @override
  String toString() => 'ChatMediaSendException($stage, $cause)';
}

String _localizedMediaLabel(String label, AppLocalizations l10n) {
  return switch (label.trim()) {
    '图片' => l10n.groupChatImage,
    '照片' => l10n.chatMediaPhoto,
    '视频' => l10n.groupChatVideo,
    '文件' => l10n.groupChatFile,
    '语音' => l10n.chatMediaAudio,
    '媒体' => l10n.chatMediaGeneric,
    final value when value.isNotEmpty => value,
    _ => l10n.chatMediaGeneric,
  };
}

typedef ChatMatrixUpload = Future<Uri> Function(
  Uint8List bytes, {
  required String filename,
  String? contentType,
});

typedef ChatAsMediaSend = Future<String> Function({
  required String roomId,
  required String msgType,
  required String body,
  required String filename,
  required String mediaUrl,
  String mimeType,
  int size,
  String thumbnailUrl,
  String thumbnailMimeType,
  int thumbnailSize,
  int width,
  int height,
  int durationMs,
});

typedef ChatOneShotSync = Future<void> Function();

typedef ChatMediaNotice = void Function(
  String message, {
  Duration duration,
});

typedef ChatMediaAttachmentSender = Future<ChatMediaSendResult> Function(
  ChatMediaAttachment attachment,
);

typedef ChatMediaAttachmentBatchPrepare = FutureOr<void> Function(
  List<ChatMediaAttachment> attachments,
);
typedef ChatMediaPendingUploadStart = FutureOr<String?> Function();
typedef ChatMediaPendingUploadFinish = FutureOr<void> Function(
  String pendingUploadId,
);

Future<void> pickAndSendChatMediaAttachment({
  required void Function() closePanel,
  required Future<ChatMediaAttachment?> Function() pickAttachment,
  required Future<void> Function(ChatMediaAttachment attachment) sendAttachment,
  required ChatMediaNotice showNotice,
  required String emptySelectionMessage,
}) async {
  await pickAndSendChatMediaAttachments(
    closePanel: closePanel,
    pickAttachments: () async {
      final attachment = await pickAttachment();
      return attachment == null ? const <ChatMediaAttachment>[] : [attachment];
    },
    sendAttachment: sendAttachment,
    showNotice: showNotice,
    emptySelectionMessage: emptySelectionMessage,
  );
}

Future<void> pickAndSendChatMediaAttachments({
  required void Function() closePanel,
  required Future<List<ChatMediaAttachment>> Function() pickAttachments,
  ChatMediaAttachmentBatchPrepare? prepareAttachments,
  required Future<void> Function(ChatMediaAttachment attachment) sendAttachment,
  required ChatMediaNotice showNotice,
  required String emptySelectionMessage,
}) async {
  closePanel();
  final attachments = await pickAttachments();
  if (attachments.isEmpty) {
    showNotice(emptySelectionMessage);
    return;
  }
  await prepareAttachments?.call(attachments);
  for (final attachment in attachments) {
    await sendAttachment(attachment);
  }
}

Future<T> runChatMediaSendTask<T>({
  ChatMediaPendingUploadStart? onStarted,
  required Future<T> Function() send,
  ChatMediaPendingUploadFinish? onSucceeded,
  ChatMediaPendingUploadFinish? onFailed,
  ChatMediaPendingUploadFinish? onFinished,
  void Function(Object error, StackTrace stackTrace)? onLifecycleError,
}) async {
  String? pendingUploadId;
  try {
    pendingUploadId = await onStarted?.call();
  } on Object catch (error, stackTrace) {
    onLifecycleError?.call(error, stackTrace);
  }

  try {
    final result = await send();
    if (pendingUploadId != null) {
      await _runLifecycleCallback(
        pendingUploadId,
        onSucceeded,
        onLifecycleError,
      );
    }
    return result;
  } catch (error) {
    if (pendingUploadId != null) {
      await _runLifecycleCallback(
        pendingUploadId,
        onFailed,
        onLifecycleError,
      );
    }
    rethrow;
  } finally {
    if (pendingUploadId != null) {
      await _runLifecycleCallback(
        pendingUploadId,
        onFinished,
        onLifecycleError,
      );
    }
  }
}

Future<void> _runLifecycleCallback(
  String pendingUploadId,
  ChatMediaPendingUploadFinish? callback,
  void Function(Object error, StackTrace stackTrace)? onLifecycleError,
) async {
  try {
    await callback?.call(pendingUploadId);
  } on Object catch (error, stackTrace) {
    onLifecycleError?.call(error, stackTrace);
  }
}

ChatMediaAttachmentSender createProductChatMediaSender({
  required String roomId,
  required ChatMatrixUpload uploadContent,
  required ChatAsMediaSend sendMedia,
  required ChatOneShotSync oneShotSync,
  void Function(Object error, StackTrace stackTrace)? onSyncFailure,
}) {
  return (attachment) => sendProductChatMedia(
        roomId: roomId,
        attachment: attachment,
        uploadContent: uploadContent,
        sendMedia: sendMedia,
        oneShotSync: oneShotSync,
        onSyncFailure: onSyncFailure,
      );
}

Future<ChatMediaSendResult> sendProductChatMedia({
  required String roomId,
  required ChatMediaAttachment attachment,
  required ChatMatrixUpload uploadContent,
  required ChatAsMediaSend sendMedia,
  required ChatOneShotSync oneShotSync,
  void Function(Object error, StackTrace stackTrace)? onSyncFailure,
}) async {
  if (attachment.bytes.isEmpty) {
    throw ChatMediaSendException(
      ChatMediaSendStage.read,
      StateError('empty ${attachment.label} bytes'),
      StackTrace.current,
      label: attachment.label,
    );
  }

  final mediaUrl = await _runStage<Uri>(
    ChatMediaSendStage.upload,
    attachment.label,
    () => uploadContent(
      attachment.bytes,
      filename: attachment.name,
      contentType: attachment.mimeType.isEmpty ? null : attachment.mimeType,
    ),
  );

  final thumbnailBytes = attachment.thumbnailBytes;
  Uri? thumbnailUrl;
  if (attachment.isVideo &&
      thumbnailBytes != null &&
      thumbnailBytes.isNotEmpty) {
    thumbnailUrl = await _runStage<Uri>(
      ChatMediaSendStage.upload,
      attachment.label,
      () => uploadContent(
        thumbnailBytes,
        filename: _videoThumbnailFilename(attachment.name),
        contentType: attachment.thumbnailMimeType.isEmpty
            ? 'image/jpeg'
            : attachment.thumbnailMimeType,
      ),
    );
  }

  final eventId = await _runStage<String>(
    ChatMediaSendStage.send,
    attachment.label,
    () => sendMedia(
      roomId: roomId,
      msgType: _asSendMediaMsgType(attachment),
      body: attachment.name,
      filename: attachment.name,
      mediaUrl: mediaUrl.toString(),
      mimeType: attachment.mimeType,
      size: attachment.bytes.length,
      thumbnailUrl: thumbnailUrl?.toString() ?? '',
      thumbnailMimeType: thumbnailUrl == null
          ? ''
          : attachment.thumbnailMimeType.isEmpty
              ? 'image/jpeg'
              : attachment.thumbnailMimeType,
      thumbnailSize: thumbnailBytes?.length ?? 0,
      width: attachment.width,
      height: attachment.height,
      durationMs: attachment.durationMs,
    ),
  );

  try {
    await oneShotSync();
  } on Object catch (error, stackTrace) {
    onSyncFailure?.call(error, stackTrace);
  }

  return ChatMediaSendResult(eventId: eventId, mediaUrl: mediaUrl);
}

String _asSendMediaMsgType(ChatMediaAttachment attachment) {
  return attachment.msgType;
}

String _videoThumbnailFilename(String videoName) {
  final trimmed = videoName.trim();
  if (trimmed.isEmpty) return 'video-thumb.jpg';
  final dot = trimmed.lastIndexOf('.');
  final base = dot > 0 ? trimmed.substring(0, dot) : trimmed;
  return '$base-thumb.jpg';
}

Future<T> _runStage<T>(
  ChatMediaSendStage stage,
  String label,
  Future<T> Function() run,
) async {
  try {
    return await run();
  } on Object catch (error, stackTrace) {
    throw ChatMediaSendException(stage, error, stackTrace, label: label);
  }
}

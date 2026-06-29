import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import '../../data/matrix_foreground_sync.dart';
import '../../data/media_thumbnail_cache.dart';
import '../../l10n/app_localizations.dart';
import 'chat_media_send_flow.dart';
import 'product_media_outbox_flow.dart';

String productSendFailureMessage(Object error, {AppLocalizations? l10n}) {
  final statusCode = error is AsClientException
      ? error.statusCode
      : error is MatrixException
          ? error.response?.statusCode
          : null;
  if (statusCode == 429) {
    return '服务器请求过于频繁，请稍后再试';
  }
  if (statusCode == 503) {
    return '服务器暂时繁忙，请稍后再试';
  }
  final errorText = error.toString();
  if (errorText.contains('M_LIMIT_EXCEEDED') ||
      errorText.toLowerCase().contains('too many requests') ||
      errorText.contains('请求过于频繁')) {
    return '服务器请求过于频繁，请稍后再试';
  }
  if (errorText.contains('M_RESOURCE_LIMIT_EXCEEDED') ||
      errorText.toLowerCase().contains('temporarily unavailable') ||
      errorText.contains('暂时繁忙')) {
    return '服务器暂时繁忙，请稍后再试';
  }
  if (error is AsClientException &&
      error.statusCode == 403 &&
      error.message == 'peer deleted contact') {
    return l10n?.chatPeerDeletedContact ?? '对方已删除联系人关系，消息未送达';
  }
  if (error is MatrixException &&
      (error.errorMessage == 'peer deleted contact' ||
          error.toString().contains('peer deleted contact'))) {
    return l10n?.chatPeerDeletedContact ?? '对方已删除联系人关系，消息未送达';
  }
  if (errorText.contains('peer deleted contact')) {
    return l10n?.chatPeerDeletedContact ?? '对方已删除联系人关系，消息未送达';
  }
  return l10n?.groupChatSendFailed('$error') ?? '发送失败：$error';
}

ChatMediaAttachmentSender createProductRoomMediaSender({
  required Client matrixClient,
  required String roomId,
}) {
  return createProductChatMediaSender(
    roomId: roomId,
    uploadContent: (bytes, {required filename, contentType}) {
      return matrixClient.uploadContent(
        bytes,
        filename: filename,
        contentType: contentType,
      );
    },
    sendMedia: ({
      required roomId,
      required msgType,
      required body,
      required filename,
      required mediaUrl,
      String mimeType = '',
      int size = 0,
      String thumbnailUrl = '',
      String thumbnailMimeType = '',
      int thumbnailSize = 0,
      int width = 0,
      int height = 0,
      int durationMs = 0,
    }) {
      return matrixClient.sendMessage(
        roomId,
        EventTypes.Message,
        matrixClient.generateUniqueTransactionId(),
        matrixMediaMessageContent(
          msgType: msgType,
          body: body,
          filename: filename,
          mediaUrl: mediaUrl,
          mimeType: mimeType,
          size: size,
          thumbnailUrl: thumbnailUrl,
          thumbnailMimeType: thumbnailMimeType,
          thumbnailSize: thumbnailSize,
          width: width,
          height: height,
          durationMs: durationMs,
        ),
      );
    },
    oneShotSync: () => syncMatrixForegroundLight(matrixClient),
    onSyncFailure: (error, stackTrace) {
      debugPrint('chat media oneShotSync failed: $error');
    },
  );
}

Map<String, Object?> matrixMediaMessageContent({
  required String msgType,
  required String body,
  required String filename,
  required String mediaUrl,
  String mimeType = '',
  int size = 0,
  String thumbnailUrl = '',
  String thumbnailMimeType = '',
  int thumbnailSize = 0,
  int width = 0,
  int height = 0,
  int durationMs = 0,
}) {
  final info = <String, Object?>{
    if (mimeType.trim().isNotEmpty) 'mimetype': mimeType.trim(),
    if (size > 0) 'size': size,
    if (width > 0) 'w': width,
    if (height > 0) 'h': height,
    if (durationMs > 0) 'duration': durationMs,
    if (thumbnailUrl.trim().isNotEmpty) 'thumbnail_url': thumbnailUrl.trim(),
    if (thumbnailSize > 0 || thumbnailMimeType.trim().isNotEmpty)
      'thumbnail_info': {
        if (thumbnailMimeType.trim().isNotEmpty)
          'mimetype': thumbnailMimeType.trim(),
        if (thumbnailSize > 0) 'size': thumbnailSize,
      },
  };
  return {
    'msgtype': msgType.trim().isEmpty ? MessageTypes.File : msgType.trim(),
    'body': body.trim().isEmpty ? filename.trim() : body.trim(),
    if (filename.trim().isNotEmpty) 'filename': filename.trim(),
    'url': mediaUrl.trim(),
    if (info.isNotEmpty) 'info': info,
  };
}

Future<void> writeSentMediaThumbnail(
  Future<MediaThumbnailCache> cacheFuture,
  String eventId,
  Uint8List bytes, {
  required bool resizeImage,
}) async {
  try {
    final cache = await cacheFuture;
    var thumbnailBytes = bytes;
    if (resizeImage) {
      try {
        thumbnailBytes = await resizeImageForLocalOutboxThumbnail(bytes);
      } on Object catch (e) {
        debugPrint('sent media thumbnail resize failed: $e');
      }
    }
    await cache.write(eventId, thumbnailBytes);
  } on Object catch (e) {
    debugPrint('sent media thumbnail cache write failed: $e');
  }
}

Future<void> sendProductMediaWithPendingState({
  required ScaffoldMessengerState messenger,
  required ChatMediaAttachment attachment,
  required ChatMediaAttachmentSender sendAttachment,
  required Future<MediaThumbnailCache>? thumbnailCacheFuture,
  required FutureOr<String?> Function()? onStarted,
  required FutureOr<void> Function(String pendingUploadId, String eventId)?
      onDelivered,
  required FutureOr<void> Function(String pendingUploadId)? onSucceeded,
  required FutureOr<void> Function(String pendingUploadId)? onFailed,
  AppLocalizations? l10n,
}) async {
  try {
    ChatMediaSendResult? sentResult;
    await runChatMediaSendTask<ChatMediaSendResult>(
      onStarted: onStarted,
      send: () async {
        final result = await sendAttachment(attachment);
        sentResult = result;
        final thumbnailBytes = attachment.isVideo
            ? attachment.thumbnailBytes
            : attachment.isImage
                ? attachment.bytes
                : null;
        if (thumbnailBytes != null &&
            thumbnailBytes.isNotEmpty &&
            thumbnailCacheFuture != null &&
            result.eventId.trim().isNotEmpty) {
          unawaited(
            writeSentMediaThumbnail(
              thumbnailCacheFuture,
              result.eventId,
              thumbnailBytes,
              resizeImage: attachment.isImage,
            ),
          );
        }
        return result;
      },
      onSucceeded: (pendingUploadId) async {
        final result = sentResult;
        if (result != null && result.eventId.trim().isNotEmpty) {
          await onDelivered?.call(pendingUploadId, result.eventId);
        }
        await onSucceeded?.call(pendingUploadId);
      },
      onFailed: onFailed,
      onLifecycleError: (error, stackTrace) {
        debugPrint(
          'chat media pending UI ignored after lifecycle loss: $error',
        );
      },
    );
  } on ChatMediaSendException catch (error) {
    debugPrint(
      'chat media send failed at ${error.stage.name}: ${error.cause}',
    );
    final message = error.stage == ChatMediaSendStage.send
        ? productSendFailureMessage(error.cause, l10n: l10n)
        : error.userMessageFor(l10n);
    if (messenger.mounted) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
    }
  } on Object catch (error) {
    debugPrint('chat media send failed: $error');
    if (messenger.mounted) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(productSendFailureMessage(error, l10n: l10n)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

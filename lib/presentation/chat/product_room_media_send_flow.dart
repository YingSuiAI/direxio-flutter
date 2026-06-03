import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import '../../data/media_thumbnail_cache.dart';
import 'chat_media_send_flow.dart';
import 'product_media_outbox_flow.dart';

String productSendFailureMessage(Object error) {
  if (error is AsClientException &&
      error.statusCode == 403 &&
      error.message == 'peer deleted contact') {
    return '对方已删除联系人关系，消息未送达';
  }
  return '发送失败：$error';
}

ChatMediaAttachmentSender createProductRoomMediaSender({
  required Client matrixClient,
  required AsClient asClient,
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
      return asClient.sendRoomMediaMessage(
        roomId: roomId,
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
      );
    },
    oneShotSync: matrixClient.oneShotSync,
    onSyncFailure: (error, stackTrace) {
      debugPrint('chat media oneShotSync failed: $error');
    },
  );
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
        ? productSendFailureMessage(error.cause)
        : error.userMessage;
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
          content: Text(productSendFailureMessage(error)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

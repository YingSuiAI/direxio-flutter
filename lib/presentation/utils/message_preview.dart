import 'package:matrix/matrix.dart';

import '../../data/local_outbox_store.dart';
import '../chat/call_timeline_events.dart';

String roomEventPreviewText(Event? event, {required bool isAgent}) {
  final fallback = isAgent ? '让 Agent 帮你总结、回复和创作' : '';
  if (event == null) return fallback;
  final callText = callPreviewText(event);
  if (callText.isNotEmpty) return callText;
  if (event.type != EventTypes.Message && event.text.isEmpty) return fallback;
  if (event.type == EventTypes.Message &&
      event.messageType == MessageTypes.Image) {
    return event.senderId == event.room.client.userID ? '发送图片' : '收到图片';
  }
  if (event.type == EventTypes.Message &&
      event.messageType == MessageTypes.Video) {
    return event.senderId == event.room.client.userID ? '发送视频' : '收到视频';
  }
  if (event.type == EventTypes.Message &&
      (event.messageType == MessageTypes.File ||
          event.messageType == MessageTypes.Audio)) {
    return event.senderId == event.room.client.userID ? '发送文件' : '收到文件';
  }
  return previewText(event.plaintextBody);
}

String conversationPreviewText({
  required Event? lastEvent,
  required LocalOutboxItem? latestFailedOutbox,
  DateTime? lastEventSortTime,
  required bool isAgent,
}) {
  final failedAt = latestFailedOutbox?.createdAt;
  final eventAt = lastEventSortTime ?? lastEvent?.originServerTs;
  if (latestFailedOutbox != null &&
      (eventAt == null || failedAt == null || failedAt.isAfter(eventAt))) {
    return '发送失败';
  }
  return roomEventPreviewText(lastEvent, isAgent: isAgent);
}

int conversationUnreadCount({
  required int matrixUnreadCount,
}) {
  return matrixUnreadCount <= 0 ? 0 : matrixUnreadCount;
}

DateTime? conversationPreviewTime({
  required Event? lastEvent,
  required LocalOutboxItem? latestFailedOutbox,
  DateTime? lastEventSortTime,
}) {
  final failedAt = latestFailedOutbox?.createdAt;
  final eventAt = lastEventSortTime ?? lastEvent?.originServerTs;
  if (latestFailedOutbox != null &&
      (eventAt == null || failedAt == null || failedAt.isAfter(eventAt))) {
    return failedAt;
  }
  return eventAt;
}

String previewText(String raw) {
  return raw
      .replaceAll(RegExp(r'[*_`#~]'), '')
      .replaceAll(RegExp(r'\s*\n+\s*'), ' ')
      .trim();
}

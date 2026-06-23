import 'package:matrix/matrix.dart';

import '../../data/local_outbox_store.dart';
import '../chat/call_timeline_events.dart';
import '../chat/chat_record_forwarding.dart';

const _channelShareMessageType = 'channel_share';

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
      event.messageType == MessageTypes.Audio) {
    return '[语音]';
  }
  if (event.type == EventTypes.Message &&
      event.messageType == MessageTypes.File) {
    if (_isAudioFileEvent(event)) return '[语音]';
    return event.senderId == event.room.client.userID ? '发送文件' : '收到文件';
  }
  return previewText(event.plaintextBody);
}

bool isChannelShareEvent(Event? event) {
  if (event == null || event.type != EventTypes.Message) return false;
  final content = event.content.map(
    (key, value) => MapEntry(key.toString(), value),
  );
  final productType = (content[chatRecordMatrixMarkerKey] as String?) ??
      (content['message_type'] as String?) ??
      '';
  return productType == _channelShareMessageType;
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

String quotedEventPreviewText(Event? event) {
  if (event == null) return '原消息暂不可见';
  final callText = callPreviewText(event);
  if (callText.isNotEmpty) return callText;
  if (event.type != EventTypes.Message && event.text.isEmpty) return '消息';
  final content = event.content.map(
    (key, value) => MapEntry(key.toString(), value),
  );
  final productType = (content[chatRecordMatrixMarkerKey] as String?) ?? '';
  if (productType == chatRecordMessageType) return '[聊天记录]';
  if (productType == _channelShareMessageType) return '[频道]';
  if (event.type == EventTypes.Message) {
    switch (event.messageType) {
      case MessageTypes.Image:
        return '[图片]';
      case MessageTypes.Video:
        return '[视频]';
      case MessageTypes.Audio:
        return '[语音]';
      case MessageTypes.File:
        if (_isAudioFileEvent(event)) return '[语音]';
        return '[文件]';
    }
  }
  return previewText(_stripMatrixReplyFallback(event.plaintextBody));
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

bool _isAudioFileEvent(Event event) {
  final mime = event.attachmentMimetype.toLowerCase();
  if (mime.startsWith('audio/')) return true;
  final name = event.body.toLowerCase();
  return name.endsWith('.m4a') ||
      name.endsWith('.aac') ||
      name.endsWith('.mp3') ||
      name.endsWith('.wav') ||
      name.endsWith('.ogg') ||
      name.endsWith('.opus') ||
      name.endsWith('.amr');
}

String _stripMatrixReplyFallback(String body) {
  final lines = body.split('\n');
  if (lines.isEmpty || !lines.first.startsWith('> ')) return body;
  var index = 0;
  while (index < lines.length && lines[index].startsWith('> ')) {
    index++;
  }
  if (index < lines.length && lines[index].trim().isEmpty) {
    return lines.skip(index + 1).join('\n');
  }
  return body;
}

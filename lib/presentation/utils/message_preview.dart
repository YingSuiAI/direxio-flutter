import 'package:matrix/matrix.dart';

import '../../data/local_outbox_store.dart';
import '../../l10n/app_localizations.dart';
import '../chat/call_timeline_events.dart';
import '../chat/chat_record_forwarding.dart';

const _channelShareMessageType = 'channel_share';
const defaultAgentConversationPreview = '开始我们的聊天吧';

String roomEventPreviewText(
  Event? event, {
  required bool isAgent,
  String? agentFallback,
  AppLocalizations? l10n,
}) {
  final fallback = isAgent
      ? (agentFallback?.trim().isNotEmpty == true
          ? agentFallback!.trim()
          : defaultAgentConversationPreview)
      : '';
  if (event == null) return fallback;
  final callText = callPreviewText(event, l10n: l10n);
  if (callText.isNotEmpty) return callText;
  if (event.type != EventTypes.Message && event.text.isEmpty) return fallback;
  if (event.type == EventTypes.Message &&
      event.messageType == MessageTypes.Image) {
    return event.senderId == event.room.client.userID
        ? l10n?.messagePreviewSentImage ?? '发送图片'
        : l10n?.messagePreviewReceivedImage ?? '收到图片';
  }
  if (event.type == EventTypes.Message &&
      event.messageType == MessageTypes.Video) {
    return event.senderId == event.room.client.userID
        ? l10n?.messagePreviewSentVideo ?? '发送视频'
        : l10n?.messagePreviewReceivedVideo ?? '收到视频';
  }
  if (event.type == EventTypes.Message &&
      event.messageType == MessageTypes.Audio) {
    return l10n?.messagePreviewVoiceBracket ?? '[语音]';
  }
  if (event.type == EventTypes.Message &&
      event.messageType == MessageTypes.File) {
    if (_isAudioFileEvent(event)) {
      return l10n?.messagePreviewVoiceBracket ?? '[语音]';
    }
    return event.senderId == event.room.client.userID
        ? l10n?.messagePreviewSentFile ?? '发送文件'
        : l10n?.messagePreviewReceivedFile ?? '收到文件';
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
  String? agentFallback,
  AppLocalizations? l10n,
}) {
  final failedAt = latestFailedOutbox?.createdAt;
  final eventAt = lastEventSortTime ?? lastEvent?.originServerTs;
  if (latestFailedOutbox != null &&
      (eventAt == null || failedAt == null || failedAt.isAfter(eventAt))) {
    return l10n?.messagePreviewSendFailed ?? '发送失败';
  }
  return roomEventPreviewText(
    lastEvent,
    isAgent: isAgent,
    agentFallback: agentFallback,
    l10n: l10n,
  );
}

String quotedEventPreviewText(Event? event, {AppLocalizations? l10n}) {
  if (event == null) {
    return l10n?.groupChatOriginalMessageUnavailable ?? '原消息暂不可见';
  }
  final callText = callPreviewText(event, l10n: l10n);
  if (callText.isNotEmpty) return callText;
  if (event.type != EventTypes.Message && event.text.isEmpty) {
    return l10n?.messagePreviewMessage ?? '消息';
  }
  final content = event.content.map(
    (key, value) => MapEntry(key.toString(), value),
  );
  final productType = (content[chatRecordMatrixMarkerKey] as String?) ?? '';
  if (productType == chatRecordMessageType) {
    return l10n?.messagePreviewChatRecordBracket ?? '[聊天记录]';
  }
  if (productType == _channelShareMessageType) {
    return l10n?.messagePreviewChannelBracket ?? '[频道]';
  }
  if (event.type == EventTypes.Message) {
    switch (event.messageType) {
      case MessageTypes.Image:
        return l10n?.messagePreviewImageBracket ?? '[图片]';
      case MessageTypes.Video:
        return l10n?.messagePreviewVideoBracket ?? '[视频]';
      case MessageTypes.Audio:
        return l10n?.messagePreviewVoiceBracket ?? '[语音]';
      case MessageTypes.File:
        if (_isAudioFileEvent(event)) {
          return l10n?.messagePreviewVoiceBracket ?? '[语音]';
        }
        return l10n?.messagePreviewFileBracket ?? '[文件]';
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

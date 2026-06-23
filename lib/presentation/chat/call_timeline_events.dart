import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';

const _missedReason = 'invite_timeout';
const _rejectedReasons = {
  'reject',
  'rejected',
  'user_reject',
  'user_rejected',
  'user_busy',
};
const _productCallIntentEventType = 'p2p.call.intent.v1';
const _productGroupCallInviteEventType = 'p2p.group_call.invite.v1';
const _productGroupCallJoinEventType = 'p2p.group_call.join.v1';
const _productGroupCallLeaveEventType = 'p2p.group_call.leave.v1';
const _productCallIntentTypeKey = 'call_type';
const _productCallIntentTypeVideo = 'video';
const _productCallIntentCallIdKey = 'call_id';
const _productGroupCallUserIdKey = 'user_id';
const _sdpStreamMetadataKey = 'org.matrix.msc3077.sdp_stream_metadata';
const _productCallIntentTtl = Duration(seconds: 45);
const _activeGroupCallInviteOnlyTtl = Duration(seconds: 75);
const _activeGroupCallObservedTtl = Duration(hours: 6);

class ActiveGroupCallEntry {
  const ActiveGroupCallEntry({
    required this.callId,
    required this.isVideo,
  });

  final String callId;
  final bool isVideo;
}

bool isCallTimelineEvent(Event event) {
  return event.type == EventTypes.CallInvite ||
      event.type == EventTypes.CallAnswer ||
      event.type == EventTypes.CallHangup ||
      event.type == EventTypes.CallReject ||
      event.type == EventTypes.CallCandidates ||
      event.type == EventTypes.CallNegotiate ||
      event.type == EventTypes.CallSelectAnswer ||
      event.type == EventTypes.CallSDPStreamMetadataChanged;
}

bool isProductCallIntentEvent(Event event) {
  return event.type == _productCallIntentEventType;
}

bool isProductGroupCallEvent(Event event) {
  return event.type == _productGroupCallInviteEventType ||
      event.type == _productGroupCallJoinEventType ||
      event.type == _productGroupCallLeaveEventType;
}

bool isCallRecordEvent(Event event) {
  return event.type == EventTypes.CallHangup ||
      event.type == EventTypes.CallReject ||
      isProductGroupCallEvent(event);
}

List<Event> chatDisplayEventsForTimeline(Iterable<Event> events) {
  final all = events.toList(growable: false);
  final terminalByCallId = <String, Event>{};
  final groupRecordByCallId = <String, Event>{};
  for (final event in all) {
    if (event.type == EventTypes.CallHangup ||
        event.type == EventTypes.CallReject) {
      final callId = _callId(event);
      if (callId == null) continue;
      final existing = terminalByCallId[callId];
      if (existing == null ||
          event.originServerTs.isAfter(existing.originServerTs)) {
        terminalByCallId[callId] = event;
      }
      continue;
    }
    if (isProductGroupCallEvent(event)) {
      final callId = _callId(event);
      if (callId == null) continue;
      final existing = groupRecordByCallId[callId];
      if (existing == null ||
          event.originServerTs.isAfter(existing.originServerTs)) {
        groupRecordByCallId[callId] = event;
      }
    }
  }

  return [
    for (final event in all)
      if (event.type == EventTypes.Message ||
          (isCallRecordEvent(event) &&
              terminalByCallId[_callId(event)] == event) ||
          (isProductGroupCallEvent(event) &&
              groupRecordByCallId[_callId(event)] == event))
        event,
  ];
}

List<Event> callRecordContextEventsForTimeline(Iterable<Event> events) {
  return [
    for (final event in events)
      if (isCallTimelineEvent(event) ||
          isProductCallIntentEvent(event) ||
          isProductGroupCallEvent(event))
        event,
  ];
}

String callRecordText(
  Event event,
  Iterable<Event> roomEvents, {
  AsCallSession? asCallSession,
  bool asCallSessionPending = false,
}) {
  final isGroupCall = isProductGroupCallEvent(event);
  final asText = _callRecordTextFromAsSession(
    asCallSession,
    isGroupCall: isGroupCall || asCallSession?.roomType == 'group',
  );
  if (asText != null) return asText;
  if (asCallSessionPending) return '同步中';
  if (isGroupCall) return _groupCallRecordText(event, roomEvents);

  final reason = _reason(event);
  if (event.type == EventTypes.CallReject) return '已拒绝';
  if (reason == _missedReason) return '未接通';

  final answer = _matchingAnswer(event, roomEvents);
  final duration = answer == null
      ? _callRecordEventDuration(event)
      : event.originServerTs.difference(answer.originServerTs);
  if (duration == null) return '未接通';
  return _formatCallDuration(duration);
}

bool callRecordIsVideo(
  Event event,
  Iterable<Event> roomEvents, {
  AsCallSession? asCallSession,
}) {
  if (asCallSession != null) {
    return asCallSession.mediaType == asCallMediaTypeVideo;
  }
  if (isProductGroupCallEvent(event)) {
    return _groupCallIsVideo(event, roomEvents);
  }
  return _callRecordIsVideo(event, roomEvents);
}

String asCallSessionRecordText(AsCallSession session) {
  return _callRecordTextFromAsSession(
        session,
        isGroupCall: session.roomType == 'group',
      ) ??
      '同步中';
}

bool asCallSessionRecordIsVideo(AsCallSession session) {
  return session.mediaType == asCallMediaTypeVideo;
}

ActiveGroupCallEntry? activeGroupCallEntryForTimeline(
  Iterable<Event> events, {
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final states = <String, _GroupCallActivity>{};
  final groupEvents = [
    for (final event in events)
      if (isProductGroupCallEvent(event)) event,
  ]..sort((a, b) => a.originServerTs.compareTo(b.originServerTs));

  for (final event in groupEvents) {
    final callId = _callId(event);
    if (callId == null) continue;
    final state = states.putIfAbsent(callId, () => _GroupCallActivity(callId));
    state.latest = event;
    if (event.type == _productGroupCallInviteEventType) {
      state.invite = event;
      state.isVideo = event.content[_productCallIntentTypeKey] ==
          _productCallIntentTypeVideo;
    } else if (event.type == _productGroupCallJoinEventType) {
      final userId = _groupCallUserId(event);
      if (userId != null) state.joinedUserIds.add(userId);
    } else if (event.type == _productGroupCallLeaveEventType) {
      final userId = _groupCallUserId(event);
      if (userId != null) state.joinedUserIds.remove(userId);
    }
  }

  final active = [
    for (final state in states.values)
      if (state.isActive(now: currentTime)) state,
  ]..sort((a, b) {
      final left =
          a.latest?.originServerTs ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right =
          b.latest?.originServerTs ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
  final latest = active.isEmpty ? null : active.first;
  if (latest == null) return null;
  return ActiveGroupCallEntry(callId: latest.callId, isVideo: latest.isVideo);
}

String callRecordSenderId(Event event, Iterable<Event> roomEvents) {
  return callRecordSenderEvent(event, roomEvents)?.senderId ?? event.senderId;
}

String? asCallIdForCallRecord(Event event, Iterable<Event> roomEvents) {
  if (isProductGroupCallEvent(event)) return _callId(event);
  final invite = _matchingInvite(event, roomEvents);
  if (invite == null) return null;
  final intent = _matchingProductCallIntent(invite, roomEvents);
  if (intent == null) return null;
  final value = intent.content[_productCallIntentCallIdKey];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

Event? callRecordSenderEvent(Event event, Iterable<Event> roomEvents) {
  if (isProductGroupCallEvent(event)) {
    return _matchingGroupCallInvite(event, roomEvents);
  }
  return _matchingInvite(event, roomEvents);
}

String callPreviewText(Event event) {
  if (event.type == EventTypes.CallReject) return '已拒绝通话';
  if (event.type == EventTypes.CallHangup && _reason(event) == _missedReason) {
    return '未接通通话';
  }
  if (isProductGroupCallEvent(event)) return '群通话';
  if (isCallTimelineEvent(event)) return '通话';
  return '';
}

Event? _matchingInvite(Event terminal, Iterable<Event> events) {
  final callId = _callId(terminal);
  if (callId == null) return null;
  Event? earliestInvite;
  for (final event in events) {
    if (event.type != EventTypes.CallInvite || _callId(event) != callId) {
      continue;
    }
    if (event.originServerTs.isAfter(terminal.originServerTs)) continue;
    if (earliestInvite == null ||
        event.originServerTs.isBefore(earliestInvite.originServerTs)) {
      earliestInvite = event;
    }
  }
  return earliestInvite;
}

Event? _matchingAnswer(Event terminal, Iterable<Event> events) {
  final callId = _callId(terminal);
  if (callId == null) return null;
  Event? earliestAnswer;
  for (final event in events) {
    if (event.type != EventTypes.CallAnswer || _callId(event) != callId) {
      continue;
    }
    if (event.originServerTs.isAfter(terminal.originServerTs)) continue;
    if (earliestAnswer == null ||
        event.originServerTs.isBefore(earliestAnswer.originServerTs)) {
      earliestAnswer = event;
    }
  }
  return earliestAnswer;
}

bool _callRecordIsVideo(Event terminal, Iterable<Event> events) {
  final invite = _matchingInvite(terminal, events);
  if (invite == null) return false;
  final intent = _matchingProductCallIntent(invite, events);
  if (intent != null) {
    return intent.content[_productCallIntentTypeKey] ==
        _productCallIntentTypeVideo;
  }
  return _callInviteLooksVideo(invite);
}

bool _callInviteLooksVideo(Event invite) {
  final metadata = invite.content[_sdpStreamMetadataKey];
  if (metadata is Map) {
    for (final purpose in metadata.values) {
      if (purpose is Map && purpose['video_muted'] == false) return true;
    }
  }
  final offer = invite.content['offer'];
  final sdp = offer is Map ? offer['sdp'] : null;
  return sdp is String && RegExp(r'(^|\r?\n)m=video\s').hasMatch(sdp);
}

Event? _matchingProductCallIntent(Event invite, Iterable<Event> events) {
  final lowerBound = invite.originServerTs.subtract(_productCallIntentTtl);
  Event? latest;
  for (final event in events) {
    if (!isProductCallIntentEvent(event)) continue;
    if (event.senderId != invite.senderId) continue;
    if (event.originServerTs.isAfter(invite.originServerTs) ||
        event.originServerTs.isBefore(lowerBound)) {
      continue;
    }
    final type = event.content[_productCallIntentTypeKey];
    if (type is! String) {
      continue;
    }
    if (latest == null || event.originServerTs.isAfter(latest.originServerTs)) {
      latest = event;
    }
  }
  return latest;
}

String? _callRecordTextFromAsSession(
  AsCallSession? session, {
  required bool isGroupCall,
}) {
  if (session == null) return null;
  if (_asSessionWasRejected(session)) return '已拒绝';
  if (session.state == asCallStateMissed ||
      session.state == asCallStateFailed) {
    return '未接通';
  }
  if (session.state != asCallStateEnded &&
      session.state != asCallStateConnected) {
    return null;
  }
  final duration = _asSessionDuration(session);
  if (session.state == asCallStateEnded && session.endedAt != null) {
    if (session.answeredAt == null && duration.inSeconds <= 0) {
      return '未接通';
    }
    return _formatCallDuration(duration);
  }
  if (session.state != asCallStateEnded &&
      session.answeredAt == null &&
      duration.inSeconds <= 0) {
    return '未接通';
  }
  return _formatCallDuration(duration);
}

String _groupCallRecordText(Event event, Iterable<Event> events) {
  final connectedAt = _groupCallConnectedAt(event, events);
  if (connectedAt == null) return '未接通';
  final endAt = _groupCallEndedAt(event, events) ?? event.originServerTs;
  final duration = endAt.difference(connectedAt);
  return _formatCallDuration(duration);
}

bool _groupCallIsVideo(Event event, Iterable<Event> events) {
  final invite = _matchingGroupCallInvite(event, events);
  final type = invite?.content[_productCallIntentTypeKey] ??
      event.content[_productCallIntentTypeKey];
  return type == _productCallIntentTypeVideo;
}

Event? _matchingGroupCallInvite(Event terminal, Iterable<Event> events) {
  final callId = _callId(terminal);
  if (callId == null) return null;
  Event? earliestInvite;
  for (final event in events) {
    if (event.type != _productGroupCallInviteEventType ||
        _callId(event) != callId) {
      continue;
    }
    if (event.originServerTs.isAfter(terminal.originServerTs)) continue;
    if (earliestInvite == null ||
        event.originServerTs.isBefore(earliestInvite.originServerTs)) {
      earliestInvite = event;
    }
  }
  return earliestInvite;
}

DateTime? _groupCallConnectedAt(Event terminal, Iterable<Event> events) {
  final callId = _callId(terminal);
  if (callId == null) return null;
  final joined = <String>{};
  final orderedJoins = [
    for (final event in events)
      if (event.type == _productGroupCallJoinEventType &&
          _callId(event) == callId &&
          !event.originServerTs.isAfter(terminal.originServerTs))
        event,
  ]..sort((a, b) => a.originServerTs.compareTo(b.originServerTs));
  for (final event in orderedJoins) {
    final userId = _groupCallUserId(event);
    if (userId == null) continue;
    joined.add(userId);
    if (joined.length >= 2) return event.originServerTs;
  }
  return null;
}

DateTime? _groupCallEndedAt(Event terminal, Iterable<Event> events) {
  final callId = _callId(terminal);
  if (callId == null) return null;
  DateTime? latest;
  for (final event in events) {
    if (event.type != _productGroupCallLeaveEventType ||
        _callId(event) != callId) {
      continue;
    }
    if (event.originServerTs.isAfter(terminal.originServerTs)) continue;
    if (latest == null || event.originServerTs.isAfter(latest)) {
      latest = event.originServerTs;
    }
  }
  return latest;
}

String? _groupCallUserId(Event event) {
  final value = event.content[_productGroupCallUserIdKey];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return event.senderId.trim().isEmpty ? null : event.senderId.trim();
}

class _GroupCallActivity {
  _GroupCallActivity(this.callId);

  final String callId;
  final Set<String> joinedUserIds = {};
  Event? invite;
  Event? latest;
  bool isVideo = false;

  bool isActive({required DateTime now}) {
    final latestEvent = latest;
    if (latestEvent == null) return false;
    if (joinedUserIds.isNotEmpty) {
      return now.difference(latestEvent.originServerTs) <=
          _activeGroupCallObservedTtl;
    }
    final inviteEvent = invite;
    if (inviteEvent == null) return false;
    return now.difference(inviteEvent.originServerTs) <=
        _activeGroupCallInviteOnlyTtl;
  }
}

Duration _asSessionDuration(AsCallSession session) {
  if (session.durationMs > 0) {
    return Duration(milliseconds: session.durationMs);
  }
  final answeredAt = session.answeredAt;
  final endedAt = session.endedAt;
  if (endedAt == null) return Duration.zero;
  final startedAt = answeredAt ?? session.createdAt;
  final duration = endedAt.difference(startedAt);
  return duration.isNegative ? Duration.zero : duration;
}

Duration? _callRecordEventDuration(Event event) {
  final durationMs = _durationMsValue(
    event.content['duration_ms'] ?? event.content['duration'],
  );
  if (durationMs == null || durationMs <= 0) return null;
  return Duration(milliseconds: durationMs);
}

int? _durationMsValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }
  return null;
}

String? _callId(Event event) {
  final value = event.content['call_id'];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

String? _reason(Event event) {
  final value = event.content['reason'];
  return value is String ? value : null;
}

bool _asSessionWasRejected(AsCallSession session) {
  final reason = session.endReason.trim().toLowerCase();
  return _rejectedReasons.contains(reason);
}

String _formatCallDuration(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 24 * 60 * 60);
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

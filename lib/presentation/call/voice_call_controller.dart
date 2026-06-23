import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:matrix/matrix.dart';
import 'package:webrtc_interface/webrtc_interface.dart' as rtc;

import '../../data/as_call_session_store.dart';
import '../../data/as_client.dart';
import '../utils/avatar_url.dart';
import '../utils/room_read_state.dart';

enum VoiceCallStatus {
  idle,
  calling,
  ringing,
  connecting,
  connected,
  ended,
  failed,
}

enum GroupCallStatus {
  idle,
  ringing,
  joining,
  connected,
  ended,
  failed,
}

enum ProductCallType {
  voice,
  video,
}

class GroupCallParticipantInfo {
  const GroupCallParticipantInfo({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.isLocal = false,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool isLocal;

  @override
  bool operator ==(Object other) {
    return other is GroupCallParticipantInfo &&
        other.userId == userId &&
        other.displayName == displayName &&
        other.avatarUrl == avatarUrl &&
        other.isLocal == isLocal;
  }

  @override
  int get hashCode => Object.hash(userId, displayName, avatarUrl, isLocal);
}

class GroupCallVideoStreamInfo {
  const GroupCallVideoStreamInfo({
    required this.userId,
    this.stream,
    this.isLocal = false,
    this.hasVideo = false,
    this.isMuted = false,
  });

  final String userId;
  final webrtc.MediaStream? stream;
  final bool isLocal;
  final bool hasVideo;
  final bool isMuted;

  bool get canRender => stream != null && hasVideo && !isMuted;

  @override
  bool operator ==(Object other) {
    return other is GroupCallVideoStreamInfo &&
        other.userId == userId &&
        other.stream == stream &&
        other.isLocal == isLocal &&
        other.hasVideo == hasVideo &&
        other.isMuted == isMuted;
  }

  @override
  int get hashCode => Object.hash(userId, stream, isLocal, hasVideo, isMuted);
}

class AsCallStateReporter {
  AsCallStateReporter(this._asClient, {AsCallSessionStore? store})
      : _store = store;

  final AsClient _asClient;
  final AsCallSessionStore? _store;
  final _connectedCallIds = <String>{};
  final _terminalCallIds = <String>{};
  final _locallyTerminalCallIds = <String>{};

  Set<String> get terminalCallIds => Set.unmodifiable(_terminalCallIds);

  Set<String> get locallyTerminalCallIds =>
      Set.unmodifiable(_locallyTerminalCallIds);

  Future<AsCallSession> createCall({
    required String roomId,
    required ProductCallType callType,
    List<String> invitedUserIds = const [],
  }) async {
    final call = await _asClient.createCall(
      roomId: roomId,
      mediaType: asMediaTypeForProductCall(callType),
      invitedUserIds: invitedUserIds,
    );
    unawaited(_storeCall(call));
    return call;
  }

  Future<List<AsCallSession>> activeCalls() async {
    final calls = await _asClient.getActiveCalls();
    unawaited(_storeCalls(calls));
    return calls;
  }

  Future<List<AsCallSession>> clearLocallyInactiveConnectedCalls(
    Iterable<AsCallSession> calls,
  ) async {
    final remaining = <AsCallSession>[];
    for (final call in calls) {
      if (call.state != asCallStateConnected ||
          _locallyTerminalCallIds.contains(call.callId)) {
        remaining.add(call);
        continue;
      }
      try {
        await reportEnded(
          call,
          reason: 'stale_local_inactive',
          connectedAt: call.answeredAt,
        );
      } catch (error) {
        debugPrint('finish stale P2P connected call failed: $error');
      }
    }
    return remaining;
  }

  Future<AsCallSession> registerIncomingCall({
    required String callId,
    required String roomId,
    required ProductCallType callType,
    required String createdByMxid,
    DateTime? createdAt,
    List<String> invitedUserIds = const [],
  }) async {
    final call = await _asClient.registerIncomingCall(
      callId: callId,
      roomId: roomId,
      mediaType: asMediaTypeForProductCall(callType),
      createdByMxid: createdByMxid,
      createdAt: createdAt,
      invitedUserIds: invitedUserIds,
    );
    unawaited(_storeCall(call));
    return call;
  }

  Future<void> reportConnected(AsCallSession? call) async {
    if (call == null ||
        _connectedCallIds.contains(call.callId) ||
        _terminalCallIds.contains(call.callId)) {
      return;
    }
    final updated = await _asClient.updateCallEvent(
      callId: call.callId,
      event: asCallStateConnected,
    );
    unawaited(_storeCall(updated));
    _connectedCallIds.add(call.callId);
  }

  Future<void> reportEnded(
    AsCallSession? call, {
    required String reason,
    DateTime? connectedAt,
    DateTime? endedAt,
  }) {
    return _reportTerminal(
      call,
      event: asCallStateEnded,
      reason: reason,
      connectedAt: connectedAt,
      endedAt: endedAt,
    );
  }

  Future<void> reportMissed(
    AsCallSession? call, {
    required String reason,
    DateTime? endedAt,
  }) {
    return _reportTerminal(
      call,
      event: asCallStateMissed,
      reason: reason,
      endedAt: endedAt,
    );
  }

  Future<void> reportFailed(
    AsCallSession? call, {
    required String reason,
    DateTime? connectedAt,
    DateTime? endedAt,
  }) {
    return _reportTerminal(
      call,
      event: asCallStateFailed,
      reason: reason,
      connectedAt: connectedAt,
      endedAt: endedAt,
    );
  }

  Future<void> _reportTerminal(
    AsCallSession? call, {
    required String event,
    required String reason,
    DateTime? connectedAt,
    DateTime? endedAt,
  }) async {
    if (call == null || _terminalCallIds.contains(call.callId)) return;
    _locallyTerminalCallIds.add(call.callId);
    final completedAt = endedAt ?? DateTime.now().toUtc();
    final updated = await _asClient.updateCallEvent(
      callId: call.callId,
      event: event,
      reason: reason,
      durationMs: _callDurationMs(connectedAt, completedAt),
    );
    unawaited(_storeCall(updated));
    _terminalCallIds.add(call.callId);
  }

  Future<void> _storeCall(AsCallSession call) async {
    try {
      await _store?.upsert(call);
    } catch (error) {
      debugPrint('persist P2P call state failed: $error');
    }
  }

  Future<void> _storeCalls(Iterable<AsCallSession> calls) async {
    try {
      await _store?.upsertAll(calls);
    } catch (error) {
      debugPrint('persist P2P active calls failed: $error');
    }
  }
}

String asMediaTypeForProductCall(ProductCallType callType) {
  return switch (callType) {
    ProductCallType.voice => asCallMediaTypeVoice,
    ProductCallType.video => asCallMediaTypeVideo,
  };
}

int _callDurationMs(DateTime? connectedAt, DateTime endedAt) {
  if (connectedAt == null) return 0;
  final duration = endedAt.toUtc().difference(connectedAt.toUtc());
  return duration.isNegative ? 0 : duration.inMilliseconds;
}

class GroupCallUiState {
  const GroupCallUiState({
    required this.status,
    this.callType = ProductCallType.voice,
    this.roomId,
    this.roomName,
    this.callId,
    this.createdByMxid,
    this.initiator,
    this.invitedUserIds = const [],
    this.invitedParticipants = const [],
    this.isIncoming = false,
    this.participantCount = 0,
    this.participants = const [],
    this.joinedUserIds = const [],
    this.mediaUserIds = const [],
    this.videoStreams = const [],
    this.isMuted = false,
    this.isCameraMuted = false,
    this.isSpeakerOn = true,
    this.connectedAt,
    this.error,
  });

  static const idle = GroupCallUiState(status: GroupCallStatus.idle);

  final GroupCallStatus status;
  final ProductCallType callType;
  final String? roomId;
  final String? roomName;
  final String? callId;
  final String? createdByMxid;
  final GroupCallParticipantInfo? initiator;
  final List<String> invitedUserIds;
  final List<GroupCallParticipantInfo> invitedParticipants;
  final bool isIncoming;
  final int participantCount;
  final List<GroupCallParticipantInfo> participants;
  final List<String> joinedUserIds;
  final List<String> mediaUserIds;
  final List<GroupCallVideoStreamInfo> videoStreams;
  final bool isMuted;
  final bool isCameraMuted;
  final bool isSpeakerOn;
  final DateTime? connectedAt;
  final String? error;

  bool get isVideo => callType == ProductCallType.video;

  int get effectiveParticipantCount {
    final media = _normalizedIds(mediaUserIds);
    if (media.isNotEmpty) return media.length;
    return participants.isNotEmpty ? participants.length : participantCount;
  }

  bool get isActive =>
      status == GroupCallStatus.ringing ||
      status == GroupCallStatus.joining ||
      status == GroupCallStatus.connected;

  GroupCallUiState copyWith({
    GroupCallStatus? status,
    ProductCallType? callType,
    String? roomId,
    String? roomName,
    String? callId,
    String? createdByMxid,
    GroupCallParticipantInfo? initiator,
    List<String>? invitedUserIds,
    List<GroupCallParticipantInfo>? invitedParticipants,
    bool? isIncoming,
    int? participantCount,
    List<GroupCallParticipantInfo>? participants,
    List<String>? joinedUserIds,
    List<String>? mediaUserIds,
    List<GroupCallVideoStreamInfo>? videoStreams,
    bool? isMuted,
    bool? isCameraMuted,
    bool? isSpeakerOn,
    DateTime? connectedAt,
    String? error,
  }) {
    return GroupCallUiState(
      status: status ?? this.status,
      callType: callType ?? this.callType,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      callId: callId ?? this.callId,
      createdByMxid: createdByMxid ?? this.createdByMxid,
      initiator: initiator ?? this.initiator,
      invitedUserIds: invitedUserIds ?? this.invitedUserIds,
      invitedParticipants: invitedParticipants ?? this.invitedParticipants,
      isIncoming: isIncoming ?? this.isIncoming,
      participantCount: participantCount ?? this.participantCount,
      participants: participants ?? this.participants,
      joinedUserIds: joinedUserIds ?? this.joinedUserIds,
      mediaUserIds: mediaUserIds ?? this.mediaUserIds,
      videoStreams: videoStreams ?? this.videoStreams,
      isMuted: isMuted ?? this.isMuted,
      isCameraMuted: isCameraMuted ?? this.isCameraMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      connectedAt: connectedAt ?? this.connectedAt,
      error: error,
    );
  }
}

const p2pCallIntentEventType = 'p2p.call.intent.v1';
const p2pGroupCallInviteEventType = 'p2p.group_call.invite.v1';
const p2pGroupCallJoinEventType = 'p2p.group_call.join.v1';
const p2pGroupCallLeaveEventType = 'p2p.group_call.leave.v1';
const _p2pCallIntentCallIdKey = 'call_id';
const _p2pCallIntentTypeKey = 'call_type';
const _p2pCallIntentTargetKey = 'target_user_id';
const _p2pCallIntentCreatedAtKey = 'created_at_ms';
const _p2pGroupCallInviteesKey = 'invited_user_ids';
const _p2pGroupCallUserIdKey = 'user_id';
const _p2pCallIntentTypeVoice = 'voice';
const _p2pCallIntentTypeVideo = 'video';
const _p2pCallIntentTtl = Duration(seconds: 45);
const _p2pCallMissedReason = 'invite_timeout';
const outgoingCallNoResponseTimeout = Duration(minutes: 1);
const incomingCallStaleInviteThreshold = Duration(seconds: 75);
const connectedCallInterruptThreshold = Duration(seconds: 10);
const outgoingCallNetworkFailureMessage = '拨打失败，请检查你的网络或节点后重试';
const groupCallNetworkFailureMessage = '群通话发起失败，请检查网络或节点后重试';
const peerNoResponseMessage = '对方暂无响应，已结束拨打';
const connectedCallUnstableMessage = '网络不稳定';
const connectedCallInterruptedMessage = '通话中断';
const groupCallMediaRecoveryDelay = Duration(seconds: 12);
const connectedGroupCallMediaRecoveryDelay = Duration(seconds: 3);
const _callRingtoneAsset = 'live_ring.wav';
const _callRingtoneRestartInterval = Duration(milliseconds: 3950);
const _callRingtoneOverlap = Duration(milliseconds: 350);

enum ConnectedCallNetworkState {
  stable,
  unstable,
  interrupted,
}

class VoiceCallUiState {
  const VoiceCallUiState({
    required this.status,
    this.callType = ProductCallType.voice,
    this.callId,
    this.roomId,
    this.peerUserId,
    this.peerName,
    this.isIncoming = false,
    this.isMuted = false,
    this.isCameraMuted = false,
    this.isSpeakerOn = true,
    this.connectedAt,
    this.error,
  });

  static const idle = VoiceCallUiState(status: VoiceCallStatus.idle);

  final VoiceCallStatus status;
  final ProductCallType callType;
  final String? callId;
  final String? roomId;
  final String? peerUserId;
  final String? peerName;
  final bool isIncoming;
  final bool isMuted;
  final bool isCameraMuted;
  final bool isSpeakerOn;
  final DateTime? connectedAt;
  final String? error;

  bool get isVideo => callType == ProductCallType.video;

  bool get isActive =>
      status == VoiceCallStatus.calling ||
      status == VoiceCallStatus.ringing ||
      status == VoiceCallStatus.connecting ||
      status == VoiceCallStatus.connected;

  bool get canAnswer => isIncoming && status == VoiceCallStatus.ringing;

  VoiceCallUiState copyWith({
    VoiceCallStatus? status,
    ProductCallType? callType,
    String? callId,
    String? roomId,
    String? peerUserId,
    String? peerName,
    bool? isIncoming,
    bool? isMuted,
    bool? isCameraMuted,
    bool? isSpeakerOn,
    DateTime? connectedAt,
    String? error,
  }) {
    return VoiceCallUiState(
      status: status ?? this.status,
      callType: callType ?? this.callType,
      callId: callId ?? this.callId,
      roomId: roomId ?? this.roomId,
      peerUserId: peerUserId ?? this.peerUserId,
      peerName: peerName ?? this.peerName,
      isIncoming: isIncoming ?? this.isIncoming,
      isMuted: isMuted ?? this.isMuted,
      isCameraMuted: isCameraMuted ?? this.isCameraMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      connectedAt: connectedAt ?? this.connectedAt,
      error: error,
    );
  }
}

CallType matrixCallTypeForProduct(ProductCallType type) {
  return switch (type) {
    ProductCallType.voice => CallType.kVoice,
    ProductCallType.video => CallType.kVideo,
  };
}

ProductCallType productCallTypeForMatrix(CallType type) {
  return switch (type) {
    CallType.kVoice => ProductCallType.voice,
    CallType.kVideo => ProductCallType.video,
  };
}

ProductCallType productCallTypeForMatrixAndIntent({
  required CallType matrixCallType,
  ProductCallType? recentIntentCallType,
}) {
  return recentIntentCallType ?? productCallTypeForMatrix(matrixCallType);
}

String p2pCallIntentTypeValue(ProductCallType type) {
  return switch (type) {
    ProductCallType.voice => _p2pCallIntentTypeVoice,
    ProductCallType.video => _p2pCallIntentTypeVideo,
  };
}

String? outgoingCallPreflightError({
  required bool serviceReady,
  required bool stateActive,
  required bool startInFlight,
  required bool roomExists,
  required bool hasPeerUserId,
}) {
  if (!serviceReady) return '通话服务还没有准备好';
  if (stateActive) return '已有通话正在进行';
  if (startInFlight) return '正在发起通话';
  if (!roomExists) return '通话房间不存在';
  if (!hasPeerUserId) return '无法确定通话对象';
  return null;
}

class AsActiveCallGateDecision {
  const AsActiveCallGateDecision({
    required this.canStart,
    required this.resetLocalActive,
    this.error,
  });

  final bool canStart;
  final bool resetLocalActive;
  final String? error;
}

AsActiveCallGateDecision asActiveCallGateDecision({
  required bool localStateActive,
  required List<AsCallSession>? activeCalls,
  Set<String> locallyTerminalCallIds = const {},
  required bool activeLookupFailed,
}) {
  if (activeLookupFailed) {
    if (localStateActive) {
      return const AsActiveCallGateDecision(
        canStart: false,
        resetLocalActive: false,
        error: '已有通话正在进行',
      );
    }
    return const AsActiveCallGateDecision(
      canStart: true,
      resetLocalActive: false,
    );
  }

  final actionableActiveCalls = activeCalls
      ?.where((call) => !locallyTerminalCallIds.contains(call.callId.trim()))
      .toList(growable: false);
  if (actionableActiveCalls != null && actionableActiveCalls.isNotEmpty) {
    return const AsActiveCallGateDecision(
      canStart: false,
      resetLocalActive: false,
      error: '已有通话正在进行',
    );
  }

  return AsActiveCallGateDecision(
    canStart: true,
    resetLocalActive: localStateActive,
  );
}

String? groupCallPreflightError({
  required bool serviceReady,
  required bool privateCallActive,
  required bool groupCallActive,
  required bool roomExists,
  required bool canJoinGroupCall,
}) {
  if (!serviceReady) return '通话服务还没有准备好';
  if (privateCallActive || groupCallActive) return '已有通话正在进行';
  if (!roomExists) return '群聊不存在';
  if (!canJoinGroupCall) return '该群暂不支持群通话';
  return null;
}

String outgoingCallStartFailureText(Object? error) {
  final text = error?.toString().toLowerCase() ?? '';
  if (text.contains('handshake') ||
      text.contains('connection') ||
      text.contains('socket') ||
      text.contains('timeout') ||
      text.contains('future not completed')) {
    return outgoingCallNetworkFailureMessage;
  }
  return '通话发起失败，请稍后重试';
}

class OutgoingNoResponseTimeoutDecision {
  const OutgoingNoResponseTimeoutDecision({
    required this.finalizeCall,
    required this.sendHangup,
  });

  final bool finalizeCall;
  final bool sendHangup;
}

OutgoingNoResponseTimeoutDecision outgoingNoResponseTimeoutDecision({
  required bool activeAttemptMatches,
  required bool matrixSessionExists,
  required bool activeSessionMatches,
  required bool callHasEnded,
  required VoiceCallStatus currentStatus,
}) {
  if (!activeAttemptMatches || currentStatus == VoiceCallStatus.connected) {
    return const OutgoingNoResponseTimeoutDecision(
      finalizeCall: false,
      sendHangup: false,
    );
  }
  if (!matrixSessionExists) {
    return const OutgoingNoResponseTimeoutDecision(
      finalizeCall: true,
      sendHangup: false,
    );
  }
  if (!activeSessionMatches) {
    return const OutgoingNoResponseTimeoutDecision(
      finalizeCall: false,
      sendHangup: false,
    );
  }
  return OutgoingNoResponseTimeoutDecision(
    finalizeCall: true,
    sendHangup: !callHasEnded,
  );
}

bool outgoingInviteResultShouldBind({
  required bool activeAttemptMatches,
  required VoiceCallStatus currentStatus,
}) {
  if (!activeAttemptMatches) return false;
  return currentStatus == VoiceCallStatus.calling ||
      currentStatus == VoiceCallStatus.ringing ||
      currentStatus == VoiceCallStatus.connecting;
}

bool callTransportLooksUnstable({
  required String? peerConnectionState,
  required String? iceConnectionState,
}) {
  final peerState = peerConnectionState?.toLowerCase() ?? '';
  final iceState = iceConnectionState?.toLowerCase() ?? '';
  return peerState.contains('disconnected') ||
      peerState.contains('failed') ||
      iceState.contains('disconnected') ||
      iceState.contains('failed');
}

ConnectedCallNetworkState connectedCallNetworkState({
  required bool transportUnstable,
  required bool remoteMediaStalled,
  required Duration unstableFor,
}) {
  if (!transportUnstable && !remoteMediaStalled) {
    return ConnectedCallNetworkState.stable;
  }
  if (unstableFor >= connectedCallInterruptThreshold) {
    return ConnectedCallNetworkState.interrupted;
  }
  return ConnectedCallNetworkState.unstable;
}

String? connectedCallNetworkPrompt(ConnectedCallNetworkState state) {
  return switch (state) {
    ConnectedCallNetworkState.stable => null,
    ConnectedCallNetworkState.unstable => connectedCallUnstableMessage,
    ConnectedCallNetworkState.interrupted => connectedCallInterruptedMessage,
  };
}

ProductCallType? productCallTypeFromIntentValue(Object? value) {
  return switch (value) {
    _p2pCallIntentTypeVoice => ProductCallType.voice,
    _p2pCallIntentTypeVideo => ProductCallType.video,
    _ => null,
  };
}

bool p2pCallHangupMatchesActiveCall({
  required String updateRoomId,
  required Map<String, dynamic> eventContent,
  required String activeRoomId,
  required String activeCallId,
}) {
  if (updateRoomId != activeRoomId) return false;
  if (eventContent['type'] != EventTypes.CallHangup) return false;
  final content = eventContent['content'];
  if (content is! Map) return false;
  return content['call_id'] == activeCallId;
}

bool p2pCallTerminalShouldAutoRead({
  required bool callWasConnected,
  required String eventType,
  required String? reason,
}) {
  if (!callWasConnected) return false;
  if (eventType != EventTypes.CallHangup) return false;
  return reason != _p2pCallMissedReason;
}

bool p2pIncomingCallShouldRing({
  required bool callHasEnded,
  required bool terminalEventKnown,
  required String callId,
  String? lastRoomEventType,
  Object? lastRoomEventContent,
  DateTime? now,
}) {
  if (callHasEnded || terminalEventKnown) return false;
  final callStartedAt = p2pCallStartedAtFromCallId(callId);
  final currentTime = now ?? DateTime.now();
  if (callStartedAt != null &&
      !callStartedAt.isAfter(currentTime) &&
      currentTime.difference(callStartedAt) >
          incomingCallStaleInviteThreshold) {
    return false;
  }
  return !p2pCallEventTerminatesCall(
    eventType: lastRoomEventType,
    eventContent: lastRoomEventContent,
    callId: callId,
  );
}

bool p2pIncomingCallCanOpenRoute(
  VoiceCallUiState state, {
  required String? currentRouteRoomId,
}) {
  final roomId = state.roomId?.trim();
  final callId = state.callId?.trim();
  if (!state.isActive ||
      !state.isIncoming ||
      state.status != VoiceCallStatus.ringing ||
      roomId == null ||
      roomId.isEmpty ||
      callId == null ||
      callId.isEmpty) {
    return false;
  }
  return currentRouteRoomId != roomId;
}

@visibleForTesting
bool shouldPlayCallRingtone({
  required VoiceCallStatus voiceStatus,
  required bool voiceIsIncoming,
  required GroupCallStatus groupStatus,
}) {
  return voiceStatus == VoiceCallStatus.calling ||
      voiceStatus == VoiceCallStatus.ringing ||
      (voiceStatus == VoiceCallStatus.connecting && !voiceIsIncoming) ||
      groupStatus == GroupCallStatus.ringing;
}

bool p2pIncomingGroupCallCanOpenRoute(
  GroupCallUiState state, {
  required String? currentRouteRoomId,
}) {
  final roomId = state.roomId?.trim();
  final callId = state.callId?.trim();
  if (!state.isIncoming ||
      state.status != GroupCallStatus.ringing ||
      roomId == null ||
      roomId.isEmpty ||
      callId == null ||
      callId.isEmpty) {
    return false;
  }
  return currentRouteRoomId != roomId;
}

DateTime? p2pCallStartedAtFromCallId(String callId) {
  final match = RegExp(r'^\d{13}').firstMatch(callId);
  if (match == null) return null;
  final millis = int.tryParse(match.group(0)!);
  if (millis == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

bool p2pCallEventTerminatesCall({
  required String? eventType,
  required Object? eventContent,
  required String callId,
}) {
  if (eventType != EventTypes.CallHangup &&
      eventType != EventTypes.CallReject) {
    return false;
  }
  if (eventContent is! Map) return false;
  return eventContent['call_id'] == callId;
}

Map<String, dynamic> p2pCallIntentContent({
  required String callId,
  required ProductCallType callType,
  required String targetUserId,
  required DateTime createdAt,
}) {
  return {
    _p2pCallIntentCallIdKey: callId.trim(),
    _p2pCallIntentTypeKey: p2pCallIntentTypeValue(callType),
    _p2pCallIntentTargetKey: targetUserId,
    _p2pCallIntentCreatedAtKey: createdAt.millisecondsSinceEpoch,
  };
}

Map<String, dynamic> p2pGroupCallInviteContent({
  required String callId,
  required ProductCallType callType,
  required Iterable<String> invitedUserIds,
  required DateTime createdAt,
}) {
  return {
    _p2pCallIntentCallIdKey: callId.trim(),
    _p2pCallIntentTypeKey: p2pCallIntentTypeValue(callType),
    _p2pGroupCallInviteesKey: _normalizedIds(invitedUserIds),
    _p2pCallIntentCreatedAtKey: createdAt.millisecondsSinceEpoch,
  };
}

Map<String, dynamic> p2pGroupCallParticipantContent({
  required String callId,
  required String userId,
  required DateTime createdAt,
}) {
  return {
    _p2pCallIntentCallIdKey: callId.trim(),
    _p2pGroupCallUserIdKey: userId.trim(),
    _p2pCallIntentCreatedAtKey: createdAt.millisecondsSinceEpoch,
  };
}

String? p2pCallIdFromIntentContent(Object? content) {
  if (content is! Map) return null;
  final value = content[_p2pCallIntentCallIdKey];
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? p2pGroupCallParticipantUserIdFromContent(Object? content) {
  if (content is! Map) return null;
  final value = content[_p2pGroupCallUserIdKey];
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> p2pGroupCallInviteesFromContent(Object? content) {
  if (content is! Map) return const [];
  final raw = content[_p2pGroupCallInviteesKey] as List? ?? const [];
  return _normalizedIds(raw.whereType<String>());
}

bool p2pGroupCallInviteTargetsUser({
  required Object? content,
  required String currentUserId,
}) {
  final invitees = p2pGroupCallInviteesFromContent(content);
  if (invitees.isEmpty) return true;
  return invitees.contains(currentUserId.trim());
}

List<String> _normalizedIds(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || seen.contains(trimmed)) continue;
    seen.add(trimmed);
    result.add(trimmed);
  }
  return result;
}

VoiceCallStatus voiceCallStatusForMatrix(
  CallState state, {
  required bool isIncoming,
}) {
  return switch (state) {
    CallState.kFledgling ||
    CallState.kInviteSent ||
    CallState.kCreateOffer =>
      isIncoming ? VoiceCallStatus.ringing : VoiceCallStatus.calling,
    CallState.kRinging => VoiceCallStatus.ringing,
    CallState.kWaitLocalMedia ||
    CallState.kCreateAnswer ||
    CallState.kConnecting =>
      VoiceCallStatus.connecting,
    CallState.kConnected => VoiceCallStatus.connected,
    CallState.kEnding || CallState.kEnded => VoiceCallStatus.ended,
  };
}

GroupCallStatus groupCallStatusForMatrix(GroupCallState state) {
  return switch (state) {
    GroupCallState.localCallFeedUninitialized => GroupCallStatus.idle,
    GroupCallState.initializingLocalCallFeed ||
    GroupCallState.localCallFeedInitialized ||
    GroupCallState.entering =>
      GroupCallStatus.joining,
    GroupCallState.entered => GroupCallStatus.connected,
    GroupCallState.ended => GroupCallStatus.ended,
  };
}

GroupCallStatus groupCallStatusWithProductJoin({
  required GroupCallStatus transportStatus,
  required bool localUserJoined,
}) {
  if (localUserJoined &&
      (transportStatus == GroupCallStatus.idle ||
          transportStatus == GroupCallStatus.ended)) {
    return GroupCallStatus.joining;
  }
  if (localUserJoined && transportStatus == GroupCallStatus.ringing) {
    return GroupCallStatus.joining;
  }
  return transportStatus;
}

GroupCallStatus groupCallStatusWithObservedMedia({
  required GroupCallStatus transportStatus,
  required bool localUserJoined,
  required bool localMediaReady,
  required Iterable<String> remoteMediaUserIds,
  bool wasConnected = false,
}) {
  if (transportStatus == GroupCallStatus.ended && wasConnected) {
    return GroupCallStatus.connected;
  }
  if (transportStatus == GroupCallStatus.idle &&
      wasConnected &&
      localUserJoined) {
    return GroupCallStatus.connected;
  }
  final baseStatus = groupCallStatusWithProductJoin(
    transportStatus: transportStatus,
    localUserJoined: localUserJoined,
  );
  if (baseStatus != GroupCallStatus.connected) return baseStatus;
  if (wasConnected) return GroupCallStatus.connected;
  final remoteMedia = _normalizedIds(remoteMediaUserIds);
  if (localUserJoined &&
      localMediaReady &&
      (remoteMedia.isNotEmpty || wasConnected)) {
    return GroupCallStatus.connected;
  }
  return GroupCallStatus.joining;
}

String voiceCallStatusLabel(VoiceCallUiState state) {
  if (state.error?.trim().isNotEmpty ?? false) return state.error!.trim();
  final callName = state.isVideo ? '视频通话' : '语音通话';
  return switch (state.status) {
    VoiceCallStatus.idle => '准备通话',
    VoiceCallStatus.calling => '正在呼叫...',
    VoiceCallStatus.ringing => state.isIncoming ? '邀请你$callName' : '等待对方接听',
    VoiceCallStatus.connecting => '正在连接...',
    VoiceCallStatus.connected => state.isVideo ? '视频通话中' : '通话中',
    VoiceCallStatus.ended => '通话已结束',
    VoiceCallStatus.failed => '通话失败',
  };
}

String groupCallStatusLabel(GroupCallUiState state) {
  if (state.error?.trim().isNotEmpty ?? false) return state.error!.trim();
  return switch (state.status) {
    GroupCallStatus.idle => '群通话',
    GroupCallStatus.ringing => state.isVideo ? '邀请你加入群视频通话' : '邀请你加入群语音通话',
    GroupCallStatus.joining => state.isVideo ? '正在进入群视频通话' : '正在进入群语音通话',
    GroupCallStatus.connected => state.isVideo ? '群视频通话中' : '群语音通话中',
    GroupCallStatus.ended => '群通话已结束',
    GroupCallStatus.failed => '群通话失败',
  };
}

DateTime? nextVoiceCallConnectedAt({
  required VoiceCallStatus previousStatus,
  required DateTime? previousConnectedAt,
  required VoiceCallStatus nextStatus,
  required DateTime now,
}) {
  if (nextStatus != VoiceCallStatus.connected) return null;
  return previousStatus == VoiceCallStatus.connected
      ? previousConnectedAt ?? now
      : now;
}

DateTime? nextGroupCallConnectedAt({
  required GroupCallStatus previousStatus,
  required DateTime? previousConnectedAt,
  required GroupCallStatus nextStatus,
  required DateTime now,
  bool isIncoming = false,
  String? localUserId,
  Iterable<String> joinedUserIds = const [],
}) {
  if (nextStatus == GroupCallStatus.joining && previousConnectedAt != null) {
    return previousConnectedAt;
  }
  if (nextStatus != GroupCallStatus.connected) return null;
  if (previousConnectedAt != null &&
      (previousStatus == GroupCallStatus.connected ||
          previousStatus == GroupCallStatus.joining)) {
    return previousConnectedAt;
  }
  final local = localUserId?.trim();
  final joined = _normalizedIds(joinedUserIds);
  if (local == null || local.isEmpty || joined.isEmpty) return now;
  if (isIncoming) {
    return joined.contains(local) ? now : null;
  }
  return joined.any((userId) => userId != local) ? now : null;
}

bool shouldAutoLeaveLastGroupMember({
  required GroupCallStatus status,
  required int maxParticipantsSeen,
  required int currentParticipantCount,
  required bool hasLocalParticipant,
}) {
  return status == GroupCallStatus.connected &&
      hasLocalParticipant &&
      maxParticipantsSeen >= 2 &&
      currentParticipantCount <= 1;
}

int groupCallAutoLeaveParticipantCount(GroupCallUiState state) {
  final counts = <int>[];

  final media = _normalizedIds(state.mediaUserIds);
  if (media.isNotEmpty) counts.add(media.length);

  final joined = _normalizedIds(state.joinedUserIds);
  if (joined.isNotEmpty) counts.add(joined.length);

  if (counts.isNotEmpty) {
    return counts.reduce((value, element) => value > element ? value : element);
  }

  final participants = _normalizedIds(
      state.participants.map((participant) => participant.userId));
  if (participants.isNotEmpty) return participants.length;

  return state.participantCount;
}

bool shouldReportGroupCallEndedAfterLocalLeave({
  required int participantCountBeforeLeave,
}) {
  return participantCountBeforeLeave <= 1;
}

bool shouldReportGroupCallEndedFromMatrixEnd({
  required bool localProductJoined,
  required int participantCountBeforeEnd,
}) {
  return false;
}

bool shouldShortCircuitGroupCallStart({
  required bool activeSameRoom,
  required bool stateActive,
  required bool joinExistingInvite,
  required bool localAlreadyJoined,
}) {
  if (!activeSameRoom || !stateActive) return false;
  if (joinExistingInvite && !localAlreadyJoined) return false;
  return true;
}

bool shouldTreatLocalGroupCallMediaJoined({
  required GroupCallStatus transportStatus,
  required bool localMediaReady,
}) {
  return transportStatus == GroupCallStatus.connected && localMediaReady;
}

bool shouldRecoverStalledGroupCallTransport({
  required GroupCallStatus status,
  required String? localUserId,
  required Iterable<String> joinedUserIds,
  required bool localMediaReady,
  required Iterable<String> remoteMediaUserIds,
  required bool recoveryAlreadyAttempted,
  bool allowLocalJoiningRecovery = false,
}) {
  if (recoveryAlreadyAttempted) return false;
  final canRecoverConnected = status == GroupCallStatus.connected;
  final canRecoverJoining =
      status == GroupCallStatus.joining && localMediaReady;
  if (!canRecoverConnected && !canRecoverJoining) return false;
  if (_normalizedIds(remoteMediaUserIds).isNotEmpty) return false;
  final local = localUserId?.trim();
  if (local == null || local.isEmpty) return false;
  final joined = _normalizedIds(joinedUserIds)..sort();
  if (joined.length < 2 || !joined.contains(local)) return false;
  if (canRecoverConnected) return true;
  if (allowLocalJoiningRecovery) return true;
  return joined.first == local;
}

bool shouldIgnoreIncomingMatrixGroupCallSession({
  required bool sameRoom,
  required bool sameProductCall,
  required bool activeLocalMediaJoined,
  required GroupCallStatus incomingTransportStatus,
}) {
  if (!sameRoom) return false;
  if (!sameProductCall) return true;
  return activeLocalMediaJoined &&
      incomingTransportStatus == GroupCallStatus.idle;
}

bool shouldPublishLocalGroupJoinBeforeMatrixEnter({
  required bool joinExistingInvite,
  required String? productCallId,
  required String? localUserId,
}) {
  return joinExistingInvite &&
      (productCallId?.trim().isNotEmpty ?? false) &&
      (localUserId?.trim().isNotEmpty ?? false);
}

String productGroupCallIdForMatrix({
  required String? productCallId,
  required String roomId,
}) {
  final normalizedProductCallId = productCallId?.trim();
  if (normalizedProductCallId != null && normalizedProductCallId.isNotEmpty) {
    return normalizedProductCallId;
  }
  return roomId;
}

bool shouldIgnoreMatrixGroupEndedForProductState({
  required bool localProductJoined,
}) {
  return localProductJoined;
}

GroupCallUiState groupCallStateAfterLocalLeave(GroupCallUiState state) {
  if (!state.isActive) return state;
  return GroupCallUiState(
    status: GroupCallStatus.ended,
    callType: state.callType,
    roomId: state.roomId,
    roomName: state.roomName,
    callId: state.callId,
    createdByMxid: state.createdByMxid,
    initiator: state.initiator,
    invitedUserIds: state.invitedUserIds,
    invitedParticipants: state.invitedParticipants,
    isIncoming: state.isIncoming,
    isMuted: state.isMuted,
    isCameraMuted: state.isCameraMuted,
    isSpeakerOn: state.isSpeakerOn,
  );
}

String p2pCallAudioStatsSummary(List<rtc.StatsReport> reports) {
  return _p2pCallMediaStatsSummary(reports, mediaKind: 'audio');
}

String p2pCallVideoStatsSummary(List<rtc.StatsReport> reports) {
  return _p2pCallMediaStatsSummary(reports, mediaKind: 'video');
}

String p2pCallMediaStatsSummary(List<rtc.StatsReport> reports) {
  return [
    p2pCallAudioStatsSummary(reports),
    p2pCallVideoStatsSummary(reports),
  ].where((summary) => summary.isNotEmpty).join(' | ');
}

Future<T?> valueAfterLoading<T>({
  required T? initialValue,
  required Future<dynamic>? loading,
  required T? Function() readValue,
  Duration timeout = const Duration(seconds: 8),
}) async {
  if (initialValue != null) return initialValue;
  if (loading != null) {
    try {
      await loading.timeout(timeout);
    } catch (_) {
      // A stale loading future should not block the normal preflight error.
    }
  }
  return readValue();
}

abstract class VoiceCallController {
  VoiceCallUiState get currentState;
  CallSession? get activeSession;
  Stream<VoiceCallUiState> get stateStream;
  GroupCallUiState get currentGroupState;
  GroupCallSession? get activeGroupSession;
  Stream<GroupCallUiState> get groupStateStream;

  Future<void> attachClient(Client client);
  Future<void> startOutgoing({
    required String roomId,
    required String peerUserId,
    String? peerDisplayName,
    ProductCallType callType = ProductCallType.voice,
  });
  Future<void> answer();
  Future<void> reject();
  Future<void> hangup();
  Future<void> setMuted(bool muted);
  Future<void> setCameraMuted(bool muted);
  Future<void> setSpeakerOn(bool enabled);
  Future<void> startOrJoinGroupCall({
    required String roomId,
    required String roomName,
    ProductCallType callType = ProductCallType.voice,
    List<String> invitedUserIds = const [],
    bool joinExistingInvite = false,
    String? existingCallId,
  });
  Future<void> leaveGroupCall();
  Future<void> setGroupMuted(bool muted);
  Future<void> setGroupCameraMuted(bool muted);
  Future<void> setGroupSpeakerOn(bool enabled);
  void dispose();
}

abstract class CallAudioRoute {
  Future<void> setSpeakerOn(bool enabled);
}

abstract class CallRingtonePlayer {
  Future<void> playLoop();
  Future<void> stop();
  Future<void> dispose();
}

class AssetCallRingtonePlayer implements CallRingtonePlayer {
  AssetCallRingtonePlayer({AudioPlayer? player})
      : _players = [player ?? AudioPlayer(), AudioPlayer()];

  final List<AudioPlayer> _players;
  final List<StreamSubscription<void>> _completeSubs = [];
  Timer? _loopTimer;
  bool _looping = false;
  bool _restarting = false;
  int _activePlayerIndex = 0;

  @override
  Future<void> playLoop() async {
    if (_looping) return;
    _looping = true;
    _loopTimer?.cancel();
    await _cancelCompleteSubscriptions();
    for (var index = 0; index < _players.length; index += 1) {
      final playerIndex = index;
      _completeSubs.add(_players[playerIndex].onPlayerComplete.listen((_) {
        if (!_looping || _restarting || playerIndex != _activePlayerIndex) {
          return;
        }
        unawaited(_startNextPlayback('complete'));
      }));
      await _players[index].stop();
      await _players[index].setReleaseMode(ReleaseMode.stop);
      await _players[index].setVolume(1);
    }
    _activePlayerIndex = 0;
    await _startPlayback(_activePlayerIndex);
    _loopTimer = Timer.periodic(_callRingtoneRestartInterval, (_) {
      unawaited(_startNextPlayback('timer').catchError((Object error) {
        debugPrint('call ringtone timed replay failed: $error');
      }));
    });
  }

  Future<void> _startPlayback(int playerIndex) async {
    final player = _players[playerIndex];
    await player.stop();
    await player.play(
      AssetSource(_callRingtoneAsset),
      mode: PlayerMode.mediaPlayer,
      ctx: _callRingtoneAudioContext,
    );
  }

  Future<void> _startNextPlayback(String source) async {
    if (!_looping || _restarting) return;
    _restarting = true;
    final previousIndex = _activePlayerIndex;
    final nextIndex = (_activePlayerIndex + 1) % _players.length;
    try {
      await _startPlayback(nextIndex);
      if (!_looping) return;
      _activePlayerIndex = nextIndex;
      unawaited(
        Future<void>.delayed(_callRingtoneOverlap, () async {
          if (!_looping || _activePlayerIndex == previousIndex) return;
          await _players[previousIndex].stop();
        }).catchError((Object error) {
          debugPrint('call ringtone overlap stop failed: $error');
        }),
      );
    } catch (error) {
      debugPrint('call ringtone $source replay failed: $error');
    } finally {
      _restarting = false;
    }
  }

  @override
  Future<void> stop() async {
    _looping = false;
    _restarting = false;
    _loopTimer?.cancel();
    _loopTimer = null;
    await _cancelCompleteSubscriptions();
    for (final player in _players) {
      await player.stop();
    }
  }

  @override
  Future<void> dispose() async {
    _looping = false;
    _loopTimer?.cancel();
    _loopTimer = null;
    await _cancelCompleteSubscriptions();
    for (final player in _players) {
      await player.dispose();
    }
  }

  Future<void> _cancelCompleteSubscriptions() async {
    for (final subscription in _completeSubs) {
      await subscription.cancel();
    }
    _completeSubs.clear();
  }
}

final AudioContext _callRingtoneAudioContext = AudioContext(
  android: const AudioContextAndroid(
    isSpeakerphoneOn: true,
    audioMode: AndroidAudioMode.normal,
    contentType: AndroidContentType.sonification,
    usageType: AndroidUsageType.notificationRingtone,
    audioFocus: AndroidAudioFocus.gainTransientMayDuck,
  ),
);

class WebRtcCallAudioRoute implements CallAudioRoute {
  const WebRtcCallAudioRoute();

  @override
  Future<void> setSpeakerOn(bool enabled) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await webrtc.Helper.ensureAudioSession();
    }
    if (enabled) {
      await webrtc.Helper.setSpeakerphoneOnButPreferBluetooth();
    } else {
      await webrtc.Helper.setSpeakerphoneOn(false);
    }
  }
}

class MatrixVoiceCallController implements VoiceCallController {
  MatrixVoiceCallController({
    CallAudioRoute? audioRoute,
    CallRingtonePlayer? ringtonePlayer,
    AsClient? asClient,
    AsCallSessionStore? asCallSessionStore,
  })  : _audioRoute = audioRoute ?? const WebRtcCallAudioRoute(),
        _ringtonePlayer = ringtonePlayer ?? AssetCallRingtonePlayer(),
        _asCallReporter = asClient == null
            ? null
            : AsCallStateReporter(asClient, store: asCallSessionStore);

  final _stateController = StreamController<VoiceCallUiState>.broadcast();
  final _groupStateController = StreamController<GroupCallUiState>.broadcast();
  late final _delegate = _MatrixWebRtcDelegate(this);
  final CallAudioRoute _audioRoute;
  final CallRingtonePlayer _ringtonePlayer;
  final AsCallStateReporter? _asCallReporter;

  Client? _client;
  VoIP? _voip;
  CallSession? _activeSession;
  GroupCallSession? _activeGroupSession;
  AsCallSession? _activeAsCall;
  AsCallSession? _activeGroupAsCall;
  StreamSubscription<CallState>? _callStateSub;
  StreamSubscription<CallStateChange>? _callEventSub;
  StreamSubscription<WrappedMediaStream>? _streamAddSub;
  StreamSubscription<WrappedMediaStream>? _streamRemoveSub;
  StreamSubscription<GroupCallState>? _groupStateSub;
  StreamSubscription<GroupCallStateChange>? _groupEventSub;
  StreamSubscription<GroupCallSession>? _groupFeedsSub;
  StreamSubscription<EventUpdate>? _clientEventSub;
  Timer? _mediaDebugTimer;
  Timer? _groupMediaDebugTimer;
  Timer? _groupMediaRecoveryTimer;
  Timer? _mediaHealthTimer;
  Timer? _outgoingNoResponseTimer;
  int _outgoingAttemptId = 0;
  final _recentCallIntents = <_RecentCallIntent>[];
  final _handledHangupCallIds = <String>{};
  final _connectedCallReadKeys = <String>{};
  final _terminalCallKeys = <String>{};
  DateTime? _mediaUnstableSince;
  DateTime? _remoteMediaStalledSince;
  int? _lastInboundMediaBytes;
  VoiceCallUiState _state = VoiceCallUiState.idle;
  GroupCallUiState _groupState = GroupCallUiState.idle;
  bool _disposed = false;
  bool _startOutgoingInFlight = false;
  bool _autoLeavingLastGroupMember = false;
  int _maxGroupParticipantsSeen = 0;
  bool _groupMediaRecoveryAttempted = false;
  bool _callRingtonePlaying = false;

  @override
  VoiceCallUiState get currentState => _state;

  @override
  CallSession? get activeSession => _activeSession;

  @override
  Stream<VoiceCallUiState> get stateStream => _stateController.stream;

  @override
  GroupCallUiState get currentGroupState => _groupState;

  @override
  GroupCallSession? get activeGroupSession => _activeGroupSession;

  @override
  Stream<GroupCallUiState> get groupStateStream => _groupStateController.stream;

  @override
  Future<void> attachClient(Client client) async {
    if (_disposed || !client.isLogged()) return;
    if (identical(_client, client) && _voip != null) return;
    await _resetActiveSession(emitIdle: false);
    await _resetActiveGroupSession(emitIdle: false);
    await _clientEventSub?.cancel();
    _recentCallIntents.clear();
    _handledHangupCallIds.clear();
    _connectedCallReadKeys.clear();
    _terminalCallKeys.clear();
    _client = client;
    _voip = VoIP(client, _delegate);
    _clientEventSub = client.onEvent.stream.listen(_handleClientEvent);
  }

  @override
  Future<void> startOutgoing({
    required String roomId,
    required String peerUserId,
    String? peerDisplayName,
    ProductCallType callType = ProductCallType.voice,
  }) async {
    final client = _client;
    final voip = _voip;
    final room = client?.getRoomById(roomId);
    final preflightError = outgoingCallPreflightError(
      serviceReady: client != null && voip != null && client.isLogged(),
      stateActive: false,
      startInFlight: _startOutgoingInFlight,
      roomExists: room != null,
      hasPeerUserId: peerUserId.trim().isNotEmpty,
    );
    if (preflightError != null) {
      _emitFailed(preflightError);
      return;
    }
    final activeGate = await _asActiveCallGate(
      localStateActive: _state.isActive,
    );
    if (activeGate.resetLocalActive) {
      await _resetActiveSession(emitIdle: false);
    }
    if (!activeGate.canStart) {
      _emitFailed(activeGate.error ?? '已有通话正在进行');
      return;
    }
    final callRoom = room!;
    final callVoip = voip!;

    _startOutgoingInFlight = true;
    final outgoingAttemptId = ++_outgoingAttemptId;
    _emit(
      VoiceCallUiState(
        status: VoiceCallStatus.calling,
        callType: callType,
        roomId: roomId,
        peerUserId: peerUserId,
        peerName: peerDisplayName?.trim().isNotEmpty ?? false
            ? peerDisplayName!.trim()
            : callRoom.getLocalizedDisplayname(),
      ),
    );
    _startOutgoingNoResponseTimer(outgoingAttemptId);

    AsCallSession? asCall;
    try {
      asCall = await _createAsCall(
        roomId: roomId,
        callType: callType,
      );
      if (!outgoingInviteResultShouldBind(
        activeAttemptMatches: _outgoingAttemptId == outgoingAttemptId,
        currentStatus: _state.status,
      )) {
        if (asCall != null) {
          unawaited(_reportAsCallMissed(
            asCall,
            reason: _p2pCallMissedReason,
          ));
        }
        return;
      }
      _activeAsCall = asCall;
      if (asCall != null) {
        _emit(_state.copyWith(callId: asCall.callId));
      }
      await _sendProductCallIntent(
        room: callRoom,
        peerUserId: peerUserId,
        callType: callType,
        callId: asCall?.callId,
      );
      if (!outgoingInviteResultShouldBind(
        activeAttemptMatches: _outgoingAttemptId == outgoingAttemptId,
        currentStatus: _state.status,
      )) {
        return;
      }
      final session = await callVoip.inviteToCall(
        callRoom,
        matrixCallTypeForProduct(callType),
        userId: peerUserId,
      );
      if (!outgoingInviteResultShouldBind(
        activeAttemptMatches: _outgoingAttemptId == outgoingAttemptId,
        currentStatus: _state.status,
      )) {
        await _cleanupLateOutgoingSession(session);
        return;
      }
      _bindSession(session);
    } catch (error) {
      if (asCall != null) {
        unawaited(_reportAsCallFailed(asCall, reason: 'start_failed'));
      }
      _emitFailed(_callStartErrorText(error));
    } finally {
      _startOutgoingInFlight = false;
    }
  }

  @override
  Future<void> answer() async {
    final session = _activeSession;
    if (session == null || session.callHasEnded) return;
    try {
      _emit(_state.copyWith(status: VoiceCallStatus.connecting));
      await session.answer();
    } catch (error) {
      _emitFailed(_callErrorText(error));
    }
  }

  @override
  Future<void> reject() async {
    final session = _activeSession;
    if (session != null && !session.callHasEnded) {
      await session.reject();
    }
    await _resetActiveSession(emitIdle: false);
  }

  @override
  Future<void> hangup() async {
    final session = _activeSession;
    final asCall = _activeAsCall;
    final connectedAt = _state.connectedAt;
    if (session != null && !session.callHasEnded) {
      await session.hangup(reason: CallErrorCode.userHangup);
    }
    await _reportAsCallEnded(
      asCall,
      reason: 'user_hangup',
      connectedAt: connectedAt,
    );
    await _resetActiveSession(emitIdle: false);
  }

  @override
  Future<void> setMuted(bool muted) async {
    final session = _activeSession;
    if (session == null || session.callHasEnded) return;
    try {
      await session.setMicrophoneMuted(muted);
      _emit(_state.copyWith(isMuted: muted));
    } catch (error) {
      _emit(_state.copyWith(error: _callErrorText(error)));
    }
  }

  @override
  Future<void> setCameraMuted(bool muted) async {
    final session = _activeSession;
    if (session == null || session.callHasEnded) return;
    try {
      await session.setLocalVideoMuted(muted);
      if (!muted && !_sessionHasLocalVideoTrack(session)) {
        final cameraCount = await _availableVideoInputCount();
        if (kDebugMode) {
          debugPrint(
            'p2p-call-camera-open-failed cameras=$cameraCount '
            'call_id=${session.callId}',
          );
        }
        _emit(_stateFromSession(session).copyWith(isCameraMuted: false));
        return;
      }
      _emit(_stateFromSession(session).copyWith(isCameraMuted: muted));
    } catch (error) {
      _emit(_state.copyWith(error: _callErrorText(error)));
    }
  }

  @override
  Future<void> setSpeakerOn(bool enabled) {
    return _setSpeakerOnInternal(enabled, emitState: true);
  }

  @override
  Future<void> startOrJoinGroupCall({
    required String roomId,
    required String roomName,
    ProductCallType callType = ProductCallType.voice,
    List<String> invitedUserIds = const [],
    bool joinExistingInvite = false,
    String? existingCallId,
  }) async {
    final client = _client;
    final voip = _voip;
    final room = await valueAfterLoading<Room>(
      initialValue: client?.getRoomById(roomId),
      loading: client?.roomsLoading,
      readValue: () => client?.getRoomById(roomId),
    );
    final activeGroupSession = _activeGroupSession;
    final activeSameRoom = activeGroupSession?.room.id == roomId;
    final localAlreadyJoined = activeGroupSession != null &&
        _localUserJoinedGroupSession(activeGroupSession);

    if (shouldShortCircuitGroupCallStart(
      activeSameRoom: activeSameRoom,
      stateActive: _groupState.isActive,
      joinExistingInvite: joinExistingInvite,
      localAlreadyJoined: localAlreadyJoined,
    )) {
      _emitGroupSessionState(activeGroupSession!);
      return;
    }

    if (_activeGroupSession != null && !_groupState.isActive) {
      await _leaveGroupSessionAfterStartFailure(_activeGroupSession);
      await _resetActiveGroupSession(emitIdle: false);
    }

    final preflightError = groupCallPreflightError(
      serviceReady: client != null && voip != null && client.isLogged(),
      privateCallActive: _state.isActive,
      groupCallActive: _groupState.isActive &&
          !(joinExistingInvite && activeSameRoom && !localAlreadyJoined) &&
          !(joinExistingInvite &&
              _groupState.status == GroupCallStatus.ringing &&
              _groupState.roomId == roomId),
      roomExists: room != null,
      canJoinGroupCall: true,
    );
    if (preflightError != null) {
      _emitGroupFailed(
        message: preflightError,
        roomId: roomId,
        roomName: roomName,
        callType: callType,
      );
      return;
    }

    final callRoom = room!;
    final callVoip = voip!;
    final normalizedExistingCallId = existingCallId?.trim();
    final normalizedInvitees = _normalizedIds(invitedUserIds);
    final previousGroupState =
        _groupState.roomId == roomId ? _groupState : GroupCallUiState.idle;
    final previousProductCallId = previousGroupState.callId ??
        ((normalizedExistingCallId == null || normalizedExistingCallId.isEmpty)
            ? null
            : normalizedExistingCallId);
    final effectiveInvitees = normalizedInvitees.isEmpty
        ? previousGroupState.invitedUserIds
        : normalizedInvitees;
    final currentUserId = callRoom.client.userID?.trim();
    final createdByMxid =
        joinExistingInvite ? previousGroupState.createdByMxid : currentUserId;
    final initiator = joinExistingInvite
        ? previousGroupState.initiator ??
            _groupCallParticipantInfo(
              room: callRoom,
              userId: previousGroupState.createdByMxid,
              isLocal: previousGroupState.createdByMxid == currentUserId,
            )
        : _groupCallParticipantInfo(
            room: callRoom,
            userId: currentUserId,
            isLocal: true,
          );
    final invitedParticipants =
        joinExistingInvite && previousGroupState.invitedParticipants.isNotEmpty
            ? previousGroupState.invitedParticipants
            : _invitedParticipantsForRoom(
                room: callRoom,
                initiatorId: createdByMxid,
                invitedUserIds: effectiveInvitees,
              );
    _emitGroup(
      GroupCallUiState(
        status: GroupCallStatus.joining,
        callType: callType,
        roomId: roomId,
        roomName: roomName,
        callId: previousProductCallId ?? callRoom.id,
        createdByMxid: createdByMxid,
        initiator: initiator,
        invitedUserIds: effectiveInvitees,
        invitedParticipants: invitedParticipants,
        participants:
            joinExistingInvite ? previousGroupState.participants : const [],
        joinedUserIds:
            joinExistingInvite ? previousGroupState.joinedUserIds : const [],
        isIncoming: joinExistingInvite && previousGroupState.isIncoming,
      ),
    );

    AsCallSession? asCall;
    GroupCallSession? groupCall;
    var localJoinPublishedBeforeEnter = false;
    try {
      asCall = joinExistingInvite
          ? _activeGroupAsCall
          : await _createAsCall(
              roomId: roomId,
              callType: callType,
              invitedUserIds: normalizedInvitees,
            );
      _activeGroupAsCall = asCall;
      final earlyProductCallId = asCall?.callId ?? previousProductCallId;
      if (earlyProductCallId != null && earlyProductCallId.trim().isNotEmpty) {
        _emitGroup(_groupState.copyWith(callId: earlyProductCallId.trim()));
      }
      final matrixGroupCallId = productGroupCallIdForMatrix(
        productCallId: earlyProductCallId,
        roomId: callRoom.id,
      );
      if (!callRoom.groupCallsEnabledForEveryone) {
        try {
          await callRoom.enableGroupCalls();
        } catch (error) {
          debugPrint('p2p-group-call-enable failed: $error');
        }
      }
      final activeSameMatrixCall = activeSameRoom &&
          activeGroupSession?.groupCallId == matrixGroupCallId;
      final resolvedGroupCall = joinExistingInvite &&
              activeSameMatrixCall &&
              activeGroupSession != null
          ? activeGroupSession
          : await callVoip.fetchOrCreateGroupCall(
              matrixGroupCallId,
              callRoom,
              MeshBackend(),
              'm.call',
              'm.room',
            );
      groupCall = resolvedGroupCall;
      _bindGroupSession(
        resolvedGroupCall,
        callType: callType,
        roomName: roomName,
      );
      if (shouldPublishLocalGroupJoinBeforeMatrixEnter(
        joinExistingInvite: joinExistingInvite,
        productCallId: earlyProductCallId,
        localUserId: currentUserId,
      )) {
        _applyGroupParticipantState(
          roomId: roomId,
          callId: earlyProductCallId!,
          userId: currentUserId!,
          isJoined: true,
        );
        unawaited(
          _sendProductGroupCallParticipantState(
            room: callRoom,
            callId: earlyProductCallId,
            isJoined: true,
          ),
        );
        localJoinPublishedBeforeEnter = true;
      }
      if (resolvedGroupCall.state ==
              GroupCallState.localCallFeedUninitialized ||
          resolvedGroupCall.state == GroupCallState.localCallFeedInitialized) {
        final localStream = callType == ProductCallType.voice
            ? await _createAudioOnlyGroupStream(resolvedGroupCall)
            : await _createVideoGroupStream(resolvedGroupCall);
        await resolvedGroupCall.enter(stream: localStream);
      }

      final productCallId = asCall?.callId ??
          previousProductCallId ??
          resolvedGroupCall.groupCallId;
      if (productCallId.trim().isNotEmpty) {
        _emitGroup(_groupState.copyWith(callId: productCallId));
      }
      if (currentUserId != null && currentUserId.isNotEmpty) {
        _applyGroupParticipantState(
          roomId: roomId,
          callId: productCallId,
          userId: currentUserId,
          isJoined: true,
        );
      }
      if (!joinExistingInvite &&
          productCallId.trim().isNotEmpty &&
          normalizedInvitees.isNotEmpty) {
        await _sendProductGroupCallInvite(
          room: callRoom,
          callType: callType,
          callId: productCallId,
          invitedUserIds: normalizedInvitees,
        );
      }
      if (!localJoinPublishedBeforeEnter) {
        unawaited(
          _sendProductGroupCallParticipantState(
            room: callRoom,
            callId: productCallId,
            isJoined: true,
          ),
        );
      }
      _emitGroupSessionState(resolvedGroupCall);
      if (_groupState.status == GroupCallStatus.connected) {
        unawaited(_reportAsCallConnected(asCall));
      }
    } catch (error) {
      if (localJoinPublishedBeforeEnter) {
        final failedCallId = previousProductCallId;
        if (failedCallId != null) {
          unawaited(
            _sendProductGroupCallParticipantState(
              room: callRoom,
              callId: failedCallId,
              isJoined: false,
            ),
          );
        }
      }
      if (asCall != null) {
        unawaited(_reportAsCallFailed(asCall, reason: 'start_failed'));
      }
      await _leaveGroupSessionAfterStartFailure(groupCall);
      await _resetActiveGroupSession(emitIdle: false);
      _emitGroupFailed(
        message: _groupCallErrorText(error),
        roomId: roomId,
        roomName: roomName,
        callType: callType,
      );
    }
  }

  @override
  Future<void> leaveGroupCall() async {
    final session = _activeGroupSession;
    final asCall = _activeGroupAsCall;
    final callId = _groupState.callId ?? asCall?.callId;
    final localUserId = session?.room.client.userID?.trim();
    final connectedAt = _groupState.connectedAt;
    final participantCountBeforeLeave =
        groupCallAutoLeaveParticipantCount(_groupState);
    if (session != null && callId != null && localUserId != null) {
      _applyGroupParticipantState(
        roomId: session.room.id,
        callId: callId,
        userId: localUserId,
        isJoined: false,
      );
      unawaited(
        _sendProductGroupCallParticipantState(
          room: session.room,
          callId: callId,
          isJoined: false,
        ),
      );
    }
    if (session != null && session.state != GroupCallState.ended) {
      try {
        await session.leave();
      } catch (error) {
        debugPrint('p2p-group-call-leave failed: $error');
      }
    }
    if (shouldReportGroupCallEndedAfterLocalLeave(
      participantCountBeforeLeave: participantCountBeforeLeave,
    )) {
      await _reportAsCallEnded(
        asCall,
        reason: 'group_leave',
        connectedAt: connectedAt,
      );
    }
    _emitGroup(groupCallStateAfterLocalLeave(_groupState));
    await _resetActiveGroupSession(emitIdle: false);
  }

  bool _localUserJoinedGroupSession(GroupCallSession session) {
    return shouldTreatLocalGroupCallMediaJoined(
      transportStatus: groupCallStatusForMatrix(session.state),
      localMediaReady: _groupMediaStreamReady(
        session.backend.localUserMediaStream,
      ),
    );
  }

  @override
  Future<void> setGroupMuted(bool muted) async {
    final session = _activeGroupSession;
    if (session == null || session.state == GroupCallState.ended) return;
    try {
      await session.backend.setDeviceMuted(
        session,
        muted,
        MediaInputKind.audioinput,
      );
      _emitGroup(_stateFromGroupSession(session).copyWith(isMuted: muted));
    } catch (error) {
      _emitGroup(_groupState.copyWith(error: _groupCallErrorText(error)));
    }
  }

  @override
  Future<void> setGroupCameraMuted(bool muted) async {
    final session = _activeGroupSession;
    if (session == null || session.state == GroupCallState.ended) return;
    try {
      await session.backend.setDeviceMuted(
        session,
        muted,
        MediaInputKind.videoinput,
      );
      _emitGroup(
        _stateFromGroupSession(session).copyWith(isCameraMuted: muted),
      );
    } catch (error) {
      _emitGroup(_groupState.copyWith(error: _groupCallErrorText(error)));
    }
  }

  @override
  Future<void> setGroupSpeakerOn(bool enabled) async {
    try {
      await _audioRoute.setSpeakerOn(enabled);
      _emitGroup(_groupState.copyWith(isSpeakerOn: enabled));
    } catch (error) {
      debugPrint('p2p-group-call-audio-route failed: $error');
      _emitGroup(_groupState.copyWith(error: '音频输出切换失败'));
    }
  }

  Future<void> handleNewCall(CallSession session) async {
    if (!session.isOutgoing && !await _incomingCallShouldRing(session)) {
      await _discardStaleIncomingCall(session);
      return;
    }
    if (!session.isOutgoing && _state.isActive && _activeSession != session) {
      if (_isSameCall(_activeSession, session)) return;
      await session.reject(reason: CallErrorCode.userBusy);
      return;
    }
    if (!session.isOutgoing && !await _ensureIncomingAsCall(session)) {
      await _discardStaleIncomingCall(session);
      return;
    }
    _bindSession(session);
  }

  Future<void> handleCallEnded(CallSession session) async {
    if (_activeSession == session) {
      final connectedAt = _state.connectedAt;
      _emit(_stateFromSession(session));
      await _reportAsCallEnded(
        _activeAsCall,
        reason: _callEndReason(session),
        connectedAt: connectedAt,
      );
      await _resetActiveSession(emitIdle: false);
    }
  }

  Future<void> handleMissedCall(CallSession session) async {
    if (_activeSession == session) {
      _emit(_stateFromSession(session));
      await _reportAsCallMissed(
        _activeAsCall,
        reason: _callEndReason(session),
      );
      await _resetActiveSession(emitIdle: false);
    }
  }

  Future<void> handleNewGroupCall(GroupCallSession groupCall) async {
    final previous = _groupState;
    final active = _activeGroupSession;
    final sameRoom = active?.room.id == groupCall.room.id;
    final activeProductCallId = previous.callId?.trim();
    final incomingMatrixCallId = groupCall.groupCallId.trim();
    final sameProductCall = activeProductCallId == null ||
        activeProductCallId.isEmpty ||
        incomingMatrixCallId == activeProductCallId;
    if (active != null &&
        shouldIgnoreIncomingMatrixGroupCallSession(
          sameRoom: sameRoom,
          sameProductCall: sameProductCall,
          activeLocalMediaJoined: _localUserJoinedGroupSession(active),
          incomingTransportStatus: groupCallStatusForMatrix(groupCall.state),
        )) {
      if (kDebugMode) {
        debugPrint(
          'p2p-group-call-stale-session-ignored product_call_id=${previous.callId} '
          'active_matrix_call_id=${active.groupCallId} '
          'incoming_matrix_call_id=${groupCall.groupCallId} '
          'incoming_state=${groupCall.state.name}',
        );
      }
      _emitGroupSessionState(active);
      return;
    }
    _bindGroupSession(
      groupCall,
      callType: previous.roomId == groupCall.room.id
          ? previous.callType
          : ProductCallType.voice,
      roomName: groupCall.room.getLocalizedDisplayname(),
    );
  }

  Future<void> handleGroupCallEnded(GroupCallSession groupCall) async {
    if (_activeGroupSession != groupCall) return;
    final localUserId = groupCall.room.client.userID?.trim();
    final localProductJoined = localUserId != null &&
        localUserId.isNotEmpty &&
        _groupState.joinedUserIds.contains(localUserId);
    final participantCountBeforeEnd =
        groupCallAutoLeaveParticipantCount(_groupState);
    if (shouldIgnoreMatrixGroupEndedForProductState(
      localProductJoined: localProductJoined,
    )) {
      if (kDebugMode) {
        debugPrint(
          'p2p-group-call-matrix-ended-ignored product_call_id=${_groupState.callId} '
          'matrix_call_id=${groupCall.groupCallId} joined=${_groupState.joinedUserIds.join(",")}',
        );
      }
      return;
    }
    if (!shouldReportGroupCallEndedFromMatrixEnd(
      localProductJoined: localProductJoined,
      participantCountBeforeEnd: participantCountBeforeEnd,
    )) {
      return;
    }
    final connectedAt = _groupState.connectedAt;
    _emitGroup(_stateFromGroupSession(groupCall).copyWith(
      status: GroupCallStatus.ended,
    ));
    await _reportAsCallEnded(
      _activeGroupAsCall,
      reason: 'group_ended',
      connectedAt: connectedAt,
    );
    await _resetActiveGroupSession(emitIdle: false);
  }

  Future<WrappedMediaStream> _createAudioOnlyGroupStream(
    GroupCallSession groupCall,
  ) async {
    final stream = await _delegate.mediaDevices.getUserMedia(
      const {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': false,
        },
        'video': false,
      },
    );
    return WrappedMediaStream(
      stream: stream,
      participant: groupCall.localParticipant!,
      room: groupCall.room,
      client: groupCall.client,
      purpose: SDPStreamMetadataPurpose.Usermedia,
      audioMuted: stream.getAudioTracks().isEmpty,
      videoMuted: true,
      isGroupCall: true,
      voip: groupCall.voip,
    );
  }

  Future<WrappedMediaStream> _createVideoGroupStream(
    GroupCallSession groupCall,
  ) async {
    try {
      final stream = await _delegate.mediaDevices.getUserMedia(
        const {
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': false,
          },
          'video': {
            'width': 1280,
            'height': 720,
            'facingMode': 'user',
          },
        },
      );
      return WrappedMediaStream(
        stream: stream,
        participant: groupCall.localParticipant!,
        room: groupCall.room,
        client: groupCall.client,
        purpose: SDPStreamMetadataPurpose.Usermedia,
        audioMuted: stream.getAudioTracks().isEmpty,
        videoMuted: stream.getVideoTracks().isEmpty,
        isGroupCall: true,
        voip: groupCall.voip,
      );
    } catch (error) {
      if (kDebugMode) {
        final cameraCount = await _availableVideoInputCount();
        debugPrint(
          'p2p-group-video-camera-open-failed cameras=$cameraCount '
          'room=${groupCall.room.id} error=$error',
        );
      }
      final audioOnlyStream = await _createAudioOnlyGroupStream(groupCall);
      audioOnlyStream.videoMuted = true;
      return audioOnlyStream;
    }
  }

  void _bindGroupSession(
    GroupCallSession groupCall, {
    required ProductCallType callType,
    required String roomName,
  }) {
    if (_activeGroupSession == groupCall) {
      _emitGroupSessionState(groupCall);
      return;
    }
    unawaited(_groupStateSub?.cancel());
    unawaited(_groupEventSub?.cancel());
    unawaited(_groupFeedsSub?.cancel());
    _groupMediaDebugTimer?.cancel();
    _activeGroupSession = groupCall;
    _maxGroupParticipantsSeen = 0;
    _debugLogGroupSessionMedia('bind', groupCall);
    unawaited(_debugLogGroupSessionStats('bind', groupCall));
    _emitGroupSessionState(
      groupCall,
      callType: callType,
      roomName: roomName,
    );
    if (_groupState.status == GroupCallStatus.connected) {
      unawaited(_reportAsCallConnected(_activeGroupAsCall));
    }
    _groupStateSub = groupCall.onGroupCallState.stream.listen((_) {
      final connectedAt = _groupState.connectedAt;
      final participantCountBeforeEnd =
          groupCallAutoLeaveParticipantCount(_groupState);
      final localUserId = groupCall.room.client.userID?.trim();
      final localProductJoinedBeforeEnd = localUserId != null &&
          localUserId.isNotEmpty &&
          _groupState.joinedUserIds.contains(localUserId);
      _debugLogGroupSessionMedia('state:${groupCall.state.name}', groupCall);
      unawaited(_debugLogGroupSessionStats('state', groupCall));
      _emitGroupSessionState(groupCall);
      if (_groupState.status == GroupCallStatus.connected) {
        unawaited(_reportAsCallConnected(_activeGroupAsCall));
      }
      if (groupCall.state == GroupCallState.ended &&
          shouldReportGroupCallEndedFromMatrixEnd(
            localProductJoined: localProductJoinedBeforeEnd,
            participantCountBeforeEnd: participantCountBeforeEnd,
          )) {
        unawaited(_reportAsCallEnded(
          _activeGroupAsCall,
          reason: 'group_ended',
          connectedAt: connectedAt,
        ));
      }
    });
    _groupEventSub = groupCall.onGroupCallEvent.stream.listen((_) {
      _debugLogGroupSessionMedia('event', groupCall);
      unawaited(_debugLogGroupSessionStats('event', groupCall));
      _emitGroupSessionState(groupCall);
    });
    final backend = groupCall.backend;
    if (backend is MeshBackend) {
      _groupFeedsSub = backend.onGroupCallFeedsChanged.stream.listen((_) {
        _debugLogGroupSessionMedia('feeds', groupCall);
        unawaited(_debugLogGroupSessionStats('feeds', groupCall));
        _emitGroupSessionState(groupCall);
      });
    }
    if (kDebugMode) {
      _groupMediaDebugTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) {
          _debugLogGroupSessionMedia('tick', groupCall);
          unawaited(_debugLogGroupSessionStats('tick', groupCall));
        },
      );
    }
  }

  void _bindSession(CallSession session) {
    if (_activeSession == session) {
      _emit(_stateFromSession(session));
      return;
    }
    unawaited(_callStateSub?.cancel());
    unawaited(_callEventSub?.cancel());
    unawaited(_streamAddSub?.cancel());
    unawaited(_streamRemoveSub?.cancel());
    _activeSession = session;
    _debugLogSessionMedia('bind', session);
    _emit(_stateFromSession(session));
    if (_state.status == VoiceCallStatus.connected) {
      unawaited(_reportAsCallConnected(_activeAsCall));
    }
    _applySpeakerRoute(session);
    _callStateSub = session.onCallStateChanged.stream.listen((_) {
      _debugLogSessionMedia('state:${session.state.name}', session);
      final connectedAt = _state.connectedAt;
      _emit(_stateFromSession(session));
      _applySpeakerRoute(session);
      if (_state.status == VoiceCallStatus.connected) {
        _rememberConnectedCall(session);
        unawaited(_reportAsCallConnected(_activeAsCall));
        _outgoingNoResponseTimer?.cancel();
        _outgoingNoResponseTimer = null;
      }
      if (session.callHasEnded) {
        unawaited(_reportAsCallEnded(
          _activeAsCall,
          reason: _callEndReason(session),
          connectedAt: connectedAt,
        ));
        unawaited(_resetActiveSession(emitIdle: false));
      }
    });
    _streamAddSub = session.onStreamAdd.stream.listen((_) {
      _debugLogSessionMedia('stream-add', session);
      _emit(_stateFromSession(session));
      _applySpeakerRoute(session);
    });
    _streamRemoveSub = session.onStreamRemoved.stream.listen((_) {
      _debugLogSessionMedia('stream-remove', session);
      _emit(_stateFromSession(session));
    });
    if (kDebugMode) {
      _mediaDebugTimer?.cancel();
      _mediaDebugTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) {
          _debugLogSessionMedia('tick', session);
          unawaited(_debugLogSessionStats('tick', session));
        },
      );
    }
    _startMediaHealthMonitor(session);
    _callEventSub = session.onCallEventChanged.stream.listen((event) {
      if (event == CallStateChange.kError) {
        _emitFailed(_callErrorText(session.hangupReason));
      } else if (event == CallStateChange.kFeedsChanged) {
        _debugLogSessionMedia('feeds-changed', session);
        _emit(_stateFromSession(session));
        _applySpeakerRoute(session);
      }
    });
  }

  void _debugLogSessionMedia(String phase, CallSession session) {
    if (!kDebugMode) return;
    final localStream = session.localUserMediaStream?.stream;
    final remoteStream = session.remoteUserMediaStream?.stream;
    final localVideoTracks = localStream?.getVideoTracks().length ?? 0;
    final localAudioTracks = localStream?.getAudioTracks().length ?? 0;
    final remoteVideoTracks = remoteStream?.getVideoTracks().length ?? 0;
    final remoteAudioTracks = remoteStream?.getAudioTracks().length ?? 0;
    final pc = session.pc;
    debugPrint(
      'p2p-call-media phase=$phase type=${session.type.name} '
      'state=${session.state.name} localVideo=$localVideoTracks '
      'localAudio=$localAudioTracks remoteVideo=$remoteVideoTracks '
      'remoteAudio=$remoteAudioTracks pc=${pc?.connectionState?.name} '
      'ice=${pc?.iceConnectionState?.name} localAudioState='
      '${_trackSummary(localStream?.getAudioTracks())} remoteAudioState='
      '${_trackSummary(remoteStream?.getAudioTracks())}',
    );
  }

  bool _sessionHasLocalVideoTrack(CallSession session) {
    final stream = session.localUserMediaStream?.stream;
    return stream?.getVideoTracks().isNotEmpty ?? false;
  }

  Future<int> _availableVideoInputCount() async {
    try {
      final devices = await _delegate.mediaDevices.enumerateDevices();
      final cameras = devices
          .where((device) => device.kind?.toLowerCase() == 'videoinput')
          .toList(growable: false);
      if (kDebugMode) {
        debugPrint(
          'p2p-call-camera-devices count=${cameras.length} '
          'labels=${cameras.map((device) => device.label).join('|')}',
        );
      }
      return cameras.length;
    } catch (error) {
      debugPrint('p2p-call-camera-devices failed: $error');
      return 0;
    }
  }

  Future<void> _debugLogSessionStats(String phase, CallSession session) async {
    if (!kDebugMode) return;
    final pc = session.pc;
    if (pc == null) return;
    try {
      final summary = p2pCallMediaStatsSummary(await pc.getStats());
      if (summary.isEmpty) return;
      debugPrint(
        'p2p-call-stats phase=$phase type=${session.type.name} '
        'state=${session.state.name} $summary',
      );
    } catch (error) {
      debugPrint('p2p-call-stats failed: $error');
    }
  }

  void _debugLogGroupSessionMedia(String phase, GroupCallSession groupCall) {
    if (!kDebugMode) return;
    final backend = groupCall.backend;
    final localStream = backend.localUserMediaStream?.stream;
    final remoteStreams = backend.userMediaStreams
        .where((stream) => !stream.isLocal())
        .toList(growable: false);
    final remoteSummary = remoteStreams.map((stream) {
      final mediaStream = stream.stream;
      final participant = stream.participant.userId;
      return '$participant:a${mediaStream?.getAudioTracks().length ?? 0}'
          '/v${mediaStream?.getVideoTracks().length ?? 0}'
          '/audio=${_trackSummary(mediaStream?.getAudioTracks())}'
          '/pc=${stream.pc?.connectionState?.name}'
          '/ice=${stream.pc?.iceConnectionState?.name}';
    }).join(';');
    debugPrint(
      'p2p-group-call-media phase=$phase product_call_id=${_groupState.callId} '
      'matrix_call_id=${groupCall.groupCallId} matrix_state=${groupCall.state.name} '
      'ui_state=${_groupState.status.name} joined=${_groupState.joinedUserIds.join(",")} '
      'localAudio=${localStream?.getAudioTracks().length ?? 0} '
      'localVideo=${localStream?.getVideoTracks().length ?? 0} '
      'localAudioState=${_trackSummary(localStream?.getAudioTracks())} '
      'remoteFeeds=${remoteStreams.length} remote=[$remoteSummary]',
    );
  }

  Future<void> _debugLogGroupSessionStats(
    String phase,
    GroupCallSession groupCall,
  ) async {
    if (!kDebugMode) return;
    final streams = groupCall.backend.userMediaStreams
        .where((stream) => stream.pc != null)
        .toList(growable: false);
    for (final stream in streams) {
      try {
        final summary = p2pCallMediaStatsSummary(await stream.pc!.getStats());
        if (summary.isEmpty) continue;
        debugPrint(
          'p2p-group-call-stats phase=$phase product_call_id=${_groupState.callId} '
          'matrix_call_id=${groupCall.groupCallId} participant=${stream.participant.userId} '
          'matrix_state=${groupCall.state.name} $summary',
        );
      } catch (error) {
        debugPrint(
          'p2p-group-call-stats failed participant=${stream.participant.userId}: $error',
        );
      }
    }
  }

  String _trackSummary(Iterable<dynamic>? tracks) {
    if (tracks == null || tracks.isEmpty) return 'none';
    return tracks
        .map((track) => '${track.enabled ? 'on' : 'off'}'
            '/${track.muted == true ? 'muted' : 'live'}')
        .join(',');
  }

  VoiceCallUiState _stateFromSession(CallSession session) {
    final isIncoming = session.direction == CallDirection.kIncoming;
    final previousState =
        _state.roomId == session.room.id ? _state : VoiceCallUiState.idle;
    final status = voiceCallStatusForMatrix(
      session.state,
      isIncoming: isIncoming,
    );
    final recentIntent =
        isIncoming ? _recentCallIntentForSession(session) : null;
    final callType = productCallTypeForMatrixAndIntent(
      matrixCallType: session.type,
      recentIntentCallType: isIncoming
          ? recentIntent?.callType
          : previousState.isVideo
              ? previousState.callType
              : null,
    );
    return VoiceCallUiState(
      status: status,
      callType: callType,
      callId: isIncoming
          ? _activeAsCall?.callId
          : _activeAsCall?.callId ?? previousState.callId,
      roomId: session.room.id,
      peerUserId: session.remoteUserId ?? previousState.peerUserId,
      peerName: session.remoteUser?.calcDisplayname() ??
          previousState.peerName ??
          session.room.getLocalizedDisplayname(),
      isIncoming: isIncoming,
      isMuted: session.isMicrophoneMuted,
      isCameraMuted: callType == ProductCallType.video
          ? previousState.isCameraMuted
          : session.isLocalVideoMuted,
      isSpeakerOn: previousState.isSpeakerOn,
      connectedAt: nextVoiceCallConnectedAt(
        previousStatus: previousState.status,
        previousConnectedAt: previousState.connectedAt,
        nextStatus: status,
        now: DateTime.now(),
      ),
    );
  }

  List<GroupCallParticipantInfo> _participantsFromGroupSession(
    GroupCallSession groupCall,
  ) {
    final byUserId = <String, GroupCallParticipantInfo>{};
    for (final participant in groupCall.participants) {
      _addGroupCallParticipant(
        byUserId,
        room: groupCall.room,
        userId: participant.userId,
        isLocal: participant.isLocal,
      );
    }
    final local = groupCall.localParticipant;
    if (groupCall.state == GroupCallState.entered && local != null) {
      _addGroupCallParticipant(
        byUserId,
        room: groupCall.room,
        userId: local.userId,
        isLocal: true,
      );
    }
    final participants = byUserId.values.toList(growable: false);
    return participants;
  }

  List<String> _mediaUserIdsFromGroupSession(GroupCallSession groupCall) {
    final ids = <String>[];
    final localUserId = groupCall.room.client.userID?.trim();
    if (localUserId != null &&
        localUserId.isNotEmpty &&
        groupCall.state == GroupCallState.entered &&
        _groupMediaStreamReady(groupCall.backend.localUserMediaStream)) {
      ids.add(localUserId);
    }
    for (final stream in groupCall.backend.userMediaStreams) {
      if (stream.isLocal() || !_groupMediaStreamReady(stream)) continue;
      final userId = stream.participant.userId.trim();
      if (userId.isNotEmpty) ids.add(userId);
    }
    return _normalizedIds(ids);
  }

  List<String> _remoteMediaUserIdsFromGroupSession(
    GroupCallSession groupCall,
  ) {
    final ids = <String>[];
    for (final stream in groupCall.backend.userMediaStreams) {
      if (stream.isLocal() || !_groupMediaStreamReady(stream)) continue;
      final userId = stream.participant.userId.trim();
      if (userId.isNotEmpty) ids.add(userId);
    }
    return _normalizedIds(ids);
  }

  List<GroupCallVideoStreamInfo> _videoStreamsFromGroupSession(
    GroupCallSession groupCall,
  ) {
    final streams = <GroupCallVideoStreamInfo>[];
    final seen = <String>{};

    void addStream(WrappedMediaStream? stream, {required bool isLocal}) {
      if (stream == null) return;
      final userId = stream.participant.userId.trim();
      if (userId.isEmpty || !seen.add(userId)) return;
      final mediaStream = stream.stream;
      streams.add(
        GroupCallVideoStreamInfo(
          userId: userId,
          stream: mediaStream,
          isLocal: isLocal,
          hasVideo: mediaStream?.getVideoTracks().isNotEmpty ?? false,
          isMuted: stream.isVideoMuted(),
        ),
      );
    }

    addStream(groupCall.backend.localUserMediaStream, isLocal: true);
    for (final stream in groupCall.backend.userMediaStreams) {
      if (stream.isLocal()) continue;
      addStream(stream, isLocal: false);
    }

    return streams;
  }

  bool _groupMediaStreamReady(WrappedMediaStream? stream) {
    final mediaStream = stream?.stream;
    if (mediaStream == null) return false;
    return mediaStream.getAudioTracks().isNotEmpty ||
        mediaStream.getVideoTracks().isNotEmpty;
  }

  List<GroupCallParticipantInfo> _invitedParticipantsForRoom({
    required Room room,
    required String? initiatorId,
    required Iterable<String> invitedUserIds,
  }) {
    final orderedIds = <String>[
      if (initiatorId?.trim().isNotEmpty ?? false) initiatorId!.trim(),
      ...invitedUserIds,
    ];
    final participants = <GroupCallParticipantInfo>[];
    for (final userId in _normalizedIds(orderedIds)) {
      final participant = _groupCallParticipantInfo(
        room: room,
        userId: userId,
        isLocal: userId == room.client.userID,
      );
      if (participant != null) participants.add(participant);
    }
    return participants;
  }

  void _addGroupCallParticipant(
    Map<String, GroupCallParticipantInfo> byUserId, {
    required Room room,
    required String userId,
    required bool isLocal,
  }) {
    final participant = _groupCallParticipantInfo(
      room: room,
      userId: userId,
      isLocal: isLocal,
    );
    if (participant == null) return;
    final existing = byUserId[participant.userId];
    byUserId[participant.userId] = GroupCallParticipantInfo(
      userId: participant.userId,
      displayName: participant.displayName,
      avatarUrl: participant.avatarUrl,
      isLocal: participant.isLocal || (existing?.isLocal ?? false),
    );
  }

  GroupCallParticipantInfo? _groupCallParticipantInfo({
    required Room room,
    required String? userId,
    required bool isLocal,
  }) {
    final normalized = userId?.trim() ?? '';
    if (normalized.isEmpty) return null;
    final user = room.unsafeGetUserFromMemoryOrFallback(normalized);
    final displayName = user.calcDisplayname().trim();
    return GroupCallParticipantInfo(
      userId: normalized,
      displayName: displayName.isEmpty ? normalized : displayName,
      avatarUrl: matrixContentHttpUrl(room.client, user.avatarUrl),
      isLocal: isLocal,
    );
  }

  GroupCallUiState _stateFromGroupSession(
    GroupCallSession groupCall, {
    ProductCallType? callType,
    String? roomName,
  }) {
    final previousState = _groupState.roomId == groupCall.room.id
        ? _groupState
        : GroupCallUiState.idle;
    var status = groupCallStatusForMatrix(groupCall.state);
    if (status == GroupCallStatus.idle &&
        previousState.status == GroupCallStatus.joining) {
      status = GroupCallStatus.joining;
    }
    final nextCallType = callType ?? previousState.callType;
    final participants = _participantsFromGroupSession(groupCall);
    final mediaUserIds = _mediaUserIdsFromGroupSession(groupCall);
    final remoteMediaUserIds = _remoteMediaUserIdsFromGroupSession(groupCall);
    final videoStreams = nextCallType == ProductCallType.video
        ? _videoStreamsFromGroupSession(groupCall)
        : const <GroupCallVideoStreamInfo>[];
    final localUserId = groupCall.room.client.userID?.trim();
    final matrixJoinedUserIds =
        participants.map((participant) => participant.userId);
    final hasProductRoster = previousState.invitedUserIds.isNotEmpty ||
        previousState.invitedParticipants.isNotEmpty ||
        (previousState.createdByMxid?.trim().isNotEmpty ?? false);
    final joinedUserIds = _normalizedIds([
      ...previousState.joinedUserIds,
      if (!hasProductRoster && previousState.joinedUserIds.isEmpty)
        ...matrixJoinedUserIds,
      if (status == GroupCallStatus.connected &&
          localUserId != null &&
          localUserId.isNotEmpty)
        localUserId,
    ]);
    final localUserJoined = localUserId != null &&
        (joinedUserIds.contains(localUserId) ||
            mediaUserIds.contains(localUserId));
    status = groupCallStatusWithObservedMedia(
      transportStatus: status,
      localUserJoined: localUserJoined,
      localMediaReady:
          localUserId != null && mediaUserIds.contains(localUserId),
      remoteMediaUserIds: remoteMediaUserIds,
      wasConnected: previousState.status == GroupCallStatus.connected,
    );
    final participantCount =
        mediaUserIds.isNotEmpty ? mediaUserIds.length : participants.length;
    final createdByMxid = previousState.createdByMxid;
    final initiator = previousState.initiator ??
        _groupCallParticipantInfo(
          room: groupCall.room,
          userId: createdByMxid,
          isLocal: createdByMxid == groupCall.room.client.userID,
        );
    final invitedParticipants = previousState.invitedParticipants.isNotEmpty
        ? previousState.invitedParticipants
        : _invitedParticipantsForRoom(
            room: groupCall.room,
            initiatorId: createdByMxid,
            invitedUserIds: previousState.invitedUserIds,
          );
    return GroupCallUiState(
      status: status,
      callType: nextCallType,
      roomId: groupCall.room.id,
      roomName: roomName ??
          previousState.roomName ??
          groupCall.room.getLocalizedDisplayname(),
      callId: _activeGroupAsCall?.callId ??
          previousState.callId ??
          groupCall.groupCallId,
      createdByMxid: createdByMxid,
      initiator: initiator,
      invitedUserIds: previousState.invitedUserIds,
      invitedParticipants: invitedParticipants,
      isIncoming: previousState.isIncoming,
      participantCount: participantCount,
      participants: participants,
      joinedUserIds: joinedUserIds,
      mediaUserIds: mediaUserIds,
      videoStreams: videoStreams,
      isMuted: groupCall.backend.isMicrophoneMuted,
      isCameraMuted: nextCallType == ProductCallType.voice
          ? true
          : groupCall.backend.isLocalVideoMuted,
      isSpeakerOn: previousState.isSpeakerOn,
      connectedAt: nextGroupCallConnectedAt(
        previousStatus: previousState.status,
        previousConnectedAt: previousState.connectedAt,
        nextStatus: status,
        now: DateTime.now(),
        isIncoming: previousState.isIncoming,
        localUserId: localUserId,
        joinedUserIds: mediaUserIds,
      ),
    );
  }

  void _applySpeakerRoute(CallSession session) {
    if (session.callHasEnded) return;
    unawaited(_setSpeakerOnInternal(_state.isSpeakerOn, emitState: false));
  }

  Future<void> _setSpeakerOnInternal(
    bool enabled, {
    required bool emitState,
  }) async {
    try {
      await _audioRoute.setSpeakerOn(enabled);
      if (kDebugMode) {
        debugPrint('p2p-call-audio-route speaker=$enabled');
      }
      if (emitState) _emit(_state.copyWith(isSpeakerOn: enabled));
    } catch (error) {
      debugPrint('p2p-call-audio-route failed: $error');
      if (emitState) {
        _emit(_state.copyWith(error: '音频输出切换失败'));
      }
    }
  }

  bool _isSameCall(CallSession? current, CallSession next) {
    return current != null &&
        current.room.id == next.room.id &&
        current.callId == next.callId;
  }

  Future<bool> _incomingCallShouldRing(CallSession session) async {
    final key = _callReadKey(session.room.id, session.callId);
    if (!p2pIncomingCallShouldRing(
      callHasEnded: session.callHasEnded,
      terminalEventKnown: _terminalCallKeys.contains(key),
      callId: session.callId,
      lastRoomEventType: session.room.lastEvent?.type,
      lastRoomEventContent: session.room.lastEvent?.content,
    )) {
      return false;
    }
    if (await _roomHasTerminalCallEvent(session.room, session.callId)) {
      return false;
    }
    return true;
  }

  Future<bool> _roomHasTerminalCallEvent(Room room, String callId) async {
    try {
      final events = await room.client.database?.getEventList(room, limit: 80);
      if (events == null || events.isEmpty) return false;
      return events.any(
        (event) => p2pCallEventTerminatesCall(
          eventType: event.type,
          eventContent: event.content,
          callId: callId,
        ),
      );
    } catch (error) {
      debugPrint('p2p-call-stale-check failed: $error');
      return false;
    }
  }

  Future<void> _discardStaleIncomingCall(CallSession session) async {
    if (kDebugMode) {
      debugPrint(
        'p2p-call-stale-incoming-discarded room=${session.room.id} '
        'call_id=${session.callId} state=${session.state.name}',
      );
    }
    try {
      await session.terminate(
        CallParty.kRemote,
        CallErrorCode.userHangup,
        false,
      );
    } catch (error) {
      debugPrint('p2p-call-stale-discard failed: $error');
      await session.cleanUp();
    }
  }

  void _startOutgoingNoResponseTimer(int attemptId) {
    _outgoingNoResponseTimer?.cancel();
    _outgoingNoResponseTimer = Timer(outgoingCallNoResponseTimeout, () {
      unawaited(_failNoResponseCall(attemptId));
    });
  }

  Future<void> _failNoResponseCall(int attemptId) async {
    final session = _activeSession;
    final decision = outgoingNoResponseTimeoutDecision(
      activeAttemptMatches: _outgoingAttemptId == attemptId,
      matrixSessionExists: session != null,
      activeSessionMatches: session != null && _activeSession == session,
      callHasEnded: session?.callHasEnded ?? false,
      currentStatus: _state.status,
    );
    if (!decision.finalizeCall) {
      return;
    }
    _startOutgoingInFlight = false;
    final asCall = _activeAsCall;
    if (decision.sendHangup && session != null) {
      try {
        await session.hangup(reason: CallErrorCode.inviteTimeout);
      } catch (error) {
        debugPrint('p2p-call-no-response hangup failed: $error');
      }
    }
    await _reportAsCallMissed(
      asCall,
      reason: _p2pCallMissedReason,
    );
    _emitFailed(peerNoResponseMessage);
    await _resetActiveSession(emitIdle: false);
  }

  Future<void> _cleanupLateOutgoingSession(CallSession session) async {
    try {
      if (!session.callHasEnded) {
        await session.hangup(reason: CallErrorCode.inviteTimeout);
      } else {
        await session.cleanUp();
      }
    } catch (error) {
      debugPrint('p2p-call-late-invite-cleanup failed: $error');
    }
  }

  void _startMediaHealthMonitor(CallSession session) {
    _mediaHealthTimer?.cancel();
    _mediaUnstableSince = null;
    _mediaHealthTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_checkConnectedMediaHealth(session));
    });
  }

  Future<void> _checkConnectedMediaHealth(CallSession session) async {
    if (_activeSession != session ||
        session.callHasEnded ||
        _state.status != VoiceCallStatus.connected) {
      _mediaUnstableSince = null;
      return;
    }

    final transportUnstable = callTransportLooksUnstable(
      peerConnectionState: session.pc?.connectionState?.name,
      iceConnectionState: session.pc?.iceConnectionState?.name,
    );
    final now = DateTime.now();
    final remoteMediaStalled = await _remoteMediaLooksStalled(session, now);
    if (!transportUnstable && !remoteMediaStalled) {
      _mediaUnstableSince = null;
      if (_state.error == connectedCallUnstableMessage) {
        _emit(_state.copyWith());
      }
      return;
    }

    _mediaUnstableSince ??= now;
    final networkState = connectedCallNetworkState(
      transportUnstable: transportUnstable,
      remoteMediaStalled: remoteMediaStalled,
      unstableFor: now.difference(_mediaUnstableSince!),
    );
    final prompt = connectedCallNetworkPrompt(networkState);
    if (networkState == ConnectedCallNetworkState.interrupted) {
      try {
        await session.hangup(reason: CallErrorCode.iceFailed);
      } catch (error) {
        debugPrint('p2p-call-interrupted hangup failed: $error');
      }
      await _reportAsCallFailed(
        _activeAsCall,
        reason: 'ice_failed',
        connectedAt: _state.connectedAt,
      );
      _emitFailed(prompt ?? connectedCallInterruptedMessage);
      await _resetActiveSession(emitIdle: false);
      return;
    }

    if (prompt != null && _state.error != prompt) {
      _emit(_state.copyWith(error: prompt));
    }
  }

  Future<bool> _remoteMediaLooksStalled(
    CallSession session,
    DateTime now,
  ) async {
    final pc = session.pc;
    if (pc == null || !_sessionHasRemoteMediaTrack(session)) {
      _lastInboundMediaBytes = null;
      _remoteMediaStalledSince = null;
      return false;
    }
    try {
      final bytes = p2pCallInboundMediaBytes(await pc.getStats());
      final previous = _lastInboundMediaBytes;
      _lastInboundMediaBytes = bytes;
      if (previous == null || bytes > previous) {
        _remoteMediaStalledSince = null;
        return false;
      }
      _remoteMediaStalledSince ??= now;
      return now.difference(_remoteMediaStalledSince!) >=
          const Duration(seconds: 6);
    } catch (error) {
      debugPrint('p2p-call-media-stall-check failed: $error');
      return false;
    }
  }

  bool _sessionHasRemoteMediaTrack(CallSession session) {
    final stream = session.remoteUserMediaStream?.stream;
    return (stream?.getAudioTracks().isNotEmpty ?? false) ||
        (stream?.getVideoTracks().isNotEmpty ?? false);
  }

  Future<void> _resetActiveSession({bool emitIdle = true}) async {
    _outgoingAttemptId++;
    if (!emitIdle) {
      _stopCallRingtone();
    }
    await _callStateSub?.cancel();
    await _callEventSub?.cancel();
    await _streamAddSub?.cancel();
    await _streamRemoveSub?.cancel();
    _mediaDebugTimer?.cancel();
    _mediaHealthTimer?.cancel();
    _outgoingNoResponseTimer?.cancel();
    _callStateSub = null;
    _callEventSub = null;
    _streamAddSub = null;
    _streamRemoveSub = null;
    _mediaDebugTimer = null;
    _mediaHealthTimer = null;
    _outgoingNoResponseTimer = null;
    _mediaUnstableSince = null;
    _remoteMediaStalledSince = null;
    _lastInboundMediaBytes = null;
    _activeSession = null;
    _activeAsCall = null;
    if (emitIdle) _emit(VoiceCallUiState.idle);
  }

  Future<void> _resetActiveGroupSession({bool emitIdle = true}) async {
    await _groupStateSub?.cancel();
    await _groupEventSub?.cancel();
    await _groupFeedsSub?.cancel();
    _groupMediaDebugTimer?.cancel();
    _groupStateSub = null;
    _groupEventSub = null;
    _groupFeedsSub = null;
    _groupMediaDebugTimer = null;
    _groupMediaRecoveryTimer?.cancel();
    _groupMediaRecoveryTimer = null;
    _activeGroupSession = null;
    _activeGroupAsCall = null;
    _autoLeavingLastGroupMember = false;
    _maxGroupParticipantsSeen = 0;
    _groupMediaRecoveryAttempted = false;
    if (emitIdle) _emitGroup(GroupCallUiState.idle);
  }

  Future<void> _leaveGroupSessionAfterStartFailure(
    GroupCallSession? session,
  ) async {
    if (session == null || session.state == GroupCallState.ended) return;
    try {
      await session.leave();
    } catch (error) {
      debugPrint('p2p-group-call-start-cleanup failed: $error');
    }
  }

  void _rememberConnectedCall(CallSession session) {
    _connectedCallReadKeys.add(_callReadKey(session.room.id, session.callId));
  }

  Future<AsCallSession?> _createAsCall({
    required String roomId,
    required ProductCallType callType,
    List<String> invitedUserIds = const [],
  }) {
    final reporter = _asCallReporter;
    if (reporter == null) return Future.value();
    return reporter.createCall(
      roomId: roomId,
      callType: callType,
      invitedUserIds: invitedUserIds,
    );
  }

  Future<AsActiveCallGateDecision> _asActiveCallGate({
    required bool localStateActive,
  }) async {
    final reporter = _asCallReporter;
    if (reporter == null) {
      return AsActiveCallGateDecision(
        canStart: !localStateActive,
        resetLocalActive: false,
        error: localStateActive ? '已有通话正在进行' : null,
      );
    }
    try {
      var activeCalls = await reporter.activeCalls();
      if (!localStateActive) {
        activeCalls = await reporter.clearLocallyInactiveConnectedCalls(
          activeCalls,
        );
      }
      return asActiveCallGateDecision(
        localStateActive: localStateActive,
        activeCalls: activeCalls,
        locallyTerminalCallIds: reporter.locallyTerminalCallIds,
        activeLookupFailed: false,
      );
    } catch (error) {
      debugPrint('p2p-as-active-calls failed: $error');
      return asActiveCallGateDecision(
        localStateActive: localStateActive,
        activeCalls: null,
        activeLookupFailed: true,
      );
    }
  }

  Future<AsCallSession?> _registerIncomingAsCall({
    required String callId,
    required String roomId,
    required ProductCallType callType,
    required String createdByMxid,
    DateTime? createdAt,
    List<String> invitedUserIds = const [],
  }) async {
    final reporter = _asCallReporter;
    if (reporter == null) return null;
    try {
      return await reporter.registerIncomingCall(
        callId: callId,
        roomId: roomId,
        callType: callType,
        createdByMxid: createdByMxid,
        createdAt: createdAt,
        invitedUserIds: invitedUserIds,
      );
    } catch (error) {
      debugPrint('p2p-as-call-incoming failed: $error');
      return null;
    }
  }

  Future<bool> _ensureIncomingAsCall(CallSession session) async {
    if (session.isOutgoing) return true;
    final intent = _recentCallIntentForSession(session);
    if (intent == null || intent.callId.isEmpty) return true;
    if (_activeAsCall?.callId == intent.callId) {
      return !_asCallIsTerminal(_activeAsCall!);
    }
    final registered = await _registerIncomingAsCall(
      callId: intent.callId,
      roomId: session.room.id,
      callType: intent.callType,
      createdByMxid: intent.senderId,
      createdAt: intent.createdAt,
    );
    if (registered != null) {
      _activeAsCall = registered;
      return !_asCallIsTerminal(registered);
    }
    return true;
  }

  bool _asCallIsTerminal(AsCallSession call) {
    return call.state == asCallStateEnded ||
        call.state == asCallStateMissed ||
        call.state == asCallStateFailed;
  }

  Future<void> _reportAsCallConnected(AsCallSession? call) async {
    final reporter = _asCallReporter;
    if (reporter == null || call == null) return;
    try {
      await reporter.reportConnected(call);
    } catch (error) {
      debugPrint('p2p-as-call-connected failed: $error');
    }
  }

  Future<void> _reportAsCallEnded(
    AsCallSession? call, {
    required String reason,
    DateTime? connectedAt,
  }) async {
    final reporter = _asCallReporter;
    if (reporter == null || call == null) return;
    try {
      await reporter.reportEnded(
        call,
        reason: reason,
        connectedAt: connectedAt,
      );
    } catch (error) {
      debugPrint('p2p-as-call-ended failed: $error');
    }
  }

  Future<void> _reportAsCallMissed(
    AsCallSession? call, {
    required String reason,
  }) async {
    final reporter = _asCallReporter;
    if (reporter == null || call == null) return;
    try {
      await reporter.reportMissed(call, reason: reason);
    } catch (error) {
      debugPrint('p2p-as-call-missed failed: $error');
    }
  }

  Future<void> _reportAsCallFailed(
    AsCallSession? call, {
    required String reason,
    DateTime? connectedAt,
  }) async {
    final reporter = _asCallReporter;
    if (reporter == null || call == null) return;
    try {
      await reporter.reportFailed(
        call,
        reason: reason,
        connectedAt: connectedAt,
      );
    } catch (error) {
      debugPrint('p2p-as-call-failed failed: $error');
    }
  }

  String _callEndReason(CallSession session) {
    final reason = session.hangupReason?.reason.trim();
    if (reason != null && reason.isNotEmpty) return reason;
    if (session.callHasEnded) return 'ended';
    return 'unknown';
  }

  Future<void> _sendProductCallIntent({
    required Room room,
    required String peerUserId,
    required ProductCallType callType,
    required String? callId,
  }) async {
    final normalizedCallId = callId?.trim();
    if (normalizedCallId == null || normalizedCallId.isEmpty) return;
    await room.sendEvent(
      p2pCallIntentContent(
        callId: normalizedCallId,
        callType: callType,
        targetUserId: peerUserId,
        createdAt: DateTime.now(),
      ),
      type: p2pCallIntentEventType,
    );
  }

  Future<void> _sendProductGroupCallInvite({
    required Room room,
    required ProductCallType callType,
    required String callId,
    required Iterable<String> invitedUserIds,
  }) async {
    final normalizedCallId = callId.trim();
    final invitees = _normalizedIds(invitedUserIds);
    if (normalizedCallId.isEmpty || invitees.isEmpty) return;
    await room.sendEvent(
      p2pGroupCallInviteContent(
        callId: normalizedCallId,
        callType: callType,
        invitedUserIds: invitees,
        createdAt: DateTime.now(),
      ),
      type: p2pGroupCallInviteEventType,
    );
  }

  Future<void> _sendProductGroupCallParticipantState({
    required Room room,
    required String? callId,
    required bool isJoined,
  }) async {
    final normalizedCallId = callId?.trim();
    final userId = room.client.userID?.trim();
    if (normalizedCallId == null ||
        normalizedCallId.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      return;
    }
    try {
      await room.sendEvent(
        p2pGroupCallParticipantContent(
          callId: normalizedCallId,
          userId: userId,
          createdAt: DateTime.now(),
        ),
        type: isJoined ? p2pGroupCallJoinEventType : p2pGroupCallLeaveEventType,
      );
    } catch (error) {
      debugPrint('p2p-group-call-participant-state failed: $error');
    }
  }

  void _handleClientEvent(EventUpdate update) {
    _recordCallIntent(update);
    _recordGroupCallInvite(update);
    _recordGroupCallParticipantState(update);
    _recordTerminalCallEvent(update);
    unawaited(_markConnectedCallTerminalRead(update));
    unawaited(_handleCallHangupFallback(update));
  }

  void _recordTerminalCallEvent(EventUpdate update) {
    if (!_isTimelineUpdate(update)) return;
    final eventType = _stringValue(update.content['type']);
    final content = update.content['content'];
    if (content is! Map) return;
    final callId = _stringValue(content['call_id']);
    if (callId == null) return;
    if (!p2pCallEventTerminatesCall(
      eventType: eventType,
      eventContent: content,
      callId: callId,
    )) {
      return;
    }
    _terminalCallKeys.add(_callReadKey(update.roomID, callId));
    while (_terminalCallKeys.length > 512) {
      _terminalCallKeys.remove(_terminalCallKeys.first);
    }
  }

  Future<void> _markConnectedCallTerminalRead(EventUpdate update) async {
    if (!_isTimelineUpdate(update)) return;
    final eventType = update.content['type'];
    if (eventType is! String) return;
    final content = update.content['content'];
    if (content is! Map) return;
    final callId = content['call_id'];
    if (callId is! String || callId.trim().isEmpty) return;

    final key = _callReadKey(update.roomID, callId);
    final active = _activeSession;
    if (active != null &&
        active.room.id == update.roomID &&
        active.callId == callId &&
        _state.status == VoiceCallStatus.connected) {
      _connectedCallReadKeys.add(key);
    }

    final callWasConnected = _connectedCallReadKeys.contains(key);
    if (!p2pCallTerminalShouldAutoRead(
      callWasConnected: callWasConnected,
      eventType: eventType,
      reason: _stringValue(content['reason']),
    )) {
      return;
    }

    _connectedCallReadKeys.remove(key);
    final room = _client?.getRoomById(update.roomID);
    if (room == null) return;
    markRoomLocallyRead(room);
    final eventId = _stringValue(update.content['event_id']);
    if (eventId == null) return;
    try {
      await room.setReadMarker(eventId, mRead: eventId);
    } catch (error) {
      debugPrint('p2p-call-mark-read failed: $error');
    }
  }

  void _recordCallIntent(EventUpdate update) {
    if (!_isTimelineUpdate(update)) return;
    if (update.content['type'] != p2pCallIntentEventType) return;
    final client = _client;
    if (client == null) return;
    final senderId = update.content['sender'];
    if (senderId is! String || senderId == client.userID) return;
    final content = update.content['content'];
    if (content is! Map) return;
    final callId = p2pCallIdFromIntentContent(content);
    if (callId == null) return;
    final targetUserId = content[_p2pCallIntentTargetKey];
    if (targetUserId is String && targetUserId != client.userID) return;
    final callType = productCallTypeFromIntentValue(
      content[_p2pCallIntentTypeKey],
    );
    if (callType == null) return;
    final createdAt =
        _eventDateTime(content[_p2pCallIntentCreatedAtKey]) ?? DateTime.now();
    final receivedAt =
        _eventDateTime(update.content['origin_server_ts']) ?? createdAt;

    _recentCallIntents.add(
      _RecentCallIntent(
        roomId: update.roomID,
        senderId: senderId,
        callId: callId,
        callType: callType,
        createdAt: createdAt,
        receivedAt: receivedAt,
      ),
    );
    _purgeExpiredCallIntents();

    final active = _activeSession;
    if (active == null ||
        active.isOutgoing ||
        active.room.id != update.roomID ||
        active.remoteUserId != senderId) {
      return;
    }
    unawaited(_applyIncomingIntentToActiveSession(active, callType, callId));
  }

  void _recordGroupCallInvite(EventUpdate update) {
    if (!_isTimelineUpdate(update)) return;
    if (update.content['type'] != p2pGroupCallInviteEventType) return;
    final client = _client;
    if (client == null) return;
    final currentUserId = client.userID;
    if (currentUserId == null || currentUserId.trim().isEmpty) return;
    final senderId = update.content['sender'];
    if (senderId is! String || senderId == currentUserId) return;
    final content = update.content['content'];
    if (content is! Map) return;
    if (!p2pGroupCallInviteTargetsUser(
      content: content,
      currentUserId: currentUserId,
    )) {
      return;
    }
    final callId = p2pCallIdFromIntentContent(content);
    if (callId == null) return;
    final callType = productCallTypeFromIntentValue(
      content[_p2pCallIntentTypeKey],
    );
    if (callType == null) return;
    final createdAt =
        _eventDateTime(content[_p2pCallIntentCreatedAtKey]) ?? DateTime.now();
    if (DateTime.now().difference(createdAt) >
        incomingCallStaleInviteThreshold) {
      return;
    }
    unawaited(_applyIncomingGroupCallInvite(
      roomId: update.roomID,
      callId: callId,
      callType: callType,
      createdByMxid: senderId,
      createdAt: createdAt,
      invitedUserIds: p2pGroupCallInviteesFromContent(content),
    ));
  }

  void _recordGroupCallParticipantState(EventUpdate update) {
    if (!_isTimelineUpdate(update)) return;
    final eventType = update.content['type'];
    if (eventType != p2pGroupCallJoinEventType &&
        eventType != p2pGroupCallLeaveEventType) {
      return;
    }
    final content = update.content['content'];
    if (content is! Map) return;
    final callId = p2pCallIdFromIntentContent(content);
    if (callId == null) return;
    final senderId = _stringValue(update.content['sender']);
    final userId =
        p2pGroupCallParticipantUserIdFromContent(content) ?? senderId;
    if (userId == null) return;
    _applyGroupParticipantState(
      roomId: update.roomID,
      callId: callId,
      userId: userId,
      isJoined: eventType == p2pGroupCallJoinEventType,
    );
  }

  Future<void> _applyIncomingGroupCallInvite({
    required String roomId,
    required String callId,
    required ProductCallType callType,
    required String createdByMxid,
    required DateTime createdAt,
    required List<String> invitedUserIds,
  }) async {
    if (_groupState.callId == callId &&
        _groupState.roomId == roomId &&
        _groupState.isActive) {
      return;
    }
    final room = _client?.getRoomById(roomId);
    if (room == null) return;
    final registered = await _registerIncomingAsCall(
      callId: callId,
      roomId: roomId,
      callType: callType,
      createdByMxid: createdByMxid,
      createdAt: createdAt,
      invitedUserIds: invitedUserIds,
    );
    if (registered != null && _asCallIsTerminal(registered)) return;
    _activeGroupAsCall = registered;
    final normalizedInvitees = _normalizedIds(invitedUserIds);
    final initiator = _groupCallParticipantInfo(
      room: room,
      userId: createdByMxid,
      isLocal: createdByMxid == room.client.userID,
    );
    _emitGroup(
      GroupCallUiState(
        status: GroupCallStatus.ringing,
        callType: callType,
        roomId: roomId,
        roomName: room.getLocalizedDisplayname(),
        callId: callId,
        createdByMxid: createdByMxid,
        initiator: initiator,
        invitedUserIds: normalizedInvitees,
        invitedParticipants: _invitedParticipantsForRoom(
          room: room,
          initiatorId: createdByMxid,
          invitedUserIds: normalizedInvitees,
        ),
        joinedUserIds: _normalizedIds([createdByMxid]),
        isIncoming: true,
        isCameraMuted: callType == ProductCallType.voice,
      ),
    );
  }

  Future<void> _applyIncomingIntentToActiveSession(
    CallSession active,
    ProductCallType callType,
    String callId,
  ) async {
    final canRing = await _ensureIncomingAsCall(active);
    if (_activeSession != active) return;
    if (!canRing) {
      await _discardStaleIncomingCall(active);
      await _resetActiveSession(emitIdle: true);
      return;
    }
    if (_state.callType != callType || _state.callId != callId) {
      _emit(_state.copyWith(callType: callType, callId: callId));
    }
  }

  Future<void> _handleCallHangupFallback(EventUpdate update) async {
    if (!_isTimelineUpdate(update)) return;
    final session = _activeSession;
    if (session == null) return;
    final callId = session.callId;
    if (_handledHangupCallIds.contains(callId)) return;
    if (!p2pCallHangupMatchesActiveCall(
      updateRoomId: update.roomID,
      eventContent: update.content,
      activeRoomId: session.room.id,
      activeCallId: callId,
    )) {
      return;
    }
    _handledHangupCallIds.add(callId);
    if (kDebugMode) {
      debugPrint('p2p-call-remote-hangup call_id=$callId');
    }
    await _reportAsCallEnded(
      _activeAsCall,
      reason: 'remote_hangup',
      connectedAt: _state.connectedAt,
    );
    _emit(_state.copyWith(status: VoiceCallStatus.ended));
    await session.cleanUp();
    await _resetActiveSession(emitIdle: false);
  }

  bool _isTimelineUpdate(EventUpdate update) {
    return update.type == EventUpdateType.timeline ||
        update.type == EventUpdateType.decryptedTimelineQueue;
  }

  String _callReadKey(String roomId, String callId) => '$roomId\u0000$callId';

  String? _stringValue(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  _RecentCallIntent? _recentCallIntentForSession(CallSession session) {
    _purgeExpiredCallIntents();
    final remoteUserId = session.remoteUserId;
    if (remoteUserId == null) return null;
    _RecentCallIntent? latest;
    for (final intent in _recentCallIntents) {
      if (intent.roomId != session.room.id || intent.senderId != remoteUserId) {
        continue;
      }
      if (latest == null || intent.receivedAt.isAfter(latest.receivedAt)) {
        latest = intent;
      }
    }
    return latest;
  }

  void _purgeExpiredCallIntents() {
    final threshold = DateTime.now().subtract(_p2pCallIntentTtl);
    _recentCallIntents.removeWhere(
      (intent) => intent.receivedAt.isBefore(threshold),
    );
  }

  DateTime? _eventDateTime(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  void _emitFailed(String message) {
    _emit(
      _state.copyWith(
        status: VoiceCallStatus.failed,
        error: message,
      ),
    );
  }

  void _emitGroupFailed({
    required String message,
    required String roomId,
    required String roomName,
    required ProductCallType callType,
  }) {
    _emitGroup(
      GroupCallUiState(
        status: GroupCallStatus.failed,
        callType: callType,
        roomId: roomId,
        roomName: roomName,
        error: message,
      ),
    );
  }

  void _emit(VoiceCallUiState state) {
    if (_disposed) return;
    _state = state;
    _syncCallRingtone();
    _stateController.add(state);
  }

  void _emitGroupSessionState(
    GroupCallSession groupCall, {
    ProductCallType? callType,
    String? roomName,
  }) {
    final state = _stateFromGroupSession(
      groupCall,
      callType: callType,
      roomName: roomName,
    );
    _emitGroup(state);
    _maybeAutoLeaveLastGroupMember(groupCall, state);
    _maybeRecoverStalledGroupMedia(groupCall, state);
  }

  void _maybeRecoverStalledGroupMedia(
    GroupCallSession groupCall,
    GroupCallUiState state,
  ) {
    final localStream = groupCall.backend.localUserMediaStream?.stream;
    final localMediaReady =
        (localStream?.getAudioTracks().isNotEmpty ?? false) ||
            (localStream?.getVideoTracks().isNotEmpty ?? false);
    final shouldRecover = shouldRecoverStalledGroupCallTransport(
      status: state.status,
      localUserId: groupCall.room.client.userID,
      joinedUserIds: state.joinedUserIds,
      localMediaReady: localMediaReady,
      remoteMediaUserIds: state.mediaUserIds
          .where((userId) => userId.trim() != groupCall.room.client.userID)
          .toList(growable: false),
      recoveryAlreadyAttempted: _groupMediaRecoveryAttempted,
      allowLocalJoiningRecovery: state.isIncoming,
    );
    if (!shouldRecover) {
      _groupMediaRecoveryTimer?.cancel();
      _groupMediaRecoveryTimer = null;
      return;
    }
    if (_groupMediaRecoveryTimer != null) return;
    final delay = state.status == GroupCallStatus.connected
        ? connectedGroupCallMediaRecoveryDelay
        : groupCallMediaRecoveryDelay;
    _groupMediaRecoveryTimer = Timer(delay, () {
      _groupMediaRecoveryTimer = null;
      unawaited(_recoverStalledGroupMedia(groupCall));
    });
  }

  Future<void> _recoverStalledGroupMedia(GroupCallSession groupCall) async {
    if (_activeGroupSession != groupCall) return;
    final snapshot = _groupState;
    final localStream = groupCall.backend.localUserMediaStream?.stream;
    final localMediaReady =
        (localStream?.getAudioTracks().isNotEmpty ?? false) ||
            (localStream?.getVideoTracks().isNotEmpty ?? false);
    if (!shouldRecoverStalledGroupCallTransport(
      status: snapshot.status,
      localUserId: groupCall.room.client.userID,
      joinedUserIds: snapshot.joinedUserIds,
      localMediaReady: localMediaReady,
      remoteMediaUserIds: snapshot.mediaUserIds
          .where((userId) => userId.trim() != groupCall.room.client.userID)
          .toList(growable: false),
      recoveryAlreadyAttempted: _groupMediaRecoveryAttempted,
      allowLocalJoiningRecovery: snapshot.isIncoming,
    )) {
      return;
    }
    _groupMediaRecoveryAttempted = true;
    if (kDebugMode) {
      debugPrint(
        'p2p-group-call-media-recovery product_call_id=${snapshot.callId} '
        'matrix_call_id=${groupCall.groupCallId} joined=${snapshot.joinedUserIds.join(",")}',
      );
    }
    try {
      await groupCall.leave();
    } catch (error) {
      debugPrint('p2p-group-call-media-recovery leave failed: $error');
    }
    if (_disposed || _groupState.callId != snapshot.callId) return;
    try {
      final room = groupCall.room;
      final callVoip = _voip ?? groupCall.voip;
      final matrixGroupCallId = productGroupCallIdForMatrix(
        productCallId: snapshot.callId,
        roomId: room.id,
      );
      final nextGroupCall = await callVoip.fetchOrCreateGroupCall(
        matrixGroupCallId,
        room,
        MeshBackend(),
        'm.call',
        'm.room',
      );
      _bindGroupSession(
        nextGroupCall,
        callType: snapshot.callType,
        roomName: snapshot.roomName ?? room.getLocalizedDisplayname(),
      );
      if (nextGroupCall.state == GroupCallState.localCallFeedUninitialized ||
          nextGroupCall.state == GroupCallState.localCallFeedInitialized) {
        final recoveryStream = snapshot.callType == ProductCallType.voice
            ? await _createAudioOnlyGroupStream(nextGroupCall)
            : await _createVideoGroupStream(nextGroupCall);
        await nextGroupCall.enter(stream: recoveryStream);
      }
      final currentUserId = room.client.userID?.trim();
      final productCallId = snapshot.callId?.trim();
      if (currentUserId != null &&
          currentUserId.isNotEmpty &&
          productCallId != null &&
          productCallId.isNotEmpty) {
        _applyGroupParticipantState(
          roomId: room.id,
          callId: productCallId,
          userId: currentUserId,
          isJoined: true,
        );
        unawaited(
          _sendProductGroupCallParticipantState(
            room: room,
            callId: productCallId,
            isJoined: true,
          ),
        );
      }
      _emitGroupSessionState(nextGroupCall);
    } catch (error) {
      debugPrint('p2p-group-call-media-recovery failed: $error');
    }
  }

  void _applyGroupParticipantState({
    required String roomId,
    required String callId,
    required String userId,
    required bool isJoined,
  }) {
    final normalizedCallId = callId.trim();
    final normalizedUserId = userId.trim();
    if (normalizedCallId.isEmpty || normalizedUserId.isEmpty) return;
    if (_groupState.roomId != roomId ||
        _groupState.callId != normalizedCallId) {
      return;
    }
    final current = _normalizedIds(_groupState.joinedUserIds);
    final next = isJoined
        ? _normalizedIds([...current, normalizedUserId])
        : current.where((id) => id != normalizedUserId).toList(growable: false);
    if (_listEquals(current, next)) return;

    final localUserId =
        _client?.userID?.trim() ?? _activeGroupSession?.room.client.userID;
    final nextStatus = groupCallStatusWithProductJoin(
      transportStatus: _groupState.status,
      localUserJoined: localUserId != null && next.contains(localUserId.trim()),
    );
    final connectedAt = nextGroupCallConnectedAt(
      previousStatus: _groupState.status,
      previousConnectedAt: _groupState.connectedAt,
      nextStatus: nextStatus,
      now: DateTime.now(),
      isIncoming: _groupState.isIncoming,
      localUserId: localUserId,
      joinedUserIds: next,
    );
    final nextState = _groupState.copyWith(
      status: nextStatus,
      joinedUserIds: next,
      participantCount: _groupState.effectiveParticipantCount,
      connectedAt: connectedAt,
    );
    _emitGroup(nextState);
    if (isJoined && next.length >= 2) {
      unawaited(_reportAsCallConnected(_activeGroupAsCall));
    }
    final session = _activeGroupSession;
    if (session != null) {
      _maybeAutoLeaveLastGroupMember(session, nextState);
    }
  }

  bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  void _maybeAutoLeaveLastGroupMember(
    GroupCallSession groupCall,
    GroupCallUiState state,
  ) {
    if (state.status != GroupCallStatus.connected) return;
    final count = groupCallAutoLeaveParticipantCount(state);
    if (count > _maxGroupParticipantsSeen) {
      _maxGroupParticipantsSeen = count;
    }
    if (_autoLeavingLastGroupMember) return;
    final localUserId = groupCall.room.client.userID?.trim();
    final localJoinedByMediaState = localUserId != null &&
        localUserId.isNotEmpty &&
        state.mediaUserIds.contains(localUserId);
    if (!shouldAutoLeaveLastGroupMember(
      status: state.status,
      maxParticipantsSeen: _maxGroupParticipantsSeen,
      currentParticipantCount: count,
      hasLocalParticipant:
          groupCall.hasLocalParticipant() || localJoinedByMediaState,
    )) {
      return;
    }
    _autoLeavingLastGroupMember = true;
    unawaited(
      leaveGroupCall().whenComplete(() {
        _autoLeavingLastGroupMember = false;
      }),
    );
  }

  void _emitGroup(GroupCallUiState state) {
    if (_disposed) return;
    _groupState = state;
    _syncCallRingtone();
    _groupStateController.add(state);
  }

  void _syncCallRingtone() {
    final shouldPlay = shouldPlayCallRingtone(
      voiceStatus: _state.status,
      voiceIsIncoming: _state.isIncoming,
      groupStatus: _groupState.status,
    );
    if (shouldPlay == _callRingtonePlaying) return;
    _callRingtonePlaying = shouldPlay;
    if (shouldPlay) {
      unawaited(
        _ringtonePlayer.playLoop().catchError((Object error) {
          debugPrint('call ringtone play failed: $error');
        }),
      );
    } else {
      unawaited(
        _ringtonePlayer.stop().catchError((Object error) {
          debugPrint('call ringtone stop failed: $error');
        }),
      );
    }
  }

  void _stopCallRingtone() {
    if (!_callRingtonePlaying) return;
    _callRingtonePlaying = false;
    unawaited(
      _ringtonePlayer.stop().catchError((Object error) {
        debugPrint('call ringtone stop failed: $error');
      }),
    );
  }

  Future<void> _disposeCallRingtone() async {
    try {
      if (_callRingtonePlaying) {
        _callRingtonePlaying = false;
        await _ringtonePlayer.stop();
      }
    } catch (error) {
      debugPrint('call ringtone stop failed: $error');
    } finally {
      await _ringtonePlayer.dispose();
    }
  }

  String _callErrorText(Object? error) {
    final mediaPermissionText =
        _state.isVideo ? '无法使用摄像头或麦克风，请检查权限' : '无法使用麦克风，请检查权限';
    if (error is CallError) {
      return switch (error.code) {
        CallErrorCode.userMediaFailed => mediaPermissionText,
        CallErrorCode.inviteTimeout => peerNoResponseMessage,
        CallErrorCode.userBusy => '对方正在通话中',
        _ => '通话失败：${error.code.reason}',
      };
    }
    if (error is CallErrorCode) {
      return switch (error) {
        CallErrorCode.userMediaFailed => mediaPermissionText,
        CallErrorCode.inviteTimeout => peerNoResponseMessage,
        CallErrorCode.userBusy => '对方正在通话中',
        _ => '通话失败：${error.reason}',
      };
    }
    return error?.toString() ?? '通话失败';
  }

  String _groupCallErrorText(Object? error) {
    final text = error?.toString().toLowerCase() ?? '';
    if (text.contains('not allowed') ||
        text.contains('power') ||
        text.contains('groupcall feature') ||
        text.contains('canjoingroupcall')) {
      return '该群暂不支持群通话';
    }
    if (text.contains('handshake') ||
        text.contains('connection') ||
        text.contains('socket') ||
        text.contains('timeout') ||
        text.contains('future not completed')) {
      return groupCallNetworkFailureMessage;
    }
    if (text.contains('getusermedia') || text.contains('user_media')) {
      return _groupState.isVideo ? '无法使用摄像头或麦克风，请检查权限' : '无法使用麦克风，请检查权限';
    }
    return error?.toString() ?? '群通话失败';
  }

  String _callStartErrorText(Object? error) {
    if (error is CallError || error is CallErrorCode) {
      return _callErrorText(error);
    }
    return outgoingCallStartFailureText(error);
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_disposeCallRingtone());
    unawaited(_callStateSub?.cancel());
    unawaited(_callEventSub?.cancel());
    unawaited(_streamAddSub?.cancel());
    unawaited(_streamRemoveSub?.cancel());
    unawaited(_groupStateSub?.cancel());
    unawaited(_groupEventSub?.cancel());
    unawaited(_groupFeedsSub?.cancel());
    unawaited(_clientEventSub?.cancel());
    _mediaDebugTimer?.cancel();
    _groupMediaDebugTimer?.cancel();
    _groupMediaRecoveryTimer?.cancel();
    _mediaHealthTimer?.cancel();
    _outgoingNoResponseTimer?.cancel();
    unawaited(_stateController.close());
    unawaited(_groupStateController.close());
  }
}

String _p2pCallMediaStatsSummary(
  List<rtc.StatsReport> reports, {
  required String mediaKind,
}) {
  final parts = <String>[];
  for (final report in reports) {
    final direction = switch (report.type) {
      'inbound-rtp' => 'inbound',
      'outbound-rtp' => 'outbound',
      _ => null,
    };
    if (direction == null || !_statsReportMatchesMedia(report, mediaKind)) {
      continue;
    }
    final values = report.values;
    final packets = direction == 'inbound'
        ? _statsValue(values, 'packetsReceived')
        : _statsValue(values, 'packetsSent');
    final bytes = direction == 'inbound'
        ? _statsValue(values, 'bytesReceived')
        : _statsValue(values, 'bytesSent');
    final metrics = <String>[
      'packets=${packets ?? '-'}',
      'bytes=${bytes ?? '-'}',
      ...switch (mediaKind) {
        'audio' => [
            if (_statsValue(values, 'audioLevel') != null)
              'level=${_statsValue(values, 'audioLevel')}',
            if (_statsValue(values, 'totalAudioEnergy') != null)
              'energy=${_statsValue(values, 'totalAudioEnergy')}',
          ],
        'video' => [
            if (_statsValue(values, 'framesEncoded') != null)
              'framesEncoded=${_statsValue(values, 'framesEncoded')}',
            if (_statsValue(values, 'framesDecoded') != null)
              'framesDecoded=${_statsValue(values, 'framesDecoded')}',
            if (_statsValue(values, 'framesPerSecond') != null)
              'fps=${_statsValue(values, 'framesPerSecond')}',
            if (_statsValue(values, 'frameWidth') != null &&
                _statsValue(values, 'frameHeight') != null)
              'size=${_statsValue(values, 'frameWidth')}x'
                  '${_statsValue(values, 'frameHeight')}',
          ],
        _ => const <String>[],
      },
    ];
    parts.add('$direction:${report.id} ${metrics.join(' ')}');
  }
  return parts.join(' ; ');
}

int p2pCallInboundMediaBytes(List<rtc.StatsReport> reports) {
  var bytes = 0;
  for (final report in reports) {
    if (report.type != 'inbound-rtp') continue;
    if (!_statsReportMatchesMedia(report, 'audio') &&
        !_statsReportMatchesMedia(report, 'video')) {
      continue;
    }
    final value = _statsValue(report.values, 'bytesReceived');
    if (value != null) bytes += int.tryParse(value) ?? 0;
  }
  return bytes;
}

bool _statsReportMatchesMedia(rtc.StatsReport report, String mediaKind) {
  for (final key in const ['kind', 'mediaType', 'trackKind']) {
    final value = report.values[key];
    if (value is String && value.toLowerCase() == mediaKind) return true;
  }
  return report.id.toLowerCase().contains(mediaKind);
}

String? _statsValue(Map<dynamic, dynamic> values, String key) {
  final value = values[key];
  if (value is num) return value.toString();
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

class _RecentCallIntent {
  const _RecentCallIntent({
    required this.roomId,
    required this.senderId,
    required this.callId,
    required this.callType,
    required this.createdAt,
    required this.receivedAt,
  });

  final String roomId;
  final String senderId;
  final String callId;
  final ProductCallType callType;
  final DateTime createdAt;
  final DateTime receivedAt;
}

class _MatrixWebRtcDelegate implements WebRTCDelegate {
  _MatrixWebRtcDelegate(this.controller);

  final MatrixVoiceCallController controller;

  @override
  rtc.MediaDevices get mediaDevices => webrtc.navigator.mediaDevices;

  @override
  Future<rtc.RTCPeerConnection> createPeerConnection(
    Map<String, dynamic> configuration, [
    Map<String, dynamic> constraints = const {},
  ]) {
    return webrtc.createPeerConnection(configuration, constraints);
  }

  @override
  Future<void> playRingtone() async {}

  @override
  Future<void> stopRingtone() async {}

  @override
  Future<void> handleNewCall(CallSession session) {
    return controller.handleNewCall(session);
  }

  @override
  Future<void> handleCallEnded(CallSession session) {
    return controller.handleCallEnded(session);
  }

  @override
  Future<void> handleMissedCall(CallSession session) {
    return controller.handleMissedCall(session);
  }

  @override
  Future<void> handleNewGroupCall(GroupCallSession groupCall) {
    return controller.handleNewGroupCall(groupCall);
  }

  @override
  Future<void> handleGroupCallEnded(GroupCallSession groupCall) {
    return controller.handleGroupCallEnded(groupCall);
  }

  @override
  bool get isWeb => kIsWeb;

  @override
  bool get canHandleNewCall =>
      controller.currentState.status != VoiceCallStatus.connected;

  @override
  EncryptionKeyProvider? get keyProvider => null;
}

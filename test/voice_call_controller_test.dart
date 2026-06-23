import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_call_session_store.dart';
import 'package:portal_app/data/as_client.dart';
import 'support/mock_as_client.dart';
import 'package:portal_app/presentation/call/voice_call_controller.dart';
import 'package:webrtc_interface/webrtc_interface.dart' as rtc;

void main() {
  test('matrix call states map to product voice call states', () {
    expect(
      voiceCallStatusForMatrix(
        CallState.kInviteSent,
        isIncoming: false,
      ),
      VoiceCallStatus.calling,
    );
    expect(
      voiceCallStatusForMatrix(
        CallState.kRinging,
        isIncoming: true,
      ),
      VoiceCallStatus.ringing,
    );
    expect(
      voiceCallStatusForMatrix(
        CallState.kConnecting,
        isIncoming: false,
      ),
      VoiceCallStatus.connecting,
    );
    expect(
      voiceCallStatusForMatrix(
        CallState.kConnected,
        isIncoming: false,
      ),
      VoiceCallStatus.connected,
    );
    expect(
      voiceCallStatusForMatrix(
        CallState.kEnded,
        isIncoming: false,
      ),
      VoiceCallStatus.ended,
    );
  });

  test('voice call status label reflects incoming and failed states', () {
    expect(
      voiceCallStatusLabel(
        const VoiceCallUiState(
          status: VoiceCallStatus.ringing,
          isIncoming: true,
        ),
      ),
      '邀请你语音通话',
    );
    expect(
      voiceCallStatusLabel(
        const VoiceCallUiState(
          status: VoiceCallStatus.ringing,
          isIncoming: false,
        ),
      ),
      '等待对方接听',
    );
    expect(
      voiceCallStatusLabel(
        const VoiceCallUiState(
          status: VoiceCallStatus.failed,
          error: '无法使用麦克风，请检查权限',
        ),
      ),
      '无法使用麦克风，请检查权限',
    );
  });

  test('video call status label reflects incoming and connected states', () {
    expect(
      voiceCallStatusLabel(
        const VoiceCallUiState(
          status: VoiceCallStatus.ringing,
          isIncoming: true,
          callType: ProductCallType.video,
        ),
      ),
      '邀请你视频通话',
    );
    expect(
      voiceCallStatusLabel(
        const VoiceCallUiState(
          status: VoiceCallStatus.connected,
          callType: ProductCallType.video,
        ),
      ),
      '视频通话中',
    );
  });

  test('product call type maps to Matrix call type', () {
    expect(matrixCallTypeForProduct(ProductCallType.voice), CallType.kVoice);
    expect(matrixCallTypeForProduct(ProductCallType.video), CallType.kVideo);
    expect(productCallTypeForMatrix(CallType.kVoice), ProductCallType.voice);
    expect(productCallTypeForMatrix(CallType.kVideo), ProductCallType.video);
  });

  test('product call intent overrides Matrix call type when present', () {
    expect(
      productCallTypeForMatrixAndIntent(
        matrixCallType: CallType.kVoice,
        recentIntentCallType: ProductCallType.video,
      ),
      ProductCallType.video,
    );
    expect(
      productCallTypeForMatrixAndIntent(
        matrixCallType: CallType.kVideo,
        recentIntentCallType: ProductCallType.voice,
      ),
      ProductCallType.voice,
    );
  });

  test('product call intent content is stable and compact', () {
    expect(
      p2pCallIntentContent(
        callId: 'as-call-1',
        callType: ProductCallType.video,
        targetUserId: '@lee:p2p-liyanan.com',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      ),
      {
        'call_id': 'as-call-1',
        'call_type': 'video',
        'target_user_id': '@lee:p2p-liyanan.com',
        'created_at_ms': 1000,
      },
    );
    expect(
      p2pCallIntentContent(
        callId: 'as-call-2',
        callType: ProductCallType.voice,
        targetUserId: '@lee:p2p-liyanan.com',
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
      )['call_type'],
      'voice',
    );
    expect(
      p2pCallIdFromIntentContent({
        'call_id': ' as-call-2 ',
      }),
      'as-call-2',
    );
    expect(productCallTypeFromIntentValue('video'), ProductCallType.video);
    expect(productCallTypeFromIntentValue('voice'), ProductCallType.voice);
    expect(productCallTypeFromIntentValue('unknown'), isNull);
  });

  test('voice call UI state preserves AS call id across copyWith', () {
    final state = const VoiceCallUiState(
      status: VoiceCallStatus.calling,
      callId: 'as-call-1',
      roomId: '!room:p2p-im.com',
    ).copyWith(status: VoiceCallStatus.connected);

    expect(state.callId, 'as-call-1');
    expect(state.status, VoiceCallStatus.connected);
  });

  test('outgoing call preflight blocks duplicate or unavailable starts', () {
    expect(
      outgoingCallPreflightError(
        serviceReady: false,
        stateActive: false,
        startInFlight: false,
        roomExists: true,
        hasPeerUserId: true,
      ),
      '通话服务还没有准备好',
    );
    expect(
      outgoingCallPreflightError(
        serviceReady: true,
        stateActive: true,
        startInFlight: false,
        roomExists: true,
        hasPeerUserId: true,
      ),
      '已有通话正在进行',
    );
    expect(
      outgoingCallPreflightError(
        serviceReady: true,
        stateActive: false,
        startInFlight: true,
        roomExists: true,
        hasPeerUserId: true,
      ),
      '正在发起通话',
    );
    expect(
      outgoingCallPreflightError(
        serviceReady: true,
        stateActive: false,
        startInFlight: false,
        roomExists: false,
        hasPeerUserId: true,
      ),
      '通话房间不存在',
    );
    expect(
      outgoingCallPreflightError(
        serviceReady: true,
        stateActive: false,
        startInFlight: false,
        roomExists: true,
        hasPeerUserId: false,
      ),
      '无法确定通话对象',
    );
    expect(
      outgoingCallPreflightError(
        serviceReady: true,
        stateActive: false,
        startInFlight: false,
        roomExists: true,
        hasPeerUserId: true,
      ),
      isNull,
    );
  });

  test('AS active call gate clears stale local active state', () {
    final decision = asActiveCallGateDecision(
      localStateActive: true,
      activeCalls: const [],
      activeLookupFailed: false,
    );

    expect(decision.canStart, isTrue);
    expect(decision.resetLocalActive, isTrue);
    expect(decision.error, isNull);
  });

  test('AS active call gate blocks when AS reports an active call', () {
    final active = AsCallSession(
      callId: 'as-call-active',
      roomId: '!room:p2p-im.com',
      roomType: 'direct',
      mediaType: asCallMediaTypeVoice,
      createdByMxid: '@owner:p2p-im.com',
      state: asCallStateRinging,
      createdAt: DateTime.utc(2026, 5, 31, 12, 0, 0),
    );

    final decision = asActiveCallGateDecision(
      localStateActive: false,
      activeCalls: [active],
      activeLookupFailed: false,
    );

    expect(decision.canStart, isFalse);
    expect(decision.resetLocalActive, isFalse);
    expect(decision.error, '已有通话正在进行');
  });

  test('AS active call gate ignores calls already ended locally', () {
    final stale = AsCallSession(
      callId: 'as-call-ended-locally',
      roomId: '!room:p2p-im.com',
      roomType: 'direct',
      mediaType: asCallMediaTypeVoice,
      createdByMxid: '@owner:p2p-im.com',
      state: asCallStateConnected,
      createdAt: DateTime.utc(2026, 5, 31, 12, 0, 0),
    );
    final active = AsCallSession(
      callId: 'as-call-still-active',
      roomId: stale.roomId,
      roomType: stale.roomType,
      mediaType: stale.mediaType,
      createdByMxid: stale.createdByMxid,
      state: asCallStateConnected,
      createdAt: stale.createdAt,
    );

    final mixedDecision = asActiveCallGateDecision(
      localStateActive: true,
      activeCalls: [stale, active],
      locallyTerminalCallIds: const {'as-call-ended-locally'},
      activeLookupFailed: false,
    );

    expect(mixedDecision.canStart, isFalse);
    expect(mixedDecision.resetLocalActive, isFalse);
    expect(mixedDecision.error, '已有通话正在进行');

    final staleOnlyDecision = asActiveCallGateDecision(
      localStateActive: true,
      activeCalls: [stale],
      locallyTerminalCallIds: const {'as-call-ended-locally'},
      activeLookupFailed: false,
    );

    expect(staleOnlyDecision.canStart, isTrue);
    expect(staleOnlyDecision.resetLocalActive, isTrue);
    expect(staleOnlyDecision.error, isNull);
  });

  test('AS active call gate keeps local block when AS lookup fails', () {
    final decision = asActiveCallGateDecision(
      localStateActive: true,
      activeCalls: null,
      activeLookupFailed: true,
    );

    expect(decision.canStart, isFalse);
    expect(decision.resetLocalActive, isFalse);
    expect(decision.error, '已有通话正在进行');
  });

  test('incoming call route waits for AS call id before opening UI', () {
    expect(
      p2pIncomingCallCanOpenRoute(
        const VoiceCallUiState(
          status: VoiceCallStatus.ringing,
          isIncoming: true,
          roomId: '!room:p2p-im.com',
        ),
        currentRouteRoomId: null,
      ),
      isFalse,
    );
    expect(
      p2pIncomingCallCanOpenRoute(
        const VoiceCallUiState(
          status: VoiceCallStatus.ringing,
          isIncoming: true,
          roomId: '!room:p2p-im.com',
          callId: 'as-call-1',
        ),
        currentRouteRoomId: null,
      ),
      isTrue,
    );
    expect(
      p2pIncomingCallCanOpenRoute(
        const VoiceCallUiState(
          status: VoiceCallStatus.ringing,
          isIncoming: true,
          roomId: '!room:p2p-im.com',
          callId: 'as-call-1',
        ),
        currentRouteRoomId: '!room:p2p-im.com',
      ),
      isFalse,
    );
  });

  test('outgoing call start errors use a stable network failure message', () {
    expect(
      outgoingCallStartFailureText(
        Exception('HandshakeException: Connection terminated during handshake'),
      ),
      '拨打失败，请检查你的网络或节点后重试',
    );
    expect(
      outgoingCallStartFailureText(Exception('Future not completed')),
      '拨打失败，请检查你的网络或节点后重试',
    );
    expect(
      outgoingCallStartFailureText(Exception('unknown')),
      '通话发起失败，请稍后重试',
    );
  });

  test('outgoing no-response timeout is exactly 1 minute', () {
    expect(outgoingCallNoResponseTimeout, const Duration(minutes: 1));
    expect(peerNoResponseMessage, '对方暂无响应，已结束拨打');
  });

  test('absolute no-response timeout can finish before Matrix session exists',
      () {
    final noSessionYet = outgoingNoResponseTimeoutDecision(
      activeAttemptMatches: true,
      matrixSessionExists: false,
      activeSessionMatches: false,
      callHasEnded: false,
      currentStatus: VoiceCallStatus.calling,
    );

    expect(noSessionYet.finalizeCall, isTrue);
    expect(noSessionYet.sendHangup, isFalse);
  });

  test('no-response timeout clears an already-ended Matrix session', () {
    final active = outgoingNoResponseTimeoutDecision(
      activeAttemptMatches: true,
      matrixSessionExists: true,
      activeSessionMatches: true,
      callHasEnded: false,
      currentStatus: VoiceCallStatus.calling,
    );
    expect(active.finalizeCall, isTrue);
    expect(active.sendHangup, isTrue);

    final alreadyEnded = outgoingNoResponseTimeoutDecision(
      activeAttemptMatches: true,
      matrixSessionExists: true,
      activeSessionMatches: true,
      callHasEnded: true,
      currentStatus: VoiceCallStatus.calling,
    );
    expect(alreadyEnded.finalizeCall, isTrue);
    expect(alreadyEnded.sendHangup, isFalse);

    final connected = outgoingNoResponseTimeoutDecision(
      activeAttemptMatches: true,
      matrixSessionExists: true,
      activeSessionMatches: true,
      callHasEnded: false,
      currentStatus: VoiceCallStatus.connected,
    );
    expect(connected.finalizeCall, isFalse);
    expect(connected.sendHangup, isFalse);
  });

  test('late Matrix invite result is ignored after timeout reset', () {
    expect(
      outgoingInviteResultShouldBind(
        activeAttemptMatches: false,
        currentStatus: VoiceCallStatus.failed,
      ),
      isFalse,
    );
    expect(
      outgoingInviteResultShouldBind(
        activeAttemptMatches: true,
        currentStatus: VoiceCallStatus.calling,
      ),
      isTrue,
    );
  });

  test('AS call reporter creates direct calls and records lifecycle', () async {
    final asClient = _RecordingAsClient();
    final reporter = AsCallStateReporter(asClient);

    final call = await reporter.createCall(
      roomId: '!direct:p2p-im.com',
      callType: ProductCallType.video,
    );
    await reporter.reportConnected(call);
    await reporter.reportEnded(
      call,
      reason: 'user_hangup',
      connectedAt: DateTime.utc(2026, 5, 31, 9, 0, 0),
      endedAt: DateTime.utc(2026, 5, 31, 9, 0, 42),
    );

    expect(asClient.created, [
      {
        'room_id': '!direct:p2p-im.com',
        'media_type': 'video',
      }
    ]);
    expect(asClient.events, [
      {
        'call_id': 'as-call-1',
        'event': 'connected',
        'reason': '',
        'duration_ms': 0,
      },
      {
        'call_id': 'as-call-1',
        'event': 'ended',
        'reason': 'user_hangup',
        'duration_ms': 42000,
      },
    ]);
  });

  test('AS call reporter records missed and failed calls once', () async {
    final asClient = _RecordingAsClient();
    final reporter = AsCallStateReporter(asClient);

    final missed = await reporter.createCall(
      roomId: '!direct:p2p-im.com',
      callType: ProductCallType.voice,
    );
    await reporter.reportMissed(missed, reason: 'invite_timeout');
    await reporter.reportMissed(missed, reason: 'invite_timeout');

    final failed = await reporter.createCall(
      roomId: '!direct:p2p-im.com',
      callType: ProductCallType.voice,
    );
    await reporter.reportFailed(failed, reason: 'network_error');

    expect(asClient.events, [
      {
        'call_id': 'as-call-1',
        'event': 'missed',
        'reason': 'invite_timeout',
        'duration_ms': 0,
      },
      {
        'call_id': 'as-call-2',
        'event': 'failed',
        'reason': 'network_error',
        'duration_ms': 0,
      },
    ]);
  });

  test('AS call reporter keeps local terminal state when AS update fails',
      () async {
    final asClient = _RecordingAsClient()..failNextEvent = true;
    final reporter = AsCallStateReporter(asClient);

    final call = await reporter.createCall(
      roomId: '!direct:p2p-im.com',
      callType: ProductCallType.voice,
    );

    await expectLater(
      reporter.reportEnded(
        call,
        reason: 'user_hangup',
        connectedAt: DateTime.utc(2026, 5, 31, 9, 0, 0),
        endedAt: DateTime.utc(2026, 5, 31, 9, 0, 3),
      ),
      throwsStateError,
    );

    expect(reporter.locallyTerminalCallIds, contains(call.callId));
    expect(reporter.terminalCallIds, isNot(contains(call.callId)));
  });

  test('AS call reporter clears stale connected calls when local state is idle',
      () async {
    final asClient = _RecordingAsClient();
    final reporter = AsCallStateReporter(asClient);

    final call = await reporter.createCall(
      roomId: '!direct:p2p-im.com',
      callType: ProductCallType.voice,
    );
    final connectedAt = DateTime.utc(2026, 5, 31, 9, 0, 0);
    final connected = call.copyWith(
      state: asCallStateConnected,
      answeredAt: connectedAt,
    );

    final remaining = await reporter.clearLocallyInactiveConnectedCalls([
      connected,
    ]);

    expect(remaining, isEmpty);
    expect(asClient.events, hasLength(1));
    expect(asClient.events.single['call_id'], call.callId);
    expect(asClient.events.single['event'], 'ended');
    expect(asClient.events.single['reason'], 'stale_local_inactive');
    expect(asClient.events.single['duration_ms'], greaterThanOrEqualTo(0));
    expect(reporter.locallyTerminalCallIds, contains(call.callId));
    expect(reporter.terminalCallIds, contains(call.callId));
  });

  test('connected call network state distinguishes unstable and interrupted',
      () {
    expect(
      connectedCallNetworkState(
        transportUnstable: false,
        remoteMediaStalled: false,
        unstableFor: Duration.zero,
      ),
      ConnectedCallNetworkState.stable,
    );
    expect(
      connectedCallNetworkState(
        transportUnstable: true,
        remoteMediaStalled: false,
        unstableFor: const Duration(seconds: 3),
      ),
      ConnectedCallNetworkState.unstable,
    );
    expect(
      connectedCallNetworkState(
        transportUnstable: false,
        remoteMediaStalled: true,
        unstableFor: connectedCallInterruptThreshold,
      ),
      ConnectedCallNetworkState.interrupted,
    );
  });

  test('connected call network prompts are product friendly', () {
    expect(
      connectedCallNetworkPrompt(ConnectedCallNetworkState.stable),
      isNull,
    );
    expect(
      connectedCallNetworkPrompt(ConnectedCallNetworkState.unstable),
      '网络不稳定',
    );
    expect(
      connectedCallNetworkPrompt(ConnectedCallNetworkState.interrupted),
      '通话中断',
    );
    expect(connectedCallInterruptThreshold, const Duration(seconds: 10));
    expect(
      callTransportLooksUnstable(
        peerConnectionState: 'RTCPeerConnectionStateDisconnected',
        iceConnectionState: 'RTCIceConnectionStateConnected',
      ),
      isTrue,
    );
    expect(
      callTransportLooksUnstable(
        peerConnectionState: 'RTCPeerConnectionStateConnected',
        iceConnectionState: 'RTCIceConnectionStateConnected',
      ),
      isFalse,
    );
  });

  test('call hangup matcher only accepts the current active call', () {
    final hangup = {
      'type': EventTypes.CallHangup,
      'content': {'call_id': 'call-1'},
    };

    expect(
      p2pCallHangupMatchesActiveCall(
        updateRoomId: '!room:p2p-im.com',
        eventContent: hangup,
        activeRoomId: '!room:p2p-im.com',
        activeCallId: 'call-1',
      ),
      isTrue,
    );
    expect(
      p2pCallHangupMatchesActiveCall(
        updateRoomId: '!other:p2p-im.com',
        eventContent: hangup,
        activeRoomId: '!room:p2p-im.com',
        activeCallId: 'call-1',
      ),
      isFalse,
    );
    expect(
      p2pCallHangupMatchesActiveCall(
        updateRoomId: '!room:p2p-im.com',
        eventContent: hangup,
        activeRoomId: '!room:p2p-im.com',
        activeCallId: 'call-2',
      ),
      isFalse,
    );
    expect(
      p2pCallHangupMatchesActiveCall(
        updateRoomId: '!room:p2p-im.com',
        eventContent: {
          'type': EventTypes.CallInvite,
          'content': {'call_id': 'call-1'},
        },
        activeRoomId: '!room:p2p-im.com',
        activeCallId: 'call-1',
      ),
      isFalse,
    );
  });

  test('only connected call terminal events auto clear call unread', () {
    expect(
      p2pCallTerminalShouldAutoRead(
        callWasConnected: true,
        eventType: EventTypes.CallHangup,
        reason: 'user_hangup',
      ),
      isTrue,
    );
    expect(
      p2pCallTerminalShouldAutoRead(
        callWasConnected: false,
        eventType: EventTypes.CallHangup,
        reason: 'user_hangup',
      ),
      isFalse,
    );
    expect(
      p2pCallTerminalShouldAutoRead(
        callWasConnected: true,
        eventType: EventTypes.CallHangup,
        reason: 'invite_timeout',
      ),
      isFalse,
    );
    expect(
      p2pCallTerminalShouldAutoRead(
        callWasConnected: true,
        eventType: EventTypes.CallReject,
        reason: null,
      ),
      isFalse,
    );
  });

  test('stale incoming calls do not ring after terminal events', () {
    expect(
      p2pIncomingCallShouldRing(
        callHasEnded: false,
        terminalEventKnown: false,
        callId: 'call-1',
        lastRoomEventType: EventTypes.Message,
        lastRoomEventContent: const {'body': 'hello'},
      ),
      isTrue,
    );
    expect(
      p2pIncomingCallShouldRing(
        callHasEnded: true,
        terminalEventKnown: false,
        callId: 'call-1',
      ),
      isFalse,
    );
    expect(
      p2pIncomingCallShouldRing(
        callHasEnded: false,
        terminalEventKnown: true,
        callId: 'call-1',
      ),
      isFalse,
    );
    expect(
      p2pIncomingCallShouldRing(
        callHasEnded: false,
        terminalEventKnown: false,
        callId: 'call-1',
        lastRoomEventType: EventTypes.CallHangup,
        lastRoomEventContent: const {'call_id': 'call-1'},
      ),
      isFalse,
    );
    expect(
      p2pIncomingCallShouldRing(
        callHasEnded: false,
        terminalEventKnown: false,
        callId: 'call-1',
        lastRoomEventType: EventTypes.CallReject,
        lastRoomEventContent: const {'call_id': 'call-2'},
      ),
      isTrue,
    );
    expect(
      p2pIncomingCallShouldRing(
        callHasEnded: false,
        terminalEventKnown: false,
        callId: '1780000000000abcdef',
        now: DateTime.fromMillisecondsSinceEpoch(
          1780000000000 + incomingCallStaleInviteThreshold.inMilliseconds + 1,
        ),
      ),
      isFalse,
    );
  });

  test('connected timer starts fresh for a new call', () {
    final oldConnectedAt = DateTime.utc(2026, 5, 30, 1);
    final newConnectedAt = DateTime.utc(2026, 5, 30, 2);

    expect(
      nextVoiceCallConnectedAt(
        previousStatus: VoiceCallStatus.ended,
        previousConnectedAt: oldConnectedAt,
        nextStatus: VoiceCallStatus.connected,
        now: newConnectedAt,
      ),
      newConnectedAt,
    );
    expect(
      nextVoiceCallConnectedAt(
        previousStatus: VoiceCallStatus.connected,
        previousConnectedAt: oldConnectedAt,
        nextStatus: VoiceCallStatus.connected,
        now: newConnectedAt,
      ),
      oldConnectedAt,
    );
    expect(
      nextVoiceCallConnectedAt(
        previousStatus: VoiceCallStatus.connected,
        previousConnectedAt: oldConnectedAt,
        nextStatus: VoiceCallStatus.ended,
        now: newConnectedAt,
      ),
      oldConnectedAt,
    );
    expect(
      nextVoiceCallConnectedAt(
        previousStatus: VoiceCallStatus.connected,
        previousConnectedAt: oldConnectedAt,
        nextStatus: VoiceCallStatus.failed,
        now: newConnectedAt,
      ),
      oldConnectedAt,
    );
  });

  test('speaker route toggle applies native route and updates state', () async {
    final audioRoute = _FakeCallAudioRoute();
    final controller = MatrixVoiceCallController(
      audioRoute: audioRoute,
      ringtonePlayer: _FakeCallRingtonePlayer(),
    );
    addTearDown(controller.dispose);

    expect(controller.currentState.isSpeakerOn, isTrue);

    await controller.setSpeakerOn(false);
    expect(audioRoute.values, [false]);
    expect(controller.currentState.isSpeakerOn, isFalse);

    await controller.setSpeakerOn(true);
    expect(audioRoute.values, [false, true]);
    expect(controller.currentState.isSpeakerOn, isTrue);
  });

  test('AS call reporter writes authoritative snapshots to local cache',
      () async {
    final asClient = _RecordingAsClient();
    final store = _MemoryAsCallSessionStore();
    final reporter = AsCallStateReporter(asClient, store: store);

    final call = await reporter.createCall(
      roomId: '!room:p2p-im.com',
      callType: ProductCallType.voice,
    );
    expect((await store.read(call.callId))?.state, asCallStateRinging);

    await reporter.reportConnected(call);
    expect((await store.read(call.callId))?.state, asCallStateConnected);

    await reporter.reportEnded(
      call,
      reason: 'hangup',
      connectedAt: DateTime.utc(2026, 5, 31, 8, 0, 0),
      endedAt: DateTime.utc(2026, 5, 31, 8, 0, 3),
    );

    final ended = await store.read(call.callId);
    expect(ended?.state, asCallStateEnded);
    expect(ended?.durationMs, 3000);
  });

  test('audio stats summary keeps only audio rtp counters', () {
    final summary = p2pCallAudioStatsSummary([
      rtcStats(
        'in-audio',
        'inbound-rtp',
        {
          'kind': 'audio',
          'packetsReceived': 12,
          'bytesReceived': 2400,
          'totalAudioEnergy': 0.42,
        },
      ),
      rtcStats(
        'out-audio',
        'outbound-rtp',
        {
          'mediaType': 'audio',
          'packetsSent': 7,
          'bytesSent': 1300,
          'totalAudioEnergy': 0.21,
        },
      ),
      rtcStats(
        'in-video',
        'inbound-rtp',
        {'kind': 'video', 'packetsReceived': 99},
      ),
    ]);

    expect(summary, contains('inbound:in-audio packets=12 bytes=2400'));
    expect(summary, contains('energy=0.42'));
    expect(summary, contains('outbound:out-audio packets=7 bytes=1300'));
    expect(summary, isNot(contains('in-video')));
  });

  test('video stats summary includes decoded frames and dimensions', () {
    final summary = p2pCallVideoStatsSummary([
      rtcStats(
        'in-video',
        'inbound-rtp',
        {
          'kind': 'video',
          'packetsReceived': 32,
          'bytesReceived': 64000,
          'framesDecoded': 12,
          'framesPerSecond': 24,
          'frameWidth': 640,
          'frameHeight': 360,
        },
      ),
      rtcStats(
        'out-video',
        'outbound-rtp',
        {
          'kind': 'video',
          'packetsSent': 28,
          'bytesSent': 56000,
          'framesEncoded': 10,
        },
      ),
    ]);

    expect(summary, contains('inbound:in-video packets=32 bytes=64000'));
    expect(summary, contains('framesDecoded=12'));
    expect(summary, contains('fps=24'));
    expect(summary, contains('size=640x360'));
    expect(summary, contains('outbound:out-video packets=28 bytes=56000'));
    expect(summary, contains('framesEncoded=10'));
  });

  test('inbound media bytes sums received audio and video only', () {
    expect(
      p2pCallInboundMediaBytes([
        rtcStats(
          'in-audio',
          'inbound-rtp',
          {'kind': 'audio', 'bytesReceived': 100},
        ),
        rtcStats(
          'in-video',
          'inbound-rtp',
          {'mediaType': 'video', 'bytesReceived': 200},
        ),
        rtcStats(
          'out-audio',
          'outbound-rtp',
          {'kind': 'audio', 'bytesSent': 300},
        ),
      ]),
      300,
    );
  });
}

rtc.StatsReport rtcStats(String id, String type, Map<String, Object> values) {
  return rtc.StatsReport(id, type, 0, values);
}

class _FakeCallAudioRoute implements CallAudioRoute {
  final values = <bool>[];

  @override
  Future<void> setSpeakerOn(bool enabled) async {
    values.add(enabled);
  }
}

class _FakeCallRingtonePlayer implements CallRingtonePlayer {
  int playLoopCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> playLoop() async {
    playLoopCalls += 1;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }
}

class _MemoryAsCallSessionStore implements AsCallSessionStore {
  final calls = <String, AsCallSession>{};

  @override
  Future<List<AsCallSession>> readAll() async {
    return calls.values.toList(growable: false);
  }

  @override
  Future<AsCallSession?> read(String callId) async {
    return calls[callId];
  }

  @override
  Future<List<AsCallSession>> readRoomStable(String roomId) async {
    final trimmed = roomId.trim();
    return calls.values
        .where((session) => session.roomId.trim() == trimmed)
        .toList(growable: false);
  }

  @override
  Future<void> upsert(AsCallSession session) async {
    calls[session.callId] = session;
  }

  @override
  Future<void> upsertAll(Iterable<AsCallSession> sessions) async {
    for (final session in sessions) {
      calls[session.callId] = session;
    }
  }
}

class _RecordingAsClient extends MockAsClient {
  final created = <Map<String, Object?>>[];
  final events = <Map<String, Object?>>[];
  final _calls = <String, AsCallSession>{};
  int _nextCall = 1;
  bool failNextEvent = false;

  @override
  Future<AsCallSession> createCall({
    required String roomId,
    required String mediaType,
    List<String> invitedUserIds = const [],
  }) async {
    created.add({
      'room_id': roomId,
      'media_type': mediaType,
    });
    final call = AsCallSession(
      callId: 'as-call-${_nextCall++}',
      roomId: roomId,
      roomType: roomId.contains('group') ? 'group' : 'direct',
      mediaType: mediaType,
      createdByMxid: '@owner:p2p-im.com',
      state: asCallStateRinging,
      createdAt: DateTime.utc(2026, 5, 31, 8, 0, 0),
    );
    _calls[call.callId] = call;
    return call;
  }

  @override
  Future<AsCallSession> updateCallEvent({
    required String callId,
    required String event,
    String reason = '',
    int durationMs = 0,
  }) async {
    if (failNextEvent) {
      failNextEvent = false;
      throw StateError('simulated AS call update failure');
    }
    events.add({
      'call_id': callId,
      'event': event,
      'reason': reason,
      'duration_ms': durationMs,
    });
    final current = _calls[callId]!;
    final next = current.copyWith(
      state: event,
      endReason: reason,
      durationMs: durationMs,
      answeredAt: event == asCallStateConnected ? DateTime.now().toUtc() : null,
      endedAt: event == asCallStateConnected ? null : DateTime.now().toUtc(),
    );
    _calls[callId] = next;
    return next;
  }
}

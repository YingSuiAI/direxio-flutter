import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'support/mock_as_client.dart';
import 'package:portal_app/presentation/call/voice_call_controller.dart';

void main() {
  test('group call status label reflects voice and video connected states', () {
    expect(
      groupCallStatusLabel(
        const GroupCallUiState(
          status: GroupCallStatus.connected,
          callType: ProductCallType.voice,
        ),
      ),
      '群语音通话中',
    );
    expect(
      groupCallStatusLabel(
        const GroupCallUiState(
          status: GroupCallStatus.connected,
          callType: ProductCallType.video,
        ),
      ),
      '群视频通话中',
    );
  });

  test('group call status label prefers explicit error text', () {
    expect(
      groupCallStatusLabel(
        const GroupCallUiState(
          status: GroupCallStatus.failed,
          callType: ProductCallType.video,
          error: '该群暂不支持群通话',
        ),
      ),
      '该群暂不支持群通话',
    );
  });

  test('group call preflight blocks unavailable starts clearly', () {
    expect(
      groupCallPreflightError(
        serviceReady: false,
        privateCallActive: false,
        groupCallActive: false,
        roomExists: true,
        canJoinGroupCall: true,
      ),
      '通话服务还没有准备好',
    );
    expect(
      groupCallPreflightError(
        serviceReady: true,
        privateCallActive: true,
        groupCallActive: false,
        roomExists: true,
        canJoinGroupCall: true,
      ),
      '已有通话正在进行',
    );
    expect(
      groupCallPreflightError(
        serviceReady: true,
        privateCallActive: false,
        groupCallActive: true,
        roomExists: true,
        canJoinGroupCall: true,
      ),
      '已有通话正在进行',
    );
    expect(
      groupCallPreflightError(
        serviceReady: true,
        privateCallActive: false,
        groupCallActive: false,
        roomExists: false,
        canJoinGroupCall: true,
      ),
      '群聊不存在',
    );
    expect(
      groupCallPreflightError(
        serviceReady: true,
        privateCallActive: false,
        groupCallActive: false,
        roomExists: true,
        canJoinGroupCall: false,
      ),
      '该群暂不支持群通话',
    );
    expect(
      groupCallPreflightError(
        serviceReady: true,
        privateCallActive: false,
        groupCallActive: false,
        roomExists: true,
        canJoinGroupCall: true,
      ),
      isNull,
    );
  });

  test('group call room lookup waits for Matrix rooms loading', () async {
    String? room;
    final loading = Completer<void>();
    final result = valueAfterLoading<String>(
      initialValue: room,
      loading: loading.future,
      readValue: () => room,
    );

    room = 'room-ready';
    loading.complete();

    expect(await result, 'room-ready');
  });

  test('group call connected timer starts only on connected transition', () {
    final now = DateTime.utc(2026, 5, 31, 1);
    final previousConnectedAt = now.subtract(const Duration(seconds: 30));

    expect(
      nextGroupCallConnectedAt(
        previousStatus: GroupCallStatus.joining,
        previousConnectedAt: null,
        nextStatus: GroupCallStatus.connected,
        now: now,
      ),
      now,
    );
    expect(
      nextGroupCallConnectedAt(
        previousStatus: GroupCallStatus.connected,
        previousConnectedAt: previousConnectedAt,
        nextStatus: GroupCallStatus.connected,
        now: now,
      ),
      previousConnectedAt,
    );
    expect(
      nextGroupCallConnectedAt(
        previousStatus: GroupCallStatus.connected,
        previousConnectedAt: previousConnectedAt,
        nextStatus: GroupCallStatus.ended,
        now: now,
      ),
      isNull,
    );
  });

  test('outgoing group call timer waits for first remote participant', () {
    final now = DateTime.utc(2026, 5, 31, 1);

    expect(
      nextGroupCallConnectedAt(
        previousStatus: GroupCallStatus.joining,
        previousConnectedAt: null,
        nextStatus: GroupCallStatus.connected,
        now: now,
        isIncoming: false,
        localUserId: '@owner:p2p-im.com',
        joinedUserIds: const ['@owner:p2p-im.com'],
      ),
      isNull,
    );

    expect(
      nextGroupCallConnectedAt(
        previousStatus: GroupCallStatus.connected,
        previousConnectedAt: null,
        nextStatus: GroupCallStatus.connected,
        now: now,
        isIncoming: false,
        localUserId: '@owner:p2p-im.com',
        joinedUserIds: const [
          '@owner:p2p-im.com',
          '@lee:p2p-liyanan.com',
        ],
      ),
      now,
    );
  });

  test('group call timer survives temporary joining during member churn', () {
    final connectedAt = DateTime.utc(2026, 5, 31, 1);
    final later = connectedAt.add(const Duration(seconds: 42));
    final recovered = connectedAt.add(const Duration(seconds: 45));

    expect(
      nextGroupCallConnectedAt(
        previousStatus: GroupCallStatus.connected,
        previousConnectedAt: connectedAt,
        nextStatus: GroupCallStatus.joining,
        now: later,
        isIncoming: false,
        localUserId: '@owner:p2p-im.com',
        joinedUserIds: const [
          '@owner:p2p-im.com',
          '@lee:p2p-liyanan.com',
        ],
      ),
      connectedAt,
    );

    expect(
      nextGroupCallConnectedAt(
        previousStatus: GroupCallStatus.joining,
        previousConnectedAt: connectedAt,
        nextStatus: GroupCallStatus.connected,
        now: recovered,
        isIncoming: false,
        localUserId: '@owner:p2p-im.com',
        joinedUserIds: const [
          '@owner:p2p-im.com',
          '@lee:p2p-liyanan.com',
        ],
      ),
      connectedAt,
    );
  });

  test('incoming group call timer starts after local join', () {
    final now = DateTime.utc(2026, 5, 31, 1);

    expect(
      nextGroupCallConnectedAt(
        previousStatus: GroupCallStatus.joining,
        previousConnectedAt: null,
        nextStatus: GroupCallStatus.connected,
        now: now,
        isIncoming: true,
        localUserId: '@owner:p2p-im.com',
        joinedUserIds: const [
          '@lee:p2p-liyanan.com',
          '@owner:p2p-im.com',
        ],
      ),
      now,
    );
  });

  test('group call status keeps product join below media connected', () {
    expect(
      groupCallStatusWithProductJoin(
        transportStatus: GroupCallStatus.joining,
        localUserJoined: true,
      ),
      GroupCallStatus.joining,
    );
    expect(
      groupCallStatusWithProductJoin(
        transportStatus: GroupCallStatus.idle,
        localUserJoined: true,
      ),
      GroupCallStatus.joining,
    );
    expect(
      groupCallStatusWithProductJoin(
        transportStatus: GroupCallStatus.ringing,
        localUserJoined: false,
      ),
      GroupCallStatus.ringing,
    );
  });

  test('group call media recovery is owned by the first participant only', () {
    expect(
      shouldRecoverStalledGroupCallTransport(
        status: GroupCallStatus.joining,
        localUserId: '@owner:p2p-im-test.com',
        joinedUserIds: const [
          '@owner:p2p-im-test.com',
          '@owner:p2p-im.com',
          '@owner:p2p-liyanan.com',
        ],
        localMediaReady: true,
        remoteMediaUserIds: const [],
        recoveryAlreadyAttempted: false,
      ),
      isTrue,
    );
    expect(
      shouldRecoverStalledGroupCallTransport(
        status: GroupCallStatus.joining,
        localUserId: '@owner:p2p-liyanan.com',
        joinedUserIds: const [
          '@owner:p2p-im-test.com',
          '@owner:p2p-im.com',
          '@owner:p2p-liyanan.com',
        ],
        localMediaReady: true,
        remoteMediaUserIds: const [],
        recoveryAlreadyAttempted: false,
      ),
      isFalse,
    );
  });

  test('late invited group member can recover missing remote media', () {
    expect(
      shouldRecoverStalledGroupCallTransport(
        status: GroupCallStatus.joining,
        localUserId: '@owner:p2p-liyanan.com',
        joinedUserIds: const [
          '@owner:p2p-im-test.com',
          '@owner:p2p-im.com',
          '@owner:p2p-liyanan.com',
        ],
        localMediaReady: true,
        remoteMediaUserIds: const [],
        recoveryAlreadyAttempted: false,
        allowLocalJoiningRecovery: true,
      ),
      isTrue,
    );
  });

  test('group call media recovery does not run after media or prior retry', () {
    expect(
      shouldRecoverStalledGroupCallTransport(
        status: GroupCallStatus.joining,
        localUserId: '@owner:p2p-im-test.com',
        joinedUserIds: const [
          '@owner:p2p-im-test.com',
          '@owner:p2p-im.com',
        ],
        localMediaReady: true,
        remoteMediaUserIds: const ['@owner:p2p-im.com'],
        recoveryAlreadyAttempted: false,
      ),
      isFalse,
    );
    expect(
      shouldRecoverStalledGroupCallTransport(
        status: GroupCallStatus.joining,
        localUserId: '@owner:p2p-im-test.com',
        joinedUserIds: const [
          '@owner:p2p-im-test.com',
          '@owner:p2p-im.com',
        ],
        localMediaReady: true,
        remoteMediaUserIds: const [],
        recoveryAlreadyAttempted: true,
      ),
      isFalse,
    );
  });

  test('media gate requires local and remote media before connected', () {
    expect(
      groupCallStatusWithObservedMedia(
        transportStatus: GroupCallStatus.connected,
        localUserJoined: true,
        localMediaReady: true,
        remoteMediaUserIds: const [],
      ),
      GroupCallStatus.joining,
    );
    expect(
      groupCallStatusWithObservedMedia(
        transportStatus: GroupCallStatus.connected,
        localUserJoined: true,
        localMediaReady: false,
        remoteMediaUserIds: const ['@lee:p2p-liyanan.com'],
      ),
      GroupCallStatus.joining,
    );
    expect(
      groupCallStatusWithObservedMedia(
        transportStatus: GroupCallStatus.connected,
        localUserJoined: true,
        localMediaReady: true,
        remoteMediaUserIds: const ['@lee:p2p-liyanan.com'],
      ),
      GroupCallStatus.connected,
    );
  });

  test('connected group call stays connected while media recovers', () {
    expect(
      groupCallStatusWithObservedMedia(
        transportStatus: GroupCallStatus.connected,
        localUserJoined: true,
        localMediaReady: false,
        remoteMediaUserIds: const [],
        wasConnected: true,
      ),
      GroupCallStatus.connected,
    );
  });

  test('connected product group call ignores stale Matrix ended state', () {
    expect(
      groupCallStatusWithObservedMedia(
        transportStatus: GroupCallStatus.ended,
        localUserJoined: false,
        localMediaReady: false,
        remoteMediaUserIds: const [],
        wasConnected: true,
      ),
      GroupCallStatus.connected,
    );
  });

  test('connected group call recovers after remote media is stranded', () {
    expect(
      shouldRecoverStalledGroupCallTransport(
        status: GroupCallStatus.connected,
        localUserId: '@owner:p2p-im-test.com',
        joinedUserIds: const [
          '@owner:p2p-im-test.com',
          '@owner:p2p-im.com',
        ],
        localMediaReady: false,
        remoteMediaUserIds: const [],
        recoveryAlreadyAttempted: false,
      ),
      isTrue,
    );
    expect(
      shouldRecoverStalledGroupCallTransport(
        status: GroupCallStatus.connected,
        localUserId: '@owner:p2p-im.com',
        joinedUserIds: const [
          '@owner:p2p-im-test.com',
          '@owner:p2p-im.com',
        ],
        localMediaReady: false,
        remoteMediaUserIds: const [],
        recoveryAlreadyAttempted: false,
      ),
      isTrue,
    );
  });

  test('initial joining media recovery remains single owner only', () {
    expect(
      shouldRecoverStalledGroupCallTransport(
        status: GroupCallStatus.joining,
        localUserId: '@owner:p2p-im-test.com',
        joinedUserIds: const [
          '@owner:p2p-im-test.com',
          '@owner:p2p-im.com',
        ],
        localMediaReady: true,
        remoteMediaUserIds: const [],
        recoveryAlreadyAttempted: false,
      ),
      isTrue,
    );
    expect(
      shouldRecoverStalledGroupCallTransport(
        status: GroupCallStatus.joining,
        localUserId: '@owner:p2p-im.com',
        joinedUserIds: const [
          '@owner:p2p-im-test.com',
          '@owner:p2p-im.com',
        ],
        localMediaReady: true,
        remoteMediaUserIds: const [],
        recoveryAlreadyAttempted: false,
      ),
      isFalse,
    );
  });

  test('connected group call stays connected after local media uninitializes',
      () {
    expect(
      groupCallStatusWithObservedMedia(
        transportStatus: GroupCallStatus.idle,
        localUserJoined: true,
        localMediaReady: false,
        remoteMediaUserIds: const [],
        wasConnected: true,
      ),
      GroupCallStatus.connected,
    );
  });

  test('product joined state keeps stale matrix ended as joining only', () {
    expect(
      groupCallStatusWithProductJoin(
        transportStatus: GroupCallStatus.ended,
        localUserJoined: true,
      ),
      GroupCallStatus.joining,
    );
    expect(
      groupCallStatusWithProductJoin(
        transportStatus: GroupCallStatus.ended,
        localUserJoined: false,
      ),
      GroupCallStatus.ended,
    );
  });

  test('incoming group invite publishes local join before matrix enter', () {
    expect(
      shouldPublishLocalGroupJoinBeforeMatrixEnter(
        joinExistingInvite: true,
        productCallId: 'as-group-call-1',
        localUserId: '@owner:p2p-im.com',
      ),
      isTrue,
    );
    expect(
      shouldPublishLocalGroupJoinBeforeMatrixEnter(
        joinExistingInvite: false,
        productCallId: 'as-group-call-1',
        localUserId: '@owner:p2p-im.com',
      ),
      isFalse,
    );
    expect(
      shouldPublishLocalGroupJoinBeforeMatrixEnter(
        joinExistingInvite: true,
        productCallId: null,
        localUserId: '@owner:p2p-im.com',
      ),
      isFalse,
    );
  });

  test('matrix ended is ignored while product state says local joined', () {
    expect(
      shouldIgnoreMatrixGroupEndedForProductState(localProductJoined: true),
      isTrue,
    );
    expect(
      shouldIgnoreMatrixGroupEndedForProductState(localProductJoined: false),
      isFalse,
    );
  });

  test('group call participant count prefers real participant identities', () {
    const state = GroupCallUiState(
      status: GroupCallStatus.connected,
      participantCount: 1,
      participants: [
        GroupCallParticipantInfo(
          userId: '@owner:p2p-im.com',
          displayName: 'Yanan',
          isLocal: true,
        ),
        GroupCallParticipantInfo(
          userId: '@lee:p2p-liyanan.com',
          displayName: 'Lee',
        ),
      ],
    );

    expect(state.effectiveParticipantCount, 2);
  });

  test('group call participant count prefers media-connected identities', () {
    const state = GroupCallUiState(
      status: GroupCallStatus.connected,
      participantCount: 1,
      participants: [
        GroupCallParticipantInfo(
          userId: '@owner:p2p-im.com',
          displayName: 'Yanan',
          isLocal: true,
        ),
      ],
      joinedUserIds: [
        '@owner:p2p-im.com',
        '@lee:p2p-liyanan.com',
        '@owner:p2p-im.com',
      ],
      mediaUserIds: [
        '@owner:p2p-im.com',
        '@lee:p2p-liyanan.com',
      ],
    );

    expect(state.effectiveParticipantCount, 2);
  });

  test('product joined identities do not inflate media participant count', () {
    const state = GroupCallUiState(
      status: GroupCallStatus.joining,
      participantCount: 1,
      participants: [
        GroupCallParticipantInfo(
          userId: '@owner:p2p-im.com',
          displayName: 'Yanan',
          isLocal: true,
        ),
      ],
      joinedUserIds: [
        '@owner:p2p-im.com',
        '@lee:p2p-liyanan.com',
      ],
      mediaUserIds: [
        '@owner:p2p-im.com',
      ],
    );

    expect(state.effectiveParticipantCount, 1);
  });

  test('group call auto leave count ignores transient remote media drops', () {
    const state = GroupCallUiState(
      status: GroupCallStatus.connected,
      participantCount: 1,
      participants: [
        GroupCallParticipantInfo(
          userId: '@owner:p2p-im-test.com',
          displayName: 'Test Node',
          isLocal: true,
        ),
      ],
      joinedUserIds: [
        '@owner:p2p-im-test.com',
        '@owner:p2p-liyanan.com',
        '@owner:p2p-im.com',
      ],
      mediaUserIds: [
        '@owner:p2p-im-test.com',
      ],
    );

    expect(state.effectiveParticipantCount, 1);
    expect(groupCallAutoLeaveParticipantCount(state), 3);
  });

  test('group call auto leave count keeps remaining media members after leave',
      () {
    const state = GroupCallUiState(
      status: GroupCallStatus.connected,
      participantCount: 1,
      participants: [
        GroupCallParticipantInfo(
          userId: '@owner:p2p-im-test.com',
          displayName: 'Test Node',
          isLocal: true,
        ),
      ],
      joinedUserIds: [
        '@owner:p2p-im-test.com',
      ],
      mediaUserIds: [
        '@owner:p2p-im-test.com',
        '@owner:p2p-liyanan.com',
      ],
    );

    expect(groupCallAutoLeaveParticipantCount(state), 2);
    expect(
      shouldAutoLeaveLastGroupMember(
        status: state.status,
        maxParticipantsSeen: 3,
        currentParticipantCount: groupCallAutoLeaveParticipantCount(state),
        hasLocalParticipant: true,
      ),
      isFalse,
    );
  });

  test('group call auto leave ignores stale Matrix participants after leaves',
      () {
    const state = GroupCallUiState(
      status: GroupCallStatus.connected,
      participantCount: 1,
      participants: [
        GroupCallParticipantInfo(
          userId: '@owner:p2p-im-test.com',
          displayName: 'Test Node',
          isLocal: true,
        ),
        GroupCallParticipantInfo(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'Yanan',
        ),
        GroupCallParticipantInfo(
          userId: '@owner:p2p-im.com',
          displayName: 'Lee',
        ),
      ],
      joinedUserIds: [
        '@owner:p2p-im-test.com',
      ],
      mediaUserIds: [
        '@owner:p2p-im-test.com',
      ],
    );

    expect(groupCallAutoLeaveParticipantCount(state), 1);
    expect(
      shouldAutoLeaveLastGroupMember(
        status: state.status,
        maxParticipantsSeen: 3,
        currentParticipantCount: groupCallAutoLeaveParticipantCount(state),
        hasLocalParticipant: true,
      ),
      isTrue,
    );
  });

  test('group call local leave only finishes call when no peers remain', () {
    expect(
      shouldReportGroupCallEndedAfterLocalLeave(participantCountBeforeLeave: 3),
      isFalse,
    );
    expect(
      shouldReportGroupCallEndedAfterLocalLeave(participantCountBeforeLeave: 2),
      isFalse,
    );
    expect(
      shouldReportGroupCallEndedAfterLocalLeave(participantCountBeforeLeave: 1),
      isTrue,
    );
    expect(
      shouldReportGroupCallEndedFromMatrixEnd(
        localProductJoined: true,
        participantCountBeforeEnd: 3,
      ),
      isFalse,
    );
    expect(
      shouldReportGroupCallEndedFromMatrixEnd(
        localProductJoined: false,
        participantCountBeforeEnd: 3,
      ),
      isFalse,
    );
    expect(
      shouldReportGroupCallEndedFromMatrixEnd(
        localProductJoined: false,
        participantCountBeforeEnd: 2,
      ),
      isFalse,
    );
    expect(
      shouldReportGroupCallEndedFromMatrixEnd(
        localProductJoined: false,
        participantCountBeforeEnd: 1,
      ),
      isFalse,
    );
  });

  test('group call state preserves expected invitation participants', () {
    const initiator = GroupCallParticipantInfo(
      userId: '@lee:p2p-liyanan.com',
      displayName: 'Lee',
    );
    const invitee = GroupCallParticipantInfo(
      userId: '@owner:p2p-im.com',
      displayName: 'Yanan',
      isLocal: true,
    );

    const state = GroupCallUiState(
      status: GroupCallStatus.ringing,
      createdByMxid: '@lee:p2p-liyanan.com',
      initiator: initiator,
      invitedParticipants: [initiator, invitee],
    );

    expect(state.initiator, initiator);
    expect(state.invitedParticipants, [initiator, invitee]);
    final next = state.copyWith(status: GroupCallStatus.joining);
    expect(next.initiator, initiator);
    expect(next.invitedParticipants, [initiator, invitee]);
  });

  test('group call last local member leaves only after real multi-member call',
      () {
    expect(
      shouldAutoLeaveLastGroupMember(
        status: GroupCallStatus.connected,
        maxParticipantsSeen: 2,
        currentParticipantCount: 1,
        hasLocalParticipant: true,
      ),
      isTrue,
    );
    expect(
      shouldAutoLeaveLastGroupMember(
        status: GroupCallStatus.connected,
        maxParticipantsSeen: 1,
        currentParticipantCount: 1,
        hasLocalParticipant: true,
      ),
      isFalse,
    );
    expect(
      shouldAutoLeaveLastGroupMember(
        status: GroupCallStatus.connected,
        maxParticipantsSeen: 3,
        currentParticipantCount: 1,
        hasLocalParticipant: false,
      ),
      isFalse,
    );
    expect(
      shouldAutoLeaveLastGroupMember(
        status: GroupCallStatus.joining,
        maxParticipantsSeen: 3,
        currentParticipantCount: 1,
        hasLocalParticipant: true,
      ),
      isFalse,
    );
  });

  test(
      'incoming invite with existing session must still enter when local not joined',
      () {
    expect(
      shouldShortCircuitGroupCallStart(
        activeSameRoom: true,
        stateActive: true,
        joinExistingInvite: true,
        localAlreadyJoined: false,
      ),
      isFalse,
    );
    expect(
      shouldShortCircuitGroupCallStart(
        activeSameRoom: true,
        stateActive: true,
        joinExistingInvite: true,
        localAlreadyJoined: true,
      ),
      isTrue,
    );
    expect(
      shouldShortCircuitGroupCallStart(
        activeSameRoom: true,
        stateActive: true,
        joinExistingInvite: false,
        localAlreadyJoined: false,
      ),
      isTrue,
    );
  });

  test('product join alone does not mean local group media joined', () {
    expect(
      shouldTreatLocalGroupCallMediaJoined(
        transportStatus: GroupCallStatus.joining,
        localMediaReady: true,
      ),
      isFalse,
    );
    expect(
      shouldTreatLocalGroupCallMediaJoined(
        transportStatus: GroupCallStatus.connected,
        localMediaReady: false,
      ),
      isFalse,
    );
    expect(
      shouldTreatLocalGroupCallMediaJoined(
        transportStatus: GroupCallStatus.connected,
        localMediaReady: true,
      ),
      isTrue,
    );
  });

  test(
      'same-room uninitialized matrix group session cannot replace joined media',
      () {
    expect(
      shouldIgnoreIncomingMatrixGroupCallSession(
        sameRoom: true,
        sameProductCall: true,
        activeLocalMediaJoined: true,
        incomingTransportStatus: GroupCallStatus.idle,
      ),
      isTrue,
    );
    expect(
      shouldIgnoreIncomingMatrixGroupCallSession(
        sameRoom: true,
        sameProductCall: true,
        activeLocalMediaJoined: true,
        incomingTransportStatus: GroupCallStatus.joining,
      ),
      isFalse,
    );
    expect(
      shouldIgnoreIncomingMatrixGroupCallSession(
        sameRoom: false,
        sameProductCall: false,
        activeLocalMediaJoined: true,
        incomingTransportStatus: GroupCallStatus.idle,
      ),
      isFalse,
    );
    expect(
      shouldIgnoreIncomingMatrixGroupCallSession(
        sameRoom: true,
        sameProductCall: true,
        activeLocalMediaJoined: false,
        incomingTransportStatus: GroupCallStatus.idle,
      ),
      isFalse,
    );
    expect(
      shouldIgnoreIncomingMatrixGroupCallSession(
        sameRoom: true,
        sameProductCall: false,
        activeLocalMediaJoined: false,
        incomingTransportStatus: GroupCallStatus.joining,
      ),
      isTrue,
    );
  });

  test('local group leave emits a terminal state for the call page', () {
    final state = groupCallStateAfterLocalLeave(
      const GroupCallUiState(
        status: GroupCallStatus.connected,
        roomId: '!group:p2p-im.com',
        callId: 'as-group-call-1',
        participantCount: 1,
        joinedUserIds: ['@owner:p2p-im.com'],
        participants: [
          GroupCallParticipantInfo(
            userId: '@owner:p2p-im.com',
            displayName: 'Yanan',
            isLocal: true,
          ),
        ],
      ),
    );

    expect(state.status, GroupCallStatus.ended);
    expect(state.joinedUserIds, isEmpty);
    expect(state.participants, isEmpty);
    expect(state.effectiveParticipantCount, 0);
  });

  test('AS call reporter creates group call session with product media type',
      () async {
    final asClient = _RecordingAsClient();
    final reporter = AsCallStateReporter(asClient);

    final call = await reporter.createCall(
      roomId: '!group:p2p-im.com',
      callType: ProductCallType.video,
      invitedUserIds: const ['@alice:p2p-liyanan.com'],
    );
    await reporter.reportConnected(call);
    await reporter.reportEnded(
      call,
      reason: 'group_leave',
      connectedAt: DateTime.utc(2026, 5, 31, 9, 0, 0),
      endedAt: DateTime.utc(2026, 5, 31, 9, 1, 0),
    );

    expect(asClient.created, [
      {
        'room_id': '!group:p2p-im.com',
        'media_type': 'video',
        'invited_user_ids': ['@alice:p2p-liyanan.com'],
      }
    ]);
    expect(asClient.events, [
      {
        'call_id': 'as-group-call-1',
        'event': 'connected',
        'reason': '',
        'duration_ms': 0,
      },
      {
        'call_id': 'as-group-call-1',
        'event': 'ended',
        'reason': 'group_leave',
        'duration_ms': 60000,
      },
    ]);
  });

  test('group call invite payload targets selected members only', () {
    final content = p2pGroupCallInviteContent(
      callId: 'call_group_1',
      callType: ProductCallType.video,
      invitedUserIds: const [
        '@alice:p2p-liyanan.com',
        '@alice:p2p-liyanan.com',
        ' @bob:p2p-test.com ',
      ],
      createdAt: DateTime.fromMillisecondsSinceEpoch(1780230600000),
    );

    expect(p2pCallIdFromIntentContent(content), 'call_group_1');
    expect(productCallTypeFromIntentValue(content['call_type']),
        ProductCallType.video);
    expect(p2pGroupCallInviteesFromContent(content), [
      '@alice:p2p-liyanan.com',
      '@bob:p2p-test.com',
    ]);
    expect(
      p2pGroupCallInviteTargetsUser(
        content: content,
        currentUserId: '@alice:p2p-liyanan.com',
      ),
      isTrue,
    );
    expect(
      p2pGroupCallInviteTargetsUser(
        content: content,
        currentUserId: '@carol:p2p-test.com',
      ),
      isFalse,
    );
  });

  test('incoming group call route opens only for ringing invite', () {
    expect(
      p2pIncomingGroupCallCanOpenRoute(
        const GroupCallUiState(
          status: GroupCallStatus.ringing,
          roomId: '!group:p2p-im.com',
          callId: 'call_group_1',
          isIncoming: true,
        ),
        currentRouteRoomId: null,
      ),
      isTrue,
    );
    expect(
      p2pIncomingGroupCallCanOpenRoute(
        const GroupCallUiState(
          status: GroupCallStatus.connected,
          roomId: '!group:p2p-im.com',
          callId: 'call_group_1',
          isIncoming: true,
        ),
        currentRouteRoomId: null,
      ),
      isFalse,
    );
  });

  test('Matrix group call id is isolated by AS product call id', () {
    final source = File('lib/presentation/call/voice_call_controller.dart')
        .readAsStringSync();
    final controllerStart = source.indexOf('class MatrixVoiceCallController');
    final methodStart = source.indexOf(
      'Future<void> startOrJoinGroupCall({',
      controllerStart,
    );
    final methodEnd =
        source.indexOf('@override\n  Future<void> leaveGroupCall', methodStart);
    final body = source.substring(methodStart, methodEnd);

    final fetchIndex = body.indexOf('fetchOrCreateGroupCall(');
    final enterIndex = body.indexOf('await resolvedGroupCall.enter(');
    final createAsIndex = body.indexOf('await _createAsCall(');
    final inviteIndex = body.indexOf('await _sendProductGroupCallInvite(');

    expect(body,
        contains('final matrixGroupCallId = productGroupCallIdForMatrix('));
    expect(fetchIndex, isNonNegative);
    expect(createAsIndex, lessThan(fetchIndex));
    expect(enterIndex, greaterThan(fetchIndex));
    expect(inviteIndex, greaterThan(enterIndex));
    expect(
        body,
        isNot(contains(
            'fetchOrCreateGroupCall(\n                  callRoom.id,')));
  });

  test('group call media recovery reuses product call id transport', () {
    final source = File('lib/presentation/call/voice_call_controller.dart')
        .readAsStringSync();
    final methodStart =
        source.indexOf('Future<void> _recoverStalledGroupMedia(');
    final methodEnd =
        source.indexOf('  void _applyGroupParticipantState({', methodStart);
    final body = source.substring(methodStart, methodEnd);

    expect(body,
        contains('final matrixGroupCallId = productGroupCallIdForMatrix('));
    expect(body, isNot(contains('fetchOrCreateGroupCall(\n        room.id,')));
  });

  test('product participant joins drive AS connected reporting', () {
    final source = File('lib/presentation/call/voice_call_controller.dart')
        .readAsStringSync();
    final methodStart = source.indexOf('void _applyGroupParticipantState({');
    final methodEnd = source.indexOf('  bool _listEquals(', methodStart);
    final body = source.substring(methodStart, methodEnd);

    expect(body, contains('joinedUserIds: next'));
    expect(body, contains('_reportAsCallConnected(_activeGroupAsCall)'));
  });

  test('group video calls enter and recover with an explicit video stream', () {
    final source = File('lib/presentation/call/voice_call_controller.dart')
        .readAsStringSync();
    final controllerStart = source.indexOf('class MatrixVoiceCallController');
    final startMethodStart = source.indexOf(
      'Future<void> startOrJoinGroupCall({',
      controllerStart,
    );
    final startMethodEnd = source.indexOf(
      '@override\n  Future<void> leaveGroupCall',
      startMethodStart,
    );
    final startBody = source.substring(startMethodStart, startMethodEnd);
    final recoveryMethodStart =
        source.indexOf('Future<void> _recoverStalledGroupMedia(');
    final recoveryMethodEnd = source.indexOf(
      '  void _applyGroupParticipantState({',
      recoveryMethodStart,
    );
    final recoveryBody =
        source.substring(recoveryMethodStart, recoveryMethodEnd);

    expect(startBody, contains('await _createVideoGroupStream('));
    expect(recoveryBody, contains('await _createVideoGroupStream('));
  });
}

class _RecordingAsClient extends MockAsClient {
  final created = <Map<String, Object?>>[];
  final events = <Map<String, Object?>>[];
  final _calls = <String, AsCallSession>{};
  int _nextCall = 1;

  @override
  Future<AsCallSession> createCall({
    required String roomId,
    required String mediaType,
    List<String> invitedUserIds = const [],
  }) async {
    created.add({
      'room_id': roomId,
      'media_type': mediaType,
      'invited_user_ids': invitedUserIds,
    });
    final call = AsCallSession(
      callId: 'as-group-call-${_nextCall++}',
      roomId: roomId,
      roomType: 'group',
      mediaType: mediaType,
      createdByMxid: '@owner:p2p-im.com',
      invitedUserIds: invitedUserIds,
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

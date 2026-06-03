import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/chat/call_timeline_events.dart';
import 'package:portal_app/presentation/utils/chat_visibility_policy.dart';

void main() {
  test('keeps only call hangup events as visible chat records', () {
    final client = Client('CallTimelineDisplayEventsTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final invite = _event(
      room,
      eventId: r'$invite',
      type: EventTypes.CallInvite,
      at: DateTime.utc(2026, 5, 30, 1),
    );
    final answer = _event(
      room,
      eventId: r'$answer',
      type: EventTypes.CallAnswer,
      at: DateTime.utc(2026, 5, 30, 1, 0, 1),
    );
    final hangup = _event(
      room,
      eventId: r'$hangup',
      type: EventTypes.CallHangup,
      at: DateTime.utc(2026, 5, 30, 1, 0, 47),
    );
    final message = Event(
      room: room,
      eventId: r'$text',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 30, 1, 1),
      content: {
        'msgtype': MessageTypes.Text,
        'body': 'hello',
      },
    );

    expect(
      chatDisplayEventsForTimeline([invite, answer, hangup, message])
          .map((event) => event.eventId),
      [r'$hangup', r'$text'],
    );
  });

  test('formats completed and missed voice call records', () {
    final client = Client('CallTimelineRecordTextTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final invite = _event(
      room,
      eventId: r'$invite',
      type: EventTypes.CallInvite,
      at: DateTime.utc(2026, 5, 30, 1),
    );
    final hangup = _event(
      room,
      eventId: r'$hangup',
      type: EventTypes.CallHangup,
      at: DateTime.utc(2026, 5, 30, 1, 0, 47),
    );
    final answer = _event(
      room,
      eventId: r'$answer',
      type: EventTypes.CallAnswer,
      at: DateTime.utc(2026, 5, 30, 1, 0, 20),
    );
    final missed = _event(
      room,
      eventId: r'$missed',
      type: EventTypes.CallHangup,
      at: DateTime.utc(2026, 5, 30, 1, 2),
      reason: 'userHangup',
    );

    expect(
      callRecordText(hangup, [invite, answer, hangup]),
      '0:27',
    );
    expect(callRecordText(missed, [invite, missed]), '未接通');
  });

  test('formats video call records from product call intent', () {
    final client = Client('CallTimelineVideoRecordTextTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final intent = Event(
      room: room,
      eventId: r'$intent',
      senderId: '@me:p2p-im.com',
      type: 'p2p.call.intent.v1',
      originServerTs: DateTime.utc(2026, 5, 30, 1),
      content: {
        'call_type': 'video',
        'target_user_id': '@peer:p2p-liyanan.com',
        'created_at_ms': DateTime.utc(2026, 5, 30, 1).millisecondsSinceEpoch,
      },
    );
    final invite = _event(
      room,
      eventId: r'$invite',
      type: EventTypes.CallInvite,
      at: DateTime.utc(2026, 5, 30, 1, 0, 1),
    );
    final answer = _event(
      room,
      eventId: r'$answer',
      type: EventTypes.CallAnswer,
      at: DateTime.utc(2026, 5, 30, 1, 0, 10),
    );
    final hangup = _event(
      room,
      eventId: r'$hangup',
      type: EventTypes.CallHangup,
      at: DateTime.utc(2026, 5, 30, 1, 0, 37),
    );

    final visible = chatDisplayEventsForTimeline([
      intent,
      invite,
      answer,
      hangup,
    ]);
    final callContext = callRecordContextEventsForTimeline([
      intent,
      invite,
      answer,
      hangup,
    ]);

    expect(visible.map((event) => event.eventId), [r'$hangup']);
    expect(callContext.map((event) => event.eventId), [
      r'$intent',
      r'$invite',
      r'$answer',
      r'$hangup',
    ]);
    expect(callRecordIsVideo(visible.single, callContext), isTrue);
    expect(callRecordText(visible.single, callContext), '0:27');
  });

  test('formats call records from AS session before Matrix answer arrives', () {
    final client = Client('CallTimelineAsSessionTextTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final intent = Event(
      room: room,
      eventId: r'$intent',
      senderId: '@me:p2p-im.com',
      type: 'p2p.call.intent.v1',
      originServerTs: DateTime.utc(2026, 5, 30, 1),
      content: {
        'call_id': 'as-call-1',
        'call_type': 'voice',
        'target_user_id': '@peer:p2p-liyanan.com',
        'created_at_ms': DateTime.utc(2026, 5, 30, 1).millisecondsSinceEpoch,
      },
    );
    final invite = _event(
      room,
      eventId: r'$invite',
      type: EventTypes.CallInvite,
      at: DateTime.utc(2026, 5, 30, 1, 0, 1),
    );
    final hangup = _event(
      room,
      eventId: r'$hangup',
      type: EventTypes.CallHangup,
      at: DateTime.utc(2026, 5, 30, 1, 0, 37),
    );
    final asSession = AsCallSession(
      callId: 'as-call-1',
      roomId: '!room:p2p-im.com',
      roomType: 'direct',
      mediaType: asCallMediaTypeVoice,
      createdByMxid: '@me:p2p-im.com',
      state: asCallStateEnded,
      createdAt: DateTime.utc(2026, 5, 30, 1),
      answeredAt: DateTime.utc(2026, 5, 30, 1, 0, 10),
      endedAt: DateTime.utc(2026, 5, 30, 1, 0, 37),
      durationMs: 27000,
    );

    expect(
        asCallIdForCallRecord(hangup, [intent, invite, hangup]), 'as-call-1');
    expect(
      callRecordText(
        hangup,
        [intent, invite, hangup],
        asCallSession: asSession,
      ),
      '0:27',
    );
  });

  test('formats standalone AS call session snapshots', () {
    final session = AsCallSession(
      callId: 'group-call-1',
      roomId: '!group:p2p-im.com',
      roomType: 'group',
      mediaType: asCallMediaTypeVideo,
      createdByMxid: '@owner:p2p-im.com',
      state: asCallStateEnded,
      createdAt: DateTime.utc(2026, 6, 2, 10),
      answeredAt: DateTime.utc(2026, 6, 2, 10, 0, 3),
      endedAt: DateTime.utc(2026, 6, 2, 10, 0, 45),
      durationMs: 42000,
    );

    expect(asCallSessionRecordIsVideo(session), isTrue);
    expect(asCallSessionRecordText(session), '0:42');
    expect(
      asCallSessionRecordText(
        AsCallSession(
          callId: 'group-call-2',
          roomId: '!group:p2p-im.com',
          roomType: 'group',
          mediaType: asCallMediaTypeVoice,
          createdByMxid: '@owner:p2p-im.com',
          state: asCallStateMissed,
          createdAt: DateTime.utc(2026, 6, 2, 10),
        ),
      ),
      '未接通',
    );
  });

  test('uses pending text for product call records before AS session loads',
      () {
    final client = Client('CallTimelinePendingAsSessionTextTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final intent = Event(
      room: room,
      eventId: r'$intent',
      senderId: '@me:p2p-im.com',
      type: 'p2p.call.intent.v1',
      originServerTs: DateTime.utc(2026, 5, 30, 1),
      content: {
        'call_id': 'as-call-1',
        'call_type': 'voice',
        'target_user_id': '@peer:p2p-liyanan.com',
      },
    );
    final invite = _event(
      room,
      eventId: r'$invite',
      type: EventTypes.CallInvite,
      at: DateTime.utc(2026, 5, 30, 1, 0, 1),
    );
    final hangup = _event(
      room,
      eventId: r'$hangup',
      type: EventTypes.CallHangup,
      at: DateTime.utc(2026, 5, 30, 1, 0, 37),
    );

    expect(
      callRecordText(
        hangup,
        [intent, invite, hangup],
        asCallSessionPending: true,
      ),
      '同步中',
    );
  });

  test('latest voice call intent overrides a stale video intent', () {
    final client = Client('CallTimelineVoiceIntentWinsTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final staleVideoIntent = Event(
      room: room,
      eventId: r'$video-intent',
      senderId: '@me:p2p-im.com',
      type: 'p2p.call.intent.v1',
      originServerTs: DateTime.utc(2026, 5, 30, 1),
      content: {
        'call_type': 'video',
        'target_user_id': '@peer:p2p-liyanan.com',
        'created_at_ms': DateTime.utc(2026, 5, 30, 1).millisecondsSinceEpoch,
      },
    );
    final voiceIntent = Event(
      room: room,
      eventId: r'$voice-intent',
      senderId: '@me:p2p-im.com',
      type: 'p2p.call.intent.v1',
      originServerTs: DateTime.utc(2026, 5, 30, 1, 0, 5),
      content: {
        'call_type': 'voice',
        'target_user_id': '@peer:p2p-liyanan.com',
        'created_at_ms':
            DateTime.utc(2026, 5, 30, 1, 0, 5).millisecondsSinceEpoch,
      },
    );
    final invite = _event(
      room,
      eventId: r'$invite',
      type: EventTypes.CallInvite,
      at: DateTime.utc(2026, 5, 30, 1, 0, 6),
    );
    final answer = _event(
      room,
      eventId: r'$answer',
      type: EventTypes.CallAnswer,
      at: DateTime.utc(2026, 5, 30, 1, 0, 10),
    );
    final hangup = _event(
      room,
      eventId: r'$hangup',
      type: EventTypes.CallHangup,
      at: DateTime.utc(2026, 5, 30, 1, 0, 20),
    );

    expect(
      callRecordText(hangup, [
        staleVideoIntent,
        voiceIntent,
        invite,
        answer,
        hangup,
      ]),
      '0:10',
    );
  });

  test('collapses duplicate hangups into one call record', () {
    final client = Client('CallTimelineDuplicateHangupsTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final invite = _event(
      room,
      eventId: r'$invite',
      type: EventTypes.CallInvite,
      at: DateTime.utc(2026, 5, 30, 1),
    );
    final answer = _event(
      room,
      eventId: r'$answer',
      type: EventTypes.CallAnswer,
      at: DateTime.utc(2026, 5, 30, 1, 0, 3),
    );
    final localHangup = _event(
      room,
      eventId: r'$local-hangup',
      type: EventTypes.CallHangup,
      at: DateTime.utc(2026, 5, 30, 1, 0, 10),
    );
    final remoteHangup = _event(
      room,
      eventId: r'$remote-hangup',
      type: EventTypes.CallHangup,
      at: DateTime.utc(2026, 5, 30, 1, 0, 11),
    );
    final lateCandidate = _event(
      room,
      eventId: r'$late-candidate',
      type: EventTypes.CallCandidates,
      at: DateTime.utc(2026, 5, 30, 1, 0, 12),
    );

    final visible = chatDisplayEventsForTimeline([
      invite,
      answer,
      localHangup,
      remoteHangup,
      lateCandidate,
    ]);

    expect(visible.map((event) => event.eventId), [r'$remote-hangup']);
    expect(
      callRecordText(visible.single, [
        invite,
        answer,
        localHangup,
        remoteHangup,
        lateCandidate,
      ]),
      '0:08',
    );
  });

  test('uses raw call context after display filtering hides answer events', () {
    final client = Client('CallTimelineRawContextTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final invite = _event(
      room,
      eventId: r'$invite',
      type: EventTypes.CallInvite,
      at: DateTime.utc(2026, 5, 30, 1),
    );
    final answer = _event(
      room,
      eventId: r'$answer',
      type: EventTypes.CallAnswer,
      at: DateTime.utc(2026, 5, 30, 1, 0, 20),
    );
    final hangup = _event(
      room,
      eventId: r'$hangup',
      type: EventTypes.CallHangup,
      at: DateTime.utc(2026, 5, 30, 1, 0, 47),
    );

    final visible = chatDisplayEventsForTimeline([invite, answer, hangup]);
    final callContext = callRecordContextEventsForTimeline([
      invite,
      answer,
      hangup,
    ]);

    expect(visible.map((event) => event.eventId), [r'$hangup']);
    expect(callRecordText(visible.single, callContext), '0:27');
  });

  test('collapses group call product events into one visible call record', () {
    final client = Client('GroupCallTimelineDisplayEventsTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(id: '!group:p2p-im.com', client: client);
    final invite = _groupCallEvent(
      room,
      eventId: r'$group-invite',
      type: 'p2p.group_call.invite.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10),
      content: {
        'call_id': 'group-call-1',
        'call_type': 'voice',
        'invited_user_ids': ['@alice:p2p-liyanan.com'],
        'created_at_ms': DateTime.utc(2026, 5, 31, 10).millisecondsSinceEpoch,
      },
    );
    final ownerJoin = _groupCallEvent(
      room,
      eventId: r'$owner-join',
      type: 'p2p.group_call.join.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10, 0, 1),
      content: {
        'call_id': 'group-call-1',
        'user_id': '@owner:p2p-im.com',
        'created_at_ms':
            DateTime.utc(2026, 5, 31, 10, 0, 1).millisecondsSinceEpoch,
      },
    );
    final aliceJoin = _groupCallEvent(
      room,
      eventId: r'$alice-join',
      type: 'p2p.group_call.join.v1',
      senderId: '@alice:p2p-liyanan.com',
      at: DateTime.utc(2026, 5, 31, 10, 0, 5),
      content: {
        'call_id': 'group-call-1',
        'user_id': '@alice:p2p-liyanan.com',
        'created_at_ms':
            DateTime.utc(2026, 5, 31, 10, 0, 5).millisecondsSinceEpoch,
      },
    );
    final aliceLeave = _groupCallEvent(
      room,
      eventId: r'$alice-leave',
      type: 'p2p.group_call.leave.v1',
      senderId: '@alice:p2p-liyanan.com',
      at: DateTime.utc(2026, 5, 31, 10, 0, 47),
      content: {
        'call_id': 'group-call-1',
        'user_id': '@alice:p2p-liyanan.com',
        'created_at_ms':
            DateTime.utc(2026, 5, 31, 10, 0, 47).millisecondsSinceEpoch,
      },
    );

    final visible = chatDisplayEventsForTimeline([
      invite,
      ownerJoin,
      aliceJoin,
      aliceLeave,
    ]);
    final callContext = callRecordContextEventsForTimeline([
      invite,
      ownerJoin,
      aliceJoin,
      aliceLeave,
    ]);

    expect(visible.map((event) => event.eventId), [r'$alice-leave']);
    expect(callRecordIsVideo(visible.single, callContext), isFalse);
    expect(callRecordText(visible.single, callContext), '0:42');
    expect(
        callRecordSenderId(visible.single, callContext), '@owner:p2p-im.com');
  });

  test('formats group call as missed until two members join', () {
    final client = Client('GroupCallTimelineMissedTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(id: '!group:p2p-im.com', client: client);
    final invite = _groupCallEvent(
      room,
      eventId: r'$group-invite',
      type: 'p2p.group_call.invite.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10),
      content: {
        'call_id': 'group-call-2',
        'call_type': 'voice',
        'invited_user_ids': ['@alice:p2p-liyanan.com'],
      },
    );
    final ownerJoin = _groupCallEvent(
      room,
      eventId: r'$owner-join',
      type: 'p2p.group_call.join.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10, 0, 1),
      content: {
        'call_id': 'group-call-2',
        'user_id': '@owner:p2p-im.com',
      },
    );
    final ownerLeave = _groupCallEvent(
      room,
      eventId: r'$owner-leave',
      type: 'p2p.group_call.leave.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10, 1),
      content: {
        'call_id': 'group-call-2',
        'user_id': '@owner:p2p-im.com',
      },
    );

    final visible =
        chatDisplayEventsForTimeline([invite, ownerJoin, ownerLeave]);
    final callContext =
        callRecordContextEventsForTimeline([invite, ownerJoin, ownerLeave]);

    expect(visible.map((event) => event.eventId), [r'$owner-leave']);
    expect(callRecordText(visible.single, callContext), '未接通');
  });

  test('formats completed group video call records', () {
    final client = Client('GroupVideoCallTimelineTextTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(id: '!group:p2p-im.com', client: client);
    final invite = _groupCallEvent(
      room,
      eventId: r'$group-video-invite',
      type: 'p2p.group_call.invite.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10),
      content: {
        'call_id': 'group-call-3',
        'call_type': 'video',
        'invited_user_ids': ['@alice:p2p-liyanan.com'],
      },
    );
    final ownerJoin = _groupCallEvent(
      room,
      eventId: r'$owner-join',
      type: 'p2p.group_call.join.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10, 0, 1),
      content: {
        'call_id': 'group-call-3',
        'user_id': '@owner:p2p-im.com',
      },
    );
    final aliceJoin = _groupCallEvent(
      room,
      eventId: r'$alice-join',
      type: 'p2p.group_call.join.v1',
      senderId: '@alice:p2p-liyanan.com',
      at: DateTime.utc(2026, 5, 31, 10, 0, 4),
      content: {
        'call_id': 'group-call-3',
        'user_id': '@alice:p2p-liyanan.com',
      },
    );
    final ownerLeave = _groupCallEvent(
      room,
      eventId: r'$owner-leave',
      type: 'p2p.group_call.leave.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10, 1, 22),
      content: {
        'call_id': 'group-call-3',
        'user_id': '@owner:p2p-im.com',
      },
    );

    final visible = chatDisplayEventsForTimeline([
      invite,
      ownerJoin,
      aliceJoin,
      ownerLeave,
    ]);
    final callContext = callRecordContextEventsForTimeline([
      invite,
      ownerJoin,
      aliceJoin,
      ownerLeave,
    ]);

    expect(callRecordIsVideo(visible.single, callContext), isTrue);
    expect(callRecordText(visible.single, callContext), '1:18');
  });

  test('formats group call as syncing while AS session is pending', () {
    final client = Client('GroupCallTimelinePendingAsSessionTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(id: '!group:p2p-im.com', client: client);
    final invite = _groupCallEvent(
      room,
      eventId: r'$group-invite',
      type: 'p2p.group_call.invite.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10),
      content: {
        'call_id': 'group-call-pending-as',
        'call_type': 'voice',
      },
    );
    final ownerJoin = _groupCallEvent(
      room,
      eventId: r'$owner-join',
      type: 'p2p.group_call.join.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10, 0, 1),
      content: {
        'call_id': 'group-call-pending-as',
        'user_id': '@owner:p2p-im.com',
      },
    );
    final aliceJoin = _groupCallEvent(
      room,
      eventId: r'$alice-join',
      type: 'p2p.group_call.join.v1',
      senderId: '@alice:p2p-liyanan.com',
      at: DateTime.utc(2026, 5, 31, 10, 0, 3),
      content: {
        'call_id': 'group-call-pending-as',
        'user_id': '@alice:p2p-liyanan.com',
      },
    );
    final ownerLeave = _groupCallEvent(
      room,
      eventId: r'$owner-leave',
      type: 'p2p.group_call.leave.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10, 0, 20),
      content: {
        'call_id': 'group-call-pending-as',
        'user_id': '@owner:p2p-im.com',
      },
    );
    final events = [invite, ownerJoin, aliceJoin, ownerLeave];
    final visible = chatDisplayEventsForTimeline(events);
    final callContext = callRecordContextEventsForTimeline(events);

    expect(
      callRecordText(
        visible.single,
        callContext,
        asCallSessionPending: true,
      ),
      '同步中',
    );
  });

  test('detects an active group call from product timeline events', () {
    final client = Client('ActiveGroupCallTimelineEntryTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(id: '!group:p2p-im.com', client: client);
    final invite = _groupCallEvent(
      room,
      eventId: r'$group-video-invite',
      type: 'p2p.group_call.invite.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10),
      content: {
        'call_id': 'group-call-active',
        'call_type': 'video',
        'invited_user_ids': ['@alice:p2p-liyanan.com'],
      },
    );
    final ownerJoin = _groupCallEvent(
      room,
      eventId: r'$owner-join',
      type: 'p2p.group_call.join.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10, 0, 1),
      content: {
        'call_id': 'group-call-active',
        'user_id': '@owner:p2p-im.com',
      },
    );

    final active = activeGroupCallEntryForTimeline(
      [invite, ownerJoin],
      now: DateTime.utc(2026, 5, 31, 10, 30),
    );

    expect(active?.callId, 'group-call-active');
    expect(active?.isVideo, isTrue);
  });

  test('does not detect active group call after all joined members leave', () {
    final client = Client('EndedGroupCallTimelineEntryTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(id: '!group:p2p-im.com', client: client);
    final invite = _groupCallEvent(
      room,
      eventId: r'$group-invite',
      type: 'p2p.group_call.invite.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10),
      content: {
        'call_id': 'group-call-ended',
        'call_type': 'voice',
      },
    );
    final ownerJoin = _groupCallEvent(
      room,
      eventId: r'$owner-join',
      type: 'p2p.group_call.join.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10, 0, 1),
      content: {
        'call_id': 'group-call-ended',
        'user_id': '@owner:p2p-im.com',
      },
    );
    final ownerLeave = _groupCallEvent(
      room,
      eventId: r'$owner-leave',
      type: 'p2p.group_call.leave.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 5, 31, 10, 1),
      content: {
        'call_id': 'group-call-ended',
        'user_id': '@owner:p2p-im.com',
      },
    );

    expect(
      activeGroupCallEntryForTimeline(
        [invite, ownerJoin, ownerLeave],
        now: DateTime.utc(2026, 5, 31, 10, 2),
      ),
      isNull,
    );
  });

  test('assigns call record bubble to the original caller', () {
    final client = Client('CallTimelineRecordSenderTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final invite = _event(
      room,
      eventId: r'$invite',
      type: EventTypes.CallInvite,
      senderId: '@me:p2p-im.com',
      at: DateTime.utc(2026, 5, 30, 1),
    );
    final answer = _event(
      room,
      eventId: r'$answer',
      type: EventTypes.CallAnswer,
      senderId: '@peer:p2p-liyanan.com',
      at: DateTime.utc(2026, 5, 30, 1, 0, 10),
    );
    final peerHangup = _event(
      room,
      eventId: r'$hangup',
      type: EventTypes.CallHangup,
      senderId: '@peer:p2p-liyanan.com',
      at: DateTime.utc(2026, 5, 30, 1, 0, 47),
    );

    expect(
      callRecordSenderId(peerHangup, [invite, answer, peerHangup]),
      '@me:p2p-im.com',
    );
  });

  test('deleted call records stay hidden through the shared visibility policy',
      () {
    final client = Client('CallTimelineDeletedRecordTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final invite = _event(
      room,
      eventId: r'$invite',
      type: EventTypes.CallInvite,
      at: DateTime.utc(2026, 5, 30, 1),
    );
    final hangup = _event(
      room,
      eventId: r'$hangup',
      type: EventTypes.CallHangup,
      at: DateTime.utc(2026, 5, 30, 1, 0, 47),
    );

    final visibleCallRecords = chatDisplayEventsForTimeline([invite, hangup]);
    final afterDelete = const ChatVisibilityPolicy(
      deletedEventIds: {r'$hangup'},
    ).filter(
      visibleCallRecords,
      eventId: (event) => event.eventId,
      originServerTs: (event) => event.originServerTs.millisecondsSinceEpoch,
      redacted: (event) => event.redacted,
    );

    expect(visibleCallRecords.map((event) => event.eventId), [r'$hangup']);
    expect(afterDelete, isEmpty);
  });
}

Event _event(
  Room room, {
  required String eventId,
  required String type,
  required DateTime at,
  String senderId = '@me:p2p-im.com',
  String reason = 'user_hangup',
}) {
  return Event(
    room: room,
    eventId: eventId,
    senderId: senderId,
    type: type,
    originServerTs: at,
    content: {
      'call_id': 'call-1',
      'version': 1,
      'reason': reason,
    },
  );
}

Event _groupCallEvent(
  Room room, {
  required String eventId,
  required String type,
  required String senderId,
  required DateTime at,
  required Map<String, Object?> content,
}) {
  return Event(
    room: room,
    eventId: eventId,
    senderId: senderId,
    type: type,
    originServerTs: at,
    content: content,
  );
}

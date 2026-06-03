import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/chat/call_timeline_events.dart';
import 'package:portal_app/presentation/chat/group_call_history_merge.dart';

void main() {
  test('AS snapshots replace visible Matrix group call records', () {
    final client = Client('GroupCallHistoryMergeTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(id: '!group:p2p-im.com', client: client);
    final invite = _groupCallEvent(
      room,
      eventId: r'$invite',
      type: 'p2p.group_call.invite.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 6, 2, 10),
      content: {
        'call_id': 'call-video',
        'call_type': 'video',
      },
    );
    final leave = _groupCallEvent(
      room,
      eventId: r'$leave',
      type: 'p2p.group_call.leave.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 6, 2, 10, 1),
      content: {
        'call_id': 'call-video',
        'user_id': '@owner:p2p-im.com',
      },
    );
    final callContext = callRecordContextEventsForTimeline([invite, leave]);
    final visibleEvents = chatDisplayEventsForTimeline([invite, leave]);
    final snapshot = _session(
      callId: 'call-video',
      mediaType: asCallMediaTypeVideo,
      state: asCallStateEnded,
      answeredAt: DateTime.utc(2026, 6, 2, 10, 0, 3),
      endedAt: DateTime.utc(2026, 6, 2, 10, 0, 45),
      durationMs: 42000,
    );

    final snapshots = asCallSessionsForGroupTimeline(
      sessions: [snapshot],
      roomId: '!group:p2p-im.com',
      rawTimelineEvents: [invite, leave],
      visibleEvents: visibleEvents,
      callRecordContextEvents: callContext,
    );
    final events = groupTimelineEventsReplacingAsCallSnapshots(
      visibleEvents: visibleEvents,
      callRecordContextEvents: callContext,
      asCallSessions: snapshots,
    );

    expect(snapshots.map((session) => session.callId), ['call-video']);
    expect(asCallSessionRecordIsVideo(snapshots.single), isTrue);
    expect(asCallSessionRecordText(snapshots.single), '0:42');
    expect(events, isEmpty);
  });

  test('AS snapshots do not re-add locally hidden Matrix call records', () {
    final client = Client('GroupCallHistoryHiddenTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(id: '!group:p2p-im.com', client: client);
    final leave = _groupCallEvent(
      room,
      eventId: r'$leave',
      type: 'p2p.group_call.leave.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 6, 2, 10, 1),
      content: {
        'call_id': 'call-hidden',
        'user_id': '@owner:p2p-im.com',
      },
    );
    final callContext = callRecordContextEventsForTimeline([leave]);

    final snapshots = asCallSessionsForGroupTimeline(
      sessions: [
        _session(
          callId: 'call-hidden',
          state: asCallStateEnded,
          answeredAt: DateTime.utc(2026, 6, 2, 10, 0, 3),
          endedAt: DateTime.utc(2026, 6, 2, 10, 0, 45),
        ),
      ],
      roomId: '!group:p2p-im.com',
      rawTimelineEvents: [leave],
      visibleEvents: const [],
      callRecordContextEvents: callContext,
    );

    expect(snapshots, isEmpty);
  });

  test('AS snapshots fill older room calls absent from local Matrix timeline',
      () {
    final snapshots = asCallSessionsForGroupTimeline(
      sessions: [
        _session(
          callId: 'call-old-voice',
          mediaType: asCallMediaTypeVoice,
          state: asCallStateEnded,
          createdAt: DateTime.utc(2026, 6, 2, 9),
          endedAt: DateTime.utc(2026, 6, 2, 9, 1),
        ),
        _session(
          callId: 'call-new-video',
          mediaType: asCallMediaTypeVideo,
          state: asCallStateEnded,
          createdAt: DateTime.utc(2026, 6, 2, 10),
          endedAt: DateTime.utc(2026, 6, 2, 10, 1),
        ),
      ],
      roomId: '!group:p2p-im.com',
      rawTimelineEvents: const [],
      visibleEvents: const [],
      callRecordContextEvents: const [],
    );

    expect(
      snapshots.map((session) => '${session.callId}:${session.mediaType}'),
      ['call-new-video:video', 'call-old-voice:voice'],
    );
  });

  test('matrix group call records without AS snapshots request refresh', () {
    final client = Client('GroupCallHistoryRefreshTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(id: '!group:p2p-im.com', client: client);
    final leave = _groupCallEvent(
      room,
      eventId: r'$leave',
      type: 'p2p.group_call.leave.v1',
      senderId: '@owner:p2p-im.com',
      at: DateTime.utc(2026, 6, 2, 10, 1),
      content: {
        'call_id': 'call-needs-as',
        'user_id': '@owner:p2p-im.com',
      },
    );
    final callContext = callRecordContextEventsForTimeline([leave]);
    final visibleEvents = chatDisplayEventsForTimeline([leave]);

    expect(
      shouldReloadAsCallSessionsForGroupTimeline(
        visibleEvents: visibleEvents,
        callRecordContextEvents: callContext,
        currentSessions: const [],
      ),
      isTrue,
    );
    expect(
      shouldReloadAsCallSessionsForGroupTimeline(
        visibleEvents: visibleEvents,
        callRecordContextEvents: callContext,
        currentSessions: [
          _session(
            callId: 'call-needs-as',
            state: asCallStateEnded,
            answeredAt: DateTime.utc(2026, 6, 2, 10, 0, 3),
            endedAt: DateTime.utc(2026, 6, 2, 10, 0, 45),
          ),
        ],
      ),
      isFalse,
    );
  });
}

AsCallSession _session({
  required String callId,
  String mediaType = asCallMediaTypeVoice,
  String state = asCallStateEnded,
  DateTime? createdAt,
  DateTime? answeredAt,
  DateTime? endedAt,
  int durationMs = 0,
}) {
  return AsCallSession(
    callId: callId,
    roomId: '!group:p2p-im.com',
    roomType: 'group',
    mediaType: mediaType,
    createdByMxid: '@owner:p2p-im.com',
    state: state,
    createdAt: createdAt ?? DateTime.utc(2026, 6, 2, 10),
    answeredAt: answeredAt,
    endedAt: endedAt,
    durationMs: durationMs,
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

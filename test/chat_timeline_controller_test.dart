import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/chat/chat_timeline_controller.dart';

void main() {
  test('open initial timeline syncs empty joined room history', () async {
    final client = _RecordingRoomHistoryClient()
      ..setUserId('@me:p2p-im.com')
      ..accessToken = 'matrix-token'
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);

    final timeline = await ChatTimelineController(
      room: room,
      rebuild: () {},
      debugLabel: 'test',
    ).openInitialTimeline();

    expect(timeline, isNotNull);
    await _flushAsyncWork();
    expect(client.syncCalls, 1);
    expect(client.lastSyncFullState, isTrue);
    expect(client.lastSyncTimeout, 0);
    expect(client.lastSyncFilter, contains(room.id));
    expect(client.handledDirection, Direction.b);
  });

  test('backfills timeline again after empty room history sync', () async {
    final client = _RecordingRoomHistoryClient()
      ..setUserId('@me:p2p-im.com')
      ..accessToken = 'matrix-token'
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final restoredEvent = _messageEvent(room, r'$restored');
    var synced = false;
    var rebuilds = 0;

    final timeline = await ChatTimelineController(
      room: room,
      rebuild: () => rebuilds++,
      debugLabel: 'test',
      localHistoryLoader: (timeline, {required start, required limit}) async {
        if (!synced || start > 0) return const <Event>[];
        return [restoredEvent];
      },
      roomHistorySyncer: (_, {required roomId, required timelineLimit}) async {
        expect(roomId, room.id);
        synced = true;
      },
    ).openInitialTimeline();

    expect(timeline, isNotNull);
    expect(timeline!.events, isEmpty);

    await _flushAsyncWork();

    expect(synced, isTrue);
    expect(timeline.events.map((event) => event.eventId), [r'$restored']);
    expect(rebuilds, greaterThan(0));
  });
}

Future<void> _flushAsyncWork() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _RecordingRoomHistoryClient extends Client {
  _RecordingRoomHistoryClient() : super('ChatTimelineControllerTest');

  int syncCalls = 0;
  String? lastSyncFilter;
  bool? lastSyncFullState;
  int? lastSyncTimeout;
  Direction? handledDirection;

  @override
  Future<SyncUpdate> sync({
    String? filter,
    String? since,
    bool? fullState,
    PresenceType? setPresence,
    int? timeout,
  }) async {
    syncCalls++;
    lastSyncFilter = filter;
    lastSyncFullState = fullState;
    lastSyncTimeout = timeout;
    return SyncUpdate(nextBatch: 's1');
  }

  @override
  Future<void> handleSync(SyncUpdate sync, {Direction? direction}) async {
    handledDirection = direction;
  }
}

Event _messageEvent(Room room, String eventId) {
  return Event(
    room: room,
    eventId: eventId,
    senderId: '@alice:p2p-im.com',
    type: EventTypes.Message,
    originServerTs: DateTime.utc(2026, 6, 29),
    content: {
      'msgtype': MessageTypes.Text,
      'body': 'hello',
    },
  );
}

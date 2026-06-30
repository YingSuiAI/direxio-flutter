import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/chat/chat_timeline_controller.dart';

void main() {
  test('open initial timeline uses local cache without room history sync',
      () async {
    final client = _RecordingRoomHistoryClient()
      ..setUserId('@me:p2p-im.com')
      ..accessToken = 'matrix-token'
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final restoredEvent = _messageEvent(room, r'$local');
    var rebuilds = 0;

    final timeline = await ChatTimelineController(
      room: room,
      rebuild: () => rebuilds++,
      debugLabel: 'test',
      localHistoryLoader: (timeline, {required start, required limit}) async {
        if (start > 0) return const <Event>[];
        return [restoredEvent];
      },
    ).openInitialTimeline();

    expect(timeline, isNotNull);
    await _flushAsyncWork();
    expect(timeline!.events.map((event) => event.eventId), [r'$local']);
    expect(client.syncCalls, 0);
    expect(rebuilds, greaterThan(0));
  });

  test('open initial timeline does not sync empty room history', () async {
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
    expect(client.syncCalls, 0);
  });

  test('user load older backfills local cache only', () async {
    final client = _RecordingRoomHistoryClient()
      ..setUserId('@me:p2p-im.com')
      ..accessToken = 'matrix-token'
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final restoredEvent = _messageEvent(room, r'$older');
    var rebuilds = 0;
    var localLoads = 0;

    final controller = ChatTimelineController(
      room: room,
      rebuild: () => rebuilds++,
      debugLabel: 'test',
      localHistoryLoader: (timeline, {required start, required limit}) async {
        localLoads++;
        if (localLoads == 2) return [restoredEvent];
        return const <Event>[];
      },
    );
    final timeline = await controller.openInitialTimeline();

    expect(timeline, isNotNull);

    await _flushAsyncWork();
    await controller.requestOlderMessages(timeline!);

    expect(timeline.events.map((event) => event.eventId), [r'$older']);
    expect(client.syncCalls, 0);
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

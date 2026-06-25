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

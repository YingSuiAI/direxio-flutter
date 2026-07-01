import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/matrix_room_history_sync.dart';

void main() {
  test('room history sync stores fetched events as history', () async {
    final client = _RecordingRoomHistoryClient();

    await syncMatrixRoomHistory(
      client,
      roomId: '!room:example.com',
      timelineLimit: 30,
    );

    expect(client.handledDirection, Direction.b);
  });

  test('room state sync filter can omit timeline message bodies', () {
    final filter = matrixRoomHistorySyncFilterJson(
      roomId: '!room:example.com',
      timelineLimit: -1,
    );
    final room = filter['room'] as Map<String, Object?>;
    final timeline = room['timeline'] as Map<String, Object?>;
    final ephemeral = room['ephemeral'] as Map<String, Object?>;

    expect(filter['event_fields'], isNull);
    expect(room['rooms'], ['!room:example.com']);
    expect(timeline['limit'], 0);
    expect(timeline['not_types'], isNull);
    expect(ephemeral['not_types'], ['m.receipt', 'm.typing']);

    final encoded = jsonEncode(filter);
    expect(encoded, contains('!room:example.com'));
  });

  test('room state sync clamps negative limits to zero', () {
    final filter = matrixRoomHistorySyncFilterJson(
      roomId: '!room:example.com',
      timelineLimit: 0,
    );
    final room = filter['room'] as Map<String, Object?>;
    final timeline = room['timeline'] as Map<String, Object?>;

    expect(timeline['limit'], 0);
  });
}

class _RecordingRoomHistoryClient extends Client {
  _RecordingRoomHistoryClient() : super('RoomHistorySyncDirectionTest');

  Direction? handledDirection;

  @override
  Future<SyncUpdate> sync({
    String? filter,
    String? since,
    bool? fullState,
    PresenceType? setPresence,
    int? timeout,
  }) async {
    return SyncUpdate(nextBatch: 's1');
  }

  @override
  Future<void> handleSync(SyncUpdate sync, {Direction? direction}) async {
    handledDirection = direction;
  }
}

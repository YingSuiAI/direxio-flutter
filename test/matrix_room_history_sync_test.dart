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

  test('chat-open room history sync fetches concrete timeline messages', () {
    final filter = matrixRoomHistorySyncFilterJson(
      roomId: '!room:example.com',
      timelineLimit: 30,
    );
    final room = filter['room'] as Map<String, Object?>;
    final timeline = room['timeline'] as Map<String, Object?>;

    expect(filter['event_fields'], isNull);
    expect(room['rooms'], ['!room:example.com']);
    expect(timeline['limit'], 30);
    expect(timeline['not_types'], isNull);

    final encoded = jsonEncode(filter);
    expect(encoded, contains('!room:example.com'));
  });

  test('chat-open room history sync clamps invalid limits to one page', () {
    final filter = matrixRoomHistorySyncFilterJson(
      roomId: '!room:example.com',
      timelineLimit: 0,
    );
    final room = filter['room'] as Map<String, Object?>;
    final timeline = room['timeline'] as Map<String, Object?>;

    expect(timeline['limit'], 1);
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

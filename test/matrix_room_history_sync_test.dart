import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/matrix_room_history_sync.dart';

void main() {
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

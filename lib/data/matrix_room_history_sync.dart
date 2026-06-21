import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:matrix/matrix.dart';

Map<String, Object?> matrixRoomHistorySyncFilterJson({
  required String roomId,
  required int timelineLimit,
}) {
  final limit = max(1, timelineLimit);
  return {
    'room': {
      'rooms': [roomId],
      'state': {'lazy_load_members': true},
      'timeline': {
        'limit': limit,
        'lazy_load_members': true,
      },
    },
  };
}

Future<void> syncMatrixRoomHistory(
  Client client, {
  required String roomId,
  required int timelineLimit,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final trimmedRoomId = roomId.trim();
  if (trimmedRoomId.isEmpty) return;
  final syncResp = await client
      .sync(
        filter: jsonEncode(
          matrixRoomHistorySyncFilterJson(
            roomId: trimmedRoomId,
            timelineLimit: timelineLimit,
          ),
        ),
        fullState: true,
        timeout: 0,
        setPresence: client.syncPresence,
      )
      .timeout(timeout);
  final database = client.database;
  if (database == null) {
    await client.handleSync(syncResp, direction: Direction.b);
    return;
  }
  await database.transaction(() async {
    await client.handleSync(syncResp, direction: Direction.b);
  });
}

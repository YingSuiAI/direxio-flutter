import 'dart:async';
import 'dart:convert';
import 'package:matrix/matrix.dart';

Map<String, Object?> matrixRoomHistorySyncFilterJson({
  required String roomId,
  required int timelineLimit,
}) {
  return {
    'room': {
      'rooms': [roomId],
      'state': {'lazy_load_members': true},
      'timeline': {
        'limit': timelineLimit < 0 ? 0 : timelineLimit,
        'lazy_load_members': true,
      },
      'ephemeral': {
        'not_types': ['m.receipt', 'm.typing'],
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

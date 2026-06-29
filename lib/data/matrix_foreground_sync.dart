import 'dart:convert';
import 'dart:math';

import 'package:matrix/matrix.dart';

Map<String, Object?> matrixForegroundSyncFilterJson({
  int timelineLimit = 5,
}) {
  final limit = max(0, timelineLimit);
  return {
    'room': {
      'state': {'lazy_load_members': true},
      'timeline': {
        'limit': limit,
        'lazy_load_members': true,
      },
    },
  };
}

Future<void> syncMatrixForegroundLight(
  Client client, {
  int timelineLimit = 5,
  Duration timeout = const Duration(seconds: 12),
}) async {
  if (!client.isLogged()) return;
  await client
      .oneShotFilteredSync(
        filter: jsonEncode(
          matrixForegroundSyncFilterJson(timelineLimit: timelineLimit),
        ),
        timeout: 0,
        setPresence: client.syncPresence,
      )
      .timeout(timeout);
}

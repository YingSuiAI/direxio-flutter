import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/matrix_foreground_sync.dart';

void main() {
  test('foreground sync filter uses low timeline limit and lazy members', () {
    final filter = matrixForegroundSyncFilterJson();
    final room = filter['room']! as Map<String, Object?>;
    final state = room['state']! as Map<String, Object?>;
    final timeline = room['timeline']! as Map<String, Object?>;

    expect(state['lazy_load_members'], isTrue);
    expect(timeline['lazy_load_members'], isTrue);
    expect(timeline['limit'], 5);
  });

  test('foreground sync sends filtered sync through Matrix SDK', () async {
    final client = _RecordingForegroundSyncClient();
    client.setUserId('@owner:example.com');

    await syncMatrixForegroundLight(client);

    final filter =
        jsonDecode(client.syncRequests.single.filter!) as Map<String, Object?>;
    final room = filter['room']! as Map<String, Object?>;
    final timeline = room['timeline']! as Map<String, Object?>;
    expect(timeline['limit'], 5);
    expect(timeline['lazy_load_members'], isTrue);
    expect(client.filteredSyncCalls, 1);
  });
}

class _RecordingForegroundSyncClient extends Client {
  _RecordingForegroundSyncClient() : super('ForegroundSyncTest');

  final syncRequests =
      <({String? filter, String? since, bool? fullState, int? timeout})>[];
  int filteredSyncCalls = 0;

  @override
  bool isLogged() => true;

  @override
  Future<void> oneShotFilteredSync({
    String? filter,
    bool? fullState,
    PresenceType? setPresence,
    int? timeout,
  }) async {
    filteredSyncCalls++;
    syncRequests.add((
      filter: filter,
      since: prevBatch,
      fullState: fullState,
      timeout: timeout,
    ));
  }
}

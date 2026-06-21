import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/chat/chat_history_backfill_policy.dart';
import 'package:portal_app/presentation/chat/chat_room_recovery_sync.dart';

void main() {
  test('skips missing room history sync for blank room ids', () async {
    var calls = 0;

    final synced = await syncMissingRoomHistoryFromServer(
      roomId: '   ',
      syncHistory: ({required roomId, required timelineLimit}) async {
        calls++;
      },
    );

    expect(synced, isFalse);
    expect(calls, 0);
  });

  test('trims room id and uses chat open history page size', () async {
    final calls = <({String roomId, int timelineLimit})>[];

    final synced = await syncMissingRoomHistoryFromServer(
      roomId: '  !room:p2p.test  ',
      syncHistory: ({required roomId, required timelineLimit}) async {
        calls.add((roomId: roomId, timelineLimit: timelineLimit));
      },
    );

    expect(synced, isTrue);
    expect(calls, [
      (
        roomId: '!room:p2p.test',
        timelineLimit: chatOpenLocalHistoryPageSize,
      ),
    ]);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/groups/group_invite_content.dart';
import 'package:portal_app/presentation/groups/group_invite_join_flow.dart';

void main() {
  test('joins group invite through AS then syncs and refreshes bootstrap',
      () async {
    final calls = <String>[];
    final roomId = await joinGroupInviteThroughAs(
      invite: const GroupInviteContent(
        groupRoomId: '!group:p2p-im.com',
        groupName: '产品测试群',
        inviterMxid: '@alice:p2p-liyanan.com',
        inviteEventId: r'$invite',
      ),
      currentDirectRoomId: '!dm:p2p-im.com',
      joinGroup: ({
        required roomId,
        required groupName,
        required inviterMxid,
        required inviteEventId,
        required directRoomId,
      }) async {
        calls.add(
          'join:$roomId:$groupName:$inviterMxid:$inviteEventId:$directRoomId',
        );
        return const AsGroupResult(
          roomId: '!joined:p2p-im.com',
          name: '产品测试群',
          memberCount: 2,
          invitedCount: 0,
          role: 'member',
        );
      },
      oneShotSync: () async => calls.add('sync'),
      refreshBootstrap: () async => calls.add('refresh'),
    );

    expect(roomId, '!joined:p2p-im.com');
    expect(calls, [
      r'join:!group:p2p-im.com:产品测试群:@alice:p2p-liyanan.com:$invite:!dm:p2p-im.com',
      'sync',
      'refresh',
    ]);
  });

  test('waits until the joined Matrix room appears after AS join', () async {
    final calls = <String>[];
    var syncCount = 0;
    var joined = false;

    final roomId = await joinGroupInviteThroughAs(
      invite: const GroupInviteContent(
        groupRoomId: '!group:example.test',
        groupName: '产品测试群',
      ),
      currentDirectRoomId: '!dm:example.test',
      joinGroup: ({
        required roomId,
        required groupName,
        required inviterMxid,
        required inviteEventId,
        required directRoomId,
      }) async {
        calls.add('join');
        return const AsGroupResult(
          roomId: '!joined:example.test',
          name: '产品测试群',
          memberCount: 2,
          invitedCount: 0,
          role: 'member',
        );
      },
      oneShotSync: () async {
        calls.add('sync');
        syncCount++;
        if (syncCount == 2) joined = true;
      },
      refreshBootstrap: () async => calls.add('refresh'),
      hasJoinedMatrixRoom: (roomId) =>
          joined && roomId == '!joined:example.test',
      roomSyncInterval: Duration.zero,
      roomSyncTimeout: const Duration(milliseconds: 50),
    );

    expect(roomId, '!joined:example.test');
    expect(calls, ['join', 'sync', 'refresh', 'sync', 'refresh']);
  });

  test('falls back to invite room id when AS returns empty room id', () async {
    final roomId = await joinGroupInviteThroughAs(
      invite: const GroupInviteContent(
        groupRoomId: '!group:p2p-im.com',
        groupName: '产品测试群',
        directRoomId: '!card-dm:p2p-im.com',
      ),
      currentDirectRoomId: '!current-dm:p2p-im.com',
      joinGroup: ({
        required roomId,
        required groupName,
        required inviterMxid,
        required inviteEventId,
        required directRoomId,
      }) async {
        expect(directRoomId, '!card-dm:p2p-im.com');
        return const AsGroupResult(
          roomId: '',
          name: '产品测试群',
          memberCount: 2,
          invitedCount: 0,
          role: 'member',
        );
      },
      oneShotSync: () async {},
      refreshBootstrap: () async {},
    );

    expect(roomId, '!group:p2p-im.com');
  });
}

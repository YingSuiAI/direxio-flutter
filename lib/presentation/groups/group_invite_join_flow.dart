import '../../data/as_client.dart';
import 'group_invite_content.dart';

typedef JoinGroupInviteRequest = Future<AsGroupResult> Function({
  required String roomId,
  required String groupName,
  required String inviterMxid,
  required String inviteEventId,
  required String directRoomId,
});

Future<String> joinGroupInviteThroughAs({
  required GroupInviteContent invite,
  required String currentDirectRoomId,
  required JoinGroupInviteRequest joinGroup,
  required Future<void> Function() oneShotSync,
  required Future<void> Function() refreshBootstrap,
}) async {
  final group = await joinGroup(
    roomId: invite.groupRoomId,
    groupName: invite.groupName,
    inviterMxid: invite.inviterMxid,
    inviteEventId: invite.inviteEventId,
    directRoomId:
        invite.directRoomId.isEmpty ? currentDirectRoomId : invite.directRoomId,
  );
  await oneShotSync();
  await refreshBootstrap();
  return group.roomId.isEmpty ? invite.groupRoomId : group.roomId;
}

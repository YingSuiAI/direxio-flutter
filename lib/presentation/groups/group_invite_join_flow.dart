import '../../data/as_client.dart';
import 'group_invite_content.dart';

typedef JoinGroupInviteRequest = Future<AsGroupResult> Function({
  required String roomId,
  required String groupName,
  required String inviterMxid,
  required String inviteEventId,
  required String directRoomId,
});

typedef HasJoinedMatrixRoom = bool Function(String roomId);

Future<AsGroupResult> joinGroupInviteThroughAs({
  required GroupInviteContent invite,
  required String currentDirectRoomId,
  required JoinGroupInviteRequest joinGroup,
  required Future<void> Function() oneShotSync,
  required Future<void> Function() refreshBootstrap,
  HasJoinedMatrixRoom? hasJoinedMatrixRoom,
  Duration roomSyncTimeout = const Duration(seconds: 20),
  Duration roomSyncInterval = const Duration(seconds: 2),
}) async {
  final joined = await joinGroup(
    roomId: invite.groupRoomId,
    groupName: invite.groupName,
    inviterMxid: invite.inviterMxid,
    inviteEventId: invite.inviteEventId,
    directRoomId:
        invite.directRoomId.isEmpty ? currentDirectRoomId : invite.directRoomId,
  );
  final joinedRoomId =
      joined.roomId.isEmpty ? invite.groupRoomId : joined.roomId;
  final group = joined.roomId.isEmpty
      ? AsGroupResult(
          roomId: joinedRoomId,
          name: joined.name,
          memberCount: joined.memberCount,
          invitedCount: joined.invitedCount,
          role: joined.role,
          status: joined.status,
          invitePolicy: joined.invitePolicy,
          productConversation: joined.productConversation,
        )
      : joined;
  if (hasJoinedMatrixRoom == null) {
    await oneShotSync();
    await refreshBootstrap();
    return group;
  }
  await waitForJoinedGroupMatrixRoom(
    roomId: joinedRoomId,
    oneShotSync: oneShotSync,
    refreshBootstrap: refreshBootstrap,
    hasJoinedMatrixRoom: hasJoinedMatrixRoom,
    timeout: roomSyncTimeout,
    interval: roomSyncInterval,
  );
  return group;
}

Future<bool> waitForJoinedGroupMatrixRoom({
  required String roomId,
  required Future<void> Function() oneShotSync,
  required Future<void> Function() refreshBootstrap,
  required HasJoinedMatrixRoom hasJoinedMatrixRoom,
  bool Function()? shouldContinue,
  Duration timeout = const Duration(seconds: 20),
  Duration interval = const Duration(seconds: 2),
}) async {
  final trimmedRoomId = roomId.trim();
  if (trimmedRoomId.isEmpty) return false;
  final deadline = DateTime.now().add(timeout);
  bool active() => shouldContinue?.call() ?? true;

  while (true) {
    if (!active()) return false;
    if (hasJoinedMatrixRoom(trimmedRoomId)) {
      await refreshBootstrap();
      return true;
    }
    try {
      if (!active()) return false;
      await oneShotSync();
    } on Object {
      // A failed sync is transient during federated joins. Keep polling until
      // the joined room is visible locally or the caller's timeout expires.
    }
    try {
      if (!active()) return false;
      await refreshBootstrap();
    } on Object {
      // Bootstrap is a projection cache; Matrix room visibility is the gate.
    }
    if (!active()) return false;
    if (hasJoinedMatrixRoom(trimmedRoomId)) return true;

    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) break;
    final delay = remaining < interval ? remaining : interval;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }
  if (!active()) return false;
  return hasJoinedMatrixRoom(trimmedRoomId);
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';

import '../providers/as_sync_cache_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../widgets/group_composite_avatar.dart';
import 'avatar_url.dart';
import 'direct_contact_status.dart';

class StableGroupAvatarMembers {
  const StableGroupAvatarMembers({
    required this.members,
    required this.memberOrder,
    required this.shouldPersistOrder,
  });

  final List<GroupCompositeAvatarMember> members;
  final List<String> memberOrder;
  final bool shouldPersistOrder;
}

StableGroupAvatarMembers stableGroupAvatarMembersForRoom({
  required Room room,
  required AsSyncCacheState syncCache,
  required List<String> cachedMemberOrder,
  Profile? currentUserProfile,
}) {
  final liveMemberIds = _liveGroupMemberIds(room);
  if (liveMemberIds.isEmpty) {
    return const StableGroupAvatarMembers(
      members: [],
      memberOrder: [],
      shouldPersistOrder: false,
    );
  }

  final resolvedOrder = _resolveStableMemberOrder(
    cachedMemberOrder: cachedMemberOrder,
    liveMemberOrder: liveMemberIds,
  );
  final states = room.states[EventTypes.RoomMember] ?? const {};
  final currentUserId = room.client.userID?.trim() ?? '';
  final members = <GroupCompositeAvatarMember>[];
  for (final mxid in resolvedOrder.take(9)) {
    final member = states[mxid]?.asUser(room);
    final memberAvatarUrl = member == null
        ? null
        : matrixContentHttpUrl(room.client, member.avatarUrl);
    final avatar = currentUserId.isNotEmpty && mxid == currentUserId
        ? profileAvatarHttpUrl(currentUserProfile, room.client) ??
            memberAvatarUrl ??
            strictGroupContactAvatarUrl(room.client, syncCache, mxid)
        : memberAvatarUrl ??
            strictGroupContactAvatarUrl(room.client, syncCache, mxid);
    members.add(
      GroupCompositeAvatarMember(
        seed: mxid,
        imageUrl: avatar,
      ),
    );
  }

  return StableGroupAvatarMembers(
    members: List.unmodifiable(members),
    memberOrder: List.unmodifiable(resolvedOrder),
    shouldPersistOrder: !_sameStringList(cachedMemberOrder, resolvedOrder),
  );
}

void scheduleGroupAvatarMemberOrderPersist(
  WidgetRef ref,
  String roomId,
  StableGroupAvatarMembers avatarMembers,
) {
  if (!avatarMembers.shouldPersistOrder) return;
  final trimmed = roomId.trim();
  if (trimmed.isEmpty) return;
  final order = avatarMembers.memberOrder;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!ref.context.mounted) return;
    setGroupAvatarMemberOrder(ref, trimmed, order);
  });
}

String? strictGroupContactAvatarUrl(
  Client client,
  AsSyncCacheState syncCache,
  String mxid,
) {
  final contact = syncCache.contactForUserId(mxid.trim());
  if (contact == null) return _strictClientDirectAvatarUrl(client, mxid);
  final directRoom = client.getRoomById(contact.roomId.trim());
  final memberState = directRoom?.getState(
    EventTypes.RoomMember,
    contact.userId.trim(),
  );
  if (directRoom != null && memberState != null) {
    final memberAvatar = matrixContentHttpUrl(
      client,
      memberState.asUser(directRoom).avatarUrl,
    );
    if (memberAvatar != null) return memberAvatar;
  }
  final profileAvatar = directRoom == null
      ? null
      : _strictDirectRoomProfileAvatarUrl(
          client,
          directRoom,
          contact.userId,
        );
  if (profileAvatar != null) return profileAvatar;
  return avatarHttpUrl(client, contact.avatarUrl) ??
      _strictClientDirectAvatarUrl(client, mxid);
}

List<String> _liveGroupMemberIds(Room room) {
  final out = <String>[];
  final seen = <String>{};
  final memberStates = room.states[EventTypes.RoomMember]?.values ??
      const <StrippedStateEvent>[];
  for (final state in memberStates) {
    final mxid = state.stateKey?.trim() ?? '';
    if (mxid.isEmpty || !seen.add(mxid)) continue;
    final member = state.asUser(room);
    if (member.membership != Membership.join &&
        member.membership != Membership.invite &&
        member.membership != Membership.knock) {
      continue;
    }
    out.add(mxid);
  }
  return List.unmodifiable(out);
}

List<String> _resolveStableMemberOrder({
  required List<String> cachedMemberOrder,
  required List<String> liveMemberOrder,
}) {
  final liveSet = liveMemberOrder.toSet();
  final cached = cachedMemberOrder
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  final cachedSet = cached.toSet();
  if (cached.length == cachedSet.length &&
      cachedSet.length == liveSet.length &&
      cachedSet.containsAll(liveSet)) {
    return cached;
  }

  final next = <String>[];
  final seen = <String>{};
  for (final mxid in cached) {
    if (liveSet.contains(mxid) && seen.add(mxid)) next.add(mxid);
  }
  for (final mxid in liveMemberOrder) {
    if (seen.add(mxid)) next.add(mxid);
  }
  return List.unmodifiable(next);
}

String? _strictDirectRoomProfileAvatarUrl(
  Client client,
  Room room,
  String mxid,
) {
  final content = room.getState(nativeRoomProfileEventType)?.content;
  if (content == null || content['room_type'] != nativeDirectRoomType) {
    return null;
  }
  final trimmed = mxid.trim();
  if (content['requester_mxid'] == trimmed ||
      content['target_mxid'] == trimmed) {
    return avatarHttpUrl(client, content['avatar_url'] as String?);
  }
  return null;
}

String? _strictClientDirectAvatarUrl(Client client, String mxid) {
  for (final room in client.rooms) {
    final profileAvatar = _strictDirectRoomProfileAvatarUrl(
      client,
      room,
      mxid,
    );
    if (profileAvatar != null) return profileAvatar;
    final content = room.getState(nativeRoomProfileEventType)?.content;
    if (content == null || content['room_type'] != nativeDirectRoomType) {
      continue;
    }
    final trimmed = mxid.trim();
    if (content['requester_mxid'] != trimmed &&
        content['target_mxid'] != trimmed) {
      continue;
    }
    final memberState = room.getState(EventTypes.RoomMember, trimmed);
    if (memberState == null) continue;
    final memberAvatar = matrixContentHttpUrl(
      client,
      memberState.asUser(room).avatarUrl,
    );
    if (memberAvatar != null) return memberAvatar;
  }
  return null;
}

bool _sameStringList(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

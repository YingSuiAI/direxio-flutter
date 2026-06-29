import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../widgets/group_composite_avatar.dart';
import 'avatar_url.dart';
import 'direct_contact_status.dart';

class StableGroupAvatarMembers {
  const StableGroupAvatarMembers({
    required this.members,
    required this.memberOrder,
    required this.memberAvatarUrls,
    required this.shouldPersistOrder,
    required this.shouldPersistAvatarUrls,
  });

  final List<GroupCompositeAvatarMember> members;
  final List<String> memberOrder;
  final Map<String, String> memberAvatarUrls;
  final bool shouldPersistOrder;
  final bool shouldPersistAvatarUrls;
}

StableGroupAvatarMembers stableGroupAvatarMembersForRoom({
  required Room room,
  required AsSyncCacheState syncCache,
  required List<String> cachedMemberOrder,
  Map<String, String> cachedMemberAvatarUrls = const {},
  List<AsGroupMember> authoritativeMembers = const [],
  Profile? currentUserProfile,
}) {
  final liveMemberIds = _liveGroupMemberIds(room);
  final authoritativeById = _authoritativeGroupMembersById(
    authoritativeMembers,
  );
  // groups.members is already backend-sorted; keep this order because older
  // projected members may legitimately have joinedAtMs == 0.
  final authoritativeOrder = authoritativeById.keys.toList(growable: false);
  if (liveMemberIds.isEmpty && authoritativeOrder.isEmpty) {
    final cached = cachedGroupAvatarMembers(
      cachedMemberOrder: cachedMemberOrder,
      cachedMemberAvatarUrls: cachedMemberAvatarUrls,
    );
    return StableGroupAvatarMembers(
      members: cached,
      memberOrder: cachedMemberOrder,
      memberAvatarUrls: _cleanMemberAvatarUrls(cachedMemberAvatarUrls),
      shouldPersistOrder: false,
      shouldPersistAvatarUrls: false,
    );
  }

  final resolvedOrder = authoritativeOrder.isEmpty
      ? _resolveStableMemberOrder(
          cachedMemberOrder: cachedMemberOrder,
          liveMemberOrder: liveMemberIds,
        )
      : _resolveAuthoritativeMemberOrder(
          authoritativeMemberOrder: authoritativeOrder,
          liveMemberOrder: liveMemberIds,
        );
  final states = room.states[EventTypes.RoomMember] ?? const {};
  final currentUserId = room.client.userID?.trim() ?? '';
  final members = <GroupCompositeAvatarMember>[];
  final avatarUrls = <String, String>{};
  for (final mxid in resolvedOrder.take(9)) {
    final authoritativeMember = authoritativeById[mxid.trim()];
    final member = states[mxid]?.asUser(room);
    final memberAvatarUrl = member == null
        ? null
        : matrixContentHttpUrl(room.client, member.avatarUrl);
    final authoritativeAvatarUrl = avatarHttpUrl(
      room.client,
      authoritativeMember?.avatarUrl,
    );
    final contactAvatarUrl = strictGroupContactAvatarUrl(
      room.client,
      syncCache,
      mxid,
    );
    final avatar = currentUserId.isNotEmpty && mxid == currentUserId
        ? profileAvatarHttpUrl(currentUserProfile, room.client) ??
            contactAvatarUrl ??
            authoritativeAvatarUrl ??
            memberAvatarUrl
        : contactAvatarUrl ??
            authoritativeAvatarUrl ??
            memberAvatarUrl ??
            cachedMemberAvatarUrls[mxid.trim()];
    final cleanAvatar = avatar?.trim() ?? '';
    if (cleanAvatar.isNotEmpty) avatarUrls[mxid.trim()] = cleanAvatar;
    members.add(
      GroupCompositeAvatarMember(
        seed: mxid,
        imageUrl: cleanAvatar.isEmpty ? null : cleanAvatar,
      ),
    );
  }

  return StableGroupAvatarMembers(
    members: List.unmodifiable(members),
    memberOrder: List.unmodifiable(resolvedOrder),
    memberAvatarUrls: Map.unmodifiable(avatarUrls),
    shouldPersistOrder: !_sameStringList(cachedMemberOrder, resolvedOrder),
    shouldPersistAvatarUrls: !_sameStringMap(
      _cleanMemberAvatarUrls(cachedMemberAvatarUrls),
      avatarUrls,
    ),
  );
}

List<GroupCompositeAvatarMember> cachedGroupAvatarMembers({
  required List<String> cachedMemberOrder,
  required Map<String, String> cachedMemberAvatarUrls,
}) {
  final avatars = _cleanMemberAvatarUrls(cachedMemberAvatarUrls);
  if (cachedMemberOrder.isEmpty || avatars.isEmpty) return const [];
  final members = <GroupCompositeAvatarMember>[];
  final seen = <String>{};
  for (final rawMemberId in cachedMemberOrder) {
    final memberId = rawMemberId.trim();
    if (memberId.isEmpty || !seen.add(memberId)) continue;
    members.add(
      GroupCompositeAvatarMember(
        seed: memberId,
        imageUrl: avatars[memberId],
      ),
    );
  }
  return List.unmodifiable(members);
}

void scheduleGroupAvatarMemberOrderPersist(
  WidgetRef ref,
  String roomId,
  StableGroupAvatarMembers avatarMembers,
) {
  if (!avatarMembers.shouldPersistOrder &&
      !avatarMembers.shouldPersistAvatarUrls) {
    return;
  }
  final trimmed = roomId.trim();
  if (trimmed.isEmpty) return;
  final order = avatarMembers.memberOrder;
  final avatarUrls = avatarMembers.memberAvatarUrls;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!ref.context.mounted) return;
    if (avatarMembers.shouldPersistOrder) {
      setGroupAvatarMemberOrder(ref, trimmed, order);
    }
    if (avatarMembers.shouldPersistAvatarUrls) {
      setGroupAvatarMemberAvatars(ref, trimmed, avatarUrls);
    }
  });
}

String? strictGroupContactAvatarUrl(
  Client client,
  AsSyncCacheState syncCache,
  String mxid,
) {
  final contact = syncCache.contactForUserId(mxid.trim());
  if (contact == null) return _strictClientDirectAvatarUrl(client, mxid);
  final contactAvatar = avatarHttpUrl(client, contact.avatarUrl);
  if (contactAvatar != null) return contactAvatar;
  final directRoom = client.getRoomById(contact.roomId.trim());
  final profileAvatar = directRoom == null
      ? null
      : _strictDirectRoomProfileAvatarUrl(
          client,
          directRoom,
          contact.userId,
        );
  if (profileAvatar != null) return profileAvatar;
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
  return _strictClientDirectAvatarUrl(client, mxid);
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
    if (member.membership != Membership.join) continue;
    out.add(mxid);
  }
  return List.unmodifiable(out);
}

Map<String, AsGroupMember> _authoritativeGroupMembersById(
  List<AsGroupMember> members,
) {
  final out = <String, AsGroupMember>{};
  for (final member in members) {
    final mxid = member.userMxid.trim();
    if (mxid.isEmpty || out.containsKey(mxid)) continue;
    if (!isAsChannelMemberJoined(member.status)) continue;
    out[mxid] = member;
  }
  return Map.unmodifiable(out);
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

List<String> _resolveAuthoritativeMemberOrder({
  required List<String> authoritativeMemberOrder,
  required List<String> liveMemberOrder,
}) {
  final next = <String>[];
  final seen = <String>{};
  for (final mxid in authoritativeMemberOrder) {
    final trimmed = mxid.trim();
    if (trimmed.isNotEmpty && seen.add(trimmed)) next.add(trimmed);
  }
  for (final mxid in liveMemberOrder) {
    final trimmed = mxid.trim();
    if (trimmed.isNotEmpty && seen.add(trimmed)) next.add(trimmed);
  }
  return List.unmodifiable(next);
}

List<User> sortGroupParticipantsByAuthoritativeMembers(
  List<User> members,
  List<AsGroupMember> authoritativeMembers,
) {
  if (members.isEmpty || authoritativeMembers.isEmpty) return members;
  final byId = {
    for (final member in members)
      if (member.id.trim().isNotEmpty) member.id.trim(): member,
  };
  final next = <User>[];
  final seen = <String>{};
  for (final member in authoritativeMembers) {
    final mxid = member.userMxid.trim();
    final user = byId[mxid];
    if (user != null && seen.add(mxid)) next.add(user);
  }
  for (final member in members) {
    final mxid = member.id.trim();
    if (mxid.isEmpty || seen.add(mxid)) next.add(member);
  }
  return List.unmodifiable(next);
}

AsGroupMember? authoritativeGroupMemberForUser(
  List<AsGroupMember> members,
  String userId,
) {
  final trimmed = userId.trim();
  if (trimmed.isEmpty) return null;
  for (final member in members) {
    if (member.userMxid.trim() == trimmed) return member;
  }
  return null;
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

Map<String, String> _cleanMemberAvatarUrls(Map<String, String> value) {
  return Map.unmodifiable({
    for (final entry in value.entries)
      if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
        entry.key.trim(): entry.value.trim(),
  });
}

bool _sameStringMap(Map<String, String> a, Map<String, String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

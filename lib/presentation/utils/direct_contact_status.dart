import 'package:matrix/matrix.dart';

import '../../data/well_known_service.dart';
import 'contact_identity_label.dart';

const nativeRoomProfileEventType = 'io.direxio.room.profile';
const nativeDirectRoomType = 'io.direxio.room.direct';
const nativeGroupRoomType = 'io.direxio.room.group';
const nativeChannelRoomType = 'io.direxio.room.channel';

String? serverNameFromMxid(String? mxid) {
  if (mxid == null) return null;
  final serverName = domainFromMxid(mxid);
  return serverName.isEmpty ? null : serverName;
}

String? portalAgentMxidForClient(Client client) {
  final serverName = serverNameFromMxid(client.userID);
  return serverName == null
      ? null
      : WellKnownService.agentMxidForDomain(serverName);
}

bool isPortalAgentDirectRoom(Room room, {String? agentMxid}) {
  final resolvedAgentMxid = agentMxid ?? portalAgentMxidForClient(room.client);
  return resolvedAgentMxid != null &&
      (room.directChatMatrixID == resolvedAgentMxid ||
          _summaryLooksLikeAgentDirectRoom(room, resolvedAgentMxid));
}

bool _summaryLooksLikeAgentDirectRoom(Room room, String agentMxid) {
  if (room.membership != Membership.join) return false;
  final heroes = room.summary.mHeroes ?? const <String>[];
  if (!heroes.contains(agentMxid)) return false;
  final joinedCount = room.summary.mJoinedMemberCount;
  return joinedCount == null || joinedCount <= 2;
}

String? productDirectPeerMxid(Room room) {
  final directMxid = room.directChatMatrixID;
  if (directMxid != null && directMxid.isNotEmpty) return directMxid;
  final nativePeerMxid = _nativeDirectPeerMxid(room);
  if (nativePeerMxid != null) return nativePeerMxid;
  final self = room.client.userID;
  final memberStates = room.states[EventTypes.RoomMember]?.values ??
      const <StrippedStateEvent>[];
  for (final state in memberStates) {
    final mxid = state.stateKey;
    if (mxid == null || mxid.isEmpty || mxid == self) continue;
    if (mxid.startsWith('@') && mxid.contains(':')) return mxid;
  }
  final creator = room.getState(EventTypes.RoomCreate)?.senderId;
  if (creator != null && creator != self) return creator;
  return null;
}

String? productDirectPeerDisplayName(Room room) {
  final peerMxid = productDirectPeerMxid(room);
  final profile = _nativeDirectProfile(room);
  if (peerMxid == null || profile == null) return null;
  if (_profileString(profile, 'requester_mxid') != peerMxid) return null;
  return _profileString(profile, 'display_name');
}

String? productDirectPeerAvatarUrl(Room room) {
  final peerMxid = productDirectPeerMxid(room);
  final profile = _nativeDirectProfile(room);
  if (peerMxid == null || profile == null) return null;
  if (_profileString(profile, 'requester_mxid') != peerMxid &&
      _profileString(profile, 'target_mxid') != peerMxid) {
    return null;
  }
  return _profileString(profile, 'avatar_url');
}

String? productDirectPeerDomain(Room room) {
  final peerMxid = productDirectPeerMxid(room);
  final profile = _nativeDirectProfile(room);
  if (peerMxid == null || profile == null) return null;
  if (_profileString(profile, 'requester_mxid') != peerMxid) return null;
  return _profileString(profile, 'domain');
}

Membership? directChatPeerMembership(Room room) {
  final peerMxid = productDirectPeerMxid(room);
  if (peerMxid == null) return null;
  return room
      .getState(EventTypes.RoomMember, peerMxid)
      ?.asUser(room)
      .membership;
}

String? joinedPersonPeerMxid(Room room, {String? agentMxid}) {
  if (room.membership != Membership.join) return null;
  final self = room.client.userID;
  final resolvedAgentMxid = agentMxid ?? portalAgentMxidForClient(room.client);
  final memberStates = room.states[EventTypes.RoomMember]?.values ??
      const <StrippedStateEvent>[];
  final peers = <String>[];
  for (final state in memberStates) {
    final mxid = state.stateKey;
    if (mxid == null || mxid.isEmpty || mxid == self) continue;
    if (resolvedAgentMxid != null && mxid == resolvedAgentMxid) continue;
    if (state.asUser(room).membership == Membership.join) {
      peers.add(mxid);
    }
  }
  return peers.length == 1 ? peers.single : null;
}

bool isProductDirectContactRoom(
  Room room, {
  String? agentMxid,
  Set<String> acceptedRoomIds = const {},
}) {
  if (isPortalAgentDirectRoom(room, agentMxid: agentMxid)) return false;
  if (acceptedRoomIds.contains(room.id)) return true;
  if (_nativeDirectProfile(room) != null) return true;
  return room.isDirectChat;
}

bool isAcceptedDirectContact(
  Room room, {
  String? agentMxid,
  Set<String> acceptedRoomIds = const {},
}) {
  if (room.membership != Membership.join) return false;
  if (acceptedRoomIds.contains(room.id)) return true;
  if (!isProductDirectContactRoom(room, agentMxid: agentMxid)) return false;
  return directChatPeerMembership(room) == Membership.join;
}

bool isPendingDirectContact(Room room, {String? agentMxid}) {
  if (room.membership != Membership.join) return false;
  if (!isProductDirectContactRoom(room, agentMxid: agentMxid)) return false;
  return directChatPeerMembership(room) == Membership.invite;
}

bool isIncomingDirectContactInvite(Room room, {String? agentMxid}) {
  if (room.membership != Membership.invite) return false;
  if (!isProductDirectContactRoom(room, agentMxid: agentMxid)) return false;
  return productDirectPeerMxid(room) != null;
}

bool canSendDirectChatMessage(
  Room room, {
  String? agentMxid,
  Set<String> acceptedRoomIds = const {},
}) {
  if (isPortalAgentDirectRoom(room, agentMxid: agentMxid)) return true;
  if (!isProductDirectContactRoom(
    room,
    agentMxid: agentMxid,
    acceptedRoomIds: acceptedRoomIds,
  )) {
    return room.membership == Membership.join;
  }
  return isAcceptedDirectContact(
    room,
    agentMxid: agentMxid,
    acceptedRoomIds: acceptedRoomIds,
  );
}

Map<String, dynamic>? _nativeDirectProfile(Room room) {
  final content = room.getState(nativeRoomProfileEventType)?.content;
  if (content == null) return null;
  final roomType = _profileString(content, 'room_type');
  if (roomType != nativeDirectRoomType) return null;
  return content;
}

String? _nativeDirectPeerMxid(Room room) {
  final profile = _nativeDirectProfile(room);
  if (profile == null) return null;
  final self = room.client.userID?.trim();
  final requester = _profileString(profile, 'requester_mxid');
  final target = _profileString(profile, 'target_mxid');
  if (self != null && self.isNotEmpty) {
    if (requester == self && target != null && target.isNotEmpty) {
      return target;
    }
    if (target == self && requester != null && requester.isNotEmpty) {
      return requester;
    }
  }
  if (requester != null && requester.isNotEmpty) return requester;
  if (target != null && target.isNotEmpty) return target;
  return null;
}

String? _profileString(Map<String, dynamic> content, String key) {
  final value = content[key];
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

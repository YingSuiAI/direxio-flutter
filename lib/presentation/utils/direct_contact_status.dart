import 'package:matrix/matrix.dart';

import '../../data/well_known_service.dart';
import 'contact_identity_label.dart';

const productRoomKindEventType = 'p2p.room.kind';

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
  return _productRoomKind(room) == 'agent' ||
      (resolvedAgentMxid != null &&
          (room.directChatMatrixID == resolvedAgentMxid ||
              _summaryLooksLikeAgentDirectRoom(room, resolvedAgentMxid)));
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
  if (_productRoomKind(room) != 'direct') return null;
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
  if (_productRoomKind(room) == 'direct') return true;
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

String _productRoomKind(Room room) {
  final raw = room.getState(productRoomKindEventType)?.content['kind'];
  return raw is String ? raw.trim() : '';
}

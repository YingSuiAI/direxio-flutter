import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import 'contact_identity_label.dart';

String directPeerMemberDisplayName(Room? room, String? peerMxid) {
  final peerId = peerMxid?.trim() ?? '';
  if (room == null || peerId.isEmpty) return '';
  final memberEvent = room.getState(EventTypes.RoomMember, peerId);
  final displayName = memberEvent?.content.tryGet<String>('displayname');
  return displayName?.trim() ?? '';
}

String safeRoomDisplayName(Room? room) {
  if (room == null) return '';
  final roomName = room
      .getState(EventTypes.RoomName)
      ?.content
      .tryGet<String>('name')
      ?.trim();
  if (roomName != null && roomName.isNotEmpty) return roomName;
  return room.id.trim();
}

String directContactDisplayName(
  AsSyncContact? contact,
  Room room, {
  String? peerMxid,
}) {
  final identity = contact?.userId.trim().isNotEmpty == true
      ? contact!.userId
      : peerMxid ?? '';
  final contactName = contact?.displayName.trim() ?? '';
  final memberName = directPeerMemberDisplayName(room, identity);
  final label = contactDisplayNameFromIdentity(
    mxid: identity,
    displayName: contactName.isNotEmpty ? contactName : memberName,
    domain: contact?.domain ?? '',
  );
  if (label.isNotEmpty) return label;
  return safeRoomDisplayName(room);
}

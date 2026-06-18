import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import 'contact_identity_label.dart';

String directPeerMemberDisplayName(Room? room, String? peerMxid) {
  final peerId = peerMxid?.trim() ?? '';
  if (room == null || peerId.isEmpty) return '';
  return room.unsafeGetUserFromMemoryOrFallback(peerId).displayName?.trim() ??
      '';
}

String directContactDisplayName(
  AsSyncContact? contact,
  Room room, {
  String? peerMxid,
}) {
  final identity = contact?.userId.trim().isNotEmpty == true
      ? contact!.userId
      : peerMxid ?? '';
  final memberName = directPeerMemberDisplayName(room, identity);
  final label = contactDisplayNameFromIdentity(
    mxid: identity,
    displayName:
        memberName.isNotEmpty ? memberName : contact?.displayName ?? '',
    domain: contact?.domain ?? '',
  );
  if (label.isNotEmpty) return label;
  return room.getLocalizedDisplayname();
}

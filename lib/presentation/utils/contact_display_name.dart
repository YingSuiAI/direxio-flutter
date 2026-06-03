import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import 'contact_identity_label.dart';

String directContactDisplayName(
  AsSyncContact? contact,
  Room room, {
  String? peerMxid,
}) {
  final identity = contact?.userId.trim().isNotEmpty == true
      ? contact!.userId
      : peerMxid ?? '';
  final label = contactDisplayNameFromIdentity(
    mxid: identity,
    displayName: contact?.displayName ?? '',
    domain: contact?.domain ?? '',
  );
  if (label.isNotEmpty) return label;
  return room.getLocalizedDisplayname();
}

import 'package:matrix/matrix.dart';

import 'contact_display_name.dart';
import 'contact_identity_label.dart';
import 'direct_contact_status.dart';

const defaultAgentDisplayName = 'Agent';
const agentAvatarAsset = 'assets/images/ai_icon.png';

String agentDisplayNameForRoom(
  Room? room, {
  Client? client,
  String fallbackTitle = '',
}) {
  final effectiveClient = room?.client ?? client;
  final agentMxid = effectiveClient == null
      ? null
      : portalAgentMxidForClient(effectiveClient);
  final memberName = directPeerMemberDisplayName(room, agentMxid);
  if (_isMeaningfulAgentName(memberName, agentMxid)) return memberName;

  final roomName = safeRoomDisplayName(room);
  if (_isMeaningfulAgentName(roomName, agentMxid) && roomName != room?.id) {
    return roomName;
  }

  final productTitle = fallbackTitle.trim();
  if (_isMeaningfulAgentName(productTitle, agentMxid)) return productTitle;

  return defaultAgentDisplayName;
}

bool _isMeaningfulAgentName(String value, String? agentMxid) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  if (agentMxid != null && trimmed == agentMxid.trim()) return false;
  if (agentMxid != null && trimmed == localpartFromMxid(agentMxid)) {
    return false;
  }
  return true;
}

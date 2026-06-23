import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import '../utils/avatar_url.dart';

String? channelMemberAvatarUrl(
  Client client,
  AsChannelMember member, {
  String roomId = '',
}) {
  final asAvatar = avatarHttpUrl(client, member.avatarUrl);
  if (asAvatar != null) return asAvatar;

  final mxid = member.userMxid.trim();
  final room = roomId.trim().isEmpty ? null : client.getRoomById(roomId.trim());
  if (room == null || mxid.isEmpty) return null;
  final user = room.unsafeGetUserFromMemoryOrFallback(mxid);
  return matrixContentHttpUrl(client, user.avatarUrl);
}

import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import '../utils/avatar_url.dart';
import '../utils/user_profile_directory.dart';

String? channelMemberAvatarUrl(
  Client client,
  AsChannelMember member, {
  String roomId = '',
}) {
  final directory = UserProfileDirectory.fromSources(
    client: client,
    extraChannelMembers: [member],
  );
  final resolved = directory.avatarUrlFor(
    member.userMxid,
    fallbackAvatarUrl: member.avatarUrl,
  );
  if (resolved != null) return resolved;

  final room = roomId.trim().isEmpty ? null : client.getRoomById(roomId.trim());
  final mxid = member.userMxid.trim();
  if (room == null || mxid.isEmpty) return null;
  return matrixContentHttpUrl(
    client,
    room.unsafeGetUserFromMemoryOrFallback(mxid).avatarUrl,
  );
}

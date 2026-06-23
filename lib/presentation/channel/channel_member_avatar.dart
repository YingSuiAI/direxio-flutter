import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import '../utils/avatar_url.dart';
import '../utils/user_profile_directory.dart';

String? channelMemberAvatarUrl(
  Client client,
  AsChannelMember member, {
  String roomId = '',
  UserProfileDirectory? directory,
  String fallbackAvatarUrl = '',
}) {
  final asAvatar = avatarHttpUrl(client, member.avatarUrl);
  if (asAvatar != null) return asAvatar;

  final mxid = member.userMxid.trim();
  if (mxid.isNotEmpty) {
    for (final id in <String>{roomId.trim(), member.roomId.trim()}) {
      if (id.isEmpty) continue;
      final room = client.getRoomById(id);
      if (room == null) continue;
      final roomMemberAvatar = matrixContentHttpUrl(
        client,
        room.unsafeGetUserFromMemoryOrFallback(mxid).avatarUrl,
      );
      if (roomMemberAvatar != null) return roomMemberAvatar;
    }
  }

  final resolvedDirectory = directory ??
      UserProfileDirectory.fromSources(
        client: client,
        extraChannelMembers: [member],
      );
  final directoryAvatar = resolvedDirectory.avatarUrlFor(
    member.userMxid,
    fallbackAvatarUrl:
        fallbackAvatarUrl.trim().isEmpty ? member.avatarUrl : fallbackAvatarUrl,
  );
  return avatarHttpUrl(client, directoryAvatar);
}

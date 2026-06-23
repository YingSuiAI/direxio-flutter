import '../../data/as_client.dart';

AsConversation? productConversationForRoom(
  Iterable<AsConversation> conversations,
  String roomId, {
  Set<String>? kinds,
}) {
  final targetRoomId = roomId.trim();
  if (targetRoomId.isEmpty) return null;
  for (final conversation in conversations) {
    if (conversation.roomId.trim() != targetRoomId) continue;
    if (kinds != null && !kinds.contains(conversation.kind)) continue;
    return conversation;
  }
  return null;
}

AsConversation? productDirectConversationForPeer(
  Iterable<AsConversation> conversations, {
  required String peerMxid,
  String roomId = '',
}) {
  final targetPeer = peerMxid.trim();
  final targetRoomId = roomId.trim();
  for (final conversation in conversations) {
    if (!conversation.isDirect) continue;
    if (targetRoomId.isNotEmpty && conversation.roomId.trim() == targetRoomId) {
      return conversation;
    }
    if (targetPeer.isNotEmpty && conversation.peerMxid.trim() == targetPeer) {
      return conversation;
    }
  }
  return null;
}

String channelConversationRoute(
  String channelIdOrRoomId, {
  String conversationId = '',
  String name = '',
}) {
  final channelId = channelIdOrRoomId.trim();
  final queryParameters = <String, String>{};
  final cleanConversationId = conversationId.trim();
  final cleanName = name.trim();
  if (cleanConversationId.isNotEmpty) {
    queryParameters['conversation'] = cleanConversationId;
  }
  if (cleanName.isNotEmpty) queryParameters['name'] = cleanName;
  final query = queryParameters.isEmpty
      ? ''
      : '?${Uri(queryParameters: queryParameters).query}';
  return '/channel/${Uri.encodeComponent(channelId)}/conversation$query';
}

String? joinedTextChannelConversationRoute({
  required String channelId,
  required String roomId,
  required String memberStatus,
  required String channelType,
  String conversationId = '',
  String name = '',
}) {
  if (normalizeAsChannelType(channelType) != asChannelTypeChat) return null;
  if (!isAsChannelMemberJoined(memberStatus)) return null;
  final routeId = channelId.trim().isEmpty ? roomId.trim() : channelId.trim();
  if (routeId.isEmpty) return null;
  return channelConversationRoute(
    routeId,
    conversationId: conversationId,
    name: name,
  );
}

String? productConversationRoute(
  AsConversation? conversation, {
  String channelId = '',
}) {
  if (conversation == null) return null;
  final roomId = conversation.roomId.trim();
  if (roomId.isEmpty) return null;
  if (!conversation.canOpen) return null;
  final conversationId = conversation.conversationId.trim();
  if (conversation.kind == asConversationKindChannel) {
    final routeId = channelId.trim().isEmpty ? roomId : channelId.trim();
    if (routeId.isEmpty) return null;
    return channelConversationRoute(
      routeId,
      conversationId: conversationId,
      name: conversation.title,
    );
  }
  final base = switch (conversation.kind) {
    asConversationKindDirect || asConversationKindAgent => '/chat',
    asConversationKindGroup => '/group',
    _ => '',
  };
  if (base.isEmpty) return null;
  final route = '$base/${Uri.encodeComponent(roomId)}';
  if (conversationId.isEmpty) return route;
  final query = Uri(
    queryParameters: {'conversation': conversationId},
  ).query;
  return '$route?$query';
}

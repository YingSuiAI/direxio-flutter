import 'package:matrix/matrix.dart';

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

String? productConversationRoute(AsConversation? conversation) {
  if (conversation == null) return null;
  final roomId = conversation.roomId.trim();
  if (roomId.isEmpty) return null;
  if (!conversation.canOpen) return null;
  final base = switch (conversation.kind) {
    asConversationKindDirect || asConversationKindAgent => '/chat',
    asConversationKindGroup || asConversationKindChannel => '/group',
    _ => '',
  };
  if (base.isEmpty) return null;
  final route = '$base/${Uri.encodeComponent(roomId)}';
  final conversationId = conversation.conversationId.trim();
  if (conversationId.isEmpty) return route;
  final query = Uri(
    queryParameters: {'conversation': conversationId},
  ).query;
  return '$route?$query';
}

String? productConversationRouteForRoom({
  required Room room,
  required Iterable<AsConversation> conversations,
}) {
  final conversation = productConversationForRoom(conversations, room.id);
  if (conversation != null) return productConversationRoute(conversation);

  final roomId = room.id.trim();
  if (roomId.isEmpty) return null;
  final base = room.isDirectChat ? '/chat' : '/group';
  return '$base/${Uri.encodeComponent(roomId)}';
}

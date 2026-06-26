import 'package:matrix/matrix.dart';

import '../providers/as_sync_cache_provider.dart';
import '../utils/direct_contact_status.dart';

bool isBootstrapAgentRoom(Room room, AsSyncCacheState syncCache) {
  final roomId = room.id.trim();
  if (roomId.isEmpty) return false;
  return (syncCache.bootstrap?.agentRoomId.trim() ?? '') == roomId;
}

bool isProductDirectRoomForChatPolicy(
  Room room,
  AsSyncCacheState syncCache,
) {
  return isProductDirectContactRoom(
        room,
        acceptedRoomIds: syncCache.acceptedDirectRoomIds,
      ) ||
      syncCache.contactStatusForRoom(room.id) != null ||
      joinedPersonPeerMxid(room) != null;
}

bool canSendPrivateRoomMessage(Room room, AsSyncCacheState syncCache) {
  if (isPortalAgentDirectRoom(room) || isBootstrapAgentRoom(room, syncCache)) {
    return true;
  }
  final isProductDirect = isProductDirectRoomForChatPolicy(room, syncCache);
  if (!isProductDirect) return room.membership == Membership.join;
  if (syncCache.acceptedDirectRoomIds.contains(room.id)) return true;
  return syncCache.isPendingContactRoom(room.id) &&
      joinedPersonPeerMxid(room) != null;
}

Future<void> sendAgentRoomText(
  Room room,
  String text, {
  Event? inReplyTo,
}) async {
  final content = <String, Object?>{
    'msgtype': MessageTypes.Text,
    'body': text,
    if (inReplyTo?.eventId.trim().isNotEmpty ?? false)
      'm.relates_to': {
        'm.in_reply_to': {'event_id': inReplyTo!.eventId},
      },
  };
  await room.client.sendMessage(
    room.id,
    EventTypes.Message,
    room.client.generateUniqueTransactionId(),
    content,
  );
}

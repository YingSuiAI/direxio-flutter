import '../../data/as_client.dart';

AsSyncBootstrap applyLocalReadMarkersToBootstrap(
  AsSyncBootstrap bootstrap,
  Map<String, DateTime> readMarkers,
) {
  if (readMarkers.isEmpty) return bootstrap;

  List<AsSyncRoomSummary> apply(List<AsSyncRoomSummary> rooms) {
    return rooms.map((room) {
      final readAt = readMarkers[room.roomId.trim()];
      if (readAt == null || room.unreadCount <= 0) return room;
      final lastActivityAt = room.lastActivityAt?.toUtc();
      if (lastActivityAt != null && lastActivityAt.isAfter(readAt.toUtc())) {
        return room;
      }
      return room.withUnreadCount(0);
    }).toList(growable: false);
  }

  return AsSyncBootstrap(
    syncedAt: bootstrap.syncedAt,
    user: bootstrap.user,
    agentRoomId: bootstrap.agentRoomId,
    rooms: apply(bootstrap.rooms),
    contacts: bootstrap.contacts,
    groups: apply(bootstrap.groups),
    channels: apply(bootstrap.channels),
    pending: bootstrap.pending,
  );
}

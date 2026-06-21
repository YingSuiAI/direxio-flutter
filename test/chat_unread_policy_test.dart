import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/chat/chat_unread_policy.dart';

void main() {
  test('local read markers clear stale AS unread summaries', () {
    const roomId = '!room:p2p-im.com';
    final readAt = DateTime.utc(2026, 6, 22, 10);
    final bootstrap = _bootstrap(
      rooms: [
        _room(roomId, unread: 3, lastActivityAt: readAt),
      ],
      groups: [
        _room(roomId, unread: 2, lastActivityAt: readAt),
      ],
      channels: [
        _room(roomId, unread: 4, lastActivityAt: readAt),
      ],
    );

    final next = applyLocalReadMarkersToBootstrap(
      bootstrap,
      {roomId: readAt},
    );

    expect(next.rooms.single.unreadCount, 0);
    expect(next.groups.single.unreadCount, 0);
    expect(next.channels.single.unreadCount, 0);
  });

  test('newer AS activity keeps unread after a local read marker', () {
    const roomId = '!room:p2p-im.com';
    final readAt = DateTime.utc(2026, 6, 22, 10);
    final bootstrap = _bootstrap(
      groups: [
        _room(
          roomId,
          unread: 2,
          lastActivityAt: readAt.add(const Duration(seconds: 1)),
        ),
      ],
    );

    final next = applyLocalReadMarkersToBootstrap(
      bootstrap,
      {roomId: readAt},
    );

    expect(next.groups.single.unreadCount, 2);
  });
}

AsSyncBootstrap _bootstrap({
  List<AsSyncRoomSummary> rooms = const [],
  List<AsSyncRoomSummary> groups = const [],
  List<AsSyncRoomSummary> channels = const [],
}) {
  return AsSyncBootstrap(
    syncedAt: DateTime.utc(2026, 6, 22),
    user: const AsSyncUser(userId: '@owner:p2p-im.com'),
    rooms: rooms,
    contacts: const [],
    groups: groups,
    channels: channels,
    pending: const AsSyncPending.empty(),
  );
}

AsSyncRoomSummary _room(
  String roomId, {
  required int unread,
  DateTime? lastActivityAt,
}) {
  return AsSyncRoomSummary(
    roomId: roomId,
    name: roomId,
    avatarUrl: '',
    unreadCount: unread,
    lastActivityAt: lastActivityAt,
  );
}

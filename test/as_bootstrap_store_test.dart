import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_bootstrap_store.dart';
import 'package:portal_app/data/as_client.dart';

void main() {
  late Directory tempDir;
  late FileAsBootstrapStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('portal_bootstrap_store');
    store = FileAsBootstrapStore(File('${tempDir.path}/bootstrap.json'));
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('write and read persists AS product metadata without messages',
      () async {
    await store.write(_bootstrap(
      contactRoomId: '!old:p2p-im.com',
      deletedEventIds: const [r'$deleted'],
      visibleAfterTs: 1710000000000,
    ));

    final loaded = await store.read();

    expect(loaded, isNotNull);
    expect(loaded!.contacts.single.roomId, '!old:p2p-im.com');
    expect(loaded.contacts.single.visibleAfterTs, 1710000000000);
    expect(loaded.contacts.single.deletedEventIds, [r'$deleted']);
    expect(loaded.rooms.single.name, 'Yanan');
    expect(loaded.pending.friendRequests.single.title, 'Alice');
  });

  test('write replaces the snapshot instead of appending stale contacts',
      () async {
    await store.write(_bootstrap(contactRoomId: '!old:p2p-im.com'));
    await store.write(_bootstrap(contactRoomId: '!new:p2p-im.com'));

    final loaded = await store.read();

    expect(loaded!.contacts.map((contact) => contact.roomId), [
      '!new:p2p-im.com',
    ]);
  });

  test('read returns null for missing or corrupt cache', () async {
    expect(await store.read(), isNull);

    await File('${tempDir.path}/bootstrap.json').writeAsString('{bad json');

    expect(await store.read(), isNull);
  });

  test('parses contact peer_mxid from message-server bootstrap', () {
    final bootstrap = AsSyncBootstrap.fromJson({
      'synced_at': '2026-06-19T00:00:00Z',
      'user': {'user_id': '@owner:dendrite-b:8448'},
      'rooms': [],
      'contacts': [
        {
          'peer_mxid': '@owner:dendrite-a:8448',
          'display_name': 'owner',
          'domain': 'dendrite-a:8448',
          'room_id': '!request:dendrite-a:8448',
          'status': 'pending_inbound',
          'remark': '我是 Bob',
        }
      ],
      'groups': [],
      'channels': [],
      'pending': {
        'friend_requests': [],
        'group_invites': [],
        'channel_notices': [],
      },
    });

    expect(bootstrap.contacts.single.userId, '@owner:dendrite-a:8448');
    expect(bootstrap.contacts.single.status, 'pending_inbound');
    expect(bootstrap.contacts.single.remark, '我是 Bob');
  });
}

AsSyncBootstrap _bootstrap({
  required String contactRoomId,
  int visibleAfterTs = 0,
  List<String> deletedEventIds = const [],
}) {
  return AsSyncBootstrap(
    syncedAt: DateTime.parse('2026-05-28T08:00:00Z'),
    user: const AsSyncUser(userId: '@owner:p2p-im.com'),
    rooms: const [
      AsSyncRoomSummary(
        roomId: '!agent:p2p-im.com',
        name: 'Yanan',
        avatarUrl: 'mxc://p2p-im.com/a',
        unreadCount: 1,
        lastActivityAt: null,
      ),
    ],
    contacts: [
      AsSyncContact(
        userId: '@owner:p2p-liyanan.com',
        displayName: 'Yanan',
        avatarUrl: 'mxc://p2p-liyanan.com/a',
        roomId: contactRoomId,
        domain: 'p2p-liyanan.com',
        status: 'accepted',
        visibleAfterTs: visibleAfterTs,
        deletedEventIds: deletedEventIds,
      ),
    ],
    groups: const [],
    channels: const [],
    pending: const AsSyncPending(
      friendRequests: [
        AsSyncPendingItem(
          id: '!request:p2p-im.com',
          title: 'Alice',
          createdAt: null,
          remark: '请通过一下',
        ),
      ],
      groupInvites: [],
      channelNotices: [],
    ),
  );
}

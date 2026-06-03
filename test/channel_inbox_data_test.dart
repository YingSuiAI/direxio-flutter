import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/channel/channel_inbox_data.dart';

void main() {
  test('builds inbox items from bootstrap channel metadata', () {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-05-26T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          roomId: '!older:p2p-im.com',
          name: '去中心化部署互助',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-05-26T09:30:00Z'),
          topic: '证书、反代和 VPS 部署经验',
          isOwned: false,
          tags: const ['部署', '安全'],
        ),
        AsSyncRoomSummary(
          roomId: '!newer:p2p-im.com',
          name: '产品公告',
          avatarUrl: '',
          unreadCount: 2,
          lastActivityAt: DateTime.parse('2026-05-26T10:20:00Z'),
          topic: '只发布重要产品更新',
          isOwned: true,
          tags: const ['产品', '公告'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    final items = ChannelInboxData.fromBootstrap(
      bootstrap,
      fallbackDomain: 'p2p-im.com',
    );

    expect(items.map((item) => item.id),
        ['!newer:p2p-im.com', '!older:p2p-im.com']);
    expect(items.first.name, '产品公告');
    expect(items.first.domain, 'p2p-im.com');
    expect(items.first.latestPreview, '只发布重要产品更新');
    expect(items.first.unreadCount, 2);
    expect(items.first.isOwned, isTrue);
    expect(items.first.tags, ['产品', '公告']);
  });

  test('builds categories and filters owned or tagged channels', () {
    final items = [
      ChannelInboxItem(
        id: '!owned:p2p-im.com',
        name: '产品公告',
        domain: 'p2p-im.com',
        avatarUrl: '',
        latestPreview: '只发布重要产品更新',
        latestAt: DateTime.parse('2026-05-26T10:20:00Z'),
        unreadCount: 0,
        isOwned: true,
        tags: const ['产品', '公告'],
      ),
      ChannelInboxItem(
        id: '!joined:p2p-im.com',
        name: '部署互助',
        domain: 'p2p-im.com',
        avatarUrl: '',
        latestPreview: '证书和 VPS 部署经验',
        latestAt: DateTime.parse('2026-05-26T09:30:00Z'),
        unreadCount: 0,
        isOwned: false,
        tags: const ['部署'],
      ),
    ];

    expect(
        ChannelInboxData.categories(items), ['全部', '我的频道', '产品', '公告', '部署']);
    expect(
      ChannelInboxData.filtered(items, '我的频道').map((item) => item.id),
      ['!owned:p2p-im.com'],
    );
    expect(
      ChannelInboxData.filtered(items, '部署').map((item) => item.id),
      ['!joined:p2p-im.com'],
    );
  });
}

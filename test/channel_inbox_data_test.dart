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
          channelId: 'ch_older',
          roomId: '!older:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '去中心化部署互助',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-05-26T09:30:00Z'),
          topic: '证书、反代和 VPS 部署经验',
          isOwned: false,
          tags: const ['部署', '安全'],
        ),
        AsSyncRoomSummary(
          channelId: 'ch_newer',
          roomId: '!newer:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '产品公告',
          avatarUrl: '',
          unreadCount: 2,
          lastActivityAt: DateTime.parse('2026-05-26T10:20:00Z'),
          topic: '只发布重要产品更新',
          isOwned: true,
          channelType: asChannelTypePost,
          tags: const ['产品', '公告'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    final items = ChannelInboxData.fromBootstrap(
      bootstrap,
      fallbackDomain: 'p2p-im.com',
    );

    expect(items.map((item) => item.id), ['ch_newer', 'ch_older']);
    expect(items.first.roomId, '!newer:p2p-im.com');
    expect(items.first.name, '产品公告');
    expect(items.first.domain, 'p2p-im.com');
    expect(items.first.latestPreview, '只发布重要产品更新');
    expect(items.first.unreadCount, 2);
    expect(items.first.isOwned, isTrue);
    expect(items.first.channelType, asChannelTypePost);
    expect(items.first.tags, ['产品', '公告']);
  });

  test('builds categories and filters owned or tagged channels', () {
    final items = [
      ChannelInboxItem(
        id: 'ch_owned',
        roomId: '!owned:p2p-im.com',
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
        id: 'ch_joined',
        roomId: '!joined:p2p-im.com',
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
      ['ch_owned'],
    );
    expect(
      ChannelInboxData.filtered(items, '部署').map((item) => item.id),
      ['ch_joined'],
    );
  });

  test('treats bootstrap owner role as owned channel', () {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-17T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_owner_role',
          roomId: '!owner-role:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '综合讨论',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-17T10:20:00Z'),
          isOwned: false,
          role: asChannelRoleOwner,
          channelType: asChannelTypePost,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    final items = ChannelInboxData.fromBootstrap(
      bootstrap,
      fallbackDomain: 'p2p-im.com',
    );

    expect(items.single.isOwned, isTrue);
    expect(items.single.channelType, asChannelTypePost);
  });

  test('ignores non-channel rooms from AS channel list results', () {
    final items = ChannelInboxData.fromChannels(
      [
        const AsChannel(
          channelId: '',
          roomId: '!direct:p2p-im.com',
          name: 'Alice',
          description: '刚刚发给用户的消息',
        ),
        AsChannel(
          channelId: 'ch_product',
          roomId: '!channel:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '产品公告',
          description: '只发布重要产品更新',
          channelType: asChannelTypePost,
          role: asChannelRoleOwner,
          latestActivityAt: DateTime.parse('2026-06-17T09:30:00Z'),
        ),
      ],
      fallbackDomain: 'p2p-im.com',
    );

    expect(items.map((item) => item.id), ['ch_product']);
    expect(items.single.latestPreview, '只发布重要产品更新');
    expect(items.single.name, '产品公告');
    expect(items.single.channelType, asChannelTypePost);
  });

  test('uses bootstrap metadata when channel list returns room id as name', () {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-17T10:30:00Z'),
      user: const AsSyncUser(userId: '@member:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_joined',
          roomId: '!joined:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '部署互助',
          avatarUrl: 'mxc://p2p-im.com/channel-avatar',
          unreadCount: 3,
          lastActivityAt: DateTime.parse('2026-06-17T09:30:00Z'),
          description: '证书和 VPS 部署经验',
          isOwned: false,
          tags: const ['文字'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    final items = ChannelInboxData.fromChannels(
      [
        const AsChannel(
          channelId: 'ch_joined',
          roomId: '!joined:p2p-im.com',
          name: '!joined:p2p-im.com',
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
        ),
      ],
      fallbackDomain: 'p2p-im.com',
      bootstrap: bootstrap,
    );

    expect(items.single.name, '部署互助');
    expect(items.single.roomId, '!joined:p2p-im.com');
    expect(items.single.unreadCount, 3);
    expect(items.single.latestPreview, '证书和 VPS 部署经验');
    expect(items.single.avatarUrl, 'mxc://p2p-im.com/channel-avatar');
    expect(items.single.tags, ['文字']);
  });

  test('uses room_name for chat channel list display name', () {
    final items = ChannelInboxData.fromChannels(
      [
        AsChannel.fromJson({
          'channel_id': 'ch_chat',
          'room_id': '!chat:p2p-im.com',
          'room_name': '综合讨论',
          'channel_type': 'chat',
          'description': '大家都在这里聊天',
        }),
      ],
      fallbackDomain: 'p2p-im.com',
    );

    expect(items.single.name, '综合讨论');
    expect(items.single.channelType, asChannelTypeChat);
  });

  test('uses bootstrap display_name for channel display name', () {
    final bootstrap = AsSyncBootstrap.fromJson({
      'synced_at': '2026-06-17T10:30:00Z',
      'user': {'user_id': '@owner:p2p-im.com'},
      'channels': [
        {
          'channel_id': 'ch_chat',
          'room_id': '!chat:p2p-im.com',
          'display_name': '综合讨论',
          'channel_type': 'chat',
        },
      ],
    });

    final items = ChannelInboxData.fromBootstrap(
      bootstrap,
      fallbackDomain: 'p2p-im.com',
    );

    expect(items.single.name, '综合讨论');
  });

  test('sorts channels by created_at when last activity is missing', () {
    final items = ChannelInboxData.fromChannels(
      [
        AsChannel.fromJson({
          'channel_id': 'ch_old',
          'room_id': '!old:p2p-im.com',
          'name': '旧频道',
          'last_activity_at': '2026-06-17T09:00:00Z',
        }),
        AsChannel.fromJson({
          'channel_id': 'ch_new',
          'room_id': '!new:p2p-im.com',
          'name': '新频道',
          'created_at': '2026-06-17T10:00:00Z',
        }),
      ],
      fallbackDomain: 'p2p-im.com',
    );

    expect(items.map((item) => item.id), ['ch_new', 'ch_old']);
  });

  test('local created channel cache keeps newly created channel on top', () {
    final items = ChannelInboxData.fromBootstrap(
      AsSyncBootstrap(
        syncedAt: DateTime.parse('2026-06-17T10:30:00Z'),
        user: const AsSyncUser(userId: '@owner:p2p-im.com'),
        rooms: const [],
        contacts: const [],
        groups: const [],
        channels: [
          AsSyncRoomSummary(
            channelId: 'ch_existing',
            roomId: '!existing:p2p-im.com',
            homeDomain: 'p2p-im.com',
            name: '已有频道',
            avatarUrl: '',
            unreadCount: 0,
            lastActivityAt: DateTime.parse('2026-06-17T10:00:00Z'),
          ),
        ],
        pending: const AsSyncPending.empty(),
      ),
      fallbackDomain: 'p2p-im.com',
    );

    final merged = ChannelInboxData.mergeCreatedCache(
      items,
      [
        ChannelCreatedCacheEntry(
          channel: AsChannel.fromJson({
            'channel_id': 'ch_created',
            'room_id': '!created:p2p-im.com',
            'name': '刚创建的帖子',
            'description': '新建频道介绍',
            'channel_type': 'post',
            'role': asChannelRoleOwner,
            'member_status': asChannelMemberStatusJoined,
            'tags': ['帖子'],
          }),
          createdAt: DateTime.parse('2026-06-17T10:20:00Z'),
        ),
      ],
      fallbackDomain: 'p2p-im.com',
    );

    expect(merged.map((item) => item.id), ['ch_created', 'ch_existing']);
    expect(merged.first.isOwned, isTrue);
    expect(merged.first.channelType, asChannelTypePost);
    expect(merged.first.latestAt, DateTime.parse('2026-06-17T10:20:00Z'));
  });

  test('local created channel cache updates existing channel sort time', () {
    final items = ChannelInboxData.fromBootstrap(
      AsSyncBootstrap(
        syncedAt: DateTime.parse('2026-06-17T10:30:00Z'),
        user: const AsSyncUser(userId: '@owner:p2p-im.com'),
        rooms: const [],
        contacts: const [],
        groups: const [],
        channels: [
          AsSyncRoomSummary(
            channelId: 'ch_other',
            roomId: '!other:p2p-im.com',
            homeDomain: 'p2p-im.com',
            name: '其他频道',
            avatarUrl: '',
            unreadCount: 0,
            lastActivityAt: DateTime.parse('2026-06-17T10:05:00Z'),
          ),
          AsSyncRoomSummary(
            channelId: 'ch_created',
            roomId: '!created:p2p-im.com',
            homeDomain: 'p2p-im.com',
            name: '刚创建的文字',
            avatarUrl: '',
            unreadCount: 0,
            lastActivityAt: DateTime.parse('2026-06-17T09:00:00Z'),
            channelType: asChannelTypeChat,
          ),
        ],
        pending: const AsSyncPending.empty(),
      ),
      fallbackDomain: 'p2p-im.com',
    );

    final merged = ChannelInboxData.mergeCreatedCache(
      items,
      [
        ChannelCreatedCacheEntry(
          channel: AsChannel.fromJson({
            'channel_id': 'ch_created',
            'room_id': '!created:p2p-im.com',
            'name': '刚创建的文字',
            'channel_type': 'chat',
          }),
          createdAt: DateTime.parse('2026-06-17T10:20:00Z'),
        ),
      ],
      fallbackDomain: 'p2p-im.com',
    );

    expect(merged.map((item) => item.id), ['ch_created', 'ch_other']);
    expect(merged.first.latestAt, DateTime.parse('2026-06-17T10:20:00Z'));
  });

  test('local created channel cache fills missing existing avatar', () {
    final items = ChannelInboxData.fromBootstrap(
      AsSyncBootstrap(
        syncedAt: DateTime.parse('2026-06-17T10:30:00Z'),
        user: const AsSyncUser(userId: '@owner:p2p-im.com'),
        rooms: const [],
        contacts: const [],
        groups: const [],
        channels: [
          AsSyncRoomSummary(
            channelId: 'ch_created',
            roomId: '!created:p2p-im.com',
            homeDomain: 'p2p-im.com',
            name: '刚创建的文字',
            avatarUrl: '',
            unreadCount: 0,
            lastActivityAt: DateTime.parse('2026-06-17T09:00:00Z'),
            channelType: asChannelTypeChat,
          ),
        ],
        pending: const AsSyncPending.empty(),
      ),
      fallbackDomain: 'p2p-im.com',
    );

    final merged = ChannelInboxData.mergeCreatedCache(
      items,
      [
        ChannelCreatedCacheEntry(
          channel: AsChannel.fromJson({
            'channel_id': 'ch_created',
            'room_id': '!created:p2p-im.com',
            'name': '刚创建的文字',
            'avatar_url': 'mxc://p2p-im.com/new-channel-avatar',
            'channel_type': 'chat',
          }),
          createdAt: DateTime.parse('2026-06-17T10:20:00Z'),
        ),
      ],
      fallbackDomain: 'p2p-im.com',
    );

    expect(merged.single.avatarUrl, 'mxc://p2p-im.com/new-channel-avatar');
    expect(merged.single.isOwned, isTrue);
  });

  test('hides exited or dissolved channels from inbox data', () {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-18T10:30:00Z'),
      user: const AsSyncUser(userId: '@member:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_joined',
          roomId: '!joined:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '正常频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-18T10:20:00Z'),
          memberStatus: asChannelMemberStatusJoined,
        ),
        AsSyncRoomSummary(
          channelId: 'ch_removed',
          roomId: '!removed:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '已解散频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-18T10:21:00Z'),
          memberStatus: 'removed',
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    final bootstrapItems = ChannelInboxData.fromBootstrap(
      bootstrap,
      fallbackDomain: 'p2p-im.com',
    );
    expect(bootstrapItems.map((item) => item.id), ['ch_joined']);

    final listedItems = ChannelInboxData.fromChannels(
      const [
        AsChannel(
          channelId: 'ch_removed',
          roomId: '!removed:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '已解散频道',
          memberStatus: 'removed',
        ),
      ],
      fallbackDomain: 'p2p-im.com',
      bootstrap: bootstrap,
    );
    expect(listedItems, isEmpty);
  });

  test('hidden bootstrap channel suppresses local created cache entry', () {
    final cachedAt = DateTime.parse('2026-06-18T10:30:00Z');
    final merged = ChannelInboxData.mergeCreatedCache(
      const <ChannelInboxItem>[],
      [
        ChannelCreatedCacheEntry(
          channel: const AsChannel(
            channelId: 'ch_removed',
            roomId: '!removed:p2p-im.com',
            homeDomain: 'p2p-im.com',
            name: '已解散频道',
          ),
          createdAt: cachedAt,
        ),
      ],
      fallbackDomain: 'p2p-im.com',
      hiddenChannelKeys: const {
        'channel:ch_removed',
        'room:!removed:p2p-im.com',
      },
    );

    expect(merged, isEmpty);
  });

  test('does not expose matrix room id as bootstrap channel name', () {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-17T10:30:00Z'),
      user: const AsSyncUser(userId: '@member:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_joined',
          roomId: '!joined:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '!joined:p2p-im.com',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-17T09:30:00Z'),
          description: '证书和 VPS 部署经验',
          isOwned: false,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    final items = ChannelInboxData.fromBootstrap(
      bootstrap,
      fallbackDomain: 'p2p-im.com',
    );

    expect(items.single.name, '未命名频道');
    expect(items.single.name, isNot('!joined:p2p-im.com'));
  });

  test('uses Matrix room metadata for joined channel name and avatar fallback',
      () {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-17T10:30:00Z'),
      user: const AsSyncUser(userId: '@member:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_joined',
          roomId: '!joined:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '!joined:p2p-im.com',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-17T09:30:00Z'),
          description: '证书和 VPS 部署经验',
          isOwned: false,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    final items = ChannelInboxData.fromBootstrap(
      bootstrap,
      fallbackDomain: 'p2p-im.com',
      roomNameForRoomId: (roomId) =>
          roomId == '!joined:p2p-im.com' ? '部署互助' : '',
      roomAvatarForRoomId: (roomId) =>
          roomId == '!joined:p2p-im.com' ? 'mxc://p2p-im.com/room-avatar' : '',
    );

    expect(items.single.name, '部署互助');
    expect(items.single.avatarUrl, 'mxc://p2p-im.com/room-avatar');
  });

  test('does not use member count text as channel preview', () {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-17T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_members',
          roomId: '!members:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '频道名称',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-17T09:30:00Z'),
          description: '2名成员',
          topic: '12 members',
          isOwned: true,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    final items = ChannelInboxData.fromBootstrap(
      bootstrap,
      fallbackDomain: 'p2p-im.com',
    );

    expect(items.single.latestPreview, '暂无频道动态');
    expect(items.single.description, '');
  });
}

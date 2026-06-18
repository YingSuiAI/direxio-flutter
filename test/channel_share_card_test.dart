import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/channel/channel_share.dart';
import 'package:portal_app/presentation/chat/chat_record_forwarding.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';

void main() {
  test('channel share payload parses structured Matrix content', () {
    final payload = channelSharePayloadFromContent({
      chatRecordMatrixMarkerKey: channelShareMessageType,
      channelShareMatrixPayloadKey: {
        'channel_id': 'ch_product',
        'room_id': '!channel:p2p-im.com',
        'home_domain': 'p2p-im.com',
        'name': '产品公告',
        'description': '只发布重要产品更新',
        'visibility': 'public',
        'join_policy': 'open',
        'comments_enabled': true,
        'tags': ['产品'],
      },
    });

    expect(payload, isNotNull);
    expect(payload!.channelId, 'ch_product');
    expect(payload.roomId, '!channel:p2p-im.com');
    expect(payload.displayName, '产品公告');
    expect(payload.asDraft.toJson()['channel_id'], 'ch_product');
  });

  test('channel share payload parses AS room send content', () {
    final payload = channelSharePayloadFromContent({
      'message_type': channelShareMessageType,
      'channel_share': {
        'channel_id': 'ch_product',
        'room_id': '!channel:p2p-im.com',
        'home_domain': 'p2p-im.com',
        'name': '产品公告',
        'description': '只发布重要产品更新',
      },
    });

    expect(payload, isNotNull);
    expect(payload!.channelId, 'ch_product');
    expect(payload.roomId, '!channel:p2p-im.com');
    expect(payload.displayName, '产品公告');
  });

  testWidgets('channel share preview card renders channel summary',
      (tester) async {
    const payload = ChannelSharePayload(
      channelId: 'ch_product',
      roomId: '!channel:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '产品公告',
      description: '只发布重要产品更新',
      channelType: asChannelTypePost,
      tags: ['产品'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(
            child: ChannelSharePreviewCard(payload: payload),
          ),
        ),
      ),
    );

    expect(find.text('产品公告'), findsOneWidget);
    expect(find.text('只发布重要产品更新'), findsOneWidget);
    expect(find.byKey(const ValueKey('channel_share_type_帖子')), findsOneWidget);
    expect(find.text('加入频道'), findsOneWidget);
  });

  testWidgets('channel share preview card renders text channel label',
      (tester) async {
    const payload = ChannelSharePayload(
      channelId: 'ch_chat',
      roomId: '!chat:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '文字频道',
      description: '实时文字讨论',
      channelType: asChannelTypeChat,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(
            child: ChannelSharePreviewCard(payload: payload),
          ),
        ),
      ),
    );

    expect(find.text('文字频道'), findsOneWidget);
    expect(find.byKey(const ValueKey('channel_share_type_文字')), findsOneWidget);
  });

  testWidgets('channel share preview card join button invokes join',
      (tester) async {
    var joins = 0;
    var opens = 0;
    const payload = ChannelSharePayload(
      channelId: 'ch_product',
      roomId: '!channel:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '产品公告',
      description: '只发布重要产品更新',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: ChannelSharePreviewCard(
              payload: payload,
              onJoin: () => joins++,
              onTap: () => opens++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('加入频道'));
    await tester.pump();

    expect(joins, 1);
    expect(opens, 0);
  });

  testWidgets('channel share preview card joined button opens channel',
      (tester) async {
    var joins = 0;
    var opens = 0;
    const payload = ChannelSharePayload(
      channelId: 'ch_product',
      roomId: '!channel:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '产品公告',
      description: '只发布重要产品更新',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: ChannelSharePreviewCard(
              payload: payload,
              alreadyJoined: true,
              onJoin: () => joins++,
              onTap: () => opens++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('已加入'));
    await tester.pump();

    expect(joins, 0);
    expect(opens, 1);
  });

  test('channel share route opens detail until channel is joined', () {
    const payload = ChannelSharePayload(
      channelId: 'ch_product',
      roomId: '!channel:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '产品公告',
      description: '只发布重要产品更新',
    );

    expect(
      channelShareOpenRoute(const AsSyncCacheState(), payload),
      '/channel/ch_product/detail',
    );

    final joined = AsSyncCacheState(
      bootstrap: AsSyncBootstrap(
        syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
        user: const AsSyncUser(userId: '@owner:p2p-im.com'),
        rooms: const [],
        contacts: const [],
        groups: const [],
        channels: const [
          AsSyncRoomSummary(
            channelId: 'ch_product',
            roomId: '!channel:p2p-im.com',
            homeDomain: 'p2p-im.com',
            name: '产品公告',
            avatarUrl: '',
            unreadCount: 0,
            lastActivityAt: null,
            memberStatus: asChannelMemberStatusJoined,
          ),
        ],
        pending: const AsSyncPending.empty(),
      ),
    );

    expect(
      channelShareOpenRoute(joined, payload),
      '/channel/ch_product/conversation?name=%E4%BA%A7%E5%93%81%E5%85%AC%E5%91%8A',
    );
  });

  test('channel share route treats empty member status as not joined', () {
    const payload = ChannelSharePayload(
      channelId: 'ch_product',
      roomId: '!channel:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '产品公告',
    );
    final discoveredOnly = AsSyncCacheState(
      bootstrap: AsSyncBootstrap(
        syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
        user: const AsSyncUser(userId: '@owner:p2p-im.com'),
        rooms: const [],
        contacts: const [],
        groups: const [],
        channels: const [
          AsSyncRoomSummary(
            channelId: 'ch_product',
            roomId: '!channel:p2p-im.com',
            homeDomain: 'p2p-im.com',
            name: '产品公告',
            avatarUrl: '',
            unreadCount: 0,
            lastActivityAt: null,
          ),
        ],
        pending: const AsSyncPending.empty(),
      ),
    );

    expect(channelShareIsJoined(discoveredOnly, payload), isFalse);
    expect(
      channelShareOpenRoute(discoveredOnly, payload),
      '/channel/ch_product/detail',
    );
  });

  test('channel share route falls back to room id when channel id is missing',
      () {
    const payload = ChannelSharePayload(
      channelId: '',
      roomId: '!channel:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '产品公告',
    );

    expect(
      channelShareOpenRoute(const AsSyncCacheState(), payload),
      '/channel/!channel%3Ap2p-im.com/detail',
    );
  });

  test('channel share joined route opens conversation after join', () {
    const payload = ChannelSharePayload(
      channelId: 'ch_product',
      roomId: '!channel:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '产品公告',
      description: '只发布重要产品更新',
    );
    const joined = AsChannel(
      channelId: 'ch_product',
      roomId: '!channel:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: 'ch_product',
      memberStatus: asChannelMemberStatusJoined,
    );

    expect(
      channelShareJoinedRoute(payload, joined),
      '/channel/ch_product/conversation?name=%E4%BA%A7%E5%93%81%E5%85%AC%E5%91%8A',
    );
  });

  test('channel share joined route opens post list for post channels', () {
    const joined = AsChannel(
      channelId: 'ch_posts',
      roomId: '!posts:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '帖子频道',
      memberStatus: asChannelMemberStatusJoined,
    );

    expect(
      channelShareJoinedRoute(
        const ChannelSharePayload(
          channelId: 'ch_posts',
          roomId: '!posts:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '帖子频道',
          channelType: asChannelTypePost,
        ),
        joined,
      ),
      '/channel/ch_posts',
    );
    expect(
      channelShareJoinedRoute(
        const ChannelSharePayload(
          channelId: 'ch_posts',
          roomId: '!posts:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '帖子频道',
          tags: ['帖子'],
        ),
        joined,
      ),
      '/channel/ch_posts',
    );
  });
}

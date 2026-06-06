import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/mock_as_client.dart';
import 'package:portal_app/presentation/pages/channel_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';

void main() {
  testWidgets('channel detail opens real bootstrap channel summary',
      (tester) async {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-05-26T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          roomId: '!real:p2p-im.com',
          name: '产品公告',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-05-26T10:20:00Z'),
          topic: '只发布重要产品更新',
          isOwned: true,
          tags: const ['产品', '公告'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: '!real:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('产品公告'), findsAtLeastNWidgets(1));
    expect(find.text('p2p-im.com · 我的频道'), findsOneWidget);
    expect(find.text('只发布重要产品更新'), findsOneWidget);
    expect(find.text('频道帖子'), findsOneWidget);
    expect(find.text('发布帖子'), findsOneWidget);
    expect(find.text('频道不存在'), findsNothing);
  });

  testWidgets('channel detail loads public AS channel when not in bootstrap',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(_PublicChannelAsClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: 'ch_public'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('公开频道'), findsAtLeastNWidgets(1));
    expect(find.text('p2p-im.com'), findsOneWidget);
    expect(find.text('加入频道'), findsOneWidget);
    expect(find.text('频道不存在'), findsNothing);
  });

  testWidgets('channel detail renders AS posts and publishes text post',
      (tester) async {
    final asClient = _PostingChannelAsClient();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_real',
          roomId: '!real:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '产品公告',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          description: '只发布重要产品更新',
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          tags: const ['产品'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第一条帖子'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '新帖子');
    await tester.tap(find.text('发布帖子'));
    await tester.pumpAndSettle();

    expect(asClient.createdBody, '新帖子');
  });
}

class _PublicChannelAsClient extends MockAsClient {
  @override
  Future<AsChannel> getPublicChannel(String channelId, {Uri? baseUri}) async {
    return const AsChannel(
      channelId: 'ch_public',
      roomId: '!ch_public:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '公开频道',
      description: '公开频道说明',
      visibility: asChannelVisibilityPublic,
      joinPolicy: asChannelJoinPolicyOpen,
      commentsEnabled: true,
    );
  }
}

class _PostingChannelAsClient extends MockAsClient {
  String? createdBody;

  @override
  Future<List<AsChannelPost>> getChannelPosts(
    String channelId, {
    int limit = 50,
    int beforeTs = 0,
  }) async {
    return [
      AsChannelPost(
        postId: 'post1',
        channelId: channelId,
        roomId: '!real:p2p-im.com',
        eventId: r'$post1',
        authorId: '@owner:p2p-im.com',
        authorName: 'Yanan',
        messageType: 'text',
        body: createdBody ?? '第一条帖子',
        originServerTs:
            DateTime.parse('2026-06-06T10:20:00Z').millisecondsSinceEpoch,
      ),
    ];
  }

  @override
  Future<AsChannelPost> createChannelPost(
    String channelId, {
    required String messageType,
    required String body,
    Map<String, Object?> media = const {},
  }) async {
    createdBody = body;
    return AsChannelPost(
      postId: 'post2',
      channelId: channelId,
      roomId: '!real:p2p-im.com',
      eventId: r'$post2',
      authorId: '@owner:p2p-im.com',
      authorName: 'Yanan',
      messageType: messageType,
      body: body,
      media: media,
      originServerTs:
          DateTime.parse('2026-06-06T10:21:00Z').millisecondsSinceEpoch,
    );
  }
}

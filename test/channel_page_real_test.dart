import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/core/theme/design_tokens.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/as_bootstrap_store.dart';
import 'package:portal_app/data/channel_post_store.dart';
import 'support/mock_as_client.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/pages/channel_conversation_page.dart';
import 'package:portal_app/presentation/pages/channel_detail_info_page.dart';
import 'package:portal_app/presentation/pages/channel_info_page.dart';
import 'package:portal_app/presentation/pages/channel_management_page.dart';
import 'package:portal_app/presentation/pages/channel_page.dart';
import 'package:portal_app/presentation/pages/channel_post_create_page.dart';
import 'package:portal_app/presentation/pages/channel_post_detail_page.dart';
import 'package:portal_app/presentation/pages/contact_home_page.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/as_bootstrap_store_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/channel_provider.dart';
import 'package:portal_app/presentation/widgets/portal_avatar.dart';

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
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(_NoPostChannelAsClient()),
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
    expect(find.text('#产品公告'), findsNothing);
    expect(find.text('p2p-im.com · 我的频道'), findsNothing);
    expect(find.text('频道主Diana发布帖子，成员可评论和恢复'), findsNothing);
    expect(find.text('还没有频道内容'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('channel_post_create_fab')), findsOneWidget);
    expect(find.text('频道不存在'), findsNothing);
  });

  testWidgets('private channel post list title shows lock', (tester) async {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-05-26T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_private',
          roomId: '!private:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '私密帖子',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-05-26T10:20:00Z'),
          description: '只给成员看',
          isOwned: true,
          visibility: asChannelVisibilityPrivate,
          channelType: asChannelTypePost,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          tags: const ['帖子'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(_NoPostChannelAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: 'ch_private'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('私密帖子'), findsOneWidget);
    expect(find.text('#私密帖子'), findsNothing);
    expect(find.byIcon(Symbols.lock), findsOneWidget);
  });

  testWidgets('channel detail loads public AS channel when not in bootstrap',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
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

  testWidgets('channel detail loads public AS channel by room id',
      (tester) async {
    final asClient = _PublicChannelAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: '!ch_public:p2p-im.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(asClient.requestedRoomId, '!ch_public:p2p-im.com');
    expect(asClient.requestedRoomBaseUri, isNull);
    expect(find.text('公开频道'), findsAtLeastNWidgets(1));
    expect(find.text('加入频道'), findsOneWidget);
    expect(find.text('频道不存在'), findsNothing);
  });

  testWidgets('public open channel completes Matrix join after AS invite',
      (tester) async {
    final asClient = _PublicChannelAsClient();
    final bootstrapStore = _MemoryAsBootstrapStore();
    final router = GoRouter(
      initialLocation: '/channel/!ch_public:p2p-im.com',
      routes: [
        GoRoute(
          path: '/channel/:channelId',
          builder: (_, state) => ChannelPage(
            channelId: state.pathParameters['channelId']!,
          ),
        ),
        GoRoute(
          path: '/group/:roomId',
          builder: (_, __) => const Scaffold(body: Text('conversation-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
          asBootstrapRepositoryProvider.overrideWithValue(
            AsBootstrapRepository(
              loadBootstrap: () async => AsSyncBootstrap(
                syncedAt: DateTime(2026, 6, 20),
                user: const AsSyncUser(userId: '@owner:p2p-im.com'),
                rooms: const [],
                contacts: const [],
                groups: const [],
                channels: const [],
                pending: const AsSyncPending.empty(),
              ),
              store: bootstrapStore,
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('加入频道'));
    await tester.pumpAndSettle();

    expect(asClient.joinRequestRoomId, '!ch_public:p2p-im.com');
    expect(asClient.joinProjectionChannelId, 'ch_public');
    expect(find.text('conversation-opened'), findsOneWidget);
  });

  testWidgets(
      'channel detail passes remote node URL for local dual node room id',
      (tester) async {
    final asClient = _PublicChannelAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: '!ch_public:dendrite-a:8448'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(asClient.requestedRoomId, '!ch_public:dendrite-a:8448');
    expect(asClient.requestedRoomBaseUri, isNull);
    expect(find.text('公开频道'), findsAtLeastNWidgets(1));
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

    final router = GoRouter(
      initialLocation: '/channel/ch_real',
      routes: [
        GoRoute(
          path: '/channel/:channelId',
          builder: (_, state) => ChannelPage(
            channelId: state.pathParameters['channelId']!,
          ),
        ),
        GoRoute(
          path: '/channel/:channelId/post/create',
          builder: (_, state) => ChannelPostCreatePage(
            channelId: state.pathParameters['channelId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第一条帖子'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('channel_post_create_fab')));
    await tester.pumpAndSettle();

    expect(find.text('发表帖子...'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '新帖子');
    await tester.tap(find.text('发表'));
    await tester.pumpAndSettle();

    expect(asClient.createdBody, '新帖子');
    expect(find.text('新帖子'), findsOneWidget);
  });

  testWidgets('post channel owner role sees create button on post list',
      (tester) async {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-17T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_real',
          roomId: '!real:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '综合讨论',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-17T10:20:00Z'),
          description: '频道帖子，成员可评论和互动',
          isOwned: false,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          channelType: asChannelTypePost,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(_PostingChannelAsClient()),
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

    expect(find.text('综合讨论'), findsOneWidget);
    expect(find.text('#综合讨论'), findsNothing);
    expect(find.text('频道帖子，成员可评论和互动'), findsOneWidget);
    expect(find.text('第一条帖子'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('channel_post_create_fab')), findsOneWidget);
    expect(find.text('输入评论...'), findsOneWidget);
  });

  testWidgets('channel post list hides expand control when body fits',
      (tester) async {
    final asClient = _PostingChannelAsClient(postBody: '短帖子正文');
    await _pumpRealChannelPage(tester, asClient);

    expect(find.text('短帖子正文'), findsOneWidget);
    expect(find.text('展开更多'), findsNothing);
  });

  testWidgets('channel post list shows expand control when body overflows',
      (tester) async {
    final asClient = _PostingChannelAsClient(
      postBody: List.filled(18, '这是一段较长的频道帖子正文').join('，'),
    );
    await _pumpRealChannelPage(tester, asClient);

    expect(find.text('展开更多'), findsOneWidget);
  });

  testWidgets('channel detail toggles AS post reaction', (tester) async {
    final asClient = _PostingChannelAsClient(reactedByMe: true);
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
          _channelPostStoreOverride(),
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

    final likeButton = find.byKey(const ValueKey('channel_post_like_post1'));
    final heart = tester.widget<Icon>(
      find.descendant(of: likeButton, matching: find.byIcon(Symbols.favorite)),
    );

    expect(heart.color, PortalTokens.light.danger);

    await tester.tap(find.byKey(const ValueKey('channel_post_like_post1')));
    await tester.pumpAndSettle();

    expect(asClient.toggledPostId, 'post1');
  });

  testWidgets('channel owner can recall a post from post list', (tester) async {
    final asClient = _PostingChannelAsClient();
    await _pumpRealChannelPage(tester, asClient);

    expect(find.text('第一条帖子'), findsOneWidget);
    final recallButton = find.byKey(
      const ValueKey('channel_post_recall_post1'),
    );
    expect(recallButton, findsOneWidget);

    await tester.tap(recallButton);
    await tester.pumpAndSettle();

    expect(asClient.recalledPostId, 'post1');
    expect(asClient.recallReason, 'recall post');
    expect(find.text('帖子已删除'), findsOneWidget);
    expect(find.text('第一条帖子'), findsNothing);
  });

  testWidgets('channel post detail uses red heart for reacted post',
      (tester) async {
    final asClient = _PostingChannelAsClient(reactedByMe: true);
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
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          tags: const ['产品'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPostDetailPage(
            channelId: 'ch_real',
            postId: 'post1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final heart = tester.widget<Icon>(find.byIcon(Symbols.favorite));
    expect(heart.color, PortalTokens.light.danger);
    expect(heart.fill, 1);

    await tester.tap(find.byIcon(Symbols.favorite));
    await tester.pumpAndSettle();

    expect(asClient.toggledPostId, 'post1');
  });

  testWidgets('channel post detail title and id align channel detail',
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
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          tags: const ['产品'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPostDetailPage(
            channelId: 'ch_real',
            postId: 'post1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('帖子详情'), findsOneWidget);
    expect(find.text('产品公告'), findsNothing);
    expect(find.text('ID:post1'), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.content_copy));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('已复制帖子 ID'), findsOneWidget);
  });

  testWidgets('channel post list input opens detail for commenting',
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
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          tags: const ['产品'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    final router = GoRouter(
      initialLocation: '/channel/ch_real',
      routes: [
        GoRoute(
          path: '/channel/:channelId',
          builder: (_, state) => ChannelPage(
            channelId: state.pathParameters['channelId']!,
          ),
        ),
        GoRoute(
          path: '/channel/:channelId/post/:postId',
          builder: (_, state) => ChannelPostDetailPage(
            channelId: state.pathParameters['channelId']!,
            postId: state.pathParameters['postId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('输入评论...'), findsOneWidget);

    await tester.tap(find.text('第一条帖子').first);
    await tester.pumpAndSettle();

    expect(find.text('帖子详情'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('输入评论...'), findsOneWidget);

    await tester.tap(find.text('输入评论...'));
    await tester.pumpAndSettle();

    expect(find.text('帖子详情'), findsOneWidget);
    expect(find.text('输入评论...'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '这条更新很有用');
    await tester.tap(find.byIcon(Symbols.send));
    await tester.pumpAndSettle();

    expect(asClient.createdCommentBody, '这条更新很有用');
    expect(find.text('这条更新很有用'), findsOneWidget);
  });

  testWidgets('joined post channel can like posts with event id fallback',
      (tester) async {
    final asClient = _PostingChannelAsClient(postId: '');
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
          name: '对方的帖子频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          description: '只发布重要产品更新',
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          channelType: asChannelTypePost,
          tags: const ['帖子'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
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

    await tester.tap(find.byKey(const ValueKey(r'channel_post_like_$post1')));
    await tester.pumpAndSettle();

    expect(asClient.toggledPostId, r'$post1');
  });

  testWidgets('channel post detail sends comment and renders thread',
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
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          tags: const ['产品'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPostDetailPage(
            channelId: 'ch_real',
            postId: 'post1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('帖子详情'), findsOneWidget);
    expect(find.text('第一条帖子'), findsAtLeastNWidgets(1));
    expect(find.text('输入评论...'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '这条更新很有用');
    await tester.tap(find.byIcon(Symbols.send));
    await tester.pumpAndSettle();

    expect(asClient.createdCommentBody, '这条更新很有用');
    expect(find.text('这条更新很有用'), findsOneWidget);
    expect(find.text('我'), findsAtLeastNWidgets(1));
  });

  testWidgets('channel post detail lazily loads collapsed comments',
      (tester) async {
    tester.view.physicalSize = const Size(390, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final comments = List.generate(12, (index) {
      final number = index + 1;
      return AsChannelComment(
        commentId: 'comment$number',
        postId: 'post1',
        channelId: 'ch_real',
        eventId: r'$comment' '$number',
        authorId: '@user$number:p2p-im.com',
        authorName: 'User$number',
        messageType: 'text',
        body: '评论 $number ${List.filled(30, '内容').join()}',
        originServerTs: 1000 - index,
      );
    });
    final asClient = _PostingChannelAsClient(comments: comments);
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
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          tags: const ['产品'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPostDetailPage(
            channelId: 'ch_real',
            postId: 'post1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('评论 1'), findsNothing);
    expect(asClient.requestedCommentPages, isEmpty);

    await tester.tap(find.text('查看评论(12)'));
    await tester.pumpAndSettle();

    expect(asClient.requestedCommentPages, [1]);
    expect(asClient.requestedCommentPageSizes, [5]);
    expect(find.textContaining('评论 1'), findsOneWidget);
    expect(find.textContaining('评论 5'), findsOneWidget);
    expect(find.textContaining('评论 6'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(asClient.requestedCommentPages.length, greaterThanOrEqualTo(2));
    expect(asClient.requestedCommentPages[1], 2);
    expect(asClient.requestedCommentPageSizes[1], 5);
    expect(find.textContaining('评论 6'), findsOneWidget);
  });

  testWidgets('channel post detail updates visible comment reaction',
      (tester) async {
    final asClient = _PostingChannelAsClient(
      comments: const [
        AsChannelComment(
          commentId: 'comment-react',
          postId: 'post1',
          channelId: 'ch_real',
          eventId: r'$comment-react',
          authorId: '@alice:p2p-im.com',
          authorName: 'Alice',
          messageType: 'text',
          body: '可以点赞的评论',
          originServerTs: 1000,
          reactionCount: 2,
          reactedByMe: false,
        ),
      ],
      commentReactionCount: 7,
    );
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
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          tags: const ['产品'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPostDetailPage(
            channelId: 'ch_real',
            postId: 'post1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看评论(1)'));
    await tester.pumpAndSettle();

    expect(find.text('可以点赞的评论'), findsOneWidget);
    expect(find.text('2'), findsAtLeastNWidgets(1));

    await tester.tap(
      find.byKey(const ValueKey('channel_comment_like_comment-react')),
    );
    await tester.pumpAndSettle();

    expect(asClient.toggledCommentId, 'comment-react');
    expect(asClient.toggledCommentPostId, 'post1');
    expect(asClient.toggledCommentChannelId, 'ch_real');
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('channel info page renders figma actions', (tester) async {
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
          name: '综合讨论',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          description: '只发布重要产品更新',
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 32,
          tags: const ['产品'],
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
          home: const ChannelInfoPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#综合讨论'), findsOneWidget);
    expect(find.text('频道信息(32)'), findsOneWidget);
    expect(find.text('频道详情'), findsOneWidget);
    expect(find.text('分享频道'), findsOneWidget);
    expect(find.text('举报频道'), findsOneWidget);
    expect(find.text('退出频道'), findsOneWidget);
  });

  testWidgets('owned channel info refreshes joined members from AS',
      (tester) async {
    final asClient = _ChannelInfoMembersAsClient();
    final matrixClient = Client('ChannelInfoMembersTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
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
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 1,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(matrixClient),
          authStateNotifierProvider
              .overrideWith(_ChannelTestLoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelInfoPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(asClient.requestedChannelId, 'ch_real');
    expect(asClient.requestedStatus, asChannelMemberStatusJoined);
    expect(find.text('频道信息(2)'), findsOneWidget);
    expect(find.text('2 名成员'), findsNothing);

    await tester.tap(find.byIcon(Symbols.remove));
    await tester.pumpAndSettle();

    expect(find.text('移除频道成员'), findsOneWidget);
    expect(find.text('Alex Chen'), findsOneWidget);
  });

  testWidgets('owned channel member avatar opens visitor public channels',
      (tester) async {
    final asClient = _ChannelInfoMembersAsClient(
      publicChannels: const [
        AsChannel(
          channelId: 'ch_alex_public',
          roomId: '!alex-public:p2p-liyanan.com',
          name: 'Alex 公开频道',
          visibility: asChannelVisibilityPublic,
          memberCount: 5,
        ),
      ],
    );
    final matrixClient = Client('ChannelInfoAvatarProfileTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
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
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 1,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/channel/ch_real/info',
      routes: [
        GoRoute(
          path: '/channel/:channelId/info',
          builder: (_, state) => ChannelInfoPage(
            channelId: state.pathParameters['channelId']!,
          ),
        ),
        GoRoute(
          path: '/me/profile',
          builder: (_, __) => const Scaffold(body: Text('个人信息页面')),
        ),
        GoRoute(
          path: '/contact-home/:userId',
          builder: (_, state) => ContactHomePage(
            userId: state.pathParameters['userId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(matrixClient),
          authStateNotifierProvider
              .overrideWith(_ChannelTestLoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('频道详情'), findsOneWidget);
    await tester.tap(find.byKey(
      const ValueKey('channel_member_avatar_@alex:p2p-liyanan.com'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('个人信息页面'), findsNothing);
    expect(find.text('主页'), findsOneWidget);
    expect(asClient.requestedPublicChannelUserId, '@alex:p2p-liyanan.com');
    expect(find.text('Alex 公开频道'), findsOneWidget);
    expect(find.text('还没有公开频道'), findsNothing);
  });

  testWidgets('owned channel info mute switch calls AS APIs', (tester) async {
    final asClient = _ChannelInfoMembersAsClient();
    final matrixClient = Client('ChannelInfoMuteTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
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
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 1,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(matrixClient),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelInfoPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_ownerSwitchFinder());
    await tester.pumpAndSettle();

    expect(asClient.mutedChannelId, 'ch_real');
    expect(find.text('已开启全员禁言'), findsOneWidget);

    await tester.tap(_ownerSwitchFinder());
    await tester.pumpAndSettle();

    expect(asClient.unmutedChannelId, 'ch_real');
    expect(find.text('已解除全员禁言'), findsOneWidget);
  });

  testWidgets('owned channel info mute switch reflects bootstrap mute state',
      (tester) async {
    final asClient = _ChannelInfoMembersAsClient();
    final matrixClient = Client('ChannelInfoMuteStateTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
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
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          commentsEnabled: false,
          memberCount: 1,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(matrixClient),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelInfoPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_ownerSwitchFinder());
    await tester.pumpAndSettle();

    expect(asClient.unmutedChannelId, 'ch_real');
    expect(asClient.mutedChannelId, isNull);
  });

  testWidgets('owned channel info mute switch updates cached channel state',
      (tester) async {
    final asClient = _ChannelInfoMembersAsClient();
    final matrixClient = Client('ChannelInfoMuteCacheTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
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
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 1,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(matrixClient),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelInfoPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_ownerSwitchFinder());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChannelInfoPage)),
    );
    expect(asClient.mutedChannelId, 'ch_real');
    expect(
      container
          .read(asSyncCacheProvider)
          .bootstrap!
          .channels
          .single
          .commentsEnabled,
      isFalse,
    );
  });

  testWidgets('channel owner does not see report action from role',
      (tester) async {
    final matrixClient = Client('ChannelOwnerNoReportTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
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
          isOwned: false,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 1,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(matrixClient),
          asClientProvider.overrideWithValue(_ChannelInfoMembersAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelInfoPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('举报频道'), findsNothing);
    expect(find.text('退出频道'), findsNothing);
    expect(find.text('频道信息(2)'), findsOneWidget);
    expect(find.text('2 名成员'), findsNothing);
  });

  testWidgets('channel leave and dissolve use shared confirm dialog',
      (tester) async {
    final asClient = _PostingChannelAsClient();
    final memberBootstrap = AsSyncBootstrap(
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
          name: '综合讨论',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          description: '只发布重要产品更新',
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 32,
          tags: const ['产品'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: memberBootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelInfoPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('退出频道'));
    await tester.pumpAndSettle();

    expect(find.text('确定退出？'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(asClient.leftChannelId, 'ch_real');
    expect(find.text('已退出频道'), findsOneWidget);
    asClient.leftChannelId = null;

    final ownerBootstrap = AsSyncBootstrap(
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
          name: '综合讨论',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          description: '只发布重要产品更新',
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 32,
          tags: const ['产品'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: ownerBootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChannelManagementPage(
            channelId: 'ch_real',
            initialSection: ChannelManagementSection.profile,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('停用频道'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用频道'));
    await tester.pumpAndSettle();

    expect(find.text('确定解散？'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(asClient.dissolvedChannelId, 'ch_real');
    expect(asClient.leftChannelId, isNull);
    expect(find.text('已解散频道'), findsOneWidget);
  });

  testWidgets('channel detail info page renders figma content', (tester) async {
    final client = Client('ChannelDetailInfoAvatarTest')
      ..homeserver = Uri.parse('https://p2p-im.com');
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
          name: '综合讨论',
          avatarUrl: 'mxc://p2p-im.com/channel-avatar',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          description: '每周产品更新和频道公告',
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: '',
          memberCount: 32,
          tags: const ['文字'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelDetailInfoPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('频道详情'), findsOneWidget);
    expect(find.text('综合讨论'), findsOneWidget);
    expect(find.text('#综合讨论'), findsNothing);
    expect(find.text('ID:!real:p2p-im.com'), findsOneWidget);
    expect(find.text('ID:ch_real'), findsNothing);
    expect(find.text('文字'), findsOneWidget);
    expect(find.text('频道介绍'), findsOneWidget);
    final avatarImage = tester.widget<Image>(
      find.descendant(
        of: find.byType(PortalAvatar),
        matching: find.byType(Image),
      ),
    );
    expect(
      (avatarImage.image as NetworkImage).url,
      contains('/download/p2p-im.com/channel-avatar'),
    );
    expect(find.text('每周产品更新和频道公告'), findsOneWidget);
    expect(find.text('申请加入'), findsNothing);
  });

  testWidgets('channel detail info uses Matrix room name instead of room id',
      (tester) async {
    final client = Client('ChannelDetailInfoRoomIdNameTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(
      id: '!real:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@owner:p2p-im.com',
        stateKey: '@owner:p2p-im.com',
        content: const {'membership': 'join'},
      ),
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomName,
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: const {'name': '综合讨论'},
      ),
    );
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
          name: '!real:p2p-im.com',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          description: '频道介绍',
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 32,
          tags: const ['文字'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelDetailInfoPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('综合讨论'), findsOneWidget);
    expect(find.text('#综合讨论'), findsNothing);
    expect(find.text('ID:!real:p2p-im.com'), findsOneWidget);
  });

  testWidgets('channel conversation page renders figma chat surface',
      (tester) async {
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
          name: '综合讨论',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          description: '只发布重要产品更新',
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 32,
          tags: const ['文字'],
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
          home: const ChannelConversationPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#综合讨论'), findsOneWidget);
    expect(find.text('频道已创建'), findsOneWidget);
    expect(find.text('Alice'), findsAtLeastNWidgets(1));
    expect(find.text('我正在考虑接受它！！'), findsAtLeastNWidgets(1));
    expect(find.text('按住 说话'), findsOneWidget);
    expect(find.byIcon(Symbols.lock), findsNothing);
  });

  testWidgets('channel conversation long press opens message actions',
      (tester) async {
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
          name: '综合讨论',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          description: '只发布重要产品更新',
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 32,
          tags: const ['文字'],
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
          home: const ChannelConversationPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我正在考虑接受它！！'), findsNWidgets(2));

    await tester.longPress(find.text('我正在考虑接受它！！').first);
    await tester.pumpAndSettle();
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(find.text('复制'), findsNothing);

    await tester.longPress(find.text('我正在考虑接受它！！').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('我正在考虑接受它！！'), findsOneWidget);
  });

  testWidgets('post list more button opens channel info page', (tester) async {
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
          _channelPostStoreOverride(),
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

    await tester.tap(find.byIcon(Symbols.more_vert).first);
    await tester.pumpAndSettle();

    expect(find.byType(ChannelInfoPage), findsOneWidget);
    expect(find.textContaining('频道信息('), findsOneWidget);
    expect(find.text('频道详情'), findsOneWidget);
    expect(find.text('分享频道'), findsOneWidget);
    expect(find.text('解散频道'), findsOneWidget);
  });

  testWidgets('owned channel member management renders members tab',
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
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          pendingJoinCount: 1,
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
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChannelManagementPage(
            channelId: 'ch_real',
            initialSection: ChannelManagementSection.members,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('成员与角色'), findsOneWidget);
    expect(find.text('Niki'), findsOneWidget);
    expect(find.text('Alex Chen'), findsOneWidget);
  });

  testWidgets('real channel page marks latest post as read', (tester) async {
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
          unreadCount: 3,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
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

    expect(asClient.readMarkerChannelId, 'ch_real');
    expect(asClient.readMarkerEventId, r'$post1');
  });
}

Override _channelPostStoreOverride([ChannelPostStore? store]) {
  final resolved = store ?? _MemoryChannelPostStore();
  return channelPostStoreProvider.overrideWith((ref) async => resolved);
}

class _MemoryChannelPostStore implements ChannelPostStore {
  final _posts = <String, AsChannelPost>{};

  @override
  Future<List<AsChannelPost>> readChannel(String channelId) async {
    return _posts.values
        .where((post) => post.channelId.trim() == channelId.trim())
        .toList(growable: false)
      ..sort((a, b) => b.originServerTs.compareTo(a.originServerTs));
  }

  @override
  Future<void> upsertChannel(
    String channelId,
    Iterable<AsChannelPost> posts,
  ) async {
    _posts.removeWhere((_, post) => post.channelId.trim() == channelId.trim());
    for (final post in posts) {
      await upsertPost(post);
    }
  }

  @override
  Future<void> upsertPost(AsChannelPost post) async {
    final postId = post.postId.trim();
    final eventId = post.eventId.trim();
    _posts['${post.channelId}:${postId.isNotEmpty ? postId : eventId}'] = post;
  }

  @override
  Future<void> removePost(String channelId, String postId) async {
    _posts.removeWhere((_, post) {
      if (post.channelId.trim() != channelId.trim()) return false;
      final id = post.postId.trim();
      if (id.isNotEmpty) return id == postId.trim();
      return post.eventId.trim() == postId.trim();
    });
  }
}

class _PublicChannelAsClient extends MockAsClient {
  String? requestedRoomId;
  Uri? requestedRoomBaseUri;
  String? joinRequestRoomId;
  String? joinProjectionChannelId;

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
      channelType: asChannelTypeChat,
      commentsEnabled: true,
    );
  }

  @override
  Future<AsChannel> getPublicChannelByRoomId(
    String roomId, {
    Uri? baseUri,
    Uri? remoteNodeBaseUri,
  }) async {
    requestedRoomId = roomId;
    requestedRoomBaseUri = baseUri;
    return const AsChannel(
      channelId: 'ch_public',
      roomId: '!ch_public:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '公开频道',
      description: '公开频道说明',
      visibility: asChannelVisibilityPublic,
      joinPolicy: asChannelJoinPolicyOpen,
      channelType: asChannelTypeChat,
      commentsEnabled: true,
    );
  }

  @override
  Future<AsChannel> joinChannelByRoomId(
    String roomId, {
    String shareToken = '',
    String grantId = '',
    String shareRoomId = '',
    AsChannel? discoveredChannel,
    Uri? remoteNodeBaseUri,
  }) async {
    joinRequestRoomId = roomId;
    return const AsChannel(
      channelId: 'ch_public',
      roomId: '!ch_public:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '公开频道',
      description: '公开频道说明',
      visibility: asChannelVisibilityPublic,
      joinPolicy: asChannelJoinPolicyOpen,
      channelType: asChannelTypeChat,
      commentsEnabled: true,
      role: asChannelRoleMember,
      memberStatus: asChannelMemberStatusInvite,
    );
  }

  @override
  Future<AsChannel> joinChannel(
    String channelId, {
    String roomId = '',
    String shareToken = '',
    String grantId = '',
    String shareRoomId = '',
    AsChannel? discoveredChannel,
  }) async {
    joinProjectionChannelId = channelId;
    return const AsChannel(
      channelId: 'ch_public',
      roomId: '!ch_public:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '公开频道',
      description: '公开频道说明',
      visibility: asChannelVisibilityPublic,
      joinPolicy: asChannelJoinPolicyOpen,
      channelType: asChannelTypeChat,
      commentsEnabled: true,
      role: asChannelRoleMember,
      memberStatus: asChannelMemberStatusJoined,
      productConversation: AsConversation(
        conversationId: 'conv_channel',
        roomId: '!ch_public:p2p-im.com',
        kind: asConversationKindChannel,
        lifecycle: 'active',
        title: '公开频道',
        avatarUrl: '',
        capabilities: AsConversationCapabilities(open: true),
      ),
    );
  }
}

class _MemoryAsBootstrapStore implements AsBootstrapStore {
  AsSyncBootstrap? value;

  @override
  Future<AsSyncBootstrap?> read() async => value;

  @override
  Future<void> write(AsSyncBootstrap bootstrap) async {
    value = bootstrap;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _ChannelInfoMembersAsClient extends MockAsClient {
  _ChannelInfoMembersAsClient({
    this.publicChannels = const [],
  });

  final List<AsChannel> publicChannels;
  String? requestedChannelId;
  String? requestedStatus;
  String? mutedChannelId;
  String? unmutedChannelId;
  String? requestedPublicChannelUserId;

  @override
  Future<List<AsChannelMember>> getChannelMembers(
    String channelId, {
    String status = '',
  }) async {
    requestedChannelId = channelId;
    requestedStatus = status;
    return const [
      AsChannelMember(
        channelId: 'ch_real',
        userMxid: '@owner:p2p-im.com',
        displayName: 'Niki',
        domain: 'p2p-im.com',
        role: asChannelRoleOwner,
        status: asChannelMemberStatusJoined,
        joinedAtMs: 1780712400000,
      ),
      AsChannelMember(
        channelId: 'ch_real',
        userMxid: '@alex:p2p-liyanan.com',
        displayName: 'Alex Chen',
        domain: 'p2p-liyanan.com',
        role: asChannelRoleMember,
        status: 'join',
        joinedAtMs: 1780712460000,
      ),
    ];
  }

  @override
  Future<void> muteChannel(String channelId) async {
    mutedChannelId = channelId;
  }

  @override
  Future<void> unmuteChannel(String channelId) async {
    unmutedChannelId = channelId;
  }

  @override
  Future<List<AsChannel>> getUserPublicChannels(
    String userId, {
    Uri? baseUri,
  }) async {
    requestedPublicChannelUserId = userId;
    return publicChannels;
  }
}

Finder _ownerSwitchFinder() {
  return find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_OwnerSwitch',
  );
}

class _NoPostChannelAsClient extends MockAsClient {
  @override
  Future<List<AsChannelPost>> getChannelPosts(
    String channelId, {
    int limit = 50,
    int beforeTs = 0,
  }) async {
    return const [];
  }
}

Future<void> _pumpRealChannelPage(
  WidgetTester tester,
  AsClient asClient,
) async {
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
        _channelPostStoreOverride(),
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
}

class _PostingChannelAsClient extends MockAsClient {
  _PostingChannelAsClient({
    this.postBody,
    this.reactedByMe = false,
    this.postId = 'post1',
    this.comments = const [],
    this.commentReactionCount = 1,
  });

  final String? postBody;
  final bool reactedByMe;
  final String postId;
  final List<AsChannelComment> comments;
  final int commentReactionCount;
  final List<int> requestedCommentPages = [];
  final List<int> requestedCommentPageSizes = [];
  String? createdBody;
  String? createdCommentBody;
  AsChannel? updatedChannel;
  String? approvedUserId;
  String? rejectedUserId;
  String? readMarkerChannelId;
  String? readMarkerEventId;
  String? leftChannelId;
  String? dissolvedChannelId;
  String? recalledPostId;
  String? recallReason;
  String? toggledCommentChannelId;
  String? toggledCommentPostId;
  String? toggledCommentId;

  @override
  Future<List<AsChannelPost>> getChannelPosts(
    String channelId, {
    int limit = 50,
    int beforeTs = 0,
  }) async {
    if (recalledPostId != null) return const [];
    return [
      AsChannelPost(
        postId: postId,
        channelId: channelId,
        roomId: '!real:p2p-im.com',
        eventId: r'$post1',
        authorId: '@owner:p2p-im.com',
        authorName: 'Yanan',
        messageType: 'text',
        body: createdBody ?? postBody ?? '第一条帖子',
        originServerTs:
            DateTime.parse('2026-06-06T10:20:00Z').millisecondsSinceEpoch,
        commentCount: comments.length,
        reactionCount: 2,
        reactedByMe: reactedByMe,
      ),
    ];
  }

  @override
  Future<void> recallChannelPost(
    String channelId,
    String postId, {
    String reason = 'recall post',
  }) async {
    recalledPostId = postId;
    recallReason = reason;
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

  @override
  Future<List<AsChannelComment>> getChannelComments(
    String channelId,
    String postId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    requestedCommentPages.add(page);
    requestedCommentPageSizes.add(pageSize);
    final sorted = comments.toList()
      ..sort((a, b) => b.originServerTs.compareTo(a.originServerTs));
    final start = (page <= 1 ? 0 : page - 1) * pageSize;
    return sorted.skip(start).take(pageSize).toList(growable: false);
  }

  @override
  Future<AsChannelComment> createChannelComment(
    String channelId,
    String postId, {
    required String messageType,
    required String body,
    Map<String, Object?> media = const {},
    String replyToCommentId = '',
    String replyToAuthorId = '',
    List<Map<String, Object?>> mentions = const [],
  }) async {
    createdCommentBody = body;
    return AsChannelComment(
      commentId: 'comment1',
      postId: postId,
      channelId: channelId,
      eventId: r'$comment1',
      authorId: '@owner:p2p-im.com',
      authorName: 'Yanan',
      messageType: messageType,
      body: body,
      media: media,
      replyToCommentId: replyToCommentId,
      replyToAuthorId: replyToAuthorId,
      mentions: mentions,
      originServerTs:
          DateTime.parse('2026-06-06T10:22:00Z').millisecondsSinceEpoch,
    );
  }

  @override
  Future<AsChannel> updateChannel(AsChannel draft) async {
    updatedChannel = draft;
    return draft;
  }

  String? toggledPostId;

  @override
  Future<AsChannelReaction> toggleChannelPostReaction(
    String channelId,
    String postId, {
    String reaction = 'like',
  }) async {
    toggledPostId = postId;
    return const AsChannelReaction(
      postId: 'post1',
      channelId: 'ch_real',
      reaction: 'like',
      active: true,
      reactionCount: 3,
    );
  }

  @override
  Future<AsChannelReaction> toggleChannelCommentReaction(
    String channelId,
    String postId,
    String commentId, {
    String reaction = 'like',
  }) async {
    toggledCommentChannelId = channelId;
    toggledCommentPostId = postId;
    toggledCommentId = commentId;
    return AsChannelReaction(
      postId: postId,
      channelId: channelId,
      reaction: reaction,
      active: true,
      reactionCount: commentReactionCount,
    );
  }

  @override
  Future<List<AsChannelMember>> getChannelMembers(
    String channelId, {
    String status = '',
  }) async {
    return [
      const AsChannelMember(
        channelId: 'ch_real',
        userMxid: '@alice:p2p-liyanan.com',
        displayName: 'Alice',
        domain: 'p2p-liyanan.com',
        role: asChannelRoleMember,
        status: asChannelMemberStatusPending,
      ),
    ];
  }

  @override
  Future<AsChannel> approveChannelJoin(
    String channelId,
    String userMxid,
  ) async {
    approvedUserId = userMxid;
    return const AsChannel(
      channelId: 'ch_real',
      roomId: '!real:p2p-im.com',
      name: '产品公告',
      role: asChannelRoleOwner,
      memberStatus: asChannelMemberStatusJoined,
      pendingJoinCount: 0,
    );
  }

  @override
  Future<AsChannel> rejectChannelJoin(
    String channelId,
    String userMxid,
  ) async {
    rejectedUserId = userMxid;
    return const AsChannel(
      channelId: 'ch_real',
      roomId: '!real:p2p-im.com',
      name: '产品公告',
      role: asChannelRoleOwner,
      memberStatus: asChannelMemberStatusJoined,
      pendingJoinCount: 0,
    );
  }

  @override
  Future<void> updateChannelReadMarker(
    String channelId, {
    required String eventId,
    required int originServerTs,
  }) async {
    readMarkerChannelId = channelId;
    readMarkerEventId = eventId;
  }

  @override
  Future<void> leaveChannel(String channelId) async {
    leftChannelId = channelId.trim();
  }

  @override
  Future<void> dissolveChannel(String channelId) async {
    dissolvedChannelId = channelId.trim();
  }
}

class _ChannelTestLoggedInAuthStateNotifier extends AuthStateNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        isLoggedIn: true,
        portalToken: 'portal-token',
        homeserver: 'https://p2p-im.com',
      );
}

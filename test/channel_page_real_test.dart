import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/core/theme/design_tokens.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/channel_post_store.dart';
import 'package:portal_app/data/mock_as_client.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/pages/channel_conversation_page.dart';
import 'package:portal_app/presentation/pages/channel_detail_info_page.dart';
import 'package:portal_app/presentation/pages/channel_info_page.dart';
import 'package:portal_app/presentation/pages/channel_management_page.dart';
import 'package:portal_app/presentation/pages/channel_page.dart';
import 'package:portal_app/presentation/pages/channel_post_create_page.dart';
import 'package:portal_app/presentation/pages/channel_post_detail_page.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
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
    expect(find.text('频道主Diana发布帖子，成员可评论和恢复'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('channel_post_create_fab')), findsOneWidget);
    expect(find.text('频道不存在'), findsNothing);
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
    expect(find.text('公开频道'), findsAtLeastNWidgets(1));
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

    await tester.tap(find.text('输入评论...'));
    await tester.pumpAndSettle();

    expect(find.text('#产品公告'), findsOneWidget);
    expect(find.text('输入评论...'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '这条更新很有用');
    await tester.tap(find.byIcon(Symbols.send));
    await tester.pumpAndSettle();

    expect(asClient.createdCommentBody, '这条更新很有用');
    expect(find.text('这条更新很有用'), findsOneWidget);
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

    expect(find.text('#产品公告'), findsOneWidget);
    expect(find.text('第一条帖子'), findsAtLeastNWidgets(1));
    expect(find.text('输入评论...'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '这条更新很有用');
    await tester.tap(find.byIcon(Symbols.send));
    await tester.pumpAndSettle();

    expect(asClient.createdCommentBody, '这条更新很有用');
    expect(find.text('这条更新很有用'), findsOneWidget);
    expect(find.text('我'), findsAtLeastNWidgets(1));
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

    expect(find.text('综合讨论'), findsOneWidget);
    expect(find.text('#综合讨论'), findsOneWidget);
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
    expect(find.text('产品公告（2）'), findsOneWidget);
    expect(find.text('2 名成员'), findsNothing);

    await tester.tap(find.byIcon(Symbols.remove));
    await tester.pumpAndSettle();

    expect(find.text('移除频道成员'), findsOneWidget);
    expect(find.text('Alex Chen'), findsOneWidget);
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
    expect(find.text('产品公告（2）'), findsOneWidget);
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

    expect(asClient.leftChannelId, 'ch_real');
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

    await tester.tap(find.byIcon(Symbols.more_horiz).first);
    await tester.pumpAndSettle();

    expect(find.byType(ChannelInfoPage), findsOneWidget);
    expect(find.text('产品公告'), findsOneWidget);
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
}

class _PublicChannelAsClient extends MockAsClient {
  String? requestedRoomId;

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

  @override
  Future<AsChannel> getPublicChannelByRoomId(
    String roomId, {
    Uri? baseUri,
  }) async {
    requestedRoomId = roomId;
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

class _ChannelInfoMembersAsClient extends MockAsClient {
  String? requestedChannelId;

  @override
  Future<List<AsChannelMember>> getChannelMembers(
    String channelId, {
    String status = '',
  }) async {
    requestedChannelId = channelId;
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
  _PostingChannelAsClient({this.postBody, this.reactedByMe = false});

  final String? postBody;
  final bool reactedByMe;
  String? createdBody;
  String? createdCommentBody;
  AsChannel? updatedChannel;
  String? approvedUserId;
  String? rejectedUserId;
  String? readMarkerChannelId;
  String? readMarkerEventId;
  String? leftChannelId;

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
        body: createdBody ?? postBody ?? '第一条帖子',
        originServerTs:
            DateTime.parse('2026-06-06T10:20:00Z').millisecondsSinceEpoch,
        reactionCount: 2,
        reactedByMe: reactedByMe,
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

  @override
  Future<List<AsChannelComment>> getChannelComments(
    String channelId,
    String postId, {
    int limit = 50,
    int beforeTs = 0,
  }) async {
    return const [];
  }

  @override
  Future<AsChannelComment> createChannelComment(
    String channelId,
    String postId, {
    required String messageType,
    required String body,
    Map<String, Object?> media = const {},
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
    return AsChannelReaction(
      postId: postId,
      channelId: channelId,
      reaction: reaction,
      active: true,
      reactionCount: 1,
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
}

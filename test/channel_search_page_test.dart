import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/im_public_client.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'support/mock_as_client.dart';
import 'package:portal_app/presentation/channel/channel_share.dart';
import 'package:portal_app/presentation/pages/channel_detail_info_page.dart';
import 'package:portal_app/presentation/pages/channel_search_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/im_public_client_provider.dart';
import 'package:portal_app/presentation/widgets/m3/m3_search_field.dart';

void main() {
  testWidgets('channel search uses localized empty state and actions',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    final imPublicClient = _ChannelSearchImPublicClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          imPublicClientProvider.overrideWithValue(imPublicClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const ChannelSearchPage(),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Search channels...'), findsOneWidget);
    expect(find.text('Search channels'), findsOneWidget);
    expect(find.text('Enter a channel ID to find a channel'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'product');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(imPublicClient.lastName, 'product');
    expect(asClient.publicSearchCallCount, 0);
    expect(find.text('Request to join'), findsOneWidget);
  });

  testWidgets('channel search uses public directory and marks approval pending',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    final imPublicClient = _ChannelSearchImPublicClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          imPublicClientProvider.overrideWithValue(imPublicClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelSearchPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '产品');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(imPublicClient.lastName, '产品');
    expect(asClient.publicSearchCallCount, 0);
    expect(find.text('产品公告'), findsOneWidget);
    expect(find.text('申请加入'), findsOneWidget);

    await tester.tap(find.text('申请加入'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(asClient.joinedRoomId, '!ch_product:p2p-im.com');
    expect(find.text('待审核'), findsWidgets);
  });

  testWidgets('channel search hides join action for owned public channels',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    final imPublicClient = _ChannelSearchImPublicClient()
      ..items = [
        _publicChannelListing(
          channelId: 'ch_owned',
          roomId: '!ch_owned:p2p-im.com',
          name: '我的公告',
          description: '自己的频道',
          role: asChannelRoleOwner,
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          imPublicClientProvider.overrideWithValue(imPublicClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelSearchPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '我的公告');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(imPublicClient.lastName, '我的公告');
    expect(find.text('p2p-im.com · 自己的频道'), findsOneWidget);
    expect(find.text('申请加入'), findsNothing);
    expect(find.text('加入'), findsNothing);
  });

  testWidgets('channel search hides join action for locally owned results',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    final imPublicClient = _ChannelSearchImPublicClient()
      ..items = [
        _publicChannelListing(
          channelId: 'ch_cached_owner',
          roomId: '!ch_cached_owner:p2p-im.com',
          name: '本地已有频道',
          description: '目录未带角色',
        ),
      ];
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          channelId: 'ch_cached_owner',
          roomId: '!ch_cached_owner:p2p-im.com',
          name: '本地已有频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
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
          imPublicClientProvider.overrideWithValue(imPublicClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelSearchPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '本地已有频道');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(imPublicClient.lastName, '本地已有频道');
    expect(find.text('p2p-im.com · 目录未带角色'), findsOneWidget);
    expect(find.text('申请加入'), findsNothing);
    expect(find.text('加入'), findsNothing);
  });

  testWidgets('channel search hides join action for joined public channels',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    final imPublicClient = _ChannelSearchImPublicClient()
      ..items = [
        _publicChannelListing(
          channelId: 'ch_joined',
          roomId: '!ch_joined:p2p-im.com',
          name: '已加入频道',
          description: '已经加入',
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          imPublicClientProvider.overrideWithValue(imPublicClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelSearchPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '已加入频道');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(imPublicClient.lastName, '已加入频道');
    expect(find.text('p2p-im.com · 已经加入'), findsOneWidget);
    expect(find.text('已加入'), findsNothing);
    expect(find.text('申请加入'), findsNothing);
    expect(find.text('加入'), findsNothing);
  });

  testWidgets('channel search hides join action for locally joined results',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    final imPublicClient = _ChannelSearchImPublicClient()
      ..items = [
        _publicChannelListing(
          channelId: 'ch_cached_joined',
          roomId: '!ch_cached_joined:p2p-im.com',
          name: '本地加入频道',
          description: '本地已经加入',
        ),
      ];
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026),
      user: const AsSyncUser(userId: '@member:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          channelId: 'ch_cached_joined',
          roomId: '!ch_cached_joined:p2p-im.com',
          name: '本地加入频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
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
          imPublicClientProvider.overrideWithValue(imPublicClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelSearchPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '本地加入频道');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(imPublicClient.lastName, '本地加入频道');
    expect(find.text('p2p-im.com · 本地已经加入'), findsOneWidget);
    expect(find.text('已加入'), findsNothing);
    expect(find.text('申请加入'), findsNothing);
    expect(find.text('加入'), findsNothing);
  });

  testWidgets('channel search result sits close to search field',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    final imPublicClient = _ChannelSearchImPublicClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          imPublicClientProvider.overrideWithValue(imPublicClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelSearchPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '产品');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    final searchRect = tester.getRect(find.byType(M3SearchField));
    final resultRect = tester.getRect(find.text('产品公告'));

    expect(resultRect.top - searchRect.bottom, lessThanOrEqualTo(20));
  });

  testWidgets('channel search treats domain text as public directory name',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    final imPublicClient = _ChannelSearchImPublicClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          imPublicClientProvider.overrideWithValue(imPublicClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelSearchPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'p2p-liyanan.com');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(imPublicClient.lastName, 'p2p-liyanan.com');
    expect(asClient.publicSearchCallCount, 0);
  });

  testWidgets('channel search loads public detail directly for room id',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelSearchPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '!ch_product:p2p-im.com');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.requestedPublicRoomId, '!ch_product:p2p-im.com');
    expect(asClient.publicSearchCallCount, 0);
    expect(find.text('接口返回频道'), findsOneWidget);
    expect(find.text('申请加入'), findsOneWidget);
  });

  testWidgets('channel search passes remote node URL for Matrix room id lookup',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelSearchPage(),
        ),
      ),
    );

    await tester.enterText(
        find.byType(TextField), '!ch_product:dendrite-a:8448');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.requestedPublicRoomId, '!ch_product:dendrite-a:8448');
    expect(asClient.requestedPublicRoomBaseUri, isNull);
    expect(
      asClient.requestedPublicRoomRemoteNodeBaseUri,
      Uri.parse('https://dendrite-a:8448/_p2p'),
    );
    expect(asClient.publicSearchCallCount, 0);
  });

  testWidgets('channel search joins public channel found by remote room id',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelSearchPage(),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      '!ch_product:dendrite-a:8448',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.requestedPublicRoomId, '!ch_product:dendrite-a:8448');
    expect(asClient.requestedPublicRoomBaseUri, isNull);
    expect(
      asClient.requestedPublicRoomRemoteNodeBaseUri,
      Uri.parse('https://dendrite-a:8448/_p2p'),
    );
    expect(find.text('接口返回频道'), findsOneWidget);

    await tester.tap(find.text('申请加入'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(asClient.joinedRoomId, '!ch_product:p2p-im.com');
    expect(
      asClient.joinedRemoteNodeBaseUri,
      Uri.parse('https://p2p-im.com/_p2p'),
    );
    expect(find.text('待审核'), findsWidgets);
    expect(find.textContaining('加入频道失败'), findsNothing);
  });

  testWidgets('channel search treats public room 404 as empty result',
      (tester) async {
    final asClient = _ChannelSearchAsClient()..publicRoomErrorStatus = 404;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelSearchPage(),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      '!missing:dendrite-a:8448',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.requestedPublicRoomId, '!missing:dendrite-a:8448');
    expect(find.text('搜索失败，请稍后重试'), findsNothing);
    expect(find.text('请检查网络或目标节点地址'), findsNothing);
    expect(find.text('没有找到频道'), findsOneWidget);
  });

  testWidgets('channel search opens public detail by room id', (tester) async {
    final asClient = _ChannelSearchAsClient();
    final imPublicClient = _ChannelSearchImPublicClient();
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(path: '/search', builder: (_, __) => const ChannelSearchPage()),
        GoRoute(
          path: '/channel/:channelId/detail',
          builder: (_, state) => ChannelDetailInfoPage(
            channelId: state.pathParameters['channelId']!,
            sharePayload: state.extra is ChannelSharePayload
                ? state.extra! as ChannelSharePayload
                : null,
            showJoinButton: state.extra is ChannelSharePayload,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          imPublicClientProvider.overrideWithValue(imPublicClient),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '产品');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.tap(find.text('产品公告'));
    await tester.pumpAndSettle();

    expect(asClient.requestedPublicRoomId, '!ch_product:p2p-im.com');
    expect(find.text('接口返回频道（0）'), findsOneWidget);
    expect(find.text('#接口返回频道'), findsNothing);
    expect(find.text('ID:!ch_product:p2p-im.com'), findsOneWidget);
    expect(find.text('接口返回频道说明'), findsOneWidget);
    expect(find.text('分享频道'), findsNothing);
  });

  testWidgets('channel search opens joined chat through ProductCore route',
      (tester) async {
    final asClient = _ChannelSearchAsClient()
      ..joinChannelByRoomIdResponse = const AsChannel(
        channelId: 'ch_product',
        roomId: '!ch_product:p2p-im.com',
        homeDomain: 'p2p-im.com',
        name: '产品公告',
        description: '只发布重要产品更新',
        visibility: asChannelVisibilityPublic,
        joinPolicy: asChannelJoinPolicyOpen,
        commentsEnabled: true,
        channelType: asChannelTypeChat,
        memberStatus: asChannelMemberStatusJoined,
        productConversation: AsConversation(
          conversationId: 'conv_channel',
          roomId: '!ch_product:p2p-im.com',
          kind: asConversationKindChannel,
          lifecycle: 'active',
          title: '产品公告',
          avatarUrl: '',
          capabilities: AsConversationCapabilities(open: true),
        ),
      );
    final imPublicClient = _ChannelSearchImPublicClient();
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(path: '/search', builder: (_, __) => const ChannelSearchPage()),
        GoRoute(
          path: '/group/:roomId',
          builder: (_, state) => Text(
            'group:${state.pathParameters['roomId']};'
            'conversation:${state.uri.queryParameters['conversation']}',
          ),
        ),
        GoRoute(
          path: '/channel/:channelId/conversation',
          builder: (_, state) => Text(
            'legacy:${state.pathParameters['channelId']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          imPublicClientProvider.overrideWithValue(imPublicClient),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '产品');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.tap(find.text('申请加入'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(asClient.joinedRoomId, '!ch_product:p2p-im.com');
    expect(find.text('legacy:ch_product'), findsOneWidget);
  });

  testWidgets('private channel share joins with grant without public lookup',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    asClient.joinChannelResponse = const AsChannel(
      channelId: 'ch_private',
      roomId: '!private:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '私密频道',
      description: '邀请可见',
      visibility: asChannelVisibilityPrivate,
      joinPolicy: asChannelJoinPolicyInvite,
      commentsEnabled: true,
      memberStatus: asChannelMemberStatusJoined,
    );
    const payload = ChannelSharePayload(
      channelId: 'ch_private',
      roomId: '!private:p2p-im.com',
      grantId: 'grant-1',
      shareRoomId: '!direct:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '私密频道',
      description: '邀请可见',
      visibility: asChannelVisibilityPrivate,
      joinPolicy: asChannelJoinPolicyInvite,
    );
    final router = GoRouter(
      initialLocation: '/channel/ch_private/detail',
      routes: [
        GoRoute(
          path: '/channel/:channelId/detail',
          builder: (_, state) => ChannelDetailInfoPage(
            channelId: state.pathParameters['channelId']!,
            sharePayload: payload,
            showJoinButton: true,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(asClient.requestedPublicRoomId, isNull);
    expect(find.text('私密频道'), findsOneWidget);

    await tester.tap(find.text('申请加入'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(asClient.joinedChannelId, 'ch_private');
    expect(asClient.joinedChannelRoomId, '!private:p2p-im.com');
    expect(asClient.joinedGrantId, 'grant-1');
    expect(asClient.joinedShareRoomId, '!direct:p2p-im.com');
    expect(asClient.joinedRoomId, isNull);
  });

  testWidgets('member channel share without grant requests public join',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    const payload = ChannelSharePayload(
      channelId: 'ch_private',
      roomId: '!private:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '私密频道',
      description: '邀请可见',
      visibility: asChannelVisibilityPrivate,
      joinPolicy: asChannelJoinPolicyInvite,
    );
    final router = GoRouter(
      initialLocation: '/channel/ch_private/detail',
      routes: [
        GoRoute(
          path: '/channel/:channelId/detail',
          builder: (_, state) => ChannelDetailInfoPage(
            channelId: state.pathParameters['channelId']!,
            sharePayload: payload,
            showJoinButton: true,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('申请加入'));
    await tester.pump();
    await tester.pump();

    expect(asClient.joinedRoomId, '!private:p2p-im.com');
    expect(
        asClient.joinedRemoteNodeBaseUri, Uri.parse('https://p2p-im.com/_p2p'));
    expect(asClient.joinedChannelId, isNull);
    expect(find.text('已申请加入频道'), findsOneWidget);
  });
}

class _ChannelSearchAsClient extends MockAsClient {
  String? joinedRoomId;
  String? joinedChannelId;
  String? joinedChannelRoomId;
  String? joinedGrantId;
  String? joinedShareRoomId;
  String? requestedPublicRoomId;
  Uri? requestedPublicRoomBaseUri;
  Uri? requestedPublicRoomRemoteNodeBaseUri;
  Uri? joinedRemoteNodeBaseUri;
  String? lastPublicSearchQuery;
  Uri? lastPublicSearchBaseUri;
  int? publicRoomErrorStatus;
  int publicSearchCallCount = 0;
  AsChannel? joinChannelByRoomIdResponse;
  AsChannel? joinChannelResponse;

  @override
  Future<List<AsChannel>> searchPublicChannels(
    String query, {
    Uri? baseUri,
    int limit = 20,
  }) async {
    publicSearchCallCount += 1;
    lastPublicSearchQuery = query;
    lastPublicSearchBaseUri = baseUri;
    return const [
      AsChannel(
        channelId: 'ch_product',
        roomId: '!ch_product:p2p-im.com',
        homeDomain: 'p2p-im.com',
        name: '产品公告',
        description: '只发布重要产品更新',
        visibility: asChannelVisibilityPublic,
        joinPolicy: asChannelJoinPolicyApproval,
        commentsEnabled: true,
      ),
    ];
  }

  @override
  Future<AsChannel> joinChannelByRoomId(
    String roomId, {
    String shareToken = '',
    String grantId = '',
    String shareRoomId = '',
    AsChannel? discoveredChannel,
    Uri? remoteNodeBaseUri,
    Uri? requesterNodeBaseUri,
    List<String> serverNames = const [],
  }) async {
    joinedRoomId = roomId;
    joinedRemoteNodeBaseUri = remoteNodeBaseUri;
    final response = joinChannelByRoomIdResponse;
    if (response != null) return response;
    return const AsChannel(
      channelId: 'ch_product',
      roomId: '!ch_product:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '产品公告',
      description: '只发布重要产品更新',
      visibility: asChannelVisibilityPublic,
      joinPolicy: asChannelJoinPolicyApproval,
      commentsEnabled: true,
      memberStatus: asChannelMemberStatusPending,
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
    List<String> serverNames = const [],
  }) async {
    joinedChannelId = channelId;
    joinedChannelRoomId = roomId;
    joinedGrantId = grantId;
    joinedShareRoomId = shareRoomId;
    final response = joinChannelResponse;
    if (response != null) return response;
    return AsChannel(
      channelId: channelId,
      roomId: roomId,
      homeDomain: 'p2p-im.com',
      name: '私密频道',
      description: '邀请可见',
      visibility: asChannelVisibilityPrivate,
      joinPolicy: asChannelJoinPolicyInvite,
      commentsEnabled: true,
      memberStatus: asChannelMemberStatusPending,
    );
  }

  @override
  Future<AsChannel> getPublicChannelByRoomId(
    String roomId, {
    Uri? baseUri,
    Uri? remoteNodeBaseUri,
  }) async {
    requestedPublicRoomId = roomId;
    requestedPublicRoomBaseUri = baseUri;
    requestedPublicRoomRemoteNodeBaseUri = remoteNodeBaseUri;
    final errorStatus = publicRoomErrorStatus;
    if (errorStatus != null) {
      throw AsClientException('not found', statusCode: errorStatus);
    }
    return const AsChannel(
      channelId: 'ch_product',
      roomId: '!ch_product:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '接口返回频道',
      description: '接口返回频道说明',
      visibility: asChannelVisibilityPublic,
      joinPolicy: asChannelJoinPolicyApproval,
      commentsEnabled: true,
    );
  }
}

class _ChannelSearchImPublicClient extends ImPublicClient {
  _ChannelSearchImPublicClient()
      : super(
          baseUri: Uri.parse('https://api.example.com'),
          secret: 'bi-secret',
        );

  String? lastName;
  int callCount = 0;
  List<ImPublicChannelListing> items = [
    _publicChannelListing(
      channelId: 'ch_product',
      roomId: '!ch_product:p2p-im.com',
      name: '产品公告',
      description: '只发布重要产品更新',
    ),
  ];

  @override
  Future<ImPublicChannelPage> listChannels({
    int page = 1,
    int pageSize = 10,
    String name = '',
    String sortBy = 'createdAt',
    bool desc = false,
  }) async {
    callCount += 1;
    lastName = name;
    return ImPublicChannelPage(
      items: items,
      total: 1,
      page: 1,
      pageSize: 10,
    );
  }
}

ImPublicChannelListing _publicChannelListing({
  required String channelId,
  required String roomId,
  required String name,
  required String description,
  String role = '',
  String memberStatus = '',
}) {
  return ImPublicChannelListing(
    id: 1,
    channelDomain: 'https://p2p-im.com',
    roomId: roomId,
    ownerDomain: 'p2p-im.com',
    intro: description,
    channel: AsChannel(
      channelId: channelId,
      roomId: roomId,
      homeDomain: 'p2p-im.com',
      name: name,
      description: description,
      visibility: asChannelVisibilityPublic,
      joinPolicy: asChannelJoinPolicyApproval,
      commentsEnabled: true,
      role: role,
      memberStatus: memberStatus,
    ),
    tagId: 0,
    tag: null,
    status: 1,
    syncStatus: 0,
    failureCount: 0,
    reportCount: 0,
    joinCount: 0,
    lastJoinTime: null,
  );
}

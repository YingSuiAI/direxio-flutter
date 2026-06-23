import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'support/mock_as_client.dart';
import 'package:portal_app/presentation/channel/channel_share.dart';
import 'package:portal_app/presentation/pages/channel_detail_info_page.dart';
import 'package:portal_app/presentation/pages/channel_search_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';

void main() {
  testWidgets('channel search uses localized empty state and actions',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
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

    expect(find.text('Request to join'), findsOneWidget);
  });

  testWidgets('channel search uses public discovery and marks approval pending',
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

    await tester.enterText(find.byType(TextField), '产品');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.lastPublicSearchQuery, '产品');
    expect(asClient.lastPublicSearchBaseUri, isNull);
    expect(find.text('产品公告'), findsOneWidget);
    expect(find.text('申请加入'), findsOneWidget);

    await tester.tap(find.text('申请加入'));
    await tester.pump();
    await tester.pump();

    expect(asClient.joinedRoomId, '!ch_product:p2p-im.com');
    expect(find.text('待审核'), findsWidgets);
  });

  testWidgets('channel search treats domain as target node', (tester) async {
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

    await tester.enterText(find.byType(TextField), 'p2p-liyanan.com');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.lastPublicSearchQuery, '');
    expect(asClient.lastPublicSearchBaseUri?.host, 'p2p-liyanan.com');
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
    await tester.pumpAndSettle();

    expect(asClient.joinedRoomId, '!ch_product:p2p-im.com');
    expect(find.text('legacy:ch_product'), findsOneWidget);
  });

  testWidgets('private channel share joins with grant without public lookup',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
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
    expect(find.text('私密频道（32）'), findsOneWidget);

    await tester.tap(find.text('申请加入'));
    await tester.pump();
    await tester.pump();

    expect(asClient.joinedChannelId, 'ch_private');
    expect(asClient.joinedChannelRoomId, '!private:p2p-im.com');
    expect(asClient.joinedGrantId, 'grant-1');
    expect(asClient.joinedShareRoomId, '!direct:p2p-im.com');
    expect(asClient.joinedRoomId, isNull);
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

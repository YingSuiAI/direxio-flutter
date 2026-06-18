import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/mock_as_client.dart';
import 'package:portal_app/presentation/channel/channel_share.dart';
import 'package:portal_app/presentation/pages/channel_detail_info_page.dart';
import 'package:portal_app/presentation/pages/channel_search_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';

void main() {
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
    expect(find.text('待审核'), findsOneWidget);
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

  testWidgets('channel search maps local dual node room id to host port',
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
    expect(
      asClient.requestedPublicRoomBaseUri.toString(),
      'http://127.0.0.1:18008/_p2p',
    );
    expect(asClient.publicSearchCallCount, 0);
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
    expect(find.text('接口返回频道'), findsOneWidget);
    expect(find.text('#接口返回频道'), findsNothing);
    expect(find.text('ID:!ch_product:p2p-im.com'), findsOneWidget);
    expect(find.text('接口返回频道说明'), findsOneWidget);
  });
}

class _ChannelSearchAsClient extends MockAsClient {
  String? joinedRoomId;
  String? requestedPublicRoomId;
  Uri? requestedPublicRoomBaseUri;
  String? lastPublicSearchQuery;
  Uri? lastPublicSearchBaseUri;
  int publicSearchCallCount = 0;

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
    AsChannel? discoveredChannel,
  }) async {
    joinedRoomId = roomId;
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
  Future<AsChannel> getPublicChannelByRoomId(
    String roomId, {
    Uri? baseUri,
  }) async {
    requestedPublicRoomId = roomId;
    requestedPublicRoomBaseUri = baseUri;
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

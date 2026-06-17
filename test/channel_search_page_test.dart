import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/mock_as_client.dart';
import 'package:portal_app/data/p2p_api_client.dart';
import 'package:portal_app/presentation/channel/channel_share.dart';
import 'package:portal_app/presentation/pages/channel_detail_info_page.dart';
import 'package:portal_app/presentation/pages/channel_search_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/p2p_api_provider.dart';

void main() {
  testWidgets('channel search uses public discovery and marks approval pending',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          p2pApiClientProvider.overrideWithValue(asClient.p2pApiClient),
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

    expect(asClient.p2pApiClient.lastKeyword, '产品');
    expect(asClient.p2pApiClient.lastOwnerDomain, '');
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
          p2pApiClientProvider.overrideWithValue(asClient.p2pApiClient),
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

    expect(asClient.p2pApiClient.lastKeyword, '');
    expect(asClient.p2pApiClient.lastOwnerDomain, 'p2p-liyanan.com');
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
          p2pApiClientProvider.overrideWithValue(asClient.p2pApiClient),
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
  final p2pApiClient = _ChannelSearchP2pApiClient();
  String? joinedRoomId;
  String? requestedPublicRoomId;

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

class _ChannelSearchP2pApiClient extends P2pApiClient {
  _ChannelSearchP2pApiClient()
      : super(baseUri: Uri.parse('http://192.168.1.103:9090'));

  String? lastKeyword;
  String? lastOwnerDomain;

  @override
  Future<List<AsChannel>> listChannels({
    int page = 1,
    int pageSize = 10,
    String ownerDomain = '',
    String keyword = '',
    String sortBy = 'createdAt',
    bool desc = true,
  }) async {
    lastKeyword = keyword;
    lastOwnerDomain = ownerDomain;
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
}

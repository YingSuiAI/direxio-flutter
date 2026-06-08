import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/mock_as_client.dart';
import 'package:portal_app/presentation/pages/channel_search_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';

void main() {
  testWidgets('channel search uses public discovery and marks approval pending',
      (tester) async {
    final asClient = _ChannelSearchAsClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [asClientProvider.overrideWithValue(asClient)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelSearchPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '产品');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.lastQuery, '产品');
    expect(asClient.lastBaseUri, isNull);
    expect(find.text('产品公告'), findsOneWidget);
    expect(find.text('申请加入'), findsOneWidget);

    await tester.tap(find.text('申请加入'));
    await tester.pump();
    await tester.pump();

    expect(asClient.joinedChannelId, 'ch_product');
    expect(asClient.joinedDiscoveredRoomId, '!ch_product:p2p-im.com');
    expect(find.text('待审核'), findsOneWidget);
  });

  testWidgets('channel search treats domain as target node', (tester) async {
    final asClient = _ChannelSearchAsClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [asClientProvider.overrideWithValue(asClient)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelSearchPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'p2p-liyanan.com');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.lastQuery, '');
    expect(asClient.lastBaseUri.toString(), 'https://p2p-liyanan.com/_as');
  });
}

class _ChannelSearchAsClient extends MockAsClient {
  String? lastQuery;
  Uri? lastBaseUri;
  String? joinedChannelId;
  String? joinedDiscoveredRoomId;

  @override
  Future<List<AsChannel>> searchPublicChannels(
    String query, {
    Uri? baseUri,
    int limit = 20,
  }) async {
    lastQuery = query;
    lastBaseUri = baseUri;
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
  Future<AsChannel> joinChannel(
    String channelId, {
    String shareToken = '',
    AsChannel? discoveredChannel,
  }) async {
    joinedChannelId = channelId;
    joinedDiscoveredRoomId = discoveredChannel?.roomId;
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
}

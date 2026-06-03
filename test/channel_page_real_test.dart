import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/pages/channel_page.dart';
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
}

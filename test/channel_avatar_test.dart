import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/channel/channel_home_tab.dart';
import 'package:portal_app/presentation/channel/channel_inbox_data.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/widgets/portal_avatar.dart';

void main() {
  testWidgets('channel inbox tile renders uploaded channel avatar',
      (tester) async {
    final client = Client('ChannelAvatarTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [matrixClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: ChannelInboxTile(
              channel: ChannelInboxItem(
                id: 'ch_avatar',
                roomId: '!avatar:p2p-im.com',
                name: '产品公告',
                domain: 'p2p-im.com',
                avatarUrl: 'https://cdn.example.com/channel.png',
                latestPreview: '频道介绍',
                latestAt: null,
                unreadCount: 0,
                isOwned: true,
                tags: ['文字'],
              ),
              showDivider: false,
            ),
          ),
        ),
      ),
    );

    final avatar = tester.widget<PortalAvatar>(find.byType(PortalAvatar));
    expect(avatar.imageUrl, 'https://cdn.example.com/channel.png');
    expect(avatar.shape, AvatarShape.squircle);
  });

  testWidgets('channel inbox tile opens post list or chat by channel type',
      (tester) async {
    var opened = '';
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: Column(
              children: [
                ChannelInboxTile(
                  channel: ChannelInboxItem(
                    id: 'ch_post',
                    roomId: '!post:p2p-im.com',
                    name: '帖子频道',
                    domain: 'p2p-im.com',
                    avatarUrl: '',
                    latestPreview: '帖子列表',
                    latestAt: null,
                    unreadCount: 0,
                    isOwned: false,
                    channelType: asChannelTypePost,
                    tags: [],
                  ),
                  showDivider: true,
                ),
                ChannelInboxTile(
                  channel: ChannelInboxItem(
                    id: 'ch_chat',
                    roomId: '!chat:p2p-im.com',
                    name: '文字频道',
                    domain: 'p2p-im.com',
                    avatarUrl: '',
                    latestPreview: '文字会话',
                    latestAt: null,
                    unreadCount: 0,
                    isOwned: false,
                    channelType: asChannelTypeChat,
                    tags: [],
                  ),
                  showDivider: false,
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/channel/:channelId',
          builder: (_, state) {
            opened = 'post:${state.pathParameters['channelId']}';
            return const Scaffold(body: Text('post route'));
          },
        ),
        GoRoute(
          path: '/channel/:channelId/conversation',
          builder: (_, state) {
            opened = 'chat:${state.pathParameters['channelId']}';
            return const Scaffold(body: Text('chat route'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('帖子频道'));
    await tester.pumpAndSettle();
    expect(opened, 'post:ch_post');

    router.go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字频道'));
    await tester.pumpAndSettle();
    expect(opened, 'chat:ch_chat');
  });
}

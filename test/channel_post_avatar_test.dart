import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/channel_post_store.dart';
import 'package:portal_app/presentation/pages/channel_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/channel_provider.dart';

import 'support/mock_as_client.dart';

void main() {
  testWidgets('channel post list renders uploaded post image as avatar',
      (tester) async {
    const avatarUrl = 'https://cdn.example.com/post-avatar.png';
    final client = Client('DirexioChannelPostAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 22, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          channelId: 'ch_real',
          roomId: '!real:p2p-im.com',
          name: '产品公告',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
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
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(
            _PostAvatarAsClient(
              const AsChannelPost(
                postId: 'post1',
                channelId: 'ch_real',
                roomId: '!real:p2p-im.com',
                eventId: r'$post1',
                authorId: '@owner:p2p-im.com',
                authorName: 'Yanan',
                messageType: 'm.image',
                body: '第一条帖子',
                originServerTs: 1780730000000,
                media: {
                  'url': avatarUrl,
                  'images': [
                    {'url': avatarUrl, 'name': 'post-avatar.png'},
                  ],
                },
              ),
            ),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          channelPostStoreProvider.overrideWith(
            (ref) async => _MemoryChannelPostStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第一条帖子'), findsAtLeastNWidgets(1));
    expect(
      find.byKey(const ValueKey('channel_post_avatar_$avatarUrl')),
      findsOneWidget,
    );
  });
}

class _PostAvatarAsClient extends MockAsClient {
  _PostAvatarAsClient(this.post);

  final AsChannelPost post;

  @override
  Future<List<AsChannelPost>> getChannelPosts(
    String channelId, {
    int limit = 50,
    int beforeTs = 0,
  }) async {
    return [post];
  }

  @override
  Future<void> updateChannelReadMarker(
    String channelId, {
    required String eventId,
    required int originServerTs,
  }) async {}
}

class _MemoryChannelPostStore implements ChannelPostStore {
  final _posts = <String, AsChannelPost>{};

  @override
  Future<List<AsChannelPost>> readChannel(String channelId) async {
    return _posts.values
        .where((post) => post.channelId.trim() == channelId.trim())
        .toList(growable: false);
  }

  @override
  Future<void> upsertChannel(
    String channelId,
    Iterable<AsChannelPost> posts,
  ) async {
    _posts.removeWhere(
      (_, post) => post.channelId.trim() == channelId.trim(),
    );
    for (final post in posts) {
      await upsertPost(post);
    }
  }

  @override
  Future<void> upsertPost(AsChannelPost post) async {
    _posts['${post.channelId}:${post.postId}:${post.eventId}'] = post;
  }

  @override
  Future<void> removePost(String channelId, String postId) async {
    _posts.removeWhere((_, post) {
      return post.channelId.trim() == channelId.trim() &&
          post.postId.trim() == postId.trim();
    });
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/channel_post_store.dart';
import 'package:portal_app/data/mock_as_client.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/channel_provider.dart';

void main() {
  test('channel posts provider serves cache first then persists AS refresh',
      () async {
    final store = _MemoryChannelPostStore();
    await store.upsertPost(
      _post(postId: 'cached', body: '本地缓存', ts: 1000),
    );
    final remotePosts = Completer<List<AsChannelPost>>();
    final asClient = _ControlledChannelPostsAsClient(remotePosts.future);
    final container = ProviderContainer(
      overrides: [
        asClientProvider.overrideWithValue(asClient),
        channelPostStoreProvider.overrideWith((ref) async => store),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      channelPostsProvider('ch_1'),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await pumpEventQueue();

    expect(
      container
          .read(channelPostsProvider('ch_1'))
          .valueOrNull
          ?.map((post) => post.body),
      ['本地缓存'],
    );

    remotePosts.complete([
      _post(postId: 'fresh', body: 'AS 新帖子', ts: 3000),
      _post(postId: 'cached', body: 'AS 里的缓存帖', ts: 1000),
    ]);
    await pumpEventQueue(times: 5);

    expect(
      container
          .read(channelPostsProvider('ch_1'))
          .valueOrNull
          ?.map((post) => post.body),
      ['AS 新帖子', 'AS 里的缓存帖'],
    );
    expect(
      (await store.readChannel('ch_1')).map((post) => post.body),
      ['AS 新帖子', 'AS 里的缓存帖'],
    );
  });
}

class _ControlledChannelPostsAsClient extends MockAsClient {
  _ControlledChannelPostsAsClient(this.posts);

  final Future<List<AsChannelPost>> posts;

  @override
  Future<List<AsChannelPost>> getChannelPosts(
    String channelId, {
    int limit = 50,
    int beforeTs = 0,
  }) {
    return posts;
  }
}

class _MemoryChannelPostStore implements ChannelPostStore {
  final _posts = <String, AsChannelPost>{};

  @override
  Future<List<AsChannelPost>> readChannel(String channelId) async {
    final posts = _posts.values
        .where((post) => post.channelId == channelId)
        .toList(growable: false)
      ..sort((a, b) => b.originServerTs.compareTo(a.originServerTs));
    return posts;
  }

  @override
  Future<void> upsertChannel(
    String channelId,
    Iterable<AsChannelPost> posts,
  ) async {
    _posts.removeWhere((_, post) => post.channelId == channelId);
    for (final post in posts) {
      await upsertPost(post);
    }
  }

  @override
  Future<void> upsertPost(AsChannelPost post) async {
    _posts[_postKey(post)] = post;
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

  String _postKey(AsChannelPost post) {
    final postId = post.postId.trim();
    if (postId.isNotEmpty) return 'post:$postId';
    return 'event:${post.eventId.trim()}';
  }
}

AsChannelPost _post({
  required String postId,
  required String body,
  required int ts,
}) {
  return AsChannelPost(
    postId: postId,
    channelId: 'ch_1',
    roomId: '!channel:p2p-im.com',
    eventId: '\$$postId',
    authorId: '@owner:p2p-im.com',
    authorName: 'Yanan',
    messageType: 'text',
    body: body,
    originServerTs: ts,
  );
}

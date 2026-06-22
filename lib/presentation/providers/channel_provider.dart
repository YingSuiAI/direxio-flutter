import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/as_client.dart';
import '../../data/channel_post_store.dart';
import 'as_client_provider.dart';

final channelPostStoreProvider = FutureProvider<ChannelPostStore>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return FileChannelPostStore(
    File('${dir.path}/portal_im_channel_posts.json'),
  );
});

final channelPostsProvider = StateNotifierProvider.autoDispose
    .family<ChannelPostsNotifier, AsyncValue<List<AsChannelPost>>, String>(
  (ref, channelId) {
    return ChannelPostsNotifier(
      channelId: channelId,
      asClient: ref.watch(asClientProvider),
      loadStore: () => ref.read(channelPostStoreProvider.future),
    );
  },
);

class ChannelPostsNotifier
    extends StateNotifier<AsyncValue<List<AsChannelPost>>> {
  ChannelPostsNotifier({
    required this.channelId,
    required AsClient asClient,
    required Future<ChannelPostStore> Function() loadStore,
  })  : _asClient = asClient,
        _loadStore = loadStore,
        super(const AsyncValue.loading()) {
    unawaited(_load());
  }

  final String channelId;
  final AsClient _asClient;
  final Future<ChannelPostStore> Function() _loadStore;
  Future<ChannelPostStore>? _storeFuture;
  int _refreshGeneration = 0;

  Future<void> refresh({bool silent = false}) async {
    final generation = ++_refreshGeneration;
    final previous = state.valueOrNull;
    if (!silent && previous == null) {
      state = const AsyncValue.loading();
    }
    try {
      final posts = await _asClient.getChannelPosts(channelId);
      final store = await _store();
      await store.upsertChannel(channelId, posts);
      final cached = await store.readChannel(channelId);
      if (generation == _refreshGeneration) {
        state = AsyncValue.data(cached);
      }
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> upsertLocal(AsChannelPost post) async {
    final store = await _store();
    await store.upsertPost(post);
    state = AsyncValue.data(await store.readChannel(channelId));
  }

  Future<void> removeLocal(String postId) async {
    final trimmed = postId.trim();
    if (trimmed.isEmpty) return;
    final store = await _store();
    await store.removePost(channelId, trimmed);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.where((post) {
          final id = post.postId.trim();
          if (id.isNotEmpty) return id != trimmed;
          return post.eventId.trim() != trimmed;
        }).toList(growable: false),
      );
      return;
    }
    state = AsyncValue.data(await store.readChannel(channelId));
  }

  Future<void> applyReaction(
    String postId,
    AsChannelReaction reaction,
  ) async {
    final trimmedPostId = postId.trim();
    final reactionPostId = reaction.postId.trim();
    if (trimmedPostId.isEmpty && reactionPostId.isEmpty) return;
    final current = state.valueOrNull ??
        await (await _store()).readChannel(
          channelId,
        );
    var changed = false;
    final next = [
      for (final post in current)
        if (_matchesPost(post, trimmedPostId, reactionPostId))
          () {
            changed = true;
            return post.copyWith(
              reactionCount: reaction.reactionCount,
              reactedByMe: reaction.active,
            );
          }()
        else
          post,
    ];
    if (!changed) return;
    final store = await _store();
    await store.upsertChannel(channelId, next);
    state = AsyncValue.data(await store.readChannel(channelId));
  }

  Future<void> _load() async {
    List<AsChannelPost> cached = const [];
    try {
      cached = await (await _store()).readChannel(channelId);
      if (cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      }
    } catch (_) {
      // A corrupt local cache must not prevent the P2P refresh path.
    }
    await refresh(silent: cached.isNotEmpty);
  }

  Future<ChannelPostStore> _store() {
    return _storeFuture ??= _loadStore();
  }

  bool _matchesPost(
    AsChannelPost post,
    String postId,
    String reactionPostId,
  ) {
    final ids = {
      post.postId.trim(),
      post.eventId.trim(),
    }..remove('');
    if (postId.isNotEmpty && ids.contains(postId)) return true;
    if (reactionPostId.isNotEmpty && ids.contains(reactionPostId)) return true;
    return false;
  }
}

final channelCommentsProvider = FutureProvider.autoDispose
    .family<List<AsChannelComment>, ChannelCommentsKey>(
  (ref, key) {
    return ref.watch(asClientProvider).getChannelComments(
          key.channelId,
          key.postId,
        );
  },
);

final channelMembersProvider =
    FutureProvider.autoDispose.family<List<AsChannelMember>, ChannelMembersKey>(
  (ref, key) {
    return ref.watch(asClientProvider).getChannelMembers(
          key.channelId,
          status: key.status,
        );
  },
);

class ChannelCommentsKey {
  const ChannelCommentsKey({required this.channelId, required this.postId});

  final String channelId;
  final String postId;

  @override
  bool operator ==(Object other) {
    return other is ChannelCommentsKey &&
        other.channelId == channelId &&
        other.postId == postId;
  }

  @override
  int get hashCode => Object.hash(channelId, postId);
}

class ChannelMembersKey {
  const ChannelMembersKey({required this.channelId, this.status = ''});

  final String channelId;
  final String status;

  @override
  bool operator ==(Object other) {
    return other is ChannelMembersKey &&
        other.channelId == channelId &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(channelId, status);
}

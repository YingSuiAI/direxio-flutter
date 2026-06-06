import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import 'as_client_provider.dart';

final channelPostsProvider =
    FutureProvider.autoDispose.family<List<AsChannelPost>, String>(
  (ref, channelId) {
    return ref.watch(asClientProvider).getChannelPosts(channelId);
  },
);

final channelCommentsProvider = FutureProvider.autoDispose
    .family<List<AsChannelComment>, ChannelCommentsKey>(
  (ref, key) {
    return ref.watch(asClientProvider).getChannelComments(
          key.channelId,
          key.postId,
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

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/im_public_client_provider.dart';
import '../providers/local_created_channels_provider.dart';

Future<void> leaveChannelThroughAs(WidgetRef ref, String channelId) async {
  final trimmed = channelId.trim();
  if (trimmed.isEmpty) return;
  await ref.read(asClientProvider).leaveChannel(trimmed);
  await _removeChannelLocally(ref, trimmed);
}

Future<void> dissolveChannelThroughAs(WidgetRef ref, String channelId) async {
  final trimmed = channelId.trim();
  if (trimmed.isEmpty) return;
  final roomId = _channelRoomIdForDirectoryClose(ref, trimmed);
  await ref.read(asClientProvider).dissolveChannel(trimmed);
  if (roomId.isNotEmpty) {
    try {
      await ref
          .read(imPublicClientProvider)
          .closeChannelDirectory(roomId: roomId);
    } catch (_) {
      // Directory cleanup must not prevent the local dissolve flow.
    }
  }
  await _removeChannelLocally(ref, trimmed);
}

String _channelRoomIdForDirectoryClose(WidgetRef ref, String channelId) {
  final bootstrap = ref.read(asSyncCacheProvider).bootstrap;
  if (bootstrap == null) return '';
  for (final channel in bootstrap.channels) {
    if (channel.channelId.trim() == channelId ||
        channel.roomId.trim() == channelId) {
      return channel.roomId.trim();
    }
  }
  return '';
}

Future<void> _removeChannelLocally(WidgetRef ref, String channelId) async {
  ref.read(asSyncCacheProvider.notifier).update(
        (state) => state.withoutChannel(channelId),
      );
  await ref
      .read(localCreatedChannelsProvider.notifier)
      .removeChannel(channelId);
  unawaited(_refreshBootstrap(ref));
}

Future<void> _refreshBootstrap(WidgetRef ref) async {
  try {
    final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.copyWith(bootstrap: bootstrap),
        );
  } catch (_) {
    // The local cache was already updated after the leave request succeeded.
  }
}

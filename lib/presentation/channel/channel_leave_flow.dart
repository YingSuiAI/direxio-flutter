import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/local_created_channels_provider.dart';

Future<void> leaveChannelThroughAs(WidgetRef ref, String channelId) async {
  final trimmed = channelId.trim();
  if (trimmed.isEmpty) return;
  await ref.read(asClientProvider).leaveChannel(trimmed);
  ref.read(asSyncCacheProvider.notifier).update(
        (state) => state.withoutChannel(trimmed),
      );
  await ref.read(localCreatedChannelsProvider.notifier).removeChannel(trimmed);
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

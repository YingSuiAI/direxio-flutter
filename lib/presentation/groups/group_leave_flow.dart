import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';

Future<void> leaveGroupThroughAs(WidgetRef ref, String roomId) async {
  final trimmedRoomId = roomId.trim();
  if (trimmedRoomId.isEmpty) return;

  await ref.read(asClientProvider).leaveGroup(trimmedRoomId);
  await _removeGroupLocally(ref, trimmedRoomId);
}

Future<void> dissolveGroupThroughAs(WidgetRef ref, String roomId) async {
  final trimmedRoomId = roomId.trim();
  if (trimmedRoomId.isEmpty) return;

  await ref.read(asClientProvider).dissolveGroup(trimmedRoomId);
  await _removeGroupLocally(ref, trimmedRoomId);
}

Future<void> _removeGroupLocally(WidgetRef ref, String roomId) async {
  ref.read(asSyncCacheProvider.notifier).update(
        (state) => state.withoutGroup(roomId),
      );
  try {
    final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.copyWith(bootstrap: bootstrap),
        );
  } on Object catch (e) {
    debugPrint('refresh bootstrap after group removal failed: $e');
  }
}

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/as_bootstrap_store.dart';
import 'as_client_provider.dart';
import 'as_sync_cache_provider.dart';
import 'auth_provider.dart';

final asBootstrapStoreProvider = FutureProvider<AsBootstrapStore>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return FileAsBootstrapStore(
    File('${dir.path}/direxio_p2p_bootstrap.json'),
  );
});

final asBootstrapRepositoryProvider = Provider<AsBootstrapRepository>((ref) {
  return AsBootstrapRepository(
    loadBootstrap: () async {
      final bootstrap = await ref.read(asClientProvider).syncBootstrap();
      final currentUserId = ref.read(matrixClientProvider).userID;
      if (!asBootstrapBelongsToUser(bootstrap, currentUserId)) {
        throw StateError(
          'P2P bootstrap user mismatch: current=$currentUserId '
          'bootstrap=${bootstrap.user.userId}',
        );
      }
      return bootstrap;
    },
    store: DeferredAsBootstrapStore(
      () => ref.read(asBootstrapStoreProvider.future),
    ),
  );
});

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/as_bootstrap_store.dart';
import 'as_client_provider.dart';

final asBootstrapStoreProvider = FutureProvider<AsBootstrapStore>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return FileAsBootstrapStore(
    File('${dir.path}/portal_im_as_bootstrap.json'),
  );
});

final asBootstrapRepositoryProvider = Provider<AsBootstrapRepository>((ref) {
  return AsBootstrapRepository(
    loadBootstrap: () => ref.read(asClientProvider).syncBootstrap(),
    store: DeferredAsBootstrapStore(
      () => ref.read(asBootstrapStoreProvider.future),
    ),
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/im_public_config.dart';
import '../../data/im_public_client.dart';
import '../../data/im_public_tag_cache.dart';

final imPublicClientProvider = Provider<ImPublicClient>((ref) {
  return ImPublicClient(
    baseUri: Uri.parse(defaultImPublicBaseUrl),
    secret: defaultImPublicSecret,
  );
});

final imPublicTagCacheStoreProvider =
    FutureProvider<ImPublicTagCacheStore>((ref) async {
  final preferences = await SharedPreferences.getInstance();
  return SharedPreferencesImPublicTagCacheStore(preferences);
});

final imPublicChannelTagsProvider =
    FutureProvider.autoDispose<List<ImPublicTag>>((ref) async {
  final store = await ref.watch(imPublicTagCacheStoreProvider.future);
  return loadCachedImPublicChannelTags(
    client: ref.read(imPublicClientProvider),
    store: store,
  );
});

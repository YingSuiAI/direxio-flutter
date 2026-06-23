import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/user_profile_directory.dart';
import 'as_sync_cache_provider.dart';
import 'auth_provider.dart';
import 'product_conversations_provider.dart';
import 'profile_provider.dart';

final userProfileDirectoryProvider = Provider<UserProfileDirectory>((ref) {
  final client = ref.watch(matrixClientProvider);
  final syncCache = ref.watch(asSyncCacheProvider);
  final productConversations =
      ref.watch(productConversationsProvider).valueOrNull ?? const [];
  final currentUserProfile = ref.watch(currentUserProfileProvider).valueOrNull;
  return UserProfileDirectory.fromSources(
    client: client,
    syncCache: syncCache,
    productConversations: productConversations,
    currentUserProfile: currentUserProfile,
  );
});

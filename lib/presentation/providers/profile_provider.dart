import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';

import 'auth_provider.dart';

class CurrentUserProfileCacheStore {
  const CurrentUserProfileCacheStore(this.file);

  final File file;

  Future<Profile?> read(String userId) async {
    final owner = userId.trim();
    if (owner.isEmpty || !await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final cachedUserId = decoded['user_id'] as String? ?? '';
      if (cachedUserId.trim() != owner) return null;
      final avatar = decoded['avatar_url'] as String? ?? '';
      return Profile(
        userId: owner,
        displayName: decoded['display_name'] as String?,
        avatarUrl: avatar.trim().isEmpty ? null : Uri.tryParse(avatar.trim()),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(Profile profile) async {
    final userId = profile.userId.trim();
    if (userId.isEmpty) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'user_id': userId,
        'display_name': profile.displayName ?? '',
        'avatar_url': profile.avatarUrl?.toString() ?? '',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
  }
}

final currentUserProfileCacheStoreProvider =
    FutureProvider<CurrentUserProfileCacheStore>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return CurrentUserProfileCacheStore(
    File('${dir.path}/current_user_profile.json'),
  );
});

/// 当前登录用户的 Matrix Profile。
///
/// 作为独立 provider 供启动预热和「我」页复用。先返回本地缓存，
/// 再用 Matrix profile 刷新缓存，避免重启后首页头像短暂空白。
final currentUserProfileProvider = FutureProvider<Profile?>((ref) async {
  final auth = await ref.watch(authStateNotifierProvider.future);
  final userId = auth.userId;
  if (!auth.isLoggedIn || userId == null || userId.isEmpty) return null;

  final store = await ref.watch(currentUserProfileCacheStoreProvider.future);
  final cached = await store.read(userId);
  if (cached != null) {
    unawaited(_refreshCurrentUserProfileCache(ref, userId, cached));
    return cached;
  }

  try {
    final profile = await ref.read(matrixClientProvider).getProfileFromUserId(
          userId,
          cache: false,
          getFromRooms: false,
        );
    await store.write(profile);
    return profile;
  } catch (_) {
    return null;
  }
});

Future<void> _refreshCurrentUserProfileCache(
  Ref ref,
  String userId,
  Profile cached,
) async {
  try {
    final profile = await ref.read(matrixClientProvider).getProfileFromUserId(
          userId,
          cache: false,
          getFromRooms: false,
        );
    if (!_sameProfile(cached, profile)) {
      final store = await ref.read(currentUserProfileCacheStoreProvider.future);
      await store.write(profile);
      ref.invalidateSelf();
    }
  } catch (error) {
    debugPrint('refresh current user profile cache failed: $error');
  }
}

bool _sameProfile(Profile a, Profile b) {
  return a.userId == b.userId &&
      (a.displayName ?? '') == (b.displayName ?? '') &&
      (a.avatarUrl?.toString() ?? '') == (b.avatarUrl?.toString() ?? '');
}

Future<void> cacheCurrentUserProfile(
  WidgetRef ref, {
  required String userId,
  String displayName = '',
  String avatarUrl = '',
}) async {
  final owner = userId.trim();
  if (owner.isEmpty) return;
  final cleanAvatar = avatarUrl.trim();
  final profile = Profile(
    userId: owner,
    displayName: displayName.trim().isEmpty ? null : displayName.trim(),
    avatarUrl: cleanAvatar.isEmpty ? null : Uri.tryParse(cleanAvatar),
  );
  final store = await ref.read(currentUserProfileCacheStoreProvider.future);
  await store.write(profile);
  ref.invalidate(currentUserProfileProvider);
}

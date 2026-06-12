import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';

import 'auth_provider.dart';

/// 当前登录用户的 Matrix Profile。
///
/// 作为独立 provider 供启动预热和「我」页复用，避免页面各自触发 profile 请求。
final currentUserProfileProvider = FutureProvider<Profile?>((ref) async {
  final auth = await ref.watch(authStateNotifierProvider.future);
  final userId = auth.userId;
  if (!auth.isLoggedIn || userId == null || userId.isEmpty) return null;

  try {
    return await ref.read(matrixClientProvider).getProfileFromUserId(
          userId,
          cache: false,
          getFromRooms: false,
        );
  } catch (_) {
    return null;
  }
});

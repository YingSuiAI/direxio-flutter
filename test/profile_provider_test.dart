import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/providers/profile_provider.dart';

void main() {
  test('current user profile cache persists avatar by user id', () async {
    final dir = await Directory.systemTemp.createTemp('profile_cache_test_');
    addTearDown(() => dir.delete(recursive: true));
    final store = CurrentUserProfileCacheStore(
      File('${dir.path}/current_user_profile.json'),
    );

    await store.write(
      Profile(
        userId: '@owner:p2p-im.com',
        displayName: 'Owner',
        avatarUrl: Uri.parse('mxc://p2p-im.com/owner-avatar'),
      ),
    );

    final cached = await store.read('@owner:p2p-im.com');
    expect(cached?.displayName, 'Owner');
    expect(cached?.avatarUrl.toString(), 'mxc://p2p-im.com/owner-avatar');
    expect(await store.read('@other:p2p-im.com'), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/well_known_service.dart';

void main() {
  test('portal owner parses avatar url', () {
    final owner = PortalOwner.fromJson(const {
      'matrix_user_id': '@alice:portal.local',
      'display_name': 'Alice Chen',
      'avatar_url': 'mxc://portal.local/avatar',
    });

    expect(owner.matrixUserId, '@alice:portal.local');
    expect(owner.displayName, 'Alice Chen');
    expect(owner.avatarUrl, 'mxc://portal.local/avatar');
  });
}

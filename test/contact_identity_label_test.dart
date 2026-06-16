import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/utils/contact_identity_label.dart';

void main() {
  group('contactDisplayNameFromIdentity', () {
    test('uses explicit display name even when it looks like a domain', () {
      expect(
        contactDisplayNameFromIdentity(
          mxid: '@owner:p2p-im.com',
          displayName: 'p2p-im.com',
          domain: 'p2p-im.com',
        ),
        'p2p-im.com',
      );
    });

    test('keeps a real profile display name', () {
      expect(
        contactDisplayNameFromIdentity(
          mxid: '@alice:p2p-liyanan.com',
          displayName: 'Alice Chen',
          domain: 'p2p-liyanan.com',
        ),
        'Alice Chen',
      );
    });

    test('uses mxid localpart when display name is missing', () {
      expect(
        contactDisplayNameFromIdentity(
          mxid: '@owner:p2p-liyanan.com',
          domain: 'p2p-liyanan.com',
        ),
        'owner',
      );
    });
  });
}

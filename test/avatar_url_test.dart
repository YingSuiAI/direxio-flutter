import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/utils/avatar_url.dart';

void main() {
  test('avatarHttpUrl keeps trimmed http urls', () {
    final client = Client('AvatarUrlHttpTest')
      ..homeserver = Uri.parse('https://p2p-im.com');

    expect(
      avatarHttpUrl(client, '  https://cdn.example.com/avatar.png  '),
      'https://cdn.example.com/avatar.png',
    );
  });

  test('avatarHttpUrl converts mxc urls to matrix download urls', () {
    final client = Client('AvatarUrlMxcTest')
      ..homeserver = Uri.parse('https://p2p-im.com');

    final result = avatarHttpUrl(client, 'mxc://example.com/alice');

    expect(result, startsWith('https://p2p-im.com/'));
    expect(result, contains('/download/example.com/alice'));
  });

  test('avatarHttpUrl ignores empty and unsupported urls', () {
    final client = Client('AvatarUrlEmptyTest')
      ..homeserver = Uri.parse('https://p2p-im.com');

    expect(avatarHttpUrl(client, ''), isNull);
    expect(avatarHttpUrl(client, '   '), isNull);
    expect(avatarHttpUrl(client, 'alice-avatar'), isNull);
    expect(avatarHttpUrl(client, 'file:///tmp/avatar.png'), isNull);
  });
}

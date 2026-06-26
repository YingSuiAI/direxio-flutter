import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/utils/avatar_url.dart';
import 'package:portal_app/presentation/widgets/portal_avatar.dart';

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

  test('avatar image headers authenticate Matrix media only', () {
    final client = Client('AvatarHeadersTest')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';

    expect(
      avatarImageHeadersForUrl(
        client,
        'https://p2p-im.com/_matrix/media/v3/download/example.com/avatar',
      ),
      {'authorization': 'Bearer matrix-token'},
    );
    expect(
      avatarImageHeadersForUrl(
        client,
        'https://cdn.example.com/avatar.png',
      ),
      isNull,
    );
  });

  testWidgets('portal avatar keeps cached network images gapless',
      (tester) async {
    final client = Client('AvatarCachedImageTest')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    const imageUrl =
        'https://p2p-im.com/_matrix/media/v3/download/example.com/avatar';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: PortalAvatar(
              seed: '@alice:p2p-im.com',
              imageUrl: imageUrl,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsNothing);

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.gaplessPlayback, isTrue);
    final provider = image.image as CachedNetworkImageProvider;
    expect(provider.url, imageUrl);
    expect(provider.headers, {'authorization': 'Bearer matrix-token'});
    expect(provider.cacheKey, imageUrl);
  });
}

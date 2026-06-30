import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/utils/avatar_url.dart';
import 'package:portal_app/presentation/widgets/group_composite_avatar.dart';
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

  testWidgets('portal avatar reuses loaded bytes after remount',
      (tester) async {
    final client = Client('AvatarMemoryCacheTest')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    const imageUrl =
        'https://p2p-im.com/_matrix/media/v3/download/example.com/avatar';
    final headers = avatarImageHeadersForUrl(client, imageUrl);
    final bytes = Uint8List.fromList(_transparentPngBytes);
    clearPortalAvatarMemoryCacheForTesting();
    addTearDown(clearPortalAvatarMemoryCacheForTesting);
    cachePortalAvatarBytesForTesting(
      imageUrl: imageUrl,
      headers: headers,
      bytes: bytes,
    );

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

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.gaplessPlayback, isTrue);
    expect(image.image, isA<MemoryImage>());
    expect((image.image as MemoryImage).bytes, same(bytes));
  });

  testWidgets('portal avatar isolates its image repaint', (tester) async {
    final bytes = Uint8List.fromList(_transparentPngBytes);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PortalAvatar(
            seed: '@alice:p2p-im.com',
            imageBytes: bytes,
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(PortalAvatar),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
  });

  testWidgets('portal avatar keeps displayed bytes while refreshed url loads',
      (tester) async {
    final client = Client('AvatarRefreshGaplessTest')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    const firstImageUrl =
        'https://p2p-im.com/_matrix/media/v3/download/example.com/avatar-a';
    const refreshedImageUrl =
        'https://p2p-im.com/_matrix/media/v3/download/example.com/avatar-b';
    final headers = avatarImageHeadersForUrl(client, firstImageUrl);
    final bytes = Uint8List.fromList(_transparentPngBytes);
    clearPortalAvatarMemoryCacheForTesting();
    addTearDown(clearPortalAvatarMemoryCacheForTesting);
    cachePortalAvatarBytesForTesting(
      imageUrl: firstImageUrl,
      headers: headers,
      bytes: bytes,
    );

    Widget buildAvatar(String imageUrl) => ProviderScope(
          overrides: [
            matrixClientProvider.overrideWithValue(client),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: PortalAvatar(
                seed: '@alice:p2p-im.com',
                imageUrl: imageUrl,
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildAvatar(firstImageUrl));
    final firstImage = tester.widget<Image>(find.byType(Image));
    expect(firstImage.image, isA<MemoryImage>());
    expect((firstImage.image as MemoryImage).bytes, same(bytes));

    clearPortalAvatarMemoryCacheForTesting();
    await tester.pumpWidget(buildAvatar(refreshedImageUrl));
    await tester.pump();

    final refreshedImage = tester.widget<Image>(find.byType(Image));
    expect(refreshedImage.image, isA<MemoryImage>());
    expect((refreshedImage.image as MemoryImage).bytes, same(bytes));
  });

  testWidgets('portal avatar reuses stable cache key when url changes',
      (tester) async {
    final client = Client('AvatarStableCacheKeyTest')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    const firstImageUrl =
        'https://p2p-im.com/_matrix/media/v3/download/example.com/stable-a';
    const refreshedImageUrl =
        'https://p2p-im.com/_matrix/media/v3/download/example.com/stable-b';
    const stableCacheKey = 'contact:@alice:p2p-im.com';
    final headers = avatarImageHeadersForUrl(client, firstImageUrl);
    final bytes = Uint8List.fromList(_transparentPngBytes);
    clearPortalAvatarMemoryCacheForTesting();
    addTearDown(clearPortalAvatarMemoryCacheForTesting);
    cachePortalAvatarBytesForTesting(
      imageUrl: firstImageUrl,
      headers: headers,
      bytes: bytes,
      stableCacheKey: stableCacheKey,
    );

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
              imageUrl: refreshedImageUrl,
              stableCacheKey: stableCacheKey,
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<MemoryImage>());
    expect((image.image as MemoryImage).bytes, same(bytes));
  });

  testWidgets('portal avatar uses stable disk cache key for refreshed urls',
      (tester) async {
    final client = Client('AvatarStableDiskKeyTest')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    const firstImageUrl =
        'https://p2p-im.com/_matrix/media/v3/download/example.com/disk-a';
    const refreshedImageUrl =
        'https://p2p-im.com/_matrix/media/v3/download/example.com/disk-b';
    const stableCacheKey = 'channel:ch_disk_key';
    clearPortalAvatarMemoryCacheForTesting();
    addTearDown(clearPortalAvatarMemoryCacheForTesting);

    Widget buildAvatar(String imageUrl) => ProviderScope(
          overrides: [
            matrixClientProvider.overrideWithValue(client),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: PortalAvatar(
                seed: '频道公告',
                imageUrl: imageUrl,
                stableCacheKey: stableCacheKey,
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildAvatar(firstImageUrl));
    final firstImage = tester.widget<Image>(find.byType(Image));
    final firstProvider = firstImage.image as CachedNetworkImageProvider;
    expect(firstProvider.url, firstImageUrl);
    expect(firstProvider.cacheKey, isNot(firstImageUrl));
    expect(firstProvider.cacheKey, contains(stableCacheKey));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: PortalAvatar(
              seed: '频道公告',
              imageUrl: refreshedImageUrl,
              stableCacheKey: stableCacheKey,
            ),
          ),
        ),
      ),
    );
    final refreshedImage = tester.widget<Image>(find.byType(Image));
    final refreshedProvider =
        refreshedImage.image as CachedNetworkImageProvider;
    expect(refreshedProvider.url, refreshedImageUrl);
    expect(refreshedProvider.cacheKey, firstProvider.cacheKey);
  });

  testWidgets('portal avatar keeps stable bytes when seed label changes',
      (tester) async {
    final client = Client('AvatarStableSeedChangeTest')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    const firstImageUrl =
        'https://p2p-im.com/_matrix/media/v3/download/example.com/channel-a';
    const refreshedImageUrl =
        'https://p2p-im.com/_matrix/media/v3/download/example.com/channel-b';
    const stableCacheKey = 'channel:ch_seed_change';
    final headers = avatarImageHeadersForUrl(client, firstImageUrl);
    final bytes = Uint8List.fromList(_transparentPngBytes);
    clearPortalAvatarMemoryCacheForTesting();
    addTearDown(clearPortalAvatarMemoryCacheForTesting);
    cachePortalAvatarBytesForTesting(
      imageUrl: firstImageUrl,
      headers: headers,
      bytes: bytes,
      stableCacheKey: stableCacheKey,
    );

    Widget buildAvatar({
      required String seed,
      required String imageUrl,
    }) =>
        ProviderScope(
          overrides: [
            matrixClientProvider.overrideWithValue(client),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: PortalAvatar(
                seed: seed,
                imageUrl: imageUrl,
                stableCacheKey: stableCacheKey,
              ),
            ),
          ),
        );

    await tester.pumpWidget(
      buildAvatar(seed: '产品公告', imageUrl: firstImageUrl),
    );
    final firstImage = tester.widget<Image>(find.byType(Image));
    expect(firstImage.image, isA<MemoryImage>());
    expect((firstImage.image as MemoryImage).bytes, same(bytes));

    clearPortalAvatarMemoryCacheForTesting();
    await tester.pumpWidget(
      buildAvatar(seed: '产品公告频道', imageUrl: refreshedImageUrl),
    );
    await tester.pump();

    final refreshedImage = tester.widget<Image>(find.byType(Image));
    expect(refreshedImage.image, isA<MemoryImage>());
    expect((refreshedImage.image as MemoryImage).bytes, same(bytes));
  });

  testWidgets('group composite avatar keeps member bytes when url refreshes',
      (tester) async {
    final client = Client('GroupCompositeAvatarRefreshTest')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    const firstImageUrl =
        'https://p2p-im.com/_matrix/media/v3/download/example.com/member-a';
    const refreshedImageUrl =
        'https://p2p-im.com/_matrix/media/v3/download/example.com/member-b';
    final headers = avatarImageHeadersForUrl(client, firstImageUrl);
    final bytes = Uint8List.fromList(_transparentPngBytes);
    clearPortalAvatarMemoryCacheForTesting();
    addTearDown(clearPortalAvatarMemoryCacheForTesting);
    cachePortalAvatarBytesForTesting(
      imageUrl: firstImageUrl,
      headers: headers,
      bytes: bytes,
    );

    Widget buildAvatar(String imageUrl) => ProviderScope(
          overrides: [
            matrixClientProvider.overrideWithValue(client),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: GroupCompositeAvatar(
                seed: '群聊',
                size: 48,
                members: [
                  GroupCompositeAvatarMember(
                    seed: '@alice:p2p-im.com',
                    imageUrl: imageUrl,
                  ),
                ],
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildAvatar(firstImageUrl));
    final firstImage = tester.widget<Image>(find.byType(Image));
    expect(firstImage.image, isA<MemoryImage>());
    expect((firstImage.image as MemoryImage).bytes, same(bytes));

    clearPortalAvatarMemoryCacheForTesting();
    await tester.pumpWidget(buildAvatar(refreshedImageUrl));
    await tester.pump();

    final refreshedImage = tester.widget<Image>(find.byType(Image));
    expect(refreshedImage.image, isA<MemoryImage>());
    expect((refreshedImage.image as MemoryImage).bytes, same(bytes));
  });
}

const _transparentPngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

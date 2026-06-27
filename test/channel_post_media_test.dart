import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/channel/channel_post_media.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/matrix_media_cache_provider.dart';

void main() {
  test('channel post media serializes at most nine images with fallback url',
      () {
    final media = channelPostMediaForImages([
      for (var i = 0; i < 11; i++)
        ChannelPostMediaImage(
          url: 'mxc://server/image_$i',
          name: 'image_$i.jpg',
          mimeType: 'image/jpeg',
          size: i + 1,
        ),
    ]);

    expect(media['url'], 'mxc://server/image_0');
    final images = media['images'] as List<Object?>;
    expect(images, hasLength(9));
    expect(
        (images.last as Map<String, Object?>)['url'], 'mxc://server/image_8');
  });

  test('channel post media reads images array and legacy single image', () {
    const post = AsChannelPost(
      postId: 'post1',
      channelId: 'ch1',
      roomId: '!room:server',
      eventId: r'$event',
      authorId: '@u:server',
      messageType: 'm.image',
      body: '图文',
      originServerTs: 1,
      media: {
        'url': 'mxc://server/cover',
        'name': 'cover.jpg',
        'images': [
          {'url': 'mxc://server/a', 'name': 'a.jpg'},
          {'url': 'mxc://server/b', 'name': 'b.jpg'},
        ],
      },
    );

    final images = channelPostImagesFromPost(post);

    expect(
      images.map((image) => image.url),
      ['mxc://server/cover', 'mxc://server/a', 'mxc://server/b'],
    );
  });

  testWidgets('channel post image grid opens images as a swipeable gallery',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider
              .overrideWithValue(Client('ChannelPostMediaTest')),
          matrixMediaBytesCacheProvider.overrideWithValue(
            _FakeMatrixMediaBytesCache(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SizedBox(
              width: 300,
              child: ChannelPostImageGrid(
                images: [
                  ChannelPostMediaImage(
                    url: 'mxc://server/first',
                    name: 'first.png',
                  ),
                  ChannelPostMediaImage(
                    url: 'mxc://server/second',
                    name: 'second.png',
                  ),
                  ChannelPostMediaImage(
                    url: 'mxc://server/third',
                    name: 'third.png',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey('channel_post_image_mxc://server/second'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byIcon(Symbols.close), findsOneWidget);
    expect(find.textContaining('second.png'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('third.png'), findsOneWidget);
  });
}

class _FakeMatrixMediaBytesCache extends MatrixMediaBytesCache {
  @override
  Future<Uint8List> read(Client client, Uri mxc) async {
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
    );
  }
}

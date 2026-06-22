import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/channel/channel_post_media.dart';

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
}

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/chat/product_room_media_send_flow.dart';

void main() {
  test('matrixMediaMessageContent preserves Matrix media fields', () {
    final content = matrixMediaMessageContent(
      msgType: MessageTypes.Image,
      body: 'photo.png',
      filename: 'photo.png',
      mediaUrl: 'mxc://p2p-im.com/photo',
      mimeType: 'image/png',
      size: 1234,
      thumbnailUrl: 'mxc://p2p-im.com/thumb',
      thumbnailMimeType: 'image/jpeg',
      thumbnailSize: 321,
      width: 640,
      height: 360,
      durationMs: 0,
    );

    expect(content['msgtype'], MessageTypes.Image);
    expect(content['url'], 'mxc://p2p-im.com/photo');
    expect(content['filename'], 'photo.png');
    expect(content['info'], {
      'mimetype': 'image/png',
      'size': 1234,
      'w': 640,
      'h': 360,
      'thumbnail_url': 'mxc://p2p-im.com/thumb',
      'thumbnail_info': {
        'mimetype': 'image/jpeg',
        'size': 321,
      },
    });
  });
}

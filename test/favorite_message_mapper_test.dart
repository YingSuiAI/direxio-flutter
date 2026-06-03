import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/chat/favorite_message_mapper.dart';
import 'package:portal_app/presentation/chat/chat_record_forwarding.dart';

void main() {
  test('maps Matrix image content to a favorite snapshot', () {
    final draft = favoriteDraftFromMatrixMessage(
      roomId: '!room:p2p-im.com',
      eventId: r'$image',
      roomType: 'direct',
      senderId: '@alice:p2p-liyanan.com',
      senderName: 'Alice',
      body: 'photo.jpg',
      content: {
        'msgtype': 'm.image',
        'body': 'photo.jpg',
        'url': 'mxc://p2p-im.com/photo',
        'info': {
          'mimetype': 'image/jpeg',
          'size': 12345,
          'w': 640,
          'h': 480,
          'thumbnail_url': 'mxc://p2p-im.com/thumb',
          'thumbnail_info': {
            'mimetype': 'image/jpeg',
            'size': 1234,
          },
        },
      },
      originServerTs: 1779685200000,
    );

    expect(draft.messageType, 'image');
    expect(draft.url, 'mxc://p2p-im.com/photo');
    expect(draft.filename, 'photo.jpg');
    expect(draft.mimeType, 'image/jpeg');
    expect(draft.size, 12345);
    expect(draft.thumbnailUrl, 'mxc://p2p-im.com/thumb');
    expect(draft.thumbnailMimeType, 'image/jpeg');
    expect(draft.thumbnailSize, 1234);
    expect(draft.width, 640);
    expect(draft.height, 480);
  });

  test('classifies text containing an URL as a link favorite', () {
    final draft = favoriteDraftFromMatrixMessage(
      roomId: '!room:p2p-im.com',
      eventId: r'$link',
      roomType: 'group',
      senderId: '@bob:p2p-im.com',
      senderName: 'Bob',
      body: '看看 https://p2p-im.com/docs',
      content: const {
        'msgtype': 'm.text',
        'body': '看看 https://p2p-im.com/docs',
      },
      originServerTs: 1779685200000,
    );

    expect(draft.messageType, 'link');
    expect(draft.roomType, 'group');
    expect(draft.url, 'https://p2p-im.com/docs');
    expect(draft.body, '看看 https://p2p-im.com/docs');
  });

  test('maps forwarded chat record content to a chat record favorite', () {
    final payload = buildChatRecordPayload(
      sourceRoomId: '!dm:p2p-im.com',
      sourceRoomType: 'direct',
      sourceName: 'Alice',
      messages: const [
        ChatRecordSourceMessage(
          senderName: 'Alice',
          body: '第一条',
          messageType: 'text',
          originServerTs: 1779685200000,
        ),
      ],
    );

    final draft = favoriteDraftFromMatrixMessage(
      roomId: '!target:p2p-im.com',
      eventId: r'$record',
      roomType: 'group',
      senderId: '@owner:p2p-im.com',
      senderName: 'Yanan',
      body: payload.body,
      content: payload.matrixContent,
      originServerTs: 1779685300000,
    );

    expect(draft.messageType, 'chat_record');
    expect(draft.roomType, 'group');
    expect(draft.body, '与 Alice 的聊天记录');
    expect(draft.url, isEmpty);
    expect(draft.chatRecord['title'], '与 Alice 的聊天记录');
    expect(draft.chatRecord['items'], isA<List<Object?>>());
  });

  test('uses saved owner-node media URL when provided', () {
    final draft = favoriteDraftFromMatrixMessage(
      roomId: '!room:p2p-im.com',
      eventId: r'$remote-video',
      roomType: 'direct',
      senderId: '@alice:p2p-liyanan.com',
      body: 'clip.mov',
      content: {
        'msgtype': 'm.video',
        'body': 'clip.mov',
        'url': 'mxc://p2p-liyanan.com/video',
        'info': {
          'mimetype': 'video/quicktime',
          'size': 4567,
          'duration': 2100,
          'thumbnail_url': 'mxc://p2p-liyanan.com/thumb',
        },
      },
      originServerTs: 1779685200000,
      savedMediaUrl: 'mxc://p2p-im.com/video-copy',
      savedThumbnailUrl: 'mxc://p2p-im.com/thumb-copy',
    );

    expect(draft.messageType, 'video');
    expect(draft.url, 'mxc://p2p-im.com/video-copy');
    expect(draft.thumbnailUrl, 'mxc://p2p-im.com/thumb-copy');
    expect(draft.durationMs, 2100);
  });

  test('detects when media must be copied to the owner node', () {
    expect(
      favoriteMediaNeedsOwnerCopy(
        mediaUrl: 'mxc://p2p-liyanan.com/file',
        ownerUserId: '@owner:p2p-im.com',
      ),
      isTrue,
    );
    expect(
      favoriteMediaNeedsOwnerCopy(
        mediaUrl: 'mxc://p2p-im.com/file',
        ownerUserId: '@owner:p2p-im.com',
      ),
      isFalse,
    );
  });
}

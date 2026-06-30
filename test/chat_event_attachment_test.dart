import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/utils/chat_event_attachment.dart';

void main() {
  test('adds video extension from mimetype when event body has no extension',
      () {
    final client = Client('ChatEventAttachmentFileNameTest')
      ..setUserId('@me:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final event = Event(
      room: room,
      eventId: r'$video-no-extension',
      senderId: '@alice:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 29),
      content: {
        'msgtype': MessageTypes.Video,
        'body': 'video',
        'url': 'mxc://p2p-im.com/video',
        'info': {'mimetype': 'video/mp4'},
      },
    );

    final name = chatEventAttachmentFileName(
      event,
      MatrixFile(bytes: Uint8List.fromList([1, 2, 3]), name: ''),
      fallbackName: event.body,
    );

    expect(name, 'video.mp4');
  });

  test('keeps existing media extension when Matrix file name has one', () {
    final client = Client('ChatEventAttachmentExistingFileNameTest')
      ..setUserId('@me:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final event = Event(
      room: room,
      eventId: r'$video-extension',
      senderId: '@alice:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 29),
      content: {
        'msgtype': MessageTypes.Video,
        'body': 'video',
        'url': 'mxc://p2p-im.com/video',
        'info': {'mimetype': 'video/mp4'},
      },
    );

    final name = chatEventAttachmentFileName(
      event,
      MatrixFile(bytes: Uint8List.fromList([1, 2, 3]), name: 'clip.mov'),
      fallbackName: event.body,
    );

    expect(name, 'clip.mov');
  });

  test('downloads attachment when AS puts media url in info map', () async {
    final requests = <Uri>[];
    final client = Client(
      'ChatEventAttachmentCompatTest',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        return http.Response.bytes([1, 2, 3, 4], 200);
      }),
    )
      ..setUserId('@me:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final event = Event(
      room: room,
      eventId: r'$voice-info-url',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 12),
      content: {
        'msgtype': MessageTypes.File,
        'body': 'voice',
        'info': {
          'url': 'mxc://p2p-im.com/voice',
          'mime_type': 'audio/mp4',
          'duration_ms': 1500,
          'size': 4,
        },
      },
    );

    final file = await downloadChatEventAttachment(event);

    expect(file.bytes, [1, 2, 3, 4]);
    expect(requests.single.path, contains('/download/p2p-im.com/voice'));
  });

  test('downloads thumbnail when AS puts thumbnail url at top level', () async {
    final requests = <Uri>[];
    final client = Client(
      'ChatEventThumbnailCompatTest',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        return http.Response.bytes([9, 8, 7, 6], 200);
      }),
    )
      ..setUserId('@me:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final event = Event(
      room: room,
      eventId: r'$video-thumb-url',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 12),
      content: {
        'msgtype': MessageTypes.Video,
        'body': 'video.mp4',
        'url': 'mxc://p2p-im.com/video',
        'thumbnail_url': 'mxc://p2p-im.com/video-thumb',
        'thumbnail_mime_type': 'image/jpeg',
        'thumbnail_size': 4,
      },
    );

    final file = await downloadChatEventThumbnail(event);

    expect(file.bytes, [9, 8, 7, 6]);
    expect(requests.single.path, contains('/download/p2p-im.com/video-thumb'));
  });

  test('downloads thumbnail when AS puts thumbnail info at top level',
      () async {
    final requests = <Uri>[];
    final client = Client(
      'ChatEventTopLevelThumbnailInfoCompatTest',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        return http.Response.bytes([9, 8, 7, 6], 200);
      }),
    )
      ..setUserId('@me:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final event = Event(
      room: room,
      eventId: r'$video-top-level-thumb-info',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 12),
      content: {
        'msgtype': MessageTypes.Video,
        'body': 'video.mp4',
        'url': 'mxc://p2p-im.com/video',
        'thumbnail_url': 'mxc://p2p-im.com/video-thumb',
        'thumbnail_info': {
          'mimetype': 'image/jpeg',
          'size': 4,
        },
      },
    );

    final file = await downloadChatEventThumbnail(event);

    expect(file.bytes, [9, 8, 7, 6]);
    expect(requests.single.path, contains('/download/p2p-im.com/video-thumb'));
  });

  test('downloads image body when received image has no thumbnail', () async {
    final requests = <Uri>[];
    final client = Client(
      'ChatEventImageBodyFallbackThumbnailTest',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        if (request.url.path.contains('/thumbnail/')) {
          return http.Response('missing thumbnail', 404);
        }
        return http.Response.bytes([5, 4, 3, 2], 200);
      }),
    )
      ..setUserId('@me:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final event = Event(
      room: room,
      eventId: r'$image-no-thumb',
      senderId: '@alice:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 12),
      content: {
        'msgtype': MessageTypes.Image,
        'body': 'photo.jpg',
        'url': 'mxc://p2p-im.com/photo',
        'info': {
          'mimetype': 'image/jpeg',
          'size': 4,
          'w': 120,
          'h': 80,
        },
      },
    );

    final file = await downloadChatEventThumbnail(event);

    expect(file.bytes, [5, 4, 3, 2]);
    expect(requests, hasLength(1));
    expect(requests.single.path, contains('/download/p2p-im.com/photo'));
  });

  test('uses image body when received image thumbnail is unusable', () async {
    final requests = <Uri>[];
    final client = Client(
      'ChatEventBadImageThumbnailFallbackTest',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        return http.Response.bytes([5, 4, 3, 2], 200);
      }),
    )
      ..setUserId('@me:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final event = Event(
      room: room,
      eventId: r'$image-bad-thumb',
      senderId: '@alice:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 12),
      content: {
        'msgtype': MessageTypes.Image,
        'body': 'photo.jpg',
        'url': 'mxc://p2p-im.com/photo',
        'thumbnail_url': 'mxc://p2p-im.com/bad-thumb',
        'thumbnail_mime_type': 'image/jpeg',
        'info': {
          'mimetype': 'image/jpeg',
          'size': 4,
          'w': 120,
          'h': 80,
        },
      },
    );

    final file = await downloadChatEventThumbnail(event);

    expect(file.bytes, [5, 4, 3, 2]);
    expect(requests, hasLength(1));
    expect(requests.single.path, contains('/download/p2p-im.com/photo'));
  });

  test('does not download video body as thumbnail when thumbnail is missing',
      () async {
    final client = Client(
      'ChatEventMissingVideoThumbnailTest',
      httpClient: MockClient((request) async {
        fail('video body must not be downloaded as a thumbnail');
      }),
    )
      ..setUserId('@me:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final event = Event(
      room: room,
      eventId: r'$video-no-thumb',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 12),
      content: {
        'msgtype': MessageTypes.Video,
        'body': 'video.mp4',
        'url': 'mxc://p2p-im.com/video',
        'info': {'mimetype': 'video/mp4'},
      },
    );

    await expectLater(downloadChatEventThumbnail(event), throwsA(anything));
  });

  test('does not download video body when thumbnail points to media url',
      () async {
    final client = Client(
      'ChatEventBadVideoThumbnailTest',
      httpClient: MockClient((request) async {
        fail('video body must not be downloaded as a thumbnail');
      }),
    )
      ..setUserId('@me:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final event = Event(
      room: room,
      eventId: r'$video-bad-thumb',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 12),
      content: {
        'msgtype': MessageTypes.Video,
        'body': 'video.mp4',
        'url': 'mxc://p2p-im.com/video',
        'info': {
          'mimetype': 'video/mp4',
          'thumbnail_url': 'mxc://p2p-im.com/video',
          'thumbnail_info': {'mimetype': 'video/mp4'},
        },
      },
    );

    await expectLater(downloadChatEventThumbnail(event), throwsA(anything));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/utils/chat_event_attachment.dart';

void main() {
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

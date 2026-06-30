import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/chat/chat_event_preview_thumbnail.dart';
import 'package:portal_app/presentation/chat/video_thumbnailer.dart';

void main() {
  test('falls back to generated video frame when Matrix thumbnail is missing',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('video-preview-test');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final event = _event(MessageTypes.Video);
    var attachmentDownloaded = false;
    var thumbnailPath = '';

    final bytes = await loadChatEventPreviewThumbnail(
      event,
      downloadThumbnail: (_) async => throw StateError('missing thumbnail'),
      downloadAttachment: (_) async {
        attachmentDownloaded = true;
        return MatrixFile(
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'clip.mp4',
        );
      },
      createVideoThumbnail: (path) async {
        thumbnailPath = path;
        expect(path, endsWith('.mp4'));
        expect(await File(path).readAsBytes(), [1, 2, 3]);
        return ChatVideoThumbnail(
          bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
          mimeType: 'image/jpeg',
          width: 320,
          height: 180,
          durationMs: 1000,
        );
      },
      temporaryDirectoryProvider: () async => tempDir,
    );

    expect(bytes, [0xFF, 0xD8, 0xFF, 0xE0]);
    expect(attachmentDownloaded, isTrue);
    expect(thumbnailPath, isNotEmpty);
  });

  test('uses event mimetype extension for generated video frame temp file',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('video-preview-test');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final event = _event(
      MessageTypes.Video,
      body: 'video',
      info: {'mimetype': 'video/webm'},
    );
    var thumbnailPath = '';

    final bytes = await loadChatEventPreviewThumbnail(
      event,
      downloadThumbnail: (_) async => throw StateError('missing thumbnail'),
      downloadAttachment: (_) async {
        return MatrixFile(
          bytes: Uint8List.fromList([1, 2, 3]),
          name: '',
        );
      },
      createVideoThumbnail: (path) async {
        thumbnailPath = path;
        expect(path, endsWith('.webm'));
        return ChatVideoThumbnail(
          bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
          mimeType: 'image/jpeg',
          width: 320,
          height: 180,
          durationMs: 1000,
        );
      },
      temporaryDirectoryProvider: () async => tempDir,
    );

    expect(bytes, [0xFF, 0xD8, 0xFF, 0xE0]);
    expect(thumbnailPath, isNotEmpty);
  });

  test('falls back to generated video frame when thumbnail bytes are not image',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('video-preview-test');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final event = _event(MessageTypes.Video);
    var attachmentDownloaded = false;

    final bytes = await loadChatEventPreviewThumbnail(
      event,
      downloadThumbnail: (_) async => MatrixFile(
        bytes: Uint8List.fromList([0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70]),
        name: 'not-image.mp4',
      ),
      downloadAttachment: (_) async {
        attachmentDownloaded = true;
        return MatrixFile(
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'clip.mp4',
        );
      },
      createVideoThumbnail: (_) async {
        return ChatVideoThumbnail(
          bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
          mimeType: 'image/jpeg',
          width: 320,
          height: 180,
          durationMs: 1000,
        );
      },
      temporaryDirectoryProvider: () async => tempDir,
    );

    expect(bytes, [0xFF, 0xD8, 0xFF, 0xE0]);
    expect(attachmentDownloaded, isTrue);
  });

  test('does not download non-video body when thumbnail loading fails',
      () async {
    final event = _event(MessageTypes.Image);

    await expectLater(
      loadChatEventPreviewThumbnail(
        event,
        downloadThumbnail: (_) async => throw StateError('missing thumbnail'),
        downloadAttachment: (_) async {
          fail('image fallback must stay in downloadChatEventThumbnail');
        },
      ),
      throwsA(isA<StateError>()),
    );
  });
}

Event _event(
  String msgtype, {
  String? body,
  Map<String, Object?> info = const <String, Object?>{},
}) {
  final client = Client('ChatEventPreviewThumbnailTest')
    ..setUserId('@me:p2p-im.com')
    ..homeserver = Uri.parse('https://p2p-im.com');
  final room = Room(id: '!room:p2p-im.com', client: client);
  return Event(
    room: room,
    eventId: r'$event',
    senderId: '@alice:p2p-im.com',
    type: EventTypes.Message,
    originServerTs: DateTime.utc(2026, 6, 29),
    content: {
      'msgtype': msgtype,
      'body':
          body ?? (msgtype == MessageTypes.Video ? 'clip.mp4' : 'photo.jpg'),
      'url': msgtype == MessageTypes.Video
          ? 'mxc://p2p-im.com/clip'
          : 'mxc://p2p-im.com/photo',
      if (info.isNotEmpty) 'info': info,
    },
  );
}

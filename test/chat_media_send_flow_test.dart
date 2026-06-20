import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/chat/chat_media_send_flow.dart';

void main() {
  test('sends selected image through Matrix media upload then product route',
      () async {
    final calls = <String>[];

    final result = await sendProductChatMedia(
      roomId: '!alice:p2p-im.com',
      attachment: ChatMediaAttachment.image(
        name: 'photo.png',
        bytes: [1, 2, 3],
        mimeType: 'image/png',
      ),
      uploadContent: (bytes, {required filename, contentType}) async {
        calls.add('upload:$filename:$contentType:${bytes.length}');
        return Uri.parse('mxc://p2p-im.com/photo');
      },
      sendMedia: ({
        required roomId,
        required msgType,
        required body,
        required filename,
        required mediaUrl,
        String mimeType = '',
        int size = 0,
        String thumbnailUrl = '',
        String thumbnailMimeType = '',
        int thumbnailSize = 0,
        int width = 0,
        int height = 0,
        int durationMs = 0,
      }) async {
        calls.add(
          'send:$roomId:$msgType:$body:$filename:$mediaUrl:$mimeType:$size',
        );
        return r'$media';
      },
      oneShotSync: () async => calls.add('sync'),
    );

    expect(result.eventId, r'$media');
    expect(result.mediaUrl.toString(), 'mxc://p2p-im.com/photo');
    expect(calls, [
      'upload:photo.png:image/png:3',
      'send:!alice:p2p-im.com:m.image:photo.png:photo.png:mxc://p2p-im.com/photo:image/png:3',
      'sync',
    ]);
  });

  test('sends group media through the same product route', () async {
    String? sentRoomId;
    String? sentMsgType;

    final result = await sendProductChatMedia(
      roomId: '!group:p2p-im.com',
      attachment: ChatMediaAttachment.file(
        name: 'brief.pdf',
        bytes: [1, 2, 3],
        mimeType: 'application/pdf',
      ),
      uploadContent: (_, {required filename, contentType}) async {
        return Uri.parse('mxc://p2p-im.com/brief');
      },
      sendMedia: ({
        required roomId,
        required msgType,
        required body,
        required filename,
        required mediaUrl,
        String mimeType = '',
        int size = 0,
        String thumbnailUrl = '',
        String thumbnailMimeType = '',
        int thumbnailSize = 0,
        int width = 0,
        int height = 0,
        int durationMs = 0,
      }) async {
        sentRoomId = roomId;
        sentMsgType = msgType;
        return r'$group-file';
      },
      oneShotSync: () async {},
    );

    expect(result.eventId, r'$group-file');
    expect(sentRoomId, '!group:p2p-im.com');
    expect(sentMsgType, 'm.file');
  });

  test('sends voice recordings as Matrix audio media with metadata', () async {
    String? sentMsgType;
    String? sentMimeType;
    int? sentDurationMs;

    final result = await sendProductChatMedia(
      roomId: '!voice:p2p-im.com',
      attachment: ChatMediaAttachment.audio(
        name: 'portal_voice.m4a',
        bytes: [1, 2, 3, 4],
        mimeType: 'audio/mp4',
        durationMs: 2460,
      ),
      uploadContent: (_, {required filename, contentType}) async {
        expect(filename, 'portal_voice.m4a');
        expect(contentType, 'audio/mp4');
        return Uri.parse('mxc://p2p-im.com/voice');
      },
      sendMedia: ({
        required roomId,
        required msgType,
        required body,
        required filename,
        required mediaUrl,
        String mimeType = '',
        int size = 0,
        String thumbnailUrl = '',
        String thumbnailMimeType = '',
        int thumbnailSize = 0,
        int width = 0,
        int height = 0,
        int durationMs = 0,
      }) async {
        sentMsgType = msgType;
        sentMimeType = mimeType;
        sentDurationMs = durationMs;
        return r'$voice';
      },
      oneShotSync: () async {},
    );

    expect(result.eventId, r'$voice');
    expect(sentMsgType, 'm.audio');
    expect(sentMimeType, 'audio/mp4');
    expect(sentDurationMs, 2460);
  });

  test('surfaces upload stage when media never reaches AS', () async {
    await expectLater(
      sendProductChatMedia(
        roomId: '!alice:p2p-im.com',
        attachment: ChatMediaAttachment.image(
          name: 'photo.png',
          bytes: [1],
          mimeType: 'image/png',
        ),
        uploadContent: (_, {required filename, contentType}) async {
          throw TimeoutException('network');
        },
        sendMedia: ({
          required roomId,
          required msgType,
          required body,
          required filename,
          required mediaUrl,
          String mimeType = '',
          int size = 0,
          String thumbnailUrl = '',
          String thumbnailMimeType = '',
          int thumbnailSize = 0,
          int width = 0,
          int height = 0,
          int durationMs = 0,
        }) async {
          fail('product media send must not be called after upload failure');
        },
        oneShotSync: () async {},
      ),
      throwsA(
        isA<ChatMediaSendException>()
            .having((e) => e.stage, 'stage', ChatMediaSendStage.upload)
            .having((e) => e.userMessage, 'userMessage', '图片上传失败，请检查网络后重试'),
      ),
    );
  });

  test('does not fail a sent media event when one-shot sync fails', () async {
    Object? syncFailure;

    final result = await sendProductChatMedia(
      roomId: '!alice:p2p-im.com',
      attachment: ChatMediaAttachment.file(
        name: 'report.pdf',
        bytes: [1, 2],
      ),
      uploadContent: (_, {required filename, contentType}) async {
        return Uri.parse('mxc://p2p-im.com/report');
      },
      sendMedia: ({
        required roomId,
        required msgType,
        required body,
        required filename,
        required mediaUrl,
        String mimeType = '',
        int size = 0,
        String thumbnailUrl = '',
        String thumbnailMimeType = '',
        int thumbnailSize = 0,
        int width = 0,
        int height = 0,
        int durationMs = 0,
      }) async {
        expect(msgType, 'm.file');
        return r'$file';
      },
      oneShotSync: () async => throw StateError('sync failed'),
      onSyncFailure: (error, _) => syncFailure = error,
    );

    expect(result.eventId, r'$file');
    expect(syncFailure, isA<StateError>());
  });

  test('sends selected video as Matrix video through product route', () async {
    final calls = <String>[];

    final result = await sendProductChatMedia(
      roomId: '!alice:p2p-im.com',
      attachment: ChatMediaAttachment.video(
        name: 'clip.mov',
        bytes: [1, 2, 3, 4],
        mimeType: 'video/quicktime',
      ),
      uploadContent: (bytes, {required filename, contentType}) async {
        calls.add('upload:$filename:$contentType:${bytes.length}');
        return Uri.parse('mxc://p2p-im.com/clip');
      },
      sendMedia: ({
        required roomId,
        required msgType,
        required body,
        required filename,
        required mediaUrl,
        String mimeType = '',
        int size = 0,
        String thumbnailUrl = '',
        String thumbnailMimeType = '',
        int thumbnailSize = 0,
        int width = 0,
        int height = 0,
        int durationMs = 0,
      }) async {
        calls.add(
          'send:$roomId:$msgType:$body:$filename:$mediaUrl:$mimeType:$size',
        );
        return r'$video';
      },
      oneShotSync: () async => calls.add('sync'),
    );

    expect(result.eventId, r'$video');
    expect(calls, [
      'upload:clip.mov:video/quicktime:4',
      'send:!alice:p2p-im.com:m.video:clip.mov:clip.mov:mxc://p2p-im.com/clip:video/quicktime:4',
      'sync',
    ]);
  });

  test('sends selected video thumbnail metadata through product route',
      () async {
    final calls = <String>[];

    final result = await sendProductChatMedia(
      roomId: '!alice:p2p-im.com',
      attachment: ChatMediaAttachment.video(
        name: 'clip.mov',
        bytes: [1, 2, 3, 4],
        mimeType: 'video/quicktime',
        thumbnailBytes: [9, 8, 7],
        thumbnailMimeType: 'image/jpeg',
        width: 640,
        height: 360,
        durationMs: 2100,
      ),
      uploadContent: (bytes, {required filename, contentType}) async {
        calls.add('upload:$filename:$contentType:${bytes.length}');
        if (filename == 'clip.mov') {
          return Uri.parse('mxc://p2p-im.com/clip');
        }
        return Uri.parse('mxc://p2p-im.com/clip-thumb');
      },
      sendMedia: ({
        required roomId,
        required msgType,
        required body,
        required filename,
        required mediaUrl,
        String mimeType = '',
        int size = 0,
        String thumbnailUrl = '',
        String thumbnailMimeType = '',
        int thumbnailSize = 0,
        int width = 0,
        int height = 0,
        int durationMs = 0,
      }) async {
        calls.add(
          'send:$roomId:$msgType:$mediaUrl:$thumbnailUrl:$thumbnailMimeType:$thumbnailSize:$width:$height:$durationMs',
        );
        return r'$video';
      },
      oneShotSync: () async => calls.add('sync'),
    );

    expect(result.eventId, r'$video');
    expect(calls, [
      'upload:clip.mov:video/quicktime:4',
      'upload:clip-thumb.jpg:image/jpeg:3',
      'send:!alice:p2p-im.com:m.video:mxc://p2p-im.com/clip:mxc://p2p-im.com/clip-thumb:image/jpeg:3:640:360:2100',
      'sync',
    ]);
  });

  test('surfaces video upload stage with video label', () async {
    await expectLater(
      sendProductChatMedia(
        roomId: '!alice:p2p-im.com',
        attachment: ChatMediaAttachment.video(
          name: 'clip.mp4',
          bytes: [1],
          mimeType: 'video/mp4',
        ),
        uploadContent: (_, {required filename, contentType}) async {
          throw TimeoutException('network');
        },
        sendMedia: ({
          required roomId,
          required msgType,
          required body,
          required filename,
          required mediaUrl,
          String mimeType = '',
          int size = 0,
          String thumbnailUrl = '',
          String thumbnailMimeType = '',
          int thumbnailSize = 0,
          int width = 0,
          int height = 0,
          int durationMs = 0,
        }) async {
          fail('product media send must not be called after upload failure');
        },
        oneShotSync: () async {},
      ),
      throwsA(
        isA<ChatMediaSendException>()
            .having((e) => e.stage, 'stage', ChatMediaSendStage.upload)
            .having((e) => e.userMessage, 'userMessage', '视频上传失败，请检查网络后重试'),
      ),
    );
  });

  test('continues attachment flow after closing plus panel', () async {
    var closed = false;
    var sent = false;
    final notices = <String>[];

    await pickAndSendChatMediaAttachment(
      closePanel: () => closed = true,
      pickAttachment: () async {
        expect(closed, isTrue);
        return ChatMediaAttachment.image(name: 'photo.png', bytes: [1]);
      },
      sendAttachment: (attachment) async {
        expect(attachment.name, 'photo.png');
        sent = true;
      },
      showNotice: (message, {duration = const Duration(seconds: 2)}) {
        notices.add(message);
      },
      emptySelectionMessage: '未选择图片',
    );

    expect(sent, isTrue);
    expect(notices, isEmpty);
  });

  test('sends multiple selected attachments in picker order', () async {
    final sent = <String>[];

    await pickAndSendChatMediaAttachments(
      closePanel: () {},
      pickAttachments: () async => [
        ChatMediaAttachment.image(name: 'first.png', bytes: [1]),
        ChatMediaAttachment.image(name: 'second.png', bytes: [2]),
        ChatMediaAttachment.image(name: 'third.png', bytes: [3]),
      ],
      sendAttachment: (attachment) async {
        sent.add(attachment.name);
      },
      showNotice: (_, {duration = const Duration(seconds: 2)}) {},
      emptySelectionMessage: '未选择图片',
    );

    expect(sent, ['first.png', 'second.png', 'third.png']);
  });

  test('prepares all selected attachments before sending the first one',
      () async {
    final calls = <String>[];

    await pickAndSendChatMediaAttachments(
      closePanel: () {},
      pickAttachments: () async => [
        ChatMediaAttachment.image(name: 'first.png', bytes: [1]),
        ChatMediaAttachment.image(name: 'second.png', bytes: [2]),
        ChatMediaAttachment.image(name: 'third.png', bytes: [3]),
      ],
      prepareAttachments: (attachments) async {
        calls.add('prepare:${attachments.map((a) => a.name).join(',')}');
      },
      sendAttachment: (attachment) async {
        calls.add('send:${attachment.name}');
      },
      showNotice: (_, {duration = const Duration(seconds: 2)}) {},
      emptySelectionMessage: '未选择图片',
    );

    expect(calls, [
      'prepare:first.png,second.png,third.png',
      'send:first.png',
      'send:second.png',
      'send:third.png',
    ]);
  });

  test('keeps sending when pending UI cleanup is disposed', () async {
    final sent = <String>[];

    await pickAndSendChatMediaAttachments(
      closePanel: () {},
      pickAttachments: () async => [
        ChatMediaAttachment.image(name: 'first.png', bytes: [1]),
        ChatMediaAttachment.image(name: 'second.png', bytes: [2]),
      ],
      sendAttachment: (attachment) async {
        await runChatMediaSendTask<void>(
          onStarted: () => 'pending-${attachment.name}',
          send: () async {
            sent.add(attachment.name);
          },
          onFinished: (_) => throw StateError('chat page disposed'),
        );
      },
      showNotice: (_, {duration = const Duration(seconds: 2)}) {},
      emptySelectionMessage: '未选择图片',
    );

    expect(sent, ['first.png', 'second.png']);
  });

  test('marks pending upload failed when media send fails', () async {
    final failed = <String>[];

    await expectLater(
      runChatMediaSendTask<void>(
        onStarted: () => 'pending-1',
        send: () async => throw StateError('network stopped'),
        onFailed: failed.add,
      ),
      throwsA(isA<StateError>()),
    );

    expect(failed, ['pending-1']);
  });

  test('waits for pending upload success cleanup before completing send task',
      () async {
    final calls = <String>[];

    await runChatMediaSendTask<void>(
      onStarted: () => 'pending-1',
      send: () async {
        calls.add('send');
      },
      onSucceeded: (pendingUploadId) async {
        calls.add('cleanup-start:$pendingUploadId');
        await Future<void>.delayed(const Duration(milliseconds: 1));
        calls.add('cleanup-finished:$pendingUploadId');
      },
    );

    expect(calls, [
      'send',
      'cleanup-start:pending-1',
      'cleanup-finished:pending-1',
    ]);
  });

  test('captured product media sender remains usable after panel close',
      () async {
    final calls = <String>[];
    var panelClosed = false;

    final sendAttachment = createProductChatMediaSender(
      roomId: '!alice:p2p-im.com',
      uploadContent: (bytes, {required filename, contentType}) async {
        expect(panelClosed, isTrue);
        calls.add('upload:$filename');
        return Uri.parse('mxc://p2p-im.com/photo');
      },
      sendMedia: ({
        required roomId,
        required msgType,
        required body,
        required filename,
        required mediaUrl,
        String mimeType = '',
        int size = 0,
        String thumbnailUrl = '',
        String thumbnailMimeType = '',
        int thumbnailSize = 0,
        int width = 0,
        int height = 0,
        int durationMs = 0,
      }) async {
        calls.add('send:$msgType:$mediaUrl');
        return r'$media';
      },
      oneShotSync: () async => calls.add('sync'),
    );

    await pickAndSendChatMediaAttachment(
      closePanel: () => panelClosed = true,
      pickAttachment: () async {
        return ChatMediaAttachment.image(name: 'photo.png', bytes: [1]);
      },
      sendAttachment: (attachment) async {
        await sendAttachment(attachment);
      },
      showNotice: (_, {duration = const Duration(seconds: 2)}) {},
      emptySelectionMessage: '未选择图片',
    );

    expect(calls, [
      'upload:photo.png',
      'send:m.image:mxc://p2p-im.com/photo',
      'sync',
    ]);
  });
}

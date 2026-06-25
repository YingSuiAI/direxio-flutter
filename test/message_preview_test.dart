import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/local_outbox_store.dart';
import 'package:portal_app/l10n/app_localizations_en.dart';
import 'package:portal_app/presentation/chat/chat_record_forwarding.dart';
import 'package:portal_app/presentation/utils/message_preview.dart';

void main() {
  test('uses direction-specific labels for image message previews', () {
    final client = Client('MessagePreviewTest')..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);

    final sent = Event(
      room: room,
      eventId: r'$sent',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 28),
      content: {
        'msgtype': MessageTypes.Image,
        'body': '1b755c3fa9d2b48f9a.jpeg',
      },
    );
    final received = Event(
      room: room,
      eventId: r'$received',
      senderId: '@peer:p2p-liyanan.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 28),
      content: {
        'msgtype': MessageTypes.Image,
        'body': '85dff0a8f4b8912d.png',
      },
    );

    expect(roomEventPreviewText(sent, isAgent: false), '发送图片');
    expect(roomEventPreviewText(received, isAgent: false), '收到图片');
  });

  test('uses direction-specific labels for file message previews', () {
    final client = Client('MessagePreviewFileTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);

    final sent = Event(
      room: room,
      eventId: r'$sent-file',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 28),
      content: {
        'msgtype': MessageTypes.File,
        'body': 'contract.pdf',
      },
    );
    final received = Event(
      room: room,
      eventId: r'$received-file',
      senderId: '@peer:p2p-liyanan.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 28),
      content: {
        'msgtype': MessageTypes.File,
        'body': 'report.xlsx',
      },
    );

    expect(roomEventPreviewText(sent, isAgent: false), '发送文件');
    expect(roomEventPreviewText(received, isAgent: false), '收到文件');
  });

  test('uses voice label for audio message previews', () {
    final client = Client('MessagePreviewAudioTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);

    final sent = Event(
      room: room,
      eventId: r'$sent-audio',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 28),
      content: {
        'msgtype': MessageTypes.Audio,
        'body': 'voice.m4a',
      },
    );
    final received = Event(
      room: room,
      eventId: r'$received-audio',
      senderId: '@peer:p2p-liyanan.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 28),
      content: {
        'msgtype': MessageTypes.Audio,
        'body': 'voice.ogg',
      },
    );

    expect(roomEventPreviewText(sent, isAgent: false), '[语音]');
    expect(roomEventPreviewText(received, isAgent: false), '[语音]');
  });

  test('uses voice label for audio files sent through media route', () {
    final client = Client('MessagePreviewAudioFileTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);

    final sent = Event(
      room: room,
      eventId: r'$sent-audio-file',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 28),
      content: {
        'msgtype': MessageTypes.File,
        'body': 'voice.m4a',
        'info': {'mimetype': 'audio/mp4'},
      },
    );
    final received = Event(
      room: room,
      eventId: r'$received-audio-file',
      senderId: '@peer:p2p-liyanan.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 28),
      content: {
        'msgtype': MessageTypes.File,
        'body': 'voice.ogg',
        'info': {'mimetype': 'audio/ogg'},
      },
    );

    expect(roomEventPreviewText(sent, isAgent: false), '[语音]');
    expect(roomEventPreviewText(received, isAgent: false), '[语音]');
    expect(quotedEventPreviewText(sent), '[语音]');
  });

  test('uses direction-specific labels for video message previews', () {
    final client = Client('MessagePreviewVideoTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);

    final sent = Event(
      room: room,
      eventId: r'$sent-video',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 28),
      content: {
        'msgtype': MessageTypes.Video,
        'body': 'clip.mp4',
      },
    );
    final received = Event(
      room: room,
      eventId: r'$received-video',
      senderId: '@peer:p2p-liyanan.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 28),
      content: {
        'msgtype': MessageTypes.Video,
        'body': 'reply.mov',
      },
    );

    expect(roomEventPreviewText(sent, isAgent: false), '发送视频');
    expect(roomEventPreviewText(received, isAgent: false), '收到视频');
  });

  test('uses localized message type labels when l10n is provided', () {
    final l10n = AppLocalizationsEn();
    final client = Client('MessagePreviewLocalizedTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final sent = Event(
      room: room,
      eventId: r'$sent-image-localized',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 25),
      content: {
        'msgtype': MessageTypes.Image,
        'body': 'photo.jpg',
      },
    );
    final quotedFile = Event(
      room: room,
      eventId: r'$quoted-file-localized',
      senderId: '@peer:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 25),
      content: {
        'msgtype': MessageTypes.File,
        'body': 'doc.pdf',
      },
    );

    expect(
      roomEventPreviewText(sent, isAgent: false, l10n: l10n),
      'Sent an image',
    );
    expect(quotedEventPreviewText(quotedFile, l10n: l10n), '[File]');
  });

  test('uses localized product card labels when l10n is provided', () {
    final l10n = AppLocalizationsEn();
    final client = Client('MessagePreviewLocalizedProductCardsTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final channelShare = Event(
      room: room,
      eventId: r'$channel-share-localized',
      senderId: '@peer:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 25),
      content: {
        'msgtype': MessageTypes.Text,
        'body': '频道分享\n产品公告',
        chatRecordMatrixMarkerKey: 'channel_share',
      },
    );
    final groupInvite = Event(
      room: room,
      eventId: r'$group-invite-localized',
      senderId: '@peer:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 25),
      content: {
        'msgtype': 'p2p.group.invite.v1',
        'body': '邀请加入群聊\n产品测试群',
        'group_room_id': '!group:p2p-im.com',
        'group_name': '产品测试群',
      },
    );

    expect(
      roomEventPreviewText(channelShare, isAgent: false, l10n: l10n),
      'Channel share',
    );
    expect(
      roomEventPreviewText(groupInvite, isAgent: false, l10n: l10n),
      'Group invitation',
    );
  });

  test('keeps text previews readable', () {
    final client = Client('MessagePreviewTextTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final event = Event(
      room: room,
      eventId: r'$text',
      senderId: '@peer:p2p-liyanan.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 28),
      content: {
        'msgtype': MessageTypes.Text,
        'body': '**hello**\nworld',
      },
    );

    expect(roomEventPreviewText(event, isAgent: false), 'hello world');
  });

  test('uses type labels for quoted media previews', () {
    final client = Client('QuotedMessagePreviewMediaTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);

    Event event(String id, String msgtype, String body) => Event(
          room: room,
          eventId: id,
          senderId: '@peer:p2p-liyanan.com',
          type: EventTypes.Message,
          originServerTs: DateTime.utc(2026, 6, 12),
          content: {
            'msgtype': msgtype,
            'body': body,
          },
        );

    expect(
      quotedEventPreviewText(event(r'$image', MessageTypes.Image, 'a.jpg')),
      '[图片]',
    );
    expect(
      quotedEventPreviewText(event(r'$video', MessageTypes.Video, 'v.mp4')),
      '[视频]',
    );
    expect(
      quotedEventPreviewText(event(r'$file', MessageTypes.File, 'doc.pdf')),
      '[文件]',
    );
    expect(
      quotedEventPreviewText(event(r'$audio', MessageTypes.Audio, 'voice.ogg')),
      '[语音]',
    );
  });

  test('uses type labels for quoted product card previews', () {
    final client = Client('QuotedMessagePreviewCardTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);

    final chatRecord = Event(
      room: room,
      eventId: r'$record',
      senderId: '@peer:p2p-liyanan.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 12),
      content: {
        'msgtype': MessageTypes.Text,
        'body': '聊天记录',
        chatRecordMatrixMarkerKey: chatRecordMessageType,
      },
    );
    final channelShare = Event(
      room: room,
      eventId: r'$channel',
      senderId: '@peer:p2p-liyanan.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 12),
      content: {
        'msgtype': MessageTypes.Text,
        'body': '频道分享',
        chatRecordMatrixMarkerKey: 'channel_share',
      },
    );

    expect(quotedEventPreviewText(chatRecord), '[聊天记录]');
    expect(quotedEventPreviewText(channelShare), '[频道]');
  });

  test('uses call events as conversation previews', () {
    final client = Client('MessagePreviewCallTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final hangup = Event(
      room: room,
      eventId: r'$call-hangup',
      senderId: '@me:p2p-im.com',
      type: EventTypes.CallHangup,
      originServerTs: DateTime.utc(2026, 5, 30),
      content: {
        'call_id': 'call-1',
        'reason': 'user_hangup',
      },
    );
    final missed = Event(
      room: room,
      eventId: r'$call-missed',
      senderId: '@peer:p2p-liyanan.com',
      type: EventTypes.CallHangup,
      originServerTs: DateTime.utc(2026, 5, 30),
      content: {
        'call_id': 'call-2',
        'reason': 'invite_timeout',
      },
    );

    expect(roomEventPreviewText(hangup, isAgent: false), '通话');
    expect(roomEventPreviewText(missed, isAgent: false), '未接通通话');
  });

  test('keeps matrix unread counts in conversation badges', () {
    expect(conversationUnreadCount(matrixUnreadCount: 1), 1);
    expect(conversationUnreadCount(matrixUnreadCount: 3), 3);
    expect(conversationUnreadCount(matrixUnreadCount: 0), 0);
  });

  test('detects channel share product messages', () {
    final client = Client('MessagePreviewChannelShareDetectTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final event = Event(
      room: room,
      eventId: r'$channel-share',
      senderId: '@peer:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 23),
      content: {
        'msgtype': MessageTypes.Text,
        'body': '频道分享',
        chatRecordMatrixMarkerKey: 'channel_share',
      },
    );

    expect(isChannelShareEvent(event), isTrue);
  });

  test('uses failed local outbox image as latest conversation preview', () {
    final client = Client('MessagePreviewFailedOutboxTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final event = Event(
      room: room,
      eventId: r'$sent',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 28, 10),
      content: {
        'msgtype': MessageTypes.Image,
        'body': 'sent.jpg',
      },
    );

    final failed = LocalOutboxItem(
      id: 'failed',
      conversationId: room.id,
      conversationType: LocalOutboxConversationType.direct,
      messageKind: LocalOutboxMessageKind.image,
      text: '',
      filename: 'failed.jpg',
      mimeType: 'image/jpeg',
      bytes: null,
      createdAt: DateTime.utc(2026, 5, 28, 10, 1),
      status: LocalOutboxItemStatus.failed,
      runtimeId: 'runtime',
      batchId: 'batch',
      batchIndex: 0,
    );

    expect(
      conversationPreviewText(
        lastEvent: event,
        latestFailedOutbox: failed,
        lastEventSortTime: event.originServerTs,
        isAgent: false,
      ),
      '发送失败',
    );
    expect(
        conversationPreviewTime(
          lastEvent: event,
          latestFailedOutbox: failed,
          lastEventSortTime: event.originServerTs,
        ),
        failed.createdAt);
  });

  test('compares failed outbox against delivered local order time', () {
    final client = Client('MessagePreviewLocalOrderTest')
      ..setUserId('@me:p2p-im.com');
    final room = Room(id: '!room:p2p-im.com', client: client);
    final delivered = Event(
      room: room,
      eventId: r'$sent',
      senderId: '@me:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 28, 10, 1),
      content: {
        'msgtype': MessageTypes.Image,
        'body': 'sent.jpg',
      },
    );
    final failed = LocalOutboxItem(
      id: 'failed',
      conversationId: room.id,
      conversationType: LocalOutboxConversationType.direct,
      messageKind: LocalOutboxMessageKind.image,
      text: '',
      filename: 'failed.jpg',
      mimeType: 'image/jpeg',
      bytes: null,
      createdAt: DateTime.utc(2026, 5, 28, 10, 0, 1),
      status: LocalOutboxItemStatus.failed,
      runtimeId: 'runtime',
      batchId: 'batch',
      batchIndex: 1,
    );

    expect(
      conversationPreviewText(
        lastEvent: delivered,
        latestFailedOutbox: failed,
        lastEventSortTime: DateTime.utc(2026, 5, 28, 10),
        isAgent: false,
      ),
      '发送失败',
    );
  });
}

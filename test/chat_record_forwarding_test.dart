import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/chat/chat_message_cards.dart';
import 'package:portal_app/presentation/chat/chat_record_detail_page.dart';
import 'package:portal_app/presentation/chat/chat_record_forwarding.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';

void main() {
  test('chat record payload preserves sender side and original media content',
      () {
    final payload = buildChatRecordPayload(
      sourceRoomId: '!source:p2p-im.com',
      sourceRoomType: 'direct',
      sourceName: 'Alice',
      messages: const [
        ChatRecordSourceMessage(
          senderId: '@owner:p2p-im.com',
          senderName: 'Yanan',
          isMe: true,
          body: 'photo.jpg',
          messageType: MessageTypes.Image,
          originServerTs: 1779685200000,
          content: {
            'msgtype': MessageTypes.Image,
            'body': 'photo.jpg',
            'url': 'mxc://p2p-im.com/photo',
            'info': {
              'mimetype': 'image/jpeg',
              'size': 2048,
              'thumbnail_url': 'mxc://p2p-im.com/thumb',
              'w': 640,
              'h': 480,
            },
          },
        ),
      ],
    );

    final parsed = chatRecordPayloadFromContent(
      Map<String, Object?>.from(payload.matrixContent),
    );
    expect(parsed, isNotNull);

    final item = chatRecordItems(parsed!).single;
    expect(item.senderId, '@owner:p2p-im.com');
    expect(item.senderName, 'Yanan');
    expect(item.isMe, isTrue);
    expect(item.messageType, MessageTypes.Image);
    expect(item.mediaUrl, 'mxc://p2p-im.com/photo');
    expect(item.thumbnailUrl, 'mxc://p2p-im.com/thumb');
    expect(item.mimeType, 'image/jpeg');
    expect(item.size, 2048);
    expect(item.width, 640);
    expect(item.height, 480);
  });

  test('chat record item reads encrypted media and thumbnail files', () {
    final item = ChatRecordItem.fromMap({
      'sender_id': '@owner:p2p-im.com',
      'sender_name': 'Yanan',
      'is_me': true,
      'body': 'photo.jpg',
      'message_type': MessageTypes.Image,
      'origin_server_ts': 1779685200000,
      'content': {
        'msgtype': MessageTypes.Image,
        'body': 'photo.jpg',
        'file': {
          'url': 'mxc://p2p-im.com/encrypted-photo',
          'key': {
            'kty': 'oct',
            'key_ops': ['encrypt', 'decrypt'],
            'alg': 'A256CTR',
            'k': 'media-key',
          },
          'iv': 'media-iv',
          'hashes': {'sha256': 'media-sha'},
        },
        'info': {
          'mimetype': 'image/jpeg',
          'thumbnail_file': {
            'url': 'mxc://p2p-im.com/encrypted-thumb',
            'key': {
              'kty': 'oct',
              'key_ops': ['encrypt', 'decrypt'],
              'alg': 'A256CTR',
              'k': 'thumb-key',
            },
            'iv': 'thumb-iv',
            'hashes': {'sha256': 'thumb-sha'},
          },
        },
      },
    });

    expect(item.mediaUrl, 'mxc://p2p-im.com/encrypted-photo');
    expect(item.thumbnailUrl, 'mxc://p2p-im.com/encrypted-thumb');
    expect(item.encryptedFile['iv'], 'media-iv');
    expect(item.encryptedThumbnailFile['iv'], 'thumb-iv');
  });

  test('group chat record payload keeps source room type as group', () {
    final payload = buildChatRecordPayload(
      sourceRoomId: '!group:p2p-im.com',
      sourceRoomType: 'group',
      sourceName: '产品测试群',
      messages: const [
        ChatRecordSourceMessage(
          senderId: '@owner:p2p-im.com',
          senderName: 'Yanan',
          isMe: true,
          body: '群消息',
          messageType: MessageTypes.Text,
          originServerTs: 1779685200000,
          content: {
            'msgtype': MessageTypes.Text,
            'body': '群消息',
          },
        ),
      ],
    );

    final content = payload.matrixContent;
    final rawPayload =
        content[chatRecordMatrixPayloadKey] as Map<String, Object?>;

    expect(payload.title, '群聊「产品测试群」的聊天记录');
    expect(rawPayload['source_room_id'], '!group:p2p-im.com');
    expect(rawPayload['source_room_type'], 'group');
    expect(rawPayload['item_count'], 1);
  });

  test('forwarding an existing chat record keeps its inner messages flat', () {
    final original = buildChatRecordPayload(
      sourceRoomId: '!source:p2p-im.com',
      sourceRoomType: 'direct',
      sourceName: 'Alice',
      messages: const [
        ChatRecordSourceMessage(
          senderId: '@alice:p2p-im.com',
          senderName: 'Alice',
          body: '第一条',
          messageType: MessageTypes.Text,
          originServerTs: 1779685200000,
          content: {
            'msgtype': MessageTypes.Text,
            'body': '第一条',
          },
        ),
        ChatRecordSourceMessage(
          senderId: '@owner:p2p-im.com',
          senderName: 'Yanan',
          isMe: true,
          body: '第二条',
          messageType: MessageTypes.Text,
          originServerTs: 1779685201000,
          content: {
            'msgtype': MessageTypes.Text,
            'body': '第二条',
          },
        ),
      ],
    );

    final forwarded = buildChatRecordPayload(
      sourceRoomId: '!relay:p2p-im.com',
      sourceRoomType: 'direct',
      sourceName: 'Bob',
      messages: [
        ChatRecordSourceMessage(
          senderId: '@bob:p2p-im.com',
          senderName: 'Bob',
          body: original.body,
          messageType: chatRecordMessageType,
          originServerTs: 1779685300000,
          content: Map<String, Object?>.from(original.matrixContent),
        ),
      ],
    );

    final parsed = chatRecordPayloadFromContent(
      Map<String, Object?>.from(forwarded.matrixContent),
    );

    expect(parsed, isNotNull);
    expect(parsed!.title, original.title);
    expect(parsed.itemCount, 2);
    expect(chatRecordItems(parsed).map((item) => item.body), [
      '第一条',
      '第二条',
    ]);
  });

  test('mixed forwarding preserves nested chat record packages', () {
    final nested = buildChatRecordPayload(
      sourceRoomId: '!nested:p2p-im.com',
      sourceRoomType: 'direct',
      sourceName: 'Alice',
      messages: const [
        ChatRecordSourceMessage(
          senderId: '@alice:p2p-im.com',
          senderName: 'Alice',
          body: '嵌套第一条',
          messageType: MessageTypes.Text,
          originServerTs: 1779685200000,
          content: {
            'msgtype': MessageTypes.Text,
            'body': '嵌套第一条',
          },
        ),
        ChatRecordSourceMessage(
          senderId: '@owner:p2p-im.com',
          senderName: 'Yanan',
          isMe: true,
          body: '嵌套第二条',
          messageType: MessageTypes.Text,
          originServerTs: 1779685201000,
          content: {
            'msgtype': MessageTypes.Text,
            'body': '嵌套第二条',
          },
        ),
      ],
    );

    final mixed = buildChatRecordPayload(
      sourceRoomId: '!mixed:p2p-im.com',
      sourceRoomType: 'group',
      sourceName: '产品测试群',
      messages: [
        const ChatRecordSourceMessage(
          senderId: '@owner:p2p-im.com',
          senderName: 'Yanan',
          isMe: true,
          body: '普通消息',
          messageType: MessageTypes.Text,
          originServerTs: 1779685300000,
          content: {
            'msgtype': MessageTypes.Text,
            'body': '普通消息',
          },
        ),
        ChatRecordSourceMessage(
          senderId: '@alice:p2p-im.com',
          senderName: 'Alice',
          body: nested.body,
          messageType: chatRecordMessageType,
          originServerTs: 1779685301000,
          content: Map<String, Object?>.from(nested.matrixContent),
        ),
      ],
    );

    final items = chatRecordItems(mixed);
    expect(mixed.itemCount, 2);
    expect(items.map((item) => item.body), ['普通消息', nested.body]);

    final preservedNested = chatRecordPayloadFromContent(items.last.content);
    expect(preservedNested, isNotNull);
    expect(preservedNested!.itemCount, 2);
    expect(chatRecordItems(preservedNested).map((item) => item.body), [
      '嵌套第一条',
      '嵌套第二条',
    ]);
  });

  test('chat record forward targets route direct and group through AS', () {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-liyanan.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
      ],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '产品测试群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [
        AsSyncRoomSummary(
          roomId: '!channel:p2p-im.com',
          name: '公开频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    final targets = chatRecordForwardTargets(
      AsSyncCacheState(bootstrap: bootstrap),
      currentRoomId: '!group:p2p-im.com',
      currentRoomName: '产品测试群',
      currentRoomType: 'group',
    );

    expect(
      targets
          .singleWhere((target) => target.roomId == '!group:p2p-im.com')
          .sendViaAs,
      isTrue,
    );
    expect(
      targets
          .singleWhere((target) => target.roomId == '!alice:p2p-im.com')
          .sendViaAs,
      isTrue,
    );
    expect(
      targets
          .singleWhere((target) => target.roomId == '!channel:p2p-im.com')
          .sendViaAs,
      isFalse,
    );
  });

  test('chat record forward targets include local accepted contacts', () {
    const state = AsSyncCacheState(
      localContactEntriesByRoomId: {
        '!new-friend:p2p-im.com': ContactEntry(
          peerMxid: '@new-friend:p2p-im.com',
          displayName: '新好友',
          domain: 'p2p-im.com',
          roomId: '!new-friend:p2p-im.com',
          status: 'accepted',
        ),
      },
    );

    final targets = chatRecordForwardTargets(
      state,
      currentRoomId: '!channel:p2p-im.com',
      currentRoomName: '频道',
      currentRoomType: 'channel',
    );

    final target = targets.singleWhere(
      (target) => target.roomId == '!new-friend:p2p-im.com',
    );
    expect(target.name, '新好友');
    expect(target.roomType, 'direct');
    expect(target.sendViaAs, isTrue);
  });

  testWidgets('chat record detail hides image filenames on media previews',
      (tester) async {
    const imageName = 'very-long-camera-upload-name-20260529-abcdef.jpg';
    final payload = buildChatRecordPayload(
      sourceRoomId: '!source:p2p-im.com',
      sourceRoomType: 'direct',
      sourceName: 'Alice',
      messages: const [
        ChatRecordSourceMessage(
          senderId: '@alice:p2p-im.com',
          senderName: 'Alice',
          body: imageName,
          messageType: MessageTypes.Image,
          originServerTs: 1779685200000,
          content: {
            'msgtype': MessageTypes.Image,
            'body': imageName,
            'url': '',
            'info': {
              'mimetype': 'image/jpeg',
            },
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: ChatRecordDetailPage(payload: payload),
        ),
      ),
    );

    expect(find.text(imageName), findsNothing);
    expect(find.text('与 Alice 的聊天记录'), findsOneWidget);
    expect(find.text('共 1 条消息'), findsOneWidget);
  });

  testWidgets('compact selection actions stay above the bottom system inset',
      (tester) async {
    const screenSize = Size(320, 240);
    const bottomInset = 34.0;
    await tester.binding.setSurfaceSize(screenSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: screenSize,
            viewPadding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatRecordSelectionBar(
                count: 3,
                compact: true,
                onExit: () {},
                onDelete: () {},
                onFavorite: () {},
                onForward: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final safeBottom = screenSize.height - bottomInset;
    expect(tester.getRect(find.byIcon(Symbols.delete)).bottom,
        lessThan(safeBottom));
    expect(tester.getRect(find.byIcon(Symbols.bookmark)).bottom,
        lessThan(safeBottom));
    expect(tester.getRect(find.byIcon(Symbols.ios_share)).bottom,
        lessThan(safeBottom));
  });

  testWidgets('chat record detail opens nested image messages', (tester) async {
    final client = _mediaClient();
    final payload = buildChatRecordPayload(
      sourceRoomId: '!source:p2p-im.com',
      sourceRoomType: 'direct',
      sourceName: 'Alice',
      messages: const [
        ChatRecordSourceMessage(
          senderId: '@alice:p2p-im.com',
          senderName: 'Alice',
          body: 'photo.jpg',
          messageType: MessageTypes.Image,
          originServerTs: 1779685200000,
          content: {
            'msgtype': MessageTypes.Image,
            'body': 'photo.jpg',
            'url': 'mxc://p2p-im.com/photo',
            'info': {
              'thumbnail_url': 'not-a-thumbnail',
              'mimetype': 'image/jpeg',
            },
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [matrixClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: ChatRecordDetailPage(payload: payload),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byIcon(Symbols.image));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump();

    expect(find.byIcon(Symbols.close), findsOneWidget);
  });

  testWidgets('chat record detail caches nested image media across reopen',
      (tester) async {
    final requestedPaths = <String>[];
    final client = Client(
      'DirexioChatRecordMediaCacheTest',
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        return http.Response.bytes(
          _transparentPng,
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final payload = buildChatRecordPayload(
      sourceRoomId: '!source:p2p-im.com',
      sourceRoomType: 'direct',
      sourceName: 'Alice',
      messages: const [
        ChatRecordSourceMessage(
          senderId: '@alice:p2p-im.com',
          senderName: 'Alice',
          body: 'photo.jpg',
          messageType: MessageTypes.Image,
          originServerTs: 1779685200000,
          content: {
            'msgtype': MessageTypes.Image,
            'body': 'photo.jpg',
            'url': 'mxc://p2p-im.com/photo',
            'info': {
              'thumbnail_url': 'mxc://p2p-im.com/thumb',
              'mimetype': 'image/jpeg',
            },
          },
        ),
      ],
    );

    Future<void> pumpDetail() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: ChatRecordDetailPage(payload: payload),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.byType(ChatMediaBubbleFrame).first);
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump();
      await tester.tap(find.byIcon(Symbols.close));
      await tester.pump(const Duration(milliseconds: 180));
    }

    await pumpDetail();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );
    await tester.pump();
    await pumpDetail();

    expect(
      requestedPaths
          .where((path) => path.contains('/download/p2p-im.com/thumb')),
      hasLength(1),
    );
    expect(
      requestedPaths
          .where((path) => path.contains('/download/p2p-im.com/photo')),
      hasLength(1),
    );
  });

  testWidgets('chat record detail opens nested video and file messages',
      (tester) async {
    final previewer = _RecordingChatRecordNativePreviewer();

    final payload = buildChatRecordPayload(
      sourceRoomId: '!source:p2p-im.com',
      sourceRoomType: 'direct',
      sourceName: 'Alice',
      messages: const [
        ChatRecordSourceMessage(
          senderId: '@alice:p2p-im.com',
          senderName: 'Alice',
          body: 'clip.mov',
          messageType: MessageTypes.Video,
          originServerTs: 1779685200001,
          content: {
            'msgtype': MessageTypes.Video,
            'body': 'clip.mov',
            'url': 'mxc://p2p-im.com/video',
            'info': {
              'mimetype': 'video/quicktime',
              'thumbnail_url': 'not-a-thumbnail',
            },
          },
        ),
        ChatRecordSourceMessage(
          senderId: '@alice:p2p-im.com',
          senderName: 'Alice',
          body: 'report.pdf',
          messageType: MessageTypes.File,
          originServerTs: 1779685200002,
          content: {
            'msgtype': MessageTypes.File,
            'body': 'report.pdf',
            'url': 'mxc://p2p-im.com/report',
            'info': {
              'mimetype': 'application/pdf',
              'size': 1024,
            },
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRecordNativePreviewerProvider.overrideWithValue(previewer),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: ChatRecordDetailPage(payload: payload),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byIcon(Symbols.play_arrow));
    await tester.pump();
    await tester.tap(find.text('report.pdf'));
    await tester.pump();

    expect(previewer.openedFilenames, ['clip.mov', 'report.pdf']);
  });

  testWidgets('chat record detail opens nested chat records recursively',
      (tester) async {
    final thirdLayer = ChatRecordPayload(
      sourceRoomId: '!third:p2p-im.com',
      sourceRoomType: 'direct',
      title: '第三层聊天记录',
      body: '聊天记录\n第三层聊天记录\n共 1 条消息',
      itemCount: 1,
      items: [
        _textRecordItem(
          senderName: 'Carol',
          body: '第三层文字',
          originServerTs: 1779685400000,
        ),
      ],
    );
    final secondLayer = ChatRecordPayload(
      sourceRoomId: '!second:p2p-im.com',
      sourceRoomType: 'direct',
      title: '第二层聊天记录',
      body: '聊天记录\n第二层聊天记录\n共 1 条消息',
      itemCount: 1,
      items: [
        _chatRecordItem(
          senderName: 'Bob',
          payload: thirdLayer,
          originServerTs: 1779685300000,
        ),
      ],
    );
    final firstLayer = ChatRecordPayload(
      sourceRoomId: '!first:p2p-im.com',
      sourceRoomType: 'direct',
      title: '第一层聊天记录',
      body: '聊天记录\n第一层聊天记录\n共 2 条消息',
      itemCount: 2,
      items: [
        _textRecordItem(
          senderName: 'Alice',
          body: '普通消息',
          originServerTs: 1779685200000,
        ),
        _chatRecordItem(
          senderName: 'Alice',
          payload: secondLayer,
          originServerTs: 1779685201000,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: ChatRecordDetailPage(payload: firstLayer),
        ),
      ),
    );

    expect(find.text('第一层聊天记录'), findsOneWidget);
    expect(find.text('普通消息'), findsOneWidget);

    await tester.tap(find.textContaining('第二层聊天记录').first);
    await tester.pumpAndSettle();

    expect(find.text('第二层聊天记录'), findsOneWidget);
    expect(find.text('第三层聊天记录'), findsOneWidget);

    await tester.tap(find.text('第三层聊天记录'));
    await tester.pumpAndSettle();

    expect(find.text('第三层聊天记录'), findsOneWidget);
    expect(find.text('第三层文字'), findsOneWidget);
  });
}

Map<String, Object?> _textRecordItem({
  required String senderName,
  required String body,
  required int originServerTs,
}) {
  return {
    'sender_id': '@${senderName.toLowerCase()}:p2p-im.com',
    'sender_name': senderName,
    'is_me': false,
    'body': body,
    'message_type': MessageTypes.Text,
    'origin_server_ts': originServerTs,
    'content': {
      'msgtype': MessageTypes.Text,
      'body': body,
    },
  };
}

Map<String, Object?> _chatRecordItem({
  required String senderName,
  required ChatRecordPayload payload,
  required int originServerTs,
}) {
  return {
    'sender_id': '@${senderName.toLowerCase()}:p2p-im.com',
    'sender_name': senderName,
    'is_me': false,
    'body': payload.body,
    'message_type': chatRecordMessageType,
    'origin_server_ts': originServerTs,
    'content': Map<String, Object?>.from(payload.matrixContent),
  };
}

class _RecordingChatRecordNativePreviewer extends ChatRecordNativePreviewer {
  final openedFilenames = <String>[];

  @override
  Future<void> open(WidgetRef ref, ChatRecordItem item) async {
    openedFilenames.add(item.filename);
  }
}

Client _mediaClient() {
  final client = Client(
    'DirexioChatRecordMediaTest',
    httpClient: MockClient((request) async {
      return http.Response.bytes(
        _transparentPng,
        200,
        headers: {'content-type': 'image/png'},
      );
    }),
  )..setUserId('@owner:p2p-im.com');
  client.homeserver = Uri.parse('https://p2p-im.com');
  client.accessToken = 'test-token';
  return client;
}

final _transparentPng = Uint8List.fromList([
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
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
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0a,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
]);

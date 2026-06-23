import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/chat/chat_message_cards.dart';
import 'package:portal_app/presentation/chat/chat_record_forwarding.dart';

void main() {
  test('directional chat bubbles use the shared media bubble radius', () {
    expect(chatDirectionalBubbleRadius(true), chatMessageBubbleRadius);
    expect(chatDirectionalBubbleRadius(false), chatMessageBubbleRadius);
  });

  testWidgets('chat record preview card matches shared card dimensions',
      (tester) async {
    const payload = ChatRecordPayload(
      sourceRoomId: '!room:p2p-im.com',
      sourceRoomType: 'group',
      title: '群聊「产品测试群」的聊天记录',
      body: '聊天记录\n群聊「产品测试群」的聊天记录\n共 3 条消息',
      itemCount: 3,
      items: [
        {
          'sender_name': 'Yanan',
          'body': '第一条文字',
          'message_type': MessageTypes.Text,
          'origin_server_ts': 1,
        },
        {
          'sender_name': 'Alice',
          'body': 'photo.jpg',
          'message_type': MessageTypes.Image,
          'origin_server_ts': 2,
        },
        {
          'sender_name': 'Bob',
          'body': 'report.pdf',
          'message_type': MessageTypes.File,
          'origin_server_ts': 3,
          'content': {'filename': 'report.pdf'},
        },
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ChatRecordPreviewCard(
            payload: payload,
          ),
        ),
      ),
    );

    expect(find.text('群聊的聊天记录'), findsOneWidget);
    expect(find.text('Yanan: 第一条文字'), findsOneWidget);
    expect(find.text('Alice: [图片]'), findsOneWidget);
    expect(find.text('Bob: [文件] report.pdf'), findsOneWidget);
    expect(find.text('聊天记录'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat_record_preview_avatar_0')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('chat_record_preview_avatar_1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('chat_record_preview_avatar_2')),
        findsOneWidget);

    final size = tester.getSize(find.byType(ChatRecordPreviewCard));
    expect(size.width, chatMessageCompactCardWidth);
    expect(size.height, chatMessageCardHeight);
  });

  testWidgets('chat record preview card uses unified message corner radius',
      (tester) async {
    const payload = ChatRecordPayload(
      sourceRoomId: '!room:p2p-im.com',
      sourceRoomType: 'group',
      title: '群聊「产品测试群」的聊天记录',
      body: '聊天记录\n群聊「产品测试群」的聊天记录\n共 1 条消息',
      itemCount: 1,
      items: [
        {
          'sender_name': 'Yanan',
          'body': '第一条文字',
          'message_type': MessageTypes.Text,
          'origin_server_ts': 1,
        },
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ChatRecordPreviewCard(
            payload: payload,
          ),
        ),
      ),
    );

    final card =
        tester.widgetList<Container>(find.byType(Container)).firstWhere(
              (container) =>
                  container.padding == const EdgeInsets.fromLTRB(13, 10, 13, 9),
            );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.borderRadius, chatMessageBubbleRadius);
  });

  testWidgets('call record bubble uses call icon and concise text',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ChatCallRecordBubble(
            isMe: false,
            isVideo: false,
            text: '0:42',
          ),
        ),
      ),
    );

    expect(find.byIcon(Symbols.call), findsOneWidget);
    expect(find.byIcon(Symbols.videocam), findsNothing);
    expect(find.text('0:42'), findsOneWidget);
  });

  testWidgets('call record bubble uses video icon for missed video calls',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ChatCallRecordBubble(
            isMe: true,
            isVideo: true,
            text: '未接通',
          ),
        ),
      ),
    );

    expect(find.byIcon(Symbols.videocam), findsOneWidget);
    expect(find.byIcon(Symbols.call), findsNothing);
    expect(find.text('未接通'), findsOneWidget);
  });

  testWidgets('voice bubble content matches iOS voice message layout',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ChatVoiceBubbleContent(
            isMe: true,
            durationSeconds: 12,
          ),
        ),
      ),
    );

    expect(find.text('12s'), findsOneWidget);
    expect(find.byIcon(Symbols.graphic_eq), findsOneWidget);
    expect(find.byType(ChatVoiceBubbleContent), findsOneWidget);

    final durationRect = tester.getRect(find.text('12s'));
    final iconRect = tester.getRect(find.byIcon(Symbols.graphic_eq));
    expect(durationRect.left, lessThan(iconRect.left));
  });

  testWidgets('voice bubble content shows playback progress and supports seek',
      (tester) async {
    final seeks = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: ChatVoiceBubbleContent(
              isMe: false,
              durationSeconds: 12,
              isPlaying: true,
              currentPlaySeconds: 4,
              onSeek: seeks.add,
            ),
          ),
        ),
      ),
    );

    expect(find.text('8s'), findsOneWidget);
    expect(find.text('12s'), findsNothing);

    await tester.drag(find.byType(ChatVoiceBubbleContent), const Offset(80, 0));
    await tester.pump();

    expect(seeks, isNotEmpty);
    expect(seeks.last, inInclusiveRange(0, 12));
  });

  testWidgets('chat bubble frame does not reserve tail space', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              ChatBubbleFrame(
                child: Container(
                  key: const ValueKey('incoming_body'),
                  width: 80,
                  height: 80,
                  color: Colors.white,
                ),
              ),
              ChatBubbleFrame(
                child: Container(
                  key: const ValueKey('outgoing_body'),
                  width: 80,
                  height: 80,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final frames = tester
        .widgetList<ChatBubbleFrame>(find.byType(ChatBubbleFrame))
        .toList(growable: false);
    expect(frames, hasLength(2));
    expect(
        find.byKey(const ValueKey('chat_message_bubble_tail')), findsNothing);

    final incomingFrame = tester.getRect(find.byType(ChatBubbleFrame).first);
    final incomingBody =
        tester.getRect(find.byKey(const ValueKey('incoming_body')));
    final outgoingFrame = tester.getRect(find.byType(ChatBubbleFrame).last);
    final outgoingBody =
        tester.getRect(find.byKey(const ValueKey('outgoing_body')));

    expect(incomingFrame, incomingBody);
    expect(outgoingFrame, outgoingBody);
    expect(incomingFrame.height, incomingBody.height);
    expect(outgoingFrame.height, outgoingBody.height);
  });

  testWidgets('media bubble frame uses exact media bounds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              ChatMediaBubbleFrame(
                width: 80,
                height: 40,
                child: Container(
                  key: const ValueKey('incoming_media'),
                  color: Colors.orange,
                ),
              ),
              ChatMediaBubbleFrame(
                width: 80,
                height: 40,
                child: Container(
                  key: const ValueKey('outgoing_media'),
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final clips = tester.widgetList<ClipRRect>(find.byType(ClipRRect)).toList();
    expect(clips, hasLength(2));

    final incomingFrame = tester.getRect(
      find.byType(ChatMediaBubbleFrame).first,
    );
    final incomingMedia =
        tester.getRect(find.byKey(const ValueKey('incoming_media')));
    final outgoingFrame = tester.getRect(
      find.byType(ChatMediaBubbleFrame).last,
    );
    final outgoingMedia =
        tester.getRect(find.byKey(const ValueKey('outgoing_media')));

    expect(incomingFrame.width, 80);
    expect(outgoingFrame.width, 80);
    expect(incomingMedia, incomingFrame);
    expect(outgoingMedia, outgoingFrame);
  });

  test('media bubble size follows image orientation', () {
    final wide = chatMediaBubbleSizeFor(width: 1600, height: 900);
    final tall = chatMediaBubbleSizeFor(width: 900, height: 1600);
    final square = chatMediaBubbleSizeFor(width: 800, height: 800);

    expect(wide.width, chatMessageMediaMaxWidth);
    expect(wide.height, lessThan(wide.width));
    expect(tall.height, chatMessageMediaMaxHeight);
    expect(tall.width, lessThan(tall.height));
    expect(square.width, square.height);
  });
}

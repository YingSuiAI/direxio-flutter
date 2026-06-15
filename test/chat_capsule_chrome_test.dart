import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/chat/chat_capsule_chrome.dart';

void main() {
  testWidgets('chat capsule header renders three floating zones',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ChatCapsuleHeader(
            title: 'Yanan',
            subtitle: '在线',
            onBack: () {},
            leadingAvatar: const CircleAvatar(child: Text('Y')),
            actions: const [
              ChatCapsuleAction(icon: Symbols.call, tooltip: '语音通话'),
              ChatCapsuleAction(icon: Symbols.more_vert, tooltip: '详情'),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('chat_header_left_capsule')), findsOne);
    expect(find.byKey(const ValueKey('chat_header_title_capsule')), findsOne);
    expect(find.byKey(const ValueKey('chat_header_actions_capsule')), findsOne);
    expect(find.text('Yanan'), findsOneWidget);
    expect(find.text('在线'), findsOneWidget);
  });

  testWidgets('chat capsule header shows encryption lock next to detail',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ChatCapsuleHeader(
            title: 'Group',
            subtitle: '3 名成员',
            onBack: () {},
            showEncryptionIcon: true,
            leadingAvatar: const CircleAvatar(child: Text('G')),
            actions: const [
              ChatCapsuleAction(icon: Symbols.call, tooltip: '语音通话'),
              ChatCapsuleAction(icon: Symbols.videocam, tooltip: '视频通话'),
              ChatCapsuleAction(icon: Symbols.more_vert, tooltip: '详情'),
            ],
          ),
        ),
      ),
    );

    expect(find.byTooltip('端对端加密'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat_header_encryption_lock')),
      findsOneWidget,
    );
    expect(find.byTooltip('详情'), findsOneWidget);
    expect(find.byTooltip('语音通话'), findsNothing);
    expect(find.byTooltip('视频通话'), findsNothing);
  });

  testWidgets('chat capsule header shows status dot before online subtitle',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ChatCapsuleHeader(
            title: 'Agent',
            subtitle: '在线',
            subtitleStatus: ChatCapsuleSubtitleStatus.online,
            onBack: () {},
            actions: const [
              ChatCapsuleAction(icon: Symbols.more_vert, tooltip: '详情'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('在线'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat_header_status_dot')), findsOne);
  });

  testWidgets('chat capsule header title capsule can open active call',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ChatCapsuleHeader(
            title: 'Group',
            subtitle: '正在群通话',
            onBack: () {},
            onTitleTap: () => tapped = true,
            leadingAvatar: const CircleAvatar(child: Text('G')),
            actions: const [
              ChatCapsuleAction(icon: Symbols.call, tooltip: '语音通话'),
              ChatCapsuleAction(icon: Symbols.more_vert, tooltip: '详情'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('chat_header_title_capsule')));
    expect(tapped, isTrue);
  });

  testWidgets(
      'chat capsule header keeps equal capsule height and smaller title',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ChatCapsuleHeader(
            title: 'Yanan',
            subtitle: '在线',
            onBack: () {},
            leadingAvatar: const CircleAvatar(child: Text('Y')),
            actions: const [
              ChatCapsuleAction(icon: Symbols.call, tooltip: '语音通话'),
              ChatCapsuleAction(icon: Symbols.more_vert, tooltip: '详情'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final left =
        tester.getRect(find.byKey(const ValueKey('chat_header_left_capsule')));
    final title =
        tester.getRect(find.byKey(const ValueKey('chat_header_title_capsule')));
    final actions = tester
        .getRect(find.byKey(const ValueKey('chat_header_actions_capsule')));

    expect(left.height, actions.height);
    expect(left.height, 40);
    expect(title.height, lessThanOrEqualTo(48));

    final titleText = tester.widget<Text>(find.text('Yanan'));
    final subtitleText = tester.widget<Text>(find.text('在线'));
    expect(titleText.style?.fontSize, 16);
    expect(subtitleText.style?.fontSize, 11);
  });

  testWidgets('chat capsule header keeps side capsules symmetric',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ChatCapsuleHeader(
            title: 'Yanan',
            subtitle: '在线',
            onBack: () {},
            leadingAvatar: const CircleAvatar(child: Text('Y')),
            actions: const [
              ChatCapsuleAction(icon: Symbols.call, tooltip: '语音通话'),
              ChatCapsuleAction(icon: Symbols.more_vert, tooltip: '详情'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final left =
        tester.getRect(find.byKey(const ValueKey('chat_header_left_capsule')));
    final title =
        tester.getRect(find.byKey(const ValueKey('chat_header_title_capsule')));
    final actions = tester
        .getRect(find.byKey(const ValueKey('chat_header_actions_capsule')));

    expect(left.width, actions.width);
    expect(left.center.dy, title.center.dy);
    expect(actions.center.dy, title.center.dy);
  });

  testWidgets('chat capsule header scales title text down when constrained',
      (tester) async {
    const longTitle = 'Very Long Portal Contact Name';
    const longSubtitle = 'p2p-im-test-long-domain.com';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: ChatCapsuleHeader(
                title: longTitle,
                subtitle: longSubtitle,
                onBack: () {},
                leadingAvatar: const CircleAvatar(child: Text('Y')),
                actions: const [
                  ChatCapsuleAction(icon: Symbols.call, tooltip: '语音通话'),
                  ChatCapsuleAction(icon: Symbols.more_vert, tooltip: '详情'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleText = tester.widget<Text>(find.text(longTitle));
    final subtitleText = tester.widget<Text>(find.text(longSubtitle));

    expect(titleText.style?.fontSize, lessThan(16));
    expect(subtitleText.style?.fontSize, lessThan(11));
  });

  testWidgets('chat capsule input switches between text and voice modes',
      (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatCapsuleInputBar(
              ctrl: ctrl,
              onSend: () {},
              onPlus: () {},
              onEmoji: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('chat_input_plus_circle')), findsOne);
    expect(find.byKey(const ValueKey('chat_input_text_capsule')), findsOne);
    expect(find.byKey(const ValueKey('chat_input_mic_circle')), findsOne);
    expect(find.text('按住 说话'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('chat_input_mic_circle')));
    await tester.pumpAndSettle();

    expect(find.text('按住 说话'), findsOneWidget);
    expect(find.byIcon(Symbols.keyboard), findsOneWidget);
  });

  testWidgets('chat capsule input records voice while pressed', (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    var started = 0;
    var stopped = 0;
    var canceled = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatCapsuleInputBar(
              ctrl: ctrl,
              onSend: () {},
              onPlus: () {},
              onEmoji: () {},
              onVoiceRecordStart: () => started++,
              onVoiceRecordStop: () => stopped++,
              onVoiceRecordCancel: () => canceled++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('chat_input_mic_circle')));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('voice_mode'))),
    );
    await tester.pump();

    expect(started, 1);
    expect(find.text('松开 发送'), findsOneWidget);
    expect(find.byKey(const ValueKey('voice_recording_overlay')), findsOne);
    expect(find.byKey(const ValueKey('voice_recording_wave_card')), findsOne);
    expect(find.text('松开发送，上滑取消'), findsOne);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(stopped, 1);
    expect(canceled, 0);
    expect(find.text('按住 说话'), findsOneWidget);
    expect(find.byKey(const ValueKey('voice_recording_overlay')), findsNothing);
  });

  testWidgets('chat capsule input cancels voice after sliding up',
      (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    var started = 0;
    var stopped = 0;
    var canceled = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatCapsuleInputBar(
              ctrl: ctrl,
              onSend: () {},
              onPlus: () {},
              onEmoji: () {},
              onVoiceRecordStart: () => started++,
              onVoiceRecordStop: () => stopped++,
              onVoiceRecordCancel: () => canceled++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('chat_input_mic_circle')));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('voice_mode'))),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, -180));
    await tester.pump();

    expect(started, 1);
    expect(find.text('松开 取消'), findsOneWidget);
    expect(find.byKey(const ValueKey('voice_recording_overlay')), findsOne);
    expect(find.text('松开取消'), findsOne);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(stopped, 0);
    expect(canceled, 1);
    expect(find.text('按住 说话'), findsOneWidget);
    expect(find.byKey(const ValueKey('voice_recording_overlay')), findsNothing);
  });

  testWidgets('chat capsule input keeps three controls on one center axis',
      (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatCapsuleInputBar(
              ctrl: ctrl,
              onSend: () {},
              onPlus: () {},
              onEmoji: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final plus =
        tester.getRect(find.byKey(const ValueKey('chat_input_plus_circle')));
    final input =
        tester.getRect(find.byKey(const ValueKey('chat_input_text_capsule')));
    final mic =
        tester.getRect(find.byKey(const ValueKey('chat_input_mic_circle')));

    expect(plus.width, mic.width);
    expect(plus.center.dy, input.center.dy);
    expect(mic.center.dy, input.center.dy);
  });

  testWidgets('chat capsule input keeps emoji button vertically centered',
      (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatCapsuleInputBar(
              ctrl: ctrl,
              onSend: () {},
              onPlus: () {},
              onEmoji: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final input =
        tester.getRect(find.byKey(const ValueKey('chat_input_text_capsule')));
    final emojiCenter =
        tester.getCenter(find.byKey(const ValueKey('chat_input_emoji_circle')));

    expect(emojiCenter.dy, input.center.dy);
  });

  testWidgets('chat capsule input shows iOS send button when text exists',
      (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    var sent = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatCapsuleInputBar(
              ctrl: ctrl,
              onSend: () => sent++,
              onPlus: () {},
              onEmoji: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat_input_plus_circle')), findsOne);
    expect(find.byKey(const ValueKey('chat_input_send_button')), findsNothing);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat_input_plus_circle')), findsNothing);
    expect(find.byKey(const ValueKey('chat_input_send_button')), findsOne);
    expect(find.text('发送'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat_input_send_button')));
    expect(sent, 1);
  });
}

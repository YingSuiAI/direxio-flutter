import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/chat/chat_capsule_chrome.dart';

void main() {
  testWidgets('message layer fills the whole screen behind chat chrome',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ChatLayeredLayout(
            header: SizedBox(
              key: ValueKey('header'),
              height: 120,
              child: Text('top chrome'),
            ),
            messageLayer: ColoredBox(
              key: ValueKey('messages'),
              color: Colors.transparent,
              child: Text('messages'),
            ),
            bottomOverlay: SizedBox(
              key: ValueKey('bottom'),
              height: 110,
              child: Text('bottom chrome'),
            ),
          ),
        ),
      ),
    );

    final screenRect = tester.getRect(find.byType(ChatLayeredLayout));
    final messageRect = tester.getRect(find.byKey(const ValueKey('messages')));
    final headerRect = tester.getRect(find.byKey(const ValueKey('header')));
    final bottomRect = tester.getRect(find.byKey(const ValueKey('bottom')));

    expect(messageRect.top, screenRect.top);
    expect(messageRect.bottom, screenRect.bottom);
    expect(headerRect.top, screenRect.top);
    expect(bottomRect.bottom, screenRect.bottom);
  });

  testWidgets('message viewport padding accounts for overlay chrome',
      (tester) async {
    late EdgeInsets padding;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: 47, bottom: 34),
          ),
          child: Builder(
            builder: (context) {
              padding = chatMessageViewportPadding(
                context,
                horizontal: 16,
                replyBarVisible: true,
                bottomPanelVisible: true,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(padding.left, 16);
    expect(padding.right, 16);
    expect(padding.top, greaterThan(47));
    expect(padding.bottom, greaterThan(34));
  });
}

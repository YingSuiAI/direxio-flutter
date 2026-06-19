import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/chat/chat_glass_background.dart';

void main() {
  testWidgets('chat background provides page color without duplicating glass',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ChatGlassBackground(
            child: Text('message area'),
          ),
        ),
      ),
    );

    expect(find.text('message area'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);

    final background = tester.widget<ColoredBox>(
      find
          .ancestor(
            of: find.text('message area'),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(background.color,
        chatPageBackgroundColor(tester.element(find.text('message area'))));
  });
}

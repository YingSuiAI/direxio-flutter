import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/widgets/agent_message_body.dart';

void main() {
  testWidgets('agent message body typewrites appended text updates',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: AgentMessageBody('Hello', animateUpdates: true),
        ),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body:
              AgentMessageBody('Hello streaming answer', animateUpdates: true),
        ),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Hello streaming answer'), findsNothing);

    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Hello strea'), findsOneWidget);
    expect(find.text('Hello streaming answer'), findsNothing);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Hello streaming answer'), findsOneWidget);
  });
}

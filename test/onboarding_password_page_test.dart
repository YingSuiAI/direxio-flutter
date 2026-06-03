import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/setup_payload.dart';
import 'package:portal_app/presentation/pages/onboarding_password_page.dart';

void main() {
  testWidgets('onboarding password page rejects mismatched confirmation',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: OnboardingPasswordPage(
            payload: SetupPayload(
              server: Uri.parse('https://example.com'),
              code: 'a7k9m2q4',
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'new-pass-2026');
    await tester.enterText(find.byType(TextField).at(1), 'new-pass-2027');
    await tester.tap(find.text('完成设置'));
    await tester.pump();

    expect(find.text('两次输入的口令不一致'), findsOneWidget);
  });
}

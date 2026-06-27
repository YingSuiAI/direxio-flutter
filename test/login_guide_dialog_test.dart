import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/pages/login_page.dart';

void main() {
  testWidgets('English login guide fits on compact iOS-sized screens',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Getting Started Guide'));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('login_guide_dialog_card')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('login_guide_dialog_card')),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/widgets/report_reason_dialog.dart';

void main() {
  testWidgets('report reason dialog uses localized visible copy',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDialog<ReportReasonResult>(
                  context: context,
                  builder: (_) => const ReportReasonDialog(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Select a report reason'), findsOneWidget);
    expect(find.text('Fraud'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
    expect(find.text('请选择举报原因'), findsNothing);
  });
}

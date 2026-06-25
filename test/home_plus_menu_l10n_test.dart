import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/home/home_plus_menu.dart';

void main() {
  testWidgets('home and contacts plus menu uses localized English labels',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: HomePlusMenuPanel.width,
              height: HomePlusMenuPanel.height,
              child: HomePlusMenuPanel(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Add Friend'), findsOneWidget);
    expect(find.text('Start Group Chat'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('添加好友'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

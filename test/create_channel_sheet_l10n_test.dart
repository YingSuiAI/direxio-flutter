import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/channel/create_channel_sheet.dart';

void main() {
  testWidgets('create channel sheet uses localized visible copy',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Consumer(
            builder: (context, ref, child) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showCreateChannelDialog(context, ref),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Create Channel'), findsWidgets);
    expect(find.text('Channel Name'), findsOneWidget);
    expect(find.text('Enter'), findsOneWidget);
    expect(find.text('Upload Channel Avatar'), findsOneWidget);
    expect(
      find.text('Upload an image to use as the channel avatar'),
      findsOneWidget,
    );
    expect(find.text('Select Channel Type'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Posts'), findsOneWidget);

    expect(find.text('创建频道'), findsNothing);
    expect(find.text('频道名称'), findsNothing);
  });
}

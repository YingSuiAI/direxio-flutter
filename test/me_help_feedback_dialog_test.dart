import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/core/theme/design_tokens.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/pages/me_home_tab.dart';
import 'package:portal_app/presentation/providers/profile_provider.dart';

void main() {
  testWidgets('help feedback dialog adapts background in dark mode',
      (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: MePage(client: client)),
        ),
      ),
    );

    await tester.tap(find.text('帮助与反馈'));
    await tester.pumpAndSettle();

    final background = tester.widget<Image>(
      find.byKey(const ValueKey('help_feedback_background')),
    );
    expect(
      (background.image as AssetImage).assetName,
      'assets/images/ic_help_feedback2.png',
    );
    expect(background.color, PortalTokens.dark.surface);
    expect(background.colorBlendMode, BlendMode.modulate);

    final headline = tester.widget<Text>(find.text('一起打造更好的\nDirexio'));
    expect(headline.style?.color, PortalTokens.dark.text);
    final buttonText = tester.widget<Text>(find.text('知道了'));
    expect(buttonText.style?.color, PortalTokens.dark.onAccent);
  });

  testWidgets('help feedback dialog fits localized copy on narrow screens',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: MePage(client: client)),
        ),
      ),
    );

    await tester.tap(find.text('Help & Feedback'));
    await tester.pumpAndSettle();

    final background = tester.widget<Image>(
      find.byKey(const ValueKey('help_feedback_background')),
    );
    expect(
      (background.image as AssetImage).assetName,
      'assets/images/ic_help_feedback2.png',
    );
    expect(find.text('Got it'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

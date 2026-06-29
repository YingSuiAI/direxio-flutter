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
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
      'assets/images/ic_help_feedback1.png',
    );
    expect(background.color, PortalTokens.dark.surface);
    expect(background.colorBlendMode, BlendMode.modulate);

    expect(find.text('一起打造更好的\nDirexio'), findsNothing);
    expect(find.text('发现问题或有好想法？'), findsNothing);
    expect(find.textContaining('liyananinsh@outlook.com'), findsNothing);
    expect(find.text('我们会持续根据你的反馈优化产品。'), findsNothing);
    expect(
      tester.getCenter(find.byType(FilledButton)).dx,
      closeTo(
        tester
                .getCenter(
                    find.byKey(const ValueKey('help_feedback_background')))
                .dx -
            10,
        0.5,
      ),
    );
    final buttonText = tester.widget<Text>(find.text('知道了'));
    expect(buttonText.style?.color, PortalTokens.dark.onAccent);
  });

  testWidgets('help feedback dialog keeps only action on narrow screens',
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
    expect(find.text('Build a Better\nDirexio Together'), findsNothing);
    expect(find.text('Found an issue or have a great idea?'), findsNothing);
    expect(find.textContaining('liyananinsh@outlook.com'), findsNothing);
    expect(
      find.text('We will keep optimizing based on your feedback.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

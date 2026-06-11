import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/providers/app_locale_provider.dart';

void main() {
  test('maps mobile language indices to supported locale modes', () {
    expect(AppLocaleMode.fromMobileIndex(0), AppLocaleMode.system);
    expect(AppLocaleMode.fromMobileIndex(1), AppLocaleMode.zh);
    expect(AppLocaleMode.fromMobileIndex(2), AppLocaleMode.en);
    expect(AppLocaleMode.fromMobileIndex(3), AppLocaleMode.zh);
    expect(AppLocaleMode.fromMobileIndex(4), AppLocaleMode.ja);
    expect(AppLocaleMode.fromMobileIndex(5), AppLocaleMode.en);
  });

  test('matches system locale with mobile fallback behavior', () {
    expect(
      AppLocaleMode.resolveSystemLocale(const Locale('zh', 'TW')),
      const Locale('zh'),
    );
    expect(
      AppLocaleMode.resolveSystemLocale(const Locale('ja', 'JP')),
      const Locale('ja'),
    );
    expect(
      AppLocaleMode.resolveSystemLocale(const Locale('ko', 'KR')),
      const Locale('en'),
    );
    expect(
      AppLocaleMode.resolveSystemLocale(const Locale('fr', 'FR')),
      const Locale('en'),
    );
  });

  testWidgets('updates MaterialApp locale when language mode changes',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({'language': '1'});

    await tester.pumpWidget(
      const ProviderScope(child: _LocaleHarness()),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('通讯录'), findsOneWidget);

    await tester.tap(find.text('to_en'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('设置'), findsNothing);
  });
}

class _LocaleHarness extends ConsumerWidget {
  const _LocaleHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeState = ref.watch(appLocaleProvider);
    return MaterialApp(
      locale: localeState.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Column(
              children: [
                Text(l10n.settingsTitle),
                Text(l10n.tabContacts),
                Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () => ref
                        .read(appLocaleProvider.notifier)
                        .setMode(AppLocaleMode.en),
                    child: const Text('to_en'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/pages/settings_page.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';

void main() {
  testWidgets('settings language picker only shows Chinese and English',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({'language': '1'});
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('简体中文')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('English')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('跟随系统')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('日本語')),
      findsNothing,
    );
  });
}

class _LoggedInAuthStateNotifier extends AuthStateNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        isLoggedIn: true,
        userId: '@owner:p2p-im.com',
        homeserver: 'https://p2p-im.com',
        portalToken: 'access-token',
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/pages/home_page.dart';
import 'package:portal_app/presentation/pages/requests_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/app_warmup_provider.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';

import 'support/mock_as_client.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('English contacts new friends shortcut opens requests page',
      (tester) async {
    final client = Client('RequestsEnglishContactsShortcutTest')
      ..setUserId('@owner:p2p-im.com');
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/requests',
          builder: (_, __) => const Text('requests-route'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_LoggedInAuthNotifier.new),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_BootstrapAsClient(
            AsSyncBootstrap(
              syncedAt: DateTime.utc(2026, 6, 26, 10),
              user: const AsSyncUser(userId: '@owner:p2p-im.com'),
              rooms: const [],
              contacts: const [],
              groups: const [],
              channels: const [],
              pending: const AsSyncPending.empty(),
            ),
          )),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Contacts').last);
    await tester.pump();
    await tester.tap(find.text('New Friends'));
    await tester.pumpAndSettle();

    expect(find.text('requests-route'), findsOneWidget);
  });

  testWidgets('new friends accepted contact message is localized in English',
      (tester) async {
    final client = Client('RequestsAcceptedContactEnglishL10nTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 26, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/requests',
      routes: [
        GoRoute(path: '/requests', builder: (_, __) => const RequestsPage()),
        GoRoute(
          path: '/contact/:userId',
          builder: (_, state) => Text(
            'contact:${state.pathParameters['userId']}:${state.uri.queryParameters['source'] ?? ''}',
          ),
        ),
        GoRoute(
          path: '/add-contact/detail/:userId',
          builder: (_, state) => Text(
            'add-contact:${state.pathParameters['userId']}',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_LoggedInAuthNotifier.new),
          asClientProvider.overrideWithValue(_BootstrapAsClient(bootstrap)),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('You are now friends'), findsOneWidget);
    expect(find.text('已成为朋友'), findsNothing);

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.text('contact:@alice:p2p-im.com:chat_avatar'), findsOneWidget);
    expect(find.text('add-contact:@alice:p2p-im.com'), findsNothing);
  });
}

class _LoggedInAuthNotifier extends AuthStateNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        isLoggedIn: true,
        userId: '@owner:p2p-im.com',
        homeserver: 'https://p2p-im.com',
        portalToken: 'portal-token',
      );
}

class _BootstrapAsClient extends MockAsClient {
  _BootstrapAsClient(this.bootstrap);

  final AsSyncBootstrap bootstrap;

  @override
  Future<AsSyncBootstrap> syncBootstrap() async => bootstrap;
}

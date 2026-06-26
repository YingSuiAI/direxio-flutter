import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/profile_provider.dart';
import 'package:portal_app/presentation/utils/group_creation_flow.dart';

void main() {
  testWidgets('create group flow localizes picker and setup pages in English',
      (tester) async {
    final client = Client('DirexioCreateGroupEnglishL10nTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 26, 12),
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const _OpenCreateGroupFlowButton(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Start Group Chat'), findsOneWidget);
    expect(find.text('ID / Nickname / Email'), findsOneWidget);
    expect(find.text('发起群聊'), findsNothing);
    expect(find.text('ID/昵称/邮箱'), findsNothing);

    await tester.tap(find.text('Alice'));
    await tester.pump();
    await tester.tap(find.text('Done(1)'));
    await tester.pumpAndSettle();

    expect(find.text('Create Group Chat'), findsOneWidget);
    expect(find.text('Group Members'), findsOneWidget);
    expect(find.text('1 member'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('创建群聊'), findsNothing);
    expect(find.text('群成员'), findsNothing);
    expect(find.text('1人'), findsNothing);
    expect(find.text('完成创建'), findsNothing);

    await client.dispose(closeDatabase: false);
  });
}

class _OpenCreateGroupFlowButton extends ConsumerWidget {
  const _OpenCreateGroupFlowButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showCreateGroupFlow(context, ref),
          child: const Text('open'),
        ),
      ),
    );
  }
}

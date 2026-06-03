import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/pages/contact_home_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';

class _LoggedInAuthStateNotifier extends AuthStateNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        isLoggedIn: true,
        userId: '@owner:p2p-im.com',
        homeserver: 'https://p2p-im.com',
        portalToken: 'portal-token',
      );
}

class _RelationshipAsClient extends Fake implements AsClient {
  _RelationshipAsClient({
    this.initialFollows = const [],
    this.bootstrapAfterDelete,
  });

  final List<FollowEntry> initialFollows;
  final AsSyncBootstrap? bootstrapAfterDelete;
  final removedFollows = <String>[];
  final deletedContacts = <String>[];

  @override
  Future<List<FollowEntry>> getFollows() async => initialFollows
      .where((follow) => !removedFollows.contains(follow.domain))
      .toList(growable: false);

  @override
  Future<void> addFollow(String domain) async {}

  @override
  Future<void> removeFollow(String domain) async {
    removedFollows.add(domain);
  }

  @override
  Future<ContactEntry> deleteContact(String roomId) async {
    deletedContacts.add(roomId);
    return ContactEntry(
      peerMxid: '@alice:portal.local',
      displayName: 'Alice Chen',
      domain: 'alice.portal.local',
      roomId: roomId,
      status: 'rejected',
    );
  }

  @override
  Future<AsSyncBootstrap> syncBootstrap() async =>
      bootstrapAfterDelete ?? _bootstrap(contacts: const []);

  @override
  Future<ContactEntry> createContactRequest({
    required String mxid,
    String displayName = '',
    String domain = '',
  }) async {
    return ContactEntry(
      peerMxid: mxid,
      displayName: displayName,
      domain: domain,
      roomId: '!pending:p2p-im.com',
      status: 'pending_outbound',
    );
  }
}

void main() {
  testWidgets('real contact without mock profile still renders visitor header',
      (tester) async {
    final client = Client('ContactHomeRealFallbackTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = _bootstrap(
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'owner',
          avatarUrl: '',
          roomId: '!owner:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_RelationshipAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContactHomePage(userId: '@owner:p2p-liyanan.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('联系人主页不存在'), findsNothing);
    expect(find.text('owner'), findsOneWidget);
    expect(find.text('p2p-liyanan.com'), findsOneWidget);
    expect(find.text('还没有公开频道'), findsOneWidget);
    expect(find.text('还没有公开动态'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('contact_home_add_friend_button')),
        matching: find.text('删除好友'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('contact_home_follow_button')),
        matching: find.text('关注'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('accepted visitor home shows delete friend and removes via AS',
      (tester) async {
    final client = Client('ContactHomeRelationshipDeleteTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = _bootstrap(
      contacts: const [
        AsSyncContact(
          userId: '@alice:portal.local',
          displayName: 'Alice Chen',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'alice.portal.local',
          status: 'accepted',
        ),
      ],
    );
    final asClient = _RelationshipAsClient(
      bootstrapAfterDelete: _bootstrap(contacts: const []),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContactHomePage(userId: '@alice:portal.local'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final friendButton =
        find.byKey(const ValueKey('contact_home_add_friend_button'));
    expect(find.descendant(of: friendButton, matching: find.text('删除好友')),
        findsOneWidget);

    await tester.tap(friendButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(asClient.deletedContacts, ['!alice:p2p-im.com']);
    expect(find.descendant(of: friendButton, matching: find.text('加好友')),
        findsOneWidget);
  });

  testWidgets('followed visitor home shows unfollow and removes via AS',
      (tester) async {
    final client = Client('ContactHomeRelationshipUnfollowTest')
      ..setUserId('@owner:p2p-im.com');
    final asClient = _RelationshipAsClient(
      initialFollows: [
        FollowEntry(
          domain: 'alice.portal.local',
          name: 'Alice Chen',
          followedAt: DateTime.utc(2026, 5, 26, 8),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) =>
                AsSyncCacheState(bootstrap: _bootstrap(contacts: const [])),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContactHomePage(userId: '@alice:portal.local'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final followButton =
        find.byKey(const ValueKey('contact_home_follow_button'));
    expect(find.descendant(of: followButton, matching: find.text('取关')),
        findsOneWidget);

    await tester.tap(followButton);
    await tester.pumpAndSettle();

    expect(asClient.removedFollows, ['alice.portal.local']);
    expect(find.descendant(of: followButton, matching: find.text('关注')),
        findsOneWidget);
  });
}

AsSyncBootstrap _bootstrap({required List<AsSyncContact> contacts}) {
  return AsSyncBootstrap(
    syncedAt: DateTime.utc(2026, 5, 26, 10),
    user: const AsSyncUser(userId: '@owner:p2p-im.com'),
    rooms: const [],
    contacts: contacts,
    groups: const [],
    channels: const [],
    pending: const AsSyncPending.empty(),
  );
}

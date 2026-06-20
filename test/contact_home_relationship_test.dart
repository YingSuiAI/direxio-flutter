import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_bootstrap_store.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/pages/channel_page.dart';
import 'package:portal_app/presentation/pages/contact_home_page.dart';
import 'package:portal_app/presentation/providers/as_bootstrap_store_provider.dart';
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

class _MemoryAsBootstrapStore implements AsBootstrapStore {
  AsSyncBootstrap? value;

  @override
  Future<void> clear() async {
    value = null;
  }

  @override
  Future<AsSyncBootstrap?> read() async => value;

  @override
  Future<void> write(AsSyncBootstrap bootstrap) async {
    value = bootstrap;
  }
}

class _RelationshipAsClient extends Fake implements AsClient {
  _RelationshipAsClient({
    this.initialFollows = const [],
    this.bootstrapAfterDelete,
    this.publicChannels = const [],
  });

  final List<FollowEntry> initialFollows;
  final AsSyncBootstrap? bootstrapAfterDelete;
  final List<AsChannel> publicChannels;
  final removedFollows = <String>[];
  final deletedContacts = <String>[];
  String? requestedPublicRoomId;

  @override
  Future<List<FollowEntry>> getFollows() async => initialFollows
      .where((follow) => !removedFollows.contains(follow.domain))
      .toList(growable: false);

  @override
  Future<List<AsChannel>> getUserPublicChannels(
    String userId, {
    Uri? baseUri,
  }) async =>
      publicChannels;

  @override
  Future<AsChannel> getPublicChannelByRoomId(
    String roomId, {
    Uri? baseUri,
    Uri? remoteNodeBaseUri,
  }) async {
    requestedPublicRoomId = roomId;
    return publicChannels.firstWhere(
      (channel) => channel.roomId.trim() == roomId.trim(),
      orElse: () => AsChannel(
        channelId: roomId,
        roomId: roomId,
        name: '公开频道',
        visibility: asChannelVisibilityPublic,
      ),
    );
  }

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
    expect(find.text('她的频道'), findsNothing);
    expect(find.text('还没有公开频道'), findsNothing);
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

  testWidgets('visitor home renders public channels returned by AS',
      (tester) async {
    final client = Client('ContactHomePublicChannelsTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = _bootstrap(
      contacts: const [
        AsSyncContact(
          userId: '@alice:portal.local',
          displayName: 'Alice Chen',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'alice.portal.local',
          status: 'pending_outbound',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(
            _RelationshipAsClient(
              publicChannels: const [
                AsChannel(
                  channelId: 'ch_alice',
                  roomId: '!alice-channel:portal.local',
                  name: 'Alice 公开频道',
                  avatarUrl: 'https://example.com/alice-channel.png',
                  visibility: asChannelVisibilityPublic,
                  memberCount: 7,
                ),
              ],
            ),
          ),
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

    expect(find.text('Alice 公开频道'), findsOneWidget);
    expect(find.textContaining('!alice-channel:portal.local'), findsOneWidget);
    expect(find.text('还没有公开频道'), findsNothing);
  });

  testWidgets('visitor public channel opens channel detail for joining',
      (tester) async {
    final client = Client('ContactHomePublicChannelOpenTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = _bootstrap(
      contacts: const [
        AsSyncContact(
          userId: '@alice:portal.local',
          displayName: 'Alice Chen',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'alice.portal.local',
          status: 'pending_outbound',
        ),
      ],
    );
    final asClient = _RelationshipAsClient(
      publicChannels: const [
        AsChannel(
          channelId: 'ch_alice',
          roomId: '!alice-channel:portal.local',
          name: 'Alice 公开频道',
          visibility: asChannelVisibilityPublic,
          joinPolicy: asChannelJoinPolicyApproval,
          memberCount: 7,
        ),
      ],
    );
    final router = GoRouter(
      initialLocation:
          '/contact-home/${Uri.encodeComponent('@alice:portal.local')}',
      routes: [
        GoRoute(
          path: '/contact-home/:userId',
          builder: (_, state) => ContactHomePage(
            userId: state.pathParameters['userId']!,
          ),
        ),
        GoRoute(
          path: '/channel/:channelId',
          builder: (_, state) => ChannelPage(
            channelId: state.pathParameters['channelId']!,
          ),
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
          asBootstrapRepositoryProvider.overrideWithValue(
            AsBootstrapRepository(
              loadBootstrap: () async => bootstrap,
              store: _MemoryAsBootstrapStore(),
            ),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice 公开频道'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(asClient.requestedPublicRoomId, '!alice-channel:portal.local');
    expect(find.text('申请加入'), findsOneWidget);
    expect(find.text('频道不存在'), findsNothing);
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

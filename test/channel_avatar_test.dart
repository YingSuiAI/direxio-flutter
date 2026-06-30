import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/channel/channel_avatar_cache.dart';
import 'package:portal_app/presentation/channel/channel_home_tab.dart';
import 'package:portal_app/presentation/channel/channel_inbox_data.dart';
import 'package:portal_app/presentation/channel/channel_member_avatar.dart';
import 'package:portal_app/presentation/pages/channel_info_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/widgets/portal_avatar.dart';
import 'support/mock_as_client.dart';

void main() {
  testWidgets('channel inbox tile renders network avatar when cache is cold',
      (tester) async {
    final client = Client('ChannelAvatarTest');
    final avatarUrl =
        'https://cdn.example.com/channel-cold-${DateTime.now().microsecondsSinceEpoch}.png';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [matrixClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChannelInboxTile(
              channel: ChannelInboxItem(
                id: 'ch_avatar',
                roomId: '!avatar:p2p-im.com',
                name: '产品公告',
                domain: 'p2p-im.com',
                avatarUrl: avatarUrl,
                latestPreview: '频道介绍',
                latestAt: null,
                unreadCount: 0,
                isOwned: true,
                tags: ['文字'],
              ),
              showDivider: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<PortalAvatar>(find.byType(PortalAvatar))
          .where((avatar) => avatar.imageUrl == avatarUrl),
      isNotEmpty,
    );
    expect(find.text('产'), findsNothing);
  });

  testWidgets('channel inbox tile renders cached avatar bytes after restart',
      (tester) async {
    final client = Client('ChannelCachedAvatarTest');
    final avatarUrl =
        'https://cdn.example.com/channel-cached-${DateTime.now().microsecondsSinceEpoch}.png';
    final bytes = Uint8List.fromList(_transparentPngBytes);
    setChannelAvatarCacheReaderForTesting(
      (url) async => url == avatarUrl ? bytes : null,
    );
    addTearDown(() {
      setChannelAvatarCacheReaderForTesting(null);
      clearChannelAvatarMemoryCacheForTesting();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [matrixClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChannelInboxTile(
              channel: ChannelInboxItem(
                id: 'ch_avatar_cached',
                roomId: '!avatar-cached:p2p-im.com',
                name: '产品公告',
                domain: 'p2p-im.com',
                avatarUrl: avatarUrl,
                latestPreview: '频道介绍',
                latestAt: null,
                unreadCount: 0,
                isOwned: true,
                tags: const ['文字'],
              ),
              showDivider: false,
            ),
          ),
        ),
      ),
    );
    final avatar = await _pumpUntilPortalAvatarBytes(tester, bytes);
    expect(avatar.imageUrl, isNull);
    expect(avatar.imageBytes, bytes);
    expect(avatar.shape, AvatarShape.squircle);
  });

  testWidgets('channel inbox tile keeps cached avatar stable after tab rebuild',
      (tester) async {
    final client = Client('ChannelStableAvatarTest');
    final avatarUrl =
        'https://cdn.example.com/channel-stable-${DateTime.now().microsecondsSinceEpoch}.png';
    final bytes = Uint8List.fromList(_transparentPngBytes);
    setChannelAvatarCacheReaderForTesting(
      (url) async => url == avatarUrl ? bytes : null,
    );
    addTearDown(() {
      setChannelAvatarCacheReaderForTesting(null);
      clearChannelAvatarMemoryCacheForTesting();
    });

    Widget buildTile() => ProviderScope(
          overrides: [matrixClientProvider.overrideWithValue(client)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: ChannelInboxTile(
                channel: ChannelInboxItem(
                  id: 'ch_avatar_stable',
                  roomId: '!avatar-stable:p2p-im.com',
                  name: '产品公告',
                  domain: 'p2p-im.com',
                  avatarUrl: avatarUrl,
                  latestPreview: '频道介绍',
                  latestAt: null,
                  unreadCount: 0,
                  isOwned: true,
                  tags: const ['文字'],
                ),
                showDivider: false,
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildTile());
    final firstAvatar = await _pumpUntilPortalAvatarBytes(tester, bytes);
    expect(firstAvatar.imageBytes, bytes);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final pendingRead = Completer<Uint8List?>();
    setChannelAvatarCacheReaderForTesting((_) => pendingRead.future);

    await tester.pumpWidget(buildTile());

    expect(find.text('产'), findsNothing);
    final avatar = tester.widget<PortalAvatar>(find.byType(PortalAvatar));
    expect(avatar.imageBytes, bytes);
    expect(avatar.shape, AvatarShape.squircle);
  });

  testWidgets(
      'channel inbox tile keeps cached avatar stable across brief unmount',
      (tester) async {
    final client = Client('ChannelUnmountAvatarTest');
    final avatarUrl =
        'https://cdn.example.com/channel-unmount-${DateTime.now().microsecondsSinceEpoch}.png';
    final bytes = Uint8List.fromList(_transparentPngBytes);
    setChannelAvatarCacheReaderForTesting(
      (url) async => url == avatarUrl ? bytes : null,
    );
    addTearDown(() {
      setChannelAvatarCacheReaderForTesting(null);
      clearChannelAvatarMemoryCacheForTesting();
    });

    var showTile = true;
    Widget buildSubject() => ProviderScope(
          overrides: [matrixClientProvider.overrideWithValue(client)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: showTile
                  ? ChannelInboxTile(
                      channel: ChannelInboxItem(
                        id: 'ch_avatar_unmount',
                        roomId: '!avatar-unmount:p2p-im.com',
                        name: '产品公告',
                        domain: 'p2p-im.com',
                        avatarUrl: avatarUrl,
                        latestPreview: '频道介绍',
                        latestAt: null,
                        unreadCount: 0,
                        isOwned: true,
                        tags: const ['文字'],
                      ),
                      showDivider: false,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        );

    await tester.pumpWidget(buildSubject());
    final firstAvatar = await _pumpUntilPortalAvatarBytes(tester, bytes);
    expect(firstAvatar.imageBytes, bytes);

    showTile = false;
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    clearChannelAvatarMemoryCacheForTesting();
    final pendingRead = Completer<Uint8List?>();
    setChannelAvatarCacheReaderForTesting((_) => pendingRead.future);

    showTile = true;
    await tester.pumpWidget(buildSubject());

    expect(find.text('产'), findsNothing);
    final avatar = tester.widget<PortalAvatar>(find.byType(PortalAvatar));
    expect(avatar.imageBytes, bytes);
    expect(avatar.shape, AvatarShape.squircle);
  });

  testWidgets(
      'channel inbox tile keeps avatar stable when refreshed url changes',
      (tester) async {
    final client = Client('ChannelStableAvatarUrlChangeTest');
    final firstAvatarUrl =
        'https://cdn.example.com/channel-stable-a-${DateTime.now().microsecondsSinceEpoch}.png';
    final refreshedAvatarUrl =
        'https://cdn.example.com/channel-stable-b-${DateTime.now().microsecondsSinceEpoch}.png';
    final bytes = Uint8List.fromList(_transparentPngBytes);
    setChannelAvatarCacheReaderForTesting(
      (url) async => url == firstAvatarUrl ? bytes : null,
    );
    addTearDown(() {
      setChannelAvatarCacheReaderForTesting(null);
      clearChannelAvatarMemoryCacheForTesting();
    });

    Widget buildTile(String avatarUrl) => ProviderScope(
          overrides: [matrixClientProvider.overrideWithValue(client)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: ChannelInboxTile(
                channel: ChannelInboxItem(
                  id: 'ch_avatar_stable_url',
                  roomId: '!avatar-stable-url:p2p-im.com',
                  name: '产品公告',
                  domain: 'p2p-im.com',
                  avatarUrl: avatarUrl,
                  latestPreview: '频道介绍',
                  latestAt: null,
                  unreadCount: 0,
                  isOwned: true,
                  tags: const ['文字'],
                ),
                showDivider: false,
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildTile(firstAvatarUrl));
    final firstAvatar = await _pumpUntilPortalAvatarBytes(tester, bytes);
    expect(firstAvatar.imageBytes, bytes);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final pendingRead = Completer<Uint8List?>();
    setChannelAvatarCacheReaderForTesting(
      (url) => url == refreshedAvatarUrl ? pendingRead.future : Future.value(),
    );

    await tester.pumpWidget(buildTile(refreshedAvatarUrl));

    expect(find.text('产'), findsNothing);
    final avatar = tester.widget<PortalAvatar>(find.byType(PortalAvatar));
    expect(avatar.imageBytes, bytes);
    expect(avatar.shape, AvatarShape.squircle);
  });

  testWidgets('channel inbox tile renders avatar bytes seeded after create',
      (tester) async {
    final client = Client('ChannelSeededAvatarTest');
    final avatarUrl =
        'https://cdn.example.com/channel-seeded-${DateTime.now().microsecondsSinceEpoch}.png';
    final bytes = Uint8List.fromList(_transparentPngBytes);
    seedChannelAvatarCacheBytes(
      avatarUrl,
      bytes,
      stableKey: channelAvatarStableCacheKey(
        channelId: 'ch_avatar_seeded',
        roomId: '!avatar-seeded:p2p-im.com',
      ),
      persist: false,
    );
    addTearDown(clearChannelAvatarMemoryCacheForTesting);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [matrixClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChannelInboxTile(
              channel: ChannelInboxItem(
                id: 'ch_avatar_seeded',
                roomId: '!avatar-seeded:p2p-im.com',
                name: '产品公告',
                domain: 'p2p-im.com',
                avatarUrl: avatarUrl,
                latestPreview: '频道介绍',
                latestAt: null,
                unreadCount: 0,
                isOwned: true,
                tags: const ['文字'],
              ),
              showDivider: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final avatar = tester.widget<PortalAvatar>(find.byType(PortalAvatar));
    expect(avatar.imageBytes, bytes);
    expect(avatar.shape, AvatarShape.squircle);
  });

  testWidgets('member channel info page renders uploaded channel avatar',
      (tester) async {
    final client = Client('MemberChannelInfoAvatarTest');
    const avatarUrl = 'https://cdn.example.com/owned-channel.png';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
      user: const AsSyncUser(userId: '@alex:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        const AsSyncRoomSummary(
          channelId: 'ch_owned',
          roomId: '!owned:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '频道头像测试',
          avatarUrl: avatarUrl,
          unreadCount: 0,
          lastActivityAt: null,
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 0,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(MockAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelInfoPage(channelId: 'ch_owned'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final avatars = tester.widgetList<PortalAvatar>(find.byType(PortalAvatar));
    expect(
      avatars.any(
        (avatar) =>
            avatar.imageUrl == avatarUrl &&
            avatar.shape == AvatarShape.squircle,
      ),
      isTrue,
    );
  });

  testWidgets('owned channel info page hides channel avatar and name',
      (tester) async {
    final client = Client('OwnedChannelInfoHeaderHiddenTest');
    const avatarUrl = 'https://cdn.example.com/owned-channel.png';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        const AsSyncRoomSummary(
          channelId: 'ch_owned',
          roomId: '!owned:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '频道头像测试',
          avatarUrl: avatarUrl,
          unreadCount: 0,
          lastActivityAt: null,
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 0,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(MockAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelInfoPage(channelId: 'ch_owned'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final avatars = tester.widgetList<PortalAvatar>(find.byType(PortalAvatar));
    expect(avatars.any((avatar) => avatar.imageUrl == avatarUrl), isFalse);
    expect(find.textContaining('频道头像测试'), findsNothing);
  });

  test('channel member parses backend user id and avatar fields', () {
    final member = AsChannelMember.fromJson(const {
      'channel_id': 'ch_owned',
      'room_id': '!owned:p2p-im.com',
      'user_id': '@alice:p2p-im.com',
      'display_name': 'Alice',
      'avatar_url': 'https://cdn.example.com/alice.png',
      'membership': 'join',
      'role': 'member',
      'joined_at': 1770000000000,
    });

    expect(member.userMxid, '@alice:p2p-im.com');
    expect(member.roomId, '!owned:p2p-im.com');
    expect(member.avatarUrl, 'https://cdn.example.com/alice.png');
    expect(member.status, asChannelMemberStatusJoined);
  });

  testWidgets('owned channel info page renders member avatars', (tester) async {
    final client = Client('OwnedChannelInfoMemberAvatarTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    const memberAvatarUrl = 'https://cdn.example.com/alice-member.png';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        const AsSyncRoomSummary(
          channelId: 'ch_owned',
          roomId: '!owned:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '频道成员头像测试',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 2,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(
            _ChannelMemberAvatarAsClient(memberAvatarUrl),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelInfoPage(channelId: 'ch_owned'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final memberAvatar = tester.widget<PortalAvatar>(
      find.descendant(
        of: find.byKey(
          const ValueKey('channel_member_avatar_@alice:p2p-im.com'),
        ),
        matching: find.byType(PortalAvatar),
      ),
    );
    expect(memberAvatar.imageUrl, memberAvatarUrl);
    expect(memberAvatar.shape, AvatarShape.squircle);
  });

  testWidgets('owned channel info page uses Matrix room member avatar fallback',
      (tester) async {
    final client = Client('OwnedChannelInfoMatrixMemberAvatarTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    final room = Room(
      id: '!owned:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@alice:p2p-im.com',
        stateKey: '@alice:p2p-im.com',
        content: const {
          'membership': 'join',
          'displayname': 'Alice',
          'avatar_url': 'mxc://p2p-im.com/alice-room-avatar',
        },
      ),
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        const AsSyncRoomSummary(
          channelId: 'ch_owned',
          roomId: '!owned:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '频道成员头像测试',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 2,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(
            _ChannelMemberAvatarAsClient(''),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelInfoPage(channelId: 'ch_owned'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final memberAvatar = tester.widget<PortalAvatar>(
      find.descendant(
        of: find.byKey(
          const ValueKey('channel_member_avatar_@alice:p2p-im.com'),
        ),
        matching: find.byType(PortalAvatar),
      ),
    );
    expect(
      memberAvatar.imageUrl,
      contains('/download/p2p-im.com/alice-room-avatar'),
    );
  });

  testWidgets(
      'owned channel info page uses Matrix members when AS list is empty',
      (tester) async {
    final client = Client('OwnedChannelInfoEmptyAsMembersFallbackTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    final room = Room(
      id: '!owned:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@alice:p2p-im.com',
        stateKey: '@alice:p2p-im.com',
        content: const {
          'membership': 'join',
          'displayname': 'Alice',
          'avatar_url': 'mxc://p2p-im.com/alice-matrix-member-avatar',
        },
      ),
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        const AsSyncRoomSummary(
          channelId: 'ch_owned',
          roomId: '!owned:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '频道成员头像测试',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 1,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(MockAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelInfoPage(channelId: 'ch_owned'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final memberAvatar = tester.widget<PortalAvatar>(
      find.descendant(
        of: find.byKey(
          const ValueKey('channel_member_avatar_@alice:p2p-im.com'),
        ),
        matching: find.byType(PortalAvatar),
      ),
    );
    expect(
      memberAvatar.imageUrl,
      contains('/download/p2p-im.com/alice-matrix-member-avatar'),
    );
  });

  testWidgets('owned channel info page uses cached contact avatar fallback',
      (tester) async {
    final client = Client('OwnedChannelInfoContactAvatarTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: 'mxc://p2p-im.com/alice-contact-avatar',
          roomId: '!direct:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: [
        const AsSyncRoomSummary(
          channelId: 'ch_owned',
          roomId: '!owned:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '频道成员头像测试',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 2,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(
            _ChannelMemberAvatarAsClient(''),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelInfoPage(channelId: 'ch_owned'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final memberAvatar = tester.widget<PortalAvatar>(
      find.descendant(
        of: find.byKey(
          const ValueKey('channel_member_avatar_@alice:p2p-im.com'),
        ),
        matching: find.byType(PortalAvatar),
      ),
    );
    expect(
      memberAvatar.imageUrl,
      contains('/download/p2p-im.com/alice-contact-avatar'),
    );
  });

  test('channel member avatar fallback uses member room id', () {
    final client = Client('OwnedChannelInfoMemberRoomAvatarTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    final room = Room(
      id: '!owned:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@alice:p2p-im.com',
        stateKey: '@alice:p2p-im.com',
        content: const {
          'membership': 'join',
          'displayname': 'Alice',
          'avatar_url': 'mxc://p2p-im.com/alice-member-room-avatar',
        },
      ),
    );
    const member = AsChannelMember(
      channelId: 'ch_owned',
      roomId: '!owned:p2p-im.com',
      userMxid: '@alice:p2p-im.com',
      displayName: 'Alice',
      role: asChannelRoleMember,
      status: asChannelMemberStatusJoined,
    );

    expect(
      channelMemberAvatarUrl(client, member, roomId: 'ch_owned'),
      contains('/download/p2p-im.com/alice-member-room-avatar'),
    );
  });

  test('channel member avatar fallback converts Matrix profile avatar', () {
    final client = Client('OwnedChannelInfoMemberProfileAvatarTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    const member = AsChannelMember(
      channelId: 'ch_owned',
      roomId: '!owned:p2p-im.com',
      userMxid: '@alice:p2p-im.com',
      displayName: 'Alice',
      role: asChannelRoleMember,
      status: asChannelMemberStatusJoined,
    );

    expect(
      channelMemberAvatarUrl(
        client,
        member,
        fallbackAvatarUrl: 'mxc://p2p-im.com/alice-profile-avatar',
      ),
      contains('/download/p2p-im.com/alice-profile-avatar'),
    );
  });

  testWidgets('channel inbox tile opens post list or chat by channel type',
      (tester) async {
    var opened = '';
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: Column(
              children: [
                ChannelInboxTile(
                  channel: ChannelInboxItem(
                    id: 'ch_post',
                    roomId: '!post:p2p-im.com',
                    name: '帖子频道',
                    domain: 'p2p-im.com',
                    avatarUrl: '',
                    latestPreview: '帖子列表',
                    latestAt: null,
                    unreadCount: 0,
                    isOwned: false,
                    channelType: asChannelTypePost,
                    tags: [],
                  ),
                  showDivider: true,
                ),
                ChannelInboxTile(
                  channel: ChannelInboxItem(
                    id: 'ch_chat',
                    roomId: '!chat:p2p-im.com',
                    name: '文字频道',
                    domain: 'p2p-im.com',
                    avatarUrl: '',
                    latestPreview: '文字会话',
                    latestAt: null,
                    unreadCount: 0,
                    isOwned: false,
                    channelType: asChannelTypeChat,
                    tags: [],
                  ),
                  showDivider: false,
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/channel/:channelId',
          builder: (_, state) {
            opened = 'post:${state.pathParameters['channelId']}';
            return const Scaffold(body: Text('post route'));
          },
        ),
        GoRoute(
          path: '/channel/:channelId/conversation',
          builder: (_, state) {
            opened = 'chat:${state.pathParameters['channelId']}';
            return const Scaffold(body: Text('chat route'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('帖子频道'));
    await tester.pumpAndSettle();
    expect(opened, 'post:ch_post');

    router.go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字频道'));
    await tester.pumpAndSettle();
    expect(opened, 'chat:ch_chat');
  });

  testWidgets('post channel inbox tile hides member count below title',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: ChannelInboxTile(
              channel: ChannelInboxItem(
                id: 'ch_post',
                roomId: '!post:p2p-im.com',
                name: '帖子频道',
                domain: 'p2p-im.com',
                avatarUrl: '',
                latestPreview: '帖子更新',
                latestAt: null,
                unreadCount: 0,
                isOwned: false,
                channelType: asChannelTypePost,
                tags: [],
                memberCount: 18,
              ),
              showDivider: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('帖子频道'), findsOneWidget);
    expect(find.text('18 名成员'), findsNothing);
    expect(find.text('帖子更新'), findsOneWidget);
  });

  testWidgets('channel inbox list tap callback can show dissolved hint',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => ChannelInboxList(
                storageKey: const PageStorageKey('dissolved_channel_test'),
                bottomPadding: 0,
                channels: const [
                  ChannelInboxItem(
                    id: 'ch_removed',
                    roomId: '!removed:p2p-im.com',
                    name: '已解散频道',
                    domain: 'p2p-im.com',
                    avatarUrl: '',
                    latestPreview: '历史会话',
                    latestAt: null,
                    unreadCount: 0,
                    isOwned: false,
                    tags: [],
                    channelType: asChannelTypeChat,
                  ),
                ],
                onTapChannel: (channel) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('频道已解散')),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('已解散频道'));
    await tester.pump();

    expect(find.text('频道已解散'), findsOneWidget);
  });
}

class _ChannelMemberAvatarAsClient extends MockAsClient {
  _ChannelMemberAvatarAsClient(this.memberAvatarUrl);

  final String memberAvatarUrl;

  @override
  Future<List<AsChannelMember>> getChannelMembers(
    String channelId, {
    String status = '',
  }) async {
    return [
      AsChannelMember(
        channelId: channelId,
        userMxid: '@alice:p2p-im.com',
        displayName: 'Alice',
        avatarUrl: memberAvatarUrl,
        role: asChannelRoleMember,
        status: asChannelMemberStatusJoined,
        joinedAtMs: 1770000000000,
      ),
    ];
  }
}

Future<PortalAvatar> _pumpUntilPortalAvatarBytes(
  WidgetTester tester,
  Uint8List bytes,
) async {
  for (var i = 0; i < 20; i++) {
    final avatars = tester.widgetList<PortalAvatar>(find.byType(PortalAvatar));
    for (final avatar in avatars) {
      if (_sameBytes(avatar.imageBytes, bytes)) return avatar;
    }
    await tester.pump(const Duration(milliseconds: 20));
  }
  return tester.widget<PortalAvatar>(find.byType(PortalAvatar));
}

bool _sameBytes(Uint8List? actual, Uint8List expected) {
  if (actual == null || actual.length != expected.length) return false;
  for (var i = 0; i < actual.length; i++) {
    if (actual[i] != expected[i]) return false;
  }
  return true;
}

const _transparentPngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

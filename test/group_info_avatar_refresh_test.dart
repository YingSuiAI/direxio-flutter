import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/pages/group_info_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/profile_provider.dart';
import 'package:portal_app/presentation/widgets/portal_avatar.dart';

import 'support/mock_as_client.dart';

void main() {
  testWidgets('group info member avatar uses refreshed contact avatar',
      (tester) async {
    const roomId = '!group:p2p-im.com';
    const peerMxid = '@alice:p2p-im.com';
    final client = Client('GroupInfoFreshContactAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    final groupRoom = Room(
      id: roomId,
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(groupRoom);
    groupRoom.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@owner:p2p-im.com',
        stateKey: '@owner:p2p-im.com',
        content: const {'membership': 'join'},
      ),
    );
    groupRoom.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: peerMxid,
        stateKey: peerMxid,
        content: const {
          'membership': 'join',
          'displayname': 'Alice',
          'avatar_url': 'https://cdn.example.com/alice-old.png',
        },
      ),
    );
    groupRoom.setState(
      StrippedStateEvent(
        type: EventTypes.RoomName,
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: const {'name': 'Avatar Group'},
      ),
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 29),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: peerMxid,
          displayName: 'Alice',
          avatarUrl: 'https://cdn.example.com/alice-new.png',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: 'Avatar Group',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_ImmediateGroupMembersAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupInfoPage(roomId: roomId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final aliceChip = find.byKey(const ValueKey('group_info_member_$peerMxid'));
    expect(aliceChip, findsOneWidget);
    final avatar = tester.widget<PortalAvatar>(
      find.descendant(of: aliceChip, matching: find.byType(PortalAvatar)),
    );
    expect(avatar.imageUrl, 'https://cdn.example.com/alice-new.png');
  });
}

class _ImmediateGroupMembersAsClient extends MockAsClient {
  @override
  Future<List<AsGroupMember>> getGroupMembers(
    String roomId, {
    String status = '',
  }) async {
    return const [];
  }
}

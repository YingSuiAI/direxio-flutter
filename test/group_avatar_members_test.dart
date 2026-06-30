import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/utils/direct_contact_status.dart';
import 'package:portal_app/presentation/utils/group_avatar_members.dart';

void main() {
  test('uses cached member avatar urls while Matrix member avatars hydrate',
      () {
    final client = Client('GroupAvatarMembersCachedUrlsTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(
      id: '!group:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@owner:p2p-im.com',
        stateKey: '@owner:p2p-im.com',
        content: const {'membership': 'join'},
      ),
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@alice:p2p-im.com',
        stateKey: '@alice:p2p-im.com',
        content: const {'membership': 'join'},
      ),
    );

    final result = stableGroupAvatarMembersForRoom(
      room: room,
      syncCache: const AsSyncCacheState(),
      cachedMemberOrder: const [
        '@alice:p2p-im.com',
        '@owner:p2p-im.com',
      ],
      cachedMemberAvatarUrls: const {
        '@alice:p2p-im.com':
            'https://p2p-im.com/_matrix/media/v3/download/p2p-im.com/alice',
      },
    );

    expect(result.members.map((member) => member.seed), [
      '@alice:p2p-im.com',
      '@owner:p2p-im.com',
    ]);
    expect(
      result.members.first.imageUrl,
      'https://p2p-im.com/_matrix/media/v3/download/p2p-im.com/alice',
    );
    expect(result.shouldPersistAvatarUrls, isFalse);
  });

  test('uses AS group member order ahead of cached avatar order', () {
    final client = Client('GroupAvatarMembersAsOrderTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(
      id: '!group:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    for (final mxid in const [
      '@bob:p2p-im.com',
      '@owner:p2p-im.com',
      '@alice:p2p-im.com',
    ]) {
      room.setState(
        StrippedStateEvent(
          type: EventTypes.RoomMember,
          senderId: mxid,
          stateKey: mxid,
          content: const {'membership': 'join'},
        ),
      );
    }

    final result = stableGroupAvatarMembersForRoom(
      room: room,
      syncCache: const AsSyncCacheState(),
      cachedMemberOrder: const [
        '@bob:p2p-im.com',
        '@alice:p2p-im.com',
        '@owner:p2p-im.com',
      ],
      authoritativeMembers: const [
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@owner:p2p-im.com',
          role: asChannelRoleOwner,
          status: asChannelMemberStatusJoined,
        ),
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: 'https://cdn.example.com/alice.png',
          role: asChannelRoleMember,
          status: asChannelMemberStatusJoined,
        ),
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@bob:p2p-im.com',
          role: asChannelRoleMember,
          status: asChannelMemberStatusJoined,
        ),
      ],
    );

    expect(result.members.map((member) => member.seed), [
      '@owner:p2p-im.com',
      '@alice:p2p-im.com',
      '@bob:p2p-im.com',
    ]);
    expect(result.members[1].imageUrl, 'https://cdn.example.com/alice.png');
    expect(result.shouldPersistOrder, isTrue);
  });

  test('uses accepted contact avatar before stale group member avatar', () {
    final client = Client('GroupAvatarMembersFreshContactAvatarTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final groupRoom = Room(
      id: '!group:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    final directRoom = Room(
      id: '!alice:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.addAll([groupRoom, directRoom]);
    for (final mxid in const ['@owner:p2p-im.com', '@alice:p2p-im.com']) {
      groupRoom.setState(
        StrippedStateEvent(
          type: EventTypes.RoomMember,
          senderId: mxid,
          stateKey: mxid,
          content: {
            'membership': 'join',
            if (mxid == '@alice:p2p-im.com')
              'avatar_url': 'https://cdn.example.com/alice-old.png',
          },
        ),
      );
    }
    directRoom.setState(
      StrippedStateEvent(
        type: nativeRoomProfileEventType,
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: const {
          'room_type': nativeDirectRoomType,
          'requester_mxid': '@owner:p2p-im.com',
          'target_mxid': '@alice:p2p-im.com',
          'avatar_url': 'https://cdn.example.com/alice-old.png',
        },
      ),
    );
    directRoom.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@alice:p2p-im.com',
        stateKey: '@alice:p2p-im.com',
        content: const {
          'membership': 'join',
          'avatar_url': 'https://cdn.example.com/alice-old.png',
        },
      ),
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 29),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: 'https://cdn.example.com/alice-new.png',
          roomId: '!alice:p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    final result = stableGroupAvatarMembersForRoom(
      room: groupRoom,
      syncCache: AsSyncCacheState(bootstrap: bootstrap),
      cachedMemberOrder: const [],
    );

    expect(result.memberAvatarUrls['@alice:p2p-im.com'],
        'https://cdn.example.com/alice-new.png');
  });

  test('uses Matrix direct room member avatar when contact cache is missing',
      () {
    final client = Client('GroupAvatarMembersDirectRoomFallbackTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final groupRoom = Room(
      id: '!group:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    final directRoom = Room(
      id: '!alice-direct:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.addAll([groupRoom, directRoom]);
    client.accountData['m.direct'] = BasicEvent(
      type: 'm.direct',
      content: const {
        '@alice:p2p-im.com': ['!alice-direct:p2p-im.com'],
      },
    );
    for (final mxid in const ['@owner:p2p-im.com', '@alice:p2p-im.com']) {
      groupRoom.setState(
        StrippedStateEvent(
          type: EventTypes.RoomMember,
          senderId: mxid,
          stateKey: mxid,
          content: const {'membership': 'join'},
        ),
      );
    }
    directRoom.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@owner:p2p-im.com',
        stateKey: '@owner:p2p-im.com',
        content: const {'membership': 'join'},
      ),
    );
    directRoom.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@alice:p2p-im.com',
        stateKey: '@alice:p2p-im.com',
        content: const {
          'membership': 'join',
          'avatar_url': 'https://cdn.example.com/alice-direct.png',
        },
      ),
    );

    final result = stableGroupAvatarMembersForRoom(
      room: groupRoom,
      syncCache: const AsSyncCacheState(),
      cachedMemberOrder: const [],
    );

    expect(result.memberAvatarUrls['@alice:p2p-im.com'],
        'https://cdn.example.com/alice-direct.png');
  });

  test('does not reuse one fresh member avatar for cached-only members', () {
    final client = Client('GroupAvatarMembersBadDuplicateCacheTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(
      id: '!group:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    for (final mxid in const [
      '@owner:p2p-im.com',
      '@alice:p2p-im.com',
      '@bob:p2p-im.com',
      '@carol:p2p-im.com',
    ]) {
      room.setState(
        StrippedStateEvent(
          type: EventTypes.RoomMember,
          senderId: mxid,
          stateKey: mxid,
          content: {
            'membership': 'join',
            if (mxid == '@alice:p2p-im.com')
              'avatar_url': 'https://cdn.example.com/alice-new.png',
          },
        ),
      );
    }

    final result = stableGroupAvatarMembersForRoom(
      room: room,
      syncCache: const AsSyncCacheState(),
      cachedMemberOrder: const [
        '@alice:p2p-im.com',
        '@bob:p2p-im.com',
        '@carol:p2p-im.com',
      ],
      cachedMemberAvatarUrls: const {
        '@alice:p2p-im.com': 'https://cdn.example.com/alice-new.png',
        '@bob:p2p-im.com': 'https://cdn.example.com/alice-new.png',
        '@carol:p2p-im.com': 'https://cdn.example.com/alice-new.png',
      },
    );

    expect(result.memberAvatarUrls['@alice:p2p-im.com'],
        'https://cdn.example.com/alice-new.png');
    expect(result.memberAvatarUrls.containsKey('@bob:p2p-im.com'), isFalse);
    expect(result.memberAvatarUrls.containsKey('@carol:p2p-im.com'), isFalse);
    expect(
      result.members
          .where((member) =>
              member.imageUrl == 'https://cdn.example.com/alice-new.png')
          .map((member) => member.seed),
      ['@alice:p2p-im.com'],
    );
    expect(result.shouldPersistAvatarUrls, isTrue);
  });

  test('uses backend group member order for avatars', () {
    final client = Client('GroupAvatarMembersJoinedAtOrderTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(
      id: '!group:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    for (final mxid in const [
      '@bob:p2p-im.com',
      '@owner:p2p-im.com',
      '@alice:p2p-im.com',
      '@carol:p2p-im.com',
    ]) {
      room.setState(
        StrippedStateEvent(
          type: EventTypes.RoomMember,
          senderId: mxid,
          stateKey: mxid,
          content: const {'membership': 'join'},
        ),
      );
    }

    final result = stableGroupAvatarMembersForRoom(
      room: room,
      syncCache: const AsSyncCacheState(),
      cachedMemberOrder: const [],
      authoritativeMembers: const [
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@owner:p2p-im.com',
          role: asChannelRoleOwner,
          status: asChannelMemberStatusJoined,
          joinedAtMs: 400,
        ),
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@alice:p2p-im.com',
          role: asChannelRoleMember,
          status: asChannelMemberStatusJoined,
          joinedAtMs: 200,
        ),
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@bob:p2p-im.com',
          role: asChannelRoleMember,
          status: asChannelMemberStatusJoined,
          joinedAtMs: 300,
        ),
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@carol:p2p-im.com',
          role: asChannelRoleMember,
          status: asChannelMemberStatusJoined,
        ),
      ],
    );

    expect(result.members.map((member) => member.seed), [
      '@owner:p2p-im.com',
      '@alice:p2p-im.com',
      '@bob:p2p-im.com',
      '@carol:p2p-im.com',
    ]);
  });

  test('preserves backend group member order when old members lack joinedAt',
      () {
    final client = Client('GroupAvatarMembersBackendOrderTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(
      id: '!group:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    for (final mxid in const [
      '@owner:p2p-im.com',
      '@second:p2p-im.com',
      '@third:p2p-im.com',
    ]) {
      room.setState(
        StrippedStateEvent(
          type: EventTypes.RoomMember,
          senderId: mxid,
          stateKey: mxid,
          content: const {'membership': 'join'},
        ),
      );
    }

    final result = stableGroupAvatarMembersForRoom(
      room: room,
      syncCache: const AsSyncCacheState(),
      cachedMemberOrder: const [],
      authoritativeMembers: const [
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@owner:p2p-im.com',
          role: asChannelRoleOwner,
          status: asChannelMemberStatusJoined,
          joinedAtMs: 300,
        ),
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@second:p2p-im.com',
          role: asChannelRoleMember,
          status: asChannelMemberStatusJoined,
        ),
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@third:p2p-im.com',
          role: asChannelRoleMember,
          status: asChannelMemberStatusJoined,
          joinedAtMs: 400,
        ),
      ],
    );

    expect(result.members.map((member) => member.seed), [
      '@owner:p2p-im.com',
      '@second:p2p-im.com',
      '@third:p2p-im.com',
    ]);
  });

  test('ignores invited Matrix members until they join the group', () {
    final client = Client('GroupAvatarMembersJoinedOnlyTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: '!group:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@owner:p2p-im.com',
        stateKey: '@owner:p2p-im.com',
        content: const {'membership': 'join'},
      ),
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@owner:p2p-im.com',
        stateKey: '@alice:p2p-im.com',
        content: const {'membership': 'invite'},
      ),
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@owner:p2p-im.com',
        stateKey: '@bob:p2p-im.com',
        content: const {'membership': 'knock'},
      ),
    );

    final result = stableGroupAvatarMembersForRoom(
      room: room,
      syncCache: const AsSyncCacheState(),
      cachedMemberOrder: const [],
    );

    expect(result.members.map((member) => member.seed), [
      '@owner:p2p-im.com',
    ]);
  });

  test('ignores non-joined AS group members in avatar order', () {
    final client = Client('GroupAvatarMembersAsJoinedOnlyTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: '!group:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@owner:p2p-im.com',
        stateKey: '@owner:p2p-im.com',
        content: const {'membership': 'join'},
      ),
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@owner:p2p-im.com',
        stateKey: '@alice:p2p-im.com',
        content: const {'membership': 'invite'},
      ),
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@owner:p2p-im.com',
        stateKey: '@bob:p2p-im.com',
        content: const {'membership': 'knock'},
      ),
    );

    final result = stableGroupAvatarMembersForRoom(
      room: room,
      syncCache: const AsSyncCacheState(),
      cachedMemberOrder: const [],
      authoritativeMembers: const [
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@owner:p2p-im.com',
          role: asChannelRoleOwner,
          status: asChannelMemberStatusJoined,
        ),
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@alice:p2p-im.com',
          role: asChannelRoleMember,
          status: asChannelMemberStatusInvite,
        ),
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@bob:p2p-im.com',
          role: asChannelRoleMember,
          status: asChannelMemberStatusPending,
        ),
      ],
    );

    expect(result.members.map((member) => member.seed), [
      '@owner:p2p-im.com',
    ]);
  });

  test('appends joined Matrix members missing from AS group member order', () {
    final client = Client('GroupAvatarMembersAppendLiveJoinedTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: '!group:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    for (final mxid in const [
      '@owner:p2p-im.com',
      '@alice:p2p-im.com',
      '@bob:p2p-im.com',
    ]) {
      room.setState(
        StrippedStateEvent(
          type: EventTypes.RoomMember,
          senderId: '@owner:p2p-im.com',
          stateKey: mxid,
          content: const {'membership': 'join'},
        ),
      );
    }

    final result = stableGroupAvatarMembersForRoom(
      room: room,
      syncCache: const AsSyncCacheState(),
      cachedMemberOrder: const [],
      authoritativeMembers: const [
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@owner:p2p-im.com',
          role: asChannelRoleOwner,
          status: asChannelMemberStatusJoined,
        ),
      ],
    );

    expect(result.members.map((member) => member.seed), [
      '@owner:p2p-im.com',
      '@alice:p2p-im.com',
      '@bob:p2p-im.com',
    ]);
  });

  test('sorts Matrix participants by AS group member order', () {
    final client = Client('GroupParticipantsAsOrderTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: '!group:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    for (final mxid in const [
      '@bob:p2p-im.com',
      '@owner:p2p-im.com',
      '@alice:p2p-im.com',
    ]) {
      room.setState(
        StrippedStateEvent(
          type: EventTypes.RoomMember,
          senderId: mxid,
          stateKey: mxid,
          content: const {'membership': 'join'},
        ),
      );
    }

    final sorted = sortGroupParticipantsByAuthoritativeMembers(
      room.getParticipants(),
      const [
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@owner:p2p-im.com',
          role: asChannelRoleOwner,
          status: asChannelMemberStatusJoined,
        ),
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@alice:p2p-im.com',
          role: asChannelRoleMember,
          status: asChannelMemberStatusJoined,
        ),
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@bob:p2p-im.com',
          role: asChannelRoleMember,
          status: asChannelMemberStatusJoined,
        ),
      ],
    );

    expect(sorted.map((member) => member.id), [
      '@owner:p2p-im.com',
      '@alice:p2p-im.com',
      '@bob:p2p-im.com',
    ]);
  });
}

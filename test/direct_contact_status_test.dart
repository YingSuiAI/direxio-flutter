import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/utils/direct_contact_status.dart';

void main() {
  test('outgoing direct invite is not an accepted contact and cannot message',
      () {
    final room = _directRoom(peerMembership: Membership.invite);

    expect(room.directChatMatrixID, '@alice:example.com');
    expect(isAcceptedDirectContact(room), isFalse);
    expect(isPendingDirectContact(room), isTrue);
    expect(canSendDirectChatMessage(room), isFalse);
  });

  test('direct contact is accepted only after the peer joins', () {
    final room = _directRoom(peerMembership: Membership.join);

    expect(isAcceptedDirectContact(room), isTrue);
    expect(isPendingDirectContact(room), isFalse);
    expect(canSendDirectChatMessage(room), isTrue);
  });

  test('AS accepted room metadata can reveal a contact before peer state loads',
      () {
    final room = _directRoomWithoutPeerState();

    expect(isAcceptedDirectContact(room), isFalse);
    expect(
      isAcceptedDirectContact(room, acceptedRoomIds: {room.id}),
      isTrue,
    );
    expect(canSendDirectChatMessage(room, acceptedRoomIds: {room.id}), isTrue);
  });

  test('AS accepted room metadata treats missing m.direct rooms as contacts',
      () {
    final client = Client('DirexioAcceptedMetadataNoDirectTest')
      ..setUserId('@owner:example.com');
    final room = Room(
      id: '!room:example.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);

    expect(isAcceptedDirectContact(room), isFalse);
    expect(
      isAcceptedDirectContact(room, acceptedRoomIds: {room.id}),
      isTrue,
    );
  });

  test('product direct room without m.direct can be pending', () {
    final room = _productDirectRoom(peerMembership: Membership.invite);

    expect(room.isDirectChat, isFalse);
    expect(isPendingDirectContact(room), isTrue);
    expect(canSendDirectChatMessage(room), isFalse);
  });

  test('product direct invite without m.direct counts as new friend request',
      () {
    final room = _productDirectRoom(
      roomMembership: Membership.invite,
      peerMembership: Membership.join,
    );

    expect(room.isDirectChat, isFalse);
    expect(isIncomingDirectContactInvite(room), isTrue);
  });

  test('native direct profile invite counts as new friend request', () {
    final room = _nativeDirectProfileRoom(
      roomMembership: Membership.invite,
      requesterMxid: '@alice:example.com',
      targetMxid: '@owner:example.com',
    );

    expect(room.isDirectChat, isFalse);
    expect(productDirectPeerMxid(room), '@alice:example.com');
    expect(isProductDirectContactRoom(room), isTrue);
    expect(isIncomingDirectContactInvite(room), isTrue);
    expect(productDirectPeerDisplayName(room), 'Alice');
    expect(productDirectPeerAvatarUrl(room), 'mxc://example.com/alice');
    expect(productDirectPeerDomain(room), 'example.com');
  });

  test('native direct profile resolves outgoing target peer', () {
    final room = _nativeDirectProfileRoom(
      requesterMxid: '@owner:example.com',
      targetMxid: '@alice:example.com',
    );

    expect(productDirectPeerMxid(room), '@alice:example.com');
    expect(productDirectPeerDisplayName(room), isNull);
  });

  test('portal agent direct chat is messageable but not a normal contact', () {
    const agentMxid = '@agent:example.com';
    final room = _directRoom(
      peerMxid: agentMxid,
      peerMembership: Membership.invite,
    );

    expect(isAcceptedDirectContact(room, agentMxid: agentMxid), isFalse);
    expect(isPendingDirectContact(room, agentMxid: agentMxid), isFalse);
    expect(canSendDirectChatMessage(room, agentMxid: agentMxid), isTrue);
  });

  test('portal agent room can be detected from Matrix summary heroes', () {
    const agentMxid = '@agent:example.com';
    final client = Client('DirexioAgentHeroSummaryTest')
      ..setUserId('@owner:example.com');
    final room = Room(
      id: '!agent:example.com',
      client: client,
      membership: Membership.join,
      summary: RoomSummary.fromJson({
        'm.heroes': [agentMxid],
        'm.joined_member_count': 2,
        'm.invited_member_count': 0,
      }),
    );
    client.rooms.add(room);

    expect(isPortalAgentDirectRoom(room, agentMxid: agentMxid), isTrue);
    expect(isAcceptedDirectContact(room, agentMxid: agentMxid), isFalse);
    expect(canSendDirectChatMessage(room, agentMxid: agentMxid), isTrue);
  });

  test('incoming direct invite from a person counts as new friend request', () {
    final room = _directRoom(
      roomMembership: Membership.invite,
      peerMembership: Membership.join,
    );

    expect(isIncomingDirectContactInvite(room), isTrue);
  });

  test('group invite does not count as new friend request', () {
    final client = Client('DirexioGroupInviteTest')
      ..setUserId('@owner:example.com');
    final room = Room(
      id: '!group:example.com',
      client: client,
      membership: Membership.invite,
    );

    expect(isIncomingDirectContactInvite(room), isFalse);
  });

  test('portal agent invite does not count as new friend request', () {
    const agentMxid = '@agent:example.com';
    final room = _directRoom(
      roomMembership: Membership.invite,
      peerMxid: agentMxid,
      peerMembership: Membership.join,
    );

    expect(
      isIncomingDirectContactInvite(room, agentMxid: agentMxid),
      isFalse,
    );
  });
}

Room _productDirectRoom({
  String peerMxid = '@alice:example.com',
  Membership roomMembership = Membership.join,
  required Membership peerMembership,
}) {
  final client = Client('DirexioProductDirectContactTest')
    ..setUserId('@owner:example.com');
  final room = Room(
    id: '!room:example.com',
    client: client,
    membership: roomMembership,
  );

  client.rooms.add(room);
  room.setState(
    StrippedStateEvent(
      type: 'io.direxio.room.profile',
      senderId: peerMxid,
      stateKey: '',
      content: {
        'room_type': 'io.direxio.room.direct',
        'requester_mxid': client.userID,
        'target_mxid': peerMxid,
      },
    ),
  );
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: client.userID!,
      stateKey: client.userID,
      content: {'membership': roomMembership.name},
    ),
  );
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: peerMxid,
      stateKey: peerMxid,
      content: {'membership': peerMembership.name},
    ),
  );
  return room;
}

Room _nativeDirectProfileRoom({
  Membership roomMembership = Membership.join,
  required String requesterMxid,
  required String targetMxid,
}) {
  final client = Client('DirexioNativeDirectContactTest')
    ..setUserId('@owner:example.com');
  final room = Room(
    id: '!room:example.com',
    client: client,
    membership: roomMembership,
  );

  client.rooms.add(room);
  room.setState(
    StrippedStateEvent(
      type: 'io.direxio.room.profile',
      senderId: requesterMxid,
      stateKey: '',
      content: {
        'room_type': 'io.direxio.room.direct',
        'name': 'Alice',
        'visibility': 'private',
        'join_policy': 'invite',
        'invite_policy': 'owner',
        'requester_mxid': requesterMxid,
        'target_mxid': targetMxid,
        'display_name': 'Alice',
        'avatar_url': 'mxc://example.com/alice',
        'domain': 'example.com',
        'dissolved': false,
      },
    ),
  );
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: targetMxid,
      stateKey: targetMxid,
      content: {'membership': roomMembership.name},
    ),
  );
  return room;
}

Room _directRoomWithoutPeerState({
  String peerMxid = '@alice:example.com',
}) {
  final client = Client('DirexioDirectContactAcceptedMetadataTest')
    ..setUserId('@owner:example.com');
  final room = Room(
    id: '!room:example.com',
    client: client,
    membership: Membership.join,
  );

  client.rooms.add(room);
  client.accountData['m.direct'] = BasicEvent(
    type: 'm.direct',
    content: {
      peerMxid: <String>[room.id],
    },
  );
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: client.userID!,
      stateKey: client.userID,
      content: {'membership': Membership.join.name},
    ),
  );
  return room;
}

Room _directRoom({
  String peerMxid = '@alice:example.com',
  Membership roomMembership = Membership.join,
  required Membership peerMembership,
}) {
  final client = Client('DirexioDirectContactTest')
    ..setUserId('@owner:example.com');
  final room = Room(
    id: '!room:example.com',
    client: client,
    membership: roomMembership,
  );

  client.rooms.add(room);
  client.accountData['m.direct'] = BasicEvent(
    type: 'm.direct',
    content: {
      peerMxid: <String>[room.id],
    },
  );
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: client.userID!,
      stateKey: client.userID,
      content: {'membership': Membership.join.name},
    ),
  );
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: peerMxid,
      stateKey: peerMxid,
      content: {'membership': peerMembership.name},
    ),
  );
  return room;
}

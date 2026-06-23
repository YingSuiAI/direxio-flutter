import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/utils/user_profile_directory.dart';

void main() {
  test('resolves one user avatar from Matrix when AS contact avatar is empty',
      () {
    final client = Client('UserProfileDirectoryMatrixAvatarTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(
      id: '!direct:p2p-im.com',
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
          'displayname': 'Alice Matrix',
          'avatar_url': 'mxc://p2p-im.com/alice-matrix',
        },
      ),
    );

    final directory = UserProfileDirectory.fromSources(
      client: client,
      extraContacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice AS',
          avatarUrl: '',
          roomId: '!direct:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
    );

    final identity = directory.resolve(userId: '@alice:p2p-im.com');

    expect(identity.displayName, 'Alice Matrix');
    expect(identity.avatarUrl, contains('/download/p2p-im.com/alice-matrix'));
  });

  test('resolves channel member avatar by user id', () {
    final client = Client('UserProfileDirectoryChannelMemberTest')
      ..homeserver = Uri.parse('https://p2p-im.com');

    final directory = UserProfileDirectory.fromSources(
      client: client,
      extraChannelMembers: const [
        AsChannelMember(
          channelId: 'ch1',
          userMxid: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: 'https://cdn.example.com/alice.png',
          role: asChannelRoleMember,
          status: asChannelMemberStatusJoined,
        ),
      ],
    );

    expect(
      directory.avatarUrlFor('@alice:p2p-im.com'),
      'https://cdn.example.com/alice.png',
    );
    expect(
      directory.displayNameFor('@alice:p2p-im.com'),
      'Alice',
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/utils/contact_display_name.dart';

void main() {
  test('direct contact display prefers AS contact remark over Matrix member',
      () {
    final client = Client('DirectContactDisplayNameTest')
      ..setUserId('@owner:example.com');
    final room = Room(
      id: '!dm:example.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@alice:example.com',
        stateKey: '@alice:example.com',
        content: const {
          'membership': 'join',
          'displayname': 'Alice 新昵称',
        },
      ),
    );

    const contact = AsSyncContact(
      userId: '@alice:example.com',
      displayName: 'Alice 旧昵称',
      avatarUrl: '',
      roomId: '!dm:example.com',
      domain: 'example.com',
      status: 'accepted',
    );

    expect(
      directContactDisplayName(contact, room, peerMxid: '@alice:example.com'),
      'Alice 旧昵称',
    );
  });
}

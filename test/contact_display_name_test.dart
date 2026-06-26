import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/utils/agent_identity.dart';
import 'package:portal_app/presentation/utils/avatar_url.dart';
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

  test('direct peer member display does not request missing Matrix user',
      () async {
    final requestedPaths = <String>[];
    final client = Client(
      'DirectPeerMemberDisplayNoRequestTest',
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        return http.Response(
          '{}',
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )
      ..setUserId('@owner:example.com')
      ..homeserver = Uri.parse('https://example.com')
      ..accessToken = 'token';
    final room = Room(
      id: '!dm:example.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);

    expect(directPeerMemberDisplayName(room, '@missing:example.com'), '');
    await Future<void>.delayed(Duration.zero);

    expect(requestedPaths, isEmpty);
  });

  test('direct contact display fallback does not request Matrix room name',
      () async {
    final requestedPaths = <String>[];
    final client = Client(
      'DirectContactDisplayFallbackNoRequestTest',
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        return http.Response(
          '{}',
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )
      ..setUserId('@owner:example.com')
      ..homeserver = Uri.parse('https://example.com')
      ..accessToken = 'token';
    final room = Room(
      id: '!dm:example.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    room.summary.mHeroes = ['@missing:example.com'];

    expect(directContactDisplayName(null, room), '!dm:example.com');
    await Future<void>.delayed(Duration.zero);

    expect(requestedPaths, isEmpty);
  });

  test('agent display fallback does not request Matrix room name', () async {
    final requestedPaths = <String>[];
    final client = Client(
      'AgentDisplayFallbackNoRequestTest',
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        return http.Response(
          '{}',
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )
      ..setUserId('@owner:example.com')
      ..homeserver = Uri.parse('https://example.com')
      ..accessToken = 'token';
    final room = Room(
      id: '!agent:example.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    room.summary.mHeroes = ['@agent:example.com'];

    expect(agentDisplayNameForRoom(room), defaultAgentDisplayName);
    await Future<void>.delayed(Duration.zero);

    expect(requestedPaths, isEmpty);
  });

  test('local room member avatar does not request missing Matrix user',
      () async {
    final requestedPaths = <String>[];
    final client = Client(
      'LocalRoomMemberAvatarNoRequestTest',
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        return http.Response(
          '{}',
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )
      ..setUserId('@owner:example.com')
      ..homeserver = Uri.parse('https://example.com')
      ..accessToken = 'token';
    final room = Room(
      id: '!dm:example.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);

    expect(localRoomMemberAvatarHttpUrl(room, '@missing:example.com'), isNull);
    await Future<void>.delayed(Duration.zero);

    expect(requestedPaths, isEmpty);
  });
}

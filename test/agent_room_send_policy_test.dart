import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/chat/agent_room_send_policy.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';

void main() {
  test('bootstrap agent room id can send even when room looks pending direct',
      () {
    const roomId = '!agent-room:p2p-im.com';
    final client = Client('DirexioAgentRoomPolicyTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: roomId,
      client: client,
      membership: Membership.join,
      summary: RoomSummary.fromJson({
        'm.joined_member_count': 2,
        'm.invited_member_count': 0,
      }),
    );
    client.rooms.add(room);
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@agent:p2p-im.com',
        stateKey: '@agent:p2p-im.com',
        content: const {'membership': 'join'},
      ),
    );
    final syncCache = AsSyncCacheState(
      bootstrap: AsSyncBootstrap(
        syncedAt: DateTime.utc(2026, 6, 26),
        user: const AsSyncUser(userId: '@owner:p2p-im.com'),
        rooms: const [],
        contacts: const [],
        groups: const [],
        channels: const [],
        pending: const AsSyncPending.empty(),
        agentRoomId: roomId,
      ),
      localContactStatusesByRoomId: const {roomId: 'pending_outbound'},
    );

    expect(isBootstrapAgentRoom(room, syncCache), isTrue);
    expect(isProductDirectRoomForChatPolicy(room, syncCache), isTrue);
    expect(canSendPrivateRoomMessage(room, syncCache), isTrue);
  });

  test('agent slash command text is sent to Matrix unchanged', () async {
    final sentBodies = <String>[];
    final client = Client(
      'DirexioAgentSlashMatrixSendTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          sentBodies.add(body['body'] as String? ?? '');
          return http.Response(
            r'{"event_id":"$agent-question"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'matrix-token';
    final room = Room(
      id: '!agent-room:p2p-im.com',
      client: client,
      membership: Membership.join,
      summary: RoomSummary.fromJson({
        'm.joined_member_count': 2,
        'm.invited_member_count': 0,
      }),
    );
    client.rooms.add(room);

    await sendAgentRoomText(room, '/help');

    expect(sentBodies, ['/help']);
  });
}

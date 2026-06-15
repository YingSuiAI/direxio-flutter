import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/http_as_client.dart';

http.Response _jsonResponse(Map<String, dynamic> body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  test('maps loopback homeserver to local AS admin port', () {
    final base = HttpAsClient.defaultAdminBaseUri(
      Uri.parse('http://127.0.0.1:8008'),
    );

    expect(base.toString(), 'http://127.0.0.1:9090/_as');
  });

  test('maps hosted homeserver without synthetic port', () {
    final base = HttpAsClient.defaultAdminBaseUri(
      Uri.parse('https://im.jkmf.top'),
    );

    expect(base.toString(), 'https://im.jkmf.top/_as');
  });

  test('search calls AS admin API with portal bearer token', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_as/search');
        expect(request.url.queryParameters['q'], 'hello');
        expect(request.url.queryParameters['limit'], '30');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'event_id': r'$event',
                'room_id': '!room:example.com',
                'sender_name': 'Alice',
                'content': 'hello world',
                'timestamp': '2026-05-20T10:30:00Z',
              },
            ],
          }),
          200,
        );
      }),
    );

    final results = await client.search('hello', limit: 30);

    expect(results, hasLength(1));
    expect(results.single.eventId, r'$event');
    expect(results.single.roomId, '!room:example.com');
    expect(results.single.content, 'hello world');
  });

  test('updateOwnerProfile persists display name through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/_as/profile');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {'display_name': '破局'});
        return http.Response(
          jsonEncode({
            'user_id': '@owner:p2p-im.com',
            'display_name': '破局',
            'domain': 'p2p-im.com',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final profile = await client.updateOwnerProfile(displayName: '  破局  ');

    expect(profile.userId, '@owner:p2p-im.com');
    expect(profile.displayName, '破局');
    expect(profile.domain, 'p2p-im.com');
  });

  test(
    'updateAgentConfig follows AS status response with GET config',
    () async {
      final seen = <String>[];
      final client = HttpAsClient(
        baseUri: Uri.parse('https://example.com/_as'),
        portalToken: 'portal-token',
        httpClient: MockClient((request) async {
          seen.add('${request.method} ${request.url.path}');
          if (request.method == 'PUT') {
            expect(request.url.path, '/_as/agent/config');
            expect(jsonDecode(request.body), {
              'display_name': '小B',
              'context_window': 30,
            });
            return http.Response(jsonEncode({'status': 'updated'}), 200);
          }
          return http.Response(
            jsonEncode({'display_name': '小B', 'context_window': 30}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final updated = await client.updateAgentConfig(
        const AgentConfig(displayName: '小B', contextWindow: 30),
      );

      expect(seen, ['PUT /_as/agent/config', 'GET /_as/agent/config']);
      expect(updated.displayName, '小B');
      expect(updated.contextWindow, 30);
    },
  );

  test('follow mutations keep mock-compatible idempotency', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(jsonEncode({'status': 'already_followed'}), 409);
        }
        if (request.method == 'DELETE') {
          return http.Response(jsonEncode({'error': 'not found'}), 404);
        }
        return http.Response('{}', 500);
      }),
    );

    await expectLater(client.addFollow('example.org'), completes);
    await expectLater(client.removeFollow('example.org'), completes);
  });

  test('unexpected AS errors surface status code', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((_) async {
        return http.Response(jsonEncode({'error': 'M_UNKNOWN_TOKEN'}), 401);
      }),
    );

    await expectLater(
      client.getPortalStatus(),
      throwsA(
        isA<AsClientException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', 'M_UNKNOWN_TOKEN'),
      ),
    );
  });

  test('createContactRequest posts target identity to AS', () async {
    late http.Request seen;
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        seen = request;
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/contacts/requests');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'mxid': '@alice:p2p-liyanan.com',
          'display_name': 'Alice',
          'domain': 'p2p-liyanan.com',
        });
        return http.Response(
          jsonEncode({
            'peer_mxid': '@alice:p2p-liyanan.com',
            'display_name': 'Alice',
            'domain': 'p2p-liyanan.com',
            'room_id': '!alice:p2p-im.com',
            'status': 'pending_outbound',
          }),
          200,
        );
      }),
    );

    final contact = await client.createContactRequest(
      mxid: '@alice:p2p-liyanan.com',
      displayName: 'Alice',
      domain: 'p2p-liyanan.com',
    );

    expect(seen.url.path, '/_as/contacts/requests');
    expect(contact.roomId, '!alice:p2p-im.com');
    expect(contact.status, 'pending_outbound');
  });

  test('sendRoomMessage posts content through AS product route', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/rooms/!alice%3Ap2p-im.com/send');
        expect(jsonDecode(request.body), {'content': 'hello'});
        return http.Response(jsonEncode({'event_id': r'$sent'}), 200);
      }),
    );

    final eventId = await client.sendRoomMessage(
      '!alice:p2p-im.com',
      'hello',
    );

    expect(eventId, r'$sent');
  });

  test('sendRoomMessage includes reply target when present', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/rooms/!alice%3Ap2p-im.com/send');
        expect(jsonDecode(request.body), {
          'content': 'hello',
          'reply_to': r'$quoted',
        });
        return http.Response(jsonEncode({'event_id': r'$sent'}), 200);
      }),
    );

    final eventId = await client.sendRoomMessage(
      '!alice:p2p-im.com',
      'hello',
      replyToEventId: r'$quoted',
    );

    expect(eventId, r'$sent');
  });

  test('sendRoomMediaMessage posts media through AS product route', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/rooms/!alice%3Ap2p-im.com/send-media');
        expect(jsonDecode(request.body), {
          'msgtype': 'm.image',
          'body': 'avatar.png',
          'filename': 'avatar.png',
          'url': 'mxc://p2p-im.com/media',
          'mime_type': 'image/png',
          'size': 1234,
        });
        return http.Response(jsonEncode({'event_id': r'$media'}), 200);
      }),
    );

    final eventId = await client.sendRoomMediaMessage(
      roomId: '!alice:p2p-im.com',
      msgType: 'm.image',
      body: 'avatar.png',
      filename: 'avatar.png',
      mediaUrl: 'mxc://p2p-im.com/media',
      mimeType: 'image/png',
      size: 1234,
    );

    expect(eventId, r'$media');
  });

  test('sendRoomMediaMessage posts video thumbnail metadata', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/rooms/!alice%3Ap2p-im.com/send-media');
        expect(jsonDecode(request.body), {
          'msgtype': 'm.video',
          'body': 'clip.mov',
          'filename': 'clip.mov',
          'url': 'mxc://p2p-im.com/video',
          'mime_type': 'video/quicktime',
          'size': 4567,
          'thumbnail_url': 'mxc://p2p-im.com/thumb',
          'thumbnail_mime_type': 'image/jpeg',
          'thumbnail_size': 321,
          'width': 640,
          'height': 360,
          'duration_ms': 2100,
        });
        return http.Response(jsonEncode({'event_id': r'$video'}), 200);
      }),
    );

    final eventId = await client.sendRoomMediaMessage(
      roomId: '!alice:p2p-im.com',
      msgType: 'm.video',
      body: 'clip.mov',
      filename: 'clip.mov',
      mediaUrl: 'mxc://p2p-im.com/video',
      mimeType: 'video/quicktime',
      size: 4567,
      thumbnailUrl: 'mxc://p2p-im.com/thumb',
      thumbnailMimeType: 'image/jpeg',
      thumbnailSize: 321,
      width: 640,
      height: 360,
      durationMs: 2100,
    );

    expect(eventId, r'$video');
  });

  test('createCall posts call session request through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/calls');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'room_id': '!alice:p2p-im.com',
          'media_type': 'video',
          'invited_user_ids': ['@alice:p2p-liyanan.com'],
        });
        return http.Response(
          jsonEncode({
            'call_id': 'call_abc',
            'room_id': '!alice:p2p-im.com',
            'room_type': 'direct',
            'media_type': 'video',
            'created_by_mxid': '@owner:p2p-im.com',
            'invited_user_ids': ['@alice:p2p-liyanan.com'],
            'state': 'ringing',
            'created_at': '2026-05-31T10:00:00Z',
          }),
          200,
        );
      }),
    );

    final call = await client.createCall(
      roomId: '!alice:p2p-im.com',
      mediaType: 'video',
      invitedUserIds: const ['@alice:p2p-liyanan.com'],
    );

    expect(call.callId, 'call_abc');
    expect(call.roomType, 'direct');
    expect(call.mediaType, 'video');
    expect(call.invitedUserIds, ['@alice:p2p-liyanan.com']);
    expect(call.state, 'ringing');
    expect(
        call.createdAt.toUtc().toIso8601String(), '2026-05-31T10:00:00.000Z');
  });

  test('updateCallEvent posts call state transition through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/calls/call_abc/events');
        expect(jsonDecode(request.body), {
          'event': 'ended',
          'reason': 'hangup',
          'duration_ms': 42000,
        });
        return http.Response(
          jsonEncode({
            'call_id': 'call_abc',
            'room_id': '!alice:p2p-im.com',
            'room_type': 'direct',
            'media_type': 'voice',
            'created_by_mxid': '@owner:p2p-im.com',
            'state': 'ended',
            'created_at': '2026-05-31T10:00:00Z',
            'answered_at': '2026-05-31T10:00:05Z',
            'ended_at': '2026-05-31T10:00:47Z',
            'ended_by_mxid': '@owner:p2p-im.com',
            'end_reason': 'hangup',
            'duration_ms': 42000,
          }),
          200,
        );
      }),
    );

    final call = await client.updateCallEvent(
      callId: 'call_abc',
      event: 'ended',
      reason: 'hangup',
      durationMs: 42000,
    );

    expect(call.state, 'ended');
    expect(
        call.answeredAt?.toUtc().toIso8601String(), '2026-05-31T10:00:05.000Z');
    expect(call.endedAt?.toUtc().toIso8601String(), '2026-05-31T10:00:47.000Z');
    expect(call.endReason, 'hangup');
    expect(call.durationMs, 42000);
  });

  test('getCall reads call session through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_as/calls/call_abc');
        return http.Response(
          jsonEncode({
            'call_id': 'call_abc',
            'room_id': '!alice:p2p-im.com',
            'room_type': 'direct',
            'media_type': 'voice',
            'created_by_mxid': '@owner:p2p-im.com',
            'state': 'connected',
            'created_at': '2026-05-31T10:00:00Z',
            'answered_at': '2026-05-31T10:00:05Z',
          }),
          200,
        );
      }),
    );

    final call = await client.getCall('call_abc');

    expect(call.callId, 'call_abc');
    expect(call.state, 'connected');
    expect(call.answeredAt, isNotNull);
  });

  test('getActiveCalls reads active call list through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_as/calls/active');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return http.Response(
          jsonEncode({
            'calls': [
              {
                'call_id': 'call_active',
                'room_id': '!alice:p2p-im.com',
                'room_type': 'direct',
                'media_type': 'voice',
                'created_by_mxid': '@alice:p2p-liyanan.com',
                'state': 'ringing',
                'created_at': '2026-05-31T10:00:00Z',
              },
            ],
          }),
          200,
        );
      }),
    );

    final calls = await client.getActiveCalls();

    expect(calls, hasLength(1));
    expect(calls.single.callId, 'call_active');
    expect(calls.single.createdByMxid, '@alice:p2p-liyanan.com');
  });

  test('listCalls reads room call history through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_as/calls');
        expect(request.url.queryParameters['room_id'], '!group:p2p-im.com');
        expect(request.url.queryParameters['limit'], '50');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return http.Response(
          jsonEncode({
            'calls': [
              {
                'call_id': 'call_group_new',
                'room_id': '!group:p2p-im.com',
                'room_type': 'group',
                'media_type': 'video',
                'created_by_mxid': '@owner:p2p-im.com',
                'state': 'missed',
                'created_at': '2026-06-02T09:04:00Z',
                'ended_at': '2026-06-02T09:05:00Z',
              },
              {
                'call_id': 'call_group_old',
                'room_id': '!group:p2p-im.com',
                'room_type': 'group',
                'media_type': 'voice',
                'created_by_mxid': '@owner:p2p-im.com',
                'state': 'ended',
                'created_at': '2026-06-02T09:00:00Z',
                'answered_at': '2026-06-02T09:00:10Z',
                'ended_at': '2026-06-02T09:01:10Z',
                'duration_ms': 60000,
              },
            ],
          }),
          200,
        );
      }),
    );

    final calls = await client.listCalls(
      roomId: '!group:p2p-im.com',
      limit: 50,
    );

    expect(calls.map((call) => call.callId), [
      'call_group_new',
      'call_group_old',
    ]);
    expect(calls.first.mediaType, asCallMediaTypeVideo);
  });

  test('registerIncomingCall posts remote call identity through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/calls/incoming');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'call_id': 'call_remote',
          'room_id': '!alice:p2p-im.com',
          'media_type': 'video',
          'created_by_mxid': '@alice:p2p-liyanan.com',
          'created_at_ms': 1780230600000,
        });
        return http.Response(
          jsonEncode({
            'call_id': 'call_remote',
            'room_id': '!alice:p2p-im.com',
            'room_type': 'direct',
            'media_type': 'video',
            'created_by_mxid': '@alice:p2p-liyanan.com',
            'state': 'ringing',
            'created_at': '2026-05-31T12:30:00Z',
          }),
          200,
        );
      }),
    );

    final call = await client.registerIncomingCall(
      callId: 'call_remote',
      roomId: '!alice:p2p-im.com',
      mediaType: 'video',
      createdByMxid: '@alice:p2p-liyanan.com',
      createdAt: DateTime.parse('2026-05-31T12:30:00Z'),
    );

    expect(call.callId, 'call_remote');
    expect(call.mediaType, 'video');
    expect(call.state, 'ringing');
  });

  test('createGroup posts name and accepted contact invites through AS',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/groups');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'name': '产品测试群',
          'invite': ['@alice:p2p-liyanan.com'],
        });
        return http.Response(
          jsonEncode({
            'room_id': '!group:p2p-im.com',
            'name': '产品测试群',
            'member_count': 1,
            'invited_count': 1,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final group = await client.createGroup(
      name: ' 产品测试群 ',
      invite: const ['@alice:p2p-liyanan.com'],
    );

    expect(group.roomId, '!group:p2p-im.com');
    expect(group.name, '产品测试群');
    expect(group.memberCount, 1);
    expect(group.invitedCount, 1);
  });

  test('joinGroup posts invite-card context through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/groups/!group%3Ap2p-im.com/join');
        expect(jsonDecode(request.body), {
          'group_name': '产品测试群',
          'inviter_mxid': '@alice:p2p-liyanan.com',
          'invite_event_id': r'$invite',
          'direct_room_id': '!dm:p2p-im.com',
        });
        return http.Response(
          jsonEncode({
            'room_id': '!group:p2p-im.com',
            'name': '产品测试群',
            'member_count': 2,
            'role': 'member',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final group = await client.joinGroup(
      roomId: '!group:p2p-im.com',
      groupName: '产品测试群',
      inviterMxid: '@alice:p2p-liyanan.com',
      inviteEventId: r'$invite',
      directRoomId: '!dm:p2p-im.com',
    );

    expect(group.roomId, '!group:p2p-im.com');
    expect(group.role, 'member');
    expect(group.memberCount, 2);
  });

  test('inviteGroupMembers posts existing group invites through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/groups/!group%3Ap2p-im.com/invite');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'invite': ['@carol:p2p-carol.com'],
        });
        return http.Response(
          jsonEncode({
            'room_id': '!group:p2p-im.com',
            'name': '产品测试群',
            'member_count': 2,
            'invited_count': 1,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final group = await client.inviteGroupMembers(
      roomId: '!group:p2p-im.com',
      invite: const [' @carol:p2p-carol.com '],
    );

    expect(group.roomId, '!group:p2p-im.com');
    expect(group.memberCount, 2);
    expect(group.invitedCount, 1);
  });

  test('removeGroupMember posts member removal through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/_as/groups/!group%3Ap2p-im.com/members/'
          '%40carol%3Ap2p-carol.com/remove',
        );
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(request.body, isEmpty);
        return http.Response(
          jsonEncode({'room_id': '!group:p2p-im.com', 'status': 'removed'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await expectLater(
      client.removeGroupMember(
        roomId: '!group:p2p-im.com',
        peerMxid: ' @carol:p2p-carol.com ',
      ),
      completes,
    );
  });

  test('updateGroupInvitePolicy puts selected policy through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(
          request.url.path,
          '/_as/groups/!group%3Ap2p-im.com/invite-policy',
        );
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {'invite_policy': 'owner_admin'});
        return http.Response(
          jsonEncode({
            'room_id': '!group:p2p-im.com',
            'name': '产品测试群',
            'member_count': 3,
            'invite_policy': 'owner_admin',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final group = await client.updateGroupInvitePolicy(
      roomId: '!group:p2p-im.com',
      invitePolicy: 'owner_admin',
    );

    expect(group.roomId, '!group:p2p-im.com');
    expect(group.invitePolicy, 'owner_admin');
    expect(group.memberCount, 3);
  });

  test('leaveGroup posts leave through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/groups/!group%3Ap2p-im.com/leave');
        return http.Response(
          jsonEncode({'room_id': '!group:p2p-im.com', 'status': 'left'}),
          200,
        );
      }),
    );

    await expectLater(client.leaveGroup('!group:p2p-im.com'), completes);
  });

  test('favoriteMessage posts a generic favorite snapshot', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/favorites');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'room_id': '!room:p2p-im.com',
          'event_id': r'$event',
          'room_type': 'direct',
          'message_type': 'image',
          'sender_id': '@owner:p2p-im.com',
          'sender_name': 'Yanan',
          'body': 'photo.jpg',
          'url': 'mxc://p2p-im.com/photo',
          'filename': 'photo.jpg',
          'mime_type': 'image/jpeg',
          'size': 12345,
          'thumbnail_url': 'mxc://p2p-im.com/thumb',
          'thumbnail_mime_type': 'image/jpeg',
          'thumbnail_size': 1234,
          'width': 640,
          'height': 480,
          'duration_ms': 0,
          'origin_server_ts': 1779685200000,
        });
        return http.Response(
          jsonEncode({
            'id': 7,
            'owner_user_id': '@owner:p2p-im.com',
            'room_id': '!room:p2p-im.com',
            'event_id': r'$event',
            'room_type': 'direct',
            'message_type': 'image',
            'sender_id': '@owner:p2p-im.com',
            'sender_name': 'Yanan',
            'body': 'photo.jpg',
            'url': 'mxc://p2p-im.com/photo',
            'filename': 'photo.jpg',
            'mime_type': 'image/jpeg',
            'size': 12345,
            'thumbnail_url': 'mxc://p2p-im.com/thumb',
            'thumbnail_mime_type': 'image/jpeg',
            'thumbnail_size': 1234,
            'width': 640,
            'height': 480,
            'duration_ms': 0,
            'origin_server_ts': 1779685200000,
            'favorited_at': '2026-05-29T10:00:00Z',
          }),
          200,
        );
      }),
    );

    final favorite = await client.favoriteMessage(
      const AsFavoriteMessageDraft(
        roomId: '!room:p2p-im.com',
        eventId: r'$event',
        roomType: 'direct',
        messageType: 'image',
        senderId: '@owner:p2p-im.com',
        senderName: 'Yanan',
        body: 'photo.jpg',
        url: 'mxc://p2p-im.com/photo',
        filename: 'photo.jpg',
        mimeType: 'image/jpeg',
        size: 12345,
        thumbnailUrl: 'mxc://p2p-im.com/thumb',
        thumbnailMimeType: 'image/jpeg',
        thumbnailSize: 1234,
        width: 640,
        height: 480,
        originServerTs: 1779685200000,
      ),
    );

    expect(favorite.id, 7);
    expect(favorite.messageType, 'image');
    expect(favorite.url, 'mxc://p2p-im.com/photo');
  });

  test('getFavorites parses AS favorites list and optional type filter',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_as/favorites');
        expect(request.url.queryParameters['type'], 'file');
        final body = jsonEncode({
          'synced_at': '2026-05-29T10:00:00Z',
          'favorites': [
            {
              'id': 8,
              'owner_user_id': '@owner:p2p-im.com',
              'room_id': '!room:p2p-im.com',
              'event_id': r'$file',
              'room_type': 'group',
              'message_type': 'file',
              'sender_id': '@bob:p2p-im.com',
              'sender_name': 'Bob',
              'body': 'report.pdf',
              'url': 'mxc://p2p-im.com/report',
              'filename': 'report.pdf',
              'mime_type': 'application/pdf',
              'size': 4096,
              'origin_server_ts': 1779685300000,
              'favorited_at': '2026-05-29T10:01:00Z',
            },
          ],
        });
        return http.Response.bytes(
          utf8.encode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final favorites = await client.getFavorites(messageType: 'file');

    expect(favorites, hasLength(1));
    expect(favorites.single.id, 8);
    expect(favorites.single.filename, 'report.pdf');
    expect(favorites.single.favoritedAt?.toUtc().toIso8601String(),
        '2026-05-29T10:01:00.000Z');
  });

  test('getFavorites preserves chat record item snapshots', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_as/favorites');
        final body = jsonEncode({
          'synced_at': '2026-05-29T10:00:00Z',
          'favorites': [
            {
              'id': 9,
              'owner_user_id': '@owner:p2p-im.com',
              'room_id': '!room:p2p-im.com',
              'event_id': r'$record',
              'room_type': 'direct',
              'message_type': 'chat_record',
              'sender_id': '@alice:p2p-liyanan.com',
              'sender_name': 'Alice',
              'body': '与 Alice 的聊天记录',
              'origin_server_ts': 1779685300000,
              'favorited_at': '2026-05-29T10:01:00Z',
              'chat_record': jsonEncode({
                'title': '与 Alice 的聊天记录',
                'source_room_id': '!source:p2p-im.com',
                'source_room_type': 'direct',
                'item_count': 2,
                'items': [
                  {
                    'sender_name': 'Alice',
                    'body': '第一条',
                    'message_type': 'm.text',
                    'origin_server_ts': 1779685200000,
                  },
                  {
                    'sender_name': 'Yanan',
                    'body': '第二条',
                    'message_type': 'm.text',
                    'origin_server_ts': 1779685300000,
                  },
                ],
              }),
            },
            {
              'id': 10,
              'owner_user_id': '@owner:p2p-im.com',
              'room_id': '!room:p2p-im.com',
              'event_id': r'$old-record',
              'room_type': 'direct',
              'message_type': 'chat_record',
              'sender_id': '@alice:p2p-liyanan.com',
              'sender_name': 'Alice',
              'body': '与 Alice 的聊天记录',
              'origin_server_ts': 1779685400000,
              'favorited_at': '2026-05-29T10:02:00Z',
              'chat_record_json': jsonEncode({
                'title': '与 Alice 的聊天记录',
                'source_room_id': '!source:p2p-im.com',
                'source_room_type': 'direct',
                'item_count': 1,
                'items': [
                  {
                    'sender_name': 'Alice',
                    'body': '旧字段也要显示',
                    'message_type': 'm.text',
                    'origin_server_ts': 1779685400000,
                  },
                ],
              }),
            },
          ],
        });
        return http.Response.bytes(
          utf8.encode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final favorites = await client.getFavorites();

    expect(favorites, hasLength(2));
    expect((favorites[0].chatRecord['items'] as List), hasLength(2));
    expect((favorites[0].chatRecord['items'] as List).first['body'], '第一条');
    expect((favorites[1].chatRecord['items'] as List).first['body'], '旧字段也要显示');
  });

  test('deleteFavorite deletes by id through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/_as/favorites/7');
        return http.Response(jsonEncode({'id': 7, 'deleted': true}), 200);
      }),
    );

    await expectLater(client.deleteFavorite(7), completes);
  });

  test('sendChatRecordMessage posts chat record metadata through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/rooms/!room%3Ap2p-im.com/send');
        expect(jsonDecode(request.body), {
          'content': '聊天记录\n与 Alice 的聊天记录\n共 1 条消息',
          'message_type': 'chat_record',
          'chat_record': {
            'title': '与 Alice 的聊天记录',
            'source_room_id': '!alice:p2p-im.com',
            'source_room_type': 'direct',
            'item_count': 1,
            'items': [
              {
                'sender_name': 'Alice',
                'body': '第一条',
                'message_type': 'text',
                'origin_server_ts': 1779685200000,
              },
            ],
          },
        });
        return http.Response(jsonEncode({'event_id': r'$record'}), 200);
      }),
    );

    final eventId = await client.sendChatRecordMessage(
      roomId: '!room:p2p-im.com',
      body: '聊天记录\n与 Alice 的聊天记录\n共 1 条消息',
      title: '与 Alice 的聊天记录',
      sourceRoomId: '!alice:p2p-im.com',
      sourceRoomType: 'direct',
      itemCount: 1,
      items: const [
        {
          'sender_name': 'Alice',
          'body': '第一条',
          'message_type': 'text',
          'origin_server_ts': 1779685200000,
        },
      ],
    );

    expect(eventId, r'$record');
  });

  test('sendChannelShareMessage posts channel metadata through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/rooms/!room%3Ap2p-im.com/send');
        expect(jsonDecode(request.body), {
          'content': '频道分享\n产品公告',
          'message_type': 'channel_share',
          'channel_share': {
            'channel_id': 'ch_product',
            'room_id': '!channel:p2p-im.com',
            'home_domain': 'p2p-im.com',
            'name': '产品公告',
            'description': '只发布重要产品更新',
            'visibility': 'public',
            'join_policy': 'open',
            'comments_enabled': true,
            'tags': ['产品'],
          },
        });
        return http.Response(jsonEncode({'event_id': r'$share'}), 200);
      }),
    );

    final eventId = await client.sendChannelShareMessage(
      roomId: '!room:p2p-im.com',
      body: '频道分享\n产品公告',
      channel: const AsChannelShareDraft(
        channelId: 'ch_product',
        roomId: '!channel:p2p-im.com',
        homeDomain: 'p2p-im.com',
        name: '产品公告',
        description: '只发布重要产品更新',
        tags: ['产品'],
      ),
    );

    expect(eventId, r'$share');
  });

  test('deleteContact removes a contact through AS product route', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/_as/contacts/!alice%3Ap2p-im.com');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return http.Response(
          jsonEncode({
            'peer_mxid': '@alice:p2p-liyanan.com',
            'display_name': 'Alice',
            'domain': 'p2p-liyanan.com',
            'room_id': '!alice:p2p-im.com',
            'status': 'rejected',
          }),
          200,
        );
      }),
    );

    final contact = await client.deleteContact('!alice:p2p-im.com');

    expect(contact.roomId, '!alice:p2p-im.com');
    expect(contact.status, 'rejected');
  });

  test('portal status treats AS connected session label as healthy', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'dendrite': 'connected',
            'federation': 'ok',
            'agent': 'connected (1 sessions)',
            'uptime': '3h',
          }),
          200,
        );
      }),
    );

    final status = await client.getPortalStatus();

    expect(status.agent, 'connected (1 sessions)');
    expect(status.allHealthy, isTrue);
  });

  test('changePortalPassword posts token payload to AS admin API', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'admin-token',
      matrixAccessTokenForDebug: 'matrix-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/_as/portal/password');
        expect(request.headers['Authorization'], 'Bearer admin-token');
        expect(jsonDecode(request.body), {
          'admin_access_token': 'admin-token',
          'matrix_access_token': 'matrix-token',
          'password': '22222222',
        });
        return http.Response(
          jsonEncode({
            'matrix_access_token': 'new-matrix-token',
            'admin_access_token': 'new-admin-token',
            'user_id': '@owner:example.com',
            'homeserver': 'https://example.com',
            'device_id': 'DEVICE2',
          }),
          200,
        );
      }),
    );

    final session = await client.changePortalPassword(
      oldPassword: '11111111',
      newPassword: '22222222',
    );

    expect(session.matrixAccessToken, 'new-matrix-token');
    expect(session.adminAccessToken, 'new-admin-token');
    expect(session.deviceId, 'DEVICE2');
  });

  test('createChannel posts channel metadata to AS admin API', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/channels');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'name': '产品公告',
          'description': '只发布重要产品更新',
          'visibility': 'public',
          'join_policy': 'open',
          'comments_enabled': true,
          'tags': ['产品', '公告'],
        });
        return _jsonResponse(
          {
            'channel_id': 'ch1',
            'room_id': '!channel:example.com',
            'home_domain': 'example.com',
            'name': '产品公告',
            'description': '只发布重要产品更新',
            'visibility': 'public',
            'join_policy': 'open',
            'comments_enabled': true,
            'role': 'owner',
            'member_status': 'joined',
            'tags': ['产品', '公告'],
          },
          200,
        );
      }),
    );

    final channel = await client.createChannel(
      name: '产品公告',
      description: '只发布重要产品更新',
      tags: const ['产品', '公告'],
    );

    expect(channel.channelId, 'ch1');
    expect(channel.roomId, '!channel:example.com');
    expect(channel.role, 'owner');
  });

  test('searchPublicChannels calls public discovery endpoint without auth',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_as/public/channels/search');
        expect(request.url.queryParameters['q'], '产品');
        expect(request.url.queryParameters['limit'], '20');
        expect(request.headers['Authorization'], isNull);
        return _jsonResponse(
          {
            'results': [
              {
                'channel_id': 'ch1',
                'room_id': '!channel:example.com',
                'home_domain': 'example.com',
                'name': '产品公告',
                'visibility': 'public',
                'join_policy': 'open',
                'comments_enabled': true,
                'tags': ['产品'],
              },
            ],
          },
          200,
        );
      }),
    );

    final results = await client.searchPublicChannels('产品');

    expect(results.single.channelId, 'ch1');
    expect(results.single.joinPolicy, 'open');
  });

  test('joinChannel returns pending for approval channel', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/channels/ch1/join');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return _jsonResponse(
          {
            'status': 'pending',
            'channel': {
              'channel_id': 'ch1',
              'room_id': '!channel:example.com',
              'home_domain': 'example.com',
              'name': '审核频道',
              'visibility': 'public',
              'join_policy': 'approval',
              'comments_enabled': true,
              'member_status': 'pending',
            },
          },
          200,
        );
      }),
    );

    final channel = await client.joinChannel('ch1');

    expect(channel.memberStatus, 'pending');
    expect(channel.joinPolicy, 'approval');
  });

  test('joinChannel sends discovered remote channel metadata', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/channels/ch_remote/join');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'room_id': '!remote:p2p-im.com',
          'home_domain': 'p2p-im.com',
          'name': '远端公开频道',
          'description': '跨节点发现',
          'visibility': 'public',
          'join_policy': 'open',
          'comments_enabled': true,
          'tags': ['产品'],
        });
        return _jsonResponse(
          {
            'status': 'joined',
            'channel': {
              'channel_id': 'ch_remote',
              'room_id': '!remote:p2p-im.com',
              'home_domain': 'p2p-im.com',
              'name': '远端公开频道',
              'description': '跨节点发现',
              'visibility': 'public',
              'join_policy': 'open',
              'comments_enabled': true,
              'member_status': 'joined',
            },
          },
          200,
        );
      }),
    );

    final channel = await client.joinChannel(
      'ch_remote',
      discoveredChannel: const AsChannel(
        channelId: 'ch_remote',
        roomId: '!remote:p2p-im.com',
        homeDomain: 'p2p-im.com',
        name: '远端公开频道',
        description: '跨节点发现',
        visibility: asChannelVisibilityPublic,
        joinPolicy: asChannelJoinPolicyOpen,
        commentsEnabled: true,
        tags: ['产品'],
      ),
    );

    expect(channel.memberStatus, 'joined');
  });

  test('getChannelMembers reads pending approval requests', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_as/channels/ch1/members');
        expect(request.url.queryParameters['status'], 'pending');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return _jsonResponse(
          {
            'members': [
              {
                'channel_id': 'ch1',
                'user_mxid': '@alice:p2p-liyanan.com',
                'domain': 'p2p-liyanan.com',
                'display_name': 'Alice',
                'role': 'member',
                'status': 'pending',
              },
            ],
          },
          200,
        );
      }),
    );

    final members = await client.getChannelMembers(
      'ch1',
      status: asChannelMemberStatusPending,
    );

    expect(members.single.userMxid, '@alice:p2p-liyanan.com');
    expect(members.single.displayName, 'Alice');
    expect(members.single.status, asChannelMemberStatusPending);
  });

  test('approveChannelJoin posts approval action to AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/_as/channels/ch1/join-requests/%40alice%3Ap2p-liyanan.com/approve',
        );
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return _jsonResponse(
          {
            'status': 'joined',
            'channel': {
              'channel_id': 'ch1',
              'room_id': '!channel:example.com',
              'name': '审核频道',
              'visibility': 'public',
              'join_policy': 'approval',
              'comments_enabled': true,
              'pending_join_count': 0,
            },
          },
          200,
        );
      }),
    );

    final channel = await client.approveChannelJoin(
      'ch1',
      '@alice:p2p-liyanan.com',
    );

    expect(channel.channelId, 'ch1');
    expect(channel.pendingJoinCount, 0);
  });

  test('createChannelPost posts text and media metadata', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/channels/ch1/posts');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['message_type'], 'image');
        expect(body['body'], '图片说明');
        expect(
            jsonDecode(body['media_json'] as String), {'mxc': 'mxc://image'});
        return _jsonResponse(
          {
            'post_id': 'post1',
            'channel_id': 'ch1',
            'room_id': '!channel:example.com',
            'event_id': r'$post1',
            'author_mxid': '@owner:example.com',
            'body': '图片说明',
            'message_type': 'image',
            'media_json': '{"mxc":"mxc://image"}',
            'origin_server_ts': 1780730000000,
            'comment_count': 0,
          },
          200,
        );
      }),
    );

    final post = await client.createChannelPost(
      'ch1',
      messageType: 'image',
      body: '图片说明',
      media: const {'mxc': 'mxc://image'},
    );

    expect(post.postId, 'post1');
    expect(post.media['mxc'], 'mxc://image');
  });

  test('createChannelComment posts to target post id', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/channels/ch1/posts/post1/comments');
        expect(jsonDecode(request.body), {
          'message_type': 'text',
          'body': '收到',
        });
        return _jsonResponse(
          {
            'comment_id': 'comment1',
            'post_id': 'post1',
            'channel_id': 'ch1',
            'event_id': r'$comment1',
            'author_mxid': '@owner:example.com',
            'body': '收到',
            'message_type': 'text',
            'origin_server_ts': 1780730000000,
          },
          200,
        );
      }),
    );

    final comment = await client.createChannelComment(
      'ch1',
      'post1',
      messageType: 'text',
      body: '收到',
    );

    expect(comment.commentId, 'comment1');
    expect(comment.postId, 'post1');
  });

  test('toggleChannelPostReaction posts current reaction state', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/channels/ch1/posts/post1/reactions');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {'reaction': 'like'});
        return _jsonResponse(
          {
            'post_id': 'post1',
            'channel_id': 'ch1',
            'reaction': 'like',
            'active': true,
            'reaction_count': 3,
          },
          200,
        );
      }),
    );

    final reaction = await client.toggleChannelPostReaction(
      'ch1',
      'post1',
      reaction: 'like',
    );

    expect(reaction.active, isTrue);
    expect(reaction.reactionCount, 3);
  });

  test('getMyChannelReactions parses channel reaction history', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_as/channels/me/reactions');
        expect(request.url.queryParameters['limit'], '25');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return _jsonResponse(
          {
            'reactions': [
              {
                'post_id': 'post1',
                'channel_id': 'ch1',
                'reaction': 'like',
                'origin_server_ts': 1780730300000,
                'channel': {
                  'channel_id': 'ch1',
                  'room_id': '!channel:example.com',
                  'name': '产品公告',
                },
                'post': {
                  'post_id': 'post1',
                  'channel_id': 'ch1',
                  'room_id': '!channel:example.com',
                  'event_id': r'$post1',
                  'author_mxid': '@owner:example.com',
                  'author_name': 'Yanan',
                  'message_type': 'text',
                  'body': '频道帖子',
                  'origin_server_ts': 1780730000000,
                },
              },
            ],
          },
          200,
        );
      }),
    );

    final reactions = await client.getMyChannelReactions(limit: 25);

    expect(reactions, hasLength(1));
    expect(reactions.single.channel.name, '产品公告');
    expect(reactions.single.post.authorName, 'Yanan');
    expect(reactions.single.post.body, '频道帖子');
  });

  test('getMyChannelComments parses channel comment history', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_as/channels/me/comments');
        expect(request.url.queryParameters['limit'], '15');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return _jsonResponse(
          {
            'comments': [
              {
                'comment': {
                  'comment_id': 'comment1',
                  'post_id': 'post1',
                  'channel_id': 'ch1',
                  'event_id': r'$comment1',
                  'author_mxid': '@owner:example.com',
                  'author_name': 'Yanan',
                  'author_domain': 'example.com',
                  'message_type': 'text',
                  'body': '评论内容',
                  'origin_server_ts': 1780730400000,
                },
                'channel': {
                  'channel_id': 'ch1',
                  'room_id': '!channel:example.com',
                  'name': '产品公告',
                },
                'post': {
                  'post_id': 'post1',
                  'channel_id': 'ch1',
                  'room_id': '!channel:example.com',
                  'event_id': r'$post1',
                  'author_mxid': '@owner:example.com',
                  'author_name': 'Yanan',
                  'message_type': 'text',
                  'body': '频道帖子',
                  'origin_server_ts': 1780730000000,
                },
              },
            ],
          },
          200,
        );
      }),
    );

    final comments = await client.getMyChannelComments(limit: 15);

    expect(comments, hasLength(1));
    expect(comments.single.comment.authorName, 'Yanan');
    expect(comments.single.comment.authorDomain, 'example.com');
    expect(comments.single.channel.name, '产品公告');
    expect(comments.single.post.body, '频道帖子');
  });

  test('updateChannelReadMarker uses channel read marker API', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/_as/channels/ch1/read-marker');
        expect(jsonDecode(request.body), {
          'event_id': r'$post1',
          'origin_server_ts': 1780730000000,
        });
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }),
    );

    await client.updateChannelReadMarker(
      'ch1',
      eventId: r'$post1',
      originServerTs: 1780730000000,
    );
  });

  test('updateReadMarker sends room and event id to sync API', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/_as/sync/read-marker');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'room_id': '!room:example.com',
          'event_id': r'$event',
          'origin_server_ts': 1779704400000,
        });
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }),
    );

    await expectLater(
      client.updateReadMarker(
        '!room:example.com',
        r'$event',
        DateTime.parse('2026-05-25T10:20:00Z'),
      ),
      completes,
    );
  });

  test('syncBootstrap parses metadata without message bodies', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_as/sync/bootstrap');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return http.Response(
          jsonEncode({
            'synced_at': '2026-05-25T10:00:00Z',
            'user': {'user_id': '@owner:example.com'},
            'contacts': [
              {
                'user_id': '@alice:p2p-liyanan.com',
                'display_name': 'Alice',
                'avatar_url': 'mxc://example.com/alice',
                'room_id': '!dm:example.com',
                'domain': 'p2p-liyanan.com',
                'status': 'accepted',
                'visible_after_ts': 1770000000123,
              }
            ],
            'groups': [],
            'channels': [],
            'pending': {
              'friend_requests': [],
              'group_invites': [],
              'channel_notices': [],
            },
            'rooms': [
              {
                'room_id': '!room:example.com',
                'name': 'Alice',
                'avatar_url': 'mxc://example.com/avatar',
                'unread_count': 2,
                'last_activity_at': '2026-05-25T09:59:00Z',
              }
            ],
          }),
          200,
        );
      }),
    );

    final bootstrap = await client.syncBootstrap();

    expect(bootstrap.user.userId, '@owner:example.com');
    expect(bootstrap.rooms.single.roomId, '!room:example.com');
    expect(bootstrap.rooms.single.name, 'Alice');
    expect(bootstrap.rooms.single.unreadCount, 2);
    expect(bootstrap.rooms.single.lastActivityAt?.toUtc().toIso8601String(),
        '2026-05-25T09:59:00.000Z');
    expect(bootstrap.contacts.single.userId, '@alice:p2p-liyanan.com');
    expect(bootstrap.contacts.single.roomId, '!dm:example.com');
    expect(bootstrap.contacts.single.domain, 'p2p-liyanan.com');
    expect(bootstrap.contacts.single.status, 'accepted');
    expect(bootstrap.contacts.single.visibleAfterTs, 1770000000123);
  });

  test('syncUnread requests unread-only recovery with limit', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_as/sync/unread');
        expect(request.url.queryParameters['limit_per_room'], '20');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return http.Response(
          jsonEncode({
            'synced_at': '2026-05-25T10:00:00Z',
            'rooms': [
              {
                'room_id': '!room:example.com',
                'messages': [
                  {
                    'event_id': r'$unread',
                    'sender_id': '@alice:example.com',
                    'sender_name': 'Alice',
                    'content': 'offline unread',
                    'message_type': 'text',
                    'timestamp': '2026-05-25T09:58:00Z',
                  }
                ],
              }
            ],
          }),
          200,
        );
      }),
    );

    final unread = await client.syncUnread(limitPerRoom: 20);

    expect(unread.rooms.single.roomId, '!room:example.com');
    expect(unread.rooms.single.messages.single.eventId, r'$unread');
    expect(unread.rooms.single.messages.single.content, 'offline unread');
  });

  test('deleteRoomMessage uses AS private visibility endpoint', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/_as/rooms/!room%3Aexample.com/messages/delete',
        );
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {'event_id': r'$event/with/slash'});
        return http.Response(
          jsonEncode({
            'room_id': '!room:example.com',
            'event_id': r'$event/with/slash',
          }),
          200,
        );
      }),
    );

    await expectLater(
      client.deleteRoomMessage(
        roomId: '!room:example.com',
        eventId: r'$event/with/slash',
      ),
      completes,
    );
  });

  test('authenticatePortal posts password to auth', () async {
    final session = await HttpAsClient.authenticatePortal(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: '11111111',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/auth');
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {'password': '11111111'});
        return http.Response(
          jsonEncode({
            'matrix_access_token': 'matrix-access-token',
            'admin_access_token': 'admin-access-token',
            'user_id': '@owner:example.com',
            'homeserver': 'https://example.com',
            'agent_room_id': '!agent:example.com',
          }),
          200,
        );
      }),
    );

    expect(session.matrixAccessToken, 'matrix-access-token');
    expect(session.adminAccessToken, 'admin-access-token');
    expect(session.userId, '@owner:example.com');
    expect(session.homeserver, 'https://example.com');
    expect(session.deviceId, isNull);
    expect(session.agentRoomId, '!agent:example.com');
  });

  test('bootstrapPortal posts setup code to bootstrap', () async {
    final session = await HttpAsClient.bootstrapPortal(
      baseUri: Uri.parse('https://example.com/_as'),
      setupCode: 'setup-code',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/bootstrap');
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {'token': 'setup-code'});
        return http.Response(
          jsonEncode({
            'matrix_access_token': 'bootstrapped-matrix-token',
            'admin_access_token': 'bootstrapped-admin-token',
            'user_id': '@owner:example.com',
            'homeserver': 'https://example.com',
          }),
          200,
        );
      }),
    );

    expect(session.matrixAccessToken, 'bootstrapped-matrix-token');
    expect(session.adminAccessToken, 'bootstrapped-admin-token');
  });
}

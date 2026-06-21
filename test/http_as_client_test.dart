import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/http_as_client.dart';
import 'package:portal_app/data/local_endpoint_resolver.dart';

http.Response _jsonResponse(Map<String, dynamic> body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  test('maps loopback homeserver to local P2P API port', () {
    final base = HttpAsClient.defaultAdminBaseUri(
      Uri.parse('http://127.0.0.1:8008'),
    );

    expect(base.toString(), 'http://127.0.0.1:8008/_p2p');
  });

  test('maps hosted homeserver to integrated P2P API', () {
    final base = HttpAsClient.defaultAdminBaseUri(
      Uri.parse('https://im.jkmf.top'),
    );

    expect(base.toString(), 'https://im.jkmf.top/_p2p');
  });

  test('maps configured local endpoints to reachable P2P API ports', () {
    final endpoints = LocalEndpointResolver.parse(
      'node-a.test=127.0.0.1:18008,node-c.test=127.0.0.1:38008',
    );
    final base = HttpAsClient.defaultAdminBaseUri(
      Uri.parse('https://node-a.test'),
      localEndpointResolver: endpoints,
    );
    final cBase = HttpAsClient.defaultAdminBaseUri(
      Uri.parse('https://node-c.test'),
      localEndpointResolver: endpoints,
    );

    expect(base.toString(), 'http://127.0.0.1:18008/_p2p');
    expect(cBase.toString(), 'http://127.0.0.1:38008/_p2p');
  });

  test('listConversations uses unified conversations query action', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/query');
        expect(jsonDecode(request.body), {
          'action': 'conversations.list',
          'params': <String, Object?>{},
        });
        return http.Response(
          jsonEncode({
            'conversations': [
              {
                'conversation_id': 'conv_1',
                'matrix_room_id': '!dm:p2p-im.com',
                'kind': 'direct',
                'lifecycle': 'active',
                'peer_mxid': '@alice:p2p-im.com',
                'title': 'Alice',
                'avatar_url': 'mxc://avatar',
                'last_event_id': r'$event',
                'last_activity_at': 1781942406000,
                'projection_state': 'ready',
                'member_count': 2,
                'membership': 'join',
                'relationship_status': 'accepted',
                'role': 'member',
                'hydration_state': 'ready',
                'capabilities': {
                  'open': true,
                  'send': true,
                  'invite': false,
                  'manage_members': false,
                },
              }
            ],
          }),
          200,
        );
      }),
    );

    final conversations = await client.listConversations();

    expect(conversations, hasLength(1));
    expect(conversations.single.roomId, '!dm:p2p-im.com');
    expect(conversations.single.kind, asConversationKindDirect);
    expect(conversations.single.peerMxid, '@alice:p2p-im.com');
    expect(conversations.single.title, 'Alice');
    expect(conversations.single.memberCount, 2);
    expect(conversations.single.membership, 'join');
    expect(conversations.single.relationshipStatus, 'accepted');
    expect(conversations.single.role, 'member');
    expect(conversations.single.hydrationState, 'ready');
    expect(conversations.single.canOpen, isTrue);
    expect(conversations.single.canSend, isTrue);
    expect(conversations.single.canInvite, isFalse);
    expect(conversations.single.canManageMembers, isFalse);
    expect(
      conversations.single.lastActivityAt,
      DateTime.fromMillisecondsSinceEpoch(1781942406000, isUtc: true),
    );
  });

  test('changePortalPassword uses unified portal password action', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(jsonDecode(request.body), {
          'action': 'portal.password',
          'params': {
            'old_password': 'old-secret',
            'new_password': 'new-secret',
            'device_id': 'DEVICE1',
          },
        });
        return http.Response(
          jsonEncode({
            'access_token': 'access-token',
            'initialized': true,
            'password_initialized': true,
            'profile_initialized': true,
            'account_initialized': true,
            'setup_completed': true,
            'already_initialized': true,
          }),
          200,
        );
      }),
    );

    final session = await client.changePortalPassword(
      oldPassword: 'old-secret',
      newPassword: 'new-secret',
      deviceId: 'DEVICE1',
    );

    expect(session.accessToken, 'access-token');
    expect(session.initialized, isTrue);
    expect(session.passwordInitialized, isTrue);
    expect(session.alreadyInitialized, isTrue);
    expect(session.profileInitialized, isTrue);
    expect(session.accountInitialized, isTrue);
    expect(session.setupCompleted, isTrue);
  });

  test('deleteFavorite uses unified favorite delete action', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(jsonDecode(request.body), {
          'action': 'favorites.delete',
          'params': {'id': '7'},
        });
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }),
    );

    await expectLater(client.deleteFavorite(7), completes);
  });

  test('deleteContact uses unified contact delete action', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(jsonDecode(request.body), {
          'action': 'contacts.delete',
          'params': {'room_id': '!alice:p2p-im.com'},
        });
        return http.Response(
          jsonEncode({
            'peer_mxid': '@alice:p2p-im.com',
            'room_id': '!alice:p2p-im.com',
            'status': 'deleted',
          }),
          200,
        );
      }),
    );

    final contact = await client.deleteContact('!alice:p2p-im.com');

    expect(contact.roomId, '!alice:p2p-im.com');
    expect(contact.status, 'deleted');
  });

  test('updateContact uses unified contact update action', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(jsonDecode(request.body), {
          'action': 'contacts.update',
          'params': {
            'room_id': '!alice:p2p-im.com',
            'display_name': 'Alice Remark',
            'domain': 'p2p-im.com',
          },
        });
        return http.Response(
          jsonEncode({
            'peer_mxid': '@alice:p2p-im.com',
            'display_name': 'Alice Remark',
            'domain': 'p2p-im.com',
            'room_id': '!alice:p2p-im.com',
            'status': 'accepted',
          }),
          200,
        );
      }),
    );

    final contact = await client.updateContact(
      roomId: '!alice:p2p-im.com',
      displayName: '  Alice Remark  ',
      domain: 'p2p-im.com',
    );

    expect(contact.displayName, 'Alice Remark');
    expect(contact.status, 'accepted');
  });

  test('agent management helpers use unified API actions', () async {
    final seen = <String>[];
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        seen.add(request.body);
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        switch (body['action']) {
          case 'agent.password':
            expect(request.url.path, '/_p2p/query');
            return http.Response(jsonEncode({'password': 'secret'}), 200);
          case 'apis.list':
            expect(request.url.path, '/_p2p/query');
            return http.Response(
              jsonEncode({
                'items': [
                  {'action': 'contacts.request', 'enabled': true},
                ],
              }),
              200,
            );
          case 'apis.status':
            expect(request.url.path, '/_p2p/command');
            expect(body['params'], {
              'items': [
                {'action': 'contacts.request', 'enabled': false},
              ],
            });
            return http.Response(
              jsonEncode({
                'items': [
                  {'action': 'contacts.request', 'enabled': false},
                ],
              }),
              200,
            );
          default:
            fail('unexpected action ${body['action']}');
        }
      }),
    );

    expect((await client.getAgentPassword())['password'], 'secret');
    expect((await client.listApiPermissions())['items'], isNotEmpty);
    final updated = await client.updateApiPermissionStatus([
      {'action': 'contacts.request', 'enabled': false},
    ]);

    expect(updated['items'], isNotEmpty);
    expect(seen, hasLength(3));
  });

  test('maps legacy channel intro field to description', () {
    final summary = AsSyncRoomSummary.fromJson({
      'channel_id': 'ch_intro',
      'room_id': '!intro:p2p-im.com',
      'name': '产品公告',
      'avatar_url': '',
      'unread_count': 0,
      'intro': '频道介绍字段',
    });
    final channel = AsChannel.fromJson({
      'channel_id': 'ch_intro',
      'room_id': '!intro:p2p-im.com',
      'name': '产品公告',
      'intro': '频道介绍字段',
    });

    expect(summary.description, '频道介绍字段');
    expect(channel.description, '频道介绍字段');
  });

  test('AS M_UNKNOWN_TOKEN refreshes token and retries once', () async {
    final authorizations = <String>[];
    var refreshCount = 0;
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'old-access-token',
      onAuthenticationRefresh: () {
        refreshCount++;
        return 'new-access-token';
      },
      httpClient: MockClient((request) async {
        authorizations.add(request.headers['Authorization'] ?? '');
        if (request.headers['Authorization'] == 'Bearer old-access-token') {
          return _jsonResponse({'error': 'M_UNKNOWN_TOKEN'}, 401);
        }
        expect(request.headers['Authorization'], 'Bearer new-access-token');
        expect(jsonDecode(request.body)['action'], 'sync.bootstrap');
        return _jsonResponse(
          {
            'synced_at': '2026-06-20T00:00:00Z',
            'user': {'user_id': '@owner:example.com'},
            'rooms': [],
            'contacts': [],
            'groups': [],
            'channels': [],
            'pending': {},
          },
          200,
        );
      }),
    );

    final bootstrap = await client.syncBootstrap();

    expect(bootstrap.user.userId, '@owner:example.com');
    expect(refreshCount, 1);
    expect(authorizations, [
      'Bearer old-access-token',
      'Bearer new-access-token',
    ]);
  });

  test('AS M_UNKNOWN_TOKEN invokes session expiration callback', () async {
    var expired = false;
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'bad-token',
      onAuthenticationFailed: () {
        expired = true;
      },
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer bad-token');
        return _jsonResponse({'error': 'M_UNKNOWN_TOKEN'}, 401);
      }),
    );

    await expectLater(
      client.getOwnerProfile(),
      throwsA(
        isA<AsClientException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(expired, isTrue);
  });

  test('AS non-M_UNKNOWN_TOKEN 401 does not expire session', () async {
    var expired = false;
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'bad-token',
      onAuthenticationFailed: () {
        expired = true;
      },
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer bad-token');
        return _jsonResponse({'error': 'invalid token'}, 401);
      }),
    );

    await expectLater(
      client.getOwnerProfile(),
      throwsA(
        isA<AsClientException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.message, 'message', 'invalid token'),
      ),
    );
    expect(expired, isFalse);
  });

  test('AS business 403 does not expire session', () async {
    var expired = false;
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      onAuthenticationFailed: () {
        expired = true;
      },
      httpClient: MockClient((request) async {
        return _jsonResponse({'error': 'room is not callable'}, 403);
      }),
    );

    await expectLater(
      client.getOwnerProfile(),
      throwsA(
        isA<AsClientException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having(
              (error) => error.message,
              'message',
              'room is not callable',
            ),
      ),
    );
    expect(expired, isFalse);
  });

  test('updateOwnerProfile persists profile fields through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/_as/profile');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'display_name': '破局',
          'avatar_url': 'mxc://p2p-im.com/avatar',
          'gender': 'female',
          'birthday': '1990-01-02',
          'phone': '13800000000',
          'email': 'alice@example.com',
        });
        return http.Response(
          jsonEncode({
            'user_id': '@owner:p2p-im.com',
            'display_name': '破局',
            'domain': 'p2p-im.com',
            'avatar_url': 'mxc://p2p-im.com/avatar',
            'gender': 'female',
            'birthday': '1990-01-02',
            'phone': '13800000000',
            'email': 'alice@example.com',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final profile = await client.updateOwnerProfile(
      displayName: '  破局  ',
      avatarUrl: ' mxc://p2p-im.com/avatar ',
      gender: ' female ',
      birthday: ' 1990-01-02 ',
      phone: ' 13800000000 ',
      email: ' alice@example.com ',
    );

    expect(profile.userId, '@owner:p2p-im.com');
    expect(profile.displayName, '破局');
    expect(profile.domain, 'p2p-im.com');
    expect(profile.avatarUrl, 'mxc://p2p-im.com/avatar');
    expect(profile.gender, 'female');
    expect(profile.birthday, '1990-01-02');
    expect(profile.phone, '13800000000');
    expect(profile.email, 'alice@example.com');
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

  test('acceptContactRequest posts decision identity to AS', () async {
    late http.Request seen;
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        seen = request;
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/_as/contacts/requests/!alice%3Ap2p-im.com/accept',
        );
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'peer_mxid': '@alice:p2p-liyanan.com',
          'display_name': 'Alice',
          'domain': 'p2p-liyanan.com',
        });
        return http.Response(
          jsonEncode({
            'peer_mxid': '@alice:p2p-liyanan.com',
            'display_name': 'Alice',
            'domain': 'p2p-liyanan.com',
            'room_id': '!alice:p2p-im.com',
            'status': 'accepted',
          }),
          200,
        );
      }),
    );

    final contact = await client.acceptContactRequest(
      roomId: '!alice:p2p-im.com',
      peerMxid: '@alice:p2p-liyanan.com',
      displayName: 'Alice',
      domain: 'p2p-liyanan.com',
    );

    expect(seen.url.path, '/_as/contacts/requests/!alice%3Ap2p-im.com/accept');
    expect(contact.roomId, '!alice:p2p-im.com');
    expect(contact.status, 'accepted');
  });

  test('rejectContactRequest posts decision identity to AS', () async {
    late http.Request seen;
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        seen = request;
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/_as/contacts/requests/!alice%3Ap2p-im.com/reject',
        );
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'peer_mxid': '@alice:p2p-liyanan.com',
          'display_name': 'Alice',
          'domain': 'p2p-liyanan.com',
        });
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

    final contact = await client.rejectContactRequest(
      roomId: '!alice:p2p-im.com',
      peerMxid: '@alice:p2p-liyanan.com',
      displayName: 'Alice',
      domain: 'p2p-liyanan.com',
    );

    expect(seen.url.path, '/_as/contacts/requests/!alice%3Ap2p-im.com/reject');
    expect(contact.roomId, '!alice:p2p-im.com');
    expect(contact.status, 'rejected');
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

  test('registerIncomingCall preserves call id through unified API', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'action': 'calls.incoming',
          'params': {
            'call_id': 'call_remote',
            'room_id': '!alice:p2p-im.com',
            'media_type': 'video',
            'created_by_mxid': '@alice:p2p-liyanan.com',
            'created_at_ms': 1780230600000,
          },
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

  test('createGroup posts name avatar and accepted contact invites through AS',
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
          'avatar_url': 'mxc://p2p-im.com/group-avatar',
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
      avatarUrl: ' mxc://p2p-im.com/group-avatar ',
      invite: const ['@alice:p2p-liyanan.com'],
    );

    expect(group.roomId, '!group:p2p-im.com');
    expect(group.name, '产品测试群');
    expect(group.memberCount, 1);
    expect(group.invitedCount, 1);
  });

  test('updateGroupProfile puts name topic and avatar through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/_as/groups/!group%3Ap2p-im.com');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'name': 'Project Group Renamed',
          'topic': 'Weekly planning',
          'avatar_url': 'mxc://example.com/group-avatar2',
        });
        return http.Response(
          jsonEncode({
            'room_id': '!group:p2p-im.com',
            'name': 'Project Group Renamed',
            'member_count': 3,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final group = await client.updateGroupProfile(
      roomId: '!group:p2p-im.com',
      name: ' Project Group Renamed ',
      topic: ' Weekly planning ',
      avatarUrl: ' mxc://example.com/group-avatar2 ',
    );

    expect(group.roomId, '!group:p2p-im.com');
    expect(group.name, 'Project Group Renamed');
    expect(group.memberCount, 3);
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

  test('inviteGroupMembers accepts members-only invite response', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(jsonDecode(request.body), {
          'action': 'groups.invite',
          'params': {
            'room_id': '!group:p2p-im.com',
            'invite': ['@owner:dm1.direxio.ai'],
          },
        });
        return _jsonResponse(
          {
            'members': [
              {
                'room_id': '!group:p2p-im.com',
                'user_mxid': '@owner:dm1.direxio.ai',
                'display_name': 'owner',
                'membership': 'invite',
                'status': 'invite',
              },
            ],
            'status': 'ok',
          },
          200,
        );
      }),
    );

    final group = await client.inviteGroupMembers(
      roomId: '!group:p2p-im.com',
      invite: const ['@owner:dm1.direxio.ai'],
    );

    expect(group.roomId, '!group:p2p-im.com');
    expect(group.invitedCount, 1);
    expect(group.status, 'ok');
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

  test('removeChannelMember posts member removal through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/_as/channels/ch1/members/%40carol%3Ap2p-carol.com/remove',
        );
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(request.body, isEmpty);
        return http.Response(
          jsonEncode({'channel_id': 'ch1', 'status': 'removed'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await expectLater(
      client.removeChannelMember('ch1', ' @carol:p2p-carol.com '),
      completes,
    );
  });

  test('inviteChannelMembers posts channel invites through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/channels/ch1/invite');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'invite': ['@carol:p2p-carol.com'],
        });
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await expectLater(
      client.inviteChannelMembers(
        channelId: ' ch1 ',
        invite: const [' @carol:p2p-carol.com ', ''],
      ),
      completes,
    );
  });

  test('createChannelInviteGrant posts unified grant action with channel id',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'action': 'channels.invite_grant.create',
          'params': {
            'channel_id': 'ch1',
            'share_room_id': '!dm:p2p-im.com',
            'reason': 'share_card',
          },
        });
        return _jsonResponse(
          {
            'grant_id': 'grant_1',
            'channel_id': 'ch1',
            'room_id': '!channel:p2p-im.com',
            'share_room_id': '!dm:p2p-im.com',
            'status': 'active',
          },
          200,
        );
      }),
    );

    final grant = await client.createChannelInviteGrant(
      channelId: ' ch1 ',
      shareRoomId: ' !dm:p2p-im.com ',
      reason: ' share_card ',
    );

    expect(grant.grantId, 'grant_1');
    expect(grant.channelId, 'ch1');
    expect(grant.roomId, '!channel:p2p-im.com');
    expect(grant.shareRoomId, '!dm:p2p-im.com');
    expect(grant.status, 'active');
  });

  test('createChannelInviteGrant accepts room id without channel id', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(jsonDecode(request.body), {
          'action': 'channels.invite_grant.create',
          'params': {
            'room_id': '!channel:p2p-im.com',
            'share_room_id': '!dm:p2p-im.com',
          },
        });
        return _jsonResponse(
          {
            'grant': {
              'id': 'grant_2',
              'room_id': '!channel:p2p-im.com',
              'share_room_id': '!dm:p2p-im.com',
            },
          },
          200,
        );
      }),
    );

    final grant = await client.createChannelInviteGrant(
      roomId: ' !channel:p2p-im.com ',
      shareRoomId: ' !dm:p2p-im.com ',
    );

    expect(grant.grantId, 'grant_2');
    expect(grant.roomId, '!channel:p2p-im.com');
    expect(grant.shareRoomId, '!dm:p2p-im.com');
  });

  test('group mute APIs post expected AS endpoints', () async {
    final expectedPaths = [
      '/_as/groups/!group%3Ap2p-im.com/mute',
      '/_as/groups/!group%3Ap2p-im.com/unmute',
      '/_as/groups/!group%3Ap2p-im.com/members/'
          '%40carol%3Ap2p-carol.com/mute',
      '/_as/groups/!group%3Ap2p-im.com/members/'
          '%40carol%3Ap2p-carol.com/unmute',
    ];
    var index = 0;
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, expectedPaths[index++]);
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(request.body, isEmpty);
        return _jsonResponse({'ok': true}, 200);
      }),
    );

    await client.muteGroup('!group:p2p-im.com');
    await client.unmuteGroup('!group:p2p-im.com');
    await client.muteGroupMember(
      roomId: '!group:p2p-im.com',
      userId: ' @carol:p2p-carol.com ',
    );
    await client.unmuteGroupMember(
      roomId: '!group:p2p-im.com',
      userId: ' @carol:p2p-carol.com ',
    );

    expect(index, expectedPaths.length);
  });

  test('channel mute APIs post expected AS endpoints', () async {
    final expectedPaths = [
      '/_as/channels/ch1/mute',
      '/_as/channels/ch1/unmute',
      '/_as/channels/ch1/members/%40carol%3Ap2p-carol.com/mute',
      '/_as/channels/ch1/members/%40carol%3Ap2p-carol.com/unmute',
    ];
    var index = 0;
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, expectedPaths[index++]);
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(request.body, isEmpty);
        return _jsonResponse({'ok': true}, 200);
      }),
    );

    await client.muteChannel(' ch1 ');
    await client.unmuteChannel(' ch1 ');
    await client.muteChannelMember(' ch1 ', ' @carol:p2p-carol.com ');
    await client.unmuteChannelMember(' ch1 ', ' @carol:p2p-carol.com ');

    expect(index, expectedPaths.length);
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

  test('dissolveGroup posts dissolve through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/groups/!group%3Ap2p-im.com/dissolve');
        return http.Response(
          jsonEncode({'room_id': '!group:p2p-im.com', 'status': 'ok'}),
          200,
        );
      }),
    );

    await expectLater(client.dissolveGroup('!group:p2p-im.com'), completes);
  });

  test('leaveChannel posts leave through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/channels/ch1/leave');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return http.Response(
          jsonEncode({'channel_id': 'ch1', 'status': 'left'}),
          200,
        );
      }),
    );

    await expectLater(client.leaveChannel(' ch1 '), completes);
  });

  test('dissolveChannel posts dissolve through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/channels/ch1/dissolve');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return http.Response(
          jsonEncode({'channel_id': 'ch1', 'status': 'ok'}),
          200,
        );
      }),
    );

    await expectLater(client.dissolveChannel(' ch1 '), completes);
  });

  test('dissolve actions use unified P2P command body', () async {
    final seenActions = <String>[];
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final action = body['action'] as String;
        seenActions.add(action);
        if (action == 'channels.dissolve') {
          expect(body['params'], {'channel_id': 'ch1'});
          return http.Response(jsonEncode({'status': 'ok'}), 200);
        }
        expect(action, 'groups.dissolve');
        expect(body['params'], {'room_id': '!group:p2p-im.com'});
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }),
    );

    await client.dissolveChannel('ch1');
    await client.dissolveGroup('!group:p2p-im.com');

    expect(seenActions, ['channels.dissolve', 'groups.dissolve']);
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

  test('submitReport posts through unified reports action', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'action': 'reports.submit',
          'params': {
            'reporter_domain': 'p2p-im.com',
            'reported_domain': 'portal.local',
            'target_type': 1,
            'reason': '欺诈',
          },
        });
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'id': 'report-1',
            'reporter_domain': 'p2p-im.com',
            'reported_domain': 'portal.local',
            'target_type': 1,
            'reason': '欺诈',
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final report = await client.submitReport(
      reporterDomain: ' p2p-im.com ',
      reportedDomain: ' portal.local ',
      reason: ' 欺诈 ',
    );

    expect(report['id'], 'report-1');
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

  test('portal status parses unified storage and projector state', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/query');
        expect(jsonDecode(request.body), {
          'action': 'portal.status',
          'params': <String, Object?>{},
        });
        return http.Response(
          jsonEncode({
            'initialized': true,
            'user_id': '@owner:example.com',
            'homeserver': 'https://example.com',
            'store_mode': 'database',
            'projector_started': true,
          }),
          200,
        );
      }),
    );

    final status = await client.getPortalStatus();

    expect(status.initialized, isTrue);
    expect(status.userId, '@owner:example.com');
    expect(status.homeserver, 'https://example.com');
    expect(status.storeMode, 'database');
    expect(status.projectorStarted, isTrue);
    expect(status.allHealthy, isTrue);
  });

  test('portal status parses policy index and event stream readiness',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/query');
        expect(jsonDecode(request.body), {
          'action': 'portal.status',
          'params': <String, Object?>{},
        });
        return http.Response(
          jsonEncode({
            'initialized': true,
            'user_id': '@owner:example.com',
            'homeserver': 'https://example.com',
            'store_mode': 'database',
            'projector_started': true,
            'policy_index_mode': 'matrix_state',
            'policy_index_ready': false,
            'event_stream_ready': true,
          }),
          200,
        );
      }),
    );

    final status = await client.getPortalStatus();

    expect(status.policyIndexMode, 'matrix_state');
    expect(status.policyIndexReady, isFalse);
    expect(status.eventStreamReady, isTrue);
    expect(status.allHealthy, isFalse);
  });

  test('streamEvents uses P2P SSE endpoint with replay cursor', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_p2p/events');
        expect(request.url.queryParameters, {'since': '41'});
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(request.headers['Accept'], 'text/event-stream');
        expect(request.headers['Last-Event-ID'], '40');
        return http.Response(
          [
            'id: 42',
            'event: sync.bootstrap.changed',
            r'data: {"seq":42,"type":"sync.bootstrap.changed","room_id":"!room:example.com","event_id":"$event","payload":{"reason":"contacts"},"created_at":"2026-06-20T00:00:00Z"}',
            '',
          ].join('\n'),
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      }),
    );

    final events = await client
        .streamEvents(
          since: 41,
          lastEventId: '40',
        )
        .toList();

    expect(events, hasLength(1));
    expect(events.single.seq, 42);
    expect(events.single.type, 'sync.bootstrap.changed');
    expect(events.single.roomId, '!room:example.com');
    expect(events.single.eventId, r'$event');
    expect(events.single.payload['reason'], 'contacts');
  });

  test('changePortalPassword posts password payload to AS admin API', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'admin-token',
      accessTokenForDebug: 'matrix-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/_as/portal/password');
        expect(request.headers['Authorization'], 'Bearer admin-token');
        expect(jsonDecode(request.body), {
          'old_password': '11111111',
          'new_password': '22222222',
          'device_id': 'DEVICE1',
        });
        return http.Response(
          jsonEncode({
            'access_token': 'new-access-token',
            'initialized': true,
            'password_initialized': true,
            'profile_initialized': true,
          }),
          200,
        );
      }),
    );

    final session = await client.changePortalPassword(
      oldPassword: '11111111',
      newPassword: '22222222',
      deviceId: 'DEVICE1',
    );

    expect(session.accessToken, 'new-access-token');
    expect(session.userId, isEmpty);
    expect(session.homeserver, isEmpty);
    expect(session.initialized, isTrue);
    expect(session.passwordInitialized, isTrue);
    expect(session.profileInitialized, isTrue);
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
          'channel_type': 'post',
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
            'channel_type': 'post',
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
      channelType: 'post',
      tags: const ['产品', '公告'],
    );

    expect(channel.channelId, 'ch1');
    expect(channel.roomId, '!channel:example.com');
    expect(channel.channelType, 'post');
    expect(channel.role, 'owner');
  });

  test('listChannels calls AS channel list endpoint', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_as/channels');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return _jsonResponse(
          {
            'channels': [
              {
                'channel_id': 'ch1',
                'room_id': '!channel:example.com',
                'home_domain': 'example.com',
                'name': '产品公告',
                'description': '重要更新',
                'visibility': 'public',
                'join_policy': 'open',
                'comments_enabled': true,
                'role': 'owner',
                'member_status': 'joined',
                'member_count': 3,
                'pending_join_count': 1,
                'tags': ['product'],
              },
            ],
          },
          200,
        );
      }),
    );

    final channels = await client.listChannels();

    expect(channels.single.channelId, 'ch1');
    expect(channels.single.roomId, '!channel:example.com');
    expect(channels.single.pendingJoinCount, 1);
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

  test('getPublicChannelByRoomId calls public detail endpoint without auth',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://example.com/_as/public/channels/%21channel%3Aexample.com',
        );
        expect(request.headers['Authorization'], isNull);
        return _jsonResponse(
          {
            'channel_id': 'ch1',
            'room_id': '!channel:example.com',
            'home_domain': 'example.com',
            'name': '产品公告',
            'visibility': 'public',
            'join_policy': 'open',
            'comments_enabled': true,
          },
          200,
        );
      }),
    );

    final channel = await client.getPublicChannelByRoomId(
      '!channel:example.com',
    );

    expect(channel.channelId, 'ch1');
    expect(channel.roomId, '!channel:example.com');
  });

  test('getPublicChannelByRoomId uses override unified node without auth',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('http://127.0.0.1:28008/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'http://127.0.0.1:18008/_p2p/query',
        );
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {
          'action': 'channels.public.get',
          'params': {
            'channel_id': '!channel:dendrite-a:8448',
            'room_id': '!channel:dendrite-a:8448',
          },
        });
        return _jsonResponse(
          {
            'channel_id': 'ch1',
            'room_id': '!channel:dendrite-a:8448',
            'home_domain': 'dendrite-a:8448',
            'name': '产品公告',
            'visibility': 'public',
            'join_policy': 'open',
            'comments_enabled': true,
          },
          200,
        );
      }),
    );

    final channel = await client.getPublicChannelByRoomId(
      '!channel:dendrite-a:8448',
      baseUri: Uri.parse('http://127.0.0.1:18008/_p2p'),
    );

    expect(channel.channelId, 'ch1');
    expect(channel.roomId, '!channel:dendrite-a:8448');
  });

  test('getPublicChannelByRoomId passes remote node base URL as params',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://local.example/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://local.example/_p2p/query');
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {
          'action': 'channels.public.get',
          'params': {
            'channel_id': '!remote:remote.example',
            'room_id': '!remote:remote.example',
            'remote_node_base_url': 'https://remote.example/_p2p',
          },
        });
        return _jsonResponse(
          {
            'channel_id': 'ch_remote',
            'room_id': '!remote:remote.example',
            'home_domain': 'remote.example',
            'name': '远端公开频道',
            'visibility': 'public',
            'join_policy': 'open',
            'comments_enabled': true,
          },
          200,
        );
      }),
    );

    final channel = await client.getPublicChannelByRoomId(
      '!remote:remote.example',
      remoteNodeBaseUri: Uri.parse('https://remote.example/_p2p'),
    );

    expect(channel.channelId, 'ch_remote');
  });

  test('getUserPublicChannels calls public user endpoint without auth',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/_as/users/%40alice%3Aexample.com/public-channels',
        );
        expect(request.headers['Authorization'], isNull);
        return _jsonResponse(
          {
            'channels': [
              {
                'channel_id': 'ch_alice',
                'room_id': '!alice-channel:example.com',
                'home_domain': 'example.com',
                'name': 'Alice 公开频道',
                'avatar_url': 'https://example.com/avatar.png',
                'visibility': 'public',
                'join_policy': 'open',
                'comments_enabled': true,
              },
            ],
          },
          200,
        );
      }),
    );

    final channels = await client.getUserPublicChannels('@alice:example.com');

    expect(channels.single.channelId, 'ch_alice');
    expect(channels.single.roomId, '!alice-channel:example.com');
  });

  test('getUserPublicChannels uses unified public query without auth',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/query');
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {
          'action': 'users.public_channels',
          'params': {
            'user_id': '@alice:example.com',
            'user_mxid': '@alice:example.com',
          },
        });
        return _jsonResponse(
          {
            'channels': [
              {
                'channel_id': 'ch_alice',
                'room_id': '!alice-channel:example.com',
                'name': 'Alice 公开频道',
                'visibility': 'public',
                'join_policy': 'open',
                'comments_enabled': true,
              },
            ],
          },
          200,
        );
      }),
    );

    final channels = await client.getUserPublicChannels('@alice:example.com');

    expect(channels.single.channelId, 'ch_alice');
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

  test('joinChannel sends room, grant, and share room params for invite grant',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        final envelope = jsonDecode(request.body) as Map<String, dynamic>;
        expect(envelope['action'], 'channels.join');
        expect(envelope['params'], {
          'channel_id': 'ch_private',
          'room_id': '!private:example.com',
          'grant_id': 'grant-1',
          'share_room_id': '!direct:example.com',
        });
        return _jsonResponse(
          {
            'channel': {
              'channel_id': 'ch_private',
              'room_id': '!private:example.com',
              'home_domain': 'example.com',
              'name': '私密频道',
              'visibility': 'private',
              'join_policy': 'invite',
              'comments_enabled': true,
              'member_status': 'joined',
            },
          },
          200,
        );
      }),
    );

    final channel = await client.joinChannel(
      'ch_private',
      roomId: '!private:example.com',
      grantId: 'grant-1',
      shareRoomId: '!direct:example.com',
    );

    expect(channel.memberStatus, asChannelMemberStatusJoined);
  });

  test('joinChannelByRoomId posts room_id to public join request endpoint',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/_as/public/channels/%21remote%3Ap2p-im.com/join-requests',
        );
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
            'status': 'invited',
            'channel': {
              'channel_id': 'ch_remote',
              'room_id': '!remote:p2p-im.com',
              'home_domain': 'p2p-im.com',
              'name': '远端公开频道',
              'description': '跨节点发现',
              'visibility': 'public',
              'join_policy': 'open',
              'comments_enabled': true,
              'member_status': 'invite',
            },
          },
          200,
        );
      }),
    );

    final channel = await client.joinChannelByRoomId(
      '!remote:p2p-im.com',
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

    expect(channel.memberStatus, asChannelMemberStatusInvite);
  });

  test('joinChannelByRoomId requests public channel join by room id', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        final envelope = jsonDecode(request.body) as Map<String, dynamic>;
        expect(envelope['action'], 'channels.public.join_request');
        expect(envelope['params'], {
          'channel_id': '!remote:p2p-im.com',
          'room_id': '!remote:p2p-im.com',
        });
        return _jsonResponse(
          {
            'status': 'invited',
            'channel': {
              'channel_id': 'ch_remote',
              'room_id': '!remote:p2p-im.com',
              'home_domain': 'p2p-im.com',
              'name': '远端公开频道',
              'visibility': 'public',
              'join_policy': 'open',
              'comments_enabled': true,
            },
          },
          200,
        );
      }),
    );

    final channel = await client.joinChannelByRoomId('!remote:p2p-im.com');

    expect(channel.channelId, 'ch_remote');
    expect(channel.memberStatus, asChannelMemberStatusInvite);
  });

  test('joinChannelByRoomId passes remote node base URL as params', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://local.example/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://local.example/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        final envelope = jsonDecode(request.body) as Map<String, dynamic>;
        expect(envelope['action'], 'channels.public.join_request');
        expect(envelope['params'], {
          'channel_id': '!remote:remote.example',
          'room_id': '!remote:remote.example',
          'remote_node_base_url': 'https://remote.example/_p2p',
        });
        return _jsonResponse(
          {
            'status': 'pending',
            'channel': {
              'channel_id': 'ch_remote',
              'room_id': '!remote:remote.example',
              'home_domain': 'remote.example',
              'name': '远端公开频道',
              'visibility': 'public',
              'join_policy': 'approval',
              'comments_enabled': true,
            },
          },
          200,
        );
      }),
    );

    final channel = await client.joinChannelByRoomId(
      '!remote:remote.example',
      remoteNodeBaseUri: Uri.parse('https://remote.example/_p2p'),
    );

    expect(channel.channelId, 'ch_remote');
    expect(channel.memberStatus, asChannelMemberStatusPending);
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

  test('AsChannelMember normalizes service membership fields', () {
    final member = AsChannelMember.fromJson({
      'channel_id': 'ch1',
      'user_mxid': '@alice:p2p-liyanan.com',
      'membership': 'invite',
      'joined_at': 1781870000000,
    });

    expect(member.status, asChannelMemberStatusInvite);
    expect(member.joinedAtMs, 1781870000000);
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
            'status': 'invited',
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

  test('rejectChannelJoin posts rejection action to AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/_as/channels/ch1/join-requests/%40alice%3Ap2p-liyanan.com/reject',
        );
        expect(request.headers['Authorization'], 'Bearer portal-token');
        return _jsonResponse(
          {
            'status': 'rejected',
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

    final channel = await client.rejectChannelJoin(
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

  test('createChannelPost uses unified channel post create action', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        final envelope = jsonDecode(request.body) as Map<String, dynamic>;
        expect(envelope['action'], 'channels.posts.create');
        expect(envelope['params'], {
          'channel_id': 'ch1',
          'message_type': 'image',
          'body': '图片说明',
          'media_json': '{"mxc":"mxc://image"}',
        });
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
  });

  test('recallChannelPost posts reason to recall endpoint', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/channels/ch1/posts/post1/recall');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {'reason': 'recall post'});
        return _jsonResponse({}, 200);
      }),
    );

    await client.recallChannelPost('ch1', 'post1');
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
          'reply_to_comment_id': 'parent1',
          'reply_to_author_mxid': '@owner:example.com',
          'mentions': [
            {'user_id': '@alice:remote.example', 'display_name': 'Alice'},
          ],
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
            'reply_to_comment_id': 'parent1',
            'reply_to_author_mxid': '@owner:example.com',
            'mentions_json':
                '[{"user_id":"@alice:remote.example","display_name":"Alice"}]',
            'origin_server_ts': 1780730000000,
            'reaction_count': 5,
            'reacted_by_me': true,
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
      replyToCommentId: 'parent1',
      replyToAuthorId: '@owner:example.com',
      mentions: const [
        {'user_id': '@alice:remote.example', 'display_name': 'Alice'},
        {'display_name': 'Missing user'},
      ],
    );

    expect(comment.commentId, 'comment1');
    expect(comment.postId, 'post1');
    expect(comment.replyToCommentId, 'parent1');
    expect(comment.replyToAuthorId, '@owner:example.com');
    expect(comment.mentions, [
      {'user_id': '@alice:remote.example', 'display_name': 'Alice'},
    ]);
    expect(comment.reactionCount, 5);
    expect(comment.reactedByMe, isTrue);
  });

  test('getChannelComments uses page query parameters', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/_as/channels/ch1/posts/post1/comments');
        expect(request.url.queryParameters, {
          'page': '1',
          'page_size': '5',
        });
        return _jsonResponse(
          {
            'comments': [
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
            ],
          },
          200,
        );
      }),
    );

    final comments = await client.getChannelComments(
      'ch1',
      'post1',
      page: 1,
      pageSize: 5,
    );

    expect(comments, hasLength(1));
    expect(comments.single.commentId, 'comment1');
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

  test('toggleChannelCommentReaction posts current reaction state', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/_as/channels/ch1/posts/post1/comments/comment1/reactions',
        );
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {'reaction': 'like'});
        return _jsonResponse(
          {
            'post_id': 'post1',
            'channel_id': 'ch1',
            'reaction': 'like',
            'active': false,
            'reaction_count': 2,
          },
          200,
        );
      }),
    );

    final reaction = await client.toggleChannelCommentReaction(
      'ch1',
      'post1',
      'comment1',
      reaction: 'like',
    );

    expect(reaction.active, isFalse);
    expect(reaction.reactionCount, 2);
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

  test(
      'getMyChannelComments uses unified history action without fake channel id',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/query');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        final envelope = jsonDecode(request.body) as Map<String, dynamic>;
        expect(envelope['action'], 'channels.my_comments');
        expect(envelope['params'], {
          'limit': '15',
        });
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

    expect(comments.single.comment.commentId, 'comment1');
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

  test('authenticatePortal posts password to auth', () async {
    final session = await HttpAsClient.authenticatePortal(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: '11111111',
      deviceId: 'DEVICE2',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/auth');
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {
          'password': '11111111',
          'device_id': 'DEVICE2',
        });
        return http.Response(
          jsonEncode({
            'access_token': 'matrix-access-token',
            'user_id': '@owner:example.com',
            'homeserver': 'https://example.com',
            'agent_room_id': '!agent:example.com',
            'initialized': true,
            'password_initialized': false,
            'profile_initialized': false,
          }),
          200,
        );
      }),
    );

    expect(session.accessToken, 'matrix-access-token');
    expect(session.userId, '@owner:example.com');
    expect(session.homeserver, 'https://example.com');
    expect(session.deviceId, isNull);
    expect(session.agentRoomId, '!agent:example.com');
    expect(session.initialized, isTrue);
    expect(session.passwordInitialized, isFalse);
    expect(session.profileInitialized, isFalse);
  });

  test('bootstrapPortal posts setup code to bootstrap', () async {
    final session = await HttpAsClient.bootstrapPortal(
      baseUri: Uri.parse('https://example.com/_as'),
      setupCode: 'setup-code',
      deviceId: 'DEVICE3',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/bootstrap');
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {
          'token': 'setup-code',
          'device_id': 'DEVICE3',
        });
        return http.Response(
          jsonEncode({
            'access_token': 'bootstrapped-access-token',
            'user_id': '@owner:example.com',
            'homeserver': 'https://example.com',
            'initialized': true,
            'password_initialized': false,
            'profile_initialized': false,
          }),
          200,
        );
      }),
    );

    expect(session.accessToken, 'bootstrapped-access-token');
    expect(session.initialized, isTrue);
    expect(session.passwordInitialized, isFalse);
    expect(session.profileInitialized, isFalse);
  });
}

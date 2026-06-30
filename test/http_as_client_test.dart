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
    final base = HttpAsClient.defaultProductBaseUri(
      Uri.parse('http://127.0.0.1:8008'),
    );

    expect(base.toString(), 'http://127.0.0.1:8008/_p2p');
  });

  test('maps hosted homeserver to integrated P2P API', () {
    final base = HttpAsClient.defaultProductBaseUri(
      Uri.parse('https://im.jkmf.top'),
    );

    expect(base.toString(), 'https://im.jkmf.top/_p2p');
  });

  test('maps configured local endpoints to reachable P2P API ports', () {
    final endpoints = LocalEndpointResolver.parse(
      'node-a.test=127.0.0.1:18008,node-c.test=127.0.0.1:38008',
    );
    final base = HttpAsClient.defaultProductBaseUri(
      Uri.parse('https://node-a.test'),
      localEndpointResolver: endpoints,
    );
    final cBase = HttpAsClient.defaultProductBaseUri(
      Uri.parse('https://node-c.test'),
      localEndpointResolver: endpoints,
    );

    expect(base.toString(), 'http://127.0.0.1:18008/_p2p');
    expect(cBase.toString(), 'http://127.0.0.1:38008/_p2p');
  });

  test('rejects non-P2P base URI for P2P product API client', () {
    expect(
      () => HttpAsClient(
        baseUri: Uri.parse('https://example.com/product'),
        portalToken: 'portal-token',
      ),
      throwsA(isA<AsClientException>()),
    );
  });

  test('conversation helpers use unified conversation actions', () async {
    final seen = <Map<String, dynamic>>[];
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/query');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        seen.add(body);
        if (body['action'] == 'conversations.list') {
          return _jsonResponse({
            'conversations': [
              {
                'conversation_id': 'conv_direct',
                'room_id': '!direct:p2p-im.com',
                'kind': 'direct',
                'lifecycle': 'active',
                'title': 'Alice',
              },
            ],
          }, 200);
        }
        return _jsonResponse({
          'conversation_id': 'conv_direct',
          'room_id': '!direct:p2p-im.com',
          'kind': 'direct',
          'lifecycle': 'active',
          'title': 'Alice',
        }, 200);
      }),
    );

    final conversations = await client.listConversations();
    final conversation =
        await client.getConversation(roomId: '!direct:p2p-im.com');

    expect(conversations.single.conversationId, 'conv_direct');
    expect(conversation.roomId, '!direct:p2p-im.com');
    expect(seen, [
      {'action': 'conversations.list', 'params': <String, dynamic>{}},
      {
        'action': 'conversations.get',
        'params': {'room_id': '!direct:p2p-im.com'},
      },
    ]);
  });

  test('contact list and reactivation use backend actions', () async {
    final seen = <Map<String, dynamic>>[];
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        seen.add(body);
        if (body['action'] == 'contacts.list') {
          expect(request.url.path, '/_p2p/query');
          return _jsonResponse({
            'contacts': [
              {
                'peer_mxid': '@alice:p2p-im.com',
                'room_id': '!alice:p2p-im.com',
                'status': 'accepted',
              },
            ],
          }, 200);
        }
        expect(request.url.path, '/_p2p/command');
        return _jsonResponse({
          'status': 'invited',
          'room_id': '!alice:p2p-im.com',
        }, 200);
      }),
    );

    final contacts = await client.listContacts();
    final reactivated = await client.reactivateContact(
      roomId: '!alice:p2p-im.com',
      requesterMxid: '@owner:p2p-im.com',
      remoteNodeBaseUri: Uri.parse('https://remote.example/_p2p'),
    );

    expect(contacts.single.peerMxid, '@alice:p2p-im.com');
    expect(reactivated['status'], 'invited');
    expect(seen, [
      {'action': 'contacts.list', 'params': <String, dynamic>{}},
      {
        'action': 'contacts.reactivate',
        'params': {
          'room_id': '!alice:p2p-im.com',
          'requester_mxid': '@owner:p2p-im.com',
          'remote_node_base_url': 'https://remote.example/_p2p',
        },
      },
    ]);
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
            'operation': {
              'action': 'contacts.delete',
              'status': 'deleted',
              'room_id': '!alice:p2p-im.com',
              'conversation_id': 'conv_direct',
            },
            'conversation': {
              'conversation_id': 'conv_direct',
              'matrix_room_id': '!alice:p2p-im.com',
              'kind': 'direct',
              'lifecycle': 'deleted',
              'peer_mxid': '@alice:p2p-im.com',
              'title': 'Alice',
              'capabilities': {'open': false},
            },
          }),
          200,
        );
      }),
    );

    final contact = await client.deleteContact('!alice:p2p-im.com');

    expect(contact.roomId, '!alice:p2p-im.com');
    expect(contact.status, 'deleted');
    expect(contact.operation.action, 'contacts.delete');
    expect(contact.operation.conversationId, 'conv_direct');
    expect(contact.productConversation?.conversationId, 'conv_direct');
    expect(contact.productConversation?.canOpen, isFalse);
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
            'avatar_url': 'mxc://p2p-im.com/alice',
            'domain': 'p2p-im.com',
          },
        });
        return http.Response(
          jsonEncode({
            'peer_mxid': '@alice:p2p-im.com',
            'display_name': 'Alice Remark',
            'avatar_url': 'mxc://p2p-im.com/alice',
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
      avatarUrl: '  mxc://p2p-im.com/alice  ',
      domain: 'p2p-im.com',
    );

    expect(contact.displayName, 'Alice Remark');
    expect(contact.avatarUrl, 'mxc://p2p-im.com/alice');
    expect(contact.status, 'accepted');
  });

  test('agent password helper uses unified API action', () async {
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
          default:
            fail('unexpected action ${body['action']}');
        }
      }),
    );

    expect((await client.getAgentPassword())['password'], 'secret');
    expect(seen, hasLength(1));
  });

  test('maps legacy channel intro field to description', () {
    final summary = AsSyncRoomSummary.fromJson({
      'channel_id': 'ch_intro',
      'room_id': '!intro:p2p-im.com',
      'name': '产品公告',
      'avatar_url': '',
      'unread_count': 0,
      'intro': '频道介绍字段',
      'muted': true,
    });
    final channel = AsChannel.fromJson({
      'channel_id': 'ch_intro',
      'room_id': '!intro:p2p-im.com',
      'name': '产品公告',
      'intro': '频道介绍字段',
      'muted': true,
    });

    expect(summary.description, '频道介绍字段');
    expect(summary.muted, isTrue);
    expect(channel.description, '频道介绍字段');
    expect(channel.muted, isTrue);
  });

  test('listChannels treats null channels envelope as empty list', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        final envelope = jsonDecode(request.body) as Map<String, dynamic>;
        expect(envelope['action'], 'channels.list');
        return _jsonResponse({'channels': null}, 200);
      }),
    );

    final channels = await client.listChannels();

    expect(channels, isEmpty);
  });

  test('createChannel requires backend product channel identity', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(jsonDecode(request.body), {
          'action': 'channels.create',
          'params': {
            'name': 'Posts',
            'description': 'Updates',
            'visibility': 'public',
            'join_policy': 'open',
            'channel_type': 'post',
            'comments_enabled': true,
            'tags': ['product'],
          },
        });
        return _jsonResponse(
          {
            'channel_id': 'ch_posts',
            'room_id': '!posts:example.com',
            'name': 'Posts',
            'description': 'Updates',
            'channel_type': 'post',
          },
          200,
        );
      }),
    );

    final channel = await client.createChannel(
      name: ' Posts ',
      description: ' Updates ',
      channelType: 'post',
      tags: const [' product '],
    );

    expect(channel.channelId, 'ch_posts');
    expect(channel.roomId, '!posts:example.com');
  });

  test('createChannel rejects response with Matrix room id channel identity',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((_) async {
        return _jsonResponse(
          {
            'channel_id': '!posts:example.com',
            'room_id': '!posts:example.com',
            'name': 'Posts',
          },
          200,
        );
      }),
    );

    await expectLater(
      client.createChannel(name: 'Posts'),
      throwsA(
        isA<AsClientException>().having(
          (error) => error.message,
          'message',
          'P2P create channel response is missing channel_id',
        ),
      ),
    );
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
            'groups': [
              {
                'room_id': '!group:example.com',
                'name': 'Group',
                'avatar_url': '',
                'unread_count': 0,
                'muted': true,
              }
            ],
            'channels': [
              {
                'channel_id': 'ch_1',
                'room_id': '!channel:example.com',
                'name': 'Channel',
                'avatar_url': '',
                'unread_count': 0,
                'muted': true,
              }
            ],
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
      baseUri: Uri.parse('https://example.com/_p2p'),
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

  test('AS M_UNKNOWN_TOKEN reports failed bearer token', () async {
    final failedTokens = <String>[];
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'stale-token',
      onAuthenticationFailedForToken: failedTokens.add,
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer stale-token');
        return _jsonResponse({'error': 'M_UNKNOWN_TOKEN'}, 401);
      }),
    );

    await expectLater(
      client.getOwnerProfile(),
      throwsA(isA<AsClientException>()),
    );

    expect(failedTokens, ['stale-token']);
  });

  test('AS non-M_UNKNOWN_TOKEN 401 does not expire session', () async {
    var expired = false;
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'bad-token',
      onAuthenticationFailed: () {
        expired = true;
      },
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer bad-token');
        return _jsonResponse({'error': 'permission denied'}, 401);
      }),
    );

    await expectLater(
      client.getOwnerProfile(),
      throwsA(
        isA<AsClientException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.message, 'message', 'permission denied'),
      ),
    );
    expect(expired, isFalse);
  });

  test('AS business 403 does not expire session', () async {
    var expired = false;
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
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

  test('follow mutations keep mock-compatible idempotency', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['action'] == 'follows.add') {
          return http.Response(jsonEncode({'status': 'already_followed'}), 409);
        }
        if (body['action'] == 'follows.remove') {
          return http.Response(jsonEncode({'error': 'not found'}), 404);
        }
        return http.Response(jsonEncode({'error': 'unexpected action'}), 500);
      }),
    );

    await expectLater(client.addFollow('example.org'), completes);
    await expectLater(client.removeFollow('example.org'), completes);
  });

  test('unexpected AS errors surface status code', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
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

  test('rejectContactRequest posts command action with room identity',
      () async {
    late http.Request seen;
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        seen = request;
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'action': 'contacts.requests.reject',
          'params': {
            'room_id': '!alice:p2p-im.com',
            'peer_mxid': '@alice:p2p-liyanan.com',
            'display_name': 'Alice',
            'domain': 'p2p-liyanan.com',
          },
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

    expect(seen.url.path, '/_p2p/command');
    expect(contact.roomId, '!alice:p2p-im.com');
    expect(contact.status, 'rejected');
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
            'operation': {
              'action': 'groups.invite',
              'status': 'ok',
              'room_id': '!group:p2p-im.com',
              'conversation_id': 'conv_group',
            },
            'conversation': {
              'conversation_id': 'conv_group',
              'matrix_room_id': '!group:p2p-im.com',
              'kind': 'group',
              'lifecycle': 'active',
              'title': 'Group',
              'capabilities': {'open': true},
            },
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
    expect(group.operation.action, 'groups.invite');
    expect(group.operation.conversationId, 'conv_group');
    expect(group.productConversation?.conversationId, 'conv_group');
  });

  test('getGroupMembers reads backend sorted group members', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/query');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'action': 'groups.members',
          'params': {
            'room_id': '!group:p2p-im.com',
            'status': 'join',
          },
        });
        return _jsonResponse(
          {
            'members': [
              {
                'room_id': '!group:p2p-im.com',
                'user_id': '@owner:p2p-im.com',
                'display_name': 'Owner',
                'avatar_url': 'mxc://p2p-im.com/owner',
                'membership': 'join',
                'role': 'owner',
                'joined_at': 100,
              },
              {
                'room_id': '!group:p2p-im.com',
                'user_id': '@alice:p2p-im.com',
                'display_name': 'Alice',
                'avatar_url': 'mxc://p2p-im.com/alice',
                'membership': 'join',
                'role': 'member',
                'joined_at': 200,
              },
            ],
          },
          200,
        );
      }),
    );

    final members = await client.getGroupMembers(
      '!group:p2p-im.com',
      status: asChannelMemberStatusJoined,
    );

    expect(members.map((member) => member.userMxid), [
      '@owner:p2p-im.com',
      '@alice:p2p-im.com',
    ]);
    expect(members.first.role, asChannelRoleOwner);
    expect(members.first.status, asChannelMemberStatusJoined);
    expect(members.first.joinedAtMs, 100);
    expect(members[1].displayName, 'Alice');
    expect(members[1].avatarUrl, 'mxc://p2p-im.com/alice');
  });

  test('removeGroupMember posts member removal through AS', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'action': 'groups.member.remove',
          'params': {
            'room_id': '!group:p2p-im.com',
            'user_id': '@carol:p2p-carol.com',
            'peer_mxid': '@carol:p2p-carol.com',
          },
        });
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
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'action': 'channels.member.remove',
          'params': {
            'channel_id': 'ch1',
            'user_id': '@carol:p2p-carol.com',
            'user_mxid': '@carol:p2p-carol.com',
          },
        });
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
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'action': 'channels.invite',
          'params': {
            'channel_id': 'ch1',
            'invite': ['@carol:p2p-carol.com'],
          },
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

  test('favoriteMessage sends media snapshot content through unified action',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://p2p-im.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['action'], 'favorites.add');
        final params = (payload['params'] as Map).cast<String, dynamic>();
        expect(params['room_id'], '!room:p2p-im.com');
        expect(params['event_id'], r'$image');
        expect(params['url'], 'mxc://p2p-im.com/photo');
        final content =
            jsonDecode(params['content'] as String) as Map<String, dynamic>;
        expect(content['msgtype'], 'm.image');
        expect(content['body'], 'photo.jpg');
        expect(content['filename'], 'photo.jpg');
        expect(content['url'], 'mxc://p2p-im.com/photo');
        final info = (content['info'] as Map).cast<String, dynamic>();
        expect(info['mimetype'], 'image/jpeg');
        expect(info['size'], 12345);
        expect(info['thumbnail_url'], 'mxc://p2p-im.com/thumb');
        expect(info['w'], 640);
        expect(info['h'], 480);
        final thumbnailInfo =
            (info['thumbnail_info'] as Map).cast<String, dynamic>();
        expect(thumbnailInfo['mimetype'], 'image/jpeg');
        expect(thumbnailInfo['size'], 1234);
        return http.Response(
          jsonEncode({
            'id': 17,
            'room_id': '!room:p2p-im.com',
            'event_id': r'$image',
            'message_type': 'image',
            'sender_id': '@owner:p2p-im.com',
            'sender_name': 'Yanan',
            'content': params['content'],
            'origin_server_ts': 1779685200000,
            'created_at': '2026-05-29T10:00:00Z',
          }),
          200,
        );
      }),
    );

    final favorite = await client.favoriteMessage(
      const AsFavoriteMessageDraft(
        roomId: '!room:p2p-im.com',
        eventId: r'$image',
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

    expect(favorite.id, 17);
    expect(favorite.body, 'photo.jpg');
    expect(favorite.url, 'mxc://p2p-im.com/photo');
    expect(favorite.thumbnailUrl, 'mxc://p2p-im.com/thumb');
    expect(favorite.mimeType, 'image/jpeg');
    expect(favorite.size, 12345);
    expect(favorite.width, 640);
    expect(favorite.height, 480);
    expect(favorite.favoritedAt?.toUtc().toIso8601String(),
        '2026-05-29T10:00:00.000Z');
  });

  test('portal status treats AS connected session label as healthy', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
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

  test('WsAsClient sends logged-in product actions through WS requestAction',
      () async {
    final calls = <Map<String, Object?>>[];
    final client = WsAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      requestAction: (
        action,
        params, {
        Set<int> allowedStatusCodes = const {200},
      }) async {
        calls.add({
          'action': action,
          'params': params,
          'allowed': allowedStatusCodes,
        });
        return {'follows': []};
      },
      httpClient: MockClient((request) async {
        fail('product action should not use HTTP');
      }),
    );

    final follows = await client.getFollows();

    expect(follows, isEmpty);
    expect(calls, hasLength(1));
    expect(calls.single['action'], 'follows.list');
    expect(calls.single['params'], isEmpty);
  });

  test('WsAsClient keeps realtime ticket creation on HTTP', () async {
    var wsCalls = 0;
    final client = WsAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      requestAction: (
        action,
        params, {
        Set<int> allowedStatusCodes = const {200},
      }) async {
        wsCalls++;
        return const {};
      },
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(jsonDecode(request.body), {
          'action': 'realtime.ws_ticket.create',
          'params': <String, Object?>{},
        });
        return _jsonResponse({
          'ticket': 'ws-ticket',
          'expires_in_ms': 60000,
        }, 200);
      }),
    );

    final ticket = await client.createRealtimeWSTicket();

    expect(ticket.ticket, 'ws-ticket');
    expect(wsCalls, 0);
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

  test('getUserPublicChannels sends remote owner node base when provided',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://local.example/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://local.example/_p2p/query');
        expect(jsonDecode(request.body), {
          'action': 'users.public_channels',
          'params': {
            'user_id': '@alice:remote.example',
            'user_mxid': '@alice:remote.example',
            'remote_node_base_url': 'https://remote.example/_p2p',
          },
        });
        return _jsonResponse(
          {
            'channels': [
              {
                'channel_id': 'ch_remote_alice',
                'room_id': '!alice-channel:remote.example',
                'name': 'Alice 远端公开频道',
              },
            ],
          },
          200,
        );
      }),
    );

    final channels = await client.getUserPublicChannels(
      '@alice:remote.example',
      remoteNodeBaseUri: Uri.parse('https://remote.example/_p2p'),
    );

    expect(channels.single.channelId, 'ch_remote_alice');
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
            'conversation': {
              'conversation_id': 'conv_channel',
              'matrix_room_id': '!private:example.com',
              'kind': 'channel',
              'lifecycle': 'active',
              'title': '私密频道',
              'capabilities': {'open': true},
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
    expect(channel.productConversation?.conversationId, 'conv_channel');
    expect(channel.productConversation?.roomId, '!private:example.com');
  });

  test('joinChannel prefers top-level joined status over stale channel member',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        final envelope = jsonDecode(request.body) as Map<String, dynamic>;
        expect(envelope['action'], 'channels.join');
        return _jsonResponse(
          {
            'status': 'joined',
            'channel': {
              'channel_id': 'ch_private',
              'room_id': '!private:example.com',
              'home_domain': 'example.com',
              'name': '私密频道',
              'visibility': 'private',
              'join_policy': 'invite',
              'comments_enabled': true,
              'member_status': 'invite',
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

  test('joinChannelByRoomId posts public join request through P2P command',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'action': 'channels.public.join_request',
          'params': {
            'channel_id': '!remote:p2p-im.com',
            'room_id': '!remote:p2p-im.com',
            'requester_node_base_url': 'https://example.com/_p2p',
            'home_domain': 'p2p-im.com',
            'name': '远端公开频道',
            'description': '跨节点发现',
            'visibility': 'public',
            'join_policy': 'open',
            'comments_enabled': true,
            'tags': ['产品'],
          },
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

    expect(channel.memberStatus, asChannelMemberStatusJoined);
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
          'requester_node_base_url': 'https://example.com/_p2p',
        });
        return _jsonResponse(
          {
            'status': 'joined',
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
    expect(channel.memberStatus, asChannelMemberStatusJoined);
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
          'requester_node_base_url': 'https://local.example/_p2p',
          'server_names': ['remote.example'],
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
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/query');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['action'], 'channels.members');
        expect(body['params'], {'status': 'pending', 'channel_id': 'ch1'});
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

  test('getChannelMembers sends backend join membership for joined status',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/query');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['action'], 'channels.members');
        expect(body['params'], {'status': 'join', 'channel_id': 'ch1'});
        return _jsonResponse(
          {
            'members': [
              {
                'channel_id': 'ch1',
                'user_mxid': '@alice:p2p-liyanan.com',
                'display_name': 'Alice',
                'role': 'member',
                'membership': 'join',
              },
            ],
          },
          200,
        );
      }),
    );

    final members = await client.getChannelMembers(
      'ch1',
      status: asChannelMemberStatusJoined,
    );

    expect(members.single.userMxid, '@alice:p2p-liyanan.com');
    expect(members.single.status, asChannelMemberStatusJoined);
  });

  test('AsChannelMember normalizes service membership fields', () {
    final member = AsChannelMember.fromJson({
      'channel_id': 'ch1',
      'user_mxid': '@alice:p2p-liyanan.com',
      'avatar_url': 'mxc://p2p-liyanan.com/alice-avatar',
      'membership': 'invite',
      'joined_at': 1781870000000,
    });

    expect(member.status, asChannelMemberStatusInvite);
    expect(member.avatarUrl, 'mxc://p2p-liyanan.com/alice-avatar');
    expect(member.joinedAtMs, 1781870000000);
  });

  test('approveChannelJoin posts approval action to P2P command', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'action': 'channels.join_request.approve',
          'params': {
            'channel_id': 'ch1',
            'user_id': '@alice:p2p-liyanan.com',
            'user_mxid': '@alice:p2p-liyanan.com',
          },
        });
        return _jsonResponse(
          {
            'status': 'approved',
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

    final result = await client.approveChannelJoin(
      'ch1',
      '@alice:p2p-liyanan.com',
    );

    expect(result.status, asChannelMemberStatusApproved);
    expect(result.channel.channelId, 'ch1');
    expect(result.channel.pendingJoinCount, 0);
  });

  test('approveChannelJoin preserves join failure status', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        return _jsonResponse(
          {
            'status': 'join_failed',
            'error': 'target node join result failed',
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

    final result = await client.approveChannelJoin(
      'ch1',
      '@alice:p2p-liyanan.com',
    );

    expect(result.status, asChannelMemberStatusJoinFailed);
    expect(result.error, 'target node join result failed');
    expect(result.channel.channelId, 'ch1');
  });

  test('rejectChannelJoin posts rejection action to P2P command', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/command');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'action': 'channels.join_request.reject',
          'params': {
            'channel_id': 'ch1',
            'user_id': '@alice:p2p-liyanan.com',
            'user_mxid': '@alice:p2p-liyanan.com',
          },
        });
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

    final result = await client.rejectChannelJoin(
      'ch1',
      '@alice:p2p-liyanan.com',
    );

    expect(result.status, asChannelMemberStatusRejected);
    expect(result.channel.channelId, 'ch1');
    expect(result.channel.pendingJoinCount, 0);
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

  test('channel post parses author avatar url from response', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/query');
        final envelope = jsonDecode(request.body) as Map<String, dynamic>;
        expect(envelope['action'], 'channels.posts.list');
        return _jsonResponse(
          {
            'posts': [
              {
                'post_id': 'post1',
                'channel_id': 'ch1',
                'room_id': '!channel:example.com',
                'event_id': r'$post1',
                'author_mxid': '@owner:example.com',
                'author_name': 'Owner',
                'author_avatar_url': 'mxc://example.com/owner-avatar',
                'body': '图片说明',
                'message_type': 'text',
                'origin_server_ts': 1780730000000,
              },
            ],
          },
          200,
        );
      }),
    );

    final posts = await client.getChannelPosts('ch1', limit: 10, beforeTs: 1);

    expect(posts.single.authorAvatarUrl, 'mxc://example.com/owner-avatar');
  });

  test('getMyChannelReactions parses channel reaction history', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/query');
        expect(request.headers['Authorization'], 'Bearer portal-token');
        expect(jsonDecode(request.body), {
          'action': 'channels.my_reactions',
          'params': {'limit': '25'},
        });
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

  test('getMyChannelReactions parses flat channel activity fields', () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_p2p/query');
        expect(jsonDecode(request.body), {
          'action': 'channels.my_reactions',
          'params': {'limit': '50'},
        });
        return _jsonResponse(
          {
            'reactions': [
              {
                'post_id': 'post1',
                'channel_id': 'ch1',
                'room_id': '!channel:example.com',
                'channel_name': '产品公告',
                'avatar_url': 'mxc://example.com/channel-avatar',
                'reaction': 'like',
                'post_body': '频道帖子',
                'post_author_name': 'Yanan',
                'origin_server_ts': 1780730300000,
              },
            ],
          },
          200,
        );
      }),
    );

    final reactions = await client.getMyChannelReactions(limit: 50);

    expect(reactions.single.channel.name, '产品公告');
    expect(
      reactions.single.channel.avatarUrl,
      'mxc://example.com/channel-avatar',
    );
    expect(reactions.single.post.body, '频道帖子');
    expect(reactions.single.post.authorName, 'Yanan');
  });

  test('getMyChannelReactions does not invent channel or post snapshots',
      () async {
    final client = HttpAsClient(
      baseUri: Uri.parse('https://example.com/_p2p'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        return _jsonResponse(
          {
            'reactions': [
              {
                'target_type': 'post',
                'target_id': 'post1',
                'post_id': 'post1',
                'channel_id': 'ch1',
                'reaction': 'like',
                'active': true,
              },
            ],
          },
          200,
        );
      }),
    );

    final reactions = await client.getMyChannelReactions(limit: 50);

    expect(reactions.single.channel.channelId, isEmpty);
    expect(reactions.single.channel.name, isEmpty);
    expect(reactions.single.post.postId, isEmpty);
    expect(reactions.single.post.body, isEmpty);
    expect(reactions.single.post.messageType, isEmpty);
    expect(reactions.single.postId, 'post1');
    expect(reactions.single.channelId, 'ch1');
  });
}

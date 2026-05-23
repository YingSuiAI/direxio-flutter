import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/http_as_client.dart';

void main() {
  test('maps loopback homeserver to local AS admin port', () {
    final base = HttpAsClient.defaultAdminBaseUri(
      Uri.parse('http://127.0.0.1:8008'),
    );

    expect(base.toString(), 'http://127.0.0.1:9090/_as');
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

  test('authenticatePortal bootstraps with body token', () async {
    final session = await HttpAsClient.authenticatePortal(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/_as/bootstrap');
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {'token': 'portal-token'});
        return http.Response(
          jsonEncode({
            'access_token': 'matrix-access-token',
            'user_id': '@owner:example.com',
            'homeserver': 'https://example.com',
            'device_id': 'DEVICE1',
          }),
          200,
        );
      }),
    );

    expect(session.accessToken, 'matrix-access-token');
    expect(session.userId, '@owner:example.com');
    expect(session.homeserver, 'https://example.com');
    expect(session.deviceId, 'DEVICE1');
  });

  test('authenticatePortal falls back to auth when already initialized',
      () async {
    var calls = 0;
    final session = await HttpAsClient.authenticatePortal(
      baseUri: Uri.parse('https://example.com/_as'),
      portalToken: 'portal-token',
      httpClient: MockClient((request) async {
        calls += 1;
        if (calls == 1) {
          expect(request.url.path, '/_as/bootstrap');
          return http.Response(
            jsonEncode({'error': 'portal already initialised'}),
            409,
          );
        }
        expect(request.url.path, '/_as/auth');
        expect(jsonDecode(request.body), {'token': 'portal-token'});
        return http.Response(
          jsonEncode({
            'access_token': 'fresh-matrix-token',
            'user_id': '@owner:example.com',
            'homeserver': 'https://example.com',
          }),
          200,
        );
      }),
    );

    expect(calls, 2);
    expect(session.accessToken, 'fresh-matrix-token');
  });
}

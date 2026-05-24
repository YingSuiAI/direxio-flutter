import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_app/data/as_gateway_client.dart';

void main() {
  test('listRooms calls AS Gateway with bearer agent token', () async {
    late http.Request seen;
    final client = AsGatewayClient(
      asUrl: 'http://as.test',
      agentToken: 'agent-token',
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({'rooms': []}), 200);
      }),
    );

    final result = await client.listRooms();

    expect(result, {'rooms': []});
    expect(seen.url.toString(), 'http://as.test/api/rooms');
    expect(seen.headers['Authorization'], 'Bearer agent-token');
  });

  test('authProbe reports configured AS Gateway profile without network call',
      () async {
    final client = AsGatewayClient(
      asUrl: 'http://as.test',
      agentToken: 'agent-token',
      httpClient: MockClient((request) async {
        fail('authProbe should not call AS Gateway endpoints');
      }),
    );

    expect(await client.authProbe(), {
      'as_url': 'http://as.test',
      'auth_mode': 'bearer_agent_token',
      'token_loaded': true,
    });
  });

  test('readRoomMessages encodes room id and query', () async {
    late Uri seenUrl;
    final client = AsGatewayClient(
      asUrl: 'http://as.test/base',
      agentToken: 'agent-token',
      httpClient: MockClient((request) async {
        seenUrl = request.url;
        return http.Response(jsonEncode({'messages': []}), 200);
      }),
    );

    await client.readRoomMessages('!room:example.com', limit: 10);

    expect(
      seenUrl.toString(),
      'http://as.test/base/api/rooms/!room%3Aexample.com/messages?limit=10',
    );
  });

  test('sendMessage posts content as the current user transport', () async {
    late http.Request seen;
    final client = AsGatewayClient(
      asUrl: 'http://as.test',
      agentToken: 'agent-token',
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({'event_id': r'$event'}), 200);
      }),
    );

    final result = await client.sendMessage('!room:example.com', '你好');

    expect(result, {'event_id': r'$event'});
    expect(seen.method, 'POST');
    expect(
      seen.url.toString(),
      'http://as.test/api/rooms/!room%3Aexample.com/send',
    );
    expect(seen.headers['Authorization'], 'Bearer agent-token');
    expect(seen.headers['Idempotency-Key'], startsWith('client-'));
    expect(jsonDecode(seen.body), {'content': '你好'});
  });

  test('throws typed error for AS Gateway failures', () async {
    final client = AsGatewayClient(
      asUrl: 'http://as.test',
      agentToken: 'bad-token',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'unauthorized', 'message': 'invalid token'}),
          401,
        );
      }),
    );

    expect(
      client.listRooms,
      throwsA(
        isA<AsGatewayException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', 'invalid token'),
      ),
    );
  });

  test('retries transient GET failures before decoding success', () async {
    var attempts = 0;
    final client = AsGatewayClient(
      asUrl: 'http://as.test',
      agentToken: 'agent-token',
      maxRetries: 2,
      retryDelay: Duration.zero,
      httpClient: MockClient((request) async {
        attempts += 1;
        if (attempts == 1) {
          return http.Response(jsonEncode({'error': 'busy'}), 503);
        }
        return http.Response(jsonEncode({'rooms': []}), 200);
      }),
    );

    expect(await client.listRooms(), {'rooms': []});
    expect(attempts, 2);
  });

  test('does not retry non-transient AS failures', () async {
    var attempts = 0;
    final client = AsGatewayClient(
      asUrl: 'http://as.test',
      agentToken: 'bad-token',
      maxRetries: 2,
      retryDelay: Duration.zero,
      httpClient: MockClient((request) async {
        attempts += 1;
        return http.Response(jsonEncode({'message': 'invalid token'}), 401);
      }),
    );

    await expectLater(client.listRooms(), throwsA(isA<AsGatewayException>()));
    expect(attempts, 1);
  });

  test('turns request timeouts into typed gateway errors', () async {
    final client = AsGatewayClient(
      asUrl: 'http://as.test',
      agentToken: 'agent-token',
      timeout: const Duration(milliseconds: 5),
      maxRetries: 0,
      httpClient: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(jsonEncode({'rooms': []}), 200);
      }),
    );

    await expectLater(
      client.listRooms(),
      throwsA(
        isA<AsGatewayException>()
            .having((e) => e.statusCode, 'statusCode', 504),
      ),
    );
  });
}

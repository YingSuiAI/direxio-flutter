import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/matrix_message_search_client.dart';

void main() {
  test('search posts Matrix room_events search and parses results', () async {
    final matrix = Client(
      'MatrixSearchTest',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://example.com/_matrix/client/v3/search',
        );
        expect(request.headers['Authorization'], 'Bearer matrix-token');
        expect(jsonDecode(request.body), {
          'search_categories': {
            'room_events': {
              'search_term': 'hello',
              'keys': ['content.body'],
              'order_by': 'recent',
              'event_context': {
                'before_limit': 0,
                'after_limit': 0,
                'include_profile': true,
              },
              'limit': 10,
              'filter': {
                'rooms': ['!room:example.com'],
              },
            },
          },
        });
        return http.Response(
          jsonEncode({
            'search_categories': {
              'room_events': {
                'results': [
                  {
                    'result': {
                      'event_id': r'$event',
                      'room_id': '!room:example.com',
                      'sender': '@alice:example.com',
                      'origin_server_ts': 1781930400000,
                      'content': {
                        'msgtype': 'm.text',
                        'body': 'hello world',
                      },
                    },
                  },
                  {
                    'result': {
                      'event_id': r'$empty',
                      'room_id': '!room:example.com',
                      'content': {'body': ''},
                    },
                  },
                ],
              },
            },
          }),
          200,
        );
      }),
    )
      ..homeserver = Uri.parse('https://example.com')
      ..accessToken = 'matrix-token';

    final results = await MatrixMessageSearchClient(matrix).search(
      ' hello ',
      roomId: ' !room:example.com ',
      limit: 10,
    );

    expect(results, hasLength(1));
    expect(results.single.eventId, r'$event');
    expect(results.single.roomId, '!room:example.com');
    expect(results.single.senderId, '@alice:example.com');
    expect(results.single.body, 'hello world');
    expect(results.single.messageType, MessageTypes.Text);
    expect(
      results.single.timestamp.toUtc().toIso8601String(),
      '2026-06-20T04:40:00.000Z',
    );
  });

  test('search returns empty for blank query without network request',
      () async {
    final matrix = Client(
      'MatrixSearchBlankTest',
      httpClient: MockClient((_) async {
        fail('request should not be sent for a blank query');
      }),
    )
      ..homeserver = Uri.parse('https://example.com')
      ..accessToken = 'matrix-token';

    final results = await MatrixMessageSearchClient(matrix).search('   ');

    expect(results, isEmpty);
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_app/data/matrix_token_refreshing_http_client.dart';

void main() {
  test('refreshes Matrix access token and retries authenticated request',
      () async {
    var calls = 0;
    final client = MatrixTokenRefreshingHttpClient(
      inner: MockClient((request) async {
        calls += 1;
        if (calls == 1) {
          expect(request.headers['authorization'], 'Bearer old-token');
          return http.Response(
            jsonEncode({
              'errcode': 'M_UNKNOWN_TOKEN',
              'error': 'Unknown token',
            }),
            401,
          );
        }

        expect(request.headers['authorization'], 'Bearer new-token');
        expect(request.method, 'PUT');
        expect(request.body, '{"ok":true}');
        return http.Response('{"event_id":"\$event"}', 200);
      }),
    )..refreshAccessToken = () async => 'new-token';

    final request = http.Request(
      'PUT',
      Uri.parse(
          'https://example.com/_matrix/client/v3/rooms/!r/send/m.room.message/1'),
    )
      ..headers['authorization'] = 'Bearer old-token'
      ..headers['content-type'] = 'application/json'
      ..body = '{"ok":true}';

    final response = await client.send(request);
    final body = await response.stream.bytesToString();

    expect(response.statusCode, 200);
    expect(body, '{"event_id":"\$event"}');
    expect(calls, 2);
  });

  test('does not refresh non-Matrix requests', () async {
    var refreshes = 0;
    final client = MatrixTokenRefreshingHttpClient(
      inner: MockClient((_) async => http.Response('unauthorized', 401)),
    )..refreshAccessToken = () async {
        refreshes += 1;
        return 'new-token';
      };

    final request = http.Request(
      'GET',
      Uri.parse('https://example.com/_as/search'),
    )..headers['authorization'] = 'Bearer old-token';

    final response = await client.send(request);
    final body = await response.stream.bytesToString();

    expect(response.statusCode, 401);
    expect(body, 'unauthorized');
    expect(refreshes, 0);
  });

  test('retries Matrix media upload after transient header close', () async {
    var calls = 0;
    final client = MatrixTokenRefreshingHttpClient(
      uploadRetryDelay: Duration.zero,
      inner: MockClient((request) async {
        calls += 1;
        if (calls == 1) {
          throw http.ClientException(
            'Connection closed before full header was received',
            request.url,
          );
        }

        expect(request.method, 'POST');
        expect(request.url.path, '/_matrix/media/v3/upload');
        expect(request.headers['authorization'], 'Bearer token');
        expect(request.bodyBytes, [1, 2, 3, 4]);
        return http.Response('{"content_uri":"mxc://example/avatar"}', 200);
      }),
    );

    final request = http.Request(
      'POST',
      Uri.parse(
        'https://example.com/_matrix/media/v3/upload?filename=avatar.png',
      ),
    )
      ..headers['authorization'] = 'Bearer token'
      ..headers['content-type'] = 'image/png'
      ..bodyBytes = [1, 2, 3, 4];

    final response = await client.send(request);
    final body = await response.stream.bytesToString();

    expect(response.statusCode, 200);
    expect(body, '{"content_uri":"mxc://example/avatar"}');
    expect(calls, 2);
  });

  test('does not retry non-upload Matrix post after transient close', () async {
    var calls = 0;
    final client = MatrixTokenRefreshingHttpClient(
      uploadRetryDelay: Duration.zero,
      inner: MockClient((request) async {
        calls += 1;
        throw http.ClientException(
          'Connection closed before full header was received',
          request.url,
        );
      }),
    );

    final request = http.Request(
      'POST',
      Uri.parse(
        'https://example.com/_matrix/client/v3/rooms/!r/send/m.room.message/1',
      ),
    )
      ..headers['authorization'] = 'Bearer token'
      ..headers['content-type'] = 'application/json'
      ..body = '{"body":"hello"}';

    await expectLater(
        client.send(request), throwsA(isA<http.ClientException>()));
    expect(calls, 1);
  });
}

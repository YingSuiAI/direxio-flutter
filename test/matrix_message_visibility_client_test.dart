import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/matrix_message_visibility_client.dart';

void main() {
  test('hideEvents posts Matrix local_delete event_ids body', () async {
    final matrix = Client(
      'MatrixLocalDeleteHideTest',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://example.com/_matrix/client/v1/io.direxio/rooms/'
          '!room%3Aexample.com/local_delete',
        );
        expect(request.headers['Authorization'], 'Bearer matrix-token');
        expect(jsonDecode(request.body), {
          'event_ids': [r'$event1', r'$event2'],
        });
        return http.Response(
          jsonEncode({
            'room_id': '!room:example.com',
            'hidden_event_ids': [r'$event1', r'$event2'],
            'through_stream_pos': 123,
          }),
          200,
        );
      }),
    )
      ..homeserver = Uri.parse('https://example.com')
      ..accessToken = 'matrix-token';

    final result = await MatrixMessageVisibilityClient(matrix).hideEvents(
      roomId: ' !room:example.com ',
      eventIds: const [r' $event1 ', '', r'$event2'],
    );

    expect(result.roomId, '!room:example.com');
    expect(result.hiddenEventIds, [r'$event1', r'$event2']);
    expect(result.clear, isFalse);
    expect(result.throughStreamPos, 123);
  });

  test('clearRoom posts Matrix local_delete clear body', () async {
    final matrix = Client(
      'MatrixLocalDeleteClearTest',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://example.com/_matrix/client/v1/io.direxio/rooms/'
          '!room%3Aexample.com/local_delete',
        );
        expect(jsonDecode(request.body), {'clear': true});
        return http.Response(
          jsonEncode({
            'room_id': '!room:example.com',
            'clear': true,
          }),
          200,
        );
      }),
    )
      ..homeserver = Uri.parse('https://example.com')
      ..accessToken = 'matrix-token';

    final result = await MatrixMessageVisibilityClient(matrix).clearRoom(
      ' !room:example.com ',
    );

    expect(result.roomId, '!room:example.com');
    expect(result.clear, isTrue);
  });

  test('hideEvents rejects an empty event list before network request',
      () async {
    final matrix = Client(
      'MatrixLocalDeleteEmptyTest',
      httpClient: MockClient((_) async {
        fail('request should not be sent for empty event_ids');
      }),
    )
      ..homeserver = Uri.parse('https://example.com')
      ..accessToken = 'matrix-token';

    expect(
      () => MatrixMessageVisibilityClient(matrix).hideEvents(
        roomId: '!room:example.com',
        eventIds: const [' ', ''],
      ),
      throwsA(isA<MatrixMessageVisibilityException>()),
    );
  });
}

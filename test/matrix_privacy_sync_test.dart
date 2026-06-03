import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/matrix_privacy_sync.dart';

void main() {
  test('baseline sync requests no timeline message bodies', () async {
    late Uri requestedUri;
    late String authorization;
    final service = MatrixPrivacySyncService(
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        authorization = request.headers['authorization'] ?? '';
        return http.Response(
          jsonEncode({
            'next_batch': 's123',
            'rooms': {
              'join': {
                '!room:example.com': {
                  'timeline': {
                    'events': [
                      {
                        'event_id': r'$should-not-be-used',
                        'content': {'body': 'read history'},
                      },
                    ],
                  },
                },
              },
            },
          }),
          200,
        );
      }),
    );

    final nextBatch = await service.establishBaseline(
      homeserver: Uri.parse('https://example.com'),
      accessToken: 'matrix-token',
    );

    expect(nextBatch, 's123');
    expect(requestedUri.path, '/_matrix/client/v3/sync');
    expect(requestedUri.queryParameters['timeout'], '0');
    expect(requestedUri.queryParameters['set_presence'], 'offline');
    expect(authorization, 'Bearer matrix-token');

    final filter = jsonDecode(requestedUri.queryParameters['filter']!)
        as Map<String, dynamic>;
    expect(filter['event_fields'], isNot(contains('content')));
    expect(filter['room']['timeline']['limit'], 0);
    expect(
      filter['room']['timeline']['not_types'],
      containsAll(['m.room.message', 'm.room.encrypted', 'm.sticker']),
    );
  });

  test('baseline sync seeds Matrix SDK prevBatch before init', () async {
    final store = _FakeMatrixSessionSeedStore();
    final service = MatrixPrivacySyncService(
      httpClient: MockClient((_) async {
        return http.Response(jsonEncode({'next_batch': 's456'}), 200);
      }),
    );

    await service.establishAndSeed(
      homeserver: Uri.parse('https://example.com'),
      accessToken: 'matrix-token',
      userId: '@owner:example.com',
      deviceId: 'DEVICE',
      deviceName: 'PortalIM',
      seedStore: store,
    );

    expect(store.prevBatch, 's456');
    expect(store.userId, '@owner:example.com');
    expect(store.deviceId, 'DEVICE');
  });

  test('Matrix SDK session seed does not close active client database',
      () async {
    final database = _TrackingMatrixDatabase();
    final client = Client(
      'PortalIMTest',
      databaseBuilder: (_) async => database,
    );
    await client.init(
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );

    await MatrixSdkSessionSeedStore(client).seed(
      homeserver: Uri.parse('https://example.com'),
      accessToken: 'matrix-token',
      userId: '@owner:example.com',
      deviceId: 'DEVICE',
      deviceName: 'PortalIM',
      prevBatch: 's789',
    );

    expect(database.closed, isFalse);
    expect(database.client?['prev_batch'], 's789');
  });
}

class _FakeMatrixSessionSeedStore implements MatrixSessionSeedStore {
  String? prevBatch;
  String? userId;
  String? deviceId;

  @override
  Future<void> seed({
    required Uri homeserver,
    required String accessToken,
    required String userId,
    required String deviceId,
    required String deviceName,
    required String prevBatch,
  }) async {
    this.prevBatch = prevBatch;
    this.userId = userId;
    this.deviceId = deviceId;
  }
}

class _TrackingMatrixDatabase extends Fake implements DatabaseApi {
  Map<String, dynamic>? client;
  bool closed = false;

  @override
  Future<Map<String, dynamic>?> getClient(String name) async => client;

  @override
  Future<int> insertClient(
    String name,
    String homeserverUrl,
    String token,
    DateTime? tokenExpiresAt,
    String? refreshToken,
    String userId,
    String? deviceId,
    String? deviceName,
    String? prevBatch,
    String? olmAccount,
  ) async {
    client = {
      'client_id': 1,
      'name': name,
      'homeserver_url': homeserverUrl,
      'token': token,
      'user_id': userId,
      'device_id': deviceId,
      'device_name': deviceName,
      'prev_batch': prevBatch,
      'olm_account': olmAccount,
    };
    return 1;
  }

  @override
  Future<void> updateClient(
    String homeserverUrl,
    String token,
    DateTime? tokenExpiresAt,
    String? refreshToken,
    String userId,
    String? deviceId,
    String? deviceName,
    String? prevBatch,
    String? olmAccount,
  ) async {
    client = {
      ...?client,
      'homeserver_url': homeserverUrl,
      'token': token,
      'user_id': userId,
      'device_id': deviceId,
      'device_name': deviceName,
      'prev_batch': prevBatch,
      'olm_account': olmAccount,
    };
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

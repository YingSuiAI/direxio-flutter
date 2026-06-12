import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

import 'api_logger.dart';

class MatrixPrivacySyncException implements Exception {
  const MatrixPrivacySyncException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'MatrixPrivacySyncException($statusCode): $message';
}

abstract class MatrixSessionSeedStore {
  Future<void> seed({
    required Uri homeserver,
    required String accessToken,
    required String userId,
    required String deviceId,
    required String deviceName,
    required String prevBatch,
  });
}

class MatrixSdkSessionSeedStore implements MatrixSessionSeedStore {
  const MatrixSdkSessionSeedStore(this.client);

  final Client client;

  @override
  Future<void> seed({
    required Uri homeserver,
    required String accessToken,
    required String userId,
    required String deviceId,
    required String deviceName,
    required String prevBatch,
  }) async {
    final builder = client.databaseBuilder;
    if (builder == null) return;

    final activeDatabase = client.database;
    final database = activeDatabase ?? await builder(client);
    final shouldCloseDatabase = activeDatabase == null;
    try {
      final existing = await database.getClient(client.clientName);
      if (existing == null) {
        await database.insertClient(
          client.clientName,
          homeserver.toString(),
          accessToken,
          null,
          null,
          userId,
          deviceId,
          deviceName,
          prevBatch,
          null,
        );
      } else {
        await database.updateClient(
          homeserver.toString(),
          accessToken,
          null,
          null,
          userId,
          deviceId,
          deviceName,
          prevBatch,
          null,
        );
      }
    } finally {
      if (shouldCloseDatabase) {
        await database.close();
      }
    }
  }
}

class MatrixPrivacySyncService {
  const MatrixPrivacySyncService({required this.httpClient});

  final http.Client httpClient;

  Future<void> establishAndSeed({
    required Uri homeserver,
    required String accessToken,
    required String userId,
    required String deviceId,
    required String deviceName,
    required MatrixSessionSeedStore seedStore,
  }) async {
    final prevBatch = await establishBaseline(
      homeserver: homeserver,
      accessToken: accessToken,
    );
    await seedStore.seed(
      homeserver: homeserver,
      accessToken: accessToken,
      userId: userId,
      deviceId: deviceId,
      deviceName: deviceName,
      prevBatch: prevBatch,
    );
  }

  Future<String> establishBaseline({
    required Uri homeserver,
    required String accessToken,
  }) async {
    final uri = homeserver.resolveUri(
      Uri(
        path: '_matrix/client/v3/sync',
        queryParameters: {
          'timeout': '0',
          'set_presence': 'offline',
          'filter': jsonEncode(matrixPrivacyBaselineSyncFilterJson()),
        },
      ),
    );
    final stopwatch = Stopwatch()..start();
    late http.Response response;
    try {
      response = await httpClient.get(
        uri,
        headers: {'authorization': 'Bearer $accessToken'},
      );
    } catch (error, stackTrace) {
      stopwatch.stop();
      ApiLogger.failure(
        service: 'Matrix sync',
        method: 'GET',
        uri: uri,
        elapsed: stopwatch.elapsed,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
    stopwatch.stop();
    ApiLogger.response(
      service: 'Matrix sync',
      method: 'GET',
      uri: uri,
      statusCode: response.statusCode,
      elapsed: stopwatch.elapsed,
      responseBody: response.body,
    );
    if (response.statusCode != 200) {
      throw MatrixPrivacySyncException(
        'privacy baseline sync failed',
        statusCode: response.statusCode,
      );
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (error, stackTrace) {
      ApiLogger.failure(
        service: 'Matrix sync',
        method: 'DECODE',
        uri: uri,
        elapsed: Duration.zero,
        statusCode: response.statusCode,
        responseBody: response.body,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
    final nextBatch = json['next_batch'] as String?;
    if (nextBatch == null || nextBatch.isEmpty) {
      throw const MatrixPrivacySyncException(
        'privacy baseline sync did not return next_batch',
      );
    }
    return nextBatch;
  }
}

Map<String, Object?> matrixPrivacyBaselineSyncFilterJson() {
  return {
    'event_fields': ['event_id', 'type', 'sender', 'origin_server_ts'],
    'room': {
      'state': {
        'lazy_load_members': true,
      },
      'timeline': {
        'limit': 0,
        'lazy_load_members': true,
        'not_types': [
          EventTypes.Message,
          EventTypes.Encrypted,
          EventTypes.Sticker,
        ],
      },
    },
  };
}

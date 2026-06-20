import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

import 'api_logger.dart';

class MatrixMessageVisibilityException implements Exception {
  const MatrixMessageVisibilityException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    return statusCode == null
        ? 'MatrixMessageVisibilityException: $message'
        : 'MatrixMessageVisibilityException($statusCode): $message';
  }
}

class MatrixLocalDeleteResult {
  const MatrixLocalDeleteResult({
    required this.roomId,
    this.hiddenEventIds = const [],
    this.clear = false,
    this.throughStreamPos = 0,
  });

  final String roomId;
  final List<String> hiddenEventIds;
  final bool clear;
  final int throughStreamPos;

  factory MatrixLocalDeleteResult.fromJson(Map<String, dynamic> json) {
    return MatrixLocalDeleteResult(
      roomId: json['room_id'] as String? ?? '',
      hiddenEventIds: (json['hidden_event_ids'] as List? ?? const [])
          .whereType<String>()
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
      clear: json['clear'] == true,
      throughStreamPos: _parseInt(json['through_stream_pos']),
    );
  }
}

class MatrixMessageVisibilityClient {
  MatrixMessageVisibilityClient(this._client);

  final Client _client;

  static const _timeout = Duration(seconds: 10);

  Future<MatrixLocalDeleteResult> hideEvents({
    required String roomId,
    required Iterable<String> eventIds,
  }) {
    final ids = eventIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) {
      throw const MatrixMessageVisibilityException('event_ids is required');
    }
    return _postLocalDelete(
      roomId: roomId,
      body: {'event_ids': ids},
    );
  }

  Future<MatrixLocalDeleteResult> clearRoom(String roomId) {
    return _postLocalDelete(
      roomId: roomId,
      body: const {'clear': true},
    );
  }

  Future<MatrixLocalDeleteResult> _postLocalDelete({
    required String roomId,
    required Map<String, Object?> body,
  }) async {
    final trimmedRoomId = roomId.trim();
    if (trimmedRoomId.isEmpty) {
      throw const MatrixMessageVisibilityException('room_id is required');
    }
    final uri = _matrixClientUri(
      _client,
      '/_matrix/client/v1/io.direxio/rooms/'
      '${Uri.encodeComponent(trimmedRoomId)}/local_delete',
    );
    final token = _client.accessToken?.trim() ?? '';
    if (token.isEmpty) {
      throw const MatrixMessageVisibilityException(
        'Matrix access token is not initialized',
      );
    }
    final requestBody = jsonEncode(body);
    final stopwatch = Stopwatch()..start();
    late final http.Response response;
    try {
      response = await _client.httpClient
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: requestBody,
            encoding: utf8,
          )
          .timeout(_timeout);
    } catch (error, stackTrace) {
      stopwatch.stop();
      ApiLogger.failure(
        service: 'Matrix local delete',
        method: 'POST',
        uri: uri,
        elapsed: stopwatch.elapsed,
        requestBody: requestBody,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
    stopwatch.stop();
    ApiLogger.response(
      service: 'Matrix local delete',
      method: 'POST',
      uri: uri,
      statusCode: response.statusCode,
      elapsed: stopwatch.elapsed,
      requestBody: requestBody,
      responseBody: response.body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MatrixMessageVisibilityException(
        _matrixErrorMessage(response.body),
        statusCode: response.statusCode,
      );
    }
    if (response.body.trim().isEmpty) {
      return MatrixLocalDeleteResult(roomId: trimmedRoomId);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw MatrixMessageVisibilityException(
        'Matrix local delete returned a non-object JSON response',
        statusCode: response.statusCode,
      );
    }
    return MatrixLocalDeleteResult.fromJson(decoded.cast<String, dynamic>());
  }
}

Uri _matrixClientUri(Client client, String path) {
  final homeserver = client.homeserver;
  if (homeserver == null) {
    throw const MatrixMessageVisibilityException(
      'Matrix homeserver is not initialized',
    );
  }
  return homeserver.replace(path: path.startsWith('/') ? path : '/$path');
}

String _matrixErrorMessage(String body) {
  if (body.trim().isEmpty) return 'Matrix request failed';
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is String && error.trim().isNotEmpty) return error.trim();
      final errcode = decoded['errcode'];
      if (errcode is String && errcode.trim().isNotEmpty) return errcode.trim();
    }
  } catch (_) {
    return body;
  }
  return body;
}

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

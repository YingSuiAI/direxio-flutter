import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

import 'api_logger.dart';

class MatrixMessageSearchException implements Exception {
  const MatrixMessageSearchException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    return statusCode == null
        ? 'MatrixMessageSearchException: $message'
        : 'MatrixMessageSearchException($statusCode): $message';
  }
}

class MatrixMessageSearchResult {
  const MatrixMessageSearchResult({
    required this.eventId,
    required this.roomId,
    required this.senderId,
    required this.body,
    required this.timestamp,
    this.messageType = MessageTypes.Text,
  });

  final String eventId;
  final String roomId;
  final String senderId;
  final String body;
  final DateTime timestamp;
  final String messageType;
}

class MatrixMessageSearchClient {
  MatrixMessageSearchClient(this._client);

  final Client _client;

  static const _timeout = Duration(seconds: 12);

  Future<List<MatrixMessageSearchResult>> search(
    String query, {
    String? roomId,
    Iterable<String> roomIds = const [],
    int limit = 20,
  }) async {
    final searchTerm = query.trim();
    if (searchTerm.isEmpty) return const [];
    final rooms = <String>{
      if (roomId != null && roomId.trim().isNotEmpty) roomId.trim(),
      for (final id in roomIds)
        if (id.trim().isNotEmpty) id.trim(),
    }.toList(growable: false);
    final body = <String, Object?>{
      'search_categories': {
        'room_events': {
          'search_term': searchTerm,
          'keys': ['content.body'],
          'order_by': 'recent',
          'event_context': const {
            'before_limit': 0,
            'after_limit': 0,
            'include_profile': true,
          },
          if (limit > 0) 'limit': limit,
          if (rooms.isNotEmpty)
            'filter': {
              'rooms': rooms,
            },
        },
      },
    };
    final response = await _postSearch(body);
    final roomEvents = ((response['search_categories'] as Map?)
            ?.cast<String, dynamic>()['room_events'] as Map?)
        ?.cast<String, dynamic>();
    final rawResults = roomEvents?['results'] as List? ?? const [];
    return rawResults
        .whereType<Map>()
        .map((item) => _parseResult(item.cast<String, dynamic>()))
        .whereType<MatrixMessageSearchResult>()
        .take(limit <= 0 ? rawResults.length : limit)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _postSearch(Map<String, Object?> body) async {
    final uri = _matrixClientUri(_client, '/_matrix/client/v3/search');
    final token = _client.accessToken?.trim() ?? '';
    if (token.isEmpty) {
      throw const MatrixMessageSearchException(
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
        service: 'Matrix search',
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
      service: 'Matrix search',
      method: 'POST',
      uri: uri,
      statusCode: response.statusCode,
      elapsed: stopwatch.elapsed,
      requestBody: requestBody,
      responseBody: response.body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MatrixMessageSearchException(
        _matrixErrorMessage(response.body),
        statusCode: response.statusCode,
      );
    }
    if (response.body.trim().isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw MatrixMessageSearchException(
        'Matrix search returned a non-object JSON response',
        statusCode: response.statusCode,
      );
    }
    return decoded.cast<String, dynamic>();
  }
}

MatrixMessageSearchResult? _parseResult(Map<String, dynamic> item) {
  final event = (item['result'] as Map?)?.cast<String, dynamic>();
  if (event == null) return null;
  final content =
      (event['content'] as Map?)?.cast<String, dynamic>() ?? const {};
  final eventId = event['event_id'] as String? ?? '';
  final roomId = event['room_id'] as String? ?? '';
  final body = content['body'] as String? ?? '';
  if (eventId.trim().isEmpty || roomId.trim().isEmpty || body.trim().isEmpty) {
    return null;
  }
  return MatrixMessageSearchResult(
    eventId: eventId,
    roomId: roomId,
    senderId: event['sender'] as String? ?? '',
    body: body,
    messageType: content['msgtype'] as String? ?? MessageTypes.Text,
    timestamp: _parseMatrixTimestamp(event['origin_server_ts']),
  );
}

Uri _matrixClientUri(Client client, String path) {
  final homeserver = client.homeserver;
  if (homeserver == null) {
    throw const MatrixMessageSearchException(
      'Matrix homeserver is not initialized',
    );
  }
  return homeserver.replace(path: path.startsWith('/') ? path : '/$path');
}

DateTime _parseMatrixTimestamp(Object? value) {
  final millis = switch (value) {
    int v => v,
    num v => v.toInt(),
    String v => int.tryParse(v) ?? 0,
    _ => 0,
  };
  if (millis <= 0) return DateTime.now().toUtc();
  return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
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

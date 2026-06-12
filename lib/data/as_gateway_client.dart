import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_logger.dart';

class AsGatewayException implements Exception {
  AsGatewayException(this.message, {this.statusCode, this.payload});

  final String message;
  final int? statusCode;
  final Object? payload;

  @override
  String toString() =>
      statusCode == null ? message : 'AS Gateway $statusCode: $message';
}

class AsGatewayClient {
  AsGatewayClient({
    required this.asUrl,
    required this.agentToken,
    this.timeout = const Duration(seconds: 10),
    this.maxRetries = 2,
    this.retryDelay = const Duration(milliseconds: 250),
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String asUrl;
  final String agentToken;
  final Duration timeout;
  final int maxRetries;
  final Duration retryDelay;
  final http.Client _http;

  Future<Map<String, dynamic>> authProbe() async => {
        'as_url': asUrl,
        'auth_mode': 'bearer_agent_token',
        'token_loaded': agentToken.isNotEmpty,
      };

  Future<Map<String, dynamic>> listRooms() => _getJson('/api/rooms');

  Future<Map<String, dynamic>> readRoomMessages(
    String roomId, {
    int limit = 20,
    String? before,
  }) {
    return _getJson(
      '/api/rooms/${Uri.encodeComponent(roomId)}/messages',
      query: {'limit': '$limit', if (before != null) 'before': before},
    );
  }

  Future<Map<String, dynamic>> listRoomMembers(String roomId) {
    return _getJson('/api/rooms/${Uri.encodeComponent(roomId)}/members');
  }

  Future<Map<String, dynamic>> listContacts() => _getJson('/api/contacts');

  Future<Map<String, dynamic>> searchMessages(
    String query, {
    String? roomId,
    int limit = 20,
  }) {
    return _getJson(
      '/api/search',
      query: {
        'q': query,
        'limit': '$limit',
        if (roomId != null) 'room_id': roomId,
      },
    );
  }

  Future<Map<String, dynamic>> sendMessage(
    String roomId,
    String content, {
    String? replyTo,
  }) {
    final idempotencyKey = _newClientTxnId();
    return _postJson(
      '/api/rooms/${Uri.encodeComponent(roomId)}/send',
      body: {'content': content, if (replyTo != null) 'reply_to': replyTo},
      headers: {'Idempotency-Key': idempotencyKey},
    );
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _sendWithRetry(
      'GET',
      _uri(path, query: query),
      headers: _headers,
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String> headers = const {},
  }) async {
    final response = await _sendWithRetry(
      'POST',
      _uri(path),
      headers: {
        ..._headers,
        'Content-Type': 'application/json',
        ...headers,
      },
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $agentToken',
        'Accept': 'application/json',
      };

  Future<http.Response> _sendWithRetry(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
  }) async {
    final canRetry = method == 'GET' || headers.containsKey('Idempotency-Key');
    final attempts = canRetry ? maxRetries + 1 : 1;
    AsGatewayException? lastError;

    for (var attempt = 1; attempt <= attempts; attempt += 1) {
      try {
        final response = await _sendOnce(
          method,
          uri,
          headers: headers,
          body: body,
        );
        if (_shouldRetryStatus(response.statusCode) && attempt < attempts) {
          await _retryPause(attempt);
          continue;
        }
        return response;
      } on TimeoutException {
        lastError = AsGatewayException(
          'AS Gateway request timed out',
          statusCode: 504,
        );
      } on http.ClientException catch (e) {
        lastError = AsGatewayException(
          'AS Gateway network error: ${e.message}',
          statusCode: 503,
        );
      }

      if (attempt >= attempts) break;
      await _retryPause(attempt);
    }

    throw lastError ?? AsGatewayException('AS Gateway request failed');
  }

  Future<http.Response> _sendOnce(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
  }) async {
    final request = http.Request(method, uri);
    request.headers.addAll(headers);
    if (body != null) request.body = body;
    final stopwatch = Stopwatch()..start();
    try {
      final streamed = await _http.send(request).timeout(timeout);
      final response =
          await http.Response.fromStream(streamed).timeout(timeout);
      stopwatch.stop();
      ApiLogger.response(
        service: 'AS gateway',
        method: method,
        uri: uri,
        statusCode: response.statusCode,
        elapsed: stopwatch.elapsed,
        responseBody: response.body,
      );
      return response;
    } catch (error, stackTrace) {
      stopwatch.stop();
      ApiLogger.failure(
        service: 'AS gateway',
        method: method,
        uri: uri,
        elapsed: stopwatch.elapsed,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  bool _shouldRetryStatus(int statusCode) {
    return statusCode == 408 ||
        statusCode == 409 ||
        statusCode == 425 ||
        statusCode == 429 ||
        statusCode >= 500;
  }

  Future<void> _retryPause(int attempt) {
    final multiplier = 1 << (attempt - 1);
    final delay = retryDelay * multiplier;
    final clamped =
        delay > const Duration(seconds: 2) ? const Duration(seconds: 2) : delay;
    return Future<void>.delayed(clamped);
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    final base = Uri.parse(asUrl);
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final childPath = path.startsWith('/') ? path.substring(1) : path;
    final mergedPath = [if (basePath.isNotEmpty) basePath, childPath].join('/');

    return base.replace(
      path: mergedPath.startsWith('/') ? mergedPath : '/$mergedPath',
      queryParameters: query?.isEmpty ?? true ? null : query,
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    final Object? payload;
    try {
      payload = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (error, stackTrace) {
      final exception = AsGatewayException(
        'AS Gateway returned invalid JSON',
        statusCode: response.statusCode,
        payload: response.body,
      );
      ApiLogger.failure(
        service: 'AS gateway',
        method: 'DECODE',
        uri: response.request?.url ?? Uri(),
        elapsed: Duration.zero,
        statusCode: response.statusCode,
        responseBody: response.body,
        error: exception,
        stackTrace: stackTrace,
      );
      throw exception;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body =
          payload is Map<String, dynamic> ? payload : <String, dynamic>{};
      throw AsGatewayException(
        body['message'] as String? ??
            body['error'] as String? ??
            'AS Gateway request failed',
        statusCode: response.statusCode,
        payload: payload,
      );
    }

    if (payload is! Map<String, dynamic>) {
      final exception = AsGatewayException(
        'AS Gateway returned a non-object JSON response',
        statusCode: response.statusCode,
        payload: payload,
      );
      ApiLogger.failure(
        service: 'AS gateway',
        method: 'DECODE',
        uri: response.request?.url ?? Uri(),
        elapsed: Duration.zero,
        statusCode: response.statusCode,
        responseBody: response.body,
        error: exception,
      );
      throw exception;
    }
    return payload;
  }

  String _newClientTxnId() {
    return 'client-${DateTime.now().microsecondsSinceEpoch}';
  }
}

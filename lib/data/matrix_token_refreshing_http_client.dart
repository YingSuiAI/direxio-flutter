import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_logger.dart';

const _logFullTokens = bool.fromEnvironment('PORTAL_LOG_FULL_TOKENS');

class MatrixTokenRefreshingHttpClient extends http.BaseClient {
  MatrixTokenRefreshingHttpClient({
    http.Client? inner,
    this.uploadMaxRetries = 1,
    this.uploadRetryDelay = const Duration(milliseconds: 250),
  })  : assert(uploadMaxRetries >= 0),
        _inner = inner ?? http.Client();

  final http.Client _inner;
  final int uploadMaxRetries;
  final Duration uploadRetryDelay;
  Future<String?> Function()? refreshAccessToken;
  Future<void> Function()? onAuthenticationFailed;
  Future<String?>? _refreshInFlight;

  http.Client get innerClient => _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final retryRequest = _cloneRequest(request);
    final http.StreamedResponse response;
    final stopwatch = Stopwatch()..start();
    try {
      response = await _inner.send(request);
    } on http.ClientException catch (error, stackTrace) {
      stopwatch.stop();
      _logFailure(request, stopwatch.elapsed, error, stackTrace);
      return _retryTransientUpload(request, retryRequest, error, stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      stopwatch.stop();
      _logFailure(request, stopwatch.elapsed, error, stackTrace);
      return _retryTransientUpload(request, retryRequest, error, stackTrace);
    }
    stopwatch.stop();

    if (!_isMatrixRequest(response.request?.url ?? request.url)) {
      return response;
    }

    final responseBody = await response.stream.toBytes();
    _logResponse(request, response, stopwatch.elapsed, responseBody);

    if (response.statusCode != 401 ||
        retryRequest == null ||
        !_isMatrixRequest(response.request?.url ?? request.url) ||
        !_hasBearerAuth(retryRequest.headers)) {
      return _rebuildResponse(response, responseBody);
    }

    if (!_isTokenFailure(responseBody)) {
      return _rebuildResponse(response, responseBody);
    }

    final originalToken = _bearerToken(retryRequest.headers);
    ApiLogger.info(
      '[Matrix] access token refresh requested '
      'uri=${request.url} ${_tokenPreview('old_token', originalToken)}',
    );
    String? token;
    try {
      token = await _refreshOnce();
    } catch (error, stackTrace) {
      ApiLogger.failure(
        service: 'Matrix token refresh',
        method: request.method,
        uri: request.url,
        elapsed: Duration.zero,
        error: error,
        stackTrace: stackTrace,
        requestBody: _tokenPreview('old_token', originalToken),
      );
      await _notifyAuthenticationFailed();
      return _rebuildResponse(response, responseBody);
    }
    if (token == null || token.isEmpty) {
      ApiLogger.info(
        '[Matrix] access token refresh returned empty '
        'uri=${request.url} ${_tokenPreview('old_token', originalToken)}',
      );
      await _notifyAuthenticationFailed();
      return _rebuildResponse(response, responseBody);
    }

    ApiLogger.info(
      '[Matrix] access token refresh succeeded '
      'uri=${request.url} '
      '${_tokenPreview('old_token', originalToken)} '
      '${_tokenPreview('new_token', token)} '
      'changed=${originalToken != token}',
    );
    _setBearerAuth(retryRequest.headers, token);
    return _sendRetry(retryRequest, notifyAuthenticationFailed: true);
  }

  Future<http.StreamedResponse> _sendRetry(
    http.BaseRequest request, {
    bool notifyAuthenticationFailed = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _inner.send(request);
      stopwatch.stop();
      if (!_isMatrixRequest(response.request?.url ?? request.url)) {
        return response;
      }
      final responseBody = await response.stream.toBytes();
      _logResponse(request, response, stopwatch.elapsed, responseBody);
      if (notifyAuthenticationFailed &&
          response.statusCode == 401 &&
          _isTokenFailure(responseBody)) {
        await _notifyAuthenticationFailed();
      }
      return _rebuildResponse(response, responseBody);
    } on http.ClientException catch (error, stackTrace) {
      stopwatch.stop();
      _logFailure(request, stopwatch.elapsed, error, stackTrace);
      rethrow;
    } on TimeoutException catch (error, stackTrace) {
      stopwatch.stop();
      _logFailure(request, stopwatch.elapsed, error, stackTrace);
      rethrow;
    }
  }

  Future<http.StreamedResponse> _retryTransientUpload(
    http.BaseRequest originalRequest,
    http.BaseRequest? retryRequest,
    Object error,
    StackTrace stackTrace,
  ) async {
    if (uploadMaxRetries == 0 ||
        retryRequest == null ||
        !_isMatrixMediaUpload(originalRequest.url)) {
      Error.throwWithStackTrace(error, stackTrace);
    }

    http.BaseRequest? nextRequest = retryRequest;
    Object lastError = error;
    StackTrace lastStackTrace = stackTrace;
    for (var attempt = 0; attempt < uploadMaxRetries; attempt += 1) {
      if (uploadRetryDelay > Duration.zero) {
        await Future<void>.delayed(uploadRetryDelay);
      }
      final request = nextRequest;
      if (request == null) break;
      nextRequest = _cloneRequest(request);
      try {
        return await _inner.send(request);
      } on http.ClientException catch (retryError, retryStackTrace) {
        lastError = retryError;
        lastStackTrace = retryStackTrace;
      } on TimeoutException catch (retryError, retryStackTrace) {
        lastError = retryError;
        lastStackTrace = retryStackTrace;
      }
      if (nextRequest == null) break;
    }

    Error.throwWithStackTrace(lastError, lastStackTrace);
  }

  Future<String?> _refreshOnce() {
    final callback = refreshAccessToken;
    if (callback == null) return Future.value(null);
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final future = callback();
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  Future<void> _notifyAuthenticationFailed() async {
    final callback = onAuthenticationFailed;
    if (callback == null) return;
    try {
      await callback();
    } catch (error, stackTrace) {
      ApiLogger.failure(
        service: 'Matrix auth failure',
        method: 'CALLBACK',
        uri: Uri.parse('matrix://local/auth-failure'),
        elapsed: Duration.zero,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  http.BaseRequest? _cloneRequest(http.BaseRequest request) {
    if (request is! http.Request) return null;
    final clone = http.Request(request.method, request.url)
      ..bodyBytes = request.bodyBytes
      ..encoding = request.encoding
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
    clone.headers.addAll(request.headers);
    return clone;
  }

  bool _isMatrixRequest(Uri uri) => uri.path.startsWith('/_matrix/');

  bool _isMatrixMediaUpload(Uri uri) => uri.path == '/_matrix/media/v3/upload';

  bool _hasBearerAuth(Map<String, String> headers) {
    return headers.entries.any(
      (entry) =>
          entry.key.toLowerCase() == 'authorization' &&
          entry.value.toLowerCase().startsWith('bearer '),
    );
  }

  void _setBearerAuth(Map<String, String> headers, String token) {
    String? existingKey;
    for (final key in headers.keys) {
      if (key.toLowerCase() == 'authorization') {
        existingKey = key;
        break;
      }
    }
    headers[existingKey ?? 'authorization'] = 'Bearer $token';
  }

  String _bearerToken(Map<String, String> headers) {
    String authorization = '';
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        authorization = entry.value;
        break;
      }
    }
    if (!authorization.toLowerCase().startsWith('bearer ')) return '';
    return authorization.substring(7).trim();
  }

  String _tokenPreview(String label, String? token) {
    final value = token ?? '';
    final tail = value.length <= 6 ? value : value.substring(value.length - 6);
    return '${label}_length=${value.length} '
        '${label}_tail=${value.isEmpty ? '<none>' : tail}'
        '${_logFullTokens && value.isNotEmpty ? ' $label=$value' : ''}';
  }

  bool _isTokenFailure(List<int> body) {
    try {
      final decoded = jsonDecode(utf8.decode(body));
      if (decoded is! Map<String, dynamic>) return false;
      final errcode = decoded['errcode'] as String?;
      return errcode == 'M_UNKNOWN_TOKEN' || errcode == 'M_MISSING_TOKEN';
    } catch (_) {
      return false;
    }
  }

  http.StreamedResponse _rebuildResponse(
    http.StreamedResponse response,
    List<int> body,
  ) {
    return http.StreamedResponse(
      Stream.value(body),
      response.statusCode,
      contentLength: body.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  void _logResponse(
    http.BaseRequest request,
    http.StreamedResponse response,
    Duration elapsed,
    List<int> body,
  ) {
    ApiLogger.response(
      service: 'Matrix',
      method: request.method,
      uri: response.request?.url ?? request.url,
      statusCode: response.statusCode,
      elapsed: elapsed,
      requestBody: _authorizationPreview(request.headers),
      responseBody: _responseBodyPreview(response, body),
    );
  }

  String _authorizationPreview(Map<String, String> headers) {
    String authorization = '';
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        authorization = entry.value;
        break;
      }
    }
    final hasBearer = authorization.toLowerCase().startsWith('bearer ');
    final token = hasBearer ? authorization.substring(7).trim() : '';
    return 'authorization_present=${authorization.isNotEmpty} '
        'bearer=$hasBearer ${_tokenPreview('token', token)}';
  }

  String _responseBodyPreview(http.StreamedResponse response, List<int> body) {
    final uri = response.request?.url;
    final contentType = response.headers.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == 'content-type',
          orElse: () => const MapEntry('content-type', ''),
        )
        .value
        .toLowerCase();
    final isMediaDownload =
        uri != null && uri.path.startsWith('/_matrix/media/');
    final isTextLike = contentType.contains('json') ||
        contentType.startsWith('text/') ||
        contentType.contains('xml');
    if (!isTextLike || isMediaDownload) {
      final label = contentType.trim().isEmpty ? 'unknown' : contentType.trim();
      return '<binary ${body.length} bytes content-type=$label>';
    }
    return utf8.decode(body, allowMalformed: true);
  }

  void _logFailure(
    http.BaseRequest request,
    Duration elapsed,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!_isMatrixRequest(request.url)) return;
    ApiLogger.failure(
      service: 'Matrix',
      method: request.method,
      uri: request.url,
      elapsed: elapsed,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

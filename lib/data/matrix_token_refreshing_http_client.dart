import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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
  Future<String?>? _refreshInFlight;

  http.Client get innerClient => _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final retryRequest = _cloneRequest(request);
    final http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } on http.ClientException catch (error, stackTrace) {
      return _retryTransientUpload(request, retryRequest, error, stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      return _retryTransientUpload(request, retryRequest, error, stackTrace);
    }

    if (response.statusCode != 401 ||
        retryRequest == null ||
        !_isMatrixRequest(response.request?.url ?? request.url) ||
        !_hasBearerAuth(retryRequest.headers)) {
      return response;
    }

    final responseBody = await response.stream.toBytes();
    if (!_isTokenFailure(responseBody)) {
      return _rebuildResponse(response, responseBody);
    }

    String? token;
    try {
      token = await _refreshOnce();
    } catch (_) {
      return _rebuildResponse(response, responseBody);
    }
    if (token == null || token.isEmpty) {
      return _rebuildResponse(response, responseBody);
    }

    _setBearerAuth(retryRequest.headers, token);
    return _inner.send(retryRequest);
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
    final existingKey = headers.keys.cast<String?>().firstWhere(
          (key) => key?.toLowerCase() == 'authorization',
          orElse: () => null,
        );
    headers[existingKey ?? 'authorization'] = 'Bearer $token';
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

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

import 'dart:developer' as developer;

class ApiLogger {
  const ApiLogger._();

  static void response({
    required String service,
    required String method,
    required Uri uri,
    required int statusCode,
    required Duration elapsed,
    String? responseBody,
  }) {
    final ok = statusCode >= 200 && statusCode < 300;
    final message = _format(
      service: service,
      method: method,
      uri: uri,
      statusCode: statusCode,
      elapsed: elapsed,
      responseBody: responseBody,
    );
    developer.log(
      message,
      name: 'portal.api',
      level: ok ? 800 : 1000,
    );
  }

  static void failure({
    required String service,
    required String method,
    required Uri uri,
    required Duration elapsed,
    required Object error,
    StackTrace? stackTrace,
    String? responseBody,
    int? statusCode,
  }) {
    developer.log(
      _format(
        service: service,
        method: method,
        uri: uri,
        statusCode: statusCode,
        elapsed: elapsed,
        error: error,
        responseBody: responseBody,
      ),
      name: 'portal.api',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static String _format({
    required String service,
    required String method,
    required Uri uri,
    required Duration elapsed,
    int? statusCode,
    Object? error,
    String? responseBody,
  }) {
    final status = statusCode == null ? 'ERR' : statusCode.toString();
    final parts = [
      '[$service]',
      method,
      _redactUri(uri),
      '->',
      status,
      '${elapsed.inMilliseconds}ms',
    ];
    if (error != null) parts.add('error=$error');
    final preview = _preview(responseBody);
    if (preview != null) parts.add('body=$preview');
    return parts.join(' ');
  }

  static String _redactUri(Uri uri) {
    if (uri.queryParameters.isEmpty) return uri.toString();
    final redacted = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      redacted[entry.key] =
          _isSensitiveKey(entry.key) ? '<redacted>' : entry.value;
    }
    return uri.replace(queryParameters: redacted).toString();
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase();
    return normalized.contains('token') ||
        normalized.contains('secret') ||
        normalized.contains('password') ||
        normalized.contains('key') ||
        normalized == 'access_token';
  }

  static String? _preview(String? body) {
    final trimmed = body?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    const maxLength = 600;
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}...';
  }
}

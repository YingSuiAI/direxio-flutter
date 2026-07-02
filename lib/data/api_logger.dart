import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

enum ApiLogKind { info, response, failure }

typedef ApiLogSink = void Function(ApiLogRecord record);

final Object _apiLogSinkZoneKey = Object();

class ApiLogRecord {
  const ApiLogRecord({
    required this.kind,
    required this.message,
    required this.level,
    this.service,
    this.method,
    this.uri,
    this.statusCode,
    this.elapsed,
    this.error,
    this.stackTrace,
    this.apiName,
    this.requestBody,
    this.responseBody,
  });

  final ApiLogKind kind;
  final String message;
  final int level;
  final String? service;
  final String? method;
  final Uri? uri;
  final int? statusCode;
  final Duration? elapsed;
  final Object? error;
  final StackTrace? stackTrace;
  final String? apiName;
  final String? requestBody;
  final String? responseBody;
}

class ApiLogger {
  const ApiLogger._();

  static R runWithSink<R>(ApiLogSink sink, R Function() body) {
    return runZoned<R>(
      body,
      zoneValues: {_apiLogSinkZoneKey: sink},
    );
  }

  static void info(String message) {
    _emit(
      ApiLogRecord(
        kind: ApiLogKind.info,
        message: message,
        level: 800,
      ),
    );
    developer.log(
      message,
      name: 'portal.api',
      level: 800,
    );
  }

  static void response({
    required String service,
    required String method,
    required Uri uri,
    required int statusCode,
    required Duration elapsed,
    String? apiName,
    String? requestBody,
    String? responseBody,
  }) {
    final ok = statusCode >= 200 && statusCode < 300;
    final message = _format(
      service: service,
      method: method,
      uri: uri,
      statusCode: statusCode,
      elapsed: elapsed,
      apiName: apiName,
      requestBody: requestBody,
      responseBody: responseBody,
    );
    final level = ok ? 800 : 1000;
    _emit(
      ApiLogRecord(
        kind: ApiLogKind.response,
        message: message,
        level: level,
        service: service,
        method: method,
        uri: uri,
        statusCode: statusCode,
        elapsed: elapsed,
        apiName: apiName,
        requestBody: requestBody,
        responseBody: responseBody,
      ),
    );
    developer.log(
      message,
      name: 'portal.api',
      level: level,
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
    String? requestBody,
    String? apiName,
    int? statusCode,
  }) {
    final message = _format(
      service: service,
      method: method,
      uri: uri,
      statusCode: statusCode,
      elapsed: elapsed,
      error: error,
      apiName: apiName,
      requestBody: requestBody,
      responseBody: responseBody,
    );
    _emit(
      ApiLogRecord(
        kind: ApiLogKind.failure,
        message: message,
        level: 1000,
        service: service,
        method: method,
        uri: uri,
        statusCode: statusCode,
        elapsed: elapsed,
        error: error,
        stackTrace: stackTrace,
        apiName: apiName,
        requestBody: requestBody,
        responseBody: responseBody,
      ),
    );
    developer.log(
      message,
      name: 'portal.api',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _emit(ApiLogRecord record) {
    final sink = Zone.current[_apiLogSinkZoneKey];
    if (sink is ApiLogSink) {
      sink(record);
    }
  }

  static String _format({
    required String service,
    required String method,
    required Uri uri,
    required Duration elapsed,
    int? statusCode,
    Object? error,
    String? apiName,
    String? requestBody,
    String? responseBody,
  }) {
    final status = statusCode == null ? 'ERR' : statusCode.toString();
    final resolvedApiName = apiName?.trim().isNotEmpty == true
        ? apiName!.trim()
        : _apiNameFromUri(uri);
    final parts = [
      '[$service]',
      'api=$resolvedApiName',
      method,
      _redactUri(uri),
      '->',
      status,
      '${elapsed.inMilliseconds}ms',
    ];
    if (error != null) parts.add('error=$error');
    final requestPreview = _previewRequestBody(requestBody);
    if (requestPreview != null) parts.add('params=$requestPreview');
    final responsePreview = _previewResponseBody(responseBody);
    if (responsePreview != null) parts.add('result=$responsePreview');
    return parts.join(' ');
  }

  static String _apiNameFromUri(Uri uri) {
    final path = uri.path.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (path.isEmpty) return uri.host;
    return path.replaceAll('/', '.');
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

  static String? _previewRequestBody(String? body) {
    final trimmed = body?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      final params = _actionParamsPreview(decoded);
      if (params != null) return _preview(jsonEncode(params));
      return _preview(jsonEncode(_redactSensitiveJson(decoded)));
    } catch (_) {
      return _preview(trimmed);
    }
  }

  static String? _previewResponseBody(String? body) {
    final trimmed = body?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    try {
      return _preview(jsonEncode(_redactSensitiveJson(jsonDecode(trimmed))));
    } catch (_) {
      return _preview(trimmed);
    }
  }

  static Object? _actionParamsPreview(Object? value) {
    if (value is Map &&
        value.containsKey('action') &&
        value['params'] != null) {
      return _redactSensitiveJson(value['params']);
    }
    return null;
  }

  static Object? _redactSensitiveJson(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _isSensitiveKey(entry.key.toString())
              ? '<redacted>'
              : _redactSensitiveJson(entry.value),
      };
    }
    if (value is List) {
      return [for (final item in value) _redactSensitiveJson(item)];
    }
    return value;
  }
}

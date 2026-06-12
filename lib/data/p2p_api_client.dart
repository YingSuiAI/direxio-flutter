import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'api_logger.dart';
import 'as_client.dart';

class P2pApiException implements Exception {
  P2pApiException(this.message, {this.statusCode, this.payload});

  final String message;
  final int? statusCode;
  final Object? payload;

  @override
  String toString() =>
      statusCode == null ? message : 'P2P API $statusCode: $message';
}

class P2pApiClient {
  P2pApiClient({
    required this.baseUri,
    this.biSecret = '',
    this.timeout = const Duration(seconds: 10),
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final Uri baseUri;
  final String biSecret;
  final Duration timeout;
  final http.Client _http;
  final Random _random = Random.secure();

  Future<void> reportBiEvent({
    required String deviceNo,
    required String eventType,
    required String phoneModel,
    required int reportTime,
    Map<String, Object?> payload = const {},
  }) async {
    final body = jsonEncode({
      'deviceNo': deviceNo,
      'eventType': eventType,
      'payload': payload,
      'phoneModel': phoneModel,
      'reportTime': reportTime,
    });
    final nonce = _nonce();
    final signature = _md5Hex('$biSecret\n$nonce\n$body');
    final uri = _resolve('/bi/events/report');
    final response = await _send(
      'POST',
      uri,
      () => _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-BI-Nonce': nonce,
              'X-BI-Signature': signature,
            },
            body: body,
          )
          .timeout(timeout),
    );
    _ensureSuccess(response);
  }

  Future<List<AsChannel>> listChannels({
    int page = 1,
    int pageSize = 10,
    String ownerDomain = '',
    String keyword = '',
    String sortBy = 'createdAt',
    bool desc = true,
  }) async {
    final uri = _resolve(
      '/im/channel/list',
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        if (ownerDomain.trim().isNotEmpty) 'ownerDomain': ownerDomain.trim(),
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
        if (sortBy.trim().isNotEmpty) 'sortBy': sortBy.trim(),
        'desc': desc.toString(),
      },
    );
    final response = await _send(
      'GET',
      uri,
      () => _http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(timeout),
    );
    final decoded = _decodeObject(response);
    return _parseChannelList(decoded);
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Future<http.Response> Function() send,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await send();
      stopwatch.stop();
      ApiLogger.response(
        service: 'P2P API',
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
        service: 'P2P API',
        method: method,
        uri: uri,
        elapsed: stopwatch.elapsed,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Uri _resolve(String path, {Map<String, String>? queryParameters}) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final childPath = path.startsWith('/') ? path.substring(1) : path;
    final mergedPath = [if (basePath.isNotEmpty) basePath, childPath].join('/');
    return baseUri.replace(
      path: mergedPath.startsWith('/') ? mergedPath : '/$mergedPath',
      queryParameters:
          queryParameters?.isEmpty ?? true ? null : queryParameters,
    );
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    _ensureSuccess(response);
    if (response.body.trim().isEmpty) return const {};
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (error, stackTrace) {
      ApiLogger.failure(
        service: 'P2P API',
        method: 'DECODE',
        uri: response.request?.url ?? Uri(),
        elapsed: Duration.zero,
        statusCode: response.statusCode,
        responseBody: response.body,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
    if (decoded is! Map<String, dynamic>) {
      final exception = P2pApiException(
        'P2P API returned a non-object JSON response',
        statusCode: response.statusCode,
        payload: decoded,
      );
      ApiLogger.failure(
        service: 'P2P API',
        method: 'DECODE',
        uri: response.request?.url ?? Uri(),
        elapsed: Duration.zero,
        statusCode: response.statusCode,
        responseBody: response.body,
        error: exception,
      );
      throw exception;
    }
    return decoded;
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    Object? payload;
    try {
      payload = response.body.trim().isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      payload = response.body;
    }
    throw P2pApiException(
      _extractError(payload),
      statusCode: response.statusCode,
      payload: payload,
    );
  }

  String _nonce() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    final suffix = List<int>.generate(8, (_) => _random.nextInt(256));
    return '$micros-${base64UrlEncode(suffix).replaceAll('=', '')}';
  }
}

List<AsChannel> _parseChannelList(Map<String, dynamic> body) {
  final raw = _firstList(body, const [
    'list',
    'items',
    'records',
    'rows',
    'channels',
    'results',
  ]);
  return raw
      .whereType<Map>()
      .map((item) => _channelFromP2pJson(item.cast<String, dynamic>()))
      .toList(growable: false);
}

List<dynamic> _firstList(Map<String, dynamic> body, List<String> keys) {
  for (final key in keys) {
    final value = body[key];
    if (value is List) return value;
  }
  final data = body['data'];
  if (data is List) return data;
  if (data is Map) {
    return _firstList(data.cast<String, dynamic>(), keys);
  }
  return const [];
}

AsChannel _channelFromP2pJson(Map<String, dynamic> json) {
  final channelDomain = _firstString(json, const [
    'channelDomain',
    'channel_domain',
    'domain',
    'handle',
  ]);
  final ownerDomain = _firstString(json, const [
    'ownerDomain',
    'owner_domain',
    'homeDomain',
    'home_domain',
  ]);
  final id = _firstString(json, const [
    'channelId',
    'channel_id',
    'id',
    'roomId',
    'room_id',
  ]);
  final effectiveId = id.isNotEmpty ? id : channelDomain;
  final name = _firstString(json, const [
    'name',
    'title',
    'channelName',
    'channel_name',
    'displayName',
    'display_name',
  ]);
  return AsChannel(
    channelId: effectiveId,
    roomId: _firstString(json, const ['roomId', 'room_id']),
    homeDomain: ownerDomain,
    name: name.isNotEmpty
        ? name
        : (channelDomain.isNotEmpty ? channelDomain : effectiveId),
    description: _firstString(json, const ['description', 'topic', 'summary']),
    avatarUrl: _firstString(json, const ['avatarUrl', 'avatar_url']),
    visibility: _firstString(json, const ['visibility']).isEmpty
        ? asChannelVisibilityPublic
        : _firstString(json, const ['visibility']),
    joinPolicy: _firstString(json, const ['joinPolicy', 'join_policy']).isEmpty
        ? asChannelJoinPolicyOpen
        : _firstString(json, const ['joinPolicy', 'join_policy']),
    commentsEnabled: json['commentsEnabled'] as bool? ??
        json['comments_enabled'] as bool? ??
        true,
    role: _firstString(json, const ['role']),
    memberStatus: _firstString(json, const ['memberStatus', 'member_status']),
    memberCount: _parseInt(json['memberCount'] ?? json['member_count']),
    tags: _parseTags(json['tags']),
    latestActivityAt: _parseDateTime(
      json['lastActivityAt'] ?? json['last_activity_at'] ?? json['createdAt'],
    ),
  );
}

String _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }
  return DateTime.tryParse(value.toString());
}

List<String> _parseTags(Object? value) {
  if (value is List) {
    return value
        .map((tag) => tag.toString().trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String) {
    return value
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

String _md5Hex(String input) => md5.convert(utf8.encode(input)).toString();

String _extractError(Object? payload) {
  if (payload is Map) {
    return (payload['message'] ?? payload['error'] ?? 'P2P API request failed')
        .toString();
  }
  return 'P2P API request failed';
}

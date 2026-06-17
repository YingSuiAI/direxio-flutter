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

  static const maxPublicImageBytes = 2 * 1024 * 1024;
  static const _publicImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
  };

  Future<void> reportBiEvent({
    required String deviceNo,
    required String eventType,
    required String phoneModel,
    required int reportTime,
    Map<String, Object?> payload = const {},
  }) async {
    final body = canonicalJson({
      'deviceNo': deviceNo,
      'eventType': eventType,
      'reportTime': reportTime,
      if (phoneModel.trim().isNotEmpty) 'phoneModel': phoneModel,
      if (payload.isNotEmpty) 'payload': payload,
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

  Future<ImPublicImageFile> uploadImage({
    required List<int> bytes,
    required String fileName,
  }) async {
    _validatePublicImage(bytes: bytes, fileName: fileName);
    final uri = _resolve('/im/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName.trim(),
        ),
      );
    final response = await _sendMultipart('POST', uri, request);
    final decoded = _decodeObject(response);
    final data = _unwrapData(decoded);
    final file = _firstMap(data, const ['file']);
    return ImPublicImageFile.fromJson(file);
  }

  Future<List<ImPublicTag>> listPublicTags() async {
    final uri = _resolve('/im/tag/public/list');
    final response = await _send(
      'GET',
      uri,
      () => _http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(timeout),
    );
    final decoded = _decodeObject(response);
    final data = _unwrapData(decoded);
    return _firstList(data, const ['list'])
        .whereType<Map>()
        .map((item) => ImPublicTag.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<ImChannelPage> listChannelPage({
    int page = 1,
    int pageSize = 10,
    int status = 1,
    String ownerDomain = '',
    String keyword = '',
    String sortBy = 'createdAt',
    bool desc = false,
  }) async {
    final uri = _resolve(
      '/im/channel/list',
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        'status': status.toString(),
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
    final data = _unwrapData(decoded);
    return ImChannelPage.fromJson(data);
  }

  Future<List<AsChannel>> listChannels({
    int page = 1,
    int pageSize = 10,
    String ownerDomain = '',
    String keyword = '',
    String sortBy = 'createdAt',
    bool desc = true,
  }) async {
    final channelPage = await listChannelPage(
      page: page,
      pageSize: pageSize,
      status: 1,
      ownerDomain: ownerDomain,
      keyword: keyword,
      sortBy: sortBy,
      desc: desc,
    );
    return channelPage.channels;
  }

  Future<void> joinChannel({
    required String channelDomain,
    required String roomId,
    int? tagId,
  }) async {
    await _requestJson(
      'POST',
      '/im/channel/join',
      body: {
        'channelDomain': channelDomain.trim(),
        'room_id': roomId.trim(),
        if (tagId != null) 'tagId': tagId,
      },
    );
  }

  Future<int> getReportCount({
    required String reportedDomain,
    int targetType = 1,
  }) async {
    final uri = _resolve(
      '/im/report/count',
      queryParameters: {
        'reportedDomain': reportedDomain.trim(),
        'targetType': targetType.toString(),
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
    final data = _unwrapData(decoded);
    return _parseInt(data['count']);
  }

  Future<Map<String, dynamic>> submitReport({
    required String reporterDomain,
    required String reportedDomain,
    required String reason,
    int targetType = 1,
    List<String> images = const [],
  }) {
    return _requestJson(
      'POST',
      '/im/report',
      body: {
        'reporterDomain': reporterDomain.trim(),
        'reportedDomain': reportedDomain.trim(),
        'targetType': targetType,
        'reason': reason.trim(),
        if (images.isNotEmpty)
          'images': images.map((image) => image.trim()).toList(growable: false),
      },
    );
  }

  Future<Map<String, dynamic>> submitReportMultipart({
    required String reporterDomain,
    required String reportedDomain,
    required String reason,
    int targetType = 1,
    List<String> images = const [],
    List<ImPublicImageUploadPart> files = const [],
  }) async {
    for (final file in files) {
      _validatePublicImage(bytes: file.bytes, fileName: file.fileName);
    }
    final uri = _resolve('/im/report');
    final request = http.MultipartRequest('POST', uri)
      ..fields['reporterDomain'] = reporterDomain.trim()
      ..fields['reportedDomain'] = reportedDomain.trim()
      ..fields['targetType'] = targetType.toString()
      ..fields['reason'] = reason.trim();
    final normalizedImages = images
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList(growable: false);
    if (normalizedImages.length == 1) {
      request.fields['images'] = normalizedImages.single;
    } else if (normalizedImages.isNotEmpty) {
      request.fields['images'] = jsonEncode(normalizedImages);
    }
    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          file.bytes,
          filename: file.fileName.trim(),
        ),
      );
    }
    final response = await _sendMultipart('POST', uri, request);
    return _unwrapData(_decodeObject(response));
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    required Map<String, Object?> body,
  }) async {
    final uri = _resolve(path);
    final rawBody = jsonEncode(body);
    final response = await _send(
      method,
      uri,
      () => _http
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: rawBody,
          )
          .timeout(timeout),
    );
    return _unwrapData(_decodeObject(response));
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

  Future<http.Response> _sendMultipart(
    String method,
    Uri uri,
    http.MultipartRequest request,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final streamed = await _http.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
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

  void _validatePublicImage({
    required List<int> bytes,
    required String fileName,
  }) {
    if (bytes.length > maxPublicImageBytes) {
      throw P2pApiException('Image must be 2MB or smaller');
    }
    final extension = _extension(fileName);
    if (!_publicImageExtensions.contains(extension)) {
      throw P2pApiException('Unsupported image type: $extension');
    }
  }
}

class ImPublicImageFile {
  const ImPublicImageFile({
    required this.url,
    required this.fileName,
    required this.size,
  });

  final String url;
  final String fileName;
  final int size;

  factory ImPublicImageFile.fromJson(Map<String, dynamic> json) {
    return ImPublicImageFile(
      url: _firstString(json, const ['url']),
      fileName: _firstString(json, const ['fileName', 'file_name', 'name']),
      size: _parseInt(json['size']),
    );
  }
}

class ImPublicImageUploadPart {
  const ImPublicImageUploadPart({
    required this.bytes,
    required this.fileName,
  });

  final List<int> bytes;
  final String fileName;
}

class ImPublicTag {
  const ImPublicTag({
    required this.id,
    required this.name,
    required this.color,
    required this.status,
    required this.sort,
  });

  final int id;
  final String name;
  final String color;
  final int status;
  final int sort;

  factory ImPublicTag.fromJson(Map<String, dynamic> json) {
    return ImPublicTag(
      id: _parseInt(json['ID'] ?? json['id']),
      name: _firstString(json, const ['name']),
      color: _firstString(json, const ['color']),
      status: _parseInt(json['status']),
      sort: _parseInt(json['sort']),
    );
  }
}

class ImChannelPage {
  const ImChannelPage({
    required this.channels,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<AsChannel> channels;
  final int total;
  final int page;
  final int pageSize;

  factory ImChannelPage.fromJson(Map<String, dynamic> json) {
    final raw = _firstList(json, const [
      'list',
      'items',
      'records',
      'rows',
      'channels',
      'results',
    ]);
    return ImChannelPage(
      channels: raw
          .whereType<Map>()
          .map((item) => _channelFromP2pJson(item.cast<String, dynamic>()))
          .toList(growable: false),
      total: _parseInt(json['total']),
      page: _parseInt(json['page']),
      pageSize: _parseInt(json['pageSize'] ?? json['page_size']),
    );
  }
}

class ImPublicChannel {
  const ImPublicChannel({
    required this.channel,
    required this.raw,
  });

  final AsChannel channel;
  final Map<String, dynamic> raw;

  factory ImPublicChannel.fromJson(Map<String, dynamic> json) {
    final source = _firstMap(json, const ['channel']);
    return ImPublicChannel(
      channel: _channelFromP2pJson(source.isEmpty ? json : source),
      raw: json,
    );
  }
}

Map<String, dynamic> _unwrapData(Map<String, dynamic> body) {
  final code = body['code'];
  if (code != null && _parseInt(code) != 0) {
    throw P2pApiException(
      (body['msg'] ?? body['message'] ?? 'P2P API request failed').toString(),
      payload: body,
    );
  }
  final data = body['data'];
  if (data is Map) return data.cast<String, dynamic>();
  return body;
}

Map<String, dynamic> _firstMap(Map<String, dynamic> body, List<String> keys) {
  for (final key in keys) {
    final value = body[key];
    if (value is Map) return value.cast<String, dynamic>();
  }
  return const {};
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
  final detail = _firstMap(json, const [
    'channelDetail',
    'channel_detail',
    'detail',
  ]);
  String pick(List<String> keys) {
    final detailValue = _firstString(detail, keys);
    if (detailValue.isNotEmpty) return detailValue;
    return _firstString(json, keys);
  }

  final channelDomain = _firstString(json, const [
    'channelDomain',
    'channel_domain',
    'domain',
    'handle',
  ]);
  final ownerDomain = pick(const [
    'ownerDomain',
    'owner_domain',
    'homeDomain',
    'home_domain',
  ]);
  final id = pick(const [
    'channelId',
    'channel_id',
    'id',
    'roomId',
    'room_id',
  ]);
  final effectiveId = id.isNotEmpty ? id : channelDomain;
  final roomId = pick(const ['roomId', 'room_id']);
  final name = pick(const [
    'name',
    'title',
    'channelName',
    'channel_name',
    'displayName',
    'display_name',
  ]);
  final visibility = pick(const ['visibility']);
  final joinPolicy = pick(const ['joinPolicy', 'join_policy']);
  final detailTags = _parseTags(detail['tags']);
  final tags = detailTags.isNotEmpty
      ? detailTags
      : _parseTags(json['tags'] ?? json['tag']);
  final memberCount = _parseInt(
    detail['memberCount'] ??
        detail['member_count'] ??
        json['memberCount'] ??
        json['member_count'] ??
        json['joinCount'],
  );
  return AsChannel(
    channelId: effectiveId,
    roomId: roomId,
    homeDomain: ownerDomain,
    name: name.isNotEmpty
        ? name
        : (channelDomain.isNotEmpty ? channelDomain : effectiveId),
    description: pick(const [
      'intro',
      'description',
      'topic',
      'summary',
    ]),
    avatarUrl: pick(const ['avatarUrl', 'avatar_url']),
    visibility: visibility.isEmpty ? asChannelVisibilityPublic : visibility,
    joinPolicy: joinPolicy.isEmpty ? asChannelJoinPolicyOpen : joinPolicy,
    commentsEnabled: detail['commentsEnabled'] as bool? ??
        detail['comments_enabled'] as bool? ??
        json['commentsEnabled'] as bool? ??
        json['comments_enabled'] as bool? ??
        true,
    channelType: normalizeAsChannelType(
      pick(const ['channelType', 'channel_type', 'type']),
    ),
    role: pick(const ['role']),
    memberStatus: pick(const ['memberStatus', 'member_status']),
    memberCount: memberCount,
    tags: tags,
    latestActivityAt: _parseDateTime(
      json['lastActivityAt'] ??
          json['last_activity_at'] ??
          json['lastJoinTime'] ??
          json['createdAt'],
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
  if (value is Map) {
    final name = _firstString(value.cast<String, dynamic>(), const ['name']);
    return name.isEmpty ? const [] : [name];
  }
  return const [];
}

String _extension(String fileName) {
  final normalized = fileName.trim().toLowerCase();
  final dot = normalized.lastIndexOf('.');
  if (dot == -1 || dot == normalized.length - 1) return '';
  return normalized.substring(dot + 1);
}

String canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return '{${keys.map((key) {
      return '${jsonEncode(key)}:${canonicalJson(value[key])}';
    }).join(',')}}';
  }
  if (value is Iterable) {
    return '[${value.map(canonicalJson).join(',')}]';
  }
  return jsonEncode(value);
}

String _md5Hex(String input) => md5.convert(utf8.encode(input)).toString();

String _extractError(Object? payload) {
  if (payload is Map) {
    return (payload['msg'] ??
            payload['message'] ??
            payload['error'] ??
            'P2P API request failed')
        .toString();
  }
  return 'P2P API request failed';
}

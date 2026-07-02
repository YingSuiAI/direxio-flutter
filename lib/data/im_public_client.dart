import 'dart:convert';

import 'package:http/http.dart' as http;

import 'as_client.dart';
import 'im_public_config.dart';

class ImPublicApiException implements Exception {
  ImPublicApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final int? code;

  @override
  String toString() => 'ImPublicApiException($statusCode/$code): $message';
}

class ImPublicClient {
  ImPublicClient({
    required Uri baseUri,
    required String secret,
    http.Client? httpClient,
  })  : _baseUri = _normalizeBaseUri(baseUri),
        _secret = secret.trim(),
        _http = httpClient ?? http.Client();

  final Uri _baseUri;
  final String _secret;
  final http.Client _http;

  Future<ImPublicUploadedFile> uploadImageBytes(
    List<int> bytes, {
    required String filename,
    String contentType = 'application/octet-stream',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _resolve('im/image/upload'),
    );
    request.headers.addAll(_signedHeaders('{}'));
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
    ));
    final response = await http.Response.fromStream(await _http.send(request));
    final data = _decodeEnvelope(response);
    return ImPublicUploadedFile.fromJson(
      (data['file'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<List<ImPublicTag>> listTags({String type = 'channel'}) async {
    final normalizedType = type.trim().isEmpty ? 'channel' : type.trim();
    final data = await _get(
      'im/tag/public/list',
      queryParameters: {'type': normalizedType},
    );
    final raw = data['list'] as List? ?? const [];
    return raw
        .whereType<Map>()
        .map((item) => ImPublicTag.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<ImPublicChannelPage> listChannels({
    int page = 1,
    int pageSize = 20,
    String name = '',
    int? tagId,
    String sortBy = 'member_count',
    bool desc = true,
  }) async {
    final data = await _get('im/channel/list', queryParameters: {
      'page': '$page',
      'page_size': '$pageSize',
      if (name.trim().isNotEmpty) 'name': name.trim(),
      if (tagId != null && tagId > 0) 'tag_id': '$tagId',
      if (sortBy.trim().isNotEmpty) 'sort_by': sortBy.trim(),
      'desc': desc.toString(),
    });
    return ImPublicChannelPage.fromJson(data);
  }

  Future<void> joinChannelDirectory({
    required String channelDomain,
    required String roomId,
    int? tagId,
  }) async {
    await _post('im/channel/join', {
      'channel_domain': channelDomain.trim(),
      'room_id': roomId.trim(),
      if (tagId != null && tagId > 0) 'tag_id': tagId,
    });
  }

  Future<void> rateChannel({
    required String uid,
    required String roomId,
    required int score,
  }) async {
    await _post('im/channel/rating', {
      'uid': uid.trim(),
      'room_id': roomId.trim(),
      'score': score,
    });
  }

  Future<void> closeChannelDirectory({
    required String roomId,
  }) async {
    await _post('im/channel/close', {
      'room_id': roomId.trim(),
    });
  }

  Future<int> getReportCount({
    required String reportedDomain,
    int targetType = 1,
  }) async {
    final data = await _get('im/report/count', queryParameters: {
      'reportedDomain': reportedDomain.trim(),
      'targetType': '$targetType',
    });
    return _parseInt(data['count']);
  }

  Future<void> submitReport({
    required String reporterDomain,
    required String reportedDomain,
    required String reason,
    int targetType = 1,
    List<ImPublicFilePart> files = const [],
  }) async {
    if (files.isNotEmpty) {
      final request = http.MultipartRequest('POST', _resolve('im/report'));
      request.headers.addAll(_signedHeaders('{}'));
      request.fields.addAll({
        'reporterDomain': reporterDomain.trim(),
        'reportedDomain': reportedDomain.trim(),
        'targetType': '$targetType',
        'reason': reason.trim(),
      });
      for (final file in files) {
        request.files.add(http.MultipartFile.fromBytes(
          'files',
          file.bytes,
          filename: file.filename,
        ));
      }
      final response =
          await http.Response.fromStream(await _http.send(request));
      _decodeEnvelope(response);
      return;
    }
    await _post('im/report', {
      'reporterDomain': reporterDomain.trim(),
      'reportedDomain': reportedDomain.trim(),
      'targetType': targetType,
      'reason': reason.trim(),
    });
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String> queryParameters = const {},
  }) async {
    final canonicalBody = canonicalImPublicJson(queryParameters);
    final response = await _http.get(
      _resolve(path, queryParameters: queryParameters),
      headers: _signedHeaders(canonicalBody),
    );
    return _decodeEnvelope(response);
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, Object?> body) async {
    final canonicalBody = canonicalImPublicJson(body);
    final response = await _http.post(
      _resolve(path),
      headers: _signedHeaders(
        canonicalBody,
        headers: {'content-type': 'application/json'},
      ),
      body: canonicalBody,
    );
    return _decodeEnvelope(response);
  }

  Map<String, String> _signedHeaders(
    String canonicalBody, {
    Map<String, String> headers = const {},
  }) {
    return signedImPublicHeaders(
      secret: _secret,
      canonicalBody: canonicalBody,
      headers: headers,
    );
  }

  Map<String, dynamic> _decodeEnvelope(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw ImPublicApiException(
        'Invalid IM public response',
        statusCode: response.statusCode,
      );
    }
    final map = decoded.cast<String, dynamic>();
    final code = _parseInt(map['code']);
    if (response.statusCode < 200 || response.statusCode >= 300 || code != 0) {
      throw ImPublicApiException(
        (map['msg'] as String?)?.trim().isNotEmpty == true
            ? (map['msg'] as String).trim()
            : 'IM public request failed',
        statusCode: response.statusCode,
        code: code,
      );
    }
    final data = map['data'];
    if (data is Map) return data.cast<String, dynamic>();
    return const {};
  }

  Uri _resolve(String path, {Map<String, String> queryParameters = const {}}) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final basePath =
        _baseUri.path.endsWith('/') ? _baseUri.path : '${_baseUri.path}/';
    final uri = _baseUri.replace(path: '$basePath$cleanPath');
    if (queryParameters.isEmpty) return uri;
    final merged = <String, String>{
      ...uri.queryParameters,
      ...queryParameters,
    };
    return uri.replace(queryParameters: merged);
  }

  static Uri _normalizeBaseUri(Uri baseUri) {
    final path =
        baseUri.path == '/' ? '' : baseUri.path.replaceAll(RegExp(r'/+$'), '');
    return baseUri.replace(path: path, queryParameters: const {});
  }
}

class ImPublicFilePart {
  const ImPublicFilePart({
    required this.filename,
    required this.bytes,
    this.contentType = 'application/octet-stream',
  });

  final String filename;
  final List<int> bytes;
  final String contentType;
}

class ImPublicUploadedFile {
  const ImPublicUploadedFile({
    required this.url,
    required this.fileName,
    required this.size,
  });

  final String url;
  final String fileName;
  final int size;

  factory ImPublicUploadedFile.fromJson(Map<String, dynamic> json) {
    return ImPublicUploadedFile(
      url: json['url'] as String? ?? '',
      fileName:
          json['fileName'] as String? ?? json['file_name'] as String? ?? '',
      size: _parseInt(json['size']),
    );
  }
}

class ImPublicTag {
  const ImPublicTag({
    required this.id,
    required this.name,
    this.icon = '',
    this.color = '',
    this.status = 0,
    this.sort = 0,
  });

  final int id;
  final String name;
  final String icon;
  final String color;
  final int status;
  final int sort;

  factory ImPublicTag.fromJson(Map<String, dynamic> json) {
    return ImPublicTag(
      id: _parseInt(json['ID'] ?? json['id']),
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      color: json['color'] as String? ?? '',
      status: _parseInt(json['status']),
      sort: _parseInt(json['sort']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (icon.trim().isNotEmpty) 'icon': icon,
      if (color.trim().isNotEmpty) 'color': color,
      if (status != 0) 'status': status,
      if (sort != 0) 'sort': sort,
    };
  }
}

class ImPublicChannelPage {
  const ImPublicChannelPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<ImPublicChannelListing> items;
  final int total;
  final int page;
  final int pageSize;

  factory ImPublicChannelPage.fromJson(Map<String, dynamic> json) {
    final raw = json['list'] as List? ?? const [];
    return ImPublicChannelPage(
      items: raw
          .whereType<Map>()
          .map((item) => ImPublicChannelListing.fromJson(
                item.cast<String, dynamic>(),
              ))
          .toList(growable: false),
      total: _parseInt(json['total']),
      page: _parseInt(json['page']),
      pageSize: _parseInt(json['pageSize'] ?? json['page_size']),
    );
  }
}

class ImPublicChannelListing {
  const ImPublicChannelListing({
    required this.id,
    required this.channelDomain,
    required this.roomId,
    required this.ownerDomain,
    required this.intro,
    required this.channel,
    required this.tagId,
    required this.tag,
    required this.status,
    required this.syncStatus,
    required this.failureCount,
    required this.reportCount,
    required this.joinCount,
    required this.lastJoinTime,
  });

  final int id;
  final String channelDomain;
  final String roomId;
  final String ownerDomain;
  final String intro;
  final AsChannel channel;
  final int tagId;
  final ImPublicTag? tag;
  final int status;
  final int syncStatus;
  final int failureCount;
  final int reportCount;
  final int joinCount;
  final DateTime? lastJoinTime;

  factory ImPublicChannelListing.fromJson(Map<String, dynamic> json) {
    final detail = {
      ...json,
      ...((json['channelDetail'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{}),
    };
    return ImPublicChannelListing(
      id: _parseInt(json['ID'] ?? json['id']),
      channelDomain: json['channel_domain'] as String? ??
          json['channelDomain'] as String? ??
          '',
      roomId: json['room_id'] as String? ?? '',
      ownerDomain: json['ownerDomain'] as String? ??
          json['owner_domain'] as String? ??
          json['channel_domain'] as String? ??
          json['channelDomain'] as String? ??
          '',
      intro: json['intro'] as String? ?? json['description'] as String? ?? '',
      channel: AsChannel.fromJson(detail),
      tagId: _parseInt(json['tag_id'] ?? json['tagId']),
      tag: json['tag'] is Map
          ? ImPublicTag.fromJson((json['tag'] as Map).cast<String, dynamic>())
          : null,
      status: _parseInt(json['status']),
      syncStatus: _parseInt(json['sync_status'] ?? json['syncStatus']),
      failureCount: _parseInt(json['failure_count'] ?? json['failureCount']),
      reportCount: _parseInt(json['report_count'] ?? json['reportCount']),
      joinCount: _parseInt(json['join_count'] ?? json['joinCount']),
      lastJoinTime:
          _parseDateTime(json['last_join_time'] ?? json['lastJoinTime']),
    );
  }
}

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim());
}

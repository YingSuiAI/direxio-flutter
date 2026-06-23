import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class BiAnalyticsService {
  BiAnalyticsService({
    Future<void> Function(BiAnalyticsEvent event)? reporter,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    bool enabled = true,
  })  : _reporter = reporter,
        _storage = storage,
        _enabled = enabled;

  final Future<void> Function(BiAnalyticsEvent event)? _reporter;
  final FlutterSecureStorage _storage;
  final bool _enabled;

  static const _deviceNoKey = 'p2p_bi_device_no';
  static const _installReportedKey = 'p2p_bi_install_reported';

  Future<void> reportInstallAndLaunch() async {
    if (!_enabled) return;
    final installReported = await _storage.read(key: _installReportedKey);
    if (installReported != 'true') {
      await _report('install', payload: await _basePayload(page: '/install'));
      await _storage.write(key: _installReportedKey, value: 'true');
    }
    await reportLaunch();
  }

  Future<void> reportLaunch() async {
    if (!_enabled) return;
    await _report('launch', payload: await _basePayload(page: '/home'));
  }

  Future<void> reportLogin({String homeserver = '', String userId = ''}) async {
    if (!_enabled) return;
    await _report(
      'login',
      payload: {
        ...await _basePayload(page: '/login'),
        if (homeserver.trim().isNotEmpty) 'homeserver': homeserver.trim(),
        if (userId.trim().isNotEmpty) 'userId': userId.trim(),
      },
    );
  }

  Future<void> _report(
    String eventType, {
    Map<String, Object?> payload = const {},
  }) async {
    if (!_enabled) return;
    final reporter = _reporter;
    if (reporter == null) return;
    await reporter(BiAnalyticsEvent(
      deviceNo: await _deviceNo(),
      eventType: eventType,
      phoneModel: _phoneModel(),
      reportTime: DateTime.now().millisecondsSinceEpoch,
      payload: payload,
    ));
  }

  Future<Map<String, Object?>> _basePayload({required String page}) async {
    final info = await PackageInfo.fromPlatform();
    return {
      'appVersion': info.version,
      'buildNumber': info.buildNumber,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'page': page,
    };
  }

  Future<String> _deviceNo() async {
    final existing = await _storage.read(key: _deviceNoKey);
    if (existing != null && existing.trim().isNotEmpty) return existing;
    final created = 'p2p-${DateTime.now().microsecondsSinceEpoch}';
    await _storage.write(key: _deviceNoKey, value: created);
    return created;
  }

  String _phoneModel() {
    if (kIsWeb) return 'web';
    return 'flutter-${defaultTargetPlatform.name}';
  }
}

class BiAnalyticsEvent {
  const BiAnalyticsEvent({
    required this.deviceNo,
    required this.eventType,
    required this.phoneModel,
    required this.reportTime,
    required this.payload,
  });

  final String deviceNo;
  final String eventType;
  final String phoneModel;
  final int reportTime;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() {
    return {
      'eventType': eventType,
      'deviceNo': deviceNo,
      if (phoneModel.trim().isNotEmpty) 'phoneModel': phoneModel,
      'reportTime': reportTime,
      if (payload.isNotEmpty) 'payload': payload,
    };
  }
}

void reportBiInBackground(Future<void> Function() task) {
  unawaited(task().catchError((Object _) {}));
}

class HttpBiAnalyticsReporter {
  HttpBiAnalyticsReporter({
    required Uri baseUri,
    required String secret,
    http.Client? httpClient,
  })  : _baseUri = _normalizeBaseUri(baseUri),
        _secret = secret.trim(),
        _http = httpClient ?? http.Client();

  final Uri _baseUri;
  final String _secret;
  final http.Client _http;

  Future<void> call(BiAnalyticsEvent event) async {
    if (_secret.isEmpty) return;
    final nonce = '${DateTime.now().microsecondsSinceEpoch}-'
        '${event.deviceNo.hashCode.toUnsigned(32)}';
    final body = canonicalBiJson(event.toJson());
    final signature = buildBiSignature(
      secret: _secret,
      nonce: nonce,
      canonicalBody: body,
    );
    final response = await _http.post(
      _resolve('bi/events/report'),
      headers: {
        'content-type': 'application/json',
        'X-BI-Nonce': nonce,
        'X-BI-Signature': signature,
      },
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('BI report failed: HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map && decoded['code'] != null && decoded['code'] != 0) {
      throw StateError(
          'BI report failed: ${decoded['msg'] ?? decoded['code']}');
    }
  }

  Uri _resolve(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final basePath =
        _baseUri.path.endsWith('/') ? _baseUri.path : '${_baseUri.path}/';
    return _baseUri.replace(path: '$basePath$cleanPath');
  }

  static Uri _normalizeBaseUri(Uri baseUri) {
    final path =
        baseUri.path == '/' ? '' : baseUri.path.replaceAll(RegExp(r'/+$'), '');
    return baseUri.replace(path: path, queryParameters: const {});
  }
}

String buildBiSignature({
  required String secret,
  required String nonce,
  required String canonicalBody,
}) {
  final input = '$secret\n$nonce\n$canonicalBody';
  return md5.convert(utf8.encode(input)).toString();
}

String canonicalBiJson(Object? value) {
  if (value is Map) {
    final entries = value.entries
        .where((entry) => entry.key != null)
        .map((entry) => MapEntry(entry.key.toString(), entry.value))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return '{${entries.map((entry) {
      return '${jsonEncode(entry.key)}:${canonicalBiJson(entry.value)}';
    }).join(',')}}';
  }
  if (value is Iterable) {
    return '[${value.map(canonicalBiJson).join(',')}]';
  }
  return jsonEncode(value);
}

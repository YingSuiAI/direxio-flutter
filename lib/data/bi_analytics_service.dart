import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'p2p_api_client.dart';

class BiAnalyticsService {
  BiAnalyticsService({
    required P2pApiClient apiClient,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  })  : _apiClient = apiClient,
        _storage = storage;

  final P2pApiClient _apiClient;
  final FlutterSecureStorage _storage;

  static const _deviceNoKey = 'p2p_bi_device_no';
  static const _installReportedKey = 'p2p_bi_install_reported';

  Future<void> reportInstallAndLaunch() async {
    final installReported = await _storage.read(key: _installReportedKey);
    if (installReported != 'true') {
      await _report('install', payload: await _basePayload(page: '/install'));
      await _storage.write(key: _installReportedKey, value: 'true');
    }
    await reportLaunch();
  }

  Future<void> reportLaunch() async {
    await _report('launch', payload: await _basePayload(page: '/home'));
  }

  Future<void> reportLogin({String homeserver = '', String userId = ''}) async {
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
    await _apiClient.reportBiEvent(
      deviceNo: await _deviceNo(),
      eventType: eventType,
      phoneModel: _phoneModel(),
      reportTime: DateTime.now().millisecondsSinceEpoch,
      payload: payload,
    );
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

void reportBiInBackground(Future<void> Function() task) {
  unawaited(task().catchError((Object _) {}));
}

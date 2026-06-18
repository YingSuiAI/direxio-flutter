import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
}

void reportBiInBackground(Future<void> Function() task) {
  unawaited(task().catchError((Object _) {}));
}

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

const direxioMatrixPusherAppId = 'io.direxio.app.android';
const direxioAndroidPackageName = 'com.direxio.ai';
const direxioPushGatewayUrl = String.fromEnvironment(
  'DIREXIO_PUSH_GATEWAY_URL',
  defaultValue: 'https://push.direxio.ai/_matrix/push/v1/notify',
);

const _storedPushTokenKey = 'matrix_push.fcm_token';
const _storedPushUserIdKey = 'matrix_push.user_id';

bool get matrixPushGatewayConfigured {
  return isAllowedMatrixPushGatewayUrl(direxioPushGatewayUrl);
}

bool isAllowedMatrixPushGatewayUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null ||
      uri.host.isEmpty ||
      !uri.path.endsWith('/_matrix/push/v1/notify')) {
    return false;
  }
  if (uri.scheme == 'https') return true;
  return uri.scheme == 'http' && _isLocalDevelopmentHost(uri.host);
}

bool get androidFcmMatrixPushSupported {
  return !kIsWeb && Platform.isAndroid;
}

Future<void> registerAndroidFcmMatrixPusher({
  required Client client,
  required String fcmToken,
}) async {
  if (!androidFcmMatrixPushSupported) return;
  final token = fcmToken.trim();
  if (token.isEmpty) return;
  final userId = client.userID?.trim() ?? '';
  if (userId.isEmpty || client.accessToken?.trim().isEmpty != false) return;
  final gatewayUrl = direxioPushGatewayUrl.trim();
  final gatewayUri = Uri.tryParse(gatewayUrl);
  if (gatewayUri == null || !isAllowedMatrixPushGatewayUrl(gatewayUrl)) {
    debugPrint(
      'Matrix push gateway URL must be HTTPS or a local development HTTP host; '
      'pusher not registered',
    );
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final previousToken = prefs.getString(_storedPushTokenKey)?.trim() ?? '';
  final previousUserId = prefs.getString(_storedPushUserIdKey)?.trim() ?? '';
  if (previousToken.isNotEmpty &&
      previousToken != token &&
      previousUserId == userId) {
    await _deleteMatrixPusher(client, previousToken);
  }

  await client.postPusher(
    Pusher(
      appId: direxioMatrixPusherAppId,
      pushkey: token,
      appDisplayName: 'Direxio',
      deviceDisplayName: _deviceDisplayName(client),
      kind: 'http',
      lang: PlatformDispatcher.instance.locale.toLanguageTag(),
      data: PusherData(
        format: 'event_id_only',
        url: gatewayUri,
        additionalProperties: {
          'provider': 'fcm',
          'platform': 'android',
          'package_name': direxioAndroidPackageName,
          if (client.deviceID?.trim().isNotEmpty == true)
            'matrix_device_id': client.deviceID!.trim(),
          'timezone': DateTime.now().timeZoneName,
        },
      ),
      profileTag: client.deviceID?.trim().isNotEmpty == true
          ? client.deviceID!.trim()
          : null,
    ),
    append: false,
  );
  await prefs.setString(_storedPushTokenKey, token);
  await prefs.setString(_storedPushUserIdKey, userId);
}

bool _isLocalDevelopmentHost(String host) {
  final normalized = host.toLowerCase();
  if (normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '10.0.2.2') {
    return true;
  }
  final parts = normalized.split('.');
  if (parts.length != 4) return false;
  final octets = parts.map(int.tryParse).toList();
  if (octets.any((octet) => octet == null || octet < 0 || octet > 255)) {
    return false;
  }
  final first = octets[0]!;
  final second = octets[1]!;
  if (first == 10) return true;
  if (first == 192 && second == 168) return true;
  if (first == 172 && second >= 16 && second <= 31) return true;
  return false;
}

Future<void> unregisterStoredAndroidFcmMatrixPusher(Client client) async {
  if (!androidFcmMatrixPushSupported) return;
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(_storedPushTokenKey)?.trim() ?? '';
  if (token.isNotEmpty && client.accessToken?.trim().isNotEmpty == true) {
    await _deleteMatrixPusher(client, token);
  }
  await prefs.remove(_storedPushTokenKey);
  await prefs.remove(_storedPushUserIdKey);
}

Future<void> _deleteMatrixPusher(Client client, String token) async {
  await client.deletePusher(
    PusherId(
      appId: direxioMatrixPusherAppId,
      pushkey: token,
    ),
  );
}

String _deviceDisplayName(Client client) {
  final deviceId = client.deviceID?.trim() ?? '';
  if (deviceId.isEmpty) return 'Android device';
  return 'Android $deviceId';
}

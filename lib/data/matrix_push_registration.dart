import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

const direxioAndroidPackageName = 'com.direxio.ai';
const direxioPushGatewayUrl = String.fromEnvironment(
  'DIREXIO_PUSH_GATEWAY_URL',
  defaultValue: '',
);

const _storedPushAppIdKey = 'matrix_push.app_id';
const _storedPushTokenKey = 'matrix_push.token';
const _storedPushUserIdKey = 'matrix_push.user_id';

class MatrixPusherProfile {
  const MatrixPusherProfile({
    required this.appId,
    required this.provider,
    required this.platform,
    required this.deviceDisplayPrefix,
    this.packageName,
  });

  final String appId;
  final String provider;
  final String platform;
  final String deviceDisplayPrefix;
  final String? packageName;
}

const direxioAndroidFcmPusherProfile = MatrixPusherProfile(
  appId: 'io.direxio.app.android',
  provider: 'fcm',
  platform: 'android',
  deviceDisplayPrefix: 'Android',
  packageName: direxioAndroidPackageName,
);

const direxioIosApnsPusherProfile = MatrixPusherProfile(
  appId: 'io.direxio.app.ios',
  provider: 'apns',
  platform: 'ios',
  deviceDisplayPrefix: 'iOS',
);

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

bool get matrixPushSupported {
  return currentMatrixPusherProfile != null;
}

MatrixPusherProfile? get currentMatrixPusherProfile {
  if (kIsWeb) return null;
  if (Platform.isAndroid) return direxioAndroidFcmPusherProfile;
  if (Platform.isIOS) return direxioIosApnsPusherProfile;
  return null;
}

Pusher buildDirexioMatrixHttpPusher({
  required MatrixPusherProfile profile,
  required String pushToken,
  required Uri gatewayUri,
  required String? matrixDeviceId,
  required String localeTag,
  required String timezoneName,
}) {
  final token = pushToken.trim();
  final deviceId = matrixDeviceId?.trim() ?? '';
  return Pusher(
    appId: profile.appId,
    pushkey: token,
    appDisplayName: 'Direxio',
    deviceDisplayName: _deviceDisplayName(profile, deviceId),
    kind: 'http',
    lang: localeTag,
    data: PusherData(
      format: 'event_id_only',
      url: gatewayUri,
      additionalProperties: {
        'provider': profile.provider,
        'platform': profile.platform,
        if (profile.packageName != null) 'package_name': profile.packageName,
        if (deviceId.isNotEmpty) 'matrix_device_id': deviceId,
        'timezone': timezoneName,
      },
    ),
    profileTag: deviceId.isNotEmpty ? deviceId : null,
  );
}

Future<void> registerMatrixPusher({
  required Client client,
  required MatrixPusherProfile profile,
  required String pushToken,
}) async {
  final token = pushToken.trim();
  if (token.isEmpty) {
    debugPrint('[push-registration] skip: empty ${profile.provider} token');
    return;
  }
  final userId = client.userID?.trim() ?? '';
  if (userId.isEmpty) {
    debugPrint('[push-registration] skip: Matrix user is not logged in');
    return;
  }
  if (client.accessToken?.trim().isEmpty != false) {
    debugPrint('[push-registration] skip: Matrix access token is missing');
    return;
  }
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
  final previousAppId = prefs.getString(_storedPushAppIdKey)?.trim() ?? '';
  final previousToken = prefs.getString(_storedPushTokenKey)?.trim() ?? '';
  final previousUserId = prefs.getString(_storedPushUserIdKey)?.trim() ?? '';
  final storedAppId = previousAppId.isNotEmpty ? previousAppId : profile.appId;
  if (previousToken.isNotEmpty && previousUserId == userId) {
    final tokenChanged = previousToken != token;
    final profileChanged = storedAppId != profile.appId;
    if (tokenChanged || profileChanged) {
      debugPrint(
        '[push-registration] deleting previous server Matrix pusher '
        'app_id=$storedAppId token=${_redactToken(previousToken)}',
      );
      await _deleteServerMatrixPusher(
        client,
        appId: storedAppId,
        token: previousToken,
      );
    }
  }

  debugPrint(
    '[push-registration] registering Matrix pusher '
    'app_id=${profile.appId} '
    'provider=${profile.provider} '
    'url=$gatewayUrl '
    'user_id=$userId '
    'device_id=${client.deviceID ?? ''} '
    'token=${_redactToken(token)}',
  );
  await client.postPusher(
    buildDirexioMatrixHttpPusher(
      profile: profile,
      pushToken: token,
      gatewayUri: gatewayUri,
      matrixDeviceId: client.deviceID,
      localeTag: PlatformDispatcher.instance.locale.toLanguageTag(),
      timezoneName: DateTime.now().timeZoneName,
    ),
    append: false,
  );
  await prefs.setString(_storedPushAppIdKey, profile.appId);
  await prefs.setString(_storedPushTokenKey, token);
  await prefs.setString(_storedPushUserIdKey, userId);
  debugPrint(
    '[push-registration] Matrix pusher registered '
    'app_id=${profile.appId} token=${_redactToken(token)}',
  );
}

Future<void> registerAndroidFcmMatrixPusher({
  required Client client,
  required String fcmToken,
}) async {
  if (!androidFcmMatrixPushSupported) {
    debugPrint('[push-registration] skip: not running on Android');
    return;
  }
  await registerMatrixPusher(
    client: client,
    profile: direxioAndroidFcmPusherProfile,
    pushToken: fcmToken,
  );
}

bool get iosApnsMatrixPushSupported {
  return !kIsWeb && Platform.isIOS;
}

Future<void> registerIosApnsMatrixPusher({
  required Client client,
  required String apnsToken,
}) async {
  if (!iosApnsMatrixPushSupported) {
    debugPrint('[push-registration] skip: not running on iOS');
    return;
  }
  await registerMatrixPusher(
    client: client,
    profile: direxioIosApnsPusherProfile,
    pushToken: apnsToken,
  );
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

Future<void> unregisterStoredMatrixPusher(Client client) async {
  final profile = currentMatrixPusherProfile;
  if (profile == null) {
    debugPrint('[push-registration] unregister skip: unsupported runtime');
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(_storedPushTokenKey)?.trim() ?? '';
  final appId = prefs.getString(_storedPushAppIdKey)?.trim() ?? profile.appId;
  if (token.isEmpty) {
    debugPrint('[push-registration] unregister skip: no stored push token');
    await prefs.remove(_storedPushAppIdKey);
    await prefs.remove(_storedPushTokenKey);
    await prefs.remove(_storedPushUserIdKey);
    return;
  }
  if (client.accessToken?.trim().isNotEmpty != true) {
    debugPrint(
      '[push-registration] server pusher unregister skipped: '
      'Matrix access token is missing app_id=$appId '
      'token=${_redactToken(token)}',
    );
    return;
  }
  debugPrint(
    '[push-registration] unregistering server Matrix pusher via '
    '/_matrix/client/v3/pushers/set kind=null '
    'app_id=$appId '
    'token=${_redactToken(token)}',
  );
  await _deleteServerMatrixPusher(
    client,
    appId: appId,
    token: token,
  );
  debugPrint(
    '[push-registration] server Matrix pusher unregistered '
    'app_id=$appId token=${_redactToken(token)}',
  );
  await prefs.remove(_storedPushAppIdKey);
  await prefs.remove(_storedPushTokenKey);
  await prefs.remove(_storedPushUserIdKey);
}

Future<void> unregisterStoredAndroidFcmMatrixPusher(Client client) async {
  if (!androidFcmMatrixPushSupported) {
    debugPrint('[push-registration] unregister skip: not running on Android');
    return;
  }
  await unregisterStoredMatrixPusher(client);
}

Future<void> _deleteServerMatrixPusher(
  Client client, {
  required String appId,
  required String token,
}) async {
  await client.deletePusher(
    PusherId(
      appId: appId,
      pushkey: token,
    ),
  );
}

String _deviceDisplayName(MatrixPusherProfile profile, String deviceId) {
  if (deviceId.isEmpty) return '${profile.deviceDisplayPrefix} device';
  return '${profile.deviceDisplayPrefix} $deviceId';
}

String _redactToken(String token) {
  final clean = token.trim();
  if (clean.length <= 12) return '<redacted:${clean.length}>';
  return '${clean.substring(0, 6)}...${clean.substring(clean.length - 6)}';
}

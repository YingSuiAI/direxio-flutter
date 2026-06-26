import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/matrix_push_registration.dart';
import 'package:portal_app/presentation/providers/push_notification_provider.dart';

void main() {
  final gatewayUri = Uri.parse(
    'https://push.direxio.ai/_matrix/push/v1/notify',
  );

  test('Direxio Android pusher constants match Firebase gateway config', () {
    expect(direxioAndroidFcmPusherProfile.appId, 'com.direxio.ai');
    expect(direxioAndroidPackageName, 'com.direxio.ai');
    expect(
      direxioPushGatewayUrl,
      'https://push.direxio.ai/_matrix/push/v1/notify',
    );
  });

  test('builds Android FCM Matrix HTTP pusher data', () {
    final pusher = buildDirexioMatrixHttpPusher(
      profile: direxioAndroidFcmPusherProfile,
      pushToken: ' fcm-token ',
      gatewayUri: gatewayUri,
      matrixDeviceId: 'DEVICE123',
      localeTag: 'zh-CN',
      timezoneName: 'CST',
    );

    expect(pusher.appId, 'com.direxio.ai');
    expect(pusher.pushkey, 'fcm-token');
    expect(pusher.kind, 'http');
    expect(pusher.lang, 'zh-CN');
    expect(pusher.profileTag, 'DEVICE123');
    expect(pusher.deviceDisplayName, 'Android DEVICE123');
    expect(pusher.data.format, 'event_id_only');
    expect(pusher.data.url, gatewayUri);
    expect(pusher.data.additionalProperties, {
      'provider': 'fcm',
      'platform': 'android',
      'package_name': 'com.direxio.ai',
      'matrix_device_id': 'DEVICE123',
      'timezone': 'CST',
    });
  });

  test('builds iOS APNs Matrix HTTP pusher data', () {
    final pusher = buildDirexioMatrixHttpPusher(
      profile: direxioIosApnsPusherProfile,
      pushToken: ' apns-token ',
      gatewayUri: gatewayUri,
      matrixDeviceId: 'IOSDEVICE',
      localeTag: 'en-US',
      timezoneName: 'PST',
    );

    expect(pusher.appId, 'com.direxio.app');
    expect(pusher.pushkey, 'apns-token');
    expect(pusher.kind, 'http');
    expect(pusher.lang, 'en-US');
    expect(pusher.profileTag, 'IOSDEVICE');
    expect(pusher.deviceDisplayName, 'iOS IOSDEVICE');
    expect(pusher.data.format, 'event_id_only');
    expect(pusher.data.url, gatewayUri);
    expect(pusher.data.additionalProperties, {
      'provider': 'apns',
      'platform': 'ios',
      'matrix_device_id': 'IOSDEVICE',
      'timezone': 'PST',
    });
  });

  test('resolves iOS push token through native APNs provider', () async {
    var androidProviderCalled = false;
    var iosProviderCalled = false;

    final token = await resolveMatrixPushTokenForProfile(
      profile: direxioIosApnsPusherProfile,
      androidFcmToken: () async {
        androidProviderCalled = true;
        return 'fcm-token';
      },
      iosApnsToken: () async {
        iosProviderCalled = true;
        return 'apns-token';
      },
    );

    expect(token, 'apns-token');
    expect(iosProviderCalled, isTrue);
    expect(androidProviderCalled, isFalse);
  });

  test('resolves Android push token through Firebase FCM provider', () async {
    var androidProviderCalled = false;
    var iosProviderCalled = false;

    final token = await resolveMatrixPushTokenForProfile(
      profile: direxioAndroidFcmPusherProfile,
      androidFcmToken: () async {
        androidProviderCalled = true;
        return 'fcm-token';
      },
      iosApnsToken: () async {
        iosProviderCalled = true;
        return 'apns-token';
      },
    );

    expect(token, 'fcm-token');
    expect(androidProviderCalled, isTrue);
    expect(iosProviderCalled, isFalse);
  });

  test('push gateway URL allows production HTTPS and local HTTP hosts only',
      () {
    expect(
      isAllowedMatrixPushGatewayUrl(
        'https://push.direxio.ai/_matrix/push/v1/notify',
      ),
      isTrue,
    );
    expect(
      isAllowedMatrixPushGatewayUrl(
        'http://127.0.0.1:5000/_matrix/push/v1/notify',
      ),
      isTrue,
    );
    expect(
      isAllowedMatrixPushGatewayUrl(
        'http://10.0.2.2:5000/_matrix/push/v1/notify',
      ),
      isTrue,
    );
    expect(
      isAllowedMatrixPushGatewayUrl(
        'http://192.168.1.20:5000/_matrix/push/v1/notify',
      ),
      isTrue,
    );
    expect(
      isAllowedMatrixPushGatewayUrl(
        'http://203.0.113.20:5000/_matrix/push/v1/notify',
      ),
      isFalse,
    );
    expect(isAllowedMatrixPushGatewayUrl('https://push.direxio.ai/notify'),
        isFalse);
  });
}

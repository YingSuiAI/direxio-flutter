import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/matrix_push_registration.dart';

void main() {
  test('Direxio Android pusher constants match Firebase gateway config', () {
    expect(direxioMatrixPusherAppId, 'io.direxio.app.android');
    expect(direxioAndroidPackageName, 'com.direxio.ai');
    expect(
      direxioPushGatewayUrl,
      'https://push.direxio.ai/_matrix/push/v1/notify',
    );
  });

  test('push gateway URL allows production HTTPS and local HTTP hosts only',
      () {
    expect(
      isAllowedMatrixPushGatewayUrl(
        'https://push.direxio.com/_matrix/push/v1/notify',
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
    expect(
      isAllowedMatrixPushGatewayUrl('https://push.direxio.com/notify'),
      isFalse,
    );
  });
}

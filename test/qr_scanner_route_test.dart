import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/pages/qr_scanner_page.dart';
import 'package:portal_app/presentation/qr/qr_scan_parser.dart';

void main() {
  test('add contact route preserves scanned avatar url', () {
    final route = addContactDetailRouteForQrTarget(
      const QrScanTarget.user(
        userId: '@alice:portal.local',
        displayName: 'Alice',
        avatarUrl: 'mxc://portal.local/alice',
      ),
    );

    final uri = Uri.parse(route);
    expect(uri.path, '/add-contact/detail/%40alice%3Aportal.local');
    expect(uri.queryParameters['name'], 'Alice');
    expect(uri.queryParameters['avatar'], 'mxc://portal.local/alice');
  });
}

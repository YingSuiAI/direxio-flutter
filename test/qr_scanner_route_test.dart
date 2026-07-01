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

  test('group route opens scanned Matrix group detail', () {
    final route = groupDetailRouteForQrTarget(
      const QrScanTarget.group(
        groupId: '!group:p2p-im.com',
        displayName: '真实群',
        avatarUrl: 'mxc://p2p-im.com/group',
      ),
    );

    final uri = Uri.parse(route!);
    expect(uri.path, '/group-detail/!group%3Ap2p-im.com');
    expect(uri.queryParameters['qr'], '1');
    expect(uri.queryParameters['name'], '真实群');
    expect(uri.queryParameters['avatar'], 'mxc://p2p-im.com/group');
  });

  test('group route marks room-id-only qr scans as scanned', () {
    final route = groupDetailRouteForQrTarget(
      const QrScanTarget.group(groupId: '!legacy:p2p-im.com'),
    );

    final uri = Uri.parse(route!);
    expect(uri.path, '/group-detail/!legacy%3Ap2p-im.com');
    expect(uri.queryParameters['qr'], '1');
    expect(uri.queryParameters.containsKey('name'), isFalse);
    expect(uri.queryParameters.containsKey('avatar'), isFalse);
  });

  test('group route opens non-matrix group qr as scanned item', () {
    final route = groupDetailRouteForQrTarget(
      const QrScanTarget.group(groupId: 'group-a'),
    );

    final uri = Uri.parse(route!);
    expect(uri.path, '/group-detail/group-a');
    expect(uri.queryParameters['qr'], '1');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/qr/qr_scan_parser.dart';

void main() {
  test('parses p2p user qr payload', () {
    final target = parseQrScanTarget(
      'p2pim://add-contact?mxid=@alice:p2p-im.com&name=Alice',
    );

    expect(target?.kind, QrScanKind.user);
    expect(target?.userId, '@alice:p2p-im.com');
    expect(target?.displayName, 'Alice');
  });

  test('parses mobile add friend qr formats', () {
    expect(
      parseQrScanTarget('https://io.openim.app/addFriend/6346071045')?.userId,
      '6346071045',
    );
    expect(
      parseQrScanTarget('openim://addFriend/6346071045')?.userId,
      '6346071045',
    );
    expect(parseQrScanTarget('6346071045')?.userId, '6346071045');
  });

  test('parses mobile join group qr formats', () {
    expect(
      parseQrScanTarget('https://io.openim.app/joinGroup/group-a')?.groupId,
      'group-a',
    );
    expect(
      parseQrScanTarget('openim://joinGroup/group-a')?.groupId,
      'group-a',
    );
  });

  test('rejects unsupported qr payload', () {
    expect(parseQrScanTarget('hello world'), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/setup_payload.dart';

void main() {
  test('parses setup QR payload with server and code', () {
    final payload = SetupPayload.parse(
      'p2pim://setup?server=https%3A%2F%2Fexample.com&code=a7k9m2q4',
    );

    expect(payload.server.toString(), 'https://example.com');
    expect(payload.code, 'a7k9m2q4');
  });

  test('parses setup QR payload from json wrapper', () {
    final payload = SetupPayload.parse(
      '{"portal_url":"https://example.com/setup","setup_code":"a7k9m2q4"}',
    );

    expect(payload.server.toString(), 'https://example.com');
    expect(payload.code, 'a7k9m2q4');
  });

  test('parses setup QR payload from https query link', () {
    final payload = SetupPayload.parse(
      'https://example.com/setup?code=a7k9m2q4',
    );

    expect(payload.server.toString(), 'https://example.com');
    expect(payload.code, 'a7k9m2q4');
  });

  test('parses setup page link without one-time code', () {
    final payload = SetupPayload.parse('https://lytestl.p2p-im.com/setup');

    expect(payload.server.toString(), 'https://lytestl.p2p-im.com');
    expect(payload.code, isEmpty);
    expect(payload.hasCode, isFalse);
  });

  test('builds setup QR payload with encoded server', () {
    final payload = SetupPayload(
      server: Uri.parse('https://example.com'),
      code: 'a7k9m2q4',
    );

    final uri = Uri.parse(payload.toDeepLink());

    expect(uri.scheme, 'p2pim');
    expect(uri.host, 'setup');
    expect(uri.queryParameters['server'], 'https://example.com');
    expect(uri.queryParameters['code'], 'a7k9m2q4');
  });

  test('rejects setup QR payload without https server', () {
    expect(
      () => SetupPayload.parse(
          'p2pim://setup?server=http%3A%2F%2Fx&code=a7k9m2q4'),
      throwsFormatException,
    );
  });

  test('parses manual entry from portal URL and setup code', () {
    final payload = SetupPayload.parseManual(
      portalOrDeepLink: 'p2p-im.com/setup',
      code: 'a7k9m2q4',
    );

    expect(payload.server.toString(), 'https://p2p-im.com');
    expect(payload.code, 'a7k9m2q4');
  });

  test('parses manual entry from pasted setup deep link', () {
    final payload = SetupPayload.parseManual(
      portalOrDeepLink:
          'p2pim://setup?server=https%3A%2F%2Fp2p-im.com&code=a7k9m2q4',
      code: '',
    );

    expect(payload.server.toString(), 'https://p2p-im.com');
    expect(payload.code, 'a7k9m2q4');
  });

  test('manual entry rejects missing setup code for portal URL', () {
    expect(
      () => SetupPayload.parseManual(
        portalOrDeepLink: 'https://p2p-im.com/setup',
        code: '',
      ),
      throwsFormatException,
    );
  });
}

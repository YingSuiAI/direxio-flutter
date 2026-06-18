import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';

void main() {
  test(
      'local login keeps browser-accessible homeserver when AS returns docker name',
      () {
    final resolved = resolveClientHomeserverForSession(
      Uri.parse('http://127.0.0.1:18008'),
      'https://dendrite-a:8448',
    );

    expect(resolved.toString(), 'http://127.0.0.1:18008');
  });

  test('local login keeps input port when AS returns localhost without port',
      () {
    final resolved = resolveClientHomeserverForSession(
      Uri.parse('http://127.0.0.1:8008'),
      'https://localhost',
    );

    expect(resolved.toString(), 'http://127.0.0.1:8008');
  });

  test('hosted login uses AS homeserver when it is externally routable', () {
    final resolved = resolveClientHomeserverForSession(
      Uri.parse('https://login.example.com'),
      'https://matrix.example.com',
    );

    expect(resolved.toString(), 'https://matrix.example.com');
  });
}

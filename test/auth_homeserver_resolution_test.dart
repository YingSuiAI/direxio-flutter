import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/local_endpoint_resolver.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';

void main() {
  final localEndpoints = LocalEndpointResolver.parse(
    'node-a.test=127.0.0.1:18008,container.internal:38448=127.0.0.1:38008',
  );

  test(
      'local login keeps browser-accessible homeserver when AS returns docker name',
      () {
    final resolved = resolveClientHomeserverForSession(
      Uri.parse('http://127.0.0.1:18008'),
      'https://node-a.test:8448',
    );

    expect(resolved.toString(), 'http://127.0.0.1:18008');
  });

  test('configured local endpoint resolves to simulator-reachable homeserver',
      () {
    final resolved = resolveClientHomeserverForSession(
      Uri.parse('https://node-a.test'),
      'https://container.internal:18448',
      localEndpointResolver: localEndpoints,
    );
    final cResolved = resolveClientHomeserverForSession(
      Uri.parse('https://unknown-node.test'),
      'https://container.internal:38448',
      localEndpointResolver: localEndpoints,
    );

    expect(resolved.toString(), 'http://127.0.0.1:18008');
    expect(cResolved.toString(), 'http://127.0.0.1:38008');
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

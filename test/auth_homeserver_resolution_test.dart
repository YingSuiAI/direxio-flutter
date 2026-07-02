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

  test('Matrix SDK database names are scoped by Matrix account', () {
    final ownerOne = matrixAccountDatabaseNameFor('@owner:p2p-im.com');
    final ownerTwo = matrixAccountDatabaseNameFor('@owner:p2p-liyanan.com');

    expect(ownerOne, isNot(ownerTwo));
    expect(ownerOne, matrixAccountDatabaseNameFor('@owner:p2p-im.com'));
    expect(ownerOne, startsWith('portal_im_db_'));
  });

  test('Matrix SDK database filenames are safe and account scoped', () {
    final ownerOne = matrixAccountDatabaseFilenameFor('@owner:p2p-im.com');
    final ownerTwo = matrixAccountDatabaseFilenameFor('@owner:p2p-liyanan.com');

    expect(ownerOne, isNot(ownerTwo));
    expect(ownerOne, endsWith('.sqlite'));
    expect(ownerOne, isNot(contains('@')));
    expect(ownerOne, isNot(contains(':')));
  });

  test('initialized relogin keeps user scoped cache by Matrix user id', () {
    final shouldReset = shouldResetUserScopedLocalStateForLogin(
      activeStoreUserId: '@account2:p2p-im.com',
      currentUserId: '@account2:p2p-im.com',
      storedUserId: '@account2:p2p-im.com',
      currentHomeserver: Uri.parse('https://p2p-im.com'),
      storedHomeserver: 'https://p2p-im.com',
      nextUserId: '@account1:p2p-im.com',
      nextHomeserver: Uri.parse('https://p2p-im.com'),
      sessionInitialized: true,
      hasCurrentRooms: true,
      isLoggedInAsNextUser: false,
    );

    expect(shouldReset, isFalse);
  });

  test('uninitialized relogin resets cache for fresh setup state', () {
    final shouldReset = shouldResetUserScopedLocalStateForLogin(
      activeStoreUserId: '@account2:p2p-im.com',
      currentUserId: '@account2:p2p-im.com',
      storedUserId: '@account2:p2p-im.com',
      currentHomeserver: Uri.parse('https://p2p-im.com'),
      storedHomeserver: 'https://p2p-im.com',
      nextUserId: '@account1:p2p-im.com',
      nextHomeserver: Uri.parse('https://p2p-im.com'),
      sessionInitialized: false,
      hasCurrentRooms: true,
      isLoggedInAsNextUser: false,
    );

    expect(shouldReset, isTrue);
  });
}

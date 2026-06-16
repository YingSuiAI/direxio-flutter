import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores auth state when Matrix client is already logged in', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = Client(
      'AuthAlreadyLoggedRestoreTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s0","rooms":{}}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    await client.init(
      newToken: 'old-token',
      newUserID: '@owner:example.com',
      newHomeserver: Uri.parse('https://example.com'),
      newDeviceID: 'DEVICE1',
      newDeviceName: 'PortalIM',
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);

    final auth = await container.read(authStateNotifierProvider.future);

    expect(auth.isLoggedIn, isTrue);
    expect(auth.userId, '@owner:example.com');
    expect(auth.homeserver, 'https://example.com');
  });

  test('restores stored auth state without waiting for first Matrix sync',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stored-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.adminAccessTokenKey: 'admin-token',
    });
    final syncCompleter = Completer<http.Response>();
    final requestPaths = <String>[];
    final client = Client(
      'AuthStoredRestoreNoSyncWaitTest',
      httpClient: MockClient((request) async {
        requestPaths.add(request.url.path);
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response(
            '{"flows":[{"type":"m.login.password"}]}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/sync') {
          return syncCompleter.future;
        }
        return http.Response('{}', 404);
      }),
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(() {
      if (!syncCompleter.isCompleted) {
        syncCompleter.complete(http.Response('{"next_batch":"s0"}', 200));
      }
    });
    addTearDown(client.clear);

    final auth = await container
        .read(authStateNotifierProvider.future)
        .timeout(const Duration(milliseconds: 500));

    expect(auth.isLoggedIn, isTrue);
    expect(auth.userId, '@owner:example.com');
    expect(auth.homeserver, 'https://example.com');
    expect(requestPaths, isNot(contains('/_as/auth')));
  });

  test(
      'restores stored auth state without waiting for Matrix preflight network',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stored-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.adminAccessTokenKey: 'admin-token',
    });
    final stalledNetwork = Completer<http.Response>();
    final client = Client(
      'AuthStoredRestoreNoPreflightWaitTest',
      httpClient: MockClient((request) => stalledNetwork.future),
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(() {
      if (!stalledNetwork.isCompleted) {
        stalledNetwork.complete(http.Response('{"next_batch":"s0"}', 200));
      }
    });
    addTearDown(client.clear);

    final auth = await container
        .read(authStateNotifierProvider.future)
        .timeout(const Duration(milliseconds: 2000));

    expect(auth.isLoggedIn, isTrue);
    expect(auth.userId, '@owner:example.com');
    expect(auth.homeserver, 'https://example.com');
  });

  test('refreshes stale stored Matrix token from portal session on restore',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stale-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.adminAccessTokenKey: 'admin-token',
    });
    final authHeaders = <String>[];
    final requestPaths = <String>[];
    final client = Client(
      'AuthStoredStaleMatrixTokenRefreshTest',
      httpClient: MockClient((request) async {
        requestPaths.add(request.url.path);
        authHeaders.add(request.headers['authorization'] ?? '');
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response(
            '{"flows":[{"type":"m.login.password"}]}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"errcode":"M_UNKNOWN_TOKEN","error":"Unknown token"}',
            401,
          );
        }
        if (request.url.path == '/_as/auth') {
          return http.Response(
            '{"matrix_access_token":"fresh-token","admin_access_token":"fresh-admin-token","user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s0","rooms":{}}', 200);
        }
        return http.Response('{}', 404);
      }),
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);

    final auth = await container
        .read(authStateNotifierProvider.future)
        .timeout(const Duration(milliseconds: 1000));

    expect(auth.isLoggedIn, isTrue);
    expect(auth.userId, '@owner:example.com');
    final deadline = DateTime.now().add(const Duration(seconds: 1));
    while (client.accessToken != 'fresh-token' &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(client.accessToken, 'fresh-token');
    expect(requestPaths, contains('/_as/auth'));
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_token'),
      'fresh-token',
    );
  });

  test('restored Matrix session reuses last portal token for AS calls',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stored-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.lastLoginPortalTokenKey: 'last-portal-token',
    });
    final client = Client(
      'AuthStoredRestoreLastPortalTokenTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response(
            '{"flows":[{"type":"m.login.password"}]}',
            200,
          );
        }
        return http.Response('{"next_batch":"s0","rooms":{}}', 200);
      }),
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);

    final auth = await container
        .read(authStateNotifierProvider.future)
        .timeout(const Duration(milliseconds: 500));

    expect(auth.isLoggedIn, isTrue);
    expect(auth.portalToken, 'last-portal-token');
  });

  test('restores auth from stored portal token when Matrix token is missing',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      AuthStateNotifier.lastLoginHomeserverKey: 'https://example.com',
      AuthStateNotifier.lastLoginPortalTokenKey: 'portal-token',
    });
    final requestPaths = <String>[];
    final client = Client(
      'AuthStoredPortalTokenRestoreTest',
      httpClient: MockClient((request) async {
        requestPaths.add(request.url.path);
        if (request.url.path == '/_as/auth') {
          return http.Response(
            '{"matrix_access_token":"fresh-token","admin_access_token":"fresh-admin-token","user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s0","rooms":{}}', 200);
        }
        return http.Response('{}', 404);
      }),
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);

    final auth = await container
        .read(authStateNotifierProvider.future)
        .timeout(const Duration(milliseconds: 500));

    expect(auth.isLoggedIn, isTrue);
    expect(auth.userId, '@owner:example.com');
    expect(auth.homeserver, 'https://example.com');
    expect(auth.portalToken, 'fresh-admin-token');
    expect(client.accessToken, 'fresh-token');
    expect(requestPaths, contains('/_as/auth'));
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_token'),
      'fresh-token',
    );
  });

  test('portal login reuses an already logged-in Matrix client', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final requestPaths = <String>[];
    final authHeaders = <String, String>{};
    final client = Client(
      'AuthAlreadyLoggedPortalLoginTest',
      httpClient: MockClient((request) async {
        requestPaths.add(request.url.path);
        authHeaders[request.url.path] = request.headers['authorization'] ?? '';
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":"owner"}',
            200,
          );
        }
        if (request.url.path == '/_as/auth') {
          return http.Response(
            '{"matrix_access_token":"fresh-matrix-token",'
            '"admin_access_token":"fresh-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1",'
            '"agent_room_id":"!agent:example.com"}',
            200,
          );
        }
        if (request.url.path == '/_as/profile') {
          return http.Response(
            '{"user_id":"@owner:example.com","display_name":"owner",'
            '"domain":"example.com"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response(
            '{"flows":[{"type":"m.login.password"}]}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s1","rooms":{}}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    await client.init(
      newToken: 'old-token',
      newUserID: '@owner:example.com',
      newHomeserver: Uri.parse('https://example.com'),
      newDeviceID: 'DEVICE1',
      newDeviceName: 'PortalIM',
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);
    await container.read(authStateNotifierProvider.future);

    await container
        .read(authStateNotifierProvider.notifier)
        .login('https://example.com', 'portal-token');
    final auth = container.read(authStateNotifierProvider).valueOrNull;

    expect(auth?.isLoggedIn, isTrue);
    expect(auth?.portalToken, 'fresh-admin-token');
    expect(auth?.requiresProfileSetup, isFalse);
    expect(client.accessToken, 'fresh-matrix-token');
    expect(authHeaders['/_as/profile'], 'Bearer fresh-admin-token');
    expect(authHeaders['/_matrix/client/v3/sync'], 'Bearer fresh-matrix-token');
    expect(
      requestPaths.indexOf('/_as/auth'),
      lessThan(requestPaths.indexOf('/.well-known/portal/owner.json')),
    );
  });

  test('portal login does not wait for first Matrix sync after baseline',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final stalledLiveSync = Completer<http.Response>();
    final client = Client(
      'AuthPortalLoginNoFirstSyncWaitTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":"owner"}',
            200,
          );
        }
        if (request.url.path == '/_as/auth') {
          return http.Response(
            '{"matrix_access_token":"fresh-token","admin_access_token":"fresh-admin-token","user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (request.url.path == '/_as/profile') {
          return http.Response(
            '{"user_id":"@owner:example.com","display_name":"owner",'
            '"domain":"example.com"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response(
            '{"flows":[{"type":"m.login.password"}]}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/sync' &&
            request.url.queryParameters['timeout'] == '0') {
          return http.Response('{"next_batch":"baseline","rooms":{}}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/sync') {
          return stalledLiveSync.future;
        }
        return http.Response('{}', 404);
      }),
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(() {
      if (!stalledLiveSync.isCompleted) {
        stalledLiveSync.complete(http.Response('{"next_batch":"s0"}', 200));
      }
    });
    addTearDown(client.clear);
    await container.read(authStateNotifierProvider.future);

    await container
        .read(authStateNotifierProvider.notifier)
        .login('https://example.com', 'portal-token')
        .timeout(const Duration(milliseconds: 500));

    final auth = container.read(authStateNotifierProvider).valueOrNull;
    expect(auth?.isLoggedIn, isTrue);
    expect(auth?.portalToken, 'fresh-admin-token');
  });

  test('portal login resolves device id from Matrix token owner', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = Client(
      'AuthPortalLoginWhoamiDeviceTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_as/auth') {
          return http.Response(
            '{"matrix_access_token":"fresh-token","admin_access_token":"fresh-admin-token","user_id":"@owner:example.com",'
            '"homeserver":"https://example.com"}',
            200,
          );
        }
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":"owner"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"TOKEN_DEVICE"}',
            200,
          );
        }
        if (request.url.path == '/_as/profile') {
          return http.Response(
            '{"user_id":"@owner:example.com","display_name":"owner",'
            '"domain":"example.com"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response(
            '{"flows":[{"type":"m.login.password"}]}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/sync' &&
            request.url.queryParameters['timeout'] == '0') {
          return http.Response('{"next_batch":"baseline","rooms":{}}', 200);
        }
        return http.Response('{"next_batch":"s1","rooms":{}}', 200);
      }),
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);
    await container.read(authStateNotifierProvider.future);

    await container
        .read(authStateNotifierProvider.notifier)
        .login('https://example.com', 'portal-token');

    expect(
      await const FlutterSecureStorage().read(key: 'matrix_device_id'),
      'TOKEN_DEVICE',
    );
  });

  test('portal login marks empty AS profile display name for setup', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = Client(
      'AuthPortalLoginEmptyProfileTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":""}',
            200,
          );
        }
        if (request.url.path == '/_as/auth') {
          return http.Response(
            '{"matrix_access_token":"fresh-token","admin_access_token":"fresh-admin-token","user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (request.url.path == '/_as/profile') {
          return http.Response(
            '{"user_id":"@owner:example.com","display_name":"",'
            '"domain":"example.com"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response(
            '{"flows":[{"type":"m.login.password"}]}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/sync' &&
            request.url.queryParameters['timeout'] == '0') {
          return http.Response('{"next_batch":"baseline","rooms":{}}', 200);
        }
        return http.Response('{"next_batch":"s1","rooms":{}}', 200);
      }),
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);
    await container.read(authStateNotifierProvider.future);

    await container
        .read(authStateNotifierProvider.notifier)
        .login('https://example.com', 'portal-token');
    final auth = container.read(authStateNotifierProvider).valueOrNull;

    expect(auth?.isLoggedIn, isTrue);
    expect(auth?.requiresProfileSetup, isTrue);
    expect(auth?.ownerDisplayName, isEmpty);
  });

  test('portal login marks missing AS profile for setup', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = Client(
      'AuthPortalLoginMissingProfileTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":""}',
            200,
          );
        }
        if (request.url.path == '/_as/auth') {
          return http.Response(
            '{"matrix_access_token":"fresh-token","admin_access_token":"fresh-admin-token","user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (request.url.path == '/_as/profile') {
          return http.Response('{}', 404);
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response(
            '{"flows":[{"type":"m.login.password"}]}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/sync' &&
            request.url.queryParameters['timeout'] == '0') {
          return http.Response('{"next_batch":"baseline","rooms":{}}', 200);
        }
        return http.Response('{"next_batch":"s1","rooms":{}}', 200);
      }),
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);
    await container.read(authStateNotifierProvider.future);

    await container
        .read(authStateNotifierProvider.notifier)
        .login('https://example.com', 'portal-token');
    final auth = container.read(authStateNotifierProvider).valueOrNull;

    expect(auth?.isLoggedIn, isTrue);
    expect(auth?.requiresProfileSetup, isTrue);
    expect(auth?.ownerDisplayName, isNull);
  });

  test('bootstrap long-term password posts password payload', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final requestPaths = <String>[];
    final client = Client(
      'AuthBootstrapPasswordChangeTest',
      httpClient: MockClient((request) async {
        requestPaths.add(request.url.path);
        if (request.url.path == '/_as/bootstrap') {
          expect(jsonDecode(request.body), {'token': '11111111'});
          return http.Response(
            '{"matrix_access_token":"fresh-token","admin_access_token":"fresh-admin-token","user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":""}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response(
            '{"flows":[{"type":"m.login.password"}]}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s1","rooms":{}}', 200);
        }
        if (request.url.path == '/_as/profile') {
          return http.Response(
            '{"user_id":"@owner:example.com","display_name":"",'
            '"domain":"example.com"}',
            200,
          );
        }
        if (request.url.path == '/_as/portal/password') {
          expect(request.method, 'PUT');
          expect(request.headers['Authorization'], 'Bearer fresh-admin-token');
          expect(jsonDecode(request.body), {
            'old_password': '11111111',
            'new_password': '22222222',
          });
          return http.Response(
            '{"matrix_access_token":"changed-matrix-token",'
            '"admin_access_token":"changed-admin-token",'
            '"device_id":"DEVICE2"}',
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);
    await container.read(authStateNotifierProvider.future);

    await container
        .read(authStateNotifierProvider.notifier)
        .bootstrapAndChangePortalToken(
          'https://example.com',
          '11111111',
          '22222222',
        );

    final auth = container.read(authStateNotifierProvider).valueOrNull;
    expect(auth?.isLoggedIn, isTrue);
    expect(auth?.userId, '@owner:example.com');
    expect(auth?.homeserver, 'https://example.com');
    expect(auth?.portalToken, 'changed-admin-token');
    expect(client.accessToken, 'changed-matrix-token');
    expect(
      requestPaths.indexOf('/_as/bootstrap'),
      lessThan(requestPaths.indexOf('/_as/portal/password')),
    );
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.adminAccessTokenKey),
      'changed-admin-token',
    );
  });
}

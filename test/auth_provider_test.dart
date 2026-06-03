import 'dart:async';

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
      'portal_token': 'portal-token',
    });
    final syncCompleter = Completer<http.Response>();
    final client = Client(
      'AuthStoredRestoreNoSyncWaitTest',
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
  });

  test('restores stored auth state without waiting for Matrix preflight network',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stored-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      'portal_token': 'portal-token',
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
        .timeout(const Duration(milliseconds: 500));

    expect(auth.isLoggedIn, isTrue);
    expect(auth.userId, '@owner:example.com');
    expect(auth.homeserver, 'https://example.com');
  });

  test('portal login reuses an already logged-in Matrix client', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = Client(
      'AuthAlreadyLoggedPortalLoginTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":"owner"}',
            200,
          );
        }
        if (request.url.path == '/_as/bootstrap') {
          return http.Response(
            '{"access_token":"fresh-token","user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1",'
            '"portal_token":"long-portal-token"}',
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
    expect(auth?.portalToken, 'long-portal-token');
    expect(client.accessToken, 'fresh-token');
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
        if (request.url.path == '/_as/bootstrap') {
          return http.Response(
            '{"access_token":"fresh-token","user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1",'
            '"portal_token":"long-portal-token"}',
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
    expect(auth?.portalToken, 'long-portal-token');
  });
}

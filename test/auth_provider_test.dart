import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/matrix_token_refreshing_http_client.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';

Map<String, dynamic>? _p2pAction(http.Request request, String action) {
  if (request.url.path != '/_p2p/command' &&
      request.url.path != '/_p2p/query') {
    return null;
  }
  final body = jsonDecode(request.body) as Map<String, dynamic>;
  return body['action'] == action ? body : null;
}

String? _p2pActionName(http.Request request) {
  if (request.url.path != '/_p2p/command' &&
      request.url.path != '/_p2p/query') {
    return null;
  }
  final body = jsonDecode(request.body) as Map<String, dynamic>;
  return body['action'] as String?;
}

class _UploadKeyFailsOnceClient extends Client {
  _UploadKeyFailsOnceClient(
    super.clientName, {
    required super.httpClient,
  });

  int initCalls = 0;

  @override
  Future<void> init({
    String? newToken,
    DateTime? newTokenExpiresAt,
    String? newRefreshToken,
    Uri? newHomeserver,
    String? newUserID,
    String? newDeviceName,
    String? newDeviceID,
    String? newOlmAccount,
    bool waitForFirstSync = true,
    bool waitUntilLoadCompletedLoaded = true,
    void Function()? onMigration,
  }) async {
    initCalls++;
    if (newToken == 'token-1') {
      throw 'Upload key failed';
    }
    return super.init(
      newToken: newToken,
      newTokenExpiresAt: newTokenExpiresAt,
      newRefreshToken: newRefreshToken,
      newHomeserver: newHomeserver,
      newUserID: newUserID,
      newDeviceName: newDeviceName,
      newDeviceID: newDeviceID,
      newOlmAccount: newOlmAccount,
      waitForFirstSync: waitForFirstSync,
      waitUntilLoadCompletedLoaded: waitUntilLoadCompletedLoaded,
      onMigration: onMigration,
    );
  }
}

class _StoredRestoreInitFailsClient extends Client {
  _StoredRestoreInitFailsClient(
    super.clientName, {
    required super.httpClient,
  });

  @override
  Future<void> init({
    String? newToken,
    DateTime? newTokenExpiresAt,
    String? newRefreshToken,
    Uri? newHomeserver,
    String? newUserID,
    String? newDeviceName,
    String? newDeviceID,
    String? newOlmAccount,
    bool waitForFirstSync = true,
    bool waitUntilLoadCompletedLoaded = true,
    void Function()? onMigration,
  }) async {
    if (newToken == 'stored-token') {
      throw TimeoutException('transient local restore failure');
    }
    return super.init(
      newToken: newToken,
      newTokenExpiresAt: newTokenExpiresAt,
      newRefreshToken: newRefreshToken,
      newHomeserver: newHomeserver,
      newUserID: newUserID,
      newDeviceName: newDeviceName,
      newDeviceID: newDeviceID,
      newOlmAccount: newOlmAccount,
      waitForFirstSync: waitForFirstSync,
      waitUntilLoadCompletedLoaded: waitUntilLoadCompletedLoaded,
      onMigration: onMigration,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('portal session token refresh requires clean Matrix init', () {
    expect(
      portalSessionNeedsCleanMatrixInit(
        currentAccessToken: 'old-token',
        currentUserId: '@owner:example.com',
        currentDeviceId: 'DEVICE1',
        currentHomeserver: Uri.parse('https://example.com'),
        nextAccessToken: 'new-token',
        nextUserId: '@owner:example.com',
        nextDeviceId: 'DEVICE1',
        nextHomeserver: Uri.parse('https://example.com'),
      ),
      isTrue,
    );
    expect(
      portalSessionNeedsCleanMatrixInit(
        currentAccessToken: 'new-token',
        currentUserId: '@owner:example.com',
        currentDeviceId: 'DEVICE1',
        currentHomeserver: Uri.parse('https://example.com'),
        nextAccessToken: 'new-token',
        nextUserId: '@owner:example.com',
        nextDeviceId: 'DEVICE1',
        nextHomeserver: Uri.parse('https://example.com'),
      ),
      isFalse,
    );
  });

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
    addTearDown(client.clear);

    final auth = await container.read(authStateNotifierProvider.future);

    expect(auth.userId, anyOf('@owner:example.com', isNull));
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
    expect(requestPaths, isNot(contains('/_p2p/command')));
  });

  test('restores stored profile initialization flag without profile lookup',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stored-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.adminAccessTokenKey: 'admin-token',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    final client = Client(
      'AuthStoredProfileInitializedFlagTest',
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

    final auth = await container.read(authStateNotifierProvider.future);

    expect(auth.isLoggedIn, isTrue);
    expect(auth.requiresProfileSetup, isFalse);
  });

  test('stored restore refreshes stale setup flag from portal auth', () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stored-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.adminAccessTokenKey: 'stored-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '12345678',
      AuthStateNotifier.profileInitializedKey: 'false',
    });
    final client = Client(
      'AuthStoredRestoreRefreshesSetupFlagTest',
      httpClient: MockClient((request) async {
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response(
            '{"matrix_access_token":"fresh-token",'
            '"admin_access_token":"fresh-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"DEVICE1",'
            '"setup_completed":true}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
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

    final auth = await container.read(authStateNotifierProvider.future);

    expect(auth.isLoggedIn, isTrue);
    expect(auth.requiresProfileSetup, isFalse);
    expect(client.accessToken, 'fresh-token');
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.profileInitializedKey),
      'true',
    );
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

  test('stored restore transient failure refreshes Matrix session via portal',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stored-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.adminAccessTokenKey: 'admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: 'portal-token',
      AuthStateNotifier.lastLoginHomeserverKey: 'https://example.com',
    });
    final client = _StoredRestoreInitFailsClient(
      'AuthStoredRestoreTransientFailureTest',
      httpClient: MockClient((request) async {
        final authAction = _p2pAction(request, 'portal.auth');
        if (authAction != null) {
          expect(authAction['params'], {
            'password': 'portal-token',
            'device_id': 'DEVICE1',
          });
          return http.Response(
            '{"matrix_access_token":"fresh-token",'
            '"admin_access_token":"fresh-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"DEVICE1",'
            '"setup_completed":true}',
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
        return http.Response('{}', 404);
      }),
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
    expect(auth.portalToken, 'fresh-admin-token');
    expect(client.accessToken, 'fresh-token');
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_token'),
      'fresh-token',
    );
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_homeserver'),
      'https://example.com',
    );
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_user_id'),
      '@owner:example.com',
    );
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.adminAccessTokenKey),
      'fresh-admin-token',
    );
  });

  test('expires stale stored Matrix token instead of portal auto login',
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
    final requestActions = <String>[];
    final client = Client(
      'AuthStoredStaleMatrixTokenRefreshTest',
      httpClient: MockClient((request) async {
        requestPaths.add(request.url.path);
        authHeaders.add(request.headers['authorization'] ?? '');
        if (request.url.path == '/_p2p/command' ||
            request.url.path == '/_p2p/query') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requestActions.add(body['action'] as String);
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
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"errcode":"M_UNKNOWN_TOKEN","error":"Unknown token"}',
            401,
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

    await container
        .read(authStateNotifierProvider.future)
        .timeout(const Duration(milliseconds: 1000));
    final deadline = DateTime.now().add(const Duration(seconds: 1));
    while ((container.read(authStateNotifierProvider).valueOrNull?.isLoggedIn ??
            true) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(
      container.read(authStateNotifierProvider).valueOrNull?.isLoggedIn,
      isNot(true),
    );
    expect(requestActions, isNot(contains('portal.auth')));
    expect(container.read(sessionExpiredNoticeProvider), greaterThan(0));
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_token'),
      isNull,
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

  test('AS admin token failure refreshes portal session and retries request',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'matrix-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.adminAccessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: 'oldpass123',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    final seenAuthorizations = <String>[];
    final requestActions = <String>[];
    final client = Client(
      'AuthAsAdminTokenRefreshTest',
      httpClient: MockClient((request) async {
        final action = _p2pActionName(request);
        if (action != null) requestActions.add(action);
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.auth') != null) {
          expect(_p2pAction(request, 'portal.auth')!['params'], {
            'password': 'oldpass123',
            'device_id': 'DEVICE1',
          });
          return http.Response(
            '{"matrix_access_token":"matrix-token",'
            '"admin_access_token":"new-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"DEVICE1",'
            '"profile_initialized":true}',
            200,
          );
        }
        if (_p2pAction(request, 'sync.bootstrap') != null) {
          final authorization = request.headers['Authorization'] ?? '';
          seenAuthorizations.add(authorization);
          if (authorization == 'Bearer old-admin-token') {
            return http.Response(
              '{"error":"M_UNKNOWN_TOKEN"}',
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          expect(authorization, 'Bearer new-admin-token');
          return http.Response(
            '{"synced_at":"2026-06-20T00:00:00Z",'
            '"user":{"user_id":"@owner:example.com"},'
            '"rooms":[],"contacts":[],"groups":[],"channels":[],'
            '"pending":{}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s1","rooms":{}}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    final authSub = container.listen(
      authStateNotifierProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(authSub.close);
    addTearDown(container.dispose);
    addTearDown(client.clear);
    await container.read(authStateNotifierProvider.future);

    final bootstrap = await container.read(asClientProvider).syncBootstrap();

    expect(bootstrap.user.userId, '@owner:example.com');
    expect(seenAuthorizations, [
      'Bearer old-admin-token',
      'Bearer new-admin-token',
    ]);
    expect(
        requestActions,
        containsAllInOrder([
          'sync.bootstrap',
          'portal.auth',
          'sync.bootstrap',
        ]));
    expect(
      container.read(authStateNotifierProvider).valueOrNull?.portalToken,
      'new-admin-token',
    );
    expect(
      await const FlutterSecureStorage().read(
        key: AuthStateNotifier.adminAccessTokenKey,
      ),
      'new-admin-token',
    );
  });

  test('restores auth from stored portal token when Matrix token is missing',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      AuthStateNotifier.lastLoginHomeserverKey: 'https://example.com',
      AuthStateNotifier.lastLoginPortalTokenKey: 'portal-token',
      'matrix_device_id': 'DEVICE1',
    });
    final requestPaths = <String>[];
    final client = Client(
      'AuthStoredPortalTokenRestoreTest',
      httpClient: MockClient((request) async {
        requestPaths.add(request.url.path);
        final authAction = _p2pAction(request, 'portal.auth');
        if (authAction != null) {
          expect(authAction['params'], {
            'password': 'portal-token',
            'device_id': 'DEVICE1',
          });
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
    expect(requestPaths, contains('/_p2p/command'));
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
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(request.body) as Map<String, dynamic>;
        final action = body['action'] as String?;
        authHeaders[action ?? request.url.path] =
            request.headers['Authorization'] ??
                request.headers['authorization'] ??
                '';
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":"owner"}',
            200,
          );
        }
        if (request.url.path == '/_p2p/command' &&
            body['action'] == 'portal.auth') {
          return http.Response(
            '{"matrix_access_token":"fresh-matrix-token",'
            '"admin_access_token":"fresh-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1",'
            '"agent_room_id":"!agent:example.com"}',
            200,
          );
        }
        if (request.url.path == '/_p2p/query' &&
            body['action'] == 'profile.get') {
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
    expect(authHeaders['profile.get'], 'Bearer fresh-admin-token');
    expect(authHeaders['/_matrix/client/v3/sync'], 'Bearer fresh-matrix-token');
    expect(
      requestPaths.indexOf('/_p2p/command'),
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
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response(
            '{"matrix_access_token":"fresh-token","admin_access_token":"fresh-admin-token","user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1",'
            '"profile_initialized":false}',
            200,
          );
        }
        if (_p2pAction(request, 'profile.get') != null) {
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
        if (_p2pAction(request, 'portal.auth') != null) {
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
        if (_p2pAction(request, 'profile.get') != null) {
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

  test('portal login replaces stale same-user Matrix device session', () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'OLDDEVICE',
      AuthStateNotifier.adminAccessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: 'oldpass123',
    });
    final client = Client(
      'AuthPortalLoginStaleDeviceRefreshTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_p2p/command') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['action'] == 'portal.auth') {
            final params = body['params'] as Map<String, dynamic>;
            if (params['password'] != '12345678') {
              return http.Response('{"error":"password invalid"}', 401);
            }
            expect(params, {'password': '12345678', 'device_id': 'OLDDEVICE'});
            return http.Response(
              '{"matrix_access_token":"new-token","admin_access_token":"new-admin-token","user_id":"@owner:example.com",'
              '"homeserver":"https://example.com","device_id":"OLDDEVICE"}',
              200,
            );
          }
        }
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":"owner"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"OLDDEVICE"}',
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
    await client.init(
      newToken: 'old-token',
      newUserID: '@owner:example.com',
      newHomeserver: Uri.parse('https://example.com'),
      newDeviceID: 'OLDDEVICE',
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
        .login('https://example.com', '12345678');

    expect(client.accessToken, 'new-token');
    expect(client.deviceID, 'OLDDEVICE');
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_device_id'),
      'OLDDEVICE',
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
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response(
            '{"matrix_access_token":"fresh-token","admin_access_token":"fresh-admin-token","user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1",'
            '"profile_initialized":false}',
            200,
          );
        }
        if (_p2pAction(request, 'profile.get') != null) {
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

  test('portal login does not infer setup from missing AS profile', () async {
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
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response(
            '{"matrix_access_token":"fresh-token","admin_access_token":"fresh-admin-token","user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (_p2pAction(request, 'profile.get') != null) {
          return http.Response('{}', 404);
        }
        if (_p2pAction(request, 'sync.bootstrap') != null) {
          return http.Response(
            '{"synced_at":"2026-06-19T00:00:00Z",'
            '"user":{"user_id":"@owner:example.com"},'
            '"rooms":[],"contacts":[],"groups":[],"channels":[],"pending":{}}',
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
    expect(auth?.requiresProfileSetup, isFalse);
    expect(auth?.ownerDisplayName, isNull);
  });

  test(
      'portal login trusts profile initialization flag when profile load fails',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = Client(
      'AuthPortalLoginProfileInitializedFlagTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":""}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response(
            '{"matrix_access_token":"fresh-token",'
            '"admin_access_token":"fresh-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"DEVICE1",'
            '"profile_initialized":true}',
            200,
          );
        }
        if (_p2pAction(request, 'profile.get') != null) {
          return http.Response('{}', 404);
        }
        if (_p2pAction(request, 'sync.bootstrap') != null) {
          return http.Response(
            '{"synced_at":"2026-06-19T00:00:00Z",'
            '"user":{"user_id":"@owner:example.com"},'
            '"rooms":[],"contacts":[],"groups":[],"channels":[],"pending":{}}',
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
    expect(auth?.requiresProfileSetup, isFalse);
    expect(auth?.ownerDisplayName, isNull);
  });

  test(
      'portal login requires password and profile flags when account flag is absent',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = Client(
      'AuthPortalLoginPasswordProfileFlagsTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":"owner"}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response(
            '{"matrix_access_token":"fresh-token",'
            '"admin_access_token":"fresh-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"DEVICE1",'
            '"profile_initialized":true,'
            '"password_initialized":false}',
            200,
          );
        }
        if (_p2pAction(request, 'profile.get') != null) {
          return http.Response('{"display_name":"owner"}', 200);
        }
        if (_p2pAction(request, 'sync.bootstrap') != null) {
          return http.Response(
            '{"synced_at":"2026-06-19T00:00:00Z",'
            '"user":{"user_id":"@owner:example.com"},'
            '"rooms":[],"contacts":[],"groups":[],"channels":[],"pending":{}}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
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
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.profileInitializedKey),
      'false',
    );
  });

  test('portal login trusts account initialization flag first', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = Client(
      'AuthPortalLoginAccountInitializedFlagTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":"owner"}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response(
            '{"matrix_access_token":"fresh-token",'
            '"admin_access_token":"fresh-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"DEVICE1",'
            '"profile_initialized":true,'
            '"account_initialized":false}',
            200,
          );
        }
        if (_p2pAction(request, 'profile.get') != null) {
          return http.Response('{}', 404);
        }
        if (_p2pAction(request, 'sync.bootstrap') != null) {
          return http.Response(
            '{"synced_at":"2026-06-19T00:00:00Z",'
            '"user":{"user_id":"@owner:example.com"},'
            '"rooms":[],"contacts":[],"groups":[],"channels":[],"pending":{}}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
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
  });

  test(
      'portal login requires explicit account initialization flag when profile flag is absent',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = Client(
      'AuthPortalLoginInitializedPasswordFlagsTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":""}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response(
            '{"matrix_access_token":"fresh-token",'
            '"admin_access_token":"fresh-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"DEVICE1",'
            '"initialized":true,'
            '"password_initialized":true}',
            200,
          );
        }
        if (_p2pAction(request, 'profile.get') != null) {
          return http.Response('{}', 404);
        }
        if (_p2pAction(request, 'sync.bootstrap') != null) {
          return http.Response(
            '{"synced_at":"2026-06-19T00:00:00Z",'
            '"user":{"user_id":"@owner:example.com"},'
            '"rooms":[],"contacts":[],"groups":[],"channels":[],"pending":{}}',
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
    expect(auth?.ownerDisplayName, isNull);
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.profileInitializedKey),
      'false',
    );
  });

  test('portal login trusts already initialized flag when profile load fails',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = Client(
      'AuthPortalLoginAlreadyInitializedFlagTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":""}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response(
            '{"matrix_access_token":"fresh-token",'
            '"admin_access_token":"fresh-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"DEVICE1",'
            '"already_initialized":true}',
            200,
          );
        }
        if (_p2pAction(request, 'profile.get') != null) {
          return http.Response('{"error":"profile unavailable"}', 500);
        }
        if (_p2pAction(request, 'sync.bootstrap') != null) {
          return http.Response(
            '{"synced_at":"2026-06-19T00:00:00Z",'
            '"user":{"user_id":"@owner:example.com"},'
            '"rooms":[],"contacts":[],"groups":[],"channels":[],"pending":{}}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
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
    expect(auth?.requiresProfileSetup, isFalse);
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.profileInitializedKey),
      'true',
    );
  });

  test(
      'portal login overwrites stale setup flag from explicit initialization completion',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      AuthStateNotifier.profileInitializedKey: 'false',
    });
    final client = Client(
      'AuthPortalLoginInitializationCompletedFlagTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":""}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response(
            '{"matrix_access_token":"fresh-token",'
            '"admin_access_token":"fresh-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"DEVICE1",'
            '"initialization_completed":true}',
            200,
          );
        }
        if (_p2pAction(request, 'profile.get') != null) {
          return http.Response('{}', 200);
        }
        if (_p2pAction(request, 'sync.bootstrap') != null) {
          return http.Response(
            '{"synced_at":"2026-06-19T00:00:00Z",'
            '"user":{"user_id":"@owner:example.com"},'
            '"rooms":[],"contacts":[],"groups":[],"channels":[],"pending":{}}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
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
    expect(auth?.requiresProfileSetup, isFalse);
    expect(auth?.ownerDisplayName, '');
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.profileInitializedKey),
      'true',
    );
  });

  test('bootstrap long-term password posts password payload', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final requestPaths = <String>[];
    final requestActions = <String>[];
    String? bootstrapDeviceId;
    final client = Client(
      'AuthBootstrapPasswordChangeTest',
      httpClient: MockClient((request) async {
        requestPaths.add(request.url.path);
        if (request.url.path == '/_p2p/command') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requestActions.add(body['action'] as String);
          if (body['action'] == 'portal.bootstrap') {
            final params = body['params'] as Map<String, dynamic>;
            final requestedDeviceId = params['device_id'] as String;
            bootstrapDeviceId = requestedDeviceId;
            expect(requestedDeviceId, startsWith('PORTALIM'));
            expect(params, {
              'token': '11111111',
              'device_id': requestedDeviceId,
            });
            return http.Response(
              '{"matrix_access_token":"fresh-token","admin_access_token":"fresh-admin-token","user_id":"@owner:example.com",'
              '"homeserver":"https://example.com","device_id":"$requestedDeviceId"}',
              200,
            );
          }
          if (body['action'] == 'portal.password') {
            expect(request.method, 'POST');
            expect(
                request.headers['Authorization'], 'Bearer fresh-admin-token');
            expect(body['params'], {
              'old_password': '11111111',
              'new_password': '22222222',
              'device_id': bootstrapDeviceId,
            });
            return http.Response(
              '{"matrix_access_token":"changed-matrix-token",'
              '"admin_access_token":"changed-admin-token",'
              '"device_id":"$bootstrapDeviceId"}',
              200,
            );
          }
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
        if (_p2pAction(request, 'profile.get') != null) {
          return http.Response(
            '{"user_id":"@owner:example.com","display_name":"",'
            '"domain":"example.com"}',
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
      requestActions.indexOf('portal.bootstrap'),
      lessThan(requestActions.indexOf('portal.password')),
    );
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.adminAccessTokenKey),
      'changed-admin-token',
    );
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_device_id'),
      bootstrapDeviceId,
    );
  });

  test(
      'profile setup persists initialized flag when password response omits it',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.adminAccessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '11111111',
      AuthStateNotifier.profileInitializedKey: 'false',
    });
    final client = Client(
      'AuthCompleteProfileSetupInitializedFlagTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (_p2pAction(request, 'profile.update') != null) {
          return http.Response(
            '{"user_id":"@owner:example.com","display_name":"Alice",'
            '"domain":"example.com"}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.password') != null) {
          return http.Response(
            '{"matrix_access_token":"new-token",'
            '"admin_access_token":"new-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (request.url.path.startsWith('/_matrix/client/v3/profile/') &&
            request.url.path.endsWith('/displayname')) {
          return http.Response('{}', 200);
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
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
        .completeOwnerProfileSetup(
          displayName: 'Alice',
          newPortalToken: '12345678',
        );

    final auth = container.read(authStateNotifierProvider).valueOrNull;
    expect(auth?.isLoggedIn, isTrue);
    expect(auth?.requiresProfileSetup, isFalse);
    expect(auth?.ownerDisplayName, 'Alice');
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.profileInitializedKey),
      'true',
    );
  });

  test('password change keeps initialized flag when response omits it',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.adminAccessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '11111111',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    final client = Client(
      'AuthPasswordChangeKeepsInitializedFlagTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.password') != null) {
          return http.Response(
            '{"matrix_access_token":"new-token",'
            '"admin_access_token":"new-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
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
        .changePortalPassword(
          oldPassword: '11111111',
          newPassword: '12345678',
        );

    final auth = container.read(authStateNotifierProvider).valueOrNull;
    expect(auth?.isLoggedIn, isTrue);
    expect(auth?.requiresProfileSetup, isFalse);
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.profileInitializedKey),
      'true',
    );
  });

  test(
      'password change trusts account initialization flag when stored flag is stale',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.adminAccessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '11111111',
      AuthStateNotifier.profileInitializedKey: 'false',
    });
    final client = Client(
      'AuthPasswordChangeTrustsInitializedPasswordFlagsTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.password') != null) {
          return http.Response(
            '{"matrix_access_token":"new-token",'
            '"admin_access_token":"new-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"DEVICE1",'
            '"initialized":true,'
            '"password_initialized":true,'
            '"account_initialized":true,'
            '"setup_completed":true}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
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
        .changePortalPassword(
          oldPassword: '11111111',
          newPassword: '12345678',
        );

    final auth = container.read(authStateNotifierProvider).valueOrNull;
    expect(auth?.isLoggedIn, isTrue);
    expect(auth?.requiresProfileSetup, isFalse);
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.profileInitializedKey),
      'true',
    );
  });

  test('password change ignores delayed Matrix 401 from previous token',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.adminAccessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '11111111',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    late ProviderContainer container;
    final refreshingClient = MatrixTokenRefreshingHttpClient(
      inner: MockClient((request) async {
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          final authorization = request.headers['authorization'] ?? '';
          if (authorization == 'Bearer old-token' ||
              authorization == 'Bearer new-token') {
            return http.Response(
              '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
              200,
            );
          }
          return http.Response(
            '{"errcode":"M_UNKNOWN_TOKEN","error":"Unknown token"}',
            401,
          );
        }
        if (_p2pAction(request, 'portal.password') != null) {
          return http.Response(
            '{"matrix_access_token":"new-token",'
            '"admin_access_token":"new-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"DEVICE1",'
            '"profile_initialized":true}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/keys/upload') {
          final authorization = request.headers['authorization'] ?? '';
          if (authorization == 'Bearer old-token') {
            return http.Response(
              '{"errcode":"M_UNKNOWN_TOKEN","error":"Unknown token"}',
              401,
            );
          }
          return http.Response('{"one_time_key_counts":{}}', 200);
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s1","rooms":{}}', 200);
        }
        return http.Response('{}', 404);
      }),
    )..onAuthenticationFailed = () async {
        await container
            .read(authStateNotifierProvider.notifier)
            .expireSessionDueInvalidToken();
      };
    final client = Client(
      'AuthPasswordChangeIgnoresStaleTokenFailureTest',
      httpClient: refreshingClient,
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
    container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);
    await container.read(authStateNotifierProvider.future);

    await container
        .read(authStateNotifierProvider.notifier)
        .changePortalPassword(
          oldPassword: '11111111',
          newPassword: '12345678',
        );

    final staleUpload = http.Request(
      'PUT',
      Uri.parse('https://example.com/_matrix/client/v3/keys/upload'),
    )
      ..headers['authorization'] = 'Bearer old-token'
      ..body = '{}';
    final response = await refreshingClient.send(staleUpload);
    await response.stream.drain<void>();

    expect(response.statusCode, 401);
    expect(client.accessToken, 'new-token');
    expect(
      container.read(authStateNotifierProvider).valueOrNull?.isLoggedIn,
      isTrue,
    );
    expect(container.read(sessionExpiredNoticeProvider), 0);
  });

  test('logout preserves Matrix device store for same device login', () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'current-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.adminAccessTokenKey: 'current-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '12345678',
      AuthStateNotifier.lastLoginHomeserverKey: 'https://example.com',
    });
    final client = Client(
      'AuthLogoutPreservesMatrixDeviceTest',
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
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s1","rooms":{}}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/logout') {
          return http.Response('{}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    await client.init(
      newToken: 'current-token',
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

    await container.read(authStateNotifierProvider.notifier).logout();

    expect(container.read(authStateNotifierProvider).valueOrNull?.isLoggedIn,
        isFalse);
    expect(client.deviceID, 'DEVICE1');
    expect(
        await const FlutterSecureStorage().read(key: 'matrix_token'), isNull);
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.lastLoginPortalTokenKey),
      '12345678',
    );
  });

  test(
      'same device can switch from one account to another without provider loop',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'alice-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@alice:example.com',
      'matrix_device_id': 'DEVICE_A',
      AuthStateNotifier.adminAccessTokenKey: 'alice-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: 'alicepass',
      AuthStateNotifier.lastLoginHomeserverKey: 'https://example.com',
    });
    final client = Client(
      'AuthSameDeviceAccountSwitchTest',
      httpClient: MockClient((request) async {
        final authAction = _p2pAction(request, 'portal.auth');
        if (authAction != null) {
          final params = authAction['params'] as Map<String, dynamic>;
          expect(params['password'], 'bobpass12');
          return http.Response(
            '{"matrix_access_token":"bob-token",'
            '"admin_access_token":"bob-admin-token",'
            '"user_id":"@bob:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"DEVICE_B"}',
            200,
          );
        }
        if (_p2pAction(request, 'profile.get') != null) {
          return http.Response(
            '{"user_id":"@bob:example.com","display_name":"Bob",'
            '"domain":"example.com"}',
            200,
          );
        }
        if (_p2pAction(request, 'sync.bootstrap') != null) {
          return http.Response(
            '{"synced_at":"2026-06-19T00:00:00Z",'
            '"user":{"user_id":"@bob:example.com","display_name":"Bob"},'
            '"rooms":[],"contacts":[],"groups":[],"channels":[],"pending":{}}',
            200,
          );
        }
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@bob:example.com","display_name":"Bob"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/logout') {
          return http.Response('{}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          final authorization = request.headers['authorization'] ?? '';
          if (authorization == 'Bearer bob-token') {
            return http.Response(
              '{"user_id":"@bob:example.com","device_id":"DEVICE_B"}',
              200,
            );
          }
          return http.Response(
            '{"user_id":"@alice:example.com","device_id":"DEVICE_A"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s1","rooms":{}}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    await client.init(
      newToken: 'alice-token',
      newUserID: '@alice:example.com',
      newHomeserver: Uri.parse('https://example.com'),
      newDeviceID: 'DEVICE_A',
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
    container.read(asClientProvider);

    await container.read(authStateNotifierProvider.notifier).logout();
    await container
        .read(authStateNotifierProvider.notifier)
        .login('https://example.com', 'bobpass12');

    final auth = container.read(authStateNotifierProvider).valueOrNull;
    expect(auth?.isLoggedIn, isTrue);
    expect(auth?.userId, '@bob:example.com');
    expect(auth?.portalToken, 'bob-admin-token');
    expect(client.userID, '@bob:example.com');
    expect(client.accessToken, 'bob-token');
    expect(client.deviceID, 'DEVICE_B');
  });

  test('password change follows token Matrix device when it differs', () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'OLDDEVICE',
      AuthStateNotifier.adminAccessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: 'oldpass123',
    });
    final client = Client(
      'AuthPasswordChangeRefreshDeviceTest',
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
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s1","rooms":{}}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          final authorization = request.headers['authorization'] ?? '';
          if (authorization == 'Bearer changed-matrix-token') {
            return http.Response(
              '{"user_id":"@owner:example.com","device_id":"P2P_PORTAL"}',
              200,
            );
          }
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"OLDDEVICE"}',
            200,
          );
        }
        if (request.url.path == '/_p2p/command') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['action'], 'portal.password');
          expect(request.method, 'POST');
          expect(request.headers['Authorization'], 'Bearer old-admin-token');
          expect(body['params'], {
            'old_password': 'oldpass123',
            'new_password': '12345678',
            'device_id': 'OLDDEVICE',
          });
          return http.Response(
            '{"matrix_access_token":"changed-matrix-token",'
            '"admin_access_token":"changed-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"OLDDEVICE"}',
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    await client.init(
      newToken: 'old-token',
      newUserID: '@owner:example.com',
      newHomeserver: Uri.parse('https://example.com'),
      newDeviceID: 'OLDDEVICE',
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
        .changePortalPassword(
          oldPassword: 'oldpass123',
          newPassword: '12345678',
        );

    expect(client.accessToken, 'changed-matrix-token');
    expect(client.deviceID, 'P2P_PORTAL');
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_device_id'),
      'P2P_PORTAL',
    );
  });

  test('portal login retries with a fresh device when key upload fails',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final requestedDevices = <String>[];
    final client = _UploadKeyFailsOnceClient(
      'AuthPortalLoginUploadKeyRetryTest',
      httpClient: MockClient((request) async {
        final authAction = _p2pAction(request, 'portal.auth');
        if (authAction != null) {
          final params = authAction['params'] as Map<String, dynamic>;
          requestedDevices.add(params['device_id'] as String);
          return http.Response(
            '{"matrix_access_token":"token-${requestedDevices.length}",'
            '"admin_access_token":"admin-${requestedDevices.length}",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"${params['device_id']}",'
            '"setup_completed":true}',
            200,
          );
        }
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":"owner"}',
            200,
          );
        }
        if (_p2pAction(request, 'profile.get') != null) {
          return http.Response('{}', 404);
        }
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          final authorization = request.headers['authorization'] ?? '';
          final token = authorization.replaceFirst('Bearer ', '');
          final suffix = token.split('-').last;
          final index = int.tryParse(suffix) ?? 1;
          final device = requestedDevices[index - 1];
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"$device"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s1","rooms":{}}', 200);
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
        .login('https://example.com', '12345678');

    final auth = container.read(authStateNotifierProvider).valueOrNull;
    expect(auth?.isLoggedIn, isTrue);
    expect(auth?.requiresProfileSetup, isFalse);
    expect(requestedDevices, hasLength(2));
    expect(requestedDevices[0], isNot(requestedDevices[1]));
    expect(client.accessToken, 'token-2');
    expect(client.deviceID, requestedDevices[1]);
  });

  test('password change retries auth with a fresh device when key upload fails',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE_A',
      AuthStateNotifier.adminAccessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '11111111',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    final requestedDevices = <String>[];
    final client = _UploadKeyFailsOnceClient(
      'AuthPasswordUploadKeyRetryTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          final authorization = request.headers['authorization'] ?? '';
          if (authorization == 'Bearer old-token') {
            return http.Response(
              '{"user_id":"@owner:example.com","device_id":"DEVICE_A"}',
              200,
            );
          }
          final token = authorization.replaceFirst('Bearer token-', '');
          final index = int.tryParse(token) ?? 1;
          final device = requestedDevices[index - 1];
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"$device"}',
            200,
          );
        }
        final passwordAction = _p2pAction(request, 'portal.password');
        if (passwordAction != null) {
          final params = passwordAction['params'] as Map<String, dynamic>;
          requestedDevices.add(params['device_id'] as String);
          expect(params['old_password'], '11111111');
          expect(params['new_password'], '12345678');
          return http.Response(
            '{"matrix_access_token":"token-1",'
            '"admin_access_token":"admin-1",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"${params['device_id']}",'
            '"setup_completed":true}',
            200,
          );
        }
        final authAction = _p2pAction(request, 'portal.auth');
        if (authAction != null) {
          final params = authAction['params'] as Map<String, dynamic>;
          expect(params['password'], '12345678');
          requestedDevices.add(params['device_id'] as String);
          return http.Response(
            '{"matrix_access_token":"token-2",'
            '"admin_access_token":"admin-2",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"${params['device_id']}",'
            '"setup_completed":true}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
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
      newDeviceID: 'DEVICE_A',
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
        .changePortalPassword(
          oldPassword: '11111111',
          newPassword: '12345678',
        );

    final auth = container.read(authStateNotifierProvider).valueOrNull;
    expect(auth?.isLoggedIn, isTrue);
    expect(auth?.requiresProfileSetup, isFalse);
    expect(requestedDevices, hasLength(2));
    expect(requestedDevices[0], 'DEVICE_A');
    expect(requestedDevices[1], isNot('DEVICE_A'));
    expect(client.accessToken, 'token-2');
    expect(client.deviceID, requestedDevices[1]);
  });

  test('new device login uses its own device and old device expires', () async {
    final matrixDevicesByToken = <String, String>{'token-a': 'DEVICE_A'};

    http.Response tokenOwnerResponse(http.Request request) {
      final auth = request.headers['authorization'] ?? '';
      final token = auth.startsWith('Bearer ') ? auth.substring(7) : '';
      final deviceId = matrixDevicesByToken[token];
      if (deviceId != null) {
        return http.Response(
          '{"user_id":"@owner:example.com","device_id":"$deviceId"}',
          200,
        );
      }
      return http.Response(
        '{"errcode":"M_UNKNOWN_TOKEN","error":"Unknown token"}',
        401,
      );
    }

    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'token-a',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE_A',
      AuthStateNotifier.adminAccessTokenKey: 'admin-a',
      AuthStateNotifier.lastLoginPortalTokenKey: 'oldpass12',
    });
    final clientA = Client(
      'AuthTwoDeviceDeviceATest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return tokenOwnerResponse(request);
        }
        if (request.url.path == '/_p2p/command') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['action'] == 'portal.password') {
            expect(body['params'], {
              'old_password': 'oldpass12',
              'new_password': '12345678',
              'device_id': 'DEVICE_A',
            });
            matrixDevicesByToken['token-a-new'] = 'DEVICE_A';
            return http.Response(
              '{"matrix_access_token":"token-a-new",'
              '"admin_access_token":"admin-a-new",'
              '"user_id":"@owner:example.com",'
              '"homeserver":"https://example.com","device_id":"DEVICE_A"}',
              200,
            );
          }
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s1","rooms":{}}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    await clientA.init(
      newToken: 'token-a',
      newUserID: '@owner:example.com',
      newHomeserver: Uri.parse('https://example.com'),
      newDeviceID: 'DEVICE_A',
      newDeviceName: 'PortalIM',
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );
    final containerA = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(clientA)],
    );
    addTearDown(containerA.dispose);
    addTearDown(clientA.clear);
    await containerA.read(authStateNotifierProvider.future);
    await containerA
        .read(authStateNotifierProvider.notifier)
        .changePortalPassword(
          oldPassword: 'oldpass12',
          newPassword: '12345678',
        );

    FlutterSecureStorage.setMockInitialValues({});
    String? deviceB;
    final clientB = Client(
      'AuthTwoDeviceDeviceBTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_p2p/command') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['action'] == 'portal.auth') {
            final params = body['params'] as Map<String, dynamic>;
            deviceB = params['device_id'] as String;
            expect(params['password'], '12345678');
            expect(deviceB, startsWith('PORTALIM'));
            expect(deviceB, isNot('DEVICE_A'));
            matrixDevicesByToken
              ..clear()
              ..['token-b'] = deviceB!;
            return http.Response(
              '{"matrix_access_token":"token-b",'
              '"admin_access_token":"admin-b",'
              '"user_id":"@owner:example.com",'
              '"homeserver":"https://example.com","device_id":"$deviceB"}',
              200,
            );
          }
        }
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:example.com","display_name":"owner"}',
            200,
          );
        }
        if (_p2pAction(request, 'profile.get') != null) {
          return http.Response(
            '{"user_id":"@owner:example.com","display_name":"owner",'
            '"domain":"example.com"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return tokenOwnerResponse(request);
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s1","rooms":{}}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    final containerB = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(clientB)],
    );
    addTearDown(containerB.dispose);
    addTearDown(clientB.clear);
    await containerB.read(authStateNotifierProvider.future);
    await containerB
        .read(authStateNotifierProvider.notifier)
        .login('https://example.com', '12345678');

    expect(clientB.deviceID, deviceB);
    expect(clientB.accessToken, 'token-b');

    await expectLater(
      containerA
          .read(authStateNotifierProvider.notifier)
          .ensureFreshMatrixSession(),
      throwsA(isA<StateError>()),
    );
    expect(
      containerA.read(authStateNotifierProvider).valueOrNull?.isLoggedIn,
      isFalse,
    );
    expect(containerA.read(sessionExpiredNoticeProvider), greaterThan(0));
  });
}

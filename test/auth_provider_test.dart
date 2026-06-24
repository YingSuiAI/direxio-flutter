import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/http_as_client.dart';
import 'package:portal_app/data/matrix_token_refreshing_http_client.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/as_event_stream_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/app_warmup_provider.dart';
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

class _MatrixOnlyAuthStateNotifier extends AuthStateNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        isLoggedIn: true,
        userId: '@owner:example.com',
        homeserver: 'https://example.com',
      );
}

class _SdkStoreRestoreClient extends Client {
  _SdkStoreRestoreClient(
    super.clientName, {
    required super.httpClient,
  });

  int initFromSdkStoreCalls = 0;
  int initWithInjectedTokenCalls = 0;
  String? _testDeviceId;

  @override
  String? get deviceID => _testDeviceId ?? super.deviceID;

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
    if (newToken != null) {
      initWithInjectedTokenCalls++;
      throw 'Upload key failed';
    }
    initFromSdkStoreCalls++;
    homeserver = Uri.parse('https://example.com');
    accessToken = 'stored-token';
    setUserId('@owner:example.com');
    _testDeviceId = 'DEVICE1';
    onLoginStateChanged.add(LoginState.loggedIn);
  }
}

class _NoSyncInitClient extends Client {
  _NoSyncInitClient(
    super.clientName, {
    required super.httpClient,
  });

  String? _testDeviceId;
  String? _testDeviceName;

  @override
  String? get deviceID => _testDeviceId ?? super.deviceID;

  @override
  String? get deviceName => _testDeviceName ?? super.deviceName;

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
    homeserver = newHomeserver;
    accessToken = newToken;
    if (newUserID != null) setUserId(newUserID);
    _testDeviceId = newDeviceID;
    _testDeviceName = newDeviceName;
    onLoginStateChanged.add(LoginState.loggedIn);
  }
}

class _UploadKeyFailsForTokensClient extends _NoSyncInitClient {
  _UploadKeyFailsForTokensClient(
    super.clientName, {
    required super.httpClient,
    required this.failingTokens,
  });

  final Set<String> failingTokens;

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
    if (newToken != null && failingTokens.contains(newToken)) {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('portal session token refresh preserves Matrix cache identity', () {
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
      isFalse,
    );
    expect(
      portalSessionNeedsCleanMatrixInit(
        currentAccessToken: 'old-token',
        currentUserId: '@owner:example.com',
        currentDeviceId: 'DEVICE1',
        currentHomeserver: Uri.parse('https://example.com'),
        nextAccessToken: 'new-token',
        nextUserId: '@other:example.com',
        nextDeviceId: 'DEVICE1',
        nextHomeserver: Uri.parse('https://example.com'),
      ),
      isTrue,
    );
    expect(
      portalSessionNeedsCleanMatrixInit(
        currentAccessToken: 'old-token',
        currentUserId: '@owner:example.com',
        currentDeviceId: 'DEVICE1',
        currentHomeserver: Uri.parse('https://example.com'),
        nextAccessToken: 'new-token',
        nextUserId: '@owner:example.com',
        nextDeviceId: 'DEVICE2',
        nextHomeserver: Uri.parse('https://example.com'),
      ),
      isTrue,
    );
    expect(
      portalSessionNeedsCleanMatrixInit(
        currentAccessToken: 'old-token',
        currentUserId: '@owner:example.com',
        currentDeviceId: 'DEVICE1',
        currentHomeserver: Uri.parse('https://example.com'),
        nextAccessToken: 'new-token',
        nextUserId: '@owner:example.com',
        nextDeviceId: 'DEVICE1',
        nextHomeserver: Uri.parse('https://matrix.example.com'),
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

  test('fresh iOS install clears stale secure session only for new app state',
      () {
    expect(
      shouldClearStaleIosKeychainAfterFreshInstall(
        isIos: true,
        markerExists: false,
        hasExistingLocalState: false,
        hasSecureSessionState: true,
      ),
      isTrue,
    );
    expect(
      shouldClearStaleIosKeychainAfterFreshInstall(
        isIos: true,
        markerExists: false,
        hasExistingLocalState: true,
        hasSecureSessionState: true,
      ),
      isFalse,
    );
    expect(
      shouldClearStaleIosKeychainAfterFreshInstall(
        isIos: false,
        markerExists: false,
        hasExistingLocalState: false,
        hasSecureSessionState: true,
      ),
      isFalse,
    );
    expect(
      shouldClearStaleIosKeychainAfterFreshInstall(
        isIos: true,
        markerExists: true,
        hasExistingLocalState: false,
        hasSecureSessionState: true,
      ),
      isFalse,
    );
  });

  test('restores auth state when Matrix client is already logged in', () async {
    FlutterSecureStorage.setMockInitialValues({
      AuthStateNotifier.accessTokenKey: 'portal-token',
    });
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
      newDeviceName: 'Direxio',
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(client.clear);

    final auth = await container.read(authStateNotifierProvider.future);

    expect(auth.isLoggedIn, isTrue);
    expect(auth.userId, anyOf('@owner:example.com', isNull));
    expect(auth.homeserver, 'https://example.com');
    expect(auth.portalToken, 'portal-token');
  });

  test('Matrix-only restored state without portal credentials logs out',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = Client(
      'AuthMatrixOnlyRestoreTest',
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
      newDeviceName: 'Direxio',
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);

    final auth = await container.read(authStateNotifierProvider.future);

    expect(auth.isLoggedIn, isFalse);
    expect(auth.portalToken, isNull);
  });

  test('event stream stays idle when auth lacks portal token', () {
    final container = ProviderContainer(
      overrides: [
        authStateNotifierProvider
            .overrideWith(_MatrixOnlyAuthStateNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(asEventStreamRefreshProvider), isNull);
  });

  test('app warmup stays idle when auth lacks portal token', () async {
    final container = ProviderContainer(
      overrides: [
        authStateNotifierProvider
            .overrideWith(_MatrixOnlyAuthStateNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(container.read(appWarmupProvider.future), completes);
  });

  test('restores stored auth state without waiting for first Matrix sync',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stored-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'admin-token',
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
    final authSub = container.listen(
      authStateNotifierProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(authSub.close);
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

  test('stored restore prefers SDK database session before injected token init',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stored-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'stored-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '12345678',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    final client = _SdkStoreRestoreClient(
      'AuthStoredRestorePrefersSdkStoreTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
            200,
          );
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

    final auth = await container.read(authStateNotifierProvider.future);

    expect(auth.isLoggedIn, isTrue);
    expect(client.initFromSdkStoreCalls, 1);
    expect(client.initWithInjectedTokenCalls, 0);
    expect(client.deviceID, 'DEVICE1');
    expect(client.accessToken, 'stored-token');
  });

  test('restores stored profile initialization flag without profile lookup',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stored-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'admin-token',
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
      AuthStateNotifier.accessTokenKey: 'stored-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '12345678',
      AuthStateNotifier.profileInitializedKey: 'false',
    });
    final client = Client(
      'AuthStoredRestoreRefreshesSetupFlagTest',
      httpClient: MockClient((request) async {
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response(
            '{"access_token":"fresh-token",'
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
      AuthStateNotifier.accessTokenKey: 'admin-token',
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
      AuthStateNotifier.accessTokenKey: 'admin-token',
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
            '{"access_token":"fresh-token",'
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
    expect(auth.portalToken, 'fresh-token');
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
          .read(key: AuthStateNotifier.accessTokenKey),
      'fresh-token',
    );
  });

  test('refreshes stale stored Matrix token from saved portal login', () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stale-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: 'portal-token',
      AuthStateNotifier.lastLoginHomeserverKey: 'https://example.com',
    });
    final authHeaders = <String>[];
    final requestPaths = <String>[];
    final requestActions = <String>[];
    late MatrixTokenRefreshingHttpClient refreshingClient;
    final client = _NoSyncInitClient(
      'AuthStoredStaleMatrixTokenRefreshTest',
      httpClient: refreshingClient = MatrixTokenRefreshingHttpClient(
        inner: MockClient((request) async {
          requestPaths.add(request.url.path);
          authHeaders.add(request.headers['authorization'] ?? '');
          if (request.url.path == '/_p2p/command' ||
              request.url.path == '/_p2p/query') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            requestActions.add(body['action'] as String);
          }
          final authAction = _p2pAction(request, 'portal.auth');
          if (authAction != null) {
            expect(authAction['params'], {
              'password': 'portal-token',
              'device_id': 'DEVICE1',
            });
            return http.Response(
              '{"access_token":"fresh-token",'
              '"user_id":"@owner:example.com",'
              '"homeserver":"https://example.com",'
              '"device_id":"DEVICE1",'
              '"profile_initialized":true}',
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
          if (request.url.path == '/_matrix/client/v3/account/whoami') {
            if (request.headers['authorization'] == 'Bearer fresh-token') {
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
          if (request.url.path == '/_matrix/client/v3/sync') {
            return http.Response('{"next_batch":"s0","rooms":{}}', 200);
          }
          return http.Response('{}', 404);
        }),
      ),
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
    while (client.accessToken != 'fresh-token' &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(refreshingClient.refreshAccessToken, isNotNull);
    expect(client.accessToken, 'fresh-token');
    expect(requestActions, contains('portal.auth'));
    expect(container.read(sessionExpiredNoticeProvider), 0);
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_token'),
      'fresh-token',
    );
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.accessTokenKey),
      'fresh-token',
    );
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.lastLoginPortalTokenKey),
      'portal-token',
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
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
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
            '{"access_token":"matrix-token",'
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
          expect(authorization, 'Bearer matrix-token');
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
    final initialAuth = await container.read(authStateNotifierProvider.future);
    expect(initialAuth.isLoggedIn, isTrue);

    final bootstrap = await container.read(asClientProvider).syncBootstrap();

    expect(bootstrap.user.userId, '@owner:example.com');
    expect(seenAuthorizations, [
      'Bearer old-admin-token',
      'Bearer matrix-token',
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
      'matrix-token',
    );
    expect(
      await const FlutterSecureStorage().read(
        key: AuthStateNotifier.accessTokenKey,
      ),
      'matrix-token',
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
            '{"access_token":"fresh-token","user_id":"@owner:example.com",'
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
    expect(auth.portalToken, 'fresh-token');
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
            '{"access_token":"fresh-matrix-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1",'
            '"agent_room_id":"!agent-room:example.com"}',
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
      newDeviceName: 'Direxio',
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );

    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);
    final initialAuth = await container.read(authStateNotifierProvider.future);
    expect(initialAuth.isLoggedIn, isFalse);

    await container
        .read(authStateNotifierProvider.notifier)
        .login('https://example.com', 'portal-token');
    final auth = container.read(authStateNotifierProvider).valueOrNull;

    expect(auth?.isLoggedIn, isTrue);
    expect(auth?.portalToken, 'fresh-matrix-token');
    expect(auth?.requiresProfileSetup, isFalse);
    expect(
      container.read(asSyncCacheProvider).bootstrap?.agentRoomId,
      '!agent-room:example.com',
    );
    expect(client.accessToken, 'fresh-matrix-token');
    expect(authHeaders['profile.get'], 'Bearer fresh-matrix-token');
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
            '{"access_token":"fresh-token","user_id":"@owner:example.com",'
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
    expect(auth?.portalToken, 'fresh-token');
  });

  test('portal login resolves device id from Matrix token owner', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = Client(
      'AuthPortalLoginWhoamiDeviceTest',
      httpClient: MockClient((request) async {
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response(
            '{"access_token":"fresh-token","user_id":"@owner:example.com",'
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
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
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
              '{"access_token":"new-token","user_id":"@owner:example.com",'
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
      newDeviceName: 'Direxio',
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
            '{"access_token":"fresh-token","user_id":"@owner:example.com",'
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
            '{"access_token":"fresh-token","user_id":"@owner:example.com",'
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
            '{"access_token":"fresh-token",'
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
            '{"access_token":"fresh-token",'
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
            '{"access_token":"fresh-token",'
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
            '{"access_token":"fresh-token",'
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
            '{"access_token":"fresh-token",'
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
            '{"access_token":"fresh-token",'
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
    final client = _NoSyncInitClient(
      'AuthBootstrapPasswordChangeTest',
      httpClient: MockClient((request) async {
        requestPaths.add(request.url.path);
        if (request.url.path == '/_p2p/command' ||
            request.url.path == '/_p2p/query') {
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
              '{"access_token":"fresh-token","user_id":"@owner:example.com",'
              '"homeserver":"https://example.com","device_id":"$requestedDeviceId"}',
              200,
            );
          }
          if (body['action'] == 'portal.password') {
            expect(request.method, 'POST');
            expect(request.headers['Authorization'], 'Bearer fresh-token');
            expect(body['params'], {
              'old_password': '11111111',
              'new_password': '22222222',
              'device_id': bootstrapDeviceId,
            });
            return http.Response(
              '{"access_token":"changed-matrix-token",'
              '"device_id":"$bootstrapDeviceId"}',
              200,
            );
          }
          if (body['action'] == 'sync.bootstrap') {
            expect(request.headers['Authorization'],
                'Bearer changed-matrix-token');
            return http.Response(
              '{"user":{"user_id":"@owner:example.com"},'
              '"rooms":[],"contacts":[],"groups":[],"channels":[],'
              '"pending":{}}',
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
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final auth = await container.read(authStateNotifierProvider.future);
    expect(auth.isLoggedIn, isTrue);
    expect(auth.userId, '@owner:example.com');
    expect(auth.homeserver, 'https://example.com');
    expect(auth.portalToken, 'changed-matrix-token');
    expect(client.accessToken, 'changed-matrix-token');
    expect(
      requestActions.indexOf('portal.bootstrap'),
      lessThan(requestActions.indexOf('portal.password')),
    );
    expect(requestActions, contains('sync.bootstrap'));
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.accessTokenKey),
      'changed-matrix-token',
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
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
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
            '{"access_token":"new-token",'
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
      newDeviceName: 'Direxio',
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

  test('profile setup uses latest stored AS bearer token', () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '11111111',
      AuthStateNotifier.profileInitializedKey: 'false',
    });
    final profileAuthorizations = <String>[];
    final passwordAuthorizations = <String>[];
    final client = Client(
      'AuthProfileSetupUsesLatestStoredAsBearerTokenTest',
      httpClient: MockClient((request) async {
        if (_p2pAction(request, 'profile.update') != null) {
          profileAuthorizations.add(request.headers['Authorization'] ?? '');
          return http.Response(
            '{"user_id":"@owner:example.com",'
            '"display_name":"Alice","domain":"example.com"}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.password') != null) {
          passwordAuthorizations.add(request.headers['Authorization'] ?? '');
          return http.Response(
            '{"access_token":"final-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1",'
            '"profile_initialized":true}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (request.url.path.startsWith('/_matrix/client/v3/profile/')) {
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
      newDeviceName: 'Direxio',
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );
    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);
    await container.read(authStateNotifierProvider.future);
    await const FlutterSecureStorage().write(
      key: AuthStateNotifier.accessTokenKey,
      value: 'fresh-admin-token',
    );

    await container
        .read(authStateNotifierProvider.notifier)
        .completeOwnerProfileSetup(
          displayName: 'Alice',
          newPortalToken: '12345678',
        );

    expect(profileAuthorizations, ['Bearer fresh-admin-token']);
    expect(passwordAuthorizations, ['Bearer fresh-admin-token']);
    final auth = container.read(authStateNotifierProvider).valueOrNull;
    expect(auth?.portalToken, 'final-token');
  });

  test('profile setup refreshes AS bearer after unknown token', () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '11111111',
      AuthStateNotifier.profileInitializedKey: 'false',
    });
    final profileAuthorizations = <String>[];
    final authPasswords = <String>[];
    final client = Client(
      'AuthProfileSetupRefreshesAsBearerAfterUnknownTokenTest',
      httpClient: MockClient((request) async {
        final profileUpdate = _p2pAction(request, 'profile.update');
        if (profileUpdate != null) {
          final authorization = request.headers['Authorization'] ?? '';
          profileAuthorizations.add(authorization);
          if (authorization == 'Bearer old-admin-token') {
            return http.Response(
              '{"errcode":"M_UNKNOWN_TOKEN","error":"Unknown token"}',
              401,
            );
          }
          expect(authorization, 'Bearer fresh-admin-token');
          return http.Response(
            '{"user_id":"@owner:example.com",'
            '"display_name":"Alice","domain":"example.com"}',
            200,
          );
        }
        final portalAuth = _p2pAction(request, 'portal.auth');
        if (portalAuth != null) {
          authPasswords.add(
            (portalAuth['params'] as Map<String, dynamic>)['password']
                as String,
          );
          return http.Response(
            '{"access_token":"fresh-admin-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1",'
            '"profile_initialized":false}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.password') != null) {
          expect(request.headers['Authorization'], 'Bearer fresh-admin-token');
          return http.Response(
            '{"access_token":"final-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1",'
            '"profile_initialized":true}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/keys/upload') {
          return http.Response('{"one_time_key_counts":{}}', 200);
        }
        if (request.url.path.startsWith('/_matrix/client/v3/profile/')) {
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
      newDeviceName: 'Direxio',
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );
    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);
    await container.read(authStateNotifierProvider.future);
    await const FlutterSecureStorage().write(
      key: AuthStateNotifier.accessTokenKey,
      value: 'old-admin-token',
    );

    await container
        .read(authStateNotifierProvider.notifier)
        .completeOwnerProfileSetup(
          displayName: 'Alice',
          newPortalToken: '12345678',
        );

    expect(profileAuthorizations, [
      'Bearer old-admin-token',
      'Bearer fresh-admin-token',
    ]);
    expect(authPasswords, isNotEmpty);
    expect(authPasswords, everyElement('11111111'));
    final auth = container.read(authStateNotifierProvider).valueOrNull;
    expect(auth?.portalToken, 'final-token');
  });

  test('profile setup stores new login password before Matrix token checks',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '11111111',
      AuthStateNotifier.profileInitializedKey: 'false',
    });
    var sawTokenOwnerAfterPasswordChange = false;
    final client = Client(
      'AuthProfileSetupStoresPasswordBeforeMatrixChecksTest',
      httpClient: MockClient((request) async {
        if (_p2pAction(request, 'profile.update') != null) {
          return http.Response(
            '{"user_id":"@owner:example.com",'
            '"display_name":"Alice","domain":"example.com"}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.password') != null) {
          return http.Response(
            '{"access_token":"new-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com","device_id":"DEVICE1",'
            '"profile_initialized":true}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          var authorization = '';
          for (final entry in request.headers.entries) {
            if (entry.key.toLowerCase() == 'authorization') {
              authorization = entry.value;
              break;
            }
          }
          if (authorization == 'Bearer new-token') {
            sawTokenOwnerAfterPasswordChange = true;
            expect(
              await const FlutterSecureStorage()
                  .read(key: AuthStateNotifier.lastLoginPortalTokenKey),
              '12345678',
            );
          }
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (request.url.path.startsWith('/_matrix/client/v3/profile/')) {
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
      newDeviceName: 'Direxio',
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

    expect(sawTokenOwnerAfterPasswordChange, isTrue);
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.lastLoginPortalTokenKey),
      '12345678',
    );
  });

  test('password change keeps initialized flag when response omits it',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
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
            '{"access_token":"new-token",'
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
      newDeviceName: 'Direxio',
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
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
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
            '{"access_token":"new-token",'
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
      newDeviceName: 'Direxio',
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

  test('password change restarts P2P sync with refreshed token', () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '11111111',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    final bootstrapAuthorizations = <String>[];
    final client = _NoSyncInitClient(
      'AuthPasswordChangeRestartsSyncTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.password') != null) {
          return http.Response(
            '{"access_token":"new-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"DEVICE1",'
            '"profile_initialized":true}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s1","rooms":{}}', 200);
        }
        if (_p2pAction(request, 'sync.bootstrap') != null) {
          bootstrapAuthorizations.add(request.headers['Authorization'] ?? '');
          return http.Response(
            '{"user":{"user_id":"@owner:example.com"},'
            '"rooms":[],"contacts":[],"groups":[],"channels":[],'
            '"pending":{}}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    await client.init(
      newToken: 'old-token',
      newUserID: '@owner:example.com',
      newHomeserver: Uri.parse('https://example.com'),
      newDeviceID: 'DEVICE1',
      newDeviceName: 'Direxio',
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
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(client.accessToken, 'new-token');
    expect(bootstrapAuthorizations, contains('Bearer new-token'));
    expect((await container.read(authStateNotifierProvider.future)).isLoggedIn,
        isTrue);
    expect(container.read(sessionExpiredNoticeProvider), 0);
  });

  test('password change ignores delayed Matrix 401 from previous token',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
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
            '{"access_token":"new-token",'
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
      newDeviceName: 'Direxio',
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
      isNot(false),
    );
    expect(container.read(sessionExpiredNoticeProvider), 0);
  });

  test('stale AS admin token failure does not expire refreshed session',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'fresh-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'fresh-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '11111111',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    final client = _NoSyncInitClient(
      'AuthStaleAsAdminFailureIgnoredTest',
      httpClient: MockClient((request) async {
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
        .expireSessionDueInvalidTokenIfCurrent('old-token');

    expect(
      container.read(authStateNotifierProvider).valueOrNull?.isLoggedIn,
      isNot(false),
    );
    expect(container.read(sessionExpiredNoticeProvider), 0);
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_token'),
      'fresh-token',
    );
  });

  test('stale AS client failure after password change keeps refreshed session',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '11111111',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    final bootstrapAuthorizations = <String>[];
    final client = _NoSyncInitClient(
      'AuthStaleAsClientFailureAfterPasswordChangeTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.password') != null) {
          return http.Response(
            '{"access_token":"new-token",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"DEVICE1",'
            '"profile_initialized":true}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response(
            '{"errcode":"M_FORBIDDEN","error":"old password rejected"}',
            403,
          );
        }
        if (_p2pAction(request, 'sync.bootstrap') != null) {
          final authorization = request.headers['Authorization'] ?? '';
          bootstrapAuthorizations.add(authorization);
          if (authorization == 'Bearer old-admin-token') {
            return http.Response(
              '{"errcode":"M_UNKNOWN_TOKEN","error":"Unknown token"}',
              401,
            );
          }
          if (authorization == 'Bearer new-token') {
            return http.Response(
              '{"user":{"user_id":"@owner:example.com"},'
              '"rooms":[],"contacts":[],"groups":[],"channels":[],'
              '"pending":{}}',
              200,
            );
          }
        }
        if (request.url.path == '/_matrix/client/v3/sync') {
          return http.Response('{"next_batch":"s1","rooms":{}}', 200);
        }
        if (request.url.path == '/_matrix/client/versions') {
          return http.Response('{"versions":["v1.1"]}', 200);
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response('{"flows":[{"type":"m.login.password"}]}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    await client.init(
      newToken: 'old-token',
      newUserID: '@owner:example.com',
      newHomeserver: Uri.parse('https://example.com'),
      newDeviceID: 'DEVICE1',
      newDeviceName: 'Direxio',
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );
    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);
    await container.read(authStateNotifierProvider.future);
    final authNotifier = container.read(authStateNotifierProvider.notifier);
    final staleAsClient = HttpAsClient.fromPortalSession(
      client,
      portalToken: 'old-admin-token',
      onAuthenticationRefresh: authNotifier.refreshPortalSessionForAsAdminToken,
      onAuthenticationFailedForToken:
          authNotifier.expireSessionDueInvalidTokenIfCurrent,
    );

    await container
        .read(authStateNotifierProvider.notifier)
        .changePortalPassword(
          oldPassword: '11111111',
          newPassword: '12345678',
        );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await expectLater(
      staleAsClient.syncBootstrap(),
      throwsA(isA<AsClientException>()),
    );

    expect(bootstrapAuthorizations, contains('Bearer old-admin-token'));
    expect(client.accessToken, 'new-token');
    expect(
      container.read(authStateNotifierProvider).valueOrNull?.isLoggedIn,
      isNot(false),
    );
    expect(container.read(sessionExpiredNoticeProvider), 0);
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_token'),
      'new-token',
    );
  });

  test('recent refreshed Matrix token rejection waits before expiring session',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: 'portal-pass',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    late MatrixTokenRefreshingHttpClient refreshingClient;
    final client = _NoSyncInitClient(
      'AuthRecentRefreshedTokenGraceTest',
      httpClient: refreshingClient = MatrixTokenRefreshingHttpClient(
        inner: MockClient((request) async {
          final authAction = _p2pAction(request, 'portal.auth');
          if (authAction != null) {
            expect(authAction['params'], {
              'password': 'portal-pass',
              'device_id': 'DEVICE1',
            });
            return http.Response(
              '{"access_token":"fresh-token",'
              '"user_id":"@owner:example.com",'
              '"homeserver":"https://example.com",'
              '"device_id":"DEVICE1",'
              '"profile_initialized":true}',
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      ),
    );
    final container = ProviderContainer(
      overrides: [matrixClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.clear);

    await container.read(authStateNotifierProvider.future);
    final refreshed = await refreshingClient.refreshAccessToken!();
    expect(refreshed, 'fresh-token');
    expect(client.accessToken, 'fresh-token');

    await container
        .read(authStateNotifierProvider.notifier)
        .expireSessionDueInvalidTokenIfCurrent('fresh-token');

    expect(
      container.read(authStateNotifierProvider).valueOrNull?.isLoggedIn,
      isNot(false),
    );
    expect(container.read(sessionExpiredNoticeProvider), 0);
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_token'),
      'fresh-token',
    );
  });

  test('transient portal refresh failure preserves stored login session',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'cached-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'cached-token',
      AuthStateNotifier.lastLoginPortalTokenKey: 'portal-pass',
      AuthStateNotifier.lastLoginHomeserverKey: 'https://example.com',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    final client = _NoSyncInitClient(
      'AuthTransientPortalRefreshPreservesSessionTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response('{"error":"temporarily unavailable"}', 503);
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
        .expireSessionDueInvalidTokenIfCurrent('cached-token');

    expect(
      container.read(authStateNotifierProvider).valueOrNull?.isLoggedIn,
      isNot(false),
    );
    expect(container.read(sessionExpiredNoticeProvider), 0);
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_token'),
      'cached-token',
    );
  });

  test('session expiry clears saved login secret', () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'expired-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'expired-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '11111111',
      AuthStateNotifier.lastLoginHomeserverKey: 'https://example.com',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    final client = _NoSyncInitClient(
      'AuthSessionExpiryPreservesLoginSecretTest',
      httpClient: MockClient((request) async {
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
        .expireSessionDueInvalidToken();

    expect(
      container.read(authStateNotifierProvider).valueOrNull?.isLoggedIn,
      isFalse,
    );
    expect(
        await const FlutterSecureStorage().read(key: 'matrix_token'), isNull);
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.accessTokenKey),
      isNull,
    );
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.lastLoginPortalTokenKey),
      isNull,
    );
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.profileInitializedKey),
      'true',
    );
  });

  test('AS 401 signed-in-elsewhere response expires local session', () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stale-admin-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'stale-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: 'oldpass123',
      AuthStateNotifier.lastLoginHomeserverKey: 'https://example.com',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    final client = _NoSyncInitClient(
      'AuthAsSignedInElsewhereExpiresSessionTest',
      httpClient: MockClient((request) async {
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE1"}',
            200,
          );
        }
        if (_p2pAction(request, 'sync.bootstrap') != null) {
          return http.Response(
            '{"error":"账号在其他设备登录，请重新登录"}',
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        if (_p2pAction(request, 'portal.auth') != null) {
          return http.Response(
            '{"error":"账号在其他设备登录，请重新登录"}',
            401,
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
    await client.init(
      newToken: 'stale-admin-token',
      newUserID: '@owner:example.com',
      newHomeserver: Uri.parse('https://example.com'),
      newDeviceID: 'DEVICE1',
      newDeviceName: 'Direxio',
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
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
    final auth = await container.read(authStateNotifierProvider.future);
    expect(auth.isLoggedIn, isTrue);
    expect(auth.portalToken, 'stale-admin-token');

    await expectLater(
      container.read(asClientProvider).syncBootstrap(),
      throwsA(
        isA<AsClientException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );

    expect(
      container.read(authStateNotifierProvider).valueOrNull?.isLoggedIn,
      isFalse,
    );
    expect(container.read(sessionExpiredNoticeProvider), greaterThan(0));
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_token'),
      isNull,
    );
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.accessTokenKey),
      isNull,
    );
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.lastLoginPortalTokenKey),
      isNull,
    );
  });

  test('logout preserves Matrix device store for same device login', () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'current-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE1',
      AuthStateNotifier.accessTokenKey: 'current-admin-token',
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
      newDeviceName: 'Direxio',
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
      isNull,
    );
    expect(
      await const FlutterSecureStorage()
          .read(key: AuthStateNotifier.profileInitializedKey),
      isNull,
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
      AuthStateNotifier.accessTokenKey: 'alice-admin-token',
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
            '{"access_token":"bob-token",'
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
      newDeviceName: 'Direxio',
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
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
    final initialAuth = await container.read(authStateNotifierProvider.future);
    expect(initialAuth.isLoggedIn, isTrue);

    await container.read(authStateNotifierProvider.notifier).logout();
    await container
        .read(authStateNotifierProvider.notifier)
        .login('https://example.com', 'bobpass12');

    final auth = container.read(authStateNotifierProvider).valueOrNull;
    expect(auth?.isLoggedIn, isTrue);
    expect(auth?.userId, '@bob:example.com');
    expect(auth?.portalToken, 'bob-token');
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
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
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
            '{"access_token":"changed-matrix-token",'
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
      newDeviceName: 'Direxio',
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
            '{"access_token":"token-${requestedDevices.length}",'
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

  test(
      'stored portal restore retries with a fresh device when key upload fails',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stored-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'OLDDEVICE',
      AuthStateNotifier.accessTokenKey: 'stale-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '12345678',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    final requestedDevices = <String>[];
    final client = _UploadKeyFailsForTokensClient(
      'AuthStoredRestoreUploadKeyRetryTest',
      failingTokens: {'stored-token', 'token-1'},
      httpClient: MockClient((request) async {
        final authAction = _p2pAction(request, 'portal.auth');
        if (authAction != null) {
          final params = authAction['params'] as Map<String, dynamic>;
          final deviceId = params['device_id'] as String;
          requestedDevices.add(deviceId);
          return http.Response(
            '{"access_token":"token-${requestedDevices.length}",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"$deviceId",'
            '"setup_completed":true}',
            200,
          );
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

    final auth = await container.read(authStateNotifierProvider.future);

    expect(auth.isLoggedIn, isTrue);
    expect(auth.requiresProfileSetup, isFalse);
    expect(requestedDevices, hasLength(2));
    expect(requestedDevices.first, 'OLDDEVICE');
    expect(requestedDevices.last, isNot('OLDDEVICE'));
    expect(client.accessToken, 'token-2');
    expect(client.deviceID, requestedDevices.last);
    expect(
      await const FlutterSecureStorage().read(key: 'matrix_device_id'),
      requestedDevices.last,
    );
  });

  test('portal session restore coalesces concurrent refreshes', () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'stored-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE_A',
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
      AuthStateNotifier.lastLoginPortalTokenKey: '12345678',
      AuthStateNotifier.profileInitializedKey: 'true',
    });
    var portalAuthCalls = 0;
    final client = _NoSyncInitClient(
      'AuthPortalRestoreSingleFlightTest',
      httpClient: MockClient((request) async {
        final authAction = _p2pAction(request, 'portal.auth');
        if (authAction != null) {
          portalAuthCalls++;
          final params = authAction['params'] as Map<String, dynamic>;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(
            '{"access_token":"token-$portalAuthCalls",'
            '"user_id":"@owner:example.com",'
            '"homeserver":"https://example.com",'
            '"device_id":"${params['device_id']}",'
            '"setup_completed":true}',
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/account/whoami') {
          return http.Response(
            '{"user_id":"@owner:example.com","device_id":"DEVICE_A"}',
            200,
          );
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
    portalAuthCalls = 0;

    final notifier = container.read(authStateNotifierProvider.notifier);
    final tokens = await Future.wait([
      notifier.refreshPortalSessionForAsAdminToken(),
      notifier.refreshPortalSessionForAsAdminToken(),
    ]);

    expect(portalAuthCalls, 1);
    expect(tokens, ['token-1', 'token-1']);
  });

  test('password change updates same-device token without clean Matrix init',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'matrix_token': 'old-token',
      'matrix_homeserver': 'https://example.com',
      'matrix_user_id': '@owner:example.com',
      'matrix_device_id': 'DEVICE_A',
      AuthStateNotifier.accessTokenKey: 'old-admin-token',
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
            '{"access_token":"token-1",'
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
            '{"access_token":"token-2",'
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
      newDeviceName: 'Direxio',
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
    expect(requestedDevices, ['DEVICE_A']);
    expect(requestedDevices[0], 'DEVICE_A');
    expect(client.accessToken, 'token-1');
    expect(client.deviceID, 'DEVICE_A');
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
      AuthStateNotifier.accessTokenKey: 'admin-a',
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
              '{"access_token":"token-a-new",'
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
      newDeviceName: 'Direxio',
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
              '{"access_token":"token-b",'
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

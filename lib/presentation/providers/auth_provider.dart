import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import '../../data/as_client.dart';
import '../../data/http_as_client.dart';
import '../../data/local_endpoint_resolver.dart';
import '../../data/matrix_privacy_sync.dart';
import '../../data/matrix_push_registration.dart';
import '../../data/matrix_sync_timeouts.dart';
import '../../data/matrix_token_refreshing_http_client.dart';
import '../../data/well_known_service.dart';
import '../../data/bi_analytics_service.dart';
import 'as_sync_cache_provider.dart';
import 'as_call_session_store_provider.dart';
import 'bi_analytics_provider.dart';
import 'chat_clear_state_provider.dart';
import 'channel_provider.dart';
import 'friend_request_read_provider.dart';
import 'local_created_channels_provider.dart';
import 'local_message_order_provider.dart';
import 'local_outbox_provider.dart';
import 'media_thumbnail_cache_provider.dart';

part 'auth_provider.g.dart';

final sessionExpiredNoticeProvider = StateProvider<int>((ref) => 0);

/// Portal 未在该域名部署（owner.json 返回 404）。
/// 对应 INTERFACE_SPEC.md §3.1：区分"未部署" vs "已初始化"。
class PortalNotDeployedException implements Exception {
  PortalNotDeployedException(this.domain);
  final String domain;
  @override
  String toString() => 'Portal 未在 $domain 部署';
}

// Matrix client singleton — 持久化到 IndexedDB（Web）或 SQLite（Native）。
// 不持久化的话，每次进入聊天页 Timeline.events 会是空（/sync 没存盘），历史拉不回。
@riverpod
Client matrixClient(Ref ref) {
  final rawHttpClient = http.Client();
  final refreshingHttpClient = MatrixTokenRefreshingHttpClient(
    inner: rawHttpClient,
  );
  late final Client client;

  client = Client(
    'Direxio',
    httpClient: refreshingHttpClient,
    databaseBuilder: (_) async {
      final db = kIsWeb
          ? MatrixSdkDatabase('portal_im_db')
          : MatrixSdkDatabase(
              'portal_im_db',
              database: await sqlite.openDatabase(
                '${(await getApplicationSupportDirectory()).path}/portal_im_matrix.sqlite',
                singleInstance: false,
              ),
            );
      await db.open();
      return db;
    },
  );
  refreshingHttpClient.onAuthenticationFailed = () async {
    await ref
        .read(authStateNotifierProvider.notifier)
        .expireSessionDueInvalidToken();
  };
  refreshingHttpClient.onAuthenticationFailedForToken = (failedToken) async {
    await ref
        .read(authStateNotifierProvider.notifier)
        .expireSessionDueInvalidTokenIfCurrent(failedToken);
  };
  ref.onDispose(refreshingHttpClient.close);
  return client;
}

class AuthState {
  const AuthState({
    required this.isLoggedIn,
    this.userId,
    this.homeserver,
    this.portalToken,
    this.ownerDisplayName,
    this.requiresInitialization = false,
  });

  final bool isLoggedIn;
  final String? userId;
  final String? homeserver;
  final String? portalToken;
  final String? ownerDisplayName;
  final bool requiresInitialization;

  bool get hasUsablePortalSession =>
      isLoggedIn && (portalToken?.trim().isNotEmpty ?? false);
}

class _ActivatedPortalSession {
  const _ActivatedPortalSession({
    required this.session,
    required this.homeserver,
    required this.userId,
    required this.deviceId,
  });

  final AsPortalSession session;
  final Uri homeserver;
  final String userId;
  final String deviceId;
}

Uri _resolveClientHomeserver(
  Uri inputUri,
  String asHomeserver, {
  LocalEndpointResolver? localEndpointResolver,
}) {
  final resolver = localEndpointResolver ?? LocalEndpointResolver.environment;
  final localDevInput = resolver.httpUriForUri(inputUri);
  if (localDevInput != null) return localDevInput;
  final parsed = Uri.tryParse(asHomeserver);
  if (parsed == null || parsed.host.isEmpty) return inputUri;
  final localDevSession = resolver.httpUriForUri(parsed);
  if (localDevSession != null) return localDevSession;
  if (_isLocalHost(inputUri.host)) {
    return inputUri;
  }
  if (_isLocalHost(parsed.host) && !_isLocalHost(inputUri.host)) {
    return inputUri;
  }
  return parsed;
}

@visibleForTesting
Uri resolveClientHomeserverForSession(
  Uri inputUri,
  String asHomeserver, {
  LocalEndpointResolver? localEndpointResolver,
}) =>
    _resolveClientHomeserver(
      inputUri,
      asHomeserver,
      localEndpointResolver: localEndpointResolver,
    );

bool _isLocalHost(String host) {
  return host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host == '0.0.0.0';
}

String _createDeviceId() {
  return 'PORTALIM${DateTime.now().microsecondsSinceEpoch}';
}

Future<String> _resolveSessionDeviceId({
  required http.Client httpClient,
  required Uri homeserver,
  required String accessToken,
  String? sessionDeviceId,
  String? storedDeviceId,
}) async {
  final tokenDeviceId = await _fetchTokenDeviceId(
    httpClient: httpClient,
    homeserver: homeserver,
    accessToken: accessToken,
  );
  if (tokenDeviceId != null && tokenDeviceId.isNotEmpty) {
    return tokenDeviceId;
  }

  final cleanSessionDeviceId = sessionDeviceId?.trim();
  if (cleanSessionDeviceId != null && cleanSessionDeviceId.isNotEmpty) {
    return cleanSessionDeviceId;
  }

  final cleanStoredDeviceId = storedDeviceId?.trim();
  if (cleanStoredDeviceId != null && cleanStoredDeviceId.isNotEmpty) {
    return cleanStoredDeviceId;
  }
  return _createDeviceId();
}

String _preferredSessionDeviceId(AsPortalSession session, String fallback) {
  final cleanFallback = fallback.trim();
  if (cleanFallback.isNotEmpty) return cleanFallback;
  final cleanSessionDeviceId = session.deviceId?.trim();
  if (cleanSessionDeviceId != null && cleanSessionDeviceId.isNotEmpty) {
    return cleanSessionDeviceId;
  }
  return _createDeviceId();
}

bool _hasStaleSameUserDevice(
  Client client,
  String nextUserId,
  String nextDeviceId,
) {
  final currentUserId = client.userID?.trim() ?? '';
  final currentDeviceId = client.deviceID?.trim() ?? '';
  final cleanNextUserId = nextUserId.trim();
  final cleanNextDeviceId = nextDeviceId.trim();
  return client.onLoginStateChanged.value == LoginState.loggedIn &&
      currentUserId.isNotEmpty &&
      currentUserId == cleanNextUserId &&
      currentDeviceId.isNotEmpty &&
      cleanNextDeviceId.isNotEmpty &&
      currentDeviceId != cleanNextDeviceId;
}

@visibleForTesting
bool portalSessionNeedsCleanMatrixInit({
  required String? currentAccessToken,
  required String? currentUserId,
  required String? currentDeviceId,
  required Uri? currentHomeserver,
  required String nextAccessToken,
  required String nextUserId,
  required String nextDeviceId,
  required Uri nextHomeserver,
}) {
  final currentUser = currentUserId?.trim() ?? '';
  final currentDevice = currentDeviceId?.trim() ?? '';
  final currentHost = currentHomeserver == null
      ? ''
      : '${currentHomeserver.scheme.toLowerCase()}://'
          '${currentHomeserver.host.toLowerCase()}'
          '${currentHomeserver.hasPort ? ':${currentHomeserver.port}' : ''}';
  final nextUser = nextUserId.trim();
  final nextDevice = nextDeviceId.trim();
  final nextHost = '${nextHomeserver.scheme.toLowerCase()}://'
      '${nextHomeserver.host.toLowerCase()}'
      '${nextHomeserver.hasPort ? ':${nextHomeserver.port}' : ''}';

  // Token refresh is only a credential update. Clearing Matrix here drops the
  // SDK's local room/message cache, so clean init is limited to identity moves.
  return currentUser != nextUser ||
      currentDevice != nextDevice ||
      currentHost != nextHost;
}

Future<String?> _fetchTokenDeviceId({
  required http.Client httpClient,
  required Uri homeserver,
  required String accessToken,
}) async {
  final uri = homeserver.replace(
    path: '/_matrix/client/v3/account/whoami',
    query: null,
    queryParameters: null,
  );
  try {
    final response = await httpClient.get(
      uri,
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded['device_id'] as String?;
  } catch (_) {
    return null;
  }
}

@riverpod
class AuthStateNotifier extends _$AuthStateNotifier {
  static const _storage = FlutterSecureStorage();
  static const _startupRestoreTimeout = Duration(seconds: 12);
  static const _freshInstallMarkerFileName = 'portal_im_install_marker_v1';
  static const accessTokenKey = 'access_token';
  static const initializedKey = 'initialized';
  static const lastLoginHomeserverKey = 'last_login_homeserver';
  static const lastLoginPortalTokenKey = 'last_login_portal_token';
  static const _legacyMatrixTokenKey = 'matrix_token';
  static const _legacyInitializedKey = 'profile_initialized';
  static const _accessTokenAppliedAtKey = 'access_token_applied_at_ms';
  static const _legacyMatrixTokenAppliedAtKey = 'matrix_token_applied_at_ms';
  static const _sessionStorageKeys = <String>[
    'matrix_homeserver',
    'matrix_user_id',
    'matrix_device_id',
    accessTokenKey,
    initializedKey,
    lastLoginHomeserverKey,
    lastLoginPortalTokenKey,
    _accessTokenAppliedAtKey,
  ];
  bool _sessionExpiredLocally = false;
  bool _isMounted = false;
  DateTime? _lastAccessTokenAppliedAt;
  bool _lastPortalRestoreNonRetryableFailure = false;
  bool _lastMatrixRefreshNonRetryableFailure = false;
  String? _portalRestoreInFlightKey;
  Future<AuthState?>? _portalRestoreInFlight;

  @override
  Future<AuthState> build() async {
    _isMounted = true;
    ref.onDispose(() => _isMounted = false);
    _configureMatrixTokenFailureHandler(ref.watch(matrixClientProvider));
    try {
      return await _buildRestoredAuthStateWithCancelableTimeout();
    } catch (e) {
      debugPrint(
        'startup auth restore failed; keeping stored credentials for retry: $e',
      );
      final fallback = await _storedAuthStateForRetry(
        client: ref.read(matrixClientProvider),
      );
      if (fallback != null) return fallback;
      return const AuthState(isLoggedIn: false);
    }
  }

  Future<AuthState> _buildRestoredAuthStateWithCancelableTimeout() {
    final completer = Completer<AuthState>();
    Timer? timeout;
    void complete(AuthState state) {
      if (!completer.isCompleted) completer.complete(state);
    }

    timeout = Timer(_startupRestoreTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('startup auth restore timed out'),
        );
      }
    });
    ref.onDispose(() {
      timeout?.cancel();
    });
    unawaited(
      _buildRestoredAuthState().then(complete).catchError((Object error) {
        if (!completer.isCompleted) completer.completeError(error);
      }).whenComplete(() => timeout?.cancel()),
    );
    return completer.future;
  }

  Future<AuthState> _buildRestoredAuthState() async {
    if (await _clearStaleIosKeychainAfterFreshInstallIfNeeded()) {
      return const AuthState(isLoggedIn: false);
    }
    final client = ref.watch(matrixClientProvider);
    final storedValues = await Future.wait<String?>([
      _storage.read(key: AuthStateNotifier.accessTokenKey),
      _storage.read(key: 'matrix_homeserver'),
      _storage.read(key: 'matrix_user_id'),
      _storage.read(key: initializedKey),
      _storage.read(key: lastLoginHomeserverKey),
      _storage.read(key: lastLoginPortalTokenKey),
    ]);
    final storedAccessToken = storedValues[0];
    final homeserver = storedValues[1];
    final userId = storedValues[2];
    final storedInitialized = _parseStoredBool(storedValues[3]);
    final lastLoginHomeserver = storedValues[4];
    final lastLoginPortalToken = storedValues[5];
    final restorePassword = (lastLoginPortalToken?.trim().isNotEmpty ?? false)
        ? lastLoginPortalToken
        : storedAccessToken;
    final storedHomeserver = homeserver ?? lastLoginHomeserver;
    if (_sessionExpiredLocally) {
      return const AuthState(isLoggedIn: false);
    }

    final restored = await _restoreMatrixSdkSession(client, storedAccessToken);
    if (_sessionExpiredLocally) return const AuthState(isLoggedIn: false);
    if (restored != null) {
      if (storedInitialized == false &&
          (restorePassword?.trim().isNotEmpty ?? false) &&
          (storedHomeserver?.trim().isNotEmpty ?? false)) {
        final refreshed = await _restorePortalSession(
          client,
          homeserver: storedHomeserver,
          portalToken: restorePassword,
        );
        if (_sessionExpiredLocally) return const AuthState(isLoggedIn: false);
        if (refreshed != null) return refreshed;
      }
      return restored;
    }

    if (storedAccessToken != null && homeserver != null && userId != null) {
      try {
        final homeserverUri = Uri.parse(homeserver);
        final deviceId =
            await _storage.read(key: 'matrix_device_id') ?? _createDeviceId();

        await client.init(
          newToken: storedAccessToken,
          newUserID: userId,
          newHomeserver: homeserverUri,
          newDeviceID: deviceId,
          newDeviceName: 'Direxio',
          waitForFirstSync: false,
          waitUntilLoadCompletedLoaded: false,
        );
        _refreshStoredMatrixSessionInBackground(
          client,
          homeserverUri,
          userId,
          storedAccessToken,
          deviceId,
        );
        await _loadChatClearState();
        if (_sessionExpiredLocally) {
          return const AuthState(isLoggedIn: false);
        }
        if (storedInitialized == false &&
            (restorePassword?.trim().isNotEmpty ?? false)) {
          final refreshed = await _restorePortalSession(
            client,
            homeserver: storedHomeserver,
            portalToken: restorePassword,
          );
          if (_sessionExpiredLocally) return const AuthState(isLoggedIn: false);
          if (refreshed != null) return refreshed;
        }
        final latestPortalToken =
            await _storage.read(key: AuthStateNotifier.accessTokenKey) ??
                storedAccessToken;
        return AuthState(
          isLoggedIn: true,
          userId: client.userID ?? userId,
          homeserver: (client.homeserver ?? homeserverUri).toString(),
          portalToken: latestPortalToken,
          requiresInitialization: storedInitialized == false,
        );
      } catch (e) {
        if (_isTokenFailure(e)) {
          final refreshed = await _restorePortalSession(
            client,
            homeserver: storedHomeserver,
            portalToken: restorePassword,
          );
          if (_sessionExpiredLocally) {
            return const AuthState(isLoggedIn: false);
          }
          if (refreshed != null) {
            return refreshed;
          }
          final fallback = await _storedAuthStateForRetry(
            client: client,
            token: storedAccessToken,
            homeserver: homeserver,
            userId: userId,
            portalToken: storedAccessToken,
            storedInitialized: storedInitialized,
          );
          if (fallback != null) {
            return fallback;
          }
        } else {
          debugPrint(
            'stored Matrix session init failed; preserving token for retry: $e',
          );
          if ((restorePassword?.trim().isNotEmpty ?? false) &&
              (storedHomeserver?.trim().isNotEmpty ?? false)) {
            final refreshed = await _restorePortalSession(
              client,
              homeserver: storedHomeserver,
              portalToken: restorePassword,
            );
            if (_sessionExpiredLocally) {
              return const AuthState(isLoggedIn: false);
            }
            if (refreshed != null) {
              return refreshed;
            }
          }
          final fallback = await _storedAuthStateForRetry(
            client: client,
            token: storedAccessToken,
            homeserver: homeserver,
            userId: userId,
            portalToken: storedAccessToken,
            storedInitialized: storedInitialized,
          );
          if (fallback != null) {
            return fallback;
          }
        }
      }
    }
    if ((restorePassword?.trim().isNotEmpty ?? false) &&
        (storedHomeserver?.trim().isNotEmpty ?? false)) {
      final portalRestored = await _restorePortalSession(
        client,
        homeserver: storedHomeserver,
        portalToken: restorePassword,
      );
      if (_sessionExpiredLocally) return const AuthState(isLoggedIn: false);
      if (portalRestored != null) return portalRestored;
    }
    return const AuthState(isLoggedIn: false);
  }

  Future<bool> _clearStaleIosKeychainAfterFreshInstallIfNeeded() async {
    if (kIsWeb || !Platform.isIOS) return false;
    final supportDir = await getApplicationSupportDirectory();
    final marker = File('${supportDir.path}/$_freshInstallMarkerFileName');
    if (await marker.exists()) return false;

    final hasExistingLocalState = await _applicationSupportHasExistingState(
      supportDir,
      marker.path,
    );
    final hasSecureSessionState = await _secureStorageHasSessionState();
    if (shouldClearStaleIosKeychainAfterFreshInstall(
      isIos: Platform.isIOS,
      markerExists: false,
      hasExistingLocalState: hasExistingLocalState,
      hasSecureSessionState: hasSecureSessionState,
    )) {
      await _storage.deleteAll();
      await marker.create(recursive: true);
      debugPrint(
        'fresh iOS install detected; cleared stale Keychain session state',
      );
      return true;
    }

    await marker.create(recursive: true);
    return false;
  }

  Future<bool> _applicationSupportHasExistingState(
    Directory supportDir,
    String markerPath,
  ) async {
    try {
      if (!await supportDir.exists()) return false;
      await for (final entity in supportDir.list(followLinks: false)) {
        if (entity.path == markerPath) continue;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('failed to inspect install marker state: $e');
      return true;
    }
  }

  Future<bool> _secureStorageHasSessionState() async {
    for (final key in _sessionStorageKeys) {
      final value = await _storage.read(key: key);
      if (value?.trim().isNotEmpty ?? false) return true;
    }
    return false;
  }

  Future<AuthState?> _storedAuthStateForRetry({
    required Client client,
    String? token,
    String? homeserver,
    String? userId,
    String? portalToken,
    bool? storedInitialized,
  }) async {
    if (_sessionExpiredLocally) return null;
    final values = token == null || homeserver == null || userId == null
        ? await Future.wait<String?>([
            _storage.read(key: AuthStateNotifier.accessTokenKey),
            _storage.read(key: 'matrix_homeserver'),
            _storage.read(key: 'matrix_user_id'),
            _storage.read(key: initializedKey),
            _storage.read(key: lastLoginPortalTokenKey),
          ])
        : null;
    final storedToken = (token ?? values?[0])?.trim() ?? '';
    final storedHomeserver = (homeserver ?? values?[1])?.trim() ?? '';
    final storedUserId = (userId ?? values?[2])?.trim() ?? '';
    final authPortalToken = (portalToken?.trim().isNotEmpty ?? false)
        ? portalToken!.trim()
        : ((values?[0]?.trim().isNotEmpty ?? false)
            ? values![0]!.trim()
            : values?[4]?.trim());
    final initialized = storedInitialized ?? _parseStoredBool(values?[3]);
    final homeserverUri = Uri.tryParse(storedHomeserver);
    if (storedToken.isEmpty ||
        storedHomeserver.isEmpty ||
        storedUserId.isEmpty ||
        homeserverUri == null ||
        homeserverUri.host.isEmpty) {
      return null;
    }
    client.homeserver = homeserverUri;
    client.accessToken = storedToken;
    client.setUserId(storedUserId);
    await _loadChatClearState();
    return AuthState(
      isLoggedIn: true,
      userId: storedUserId,
      homeserver: storedHomeserver,
      portalToken: authPortalToken,
      requiresInitialization: initialized == false,
    );
  }

  Future<void> _loadChatClearState() async {
    try {
      final store = await ref.read(chatClearStateStoreProvider.future);
      final clearedBeforeTs = await store.readClearedBeforeTs();
      final roomClearedBeforeTs = await store.readRoomClearedBeforeTs();
      if (clearedBeforeTs <= 0 && roomClearedBeforeTs.isEmpty) return;
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(
              localClearedBeforeTs: clearedBeforeTs,
              localRoomClearedBeforeTs: roomClearedBeforeTs,
            ),
          );
    } catch (e) {
      debugPrint('load chat clear state failed: $e');
    }
  }

  void _rememberSessionAgentRoomId(AsPortalSession session, {String? userId}) {
    final agentRoomId = session.agentRoomId?.trim() ?? '';
    if (agentRoomId.isEmpty) return;
    final effectiveUserId = (userId?.trim().isNotEmpty ?? false)
        ? userId!.trim()
        : session.userId.trim();
    ref.read(asSyncCacheProvider.notifier).update((cache) {
      final current = cache.bootstrap;
      final nextBootstrap = current == null
          ? AsSyncBootstrap(
              syncedAt: DateTime.now().toUtc(),
              user: AsSyncUser(userId: effectiveUserId),
              agentRoomId: agentRoomId,
              rooms: const [],
              contacts: const [],
              groups: const [],
              channels: const [],
              pending: const AsSyncPending.empty(),
            )
          : AsSyncBootstrap(
              syncedAt: current.syncedAt,
              user: current.user.userId.trim().isNotEmpty
                  ? current.user
                  : AsSyncUser(userId: effectiveUserId),
              agentRoomId: agentRoomId,
              rooms: current.rooms,
              contacts: current.contacts,
              groups: current.groups,
              channels: current.channels,
              pending: current.pending,
            );
      return cache.copyWith(
        bootstrap: nextBootstrap,
        localContactStatusesByRoomId: cache.localContactStatusesByRoomId,
        localContactEntriesByRoomId: cache.localContactEntriesByRoomId,
        localDeletedEventIdsByRoomId: cache.localDeletedEventIdsByRoomId,
        localReadMarkersByRoomId: cache.localReadMarkersByRoomId,
        localRoomClearedBeforeTs: cache.localRoomClearedBeforeTs,
      );
    });
  }

  Future<void> login(String homeserverUrl, String portalToken) async {
    _sessionExpiredLocally = false;
    await _loginWithPortal(homeserverUrl, portalToken);
  }

  Future<_PortalLoginResult> _loginWithPortal(
    String homeserverUrl,
    String portalToken, {
    String? displayName,
    bool publishState = true,
    bool useBootstrap = false,
  }) async {
    final client = ref.read(matrixClientProvider);
    final inputUri = _normalizeHomeserverUri(homeserverUrl);
    final cleanPortalToken = portalToken.trim();
    if (cleanPortalToken.isEmpty) {
      throw ArgumentError('登录密码 不能为空');
    }
    final requestedDeviceId = await _localMatrixDeviceId(client);

    final baseUri = HttpAsClient.defaultProductBaseUri(inputUri);
    var session = useBootstrap
        ? await HttpAsClient.bootstrapPortal(
            baseUri: baseUri,
            setupCode: cleanPortalToken,
            deviceId: requestedDeviceId,
            httpClient: client.httpClient,
          )
        : await HttpAsClient.authenticatePortal(
            baseUri: baseUri,
            portalToken: cleanPortalToken,
            deviceId: requestedDeviceId,
            httpClient: client.httpClient,
          );
    final storedUserId = await _storage.read(key: 'matrix_user_id');
    final storedHomeserver = await _storage.read(key: 'matrix_homeserver');
    // 认证成功后再读取 owner.json，用于确认 Portal owner 信息。
    await _assertPortalDeployed(inputUri.host);
    var effectivePortalToken = session.accessToken.trim();
    final matrixUri = _resolveClientHomeserver(inputUri, session.homeserver);

    if (_shouldResetUserScopedLocalStateForLogin(
      client,
      session.userId,
      storedUserId: storedUserId,
      nextHomeserver: matrixUri,
      storedHomeserver: storedHomeserver,
    )) {
      await _clearUserScopedLocalState(client);
    }
    await client.checkHomeserver(matrixUri);
    var checkedHomeserver = client.homeserver ?? matrixUri;
    final storedDeviceId = await _storage.read(key: 'matrix_device_id');
    var deviceId = await _resolveSessionDeviceId(
      httpClient: client.httpClient,
      homeserver: checkedHomeserver,
      accessToken: session.accessToken,
      sessionDeviceId: session.deviceId,
      storedDeviceId: storedDeviceId,
    );
    final hasStaleSameUserDevice = _hasStaleSameUserDevice(
      client,
      session.userId,
      deviceId,
    );
    if (hasStaleSameUserDevice) {
      await _clearMatrixForCleanInit(client);
    }
    await _establishPrivacyBaselineBeforeInit(
      client,
      homeserver: checkedHomeserver,
      accessToken: session.accessToken,
      userId: session.userId,
      deviceId: deviceId,
    );

    try {
      if (_isLoggedInAs(client, session.userId)) {
        await _applyRefreshedSession(
          client,
          checkedHomeserver,
          session,
          portalToken: effectivePortalToken,
          deviceId: deviceId,
        );
      } else {
        await _initMatrixSessionWithKeyUploadRetry(
          client,
          accessToken: session.accessToken,
          userId: session.userId,
          homeserver: checkedHomeserver,
          deviceId: deviceId,
        );
      }
    } catch (error) {
      if (!_isUploadKeyFailure(error)) rethrow;
      debugPrint(
        'Matrix key upload failed after portal auth; retrying fresh device',
      );
      final freshDeviceId = _createDeviceId();
      session = useBootstrap
          ? await HttpAsClient.bootstrapPortal(
              baseUri: baseUri,
              setupCode: cleanPortalToken,
              deviceId: freshDeviceId,
              httpClient: client.httpClient,
            )
          : await HttpAsClient.authenticatePortal(
              baseUri: baseUri,
              portalToken: cleanPortalToken,
              deviceId: freshDeviceId,
              httpClient: client.httpClient,
            );
      effectivePortalToken = session.accessToken.trim();
      final retryMatrixUri = _resolveClientHomeserver(
        inputUri,
        session.homeserver,
      );
      await _clearMatrixForCleanInit(client);
      await client.checkHomeserver(retryMatrixUri);
      checkedHomeserver = client.homeserver ?? retryMatrixUri;
      deviceId = await _resolveSessionDeviceId(
        httpClient: client.httpClient,
        homeserver: checkedHomeserver,
        accessToken: session.accessToken,
        sessionDeviceId: session.deviceId,
        storedDeviceId: freshDeviceId,
      );
      await _establishPrivacyBaselineBeforeInit(
        client,
        homeserver: checkedHomeserver,
        accessToken: session.accessToken,
        userId: session.userId,
        deviceId: deviceId,
      );
      await _initMatrixSessionWithKeyUploadRetry(
        client,
        accessToken: session.accessToken,
        userId: session.userId,
        homeserver: checkedHomeserver,
        deviceId: deviceId,
      );
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      await client.setDisplayName(session.userId, displayName.trim());
    }
    final initialized = _sessionInitialized(session);
    _rememberSessionAgentRoomId(session, userId: client.userID);
    await _persistSession(
      client,
      checkedHomeserver,
      portalToken: effectivePortalToken,
      deviceId: deviceId,
      initialized: initialized,
      loginPortalToken: cleanPortalToken,
    );
    final result = _PortalLoginResult(
      userId: client.userID,
      homeserver: checkedHomeserver,
      portalToken: effectivePortalToken,
      deviceId: deviceId,
    );
    final ownerDisplayName = await _loadOwnerDisplayNameForLogin(
      client,
      homeserver: checkedHomeserver,
      portalToken: effectivePortalToken,
    );
    if (publishState) {
      final requiresInitialization = initialized == false;
      state = AsyncData(
        AuthState(
          isLoggedIn: true,
          userId: result.userId,
          homeserver: result.homeserver.toString(),
          portalToken: result.portalToken,
          ownerDisplayName: ownerDisplayName,
          requiresInitialization: requiresInitialization,
        ),
      );
      _startPostLoginConversationSync(
        client,
        homeserver: checkedHomeserver,
        portalToken: effectivePortalToken,
      );
    }
    reportBiInBackground(
      () => ref.read(biAnalyticsServiceProvider).reportLogin(
            homeserver: checkedHomeserver.toString(),
            userId: client.userID ?? session.userId,
          ),
    );
    return result;
  }

  bool? _sessionInitialized(AsPortalSession session) => session.initialized;

  Future<String?> _loadOwnerDisplayNameForLogin(
    Client client, {
    required Uri homeserver,
    required String portalToken,
  }) async {
    try {
      final ownerProfile = await HttpAsClient.fromPortalSession(
        client,
        portalToken: portalToken,
        baseUri: HttpAsClient.defaultProductBaseUri(homeserver),
      ).getOwnerProfile().timeout(const Duration(seconds: 2));
      return ownerProfile.displayName;
    } on TimeoutException {
      debugPrint('P2P owner profile timed out during login');
      return null;
    } catch (e) {
      debugPrint('P2P owner profile failed during login: $e');
      return null;
    }
  }

  void _startPostLoginConversationSync(
    Client client, {
    required Uri homeserver,
    required String portalToken,
  }) {
    unawaited(_syncConversationsAfterLogin(
      client,
      homeserver: homeserver,
      portalToken: portalToken,
    ));
  }

  Future<void> _syncConversationsAfterLogin(
    Client client, {
    required Uri homeserver,
    required String portalToken,
  }) async {
    await Future.wait([
      _syncMatrixRoomsAfterLogin(client),
      _syncAsBootstrapAfterLogin(client, homeserver, portalToken),
    ]);
  }

  Future<void> _syncMatrixRoomsAfterLogin(Client client) async {
    try {
      await client.oneShotSync().timeout(matrixForegroundSyncTimeout);
    } catch (e) {
      debugPrint('post-login Matrix room sync failed: $e');
    }
  }

  Future<void> _syncAsBootstrapAfterLogin(
    Client client,
    Uri homeserver,
    String portalToken,
  ) async {
    try {
      final bootstrap = await HttpAsClient.fromPortalSession(
        client,
        portalToken: portalToken,
        baseUri: HttpAsClient.defaultProductBaseUri(homeserver),
      ).syncBootstrap().timeout(const Duration(seconds: 10));
      if (!asBootstrapBelongsToUser(bootstrap, client.userID)) {
        debugPrint(
          'post-login ignored P2P bootstrap for ${bootstrap.user.userId}; '
          'current user is ${client.userID}',
        );
        return;
      }
      if (!_isMounted) return;
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
    } catch (e) {
      debugPrint('post-login P2P bootstrap sync failed: $e');
    }
  }

  Future<void> register(
    String homeserverUrl,
    String portalToken,
    String displayName,
  ) async {
    await _loginWithPortal(
      homeserverUrl,
      portalToken,
      displayName: displayName,
    );
  }

  Future<void> completeInitialization({
    String displayName = '',
    required String newPortalToken,
    String avatarUrl = '',
  }) async {
    final cleanDisplayName = displayName.trim();
    final cleanAvatarUrl = avatarUrl.trim();
    if (cleanDisplayName.isEmpty) {
      throw ArgumentError('用户昵称不能为空');
    }
    final cleanToken = _validatePortalLoginToken(newPortalToken);
    final client = ref.read(matrixClientProvider);
    final auth = state.valueOrNull;
    final currentPortalToken = await _currentAsBearerToken(auth);
    if (currentPortalToken == null || currentPortalToken.trim().isEmpty) {
      throw StateError('当前 P2P 登录态缺失，请重新登录');
    }
    final currentLoginPassword =
        (await _storage.read(key: lastLoginPortalTokenKey))?.trim();
    if (currentLoginPassword == null || currentLoginPassword.isEmpty) {
      throw StateError('当前旧密码缺失，请重新登录');
    }
    final homeserver = client.homeserver ??
        Uri.tryParse(auth?.homeserver ?? '') ??
        Uri.tryParse(await _storage.read(key: 'matrix_homeserver') ?? '');
    if (homeserver == null) {
      throw StateError('当前 Portal 地址缺失，请重新登录');
    }

    final asClient = HttpAsClient.fromPortalSession(
      client,
      portalToken: currentPortalToken.trim(),
      baseUri: HttpAsClient.defaultProductBaseUri(homeserver),
      onAuthenticationRefresh: refreshPortalSessionForAsBearerToken,
      onAuthenticationFailed: expireSessionDueInvalidToken,
    );
    var session = await asClient.changePortalPassword(
      oldPassword: currentLoginPassword,
      newPassword: cleanToken,
      deviceId: await _localMatrixDeviceId(client),
    );
    var matrixUri = _resolveClientHomeserver(homeserver, session.homeserver);
    var deviceId = await _resolveSessionDeviceId(
      httpClient: client.httpClient,
      homeserver: matrixUri,
      accessToken: session.accessToken,
      sessionDeviceId: session.deviceId,
      storedDeviceId: await _storage.read(key: 'matrix_device_id'),
    );
    var userId = session.userId.trim().isNotEmpty
        ? session.userId
        : auth?.userId ?? client.userID ?? '';
    try {
      await _applyRefreshedSession(
        client,
        matrixUri,
        session,
        portalToken: session.accessToken,
        deviceId: deviceId,
        loginPortalToken: cleanToken,
        initialized: _sessionInitialized(session) ?? true,
      );
    } catch (error) {
      if (!_isUploadKeyFailure(error)) rethrow;
      final recovered = await _authenticateFreshDeviceAfterUploadKeyFailure(
        client,
        homeserver: homeserver,
        loginPassword: cleanToken,
        fallbackUserId: auth?.userId,
        initialized: _sessionInitialized(session) ?? true,
        logContext: 'initialization',
      );
      session = recovered.session;
      matrixUri = recovered.homeserver;
      userId = recovered.userId;
      deviceId = recovered.deviceId;
    }
    final profileClient = HttpAsClient.fromPortalSession(
      client,
      portalToken: session.accessToken,
      baseUri: HttpAsClient.defaultProductBaseUri(matrixUri),
      onAuthenticationRefresh: refreshPortalSessionForAsBearerToken,
      onAuthenticationFailed: expireSessionDueInvalidToken,
    );
    final profile = await profileClient.updateOwnerProfile(
      displayName: cleanDisplayName,
      avatarUrl: cleanAvatarUrl,
    );
    if (userId.isNotEmpty) {
      await client.setDisplayName(userId, cleanDisplayName);
      if (cleanAvatarUrl.isNotEmpty) {
        await client.setAvatarUrl(userId, Uri.parse(cleanAvatarUrl));
      }
    }
    final savedDisplayName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : cleanDisplayName;
    state = AsyncData(
      AuthState(
        isLoggedIn: true,
        userId: userId,
        homeserver: matrixUri.toString(),
        portalToken: session.accessToken,
        ownerDisplayName: savedDisplayName,
        requiresInitialization: false,
      ),
    );
    _startPostLoginConversationSync(
      client,
      homeserver: matrixUri,
      portalToken: session.accessToken,
    );
  }

  Future<void> ensureFreshMatrixSession() async {
    final client = ref.read(matrixClientProvider);
    final auth = state.valueOrNull;
    final homeserver = client.homeserver ??
        Uri.tryParse(auth?.homeserver ?? '') ??
        Uri.tryParse(await _storage.read(key: 'matrix_homeserver') ?? '');
    final userId = client.userID ??
        auth?.userId ??
        await _storage.read(key: 'matrix_user_id');
    final portalToken = auth?.portalToken ??
        await _storage.read(key: AuthStateNotifier.accessTokenKey);
    final deviceId = client.deviceID ??
        await _storage.read(key: 'matrix_device_id') ??
        _createDeviceId();

    if (homeserver == null || userId == null || userId.isEmpty) return;
    await _ensureCurrentSessionValid(
      client,
      homeserver,
      userId,
      portalToken,
      deviceId,
    );
  }

  Future<String?> refreshPortalSessionForAsBearerToken() async {
    final restored = await _refreshPortalSessionFromStoredLogin();
    if (restored == null || _sessionExpiredLocally) return null;
    if (_isMounted) {
      state = AsyncData(restored);
    }
    return restored.portalToken;
  }

  Future<String?> _currentAsBearerToken(AuthState? auth) async {
    final stored =
        (await _storage.read(key: AuthStateNotifier.accessTokenKey))?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    final stateToken = auth?.portalToken?.trim();
    if (stateToken != null && stateToken.isNotEmpty) return stateToken;
    return null;
  }

  Future<String?> _portalLoginTokenForRefresh(AuthState? auth) async {
    final loginToken =
        (await _storage.read(key: lastLoginPortalTokenKey))?.trim();
    if (loginToken != null && loginToken.isNotEmpty) return loginToken;
    return _currentAsBearerToken(auth);
  }

  Future<AuthState?> _refreshPortalSessionFromStoredLogin() async {
    if (_sessionExpiredLocally) return null;
    final client = ref.read(matrixClientProvider);
    final auth = state.valueOrNull;
    final homeserver = client.homeserver ??
        Uri.tryParse(auth?.homeserver ?? '') ??
        Uri.tryParse(await _storage.read(key: 'matrix_homeserver') ?? '') ??
        Uri.tryParse(await _storage.read(key: lastLoginHomeserverKey) ?? '');
    if (homeserver == null) return null;
    final portalToken = await _portalLoginTokenForRefresh(auth);
    return _restorePortalSession(
      client,
      homeserver: homeserver.toString(),
      portalToken: portalToken,
    );
  }

  Future<AuthState?> _refreshMatrixAccessTokenForHttpRetry() async {
    if (_sessionExpiredLocally) return null;
    _lastMatrixRefreshNonRetryableFailure = false;
    final client = ref.read(matrixClientProvider);
    final auth = state.valueOrNull;
    final homeserver = client.homeserver ??
        Uri.tryParse(auth?.homeserver ?? '') ??
        Uri.tryParse(await _storage.read(key: 'matrix_homeserver') ?? '') ??
        Uri.tryParse(await _storage.read(key: lastLoginHomeserverKey) ?? '');
    if (homeserver == null) return null;
    final loginPortalToken =
        (await _storage.read(key: lastLoginPortalTokenKey))?.trim();
    final portalToken = (loginPortalToken?.isNotEmpty ?? false)
        ? loginPortalToken!
        : (auth?.portalToken ??
                await _storage.read(key: AuthStateNotifier.accessTokenKey))
            ?.trim();
    if (portalToken == null || portalToken.isEmpty) return null;
    final deviceId = client.deviceID ??
        await _storage.read(key: 'matrix_device_id') ??
        _createDeviceId();
    final AsPortalSession session;
    try {
      session = await HttpAsClient.authenticatePortal(
        baseUri: HttpAsClient.defaultProductBaseUri(homeserver),
        portalToken: portalToken,
        deviceId: deviceId,
        httpClient: _rawHttpClient(client),
      );
    } catch (e) {
      _lastMatrixRefreshNonRetryableFailure =
          _isNonRetryablePortalAuthFailure(e);
      final action = _lastMatrixRefreshNonRetryableFailure
          ? 'will expire session'
          : 'keeping session';
      debugPrint('Matrix access token refresh failed; $action: $e');
      return null;
    }
    final matrixUri = _resolveClientHomeserver(homeserver, session.homeserver);
    final effectiveUserId = session.userId.trim().isNotEmpty
        ? session.userId
        : client.userID ?? await _storage.read(key: 'matrix_user_id') ?? '';
    if (effectiveUserId.isEmpty) return null;
    final effectiveDeviceId = _preferredSessionDeviceId(session, deviceId);
    final currentUserId = client.userID?.trim() ?? '';
    if (currentUserId.isNotEmpty && currentUserId != effectiveUserId) {
      return null;
    }
    client.homeserver = matrixUri;
    client.accessToken = session.accessToken;
    _lastAccessTokenAppliedAt = DateTime.now();
    await client.database?.updateClient(
      matrixUri.toString(),
      session.accessToken,
      null,
      null,
      effectiveUserId,
      effectiveDeviceId,
      client.deviceName ?? 'Direxio',
      client.prevBatch,
      client.encryption?.pickledOlmAccount,
    );
    await _persistSession(
      client,
      matrixUri,
      portalToken: session.accessToken,
      deviceId: effectiveDeviceId,
      userId: effectiveUserId,
      initialized: _sessionInitialized(session),
      loginPortalToken: portalToken,
    );
    await _loadChatClearState();
    return AuthState(
      isLoggedIn: true,
      userId: effectiveUserId,
      homeserver: matrixUri.toString(),
      portalToken: session.accessToken,
      requiresInitialization: _sessionInitialized(session) == false,
    );
  }

  Future<void> changePortalPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final cleanOldPassword = oldPassword.trim();
    final cleanNewPassword = _validatePortalLoginToken(newPassword);
    if (cleanOldPassword.length < 8) {
      throw ArgumentError('原密码至少 8 位');
    }
    if (cleanOldPassword.contains(RegExp(r'\s'))) {
      throw ArgumentError('原密码不能包含空格');
    }

    final client = ref.read(matrixClientProvider);
    final auth = state.valueOrNull;
    final currentPortalToken = await _currentAsBearerToken(auth);
    if (currentPortalToken == null || currentPortalToken.trim().isEmpty) {
      throw StateError('当前登录口令缺失，请重新登录');
    }
    final homeserver = client.homeserver ??
        Uri.tryParse(auth?.homeserver ?? '') ??
        Uri.tryParse(await _storage.read(key: 'matrix_homeserver') ?? '');
    if (homeserver == null) {
      throw StateError('当前 Portal 地址缺失，请重新登录');
    }

    final asClient = HttpAsClient.fromPortalSession(
      client,
      portalToken: currentPortalToken.trim(),
      baseUri: HttpAsClient.defaultProductBaseUri(homeserver),
      onAuthenticationRefresh: refreshPortalSessionForAsBearerToken,
      onAuthenticationFailed: expireSessionDueInvalidToken,
    );
    var session = await asClient.changePortalPassword(
      oldPassword: cleanOldPassword,
      newPassword: cleanNewPassword,
      deviceId: await _localMatrixDeviceId(client),
    );
    var matrixUri = _resolveClientHomeserver(homeserver, session.homeserver);
    var userId = session.userId.trim().isNotEmpty
        ? session.userId
        : auth?.userId ?? client.userID ?? '';
    var deviceId = await _resolveSessionDeviceId(
      httpClient: client.httpClient,
      homeserver: matrixUri,
      accessToken: session.accessToken,
      sessionDeviceId: session.deviceId,
      storedDeviceId: await _storage.read(key: 'matrix_device_id'),
    );
    const fallbackInitialized = true;
    try {
      await _applyRefreshedSession(
        client,
        matrixUri,
        session,
        portalToken: session.accessToken,
        deviceId: deviceId,
        loginPortalToken: cleanNewPassword,
        initialized: _sessionInitialized(session) ?? fallbackInitialized,
      );
    } catch (error) {
      if (!_isUploadKeyFailure(error)) rethrow;
      final recovered = await _authenticateFreshDeviceAfterUploadKeyFailure(
        client,
        homeserver: homeserver,
        loginPassword: cleanNewPassword,
        fallbackUserId: auth?.userId,
        initialized: _sessionInitialized(session) ?? fallbackInitialized,
        logContext: 'password change',
      );
      session = recovered.session;
      matrixUri = recovered.homeserver;
      userId = recovered.userId;
      deviceId = recovered.deviceId;
    }
    final initialized = _sessionInitialized(session) ?? true;
    state = AsyncData(
      AuthState(
        isLoggedIn: true,
        userId: userId,
        homeserver: matrixUri.toString(),
        portalToken: session.accessToken,
        ownerDisplayName: auth?.ownerDisplayName,
        requiresInitialization: initialized == false,
      ),
    );
  }

  Future<void> bootstrapAndChangePortalToken(
    String homeserverUrl,
    String setupCode,
    String newToken,
  ) async {
    final cleanSetupCode = setupCode.trim();
    final cleanNewToken = _validatePortalLoginToken(newToken);
    final result = await _loginWithPortal(
      homeserverUrl,
      cleanSetupCode,
      publishState: false,
      useBootstrap: true,
    );

    final client = ref.read(matrixClientProvider);
    final currentPortalToken = result.portalToken.trim().isNotEmpty
        ? result.portalToken
        : cleanSetupCode;
    final asClient = HttpAsClient.fromPortalSession(
      client,
      portalToken: currentPortalToken,
      baseUri: HttpAsClient.defaultProductBaseUri(result.homeserver),
    );
    final session = await asClient.changePortalPassword(
      oldPassword: cleanSetupCode,
      newPassword: cleanNewToken,
      deviceId: await _localMatrixDeviceId(client),
    );
    final matrixUri = _resolveClientHomeserver(
      result.homeserver,
      session.homeserver,
    );
    final userId = session.userId.trim().isNotEmpty
        ? session.userId
        : result.userId ?? client.userID ?? '';
    final deviceId = await _resolveSessionDeviceId(
      httpClient: client.httpClient,
      homeserver: matrixUri,
      accessToken: session.accessToken,
      sessionDeviceId: session.deviceId,
      storedDeviceId: result.deviceId,
    );
    await _applyRefreshedSession(
      client,
      matrixUri,
      session,
      portalToken: session.accessToken,
      deviceId: deviceId,
      loginPortalToken: cleanNewToken,
      initialized: _sessionInitialized(session) ?? true,
    );
    state = AsyncData(
      AuthState(
        isLoggedIn: true,
        userId: userId,
        homeserver: matrixUri.toString(),
        portalToken: session.accessToken,
        requiresInitialization: false,
      ),
    );
  }

  Future<AuthState?> _restoreMatrixSdkSession(
    Client client,
    String? portalToken,
  ) async {
    try {
      if (client.onLoginStateChanged.value != LoginState.loggedIn) {
        await client.init(
          waitForFirstSync: false,
          waitUntilLoadCompletedLoaded: false,
        );
      }
      if (!client.isLogged()) return null;
      String? userId;
      try {
        final tokenOwner = await client.getTokenOwner();
        userId = client.userID ?? tokenOwner.userId;
      } catch (e) {
        if (_isTokenFailure(e)) {
          final refreshed = await _restorePortalSession(
            client,
            homeserver: client.homeserver?.toString() ??
                await _storage.read(key: 'matrix_homeserver') ??
                await _storage.read(key: lastLoginHomeserverKey),
            portalToken: portalToken ??
                await _storage.read(key: AuthStateNotifier.accessTokenKey) ??
                await _storage.read(key: lastLoginPortalTokenKey),
          );
          if (refreshed != null) return refreshed;
          return null;
        } else {
          userId = client.userID;
        }
      }
      final homeserver = client.homeserver;
      final accessToken = client.accessToken;
      if (homeserver == null ||
          accessToken == null ||
          userId == null ||
          userId.isEmpty) {
        return null;
      }

      await _storage.write(
          key: AuthStateNotifier.accessTokenKey, value: accessToken);
      await _storage.write(
          key: 'matrix_homeserver', value: homeserver.toString());
      await _storage.write(key: 'matrix_user_id', value: userId);
      await _storage.write(
        key: 'matrix_device_id',
        value: client.deviceID ?? _createDeviceId(),
      );
      await _loadChatClearState();
      return AuthState(
        isLoggedIn: true,
        userId: userId,
        homeserver: homeserver.toString(),
        portalToken: (portalToken?.trim().isNotEmpty ?? false)
            ? portalToken
            : accessToken,
        requiresInitialization:
            _parseStoredBool(await _storage.read(key: initializedKey)) == false,
      );
    } catch (_) {
      return null;
    }
  }

  void _refreshStoredMatrixSessionInBackground(
    Client client,
    Uri homeserver,
    String userId,
    String? portalToken,
    String deviceId,
  ) {
    unawaited(
      Future<void>.delayed(
        Duration.zero,
        () => _ensureCurrentSessionValid(
          client,
          homeserver,
          userId,
          portalToken,
          deviceId,
        ),
      ).timeout(const Duration(seconds: 10)).catchError((Object e) {
        debugPrint('background Matrix session refresh skipped: $e');
      }),
    );
  }

  Future<AuthState?> _restorePortalSession(
    Client client, {
    required String? homeserver,
    required String? portalToken,
  }) async {
    final restoreKey =
        '${homeserver?.trim() ?? ''}|${portalToken?.trim() ?? ''}';
    final inFlight = _portalRestoreInFlight;
    if (inFlight != null && _portalRestoreInFlightKey == restoreKey) {
      return inFlight;
    }
    late final Future<AuthState?> future;
    future = _restorePortalSessionUncoalesced(
      client,
      homeserver: homeserver,
      portalToken: portalToken,
    ).whenComplete(() {
      if (identical(_portalRestoreInFlight, future)) {
        _portalRestoreInFlight = null;
        _portalRestoreInFlightKey = null;
      }
    });
    _portalRestoreInFlightKey = restoreKey;
    _portalRestoreInFlight = future;
    return future;
  }

  Future<AuthState?> _restorePortalSessionUncoalesced(
    Client client, {
    required String? homeserver,
    required String? portalToken,
  }) async {
    _lastPortalRestoreNonRetryableFailure = false;
    final cleanPortalToken = portalToken?.trim() ?? '';
    if (cleanPortalToken.isEmpty) return null;
    final homeserverUri = Uri.tryParse(homeserver?.trim() ?? '');
    if (homeserverUri == null || homeserverUri.host.isEmpty) return null;
    final loginPortalToken =
        (await _storage.read(key: lastLoginPortalTokenKey))?.trim();
    final authPortalToken = (loginPortalToken?.isNotEmpty ?? false)
        ? loginPortalToken!
        : cleanPortalToken;

    try {
      final requestedDeviceId = await _localMatrixDeviceId(client);
      var session = await HttpAsClient.authenticatePortal(
        baseUri: HttpAsClient.defaultProductBaseUri(homeserverUri),
        portalToken: authPortalToken,
        deviceId: requestedDeviceId,
        httpClient: client.httpClient,
      );
      var effectivePortalToken = session.accessToken.trim();
      var matrixUri = _resolveClientHomeserver(
        homeserverUri,
        session.homeserver,
      );
      var deviceId = await _resolveSessionDeviceId(
        httpClient: client.httpClient,
        homeserver: matrixUri,
        accessToken: session.accessToken,
        sessionDeviceId: session.deviceId,
        storedDeviceId: await _storage.read(key: 'matrix_device_id'),
      );
      var initialized = _sessionInitialized(session);
      try {
        if (client.onLoginStateChanged.value == LoginState.loggedIn) {
          await _applyRefreshedSession(
            client,
            matrixUri,
            session,
            portalToken: effectivePortalToken,
            deviceId: deviceId,
            loginPortalToken: authPortalToken,
            initialized: initialized,
          );
        } else {
          await _initMatrixSessionWithKeyUploadRetry(
            client,
            accessToken: session.accessToken,
            userId: session.userId,
            homeserver: matrixUri,
            deviceId: deviceId,
          );
          await _persistSession(
            client,
            matrixUri,
            portalToken: effectivePortalToken,
            deviceId: deviceId,
            userId: session.userId,
            initialized: initialized,
            loginPortalToken: authPortalToken,
          );
        }
      } catch (e) {
        if (!_isUploadKeyFailure(e)) rethrow;
        final recovered = await _authenticateFreshDeviceAfterUploadKeyFailure(
          client,
          homeserver: matrixUri,
          loginPassword: authPortalToken,
          fallbackUserId: session.userId,
          initialized: initialized ?? true,
          logContext: 'portal restore',
        );
        session = recovered.session;
        matrixUri = recovered.homeserver;
        deviceId = recovered.deviceId;
        effectivePortalToken = session.accessToken.trim();
        initialized = _sessionInitialized(session);
      }
      await _loadChatClearState();
      _rememberSessionAgentRoomId(session, userId: client.userID);
      return AuthState(
        isLoggedIn: true,
        userId: client.userID ?? session.userId,
        homeserver: (client.homeserver ?? matrixUri).toString(),
        portalToken: effectivePortalToken,
        requiresInitialization: initialized == false,
      );
    } catch (e) {
      _lastPortalRestoreNonRetryableFailure =
          _isNonRetryablePortalAuthFailure(e);
      debugPrint('portal token restore failed: $e');
      return null;
    }
  }

  Future<void> _ensureCurrentSessionValid(
    Client client,
    Uri homeserver,
    String expectedUserId,
    String? portalToken,
    String deviceId,
  ) async {
    if (_sessionExpiredLocally) {
      throw StateError('登录态已失效，请重新登录');
    }
    try {
      final tokenOwner = await client.getTokenOwner();
      if (tokenOwner.userId == expectedUserId) return;
    } catch (e) {
      if (!_isTokenFailure(e)) rethrow;
      final refreshed = await _restorePortalSession(
        client,
        homeserver: homeserver.toString(),
        portalToken: portalToken,
      );
      if (refreshed != null && refreshed.userId == expectedUserId) {
        return;
      }
      if (_lastPortalRestoreNonRetryableFailure) {
        await _expireSessionDueInvalidToken(client);
        throw StateError('账号在其他设备登录，请重新登录');
      }
      throw StateError(
          'Matrix access token refresh unavailable; keeping session');
    }

    final cleanPortalToken = portalToken?.trim() ?? '';
    if (cleanPortalToken.isEmpty) {
      throw StateError('Matrix access token 已失效，请重新登录');
    }
    final loginPortalToken =
        (await _storage.read(key: lastLoginPortalTokenKey))?.trim();
    final authPortalToken = (loginPortalToken?.isNotEmpty ?? false)
        ? loginPortalToken!
        : cleanPortalToken;

    final session = await HttpAsClient.authenticatePortal(
      baseUri: HttpAsClient.defaultProductBaseUri(homeserver),
      portalToken: authPortalToken,
      deviceId: deviceId,
      httpClient: _rawHttpClient(client),
    );
    final effectivePortalToken = session.accessToken.trim();
    final refreshedDeviceId = await _resolveSessionDeviceId(
      httpClient: client.httpClient,
      homeserver: homeserver,
      accessToken: session.accessToken,
      sessionDeviceId: session.deviceId,
      storedDeviceId: deviceId,
    );
    if (_sessionExpiredLocally) {
      throw StateError('登录态已失效，请重新登录');
    }
    await _applyRefreshedSession(
      client,
      homeserver,
      session,
      portalToken: effectivePortalToken,
      deviceId: refreshedDeviceId,
      loginPortalToken: authPortalToken,
    );
  }

  http.Client _rawHttpClient(Client client) {
    final httpClient = client.httpClient;
    if (httpClient is MatrixTokenRefreshingHttpClient) {
      return httpClient.innerClient;
    }
    if (httpClient is TimeoutHttpClient &&
        httpClient.inner is MatrixTokenRefreshingHttpClient) {
      return (httpClient.inner as MatrixTokenRefreshingHttpClient).innerClient;
    }
    return httpClient;
  }

  Future<_ActivatedPortalSession> _authenticateFreshDeviceAfterUploadKeyFailure(
    Client client, {
    required Uri homeserver,
    required String loginPassword,
    required String? fallbackUserId,
    required bool initialized,
    required String logContext,
  }) async {
    debugPrint(
      'Matrix key upload failed after $logContext; retrying fresh auth',
    );
    final freshDeviceId = _createDeviceId();
    final session = await HttpAsClient.authenticatePortal(
      baseUri: HttpAsClient.defaultProductBaseUri(homeserver),
      portalToken: loginPassword,
      deviceId: freshDeviceId,
      httpClient: client.httpClient,
    );
    final matrixUri = _resolveClientHomeserver(homeserver, session.homeserver);
    final userId = session.userId.trim().isNotEmpty
        ? session.userId
        : fallbackUserId ?? client.userID ?? '';
    await _clearMatrixForCleanInit(client);
    await client.checkHomeserver(matrixUri);
    final checkedHomeserver = client.homeserver ?? matrixUri;
    final deviceId = await _resolveSessionDeviceId(
      httpClient: client.httpClient,
      homeserver: checkedHomeserver,
      accessToken: session.accessToken,
      sessionDeviceId: session.deviceId,
      storedDeviceId: freshDeviceId,
    );
    await _establishPrivacyBaselineBeforeInit(
      client,
      homeserver: checkedHomeserver,
      accessToken: session.accessToken,
      userId: userId,
      deviceId: deviceId,
    );
    await _initMatrixSessionWithKeyUploadRetry(
      client,
      accessToken: session.accessToken,
      userId: userId,
      homeserver: checkedHomeserver,
      deviceId: deviceId,
    );
    await _persistSession(
      client,
      checkedHomeserver,
      portalToken: session.accessToken,
      deviceId: deviceId,
      userId: userId,
      initialized: initialized,
      loginPortalToken: loginPassword,
    );
    return _ActivatedPortalSession(
      session: session,
      homeserver: checkedHomeserver,
      userId: userId,
      deviceId: deviceId,
    );
  }

  Future<void> _applyRefreshedSession(
    Client client,
    Uri currentHomeserver,
    AsPortalSession session, {
    required String portalToken,
    required String deviceId,
    String? loginPortalToken,
    bool? initialized,
  }) async {
    final matrixUri = _resolveClientHomeserver(
      currentHomeserver,
      session.homeserver,
    );
    final effectiveUserId = session.userId.trim().isNotEmpty
        ? session.userId
        : client.userID ?? await _storage.read(key: 'matrix_user_id') ?? '';
    final effectiveDeviceId = _preferredSessionDeviceId(session, deviceId);
    if (portalSessionNeedsCleanMatrixInit(
      currentAccessToken: client.accessToken,
      currentUserId: client.userID,
      currentDeviceId: client.deviceID,
      currentHomeserver: client.homeserver,
      nextAccessToken: session.accessToken,
      nextUserId: effectiveUserId,
      nextDeviceId: effectiveDeviceId,
      nextHomeserver: matrixUri,
    )) {
      await _clearMatrixForCleanInit(client);
      await _initMatrixSessionWithKeyUploadRetry(
        client,
        accessToken: session.accessToken,
        userId: effectiveUserId,
        homeserver: matrixUri,
        deviceId: effectiveDeviceId,
      );
    } else {
      client.homeserver = matrixUri;
      client.accessToken = session.accessToken;
      _lastAccessTokenAppliedAt = DateTime.now();
      await client.database?.updateClient(
        matrixUri.toString(),
        session.accessToken,
        null,
        null,
        effectiveUserId,
        effectiveDeviceId,
        client.deviceName ?? 'Direxio',
        client.prevBatch,
        client.encryption?.pickledOlmAccount,
      );
    }
    await _persistSession(
      client,
      matrixUri,
      portalToken: portalToken,
      deviceId: effectiveDeviceId,
      userId: effectiveUserId,
      initialized: initialized ?? _sessionInitialized(session),
      loginPortalToken: loginPortalToken,
    );
    _rememberSessionAgentRoomId(session, userId: effectiveUserId);
  }

  Future<String> _localMatrixDeviceId(Client client) async {
    final current = client.deviceID?.trim();
    if (current != null && current.isNotEmpty) return current;
    final stored = (await _storage.read(key: 'matrix_device_id'))?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return _createDeviceId();
  }

  Future<void> _initMatrixSessionWithKeyUploadRetry(
    Client client, {
    required String accessToken,
    required String userId,
    required Uri homeserver,
    required String deviceId,
  }) async {
    Future<void> init() {
      return client.init(
        newToken: accessToken,
        newUserID: userId,
        newHomeserver: homeserver,
        newDeviceID: deviceId,
        newDeviceName: 'Direxio',
        waitForFirstSync: false,
        waitUntilLoadCompletedLoaded: false,
      );
    }

    try {
      await init();
    } catch (error) {
      if (!_isUploadKeyFailure(error)) rethrow;
      debugPrint(
          'Matrix key upload failed during init; retrying clean session');
      await _clearMatrixForCleanInit(client);
      await init();
    }
  }

  Future<void> _clearMatrixForCleanInit(Client client) async {
    try {
      client.backgroundSync = false;
      await client.abortSync();
    } catch (e) {
      debugPrint('stop Matrix sync before clean init failed: $e');
    }
    try {
      await client.encryption?.olmManager.currentUpload?.cancel();
    } catch (e) {
      debugPrint('cancel Matrix key upload before clean init failed: $e');
    }
    await client.clear();
  }

  bool _isUploadKeyFailure(Object error) {
    return error.toString().contains('Upload key failed');
  }

  bool _isLoggedInAs(Client client, String userId) {
    return client.onLoginStateChanged.value == LoginState.loggedIn &&
        client.userID == userId;
  }

  bool _shouldResetUserScopedLocalStateForLogin(
    Client client,
    String nextUserId, {
    required String? storedUserId,
    required Uri nextHomeserver,
    required String? storedHomeserver,
  }) {
    final next = nextUserId.trim();
    if (next.isEmpty) return false;
    final current = client.userID?.trim() ?? '';
    if (current.isNotEmpty && current != next) return true;
    final stored = storedUserId?.trim() ?? '';
    if (stored.isNotEmpty && stored != next) return true;
    final nextHost = _normalizedAccountHost(nextHomeserver);
    final currentHost = client.homeserver == null
        ? ''
        : _normalizedAccountHost(client.homeserver!);
    if (currentHost.isNotEmpty && currentHost != nextHost) return true;
    final storedHost = _normalizedStoredAccountHost(storedHomeserver);
    if (storedHost.isNotEmpty && storedHost != nextHost) return true;
    return client.rooms.isNotEmpty && !_isLoggedInAs(client, next);
  }

  String _normalizedStoredAccountHost(String? homeserver) {
    final parsed = Uri.tryParse(homeserver?.trim() ?? '');
    if (parsed == null || parsed.host.isEmpty) return '';
    return _normalizedAccountHost(parsed);
  }

  String _normalizedAccountHost(Uri homeserver) {
    final scheme = homeserver.scheme.toLowerCase();
    final host = homeserver.host.toLowerCase();
    if (host.isEmpty) return '';
    final port = homeserver.hasPort ? ':${homeserver.port}' : '';
    return '$scheme://$host$port';
  }

  bool _isTokenFailure(Object error) {
    return error is MatrixException && error.errcode == 'M_UNKNOWN_TOKEN';
  }

  bool _isNonRetryablePortalAuthFailure(Object error) {
    if (error is! AsClientException) return false;
    final statusCode = error.statusCode;
    if (statusCode == null) return false;
    if (statusCode == 408 || statusCode == 429) return false;
    return statusCode >= 400 && statusCode < 500;
  }

  /// §3.1 / §7 步骤 3：调 owner.json，确认 Portal 在该域名部署。
  /// 404 → 抛 [PortalNotDeployedException]，让 UI 给出明确提示。
  Future<void> _assertPortalDeployed(String host) async {
    final client = ref.read(matrixClientProvider);
    final wk = WellKnownService(httpClient: client.httpClient);
    final result = await wk.discoverOwner(host);
    if (result.availability == PortalAvailability.notDeployed) {
      throw PortalNotDeployedException(host);
    }
    // unreachable 不阻断登录（可能只是 well-known 没配），交给后续 login 报错
  }

  Future<void> _establishPrivacyBaselineBeforeInit(
    Client client, {
    required Uri homeserver,
    required String accessToken,
    required String userId,
    required String deviceId,
  }) async {
    await MatrixPrivacySyncService(httpClient: client.httpClient)
        .establishAndSeed(
      homeserver: homeserver,
      accessToken: accessToken,
      userId: userId,
      deviceId: deviceId,
      deviceName: 'Direxio',
      seedStore: MatrixSdkSessionSeedStore(client),
    );
  }

  Uri _normalizeHomeserverUri(String input) {
    final trimmed = input.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) throw ArgumentError('Portal 地址不能为空');
    return Uri.parse(trimmed.startsWith('http') ? trimmed : 'https://$trimmed');
  }

  String _createDeviceId() {
    return 'PORTALIM${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _persistSession(
    Client client,
    Uri uri, {
    required String portalToken,
    required String deviceId,
    String? userId,
    bool? initialized,
    String? loginPortalToken,
  }) async {
    await _storage.write(
        key: AuthStateNotifier.accessTokenKey, value: portalToken);
    await _storage.write(key: 'matrix_homeserver', value: uri.toString());
    await _storage.write(key: 'matrix_user_id', value: userId ?? client.userID);
    await _storage.write(
      key: 'matrix_device_id',
      value: deviceId,
    );
    await _storage.write(key: lastLoginHomeserverKey, value: uri.toString());
    await _storage.write(
      key: lastLoginPortalTokenKey,
      value: loginPortalToken ?? portalToken,
    );
    if (initialized != null) {
      await _storage.write(
        key: initializedKey,
        value: initialized ? 'true' : 'false',
      );
    }
    if ((client.accessToken?.trim().isNotEmpty ?? false)) {
      final now = DateTime.now();
      _lastAccessTokenAppliedAt = now;
      await _storage.write(
        key: _accessTokenAppliedAtKey,
        value: now.millisecondsSinceEpoch.toString(),
      );
    }
  }

  Future<void> _clearUserScopedLocalState(
    Client client, {
    bool clearMatrix = true,
    bool clearCaches = true,
  }) async {
    if (clearMatrix) {
      await _clearMatrixForCleanInit(client);
    }
    if (!clearCaches) return;
    ref.read(asSyncCacheProvider.notifier).state = const AsSyncCacheState();
    await _deleteUserScopedSupportFiles();
    _scheduleUserScopedProviderInvalidation();
  }

  void _scheduleUserScopedProviderInvalidation() {
    unawaited(Future<void>(() {
      if (!_isMounted) return;
      try {
        ref.invalidate(localOutboxProvider);
        ref.invalidate(localOutboxStoreProvider);
        ref.invalidate(localMessageOrderProvider);
        ref.invalidate(localMessageOrderStoreProvider);
        ref.invalidate(mediaThumbnailCacheProvider);
        ref.invalidate(chatClearStateStoreProvider);
        ref.invalidate(friendRequestReadProvider);
        ref.invalidate(friendRequestReadStoreProvider);
        ref.invalidate(asCallSessionStoreProvider);
        ref.invalidate(channelPostStoreProvider);
        ref.invalidate(localCreatedChannelsProvider);
      } catch (e) {
        debugPrint('deferred user scoped provider invalidation failed: $e');
      }
    }));
  }

  Future<void> _deleteUserScopedSupportFiles() async {
    await _deleteSupportFiles(const [
      'direxio_p2p_bootstrap.json',
      'portal_im_as_bootstrap.json',
      'portal_im_recovered_unread.json',
      'portal_im_pending_media_uploads.json',
      'portal_im_local_message_order.json',
      'portal_im_call_sessions.json',
      'portal_im_friend_request_read.json',
      'portal_im_channel_posts.json',
      'portal_im_chat_clear_state.json',
      'conversation_summary.json',
      'current_user_profile.json',
    ]);
  }

  Future<void> _deleteSupportFiles(List<String> filenames) async {
    final Directory dir;
    try {
      dir = await getApplicationSupportDirectory();
    } catch (e) {
      debugPrint('clear user cache skipped: $e');
      return;
    }
    for (final filename in filenames) {
      final file = File('${dir.path}/$filename');
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('clear user cache failed for $filename: $e');
      }
    }
  }

  Future<void> clearChatHistory() async {
    final clearedBeforeTs = DateTime.now().toUtc().millisecondsSinceEpoch + 1;
    final store = await ref.read(chatClearStateStoreProvider.future);
    await store.writeClearedBeforeTs(clearedBeforeTs);
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.withAllChatsClearedBefore(clearedBeforeTs),
        );

    await _deleteSupportFiles(const [
      'portal_im_recovered_unread.json',
      'portal_im_pending_media_uploads.json',
      'portal_im_local_message_order.json',
    ]);

    final Directory dir;
    try {
      dir = await getApplicationSupportDirectory();
      final thumbnails = Directory('${dir.path}/portal_im_media_thumbnails');
      if (await thumbnails.exists()) {
        await thumbnails.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('clear media thumbnail cache failed: $e');
    }

    ref.invalidate(localOutboxProvider);
    ref.invalidate(localOutboxStoreProvider);
    ref.invalidate(localMessageOrderProvider);
    ref.invalidate(localMessageOrderStoreProvider);
    ref.invalidate(mediaThumbnailCacheProvider);
  }

  Future<void> clearRoomChatHistory(
    String roomId, {
    int? clearedBeforeTs,
  }) async {
    final trimmed = roomId.trim();
    if (trimmed.isEmpty) return;
    final clearBefore =
        clearedBeforeTs ?? DateTime.now().toUtc().millisecondsSinceEpoch + 1;
    final store = await ref.read(chatClearStateStoreProvider.future);
    await store.writeRoomClearedBeforeTs(trimmed, clearBefore);
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.withRoomClearedBefore(trimmed, clearBefore),
        );
  }

  Future<void> logout() async {
    final client = ref.read(matrixClientProvider);
    final lastHomeserver = await _storage.read(key: lastLoginHomeserverKey) ??
        await _storage.read(key: 'matrix_homeserver');
    try {
      await unregisterStoredAndroidFcmMatrixPusher(client);
    } catch (e) {
      debugPrint('Matrix pusher unregister during logout failed: $e');
    }
    await _logoutMatrixSessionPreservingStore(client);
    await _clearUserScopedLocalState(
      client,
      clearMatrix: false,
      clearCaches: false,
    );
    await _storage.deleteAll();
    if (lastHomeserver != null && lastHomeserver.trim().isNotEmpty) {
      await _storage.write(
        key: lastLoginHomeserverKey,
        value: lastHomeserver.trim(),
      );
    }
    state = const AsyncData(AuthState(isLoggedIn: false));
  }

  Future<void> _logoutMatrixSessionPreservingStore(Client client) async {
    final homeserver = client.homeserver;
    final accessToken = client.accessToken?.trim();
    try {
      client.backgroundSync = false;
      await client.abortSync();
    } catch (e) {
      debugPrint('stop Matrix sync during logout failed: $e');
    }
    if (homeserver == null || accessToken == null || accessToken.isEmpty) {
      return;
    }
    final uri = homeserver.resolveUri(
      Uri(path: '_matrix/client/v3/logout'),
    );
    try {
      final response = await _rawHttpClient(client).post(
        uri,
        headers: {'authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 &&
          response.statusCode != 401 &&
          response.statusCode != 403) {
        debugPrint(
          'matrix logout returned ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('matrix logout request failed: $e');
    }
  }

  Future<void> expireSessionDueInvalidToken() async {
    final client = ref.read(matrixClientProvider);
    if (await _preserveSessionForRetryAfterMatrixAuthFailure()) return;
    await _expireSessionDueInvalidToken(client);
  }

  Future<void> expireSessionDueInvalidTokenIfCurrent(String failedToken) async {
    final rejectedToken = failedToken.trim();
    final client = ref.read(matrixClientProvider);
    final currentToken = client.accessToken?.trim() ?? '';
    if (rejectedToken.isNotEmpty &&
        currentToken.isNotEmpty &&
        rejectedToken != currentToken) {
      debugPrint('stale Matrix access token rejected; keeping current session');
      return;
    }
    if (await _shouldIgnoreRecentMatrixAuthFailureForToken(
      rejectedToken: rejectedToken,
      currentToken: currentToken,
    )) {
      debugPrint(
        'recent Matrix token update rejected; keeping session for retry window',
      );
      return;
    }
    if (await _preserveSessionForRetryAfterMatrixAuthFailure()) return;
    await _expireSessionDueInvalidToken(client);
  }

  Future<bool> _preserveSessionForRetryAfterMatrixAuthFailure() async {
    if (_sessionExpiredLocally) return false;
    final refreshed = await _refreshMatrixAccessTokenForHttpRetry();
    if (refreshed != null && !_sessionExpiredLocally) {
      if (_isMounted) state = AsyncData(refreshed);
      return true;
    }
    if (_lastMatrixRefreshNonRetryableFailure ||
        _lastPortalRestoreNonRetryableFailure) {
      return false;
    }
    if (await _hasStoredSessionRestoreCredentials()) {
      debugPrint(
        'Matrix token rejected but restore credentials remain; keeping session for retry',
      );
      return true;
    }
    return false;
  }

  Future<bool> _hasStoredSessionRestoreCredentials() async {
    final values = await Future.wait<String?>([
      _storage.read(key: AuthStateNotifier.accessTokenKey),
      _storage.read(key: 'matrix_homeserver'),
      _storage.read(key: 'matrix_user_id'),
      _storage.read(key: lastLoginHomeserverKey),
      _storage.read(key: lastLoginPortalTokenKey),
    ]);
    final accessToken = values[0]?.trim() ?? '';
    final matrixHomeserver = values[1]?.trim() ?? '';
    final matrixUserId = values[2]?.trim() ?? '';
    final lastHomeserver = values[3]?.trim() ?? '';
    final lastPortalToken = values[4]?.trim() ?? '';
    return (accessToken.isNotEmpty &&
            matrixHomeserver.isNotEmpty &&
            matrixUserId.isNotEmpty) ||
        (lastHomeserver.isNotEmpty && lastPortalToken.isNotEmpty) ||
        (matrixHomeserver.isNotEmpty && accessToken.isNotEmpty);
  }

  Future<void> _expireSessionDueInvalidToken(
    Client client, {
    bool publishState = true,
  }) async {
    if (_sessionExpiredLocally && publishState) {
      state = const AsyncData(AuthState(isLoggedIn: false));
      return;
    }
    _sessionExpiredLocally = true;
    debugPrint('access token rejected; expiring local session');
    await _clearUserScopedLocalState(
      client,
      clearMatrix: false,
      clearCaches: false,
    );
    await _storage.delete(key: AuthStateNotifier.accessTokenKey);
    await _storage.delete(key: initializedKey);
    await _storage.delete(key: 'matrix_homeserver');
    await _storage.delete(key: 'matrix_user_id');
    await _storage.delete(key: 'matrix_device_id');
    await _storage.delete(key: lastLoginPortalTokenKey);
    await _storage.delete(key: _accessTokenAppliedAtKey);
    await _storage.delete(key: _legacyMatrixTokenKey);
    await _storage.delete(key: _legacyInitializedKey);
    await _storage.delete(key: _legacyMatrixTokenAppliedAtKey);
    ref.read(sessionExpiredNoticeProvider.notifier).state++;
    if (publishState) {
      state = const AsyncData(AuthState(isLoggedIn: false));
    }
  }

  void _configureMatrixTokenFailureHandler(Client client) {
    final httpClient = _matrixTokenRefreshingHttpClient(client);
    if (httpClient == null) return;
    httpClient.refreshAccessToken = () async {
      final restored = await _refreshMatrixAccessTokenForHttpRetry();
      if (restored == null || _sessionExpiredLocally) return null;
      unawaited(Future<void>.delayed(Duration.zero, () {
        if (_isMounted && !_sessionExpiredLocally && state.hasValue) {
          state = AsyncData(restored);
        }
      }));
      return restored.portalToken;
    };
    httpClient.onAuthenticationFailed = () async {
      if (await _shouldIgnoreRecentAnonymousMatrixAuthFailure(client)) {
        debugPrint(
          'recent Matrix token update saw an auth failure without token; waiting for current token retry',
        );
        return;
      }
      await expireSessionDueInvalidToken();
    };
    httpClient.onAuthenticationFailedForToken = (failedToken) async {
      await expireSessionDueInvalidTokenIfCurrent(failedToken);
    };
  }

  MatrixTokenRefreshingHttpClient? _matrixTokenRefreshingHttpClient(
    Client client,
  ) {
    final httpClient = client.httpClient;
    if (httpClient is MatrixTokenRefreshingHttpClient) return httpClient;
    if (httpClient is TimeoutHttpClient &&
        httpClient.inner is MatrixTokenRefreshingHttpClient) {
      return httpClient.inner as MatrixTokenRefreshingHttpClient;
    }
    return null;
  }

  Future<bool> _shouldIgnoreRecentAnonymousMatrixAuthFailure(
    Client client,
  ) async {
    if (_sessionExpiredLocally) return false;
    final appliedAt = await _recentAccessTokenAppliedAt();
    if (appliedAt == null) return false;
    if (DateTime.now().difference(appliedAt) > const Duration(seconds: 15)) {
      return false;
    }
    return client.accessToken?.trim().isNotEmpty ?? false;
  }

  Future<bool> _shouldIgnoreRecentMatrixAuthFailureForToken({
    required String rejectedToken,
    required String currentToken,
  }) async {
    if (_sessionExpiredLocally || currentToken.isEmpty) return false;
    final appliedAt = await _recentAccessTokenAppliedAt();
    if (appliedAt == null) return false;
    if (DateTime.now().difference(appliedAt) > const Duration(seconds: 15)) {
      return false;
    }
    return rejectedToken.isEmpty || rejectedToken == currentToken;
  }

  Future<DateTime?> _recentAccessTokenAppliedAt() async {
    final appliedAt = _lastAccessTokenAppliedAt;
    if (appliedAt != null) return appliedAt;
    final stored = await _storage.read(key: _accessTokenAppliedAtKey);
    final millis = int.tryParse(stored?.trim() ?? '');
    if (millis == null || millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}

String _validatePortalLoginToken(String token) {
  final cleanToken = token.trim();
  if (cleanToken.length < 8) {
    throw ArgumentError('新登录口令至少 8 位');
  }
  if (cleanToken.contains(RegExp(r'\s'))) {
    throw ArgumentError('新登录口令不能包含空格');
  }
  return cleanToken;
}

bool? _parseStoredBool(String? value) {
  final clean = value?.trim().toLowerCase();
  if (clean == 'true') return true;
  if (clean == 'false') return false;
  return null;
}

@visibleForTesting
bool shouldClearStaleIosKeychainAfterFreshInstall({
  required bool isIos,
  required bool markerExists,
  required bool hasExistingLocalState,
  required bool hasSecureSessionState,
}) {
  return isIos &&
      !markerExists &&
      !hasExistingLocalState &&
      hasSecureSessionState;
}

class _PortalLoginResult {
  const _PortalLoginResult({
    required this.userId,
    required this.homeserver,
    required this.portalToken,
    required this.deviceId,
  });

  final String? userId;
  final Uri homeserver;
  final String portalToken;
  final String deviceId;

  AuthState toAuthState({String ownerDisplayName = ''}) => AuthState(
        isLoggedIn: true,
        userId: userId,
        homeserver: homeserver.toString(),
        portalToken: portalToken,
        ownerDisplayName: ownerDisplayName,
      );
}

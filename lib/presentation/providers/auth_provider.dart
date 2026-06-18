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
import '../../data/matrix_privacy_sync.dart';
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
import 'recovered_unread_store_provider.dart';

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
    'PortalIM',
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
    this.requiresProfileSetup = false,
  });

  final bool isLoggedIn;
  final String? userId;
  final String? homeserver;
  final String? portalToken;
  final String? ownerDisplayName;
  final bool requiresProfileSetup;
}

Uri _resolveClientHomeserver(Uri inputUri, String asHomeserver) {
  final parsed = Uri.tryParse(asHomeserver);
  if (parsed == null || parsed.host.isEmpty) return inputUri;
  if (_isLocalHost(inputUri.host)) {
    return inputUri;
  }
  if (_isLocalHost(parsed.host) && !_isLocalHost(inputUri.host)) {
    return inputUri;
  }
  return parsed;
}

@visibleForTesting
Uri resolveClientHomeserverForSession(Uri inputUri, String asHomeserver) =>
    _resolveClientHomeserver(inputUri, asHomeserver);

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
  static const adminAccessTokenKey = 'admin_access_token';
  static const lastLoginHomeserverKey = 'last_login_homeserver';
  static const lastLoginPortalTokenKey = 'last_login_portal_token';
  static const profileInitializedKey = 'profile_initialized';
  bool _sessionExpiredLocally = false;
  bool _isMounted = false;

  @override
  Future<AuthState> build() async {
    _isMounted = true;
    ref.onDispose(() => _isMounted = false);
    try {
      return await _buildRestoredAuthState().timeout(_startupRestoreTimeout);
    } catch (e) {
      debugPrint('startup auth restore failed, returning to login: $e');
      unawaited(
        _clearAutoRestoreCredentials()
            .timeout(const Duration(seconds: 2))
            .catchError((Object clearError) {
          debugPrint('startup auth credential cleanup skipped: $clearError');
        }),
      );
      return const AuthState(isLoggedIn: false);
    }
  }

  Future<AuthState> _buildRestoredAuthState() async {
    final client = ref.watch(matrixClientProvider);
    final storedValues = await Future.wait<String?>([
      _storage.read(key: 'matrix_token'),
      _storage.read(key: 'matrix_homeserver'),
      _storage.read(key: 'matrix_user_id'),
      _storage.read(key: AuthStateNotifier.adminAccessTokenKey),
      _storage.read(key: lastLoginHomeserverKey),
      _storage.read(key: lastLoginPortalTokenKey),
      _storage.read(key: profileInitializedKey),
    ]);
    final token = storedValues[0];
    final homeserver = storedValues[1];
    final userId = storedValues[2];
    final portalToken = storedValues[3];
    final lastLoginHomeserver = storedValues[4];
    final lastLoginPortalToken = storedValues[5];
    final storedProfileInitialized = _parseStoredBool(storedValues[6]);
    final storedPortalToken = (portalToken?.trim().isNotEmpty ?? false)
        ? portalToken
        : lastLoginPortalToken;
    final storedHomeserver = homeserver ?? lastLoginHomeserver;
    if (_sessionExpiredLocally) {
      return const AuthState(isLoggedIn: false);
    }

    if (token != null && homeserver != null && userId != null) {
      try {
        final homeserverUri = Uri.parse(homeserver);
        final deviceId =
            await _storage.read(key: 'matrix_device_id') ?? _createDeviceId();

        await client.init(
          newToken: token,
          newUserID: userId,
          newHomeserver: homeserverUri,
          newDeviceID: deviceId,
          newDeviceName: 'PortalIM',
          waitForFirstSync: false,
          waitUntilLoadCompletedLoaded: false,
        );
        _refreshStoredMatrixSessionInBackground(
          client,
          homeserverUri,
          userId,
          storedPortalToken,
          deviceId,
        );
        await _loadChatClearState();
        if (_sessionExpiredLocally) {
          return const AuthState(isLoggedIn: false);
        }
        return AuthState(
          isLoggedIn: true,
          userId: client.userID ?? userId,
          homeserver: (client.homeserver ?? homeserverUri).toString(),
          portalToken: storedPortalToken,
          requiresProfileSetup: storedProfileInitialized == false,
        );
      } catch (_) {
        await _storage.delete(key: 'matrix_token');
      }
    }
    final restored = await _restoreMatrixSdkSession(client, storedPortalToken);
    if (_sessionExpiredLocally) return const AuthState(isLoggedIn: false);
    if (restored != null) return restored;
    if ((storedPortalToken?.trim().isNotEmpty ?? false) &&
        (storedHomeserver?.trim().isNotEmpty ?? false)) {
      final portalRestored = await _restorePortalSession(
        client,
        homeserver: storedHomeserver,
        portalToken: storedPortalToken,
      );
      if (_sessionExpiredLocally) return const AuthState(isLoggedIn: false);
      if (portalRestored != null) return portalRestored;
    }
    return const AuthState(isLoggedIn: false);
  }

  Future<void> _clearAutoRestoreCredentials() async {
    await Future.wait<void>([
      _storage.delete(key: 'matrix_token'),
      _storage.delete(key: 'matrix_homeserver'),
      _storage.delete(key: 'matrix_user_id'),
      _storage.delete(key: 'matrix_device_id'),
      _storage.delete(key: adminAccessTokenKey),
      _storage.delete(key: profileInitializedKey),
    ]);
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

    final baseUri = HttpAsClient.defaultAdminBaseUri(inputUri);
    final session = useBootstrap
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
    final effectivePortalToken = session.adminAccessToken.trim();
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
    final checkedHomeserver = client.homeserver ?? matrixUri;
    final storedDeviceId = await _storage.read(key: 'matrix_device_id');
    final deviceId = await _resolveSessionDeviceId(
      httpClient: client.httpClient,
      homeserver: checkedHomeserver,
      accessToken: session.matrixAccessToken,
      sessionDeviceId: session.deviceId,
      storedDeviceId: storedDeviceId,
    );
    final hasStaleSameUserDevice = _hasStaleSameUserDevice(
      client,
      session.userId,
      deviceId,
    );
    if (hasStaleSameUserDevice) {
      await client.clear();
    }
    await _establishPrivacyBaselineBeforeInit(
      client,
      homeserver: checkedHomeserver,
      accessToken: session.matrixAccessToken,
      userId: session.userId,
      deviceId: deviceId,
    );

    if (_isLoggedInAs(client, session.userId)) {
      await _applyRefreshedSession(
        client,
        checkedHomeserver,
        session,
        portalToken: effectivePortalToken,
        deviceId: deviceId,
      );
    } else {
      await client.init(
        newToken: session.matrixAccessToken,
        newUserID: session.userId,
        newHomeserver: checkedHomeserver,
        newDeviceID: deviceId,
        newDeviceName: 'PortalIM',
        waitForFirstSync: false,
        waitUntilLoadCompletedLoaded: false,
      );
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      await client.setDisplayName(session.userId, displayName.trim());
    }
    final profileInitialized = _sessionProfileInitialized(session);
    await _persistSession(
      client,
      checkedHomeserver,
      portalToken: effectivePortalToken,
      deviceId: deviceId,
      profileInitialized: profileInitialized,
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
      final requiresProfileSetup = profileInitialized == false;
      state = AsyncData(
        AuthState(
          isLoggedIn: true,
          userId: result.userId,
          homeserver: result.homeserver.toString(),
          portalToken: result.portalToken,
          ownerDisplayName: ownerDisplayName,
          requiresProfileSetup: requiresProfileSetup,
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

  bool? _sessionProfileInitialized(AsPortalSession session) {
    if (session.profileInitialized != null) return session.profileInitialized;
    if (session.initialized == true && session.passwordInitialized == true) {
      return true;
    }
    if (session.initialized == true && session.passwordInitialized == false) {
      return false;
    }
    return null;
  }

  Future<String?> _loadOwnerDisplayNameForLogin(
    Client client, {
    required Uri homeserver,
    required String portalToken,
  }) async {
    try {
      final ownerProfile = await HttpAsClient.fromPortalSession(
        client,
        portalToken: portalToken,
        baseUri: HttpAsClient.defaultAdminBaseUri(homeserver),
      ).getOwnerProfile().timeout(const Duration(seconds: 2));
      return ownerProfile.displayName;
    } on TimeoutException {
      debugPrint('AS owner profile timed out during login');
      return null;
    } catch (e) {
      debugPrint('AS owner profile failed during login: $e');
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
      await client.oneShotSync().timeout(const Duration(seconds: 12));
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
        baseUri: HttpAsClient.defaultAdminBaseUri(homeserver),
      ).syncBootstrap().timeout(const Duration(seconds: 10));
      if (!asBootstrapBelongsToUser(bootstrap, client.userID)) {
        debugPrint(
          'post-login ignored AS bootstrap for ${bootstrap.user.userId}; '
          'current user is ${client.userID}',
        );
        return;
      }
      if (!_isMounted) return;
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
    } catch (e) {
      debugPrint('post-login AS bootstrap sync failed: $e');
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

  Future<void> completeOwnerProfileSetup({
    required String displayName,
    required String newPortalToken,
  }) async {
    final cleanDisplayName = displayName.trim();
    if (cleanDisplayName.isEmpty) {
      throw ArgumentError('用户昵称不能为空');
    }
    final cleanToken = _validatePortalLoginToken(newPortalToken);
    final client = ref.read(matrixClientProvider);
    final auth = state.valueOrNull;
    final currentPortalToken = auth?.portalToken ??
        await _storage.read(key: AuthStateNotifier.adminAccessTokenKey);
    if (currentPortalToken == null || currentPortalToken.trim().isEmpty) {
      throw StateError('当前 AS 登录态缺失，请重新登录');
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
      baseUri: HttpAsClient.defaultAdminBaseUri(homeserver),
    );
    final profile =
        await asClient.updateOwnerProfile(displayName: cleanDisplayName);
    final session = await asClient.changePortalPassword(
      oldPassword: currentLoginPassword,
      newPassword: cleanToken,
      deviceId: await _localMatrixDeviceId(client),
    );
    final matrixUri = _resolveClientHomeserver(homeserver, session.homeserver);
    final deviceId = await _resolveSessionDeviceId(
      httpClient: client.httpClient,
      homeserver: matrixUri,
      accessToken: session.matrixAccessToken,
      sessionDeviceId: session.deviceId,
      storedDeviceId: await _storage.read(key: 'matrix_device_id'),
    );
    await _applyRefreshedSession(
      client,
      matrixUri,
      session,
      portalToken: session.adminAccessToken,
      deviceId: deviceId,
      loginPortalToken: cleanToken,
      profileInitialized: _sessionProfileInitialized(session) ?? true,
    );
    final userId = session.userId.trim().isNotEmpty
        ? session.userId
        : auth?.userId ?? client.userID ?? '';
    if (userId.isNotEmpty) {
      await client.setDisplayName(userId, cleanDisplayName);
    }
    final savedDisplayName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : cleanDisplayName;
    state = AsyncData(
      AuthState(
        isLoggedIn: true,
        userId: userId,
        homeserver: matrixUri.toString(),
        portalToken: session.adminAccessToken,
        ownerDisplayName: savedDisplayName,
        requiresProfileSetup: false,
      ),
    );
    _startPostLoginConversationSync(
      client,
      homeserver: matrixUri,
      portalToken: session.adminAccessToken,
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
        await _storage.read(key: AuthStateNotifier.adminAccessTokenKey);
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
    final currentPortalToken = auth?.portalToken ??
        await _storage.read(key: AuthStateNotifier.adminAccessTokenKey);
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
      baseUri: HttpAsClient.defaultAdminBaseUri(homeserver),
    );
    final session = await asClient.changePortalPassword(
      oldPassword: cleanOldPassword,
      newPassword: cleanNewPassword,
      deviceId: await _localMatrixDeviceId(client),
    );
    final matrixUri = _resolveClientHomeserver(homeserver, session.homeserver);
    final userId = session.userId.trim().isNotEmpty
        ? session.userId
        : auth?.userId ?? client.userID ?? '';
    final deviceId = await _resolveSessionDeviceId(
      httpClient: client.httpClient,
      homeserver: matrixUri,
      accessToken: session.matrixAccessToken,
      sessionDeviceId: session.deviceId,
      storedDeviceId: await _storage.read(key: 'matrix_device_id'),
    );
    await _applyRefreshedSession(
      client,
      matrixUri,
      session,
      portalToken: session.adminAccessToken,
      deviceId: deviceId,
      loginPortalToken: cleanNewPassword,
      profileInitialized: _sessionProfileInitialized(session) ??
          _parseStoredBool(await _storage.read(key: profileInitializedKey)) ??
          !(auth?.requiresProfileSetup ?? false),
    );
    final profileInitialized = _sessionProfileInitialized(session) ??
        _parseStoredBool(await _storage.read(key: profileInitializedKey));
    state = AsyncData(
      AuthState(
        isLoggedIn: true,
        userId: userId,
        homeserver: matrixUri.toString(),
        portalToken: session.adminAccessToken,
        ownerDisplayName: auth?.ownerDisplayName,
        requiresProfileSetup: profileInitialized == false,
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
      baseUri: HttpAsClient.defaultAdminBaseUri(result.homeserver),
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
      accessToken: session.matrixAccessToken,
      sessionDeviceId: session.deviceId,
      storedDeviceId: result.deviceId,
    );
    await _applyRefreshedSession(
      client,
      matrixUri,
      session,
      portalToken: session.adminAccessToken,
      deviceId: deviceId,
      loginPortalToken: cleanNewToken,
      profileInitialized: _sessionProfileInitialized(session) ?? false,
    );
    state = AsyncData(
      AuthState(
        isLoggedIn: true,
        userId: userId,
        homeserver: matrixUri.toString(),
        portalToken: session.adminAccessToken,
        requiresProfileSetup: true,
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
          await _expireSessionDueInvalidToken(client, publishState: false);
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

      await _storage.write(key: 'matrix_token', value: accessToken);
      await _storage.write(
          key: 'matrix_homeserver', value: homeserver.toString());
      await _storage.write(key: 'matrix_user_id', value: userId);
      await _storage.write(
        key: 'matrix_device_id',
        value: client.deviceID ?? _createDeviceId(),
      );
      if (portalToken != null && portalToken.isNotEmpty) {
        await _storage.write(
            key: AuthStateNotifier.adminAccessTokenKey, value: portalToken);
      }

      await _loadChatClearState();
      return AuthState(
        isLoggedIn: true,
        userId: userId,
        homeserver: homeserver.toString(),
        portalToken: portalToken,
        requiresProfileSetup:
            _parseStoredBool(await _storage.read(key: profileInitializedKey)) ==
                false,
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
      final session = await HttpAsClient.authenticatePortal(
        baseUri: HttpAsClient.defaultAdminBaseUri(homeserverUri),
        portalToken: authPortalToken,
        deviceId: requestedDeviceId,
        httpClient: client.httpClient,
      );
      final effectivePortalToken = session.adminAccessToken.trim();
      final matrixUri = _resolveClientHomeserver(
        homeserverUri,
        session.homeserver,
      );
      final deviceId = await _resolveSessionDeviceId(
        httpClient: client.httpClient,
        homeserver: matrixUri,
        accessToken: session.matrixAccessToken,
        sessionDeviceId: session.deviceId,
        storedDeviceId: await _storage.read(key: 'matrix_device_id'),
      );
      if (client.onLoginStateChanged.value == LoginState.loggedIn) {
        await _applyRefreshedSession(
          client,
          matrixUri,
          session,
          portalToken: effectivePortalToken,
          deviceId: deviceId,
          loginPortalToken: authPortalToken,
        );
      } else {
        final profileInitialized = _sessionProfileInitialized(session);
        await client.init(
          newToken: session.matrixAccessToken,
          newUserID: session.userId,
          newHomeserver: matrixUri,
          newDeviceID: deviceId,
          newDeviceName: 'PortalIM',
          waitForFirstSync: false,
          waitUntilLoadCompletedLoaded: false,
        );
        await _persistSession(
          client,
          matrixUri,
          portalToken: effectivePortalToken,
          deviceId: deviceId,
          userId: session.userId,
          profileInitialized: profileInitialized,
          loginPortalToken: authPortalToken,
        );
      }
      final profileInitialized = _sessionProfileInitialized(session);
      await _loadChatClearState();
      return AuthState(
        isLoggedIn: true,
        userId: client.userID ?? session.userId,
        homeserver: (client.homeserver ?? matrixUri).toString(),
        portalToken: effectivePortalToken,
        requiresProfileSetup: profileInitialized == false,
      );
    } catch (e) {
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
      await _expireSessionDueInvalidToken(client);
      throw StateError('账号在其他设备登录，请重新登录');
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
      baseUri: HttpAsClient.defaultAdminBaseUri(homeserver),
      portalToken: authPortalToken,
      deviceId: deviceId,
      httpClient: _rawHttpClient(client),
    );
    final effectivePortalToken = session.adminAccessToken.trim();
    final refreshedDeviceId = await _resolveSessionDeviceId(
      httpClient: client.httpClient,
      homeserver: homeserver,
      accessToken: session.matrixAccessToken,
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
    return httpClient;
  }

  Future<void> _applyRefreshedSession(
    Client client,
    Uri currentHomeserver,
    AsPortalSession session, {
    required String portalToken,
    required String deviceId,
    String? loginPortalToken,
    bool? profileInitialized,
  }) async {
    final matrixUri = _resolveClientHomeserver(
      currentHomeserver,
      session.homeserver,
    );
    final effectiveUserId = session.userId.trim().isNotEmpty
        ? session.userId
        : client.userID ?? await _storage.read(key: 'matrix_user_id') ?? '';
    final effectiveDeviceId = _preferredSessionDeviceId(session, deviceId);
    if (_hasStaleSameUserDevice(client, effectiveUserId, effectiveDeviceId)) {
      await client.clear();
      await client.init(
        newToken: session.matrixAccessToken,
        newUserID: effectiveUserId,
        newHomeserver: matrixUri,
        newDeviceID: effectiveDeviceId,
        newDeviceName: 'PortalIM',
        waitForFirstSync: false,
        waitUntilLoadCompletedLoaded: false,
      );
    } else {
      client.homeserver = matrixUri;
      client.accessToken = session.matrixAccessToken;
      await client.database?.updateClient(
        matrixUri.toString(),
        session.matrixAccessToken,
        null,
        null,
        effectiveUserId,
        effectiveDeviceId,
        client.deviceName ?? 'PortalIM',
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
      profileInitialized:
          profileInitialized ?? _sessionProfileInitialized(session),
      loginPortalToken: loginPortalToken,
    );
  }

  Future<String> _localMatrixDeviceId(Client client) async {
    final current = client.deviceID?.trim();
    if (current != null && current.isNotEmpty) return current;
    final stored = (await _storage.read(key: 'matrix_device_id'))?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return _createDeviceId();
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
      deviceName: 'PortalIM',
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
    bool? profileInitialized,
    String? loginPortalToken,
  }) async {
    await _storage.write(key: 'matrix_token', value: client.accessToken);
    await _storage.write(key: 'matrix_homeserver', value: uri.toString());
    await _storage.write(key: 'matrix_user_id', value: userId ?? client.userID);
    await _storage.write(
      key: 'matrix_device_id',
      value: deviceId,
    );
    await _storage.write(
        key: AuthStateNotifier.adminAccessTokenKey, value: portalToken);
    await _storage.write(key: lastLoginHomeserverKey, value: uri.toString());
    await _storage.write(
      key: lastLoginPortalTokenKey,
      value: loginPortalToken ?? portalToken,
    );
    if (profileInitialized != null) {
      await _storage.write(
        key: profileInitializedKey,
        value: profileInitialized ? 'true' : 'false',
      );
    }
  }

  Future<void> _clearUserScopedLocalState(
    Client client, {
    bool clearMatrix = true,
    bool clearCaches = true,
  }) async {
    if (clearMatrix) {
      await client.clear();
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
        ref.invalidate(recoveredUnreadStoreProvider);
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
      'portal_im_as_bootstrap.json',
      'portal_im_recovered_unread.json',
      'portal_im_pending_media_uploads.json',
      'portal_im_local_message_order.json',
      'portal_im_call_sessions.json',
      'portal_im_friend_request_read.json',
      'portal_im_channel_posts.json',
      'portal_im_chat_clear_state.json',
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

    try {
      final unreadStore = await ref.read(recoveredUnreadStoreProvider.future);
      final unread = await unreadStore.read();
      for (final room in unread?.rooms ?? const <AsUnreadRoom>[]) {
        await unreadStore.removeRoom(room.roomId);
      }
    } catch (e) {
      debugPrint('clear recovered unread cache failed: $e');
    }

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
    ref.invalidate(recoveredUnreadStoreProvider);
  }

  Future<void> clearRoomChatHistory(String roomId) async {
    final trimmed = roomId.trim();
    if (trimmed.isEmpty) return;
    final clearedBeforeTs = DateTime.now().toUtc().millisecondsSinceEpoch + 1;
    final store = await ref.read(chatClearStateStoreProvider.future);
    await store.writeRoomClearedBeforeTs(trimmed, clearedBeforeTs);
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.withRoomClearedBefore(trimmed, clearedBeforeTs),
        );
    try {
      final unreadStore = await ref.read(recoveredUnreadStoreProvider.future);
      await unreadStore.removeRoom(trimmed);
    } catch (e) {
      debugPrint('clear room recovered unread cache failed: $e');
    }
  }

  Future<void> logout() async {
    final client = ref.read(matrixClientProvider);
    final lastHomeserver = await _storage.read(key: lastLoginHomeserverKey) ??
        await _storage.read(key: 'matrix_homeserver');
    final lastPortalToken = await _storage.read(key: lastLoginPortalTokenKey) ??
        await _storage.read(key: AuthStateNotifier.adminAccessTokenKey);
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
    if (lastPortalToken != null && lastPortalToken.trim().isNotEmpty) {
      await _storage.write(
        key: lastLoginPortalTokenKey,
        value: lastPortalToken.trim(),
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
    await _expireSessionDueInvalidToken(client);
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
    await _storage.delete(key: 'matrix_token');
    await _storage.delete(key: 'matrix_homeserver');
    await _storage.delete(key: 'matrix_user_id');
    await _storage.delete(key: 'matrix_device_id');
    await _storage.delete(key: AuthStateNotifier.adminAccessTokenKey);
    await _storage.delete(key: lastLoginPortalTokenKey);
    await _storage.delete(key: profileInitializedKey);
    ref.read(sessionExpiredNoticeProvider.notifier).state++;
    if (publishState) {
      state = const AsyncData(AuthState(isLoggedIn: false));
    }
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

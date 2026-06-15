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
import '../../data/http_as_client.dart';
import '../../data/matrix_privacy_sync.dart';
import '../../data/matrix_token_refreshing_http_client.dart';
import '../../data/well_known_service.dart';
import '../../data/bi_analytics_service.dart';
import 'as_sync_cache_provider.dart';
import 'as_call_session_store_provider.dart';
import 'friend_request_read_provider.dart';
import 'local_message_order_provider.dart';
import 'local_outbox_provider.dart';
import 'p2p_api_provider.dart';
import 'recovered_unread_store_provider.dart';

part 'auth_provider.g.dart';

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
      final dir = await getApplicationSupportDirectory();
      final db = MatrixSdkDatabase(
        'portal_im_db',
        database: await sqlite.openDatabase(
          '${dir.path}/portal_im_matrix.sqlite',
          singleInstance: false,
        ),
      );
      await db.open();
      return db;
    },
  );
  refreshingHttpClient.refreshAccessToken =
      () => _refreshMatrixAccessTokenFromPortal(client, rawHttpClient);
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

Future<String?> _refreshMatrixAccessTokenFromPortal(
  Client client,
  http.Client httpClient,
) async {
  final portalToken =
      await AuthStateNotifier._storage.read(key: 'portal_token');
  final cleanPortalToken = portalToken?.trim() ?? '';
  if (cleanPortalToken.isEmpty) return null;

  final storedHomeserver =
      await AuthStateNotifier._storage.read(key: 'matrix_homeserver');
  final homeserver = client.homeserver ?? Uri.tryParse(storedHomeserver ?? '');
  if (homeserver == null) return null;

  final storedDeviceId =
      await AuthStateNotifier._storage.read(key: 'matrix_device_id');
  final session = await HttpAsClient.authenticatePortal(
    baseUri: HttpAsClient.defaultAdminBaseUri(homeserver),
    portalToken: cleanPortalToken,
    httpClient: httpClient,
  );
  final matrixUri = _resolveClientHomeserver(homeserver, session.homeserver);
  final deviceId = await _resolveSessionDeviceId(
    httpClient: httpClient,
    homeserver: matrixUri,
    accessToken: session.accessToken,
    sessionDeviceId: session.deviceId,
    storedDeviceId: client.deviceID ?? storedDeviceId,
  );

  client.homeserver = matrixUri;
  client.accessToken = session.accessToken;
  await client.database?.updateClient(
    matrixUri.toString(),
    session.accessToken,
    null,
    null,
    session.userId,
    deviceId,
    client.deviceName ?? 'PortalIM',
    client.prevBatch,
    client.encryption?.pickledOlmAccount,
  );
  await _persistMatrixSession(
    client,
    matrixUri,
    userId: session.userId,
    portalToken: cleanPortalToken,
    deviceId: deviceId,
  );

  return session.accessToken;
}

Future<void> _persistMatrixSession(
  Client client,
  Uri uri, {
  required String? userId,
  required String portalToken,
  required String deviceId,
}) async {
  await AuthStateNotifier._storage.write(
    key: 'matrix_token',
    value: client.accessToken,
  );
  await AuthStateNotifier._storage.write(
    key: 'matrix_homeserver',
    value: uri.toString(),
  );
  await AuthStateNotifier._storage.write(
    key: 'matrix_user_id',
    value: userId ?? client.userID,
  );
  await AuthStateNotifier._storage.write(
    key: 'matrix_device_id',
    value: client.deviceID ?? deviceId,
  );
  await AuthStateNotifier._storage.write(
    key: 'portal_token',
    value: portalToken,
  );
}

Uri _resolveClientHomeserver(Uri inputUri, String asHomeserver) {
  final parsed = Uri.tryParse(asHomeserver);
  if (parsed == null || parsed.host.isEmpty) return inputUri;
  if (_isLocalHost(parsed.host) && !_isLocalHost(inputUri.host)) {
    return inputUri;
  }
  return parsed;
}

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
  final cleanSessionDeviceId = sessionDeviceId?.trim();
  if (cleanSessionDeviceId != null && cleanSessionDeviceId.isNotEmpty) {
    return cleanSessionDeviceId;
  }

  final tokenDeviceId = await _fetchTokenDeviceId(
    httpClient: httpClient,
    homeserver: homeserver,
    accessToken: accessToken,
  );
  if (tokenDeviceId != null && tokenDeviceId.isNotEmpty) {
    return tokenDeviceId;
  }

  final cleanStoredDeviceId = storedDeviceId?.trim();
  if (cleanStoredDeviceId != null && cleanStoredDeviceId.isNotEmpty) {
    return cleanStoredDeviceId;
  }
  return _createDeviceId();
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
  static const lastLoginHomeserverKey = 'last_login_homeserver';
  static const lastLoginPortalTokenKey = 'last_login_portal_token';

  @override
  Future<AuthState> build() async {
    final client = ref.watch(matrixClientProvider);
    final token = await _storage.read(key: 'matrix_token');
    final homeserver = await _storage.read(key: 'matrix_homeserver');
    final userId = await _storage.read(key: 'matrix_user_id');
    final portalToken = await _storage.read(key: 'portal_token');
    final lastLoginHomeserver =
        await _storage.read(key: lastLoginHomeserverKey);
    final lastLoginPortalToken =
        await _storage.read(key: lastLoginPortalTokenKey);
    final storedPortalToken = (portalToken?.trim().isNotEmpty ?? false)
        ? portalToken
        : lastLoginPortalToken;

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
          waitUntilLoadCompletedLoaded: true,
        );
        return AuthState(
          isLoggedIn: true,
          userId: client.userID ?? userId,
          homeserver: (client.homeserver ?? homeserverUri).toString(),
          portalToken: portalToken,
        );
      } catch (_) {
        await _storage.delete(key: 'matrix_token');
      }
    }
    final restored = await _restoreMatrixSdkSession(client, storedPortalToken);
    if (restored != null) return restored;
    final portalRestored = await _restorePortalSession(
      client,
      homeserver: homeserver ?? lastLoginHomeserver,
      portalToken: storedPortalToken,
    );
    if (portalRestored != null) return portalRestored;
    return const AuthState(isLoggedIn: false);
  }

  Future<void> login(String homeserverUrl, String portalToken) async {
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

    final baseUri = HttpAsClient.defaultAdminBaseUri(inputUri);
    final session = useBootstrap
        ? await HttpAsClient.bootstrapPortal(
            baseUri: baseUri,
            setupCode: cleanPortalToken,
            httpClient: client.httpClient,
          )
        : await HttpAsClient.authenticatePortal(
            baseUri: baseUri,
            portalToken: cleanPortalToken,
            httpClient: client.httpClient,
          );
    final storedUserId = await _storage.read(key: 'matrix_user_id');
    // 认证成功后再读取 owner.json，用于确认 Portal owner 信息。
    await _assertPortalDeployed(inputUri.host);
    final effectivePortalToken =
        (session.portalToken?.trim().isNotEmpty ?? false)
            ? session.portalToken!.trim()
            : cleanPortalToken;

    if (_isDifferentAccountLogin(
      client,
      session.userId,
      storedUserId: storedUserId,
    )) {
      await _clearUserScopedLocalState(client);
    }
    final matrixUri = _resolveClientHomeserver(inputUri, session.homeserver);
    await client.checkHomeserver(matrixUri);
    final checkedHomeserver = client.homeserver ?? matrixUri;
    final storedDeviceId = await _storage.read(key: 'matrix_device_id');
    final deviceId = await _resolveSessionDeviceId(
      httpClient: client.httpClient,
      homeserver: checkedHomeserver,
      accessToken: session.accessToken,
      sessionDeviceId: session.deviceId,
      storedDeviceId: storedDeviceId,
    );
    await _establishPrivacyBaselineBeforeInit(
      client,
      homeserver: checkedHomeserver,
      accessToken: session.accessToken,
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
        newToken: session.accessToken,
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
    await _persistSession(
      client,
      checkedHomeserver,
      portalToken: effectivePortalToken,
      deviceId: deviceId,
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
      state = AsyncData(
        AuthState(
          isLoggedIn: true,
          userId: result.userId,
          homeserver: result.homeserver.toString(),
          portalToken: result.portalToken,
          ownerDisplayName: ownerDisplayName,
          requiresProfileSetup:
              ownerDisplayName != null && ownerDisplayName.trim().isEmpty,
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
    final currentPortalToken =
        auth?.portalToken ?? await _storage.read(key: 'portal_token');
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
    final profile =
        await asClient.updateOwnerProfile(displayName: cleanDisplayName);
    await asClient.changePortalPassword(
      oldPassword: currentPortalToken.trim(),
      newPassword: cleanToken,
    );
    final deviceId = client.deviceID ??
        await _storage.read(key: 'matrix_device_id') ??
        _createDeviceId();
    final userId = client.userID ?? auth?.userId ?? profile.userId;
    if (userId.isNotEmpty) {
      await client.setDisplayName(userId, cleanDisplayName);
    }
    await _persistSession(
      client,
      homeserver,
      portalToken: cleanToken,
      deviceId: deviceId,
      userId: userId,
    );
    final savedDisplayName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : cleanDisplayName;
    state = AsyncData(
      AuthState(
        isLoggedIn: true,
        userId: userId,
        homeserver: homeserver.toString(),
        portalToken: cleanToken,
        ownerDisplayName: savedDisplayName,
      ),
    );
    _startPostLoginConversationSync(
      client,
      homeserver: homeserver,
      portalToken: cleanToken,
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
    final portalToken =
        auth?.portalToken ?? await _storage.read(key: 'portal_token');
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
    final currentPortalToken =
        auth?.portalToken ?? await _storage.read(key: 'portal_token');
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
    await asClient.changePortalPassword(
      oldPassword: cleanOldPassword,
      newPassword: cleanNewPassword,
    );
    final deviceId = client.deviceID ??
        await _storage.read(key: 'matrix_device_id') ??
        _createDeviceId();
    await _persistSession(
      client,
      homeserver,
      portalToken: cleanNewPassword,
      deviceId: deviceId,
    );
    state = AsyncData(
      AuthState(
        isLoggedIn: true,
        userId: client.userID ?? auth?.userId,
        homeserver: homeserver.toString(),
        portalToken: cleanNewPassword,
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
    await asClient.changePortalPassword(
      oldPassword: cleanSetupCode,
      newPassword: cleanNewToken,
    );
    await _persistSession(
      client,
      result.homeserver,
      portalToken: cleanNewToken,
      deviceId: result.deviceId,
    );
    state = AsyncData(
      AuthState(
        isLoggedIn: true,
        userId: client.userID ?? result.userId,
        homeserver: result.homeserver.toString(),
        portalToken: cleanNewToken,
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
          waitUntilLoadCompletedLoaded: true,
        );
      }
      if (!client.isLogged()) return null;
      String? userId;
      try {
        final tokenOwner = await client.getTokenOwner();
        userId = client.userID ?? tokenOwner.userId;
      } catch (e) {
        if (_isTokenFailure(e) && (portalToken?.trim().isEmpty ?? true)) {
          return null;
        }
        userId = client.userID;
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
        await _storage.write(key: 'portal_token', value: portalToken);
      }

      return AuthState(
        isLoggedIn: true,
        userId: userId,
        homeserver: homeserver.toString(),
        portalToken: portalToken,
      );
    } catch (_) {
      return null;
    }
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

    try {
      final session = await HttpAsClient.authenticatePortal(
        baseUri: HttpAsClient.defaultAdminBaseUri(homeserverUri),
        portalToken: cleanPortalToken,
        httpClient: client.httpClient,
      );
      final matrixUri = _resolveClientHomeserver(
        homeserverUri,
        session.homeserver,
      );
      final deviceId = await _resolveSessionDeviceId(
        httpClient: client.httpClient,
        homeserver: matrixUri,
        accessToken: session.accessToken,
        sessionDeviceId: session.deviceId,
        storedDeviceId: await _storage.read(key: 'matrix_device_id'),
      );
      if (client.onLoginStateChanged.value == LoginState.loggedIn) {
        await _applyRefreshedSession(
          client,
          matrixUri,
          session,
          portalToken: cleanPortalToken,
          deviceId: deviceId,
        );
      } else {
        await client.init(
          newToken: session.accessToken,
          newUserID: session.userId,
          newHomeserver: matrixUri,
          newDeviceID: deviceId,
          newDeviceName: 'PortalIM',
          waitForFirstSync: false,
          waitUntilLoadCompletedLoaded: true,
        );
        await _persistSession(
          client,
          matrixUri,
          portalToken: cleanPortalToken,
          deviceId: deviceId,
          userId: session.userId,
        );
      }
      return AuthState(
        isLoggedIn: true,
        userId: client.userID ?? session.userId,
        homeserver: (client.homeserver ?? matrixUri).toString(),
        portalToken: cleanPortalToken,
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
    try {
      final tokenOwner = await client.getTokenOwner();
      if (tokenOwner.userId == expectedUserId) return;
    } catch (e) {
      if (!_isTokenFailure(e)) rethrow;
    }

    final cleanPortalToken = portalToken?.trim() ?? '';
    if (cleanPortalToken.isEmpty) {
      throw StateError('Matrix access token 已失效，请重新登录');
    }

    final session = await HttpAsClient.authenticatePortal(
      baseUri: HttpAsClient.defaultAdminBaseUri(homeserver),
      portalToken: cleanPortalToken,
      httpClient: client.httpClient,
    );
    final refreshedDeviceId = await _resolveSessionDeviceId(
      httpClient: client.httpClient,
      homeserver: homeserver,
      accessToken: session.accessToken,
      sessionDeviceId: session.deviceId,
      storedDeviceId: deviceId,
    );
    await _applyRefreshedSession(
      client,
      homeserver,
      session,
      portalToken: cleanPortalToken,
      deviceId: refreshedDeviceId,
    );
  }

  Future<void> _applyRefreshedSession(
    Client client,
    Uri currentHomeserver,
    AsPortalSession session, {
    required String portalToken,
    required String deviceId,
  }) async {
    final matrixUri = _resolveClientHomeserver(
      currentHomeserver,
      session.homeserver,
    );
    client.homeserver = matrixUri;
    client.accessToken = session.accessToken;
    final effectiveDeviceId = client.deviceID ?? session.deviceId ?? deviceId;
    await client.database?.updateClient(
      matrixUri.toString(),
      session.accessToken,
      null,
      null,
      session.userId,
      effectiveDeviceId,
      client.deviceName ?? 'PortalIM',
      client.prevBatch,
      client.encryption?.pickledOlmAccount,
    );
    await _persistSession(
      client,
      matrixUri,
      portalToken: portalToken,
      deviceId: effectiveDeviceId,
      userId: session.userId,
    );
  }

  bool _isLoggedInAs(Client client, String userId) {
    return client.onLoginStateChanged.value == LoginState.loggedIn &&
        client.userID == userId;
  }

  bool _isDifferentAccountLogin(
    Client client,
    String nextUserId, {
    required String? storedUserId,
  }) {
    final next = nextUserId.trim();
    if (next.isEmpty) return false;
    final current = client.userID?.trim() ?? '';
    if (current.isNotEmpty && current != next) return true;
    final stored = storedUserId?.trim() ?? '';
    if (stored.isNotEmpty && stored != next) return true;
    return client.rooms.isNotEmpty && !_isLoggedInAs(client, next);
  }

  bool _isTokenFailure(Object error) {
    return error is MatrixException &&
        (error.errcode == 'M_UNKNOWN_TOKEN' ||
            error.errcode == 'M_MISSING_TOKEN' ||
            error.response?.statusCode == 401);
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

  Uri _resolveClientHomeserver(Uri inputUri, String asHomeserver) {
    final parsed = Uri.tryParse(asHomeserver);
    if (parsed == null || parsed.host.isEmpty) return inputUri;
    if (_isLocalHost(parsed.host) && !_isLocalHost(inputUri.host)) {
      return inputUri;
    }
    return parsed;
  }

  bool _isLocalHost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '0.0.0.0';
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
  }) async {
    await _storage.write(key: 'matrix_token', value: client.accessToken);
    await _storage.write(key: 'matrix_homeserver', value: uri.toString());
    await _storage.write(key: 'matrix_user_id', value: userId ?? client.userID);
    await _storage.write(
      key: 'matrix_device_id',
      value: client.deviceID ?? deviceId,
    );
    await _storage.write(key: 'portal_token', value: portalToken);
    await _storage.write(key: lastLoginHomeserverKey, value: uri.toString());
    await _storage.write(key: lastLoginPortalTokenKey, value: portalToken);
  }

  Future<void> _clearUserScopedLocalState(
    Client client, {
    bool clearMatrix = true,
  }) async {
    if (clearMatrix) {
      await client.clear();
    }
    ref.read(asSyncCacheProvider.notifier).state = const AsSyncCacheState();
    ref.invalidate(localOutboxProvider);
    ref.invalidate(localOutboxStoreProvider);
    ref.invalidate(localMessageOrderProvider);
    ref.invalidate(localMessageOrderStoreProvider);
    ref.invalidate(friendRequestReadProvider);
    ref.invalidate(friendRequestReadStoreProvider);
    ref.invalidate(recoveredUnreadStoreProvider);
    ref.invalidate(asCallSessionStoreProvider);
    await _deleteUserScopedSupportFiles();
  }

  Future<void> _deleteUserScopedSupportFiles() async {
    final dir = await getApplicationSupportDirectory();
    const filenames = [
      'portal_im_as_bootstrap.json',
      'portal_im_recovered_unread.json',
      'portal_im_pending_media_uploads.json',
      'portal_im_local_message_order.json',
      'portal_im_call_sessions.json',
      'portal_im_friend_request_read.json',
      'portal_im_channel_posts.json',
    ];
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

  Future<void> logout() async {
    final client = ref.read(matrixClientProvider);
    final lastHomeserver = await _storage.read(key: lastLoginHomeserverKey) ??
        await _storage.read(key: 'matrix_homeserver');
    final lastPortalToken = await _storage.read(key: lastLoginPortalTokenKey) ??
        await _storage.read(key: 'portal_token');
    try {
      await client.logout();
    } catch (e) {
      debugPrint('matrix logout failed: $e');
      await client.clear();
    }
    await _clearUserScopedLocalState(client, clearMatrix: false);
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
        requiresProfileSetup: ownerDisplayName.trim().isEmpty,
      );
}

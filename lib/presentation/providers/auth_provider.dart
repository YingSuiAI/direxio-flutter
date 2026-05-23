import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/http_as_client.dart';
import '../../data/well_known_service.dart';

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
  return Client(
    'PortalIM',
    databaseBuilder: (_) async {
      final db = MatrixSdkDatabase('portal_im_db');
      await db.open();
      return db;
    },
  );
}

class AuthState {
  const AuthState({
    required this.isLoggedIn,
    this.userId,
    this.homeserver,
    this.portalToken,
  });

  final bool isLoggedIn;
  final String? userId;
  final String? homeserver;
  final String? portalToken;
}

@riverpod
class AuthStateNotifier extends _$AuthStateNotifier {
  static const _storage = FlutterSecureStorage();

  @override
  Future<AuthState> build() async {
    final client = ref.watch(matrixClientProvider);
    final token = await _storage.read(key: 'matrix_token');
    final homeserver = await _storage.read(key: 'matrix_homeserver');
    final userId = await _storage.read(key: 'matrix_user_id');
    final portalToken = await _storage.read(key: 'portal_token');

    if (token != null && homeserver != null && userId != null) {
      try {
        await client.checkHomeserver(Uri.parse(homeserver));
        final deviceId =
            await _storage.read(key: 'matrix_device_id') ?? _createDeviceId();
        await client.init(
          newToken: token,
          newUserID: userId,
          newHomeserver: client.homeserver ?? Uri.parse(homeserver),
          newDeviceID: deviceId,
          newDeviceName: 'PortalIM',
        );
        return AuthState(
          isLoggedIn: true,
          userId: userId,
          homeserver: homeserver,
          portalToken: portalToken,
        );
      } catch (_) {
        await _storage.deleteAll();
      }
    }
    return const AuthState(isLoggedIn: false);
  }

  Future<void> login(String homeserverUrl, String portalToken) async {
    await _loginWithPortal(homeserverUrl, portalToken);
  }

  Future<void> _loginWithPortal(
    String homeserverUrl,
    String portalToken, {
    String? displayName,
  }) async {
    final client = ref.read(matrixClientProvider);
    final inputUri = _normalizeHomeserverUri(homeserverUrl);
    final cleanPortalToken = portalToken.trim();
    if (cleanPortalToken.isEmpty) {
      throw ArgumentError('Portal Token 不能为空');
    }

    // §3.1 / §7 步骤 3：先确认 Portal 已部署。
    await _assertPortalDeployed(inputUri.host);
    final session = await HttpAsClient.authenticatePortal(
      baseUri: HttpAsClient.defaultAdminBaseUri(inputUri),
      portalToken: cleanPortalToken,
      httpClient: client.httpClient,
    );

    final matrixUri = _resolveClientHomeserver(inputUri, session.homeserver);
    await client.checkHomeserver(matrixUri);
    final checkedHomeserver = client.homeserver ?? matrixUri;
    final storedDeviceId = await _storage.read(key: 'matrix_device_id');
    final deviceId = session.deviceId ?? storedDeviceId ?? _createDeviceId();

    await client.init(
      newToken: session.accessToken,
      newUserID: session.userId,
      newHomeserver: checkedHomeserver,
      newDeviceID: deviceId,
      newDeviceName: 'PortalIM',
    );
    if (displayName != null && displayName.trim().isNotEmpty) {
      await client.setDisplayName(session.userId, displayName.trim());
    }
    await _persistSession(
      client,
      checkedHomeserver,
      portalToken: cleanPortalToken,
      deviceId: deviceId,
    );
    // §7 步骤 6：登录后确保与 Agent 的 DM 存在
    await _ensureAgentDm(client, inputUri.host);
    state = AsyncData(
      AuthState(
        isLoggedIn: true,
        userId: client.userID,
        homeserver: checkedHomeserver.toString(),
        portalToken: cleanPortalToken,
      ),
    );
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

  /// §7 步骤 6：在 rooms 中找 `@agent:{domain}` 的 DM，没有则创建。
  /// 失败不阻断登录流程（Agent 可能尚未部署）。
  Future<void> _ensureAgentDm(Client client, String host) async {
    try {
      final agentMxid = WellKnownService.agentMxidForDomain(host);
      final existing = client.getDirectChatFromUserId(agentMxid);
      if (existing == null) {
        await client.startDirectChat(agentMxid);
      }
    } catch (_) {
      // Agent 未部署 / 无法邀请 —— 静默跳过，不影响登录
    }
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
  }) async {
    await _storage.write(key: 'matrix_token', value: client.accessToken);
    await _storage.write(key: 'matrix_homeserver', value: uri.toString());
    await _storage.write(key: 'matrix_user_id', value: client.userID);
    await _storage.write(
      key: 'matrix_device_id',
      value: client.deviceID ?? deviceId,
    );
    await _storage.write(key: 'portal_token', value: portalToken);
  }

  Future<void> logout() async {
    final client = ref.read(matrixClientProvider);
    await client.logout();
    await _storage.deleteAll();
    state = const AsyncData(AuthState(isLoggedIn: false));
  }
}

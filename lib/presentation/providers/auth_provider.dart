import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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
  const AuthState({required this.isLoggedIn, this.userId, this.homeserver});
  final bool isLoggedIn;
  final String? userId;
  final String? homeserver;
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

    if (token != null && homeserver != null && userId != null) {
      try {
        await client.checkHomeserver(Uri.parse(homeserver));
        await client.init(
          newToken: token,
          newUserID: userId,
          newHomeserver: Uri.parse(homeserver),
          newDeviceID: await _storage.read(key: 'matrix_device_id'),
          newDeviceName: 'PortalIM',
        );
        return AuthState(isLoggedIn: true, userId: userId, homeserver: homeserver);
      } catch (_) {
        await _storage.deleteAll();
      }
    }
    return const AuthState(isLoggedIn: false);
  }

  Future<void> login(String homeserverUrl, String password) async {
    final client = ref.read(matrixClientProvider);
    final uri = Uri.parse(
      homeserverUrl.startsWith('http') ? homeserverUrl : 'https://$homeserverUrl',
    );
    // §3.1 / §7 步骤 3：先确认 Portal 已部署
    await _assertPortalDeployed(uri.host);
    await client.checkHomeserver(uri);
    await client.login(
      LoginType.mLoginPassword,
      identifier: AuthenticationUserIdentifier(user: '@owner:${uri.host}'),
      password: password,
    );
    await _persistSession(client, uri);
    // §7 步骤 6：登录后确保与 Agent 的 DM 存在
    await _ensureAgentDm(client, uri.host);
    state = AsyncData(AuthState(
      isLoggedIn: true,
      userId: client.userID,
      homeserver: uri.toString(),
    ));
  }

  Future<void> register(String homeserverUrl, String password, String displayName) async {
    final client = ref.read(matrixClientProvider);
    final uri = Uri.parse(
      homeserverUrl.startsWith('http') ? homeserverUrl : 'https://$homeserverUrl',
    );
    await client.checkHomeserver(uri);
    await client.register(username: 'owner', password: password);
    await client.setDisplayName(client.userID!, displayName);
    await _persistSession(client, uri);
    await _ensureAgentDm(client, uri.host);
    state = AsyncData(AuthState(
      isLoggedIn: true,
      userId: client.userID,
      homeserver: uri.toString(),
    ));
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

  Future<void> _persistSession(Client client, Uri uri) async {
    await _storage.write(key: 'matrix_token', value: client.accessToken);
    await _storage.write(key: 'matrix_homeserver', value: uri.toString());
    await _storage.write(key: 'matrix_user_id', value: client.userID);
    await _storage.write(key: 'matrix_device_id', value: client.deviceID);
  }

  Future<void> logout() async {
    final client = ref.read(matrixClientProvider);
    await client.logout();
    await _storage.deleteAll();
    state = const AsyncData(AuthState(isLoggedIn: false));
  }
}

/// 域名发现服务 —— 对应 INTERFACE_SPEC.md §2
///
/// App 启动时只知道域名（如 liyananp2p.com），需要自动发现 Matrix 服务入口。
/// 本服务封装三个 .well-known 端点的解析。
import 'dart:convert';
import 'package:http/http.dart' as http;

/// `/.well-known/portal/owner.json` 的解析结果
class PortalOwner {
  const PortalOwner({required this.matrixUserId, required this.displayName});

  /// Portal 主人的 MXID，如 `@owner:liyananp2p.com`
  final String matrixUserId;

  /// 显示名，如 "施歌"
  final String displayName;

  factory PortalOwner.fromJson(Map<String, dynamic> json) => PortalOwner(
        matrixUserId: json['matrix_user_id'] as String,
        displayName: (json['display_name'] as String?) ?? '',
      );
}

/// Portal 部署状态
enum PortalAvailability {
  /// owner.json 返回 200 —— Portal 已部署且在线
  online,

  /// owner.json 返回 404 —— 该域名未部署 Portal
  notDeployed,

  /// 网络错误 / 其他状态码 —— 无法确定
  unreachable,
}

class WellKnownResult {
  const WellKnownResult({
    required this.availability,
    this.homeserverBaseUrl,
    this.owner,
    this.federationServer,
  });

  final PortalAvailability availability;

  /// `/.well-known/matrix/client` 的 `m.homeserver.base_url`
  final String? homeserverBaseUrl;

  /// `/.well-known/portal/owner.json` 解析结果
  final PortalOwner? owner;

  /// `/.well-known/matrix/server` 的 `m.server`
  final String? federationServer;

  bool get isOnline => availability == PortalAvailability.online;
}

/// 域名发现。可注入自定义 [http.Client]（默认复用调用方传入的，便于测试 / 复用 matrix SDK 的 client）。
class WellKnownService {
  WellKnownService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _timeout = Duration(seconds: 8);

  String _normalizeDomain(String input) =>
      input.trim().replaceAll(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/+$'), '');

  /// 发现 Homeserver —— §2.1
  /// GET https://{domain}/.well-known/matrix/client
  Future<String?> discoverHomeserver(String domain) async {
    final d = _normalizeDomain(domain);
    try {
      final resp = await _http
          .get(Uri.parse('https://$d/.well-known/matrix/client'))
          .timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final hs = json['m.homeserver'] as Map<String, dynamic>?;
      return hs?['base_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 发现 Bot（Agent）/ 确认 Portal 部署 —— §2.2 + §3.1
  /// GET https://{domain}/.well-known/portal/owner.json
  ///
  /// 返回结果区分三态：online / notDeployed(404) / unreachable。
  Future<({PortalAvailability availability, PortalOwner? owner})> discoverOwner(
      String domain) async {
    final d = _normalizeDomain(domain);
    try {
      final resp = await _http
          .get(Uri.parse('https://$d/.well-known/portal/owner.json'))
          .timeout(_timeout);
      if (resp.statusCode == 404) {
        return (availability: PortalAvailability.notDeployed, owner: null);
      }
      if (resp.statusCode != 200) {
        return (availability: PortalAvailability.unreachable, owner: null);
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return (
        availability: PortalAvailability.online,
        owner: PortalOwner.fromJson(json),
      );
    } catch (_) {
      return (availability: PortalAvailability.unreachable, owner: null);
    }
  }

  /// 发现 Federation —— §2.3
  /// GET https://{domain}/.well-known/matrix/server
  Future<String?> discoverFederation(String domain) async {
    final d = _normalizeDomain(domain);
    try {
      final resp = await _http
          .get(Uri.parse('https://$d/.well-known/matrix/server'))
          .timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return json['m.server'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 一次性发现全部 —— App 初始化流程 §7 步骤 2-3 用。
  Future<WellKnownResult> discoverAll(String domain) async {
    final ownerResult = await discoverOwner(domain);
    // owner.json 不通就没必要继续；homeserver / federation 一般也不可用
    if (ownerResult.availability != PortalAvailability.online) {
      return WellKnownResult(availability: ownerResult.availability);
    }
    final homeserver = await discoverHomeserver(domain);
    final federation = await discoverFederation(domain);
    return WellKnownResult(
      availability: PortalAvailability.online,
      homeserverBaseUrl: homeserver,
      owner: ownerResult.owner,
      federationServer: federation,
    );
  }

  /// Agent MXID 约定 —— §2.2：`@agent:{domain}`
  static String agentMxidForDomain(String domain) {
    final d = domain.trim().replaceAll(RegExp(r'^https?://'), '');
    return '@agent:$d';
  }
}

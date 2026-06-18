// 域名发现服务 —— 对应 INTERFACE_SPEC.md §2
//
// App 启动时只知道域名（如 liyananp2p.com），需要自动发现 Matrix 服务入口。
// 本服务封装三个 .well-known 端点的解析。
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_logger.dart';

//// `/.well-known/portal/owner.json` 的解析结果
class PortalOwner {
  const PortalOwner({
    required this.matrixUserId,
    required this.displayName,
    this.avatarUrl = '',
  });

  /// Portal 主人的 MXID，如 `@owner:liyananp2p.com`
  final String matrixUserId;

  /// 显示名，如 "施歌"
  final String displayName;

  /// 头像地址，通常是 mxc:// 或 https://。
  final String avatarUrl;

  factory PortalOwner.fromJson(Map<String, dynamic> json) => PortalOwner(
        matrixUserId: _firstString(json, const [
          'matrix_user_id',
          'mxid',
          'user_id',
          'userId',
        ]),
        displayName: _firstString(json, const [
          'display_name',
          'displayName',
          'name',
          'nickname',
          'nick_name',
        ]),
        avatarUrl: _firstString(json, const [
          'avatar_url',
          'avatarUrl',
          'avatar',
          'avatar_mxc',
        ]),
      );
}

String _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

//// Portal 部署状态
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

//// 域名发现。可注入自定义 [http.Client]（默认复用调用方传入的，便于测试 / 复用 matrix SDK 的 client）。
class WellKnownService {
  WellKnownService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _timeout = Duration(seconds: 8);

  String _normalizeDomain(String input) => input
      .trim()
      .replaceAll(RegExp(r'^https?://'), '')
      .replaceAll(RegExp(r'/+$'), '');

  Uri _wellKnownUri(String domain, String path) {
    final d = _normalizeDomain(domain);
    final localPort = _localDualNodeHttpPort(d);
    if (localPort != null) {
      return Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: localPort,
        path: path,
      );
    }
    return Uri.parse('https://$d$path');
  }

  /// 发现 Homeserver —— §2.1
  /// GET https://{domain}/.well-known/matrix/client
  Future<String?> discoverHomeserver(String domain) async {
    final uri = _wellKnownUri(domain, '/.well-known/matrix/client');
    try {
      final resp = await _get(uri);
      if (resp.statusCode != 200) return null;
      final json = _decodeObject(uri, resp);
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
    String domain,
  ) async {
    final uri = _wellKnownUri(domain, '/.well-known/portal/owner.json');
    try {
      final resp = await _get(uri);
      if (resp.statusCode == 404) {
        return (availability: PortalAvailability.notDeployed, owner: null);
      }
      if (resp.statusCode != 200) {
        return (availability: PortalAvailability.unreachable, owner: null);
      }
      final json = _decodeObject(uri, resp);
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
    final uri = _wellKnownUri(domain, '/.well-known/matrix/server');
    try {
      final resp = await _get(uri);
      if (resp.statusCode != 200) return null;
      final json = _decodeObject(uri, resp);
      return json['m.server'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 发现全部 —— App 初始化流程 §7 步骤 2-3 用。
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

  Future<http.Response> _get(Uri uri) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _http.get(uri).timeout(_timeout);
      stopwatch.stop();
      ApiLogger.response(
        service: 'well-known',
        method: 'GET',
        uri: uri,
        statusCode: response.statusCode,
        elapsed: stopwatch.elapsed,
        responseBody: response.body,
      );
      return response;
    } catch (error, stackTrace) {
      stopwatch.stop();
      ApiLogger.failure(
        service: 'well-known',
        method: 'GET',
        uri: uri,
        elapsed: stopwatch.elapsed,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Map<String, dynamic> _decodeObject(Uri uri, http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (error, stackTrace) {
      ApiLogger.failure(
        service: 'well-known',
        method: 'DECODE',
        uri: uri,
        elapsed: Duration.zero,
        statusCode: response.statusCode,
        responseBody: response.body,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

int? _localDualNodeHttpPort(String domain) {
  final host = Uri.tryParse('matrix://$domain')?.host.toLowerCase();
  return switch (host) {
    'dendrite-a' => 18008,
    'dendrite-b' => 28008,
    _ => null,
  };
}

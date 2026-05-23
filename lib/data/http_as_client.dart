import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

import 'as_client.dart';

/// HTTP implementation for the p2p-matrix-as Admin API.
///
/// Production deployments expose AS under `https://{domain}/_as/*`.
/// Local AS development runs the admin API on port 9090, so loopback
/// homeservers such as `http://127.0.0.1:8008` are mapped to
/// `http://127.0.0.1:9090/_as/*`.
class HttpAsClient implements AsClient {
  HttpAsClient({
    required Uri baseUri,
    String? portalToken,
    String? accessToken,
    http.Client? httpClient,
  })  : _baseUri = _normalizeBaseUri(baseUri),
        _portalToken = _requireToken(portalToken ?? accessToken),
        _http = httpClient ?? http.Client();

  factory HttpAsClient.fromPortalSession(
    Client client, {
    required String portalToken,
    Uri? baseUri,
  }) {
    final homeserver = client.homeserver;
    if (homeserver == null) {
      throw AsClientException('Matrix session is not initialized');
    }
    return HttpAsClient(
      baseUri: baseUri ?? defaultAdminBaseUri(homeserver),
      portalToken: portalToken,
      httpClient: client.httpClient,
    );
  }

  /// Backward-compatible constructor for sessions created before AS v2 auth.
  /// New p2p-matrix-as deployments expect [fromPortalSession] instead.
  factory HttpAsClient.fromMatrixClient(Client client, {Uri? baseUri}) {
    final token = client.accessToken;
    final homeserver = client.homeserver;
    if (token == null || token.isEmpty || homeserver == null) {
      throw AsClientException('Matrix session is not initialized');
    }
    return HttpAsClient(
      baseUri: baseUri ?? defaultAdminBaseUri(homeserver),
      accessToken: token,
      httpClient: client.httpClient,
    );
  }

  final Uri _baseUri;
  final String _portalToken;
  final http.Client _http;

  static const _timeout = Duration(seconds: 10);

  static Uri defaultAdminBaseUri(Uri homeserver) {
    final host = homeserver.host;
    final isLoopback =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    final port = isLoopback ? 9090 : (homeserver.hasPort ? homeserver.port : 0);
    return Uri(
      scheme: homeserver.scheme.isEmpty ? 'https' : homeserver.scheme,
      host: host,
      port: port,
      path: '/_as',
    );
  }

  static Future<AsPortalSession> authenticatePortal({
    required Uri baseUri,
    required String portalToken,
    http.Client? httpClient,
  }) async {
    final ownsClient = httpClient == null;
    final client = httpClient ?? http.Client();
    final normalizedBase = _normalizeBaseUri(baseUri);
    try {
      return await _postPortalAuth(
        client,
        normalizedBase,
        'bootstrap',
        portalToken,
        allowAlreadyInitialized: true,
      );
    } on AsClientException catch (e) {
      if (e.statusCode != 409) rethrow;
      return _postPortalAuth(client, normalizedBase, 'auth', portalToken);
    } finally {
      if (ownsClient) client.close();
    }
  }

  @override
  Future<List<AsSearchResult>> search(
    String query, {
    String? roomId,
    int limit = 20,
  }) async {
    final body = await _getJson(
      'search',
      queryParameters: {
        'q': query,
        if (roomId != null && roomId.isNotEmpty) 'room_id': roomId,
        'limit': limit.toString(),
      },
    );
    final raw = body['results'] as List<dynamic>? ?? const [];
    return raw
        .map((item) => AsSearchResult.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<AgentConfig> getAgentConfig() async {
    final body = await _getJson('agent/config');
    return AgentConfig.fromJson(body);
  }

  @override
  Future<AgentConfig> updateAgentConfig(AgentConfig config) async {
    await _requestJson(
      'PUT',
      'agent/config',
      body: config.toJson(),
      allowedStatusCodes: const {200},
    );
    return getAgentConfig();
  }

  @override
  Future<AgentStatus> getAgentStatus() async {
    final body = await _getJson('agent/status');
    return AgentStatus.fromJson(body);
  }

  @override
  Future<List<FollowEntry>> getFollows() async {
    final body = await _getJson('follows');
    final raw = body['follows'] as List<dynamic>? ?? const [];
    return raw
        .map((item) => FollowEntry.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> addFollow(String domain) async {
    await _requestJson(
      'POST',
      'follows',
      body: {'domain': domain},
      allowedStatusCodes: const {200, 409},
    );
  }

  @override
  Future<void> removeFollow(String domain) async {
    await _requestJson(
      'DELETE',
      'follows/${Uri.encodeComponent(domain)}',
      allowedStatusCodes: const {200, 404},
    );
  }

  @override
  Future<PortalStatus> getPortalStatus() async {
    final body = await _getJson('portal/status');
    return PortalStatus.fromJson(body);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return _requestJson(
      'GET',
      path,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    Set<int> allowedStatusCodes = const {200},
  }) async {
    final uri = _resolve(path, queryParameters: queryParameters);
    final request = http.Request(method, uri);
    request.headers['Authorization'] = 'Bearer $_portalToken';
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.encoding = utf8;
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final streamed = await _http.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    if (!allowedStatusCodes.contains(response.statusCode)) {
      throw AsClientException(
        _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
    if (response.body.trim().isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw AsClientException(
        'AS returned a non-object JSON response',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Uri _resolve(String path, {Map<String, String>? queryParameters}) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final basePath =
        _baseUri.path.endsWith('/') ? _baseUri.path : '${_baseUri.path}/';
    return _baseUri.replace(
      path: '$basePath$cleanPath',
      queryParameters: queryParameters,
    );
  }

  static Uri _normalizeBaseUri(Uri baseUri) {
    final path =
        baseUri.path.isEmpty || baseUri.path == '/' ? '/_as' : baseUri.path;
    return baseUri.replace(path: path.endsWith('/') ? path : path);
  }

  static String _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded['error'] as String? ??
            decoded['message'] as String? ??
            response.reasonPhrase ??
            'AS request failed';
      }
    } catch (_) {
      // Fall through to a generic HTTP error message.
    }
    return response.reasonPhrase ?? 'AS request failed';
  }

  static String _requireToken(String? token) {
    if (token == null || token.isEmpty) {
      throw AsClientException('AS portal token is required');
    }
    return token;
  }

  static Future<AsPortalSession> _postPortalAuth(
    http.Client client,
    Uri baseUri,
    String path,
    String portalToken, {
    bool allowAlreadyInitialized = false,
  }) async {
    final uri = _resolveStatic(baseUri, path);
    final response = await client
        .post(
          uri,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({'token': portalToken}),
        )
        .timeout(_timeout);

    if (allowAlreadyInitialized && response.statusCode == 409) {
      throw AsClientException(
        _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode != 200) {
      throw AsClientException(
        _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw AsClientException(
        'AS returned a non-object JSON response',
        statusCode: response.statusCode,
      );
    }
    final session = AsPortalSession.fromJson(decoded);
    if (session.accessToken.isEmpty ||
        session.userId.isEmpty ||
        session.homeserver.isEmpty) {
      throw AsClientException(
        'AS auth response is missing access_token, user_id, or homeserver',
        statusCode: response.statusCode,
      );
    }
    return session;
  }

  static Uri _resolveStatic(Uri baseUri, String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final basePath =
        baseUri.path.endsWith('/') ? baseUri.path : '${baseUri.path}/';
    return baseUri.replace(path: '$basePath$cleanPath');
  }
}

class AsPortalSession {
  const AsPortalSession({
    required this.accessToken,
    required this.userId,
    required this.homeserver,
    this.deviceId,
  });

  final String accessToken;
  final String userId;
  final String homeserver;
  final String? deviceId;

  factory AsPortalSession.fromJson(Map<String, dynamic> json) {
    return AsPortalSession(
      accessToken: json['access_token'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      homeserver: json['homeserver'] as String? ?? '',
      deviceId: json['device_id'] as String?,
    );
  }
}

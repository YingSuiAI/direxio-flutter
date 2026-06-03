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

  @override
  Future<OwnerProfile> getOwnerProfile() async {
    final body = await _getJson('profile');
    return OwnerProfile.fromJson(body);
  }

  @override
  Future<OwnerProfile> updateOwnerProfile({
    required String displayName,
  }) async {
    final body = await _requestJson(
      'PUT',
      'profile',
      body: {'display_name': displayName.trim()},
      allowedStatusCodes: const {200},
    );
    return OwnerProfile.fromJson(body);
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
  Future<AsSyncBootstrap> syncBootstrap() async {
    final body = await _getJson('sync/bootstrap');
    return AsSyncBootstrap.fromJson(body);
  }

  @override
  Future<AsSyncUnread> syncUnread({int limitPerRoom = 200}) async {
    final body = await _getJson(
      'sync/unread',
      queryParameters: {'limit_per_room': limitPerRoom.toString()},
    );
    return AsSyncUnread.fromJson(body);
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
  Future<List<AsFavoriteMessage>> getFavorites({
    String messageType = '',
    int limit = 100,
  }) async {
    final body = await _getJson(
      'favorites',
      queryParameters: {
        if (messageType.trim().isNotEmpty) 'type': messageType.trim(),
        'limit': limit.toString(),
      },
    );
    final raw = body['favorites'] as List<dynamic>? ?? const [];
    return raw
        .map((item) => AsFavoriteMessage.fromJson(
              (item as Map).cast<String, dynamic>(),
            ))
        .toList(growable: false);
  }

  @override
  Future<AsFavoriteMessage> favoriteMessage(
    AsFavoriteMessageDraft draft,
  ) async {
    final body = await _requestJson(
      'POST',
      'favorites',
      body: draft.toJson(),
      allowedStatusCodes: const {200},
    );
    return AsFavoriteMessage.fromJson(body);
  }

  @override
  Future<void> deleteFavorite(int id) async {
    await _requestJson(
      'DELETE',
      'favorites/${Uri.encodeComponent(id.toString())}',
      allowedStatusCodes: const {200, 404},
    );
  }

  @override
  Future<ContactEntry> createContactRequest({
    required String mxid,
    String displayName = '',
    String domain = '',
  }) async {
    final body = await _requestJson(
      'POST',
      'contacts/requests',
      body: {
        'mxid': mxid.trim(),
        if (displayName.trim().isNotEmpty) 'display_name': displayName.trim(),
        if (domain.trim().isNotEmpty) 'domain': domain.trim(),
      },
      allowedStatusCodes: const {200},
    );
    return ContactEntry.fromJson(body);
  }

  @override
  Future<ContactEntry> acceptContactRequest({
    required String roomId,
    required String peerMxid,
    String displayName = '',
    String domain = '',
  }) {
    return _contactDecision(
      roomId: roomId,
      peerMxid: peerMxid,
      displayName: displayName,
      domain: domain,
      action: 'accept',
    );
  }

  @override
  Future<ContactEntry> rejectContactRequest({
    required String roomId,
    required String peerMxid,
    String displayName = '',
    String domain = '',
  }) {
    return _contactDecision(
      roomId: roomId,
      peerMxid: peerMxid,
      displayName: displayName,
      domain: domain,
      action: 'reject',
    );
  }

  Future<ContactEntry> _contactDecision({
    required String roomId,
    required String peerMxid,
    required String action,
    String displayName = '',
    String domain = '',
  }) async {
    final body = await _requestJson(
      'POST',
      'contacts/requests/${Uri.encodeComponent(roomId)}/$action',
      body: {
        'peer_mxid': peerMxid.trim(),
        if (displayName.trim().isNotEmpty) 'display_name': displayName.trim(),
        if (domain.trim().isNotEmpty) 'domain': domain.trim(),
      },
      allowedStatusCodes: const {200},
    );
    return ContactEntry.fromJson(body);
  }

  @override
  Future<ContactEntry> deleteContact(String roomId) async {
    final body = await _requestJson(
      'DELETE',
      'contacts/${Uri.encodeComponent(roomId)}',
      allowedStatusCodes: const {200},
    );
    return ContactEntry.fromJson(body);
  }

  @override
  Future<void> deleteRoomMessage({
    required String roomId,
    required String eventId,
  }) async {
    await _requestJson(
      'POST',
      'rooms/${Uri.encodeComponent(roomId)}/messages/delete',
      body: {'event_id': eventId.trim()},
      allowedStatusCodes: const {200},
    );
  }

  @override
  Future<String> sendRoomMessage(String roomId, String content) async {
    final body = await _requestJson(
      'POST',
      'rooms/${Uri.encodeComponent(roomId)}/send',
      body: {'content': content},
      allowedStatusCodes: const {200},
    );
    return body['event_id'] as String? ?? '';
  }

  @override
  Future<String> sendChatRecordMessage({
    required String roomId,
    required String body,
    required String title,
    required String sourceRoomId,
    required String sourceRoomType,
    required int itemCount,
    List<Map<String, Object?>> items = const [],
  }) async {
    final response = await _requestJson(
      'POST',
      'rooms/${Uri.encodeComponent(roomId)}/send',
      body: {
        'content': body.trim(),
        'message_type': 'chat_record',
        'chat_record': {
          'title': title.trim(),
          'source_room_id': sourceRoomId.trim(),
          'source_room_type': sourceRoomType.trim(),
          'item_count': itemCount,
          'items': items,
        },
      },
      allowedStatusCodes: const {200},
    );
    return response['event_id'] as String? ?? '';
  }

  @override
  Future<String> sendRoomMediaMessage({
    required String roomId,
    required String msgType,
    required String body,
    required String filename,
    required String mediaUrl,
    String mimeType = '',
    int size = 0,
    String thumbnailUrl = '',
    String thumbnailMimeType = '',
    int thumbnailSize = 0,
    int width = 0,
    int height = 0,
    int durationMs = 0,
  }) async {
    final response = await _requestJson(
      'POST',
      'rooms/${Uri.encodeComponent(roomId)}/send-media',
      body: {
        'msgtype': msgType.trim(),
        'body': body.trim(),
        if (filename.trim().isNotEmpty) 'filename': filename.trim(),
        'url': mediaUrl.trim(),
        if (mimeType.trim().isNotEmpty) 'mime_type': mimeType.trim(),
        if (size > 0) 'size': size,
        if (thumbnailUrl.trim().isNotEmpty)
          'thumbnail_url': thumbnailUrl.trim(),
        if (thumbnailMimeType.trim().isNotEmpty)
          'thumbnail_mime_type': thumbnailMimeType.trim(),
        if (thumbnailSize > 0) 'thumbnail_size': thumbnailSize,
        if (width > 0) 'width': width,
        if (height > 0) 'height': height,
        if (durationMs > 0) 'duration_ms': durationMs,
      },
      allowedStatusCodes: const {200},
    );
    return response['event_id'] as String? ?? '';
  }

  @override
  Future<AsCallSession> createCall({
    required String roomId,
    required String mediaType,
    List<String> invitedUserIds = const [],
  }) async {
    final body = await _requestJson(
      'POST',
      'calls',
      body: {
        'room_id': roomId.trim(),
        'media_type': mediaType.trim(),
        if (invitedUserIds.isNotEmpty)
          'invited_user_ids': _normalizedStringList(invitedUserIds),
      },
      allowedStatusCodes: const {200},
    );
    return AsCallSession.fromJson(body);
  }

  @override
  Future<AsCallSession> getCall(String callId) async {
    final body = await _getJson('calls/${Uri.encodeComponent(callId)}');
    return AsCallSession.fromJson(body);
  }

  @override
  Future<List<AsCallSession>> getActiveCalls() async {
    final body = await _getJson('calls/active');
    final raw = body['calls'] as List? ?? const [];
    return raw
        .whereType<Map>()
        .map((item) => AsCallSession.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  @override
  Future<List<AsCallSession>> listCalls({
    required String roomId,
    int limit = 50,
  }) async {
    final trimmedRoomId = roomId.trim();
    if (trimmedRoomId.isEmpty) return const [];
    final body = await _getJson(
      'calls',
      queryParameters: {
        'room_id': trimmedRoomId,
        'limit': limit.toString(),
      },
    );
    final raw = body['calls'] as List? ?? const [];
    return raw
        .whereType<Map>()
        .map((item) => AsCallSession.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  @override
  Future<AsCallSession> registerIncomingCall({
    required String callId,
    required String roomId,
    required String mediaType,
    required String createdByMxid,
    DateTime? createdAt,
    List<String> invitedUserIds = const [],
  }) async {
    final body = await _requestJson(
      'POST',
      'calls/incoming',
      body: {
        'call_id': callId.trim(),
        'room_id': roomId.trim(),
        'media_type': mediaType.trim(),
        'created_by_mxid': createdByMxid.trim(),
        if (createdAt != null)
          'created_at_ms': createdAt.toUtc().millisecondsSinceEpoch,
        if (invitedUserIds.isNotEmpty)
          'invited_user_ids': _normalizedStringList(invitedUserIds),
      },
      allowedStatusCodes: const {200},
    );
    return AsCallSession.fromJson(body);
  }

  @override
  Future<AsCallSession> updateCallEvent({
    required String callId,
    required String event,
    String reason = '',
    int durationMs = 0,
  }) async {
    final body = await _requestJson(
      'POST',
      'calls/${Uri.encodeComponent(callId)}/events',
      body: {
        'event': event.trim(),
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
        if (durationMs > 0) 'duration_ms': durationMs,
      },
      allowedStatusCodes: const {200},
    );
    return AsCallSession.fromJson(body);
  }

  @override
  Future<PortalStatus> getPortalStatus() async {
    final body = await _getJson('portal/status');
    return PortalStatus.fromJson(body);
  }

  @override
  Future<String> changePortalToken(String newToken) async {
    final trimmed = newToken.trim();
    final body = await _requestJson(
      'PUT',
      'portal/token',
      body: {'token': trimmed},
      allowedStatusCodes: const {200},
    );
    return body['portal_token'] as String? ?? trimmed;
  }

  @override
  Future<String> createChannel({
    required String name,
    String topic = '',
  }) async {
    final trimmedName = name.trim();
    final trimmedTopic = topic.trim();
    final body = await _requestJson(
      'POST',
      'channels',
      body: {
        'name': trimmedName,
        if (trimmedTopic.isNotEmpty) 'topic': trimmedTopic,
      },
      allowedStatusCodes: const {200},
    );
    final roomId = body['room_id'] as String? ?? '';
    if (roomId.isEmpty) {
      throw AsClientException('AS create channel response is missing room_id');
    }
    return roomId;
  }

  @override
  Future<AsGroupResult> createGroup({
    required String name,
    required List<String> invite,
  }) async {
    final body = await _requestJson(
      'POST',
      'groups',
      body: {
        'name': name.trim(),
        'invite': invite.map((mxid) => mxid.trim()).where((mxid) {
          return mxid.isNotEmpty;
        }).toList(growable: false),
      },
      allowedStatusCodes: const {200},
    );
    final group = AsGroupResult.fromJson(body);
    if (group.roomId.isEmpty) {
      throw AsClientException('AS create group response is missing room_id');
    }
    return group;
  }

  @override
  Future<AsGroupResult> inviteGroupMembers({
    required String roomId,
    required List<String> invite,
  }) async {
    final body = await _requestJson(
      'POST',
      'groups/${Uri.encodeComponent(roomId)}/invite',
      body: {
        'invite': invite.map((mxid) => mxid.trim()).where((mxid) {
          return mxid.isNotEmpty;
        }).toList(growable: false),
      },
      allowedStatusCodes: const {200},
    );
    final group = AsGroupResult.fromJson(body);
    if (group.roomId.isEmpty) {
      throw AsClientException('AS invite group response is missing room_id');
    }
    return group;
  }

  @override
  Future<AsGroupResult> updateGroupInvitePolicy({
    required String roomId,
    required String invitePolicy,
  }) async {
    final body = await _requestJson(
      'PUT',
      'groups/${Uri.encodeComponent(roomId)}/invite-policy',
      body: {'invite_policy': invitePolicy.trim()},
      allowedStatusCodes: const {200},
    );
    final group = AsGroupResult.fromJson(body);
    if (group.roomId.isEmpty) {
      throw AsClientException(
        'AS update group invite policy response is missing room_id',
      );
    }
    return group;
  }

  @override
  Future<AsGroupResult> joinGroup({
    required String roomId,
    String groupName = '',
    String inviterMxid = '',
    String inviteEventId = '',
    String directRoomId = '',
  }) async {
    final body = await _requestJson(
      'POST',
      'groups/${Uri.encodeComponent(roomId)}/join',
      body: {
        if (groupName.trim().isNotEmpty) 'group_name': groupName.trim(),
        if (inviterMxid.trim().isNotEmpty) 'inviter_mxid': inviterMxid.trim(),
        if (inviteEventId.trim().isNotEmpty)
          'invite_event_id': inviteEventId.trim(),
        if (directRoomId.trim().isNotEmpty)
          'direct_room_id': directRoomId.trim(),
      },
      allowedStatusCodes: const {200},
    );
    final group = AsGroupResult.fromJson(body);
    if (group.roomId.isEmpty) {
      throw AsClientException('AS join group response is missing room_id');
    }
    return group;
  }

  @override
  Future<void> leaveGroup(String roomId) async {
    await _requestJson(
      'POST',
      'groups/${Uri.encodeComponent(roomId)}/leave',
      allowedStatusCodes: const {200},
    );
  }

  @override
  Future<void> updateReadMarker(
    String roomId,
    String eventId,
    DateTime timestamp,
  ) async {
    await _requestJson(
      'PUT',
      'sync/read-marker',
      body: {
        'room_id': roomId,
        'event_id': eventId,
        'origin_server_ts': timestamp.toUtc().millisecondsSinceEpoch,
      },
      allowedStatusCodes: const {200},
    );
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
    this.agentRoomId,
    this.portalToken,
  });

  final String accessToken;
  final String userId;
  final String homeserver;
  final String? deviceId;
  final String? agentRoomId;
  final String? portalToken;

  factory AsPortalSession.fromJson(Map<String, dynamic> json) {
    return AsPortalSession(
      accessToken: json['access_token'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      homeserver: json['homeserver'] as String? ?? '',
      deviceId: json['device_id'] as String?,
      agentRoomId: json['agent_room_id'] as String?,
      portalToken: json['portal_token'] as String?,
    );
  }
}

List<String> _normalizedStringList(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || seen.contains(trimmed)) continue;
    seen.add(trimmed);
    result.add(trimmed);
  }
  return result;
}

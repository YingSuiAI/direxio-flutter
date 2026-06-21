import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

import 'api_logger.dart';
import 'as_client.dart';
import 'local_endpoint_resolver.dart';

/// HTTP implementation for the p2p-matrix-as Admin API.
///
/// Production deployments expose the integrated P2P product API under
/// `https://{domain}/_p2p/*`.
class HttpAsClient implements AsClient {
  HttpAsClient({
    required Uri baseUri,
    String? portalToken,
    String? accessToken,
    String authSource = 'portal_token',
    String? accessTokenForDebug,
    FutureOr<String?> Function()? onAuthenticationRefresh,
    FutureOr<void> Function()? onAuthenticationFailed,
    http.Client? httpClient,
  })  : _baseUri = _normalizeBaseUri(baseUri),
        _portalToken = _requireToken(portalToken ?? accessToken),
        _authSource = authSource,
        _accessTokenForDebug = accessTokenForDebug,
        _onAuthenticationRefresh = onAuthenticationRefresh,
        _onAuthenticationFailed = onAuthenticationFailed,
        _http = httpClient ?? http.Client();

  factory HttpAsClient.fromPortalSession(
    Client client, {
    required String portalToken,
    Uri? baseUri,
    FutureOr<String?> Function()? onAuthenticationRefresh,
    FutureOr<void> Function()? onAuthenticationFailed,
  }) {
    final homeserver = client.homeserver;
    if (homeserver == null) {
      throw AsClientException('Matrix session is not initialized');
    }
    return HttpAsClient(
      baseUri: baseUri ?? defaultAdminBaseUri(homeserver),
      portalToken: portalToken,
      authSource: 'portal_token',
      accessTokenForDebug: client.accessToken,
      onAuthenticationRefresh: onAuthenticationRefresh,
      onAuthenticationFailed: onAuthenticationFailed,
      httpClient: client.httpClient,
    );
  }

  /// Backward-compatible constructor for sessions created before AS v2 auth.
  /// New p2p-matrix-as deployments expect [fromPortalSession] instead.
  factory HttpAsClient.fromMatrixClient(
    Client client, {
    Uri? baseUri,
    FutureOr<String?> Function()? onAuthenticationRefresh,
    FutureOr<void> Function()? onAuthenticationFailed,
  }) {
    final token = client.accessToken;
    final homeserver = client.homeserver;
    if (token == null || token.isEmpty || homeserver == null) {
      throw AsClientException('Matrix session is not initialized');
    }
    return HttpAsClient(
      baseUri: baseUri ?? defaultAdminBaseUri(homeserver),
      accessToken: token,
      authSource: 'access_token',
      accessTokenForDebug: token,
      onAuthenticationRefresh: onAuthenticationRefresh,
      onAuthenticationFailed: onAuthenticationFailed,
      httpClient: client.httpClient,
    );
  }

  final Uri _baseUri;
  String _portalToken;
  final String? _authSource;
  final String? _accessTokenForDebug;
  final FutureOr<String?> Function()? _onAuthenticationRefresh;
  final FutureOr<void> Function()? _onAuthenticationFailed;
  final http.Client _http;

  static const _timeout = Duration(seconds: 10);

  static Uri defaultAdminBaseUri(
    Uri homeserver, {
    LocalEndpointResolver? localEndpointResolver,
  }) {
    final localEndpointUri =
        (localEndpointResolver ?? LocalEndpointResolver.environment)
            .httpUriForUri(homeserver, path: '/_p2p');
    if (localEndpointUri != null) return localEndpointUri;
    final host = homeserver.host;
    return Uri(
      scheme: homeserver.scheme.isEmpty ? 'https' : homeserver.scheme,
      host: host,
      port: homeserver.hasPort ? homeserver.port : null,
      path: '/_p2p',
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
    String avatarUrl = '',
    String gender = '',
    String birthday = '',
    String phone = '',
    String email = '',
  }) async {
    final body = await _requestJson(
      'PUT',
      'profile',
      body: {
        'display_name': displayName.trim(),
        'avatar_url': avatarUrl.trim(),
        'gender': gender.trim(),
        'birthday': birthday.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
      },
      allowedStatusCodes: const {200},
    );
    return OwnerProfile.fromJson(body);
  }

  static Future<AsPortalSession> authenticatePortal({
    required Uri baseUri,
    required String portalToken,
    String? deviceId,
    http.Client? httpClient,
  }) async {
    final ownsClient = httpClient == null;
    final client = httpClient ?? http.Client();
    final normalizedBase = _normalizeBaseUri(baseUri);
    try {
      return _postPortalAuth(
        client,
        normalizedBase,
        'auth',
        body: {
          'password': portalToken,
          if (deviceId != null && deviceId.trim().isNotEmpty)
            'device_id': deviceId.trim(),
        },
      );
    } finally {
      if (ownsClient) client.close();
    }
  }

  static Future<AsPortalSession> bootstrapPortal({
    required Uri baseUri,
    required String setupCode,
    String? deviceId,
    http.Client? httpClient,
  }) async {
    final ownsClient = httpClient == null;
    final client = httpClient ?? http.Client();
    final normalizedBase = _normalizeBaseUri(baseUri);
    try {
      return _postPortalAuth(
        client,
        normalizedBase,
        'bootstrap',
        body: {
          'token': setupCode,
          if (deviceId != null && deviceId.trim().isNotEmpty)
            'device_id': deviceId.trim(),
        },
      );
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
  Future<List<AsConversation>> listConversations() async {
    final body = await _getJson('conversations');
    return _parseConversations(
      body['conversations'] ?? body['results'] ?? body,
    );
  }

  @override
  Stream<AsEventStreamEvent> streamEvents({
    int? since,
    String? lastEventId,
  }) async* {
    if (!_isUnifiedBase(_baseUri)) {
      throw AsClientException('SSE event stream requires a /_p2p base URI');
    }
    final queryParameters = <String, String>{
      if (since != null && since > 0) 'since': since.toString(),
    };
    final uri = _resolve(
      'events',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final request = http.Request('GET', uri);
    request.headers['Authorization'] = 'Bearer $_portalToken';
    request.headers['Accept'] = 'text/event-stream';
    final replayId = lastEventId?.trim() ?? '';
    if (replayId.isNotEmpty) {
      request.headers['Last-Event-ID'] = replayId;
    }

    final stopwatch = Stopwatch()..start();
    late http.StreamedResponse streamed;
    try {
      streamed = await _http.send(request).timeout(_timeout);
    } catch (error, stackTrace) {
      stopwatch.stop();
      ApiLogger.failure(
        service: 'AS events',
        method: 'GET',
        uri: uri,
        elapsed: stopwatch.elapsed,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
    stopwatch.stop();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final response = await http.Response.fromStream(streamed);
      ApiLogger.response(
        service: 'AS events',
        method: 'GET',
        uri: uri,
        statusCode: response.statusCode,
        elapsed: stopwatch.elapsed,
        responseBody: response.body,
      );
      if (_isAuthenticationFailureResponse(response)) {
        await _onAuthenticationFailed?.call();
      }
      throw AsClientException(
        _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
    ApiLogger.response(
      service: 'AS events',
      method: 'GET',
      uri: uri,
      statusCode: streamed.statusCode,
      elapsed: stopwatch.elapsed,
    );
    yield* _decodeSseEvents(
      streamed.stream.transform(utf8.decoder).transform(const LineSplitter()),
    );
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

  Future<Map<String, dynamic>> getAgentPassword() {
    return _getJson('agents/get-password');
  }

  Future<Map<String, dynamic>> listApiPermissions() {
    return _getJson('apis');
  }

  Future<Map<String, dynamic>> updateApiPermissionStatus(
    List<Map<String, Object?>> items,
  ) {
    return _requestJson(
      'PUT',
      'apis/status',
      body: {'items': items},
      allowedStatusCodes: const {200},
    );
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
  Future<Map<String, dynamic>> submitReport({
    required String reporterDomain,
    required String reportedDomain,
    required String reason,
    int targetType = 1,
    List<String> images = const [],
  }) {
    return _requestJson(
      'POST',
      'reports',
      body: {
        'reporter_domain': reporterDomain.trim(),
        'reported_domain': reportedDomain.trim(),
        'target_type': targetType,
        'reason': reason.trim(),
        if (images.isNotEmpty)
          'images': images.map((image) => image.trim()).toList(growable: false),
      },
    );
  }

  @override
  Future<ContactEntry> createContactRequest({
    required String mxid,
    String displayName = '',
    String domain = '',
  }) async {
    final requestBody = {
      'mxid': mxid.trim(),
      if (displayName.trim().isNotEmpty) 'display_name': displayName.trim(),
      if (domain.trim().isNotEmpty) 'domain': domain.trim(),
    };
    ApiLogger.info(
      '[AS admin] friend request params '
      'auth_source=$_authSourceLabel '
      'params=${jsonEncode(requestBody)}',
    );
    try {
      final body = await _requestJson(
        'POST',
        'contacts/requests',
        body: requestBody,
        allowedStatusCodes: const {200},
      );
      final contact = ContactEntry.fromJson(body);
      ApiLogger.info(
        '[AS admin] friend request result '
        'status=ok '
        'result=${jsonEncode(_contactEntryLogJson(contact))}',
      );
      return contact;
    } catch (error) {
      ApiLogger.info(
        '[AS admin] friend request result '
        'status=error '
        'params=${jsonEncode(requestBody)} '
        'error=$error',
      );
      rethrow;
    }
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
  Future<ContactEntry> updateContact({
    required String roomId,
    required String displayName,
    String domain = '',
  }) async {
    final body = await _requestJson(
      'PUT',
      'contacts/${Uri.encodeComponent(roomId)}',
      body: {
        'display_name': displayName.trim(),
        if (domain.trim().isNotEmpty) 'domain': domain.trim(),
      },
      allowedStatusCodes: const {200},
    );
    return ContactEntry.fromJson(body);
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
  Future<AsPortalSession> changePortalPassword({
    required String oldPassword,
    required String newPassword,
    String? deviceId,
  }) async {
    final requestBody = {
      'old_password': oldPassword.trim(),
      'new_password': newPassword.trim(),
      if (deviceId != null && deviceId.trim().isNotEmpty)
        'device_id': deviceId.trim(),
    };
    ApiLogger.info(
      '[AS admin] portal password params '
      'auth_source=$_authSourceLabel '
      'authorization_present=${_portalToken.trim().isNotEmpty} '
      'bearer=true '
      'access_token_length=${_portalToken.trim().length} '
      'old_password_length=${oldPassword.trim().length} '
      'new_password_length=${newPassword.trim().length} '
      'params=${jsonEncode(_passwordChangeLogJson(requestBody))}',
    );
    final Map<String, dynamic> response;
    try {
      response = await _requestJson(
        'PUT',
        'portal/password',
        body: requestBody,
        allowedStatusCodes: const {200},
      );
    } catch (error) {
      ApiLogger.info(
        '[AS admin] portal password result '
        'status=error '
        'params=${jsonEncode(_passwordChangeLogJson(requestBody))} '
        'error=$error',
      );
      rethrow;
    }
    final session = AsPortalSession.fromJson(response);
    if (session.accessToken.isEmpty) {
      throw AsClientException(
        'AS password response is missing access_token',
      );
    }
    ApiLogger.info(
      '[AS admin] portal password result '
      'status=ok '
      'result=${jsonEncode(_portalSessionLogJson(session))}',
    );
    return session;
  }

  @override
  Future<AsChannel> createChannel({
    required String name,
    String topic = '',
    String description = '',
    String avatarUrl = '',
    String visibility = asChannelVisibilityPublic,
    String joinPolicy = asChannelJoinPolicyOpen,
    String channelType = 'chat',
    bool commentsEnabled = true,
    List<String> tags = const [],
  }) async {
    final trimmedName = name.trim();
    final trimmedDescription =
        description.trim().isNotEmpty ? description.trim() : topic.trim();
    final requestBody = {
      'name': trimmedName,
      if (trimmedDescription.isNotEmpty) 'description': trimmedDescription,
      if (avatarUrl.trim().isNotEmpty) 'avatar_url': avatarUrl.trim(),
      'visibility': visibility.trim().isEmpty
          ? asChannelVisibilityPublic
          : visibility.trim(),
      'join_policy': joinPolicy.trim().isEmpty
          ? asChannelJoinPolicyOpen
          : joinPolicy.trim(),
      'channel_type': _normalizedChannelType(channelType),
      'comments_enabled': commentsEnabled,
      'tags': tags.map((tag) => tag.trim()).where((tag) {
        return tag.isNotEmpty;
      }).toList(growable: false),
    };
    ApiLogger.info(
      '[AS admin] create channel request ${jsonEncode(requestBody)}',
    );
    final body = await _requestJson(
      'POST',
      'channels',
      body: requestBody,
      allowedStatusCodes: const {200},
    );
    final channel = AsChannel.fromJson(body);
    if (channel.roomId.isEmpty) {
      throw AsClientException('AS create channel response is missing room_id');
    }
    return channel;
  }

  @override
  Future<List<AsChannel>> listChannels() async {
    final body = await _getJson('channels');
    return _parseChannels(body['channels'] ?? body['results'] ?? body);
  }

  @override
  Future<List<AsChannel>> searchPublicChannels(
    String query, {
    Uri? baseUri,
    int limit = 20,
  }) async {
    final body = await _getPublicJson(
      'public/channels/search',
      baseUri: baseUri,
      queryParameters: {
        'q': query.trim(),
        'limit': limit.toString(),
      },
    );
    return _parseChannels(body['results'] ?? body['channels']);
  }

  @override
  Future<AsChannel> getPublicChannel(String channelId, {Uri? baseUri}) async {
    final body = await _getPublicJson(
      'public/channels/${Uri.encodeComponent(channelId)}',
      baseUri: baseUri,
    );
    return AsChannel.fromJson(body);
  }

  @override
  Future<AsChannel> getPublicChannelByRoomId(
    String roomId, {
    Uri? baseUri,
    Uri? remoteNodeBaseUri,
  }) async {
    final body = await _getPublicJson(
      'public/channels/${_encodeStrictPathComponent(roomId.trim())}',
      baseUri: baseUri,
      extraParams: _remoteNodeParams(remoteNodeBaseUri),
    );
    return AsChannel.fromJson(body);
  }

  @override
  Future<List<AsChannel>> getUserPublicChannels(
    String userId, {
    Uri? baseUri,
  }) async {
    final body = await _getPublicJson(
      'users/${_encodeStrictPathComponent(userId.trim())}/public-channels',
      baseUri: baseUri,
    );
    return _parseChannels(body['channels'] ?? body['results'] ?? body);
  }

  @override
  Future<AsChannel> updateChannel(AsChannel draft) async {
    final body = await _requestJson(
      'PUT',
      'channels/${Uri.encodeComponent(draft.channelId)}',
      body: {
        'name': draft.name.trim(),
        'description': draft.description.trim(),
        if (draft.avatarUrl.trim().isNotEmpty)
          'avatar_url': draft.avatarUrl.trim(),
        'visibility': draft.visibility,
        'join_policy': draft.joinPolicy,
        'comments_enabled': draft.commentsEnabled,
        'tags': draft.tags,
      },
      allowedStatusCodes: const {200},
    );
    return AsChannel.fromJson(body);
  }

  @override
  Future<AsChannel> joinChannelByRoomId(
    String roomId, {
    String shareToken = '',
    String grantId = '',
    String shareRoomId = '',
    AsChannel? discoveredChannel,
    Uri? remoteNodeBaseUri,
  }) async {
    final trimmedRoomId = roomId.trim();
    final requestBody = <String, Object?>{
      if (shareToken.trim().isNotEmpty) 'share_token': shareToken.trim(),
      if (grantId.trim().isNotEmpty) 'grant_id': grantId.trim(),
      if (shareRoomId.trim().isNotEmpty) 'share_room_id': shareRoomId.trim(),
      ..._remoteNodeParams(remoteNodeBaseUri),
      ..._discoveredChannelJoinBody(discoveredChannel),
    };
    final body = await _requestJson(
      'POST',
      'public/channels/${_encodeStrictPathComponent(trimmedRoomId)}/join-requests',
      body: requestBody.isEmpty ? null : requestBody,
      allowedStatusCodes: const {200},
    );
    return _parseChannelEnvelope(body, statusBelongsToCurrentUser: true);
  }

  @override
  Future<AsChannel> joinChannel(
    String channelId, {
    String roomId = '',
    String shareToken = '',
    String grantId = '',
    String shareRoomId = '',
    AsChannel? discoveredChannel,
  }) async {
    final requestBody = <String, Object?>{
      if (roomId.trim().isNotEmpty) 'room_id': roomId.trim(),
      if (shareToken.trim().isNotEmpty) 'share_token': shareToken.trim(),
      if (grantId.trim().isNotEmpty) 'grant_id': grantId.trim(),
      if (shareRoomId.trim().isNotEmpty) 'share_room_id': shareRoomId.trim(),
      ..._discoveredChannelJoinBody(discoveredChannel),
    };
    final body = await _requestJson(
      'POST',
      'channels/${Uri.encodeComponent(channelId)}/join',
      body: requestBody.isEmpty ? null : requestBody,
      allowedStatusCodes: const {200},
    );
    return _parseChannelEnvelope(body, statusBelongsToCurrentUser: true);
  }

  @override
  Future<void> leaveChannel(String channelId) async {
    await _requestJson(
      'POST',
      'channels/${Uri.encodeComponent(channelId.trim())}/leave',
      allowedStatusCodes: const {200},
    );
  }

  @override
  Future<void> dissolveChannel(String channelId) async {
    await _requestJson(
      'POST',
      'channels/${Uri.encodeComponent(channelId.trim())}/dissolve',
      allowedStatusCodes: const {200},
    );
  }

  static Map<String, Object?> _discoveredChannelJoinBody(
    AsChannel? channel,
  ) {
    if (channel == null) return const {};
    return {
      if (channel.roomId.trim().isNotEmpty) 'room_id': channel.roomId.trim(),
      if (channel.homeDomain.trim().isNotEmpty)
        'home_domain': channel.homeDomain.trim(),
      if (channel.name.trim().isNotEmpty) 'name': channel.name.trim(),
      if (channel.description.trim().isNotEmpty)
        'description': channel.description.trim(),
      if (channel.avatarUrl.trim().isNotEmpty)
        'avatar_url': channel.avatarUrl.trim(),
      'visibility': channel.visibility,
      'join_policy': channel.joinPolicy,
      'comments_enabled': channel.commentsEnabled,
      'tags': channel.tags,
    };
  }

  @override
  Future<List<AsChannelMember>> getChannelMembers(
    String channelId, {
    String status = '',
  }) async {
    final body = await _getJson(
      'channels/${Uri.encodeComponent(channelId)}/members',
      queryParameters: {
        if (status.trim().isNotEmpty) 'status': status.trim(),
      },
    );
    final raw = body['members'] as List? ?? const [];
    return raw
        .whereType<Map>()
        .map((item) => AsChannelMember.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  @override
  Future<void> inviteChannelMembers({
    required String channelId,
    required List<String> invite,
  }) async {
    await _requestJson(
      'POST',
      'channels/${Uri.encodeComponent(channelId.trim())}/invite',
      body: {
        'invite': invite
            .map((mxid) => mxid.trim())
            .where((mxid) => mxid.isNotEmpty)
            .toList(growable: false),
      },
      allowedStatusCodes: const {200},
    );
  }

  @override
  Future<AsChannelInviteGrant> createChannelInviteGrant({
    String channelId = '',
    String roomId = '',
    required String shareRoomId,
    String grantId = '',
    String reason = '',
  }) async {
    final trimmedChannelId = channelId.trim();
    final trimmedRoomId = roomId.trim();
    final trimmedShareRoomId = shareRoomId.trim();
    if (trimmedChannelId.isEmpty && trimmedRoomId.isEmpty) {
      throw ArgumentError('channelId or roomId is required');
    }
    if (trimmedShareRoomId.isEmpty) {
      throw ArgumentError.value(shareRoomId, 'shareRoomId', 'is required');
    }
    final body = await _requestJson(
      'POST',
      'channels/invite-grants',
      body: {
        if (trimmedChannelId.isNotEmpty) 'channel_id': trimmedChannelId,
        if (trimmedRoomId.isNotEmpty) 'room_id': trimmedRoomId,
        'share_room_id': trimmedShareRoomId,
        if (grantId.trim().isNotEmpty) 'grant_id': grantId.trim(),
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      allowedStatusCodes: const {200},
    );
    return AsChannelInviteGrant.fromJson(body);
  }

  @override
  Future<AsChannel> approveChannelJoin(
    String channelId,
    String userMxid,
  ) {
    return _resolveChannelJoinRequest(channelId, userMxid, 'approve');
  }

  @override
  Future<AsChannel> rejectChannelJoin(
    String channelId,
    String userMxid,
  ) {
    return _resolveChannelJoinRequest(channelId, userMxid, 'reject');
  }

  @override
  Future<void> removeChannelMember(String channelId, String userMxid) async {
    await _requestJson(
      'POST',
      'channels/${Uri.encodeComponent(channelId)}/members/'
          '${Uri.encodeComponent(userMxid.trim())}/remove',
      allowedStatusCodes: const {200},
    );
  }

  @override
  Future<void> muteChannel(String channelId) {
    return _postEmpty(
      'channels/${Uri.encodeComponent(channelId.trim())}/mute',
    );
  }

  @override
  Future<void> unmuteChannel(String channelId) {
    return _postEmpty(
      'channels/${Uri.encodeComponent(channelId.trim())}/unmute',
    );
  }

  @override
  Future<void> muteChannelMember(String channelId, String userId) {
    return _postEmpty(
      'channels/${Uri.encodeComponent(channelId.trim())}/members/'
      '${Uri.encodeComponent(userId.trim())}/mute',
    );
  }

  @override
  Future<void> unmuteChannelMember(String channelId, String userId) {
    return _postEmpty(
      'channels/${Uri.encodeComponent(channelId.trim())}/members/'
      '${Uri.encodeComponent(userId.trim())}/unmute',
    );
  }

  Future<AsChannel> _resolveChannelJoinRequest(
    String channelId,
    String userMxid,
    String action,
  ) async {
    final body = await _requestJson(
      'POST',
      'channels/${Uri.encodeComponent(channelId)}/join-requests/${Uri.encodeComponent(userMxid)}/$action',
      allowedStatusCodes: const {200},
    );
    return AsChannel.fromJson(
      (body['channel'] as Map?)?.cast<String, dynamic>() ?? body,
    );
  }

  @override
  Future<List<AsChannelPost>> getChannelPosts(
    String channelId, {
    int limit = 50,
    int beforeTs = 0,
  }) async {
    final body = await _getJson(
      'channels/${Uri.encodeComponent(channelId)}/posts',
      queryParameters: {
        'limit': limit.toString(),
        if (beforeTs > 0) 'before_ts': beforeTs.toString(),
      },
    );
    final raw = body['posts'] as List? ?? const [];
    return raw
        .whereType<Map>()
        .map((item) => AsChannelPost.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  @override
  Future<AsChannelPost> createChannelPost(
    String channelId, {
    required String messageType,
    required String body,
    Map<String, Object?> media = const {},
  }) async {
    final response = await _requestJson(
      'POST',
      'channels/${Uri.encodeComponent(channelId)}/posts',
      body: {
        'message_type':
            messageType.trim().isEmpty ? 'text' : messageType.trim(),
        'body': body.trim(),
        if (media.isNotEmpty) 'media_json': jsonEncode(media),
      },
      allowedStatusCodes: const {200},
    );
    return AsChannelPost.fromJson(response);
  }

  @override
  Future<void> recallChannelPost(
    String channelId,
    String postId, {
    String reason = 'recall post',
  }) async {
    await _requestJson(
      'POST',
      'channels/${Uri.encodeComponent(channelId)}/posts/'
          '${Uri.encodeComponent(postId)}/recall',
      body: {'reason': reason.trim().isEmpty ? 'recall post' : reason.trim()},
      allowedStatusCodes: const {200},
    );
  }

  @override
  Future<List<AsChannelComment>> getChannelComments(
    String channelId,
    String postId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _getJson(
      'channels/${Uri.encodeComponent(channelId)}/posts/${Uri.encodeComponent(postId)}/comments',
      queryParameters: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
      },
    );
    final raw = response['comments'] as List? ?? const [];
    return raw
        .whereType<Map>()
        .map((item) => AsChannelComment.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  @override
  Future<AsChannelComment> createChannelComment(
    String channelId,
    String postId, {
    required String messageType,
    required String body,
    Map<String, Object?> media = const {},
    String replyToCommentId = '',
    String replyToAuthorId = '',
    List<Map<String, Object?>> mentions = const [],
  }) async {
    final normalizedMentions = _normalizedMentionPayload(mentions);
    final replyTo = replyToCommentId.trim();
    final replyAuthor = replyToAuthorId.trim();
    final response = await _requestJson(
      'POST',
      'channels/${Uri.encodeComponent(channelId)}/posts/${Uri.encodeComponent(postId)}/comments',
      body: {
        'message_type':
            messageType.trim().isEmpty ? 'text' : messageType.trim(),
        'body': body.trim(),
        if (media.isNotEmpty) 'media_json': jsonEncode(media),
        if (replyTo.isNotEmpty) 'reply_to_comment_id': replyTo,
        if (replyAuthor.isNotEmpty) 'reply_to_author_mxid': replyAuthor,
        if (normalizedMentions.isNotEmpty) 'mentions': normalizedMentions,
      },
      allowedStatusCodes: const {200},
    );
    return AsChannelComment.fromJson(response);
  }

  @override
  Future<List<AsChannelCommentHistory>> getMyChannelComments({
    int limit = 50,
  }) async {
    final response = await _getJson(
      'channels/me/comments',
      queryParameters: {'limit': limit.toString()},
    );
    final raw = response['comments'] as List? ?? const [];
    return raw
        .whereType<Map>()
        .map(
          (item) =>
              AsChannelCommentHistory.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  @override
  Future<List<AsChannelReactionHistory>> getMyChannelReactions({
    int limit = 50,
  }) async {
    final response = await _getJson(
      'channels/me/reactions',
      queryParameters: {'limit': limit.toString()},
    );
    final raw = response['reactions'] as List? ?? const [];
    return raw
        .whereType<Map>()
        .map(
          (item) =>
              AsChannelReactionHistory.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  @override
  Future<AsChannelReaction> toggleChannelPostReaction(
    String channelId,
    String postId, {
    String reaction = 'like',
  }) async {
    final response = await _requestJson(
      'POST',
      'channels/${Uri.encodeComponent(channelId)}/posts/${Uri.encodeComponent(postId)}/reactions',
      body: {'reaction': reaction.trim().isEmpty ? 'like' : reaction.trim()},
      allowedStatusCodes: const {200},
    );
    return AsChannelReaction.fromJson(response);
  }

  @override
  Future<AsChannelReaction> toggleChannelCommentReaction(
    String channelId,
    String postId,
    String commentId, {
    String reaction = 'like',
  }) async {
    final response = await _requestJson(
      'POST',
      'channels/${Uri.encodeComponent(channelId)}/posts/'
          '${Uri.encodeComponent(postId)}/comments/'
          '${Uri.encodeComponent(commentId)}/reactions',
      body: {'reaction': reaction.trim().isEmpty ? 'like' : reaction.trim()},
      allowedStatusCodes: const {200},
    );
    return AsChannelReaction.fromJson(response);
  }

  @override
  Future<void> updateChannelReadMarker(
    String channelId, {
    required String eventId,
    required int originServerTs,
  }) async {
    await _requestJson(
      'PUT',
      'channels/${Uri.encodeComponent(channelId)}/read-marker',
      body: {
        'event_id': eventId,
        'origin_server_ts': originServerTs,
      },
      allowedStatusCodes: const {200},
    );
  }

  @override
  Future<AsGroupResult> createGroup({
    required String name,
    required List<String> invite,
    String avatarUrl = '',
  }) async {
    final body = await _requestJson(
      'POST',
      'groups',
      body: {
        'name': name.trim(),
        if (avatarUrl.trim().isNotEmpty) 'avatar_url': avatarUrl.trim(),
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
  Future<AsGroupResult> updateGroupProfile({
    required String roomId,
    String name = '',
    String topic = '',
    String avatarUrl = '',
  }) async {
    final trimmedRoomId = roomId.trim();
    final body = <String, Object?>{
      if (name.trim().isNotEmpty) 'name': name.trim(),
      if (topic.trim().isNotEmpty) 'topic': topic.trim(),
      if (avatarUrl.trim().isNotEmpty) 'avatar_url': avatarUrl.trim(),
    };
    if (body.isEmpty) {
      throw ArgumentError('At least one group profile field is required');
    }
    final response = await _requestJson(
      'PUT',
      'groups/${Uri.encodeComponent(trimmedRoomId)}',
      body: body,
      allowedStatusCodes: const {200},
    );
    final group = AsGroupResult.fromJson(response);
    if (group.roomId.isEmpty) {
      throw AsClientException('AS update group response is missing room_id');
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
      final fallbackRoomId = roomId.trim();
      final rawMembers = body['members'] as List? ?? const [];
      final status = body['status'] as String? ?? group.status;
      if (fallbackRoomId.isEmpty || rawMembers.isEmpty) {
        throw AsClientException('AS invite group response is missing room_id');
      }
      return AsGroupResult(
        roomId: fallbackRoomId,
        name: group.name,
        memberCount: group.memberCount,
        invitedCount: rawMembers.whereType<Map>().length,
        role: group.role,
        status: status,
        invitePolicy: group.invitePolicy,
      );
    }
    return group;
  }

  @override
  Future<void> removeGroupMember({
    required String roomId,
    required String peerMxid,
  }) async {
    await _requestJson(
      'POST',
      'groups/${Uri.encodeComponent(roomId.trim())}/members/'
          '${Uri.encodeComponent(peerMxid.trim())}/remove',
      allowedStatusCodes: const {200, 204},
    );
  }

  @override
  Future<void> muteGroup(String roomId) {
    return _postEmpty(
      'groups/${Uri.encodeComponent(roomId.trim())}/mute',
    );
  }

  @override
  Future<void> unmuteGroup(String roomId) {
    return _postEmpty(
      'groups/${Uri.encodeComponent(roomId.trim())}/unmute',
    );
  }

  @override
  Future<void> muteGroupMember({
    required String roomId,
    required String userId,
  }) {
    return _postEmpty(
      'groups/${Uri.encodeComponent(roomId.trim())}/members/'
      '${Uri.encodeComponent(userId.trim())}/mute',
    );
  }

  @override
  Future<void> unmuteGroupMember({
    required String roomId,
    required String userId,
  }) {
    return _postEmpty(
      'groups/${Uri.encodeComponent(roomId.trim())}/members/'
      '${Uri.encodeComponent(userId.trim())}/unmute',
    );
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
      'groups/${Uri.encodeComponent(roomId.trim())}/leave',
      allowedStatusCodes: const {200},
    );
  }

  @override
  Future<void> dissolveGroup(String roomId) async {
    await _requestJson(
      'POST',
      'groups/${Uri.encodeComponent(roomId.trim())}/dissolve',
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

  Future<void> _postEmpty(String path) async {
    await _requestJson(
      'POST',
      path,
      allowedStatusCodes: const {200},
    );
  }

  Future<Map<String, dynamic>> _getPublicJson(
    String path, {
    Uri? baseUri,
    Map<String, String>? queryParameters,
    Map<String, Object?>? extraParams,
  }) async {
    final normalizedBase = _normalizeBaseUri(baseUri ?? _baseUri);
    final unified = _isUnifiedBase(normalizedBase);
    final publicQueryParameters = unified
        ? queryParameters
        : _mergeQueryParameters(queryParameters, extraParams);
    final uri = unified
        ? _resolveAgainst(normalizedBase, 'query')
        : _resolveAgainst(
            normalizedBase,
            path,
            queryParameters: publicQueryParameters,
          );
    final unifiedParams = _actionParams(path, queryParameters: queryParameters)
      ..addAll(extraParams ?? const <String, Object?>{});
    final requestBody = unified
        ? jsonEncode({
            'action': _actionFor('GET', path),
            'params': unifiedParams,
          })
        : null;
    final stopwatch = Stopwatch()..start();
    late http.Response response;
    try {
      response = unified
          ? await _http
              .post(
                uri,
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json; charset=utf-8',
                },
                body: requestBody,
              )
              .timeout(_timeout)
          : await _http.get(uri,
              headers: const {'Accept': 'application/json'}).timeout(_timeout);
    } catch (error, stackTrace) {
      stopwatch.stop();
      ApiLogger.failure(
        service: 'AS public',
        method: unified ? 'POST' : 'GET',
        uri: uri,
        elapsed: stopwatch.elapsed,
        error: error,
        stackTrace: stackTrace,
        requestBody: requestBody,
      );
      rethrow;
    }
    stopwatch.stop();
    ApiLogger.response(
      service: 'AS public',
      method: unified ? 'POST' : 'GET',
      uri: uri,
      statusCode: response.statusCode,
      elapsed: stopwatch.elapsed,
      requestBody: requestBody,
      responseBody: response.body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AsClientException(
        _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
    if (response.body.trim().isEmpty) return const {};
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (error, stackTrace) {
      ApiLogger.failure(
        service: 'AS public',
        method: 'GET',
        uri: uri,
        elapsed: stopwatch.elapsed,
        statusCode: response.statusCode,
        responseBody: response.body,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
    if (decoded is! Map<String, dynamic>) {
      final error = AsClientException(
        'AS returned a non-object JSON response',
        statusCode: response.statusCode,
      );
      ApiLogger.failure(
        service: 'AS public',
        method: 'GET',
        uri: uri,
        elapsed: stopwatch.elapsed,
        statusCode: response.statusCode,
        responseBody: response.body,
        error: error,
      );
      throw error;
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    Set<int> allowedStatusCodes = const {200},
  }) async {
    if (!_isUnifiedBase(_baseUri)) {
      return _legacyRequestJson(
        method,
        path,
        queryParameters: queryParameters,
        body: body,
        allowedStatusCodes: allowedStatusCodes,
      );
    }
    final action = _actionFor(method, path);
    final params =
        _actionParams(path, queryParameters: queryParameters, body: body);
    final endpoint = method == 'GET' ? 'query' : 'command';
    final uri = _resolve(endpoint);
    late http.Response response;
    String? requestBody;
    var requestElapsed = Duration.zero;
    for (var attempt = 0;; attempt++) {
      final request = http.Request('POST', uri);
      request.headers['Authorization'] = 'Bearer $_portalToken';
      request.headers['Accept'] = 'application/json';
      request.encoding = utf8;
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode({
        'action': action,
        'params': params,
      });
      if (method == 'POST' && path == 'contacts/requests') {
        final authorization = request.headers['Authorization'] ?? '';
        final accessToken = _accessTokenForDebug?.trim() ?? '';
        ApiLogger.info(
          '[AS admin] friend request auth '
          'authorization_present=${authorization.isNotEmpty} '
          'bearer=${authorization.startsWith('Bearer ')} '
          'auth_source=$_authSourceLabel '
          'portal_token_present=${_portalToken.trim().isNotEmpty} '
          'portal_token_length=${_portalToken.length} '
          'access_token_for_debug_present=${accessToken.isNotEmpty} '
          'access_token_for_debug_length=${accessToken.length} '
          'authorization_matches_access_token_for_debug='
          '${authorization == 'Bearer $accessToken'} '
          'target=${_friendRequestTarget(body)}',
        );
      }
      requestBody = request.body.isEmpty ? null : request.body;

      final stopwatch = Stopwatch()..start();
      try {
        final streamed = await _http.send(request).timeout(_timeout);
        response = await http.Response.fromStream(streamed);
      } catch (error, stackTrace) {
        stopwatch.stop();
        ApiLogger.failure(
          service: 'AS admin',
          method: 'POST',
          uri: uri,
          elapsed: stopwatch.elapsed,
          error: error,
          stackTrace: stackTrace,
          requestBody: requestBody,
        );
        rethrow;
      }
      stopwatch.stop();
      requestElapsed = stopwatch.elapsed;
      ApiLogger.response(
        service: 'AS admin',
        method: 'POST',
        uri: uri,
        statusCode: response.statusCode,
        elapsed: requestElapsed,
        requestBody: requestBody,
        responseBody: response.body,
      );
      if (allowedStatusCodes.contains(response.statusCode)) {
        break;
      }
      if (_isAuthenticationFailureResponse(response)) {
        if (attempt == 0) {
          final refreshedToken =
              (await _onAuthenticationRefresh?.call())?.trim();
          if (refreshedToken != null && refreshedToken.isNotEmpty) {
            _portalToken = refreshedToken;
            continue;
          }
        }
        await _onAuthenticationFailed?.call();
      }
      throw AsClientException(
        _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
    if (response.body.trim().isEmpty) return const {};
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (error, stackTrace) {
      ApiLogger.failure(
        service: 'AS admin',
        method: method,
        uri: uri,
        elapsed: requestElapsed,
        statusCode: response.statusCode,
        requestBody: requestBody,
        responseBody: response.body,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
    if (decoded is! Map<String, dynamic>) {
      final error = AsClientException(
        'AS returned a non-object JSON response',
        statusCode: response.statusCode,
      );
      ApiLogger.failure(
        service: 'AS admin',
        method: method,
        uri: uri,
        elapsed: requestElapsed,
        statusCode: response.statusCode,
        requestBody: requestBody,
        responseBody: response.body,
        error: error,
      );
      throw error;
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _legacyRequestJson(
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
    if (method == 'POST' && path == 'contacts/requests') {
      final authorization = request.headers['Authorization'] ?? '';
      final accessToken = _accessTokenForDebug?.trim() ?? '';
      ApiLogger.info(
        '[AS admin] friend request auth '
        'authorization_present=${authorization.isNotEmpty} '
        'bearer=${authorization.startsWith('Bearer ')} '
        'auth_source=$_authSourceLabel '
        'portal_token_present=${_portalToken.trim().isNotEmpty} '
        'portal_token_length=${_portalToken.length} '
        'access_token_for_debug_present=${accessToken.isNotEmpty} '
        'access_token_for_debug_length=${accessToken.length} '
        'authorization_matches_access_token_for_debug='
        '${authorization == 'Bearer $accessToken'} '
        'target=${_friendRequestTarget(body)}',
      );
    }
    final requestBody = request.body.isEmpty ? null : request.body;

    final stopwatch = Stopwatch()..start();
    late http.Response response;
    try {
      final streamed = await _http.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } catch (error, stackTrace) {
      stopwatch.stop();
      ApiLogger.failure(
        service: 'AS admin',
        method: method,
        uri: uri,
        elapsed: stopwatch.elapsed,
        error: error,
        stackTrace: stackTrace,
        requestBody: requestBody,
      );
      rethrow;
    }
    stopwatch.stop();
    ApiLogger.response(
      service: 'AS admin',
      method: method,
      uri: uri,
      statusCode: response.statusCode,
      elapsed: stopwatch.elapsed,
      requestBody: requestBody,
      responseBody: response.body,
    );
    if (!allowedStatusCodes.contains(response.statusCode)) {
      if (_isAuthenticationFailureResponse(response)) {
        await _onAuthenticationFailed?.call();
      }
      throw AsClientException(
        _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
    if (response.body.trim().isEmpty) return const {};
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (error, stackTrace) {
      ApiLogger.failure(
        service: 'AS admin',
        method: method,
        uri: uri,
        elapsed: stopwatch.elapsed,
        statusCode: response.statusCode,
        requestBody: requestBody,
        responseBody: response.body,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
    if (decoded is! Map<String, dynamic>) {
      final error = AsClientException(
        'AS returned a non-object JSON response',
        statusCode: response.statusCode,
      );
      ApiLogger.failure(
        service: 'AS admin',
        method: method,
        uri: uri,
        elapsed: stopwatch.elapsed,
        statusCode: response.statusCode,
        requestBody: requestBody,
        responseBody: response.body,
        error: error,
      );
      throw error;
    }
    return decoded;
  }

  String get _authSourceLabel {
    final value = _authSource?.trim();
    return value == null || value.isEmpty ? 'unknown' : value;
  }

  Uri _resolve(String path, {Map<String, String>? queryParameters}) {
    return _resolveAgainst(_baseUri, path, queryParameters: queryParameters);
  }

  static Uri _resolveAgainst(
    Uri baseUri,
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final basePath =
        baseUri.path.endsWith('/') ? baseUri.path : '${baseUri.path}/';
    return baseUri.replace(
      path: '$basePath$cleanPath',
      queryParameters: queryParameters,
    );
  }

  static List<AsChannel> _parseChannels(Object? value) {
    final raw = value as List? ?? const [];
    return raw
        .whereType<Map>()
        .map((item) => AsChannel.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  static List<AsConversation> _parseConversations(Object? value) {
    final raw = value as List? ?? const [];
    return raw
        .whereType<Map>()
        .map((item) => AsConversation.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  static AsChannel _parseChannelEnvelope(
    Map<String, dynamic> body, {
    bool statusBelongsToCurrentUser = false,
  }) {
    final channelJson = <String, dynamic>{
      ...((body['channel'] as Map?)?.cast<String, dynamic>() ?? body),
    };
    final conversationJson = body['conversation'];
    if (conversationJson != null) {
      channelJson['conversation'] = conversationJson;
    }
    if (statusBelongsToCurrentUser) {
      final currentStatus = channelJson['member_status'];
      final envelopeStatus = body['status'];
      if ((currentStatus is! String || currentStatus.trim().isEmpty) &&
          envelopeStatus is String &&
          envelopeStatus.trim().isNotEmpty) {
        return AsChannel.fromJson({
          ...channelJson,
          'member_status': envelopeStatus,
        });
      }
    }
    return AsChannel.fromJson(channelJson);
  }

  static Uri _normalizeBaseUri(Uri baseUri) {
    final path =
        baseUri.path.isEmpty || baseUri.path == '/' ? '/_p2p' : baseUri.path;
    return baseUri.replace(
        path: path.endsWith('/') ? path.substring(0, path.length - 1) : path);
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

  static bool _isAuthenticationFailureResponse(http.Response response) {
    if (response.statusCode != 401) return false;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded['error'] == 'M_UNKNOWN_TOKEN';
      }
    } catch (_) {
      // Non-JSON 401 responses are not treated as session expiry.
    }
    return false;
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
    String path, {
    required Map<String, String> body,
  }) async {
    final unified = _isUnifiedBase(baseUri);
    final uri = _resolveStatic(baseUri, unified ? 'command' : path);
    final requestBody = jsonEncode(
      unified
          ? {
              'action':
                  path == 'bootstrap' ? 'portal.bootstrap' : 'portal.auth',
              'params': body,
            }
          : body,
    );
    final stopwatch = Stopwatch()..start();
    late http.Response response;
    try {
      response = await client
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: requestBody,
          )
          .timeout(_timeout);
    } catch (error, stackTrace) {
      stopwatch.stop();
      ApiLogger.failure(
        service: 'AS auth',
        method: 'POST',
        uri: uri,
        elapsed: stopwatch.elapsed,
        error: error,
        stackTrace: stackTrace,
        requestBody: requestBody,
      );
      rethrow;
    }
    stopwatch.stop();
    ApiLogger.response(
      service: 'AS auth',
      method: 'POST',
      uri: uri,
      statusCode: response.statusCode,
      elapsed: stopwatch.elapsed,
      requestBody: requestBody,
      responseBody: response.body,
    );

    if (response.statusCode != 200) {
      throw AsClientException(
        _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (error, stackTrace) {
      ApiLogger.failure(
        service: 'AS auth',
        method: 'POST',
        uri: uri,
        elapsed: stopwatch.elapsed,
        statusCode: response.statusCode,
        requestBody: requestBody,
        responseBody: response.body,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
    if (decoded is! Map<String, dynamic>) {
      final error = AsClientException(
        'AS returned a non-object JSON response',
        statusCode: response.statusCode,
      );
      ApiLogger.failure(
        service: 'AS auth',
        method: 'POST',
        uri: uri,
        elapsed: stopwatch.elapsed,
        statusCode: response.statusCode,
        requestBody: requestBody,
        responseBody: response.body,
        error: error,
      );
      throw error;
    }
    final session = AsPortalSession.fromJson(decoded);
    if (session.accessToken.isEmpty ||
        session.userId.isEmpty ||
        session.homeserver.isEmpty) {
      final error = AsClientException(
        'AS auth response is missing access_token, user_id, or homeserver',
        statusCode: response.statusCode,
      );
      ApiLogger.failure(
        service: 'AS auth',
        method: 'POST',
        uri: uri,
        elapsed: stopwatch.elapsed,
        statusCode: response.statusCode,
        requestBody: requestBody,
        responseBody: response.body,
        error: error,
      );
      throw error;
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

List<Map<String, String>> _normalizedMentionPayload(
  Iterable<Map<String, Object?>> mentions,
) {
  return [
    for (final mention in mentions)
      if ((mention['user_id']?.toString() ?? '').trim().isNotEmpty)
        {
          'user_id': (mention['user_id']?.toString() ?? '').trim(),
          if ((mention['display_name']?.toString() ?? '').trim().isNotEmpty)
            'display_name': (mention['display_name']?.toString() ?? '').trim(),
        },
  ];
}

Map<String, Object?> _remoteNodeParams(Uri? remoteNodeBaseUri) {
  final value = remoteNodeBaseUri?.toString().trim() ?? '';
  if (value.isEmpty) return const {};
  return {'remote_node_base_url': value};
}

Map<String, String>? _mergeQueryParameters(
  Map<String, String>? queryParameters,
  Map<String, Object?>? extraParams,
) {
  if (extraParams == null || extraParams.isEmpty) return queryParameters;
  final merged = <String, String>{
    if (queryParameters != null) ...queryParameters,
  };
  for (final entry in extraParams.entries) {
    final value = entry.value?.toString().trim() ?? '';
    if (value.isNotEmpty) merged[entry.key] = value;
  }
  return merged;
}

String _actionFor(String method, String path) {
  final clean = path.trim().replaceAll(RegExp(r'^/+|/+$'), '');
  final segments = clean.split('/');
  if (method == 'GET' && clean == 'agents/get-password') {
    return 'agent.password';
  }
  if (method == 'GET' && clean == 'apis') return 'apis.list';
  if (method == 'PUT' && clean == 'apis/status') return 'apis.status';
  if (method == 'GET' && clean == 'agent/config') return 'agent.config.get';
  if (method == 'PUT' && clean == 'agent/config') return 'agent.config.update';
  if (method == 'GET' && clean == 'agent/status') return 'agent.status';
  if (method == 'GET' && clean == 'follows') return 'follows.list';
  if (method == 'POST' && clean == 'follows') return 'follows.add';
  if (method == 'DELETE' && segments.first == 'follows') {
    return 'follows.remove';
  }
  if (method == 'GET' && clean == 'favorites') return 'favorites.list';
  if (method == 'POST' && clean == 'favorites') return 'favorites.add';
  if (method == 'POST' && clean == 'favorites/delete-batch') {
    return 'favorites.delete_batch';
  }
  if (method == 'DELETE' && segments.first == 'favorites') {
    return 'favorites.delete';
  }
  if (method == 'POST' && clean == 'calls') return 'calls.create';
  if (method == 'GET' && clean == 'calls/active') return 'calls.active';
  if (method == 'GET' && clean == 'calls') return 'calls.list';
  if (method == 'POST' && clean == 'calls/incoming') return 'calls.incoming';
  if (segments.length == 2 && segments.first == 'calls') return 'calls.get';
  if (segments.length == 3 && segments.first == 'calls') return 'calls.event';
  if (method == 'POST' && clean == 'channels') return 'channels.create';
  if (method == 'GET' && clean == 'channels') return 'channels.list';
  if (method == 'GET' && clean == 'channels/me/comments') {
    return 'channels.my_comments';
  }
  if (method == 'GET' && clean == 'channels/me/reactions') {
    return 'channels.my_reactions';
  }
  if (method == 'GET' && clean == 'public/channels/search') {
    return 'channels.public.search';
  }
  if (segments.length >= 3 &&
      segments[0] == 'public' &&
      segments[1] == 'channels') {
    return method == 'GET'
        ? 'channels.public.get'
        : 'channels.public.join_request';
  }
  if (method == 'GET' &&
      segments.length == 3 &&
      segments[0] == 'users' &&
      segments[2] == 'public-channels') {
    return 'users.public_channels';
  }
  if (segments.isNotEmpty && segments[0] == 'channels') {
    if (method == 'POST' && clean == 'channels/invite-grants') {
      return 'channels.invite_grant.create';
    }
    if (segments.length == 2 && method == 'PUT') return 'channels.update';
    if (segments.length == 2 && method == 'POST') return 'channels.join';
    if (segments.length == 3 && segments[2] == 'join') return 'channels.join';
    if (segments.length == 3 && segments[2] == 'leave') return 'channels.leave';
    if (segments.length == 3 && segments[2] == 'dissolve') {
      return 'channels.dissolve';
    }
    if (segments.length == 3 && segments[2] == 'invite') {
      return 'channels.invite';
    }
    if (segments.length == 3 && segments[2] == 'invite-grants') {
      return 'channels.invite_grant.create';
    }
    if (segments.length == 3 && segments[2] == 'members') {
      return 'channels.members';
    }
    if (segments.length >= 5 && segments[2] == 'members') {
      return 'channels.member.${segments[4].replaceAll('-', '_')}';
    }
    if (segments.length >= 5 && segments[2] == 'join-requests') {
      return 'channels.join_request.${segments[4].replaceAll('-', '_')}';
    }
    if (segments.length == 3 &&
        (segments[2] == 'mute' || segments[2] == 'unmute')) {
      return 'channels.${segments[2]}';
    }
    if (segments.length == 3 && segments[2] == 'posts') {
      return method == 'GET' ? 'channels.posts.list' : 'channels.posts.create';
    }
    if (segments.length == 3 && segments[2] == 'read-marker') {
      return 'channels.read_marker';
    }
    if (segments.length == 4 && segments[2] == 'posts') {
      return 'channels.posts.recall';
    }
    if (segments.length == 5 &&
        segments[2] == 'posts' &&
        segments[4] == 'recall') {
      return 'channels.posts.recall';
    }
    if (segments.length == 5 &&
        segments[2] == 'posts' &&
        segments[4] == 'comments') {
      return method == 'GET'
          ? 'channels.comments.list'
          : 'channels.comments.create';
    }
    if (segments.length == 5 &&
        segments[2] == 'posts' &&
        segments[4] == 'reactions') {
      return 'channels.post_reaction.toggle';
    }
    if (segments.length >= 7 &&
        segments[2] == 'posts' &&
        segments[4] == 'comments') {
      return segments.last == 'recall'
          ? 'channels.comments.recall'
          : 'channels.comment_reaction.toggle';
    }
  }
  if (method == 'POST' && clean == 'groups') return 'groups.create';
  if (method == 'GET' && clean == 'groups') return 'groups.list';
  if (segments.isNotEmpty && segments[0] == 'groups') {
    if (segments.length == 2 && method == 'PUT') return 'groups.update';
    if (segments.length == 3 && segments[2] == 'invite') return 'groups.invite';
    if (segments.length == 3 && segments[2] == 'members') {
      return 'groups.members';
    }
    if (segments.length >= 5 && segments[2] == 'members') {
      return 'groups.member.${segments[4].replaceAll('-', '_')}';
    }
    if (segments.length == 3 && segments[2] == 'invite-policy') {
      return 'groups.invite_policy.update';
    }
    if (segments.length == 3) {
      return 'groups.${segments[2].replaceAll('-', '_')}';
    }
  }
  if (method == 'GET' && clean == 'profile') return 'profile.get';
  if (method == 'PUT' && clean == 'profile') return 'profile.update';
  if (method == 'GET' && clean == 'sync/bootstrap') return 'sync.bootstrap';
  if (method == 'GET' && clean == 'conversations') {
    return 'conversations.list';
  }
  if (method == 'PUT' && clean == 'sync/read-marker') return 'sync.read_marker';
  if (method == 'GET' && clean == 'portal/status') return 'portal.status';
  if (method == 'POST' && clean == 'portal/setup') return 'portal.setup';
  if (method == 'PUT' && clean == 'portal/password') return 'portal.password';
  if (method == 'POST' && clean == 'reports') return 'reports.submit';
  if (method == 'GET' && clean == 'contacts') return 'contacts.list';
  if (method == 'POST' && clean == 'contacts/requests') {
    return 'contacts.request';
  }
  if (method == 'DELETE' &&
      segments.length >= 3 &&
      segments[0] == 'contacts' &&
      segments[1] == 'requests') {
    return 'contacts.requests.delete';
  }
  if (segments.length >= 4 &&
      segments[0] == 'contacts' &&
      segments[1] == 'requests') {
    return 'contacts.requests.${segments.last.replaceAll('-', '_')}';
  }
  if (segments.length >= 2 && segments[0] == 'contacts') {
    if (method == 'PUT') return 'contacts.update';
    return 'contacts.delete';
  }
  return clean.replaceAll('/', '.').replaceAll('-', '_');
}

Map<String, Object?> _actionParams(
  String path, {
  Map<String, String>? queryParameters,
  Object? body,
}) {
  final params = <String, Object?>{};
  if (queryParameters != null) {
    params.addAll(queryParameters);
  }
  if (body is Map) {
    params.addAll(body.cast<String, Object?>());
  } else if (body != null) {
    params['body'] = body;
  }
  final clean = path.trim().replaceAll(RegExp(r'^/+|/+$'), '');
  final segments = clean.split('/');
  if (segments.length >= 2 && segments[0] == 'rooms') {
    params['room_id'] = Uri.decodeComponent(segments[1]);
  }
  if (segments.length >= 2 &&
      segments[0] == 'channels' &&
      !(segments.length == 2 && segments[1] == 'join') &&
      segments[1] != 'me' &&
      segments[1] != 'invite-grants') {
    params['channel_id'] = Uri.decodeComponent(segments[1]);
  }
  if (segments.length >= 3 &&
      segments[0] == 'public' &&
      segments[1] == 'channels' &&
      segments[2] != 'search') {
    final id = Uri.decodeComponent(segments[2]);
    params['channel_id'] = id;
    params['room_id'] = id;
  }
  if (segments.length >= 3 &&
      segments[0] == 'users' &&
      segments[2] == 'public-channels') {
    final userID = Uri.decodeComponent(segments[1]);
    params['user_id'] = userID;
    params['user_mxid'] = userID;
  }
  if (segments.length >= 4 &&
      segments[0] == 'channels' &&
      segments[2] == 'posts') {
    params['post_id'] = Uri.decodeComponent(segments[3]);
  }
  if (segments.length >= 6 &&
      segments[0] == 'channels' &&
      segments[2] == 'posts' &&
      segments[4] == 'comments') {
    params['comment_id'] = Uri.decodeComponent(segments[5]);
  }
  if (segments.length >= 4 &&
      segments[0] == 'channels' &&
      (segments[2] == 'members' || segments[2] == 'join-requests')) {
    params['user_id'] = Uri.decodeComponent(segments[3]);
    params['user_mxid'] = Uri.decodeComponent(segments[3]);
  }
  if (segments.length >= 2 && segments[0] == 'groups') {
    params['room_id'] = Uri.decodeComponent(segments[1]);
  }
  if (segments.length >= 4 &&
      segments[0] == 'groups' &&
      segments[2] == 'members') {
    params['user_id'] = Uri.decodeComponent(segments[3]);
    params['peer_mxid'] = Uri.decodeComponent(segments[3]);
  }
  if (segments.length >= 2 &&
      segments[0] == 'calls' &&
      segments[1] != 'incoming' &&
      segments[1] != 'active') {
    params['call_id'] = Uri.decodeComponent(segments[1]);
  }
  if (segments.length >= 2 && segments[0] == 'favorites') {
    params['id'] = Uri.decodeComponent(segments[1]);
  }
  if (segments.length >= 2 && segments[0] == 'follows') {
    params['domain'] = Uri.decodeComponent(segments[1]);
  }
  if (segments.length >= 2 && segments[0] == 'contacts') {
    if (segments[1] == 'export' && segments.length >= 3) {
      params['filename'] = Uri.decodeComponent(segments[2]);
    } else if (segments[1] == 'requests' && segments.length >= 3) {
      params['room_id'] = Uri.decodeComponent(segments[2]);
    } else if (segments[1] != 'export' && segments[1] != 'import') {
      params['room_id'] = Uri.decodeComponent(segments[1]);
    }
  }
  return params;
}

String _encodeStrictPathComponent(String value) =>
    Uri.encodeComponent(value).replaceAll('!', '%21');

bool _isUnifiedBase(Uri baseUri) =>
    baseUri.path == '/_p2p' || baseUri.path.startsWith('/_p2p/');

String _friendRequestTarget(Object? body) {
  if (body is! Map) return '<unknown>';
  final mxid = body['mxid'];
  if (mxid is! String || mxid.trim().isEmpty) return '<unknown>';
  return mxid.trim();
}

Map<String, dynamic> _contactEntryLogJson(ContactEntry contact) {
  return {
    'peer_mxid': contact.peerMxid,
    'display_name': contact.displayName,
    'domain': contact.domain,
    'room_id': contact.roomId,
    'status': contact.status,
  };
}

Map<String, dynamic> _passwordChangeLogJson(Map<String, String> body) {
  return {
    'old_password': '<redacted>',
    'new_password': '<redacted>',
    'old_password_length': body['old_password']?.length ?? 0,
    'new_password_length': body['new_password']?.length ?? 0,
  };
}

Map<String, dynamic> _portalSessionLogJson(AsPortalSession session) {
  return {
    'access_token_present': session.accessToken.isNotEmpty,
    'access_token_length': session.accessToken.length,
    'user_id': session.userId,
    'homeserver': session.homeserver,
    'device_id': session.deviceId,
    'initialization_completed': session.initializationCompleted,
    'already_initialized': session.alreadyInitialized,
    'setup_completed': session.setupCompleted,
    'account_initialized': session.accountInitialized,
    'profile_initialized': session.profileInitialized,
    'password_initialized': session.passwordInitialized,
  };
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

String _normalizedChannelType(String value) {
  final trimmed = value.trim().toLowerCase();
  return switch (trimmed) {
    'chat' || '聊天' => 'chat',
    _ => 'post',
  };
}

Stream<AsEventStreamEvent> _decodeSseEvents(Stream<String> lines) async* {
  var eventName = '';
  var eventId = '';
  final dataLines = <String>[];

  AsEventStreamEvent? buildEvent() {
    if (dataLines.isEmpty) return null;
    final rawData = dataLines.join('\n');
    dataLines.clear();
    final name = eventName;
    final id = eventId;
    eventName = '';
    eventId = '';

    final decoded = jsonDecode(rawData);
    if (decoded is! Map<String, dynamic>) return null;
    final fromJson = AsEventStreamEvent.fromJson(decoded);
    final fallbackSeq = int.tryParse(id) ?? 0;
    return AsEventStreamEvent(
      seq: fromJson.seq > 0 ? fromJson.seq : fallbackSeq,
      type: fromJson.type.isNotEmpty ? fromJson.type : name,
      roomId: fromJson.roomId,
      eventId: fromJson.eventId,
      payload: fromJson.payload,
      createdAt: fromJson.createdAt,
    );
  }

  await for (final line in lines) {
    if (line.isEmpty) {
      final event = buildEvent();
      if (event != null) yield event;
      continue;
    }
    if (line.startsWith(':')) continue;
    final separator = line.indexOf(':');
    final field = separator == -1 ? line : line.substring(0, separator);
    var value = separator == -1 ? '' : line.substring(separator + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        eventName = value;
        break;
      case 'id':
        eventId = value;
        break;
      case 'data':
        dataLines.add(value);
        break;
    }
  }
  final trailing = buildEvent();
  if (trailing != null) yield trailing;
}

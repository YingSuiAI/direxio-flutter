import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

import 'api_logger.dart';
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
    String authSource = 'portal_token',
    String? matrixAccessTokenForDebug,
    FutureOr<void> Function()? onAuthenticationFailed,
    http.Client? httpClient,
  })  : _baseUri = _normalizeBaseUri(baseUri),
        _portalToken = _requireToken(portalToken ?? accessToken),
        _authSource = authSource,
        _matrixAccessTokenForDebug = matrixAccessTokenForDebug,
        _onAuthenticationFailed = onAuthenticationFailed,
        _http = httpClient ?? http.Client();

  factory HttpAsClient.fromPortalSession(
    Client client, {
    required String portalToken,
    Uri? baseUri,
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
      matrixAccessTokenForDebug: client.accessToken,
      onAuthenticationFailed: onAuthenticationFailed,
      httpClient: client.httpClient,
    );
  }

  /// Backward-compatible constructor for sessions created before AS v2 auth.
  /// New p2p-matrix-as deployments expect [fromPortalSession] instead.
  factory HttpAsClient.fromMatrixClient(
    Client client, {
    Uri? baseUri,
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
      authSource: 'matrix_access_token',
      matrixAccessTokenForDebug: token,
      onAuthenticationFailed: onAuthenticationFailed,
      httpClient: client.httpClient,
    );
  }

  final Uri _baseUri;
  final String _portalToken;
  final String? _authSource;
  final String? _matrixAccessTokenForDebug;
  final FutureOr<void> Function()? _onAuthenticationFailed;
  final http.Client _http;

  static const _timeout = Duration(seconds: 10);

  static Uri defaultAdminBaseUri(Uri homeserver) {
    final host = homeserver.host;
    final isLoopback =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    final port = isLoopback
        ? 9090
        : homeserver.hasPort
            ? homeserver.port
            : null;
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
        body: {'password': portalToken},
      );
    } finally {
      if (ownsClient) client.close();
    }
  }

  static Future<AsPortalSession> bootstrapPortal({
    required Uri baseUri,
    required String setupCode,
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
        body: {'token': setupCode},
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
  Future<String> sendRoomMessage(
    String roomId,
    String content, {
    String? replyToEventId,
    List<Map<String, String>> mentions = const [],
  }) async {
    final replyTo = replyToEventId?.trim();
    final normalizedMentions = [
      for (final mention in mentions)
        if ((mention['user_id'] ?? '').trim().isNotEmpty)
          {
            'user_id': (mention['user_id'] ?? '').trim(),
            if ((mention['display_name'] ?? '').trim().isNotEmpty)
              'display_name': (mention['display_name'] ?? '').trim(),
          },
    ];
    final body = await _requestJson(
      'POST',
      'rooms/${Uri.encodeComponent(roomId)}/send',
      body: {
        'content': content,
        if (replyTo != null && replyTo.isNotEmpty) 'reply_to': replyTo,
        if (normalizedMentions.isNotEmpty) ...{
          'message_type': 'at_text',
          'mentions': normalizedMentions,
        },
      },
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
  Future<String> sendChannelShareMessage({
    required String roomId,
    required String body,
    required AsChannelShareDraft channel,
  }) async {
    final response = await _requestJson(
      'POST',
      'rooms/${Uri.encodeComponent(roomId)}/send',
      body: {
        'content': body.trim(),
        'message_type': 'channel_share',
        'channel_share': channel.toJson(),
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
  Future<AsPortalSession> changePortalPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final requestBody = {
      'old_password': oldPassword.trim(),
      'new_password': newPassword.trim(),
    };
    ApiLogger.info(
      '[AS admin] portal password params '
      'auth_source=$_authSourceLabel '
      'authorization_present=${_portalToken.trim().isNotEmpty} '
      'bearer=true '
      'admin_access_token_length=${_portalToken.trim().length} '
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
    if (session.matrixAccessToken.isEmpty || session.adminAccessToken.isEmpty) {
      throw AsClientException(
        'AS password response is missing matrix_access_token, '
        'or admin_access_token',
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
  }) async {
    final body = await _getPublicJson(
      'public/channels/${_encodeStrictPathComponent(roomId.trim())}',
      baseUri: baseUri,
    );
    return AsChannel.fromJson(body);
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
    AsChannel? discoveredChannel,
  }) async {
    final trimmedRoomId = roomId.trim();
    final requestBody = <String, Object?>{
      'room_id': trimmedRoomId,
      if (shareToken.trim().isNotEmpty) 'share_token': shareToken.trim(),
    };
    final body = await _requestJson(
      'POST',
      'channels/join',
      body: requestBody,
      allowedStatusCodes: const {200},
    );
    return AsChannel.fromJson(
      (body['channel'] as Map?)?.cast<String, dynamic>() ?? body,
    );
  }

  @override
  Future<AsChannel> joinChannel(
    String channelId, {
    String shareToken = '',
    AsChannel? discoveredChannel,
  }) async {
    final requestBody = <String, Object?>{
      if (shareToken.trim().isNotEmpty) 'share_token': shareToken.trim(),
      ..._discoveredChannelJoinBody(discoveredChannel),
    };
    final body = await _requestJson(
      'POST',
      'channels/${Uri.encodeComponent(channelId)}/join',
      body: requestBody.isEmpty ? null : requestBody,
      allowedStatusCodes: const {200},
    );
    return AsChannel.fromJson(
      (body['channel'] as Map?)?.cast<String, dynamic>() ?? body,
    );
  }

  @override
  Future<void> leaveChannel(String channelId) async {
    await _requestJson(
      'POST',
      'channels/${Uri.encodeComponent(channelId.trim())}/leave',
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
  Future<List<AsChannelComment>> getChannelComments(
    String channelId,
    String postId, {
    int limit = 50,
    int beforeTs = 0,
  }) async {
    final response = await _getJson(
      'channels/${Uri.encodeComponent(channelId)}/posts/${Uri.encodeComponent(postId)}/comments',
      queryParameters: {
        'limit': limit.toString(),
        if (beforeTs > 0) 'before_ts': beforeTs.toString(),
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
  }) async {
    final response = await _requestJson(
      'POST',
      'channels/${Uri.encodeComponent(channelId)}/posts/${Uri.encodeComponent(postId)}/comments',
      body: {
        'message_type':
            messageType.trim().isEmpty ? 'text' : messageType.trim(),
        'body': body.trim(),
        if (media.isNotEmpty) 'media_json': jsonEncode(media),
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
  Future<void> removeGroupMember({
    required String roomId,
    required String peerMxid,
  }) async {
    await _requestJson(
      'POST',
      'groups/${Uri.encodeComponent(roomId)}/members/'
          '${Uri.encodeComponent(peerMxid.trim())}/remove',
      allowedStatusCodes: const {200},
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

  Future<Map<String, dynamic>> _getPublicJson(
    String path, {
    Uri? baseUri,
    Map<String, String>? queryParameters,
  }) async {
    final uri = _resolveAgainst(
      _normalizeBaseUri(baseUri ?? _baseUri),
      path,
      queryParameters: queryParameters,
    );
    final stopwatch = Stopwatch()..start();
    late http.Response response;
    try {
      response = await _http.get(uri,
          headers: const {'Accept': 'application/json'}).timeout(_timeout);
    } catch (error, stackTrace) {
      stopwatch.stop();
      ApiLogger.failure(
        service: 'AS public',
        method: 'GET',
        uri: uri,
        elapsed: stopwatch.elapsed,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
    stopwatch.stop();
    ApiLogger.response(
      service: 'AS public',
      method: 'GET',
      uri: uri,
      statusCode: response.statusCode,
      elapsed: stopwatch.elapsed,
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
      final matrixAccessToken = _matrixAccessTokenForDebug?.trim() ?? '';
      ApiLogger.info(
        '[AS admin] friend request auth '
        'authorization_present=${authorization.isNotEmpty} '
        'bearer=${authorization.startsWith('Bearer ')} '
        'auth_source=$_authSourceLabel '
        'portal_token_present=${_portalToken.trim().isNotEmpty} '
        'portal_token_length=${_portalToken.length} '
        'matrix_access_token_present=${matrixAccessToken.isNotEmpty} '
        'matrix_access_token_length=${matrixAccessToken.length} '
        'authorization_matches_matrix_access_token='
        '${authorization == 'Bearer $matrixAccessToken'} '
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
    final uri = _resolveStatic(baseUri, path);
    final requestBody = jsonEncode(body);
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
    if (session.matrixAccessToken.isEmpty ||
        session.adminAccessToken.isEmpty ||
        session.userId.isEmpty ||
        session.homeserver.isEmpty) {
      final error = AsClientException(
        'AS auth response is missing matrix_access_token, '
        'admin_access_token, user_id, or homeserver',
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

String _encodeStrictPathComponent(String value) =>
    Uri.encodeComponent(value).replaceAll('!', '%21');

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
    'matrix_access_token_present': session.matrixAccessToken.isNotEmpty,
    'matrix_access_token_length': session.matrixAccessToken.length,
    'admin_access_token_present': session.adminAccessToken.isNotEmpty,
    'admin_access_token_length': session.adminAccessToken.length,
    'user_id': session.userId,
    'homeserver': session.homeserver,
    'device_id': session.deviceId,
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
    'post' || '帖子' => 'post',
    _ => 'chat',
  };
}

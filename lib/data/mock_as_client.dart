// [AsClient] 的 Mock 实现。
//
// 真实 App 注入点已经切到 HttpAsClient；本类保留给本地 UI / 单测兜底使用。
import '../presentation/mock/mock_data.dart';
import 'as_client.dart';

class MockAsClient implements AsClient {
  static const _latency = Duration(milliseconds: 240);

  // 进程内可变状态，模拟服务端持久化
  AgentConfig _config = const AgentConfig(displayName: '小A', contextWindow: 20);
  OwnerProfile _ownerProfile = const OwnerProfile(
    userId: '@owner:mock.local',
    displayName: '破局',
    domain: 'mock.local',
  );
  final List<FollowEntry> _follows = [
    FollowEntry(
      domain: 'liyananp2p.com',
      name: 'Jack',
      followedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];
  final List<AsFavoriteMessage> _favorites = [];
  final Map<String, AsCallSession> _calls = {};
  int _nextFavoriteId = 1;
  int _nextCallId = 1;

  @override
  Future<OwnerProfile> getOwnerProfile() async {
    await Future.delayed(_latency);
    return _ownerProfile;
  }

  @override
  Future<OwnerProfile> updateOwnerProfile({required String displayName}) async {
    await Future.delayed(_latency);
    _ownerProfile = OwnerProfile(
      userId: _ownerProfile.userId,
      displayName: displayName.trim(),
      domain: _ownerProfile.domain,
    );
    return _ownerProfile;
  }

  @override
  Future<AsSyncBootstrap> syncBootstrap() async {
    await Future.delayed(_latency);
    return AsSyncBootstrap(
      syncedAt: DateTime.now().toUtc(),
      user: const AsSyncUser(userId: '@owner:mock'),
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
      rooms: const [],
    );
  }

  @override
  Future<AsSyncUnread> syncUnread({int limitPerRoom = 200}) async {
    await Future.delayed(_latency);
    return AsSyncUnread(
      syncedAt: DateTime.now().toUtc(),
      rooms: const [],
    );
  }

  @override
  Future<List<AsSearchResult>> search(
    String query, {
    String? roomId,
    int limit = 20,
  }) async {
    await Future.delayed(_latency);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final results = <AsSearchResult>[];
    for (final conv in MockData.conversations) {
      if (roomId != null && conv.id != roomId) continue;
      for (final m in conv.messages) {
        if (m.text.toLowerCase().contains(q)) {
          results.add(
            AsSearchResult(
              eventId: 'mock_evt_${results.length}',
              roomId: conv.id,
              senderName: m.isMe ? '我' : conv.name,
              content: m.text,
              timestamp: m.time,
            ),
          );
          if (results.length >= limit) return results;
        }
      }
    }
    return results;
  }

  @override
  Future<AgentConfig> getAgentConfig() async {
    await Future.delayed(_latency);
    return _config;
  }

  @override
  Future<AgentConfig> updateAgentConfig(AgentConfig config) async {
    await Future.delayed(_latency);
    _config = config;
    return _config;
  }

  @override
  Future<AgentStatus> getAgentStatus() async {
    await Future.delayed(_latency);
    return AgentStatus(
      connected: true,
      lastSeen: DateTime.now().subtract(const Duration(minutes: 2)),
      roomsJoined: MockData.conversations.length,
      messagesToday: 42,
    );
  }

  @override
  Future<List<FollowEntry>> getFollows() async {
    await Future.delayed(_latency);
    return List.unmodifiable(_follows);
  }

  @override
  Future<void> addFollow(String domain) async {
    await Future.delayed(_latency);
    final d = domain.trim();
    if (_follows.any((f) => f.domain == d)) return;
    _follows.add(FollowEntry(domain: d, name: d, followedAt: DateTime.now()));
  }

  @override
  Future<void> removeFollow(String domain) async {
    await Future.delayed(_latency);
    _follows.removeWhere((f) => f.domain == domain.trim());
  }

  @override
  Future<List<AsFavoriteMessage>> getFavorites({
    String messageType = '',
    int limit = 100,
  }) async {
    await Future.delayed(_latency);
    return _favorites
        .where(
          (favorite) =>
              messageType.trim().isEmpty ||
              favorite.messageType == messageType.trim(),
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<AsFavoriteMessage> favoriteMessage(
    AsFavoriteMessageDraft draft,
  ) async {
    await Future.delayed(_latency);
    final existingIndex = _favorites.indexWhere(
      (favorite) =>
          favorite.roomId == draft.roomId && favorite.eventId == draft.eventId,
    );
    final favorite = AsFavoriteMessage(
      id: existingIndex == -1
          ? _nextFavoriteId++
          : _favorites[existingIndex].id,
      ownerUserId: _ownerProfile.userId,
      roomId: draft.roomId,
      eventId: draft.eventId,
      roomType: draft.roomType,
      messageType: draft.messageType,
      senderId: draft.senderId,
      senderName: draft.senderName,
      body: draft.body,
      url: draft.url,
      filename: draft.filename,
      mimeType: draft.mimeType,
      size: draft.size,
      thumbnailUrl: draft.thumbnailUrl,
      thumbnailMimeType: draft.thumbnailMimeType,
      thumbnailSize: draft.thumbnailSize,
      width: draft.width,
      height: draft.height,
      durationMs: draft.durationMs,
      originServerTs: draft.originServerTs,
      favoritedAt: DateTime.now().toUtc(),
      chatRecord: draft.chatRecord,
    );
    if (existingIndex == -1) {
      _favorites.insert(0, favorite);
    } else {
      _favorites
        ..removeAt(existingIndex)
        ..insert(0, favorite);
    }
    return favorite;
  }

  @override
  Future<void> deleteFavorite(int id) async {
    await Future.delayed(_latency);
    _favorites.removeWhere((favorite) => favorite.id == id);
  }

  @override
  Future<ContactEntry> createContactRequest({
    required String mxid,
    String displayName = '',
    String domain = '',
  }) async {
    await Future.delayed(_latency);
    return ContactEntry(
      peerMxid: mxid,
      displayName: displayName,
      domain: domain,
      roomId: '!mock-contact:portal.local',
      status: 'pending_outbound',
    );
  }

  @override
  Future<ContactEntry> acceptContactRequest({
    required String roomId,
    required String peerMxid,
    String displayName = '',
    String domain = '',
  }) async {
    await Future.delayed(_latency);
    return ContactEntry(
      peerMxid: peerMxid,
      displayName: displayName,
      domain: domain,
      roomId: roomId,
      status: 'accepted',
    );
  }

  @override
  Future<ContactEntry> rejectContactRequest({
    required String roomId,
    required String peerMxid,
    String displayName = '',
    String domain = '',
  }) async {
    await Future.delayed(_latency);
    return ContactEntry(
      peerMxid: peerMxid,
      displayName: displayName,
      domain: domain,
      roomId: roomId,
      status: 'rejected',
    );
  }

  @override
  Future<ContactEntry> deleteContact(String roomId) async {
    await Future.delayed(_latency);
    return ContactEntry(
      peerMxid: '@mock:portal.local',
      displayName: '',
      domain: 'portal.local',
      roomId: roomId,
      status: 'rejected',
    );
  }

  @override
  Future<void> deleteRoomMessage({
    required String roomId,
    required String eventId,
  }) async {
    await Future.delayed(_latency);
  }

  @override
  Future<String> sendRoomMessage(String roomId, String content) async {
    await Future.delayed(_latency);
    return 'mock-event';
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
    await Future.delayed(_latency);
    return 'mock-chat-record-event';
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
    await Future.delayed(_latency);
    return 'mock-media-event';
  }

  @override
  Future<AsCallSession> createCall({
    required String roomId,
    required String mediaType,
    List<String> invitedUserIds = const [],
  }) async {
    await Future.delayed(_latency);
    final now = DateTime.now().toUtc();
    final call = AsCallSession(
      callId: 'mock_call_${_nextCallId++}',
      roomId: roomId.trim(),
      roomType: roomId.contains('group') ? 'group' : 'direct',
      mediaType:
          mediaType.trim().isEmpty ? asCallMediaTypeVoice : mediaType.trim(),
      createdByMxid: _ownerProfile.userId,
      invitedUserIds: _normalizedMockStringList(invitedUserIds),
      state: asCallStateRinging,
      createdAt: now,
    );
    _calls[call.callId] = call;
    return call;
  }

  @override
  Future<AsCallSession> getCall(String callId) async {
    await Future.delayed(_latency);
    final call = _calls[callId.trim()];
    if (call == null) {
      throw AsClientException('call not found', statusCode: 404);
    }
    return call;
  }

  @override
  Future<List<AsCallSession>> getActiveCalls() async {
    await Future.delayed(_latency);
    return _calls.values
        .where((call) =>
            call.state == asCallStateRinging ||
            call.state == asCallStateConnected)
        .toList(growable: false);
  }

  @override
  Future<List<AsCallSession>> listCalls({
    required String roomId,
    int limit = 50,
  }) async {
    await Future.delayed(_latency);
    final trimmedRoomId = roomId.trim();
    if (trimmedRoomId.isEmpty) return const [];
    final cappedLimit = limit <= 0 ? 50 : limit;
    final calls = _calls.values
        .where((call) => call.roomId.trim() == trimmedRoomId)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return calls.take(cappedLimit).toList(growable: false);
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
    await Future.delayed(_latency);
    final key = callId.trim();
    final existing = _calls[key];
    if (existing != null) return existing;
    final call = AsCallSession(
      callId: key,
      roomId: roomId.trim(),
      roomType: roomId.contains('group') ? 'group' : 'direct',
      mediaType:
          mediaType.trim().isEmpty ? asCallMediaTypeVoice : mediaType.trim(),
      createdByMxid: createdByMxid.trim(),
      invitedUserIds: _normalizedMockStringList(invitedUserIds),
      state: asCallStateRinging,
      createdAt: createdAt?.toUtc() ?? DateTime.now().toUtc(),
    );
    _calls[key] = call;
    return call;
  }

  @override
  Future<AsCallSession> updateCallEvent({
    required String callId,
    required String event,
    String reason = '',
    int durationMs = 0,
  }) async {
    await Future.delayed(_latency);
    final key = callId.trim();
    final current = _calls[key];
    if (current == null) {
      throw AsClientException('call not found', statusCode: 404);
    }
    final now = DateTime.now().toUtc();
    final normalizedEvent = event.trim();
    late final AsCallSession next;
    if (normalizedEvent == asCallStateConnected) {
      next = current.copyWith(
        state: asCallStateConnected,
        answeredAt: now,
      );
    } else {
      final terminalState = switch (normalizedEvent) {
        asCallStateMissed => asCallStateMissed,
        asCallStateFailed => asCallStateFailed,
        _ => asCallStateEnded,
      };
      final answeredAt = current.answeredAt;
      final computedDuration = durationMs > 0
          ? durationMs
          : answeredAt == null
              ? 0
              : now.difference(answeredAt).inMilliseconds;
      next = current.copyWith(
        state: terminalState,
        endedAt: now,
        endedByMxid: _ownerProfile.userId,
        endReason: reason.trim(),
        durationMs: computedDuration,
      );
    }
    _calls[key] = next;
    return next;
  }

  @override
  Future<PortalStatus> getPortalStatus() async {
    await Future.delayed(_latency);
    return const PortalStatus(
      dendrite: 'connected',
      federation: 'ok',
      agent: 'connected',
      uptime: '3d 5h',
    );
  }

  @override
  Future<String> changePortalToken(String newToken) async {
    await Future.delayed(_latency);
    return newToken.trim();
  }

  @override
  Future<String> createChannel({
    required String name,
    String topic = '',
  }) async {
    await Future.delayed(_latency);
    return 'mock_channel_${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  Future<AsGroupResult> createGroup({
    required String name,
    required List<String> invite,
  }) async {
    await Future.delayed(_latency);
    return AsGroupResult(
      roomId: 'mock_group_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      memberCount: 1,
      invitedCount: invite.where((mxid) => mxid.trim().isNotEmpty).length,
      role: 'owner',
    );
  }

  @override
  Future<AsGroupResult> inviteGroupMembers({
    required String roomId,
    required List<String> invite,
  }) async {
    await Future.delayed(_latency);
    return AsGroupResult(
      roomId: roomId,
      name: '群聊',
      memberCount: 1,
      invitedCount: invite.where((mxid) => mxid.trim().isNotEmpty).length,
    );
  }

  @override
  Future<AsGroupResult> updateGroupInvitePolicy({
    required String roomId,
    required String invitePolicy,
  }) async {
    await Future.delayed(_latency);
    return AsGroupResult(
      roomId: roomId,
      name: '群聊',
      memberCount: 1,
      invitePolicy: invitePolicy.trim(),
    );
  }

  @override
  Future<AsGroupResult> joinGroup({
    required String roomId,
    String groupName = '',
    String inviterMxid = '',
    String inviteEventId = '',
    String directRoomId = '',
  }) async {
    await Future.delayed(_latency);
    return AsGroupResult(
      roomId: roomId,
      name: groupName.trim().isEmpty ? '群聊' : groupName.trim(),
      memberCount: 2,
      role: 'member',
    );
  }

  @override
  Future<void> leaveGroup(String roomId) async {
    await Future.delayed(_latency);
  }

  @override
  Future<void> updateReadMarker(
    String roomId,
    String eventId,
    DateTime timestamp,
  ) async {
    await Future.delayed(_latency);
  }
}

List<String> _normalizedMockStringList(Iterable<String> values) {
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

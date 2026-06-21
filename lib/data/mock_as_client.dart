import 'dart:async';

// [AsClient] 的 Mock 实现。
//
// 真实 App 注入点已经切到 HttpAsClient；本类保留给本地 UI / 单测兜底使用。
import '../presentation/mock/mock_data.dart';
import '../presentation/utils/contact_identity_label.dart';
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
  final Map<String, AsChannel> _channels = {};
  final Map<String, List<AsChannelMember>> _channelMembers = {};
  final Map<String, List<AsChannelPost>> _channelPosts = {};
  final Map<String, List<AsChannelComment>> _channelComments = {};
  final Set<String> _channelReactions = {};
  final Set<String> _channelCommentReactions = {};
  int _nextFavoriteId = 1;
  int _nextCallId = 1;
  int _nextChannelId = 1;
  int _nextChannelPostId = 1;
  int _nextChannelCommentId = 1;

  @override
  Future<OwnerProfile> getOwnerProfile() async {
    await Future.delayed(_latency);
    return _ownerProfile;
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
    await Future.delayed(_latency);
    _ownerProfile = OwnerProfile(
      userId: _ownerProfile.userId,
      displayName: displayName.trim(),
      domain: _ownerProfile.domain,
      avatarUrl: avatarUrl.trim(),
      gender: gender.trim(),
      birthday: birthday.trim(),
      phone: phone.trim(),
      email: email.trim(),
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
  Future<List<AsConversation>> listConversations() async {
    await Future.delayed(_latency);
    return const [];
  }

  @override
  Stream<AsEventStreamEvent> streamEvents({
    int? since,
    String? lastEventId,
  }) {
    return Completer<AsEventStreamEvent>().future.asStream();
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
  Future<Map<String, dynamic>> submitReport({
    required String reporterDomain,
    required String reportedDomain,
    required String reason,
    int targetType = 1,
    List<String> images = const [],
  }) async {
    await Future.delayed(_latency);
    return {
      'id': 'mock_report_${DateTime.now().microsecondsSinceEpoch}',
      'reporter_domain': reporterDomain.trim(),
      'reported_domain': reportedDomain.trim(),
      'target_type': targetType,
      'reason': reason.trim(),
      'images': images,
    };
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
  Future<ContactEntry> updateContact({
    required String roomId,
    required String displayName,
    String domain = '',
  }) async {
    await Future.delayed(_latency);
    return ContactEntry(
      peerMxid: '@mock:portal.local',
      displayName: displayName.trim(),
      domain: domain.trim(),
      roomId: roomId,
      status: 'accepted',
    );
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
  Future<AsPortalSession> changePortalPassword({
    required String oldPassword,
    required String newPassword,
    String? deviceId,
  }) async {
    await Future.delayed(_latency);
    throw UnsupportedError('Mock AS does not issue auth tokens');
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
    await Future.delayed(_latency);
    final id = 'mock_channel_${_nextChannelId++}';
    final channel = AsChannel(
      channelId: id,
      roomId: '!$id:mock.local',
      name: name.trim().isEmpty ? '未命名频道' : name.trim(),
      homeDomain: 'mock.local',
      description:
          description.trim().isEmpty ? topic.trim() : description.trim(),
      avatarUrl: avatarUrl.trim(),
      visibility: visibility,
      joinPolicy: joinPolicy,
      commentsEnabled: commentsEnabled,
      channelType: normalizeAsChannelType(channelType),
      role: asChannelRoleOwner,
      memberStatus: asChannelMemberStatusJoined,
      memberCount: 1,
      tags: tags,
      latestActivityAt: DateTime.now().toUtc(),
      productConversation: _mockProductConversation(
        roomId: '!$id:mock.local',
        kind: asConversationKindChannel,
        title: name.trim().isEmpty ? '未命名频道' : name.trim(),
      ),
    );
    _channels[id] = channel;
    _channelMembers[id] = [
      AsChannelMember(
        channelId: id,
        userMxid: _ownerProfile.userId,
        domain: _ownerProfile.domain,
        displayName: _ownerProfile.displayName,
        role: asChannelRoleOwner,
        status: asChannelMemberStatusJoined,
        joinedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
    _channelPosts[id] = [];
    return channel;
  }

  @override
  Future<List<AsChannel>> listChannels() async {
    await Future.delayed(_latency);
    return _channels.values.toList(growable: false);
  }

  @override
  Future<List<AsChannel>> searchPublicChannels(
    String query, {
    Uri? baseUri,
    int limit = 20,
  }) async {
    await Future.delayed(_latency);
    final q = query.trim().toLowerCase();
    return _channels.values
        .where((channel) => channel.visibility == asChannelVisibilityPublic)
        .where((channel) {
      if (q.isEmpty) return true;
      return channel.name.toLowerCase().contains(q) ||
          channel.description.toLowerCase().contains(q) ||
          channel.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList(growable: false);
  }

  @override
  Future<AsChannel> getPublicChannel(String channelId, {Uri? baseUri}) async {
    await Future.delayed(_latency);
    return _channels[channelId] ??
        AsChannel(
          channelId: channelId,
          roomId: '!$channelId:mock.local',
          name: '公开频道',
          homeDomain: 'mock.local',
          visibility: asChannelVisibilityPublic,
          joinPolicy: asChannelJoinPolicyOpen,
          commentsEnabled: true,
          memberStatus: '',
        );
  }

  @override
  Future<AsChannel> getPublicChannelByRoomId(
    String roomId, {
    Uri? baseUri,
    Uri? remoteNodeBaseUri,
  }) async {
    await Future.delayed(_latency);
    final trimmedRoomId = roomId.trim();
    for (final channel in _channels.values) {
      if (channel.roomId.trim() == trimmedRoomId) return channel;
    }
    final channelId = trimmedRoomId.startsWith('!')
        ? trimmedRoomId.substring(1).split(':').first
        : trimmedRoomId;
    return AsChannel(
      channelId: channelId,
      roomId: trimmedRoomId,
      name: '公开频道',
      homeDomain: trimmedRoomId.contains(':')
          ? serverNameFromMatrixId(trimmedRoomId)
          : 'mock.local',
      visibility: asChannelVisibilityPublic,
      joinPolicy: asChannelJoinPolicyOpen,
      commentsEnabled: true,
      memberStatus: '',
    );
  }

  @override
  Future<List<AsChannel>> getUserPublicChannels(
    String userId, {
    Uri? baseUri,
  }) async {
    await Future.delayed(_latency);
    return _channels.values
        .where((channel) => channel.visibility == asChannelVisibilityPublic)
        .where((channel) => channel.role == asChannelRoleOwner)
        .toList(growable: false);
  }

  @override
  Future<AsChannel> updateChannel(AsChannel draft) async {
    await Future.delayed(_latency);
    _channels[draft.channelId] = draft;
    return draft;
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
    await Future.delayed(_latency);
    final trimmedRoomId = roomId.trim();
    final existing = _channels.values.cast<AsChannel?>().firstWhere(
              (channel) => channel?.roomId.trim() == trimmedRoomId,
              orElse: () => null,
            ) ??
        discoveredChannel ??
        AsChannel(
          channelId: trimmedRoomId,
          roomId: trimmedRoomId,
          name: '公开频道',
          homeDomain: 'mock.local',
          visibility: asChannelVisibilityPublic,
          joinPolicy: asChannelJoinPolicyOpen,
          commentsEnabled: true,
        );
    final key = existing.channelId.trim().isEmpty
        ? existing.roomId
        : existing.channelId;
    final memberStatus = existing.joinPolicy == asChannelJoinPolicyApproval
        ? asChannelMemberStatusPending
        : asChannelMemberStatusInvite;
    final invited = AsChannel(
      channelId: existing.channelId,
      roomId: existing.roomId,
      name: existing.name,
      homeDomain: existing.homeDomain,
      description: existing.description,
      avatarUrl: existing.avatarUrl,
      visibility: existing.visibility,
      joinPolicy: existing.joinPolicy,
      commentsEnabled: existing.commentsEnabled,
      channelType: existing.channelType,
      role: asChannelRoleMember,
      memberStatus: memberStatus,
      memberCount: existing.memberCount,
      pendingJoinCount: existing.pendingJoinCount,
      tags: existing.tags,
      latestActivityAt: existing.latestActivityAt,
      productConversation: _mockProductConversation(
        roomId: existing.roomId,
        kind: asConversationKindChannel,
        title: existing.name,
      ),
    );
    _channels[key] = invited;
    _channelMembers.putIfAbsent(key, () => []);
    final members = _channelMembers[key]!;
    members.removeWhere((member) => member.userMxid == _ownerProfile.userId);
    members.add(
      AsChannelMember(
        channelId: key,
        userMxid: _ownerProfile.userId,
        domain: _ownerProfile.domain,
        displayName: _ownerProfile.displayName,
        role: asChannelRoleMember,
        status: memberStatus,
        joinedAtMs: memberStatus == asChannelMemberStatusInvite
            ? DateTime.now().millisecondsSinceEpoch
            : 0,
      ),
    );
    _channelPosts.putIfAbsent(key, () => []);
    return invited;
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
    await Future.delayed(_latency);
    final existing = _channels[channelId] ??
        discoveredChannel ??
        AsChannel(
          channelId: channelId,
          roomId: '!$channelId:mock.local',
          name: '公开频道',
          homeDomain: 'mock.local',
          visibility: asChannelVisibilityPublic,
          joinPolicy: asChannelJoinPolicyOpen,
          commentsEnabled: true,
        );
    final joined = AsChannel(
      channelId: existing.channelId,
      roomId: existing.roomId,
      name: existing.name,
      homeDomain: existing.homeDomain,
      description: existing.description,
      avatarUrl: existing.avatarUrl,
      visibility: existing.visibility,
      joinPolicy: existing.joinPolicy,
      commentsEnabled: existing.commentsEnabled,
      role: asChannelRoleMember,
      memberStatus: existing.joinPolicy == asChannelJoinPolicyApproval
          ? asChannelMemberStatusPending
          : asChannelMemberStatusJoined,
      memberCount: existing.memberCount,
      pendingJoinCount: existing.pendingJoinCount,
      tags: existing.tags,
      latestActivityAt: existing.latestActivityAt,
      productConversation: _mockProductConversation(
        roomId: existing.roomId,
        kind: asConversationKindChannel,
        title: existing.name,
      ),
    );
    _channels[channelId] = joined;
    _channelMembers.putIfAbsent(channelId, () => []);
    final members = _channelMembers[channelId]!;
    members.removeWhere((member) => member.userMxid == _ownerProfile.userId);
    members.add(
      AsChannelMember(
        channelId: channelId,
        userMxid: _ownerProfile.userId,
        domain: _ownerProfile.domain,
        displayName: _ownerProfile.displayName,
        role: asChannelRoleMember,
        status: joined.memberStatus,
        joinedAtMs: joined.memberStatus == asChannelMemberStatusJoined
            ? DateTime.now().millisecondsSinceEpoch
            : 0,
      ),
    );
    _channelPosts.putIfAbsent(channelId, () => []);
    return joined;
  }

  @override
  Future<List<AsChannelMember>> getChannelMembers(
    String channelId, {
    String status = '',
  }) async {
    await Future.delayed(_latency);
    final filter = status.trim();
    final members = _channelMembers[channelId.trim()] ?? const [];
    return members
        .where((member) => filter.isEmpty || member.status == filter)
        .toList(growable: false);
  }

  @override
  Future<void> inviteChannelMembers({
    required String channelId,
    required List<String> invite,
  }) async {
    await Future.delayed(_latency);
    final key = channelId.trim();
    if (key.isEmpty) return;
    final members = _channelMembers.putIfAbsent(key, () => []);
    for (final mxid in invite.map((value) => value.trim())) {
      if (mxid.isEmpty) continue;
      members.removeWhere((member) => member.userMxid.trim() == mxid);
      members.add(
        AsChannelMember(
          channelId: key,
          userMxid: mxid,
          role: asChannelRoleMember,
          status: asChannelMemberStatusInvite,
        ),
      );
    }
  }

  @override
  Future<AsChannelInviteGrant> createChannelInviteGrant({
    String channelId = '',
    String roomId = '',
    required String shareRoomId,
    String grantId = '',
    String reason = '',
  }) async {
    await Future.delayed(_latency);
    final key = channelId.trim().isNotEmpty ? channelId.trim() : roomId.trim();
    final channel = _channels[key] ??
        AsChannel(
          channelId: key,
          roomId: roomId.trim().isEmpty ? '!$key:mock.local' : roomId.trim(),
          name: '频道',
          homeDomain: 'mock.local',
          visibility: asChannelVisibilityPrivate,
          joinPolicy: asChannelJoinPolicyInvite,
          commentsEnabled: true,
        );
    return AsChannelInviteGrant(
      grantId: grantId.trim().isEmpty
          ? 'mock-grant-${DateTime.now().microsecondsSinceEpoch}'
          : grantId.trim(),
      roomId: channel.roomId,
      channelId: channel.channelId,
      shareRoomId: shareRoomId.trim(),
      status: 'created',
      channel: channel,
      members: _channelMembers[key] ?? const [],
    );
  }

  @override
  Future<AsChannel> approveChannelJoin(
    String channelId,
    String userMxid,
  ) async {
    return _resolveMockChannelJoin(channelId, userMxid, joined: true);
  }

  @override
  Future<AsChannel> rejectChannelJoin(
    String channelId,
    String userMxid,
  ) async {
    return _resolveMockChannelJoin(channelId, userMxid, joined: false);
  }

  @override
  Future<void> removeChannelMember(String channelId, String userMxid) async {
    await Future.delayed(_latency);
    final key = channelId.trim();
    final user = userMxid.trim();
    if (key.isEmpty || user.isEmpty) return;
    final members = _channelMembers[key];
    if (members == null) return;
    _channelMembers[key] = members
        .where((member) => member.userMxid.trim() != user)
        .toList(growable: false);
    final channel = _channels[key];
    if (channel == null) return;
    final memberCount = _channelMembers[key]!
        .where((member) => member.status == asChannelMemberStatusJoined)
        .length;
    _channels[key] = AsChannel(
      channelId: channel.channelId,
      roomId: channel.roomId,
      name: channel.name,
      homeDomain: channel.homeDomain,
      description: channel.description,
      avatarUrl: channel.avatarUrl,
      visibility: channel.visibility,
      joinPolicy: channel.joinPolicy,
      commentsEnabled: channel.commentsEnabled,
      role: channel.role,
      memberStatus: channel.memberStatus,
      memberCount: memberCount,
      pendingJoinCount: channel.pendingJoinCount,
      tags: channel.tags,
      latestActivityAt: channel.latestActivityAt,
    );
  }

  @override
  Future<void> muteChannel(String channelId) async {
    await Future.delayed(_latency);
  }

  @override
  Future<void> unmuteChannel(String channelId) async {
    await Future.delayed(_latency);
  }

  @override
  Future<void> muteChannelMember(String channelId, String userId) async {
    await Future.delayed(_latency);
  }

  @override
  Future<void> unmuteChannelMember(String channelId, String userId) async {
    await Future.delayed(_latency);
  }

  @override
  Future<void> leaveChannel(String channelId) async {
    await Future.delayed(_latency);
    final key = channelId.trim();
    if (key.isEmpty) return;
    _channels.remove(key);
    _channelMembers.remove(key);
    _channelPosts.remove(key);
  }

  @override
  Future<void> dissolveChannel(String channelId) => leaveChannel(channelId);

  Future<AsChannel> _resolveMockChannelJoin(
    String channelId,
    String userMxid, {
    required bool joined,
  }) async {
    await Future.delayed(_latency);
    final key = channelId.trim();
    final members = _channelMembers[key] ?? const <AsChannelMember>[];
    _channelMembers[key] = members.map((member) {
      if (member.userMxid != userMxid.trim()) return member;
      return AsChannelMember(
        channelId: member.channelId,
        userMxid: member.userMxid,
        domain: member.domain,
        displayName: member.displayName,
        role: member.role,
        status: joined
            ? asChannelMemberStatusInvite
            : asChannelMemberStatusRejected,
        joinedAtMs:
            joined ? DateTime.now().millisecondsSinceEpoch : member.joinedAtMs,
      );
    }).toList(growable: false);
    final channel = _channels[key] ?? await getPublicChannel(key);
    final pendingCount = _channelMembers[key]!
        .where((member) => member.status == asChannelMemberStatusPending)
        .length;
    final updated = AsChannel(
      channelId: channel.channelId,
      roomId: channel.roomId,
      name: channel.name,
      homeDomain: channel.homeDomain,
      description: channel.description,
      avatarUrl: channel.avatarUrl,
      visibility: channel.visibility,
      joinPolicy: channel.joinPolicy,
      commentsEnabled: channel.commentsEnabled,
      role: channel.role,
      memberStatus: channel.memberStatus,
      memberCount: channel.memberCount,
      pendingJoinCount: pendingCount,
      tags: channel.tags,
      latestActivityAt: channel.latestActivityAt,
    );
    _channels[key] = updated;
    return updated;
  }

  @override
  Future<List<AsChannelPost>> getChannelPosts(
    String channelId, {
    int limit = 50,
    int beforeTs = 0,
  }) async {
    await Future.delayed(_latency);
    final posts =
        List<AsChannelPost>.from(_channelPosts[channelId] ?? const []);
    final filtered = beforeTs > 0
        ? posts.where((post) => post.originServerTs < beforeTs)
        : posts;
    return filtered.map((post) {
      final key = _channelReactionKey(channelId, post.postId);
      final reacted = _channelReactions.contains(key);
      return AsChannelPost(
        postId: post.postId,
        channelId: post.channelId,
        roomId: post.roomId,
        eventId: post.eventId,
        authorId: post.authorId,
        authorName: post.authorName,
        messageType: post.messageType,
        body: post.body,
        media: post.media,
        originServerTs: post.originServerTs,
        commentCount: post.commentCount,
        reactionCount: reacted ? 1 : post.reactionCount,
        reactedByMe: reacted,
      );
    }).toList(growable: false);
  }

  @override
  Future<AsChannelPost> createChannelPost(
    String channelId, {
    required String messageType,
    required String body,
    Map<String, Object?> media = const {},
  }) async {
    await Future.delayed(_latency);
    final channel = await getPublicChannel(channelId);
    final postId = 'mock_post_${_nextChannelPostId++}';
    final post = AsChannelPost(
      postId: postId,
      channelId: channel.channelId,
      roomId: channel.roomId,
      eventId: '\$$postId',
      authorId: _ownerProfile.userId,
      authorName: _ownerProfile.displayName,
      messageType: messageType,
      body: body,
      media: media,
      originServerTs: DateTime.now().millisecondsSinceEpoch,
      commentCount: 0,
    );
    _channelPosts.putIfAbsent(channelId, () => []).insert(0, post);
    return post;
  }

  @override
  Future<void> recallChannelPost(
    String channelId,
    String postId, {
    String reason = 'recall post',
  }) async {
    await Future.delayed(_latency);
    final posts = _channelPosts[channelId];
    if (posts == null) return;
    posts.removeWhere((post) {
      final id = post.postId.trim();
      if (id.isNotEmpty) return id == postId.trim();
      return post.eventId.trim() == postId.trim();
    });
  }

  @override
  Future<List<AsChannelComment>> getChannelComments(
    String channelId,
    String postId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    await Future.delayed(_latency);
    final comments =
        List<AsChannelComment>.from(_channelComments[postId] ?? const []);
    final start = (page <= 1 ? 0 : page - 1) * pageSize;
    return comments.skip(start).take(pageSize).map((comment) {
      final reacted = _channelCommentReactions.contains(
        _channelCommentReactionKey(channelId, postId, comment.commentId),
      );
      return AsChannelComment(
        commentId: comment.commentId,
        postId: comment.postId,
        channelId: comment.channelId,
        eventId: comment.eventId,
        authorId: comment.authorId,
        authorName: comment.authorName,
        authorDomain: comment.authorDomain,
        messageType: comment.messageType,
        body: comment.body,
        media: comment.media,
        replyToCommentId: comment.replyToCommentId,
        replyToAuthorId: comment.replyToAuthorId,
        mentions: comment.mentions,
        originServerTs: comment.originServerTs,
        reactionCount: reacted ? 1 : comment.reactionCount,
        reactedByMe: reacted,
      );
    }).toList(growable: false);
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
    await Future.delayed(_latency);
    final commentId = 'mock_comment_${_nextChannelCommentId++}';
    final comment = AsChannelComment(
      commentId: commentId,
      postId: postId,
      channelId: channelId,
      eventId: '\$$commentId',
      authorId: _ownerProfile.userId,
      authorName: _ownerProfile.displayName,
      messageType: messageType,
      body: body,
      media: media,
      replyToCommentId: replyToCommentId,
      replyToAuthorId: replyToAuthorId,
      mentions: mentions,
      originServerTs: DateTime.now().millisecondsSinceEpoch,
    );
    _channelComments.putIfAbsent(postId, () => []).add(comment);
    return comment;
  }

  @override
  Future<List<AsChannelCommentHistory>> getMyChannelComments({
    int limit = 50,
  }) async {
    await Future.delayed(_latency);
    final items = <AsChannelCommentHistory>[];
    for (final entry in _channelComments.entries) {
      final post = _findChannelPost(entry.key);
      if (post == null) continue;
      final channel = _channels[post.channelId];
      if (channel == null) continue;
      for (final comment in entry.value) {
        if (comment.authorId.trim() != _ownerProfile.userId.trim()) continue;
        items.add(
          AsChannelCommentHistory(
            comment: comment,
            channel: channel,
            post: post,
          ),
        );
      }
    }
    items.sort((a, b) {
      return b.comment.originServerTs.compareTo(a.comment.originServerTs);
    });
    return items.take(limit).toList(growable: false);
  }

  @override
  Future<List<AsChannelReactionHistory>> getMyChannelReactions({
    int limit = 50,
  }) async {
    await Future.delayed(_latency);
    final items = <AsChannelReactionHistory>[];
    for (final key in _channelReactions) {
      final parts = key.split('|');
      if (parts.length < 2) continue;
      final channelId = parts[0];
      final postId = parts[1];
      final reaction = parts.length > 2 ? parts[2] : 'like';
      final channel = _channels[channelId];
      final post = _findChannelPost(postId);
      if (channel == null || post == null) continue;
      items.add(
        AsChannelReactionHistory(
          postId: postId,
          channelId: channelId,
          reaction: reaction.trim().isEmpty ? 'like' : reaction.trim(),
          originServerTs: post.originServerTs,
          channel: channel,
          post: post,
        ),
      );
    }
    items.sort((a, b) {
      return b.originServerTs.compareTo(a.originServerTs);
    });
    return items.take(limit).toList(growable: false);
  }

  @override
  Future<AsChannelReaction> toggleChannelPostReaction(
    String channelId,
    String postId, {
    String reaction = 'like',
  }) async {
    await Future.delayed(_latency);
    final key = _channelReactionKey(channelId, postId);
    final active = _channelReactions.contains(key)
        ? !_channelReactions.remove(key)
        : _channelReactions.add(key);
    return AsChannelReaction(
      postId: postId,
      channelId: channelId,
      reaction: reaction.trim().isEmpty ? 'like' : reaction.trim(),
      active: active,
      reactionCount: active ? 1 : 0,
    );
  }

  @override
  Future<AsChannelReaction> toggleChannelCommentReaction(
    String channelId,
    String postId,
    String commentId, {
    String reaction = 'like',
  }) async {
    await Future.delayed(_latency);
    final key = _channelCommentReactionKey(channelId, postId, commentId);
    final active = _channelCommentReactions.contains(key)
        ? !_channelCommentReactions.remove(key)
        : _channelCommentReactions.add(key);
    return AsChannelReaction(
      postId: postId,
      channelId: channelId,
      reaction: reaction.trim().isEmpty ? 'like' : reaction.trim(),
      active: active,
      reactionCount: active ? 1 : 0,
    );
  }

  AsChannelPost? _findChannelPost(String postId) {
    for (final posts in _channelPosts.values) {
      for (final post in posts) {
        if (post.postId == postId) return post;
      }
    }
    return null;
  }

  @override
  Future<void> updateChannelReadMarker(
    String channelId, {
    required String eventId,
    required int originServerTs,
  }) async {
    await Future.delayed(_latency);
  }

  @override
  Future<AsGroupResult> createGroup({
    required String name,
    required List<String> invite,
    String avatarUrl = '',
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
  Future<AsGroupResult> updateGroupProfile({
    required String roomId,
    String name = '',
    String topic = '',
    String avatarUrl = '',
  }) async {
    await Future.delayed(_latency);
    return AsGroupResult(
      roomId: roomId.trim(),
      name: name.trim().isEmpty ? '群聊' : name.trim(),
      memberCount: 1,
      invitedCount: 0,
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
  Future<void> removeGroupMember({
    required String roomId,
    required String peerMxid,
  }) async {
    await Future.delayed(_latency);
  }

  @override
  Future<void> muteGroup(String roomId) async {
    await Future.delayed(_latency);
  }

  @override
  Future<void> unmuteGroup(String roomId) async {
    await Future.delayed(_latency);
  }

  @override
  Future<void> muteGroupMember({
    required String roomId,
    required String userId,
  }) async {
    await Future.delayed(_latency);
  }

  @override
  Future<void> unmuteGroupMember({
    required String roomId,
    required String userId,
  }) async {
    await Future.delayed(_latency);
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
      productConversation: _mockProductConversation(
        roomId: roomId,
        kind: asConversationKindGroup,
        title: groupName.trim().isEmpty ? '群聊' : groupName.trim(),
      ),
    );
  }

  @override
  Future<void> leaveGroup(String roomId) async {
    await Future.delayed(_latency);
  }

  @override
  Future<void> dissolveGroup(String roomId) => leaveGroup(roomId);

  @override
  Future<void> updateReadMarker(
    String roomId,
    String eventId,
    DateTime timestamp,
  ) async {
    await Future.delayed(_latency);
  }
}

AsConversation _mockProductConversation({
  required String roomId,
  required String kind,
  required String title,
}) {
  final trimmedRoomId = roomId.trim();
  return AsConversation(
    conversationId: '${kind}_${trimmedRoomId.hashCode}',
    roomId: trimmedRoomId,
    kind: kind,
    lifecycle: 'active',
    title: title.trim(),
    avatarUrl: '',
    capabilities: const AsConversationCapabilities(
      open: true,
      send: true,
      invite: true,
      manageMembers: true,
    ),
  );
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

String _channelReactionKey(String channelId, String postId) =>
    '${channelId.trim()}|${postId.trim()}|like';

String _channelCommentReactionKey(
  String channelId,
  String postId,
  String commentId,
) =>
    '${channelId.trim()}|${postId.trim()}|${commentId.trim()}|like';

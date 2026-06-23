// P2P product API 客户端 —— 对应 INTERFACE_SPEC.md §5 / §6
//
// Matrix 标准协议不覆盖的能力（Agent 配置、关注系统、Portal 状态）
// 由 Direxio P2P backend 的 P2P product API 补齐，端点统一走 `https://{domain}/_p2p/`
// 前缀。当前后端统一返回 `access_token`，P2P API 和 Matrix SDK 使用同一个
// 用户 token。
//
// 本文件只定义抽象接口与数据模型；真实 HTTP 实现在 http_as_client.dart。

import 'dart:convert';

const groupInvitePolicyOwnerAdmin = 'owner_admin';
const groupInvitePolicyAllMembers = 'all_members';
const asCallMediaTypeVoice = 'voice';
const asCallMediaTypeVideo = 'video';
const asCallStateRinging = 'ringing';
const asCallStateConnected = 'connected';
const asCallStateEnded = 'ended';
const asCallStateMissed = 'missed';
const asCallStateFailed = 'failed';
const asChannelVisibilityPublic = 'public';
const asChannelVisibilityPrivate = 'private';
const asChannelJoinPolicyOpen = 'open';
const asChannelJoinPolicyApproval = 'approval';
const asChannelJoinPolicyInvite = 'invite';
const asChannelMemberStatusJoined = 'joined';
const asChannelMemberStatusInvite = 'invite';
const asChannelMemberStatusPending = 'pending';
const asChannelMemberStatusRejected = 'rejected';
const asChannelMemberStatusApproved = 'approved';
const asChannelMemberStatusJoining = 'joining';
const asChannelMemberStatusJoinFailed = 'join_failed';
const asChannelRoleOwner = 'owner';
const asChannelRoleAdmin = 'admin';
const asChannelRoleMember = 'member';
const asChannelTypeChat = 'chat';
const asChannelTypePost = 'post';

// ─────────────────────────── 数据模型 ───────────────────────────

class AsPortalSession {
  const AsPortalSession({
    required this.accessToken,
    required this.userId,
    required this.homeserver,
    this.deviceId,
    this.agentRoomId,
    this.initialized,
    this.passwordInitialized,
    this.profileInitialized,
    this.accountInitialized,
    this.setupCompleted,
    this.alreadyInitialized,
    this.initializationCompleted,
  });

  final String accessToken;
  final String userId;
  final String homeserver;
  final String? deviceId;
  final String? agentRoomId;
  final bool? initialized;
  final bool? passwordInitialized;
  final bool? profileInitialized;
  final bool? accountInitialized;
  final bool? setupCompleted;
  final bool? alreadyInitialized;
  final bool? initializationCompleted;

  factory AsPortalSession.fromJson(Map<String, dynamic> json) {
    return AsPortalSession(
      accessToken: json['access_token'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      homeserver: json['homeserver'] as String? ?? '',
      deviceId: json['device_id'] as String?,
      agentRoomId: json['agent_room_id'] as String?,
      initialized: _parseNullableBool(json['initialized']),
      passwordInitialized: _parseNullableBool(json['password_initialized']),
      profileInitialized: _parseNullableBool(json['profile_initialized']),
      accountInitialized: _parseNullableBool(json['account_initialized']),
      setupCompleted: _parseNullableBool(json['setup_completed']),
      alreadyInitialized: _parseNullableBool(json['already_initialized']),
      initializationCompleted:
          _parseNullableBool(json['initialization_completed']),
    );
  }
}

/// §5.2 Agent 配置
class AgentConfig {
  const AgentConfig({required this.displayName, required this.contextWindow});
  final String displayName;
  final int contextWindow;

  factory AgentConfig.fromJson(Map<String, dynamic> j) => AgentConfig(
        displayName: j['display_name'] as String? ?? '小A',
        contextWindow: j['context_window'] as int? ?? 20,
      );

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'context_window': contextWindow,
      };

  AgentConfig copyWith({String? displayName, int? contextWindow}) =>
      AgentConfig(
        displayName: displayName ?? this.displayName,
        contextWindow: contextWindow ?? this.contextWindow,
      );
}

/// §5.3 Agent 在线状态
class AgentStatus {
  const AgentStatus({
    required this.connected,
    required this.lastSeen,
    required this.roomsJoined,
    required this.messagesToday,
  });
  final bool connected;
  final DateTime? lastSeen;
  final int roomsJoined;
  final int messagesToday;

  factory AgentStatus.fromJson(Map<String, dynamic> j) => AgentStatus(
        connected: j['connected'] as bool? ?? false,
        lastSeen: j['last_seen'] != null
            ? DateTime.parse(j['last_seen'] as String)
            : null,
        roomsJoined: j['rooms_joined'] as int? ?? 0,
        messagesToday: j['messages_today'] as int? ?? 0,
      );
}

/// §5.4 关注列表单项
class FollowEntry {
  const FollowEntry({
    required this.domain,
    required this.name,
    required this.followedAt,
  });
  final String domain;
  final String name;
  final DateTime? followedAt;

  factory FollowEntry.fromJson(Map<String, dynamic> j) => FollowEntry(
        domain: j['domain'] as String,
        name: j['name'] as String? ?? '',
        followedAt: j['followed_at'] != null
            ? DateTime.tryParse(j['followed_at'] as String)
            : null,
      );
}

class AsFavoriteMessageDraft {
  const AsFavoriteMessageDraft({
    required this.roomId,
    required this.eventId,
    required this.roomType,
    required this.messageType,
    this.senderId = '',
    this.senderName = '',
    this.senderAvatarUrl = '',
    this.body = '',
    this.url = '',
    this.filename = '',
    this.mimeType = '',
    this.size = 0,
    this.thumbnailUrl = '',
    this.thumbnailMimeType = '',
    this.thumbnailSize = 0,
    this.width = 0,
    this.height = 0,
    this.durationMs = 0,
    this.originServerTs = 0,
    this.chatRecord = const {},
  });

  final String roomId;
  final String eventId;
  final String roomType;
  final String messageType;
  final String senderId;
  final String senderName;
  final String senderAvatarUrl;
  final String body;
  final String url;
  final String filename;
  final String mimeType;
  final int size;
  final String thumbnailUrl;
  final String thumbnailMimeType;
  final int thumbnailSize;
  final int width;
  final int height;
  final int durationMs;
  final int originServerTs;
  final Map<String, Object?> chatRecord;

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId.trim(),
      'event_id': eventId.trim(),
      'room_type': roomType.trim(),
      'message_type': messageType.trim(),
      'sender_id': senderId.trim(),
      'sender_name': senderName.trim(),
      if (senderAvatarUrl.trim().isNotEmpty)
        'sender_avatar_url': senderAvatarUrl.trim(),
      'body': body.trim(),
      'url': url.trim(),
      'filename': filename.trim(),
      'mime_type': mimeType.trim(),
      'size': size,
      'thumbnail_url': thumbnailUrl.trim(),
      'thumbnail_mime_type': thumbnailMimeType.trim(),
      'thumbnail_size': thumbnailSize,
      'width': width,
      'height': height,
      'duration_ms': durationMs,
      'origin_server_ts': originServerTs,
      if (chatRecord.isNotEmpty) 'chat_record': chatRecord,
    };
  }
}

class AsFavoriteMessage {
  const AsFavoriteMessage({
    required this.id,
    required this.ownerUserId,
    required this.roomId,
    required this.eventId,
    required this.roomType,
    required this.messageType,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl = '',
    required this.body,
    required this.url,
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.thumbnailUrl,
    required this.thumbnailMimeType,
    required this.thumbnailSize,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.originServerTs,
    required this.favoritedAt,
    this.chatRecord = const {},
  });

  final int id;
  final String ownerUserId;
  final String roomId;
  final String eventId;
  final String roomType;
  final String messageType;
  final String senderId;
  final String senderName;
  final String senderAvatarUrl;
  final String body;
  final String url;
  final String filename;
  final String mimeType;
  final int size;
  final String thumbnailUrl;
  final String thumbnailMimeType;
  final int thumbnailSize;
  final int width;
  final int height;
  final int durationMs;
  final int originServerTs;
  final DateTime? favoritedAt;
  final Map<String, Object?> chatRecord;

  factory AsFavoriteMessage.fromJson(Map<String, dynamic> json) {
    return AsFavoriteMessage(
      id: json['id'] as int? ?? 0,
      ownerUserId: json['owner_user_id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      roomType: json['room_type'] as String? ?? '',
      messageType: json['message_type'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? '',
      senderAvatarUrl: json['sender_avatar_url'] as String? ??
          json['sender_avatar'] as String? ??
          json['avatar_url'] as String? ??
          '',
      body: json['body'] as String? ?? '',
      url: json['url'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      thumbnailMimeType: json['thumbnail_mime_type'] as String? ?? '',
      thumbnailSize: json['thumbnail_size'] as int? ?? 0,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      durationMs: json['duration_ms'] as int? ?? 0,
      originServerTs: json['origin_server_ts'] as int? ?? 0,
      favoritedAt: _parseDateTime(json['favorited_at']),
      chatRecord: _chatRecordMap(
        json['chat_record'],
        fallback: json['chat_record_json'],
      ),
    );
  }
}

class ContactEntry {
  const ContactEntry({
    required this.peerMxid,
    required this.displayName,
    required this.domain,
    required this.roomId,
    required this.status,
    this.visibleAfterTs = 0,
    this.deletedEventIds = const [],
    this.operation = const AsOperation(),
    this.productConversation,
  });

  final String peerMxid;
  final String displayName;
  final String domain;
  final String roomId;
  final String status;
  final int visibleAfterTs;
  final List<String> deletedEventIds;
  final AsOperation operation;
  final AsConversation? productConversation;

  factory ContactEntry.fromJson(Map<String, dynamic> j) => ContactEntry(
        peerMxid: j['peer_mxid'] as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        domain: j['domain'] as String? ?? '',
        roomId: j['room_id'] as String? ?? '',
        status: j['status'] as String? ?? '',
        visibleAfterTs: j['visible_after_ts'] as int? ?? 0,
        deletedEventIds: _parseStringList(j['deleted_event_ids']),
        operation: AsOperation.fromJson(
          (j['operation'] as Map?)?.cast<String, dynamic>(),
        ),
        productConversation: _parseConversation(j['conversation']),
      );
}

/// Portal owner profile managed by Direxio P2P backend.
///
/// `userId` remains Matrix's technical MXID, while `displayName` is the
/// product-visible name users set in the app.
class OwnerProfile {
  const OwnerProfile({
    required this.userId,
    required this.displayName,
    required this.domain,
    this.avatarUrl = '',
    this.gender = '',
    this.birthday = '',
    this.phone = '',
    this.email = '',
  });

  final String userId;
  final String displayName;
  final String domain;
  final String avatarUrl;
  final String gender;
  final String birthday;
  final String phone;
  final String email;

  factory OwnerProfile.fromJson(Map<String, dynamic> json) {
    return OwnerProfile(
      userId: json['user_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      birthday: json['birthday'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

/// §5.5 Portal 整体状态
class PortalStatus {
  const PortalStatus({
    this.dendrite = 'unknown',
    this.federation = 'unknown',
    this.agent = 'unknown',
    required this.uptime,
    this.initialized,
    this.userId = '',
    this.homeserver = '',
    this.storeMode = '',
    this.projectorStarted,
    this.policyIndexMode = '',
    this.policyIndexReady,
    this.eventStreamReady,
  });

  /// "connected" / "disconnected"
  final String dendrite;

  /// "ok" / "degraded" / ...
  final String federation;

  /// "connected" / "disconnected"
  final String agent;

  /// 人类可读的运行时长，如 "3d 5h"
  final String uptime;

  /// Unified `/_p2p` portal status fields.
  final bool? initialized;
  final String userId;
  final String homeserver;
  final String storeMode;
  final bool? projectorStarted;
  final String policyIndexMode;
  final bool? policyIndexReady;
  final bool? eventStreamReady;

  factory PortalStatus.fromJson(Map<String, dynamic> j) => PortalStatus(
        dendrite: j['dendrite'] as String? ?? 'unknown',
        federation: j['federation'] as String? ?? 'unknown',
        agent: j['agent'] as String? ?? 'unknown',
        uptime: j['uptime'] as String? ?? '',
        initialized: _parseNullableBool(j['initialized']),
        userId: j['user_id'] as String? ?? '',
        homeserver: j['homeserver'] as String? ?? '',
        storeMode: j['store_mode'] as String? ?? '',
        projectorStarted: _parseNullableBool(j['projector_started']),
        policyIndexMode: j['policy_index_mode'] as String? ?? '',
        policyIndexReady: _parseNullableBool(j['policy_index_ready']),
        eventStreamReady: _parseNullableBool(j['event_stream_ready']),
      );

  bool get allHealthy {
    final legacyHealthy = dendrite == 'connected' &&
        federation == 'ok' &&
        agent.startsWith('connected');
    final hasUnifiedFields = initialized != null ||
        userId.trim().isNotEmpty ||
        homeserver.trim().isNotEmpty ||
        storeMode.trim().isNotEmpty ||
        projectorStarted != null ||
        policyIndexMode.trim().isNotEmpty ||
        policyIndexReady != null ||
        eventStreamReady != null;
    if (!hasUnifiedFields) return legacyHealthy;
    return initialized != false &&
        userId.trim().isNotEmpty &&
        homeserver.trim().isNotEmpty &&
        storeMode.trim().isNotEmpty &&
        projectorStarted != false &&
        policyIndexReady != false &&
        eventStreamReady != false;
  }
}

class AsEventStreamEvent {
  const AsEventStreamEvent({
    required this.seq,
    required this.type,
    required this.createdAt,
    this.roomId = '',
    this.eventId = '',
    this.payload = const {},
  });

  final int seq;
  final String type;
  final String roomId;
  final String eventId;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  factory AsEventStreamEvent.fromJson(Map<String, dynamic> json) {
    return AsEventStreamEvent(
      seq: _parseInt(json['seq']),
      type: json['type'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: _parseDateTime(json['created_at']),
    );
  }
}

bool isAsChannelMemberJoined(String status) {
  return _normalizeChannelMemberStatus(status) == asChannelMemberStatusJoined;
}

bool isAsChannelMemberAwaitingJoin(String status) {
  final normalized = _normalizeChannelMemberStatus(status);
  return normalized == asChannelMemberStatusPending ||
      normalized == asChannelMemberStatusInvite ||
      normalized == asChannelMemberStatusApproved ||
      normalized == asChannelMemberStatusJoining;
}

bool isAsChannelMemberJoinFailed(String status) {
  return _normalizeChannelMemberStatus(status) ==
      asChannelMemberStatusJoinFailed;
}

/// P2P product API action.
class AsSyncBootstrap {
  const AsSyncBootstrap({
    required this.syncedAt,
    required this.user,
    required this.rooms,
    required this.contacts,
    required this.groups,
    required this.channels,
    required this.pending,
    this.agentRoomId = '',
  });

  final DateTime syncedAt;
  final AsSyncUser user;
  final String agentRoomId;
  final List<AsSyncRoomSummary> rooms;
  final List<AsSyncContact> contacts;
  final List<AsSyncRoomSummary> groups;
  final List<AsSyncRoomSummary> channels;
  final AsSyncPending pending;

  factory AsSyncBootstrap.fromJson(Map<String, dynamic> json) {
    return AsSyncBootstrap(
      syncedAt: _parseDateTime(json['synced_at']) ?? DateTime.now().toUtc(),
      user: AsSyncUser.fromJson(
        (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      agentRoomId: json['agent_room_id'] as String? ?? '',
      rooms: _parseList(json['rooms'], AsSyncRoomSummary.fromJson),
      contacts: _parseList(json['contacts'], AsSyncContact.fromJson),
      groups: _parseList(json['groups'], AsSyncRoomSummary.fromJson),
      channels: _parseList(json['channels'], AsSyncRoomSummary.fromJson),
      pending: AsSyncPending.fromJson(
        (json['pending'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'synced_at': syncedAt.toUtc().toIso8601String(),
      'user': user.toJson(),
      if (agentRoomId.trim().isNotEmpty) 'agent_room_id': agentRoomId.trim(),
      'rooms': rooms.map((room) => room.toJson()).toList(),
      'contacts': contacts.map((contact) => contact.toJson()).toList(),
      'groups': groups.map((group) => group.toJson()).toList(),
      'channels': channels.map((channel) => channel.toJson()).toList(),
      'pending': pending.toJson(),
    };
  }
}

const asConversationKindDirect = 'direct';
const asConversationKindGroup = 'group';
const asConversationKindChannel = 'channel';
const asConversationKindAgent = 'agent';

class AsOperation {
  const AsOperation({
    this.action = '',
    this.status = '',
    this.roomId = '',
    this.conversationId = '',
  });

  final String action;
  final String status;
  final String roomId;
  final String conversationId;

  bool get isEmpty =>
      action.trim().isEmpty &&
      status.trim().isEmpty &&
      roomId.trim().isEmpty &&
      conversationId.trim().isEmpty;

  factory AsOperation.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const AsOperation();
    return AsOperation(
      action: json['action'] as String? ?? '',
      status: json['status'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
    );
  }
}

class AsConversation {
  const AsConversation({
    required this.conversationId,
    required this.roomId,
    required this.kind,
    required this.lifecycle,
    required this.title,
    required this.avatarUrl,
    this.peerMxid = '',
    this.lastEventId = '',
    this.lastMessage = '',
    this.lastActivityAt,
    this.projectionState = '',
    this.projectionReason = '',
    this.memberCount = 0,
    this.membership = '',
    this.relationshipStatus = '',
    this.role = '',
    this.hydrationState = '',
    this.hydrationReason = '',
    this.capabilities = const AsConversationCapabilities(),
  });

  final String conversationId;
  final String roomId;
  final String kind;
  final String lifecycle;
  final String peerMxid;
  final String title;
  final String avatarUrl;
  final String lastEventId;
  final String lastMessage;
  final DateTime? lastActivityAt;
  final String projectionState;
  final String projectionReason;
  final int memberCount;
  final String membership;
  final String relationshipStatus;
  final String role;
  final String hydrationState;
  final String hydrationReason;
  final AsConversationCapabilities capabilities;

  bool get isDirect => kind == asConversationKindDirect;
  bool get isGroup => kind == asConversationKindGroup;
  bool get isChannel => kind == asConversationKindChannel;
  bool get isAgent => kind == asConversationKindAgent;
  bool get canOpen => capabilities.open;
  bool get canSend => capabilities.send;
  bool get canSendMedia => capabilities.sendMedia;
  bool get canCall => capabilities.call;
  bool get canInvite => capabilities.invite;
  bool get canManageMembers => capabilities.manageMembers;
  bool get canRename => capabilities.rename;
  bool get canRemoveMembers => capabilities.removeMembers;
  bool get canLeave => capabilities.leave;
  bool get canDelete => capabilities.delete;
  bool get canCreatePost => capabilities.postCreate;
  bool get canCreateComment => capabilities.commentCreate;
  bool get canToggleReaction => capabilities.reactionToggle;
  bool get canRecallPost => capabilities.postRecall;
  bool get canRecallComment => capabilities.commentRecall;
  bool get commentsEnabled => capabilities.commentsEnabled;

  factory AsConversation.fromJson(Map<String, dynamic> json) {
    return AsConversation(
      conversationId: json['conversation_id'] as String? ?? '',
      roomId:
          json['matrix_room_id'] as String? ?? json['room_id'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      lifecycle: json['lifecycle'] as String? ?? '',
      peerMxid: json['peer_mxid'] as String? ?? '',
      title: json['title'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      lastEventId: json['last_event_id'] as String? ?? '',
      lastMessage: json['last_message'] as String? ?? '',
      lastActivityAt: _parseUnixMillisDateTime(json['last_activity_at']),
      projectionState: json['projection_state'] as String? ?? '',
      projectionReason: json['projection_reason'] as String? ?? '',
      memberCount: _parseInt(json['member_count']),
      membership: json['membership'] as String? ?? '',
      relationshipStatus: json['relationship_status'] as String? ?? '',
      role: json['role'] as String? ?? '',
      hydrationState: json['hydration_state'] as String? ?? '',
      hydrationReason: json['hydration_reason'] as String? ?? '',
      capabilities: AsConversationCapabilities.fromJson(
        (json['capabilities'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

class AsConversationCapabilities {
  const AsConversationCapabilities({
    this.open = false,
    this.send = false,
    this.sendMedia = false,
    this.call = false,
    this.invite = false,
    this.manageMembers = false,
    this.rename = false,
    this.removeMembers = false,
    this.leave = false,
    this.delete = false,
    this.postCreate = false,
    this.commentCreate = false,
    this.reactionToggle = false,
    this.postRecall = false,
    this.commentRecall = false,
    this.commentsEnabled = false,
  });

  final bool open;
  final bool send;
  final bool sendMedia;
  final bool call;
  final bool invite;
  final bool manageMembers;
  final bool rename;
  final bool removeMembers;
  final bool leave;
  final bool delete;
  final bool postCreate;
  final bool commentCreate;
  final bool reactionToggle;
  final bool postRecall;
  final bool commentRecall;
  final bool commentsEnabled;

  factory AsConversationCapabilities.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AsConversationCapabilities();
    return AsConversationCapabilities(
      open: json['open'] == true,
      send: json['send'] == true,
      sendMedia: json['send_media'] == true,
      call: json['call'] == true,
      invite: json['invite'] == true,
      manageMembers: json['manage_members'] == true,
      rename: json['rename'] == true,
      removeMembers: json['remove_members'] == true,
      leave: json['leave'] == true,
      delete: json['delete'] == true,
      postCreate: json['post_create'] == true,
      commentCreate: json['comment_create'] == true,
      reactionToggle: json['reaction_toggle'] == true,
      postRecall: json['post_recall'] == true,
      commentRecall: json['comment_recall'] == true,
      commentsEnabled: json['comments_enabled'] == true,
    );
  }
}

AsConversation? _parseConversation(Object? value) {
  final json = (value as Map?)?.cast<String, dynamic>();
  if (json == null || json.isEmpty) return null;
  final conversation = AsConversation.fromJson(json);
  if (conversation.conversationId.trim().isEmpty &&
      conversation.roomId.trim().isEmpty) {
    return null;
  }
  return conversation;
}

class AsSyncUser {
  const AsSyncUser({required this.userId});

  final String userId;

  factory AsSyncUser.fromJson(Map<String, dynamic> json) {
    return AsSyncUser(userId: json['user_id'] as String? ?? '');
  }

  Map<String, dynamic> toJson() => {'user_id': userId};
}

class AsSyncContact {
  const AsSyncContact({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    this.roomId = '',
    this.domain = '',
    this.status = '',
    this.visibleAfterTs = 0,
    this.deletedEventIds = const [],
  });

  final String userId;
  final String displayName;
  final String avatarUrl;
  final String roomId;
  final String domain;
  final String status;
  final int visibleAfterTs;
  final List<String> deletedEventIds;

  factory AsSyncContact.fromJson(Map<String, dynamic> json) {
    return AsSyncContact(
      userId: json['user_id'] as String? ?? json['peer_mxid'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      status: json['status'] as String? ?? '',
      visibleAfterTs: json['visible_after_ts'] as int? ?? 0,
      deletedEventIds: _parseStringList(json['deleted_event_ids']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'room_id': roomId,
      'domain': domain,
      'status': status,
      'visible_after_ts': visibleAfterTs,
      'deleted_event_ids': deletedEventIds,
    };
  }
}

class AsSyncRoomSummary {
  const AsSyncRoomSummary({
    required this.roomId,
    required this.name,
    required this.avatarUrl,
    required this.unreadCount,
    required this.lastActivityAt,
    this.channelId = '',
    this.homeDomain = '',
    this.description = '',
    this.topic = '',
    this.isOwned = false,
    this.tags = const [],
    this.invitePolicy = groupInvitePolicyAllMembers,
    this.visibility = asChannelVisibilityPublic,
    this.joinPolicy = asChannelJoinPolicyOpen,
    this.commentsEnabled = true,
    this.muted = false,
    this.channelType = asChannelTypePost,
    this.role = '',
    this.memberStatus = '',
    this.lifecycle = '',
    this.memberCount = 0,
    this.pendingJoinCount = 0,
  });

  final String channelId;
  final String roomId;
  final String name;
  final String homeDomain;
  final String avatarUrl;
  final int unreadCount;
  final DateTime? lastActivityAt;
  final String description;
  final String topic;
  final bool isOwned;
  final List<String> tags;
  final String invitePolicy;
  final String visibility;
  final String joinPolicy;
  final bool commentsEnabled;
  final bool muted;
  final String channelType;
  final String role;
  final String memberStatus;
  final String lifecycle;
  final int memberCount;
  final int pendingJoinCount;

  factory AsSyncRoomSummary.fromJson(Map<String, dynamic> json) {
    final role = json['role'] as String? ?? '';
    return AsSyncRoomSummary(
      channelId: json['channel_id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      homeDomain: json['home_domain'] as String? ?? '',
      name: _parseChannelDisplayName(json),
      avatarUrl: json['avatar_url'] as String? ?? '',
      unreadCount: _parseInt(json['unread_count']),
      lastActivityAt:
          _parseDateTime(json['last_activity_at'] ?? json['created_at']),
      description:
          json['description'] as String? ?? json['intro'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      isOwned: json['is_owned'] as bool? ??
          role == asChannelRoleOwner || role == asChannelRoleAdmin,
      tags: (json['tags'] as List? ?? const [])
          .whereType<String>()
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false),
      invitePolicy: _normalizeGroupInvitePolicy(
        json['invite_policy'] as String? ?? '',
      ),
      visibility:
          _normalizeChannelVisibility(json['visibility'] as String? ?? ''),
      joinPolicy:
          _normalizeChannelJoinPolicy(json['join_policy'] as String? ?? ''),
      commentsEnabled: json['comments_enabled'] as bool? ?? true,
      muted: _parseNullableBool(json['muted']) ?? false,
      channelType:
          normalizeAsChannelType(json['channel_type'] as String? ?? ''),
      role: role,
      memberStatus: _normalizeChannelMemberStatus(
        _firstString(json, const ['member_status', 'membership', 'status']),
      ),
      lifecycle: json['lifecycle'] as String? ?? '',
      memberCount: _parseInt(json['member_count']),
      pendingJoinCount: _parseInt(json['pending_join_count']),
    );
  }

  AsSyncRoomSummary withInvitePolicy(String policy) {
    return AsSyncRoomSummary(
      channelId: channelId,
      roomId: roomId,
      homeDomain: homeDomain,
      name: name,
      avatarUrl: avatarUrl,
      unreadCount: unreadCount,
      lastActivityAt: lastActivityAt,
      description: description,
      topic: topic,
      isOwned: isOwned,
      tags: tags,
      invitePolicy: _normalizeGroupInvitePolicy(policy),
      visibility: visibility,
      joinPolicy: joinPolicy,
      commentsEnabled: commentsEnabled,
      muted: muted,
      channelType: channelType,
      role: role,
      memberStatus: memberStatus,
      lifecycle: lifecycle,
      memberCount: memberCount,
      pendingJoinCount: pendingJoinCount,
    );
  }

  AsSyncRoomSummary withName(String nextName) {
    return AsSyncRoomSummary(
      channelId: channelId,
      roomId: roomId,
      homeDomain: homeDomain,
      name: nextName.trim().isEmpty ? name : nextName.trim(),
      avatarUrl: avatarUrl,
      unreadCount: unreadCount,
      lastActivityAt: lastActivityAt,
      description: description,
      topic: topic,
      isOwned: isOwned,
      tags: tags,
      invitePolicy: invitePolicy,
      visibility: visibility,
      joinPolicy: joinPolicy,
      commentsEnabled: commentsEnabled,
      muted: muted,
      channelType: channelType,
      role: role,
      memberStatus: memberStatus,
      lifecycle: lifecycle,
      memberCount: memberCount,
      pendingJoinCount: pendingJoinCount,
    );
  }

  AsSyncRoomSummary withProfile({
    String? name,
    String? avatarUrl,
    String? topic,
  }) {
    return AsSyncRoomSummary(
      channelId: channelId,
      roomId: roomId,
      homeDomain: homeDomain,
      name: name?.trim().isNotEmpty == true ? name!.trim() : this.name,
      avatarUrl: avatarUrl?.trim().isNotEmpty == true
          ? avatarUrl!.trim()
          : this.avatarUrl,
      unreadCount: unreadCount,
      lastActivityAt: lastActivityAt,
      description: description,
      topic: topic?.trim().isNotEmpty == true ? topic!.trim() : this.topic,
      isOwned: isOwned,
      tags: tags,
      invitePolicy: invitePolicy,
      visibility: visibility,
      joinPolicy: joinPolicy,
      commentsEnabled: commentsEnabled,
      muted: muted,
      channelType: channelType,
      role: role,
      memberStatus: memberStatus,
      lifecycle: lifecycle,
      memberCount: memberCount,
      pendingJoinCount: pendingJoinCount,
    );
  }

  AsSyncRoomSummary withUnreadCount(int count) {
    return AsSyncRoomSummary(
      channelId: channelId,
      roomId: roomId,
      homeDomain: homeDomain,
      name: name,
      avatarUrl: avatarUrl,
      unreadCount: count < 0 ? 0 : count,
      lastActivityAt: lastActivityAt,
      description: description,
      topic: topic,
      isOwned: isOwned,
      tags: tags,
      invitePolicy: invitePolicy,
      visibility: visibility,
      joinPolicy: joinPolicy,
      commentsEnabled: commentsEnabled,
      muted: muted,
      channelType: channelType,
      role: role,
      memberStatus: memberStatus,
      lifecycle: lifecycle,
      memberCount: memberCount,
      pendingJoinCount: pendingJoinCount,
    );
  }

  AsSyncRoomSummary withCommentsEnabled(bool enabled) {
    return AsSyncRoomSummary(
      channelId: channelId,
      roomId: roomId,
      homeDomain: homeDomain,
      name: name,
      avatarUrl: avatarUrl,
      unreadCount: unreadCount,
      lastActivityAt: lastActivityAt,
      description: description,
      topic: topic,
      isOwned: isOwned,
      tags: tags,
      invitePolicy: invitePolicy,
      visibility: visibility,
      joinPolicy: joinPolicy,
      commentsEnabled: enabled,
      muted: muted,
      channelType: channelType,
      role: role,
      memberStatus: memberStatus,
      lifecycle: lifecycle,
      memberCount: memberCount,
      pendingJoinCount: pendingJoinCount,
    );
  }

  AsSyncRoomSummary withMuted(bool muted) {
    return AsSyncRoomSummary(
      channelId: channelId,
      roomId: roomId,
      homeDomain: homeDomain,
      name: name,
      avatarUrl: avatarUrl,
      unreadCount: unreadCount,
      lastActivityAt: lastActivityAt,
      description: description,
      topic: topic,
      isOwned: isOwned,
      tags: tags,
      invitePolicy: invitePolicy,
      visibility: visibility,
      joinPolicy: joinPolicy,
      commentsEnabled: commentsEnabled,
      muted: muted,
      channelType: channelType,
      role: role,
      memberStatus: memberStatus,
      lifecycle: lifecycle,
      memberCount: memberCount,
      pendingJoinCount: pendingJoinCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (channelId.trim().isNotEmpty) 'channel_id': channelId,
      'room_id': roomId,
      if (homeDomain.trim().isNotEmpty) 'home_domain': homeDomain,
      'name': name,
      'avatar_url': avatarUrl,
      'unread_count': unreadCount,
      'last_activity_at': lastActivityAt?.toUtc().toIso8601String(),
      if (description.trim().isNotEmpty) 'description': description,
      'topic': topic,
      'is_owned': isOwned,
      'tags': tags,
      'invite_policy': invitePolicy,
      'visibility': visibility,
      'join_policy': joinPolicy,
      'comments_enabled': commentsEnabled,
      'muted': muted,
      'channel_type': channelType,
      if (role.trim().isNotEmpty) 'role': role,
      if (memberStatus.trim().isNotEmpty) 'member_status': memberStatus,
      if (lifecycle.trim().isNotEmpty) 'lifecycle': lifecycle,
      if (memberCount > 0) 'member_count': memberCount,
      if (pendingJoinCount > 0) 'pending_join_count': pendingJoinCount,
    };
  }
}

class AsChannel {
  const AsChannel({
    required this.channelId,
    required this.roomId,
    required this.name,
    this.homeDomain = '',
    this.description = '',
    this.avatarUrl = '',
    this.visibility = asChannelVisibilityPublic,
    this.joinPolicy = asChannelJoinPolicyOpen,
    this.commentsEnabled = true,
    this.muted = false,
    this.channelType = asChannelTypePost,
    this.role = '',
    this.memberStatus = '',
    this.lifecycle = '',
    this.memberCount = 0,
    this.pendingJoinCount = 0,
    this.tags = const [],
    this.latestActivityAt,
    this.productConversation,
  });

  final String channelId;
  final String roomId;
  final String name;
  final String homeDomain;
  final String description;
  final String avatarUrl;
  final String visibility;
  final String joinPolicy;
  final bool commentsEnabled;
  final bool muted;
  final String channelType;
  final String role;
  final String memberStatus;
  final String lifecycle;
  final int memberCount;
  final int pendingJoinCount;
  final List<String> tags;
  final DateTime? latestActivityAt;
  final AsConversation? productConversation;

  factory AsChannel.fromJson(Map<String, dynamic> json) {
    return AsChannel(
      channelId: json['channel_id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      name: _parseChannelDisplayName(json),
      homeDomain: json['home_domain'] as String? ?? '',
      description: json['description'] as String? ??
          json['intro'] as String? ??
          json['topic'] as String? ??
          '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      visibility:
          _normalizeChannelVisibility(json['visibility'] as String? ?? ''),
      joinPolicy:
          _normalizeChannelJoinPolicy(json['join_policy'] as String? ?? ''),
      commentsEnabled: json['comments_enabled'] as bool? ?? true,
      muted: _parseNullableBool(json['muted']) ?? false,
      channelType:
          normalizeAsChannelType(json['channel_type'] as String? ?? ''),
      role: json['role'] as String? ?? '',
      memberStatus: _normalizeChannelMemberStatus(
        _firstString(json, const ['member_status', 'membership', 'status']),
      ),
      lifecycle: json['lifecycle'] as String? ?? '',
      memberCount: _parseInt(json['member_count']),
      pendingJoinCount: _parseInt(json['pending_join_count']),
      tags: _parseStringList(json['tags']),
      latestActivityAt:
          _parseDateTime(json['last_activity_at'] ?? json['created_at']),
      productConversation: _parseConversation(json['conversation']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_id': channelId,
      'room_id': roomId,
      if (homeDomain.trim().isNotEmpty) 'home_domain': homeDomain,
      'name': name,
      if (description.trim().isNotEmpty) 'description': description,
      if (avatarUrl.trim().isNotEmpty) 'avatar_url': avatarUrl,
      'visibility': visibility,
      'join_policy': joinPolicy,
      'comments_enabled': commentsEnabled,
      'muted': muted,
      'channel_type': channelType,
      if (role.trim().isNotEmpty) 'role': role,
      if (memberStatus.trim().isNotEmpty) 'member_status': memberStatus,
      if (lifecycle.trim().isNotEmpty) 'lifecycle': lifecycle,
      if (memberCount > 0) 'member_count': memberCount,
      if (pendingJoinCount > 0) 'pending_join_count': pendingJoinCount,
      'tags': tags,
      if (latestActivityAt != null)
        'last_activity_at': latestActivityAt!.toUtc().toIso8601String(),
    };
  }
}

class AsChannelShareDraft {
  const AsChannelShareDraft({
    required this.channelId,
    required this.roomId,
    this.grantId = '',
    this.shareRoomId = '',
    required this.homeDomain,
    required this.name,
    this.description = '',
    this.avatarUrl = '',
    this.visibility = asChannelVisibilityPublic,
    this.joinPolicy = asChannelJoinPolicyOpen,
    this.commentsEnabled = true,
    this.channelType = asChannelTypePost,
    this.tags = const [],
  });

  final String channelId;
  final String roomId;
  final String grantId;
  final String shareRoomId;
  final String homeDomain;
  final String name;
  final String description;
  final String avatarUrl;
  final String visibility;
  final String joinPolicy;
  final bool commentsEnabled;
  final String channelType;
  final List<String> tags;

  Map<String, dynamic> toJson() {
    return {
      'channel_id': channelId.trim(),
      'room_id': roomId.trim(),
      if (grantId.trim().isNotEmpty) 'grant_id': grantId.trim(),
      if (shareRoomId.trim().isNotEmpty) 'share_room_id': shareRoomId.trim(),
      if (homeDomain.trim().isNotEmpty) 'home_domain': homeDomain.trim(),
      'name': name.trim(),
      if (description.trim().isNotEmpty) 'description': description.trim(),
      if (avatarUrl.trim().isNotEmpty) 'avatar_url': avatarUrl.trim(),
      'visibility': _normalizeChannelVisibility(visibility),
      'join_policy': _normalizeChannelJoinPolicy(joinPolicy),
      'comments_enabled': commentsEnabled,
      'channel_type': normalizeAsChannelType(channelType),
      'tags':
          tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList(),
    };
  }
}

class AsChannelInviteGrant {
  const AsChannelInviteGrant({
    required this.grantId,
    required this.roomId,
    required this.channelId,
    required this.shareRoomId,
    this.status = '',
    this.channel,
    this.members = const [],
  });

  final String grantId;
  final String roomId;
  final String channelId;
  final String shareRoomId;
  final String status;
  final AsChannel? channel;
  final List<AsChannelMember> members;

  factory AsChannelInviteGrant.fromJson(Map<String, dynamic> json) {
    final channelJson =
        (json['channel'] as Map?)?.cast<String, dynamic>() ?? const {};
    final grantJson =
        (json['grant'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawMembers = json['members'] as List? ?? const [];
    final grantId = _firstString(json, const ['grant_id', 'id']);
    final nestedGrantId = _firstString(grantJson, const ['grant_id', 'id']);
    final shareRoomId = _firstString(json, const [
      'share_room_id',
      'via_room_id',
    ]);
    final nestedShareRoomId = _firstString(grantJson, const [
      'share_room_id',
      'via_room_id',
    ]);
    return AsChannelInviteGrant(
      grantId: grantId.isNotEmpty ? grantId : nestedGrantId,
      roomId: _firstString(json, const ['room_id']).isNotEmpty
          ? _firstString(json, const ['room_id'])
          : _firstString(grantJson, const ['room_id']),
      channelId: _firstString(json, const ['channel_id']).isNotEmpty
          ? _firstString(json, const ['channel_id'])
          : _firstString(grantJson, const ['channel_id']),
      shareRoomId: shareRoomId.isNotEmpty ? shareRoomId : nestedShareRoomId,
      status: json['status'] as String? ?? '',
      channel: channelJson.isEmpty ? null : AsChannel.fromJson(channelJson),
      members: rawMembers
          .whereType<Map>()
          .map((item) => AsChannelMember.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class AsChannelPost {
  const AsChannelPost({
    required this.postId,
    required this.channelId,
    required this.roomId,
    required this.eventId,
    required this.authorId,
    required this.messageType,
    required this.body,
    required this.originServerTs,
    this.authorName = '',
    this.authorAvatarUrl = '',
    this.media = const {},
    this.commentCount = 0,
    this.reactionCount = 0,
    this.reactedByMe = false,
    this.operation = const AsOperation(),
    this.productConversation,
  });

  final String postId;
  final String channelId;
  final String roomId;
  final String eventId;
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String messageType;
  final String body;
  final Map<String, Object?> media;
  final int originServerTs;
  final int commentCount;
  final int reactionCount;
  final bool reactedByMe;
  final AsOperation operation;
  final AsConversation? productConversation;

  AsChannelPost copyWith({
    String? postId,
    String? channelId,
    String? roomId,
    String? eventId,
    String? authorId,
    String? authorName,
    String? authorAvatarUrl,
    String? messageType,
    String? body,
    Map<String, Object?>? media,
    int? originServerTs,
    int? commentCount,
    int? reactionCount,
    bool? reactedByMe,
    AsOperation? operation,
    AsConversation? productConversation,
  }) {
    return AsChannelPost(
      postId: postId ?? this.postId,
      channelId: channelId ?? this.channelId,
      roomId: roomId ?? this.roomId,
      eventId: eventId ?? this.eventId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      messageType: messageType ?? this.messageType,
      body: body ?? this.body,
      media: media ?? this.media,
      originServerTs: originServerTs ?? this.originServerTs,
      commentCount: commentCount ?? this.commentCount,
      reactionCount: reactionCount ?? this.reactionCount,
      reactedByMe: reactedByMe ?? this.reactedByMe,
      operation: operation ?? this.operation,
      productConversation: productConversation ?? this.productConversation,
    );
  }

  factory AsChannelPost.fromJson(Map<String, dynamic> json) {
    return AsChannelPost(
      postId: json['post_id'] as String? ?? '',
      channelId: json['channel_id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      authorId: _firstString(json, const [
        'author_mxid',
        'author_id',
        'sender_mxid',
        'sender_id',
        'user_mxid',
      ]),
      authorName: _firstString(json, const [
        'author_name',
        'author_display_name',
        'sender_name',
        'display_name',
        'name',
      ]),
      authorAvatarUrl: _firstString(json, const [
        'author_avatar_url',
        'sender_avatar_url',
        'avatar_url',
      ]),
      messageType: json['message_type'] as String? ?? 'text',
      body: json['body'] as String? ?? '',
      media: _objectMapOrJson(json['media_json'] ?? json['media']),
      originServerTs: _parseInt(json['origin_server_ts']),
      commentCount: _parseInt(json['comment_count']),
      reactionCount: _parseInt(json['reaction_count']),
      reactedByMe: json['reacted_by_me'] as bool? ?? false,
      operation: AsOperation.fromJson(
        (json['operation'] as Map?)?.cast<String, dynamic>(),
      ),
      productConversation: _parseConversation(json['conversation']),
    );
  }

  Map<String, dynamic> toJson() => {
        'post_id': postId,
        'channel_id': channelId,
        'room_id': roomId,
        'event_id': eventId,
        'author_mxid': authorId,
        'author_name': authorName,
        if (authorAvatarUrl.trim().isNotEmpty)
          'author_avatar_url': authorAvatarUrl,
        'message_type': messageType,
        'body': body,
        'media': media,
        'origin_server_ts': originServerTs,
        'comment_count': commentCount,
        'reaction_count': reactionCount,
        'reacted_by_me': reactedByMe,
      };
}

class AsChannelReaction {
  const AsChannelReaction({
    required this.postId,
    required this.channelId,
    required this.reaction,
    required this.active,
    required this.reactionCount,
    this.operation = const AsOperation(),
    this.productConversation,
  });

  final String postId;
  final String channelId;
  final String reaction;
  final bool active;
  final int reactionCount;
  final AsOperation operation;
  final AsConversation? productConversation;

  factory AsChannelReaction.fromJson(Map<String, dynamic> json) {
    return AsChannelReaction(
      postId: json['post_id'] as String? ?? '',
      channelId: json['channel_id'] as String? ?? '',
      reaction: json['reaction'] as String? ?? 'like',
      active: json['active'] as bool? ?? false,
      reactionCount: _parseInt(json['reaction_count']),
      operation: AsOperation.fromJson(
        (json['operation'] as Map?)?.cast<String, dynamic>(),
      ),
      productConversation: _parseConversation(json['conversation']),
    );
  }
}

class AsChannelMember {
  const AsChannelMember({
    required this.channelId,
    required this.userMxid,
    required this.role,
    required this.status,
    this.domain = '',
    this.displayName = '',
    this.avatarUrl = '',
    this.joinedAtMs = 0,
  });

  final String channelId;
  final String userMxid;
  final String domain;
  final String displayName;
  final String avatarUrl;
  final String role;
  final String status;
  final int joinedAtMs;

  factory AsChannelMember.fromJson(Map<String, dynamic> json) {
    return AsChannelMember(
      channelId: json['channel_id'] as String? ?? '',
      userMxid: json['user_mxid'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      avatarUrl: _firstString(
        json,
        const ['avatar_url', 'profile_avatar_url', 'user_avatar_url'],
      ),
      role: json['role'] as String? ?? asChannelRoleMember,
      status: _normalizeChannelMemberStatus(
        _firstString(json, const ['status', 'member_status', 'membership']),
      ),
      joinedAtMs: _parseInt(json['joined_at_ms'] ?? json['joined_at']),
    );
  }
}

class AsChannelComment {
  const AsChannelComment({
    required this.commentId,
    required this.postId,
    required this.channelId,
    required this.eventId,
    required this.authorId,
    required this.messageType,
    required this.body,
    required this.originServerTs,
    this.authorName = '',
    this.authorDomain = '',
    this.authorAvatarUrl = '',
    this.media = const {},
    this.replyToCommentId = '',
    this.replyToAuthorId = '',
    this.mentions = const [],
    this.reactionCount = 0,
    this.reactedByMe = false,
    this.operation = const AsOperation(),
    this.productConversation,
  });

  final String commentId;
  final String postId;
  final String channelId;
  final String eventId;
  final String authorId;
  final String authorName;
  final String authorDomain;
  final String authorAvatarUrl;
  final String messageType;
  final String body;
  final Map<String, Object?> media;
  final String replyToCommentId;
  final String replyToAuthorId;
  final List<Map<String, Object?>> mentions;
  final int originServerTs;
  final int reactionCount;
  final bool reactedByMe;
  final AsOperation operation;
  final AsConversation? productConversation;

  factory AsChannelComment.fromJson(Map<String, dynamic> json) {
    return AsChannelComment(
      commentId: json['comment_id'] as String? ?? '',
      postId: json['post_id'] as String? ?? '',
      channelId: json['channel_id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      authorId: _firstString(json, const [
        'author_mxid',
        'author_id',
        'sender_mxid',
        'sender_id',
        'user_mxid',
      ]),
      authorName: _firstString(json, const [
        'author_name',
        'author_display_name',
        'sender_name',
        'display_name',
        'name',
      ]),
      authorDomain: json['author_domain'] as String? ?? '',
      authorAvatarUrl: _firstString(json, const [
        'author_avatar_url',
        'sender_avatar_url',
        'avatar_url',
      ]),
      messageType: json['message_type'] as String? ?? 'text',
      body: json['body'] as String? ?? '',
      media: _objectMapOrJson(json['media_json'] ?? json['media']),
      replyToCommentId: json['reply_to_comment_id'] as String? ?? '',
      replyToAuthorId: json['reply_to_author_mxid'] as String? ?? '',
      mentions: _objectMapListOrJson(json['mentions'] ?? json['mentions_json']),
      originServerTs: _parseInt(json['origin_server_ts']),
      reactionCount: _parseInt(json['reaction_count']),
      reactedByMe: json['reacted_by_me'] as bool? ?? false,
      operation: AsOperation.fromJson(
        (json['operation'] as Map?)?.cast<String, dynamic>(),
      ),
      productConversation: _parseConversation(json['conversation']),
    );
  }
}

class AsChannelCommentHistory {
  const AsChannelCommentHistory({
    required this.comment,
    required this.channel,
    required this.post,
  });

  final AsChannelComment comment;
  final AsChannel channel;
  final AsChannelPost post;

  factory AsChannelCommentHistory.fromJson(Map<String, dynamic> json) {
    final commentJson = (json['comment'] as Map?)?.cast<String, dynamic>() ??
        {
          ...json,
          'body': _firstString(json, const ['comment_body', 'body']),
        };
    final channelJson =
        (json['channel'] as Map?)?.cast<String, dynamic>() ?? json;
    final postJson = (json['post'] as Map?)?.cast<String, dynamic>() ??
        {
          ...json,
          'body': _firstString(
            json,
            const ['post_body', 'post_text', 'post_message'],
          ),
          'author_name': _firstString(
            json,
            const ['post_author_name', 'post_author_display_name'],
          ),
          'author_mxid': _firstString(
            json,
            const ['post_author_mxid', 'post_author_id'],
          ),
        };
    return AsChannelCommentHistory(
      comment: AsChannelComment.fromJson(commentJson),
      channel: AsChannel.fromJson(channelJson),
      post: AsChannelPost.fromJson(postJson),
    );
  }
}

class AsChannelReactionHistory {
  const AsChannelReactionHistory({
    required this.postId,
    required this.channelId,
    required this.reaction,
    required this.originServerTs,
    required this.channel,
    required this.post,
  });

  final String postId;
  final String channelId;
  final String reaction;
  final int originServerTs;
  final AsChannel channel;
  final AsChannelPost post;

  factory AsChannelReactionHistory.fromJson(Map<String, dynamic> json) {
    final channelJson =
        (json['channel'] as Map?)?.cast<String, dynamic>() ?? json;
    final postJson = (json['post'] as Map?)?.cast<String, dynamic>() ??
        {
          ...json,
          'body': _firstString(
            json,
            const ['post_body', 'post_text', 'post_message', 'body'],
          ),
          'author_name': _firstString(
            json,
            const ['post_author_name', 'post_author_display_name'],
          ),
          'author_mxid': _firstString(
            json,
            const ['post_author_mxid', 'post_author_id'],
          ),
        };
    return AsChannelReactionHistory(
      postId: json['post_id'] as String? ?? '',
      channelId: json['channel_id'] as String? ?? '',
      reaction: json['reaction'] as String? ?? 'like',
      originServerTs: _parseInt(json['origin_server_ts']),
      channel: AsChannel.fromJson(channelJson),
      post: AsChannelPost.fromJson(postJson),
    );
  }
}

class AsGroupResult {
  const AsGroupResult({
    required this.roomId,
    required this.name,
    required this.memberCount,
    this.invitedCount = 0,
    this.role = '',
    this.status = '',
    this.invitePolicy = groupInvitePolicyAllMembers,
    this.muted = false,
    this.operation = const AsOperation(),
    this.productConversation,
  });

  final String roomId;
  final String name;
  final int memberCount;
  final int invitedCount;
  final String role;
  final String status;
  final String invitePolicy;
  final bool muted;
  final AsOperation operation;
  final AsConversation? productConversation;

  factory AsGroupResult.fromJson(Map<String, dynamic> json) {
    return AsGroupResult(
      roomId: json['room_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      memberCount: json['member_count'] as int? ?? 0,
      invitedCount: json['invited_count'] as int? ?? 0,
      role: json['role'] as String? ?? '',
      status: json['status'] as String? ?? '',
      invitePolicy: _normalizeGroupInvitePolicy(
        json['invite_policy'] as String? ?? '',
      ),
      muted: _parseNullableBool(json['muted']) ?? false,
      operation: AsOperation.fromJson(
        (json['operation'] as Map?)?.cast<String, dynamic>(),
      ),
      productConversation: _parseConversation(json['conversation']),
    );
  }
}

class AsCallSession {
  const AsCallSession({
    required this.callId,
    required this.roomId,
    required this.roomType,
    required this.mediaType,
    required this.createdByMxid,
    required this.state,
    required this.createdAt,
    this.invitedUserIds = const [],
    this.answeredAt,
    this.endedAt,
    this.endedByMxid = '',
    this.endReason = '',
    this.durationMs = 0,
  });

  final String callId;
  final String roomId;
  final String roomType;
  final String mediaType;
  final String createdByMxid;
  final String state;
  final DateTime createdAt;
  final List<String> invitedUserIds;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final String endedByMxid;
  final String endReason;
  final int durationMs;

  factory AsCallSession.fromJson(Map<String, dynamic> json) {
    return AsCallSession(
      callId: json['call_id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      roomType: json['room_type'] as String? ?? '',
      mediaType: json['media_type'] as String? ?? asCallMediaTypeVoice,
      createdByMxid: json['created_by_mxid'] as String? ?? '',
      state: json['state'] as String? ?? asCallStateRinging,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now().toUtc(),
      invitedUserIds: _parseStringList(json['invited_user_ids']),
      answeredAt: _parseDateTime(json['answered_at']),
      endedAt: _parseDateTime(json['ended_at']),
      endedByMxid: json['ended_by_mxid'] as String? ?? '',
      endReason: json['end_reason'] as String? ?? '',
      durationMs: json['duration_ms'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'room_id': roomId,
      'room_type': roomType,
      'media_type': mediaType,
      'created_by_mxid': createdByMxid,
      'invited_user_ids': invitedUserIds,
      'state': state,
      'created_at': createdAt.toUtc().toIso8601String(),
      'answered_at': answeredAt?.toUtc().toIso8601String(),
      'ended_at': endedAt?.toUtc().toIso8601String(),
      'ended_by_mxid': endedByMxid,
      'end_reason': endReason,
      'duration_ms': durationMs,
    };
  }

  AsCallSession copyWith({
    String? state,
    DateTime? answeredAt,
    DateTime? endedAt,
    String? endedByMxid,
    String? endReason,
    int? durationMs,
    List<String>? invitedUserIds,
  }) {
    return AsCallSession(
      callId: callId,
      roomId: roomId,
      roomType: roomType,
      mediaType: mediaType,
      createdByMxid: createdByMxid,
      invitedUserIds: invitedUserIds ?? this.invitedUserIds,
      state: state ?? this.state,
      createdAt: createdAt,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
      endedByMxid: endedByMxid ?? this.endedByMxid,
      endReason: endReason ?? this.endReason,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}

String _normalizeGroupInvitePolicy(String policy) {
  switch (policy.trim()) {
    case groupInvitePolicyOwnerAdmin:
      return groupInvitePolicyOwnerAdmin;
    case groupInvitePolicyAllMembers:
      return groupInvitePolicyAllMembers;
    default:
      return groupInvitePolicyAllMembers;
  }
}

class AsSyncPending {
  const AsSyncPending({
    required this.friendRequests,
    required this.groupInvites,
    required this.channelNotices,
  });

  const AsSyncPending.empty()
      : friendRequests = const [],
        groupInvites = const [],
        channelNotices = const [];

  final List<AsSyncPendingItem> friendRequests;
  final List<AsSyncPendingItem> groupInvites;
  final List<AsSyncPendingItem> channelNotices;

  factory AsSyncPending.fromJson(Map<String, dynamic> json) {
    return AsSyncPending(
      friendRequests:
          _parseList(json['friend_requests'], AsSyncPendingItem.fromJson),
      groupInvites:
          _parseList(json['group_invites'], AsSyncPendingItem.fromJson),
      channelNotices:
          _parseList(json['channel_notices'], AsSyncPendingItem.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'friend_requests':
          friendRequests.map((request) => request.toJson()).toList(),
      'group_invites': groupInvites.map((invite) => invite.toJson()).toList(),
      'channel_notices':
          channelNotices.map((notice) => notice.toJson()).toList(),
    };
  }
}

class AsSyncPendingItem {
  const AsSyncPendingItem({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  final String id;
  final String title;
  final DateTime? createdAt;

  factory AsSyncPendingItem.fromJson(Map<String, dynamic> json) {
    return AsSyncPendingItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt?.toUtc().toIso8601String(),
    };
  }
}

/// P2P API 调用失败
class AsClientException implements Exception {
  AsClientException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'AsClientException($statusCode): $message';
}

// ─────────────────────────── 抽象接口 ───────────────────────────

/// Direxio P2P backend 的 P2P product API 客户端。
///
/// 所有实现都用 `access_token` 做认证（Bearer）。
abstract class AsClient {
  /// P2P product API action.
  Future<OwnerProfile> getOwnerProfile();

  /// P2P product API action.
  Future<OwnerProfile> updateOwnerProfile({
    required String displayName,
    String avatarUrl = '',
    String gender = '',
    String birthday = '',
    String phone = '',
    String email = '',
  });

  /// P2P product API action.
  Future<AsSyncBootstrap> syncBootstrap();

  /// GET /_p2p/conversations
  Future<List<AsConversation>> listConversations() async => const [];

  /// GET /_p2p/events?since= SSE refresh stream.
  Stream<AsEventStreamEvent> streamEvents({
    int? since,
    String? lastEventId,
  }) {
    throw AsClientException('streamEvents is not supported by this client');
  }

  /// P2P product API action.
  Future<AgentConfig> getAgentConfig();

  /// P2P product API action.
  Future<AgentConfig> updateAgentConfig(AgentConfig config);

  /// P2P product API action.
  Future<AgentStatus> getAgentStatus();

  /// P2P product API action.
  Future<List<FollowEntry>> getFollows();

  /// P2P product API action.
  Future<void> addFollow(String domain);

  /// P2P product API action.
  Future<void> removeFollow(String domain);

  /// P2P product API action.
  Future<List<AsFavoriteMessage>> getFavorites({
    String messageType = '',
    int limit = 100,
  });

  /// P2P product API action.
  Future<AsFavoriteMessage> favoriteMessage(AsFavoriteMessageDraft draft);

  /// P2P product API action.
  Future<void> deleteFavorite(int id);

  /// P2P product API action.
  Future<Map<String, dynamic>> submitReport({
    required String reporterDomain,
    required String reportedDomain,
    required String reason,
    int targetType = 1,
    List<String> images = const [],
  });

  /// P2P product API action.
  Future<ContactEntry> createContactRequest({
    required String mxid,
    String displayName = '',
    String domain = '',
  });

  /// P2P product API action.
  Future<ContactEntry> acceptContactRequest({
    required String roomId,
    required String peerMxid,
    String displayName = '',
    String domain = '',
  });

  /// P2P product API action.
  Future<ContactEntry> rejectContactRequest({
    required String roomId,
    required String peerMxid,
    String displayName = '',
    String domain = '',
  });

  /// P2P product API action.
  Future<ContactEntry> deleteContact(String roomId);

  /// P2P product API action.
  Future<ContactEntry> updateContact({
    required String roomId,
    required String displayName,
    String domain = '',
  });

  /// P2P product API action.
  Future<AsCallSession> createCall({
    required String roomId,
    required String mediaType,
    List<String> invitedUserIds = const [],
  });

  /// P2P product API action.
  Future<AsCallSession> getCall(String callId);

  /// P2P product API action.
  Future<List<AsCallSession>> getActiveCalls();

  /// P2P product API action.
  Future<List<AsCallSession>> listCalls({
    required String roomId,
    int limit = 50,
  });

  /// P2P product API action.
  Future<AsCallSession> registerIncomingCall({
    required String callId,
    required String roomId,
    required String mediaType,
    required String createdByMxid,
    DateTime? createdAt,
    List<String> invitedUserIds = const [],
  });

  /// P2P product API action.
  Future<AsCallSession> updateCallEvent({
    required String callId,
    required String event,
    String reason = '',
    int durationMs = 0,
  });

  /// P2P product API action.
  Future<PortalStatus> getPortalStatus();

  /// Updates the Portal password through P2P product auth.
  Future<AsPortalSession> changePortalPassword({
    required String oldPassword,
    required String newPassword,
    String? deviceId,
  });

  /// P2P product API action.
  ///
  /// Creates a Matrix room marked as a P2P IM channel and returns P2P channel
  /// metadata. Matrix room ID is no longer enough for channel UI/routing.
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
  });

  /// P2P product API action.
  Future<List<AsChannel>> listChannels();

  /// P2P product API action.
  Future<List<AsChannel>> searchPublicChannels(
    String query, {
    Uri? baseUri,
    int limit = 20,
  });

  /// P2P product API action.
  Future<AsChannel> getPublicChannel(String channelId, {Uri? baseUri});

  /// P2P product API action.
  Future<AsChannel> getPublicChannelByRoomId(
    String roomId, {
    Uri? baseUri,
    Uri? remoteNodeBaseUri,
  });

  /// P2P product API action.
  Future<List<AsChannel>> getUserPublicChannels(String userId, {Uri? baseUri});

  /// P2P product API action.
  Future<AsChannel> updateChannel(AsChannel draft);

  /// P2P product API action.
  Future<AsChannel> joinChannelByRoomId(
    String roomId, {
    String shareToken = '',
    String grantId = '',
    String shareRoomId = '',
    AsChannel? discoveredChannel,
    Uri? remoteNodeBaseUri,
    Uri? requesterNodeBaseUri,
    List<String> serverNames = const [],
  });

  /// P2P product API action.
  Future<AsChannel> joinChannel(
    String channelId, {
    String roomId = '',
    String shareToken = '',
    String grantId = '',
    String shareRoomId = '',
    AsChannel? discoveredChannel,
    List<String> serverNames = const [],
  });

  /// P2P product API action.
  Future<void> leaveChannel(String channelId);

  /// P2P product API action.
  Future<void> dissolveChannel(String channelId);

  /// P2P product API action.
  Future<List<AsChannelMember>> getChannelMembers(
    String channelId, {
    String status = '',
  });

  /// P2P product API action.
  Future<void> inviteChannelMembers({
    required String channelId,
    required List<String> invite,
  });

  /// POST /_p2p/command action channels.invite_grant.create.
  ///
  /// Creates a share grant for sending a Matrix channel share card into a
  /// direct/group room. The card receiver later joins with grant_id +
  /// share_room_id.
  Future<AsChannelInviteGrant> createChannelInviteGrant({
    String channelId = '',
    String roomId = '',
    required String shareRoomId,
    String grantId = '',
    String reason = '',
  });

  /// P2P product API action.
  Future<AsChannel> approveChannelJoin(String channelId, String userMxid);

  /// P2P product API action.
  Future<AsChannel> rejectChannelJoin(String channelId, String userMxid);

  /// P2P product API action.
  Future<void> removeChannelMember(String channelId, String userMxid);

  /// P2P product API action.
  Future<void> muteChannel(String channelId);

  /// P2P product API action.
  Future<void> unmuteChannel(String channelId);

  /// P2P product API action.
  Future<void> muteChannelMember(String channelId, String userId);

  /// P2P product API action.
  Future<void> unmuteChannelMember(String channelId, String userId);

  /// P2P product API action.
  Future<List<AsChannelPost>> getChannelPosts(
    String channelId, {
    int limit = 50,
    int beforeTs = 0,
  });

  /// P2P product API action.
  Future<AsChannelPost> createChannelPost(
    String channelId, {
    required String messageType,
    required String body,
    Map<String, Object?> media = const {},
  });

  /// P2P product API action.
  Future<void> recallChannelPost(
    String channelId,
    String postId, {
    String reason = 'recall post',
  });

  /// P2P product API action.
  Future<List<AsChannelComment>> getChannelComments(
    String channelId,
    String postId, {
    int page = 1,
    int pageSize = 50,
  });

  /// P2P product API action.
  Future<AsChannelComment> createChannelComment(
    String channelId,
    String postId, {
    required String messageType,
    required String body,
    Map<String, Object?> media = const {},
    String replyToCommentId = '',
    String replyToAuthorId = '',
    List<Map<String, Object?>> mentions = const [],
  });

  /// P2P product API action.
  Future<List<AsChannelCommentHistory>> getMyChannelComments({
    int limit = 50,
  });

  /// P2P product API action.
  Future<List<AsChannelReactionHistory>> getMyChannelReactions({
    int limit = 50,
  });

  /// P2P product API action.
  Future<AsChannelReaction> toggleChannelPostReaction(
    String channelId,
    String postId, {
    String reaction = 'like',
  });

  /// P2P product API action.
  Future<AsChannelReaction> toggleChannelCommentReaction(
    String channelId,
    String postId,
    String commentId, {
    String reaction = 'like',
  });

  /// P2P product API action.
  Future<void> updateChannelReadMarker(
    String channelId, {
    required String eventId,
    required int originServerTs,
  });

  /// P2P product API action.
  Future<AsGroupResult> createGroup({
    required String name,
    required List<String> invite,
    String avatarUrl = '',
  });

  /// P2P product API action.
  Future<AsGroupResult> updateGroupProfile({
    required String roomId,
    String name = '',
    String topic = '',
    String avatarUrl = '',
  });

  /// P2P product API action.
  Future<AsGroupResult> inviteGroupMembers({
    required String roomId,
    required List<String> invite,
  });

  /// P2P product API action.
  Future<void> removeGroupMember({
    required String roomId,
    required String peerMxid,
  });

  /// P2P product API action.
  Future<void> muteGroup(String roomId);

  /// P2P product API action.
  Future<void> unmuteGroup(String roomId);

  /// P2P product API action.
  Future<void> muteGroupMember({
    required String roomId,
    required String userId,
  });

  /// P2P product API action.
  Future<void> unmuteGroupMember({
    required String roomId,
    required String userId,
  });

  /// P2P product API action.
  Future<AsGroupResult> updateGroupInvitePolicy({
    required String roomId,
    required String invitePolicy,
  });

  /// P2P product API action.
  Future<AsGroupResult> joinGroup({
    required String roomId,
    String groupName = '',
    String inviterMxid = '',
    String inviteEventId = '',
    String directRoomId = '',
  });

  /// P2P product API action.
  Future<void> leaveGroup(String roomId);

  /// P2P product API action.
  Future<void> dissolveGroup(String roomId);

  /// P2P product API action.
  ///
  /// Records the latest read marker known by this device so unread-only
  /// recovery can avoid returning already-read history on a new device.
  Future<void> updateReadMarker(
    String roomId,
    String eventId,
    DateTime timestamp,
  );
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}

DateTime? _parseUnixMillisDateTime(Object? value) {
  final millis = _parseInt(value);
  if (millis > 0) {
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }
  return _parseDateTime(value);
}

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool? _parseNullableBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return null;
}

String _parseChannelDisplayName(Map<String, dynamic> json) {
  return _firstString(json, const [
    'name',
    'channel_name',
    'room_name',
    'display_name',
    'displayName',
  ]);
}

String _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value;
  }
  return '';
}

String _normalizeChannelVisibility(String visibility) {
  return visibility.trim() == asChannelVisibilityPrivate
      ? asChannelVisibilityPrivate
      : asChannelVisibilityPublic;
}

String _normalizeChannelJoinPolicy(String policy) {
  switch (policy.trim()) {
    case asChannelJoinPolicyApproval:
      return asChannelJoinPolicyApproval;
    case asChannelJoinPolicyInvite:
      return asChannelJoinPolicyInvite;
    default:
      return asChannelJoinPolicyOpen;
  }
}

String _normalizeChannelMemberStatus(String status) {
  switch (status.trim().toLowerCase()) {
    case 'join':
    case asChannelMemberStatusJoined:
      return asChannelMemberStatusJoined;
    case asChannelMemberStatusInvite:
    case 'invited':
      return asChannelMemberStatusInvite;
    case asChannelMemberStatusPending:
      return asChannelMemberStatusPending;
    case asChannelMemberStatusApproved:
      return asChannelMemberStatusApproved;
    case asChannelMemberStatusJoining:
      return asChannelMemberStatusJoining;
    case asChannelMemberStatusJoinFailed:
      return asChannelMemberStatusJoinFailed;
    case 'reject':
    case asChannelMemberStatusRejected:
      return asChannelMemberStatusRejected;
    default:
      return status.trim();
  }
}

String normalizeAsChannelType(String value) {
  final trimmed = value.trim().toLowerCase();
  return switch (trimmed) {
    asChannelTypeChat || '聊天' => asChannelTypeChat,
    _ => asChannelTypePost,
  };
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}

Map<String, Object?> _chatRecordMap(Object? value, {Object? fallback}) {
  final direct = _objectMapOrJson(value);
  if (direct.isNotEmpty) return direct;
  return _objectMapOrJson(fallback);
}

Map<String, Object?> _objectMapOrJson(Object? value) {
  final map = _objectMap(value);
  if (map.isNotEmpty) return map;
  if (value is! String || value.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(value);
    return _objectMap(decoded);
  } on FormatException {
    return const {};
  }
}

List<Map<String, Object?>> _objectMapListOrJson(Object? value) {
  Object? raw = value;
  if (value is String) {
    if (value.trim().isEmpty) return const [];
    try {
      raw = jsonDecode(value);
    } on FormatException {
      return const [];
    }
  }
  final list = raw as List? ?? const [];
  return list
      .whereType<Map>()
      .map((item) => item.cast<String, Object?>())
      .toList(growable: false);
}

List<T> _parseList<T>(
  Object? value,
  T Function(Map<String, dynamic>) parse,
) {
  final raw = value as List? ?? const [];
  return raw
      .whereType<Map>()
      .map((item) => parse(item.cast<String, dynamic>()))
      .toList(growable: false);
}

List<String> _parseStringList(Object? value) {
  final raw = value as List? ?? const [];
  return raw
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

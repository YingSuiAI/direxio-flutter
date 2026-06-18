// AS Admin API 客户端 —— 对应 INTERFACE_SPEC.md §5 / §6
//
// Matrix 标准协议不覆盖的能力（消息搜索、Agent 配置、关注系统、Portal 状态）
// 由 p2p-matrix-as 的 Admin API 补齐，端点统一走 `https://{domain}/_as/` 前缀。
// Admin API 使用 AS `admin_access_token` 作为 Bearer；Matrix SDK 自身继续使用
// Matrix `matrix_access_token`。
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
const asChannelMemberStatusPending = 'pending';
const asChannelMemberStatusRejected = 'rejected';
const asChannelRoleOwner = 'owner';
const asChannelRoleAdmin = 'admin';
const asChannelRoleMember = 'member';
const asChannelTypeChat = 'chat';
const asChannelTypePost = 'post';

// ─────────────────────────── 数据模型 ───────────────────────────

class AsPortalSession {
  const AsPortalSession({
    required this.matrixAccessToken,
    required this.adminAccessToken,
    required this.userId,
    required this.homeserver,
    this.deviceId,
    this.agentRoomId,
    this.profileInitialized,
  });

  final String matrixAccessToken;
  final String adminAccessToken;
  final String userId;
  final String homeserver;
  final String? deviceId;
  final String? agentRoomId;
  final bool? profileInitialized;

  factory AsPortalSession.fromJson(Map<String, dynamic> json) {
    return AsPortalSession(
      matrixAccessToken: json['matrix_access_token'] as String? ?? '',
      adminAccessToken: json['admin_access_token'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      homeserver: json['homeserver'] as String? ?? '',
      deviceId: json['device_id'] as String?,
      agentRoomId: json['agent_room_id'] as String?,
      profileInitialized: _parseNullableBool(json['profile_initialized']),
    );
  }
}

/// §5.1 消息搜索单条结果
class AsSearchResult {
  const AsSearchResult({
    required this.eventId,
    required this.roomId,
    required this.senderName,
    required this.content,
    required this.timestamp,
  });
  final String eventId;
  final String roomId;
  final String senderName;
  final String content;
  final DateTime timestamp;

  factory AsSearchResult.fromJson(Map<String, dynamic> j) => AsSearchResult(
        eventId: j['event_id'] as String,
        roomId: j['room_id'] as String,
        senderName: j['sender_name'] as String? ?? '',
        content: j['content'] as String? ?? '',
        timestamp: DateTime.parse(j['timestamp'] as String),
      );
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
  });

  final String peerMxid;
  final String displayName;
  final String domain;
  final String roomId;
  final String status;
  final int visibleAfterTs;
  final List<String> deletedEventIds;

  factory ContactEntry.fromJson(Map<String, dynamic> j) => ContactEntry(
        peerMxid: j['peer_mxid'] as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        domain: j['domain'] as String? ?? '',
        roomId: j['room_id'] as String? ?? '',
        status: j['status'] as String? ?? '',
        visibleAfterTs: j['visible_after_ts'] as int? ?? 0,
        deletedEventIds: _parseStringList(j['deleted_event_ids']),
      );
}

/// Portal owner profile managed by p2p-matrix-as.
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
    required this.dendrite,
    required this.federation,
    required this.agent,
    required this.uptime,
  });

  /// "connected" / "disconnected"
  final String dendrite;

  /// "ok" / "degraded" / ...
  final String federation;

  /// "connected" / "disconnected"
  final String agent;

  /// 人类可读的运行时长，如 "3d 5h"
  final String uptime;

  factory PortalStatus.fromJson(Map<String, dynamic> j) => PortalStatus(
        dendrite: j['dendrite'] as String? ?? 'unknown',
        federation: j['federation'] as String? ?? 'unknown',
        agent: j['agent'] as String? ?? 'unknown',
        uptime: j['uptime'] as String? ?? '',
      );

  bool get allHealthy =>
      dendrite == 'connected' &&
      federation == 'ok' &&
      agent.startsWith('connected');
}

/// Privacy-safe new-device bootstrap metadata from `GET /_as/sync/bootstrap`.
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
    this.channelType = asChannelTypePost,
    this.role = '',
    this.memberStatus = '',
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
  final String channelType;
  final String role;
  final String memberStatus;
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
      channelType:
          normalizeAsChannelType(json['channel_type'] as String? ?? ''),
      role: role,
      memberStatus: json['member_status'] as String? ?? '',
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
      channelType: channelType,
      role: role,
      memberStatus: memberStatus,
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
      channelType: channelType,
      role: role,
      memberStatus: memberStatus,
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
      channelType: channelType,
      role: role,
      memberStatus: memberStatus,
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
      channelType: channelType,
      role: role,
      memberStatus: memberStatus,
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
      'channel_type': channelType,
      if (role.trim().isNotEmpty) 'role': role,
      if (memberStatus.trim().isNotEmpty) 'member_status': memberStatus,
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
    this.channelType = asChannelTypePost,
    this.role = '',
    this.memberStatus = '',
    this.memberCount = 0,
    this.pendingJoinCount = 0,
    this.tags = const [],
    this.latestActivityAt,
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
  final String channelType;
  final String role;
  final String memberStatus;
  final int memberCount;
  final int pendingJoinCount;
  final List<String> tags;
  final DateTime? latestActivityAt;

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
      channelType:
          normalizeAsChannelType(json['channel_type'] as String? ?? ''),
      role: json['role'] as String? ?? '',
      memberStatus: json['member_status'] as String? ?? '',
      memberCount: _parseInt(json['member_count']),
      pendingJoinCount: _parseInt(json['pending_join_count']),
      tags: _parseStringList(json['tags']),
      latestActivityAt:
          _parseDateTime(json['last_activity_at'] ?? json['created_at']),
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
      'channel_type': channelType,
      if (role.trim().isNotEmpty) 'role': role,
      if (memberStatus.trim().isNotEmpty) 'member_status': memberStatus,
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
    this.media = const {},
    this.commentCount = 0,
    this.reactionCount = 0,
    this.reactedByMe = false,
  });

  final String postId;
  final String channelId;
  final String roomId;
  final String eventId;
  final String authorId;
  final String authorName;
  final String messageType;
  final String body;
  final Map<String, Object?> media;
  final int originServerTs;
  final int commentCount;
  final int reactionCount;
  final bool reactedByMe;

  factory AsChannelPost.fromJson(Map<String, dynamic> json) {
    return AsChannelPost(
      postId: json['post_id'] as String? ?? '',
      channelId: json['channel_id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      authorId: json['author_mxid'] as String? ?? '',
      authorName: json['author_name'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      body: json['body'] as String? ?? '',
      media: _objectMapOrJson(json['media_json'] ?? json['media']),
      originServerTs: _parseInt(json['origin_server_ts']),
      commentCount: _parseInt(json['comment_count']),
      reactionCount: _parseInt(json['reaction_count']),
      reactedByMe: json['reacted_by_me'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'post_id': postId,
        'channel_id': channelId,
        'room_id': roomId,
        'event_id': eventId,
        'author_mxid': authorId,
        'author_name': authorName,
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
  });

  final String postId;
  final String channelId;
  final String reaction;
  final bool active;
  final int reactionCount;

  factory AsChannelReaction.fromJson(Map<String, dynamic> json) {
    return AsChannelReaction(
      postId: json['post_id'] as String? ?? '',
      channelId: json['channel_id'] as String? ?? '',
      reaction: json['reaction'] as String? ?? 'like',
      active: json['active'] as bool? ?? false,
      reactionCount: _parseInt(json['reaction_count']),
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
    this.joinedAtMs = 0,
  });

  final String channelId;
  final String userMxid;
  final String domain;
  final String displayName;
  final String role;
  final String status;
  final int joinedAtMs;

  factory AsChannelMember.fromJson(Map<String, dynamic> json) {
    return AsChannelMember(
      channelId: json['channel_id'] as String? ?? '',
      userMxid: json['user_mxid'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      role: json['role'] as String? ?? asChannelRoleMember,
      status: json['status'] as String? ?? '',
      joinedAtMs: _parseInt(json['joined_at_ms']),
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
    this.media = const {},
    this.reactionCount = 0,
    this.reactedByMe = false,
  });

  final String commentId;
  final String postId;
  final String channelId;
  final String eventId;
  final String authorId;
  final String authorName;
  final String authorDomain;
  final String messageType;
  final String body;
  final Map<String, Object?> media;
  final int originServerTs;
  final int reactionCount;
  final bool reactedByMe;

  factory AsChannelComment.fromJson(Map<String, dynamic> json) {
    return AsChannelComment(
      commentId: json['comment_id'] as String? ?? '',
      postId: json['post_id'] as String? ?? '',
      channelId: json['channel_id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      authorId: json['author_mxid'] as String? ?? '',
      authorName: json['author_name'] as String? ?? '',
      authorDomain: json['author_domain'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      body: json['body'] as String? ?? '',
      media: _objectMapOrJson(json['media_json'] ?? json['media']),
      originServerTs: _parseInt(json['origin_server_ts']),
      reactionCount: _parseInt(json['reaction_count']),
      reactedByMe: json['reacted_by_me'] as bool? ?? false,
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
    return AsChannelCommentHistory(
      comment: AsChannelComment.fromJson(
        (json['comment'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      channel: AsChannel.fromJson(
        (json['channel'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      post: AsChannelPost.fromJson(
        (json['post'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
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
    return AsChannelReactionHistory(
      postId: json['post_id'] as String? ?? '',
      channelId: json['channel_id'] as String? ?? '',
      reaction: json['reaction'] as String? ?? 'like',
      originServerTs: _parseInt(json['origin_server_ts']),
      channel: AsChannel.fromJson(
        (json['channel'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      post: AsChannelPost.fromJson(
        (json['post'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
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
  });

  final String roomId;
  final String name;
  final int memberCount;
  final int invitedCount;
  final String role;
  final String status;
  final String invitePolicy;

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

/// Unread-only message recovery from `GET /_as/sync/unread`.
class AsSyncUnread {
  const AsSyncUnread({
    required this.syncedAt,
    required this.rooms,
  });

  final DateTime syncedAt;
  final List<AsUnreadRoom> rooms;

  factory AsSyncUnread.fromJson(Map<String, dynamic> json) {
    return AsSyncUnread(
      syncedAt: _parseDateTime(json['synced_at']) ?? DateTime.now().toUtc(),
      rooms: _parseList(json['rooms'], AsUnreadRoom.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'synced_at': syncedAt.toUtc().toIso8601String(),
      'rooms': rooms.map((room) => room.toJson()).toList(),
    };
  }

  List<AsUnreadMessage> messagesForRoom(String roomId) {
    for (final room in rooms) {
      if (room.roomId == roomId) return room.messages;
    }
    return const [];
  }
}

class AsSyncMessages {
  const AsSyncMessages({
    required this.syncedAt,
    required this.page,
    required this.pageSize,
    required this.rooms,
  });

  final DateTime syncedAt;
  final int page;
  final int pageSize;
  final List<AsSyncMessagesRoom> rooms;

  factory AsSyncMessages.fromJson(Map<String, dynamic> json) {
    final page = _parseInt(json['page']);
    final pageSize = _parseInt(json['page_size']);
    return AsSyncMessages(
      syncedAt: _parseDateTime(json['synced_at']) ?? DateTime.now().toUtc(),
      page: page <= 0 ? 1 : page,
      pageSize: pageSize <= 0 ? 20 : pageSize,
      rooms: _parseList(json['rooms'], AsSyncMessagesRoom.fromJson),
    );
  }
}

class AsSyncMessagesRoom {
  const AsSyncMessagesRoom({
    required this.roomId,
    required this.messages,
    required this.hasMoreMessages,
    this.nextMessagePage,
  });

  final String roomId;
  final List<AsUnreadMessage> messages;
  final bool hasMoreMessages;
  final int? nextMessagePage;

  factory AsSyncMessagesRoom.fromJson(Map<String, dynamic> json) {
    return AsSyncMessagesRoom(
      roomId: json['room_id'] as String? ?? '',
      messages: _parseList(json['messages'], AsUnreadMessage.fromJson),
      hasMoreMessages: _parseNullableBool(json['has_more_messages']) ?? false,
      nextMessagePage: _parseOptionalPositiveInt(json['next_message_page']),
    );
  }
}

class AsUnreadRoom {
  const AsUnreadRoom({
    required this.roomId,
    required this.messages,
  });

  final String roomId;
  final List<AsUnreadMessage> messages;

  factory AsUnreadRoom.fromJson(Map<String, dynamic> json) {
    return AsUnreadRoom(
      roomId: json['room_id'] as String? ?? '',
      messages: _parseList(json['messages'], AsUnreadMessage.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'messages': messages.map((message) => message.toJson()).toList(),
    };
  }
}

class AsUnreadMessage {
  const AsUnreadMessage({
    required this.eventId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.messageType,
    required this.timestamp,
  });

  final String eventId;
  final String senderId;
  final String senderName;
  final String content;
  final String messageType;
  final DateTime? timestamp;

  factory AsUnreadMessage.fromJson(Map<String, dynamic> json) {
    return AsUnreadMessage(
      eventId: json['event_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? '',
      content: json['content'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      timestamp: _parseDateTime(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
      'message_type': messageType,
      'timestamp': timestamp?.toUtc().toIso8601String(),
    };
  }
}

/// AS API 调用失败
class AsClientException implements Exception {
  AsClientException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'AsClientException($statusCode): $message';
}

// ─────────────────────────── 抽象接口 ───────────────────────────

/// p2p-matrix-as 的 Admin API 客户端。
///
/// 所有实现都用 `admin_access_token` 做认证（Bearer）。
abstract class AsClient {
  /// GET /_as/profile
  Future<OwnerProfile> getOwnerProfile();

  /// PUT /_as/profile
  Future<OwnerProfile> updateOwnerProfile({
    required String displayName,
    String avatarUrl = '',
    String gender = '',
    String birthday = '',
    String phone = '',
    String email = '',
  });

  /// GET /_as/sync/bootstrap
  Future<AsSyncBootstrap> syncBootstrap();

  /// GET /_as/sync/unread?limit_per_room=
  Future<AsSyncUnread> syncUnread({int limitPerRoom = 200});

  /// GET /_as/sync/messages?room_id=&page=&page_size=
  Future<AsSyncMessages> syncMessages({
    String roomId = '',
    int page = 1,
    int pageSize = 20,
    int fromTs = 0,
    int toTs = 0,
  }) {
    throw AsClientException('syncMessages is not supported by this client');
  }

  /// §5.1 GET /_as/search?q=&room_id=&limit=
  Future<List<AsSearchResult>> search(
    String query, {
    String? roomId,
    int limit = 20,
  });

  /// §5.2 GET /_as/agent/config
  Future<AgentConfig> getAgentConfig();

  /// §5.2 PUT /_as/agent/config
  Future<AgentConfig> updateAgentConfig(AgentConfig config);

  /// §5.3 GET /_as/agent/status
  Future<AgentStatus> getAgentStatus();

  /// §5.4 GET /_as/follows
  Future<List<FollowEntry>> getFollows();

  /// §5.4 POST /_as/follows
  Future<void> addFollow(String domain);

  /// §5.4 DELETE /_as/follows/{domain}
  Future<void> removeFollow(String domain);

  /// GET /_as/favorites
  Future<List<AsFavoriteMessage>> getFavorites({
    String messageType = '',
    int limit = 100,
  });

  /// POST /_as/favorites
  Future<AsFavoriteMessage> favoriteMessage(AsFavoriteMessageDraft draft);

  /// DELETE /_as/favorites/{id}
  Future<void> deleteFavorite(int id);

  /// POST /_as/reports
  Future<Map<String, dynamic>> submitReport({
    required String reporterDomain,
    required String reportedDomain,
    required String reason,
    int targetType = 1,
    List<String> images = const [],
  });

  /// POST /_as/contacts/requests
  Future<ContactEntry> createContactRequest({
    required String mxid,
    String displayName = '',
    String domain = '',
  });

  /// POST /_as/contacts/requests/{roomId}/accept
  Future<ContactEntry> acceptContactRequest({
    required String roomId,
    required String peerMxid,
    String displayName = '',
    String domain = '',
  });

  /// POST /_as/contacts/requests/{roomId}/reject
  Future<ContactEntry> rejectContactRequest({
    required String roomId,
    required String peerMxid,
    String displayName = '',
    String domain = '',
  });

  /// DELETE /_as/contacts/{roomId}
  Future<ContactEntry> deleteContact(String roomId);

  /// POST /_as/rooms/{roomId}/messages/delete
  ///
  /// Hides one message for the current portal owner only. This must not use
  /// Matrix redaction because redaction is visible to the whole room.
  Future<void> deleteRoomMessage({
    required String roomId,
    required String eventId,
  });

  /// POST /_as/rooms/{roomId}/send
  Future<String> sendRoomMessage(
    String roomId,
    String content, {
    String? replyToEventId,
    List<Map<String, String>> mentions = const [],
  });

  /// POST /_as/rooms/{roomId}/send with message_type=chat_record
  Future<String> sendChatRecordMessage({
    required String roomId,
    required String body,
    required String title,
    required String sourceRoomId,
    required String sourceRoomType,
    required int itemCount,
    List<Map<String, Object?>> items = const [],
  });

  /// POST /_as/rooms/{roomId}/send with message_type=channel_share
  Future<String> sendChannelShareMessage({
    required String roomId,
    required String body,
    required AsChannelShareDraft channel,
  });

  /// POST /_as/rooms/{roomId}/send-media
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
  });

  /// POST /_as/calls
  Future<AsCallSession> createCall({
    required String roomId,
    required String mediaType,
    List<String> invitedUserIds = const [],
  });

  /// GET /_as/calls/{callId}
  Future<AsCallSession> getCall(String callId);

  /// GET /_as/calls/active
  Future<List<AsCallSession>> getActiveCalls();

  /// GET /_as/calls?room_id=&limit=
  Future<List<AsCallSession>> listCalls({
    required String roomId,
    int limit = 50,
  });

  /// POST /_as/calls/incoming
  Future<AsCallSession> registerIncomingCall({
    required String callId,
    required String roomId,
    required String mediaType,
    required String createdByMxid,
    DateTime? createdAt,
    List<String> invitedUserIds = const [],
  });

  /// POST /_as/calls/{callId}/events
  Future<AsCallSession> updateCallEvent({
    required String callId,
    required String event,
    String reason = '',
    int durationMs = 0,
  });

  /// §5.5 GET /_as/portal/status
  Future<PortalStatus> getPortalStatus();

  /// Updates the Portal password through AS admin auth.
  Future<AsPortalSession> changePortalPassword({
    required String oldPassword,
    required String newPassword,
    String? deviceId,
  });

  /// POST /_as/channels
  ///
  /// Creates a Matrix room marked as a P2P IM channel and returns AS channel
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

  /// GET /_as/channels
  Future<List<AsChannel>> listChannels();

  /// GET /_as/public/channels/search
  Future<List<AsChannel>> searchPublicChannels(
    String query, {
    Uri? baseUri,
    int limit = 20,
  });

  /// GET /_as/public/channels/{channelId}
  Future<AsChannel> getPublicChannel(String channelId, {Uri? baseUri});

  /// GET /_as/public/channels/{roomId}
  Future<AsChannel> getPublicChannelByRoomId(String roomId, {Uri? baseUri});

  /// GET /_as/users/{userId}/public-channels
  Future<List<AsChannel>> getUserPublicChannels(String userId, {Uri? baseUri});

  /// PUT /_as/channels/{channelId}
  Future<AsChannel> updateChannel(AsChannel draft);

  /// POST /_as/channels/join
  Future<AsChannel> joinChannelByRoomId(
    String roomId, {
    String shareToken = '',
    AsChannel? discoveredChannel,
  });

  /// POST /_as/channels/{channelId}/join
  Future<AsChannel> joinChannel(
    String channelId, {
    String shareToken = '',
    AsChannel? discoveredChannel,
  });

  /// POST /_as/channels/{channelId}/leave
  Future<void> leaveChannel(String channelId);

  /// GET /_as/channels/{channelId}/members
  Future<List<AsChannelMember>> getChannelMembers(
    String channelId, {
    String status = '',
  });

  /// POST /_as/channels/{channelId}/invite
  Future<void> inviteChannelMembers({
    required String channelId,
    required List<String> invite,
  });

  /// POST /_as/channels/{channelId}/join-requests/{userMxid}/approve
  Future<AsChannel> approveChannelJoin(String channelId, String userMxid);

  /// POST /_as/channels/{channelId}/join-requests/{userMxid}/reject
  Future<AsChannel> rejectChannelJoin(String channelId, String userMxid);

  /// POST /_as/channels/{channelId}/members/{userMxid}/remove
  Future<void> removeChannelMember(String channelId, String userMxid);

  /// POST /_as/channels/{channelId}/mute
  Future<void> muteChannel(String channelId);

  /// POST /_as/channels/{channelId}/unmute
  Future<void> unmuteChannel(String channelId);

  /// POST /_as/channels/{channelId}/members/{userId}/mute
  Future<void> muteChannelMember(String channelId, String userId);

  /// POST /_as/channels/{channelId}/members/{userId}/unmute
  Future<void> unmuteChannelMember(String channelId, String userId);

  /// GET /_as/channels/{channelId}/posts
  Future<List<AsChannelPost>> getChannelPosts(
    String channelId, {
    int limit = 50,
    int beforeTs = 0,
  });

  /// POST /_as/channels/{channelId}/posts
  Future<AsChannelPost> createChannelPost(
    String channelId, {
    required String messageType,
    required String body,
    Map<String, Object?> media = const {},
  });

  /// POST /_as/channels/{channelId}/posts/{postId}/recall
  Future<void> recallChannelPost(
    String channelId,
    String postId, {
    String reason = 'recall post',
  });

  /// GET /_as/channels/{channelId}/posts/{postId}/comments
  Future<List<AsChannelComment>> getChannelComments(
    String channelId,
    String postId, {
    int page = 1,
    int pageSize = 50,
  });

  /// POST /_as/channels/{channelId}/posts/{postId}/comments
  Future<AsChannelComment> createChannelComment(
    String channelId,
    String postId, {
    required String messageType,
    required String body,
    Map<String, Object?> media = const {},
  });

  /// GET /_as/channels/me/comments
  Future<List<AsChannelCommentHistory>> getMyChannelComments({
    int limit = 50,
  });

  /// GET /_as/channels/me/reactions
  Future<List<AsChannelReactionHistory>> getMyChannelReactions({
    int limit = 50,
  });

  /// POST /_as/channels/{channelId}/posts/{postId}/reactions
  Future<AsChannelReaction> toggleChannelPostReaction(
    String channelId,
    String postId, {
    String reaction = 'like',
  });

  /// POST /_as/channels/{channelId}/posts/{postId}/comments/{commentId}/reactions
  Future<AsChannelReaction> toggleChannelCommentReaction(
    String channelId,
    String postId,
    String commentId, {
    String reaction = 'like',
  });

  /// PUT /_as/channels/{channelId}/read-marker
  Future<void> updateChannelReadMarker(
    String channelId, {
    required String eventId,
    required int originServerTs,
  });

  /// POST /_as/groups
  Future<AsGroupResult> createGroup({
    required String name,
    required List<String> invite,
    String avatarUrl = '',
  });

  /// PUT /_as/groups/{roomId}
  Future<AsGroupResult> updateGroupProfile({
    required String roomId,
    String name = '',
    String topic = '',
    String avatarUrl = '',
  });

  /// POST /_as/groups/{roomId}/invite
  Future<AsGroupResult> inviteGroupMembers({
    required String roomId,
    required List<String> invite,
  });

  /// POST /_as/groups/{roomId}/members/{userId}/remove
  Future<void> removeGroupMember({
    required String roomId,
    required String peerMxid,
  });

  /// POST /_as/groups/{roomId}/mute
  Future<void> muteGroup(String roomId);

  /// POST /_as/groups/{roomId}/unmute
  Future<void> unmuteGroup(String roomId);

  /// POST /_as/groups/{roomId}/members/{userId}/mute
  Future<void> muteGroupMember({
    required String roomId,
    required String userId,
  });

  /// POST /_as/groups/{roomId}/members/{userId}/unmute
  Future<void> unmuteGroupMember({
    required String roomId,
    required String userId,
  });

  /// PUT /_as/groups/{roomId}/invite-policy
  Future<AsGroupResult> updateGroupInvitePolicy({
    required String roomId,
    required String invitePolicy,
  });

  /// POST /_as/groups/{roomId}/join
  Future<AsGroupResult> joinGroup({
    required String roomId,
    String groupName = '',
    String inviterMxid = '',
    String inviteEventId = '',
    String directRoomId = '',
  });

  /// POST /_as/groups/{roomId}/leave
  Future<void> leaveGroup(String roomId);

  /// PUT /_as/sync/read-marker
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

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _parseOptionalPositiveInt(Object? value) {
  final parsed = _parseInt(value);
  return parsed <= 0 ? null : parsed;
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

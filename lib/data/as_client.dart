// AS Admin API 客户端 —— 对应 INTERFACE_SPEC.md §5 / §6
//
// Matrix 标准协议不覆盖的能力（消息搜索、Agent 配置、关注系统、Portal 状态）
// 由 p2p-matrix-as 的 Admin API 补齐，端点统一走 `https://{domain}/_as/` 前缀。
// Admin API 使用 `portal_token` 作为 Bearer；Matrix SDK 自身继续使用
// Matrix `access_token`。
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

// ─────────────────────────── 数据模型 ───────────────────────────

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
  });

  final String userId;
  final String displayName;
  final String domain;

  factory OwnerProfile.fromJson(Map<String, dynamic> json) {
    return OwnerProfile(
      userId: json['user_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
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
  });

  final DateTime syncedAt;
  final AsSyncUser user;
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
      userId: json['user_id'] as String? ?? '',
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
    this.topic = '',
    this.isOwned = false,
    this.tags = const [],
    this.invitePolicy = groupInvitePolicyAllMembers,
  });

  final String roomId;
  final String name;
  final String avatarUrl;
  final int unreadCount;
  final DateTime? lastActivityAt;
  final String topic;
  final bool isOwned;
  final List<String> tags;
  final String invitePolicy;

  factory AsSyncRoomSummary.fromJson(Map<String, dynamic> json) {
    return AsSyncRoomSummary(
      roomId: json['room_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      unreadCount: json['unread_count'] as int? ?? 0,
      lastActivityAt: _parseDateTime(json['last_activity_at']),
      topic: json['topic'] as String? ?? '',
      isOwned: json['is_owned'] as bool? ?? false,
      tags: (json['tags'] as List? ?? const [])
          .whereType<String>()
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false),
      invitePolicy: _normalizeGroupInvitePolicy(
        json['invite_policy'] as String? ?? '',
      ),
    );
  }

  AsSyncRoomSummary withInvitePolicy(String policy) {
    return AsSyncRoomSummary(
      roomId: roomId,
      name: name,
      avatarUrl: avatarUrl,
      unreadCount: unreadCount,
      lastActivityAt: lastActivityAt,
      topic: topic,
      isOwned: isOwned,
      tags: tags,
      invitePolicy: _normalizeGroupInvitePolicy(policy),
    );
  }

  AsSyncRoomSummary withUnreadCount(int count) {
    return AsSyncRoomSummary(
      roomId: roomId,
      name: name,
      avatarUrl: avatarUrl,
      unreadCount: count < 0 ? 0 : count,
      lastActivityAt: lastActivityAt,
      topic: topic,
      isOwned: isOwned,
      tags: tags,
      invitePolicy: invitePolicy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'name': name,
      'avatar_url': avatarUrl,
      'unread_count': unreadCount,
      'last_activity_at': lastActivityAt?.toUtc().toIso8601String(),
      'topic': topic,
      'is_owned': isOwned,
      'tags': tags,
      'invite_policy': invitePolicy,
    };
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
/// 所有实现都用 `portal_token` 做认证（Bearer）。
abstract class AsClient {
  /// GET /_as/profile
  Future<OwnerProfile> getOwnerProfile();

  /// PUT /_as/profile
  Future<OwnerProfile> updateOwnerProfile({required String displayName});

  /// GET /_as/sync/bootstrap
  Future<AsSyncBootstrap> syncBootstrap();

  /// GET /_as/sync/unread?limit_per_room=
  Future<AsSyncUnread> syncUnread({int limitPerRoom = 200});

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
  Future<String> sendRoomMessage(String roomId, String content);

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

  /// Rotates the Portal Token used for app login and /_as/* Admin API calls.
  Future<String> changePortalToken(String newToken);

  /// POST /_as/channels
  ///
  /// Creates a Matrix room marked as a P2P IM channel and returns its room ID.
  Future<String> createChannel({
    required String name,
    String topic = '',
  });

  /// POST /_as/groups
  Future<AsGroupResult> createGroup({
    required String name,
    required List<String> invite,
  });

  /// POST /_as/groups/{roomId}/invite
  Future<AsGroupResult> inviteGroupMembers({
    required String roomId,
    required List<String> invite,
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

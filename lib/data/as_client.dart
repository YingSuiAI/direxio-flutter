/// AS Admin API 客户端 —— 对应 INTERFACE_SPEC.md §5 / §6
///
/// Matrix 标准协议不覆盖的能力（消息搜索、Agent 配置、关注系统、Portal 状态）
/// 由 p2p-matrix-as 的 Admin API 补齐，端点统一走 `https://{domain}/_as/` 前缀。
///
/// 本文件只定义抽象接口与数据模型；当前阶段用 [MockAsClient]（见 mock_as_client.dart），
/// p2p-matrix-as 服务上线后再补 HttpAsClient 真实现，UI 与上层 provider 无需改动。

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
      dendrite == 'connected' && federation == 'ok' && agent == 'connected';
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
/// 所有实现都用 Matrix `access_token` 做认证（Bearer），AS 向 Dendrite 校验。
abstract class AsClient {
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

  /// §5.5 GET /_as/portal/status
  Future<PortalStatus> getPortalStatus();
}

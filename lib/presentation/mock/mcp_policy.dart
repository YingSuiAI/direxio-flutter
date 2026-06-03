// MCP / Agent 权限策略模型 —— mock 阶段：纯内存，StateNotifier 持有
// 真实版会换成 freezed + Biscuit token + 本地加密存储
import 'package:flutter_riverpod/flutter_riverpod.dart';

//// 一个 MCP 工具的定义（给 UI 渲染勾选项用）
class McpToolDef {
  const McpToolDef({
    required this.id,
    required this.label,
    required this.description,
    required this.isWrite,
  });
  final String id;
  final String label;
  final String description;
  final bool isWrite; // 写类工具默认进 confirmTools

  static const all = <McpToolDef>[
    McpToolDef(
      id: 'list_conversations',
      label: '列出会话',
      description: '让 Agent 看到你有哪些会话',
      isWrite: false,
    ),
    McpToolDef(
      id: 'search_messages',
      label: '搜索消息',
      description: '允许 Agent 对历史消息做全文检索',
      isWrite: false,
    ),
    McpToolDef(
      id: 'get_recent_messages',
      label: '拉取最近消息',
      description: '按 room 拉一段历史消息',
      isWrite: false,
    ),
    McpToolDef(
      id: 'summarize_room',
      label: '总结会话',
      description: '让 Agent 总结某个会话',
      isWrite: false,
    ),
    McpToolDef(
      id: 'send_message',
      label: '发送消息',
      description: '允许 Agent 替你发消息（写）',
      isWrite: true,
    ),
    McpToolDef(
      id: 'who_is',
      label: '查询身份',
      description: '解析联系人 mxid / 显示名',
      isWrite: false,
    ),
  ];
}

enum RoomScope { all, whitelist, blacklist }

class TimeRange {
  const TimeRange(this.startHour, this.endHour);
  final int startHour; // 0-23
  final int endHour; // 0-23
  @override
  String toString() =>
      '${startHour.toString().padLeft(2, '0')}:00 — ${endHour.toString().padLeft(2, '0')}:00';
}

//// 历史窗口选项
enum HistoryWindow {
  h24('最近 24 小时', Duration(hours: 24)),
  d7('最近 7 天', Duration(days: 7)),
  d30('最近 30 天', Duration(days: 30)),
  d90('最近 90 天', Duration(days: 90)),
  unlimited('不限', null);

  const HistoryWindow(this.label, this.duration);
  final String label;
  final Duration? duration;
}

enum ExpiryOption {
  h1('1 小时', Duration(hours: 1)),
  h4('4 小时', Duration(hours: 4)),
  h24('24 小时', Duration(hours: 24)),
  d7('7 天', Duration(days: 7)),
  never('永不过期', null);

  const ExpiryOption(this.label, this.duration);
  final String label;
  final Duration? duration;
}

class McpPolicy {
  McpPolicy({
    required this.agentId,
    required this.displayName,
    required this.mxid,
    this.enabled = true,
    Set<String>? allowedTools,
    Set<String>? confirmTools,
    this.roomScope = RoomScope.all,
    Set<String>? roomIds,
    this.historyWindow = HistoryWindow.d30,
    this.activeHours,
    this.maskMedia = true,
    Set<String>? redactKeywords,
    this.dailyCallLimit = 200,
    this.perCallMessageLimit = 50,
    this.expiryOption = ExpiryOption.h4,
    DateTime? grantedAt,
  })  : allowedTools = allowedTools ??
            {
              'list_conversations',
              'search_messages',
              'get_recent_messages',
              'summarize_room',
              'send_message',
              'who_is',
            },
        confirmTools = confirmTools ?? {'send_message'},
        roomIds = roomIds ?? {},
        redactKeywords = redactKeywords ?? {'密码', '身份证', '验证码'},
        grantedAt = grantedAt ?? DateTime.now();

  final String agentId;
  final String displayName;
  final String mxid;
  bool enabled;
  Set<String> allowedTools;
  Set<String> confirmTools;
  RoomScope roomScope;
  Set<String> roomIds;
  HistoryWindow historyWindow;
  TimeRange? activeHours;
  bool maskMedia;
  Set<String> redactKeywords;
  int? dailyCallLimit;
  int? perCallMessageLimit;
  ExpiryOption expiryOption;
  DateTime grantedAt;

  DateTime? get expiresAt {
    final d = expiryOption.duration;
    if (d == null) return null;
    return grantedAt.add(d);
  }

  /// 一句话摘要给入口副标题
  String get summary {
    if (!enabled) return '已禁用';
    final scopeText = switch (roomScope) {
      RoomScope.all => '所有会话',
      RoomScope.whitelist => '${roomIds.length} 个会话',
      RoomScope.blacklist => '排除 ${roomIds.length} 个会话',
    };
    return '$scopeText · ${historyWindow.label} · ${allowedTools.length} 个工具';
  }

  McpPolicy copy() {
    return McpPolicy(
      agentId: agentId,
      displayName: displayName,
      mxid: mxid,
      enabled: enabled,
      allowedTools: {...allowedTools},
      confirmTools: {...confirmTools},
      roomScope: roomScope,
      roomIds: {...roomIds},
      historyWindow: historyWindow,
      activeHours: activeHours,
      maskMedia: maskMedia,
      redactKeywords: {...redactKeywords},
      dailyCallLimit: dailyCallLimit,
      perCallMessageLimit: perCallMessageLimit,
      expiryOption: expiryOption,
      grantedAt: grantedAt,
    );
  }
}

//// 全局 mock 策略表（agentId -> policy）
class McpPolicyStore extends StateNotifier<Map<String, McpPolicy>> {
  McpPolicyStore()
      : super({
          'local-aibot': McpPolicy(
            agentId: 'local-aibot',
            displayName: 'AI Bot',
            mxid: '@aibot:portal.ai',
          ),
        });

  void update(String agentId, McpPolicy newPolicy) {
    state = {...state, agentId: newPolicy};
  }
}

final mcpPolicyStoreProvider =
    StateNotifierProvider<McpPolicyStore, Map<String, McpPolicy>>(
  (ref) => McpPolicyStore(),
);

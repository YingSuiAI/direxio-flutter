/// Mock MCP Client：模拟真实 MCP server 行为，被权限闸门拦截
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mcp_policy.dart';
import 'mcp_audit.dart';
import 'mock_data.dart';

class McpDeniedException implements Exception {
  McpDeniedException(this.reason);
  final String reason;
  @override
  String toString() => 'MCP Denied: $reason';
}

class ToolResult {
  ToolResult({
    required this.data,
    this.warnings = const [],
    required this.latencyMs,
    this.summary = '',
  });
  final Map<String, dynamic> data;
  final List<String> warnings;
  final int latencyMs;
  final String summary;
}

class MockMcpClient {
  MockMcpClient(this.ref);
  final Ref ref;
  int _seq = 0;

  String _genId() => 'audit_${DateTime.now().millisecondsSinceEpoch}_${++_seq}';

  /// 调用前预检：返回是否需要二次确认。UI 可在确认 banner 里展示。
  ({bool needConfirm, String? deniedReason, McpPolicy? policy})
      precheck(String agentId, String tool) {
    final policy = ref.read(mcpPolicyStoreProvider)[agentId];
    if (policy == null) {
      return (
        needConfirm: false,
        deniedReason: '未授权 Agent',
        policy: null,
      );
    }
    if (!policy.enabled) {
      return (
        needConfirm: false,
        deniedReason: 'Agent 已禁用',
        policy: policy,
      );
    }
    if (!policy.allowedTools.contains(tool)) {
      return (
        needConfirm: false,
        deniedReason: '工具未授权：$tool',
        policy: policy,
      );
    }
    return (
      needConfirm: policy.confirmTools.contains(tool),
      deniedReason: null,
      policy: policy,
    );
  }

  Future<ToolResult> call(
    String agentId,
    String tool,
    Map<String, dynamic> args, {
    bool userConfirmed = false,
  }) async {
    final pre = precheck(agentId, tool);
    final audit = ref.read(mcpAuditStoreProvider.notifier);

    if (pre.deniedReason != null) {
      audit.log(McpAuditEntry(
        id: _genId(),
        agentId: agentId,
        tool: tool,
        args: args,
        outcome: McpAuditOutcome.denied,
        ts: DateTime.now(),
        deniedReason: pre.deniedReason,
      ));
      throw McpDeniedException(pre.deniedReason!);
    }
    if (pre.needConfirm && !userConfirmed) {
      audit.log(McpAuditEntry(
        id: _genId(),
        agentId: agentId,
        tool: tool,
        args: args,
        outcome: McpAuditOutcome.confirmRequired,
        ts: DateTime.now(),
      ));
      throw McpDeniedException('需用户二次确认');
    }

    await Future.delayed(const Duration(milliseconds: 250));
    final policy = pre.policy!;
    final raw = _dispatch(tool, args, policy);
    final summary = _summarize(tool, raw.data);
    final result = ToolResult(
      data: raw.data,
      warnings: raw.warnings,
      latencyMs: raw.latencyMs,
      summary: summary,
    );

    audit.log(McpAuditEntry(
      id: _genId(),
      agentId: agentId,
      tool: tool,
      args: args,
      outcome: userConfirmed
          ? McpAuditOutcome.confirmed
          : McpAuditOutcome.ok,
      ts: DateTime.now(),
      latencyMs: result.latencyMs,
      warnings: result.warnings,
      resultSummary: summary,
    ));
    return result;
  }

  ToolResult _dispatch(
      String tool, Map<String, dynamic> args, McpPolicy policy) {
    switch (tool) {
      case 'list_conversations':
        return _listConversations(args, policy);
      case 'get_recent_messages':
        return _getRecentMessages(args, policy);
      case 'send_message':
        return _sendMessage(args, policy);
      case 'who_is':
        return _whoIs(args, policy);
      case 'search_messages':
        return _searchMessages(args, policy);
      case 'token_usage':
        return ToolResult(data: {
          'input': 234567,
          'output': 156890,
          'total': 391457,
          'limit': 1000000,
          'model': 'claude-opus-4',
          'cost_cny': 9.39,
        }, latencyMs: 80);
      default:
        throw McpDeniedException('未知工具：$tool');
    }
  }

  ToolResult _listConversations(Map<String, dynamic> args, McpPolicy p) {
    final q = (args['query'] as String?)?.toLowerCase();
    var rooms = MockData.conversations;
    if (p.roomScope == RoomScope.whitelist) {
      rooms = rooms.where((r) => p.roomIds.contains(r.id)).toList();
    } else if (p.roomScope == RoomScope.blacklist) {
      rooms = rooms.where((r) => !p.roomIds.contains(r.id)).toList();
    }
    if (q != null && q.isNotEmpty) {
      rooms = rooms
          .where((r) =>
              r.name.toLowerCase().contains(q) ||
              r.mxid.toLowerCase().contains(q))
          .toList();
    }
    return ToolResult(
      data: {
        'conversations': rooms
            .map((r) => {
                  'id': r.id,
                  'name': r.name,
                  'mxid': r.mxid,
                  'unread': r.unread,
                })
            .toList(),
      },
      latencyMs: 120,
    );
  }

  ToolResult _getRecentMessages(Map<String, dynamic> args, McpPolicy p) {
    final roomId = args['room_id'] as String;
    if (p.roomScope == RoomScope.whitelist && !p.roomIds.contains(roomId)) {
      throw McpDeniedException('该会话不在授权白名单');
    }
    if (p.roomScope == RoomScope.blacklist && p.roomIds.contains(roomId)) {
      throw McpDeniedException('该会话被排除');
    }
    final conv = MockData.byId(roomId);
    if (conv == null) throw McpDeniedException('会话不存在');

    final window = p.historyWindow.duration;
    final cutoff = window == null
        ? null
        : DateTime.now().subtract(window);

    var msgs = conv.messages;
    var truncated = false;
    if (cutoff != null) {
      final before = msgs.length;
      msgs = msgs.where((m) => m.time.isAfter(cutoff)).toList();
      truncated = msgs.length < before;
    }
    var redactCount = 0;
    final out = msgs.map((m) {
      final r = p.redactKeywords.any((k) => m.text.contains(k));
      if (r) redactCount++;
      return {
        'sender': m.isMe ? '@me' : conv.mxid,
        'sender_name': m.isMe ? '我' : conv.name,
        'text': r ? '[REDACTED]' : m.text,
        'ts': m.time.toIso8601String(),
        'redacted': r,
      };
    }).toList();

    final limit = args['limit'] as int? ?? p.perCallMessageLimit ?? 200;
    final clamped = out.take(limit).toList();
    final policyLimited = clamped.length < out.length;

    final warnings = <String>[
      if (truncated) '超出历史窗口（${p.historyWindow.label}）的内容已隐藏',
      if (redactCount > 0) '$redactCount 条消息因关键词命中被遮蔽',
      if (policyLimited) '已按单次上限截断为 $limit 条',
    ];

    return ToolResult(
      data: {
        'messages': clamped,
        'truncated_by_policy': truncated || policyLimited,
        'redacted_count': redactCount,
      },
      warnings: warnings,
      latencyMs: 240,
    );
  }

  ToolResult _sendMessage(Map<String, dynamic> args, McpPolicy p) {
    final roomId = args['room_id'] as String;
    if (p.roomScope == RoomScope.whitelist && !p.roomIds.contains(roomId)) {
      throw McpDeniedException('该会话不在授权白名单');
    }
    return ToolResult(data: {
      'msg_id': 'mock_msg_${DateTime.now().millisecondsSinceEpoch}',
      'room_id': roomId,
    }, latencyMs: 180);
  }

  ToolResult _whoIs(Map<String, dynamic> args, McpPolicy p) {
    final q = (args['query'] as String).toLowerCase();
    final r = MockData.conversations.firstWhere(
      (c) => c.name.toLowerCase().contains(q) || c.mxid.contains(q),
      orElse: () => MockData.conversations.first,
    );
    return ToolResult(data: {
      'mxid': r.mxid,
      'name': r.name,
      'last_seen': r.lastMessage?.time.toIso8601String(),
    }, latencyMs: 90);
  }

  ToolResult _searchMessages(Map<String, dynamic> args, McpPolicy p) {
    final q = (args['query'] as String).toLowerCase();
    final results = <Map<String, dynamic>>[];
    for (final conv in MockData.conversations) {
      if (p.roomScope == RoomScope.whitelist &&
          !p.roomIds.contains(conv.id)) continue;
      if (p.roomScope == RoomScope.blacklist &&
          p.roomIds.contains(conv.id)) continue;
      for (final m in conv.messages) {
        if (m.text.toLowerCase().contains(q)) {
          results.add({
            'room': conv.name,
            'sender': m.isMe ? '我' : conv.name,
            'text': m.text.length > 60
                ? '${m.text.substring(0, 60)}…'
                : m.text,
            'ts': m.time.toIso8601String(),
          });
        }
      }
    }
    return ToolResult(
      data: {'matches': results, 'count': results.length},
      latencyMs: 320,
    );
  }

  String _summarize(String tool, Map<String, dynamic> data) {
    switch (tool) {
      case 'list_conversations':
        return '返回 ${(data['conversations'] as List).length} 个会话';
      case 'get_recent_messages':
        return '返回 ${(data['messages'] as List).length} 条消息';
      case 'send_message':
        return '已发送 ${data['msg_id']}';
      case 'who_is':
        return '${data['name']}';
      case 'search_messages':
        return '命中 ${data['count']} 条';
      case 'token_usage':
        return '${data['total']} / ${data['limit']} tokens';
      default:
        return '完成';
    }
  }
}

final mockMcpClientProvider =
    Provider<MockMcpClient>((ref) => MockMcpClient(ref));

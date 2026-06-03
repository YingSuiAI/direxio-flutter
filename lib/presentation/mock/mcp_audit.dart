// MCP 审计日志（mock 阶段：内存）
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum McpAuditOutcome { ok, denied, confirmRequired, confirmed, cancelled }

class McpAuditEntry {
  McpAuditEntry({
    required this.id,
    required this.agentId,
    required this.tool,
    required this.args,
    required this.outcome,
    required this.ts,
    this.resultSummary,
    this.latencyMs,
    this.warnings = const [],
    this.deniedReason,
  });
  final String id;
  final String agentId;
  final String tool;
  final Map<String, dynamic> args;
  final McpAuditOutcome outcome;
  final DateTime ts;
  final String? resultSummary;
  final int? latencyMs;
  final List<String> warnings;
  final String? deniedReason;
}

class McpAuditStore extends StateNotifier<List<McpAuditEntry>> {
  McpAuditStore() : super([]);

  void log(McpAuditEntry e) {
    state = [e, ...state].take(500).toList();
  }

  void clear() => state = [];

  List<McpAuditEntry> forAgent(String agentId) =>
      state.where((e) => e.agentId == agentId).toList();
}

final mcpAuditStoreProvider =
    StateNotifierProvider<McpAuditStore, List<McpAuditEntry>>(
  (ref) => McpAuditStore(),
);

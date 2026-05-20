/// [AsClient] 的 Mock 实现。
///
/// 真实 App 注入点已经切到 HttpAsClient；本类保留给本地 UI / 单测兜底使用。
import '../presentation/mock/mock_data.dart';
import 'as_client.dart';

class MockAsClient implements AsClient {
  static const _latency = Duration(milliseconds: 240);

  // 进程内可变状态，模拟服务端持久化
  AgentConfig _config = const AgentConfig(displayName: '小A', contextWindow: 20);
  final List<FollowEntry> _follows = [
    FollowEntry(
      domain: 'liyananp2p.com',
      name: 'Jack',
      followedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

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
  Future<PortalStatus> getPortalStatus() async {
    await Future.delayed(_latency);
    return const PortalStatus(
      dendrite: 'connected',
      federation: 'ok',
      agent: 'connected',
      uptime: '3d 5h',
    );
  }
}

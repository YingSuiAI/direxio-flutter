import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgentOfflineReplyCache extends StateNotifier<Map<String, int>> {
  AgentOfflineReplyCache() : super(const {});

  int countFor(String roomId) => state[_normalize(roomId)] ?? 0;

  void increment(String roomId) {
    final key = _normalize(roomId);
    if (key.isEmpty) return;
    state = {...state, key: (state[key] ?? 0) + 1};
  }

  void decrement(String roomId) {
    final key = _normalize(roomId);
    if (key.isEmpty) return;
    final current = state[key] ?? 0;
    if (current <= 1) {
      final next = {...state}..remove(key);
      state = next;
      return;
    }
    state = {...state, key: current - 1};
  }

  void clear(String roomId) {
    final key = _normalize(roomId);
    if (key.isEmpty || !state.containsKey(key)) return;
    final next = {...state}..remove(key);
    state = next;
  }

  static String _normalize(String roomId) => roomId.trim();
}

final agentOfflineReplyCacheProvider =
    StateNotifierProvider<AgentOfflineReplyCache, Map<String, int>>(
  (ref) => AgentOfflineReplyCache(),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import 'as_sync_cache_provider.dart';

enum AgentBridgePresenceState { connecting, online, offline, error, unknown }

class AgentBridgePresence {
  const AgentBridgePresence({
    required this.state,
    this.presence,
    this.error,
    this.source = '',
  });

  const AgentBridgePresence.connecting()
      : state = AgentBridgePresenceState.connecting,
        presence = null,
        error = null,
        source = '';

  const AgentBridgePresence.unknown({
    this.source = 'owner_presence_contract_unavailable',
  })  : state = AgentBridgePresenceState.unknown,
        presence = null,
        error = null;

  final AgentBridgePresenceState state;
  final AsAgentPresence? presence;
  final Object? error;
  final String source;

  bool get bridgeConnected => presence?.connected ?? false;

  String get label {
    return switch (state) {
      AgentBridgePresenceState.connecting => '连接中',
      AgentBridgePresenceState.online => '在线',
      AgentBridgePresenceState.offline => '离线',
      AgentBridgePresenceState.error => '状态异常',
      AgentBridgePresenceState.unknown => '状态未知',
    };
  }
}

/// Agent header presence uses the owner-readable product contract:
/// `sync.bootstrap.agent_presence` for the initial value and `agent.presence`
/// owner SSE events for live updates through [asSyncCacheProvider].
final agentBridgePresenceProvider = Provider<AgentBridgePresence>((ref) {
  final syncCache = ref.watch(asSyncCacheProvider);
  final bootstrapLoaded = syncCache.bootstrap != null;
  final presence =
      syncCache.agentPresence ?? syncCache.bootstrap?.agentPresence;
  if (presence == null) {
    return bootstrapLoaded
        ? const AgentBridgePresence.unknown()
        : const AgentBridgePresence.connecting();
  }
  return AgentBridgePresence(
    state: presence.online
        ? AgentBridgePresenceState.online
        : AgentBridgePresenceState.offline,
    presence: presence,
    source: 'sync.bootstrap.agent_presence/agent.presence',
  );
});

AgentBridgePresence agentBridgePresenceFromError(Object error) {
  return AgentBridgePresence(
    state: AgentBridgePresenceState.error,
    error: error,
  );
}

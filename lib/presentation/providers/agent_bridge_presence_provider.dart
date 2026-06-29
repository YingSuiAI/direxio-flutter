import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';

import 'as_sync_cache_provider.dart';
import 'auth_provider.dart';

const direxioAgentStatusEventType = 'io.direxio.agent.status';

enum AgentBridgePresenceState { connecting, online, offline, error, unknown }

class AgentBridgePresence {
  const AgentBridgePresence({
    required this.state,
    this.online,
    this.error,
    this.source = '',
  });

  const AgentBridgePresence.connecting()
      : state = AgentBridgePresenceState.connecting,
        online = null,
        error = null,
        source = '';

  const AgentBridgePresence.unknown({
    this.source = 'owner_presence_contract_unavailable',
  })  : state = AgentBridgePresenceState.unknown,
        online = null,
        error = null;

  final AgentBridgePresenceState state;
  final bool? online;
  final Object? error;
  final String source;

  bool get bridgeConnected => online ?? false;

  String get label {
    return switch (state) {
      AgentBridgePresenceState.online => '在线',
      AgentBridgePresenceState.offline => '离线',
      AgentBridgePresenceState.connecting => '离线',
      AgentBridgePresenceState.error => '离线',
      AgentBridgePresenceState.unknown => '离线',
    };
  }
}

final _matrixAgentStateTickProvider = StreamProvider<int>((ref) {
  final client = ref.watch(matrixClientProvider);
  var tick = 0;
  return client.onSync.stream.map((_) => ++tick);
});

/// Agent header presence is native Matrix room state in the real agent room.
/// Bootstrap only locates the room through `agent_room_id`; it no longer
/// mirrors the online bit.
final agentBridgePresenceProvider = Provider<AgentBridgePresence>((ref) {
  final syncCache = ref.watch(asSyncCacheProvider);
  final agentRoomId = syncCache.bootstrap?.agentRoomId.trim() ?? '';
  if (agentRoomId.isEmpty) {
    return syncCache.bootstrap == null
        ? const AgentBridgePresence.connecting()
        : const AgentBridgePresence.unknown(source: 'missing_agent_room_id');
  }
  ref.watch(_matrixAgentStateTickProvider);
  final room = ref.watch(matrixClientProvider).getRoomById(agentRoomId);
  if (room == null) {
    return const AgentBridgePresence.connecting();
  }
  final online = agentRoomStatusOnline(room, agentRoomId: agentRoomId);
  if (online == null) {
    return const AgentBridgePresence.unknown(
      source: 'matrix_agent_status_state_missing',
    );
  }
  return AgentBridgePresence(
    state: online
        ? AgentBridgePresenceState.online
        : AgentBridgePresenceState.offline,
    online: online,
    source: 'matrix.room_state.io.direxio.agent.status',
  );
});

bool? agentRoomStatusOnline(Room room, {required String agentRoomId}) {
  final agentMXID = agentMXIDFromAgentRoomID(agentRoomId);
  final directState = agentMXID == null
      ? null
      : room.getState(direxioAgentStatusEventType, agentMXID);
  final directOnline = _onlineFromStateEvent(directState);
  if (directOnline != null) return directOnline;
  final defaultOnline = _onlineFromStateEvent(
    room.getState(direxioAgentStatusEventType),
  );
  if (defaultOnline != null) return defaultOnline;
  final states = room.states[direxioAgentStatusEventType]?.values;
  if (states == null) return null;
  for (final state in states) {
    final online = _onlineFromStateEvent(state);
    if (online != null) return online;
  }
  return null;
}

String? agentMXIDFromAgentRoomID(String roomId) {
  final trimmed = roomId.trim();
  final split = trimmed.indexOf(':');
  if (!trimmed.startsWith('!') || split < 0 || split == trimmed.length - 1) {
    return null;
  }
  return '@agent:${trimmed.substring(split + 1)}';
}

bool? _onlineFromStateEvent(dynamic event) {
  final content = event?.content;
  if (content is! Map) return null;
  final raw = content['online'];
  return raw is bool ? raw : null;
}

AgentBridgePresence agentBridgePresenceFromError(Object error) {
  return AgentBridgePresence(
    state: AgentBridgePresenceState.error,
    error: error,
  );
}

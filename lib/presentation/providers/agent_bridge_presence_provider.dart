import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';

import '../../data/direxio_matrix_events.dart' as direxio_matrix_events;
import 'as_sync_cache_provider.dart';
import 'auth_provider.dart';

const direxioAgentStatusEventType =
    direxio_matrix_events.direxioAgentStatusEventType;

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

final agentBridgePresenceStateRefreshIntervalProvider =
    Provider<Duration>((ref) => const Duration(seconds: 5));

final _matrixAgentStatusStateRefreshTickProvider =
    StreamProvider.autoDispose<int>((ref) async* {
  final interval = ref.watch(agentBridgePresenceStateRefreshIntervalProvider);
  yield 0;
  yield* Stream.periodic(interval, (tick) => tick + 1);
});

final _matrixAgentStatusStateProvider = FutureProvider.autoDispose
    .family<bool?, _MatrixAgentStatusStateRequest>((ref, request) async {
  final client = ref.watch(matrixClientProvider);
  final content = await client.getRoomStateWithKey(
    request.roomId,
    direxioAgentStatusEventType,
    request.stateKey,
  );
  final raw = content['online'];
  final online = raw is bool ? raw : null;
  if (online != null) {
    ref
        .read(_matrixAgentStatusSnapshotProvider(request.identity).notifier)
        .state = online;
  }
  return online;
});

final _matrixAgentStatusSnapshotProvider =
    StateProvider.autoDispose.family<bool?, _MatrixAgentStatusStateIdentity>(
  (ref, identity) => null,
);

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
  final client = ref.watch(matrixClientProvider);
  final room = client.getRoomById(agentRoomId);
  if (room == null) {
    return const AgentBridgePresence.connecting();
  }
  final online = agentRoomStatusOnline(room, agentRoomId: agentRoomId);
  if (online == null) {
    final agentMXID = agentMXIDFromAgentRoomID(agentRoomId);
    final homeserver = client.homeserver;
    final accessToken = client.accessToken;
    if (agentMXID == null ||
        homeserver == null ||
        accessToken == null ||
        accessToken.trim().isEmpty) {
      return const AgentBridgePresence.unknown(
        source: 'matrix_agent_status_state_missing',
      );
    }
    final stateIdentity = _MatrixAgentStatusStateIdentity(
      roomId: agentRoomId,
      stateKey: agentMXID,
    );
    final cachedOnline = ref.watch(
      _matrixAgentStatusSnapshotProvider(stateIdentity),
    );
    if (cachedOnline != null) {
      return AgentBridgePresence(
        state: cachedOnline
            ? AgentBridgePresenceState.online
            : AgentBridgePresenceState.offline,
        online: cachedOnline,
        source: 'matrix.room_state.io.direxio.agent.status.fetch',
      );
    }
    final refreshTick =
        ref.watch(_matrixAgentStatusStateRefreshTickProvider).valueOrNull ?? 0;
    final stateFetch = ref.watch(
      _matrixAgentStatusStateProvider(
        _MatrixAgentStatusStateRequest(
          identity: stateIdentity,
          refreshTick: refreshTick,
        ),
      ),
    );
    return switch (stateFetch) {
      AsyncData(value: final fetchedOnline?) => AgentBridgePresence(
          state: fetchedOnline
              ? AgentBridgePresenceState.online
              : AgentBridgePresenceState.offline,
          online: fetchedOnline,
          source: 'matrix.room_state.io.direxio.agent.status.fetch',
        ),
      AsyncError(:final error) => AgentBridgePresence(
          state: AgentBridgePresenceState.error,
          error: error,
          source: 'matrix_agent_status_state_fetch_failed',
        ),
      AsyncData() => const AgentBridgePresence.unknown(
          source: 'matrix_agent_status_state_fetch_missing',
        ),
      _ => const AgentBridgePresence.connecting(),
    };
  }
  return AgentBridgePresence(
    state: online
        ? AgentBridgePresenceState.online
        : AgentBridgePresenceState.offline,
    online: online,
    source: 'matrix.room_state.io.direxio.agent.status',
  );
});

class _MatrixAgentStatusStateRequest {
  const _MatrixAgentStatusStateRequest({
    required this.identity,
    required this.refreshTick,
  });

  final _MatrixAgentStatusStateIdentity identity;
  final int refreshTick;

  String get roomId => identity.roomId;

  String get stateKey => identity.stateKey;

  @override
  bool operator ==(Object other) {
    return other is _MatrixAgentStatusStateRequest &&
        identity == other.identity &&
        refreshTick == other.refreshTick;
  }

  @override
  int get hashCode => Object.hash(identity, refreshTick);
}

class _MatrixAgentStatusStateIdentity {
  const _MatrixAgentStatusStateIdentity({
    required this.roomId,
    required this.stateKey,
  });

  final String roomId;
  final String stateKey;

  @override
  bool operator ==(Object other) {
    return other is _MatrixAgentStatusStateIdentity &&
        roomId == other.roomId &&
        stateKey == other.stateKey;
  }

  @override
  int get hashCode => Object.hash(roomId, stateKey);
}

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

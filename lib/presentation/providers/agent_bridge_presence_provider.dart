import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import 'as_client_provider.dart';

enum AgentBridgePresenceState { connecting, online, offline, error, unknown }

class AgentBridgePresence {
  const AgentBridgePresence({required this.state, this.status, this.error});

  const AgentBridgePresence.connecting()
      : state = AgentBridgePresenceState.connecting,
        status = null,
        error = null;

  final AgentBridgePresenceState state;
  final AgentStatus? status;
  final Object? error;

  bool get bridgeConnected => status?.connected ?? false;

  String get label {
    return switch (state) {
      AgentBridgePresenceState.connecting => '连接中',
      AgentBridgePresenceState.online => '在线',
      AgentBridgePresenceState.offline => '离线',
      AgentBridgePresenceState.error => '状态异常',
      AgentBridgePresenceState.unknown => '未知',
    };
  }
}

final agentBridgePresenceProvider =
    StreamProvider.autoDispose<AgentBridgePresence>((ref) {
  final asClient = ref.watch(asClientProvider);
  final controller = StreamController<AgentBridgePresence>();
  Timer? timer;

  Future<void> load() async {
    try {
      final status = await asClient.getAgentStatus();
      if (!controller.isClosed) {
        controller.add(agentBridgePresenceFromStatus(status));
      }
    } catch (error) {
      if (!controller.isClosed) {
        controller.add(agentBridgePresenceFromError(error));
      }
    }
  }

  controller.add(const AgentBridgePresence.connecting());
  unawaited(load());
  timer = Timer.periodic(
    const Duration(seconds: 10),
    (_) => unawaited(load()),
  );
  ref.onDispose(() {
    timer?.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});

AgentBridgePresence agentBridgePresenceFromStatus(AgentStatus status) {
  if (!status.configured &&
      !status.connected &&
      status.agentRoomId.trim().isEmpty) {
    return AgentBridgePresence(
      state: AgentBridgePresenceState.unknown,
      status: status,
    );
  }
  return AgentBridgePresence(
    state: status.online
        ? AgentBridgePresenceState.online
        : AgentBridgePresenceState.offline,
    status: status,
  );
}

AgentBridgePresence agentBridgePresenceFromError(Object error) {
  return AgentBridgePresence(
    state: AgentBridgePresenceState.error,
    error: error,
  );
}

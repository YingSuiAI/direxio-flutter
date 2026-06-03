import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import '../../data/http_as_client.dart';
import 'auth_provider.dart';

/// Global AS Admin API client.
///
/// It reuses the active Matrix session's homeserver and the persisted
/// `portal_token`, matching p2p-matrix-as v2 Admin API authentication.
final asClientProvider = Provider<AsClient>((ref) {
  final client = ref.watch(matrixClientProvider);
  final portalToken =
      ref.watch(authStateNotifierProvider).valueOrNull?.portalToken;
  if (portalToken != null && portalToken.isNotEmpty) {
    return HttpAsClient.fromPortalSession(client, portalToken: portalToken);
  }
  return HttpAsClient.fromMatrixClient(client);
});

final agentStatusProvider = StreamProvider.autoDispose<AgentStatus>((ref) {
  final asClient = ref.watch(asClientProvider);
  final controller = StreamController<AgentStatus>();
  Timer? timer;

  Future<void> load() async {
    try {
      controller.add(await asClient.getAgentStatus());
    } catch (_) {
      controller.add(const AgentStatus(
        connected: false,
        lastSeen: null,
        roomsJoined: 0,
        messagesToday: 0,
      ));
    }
  }

  unawaited(load());
  timer = Timer.periodic(const Duration(seconds: 10), (_) => unawaited(load()));
  ref.onDispose(() {
    timer?.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import '../../data/http_as_client.dart';
import 'auth_provider.dart';

/// Global P2P product API client.
///
/// It reuses the active Matrix session's homeserver and the persisted AS
/// `access_token`, matching Direxio P2P backend P2P product API authentication.
final asClientProvider = Provider<AsClient>((ref) {
  final client = ref.watch(matrixClientProvider);
  final authNotifier = ref.read(authStateNotifierProvider.notifier);
  final auth = ref.watch(authStateNotifierProvider).valueOrNull;
  final authToken = auth?.portalToken?.trim() ?? '';
  final clientToken =
      auth?.isLoggedIn == true ? client.accessToken?.trim() ?? '' : '';
  final portalToken = authToken.isNotEmpty ? authToken : clientToken;
  if (portalToken.isNotEmpty) {
    return HttpAsClient.fromPortalSession(
      client,
      portalToken: portalToken,
      onAuthenticationRefresh: authNotifier.refreshPortalSessionForAsAdminToken,
      onAuthenticationFailedForToken:
          authNotifier.expireSessionDueInvalidTokenIfCurrent,
    );
  }
  throw AsClientException('P2P portal token is required');
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

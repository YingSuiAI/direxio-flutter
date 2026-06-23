import 'dart:async';

import 'package:flutter/foundation.dart';
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
  final portalToken =
      ref.watch(authStateNotifierProvider).valueOrNull?.portalToken;
  if (portalToken != null && portalToken.isNotEmpty) {
    return HttpAsClient.fromPortalSession(
      client,
      portalToken: portalToken,
      onAuthenticationRefresh: authNotifier.refreshPortalSessionForAsAdminToken,
      onAuthenticationFailed: authNotifier.expireSessionDueInvalidToken,
    );
  }
  debugPrint(
    'asClientProvider missing access_token; falling back to Matrix '
    'access token for P2P product API. This will fail on P2P API token auth with '
    'M_UNKNOWN_TOKEN.',
  );
  return HttpAsClient.fromMatrixClient(
    client,
    onAuthenticationRefresh: authNotifier.refreshPortalSessionForAsAdminToken,
    onAuthenticationFailed: () {
      final failedToken = client.accessToken?.trim() ?? '';
      return authNotifier.expireSessionDueInvalidTokenIfCurrent(failedToken);
    },
  );
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

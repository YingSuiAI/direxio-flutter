import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import '../../data/as_realtime_transport.dart';
import '../../data/http_as_client.dart';
import 'auth_provider.dart';

typedef AsClientSessionSnapshot = ({
  String homeserver,
  bool hasUsablePortalSession,
  bool isLoggedIn,
  String portalToken,
  String userId,
});

final asClientSessionSnapshotProvider =
    Provider<AsClientSessionSnapshot>((ref) {
  return ref.watch(
    authStateNotifierProvider.select((state) {
      final auth = state.valueOrNull;
      final portalToken = auth?.portalToken?.trim() ?? '';
      return (
        homeserver: auth?.homeserver?.trim() ?? '',
        hasUsablePortalSession:
            auth?.isLoggedIn == true && portalToken.isNotEmpty,
        isLoggedIn: auth?.isLoggedIn == true,
        portalToken: portalToken,
        userId: auth?.userId?.trim() ?? '',
      );
    }),
  );
});

final asHttpClientProvider = Provider<HttpAsClient>((ref) {
  final client = ref.watch(matrixClientProvider);
  final authNotifier = ref.read(authStateNotifierProvider.notifier);
  final auth = ref.watch(asClientSessionSnapshotProvider);
  final authToken = auth.portalToken;
  final clientToken = auth.isLoggedIn ? client.accessToken?.trim() ?? '' : '';
  final portalToken = clientToken.isNotEmpty ? clientToken : authToken;
  if (portalToken.isNotEmpty) {
    final homeserver = client.homeserver ?? Uri.tryParse(auth.homeserver);
    if (homeserver == null || homeserver.host.isEmpty) {
      throw AsClientException('P2P homeserver is required');
    }
    return HttpAsClient(
      baseUri: HttpAsClient.defaultProductBaseUri(homeserver),
      portalToken: portalToken,
      accessTokenForDebug: client.accessToken,
      onAuthenticationFailedForToken:
          authNotifier.expireSessionDueInvalidTokenIfCurrent,
      httpClient: client.httpClient,
    );
  }
  throw AsClientException('P2P portal token is required');
});

final asRealtimeTransportProvider = Provider<WsAsRealtimeTransport>((ref) {
  final httpClient = ref.watch(asHttpClientProvider);
  final transport = WsAsRealtimeTransport(
    baseUri: httpClient.realtimeBaseUri,
    createTicket: httpClient.createRealtimeWSTicket,
  );
  ref.onDispose(() {
    unawaited(transport.close());
  });
  return transport;
});

/// Global P2P product API client.
///
/// It reuses the active Matrix session's homeserver and the persisted AS
/// `access_token`, matching Direxio P2P backend P2P product API authentication.
/// Logged-in product actions use `GET /_p2p/ws` `client.request` frames.
final asClientProvider = Provider<AsClient>((ref) {
  final httpClient = ref.watch(asHttpClientProvider);
  final realtimeTransport = ref.watch(asRealtimeTransportProvider);
  return WsAsClient.fromHttpClient(
    httpClient,
    requestAction: realtimeTransport.requestAction,
  );
});

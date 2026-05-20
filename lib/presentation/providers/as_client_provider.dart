import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import '../../data/http_as_client.dart';
import 'auth_provider.dart';

/// Global AS Admin API client.
///
/// It reuses the active Matrix session's homeserver and access token, matching
/// p2p-matrix-as Admin API authentication.
final asClientProvider = Provider<AsClient>((ref) {
  final client = ref.watch(matrixClientProvider);
  return HttpAsClient.fromMatrixClient(client);
});

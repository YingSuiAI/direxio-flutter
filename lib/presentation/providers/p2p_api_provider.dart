import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bi_analytics_service.dart';
import '../../data/p2p_api_client.dart';

const _p2pApiBaseUrl = String.fromEnvironment(
  'P2P_API_BASE_URL',
  defaultValue: 'http://192.168.1.104:8888',
);

const _p2pBiSecret = String.fromEnvironment(
  'P2P_BI_SECRET',
  defaultValue: '',
);

const _p2pBiEnabled = bool.fromEnvironment(
  'P2P_BI_ENABLED',
  defaultValue: false,
);

final p2pApiClientProvider = Provider<P2pApiClient>((ref) {
  return P2pApiClient(
    baseUri: Uri.parse(_p2pApiBaseUrl),
    biSecret: _p2pBiSecret,
  );
});

final biAnalyticsServiceProvider = Provider<BiAnalyticsService>((ref) {
  return BiAnalyticsService(
    apiClient: ref.watch(p2pApiClientProvider),
    enabled: _p2pBiEnabled,
  );
});

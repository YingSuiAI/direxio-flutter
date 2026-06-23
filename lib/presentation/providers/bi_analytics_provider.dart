import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bi_analytics_service.dart';

const _p2pBiEnabled = bool.fromEnvironment(
  'P2P_BI_ENABLED',
  defaultValue: false,
);
const _p2pBiBaseUrl = String.fromEnvironment('P2P_BI_BASE_URL');
const _p2pBiSecret = String.fromEnvironment('P2P_BI_SECRET');

final biAnalyticsServiceProvider = Provider<BiAnalyticsService>((ref) {
  final baseUrl = _p2pBiBaseUrl.trim();
  final secret = _p2pBiSecret.trim();
  return BiAnalyticsService(
    enabled: _p2pBiEnabled,
    reporter: baseUrl.isEmpty || secret.isEmpty
        ? null
        : HttpBiAnalyticsReporter(
            baseUri: Uri.parse(baseUrl),
            secret: secret,
          ).call,
  );
});

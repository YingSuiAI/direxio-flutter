import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bi_analytics_service.dart';
import '../../data/im_public_config.dart';

const _p2pBiEnabled = bool.fromEnvironment(
  'P2P_BI_ENABLED',
  defaultValue: true,
);
const _p2pBiBaseUrl = String.fromEnvironment(
  'P2P_BI_BASE_URL',
  defaultValue: defaultImPublicBaseUrl,
);
const _p2pBiSecret = String.fromEnvironment(
  'P2P_BI_SECRET',
  defaultValue: defaultImPublicSecret,
);

final biAnalyticsServiceProvider = Provider<BiAnalyticsService>((ref) {
  final baseUrl = _p2pBiBaseUrl.trim();
  final secret = _p2pBiSecret.trim();
  return BiAnalyticsService(
    enabled: _p2pBiEnabled,
    reporter: HttpBiAnalyticsReporter(
      baseUri: Uri.parse(baseUrl),
      secret: secret,
    ).call,
  );
});

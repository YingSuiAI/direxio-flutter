import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bi_analytics_service.dart';

const _p2pBiEnabled = bool.fromEnvironment(
  'P2P_BI_ENABLED',
  defaultValue: false,
);

final biAnalyticsServiceProvider = Provider<BiAnalyticsService>((ref) {
  return BiAnalyticsService(enabled: _p2pBiEnabled);
});

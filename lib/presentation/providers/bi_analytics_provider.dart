import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bi_analytics_service.dart';
import '../../data/im_public_config.dart';

final biAnalyticsServiceProvider = Provider<BiAnalyticsService>((ref) {
  return BiAnalyticsService(
    enabled: true,
    reporter: HttpBiAnalyticsReporter(
      baseUri: Uri.parse(defaultImPublicBaseUrl),
      secret: defaultImPublicSecret,
    ).call,
  );
});

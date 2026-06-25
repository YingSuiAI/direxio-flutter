import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/im_public_config.dart';
import '../../data/im_public_client.dart';

final imPublicClientProvider = Provider<ImPublicClient>((ref) {
  return ImPublicClient(
    baseUri: Uri.parse(defaultImPublicBaseUrl),
    secret: defaultImPublicSecret,
  );
});

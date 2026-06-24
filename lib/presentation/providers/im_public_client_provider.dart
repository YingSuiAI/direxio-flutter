import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/im_public_config.dart';
import '../../data/im_public_client.dart';

const _p2pImPublicBaseUrl = String.fromEnvironment(
  'P2P_IM_PUBLIC_BASE_URL',
  defaultValue: defaultImPublicBaseUrl,
);
const _p2pImPublicSecret = String.fromEnvironment(
  'P2P_IM_PUBLIC_SECRET',
  defaultValue: defaultImPublicSecret,
);

final imPublicClientProvider = Provider<ImPublicClient>((ref) {
  final baseUrl = _p2pImPublicBaseUrl.trim();
  final secret = _p2pImPublicSecret.trim();
  return ImPublicClient(
    baseUri: Uri.parse(baseUrl),
    secret: secret,
  );
});

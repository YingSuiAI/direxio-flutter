import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/im_public_client.dart';

const _p2pImPublicBaseUrl = String.fromEnvironment('P2P_IM_PUBLIC_BASE_URL');

final imPublicClientProvider = Provider<ImPublicClient?>((ref) {
  final baseUrl = _p2pImPublicBaseUrl.trim();
  if (baseUrl.isEmpty) return null;
  return ImPublicClient(baseUri: Uri.parse(baseUrl));
});

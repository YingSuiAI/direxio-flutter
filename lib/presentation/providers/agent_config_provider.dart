import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import 'as_client_provider.dart';

final agentConfigProvider = FutureProvider.autoDispose<AgentConfig>((ref) {
  return ref.watch(asClientProvider).getAgentConfig();
});

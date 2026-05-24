import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_gateway_client.dart';

const _defaultAsGatewayUrl = String.fromEnvironment(
  'P2P_MATRIX_AS_URL',
  defaultValue: 'http://127.0.0.1:19091',
);

const _defaultAgentToken = String.fromEnvironment(
  'P2P_MATRIX_AGENT_TOKEN',
  defaultValue: '',
);

const _gatewayTimeoutMs = int.fromEnvironment(
  'P2P_MATRIX_AS_TIMEOUT_MS',
  defaultValue: 10000,
);

const _gatewayRetryCount = int.fromEnvironment(
  'P2P_MATRIX_AS_RETRY_COUNT',
  defaultValue: 2,
);

final asGatewayClientProvider = Provider<AsGatewayClient>((ref) {
  return AsGatewayClient(
    asUrl: _defaultAsGatewayUrl,
    agentToken: _defaultAgentToken,
    timeout: const Duration(milliseconds: _gatewayTimeoutMs),
    maxRetries: _gatewayRetryCount,
  );
});

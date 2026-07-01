import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import 'as_client_provider.dart';

final agentConfigProvider =
    StateNotifierProvider<AgentConfigController, AsyncValue<AgentConfig>>(
  AgentConfigController.new,
);

class AgentConfigController extends StateNotifier<AsyncValue<AgentConfig>> {
  AgentConfigController(this._ref) : super(const AsyncLoading()) {
    unawaited(reload());
  }

  final Ref _ref;

  Future<AgentConfig> reload() async {
    final previous = state.valueOrNull;
    if (previous == null) {
      state = const AsyncLoading();
    } else {
      state = AsyncData(previous);
    }
    try {
      final config = await _ref.read(asClientProvider).getAgentConfig();
      state = AsyncData(config);
      return config;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<AgentConfig> update(AgentConfig config) async {
    final previous = state;
    state = AsyncData(config);
    try {
      final saved = await _ref.read(asClientProvider).updateAgentConfig(config);
      state = AsyncData(saved);
      return saved;
    } catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

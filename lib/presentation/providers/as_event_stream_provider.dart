import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import '../call/voice_call_controller.dart';
import 'as_bootstrap_store_provider.dart';
import 'as_call_session_store_provider.dart';
import 'as_client_provider.dart';
import 'as_sync_cache_provider.dart';
import 'auth_provider.dart';
import 'product_conversations_provider.dart';
import 'voice_call_provider.dart';

typedef AsEventStreamOpener = Stream<AsEventStreamEvent> Function({
  int? since,
  String? lastEventId,
});

typedef AsBootstrapRefresh = Future<AsSyncBootstrap> Function();
typedef MatrixConversationRefresh = Future<void> Function();
typedef AsCallChanged = FutureOr<void> Function(AsCallSession call);

final asEventStreamRefreshProvider =
    Provider<AsEventStreamRefreshController?>((ref) {
  final auth = ref.watch(authStateNotifierProvider).valueOrNull;
  if (auth?.hasUsablePortalSession != true) return null;

  final asClient = ref.watch(asClientProvider);
  final bootstrapRepository = ref.watch(asBootstrapRepositoryProvider);
  final matrixClient = ref.watch(matrixClientProvider);
  final callSessionStore = ref.watch(asCallSessionStoreProvider.future);
  final voiceCallController = ref.watch(voiceCallControllerProvider);
  final controller = AsEventStreamRefreshController(
    openEvents: asClient.streamEvents,
    syncMatrixConversations: matrixClient.oneShotSync,
    loadBootstrap: bootstrapRepository.refresh,
    onCallChanged: (call) async {
      final store = await callSessionStore;
      await store.upsert(call);
      final controller = voiceCallController;
      if (controller is MatrixVoiceCallController) {
        await controller.applyCallUpdate(call);
      }
    },
    onBootstrapLoaded: (bootstrap) {
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
      ref.invalidate(productConversationsProvider);
    },
    onError: (error, stackTrace) {
      debugPrint('P2P event stream refresh failed: $error');
    },
  );
  controller.start();
  ref.onDispose(() {
    unawaited(controller.stop());
  });
  return controller;
});

class AsEventStreamRefreshController {
  AsEventStreamRefreshController({
    required AsEventStreamOpener openEvents,
    required MatrixConversationRefresh syncMatrixConversations,
    required AsBootstrapRefresh loadBootstrap,
    required void Function(AsSyncBootstrap bootstrap) onBootstrapLoaded,
    AsCallChanged? onCallChanged,
    void Function(Object error, StackTrace stackTrace)? onError,
    Duration reconnectDelay = const Duration(seconds: 3),
  })  : _openEvents = openEvents,
        _syncMatrixConversations = syncMatrixConversations,
        _loadBootstrap = loadBootstrap,
        _onBootstrapLoaded = onBootstrapLoaded,
        _onCallChanged = onCallChanged,
        _onError = onError,
        _reconnectDelay = reconnectDelay;

  final AsEventStreamOpener _openEvents;
  final MatrixConversationRefresh _syncMatrixConversations;
  final AsBootstrapRefresh _loadBootstrap;
  final void Function(AsSyncBootstrap bootstrap) _onBootstrapLoaded;
  final AsCallChanged? _onCallChanged;
  final void Function(Object error, StackTrace stackTrace)? _onError;
  final Duration _reconnectDelay;

  StreamSubscription<AsEventStreamEvent>? _subscription;
  Timer? _reconnectTimer;
  var _started = false;
  var _refreshInFlight = false;
  var _refreshQueued = false;
  int _lastSeq = 0;

  int get lastSeq => _lastSeq;

  void start() {
    if (_started) return;
    _started = true;
    _connect();
  }

  Future<void> stop() async {
    _started = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  void _connect() {
    if (!_started) return;
    _subscription?.cancel();
    _subscription = _openEvents(
      since: _lastSeq > 0 ? _lastSeq : null,
      lastEventId: _lastSeq > 0 ? _lastSeq.toString() : null,
    ).listen(
      _handleEvent,
      onError: (Object error, StackTrace? stackTrace) {
        _onError?.call(error, stackTrace ?? StackTrace.current);
        _scheduleReconnect();
      },
      onDone: _scheduleReconnect,
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    if (!_started) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, _connect);
  }

  void _handleEvent(AsEventStreamEvent event) {
    if (event.seq > _lastSeq) _lastSeq = event.seq;
    final call = asCallSessionFromEvent(event);
    if (call != null) {
      unawaited(_handleCallChanged(call));
      return;
    }
    if (_refreshInFlight) {
      _refreshQueued = true;
      return;
    }
    unawaited(_runRefreshLoop());
  }

  Future<void> _runRefreshLoop() async {
    _refreshInFlight = true;
    try {
      do {
        _refreshQueued = false;
        await _syncMatrixConversations();
        final bootstrap = await _loadBootstrap();
        _onBootstrapLoaded(bootstrap);
      } while (_refreshQueued);
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _handleCallChanged(AsCallSession call) async {
    try {
      await _onCallChanged?.call(call);
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }
}

AsCallSession? asCallSessionFromEvent(AsEventStreamEvent event) {
  if (event.type != 'call.changed') return null;
  final rawCall = event.payload['call'];
  if (rawCall is Map) {
    return AsCallSession.fromJson(rawCall.cast<String, dynamic>());
  }
  return AsCallSession.fromJson(event.payload);
}

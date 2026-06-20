import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import 'as_bootstrap_store_provider.dart';
import 'as_client_provider.dart';
import 'as_sync_cache_provider.dart';
import 'auth_provider.dart';

typedef AsEventStreamOpener = Stream<AsEventStreamEvent> Function({
  int? since,
  String? lastEventId,
});

typedef AsBootstrapRefresh = Future<AsSyncBootstrap> Function();
typedef AsUnreadRefresh = Future<AsSyncUnread> Function({int limitPerRoom});
typedef MatrixConversationRefresh = Future<void> Function();

final asEventStreamRefreshProvider =
    Provider<AsEventStreamRefreshController?>((ref) {
  final auth = ref.watch(authStateNotifierProvider).valueOrNull;
  if (auth?.isLoggedIn != true) return null;

  final asClient = ref.watch(asClientProvider);
  final bootstrapRepository = ref.watch(asBootstrapRepositoryProvider);
  final matrixClient = ref.watch(matrixClientProvider);
  final controller = AsEventStreamRefreshController(
    openEvents: asClient.streamEvents,
    syncMatrixConversations: matrixClient.oneShotSync,
    loadBootstrap: bootstrapRepository.refresh,
    loadUnread: ({int limitPerRoom = 200}) =>
        asClient.syncUnread(limitPerRoom: limitPerRoom),
    onBootstrapLoaded: (bootstrap) {
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
    },
    onUnreadRecovered: (unread) {
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.mergeUnread(unread),
          );
    },
    onError: (error, stackTrace) {
      debugPrint('AS event stream refresh failed: $error');
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
    required AsUnreadRefresh loadUnread,
    required void Function(AsSyncBootstrap bootstrap) onBootstrapLoaded,
    required void Function(AsSyncUnread unread) onUnreadRecovered,
    void Function(Object error, StackTrace stackTrace)? onError,
    Duration reconnectDelay = const Duration(seconds: 3),
  })  : _openEvents = openEvents,
        _syncMatrixConversations = syncMatrixConversations,
        _loadBootstrap = loadBootstrap,
        _loadUnread = loadUnread,
        _onBootstrapLoaded = onBootstrapLoaded,
        _onUnreadRecovered = onUnreadRecovered,
        _onError = onError,
        _reconnectDelay = reconnectDelay;

  final AsEventStreamOpener _openEvents;
  final MatrixConversationRefresh _syncMatrixConversations;
  final AsBootstrapRefresh _loadBootstrap;
  final AsUnreadRefresh _loadUnread;
  final void Function(AsSyncBootstrap bootstrap) _onBootstrapLoaded;
  final void Function(AsSyncUnread unread) _onUnreadRecovered;
  final void Function(Object error, StackTrace stackTrace)? _onError;
  final Duration _reconnectDelay;

  StreamSubscription<AsEventStreamEvent>? _subscription;
  Timer? _reconnectTimer;
  var _started = false;
  var _refreshInFlight = false;
  var _refreshQueued = false;
  var _lastRefreshNeedsUnread = false;
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
      onError: (Object error, StackTrace stackTrace) {
        _onError?.call(error, stackTrace);
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
    _lastRefreshNeedsUnread =
        _lastRefreshNeedsUnread || _eventNeedsUnreadRefresh(event.type);
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
        final needsUnread = _lastRefreshNeedsUnread;
        _lastRefreshNeedsUnread = false;
        await _syncMatrixConversations();
        final bootstrap = await _loadBootstrap();
        _onBootstrapLoaded(bootstrap);
        if (needsUnread) {
          final unread = await _loadUnread();
          _onUnreadRecovered(unread);
        }
      } while (_refreshQueued);
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    } finally {
      _refreshInFlight = false;
    }
  }
}

bool _eventNeedsUnreadRefresh(String type) {
  return type == 'room.message.projected' ||
      type == 'room.redaction.projected';
}

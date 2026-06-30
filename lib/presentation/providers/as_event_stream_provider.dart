import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import '../../data/as_event_cursor_store.dart';
import '../../data/matrix_foreground_sync.dart';
import '../call/voice_call_controller.dart';
import 'as_event_cursor_store_provider.dart';
import 'as_bootstrap_store_provider.dart';
import 'as_call_session_store_provider.dart';
import 'as_client_provider.dart';
import 'as_sync_cache_provider.dart';
import 'channel_provider.dart';
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
typedef AsEventSeqRead = Future<int> Function();
typedef AsEventSeqWrite = Future<void> Function(int seq);
typedef AsEventSeqAck = Future<void> Function(int seq);
typedef AsLifecycleReport = Future<void> Function(
  bool foreground, {
  String? appState,
  required bool hidden,
  required Map<String, bool> flags,
});
typedef AsFocusedRoomReport = Future<void> Function(String roomId);
typedef AsReadMarkerReport = Future<void> Function(
  String roomId,
  String eventId,
  int originServerTs,
  String action,
  String channelId,
);

Future<void> _noopReadMarkerReport(
  String roomId,
  String eventId,
  int originServerTs,
  String action,
  String channelId,
) async {}
typedef ProductCacheClear = Future<void> Function();
typedef AsProductEventApply = FutureOr<AsProductEventHandling> Function(
  AsEventStreamEvent event,
);

enum AsProductEventHandling { handled, bootstrapRequired }

final asEventStreamRefreshProvider =
    Provider<AsEventStreamRefreshController?>((ref) {
  final auth = ref.watch(authStateNotifierProvider).valueOrNull;
  final matrixClient = ref.watch(matrixClientProvider);
  final hasMatrixSession = auth?.isLoggedIn == true &&
      (matrixClient.accessToken?.trim().isNotEmpty ?? false);
  if (auth?.hasUsablePortalSession != true && !hasMatrixSession) return null;

  final realtimeTransport = ref.watch(asRealtimeTransportProvider);
  final bootstrapRepository = ref.watch(asBootstrapRepositoryProvider);
  final cursorStore = DeferredAsEventCursorStore(
    () => ref.read(asEventCursorStoreProvider.future),
  );
  final callSessionStore = ref.watch(asCallSessionStoreProvider.future);
  final voiceCallController = ref.watch(voiceCallControllerProvider);
  final controller = AsEventStreamRefreshController(
    openEvents: realtimeTransport.streamEvents,
    syncMatrixConversations: () => syncMatrixForegroundLight(matrixClient),
    loadBootstrap: bootstrapRepository.refresh,
    readLastSeq: cursorStore.readLastSeq,
    writeLastSeq: cursorStore.writeLastSeq,
    ackEventSeq: realtimeTransport.ackEventSeq,
    clearLastSeq: cursorStore.clear,
    clearProductCache: () async {
      await bootstrapRepository.clear();
      await cursorStore.clear();
      try {
        await (await ref.read(channelPostStoreProvider.future)).clear();
      } catch (_) {}
      try {
        await (await callSessionStore).clear();
      } catch (_) {}
      ref.read(asSyncCacheProvider.notifier).state = const AsSyncCacheState();
      ref.invalidate(productConversationsProvider);
    },
    applyProductEvent: (event) {
      return _applyProductEvent(ref, event);
    },
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
    reportLifecycle: realtimeTransport.reportLifecycle,
    reportFocusedRoom: realtimeTransport.reportFocusedRoom,
    updateReadMarker: (roomId, eventId, originServerTs, action, channelId) {
      return realtimeTransport.updateReadMarker(
        roomId: roomId,
        eventId: eventId,
        originServerTs: originServerTs,
        action: action,
        channelId: channelId,
      );
    },
    onError: (error, stackTrace) {
      debugPrint('P2P event stream refresh failed: $error');
    },
  );
  controller.start();
  ref.onDispose(() {
    unawaited(controller.stop());
    unawaited(realtimeTransport.close());
  });
  return controller;
});

class AsEventStreamRefreshController {
  AsEventStreamRefreshController({
    required AsEventStreamOpener openEvents,
    required MatrixConversationRefresh syncMatrixConversations,
    required AsBootstrapRefresh loadBootstrap,
    required void Function(AsSyncBootstrap bootstrap) onBootstrapLoaded,
    AsEventSeqRead? readLastSeq,
    AsEventSeqWrite? writeLastSeq,
    AsEventSeqAck? ackEventSeq,
    Future<void> Function()? clearLastSeq,
    ProductCacheClear? clearProductCache,
    AsProductEventApply? applyProductEvent,
    AsCallChanged? onCallChanged,
    AsLifecycleReport? reportLifecycle,
    AsFocusedRoomReport? reportFocusedRoom,
    AsReadMarkerReport? updateReadMarker,
    void Function(Object error, StackTrace stackTrace)? onError,
    Duration reconnectDelay = const Duration(seconds: 3),
  })  : _openEvents = openEvents,
        _syncMatrixConversations = syncMatrixConversations,
        _loadBootstrap = loadBootstrap,
        _onBootstrapLoaded = onBootstrapLoaded,
        _readLastSeq = readLastSeq ?? (() async => 0),
        _writeLastSeq = writeLastSeq ?? ((_) async {}),
        _ackEventSeq = ackEventSeq ?? ((_) async {}),
        _clearLastSeq = clearLastSeq ?? (() async {}),
        _clearProductCache = clearProductCache ?? (() async {}),
        _applyProductEvent = applyProductEvent,
        _onCallChanged = onCallChanged,
        _reportLifecycle = reportLifecycle ??
            ((_, {appState, required hidden, required flags}) async {}),
        _reportFocusedRoom = reportFocusedRoom ?? ((_) async {}),
        _updateReadMarker = updateReadMarker ?? _noopReadMarkerReport,
        _onError = onError,
        _reconnectDelay = reconnectDelay;

  final AsEventStreamOpener _openEvents;
  final MatrixConversationRefresh _syncMatrixConversations;
  final AsBootstrapRefresh _loadBootstrap;
  final void Function(AsSyncBootstrap bootstrap) _onBootstrapLoaded;
  final AsEventSeqRead _readLastSeq;
  final AsEventSeqWrite _writeLastSeq;
  final AsEventSeqAck _ackEventSeq;
  final Future<void> Function() _clearLastSeq;
  final ProductCacheClear _clearProductCache;
  final AsProductEventApply? _applyProductEvent;
  final AsCallChanged? _onCallChanged;
  final AsLifecycleReport _reportLifecycle;
  final AsFocusedRoomReport _reportFocusedRoom;
  final AsReadMarkerReport _updateReadMarker;
  final void Function(Object error, StackTrace stackTrace)? _onError;
  final Duration _reconnectDelay;

  StreamSubscription<AsEventStreamEvent>? _subscription;
  Timer? _reconnectTimer;
  var _started = false;
  var _refreshInFlight = false;
  var _refreshQueued = false;
  var _cursorResetInFlight = false;
  int _lastSeq = 0;
  int _refreshTargetSeq = 0;

  int get lastSeq => _lastSeq;

  Future<void> reportLifecycle({
    required bool foreground,
    String? appState,
    bool hidden = false,
    Map<String, bool> flags = const {},
  }) {
    return _reportLifecycle(
      foreground,
      appState: appState,
      hidden: hidden,
      flags: flags,
    );
  }

  Future<void> reportFocusedRoom(String roomId) {
    return _reportFocusedRoom(roomId.trim());
  }

  Future<void> clearFocusedRoom() {
    return _reportFocusedRoom('');
  }

  Future<void> updateReadMarker(
    String roomId,
    String eventId, {
    required int originServerTs,
    String action = 'sync.read_marker',
    String channelId = '',
  }) {
    return _updateReadMarker(
      roomId,
      eventId,
      originServerTs,
      action,
      channelId,
    );
  }

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_startFromStoredCursor());
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

  Future<void> _startFromStoredCursor() async {
    try {
      _lastSeq = await _readLastSeq();
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
      _lastSeq = 0;
    }
    if (!_started) return;
    _connect();
  }

  void _scheduleReconnect() {
    if (!_started) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, _connect);
  }

  void _handleEvent(AsEventStreamEvent event) {
    unawaited(_handleEventAsync(event));
  }

  Future<void> _handleEventAsync(AsEventStreamEvent event) async {
    if (_isCursorResetEvent(event)) {
      await _handleCursorReset(event);
      return;
    }
    if (event.type == 'agent.stream') {
      try {
        await _applyProductEvent?.call(event);
      } catch (error, stackTrace) {
        _onError?.call(error, stackTrace);
      }
      return;
    }
    if (event.seq > 0 && event.seq <= _lastSeq) return;
    final call = asCallSessionFromEvent(event);
    if (call != null) {
      await _handleCallChanged(call);
      await _persistSeq(event.seq);
      return;
    }
    final handler = _applyProductEvent;
    final result = handler == null
        ? AsProductEventHandling.bootstrapRequired
        : await handler(event);
    if (result == AsProductEventHandling.handled) {
      try {
        await _syncMatrixConversations();
        await _persistSeq(event.seq);
      } catch (error, stackTrace) {
        _onError?.call(error, stackTrace);
      }
      return;
    }
    _refreshTargetSeq =
        event.seq > _refreshTargetSeq ? event.seq : _refreshTargetSeq;
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
        await _persistSeq(_refreshTargetSeq);
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

  Future<void> _handleCursorReset(AsEventStreamEvent event) async {
    if (_cursorResetInFlight) return;
    _cursorResetInFlight = true;
    try {
      final subscription = _subscription;
      _subscription = null;
      await subscription?.cancel();
      await _clearLastSeq();
      await _clearProductCache();
      final bootstrap = await _loadBootstrap();
      _onBootstrapLoaded(bootstrap);
      await _persistSeq(_eventMaxSeq(event));
      _connect();
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
      _scheduleReconnect();
    } finally {
      _cursorResetInFlight = false;
    }
  }

  Future<void> _persistSeq(int seq) async {
    if (seq <= 0) return;
    if (seq > _lastSeq) _lastSeq = seq;
    await _writeLastSeq(_lastSeq);
    await _ackEventSeq(_lastSeq);
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

bool _isCursorResetEvent(AsEventStreamEvent event) {
  return event.type == 'p2p.cursor_reset' ||
      event.payload['recovery'] == 'bootstrap_required';
}

int _eventMaxSeq(AsEventStreamEvent event) {
  final raw = event.payload['max_seq'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

Future<AsProductEventHandling> _applyProductEvent(
  Ref ref,
  AsEventStreamEvent event,
) async {
  switch (event.type) {
    case 'contact.requested':
      final contact = ContactEntry.fromJson(event.payload);
      ref
          .read(asSyncCacheProvider.notifier)
          .update((state) => state.withContactEntry(contact));
      ref.invalidate(productConversationsProvider);
      return AsProductEventHandling.handled;
    case 'profile.changed':
      final roomType = event.payload['room_type']?.toString().trim() ?? '';
      final dissolved = event.payload['dissolved'] == true;
      if (dissolved && roomType.endsWith('.group')) {
        ref
            .read(asSyncCacheProvider.notifier)
            .update((state) => state.withoutGroup(event.roomId));
      } else if (dissolved && roomType.endsWith('.channel')) {
        final channelId =
            event.payload['channel_id']?.toString().trim() ?? event.roomId;
        ref
            .read(asSyncCacheProvider.notifier)
            .update((state) => state.withoutChannel(channelId));
      }
      ref.invalidate(productConversationsProvider);
      return AsProductEventHandling.handled;
    case 'room.member_policy.projected':
    case 'channel.join_request.changed':
    case 'agent_room.message':
    case 'agent.stream':
      ref.invalidate(productConversationsProvider);
      return AsProductEventHandling.handled;
    default:
      return AsProductEventHandling.bootstrapRequired;
  }
}

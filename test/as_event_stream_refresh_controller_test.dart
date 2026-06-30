import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/providers/as_event_stream_provider.dart';

void main() {
  test('events refresh Matrix sync and bootstrap metadata', () async {
    final streams = <StreamController<AsEventStreamEvent>>[];
    var matrixSyncCalls = 0;
    var bootstrapCalls = 0;
    final loadedBootstraps = <AsSyncBootstrap>[];

    final controller = AsEventStreamRefreshController(
      openEvents: ({int? since, String? lastEventId}) {
        final stream = StreamController<AsEventStreamEvent>();
        streams.add(stream);
        return stream.stream;
      },
      syncMatrixConversations: () async {
        matrixSyncCalls++;
      },
      loadBootstrap: () async {
        bootstrapCalls++;
        return _bootstrap();
      },
      onBootstrapLoaded: loadedBootstraps.add,
      reconnectDelay: const Duration(milliseconds: 5),
    );

    controller.start();
    await Future<void>.delayed(Duration.zero);
    streams.single.add(AsEventStreamEvent(
      seq: 10,
      type: 'contact.request.created',
      roomId: '!room:example.com',
      eventId: r'$event',
      payload: const {'status': 'pending'},
      createdAt: DateTime.utc(2026, 6, 20),
    ));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(matrixSyncCalls, 1);
    expect(bootstrapCalls, 1);
    expect(loadedBootstraps, hasLength(1));
    expect(controller.lastSeq, 10);

    await controller.stop();
  });

  test('call changed events update calls without full refresh', () async {
    final streams = <StreamController<AsEventStreamEvent>>[];
    var matrixSyncCalls = 0;
    var bootstrapCalls = 0;
    final calls = <AsCallSession>[];

    final controller = AsEventStreamRefreshController(
      openEvents: ({int? since, String? lastEventId}) {
        final stream = StreamController<AsEventStreamEvent>();
        streams.add(stream);
        return stream.stream;
      },
      syncMatrixConversations: () async {
        matrixSyncCalls++;
      },
      loadBootstrap: () async {
        bootstrapCalls++;
        return _bootstrap();
      },
      onBootstrapLoaded: (_) {},
      onCallChanged: calls.add,
      reconnectDelay: const Duration(milliseconds: 5),
    );

    controller.start();
    await Future<void>.delayed(Duration.zero);
    streams.single.add(AsEventStreamEvent(
      seq: 12,
      type: 'call.changed',
      roomId: '!room:example.com',
      payload: {
        'call': {
          'call_id': 'call-1',
          'room_id': '!room:example.com',
          'room_type': 'direct',
          'media_type': 'voice',
          'created_by_mxid': '@alice:example.com',
          'state': asCallStateRejected,
          'created_at': '2026-06-20T10:00:00Z',
          'ended_at': '2026-06-20T10:00:05Z',
          'ended_by_mxid': '@bob:example.com',
          'end_reason': 'user_reject',
          'duration_ms': 0,
        },
      },
      createdAt: DateTime.utc(2026, 6, 20),
    ));
    await Future<void>.delayed(Duration.zero);

    expect(calls, hasLength(1));
    expect(calls.single.callId, 'call-1');
    expect(calls.single.state, asCallStateRejected);
    expect(calls.single.endedByMxid, '@bob:example.com');
    expect(matrixSyncCalls, 0);
    expect(bootstrapCalls, 0);
    expect(controller.lastSeq, 12);

    await controller.stop();
  });

  test('handled product events use local reducer and persist sequence',
      () async {
    final streams = <StreamController<AsEventStreamEvent>>[];
    var matrixSyncCalls = 0;
    var bootstrapCalls = 0;
    final handledTypes = <String>[];
    final persisted = <int>[];

    final controller = AsEventStreamRefreshController(
      openEvents: ({int? since, String? lastEventId}) {
        final stream = StreamController<AsEventStreamEvent>();
        streams.add(stream);
        return stream.stream;
      },
      syncMatrixConversations: () async {
        matrixSyncCalls++;
      },
      loadBootstrap: () async {
        bootstrapCalls++;
        return _bootstrap();
      },
      onBootstrapLoaded: (_) {},
      applyProductEvent: (event) {
        handledTypes.add(event.type);
        return AsProductEventHandling.handled;
      },
      writeLastSeq: (seq) async {
        persisted.add(seq);
      },
      reconnectDelay: const Duration(milliseconds: 5),
    );

    controller.start();
    await Future<void>.delayed(Duration.zero);
    streams.single.add(AsEventStreamEvent(
      seq: 21,
      type: 'contact.requested',
      payload: const {'room_id': '!room:example.com'},
      createdAt: DateTime.utc(2026, 6, 29),
    ));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(handledTypes, ['contact.requested']);
    expect(matrixSyncCalls, 1);
    expect(bootstrapCalls, 0);
    expect(persisted, [21]);
    expect(controller.lastSeq, 21);

    await controller.stop();
  });

  test('handled events acknowledge the persisted sequence', () async {
    final streams = <StreamController<AsEventStreamEvent>>[];
    final persisted = <int>[];
    final acked = <int>[];

    final controller = AsEventStreamRefreshController(
      openEvents: ({int? since, String? lastEventId}) {
        final stream = StreamController<AsEventStreamEvent>();
        streams.add(stream);
        return stream.stream;
      },
      syncMatrixConversations: () async {},
      loadBootstrap: () async => _bootstrap(),
      onBootstrapLoaded: (_) {},
      applyProductEvent: (_) => AsProductEventHandling.handled,
      writeLastSeq: (seq) async {
        persisted.add(seq);
      },
      ackEventSeq: (seq) async {
        acked.add(seq);
      },
      reconnectDelay: const Duration(milliseconds: 5),
    );

    controller.start();
    await Future<void>.delayed(Duration.zero);
    streams.single.add(AsEventStreamEvent(
      seq: 31,
      type: 'contact.requested',
      payload: const {'room_id': '!room:example.com'},
      createdAt: DateTime.utc(2026, 6, 29),
    ));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(persisted, [31]);
    expect(acked, [31]);

    await controller.stop();
  });

  test('lifecycle and focused room changes are forwarded', () async {
    final lifecycle = <Map<String, Object?>>[];
    final focusedRooms = <String>[];
    final controller = AsEventStreamRefreshController(
      openEvents: ({int? since, String? lastEventId}) => const Stream.empty(),
      syncMatrixConversations: () async {},
      loadBootstrap: () async => _bootstrap(),
      onBootstrapLoaded: (_) {},
      reportLifecycle: (
        foreground, {
        String? appState,
        bool hidden = false,
        Map<String, bool> flags = const {},
      }) async {
        lifecycle.add({
          'foreground': foreground,
          'state': appState,
          'hidden': hidden,
          'flags': flags,
        });
      },
      reportFocusedRoom: (roomId) async {
        focusedRooms.add(roomId);
      },
    );

    await controller.reportLifecycle(
      foreground: false,
      appState: 'hidden',
      hidden: true,
      flags: const {'hidden': true},
    );
    await controller.reportFocusedRoom(' !room:example.com ');
    await controller.clearFocusedRoom();

    expect(lifecycle, [
      {
        'foreground': false,
        'state': 'hidden',
        'hidden': true,
        'flags': {'hidden': true},
      }
    ]);
    expect(focusedRooms, ['!room:example.com', '']);
  });

  test('read marker changes are forwarded to realtime command path', () async {
    final markers = <String>[];
    final controller = AsEventStreamRefreshController(
      openEvents: ({int? since, String? lastEventId}) => const Stream.empty(),
      syncMatrixConversations: () async {},
      loadBootstrap: () async => _bootstrap(),
      onBootstrapLoaded: (_) {},
      updateReadMarker: (roomId, eventId, originServerTs, action, channelId) {
        markers.add('$action|$roomId|$eventId|$originServerTs|$channelId');
        return Future<void>.value();
      },
    );

    await controller.updateReadMarker(
      '!room:example.com',
      r'$event',
      originServerTs: 1710000000000,
      action: 'channels.read_marker',
      channelId: 'channel-1',
    );

    expect(markers, [
      r'channels.read_marker|!room:example.com|$event|1710000000000|channel-1',
    ]);
  });

  test('agent stream events do not trigger bootstrap or matrix sync', () async {
    final streams = <StreamController<AsEventStreamEvent>>[];
    var matrixSyncCalls = 0;
    var bootstrapCalls = 0;
    final handledTypes = <String>[];

    final controller = AsEventStreamRefreshController(
      openEvents: ({int? since, String? lastEventId}) {
        final stream = StreamController<AsEventStreamEvent>();
        streams.add(stream);
        return stream.stream;
      },
      syncMatrixConversations: () async {
        matrixSyncCalls++;
      },
      loadBootstrap: () async {
        bootstrapCalls++;
        return _bootstrap();
      },
      onBootstrapLoaded: (_) {},
      applyProductEvent: (event) {
        handledTypes.add(event.type);
        return AsProductEventHandling.handled;
      },
      reconnectDelay: const Duration(milliseconds: 5),
    );

    controller.start();
    await Future<void>.delayed(Duration.zero);
    streams.single.add(const AsEventStreamEvent(
      seq: 0,
      type: 'agent.stream',
      roomId: '!agent:example.com',
      payload: {'stream_id': 'turn-1', 'delta': 'Hello'},
      createdAt: null,
    ));
    await Future<void>.delayed(Duration.zero);

    expect(handledTypes, ['agent.stream']);
    expect(matrixSyncCalls, 0);
    expect(bootstrapCalls, 0);
    expect(controller.lastSeq, 0);

    await controller.stop();
  });

  test(
      'cursor reset clears cache, bootstraps once, and reconnects from max seq',
      () async {
    final requests = <({int? since, String? lastEventId})>[];
    final streams = <StreamController<AsEventStreamEvent>>[];
    var clearCursorCalls = 0;
    var clearCacheCalls = 0;
    var bootstrapCalls = 0;
    final persisted = <int>[];

    final controller = AsEventStreamRefreshController(
      openEvents: ({int? since, String? lastEventId}) {
        requests.add((since: since, lastEventId: lastEventId));
        final stream = StreamController<AsEventStreamEvent>();
        streams.add(stream);
        return stream.stream;
      },
      syncMatrixConversations: () async {},
      loadBootstrap: () async {
        bootstrapCalls++;
        return _bootstrap();
      },
      onBootstrapLoaded: (_) {},
      readLastSeq: () async => 8,
      clearLastSeq: () async {
        clearCursorCalls++;
      },
      clearProductCache: () async {
        clearCacheCalls++;
      },
      writeLastSeq: (seq) async {
        persisted.add(seq);
      },
      reconnectDelay: const Duration(milliseconds: 5),
    );

    controller.start();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    streams.single.add(const AsEventStreamEvent(
      seq: 0,
      type: 'p2p.cursor_reset',
      payload: {
        'since': 8,
        'min_seq': 12,
        'max_seq': 19,
        'count': 8,
        'recovery': 'bootstrap_required',
      },
      createdAt: null,
    ));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(clearCursorCalls, 1);
    expect(clearCacheCalls, 1);
    expect(bootstrapCalls, 1);
    expect(persisted, [19]);
    expect(requests.first.since, 8);
    expect(requests.last.since, 19);
    expect(requests.last.lastEventId, '19');

    await controller.stop();
  });

  test('events queued during refresh run one follow-up refresh', () async {
    final streams = <StreamController<AsEventStreamEvent>>[];
    final syncCompleter = Completer<void>();
    var matrixSyncCalls = 0;
    var bootstrapCalls = 0;

    final controller = AsEventStreamRefreshController(
      openEvents: ({int? since, String? lastEventId}) {
        final stream = StreamController<AsEventStreamEvent>();
        streams.add(stream);
        return stream.stream;
      },
      syncMatrixConversations: () {
        matrixSyncCalls++;
        return matrixSyncCalls == 1 ? syncCompleter.future : Future.value();
      },
      loadBootstrap: () async {
        bootstrapCalls++;
        return _bootstrap();
      },
      onBootstrapLoaded: (_) {},
      reconnectDelay: const Duration(milliseconds: 5),
    );

    controller.start();
    await Future<void>.delayed(Duration.zero);
    streams.single.add(AsEventStreamEvent(
      seq: 10,
      type: 'contact.request.created',
      createdAt: DateTime.utc(2026, 6, 20),
    ));
    await Future<void>.delayed(Duration.zero);
    streams.single.add(AsEventStreamEvent(
      seq: 11,
      type: 'group.member.changed',
      createdAt: DateTime.utc(2026, 6, 20),
    ));
    await Future<void>.delayed(Duration.zero);

    expect(matrixSyncCalls, 1);
    expect(bootstrapCalls, 0);

    syncCompleter.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(matrixSyncCalls, 2);
    expect(bootstrapCalls, 2);
    expect(controller.lastSeq, 11);

    await controller.stop();
  });

  test('event stream reconnects from the latest event sequence', () async {
    final requests = <({int? since, String? lastEventId})>[];
    final streams = <StreamController<AsEventStreamEvent>>[];

    final controller = AsEventStreamRefreshController(
      openEvents: ({int? since, String? lastEventId}) {
        requests.add((since: since, lastEventId: lastEventId));
        final stream = StreamController<AsEventStreamEvent>();
        streams.add(stream);
        return stream.stream;
      },
      syncMatrixConversations: () async {},
      loadBootstrap: () async => _bootstrap(),
      onBootstrapLoaded: (_) {},
      reconnectDelay: const Duration(milliseconds: 5),
    );

    controller.start();
    await Future<void>.delayed(Duration.zero);
    streams.single.add(AsEventStreamEvent(
      seq: 42,
      type: 'contact.request.created',
      createdAt: DateTime.utc(2026, 6, 20),
    ));
    await Future<void>.delayed(Duration.zero);
    await streams.single.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(requests, hasLength(2));
    expect(requests.first.since, isNull);
    expect(requests.first.lastEventId, isNull);
    expect(requests.last.since, 42);
    expect(requests.last.lastEventId, '42');

    await controller.stop();
  });
}

AsSyncBootstrap _bootstrap() {
  return AsSyncBootstrap(
    syncedAt: DateTime.utc(2026, 6, 20),
    user: const AsSyncUser(userId: '@owner:example.com'),
    rooms: const [],
    contacts: const [],
    groups: const [],
    channels: const [],
    pending: const AsSyncPending.empty(),
  );
}

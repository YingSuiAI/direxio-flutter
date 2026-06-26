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

  test('agent presence events update presence without full refresh', () async {
    final streams = <StreamController<AsEventStreamEvent>>[];
    var matrixSyncCalls = 0;
    var bootstrapCalls = 0;
    final onlineStates = <bool>[];

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
      onAgentOnlineChanged: onlineStates.add,
      reconnectDelay: const Duration(milliseconds: 5),
    );

    controller.start();
    streams.single.add(AsEventStreamEvent(
      seq: 13,
      type: 'agent.presence',
      roomId: '!agent:example.com',
      payload: const {
        'online': false,
      },
      createdAt: DateTime.utc(2026, 6, 26),
    ));
    await Future<void>.delayed(Duration.zero);

    expect(onlineStates, [false]);
    expect(matrixSyncCalls, 0);
    expect(bootstrapCalls, 0);
    expect(controller.lastSeq, 13);

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

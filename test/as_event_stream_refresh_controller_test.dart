import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/providers/as_event_stream_provider.dart';

void main() {
  test('event stream refreshes Matrix, bootstrap, and unread state', () async {
    final streams = <StreamController<AsEventStreamEvent>>[];
    var matrixSyncCalls = 0;
    var bootstrapCalls = 0;
    var unreadCalls = 0;
    final loadedBootstraps = <AsSyncBootstrap>[];
    final loadedUnread = <AsSyncUnread>[];

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
      loadUnread: ({int limitPerRoom = 200}) async {
        unreadCalls++;
        return _unread();
      },
      onBootstrapLoaded: loadedBootstraps.add,
      onUnreadRecovered: loadedUnread.add,
      reconnectDelay: const Duration(milliseconds: 5),
    );

    controller.start();
    streams.single.add(AsEventStreamEvent(
      seq: 10,
      type: 'room.message.projected',
      roomId: '!room:example.com',
      eventId: r'$event',
      payload: const {'message_type': 'text'},
      createdAt: DateTime.utc(2026, 6, 20),
    ));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(matrixSyncCalls, 1);
    expect(bootstrapCalls, 1);
    expect(unreadCalls, 1);
    expect(loadedBootstraps, hasLength(1));
    expect(loadedUnread, hasLength(1));

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
      loadUnread: ({int limitPerRoom = 200}) async => _unread(),
      onBootstrapLoaded: (_) {},
      onUnreadRecovered: (_) {},
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

AsSyncUnread _unread() {
  return AsSyncUnread(
    syncedAt: DateTime.utc(2026, 6, 20),
    rooms: const [],
  );
}

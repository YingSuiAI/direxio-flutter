import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/as_realtime_transport.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('WS transport sends hello, lifecycle, focus, and ack frames', () async {
    final server = _FakeWebSocketServer();
    final transport = WsAsRealtimeTransport(
      baseUri: Uri.parse('https://node.example/_p2p'),
      createTicket: () async => const AsRealtimeWSTicket(ticket: 'ticket-1'),
      connect: server.connect,
      reconnectDelays: const [Duration.zero],
    );

    final events = <AsEventStreamEvent>[];
    final sub = transport.streamEvents(since: 8).listen(events.add);
    await server.waitForConnection();
    expect(server.connectedUris.single.toString(),
        'wss://node.example/_p2p/ws?ticket=ticket-1');
    expect(
        await server.takeClientFrame(), {'type': 'client.hello', 'since': 8});
    expect(await server.takeClientFrame(),
        {'type': 'client.lifecycle', 'foreground': true});

    await transport.reportLifecycle(true);
    await transport.reportFocusedRoom(' !room:example.com ');
    await transport.ackEventSeq(9);

    expect(await server.takeClientFrame(),
        {'type': 'client.lifecycle', 'foreground': true});
    expect(await server.takeClientFrame(),
        {'type': 'client.focus', 'room_id': '!room:example.com'});
    expect(await server.takeClientFrame(), {'type': 'client.ack', 'seq': 9});

    final readMarkerFuture = transport.updateReadMarker(
      roomId: ' !room:example.com ',
      eventId: r'$event',
      originServerTs: 1710000000000,
    );
    expect(await server.takeClientFrame(), {
      'type': 'client.command',
      'id': 'cmd-1',
      'action': 'sync.read_marker',
      'params': {
        'room_id': '!room:example.com',
        'event_id': r'$event',
        'origin_server_ts': 1710000000000,
      },
    });
    server.sendServerFrame({
      'type': 'server.command_result',
      'id': 'cmd-1',
      'result': {'status': 'ok'},
    });
    await readMarkerFuture;

    server.sendServerFrame({
      'type': 'server.event',
      'event': {
        'seq': 9,
        'type': 'contact.requested',
        'room_id': '!room:example.com',
        'payload': {'room_id': '!room:example.com'},
      },
    });
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single.seq, 9);
    expect(events.single.type, 'contact.requested');

    await sub.cancel().timeout(const Duration(seconds: 2));
    await transport.close();
  });

  test('WS transport maps agent stream frames into realtime events', () async {
    final server = _FakeWebSocketServer();
    final transport = WsAsRealtimeTransport(
      baseUri: Uri.parse('https://node.example/_p2p'),
      createTicket: () async => const AsRealtimeWSTicket(ticket: 'ticket-1'),
      connect: server.connect,
      reconnectDelays: const [Duration.zero],
    );

    final events = <AsEventStreamEvent>[];
    final sub = transport.streamEvents().listen(events.add);
    await server.waitForConnection();
    await server.takeClientFrame();
    await server.takeClientFrame();

    server.sendServerFrame({
      'type': 'server.agent_stream',
      'room_id': '!agent:example.com',
      'stream_id': 'turn-1',
      'seq': 1,
      'delta': 'Hello',
      'done': false,
      'created_at': '2026-06-30T00:00:00Z',
    });
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single.type, 'agent.stream');
    expect(events.single.roomId, '!agent:example.com');
    expect(events.single.payload['stream_id'], 'turn-1');
    expect(events.single.payload['delta'], 'Hello');

    await sub.cancel().timeout(const Duration(seconds: 2));
    await transport.close();
  });

  test('WS transport fails read marker command when not connected', () async {
    final transport = WsAsRealtimeTransport(
      baseUri: Uri.parse('https://node.example/_p2p'),
      createTicket: () async => const AsRealtimeWSTicket(ticket: 'ticket-1'),
      reconnectDelays: const [Duration.zero],
    );

    await expectLater(
      transport.updateReadMarker(
        roomId: '!room:example.com',
        eventId: r'$event',
        originServerTs: 1710000000000,
      ),
      throwsA(isA<AsClientException>()),
    );
  });

  test('WS transport reconnects with latest seq and replays state', () async {
    final server = _FakeWebSocketServer();
    var tickets = 0;
    final transport = WsAsRealtimeTransport(
      baseUri: Uri.parse('http://localhost:8448/_p2p'),
      createTicket: () async =>
          AsRealtimeWSTicket(ticket: 'ticket-${++tickets}'),
      connect: server.connect,
      reconnectDelays: const [Duration.zero, Duration.zero],
    );

    final events = <AsEventStreamEvent>[];
    final sub = transport.streamEvents(since: 1).listen(events.add);
    await server.waitForConnection();
    expect(
        await server.takeClientFrame(), {'type': 'client.hello', 'since': 1});
    await transport.reportLifecycle(true);
    await transport.reportFocusedRoom('!focused:localhost');
    server.sendServerFrame({
      'type': 'server.event',
      'event': {'seq': 2, 'type': 'call.changed', 'payload': {}},
    });
    await Future<void>.delayed(Duration.zero);
    expect(events.single.seq, 2);

    await server.closeActive();
    await server.waitForConnection(count: 2);
    expect(server.connectedUris.last.toString(),
        'ws://localhost:8448/_p2p/ws?ticket=ticket-2');
    expect(
        await server.takeClientFrame(), {'type': 'client.hello', 'since': 2});
    expect(await server.takeClientFrame(),
        {'type': 'client.lifecycle', 'foreground': true});
    expect(await server.takeClientFrame(),
        {'type': 'client.focus', 'room_id': '!focused:localhost'});

    await sub.cancel().timeout(const Duration(seconds: 2));
    await transport.close();
  });

  test('fallback transport uses SSE when WS fails before yielding events',
      () async {
    final fallbackEvent = AsEventStreamEvent(
      seq: 5,
      type: 'contact.requested',
      createdAt: DateTime.utc(2026, 6, 29),
    );
    final transport = FallbackAsRealtimeTransport(
      primary: _FailingTransport(),
      fallback: _StaticTransport(Stream.value(fallbackEvent)),
    );

    final events = await transport.streamEvents(since: 4).toList();

    expect(events.single.seq, 5);
  });

  test('fallback transport propagates read marker command failures', () async {
    final transport = FallbackAsRealtimeTransport(
      primary: _FailingTransport(),
      fallback: _StaticTransport(const Stream.empty()),
    );

    await expectLater(
      transport.updateReadMarker(
        roomId: '!room:example.com',
        eventId: r'$event',
        originServerTs: 1710000000000,
      ),
      throwsStateError,
    );
  });
}

class _FakeWebSocketServer {
  final connectedUris = <Uri>[];
  final _connections = <_FakeWebSocketChannel>[];
  final _connectionEvents = StreamController<void>.broadcast();

  Future<WebSocketChannel> connect(Uri uri) async {
    connectedUris.add(uri);
    final channel = _FakeWebSocketChannel();
    _connections.add(channel);
    _connectionEvents.add(null);
    return channel;
  }

  Future<void> waitForConnection({int count = 1}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (_connections.length < count) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('timed out waiting for WS connection $count');
      }
      await _connectionEvents.stream.first;
    }
  }

  Future<Map<String, Object?>> takeClientFrame() async {
    final raw = await _connections.last.takeClientFrame();
    return jsonDecode(raw) as Map<String, Object?>;
  }

  void sendServerFrame(Map<String, Object?> frame) {
    _connections.last.sendServerFrame(frame);
  }

  Future<void> closeActive() => _connections.last.close();
}

class _FakeWebSocketChannel implements WebSocketChannel {
  _FakeWebSocketChannel()
      : _stream = StreamController<dynamic>(),
        _sink = _RecordingSink() {
    _sink.onClose = close;
  }

  final StreamController<dynamic> _stream;
  final _RecordingSink _sink;

  @override
  Stream get stream => _stream.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  Future<String> takeClientFrame() => _sink.take();

  void sendServerFrame(Map<String, Object?> frame) {
    _stream.add(jsonEncode(frame));
  }

  Future<void> close() async {
    if (!_stream.isClosed) {
      unawaited(_stream.close());
    }
  }
}

class _RecordingSink implements WebSocketSink {
  final frames = <String>[];
  Future<void> Function()? onClose;

  @override
  void add(event) {
    frames.add(event as String);
  }

  Future<String> take() async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (frames.isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('timed out waiting for client WS frame');
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    return frames.removeAt(0);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {
    await for (final event in stream) {
      add(event);
    }
  }

  @override
  Future close([int? closeCode, String? closeReason]) async {
    unawaited(onClose?.call() ?? Future<void>.value());
  }

  @override
  Future get done async {}
}

class _FailingTransport implements AsRealtimeTransport {
  @override
  Stream<AsEventStreamEvent> streamEvents({int? since, String? lastEventId}) {
    return Stream<AsEventStreamEvent>.error(StateError('ws failed'));
  }

  @override
  Future<void> ackEventSeq(int seq) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> reportFocusedRoom(String roomId) async {}

  @override
  Future<void> reportLifecycle(bool foreground) async {}

  @override
  Future<void> updateReadMarker({
    required String roomId,
    required String eventId,
    required int originServerTs,
    String action = 'sync.read_marker',
    String channelId = '',
  }) async {
    throw StateError('ws command failed');
  }
}

class _StaticTransport implements AsRealtimeTransport {
  _StaticTransport(this._stream);

  final Stream<AsEventStreamEvent> _stream;

  @override
  Stream<AsEventStreamEvent> streamEvents({int? since, String? lastEventId}) {
    return _stream;
  }

  @override
  Future<void> ackEventSeq(int seq) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> reportFocusedRoom(String roomId) async {}

  @override
  Future<void> reportLifecycle(bool foreground) async {}

  @override
  Future<void> updateReadMarker({
    required String roomId,
    required String eventId,
    required int originServerTs,
    String action = 'sync.read_marker',
    String channelId = '',
  }) async {}
}

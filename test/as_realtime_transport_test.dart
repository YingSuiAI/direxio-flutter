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
      'type': 'client.request',
      'id': 'req-1',
      'action': 'sync.read_marker',
      'params': {
        'room_id': '!room:example.com',
        'event_id': r'$event',
        'origin_server_ts': 1710000000000,
      },
    });
    server.sendServerFrame({
      'type': 'server.response',
      'id': 'req-1',
      'action': 'sync.read_marker',
      'ok': true,
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

  test('WS transport can send one-shot request before event stream starts',
      () async {
    final server = _FakeWebSocketServer();
    final transport = WsAsRealtimeTransport(
      baseUri: Uri.parse('https://node.example/_p2p'),
      createTicket: () async => const AsRealtimeWSTicket(ticket: 'ticket-1'),
      connect: server.connect,
      reconnectDelays: const [Duration.zero],
    );

    final request = transport.requestAction(
      'contacts.list',
      const {},
    );
    await server.waitForConnection();
    expect(await server.takeClientFrame(), {'type': 'client.hello'});
    expect(await server.takeClientFrame(),
        {'type': 'client.lifecycle', 'foreground': true});
    expect(await server.takeClientFrame(), {
      'type': 'client.request',
      'id': 'req-1',
      'action': 'contacts.list',
      'params': {},
    });
    server.sendServerFrame({
      'type': 'server.response',
      'id': 'req-1',
      'action': 'contacts.list',
      'ok': true,
      'result': {
        'contacts': [],
      },
    });
    final result = await request;
    expect(result['contacts'], isEmpty);
    await transport.close();
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

  test('WS request does not retry non-idempotent action after disconnect',
      () async {
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

    final request = transport.requestAction(
      'groups.create',
      const {'name': 'No retry'},
    );
    expect(await server.takeClientFrame(), {
      'type': 'client.request',
      'id': 'req-1',
      'action': 'groups.create',
      'params': {'name': 'No retry'},
    });
    await server.closeActive();
    await expectLater(request, throwsA(isA<AsClientException>()));
    await Future<void>.delayed(Duration.zero);
    await server.waitForConnection(count: 2);
    final createRequests = server.allClientFrames.where((frame) {
      return frame['type'] == 'client.request' &&
          frame['action'] == 'groups.create';
    }).toList(growable: false);
    expect(createRequests, hasLength(1));

    await sub.cancel().timeout(const Duration(seconds: 2));
    await transport.close();
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

  List<Map<String, Object?>> get allClientFrames {
    return [
      for (final connection in _connections)
        for (final raw in connection.allClientFrames)
          jsonDecode(raw) as Map<String, Object?>,
    ];
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

  List<String> get allClientFrames => _sink.allFrames;

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
  final allFrames = <String>[];
  Future<void> Function()? onClose;

  @override
  void add(event) {
    final value = event as String;
    frames.add(value);
    allFrames.add(value);
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

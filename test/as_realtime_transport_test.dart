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
    server.sendReady();
    expect(await server.takeClientFrame(), _lifecycleFrame());

    await transport.reportLifecycle(
      true,
      appState: 'resumed',
      flags: const {'resumed': true},
    );
    await transport.reportFocusedRoom(' !room:example.com ');
    await transport.ackEventSeq(9);

    expect(
      await server.takeClientFrame(),
      _lifecycleFrame(appState: 'resumed', flags: const {'resumed': true}),
    );
    expect(await server.takeClientFrame(), _focusFrame('!room:example.com'));
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

  test('WS transport rejects request before realtime stream is ready',
      () async {
    final server = _FakeWebSocketServer();
    final transport = WsAsRealtimeTransport(
      baseUri: Uri.parse('https://node.example/_p2p'),
      createTicket: () async => const AsRealtimeWSTicket(ticket: 'ticket-1'),
      connect: server.connect,
      reconnectDelays: const [Duration.zero],
    );

    await expectLater(
      transport.requestAction('contacts.list', const {}),
      throwsA(
        isA<AsClientException>().having(
          (error) => error.message,
          'message',
          'WS transport is not ready before request',
        ),
      ),
    );
    expect(server.connectedUris, isEmpty);
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
    server.sendReady();
    expect(await server.takeClientFrame(), _lifecycleFrame());
    await transport.reportLifecycle(
      false,
      appState: 'hidden',
      hidden: true,
      flags: const {'hidden': true, 'background': true},
    );
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
    server.sendReady();
    expect(
      await server.takeClientFrame(),
      _lifecycleFrame(
        foreground: false,
        appState: 'hidden',
        hidden: true,
        flags: const {'hidden': true, 'background': true},
      ),
    );
    expect(await server.takeClientFrame(), _focusFrame('!focused:localhost'));

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
    server.sendReady();
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

  test('WS request fails fast while stream has not received ready', () async {
    final server = _FakeWebSocketServer();
    var tickets = 0;
    final transport = WsAsRealtimeTransport(
      baseUri: Uri.parse('https://node.example/_p2p'),
      createTicket: () async =>
          AsRealtimeWSTicket(ticket: 'ticket-${++tickets}'),
      connect: server.connect,
      reconnectDelays: const [Duration.zero],
    );

    final events = <AsEventStreamEvent>[];
    final sub = transport.streamEvents().listen(events.add);
    await server.waitForConnection();
    expect(server.connectedUris.first.toString(),
        'wss://node.example/_p2p/ws?ticket=ticket-1');
    expect(await server.takeClientFrame(), {'type': 'client.hello'});

    await expectLater(
      transport.requestAction('contacts.list', const {}),
      throwsA(
        isA<AsClientException>().having(
          (error) => error.message,
          'message',
          'WS transport is not ready before request',
        ),
      ),
    );
    expect(server.connectedUris, hasLength(1));
    await sub.cancel().timeout(const Duration(seconds: 2));
    await transport.close();
  });

  test('WS request does not retry after request is sent', () async {
    final server = _FakeWebSocketServer();
    var tickets = 0;
    final transport = WsAsRealtimeTransport(
      baseUri: Uri.parse('https://node.example/_p2p'),
      createTicket: () async =>
          AsRealtimeWSTicket(ticket: 'ticket-${++tickets}'),
      connect: server.connect,
      reconnectDelays: const [Duration.zero],
    );

    final events = <AsEventStreamEvent>[];
    final sub = transport.streamEvents().listen(events.add);
    await server.waitForConnection();
    expect(await server.takeClientFrame(), {'type': 'client.hello'});
    server.sendReady();
    expect(await server.takeClientFrame(), _lifecycleFrame());
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

    await expectLater(
      request,
      throwsA(
        isA<AsClientException>().having(
          (error) => error.message,
          'message',
          'WS connection closed before response',
        ),
      ),
    );
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

  void sendReady() {
    sendServerFrame({
      'type': 'server.ready',
      'role': 'owner',
      'heartbeat_interval_ms': 25000,
    });
  }

  Future<void> closeActive() => _connections.last.close();
}

Map<String, Object?> _lifecycleFrame({
  bool foreground = true,
  String? appState,
  bool hidden = false,
  Map<String, bool> flags = const {},
}) {
  return {
    'type': 'client.lifecycle',
    'foreground': foreground,
    if (appState != null) 'state': appState,
    'hidden': hidden,
    'flags': {
      ...flags,
      'foreground': foreground,
      'background': !foreground,
      'hidden': hidden,
    },
  };
}

Map<String, Object?> _focusFrame(String roomId) {
  final focused = roomId.trim().isNotEmpty;
  return {
    'type': 'client.focus',
    'room_id': roomId.trim(),
    'focused': focused,
    'flags': {'focused': focused},
  };
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

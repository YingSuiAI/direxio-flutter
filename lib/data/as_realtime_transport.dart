import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'as_client.dart';
import 'as_realtime_ws_connector.dart';

typedef AsRealtimeTicketFactory = Future<AsRealtimeWSTicket> Function();
typedef AsRealtimeWSConnector = FutureOr<WebSocketChannel> Function(Uri uri);

class AsRealtimeWSTicket {
  const AsRealtimeWSTicket({
    required this.ticket,
    this.expiresInMs = 0,
  });

  final String ticket;
  final int expiresInMs;

  factory AsRealtimeWSTicket.fromJson(Map<String, dynamic> json) {
    return AsRealtimeWSTicket(
      ticket: json['ticket']?.toString() ?? '',
      expiresInMs: _parseInt(json['expires_in_ms']),
    );
  }
}

abstract class AsRealtimeTransport {
  Stream<AsEventStreamEvent> streamEvents({int? since, String? lastEventId});

  Future<void> updateReadMarker({
    required String roomId,
    required String eventId,
    required int originServerTs,
    String action = 'sync.read_marker',
    String channelId = '',
  });

  Future<void> reportLifecycle(bool foreground);

  Future<void> reportFocusedRoom(String roomId);

  Future<void> ackEventSeq(int seq);

  Future<void> close();
}

class SseAsRealtimeTransport implements AsRealtimeTransport {
  SseAsRealtimeTransport(this._openEvents);

  final Stream<AsEventStreamEvent> Function({
    int? since,
    String? lastEventId,
  }) _openEvents;

  @override
  Stream<AsEventStreamEvent> streamEvents({int? since, String? lastEventId}) {
    return _openEvents(since: since, lastEventId: lastEventId);
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

class FallbackAsRealtimeTransport implements AsRealtimeTransport {
  FallbackAsRealtimeTransport({
    required AsRealtimeTransport primary,
    required AsRealtimeTransport fallback,
  })  : _primary = primary,
        _fallback = fallback;

  final AsRealtimeTransport _primary;
  final AsRealtimeTransport _fallback;

  @override
  Stream<AsEventStreamEvent> streamEvents(
      {int? since, String? lastEventId}) async* {
    var cursor = _cursorFrom(since, lastEventId);
    try {
      await for (final event
          in _primary.streamEvents(since: since, lastEventId: lastEventId)) {
        if (event.seq > cursor) cursor = event.seq;
        yield event;
      }
    } catch (_) {
      yield* _fallback.streamEvents(
        since: cursor > 0 ? cursor : since,
        lastEventId: cursor > 0 ? cursor.toString() : lastEventId,
      );
    }
  }

  @override
  Future<void> ackEventSeq(int seq) async {
    await _primary.ackEventSeq(seq);
    await _fallback.ackEventSeq(seq);
  }

  @override
  Future<void> close() async {
    await _primary.close();
    await _fallback.close();
  }

  @override
  Future<void> reportFocusedRoom(String roomId) async {
    await _primary.reportFocusedRoom(roomId);
    await _fallback.reportFocusedRoom(roomId);
  }

  @override
  Future<void> reportLifecycle(bool foreground) async {
    await _primary.reportLifecycle(foreground);
    await _fallback.reportLifecycle(foreground);
  }

  @override
  Future<void> updateReadMarker({
    required String roomId,
    required String eventId,
    required int originServerTs,
    String action = 'sync.read_marker',
    String channelId = '',
  }) async {
    await _primary.updateReadMarker(
      roomId: roomId,
      eventId: eventId,
      originServerTs: originServerTs,
      action: action,
      channelId: channelId,
    );
  }
}

class WsAsRealtimeTransport implements AsRealtimeTransport {
  WsAsRealtimeTransport({
    required Uri baseUri,
    required AsRealtimeTicketFactory createTicket,
    AsRealtimeWSConnector? connect,
    List<Duration>? reconnectDelays,
  })  : _baseUri = baseUri,
        _createTicket = createTicket,
        _connect = connect ?? connectAsRealtimeWebSocket,
        _reconnectDelays = reconnectDelays ??
            const [
              Duration(seconds: 1),
              Duration(seconds: 2),
              Duration(seconds: 5),
              Duration(seconds: 10),
              Duration(seconds: 30),
            ];

  final Uri _baseUri;
  final AsRealtimeTicketFactory _createTicket;
  final AsRealtimeWSConnector _connect;
  final List<Duration> _reconnectDelays;

  WebSocketChannel? _channel;
  bool _closed = false;
  bool? _foreground;
  String? _focusedRoomId;
  int _latestSeq = 0;
  int _nextCommandId = 0;
  final Map<String, Completer<Map<String, dynamic>>> _pendingCommands = {};

  @override
  Stream<AsEventStreamEvent> streamEvents({int? since, String? lastEventId}) {
    _closed = false;
    _latestSeq = _cursorFrom(since, lastEventId);
    late StreamController<AsEventStreamEvent> controller;
    controller = StreamController<AsEventStreamEvent>(
      onListen: () {
        unawaited(_runEventLoop(controller));
      },
      onCancel: () async {
        await close();
      },
    );
    return controller.stream;
  }

  Future<void> _runEventLoop(
    StreamController<AsEventStreamEvent> controller,
  ) async {
    var failures = 0;
    try {
      while (!_closed) {
        try {
          final channel = await _connectWithTicket(_latestSeq);
          failures = 0;
          await for (final raw in channel.stream) {
            if (_closed || controller.isClosed) return;
            final event = _eventFromServerFrame(raw);
            if (event == null) continue;
            if (event.seq > _latestSeq) _latestSeq = event.seq;
            controller.add(event);
          }
          if (identical(_channel, channel)) {
            _channel = null;
          }
          _failPendingCommands(AsClientException('WS connection closed'));
        } catch (_) {
          if (_closed) return;
          _failPendingCommands(AsClientException('WS connection failed'));
          final delay = _reconnectDelay(failures++);
          if (delay > Duration.zero) {
            await Future<void>.delayed(delay);
          }
        }
      }
    } finally {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  Future<WebSocketChannel> _connectWithTicket(int since) async {
    final ticket = await _createTicket();
    final channel = await _connect(_wsUri(ticket.ticket));
    _channel = channel;
    await channel.ready;
    _sendFrame({
      'type': 'client.hello',
      if (since > 0) 'since': since,
    });
    _sendFrame({
      'type': 'client.lifecycle',
      'foreground': _foreground ?? true,
    });
    final focusedRoomId = _focusedRoomId;
    if (focusedRoomId != null) {
      _sendFrame({'type': 'client.focus', 'room_id': focusedRoomId});
    }
    return channel;
  }

  Uri _wsUri(String ticket) {
    final cleanPath = _baseUri.path.endsWith('/')
        ? '${_baseUri.path}ws'
        : '${_baseUri.path}/ws';
    final scheme = _baseUri.scheme == 'http' ? 'ws' : 'wss';
    return _baseUri.replace(
      scheme: scheme,
      path: cleanPath,
      queryParameters: {'ticket': ticket},
    );
  }

  Duration _reconnectDelay(int failureCount) {
    if (_reconnectDelays.isEmpty) return Duration.zero;
    final index = failureCount < _reconnectDelays.length
        ? failureCount
        : _reconnectDelays.length - 1;
    return _reconnectDelays[index];
  }

  AsEventStreamEvent? _eventFromServerFrame(Object? raw) {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) return null;
    final frame = decoded.cast<String, dynamic>();
    switch (frame['type']) {
      case 'server.event':
        final rawEvent = frame['event'];
        if (rawEvent is! Map) return null;
        return AsEventStreamEvent.fromJson(rawEvent.cast<String, dynamic>());
      case 'server.agent_stream':
        return AsEventStreamEvent(
          seq: 0,
          type: 'agent.stream',
          roomId: frame['room_id']?.toString() ?? '',
          payload: Map<String, dynamic>.from(frame),
          createdAt: DateTime.tryParse(frame['created_at']?.toString() ?? ''),
        );
      case 'server.command_result':
      case 'server.command_error':
        _completeCommand(frame);
        return null;
      case 'server.cursor_reset':
        return AsEventStreamEvent(
          seq: 0,
          type: 'p2p.cursor_reset',
          payload: Map<String, dynamic>.from(frame),
          createdAt: null,
        );
      case 'server.error':
        throw AsClientException(frame['error']?.toString() ?? 'WS error');
      default:
        return null;
    }
  }

  @override
  Future<void> reportLifecycle(bool foreground) async {
    _foreground = foreground;
    _sendFrame({'type': 'client.lifecycle', 'foreground': foreground});
  }

  @override
  Future<void> reportFocusedRoom(String roomId) async {
    _focusedRoomId = roomId.trim();
    _sendFrame({'type': 'client.focus', 'room_id': _focusedRoomId});
  }

  @override
  Future<void> ackEventSeq(int seq) async {
    if (seq <= 0) return;
    _sendFrame({'type': 'client.ack', 'seq': seq});
  }

  @override
  Future<void> updateReadMarker({
    required String roomId,
    required String eventId,
    required int originServerTs,
    String action = 'sync.read_marker',
    String channelId = '',
  }) async {
    final trimmedRoomId = roomId.trim();
    final trimmedEventId = eventId.trim();
    if (trimmedRoomId.isEmpty || trimmedEventId.isEmpty) return;
    if (_channel == null) {
      throw AsClientException('WS realtime is not connected');
    }
    final commandId = 'cmd-${++_nextCommandId}';
    final completer = Completer<Map<String, dynamic>>();
    _pendingCommands[commandId] = completer;
    _sendFrame({
      'type': 'client.command',
      'id': commandId,
      'action': action,
      'params': {
        'room_id': trimmedRoomId,
        'event_id': trimmedEventId,
        'origin_server_ts': originServerTs,
        if (channelId.trim().isNotEmpty) 'channel_id': channelId.trim(),
      },
    });
    try {
      final frame = await completer.future.timeout(const Duration(seconds: 5));
      if (frame['type'] == 'server.command_error') {
        throw AsClientException(
          frame['error']?.toString() ?? 'WS command error',
          statusCode: _parseInt(frame['status']),
        );
      }
    } finally {
      _pendingCommands.remove(commandId);
    }
  }

  void _completeCommand(Map<String, dynamic> frame) {
    final id = frame['id']?.toString() ?? '';
    final completer = _pendingCommands[id];
    if (completer == null || completer.isCompleted) return;
    completer.complete(frame);
  }

  void _failPendingCommands(Object error) {
    if (_pendingCommands.isEmpty) return;
    final pending = List<Completer<Map<String, dynamic>>>.from(
      _pendingCommands.values,
    );
    _pendingCommands.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
  }

  void _sendFrame(Map<String, Object?> frame) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(frame));
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    _closed = true;
    final channel = _channel;
    _channel = null;
    _failPendingCommands(AsClientException('WS realtime is closed'));
    await channel?.sink.close();
  }
}

int _cursorFrom(int? since, String? lastEventId) {
  final fromLastEventId = int.tryParse(lastEventId?.trim() ?? '') ?? 0;
  final fromSince = since ?? 0;
  return fromSince > fromLastEventId ? fromSince : fromLastEventId;
}

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

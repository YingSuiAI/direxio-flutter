import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'as_client.dart';
import 'as_realtime_ws_connector.dart';

typedef AsRealtimeTicketFactory = Future<AsRealtimeWSTicket> Function();
typedef AsRealtimeWSConnector = FutureOr<WebSocketChannel> Function(Uri uri);

const _wsResponseTimeout = Duration(seconds: 10);

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

  Future<Map<String, dynamic>> requestAction(
    String action,
    Map<String, Object?> params, {
    Set<int> allowedStatusCodes = const {200},
  });

  Future<void> updateReadMarker({
    required String roomId,
    required String eventId,
    required int originServerTs,
    String action = 'sync.read_marker',
    String channelId = '',
  });

  Future<void> reportLifecycle(
    bool foreground, {
    String? appState,
    bool hidden = false,
    Map<String, bool> flags = const {},
  });

  Future<void> reportFocusedRoom(String roomId);

  Future<void> ackEventSeq(int seq);

  Future<void> close();
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
  bool _ready = false;
  bool? _foreground;
  String? _appState;
  bool _hidden = false;
  Map<String, bool> _lifecycleFlags = const {};
  String? _focusedRoomId;
  int _latestSeq = 0;
  int _nextRequestId = 0;
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};

  bool get isReady => !_closed && _ready && _channel != null;

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
            _markNotReady();
          }
          _failPendingRequests(
            AsClientException('WS connection closed before response'),
          );
        } catch (_) {
          if (_closed) return;
          _markNotReady();
          _failPendingRequests(
            AsClientException('WS connection failed before response'),
          );
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
    _beginReadyWait();
    await channel.ready;
    _sendFrameToChannel(channel, {
      'type': 'client.hello',
      if (since > 0) 'since': since,
    });
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
      case 'server.ready':
        _markReadyAndReplayState();
        return null;
      case 'server.event':
        final rawEvent = frame['event'];
        if (rawEvent is! Map) return null;
        return AsEventStreamEvent.fromJson(rawEvent.cast<String, dynamic>());
      case 'server.response':
        _completeRequest(frame);
        return null;
      case 'server.command_result':
      case 'server.command_error':
        _completeRequest(frame);
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
  Future<void> reportLifecycle(
    bool foreground, {
    String? appState,
    bool hidden = false,
    Map<String, bool> flags = const {},
  }) async {
    _foreground = foreground;
    _appState = appState?.trim();
    _hidden = hidden;
    _lifecycleFlags = Map<String, bool>.unmodifiable({
      ...flags,
      'foreground': foreground,
      'background': !foreground,
      'hidden': hidden,
    });
    _sendFrame(_lifecycleFrame());
  }

  @override
  Future<void> reportFocusedRoom(String roomId) async {
    _focusedRoomId = roomId.trim();
    _sendFrame(_focusFrame(_focusedRoomId ?? ''));
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
    await requestAction(
      action,
      {
        'room_id': trimmedRoomId,
        'event_id': trimmedEventId,
        'origin_server_ts': originServerTs,
        if (channelId.trim().isNotEmpty) 'channel_id': channelId.trim(),
      },
    );
  }

  @override
  Future<Map<String, dynamic>> requestAction(
    String action,
    Map<String, Object?> params, {
    Set<int> allowedStatusCodes = const {200},
  }) async {
    final trimmedAction = action.trim();
    if (trimmedAction.isEmpty) {
      throw AsClientException('WS action is required');
    }
    final channel = _channel;
    if (channel == null) {
      throw AsClientException('WS transport is not ready before request');
    }
    if (!isReady || !identical(_channel, channel)) {
      throw AsClientException('WS transport is not ready before request');
    }
    final requestId = 'req-${++_nextRequestId}';
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;
    final sent = _sendFrameToChannel(channel, {
      'type': 'client.request',
      'id': requestId,
      'action': trimmedAction,
      'params': params,
    });
    if (!sent) {
      _pendingRequests.remove(requestId);
      throw AsClientException('WS transport is not ready before request');
    }
    try {
      final frame = await completer.future.timeout(_wsResponseTimeout);
      return _resultFromResponseFrame(
        frame,
        allowedStatusCodes: allowedStatusCodes,
      );
    } on TimeoutException {
      throw AsClientException('WS response timed out after request');
    } finally {
      _pendingRequests.remove(requestId);
    }
  }

  Map<String, dynamic> _resultFromResponseFrame(
    Map<String, dynamic> frame, {
    required Set<int> allowedStatusCodes,
  }) {
    if (frame['ok'] == false || frame['type'] == 'server.command_error') {
      final status = _parseInt(frame['status']);
      final error = frame['error']?.toString() ?? 'WS request failed';
      if (allowedStatusCodes.contains(status)) {
        return {'error': error, 'status': status};
      }
      throw AsClientException(error, statusCode: status);
    }
    final result = frame['result'];
    if (result == null) return const {};
    if (result is Map) return result.cast<String, dynamic>();
    throw AsClientException('WS response result is not an object');
  }

  void _completeRequest(Map<String, dynamic> frame) {
    final id = frame['id']?.toString() ?? '';
    final completer = _pendingRequests[id];
    if (completer == null || completer.isCompleted) return;
    completer.complete(frame);
  }

  void _failPendingRequests(Object error) {
    if (_pendingRequests.isEmpty) return;
    final pending = List<Completer<Map<String, dynamic>>>.from(
      _pendingRequests.values,
    );
    _pendingRequests.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
  }

  bool _sendFrame(Map<String, Object?> frame) {
    final channel = _channel;
    if (channel == null) return false;
    return _sendFrameToChannel(channel, frame);
  }

  bool _sendFrameToChannel(
    WebSocketChannel channel,
    Map<String, Object?> frame,
  ) {
    try {
      channel.sink.add(jsonEncode(frame));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    final channel = _channel;
    _channel = null;
    _markNotReady();
    _failPendingRequests(AsClientException('WS realtime is closed'));
    await channel?.sink.close();
  }

  void _beginReadyWait() {
    _ready = false;
  }

  void _markReadyAndReplayState() {
    if (_closed) return;
    _ready = true;
    _sendFrame(_lifecycleFrame());
    final focusedRoomId = _focusedRoomId;
    if (focusedRoomId != null) {
      _sendFrame(_focusFrame(focusedRoomId));
    }
  }

  void _markNotReady() {
    _ready = false;
  }

  Map<String, Object?> _lifecycleFrame() {
    final foreground = _foreground ?? true;
    final appState = _appState;
    final hidden = _hidden;
    final flags = <String, bool>{
      ..._lifecycleFlags,
      'foreground': foreground,
      'background': !foreground,
      'hidden': hidden,
    };
    return {
      'type': 'client.lifecycle',
      'foreground': foreground,
      if (appState != null && appState.isNotEmpty) 'state': appState,
      'hidden': hidden,
      'flags': flags,
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

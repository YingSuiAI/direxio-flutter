import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

const direxioPushContextAccountDataType = 'io.direxio.push.context';
const direxioPushContextHeartbeatInterval = Duration(seconds: 30);

typedef DirexioPushContextSend = Future<void> Function(
  DirexioPushContextPayload payload,
);
typedef DirexioPushContextTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);
typedef DirexioPushContextErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
);

class DirexioPushContextPayload {
  const DirexioPushContextPayload({required this.foreground});

  final bool foreground;

  Map<String, Object?> toJson() => {'foreground': foreground};
}

Future<void> setDirexioPushContext(
  Client client,
  DirexioPushContextPayload payload,
) async {
  final userId = client.userID?.trim() ?? '';
  if (userId.isEmpty) {
    throw StateError('Matrix user is not logged in');
  }
  if (client.accessToken?.trim().isEmpty != false) {
    throw StateError('Matrix access token is missing');
  }
  if (client.homeserver == null) {
    throw StateError('Matrix homeserver is missing');
  }
  await client.setAccountData(
    userId,
    direxioPushContextAccountDataType,
    payload.toJson(),
  );
}

class DirexioPushContextReporter {
  DirexioPushContextReporter({
    required DirexioPushContextSend send,
    DirexioPushContextTimerFactory? timerFactory,
    DirexioPushContextErrorHandler? onError,
    Duration heartbeatInterval = direxioPushContextHeartbeatInterval,
  })  : _send = send,
        _timerFactory = timerFactory ?? Timer.new,
        _onError = onError,
        _heartbeatInterval = heartbeatInterval;

  final DirexioPushContextSend _send;
  final DirexioPushContextTimerFactory _timerFactory;
  final DirexioPushContextErrorHandler? _onError;
  final Duration _heartbeatInterval;

  Timer? _heartbeatTimer;
  bool _foreground = false;
  bool _disposed = false;

  Future<void> enterForeground() async {
    if (_disposed) return;
    _foreground = true;
    _scheduleHeartbeat();
    await _safeSend(const DirexioPushContextPayload(foreground: true));
  }

  Future<void> enterBackground() async {
    if (_disposed) return;
    _foreground = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _safeSend(const DirexioPushContextPayload(foreground: false));
  }

  void stop() {
    _foreground = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void dispose() {
    _disposed = true;
    stop();
  }

  void _scheduleHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = _timerFactory(_heartbeatInterval, () {
      if (!_foreground || _disposed) return;
      unawaited(enterForeground());
    });
  }

  Future<void> _safeSend(DirexioPushContextPayload payload) async {
    try {
      await _send(payload);
    } catch (error, stackTrace) {
      final onError = _onError;
      if (onError != null) {
        onError(error, stackTrace);
      } else {
        debugPrint('[push-context] report failed: $error');
      }
    }
  }
}

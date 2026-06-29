import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/matrix_push_context.dart';
import 'as_event_stream_provider.dart';
import 'auth_provider.dart';

final direxioPushContextLifecycleProvider = Provider<void>((ref) {
  final client = ref.watch(matrixClientProvider);
  final reporter = DirexioPushContextReporter(
    send: (payload) => setDirexioPushContext(client, payload),
    onError: (error, _) => debugPrint('[push-context] report failed: $error'),
  );
  final lifecycle = _DirexioPushContextLifecycle(
    reporter,
    reportRealtimeLifecycle: (foreground) async {
      await ref.read(asEventStreamRefreshProvider)?.reportLifecycle(
            foreground: foreground,
          );
    },
  );

  WidgetsBinding.instance.addObserver(lifecycle);
  ref.listen<AsyncValue<AuthState>>(authStateNotifierProvider, (_, next) {
    lifecycle.updateAuth(next.valueOrNull);
  });
  lifecycle.updateAuth(ref.read(authStateNotifierProvider).valueOrNull);

  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(lifecycle);
    lifecycle.dispose();
  });
});

class _DirexioPushContextLifecycle with WidgetsBindingObserver {
  _DirexioPushContextLifecycle(
    this._reporter, {
    Future<void> Function(bool foreground)? reportRealtimeLifecycle,
  }) : _reportRealtimeLifecycle = reportRealtimeLifecycle;

  final DirexioPushContextReporter _reporter;
  final Future<void> Function(bool foreground)? _reportRealtimeLifecycle;

  bool _loggedIn = false;
  AppLifecycleState? _state = SchedulerBinding.instance.lifecycleState;

  void updateAuth(AuthState? auth) {
    _loggedIn = auth?.isLoggedIn == true;
    if (!_loggedIn) {
      _reporter.stop();
      return;
    }
    _syncForLifecycle();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state = state;
    if (!_loggedIn) return;
    _syncForLifecycle();
  }

  void dispose() {
    _reporter.dispose();
  }

  void _syncForLifecycle() {
    final report = _state == null || _state == AppLifecycleState.resumed
        ? _reporter.enterForeground()
        : _reporter.enterBackground();
    unawaited(report);
    final foreground = _state == null || _state == AppLifecycleState.resumed;
    unawaited(_reportRealtimeLifecycle?.call(foreground));
  }
}

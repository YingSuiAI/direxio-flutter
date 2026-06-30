import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/chat/chat_event_open_guard.dart';

void main() {
  test('ignores duplicate opens while the first action is in flight', () async {
    final guard = ChatEventOpenGuard();
    final completer = Completer<void>();
    var attempts = 0;

    final first = guard.runOnce('event-1', () {
      attempts += 1;
      return completer.future;
    });
    final second = guard.runOnce('event-1', () {
      attempts += 1;
      return Future<void>.value();
    });

    expect(attempts, 1);
    expect(second, completes);

    completer.complete();
    await first;

    await guard.runOnce('event-1', () {
      attempts += 1;
      return Future<void>.value();
    });
    expect(attempts, 2);
  });
}

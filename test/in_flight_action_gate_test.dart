import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/utils/in_flight_action_gate.dart';

void main() {
  test('runs only one action for the same in-flight key', () async {
    final gate = InFlightActionGate();
    final completer = Completer<int>();
    var runs = 0;

    final first = gate.run<int>(
      'contacts.requests.accept:!room:example.com',
      () {
        runs++;
        return completer.future;
      },
    );
    final second = gate.run<int>(
      'contacts.requests.accept:!room:example.com',
      () {
        runs++;
        return Future.value(2);
      },
    );
    completer.complete(1);

    expect(await first, 1);
    expect(await second, isNull);
    expect(runs, 1);
  });

  test('releases key after action finishes', () async {
    final gate = InFlightActionGate();

    expect(await gate.run('groups.join:!group:example.com', () async => 1), 1);
    expect(await gate.run('groups.join:!group:example.com', () async => 2), 2);
  });
}

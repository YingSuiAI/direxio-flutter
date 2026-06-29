import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/matrix_push_context.dart';

void main() {
  test('writes foreground push context to global Matrix account data',
      () async {
    final requests = <http.Request>[];
    final client = Client(
      'push-context-test',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.dispose);

    await client.init(
      newToken: 'access-token',
      newUserID: '@alice:example.com',
      newHomeserver: Uri.parse('https://matrix.example'),
      newDeviceID: 'DEVICE',
      newDeviceName: 'Direxio',
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );

    await setDirexioPushContext(
      client,
      const DirexioPushContextPayload(foreground: true),
    );

    final accountDataRequests = requests
        .where((request) => request.url.path.contains('/account_data/'))
        .toList(growable: false);
    expect(accountDataRequests, hasLength(1));
    final request = accountDataRequests.single;
    expect(request.method, 'PUT');
    expect(
      request.url.toString(),
      'https://matrix.example/_matrix/client/v3/user/'
      '%40alice%3Aexample.com/account_data/io.direxio.push.context',
    );
    expect(request.headers['authorization'], 'Bearer access-token');
    expect(request.headers['content-type'], contains('application/json'));
    expect(jsonDecode(request.body), {'foreground': true});
  });

  test('reports foreground immediately and renews every heartbeat', () async {
    final payloads = <DirexioPushContextPayload>[];
    final timers = <_FakeTimer>[];
    final reporter = DirexioPushContextReporter(
      send: (payload) async => payloads.add(payload),
      timerFactory: (duration, callback) {
        final timer = _FakeTimer(duration, callback);
        timers.add(timer);
        return timer;
      },
    );
    addTearDown(reporter.dispose);

    await reporter.enterForeground();

    expect(timers.single.duration, direxioPushContextHeartbeatInterval);
    expect(payloads.single.toJson(), {'foreground': true});

    timers.single.fire();
    await Future<void>.delayed(Duration.zero);

    expect(timers, hasLength(2));
    expect(payloads, hasLength(2));
    expect(payloads.last.toJson(), {'foreground': true});
  });

  test('background report cancels heartbeat and sends foreground false',
      () async {
    final payloads = <DirexioPushContextPayload>[];
    final timers = <_FakeTimer>[];
    final reporter = DirexioPushContextReporter(
      send: (payload) async => payloads.add(payload),
      timerFactory: (duration, callback) {
        final timer = _FakeTimer(duration, callback);
        timers.add(timer);
        return timer;
      },
    );
    addTearDown(reporter.dispose);

    await reporter.enterForeground();
    await reporter.enterBackground();
    timers.single.fire();
    await Future<void>.delayed(Duration.zero);

    expect(timers.single.isActive, isFalse);
    expect(payloads.map((payload) => payload.toJson()), [
      {'foreground': true},
      {'foreground': false},
    ]);
  });
}

class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  var _active = true;

  void fire() {
    if (!_active) return;
    _callback();
  }

  @override
  void cancel() {
    _active = false;
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

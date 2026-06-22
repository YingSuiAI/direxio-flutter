import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_bootstrap_store.dart';
import 'package:portal_app/data/as_client.dart';

void main() {
  test('refresh is single-flight and persists the fresh bootstrap', () async {
    var loadCalls = 0;
    final store = _MemoryAsBootstrapStore();
    final completer = Completer<AsSyncBootstrap>();
    final repository = AsBootstrapRepository(
      loadBootstrap: () {
        loadCalls++;
        return completer.future;
      },
      store: store,
    );

    final first = repository.refresh();
    final second = repository.refresh();
    expect(identical(first, second), isTrue);
    expect(loadCalls, 1);

    completer.complete(_bootstrap('!fresh:p2p-im.com'));

    expect(await first, same(await second));
    expect(store.writes, 1);
    expect((await repository.readCached())!.contacts.single.roomId,
        '!fresh:p2p-im.com');
  });

  test('failed refresh clears in-flight state so the next call can retry',
      () async {
    var loadCalls = 0;
    final repository = AsBootstrapRepository(
      loadBootstrap: () async {
        loadCalls++;
        if (loadCalls == 1) throw StateError('network down');
        return _bootstrap('!retry:p2p-im.com');
      },
      store: _MemoryAsBootstrapStore(),
    );

    await expectLater(repository.refresh(), throwsA(isA<StateError>()));

    final bootstrap = await repository.refresh();

    expect(loadCalls, 2);
    expect(bootstrap.contacts.single.roomId, '!retry:p2p-im.com');
  });

  test('refresh still returns fresh bootstrap when cache write fails',
      () async {
    final repository = AsBootstrapRepository(
      loadBootstrap: () async => _bootstrap('!fresh:p2p-im.com'),
      store: _ThrowingAsBootstrapStore(),
    );

    final bootstrap = await repository.refresh();

    expect(bootstrap.contacts.single.roomId, '!fresh:p2p-im.com');
  });

  test('refresh does not wait for a slow cache write', () async {
    final store = _SlowAsBootstrapStore();
    final repository = AsBootstrapRepository(
      loadBootstrap: () async => _bootstrap('!fast-ui:p2p-im.com'),
      store: store,
    );

    final bootstrap = await repository.refresh();

    expect(bootstrap.contacts.single.roomId, '!fast-ui:p2p-im.com');
    expect(store.writeStarted, isTrue);
    expect(store.writeCompleted, isFalse);

    store.completeWrite();
  });
}

AsSyncBootstrap _bootstrap(String roomId) {
  return AsSyncBootstrap(
    syncedAt: DateTime.parse('2026-05-28T08:00:00Z'),
    user: const AsSyncUser(userId: '@owner:p2p-im.com'),
    rooms: const [],
    contacts: [
      AsSyncContact(
        userId: '@peer:p2p-liyanan.com',
        displayName: 'Peer',
        avatarUrl: '',
        roomId: roomId,
        domain: 'p2p-liyanan.com',
        status: 'accepted',
      ),
    ],
    groups: const [],
    channels: const [],
    pending: const AsSyncPending.empty(),
  );
}

class _MemoryAsBootstrapStore implements AsBootstrapStore {
  AsSyncBootstrap? bootstrap;
  int writes = 0;

  @override
  Future<AsSyncBootstrap?> read() async => bootstrap;

  @override
  Future<void> write(AsSyncBootstrap bootstrap) async {
    writes++;
    this.bootstrap = bootstrap;
  }

  @override
  Future<void> clear() async {
    bootstrap = null;
  }
}

class _ThrowingAsBootstrapStore implements AsBootstrapStore {
  @override
  Future<AsSyncBootstrap?> read() async => null;

  @override
  Future<void> write(AsSyncBootstrap bootstrap) async {
    throw StateError('cache unavailable');
  }

  @override
  Future<void> clear() async {}
}

class _SlowAsBootstrapStore implements AsBootstrapStore {
  final _writeCompleter = Completer<void>();
  bool writeStarted = false;
  bool writeCompleted = false;

  @override
  Future<AsSyncBootstrap?> read() async => null;

  @override
  Future<void> write(AsSyncBootstrap bootstrap) async {
    writeStarted = true;
    await _writeCompleter.future;
    writeCompleted = true;
  }

  @override
  Future<void> clear() async {}

  void completeWrite() => _writeCompleter.complete();
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_call_session_store.dart';
import 'package:portal_app/data/as_client.dart';

void main() {
  late Directory tempDir;
  late File file;
  late FileAsCallSessionStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('portal_calls_test');
    file = File('${tempDir.path}/calls.json');
    store = FileAsCallSessionStore(file);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('persists AS call session snapshots by call id', () async {
    final session = _session(
      callId: 'call-1',
      state: asCallStateRinging,
      createdAt: DateTime.parse('2026-05-31T10:00:00Z'),
    );

    await store.upsert(session);

    final loaded = await store.read('call-1');
    expect(loaded, isNotNull);
    expect(loaded!.callId, 'call-1');
    expect(loaded.state, asCallStateRinging);
    expect(loaded.createdAt, DateTime.parse('2026-05-31T10:00:00Z'));
  });

  test('upsert replaces stale snapshots instead of duplicating them', () async {
    await store.upsert(_session(callId: 'call-1', state: asCallStateRinging));
    await store.upsert(_session(
      callId: 'call-1',
      state: asCallStateEnded,
      durationMs: 24000,
      endedAt: DateTime.parse('2026-05-31T10:00:24Z'),
    ));

    final loaded = await store.readAll();

    expect(loaded, hasLength(1));
    expect(loaded.single.state, asCallStateEnded);
    expect(loaded.single.durationMs, 24000);
  });

  test('upsert keeps local duration when AS refresh is sparse', () async {
    final answeredAt = DateTime.parse('2026-05-31T10:00:05Z');
    final endedAt = DateTime.parse('2026-05-31T10:00:47Z');
    await store.upsert(_session(
      callId: 'call-1',
      state: asCallStateEnded,
      answeredAt: answeredAt,
      endedAt: endedAt,
      durationMs: 42000,
    ));

    await store.upsert(_session(
      callId: 'call-1',
      state: asCallStateEnded,
      durationMs: 0,
    ));

    final loaded = await store.read('call-1');

    expect(loaded?.state, asCallStateEnded);
    expect(loaded?.answeredAt, answeredAt);
    expect(loaded?.endedAt, endedAt);
    expect(loaded?.durationMs, 42000);
  });

  test('upsert does not downgrade local terminal call to ringing', () async {
    await store.upsert(_session(
      callId: 'call-1',
      state: asCallStateEnded,
      endedAt: DateTime.parse('2026-05-31T10:00:24Z'),
      durationMs: 24000,
    ));

    await store.upsert(_session(callId: 'call-1', state: asCallStateRinging));

    final loaded = await store.read('call-1');

    expect(loaded?.state, asCallStateEnded);
    expect(loaded?.durationMs, 24000);
  });

  test('reads stable room snapshots newest first', () async {
    await store.upsertAll([
      _session(
        callId: 'call-old',
        roomId: '!group:p2p-im.com',
        state: asCallStateEnded,
        createdAt: DateTime.parse('2026-06-02T09:00:00Z'),
        endedAt: DateTime.parse('2026-06-02T09:01:00Z'),
        durationMs: 60000,
      ),
      _session(
        callId: 'call-other-room',
        roomId: '!other:p2p-im.com',
        state: asCallStateEnded,
        createdAt: DateTime.parse('2026-06-02T09:02:00Z'),
        endedAt: DateTime.parse('2026-06-02T09:03:00Z'),
      ),
      _session(
        callId: 'call-new',
        roomId: '!group:p2p-im.com',
        state: asCallStateMissed,
        createdAt: DateTime.parse('2026-06-02T09:04:00Z'),
        endedAt: DateTime.parse('2026-06-02T09:05:00Z'),
      ),
      _session(
        callId: 'call-active',
        roomId: '!group:p2p-im.com',
        state: asCallStateConnected,
        createdAt: DateTime.parse('2026-06-02T09:06:00Z'),
      ),
    ]);

    final loaded = await store.readRoomStable('!group:p2p-im.com');

    expect(loaded.map((session) => session.callId), [
      'call-new',
      'call-old',
    ]);
  });

  test('caps old call snapshots by creation time', () async {
    store = FileAsCallSessionStore(file, maxEntries: 2);

    await store.upsertAll([
      _session(
          callId: 'call-1', createdAt: DateTime.parse('2026-05-31T10:00:00Z')),
      _session(
          callId: 'call-2', createdAt: DateTime.parse('2026-05-31T10:01:00Z')),
      _session(
          callId: 'call-3', createdAt: DateTime.parse('2026-05-31T10:02:00Z')),
    ]);

    final loaded = await store.readAll();

    expect(loaded.map((session) => session.callId), ['call-2', 'call-3']);
  });

  test('refresh policy skips AS lookup once cached snapshot is terminal',
      () async {
    expect(shouldRefreshAsCallSessionSnapshot(null), isTrue);
    expect(
      shouldRefreshAsCallSessionSnapshot(
        _session(callId: 'ringing', state: asCallStateRinging),
      ),
      isTrue,
    );
    expect(
      shouldRefreshAsCallSessionSnapshot(
        _session(callId: 'connected', state: asCallStateConnected),
      ),
      isTrue,
    );
    expect(
      shouldRefreshAsCallSessionSnapshot(
        _session(callId: 'ended', state: asCallStateEnded),
      ),
      isFalse,
    );
    expect(
      shouldRefreshAsCallSessionSnapshot(
        _session(callId: 'rejected', state: asCallStateRejected),
      ),
      isFalse,
    );
    expect(
      shouldRefreshAsCallSessionSnapshot(
        _session(callId: 'missed', state: asCallStateMissed),
      ),
      isFalse,
    );
    expect(
      shouldRefreshAsCallSessionSnapshot(
        _session(callId: 'failed', state: asCallStateFailed),
      ),
      isFalse,
    );
  });
}

AsCallSession _session({
  required String callId,
  String roomId = '!room:p2p-im.com',
  String state = asCallStateRinging,
  DateTime? createdAt,
  DateTime? answeredAt,
  DateTime? endedAt,
  int durationMs = 0,
}) {
  return AsCallSession(
    callId: callId,
    roomId: roomId,
    roomType: 'direct',
    mediaType: asCallMediaTypeVoice,
    createdByMxid: '@owner:p2p-im.com',
    state: state,
    createdAt: createdAt ?? DateTime.parse('2026-05-31T10:00:00Z'),
    answeredAt: answeredAt,
    endedAt: endedAt,
    endedByMxid: '@owner:p2p-im.com',
    endReason: endedAt == null ? '' : 'hangup',
    durationMs: durationMs,
  );
}

import 'dart:convert';
import 'dart:io';

import 'as_client.dart';

bool shouldRefreshAsCallSessionSnapshot(AsCallSession? session) {
  if (session == null) return true;
  return !asCallSessionSnapshotIsTerminal(session);
}

bool asCallSessionSnapshotIsTerminal(AsCallSession session) {
  return session.state == asCallStateEnded ||
      session.state == asCallStateRejected ||
      session.state == asCallStateMissed ||
      session.state == asCallStateFailed;
}

abstract class AsCallSessionStore {
  Future<List<AsCallSession>> readAll();

  Future<AsCallSession?> read(String callId);

  Future<List<AsCallSession>> readRoomStable(String roomId);

  Future<void> upsert(AsCallSession session);

  Future<void> upsertAll(Iterable<AsCallSession> sessions);
}

class DeferredAsCallSessionStore implements AsCallSessionStore {
  DeferredAsCallSessionStore(this._loadStore);

  final Future<AsCallSessionStore> Function() _loadStore;

  @override
  Future<List<AsCallSession>> readAll() async {
    final store = await _loadStore();
    return store.readAll();
  }

  @override
  Future<AsCallSession?> read(String callId) async {
    final store = await _loadStore();
    return store.read(callId);
  }

  @override
  Future<List<AsCallSession>> readRoomStable(String roomId) async {
    final store = await _loadStore();
    return store.readRoomStable(roomId);
  }

  @override
  Future<void> upsert(AsCallSession session) async {
    final store = await _loadStore();
    await store.upsert(session);
  }

  @override
  Future<void> upsertAll(Iterable<AsCallSession> sessions) async {
    final store = await _loadStore();
    await store.upsertAll(sessions);
  }
}

class FileAsCallSessionStore implements AsCallSessionStore {
  const FileAsCallSessionStore(
    this.file, {
    this.maxEntries = 1000,
  });

  final File file;
  final int maxEntries;

  @override
  Future<List<AsCallSession>> readAll() async {
    if (!await file.exists()) return const [];
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return const [];
      final decoded = jsonDecode(content);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            _validOrNull(
              AsCallSession.fromJson(item.cast<String, dynamic>()),
            ),
      ].whereType<AsCallSession>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<AsCallSession?> read(String callId) async {
    final trimmed = callId.trim();
    if (trimmed.isEmpty) return null;
    final sessions = await readAll();
    for (final session in sessions) {
      if (session.callId.trim() == trimmed) return session;
    }
    return null;
  }

  @override
  Future<List<AsCallSession>> readRoomStable(String roomId) async {
    final trimmed = roomId.trim();
    if (trimmed.isEmpty) return const [];
    final sessions = await readAll();
    final stable = sessions
        .where((session) =>
            session.roomId.trim() == trimmed &&
            asCallSessionSnapshotIsTerminal(session))
        .toList(growable: false)
      ..sort((a, b) => _stableTimestamp(b).compareTo(_stableTimestamp(a)));
    return stable;
  }

  @override
  Future<void> upsert(AsCallSession session) {
    return upsertAll([session]);
  }

  @override
  Future<void> upsertAll(Iterable<AsCallSession> sessions) async {
    final normalized = [
      for (final session in sessions) _validOrNull(session),
    ].whereType<AsCallSession>().toList(growable: false);
    if (normalized.isEmpty) return;
    final byCallId = <String, AsCallSession>{
      for (final session in await readAll()) session.callId.trim(): session,
    };
    for (final session in normalized) {
      final callId = session.callId.trim();
      byCallId[callId] = _mergeSnapshot(byCallId[callId], session);
    }
    final next = byCallId.values.toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final capped = next.length <= maxEntries
        ? next
        : next.sublist(next.length - maxEntries);
    await _write(capped);
  }

  AsCallSession? _validOrNull(AsCallSession session) {
    if (session.callId.trim().isEmpty || session.roomId.trim().isEmpty) {
      return null;
    }
    return session;
  }

  DateTime _stableTimestamp(AsCallSession session) {
    return session.endedAt ?? session.answeredAt ?? session.createdAt;
  }

  AsCallSession _mergeSnapshot(
    AsCallSession? existing,
    AsCallSession incoming,
  ) {
    if (existing == null) return incoming;
    final existingTerminal = asCallSessionSnapshotIsTerminal(existing);
    final incomingTerminal = asCallSessionSnapshotIsTerminal(incoming);
    final state =
        existingTerminal && !incomingTerminal ? existing.state : incoming.state;
    return AsCallSession(
      callId: incoming.callId,
      roomId:
          incoming.roomId.trim().isNotEmpty ? incoming.roomId : existing.roomId,
      roomType: incoming.roomType.trim().isNotEmpty
          ? incoming.roomType
          : existing.roomType,
      mediaType: incoming.mediaType.trim().isNotEmpty
          ? incoming.mediaType
          : existing.mediaType,
      createdByMxid: incoming.createdByMxid.trim().isNotEmpty
          ? incoming.createdByMxid
          : existing.createdByMxid,
      state: state,
      createdAt: incoming.createdAt.isBefore(existing.createdAt)
          ? incoming.createdAt
          : existing.createdAt,
      invitedUserIds: incoming.invitedUserIds.isNotEmpty
          ? incoming.invitedUserIds
          : existing.invitedUserIds,
      answeredAt: incoming.answeredAt ?? existing.answeredAt,
      endedAt: incoming.endedAt ?? existing.endedAt,
      endedByMxid: incoming.endedByMxid.trim().isNotEmpty
          ? incoming.endedByMxid
          : existing.endedByMxid,
      endReason: incoming.endReason.trim().isNotEmpty
          ? incoming.endReason
          : existing.endReason,
      durationMs:
          incoming.durationMs > 0 ? incoming.durationMs : existing.durationMs,
    );
  }

  Future<void> _write(List<AsCallSession> sessions) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode([for (final session in sessions) session.toJson()]),
      flush: true,
    );
  }
}

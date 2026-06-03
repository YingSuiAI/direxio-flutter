import 'dart:convert';
import 'dart:io';

import 'as_client.dart';

abstract class RecoveredUnreadStore {
  Future<AsSyncUnread?> read();

  Future<AsSyncUnread> merge(AsSyncUnread unread);

  Future<void> removeEvents(Iterable<String> eventIds);

  Future<void> removeRoom(String roomId);
}

class DeferredRecoveredUnreadStore implements RecoveredUnreadStore {
  const DeferredRecoveredUnreadStore(this._load);

  final Future<RecoveredUnreadStore> Function() _load;

  @override
  Future<AsSyncUnread?> read() async => (await _load()).read();

  @override
  Future<AsSyncUnread> merge(AsSyncUnread unread) async {
    return (await _load()).merge(unread);
  }

  @override
  Future<void> removeEvents(Iterable<String> eventIds) async {
    await (await _load()).removeEvents(eventIds);
  }

  @override
  Future<void> removeRoom(String roomId) async {
    await (await _load()).removeRoom(roomId);
  }
}

class FileRecoveredUnreadStore implements RecoveredUnreadStore {
  const FileRecoveredUnreadStore(this.file);

  final File file;

  @override
  Future<AsSyncUnread?> read() async {
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return AsSyncUnread.fromJson(
        jsonDecode(content) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AsSyncUnread> merge(AsSyncUnread unread) async {
    final current = await read();
    final merged = mergeRecoveredUnread(current, unread);
    await _write(merged);
    return merged;
  }

  @override
  Future<void> removeEvents(Iterable<String> eventIds) async {
    final ids = eventIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return;
    final current = await read();
    if (current == null) return;
    await _write(removeRecoveredUnreadEvents(current, ids));
  }

  @override
  Future<void> removeRoom(String roomId) async {
    if (roomId.isEmpty) return;
    final current = await read();
    if (current == null) return;
    await _write(removeRecoveredUnreadRoom(current, roomId));
  }

  Future<void> _write(AsSyncUnread unread) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(unread.toJson()), flush: true);
  }
}

AsSyncUnread mergeRecoveredUnread(
  AsSyncUnread? current,
  AsSyncUnread incoming,
) {
  final byRoom = <String, Map<String, AsUnreadMessage>>{};

  void addRoom(AsUnreadRoom room) {
    if (room.roomId.isEmpty) return;
    final byEvent = byRoom.putIfAbsent(room.roomId, () => {});
    for (final message in room.messages) {
      if (message.eventId.isEmpty) continue;
      byEvent[message.eventId] = message;
    }
  }

  for (final room in current?.rooms ?? const <AsUnreadRoom>[]) {
    addRoom(room);
  }
  for (final room in incoming.rooms) {
    addRoom(room);
  }

  return AsSyncUnread(
    syncedAt: incoming.syncedAt,
    rooms: [
      for (final entry in byRoom.entries)
        AsUnreadRoom(
          roomId: entry.key,
          messages: entry.value.values.toList(),
        ),
    ],
  );
}

AsSyncUnread removeRecoveredUnreadEvents(
  AsSyncUnread unread,
  Set<String> eventIds,
) {
  return AsSyncUnread(
    syncedAt: unread.syncedAt,
    rooms: [
      for (final room in unread.rooms)
        if (room.messages.any((message) => !eventIds.contains(message.eventId)))
          AsUnreadRoom(
            roomId: room.roomId,
            messages: [
              for (final message in room.messages)
                if (!eventIds.contains(message.eventId)) message,
            ],
          ),
    ],
  );
}

AsSyncUnread removeRecoveredUnreadRoom(AsSyncUnread unread, String roomId) {
  return AsSyncUnread(
    syncedAt: unread.syncedAt,
    rooms: [
      for (final room in unread.rooms)
        if (room.roomId != roomId) room,
    ],
  );
}

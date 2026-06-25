import 'dart:convert';
import 'dart:io';

abstract class ChatClearStateStore {
  Future<int> readClearedBeforeTs();

  Future<Map<String, int>> readRoomClearedBeforeTs();

  Future<Map<String, Set<String>>> readDeletedEventIdsByRoom();

  Future<void> writeClearedBeforeTs(int timestamp);

  Future<void> writeRoomClearedBeforeTs(String roomId, int timestamp);

  Future<void> writeDeletedEventIds(String roomId, Iterable<String> eventIds);

  Future<void> clear();
}

class FileChatClearStateStore implements ChatClearStateStore {
  const FileChatClearStateStore(this.file);

  final File file;

  @override
  Future<int> readClearedBeforeTs() async {
    final decoded = await _readState();
    final value = decoded['cleared_before_ts'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  @override
  Future<Map<String, int>> readRoomClearedBeforeTs() async {
    final decoded = await _readState();
    final value = decoded['room_cleared_before_ts'];
    if (value is! Map) return const <String, int>{};
    final result = <String, int>{};
    for (final entry in value.entries) {
      final roomId = '${entry.key}'.trim();
      if (roomId.isEmpty) continue;
      final timestamp = entry.value;
      if (timestamp is int && timestamp > 0) {
        result[roomId] = timestamp;
      } else if (timestamp is num && timestamp > 0) {
        result[roomId] = timestamp.toInt();
      }
    }
    return Map.unmodifiable(result);
  }

  @override
  Future<Map<String, Set<String>>> readDeletedEventIdsByRoom() async {
    final decoded = await _readState();
    final value = decoded['deleted_event_ids_by_room'];
    if (value is! Map) return const <String, Set<String>>{};
    final result = <String, Set<String>>{};
    for (final entry in value.entries) {
      final roomId = '${entry.key}'.trim();
      if (roomId.isEmpty) continue;
      final rawIds = entry.value;
      if (rawIds is! List) continue;
      final ids = rawIds
          .whereType<String>()
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      if (ids.isNotEmpty) {
        result[roomId] = Set.unmodifiable(ids);
      }
    }
    return Map.unmodifiable(result);
  }

  @override
  Future<void> writeClearedBeforeTs(int timestamp) async {
    if (timestamp <= 0) return;
    final decoded = await _readState();
    decoded['cleared_before_ts'] = timestamp;
    await _writeState(decoded);
  }

  @override
  Future<void> writeRoomClearedBeforeTs(String roomId, int timestamp) async {
    final trimmed = roomId.trim();
    if (trimmed.isEmpty || timestamp <= 0) return;
    final decoded = await _readState();
    final rawRooms = decoded['room_cleared_before_ts'];
    final rooms = rawRooms is Map
        ? Map<String, dynamic>.from(rawRooms)
        : <String, dynamic>{};
    rooms[trimmed] = timestamp;
    decoded['room_cleared_before_ts'] = rooms;
    await _writeState(decoded);
  }

  @override
  Future<void> writeDeletedEventIds(
    String roomId,
    Iterable<String> eventIds,
  ) async {
    final trimmed = roomId.trim();
    if (trimmed.isEmpty) return;
    final ids =
        eventIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return;
    final decoded = await _readState();
    final rawRooms = decoded['deleted_event_ids_by_room'];
    final rooms = rawRooms is Map
        ? Map<String, dynamic>.from(rawRooms)
        : <String, dynamic>{};
    final currentRaw = rooms[trimmed];
    final current = currentRaw is List
        ? currentRaw
            .whereType<String>()
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
        : <String>{};
    current.addAll(ids);
    rooms[trimmed] = current.toList()..sort();
    decoded['deleted_event_ids_by_room'] = rooms;
    await _writeState(decoded);
  }

  @override
  Future<void> clear() async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Map<String, dynamic>> _readState() async {
    if (!await file.exists()) return <String, dynamic>{};
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) return <String, dynamic>{};
      return decoded;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeState(Map<String, dynamic> state) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(state), flush: true);
  }
}

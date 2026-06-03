import 'dart:convert';
import 'dart:io';

abstract class FriendRequestReadStore {
  Future<Set<String>> readRoomIds();

  Future<void> writeRoomIds(Set<String> roomIds);
}

class FileFriendRequestReadStore implements FriendRequestReadStore {
  const FileFriendRequestReadStore(this.file);

  final File file;

  @override
  Future<Set<String>> readRoomIds() async {
    if (!await file.exists()) return {};
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      final decoded = jsonDecode(content);
      if (decoded is! List) return {};
      return decoded.whereType<String>().where((id) => id.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> writeRoomIds(Set<String> roomIds) async {
    await file.parent.create(recursive: true);
    final sorted = roomIds.where((id) => id.isNotEmpty).toList()..sort();
    await file.writeAsString(jsonEncode(sorted), flush: true);
  }
}

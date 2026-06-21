import 'dart:convert';
import 'dart:io';

class HomeConversationSnapshot {
  const HomeConversationSnapshot({
    required this.userId,
    required this.entries,
    required this.updatedAt,
  });

  final String userId;
  final List<HomeConversationSnapshotEntry> entries;
  final DateTime updatedAt;

  factory HomeConversationSnapshot.fromJson(Map<String, dynamic> json) {
    return HomeConversationSnapshot(
      userId: json['user_id'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      entries: (json['entries'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => HomeConversationSnapshotEntry.fromJson(
                item.cast<String, dynamic>(),
              ))
          .where((entry) => entry.roomId.trim().isNotEmpty)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'entries': entries.map((entry) => entry.toJson()).toList(),
    };
  }
}

class HomeConversationSnapshotEntry {
  const HomeConversationSnapshotEntry({
    required this.roomId,
    required this.name,
    required this.lastMessage,
    required this.previewTs,
    required this.unread,
    required this.isGroup,
    required this.isAgent,
    this.avatarUrl = '',
  });

  final String roomId;
  final String name;
  final String lastMessage;
  final int previewTs;
  final int unread;
  final bool isGroup;
  final bool isAgent;
  final String avatarUrl;

  factory HomeConversationSnapshotEntry.fromJson(Map<String, dynamic> json) {
    return HomeConversationSnapshotEntry(
      roomId: json['room_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lastMessage: json['last_message'] as String? ?? '',
      previewTs: _parseInt(json['preview_ts']),
      unread: _parseInt(json['unread']),
      isGroup: json['is_group'] as bool? ?? false,
      isAgent: json['is_agent'] as bool? ?? false,
      avatarUrl: json['avatar_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'name': name,
      'last_message': lastMessage,
      'preview_ts': previewTs,
      'unread': unread,
      'is_group': isGroup,
      'is_agent': isAgent,
      if (avatarUrl.trim().isNotEmpty) 'avatar_url': avatarUrl,
    };
  }
}

abstract class HomeConversationSnapshotStore {
  Future<HomeConversationSnapshot?> read();

  Future<void> write(HomeConversationSnapshot snapshot);

  Future<void> clear();
}

class FileHomeConversationSnapshotStore
    implements HomeConversationSnapshotStore {
  const FileHomeConversationSnapshotStore(this.file);

  final File file;

  @override
  Future<HomeConversationSnapshot?> read() async {
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) return null;
      return HomeConversationSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(HomeConversationSnapshot snapshot) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
  }

  @override
  Future<void> clear() async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

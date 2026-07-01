import 'dart:convert';
import 'dart:io';

import 'as_client.dart';

class ConversationSummarySnapshot {
  const ConversationSummarySnapshot({
    required this.userId,
    required this.entries,
    required this.updatedAt,
  });

  final String userId;
  final List<ConversationSummaryEntry> entries;
  final DateTime updatedAt;

  factory ConversationSummarySnapshot.fromJson(Map<String, dynamic> json) {
    return ConversationSummarySnapshot(
      userId: json['user_id'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      entries: (json['entries'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => ConversationSummaryEntry.fromJson(
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

class ConversationSummaryState {
  const ConversationSummaryState({
    this.loaded = false,
    this.userId = '',
    this.entries = const [],
    this.updatedAt,
  });

  final bool loaded;
  final String userId;
  final List<ConversationSummaryEntry> entries;
  final DateTime? updatedAt;

  factory ConversationSummaryState.fromSnapshot(
    ConversationSummarySnapshot snapshot,
  ) {
    return ConversationSummaryState(
      loaded: true,
      userId: snapshot.userId,
      entries: List.unmodifiable(snapshot.entries),
      updatedAt: snapshot.updatedAt,
    );
  }

  ConversationSummarySnapshot? toSnapshot() {
    final owner = userId.trim();
    if (owner.isEmpty) return null;
    return ConversationSummarySnapshot(
      userId: owner,
      entries: entries,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  ConversationSummaryState copyWith({
    bool? loaded,
    String? userId,
    List<ConversationSummaryEntry>? entries,
    DateTime? updatedAt,
  }) {
    return ConversationSummaryState(
      loaded: loaded ?? this.loaded,
      userId: userId ?? this.userId,
      entries: List.unmodifiable(entries ?? this.entries),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ConversationSummaryProjection {
  const ConversationSummaryProjection({
    required this.displayEntries,
    required this.storeEntries,
    required this.shouldWriteStore,
  });

  final List<ConversationSummaryEntry> displayEntries;
  final List<ConversationSummaryEntry> storeEntries;
  final bool shouldWriteStore;
}

class ConversationSummaryEntry {
  const ConversationSummaryEntry({
    this.conversationId = '',
    required this.roomId,
    this.kind = '',
    required this.name,
    required this.lastMessage,
    required this.previewTs,
    required this.unread,
    required this.isGroup,
    required this.isAgent,
    this.canOpen = true,
    this.avatarUrl = '',
    this.clearCachedPreview = false,
  });

  final String conversationId;
  final String roomId;
  final String kind;
  final String name;
  final String lastMessage;
  final int previewTs;
  final int unread;
  final bool isGroup;
  final bool isAgent;
  final bool canOpen;
  final String avatarUrl;
  final bool clearCachedPreview;

  factory ConversationSummaryEntry.fromJson(Map<String, dynamic> json) {
    return ConversationSummaryEntry(
      conversationId: json['conversation_id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lastMessage: json['last_message'] as String? ?? '',
      previewTs: _parseInt(json['preview_ts']),
      unread: _parseInt(json['unread']),
      isGroup: json['is_group'] as bool? ?? false,
      isAgent: json['is_agent'] as bool? ?? false,
      canOpen: json['can_open'] as bool? ?? true,
      avatarUrl: json['avatar_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (conversationId.trim().isNotEmpty) 'conversation_id': conversationId,
      'room_id': roomId,
      if (kind.trim().isNotEmpty) 'kind': kind,
      'name': name,
      'last_message': lastMessage,
      'preview_ts': previewTs,
      'unread': unread,
      'is_group': isGroup,
      'is_agent': isAgent,
      'can_open': canOpen,
      if (avatarUrl.trim().isNotEmpty) 'avatar_url': avatarUrl,
    };
  }

  ConversationSummaryEntry mergeLive({
    ConversationSummaryEntry? previous,
  }) {
    final previousEntry = previous;
    final liveLastMessage = lastMessage.trim();
    final liveAvatar = avatarUrl.trim();
    final keepPreviousPreview = previousEntry != null &&
        !clearCachedPreview &&
        _previousPreviewIsNewer(
          previousEntry,
          liveLastMessage: liveLastMessage,
          livePreviewTs: previewTs,
        );
    return ConversationSummaryEntry(
      conversationId: conversationId.trim().isNotEmpty
          ? conversationId
          : previousEntry?.conversationId ?? '',
      roomId: roomId,
      kind: kind.trim().isNotEmpty ? kind : previousEntry?.kind ?? '',
      name: name.trim().isNotEmpty ? name : previousEntry?.name ?? roomId,
      lastMessage: clearCachedPreview
          ? ''
          : keepPreviousPreview
              ? previousEntry.lastMessage
              : liveLastMessage.isNotEmpty
                  ? lastMessage
                  : previousEntry?.lastMessage ?? lastMessage,
      previewTs: clearCachedPreview
          ? 0
          : keepPreviousPreview
              ? previousEntry.previewTs
              : previewTs > 0
                  ? previewTs
                  : previousEntry?.previewTs ?? 0,
      unread: clearCachedPreview
          ? unread
          : hasDisplaySignal
              ? unread
              : previousEntry?.unread ?? unread,
      isGroup: isGroup,
      isAgent: isAgent,
      canOpen: canOpen,
      avatarUrl:
          liveAvatar.isNotEmpty ? avatarUrl : previousEntry?.avatarUrl ?? '',
    );
  }

  bool get hasDisplaySignal {
    return lastMessage.trim().isNotEmpty ||
        previewTs > 0 ||
        unread > 0 ||
        (roomId.trim().isNotEmpty &&
            canOpen &&
            (kind.trim().isNotEmpty || isGroup || isAgent)) ||
        (conversationId.trim().isNotEmpty && canOpen);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationSummaryEntry &&
        other.conversationId == conversationId &&
        other.roomId == roomId &&
        other.kind == kind &&
        other.name == name &&
        other.lastMessage == lastMessage &&
        other.previewTs == previewTs &&
        other.unread == unread &&
        other.isGroup == isGroup &&
        other.isAgent == isAgent &&
        other.canOpen == canOpen &&
        other.avatarUrl == avatarUrl &&
        other.clearCachedPreview == clearCachedPreview;
  }

  @override
  int get hashCode {
    return Object.hash(
      conversationId,
      roomId,
      kind,
      name,
      lastMessage,
      previewTs,
      unread,
      isGroup,
      isAgent,
      canOpen,
      avatarUrl,
      clearCachedPreview,
    );
  }
}

bool _previousPreviewIsNewer(
  ConversationSummaryEntry previous, {
  required String liveLastMessage,
  required int livePreviewTs,
}) {
  final previousPreviewTs = previous.previewTs;
  if (previousPreviewTs <= 0) return false;
  if (livePreviewTs <= 0) return liveLastMessage.isNotEmpty;
  return previousPreviewTs > livePreviewTs;
}

abstract class ConversationSummaryStore {
  Future<ConversationSummarySnapshot?> read();

  Future<void> write(ConversationSummarySnapshot snapshot);

  Future<void> clear();
}

class FileConversationSummaryStore implements ConversationSummaryStore {
  const FileConversationSummaryStore(this.file);

  final File file;

  @override
  Future<ConversationSummarySnapshot?> read() async {
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) return null;
      return ConversationSummarySnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(ConversationSummarySnapshot snapshot) async {
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

List<ConversationSummaryEntry> conversationSummaryEntriesForUser(
  ConversationSummarySnapshot? snapshot, {
  required String? userId,
  required Set<String> hiddenConversationIds,
  required Set<String> pinnedConversationIds,
}) {
  final expectedUserId = userId?.trim() ?? '';
  if (snapshot == null ||
      expectedUserId.isEmpty ||
      snapshot.userId.trim() != expectedUserId) {
    return const [];
  }
  final entries = [
    for (final entry in snapshot.entries)
      if (entry.roomId.trim().isNotEmpty &&
          entry.hasDisplaySignal &&
          !hiddenConversationIds.contains(entry.roomId.trim()))
        entry,
  ];
  sortConversationSummaryEntries(entries, pinnedConversationIds);
  return List.unmodifiable(entries);
}

List<ConversationSummaryEntry> mergeConversationSummaryEntries({
  required List<ConversationSummaryEntry> cachedEntries,
  required List<ConversationSummaryEntry> liveEntries,
  required bool includeCachedOnlyEntries,
  required Set<String> pinnedConversationIds,
}) {
  final byRoomId = <String, ConversationSummaryEntry>{};
  if (includeCachedOnlyEntries) {
    for (final entry in cachedEntries) {
      final roomId = entry.roomId.trim();
      if (roomId.isEmpty || byRoomId.containsKey(roomId)) continue;
      byRoomId[roomId] = entry;
    }
  }
  final cachedByRoomId = {
    for (final entry in cachedEntries)
      if (entry.roomId.trim().isNotEmpty) entry.roomId.trim(): entry,
  };
  for (final live in liveEntries) {
    final roomId = live.roomId.trim();
    if (roomId.isEmpty) continue;
    byRoomId[roomId] = live.mergeLive(previous: cachedByRoomId[roomId]);
  }
  final entries = byRoomId.values.toList();
  sortConversationSummaryEntries(entries, pinnedConversationIds);
  return List.unmodifiable(entries);
}

ConversationSummaryProjection projectConversationSummaryEntries({
  required ConversationSummaryState state,
  required String? userId,
  required Set<String> hiddenConversationIds,
  required Set<String> pinnedConversationIds,
  required List<ConversationSummaryEntry> liveEntries,
  required bool includeCachedOnlyEntries,
}) {
  final owner = userId?.trim() ?? '';
  final cachedEntries = conversationSummaryEntriesForUser(
    state.toSnapshot(),
    userId: owner,
    hiddenConversationIds: hiddenConversationIds,
    pinnedConversationIds: pinnedConversationIds,
  );
  final storeEntries = mergeConversationSummaryEntries(
    cachedEntries:
        state.loaded ? cachedEntries : const <ConversationSummaryEntry>[],
    liveEntries: liveEntries,
    includeCachedOnlyEntries: includeCachedOnlyEntries,
    pinnedConversationIds: pinnedConversationIds,
  );
  return ConversationSummaryProjection(
    displayEntries: storeEntries,
    storeEntries: storeEntries,
    shouldWriteStore: state.loaded && owner.isNotEmpty,
  );
}

List<ConversationSummaryEntry> applyProductConversationSummary({
  required List<ConversationSummaryEntry> existingEntries,
  required AsConversation conversation,
  required Set<String> pinnedConversationIds,
}) {
  final roomId = conversation.roomId.trim();
  final conversationId = conversation.conversationId.trim();
  if (roomId.isEmpty) return List.unmodifiable(existingEntries);

  final entries = existingEntries
      .where((entry) => !_sameConversationSummary(
            entry,
            roomId: roomId,
            conversationId: conversationId,
          ))
      .toList();
  if (!_shouldKeepProductConversationSummary(conversation)) {
    sortConversationSummaryEntries(entries, pinnedConversationIds);
    return List.unmodifiable(entries);
  }

  ConversationSummaryEntry? previous;
  for (final entry in existingEntries) {
    if (_sameConversationSummary(
      entry,
      roomId: roomId,
      conversationId: conversationId,
    )) {
      previous = entry;
      break;
    }
  }
  entries.add(
    conversationSummaryEntryFromProductConversation(conversation)
        .mergeLive(previous: previous),
  );
  sortConversationSummaryEntries(entries, pinnedConversationIds);
  return List.unmodifiable(entries);
}

ConversationSummaryEntry conversationSummaryEntryFromProductConversation(
  AsConversation conversation,
) {
  final roomId = conversation.roomId.trim();
  final kind = conversation.kind.trim();
  return ConversationSummaryEntry(
    conversationId: conversation.conversationId.trim(),
    roomId: roomId,
    kind: kind,
    name: conversation.title.trim().isNotEmpty
        ? conversation.title.trim()
        : roomId,
    lastMessage: conversation.lastMessage,
    previewTs: conversation.lastActivityAt?.millisecondsSinceEpoch ?? 0,
    unread: 0,
    isGroup: conversation.isGroup || conversation.isChannel,
    isAgent: conversation.isAgent,
    canOpen: conversation.canOpen,
    avatarUrl: conversation.avatarUrl.trim(),
  );
}

void sortConversationSummaryEntries(
  List<ConversationSummaryEntry> entries,
  Set<String> pinnedConversationIds,
) {
  entries.sort((a, b) {
    if (a.isAgent != b.isAgent) return a.isAgent ? -1 : 1;
    final aPinned = pinnedConversationIds.contains(a.roomId.trim());
    final bPinned = pinnedConversationIds.contains(b.roomId.trim());
    if (aPinned != bPinned) return aPinned ? -1 : 1;
    if (a.previewTs != b.previewTs) return b.previewTs.compareTo(a.previewTs);
    return a.roomId.compareTo(b.roomId);
  });
}

bool _shouldKeepProductConversationSummary(AsConversation conversation) {
  final lifecycle = conversation.lifecycle.trim().toLowerCase();
  return conversation.canOpen &&
      !conversation.isChannel &&
      lifecycle != 'deleted' &&
      lifecycle != 'left' &&
      lifecycle != 'dissolved';
}

bool _sameConversationSummary(
  ConversationSummaryEntry entry, {
  required String roomId,
  required String conversationId,
}) {
  final entryConversationId = entry.conversationId.trim();
  return (conversationId.isNotEmpty &&
          entryConversationId.isNotEmpty &&
          entryConversationId == conversationId) ||
      entry.roomId.trim() == roomId;
}

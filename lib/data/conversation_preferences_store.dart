import 'dart:convert';
import 'dart:io';

class ConversationPreferencesData {
  const ConversationPreferencesData({
    this.pinnedConversationIds = const {},
    this.groupRemarkNames = const {},
    Set<String> mutedConversationIds = const {},
    Set<String> hiddenConversationIds = const {},
  })  : _mutedConversationIds = mutedConversationIds,
        _hiddenConversationIds = hiddenConversationIds;

  final Set<String> pinnedConversationIds;
  final Map<String, String> groupRemarkNames;
  final Set<String>? _mutedConversationIds;
  final Set<String>? _hiddenConversationIds;

  Set<String> get mutedConversationIds => _mutedConversationIds ?? const {};

  Set<String> get hiddenConversationIds => _hiddenConversationIds ?? const {};
}

abstract class ConversationPreferencesStore {
  Future<ConversationPreferencesData> read();

  Future<void> write(ConversationPreferencesData data);
}

class FileConversationPreferencesStore implements ConversationPreferencesStore {
  const FileConversationPreferencesStore(this.file);

  final File file;

  @override
  Future<ConversationPreferencesData> read() async {
    if (!await file.exists()) return const ConversationPreferencesData();
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return const ConversationPreferencesData();
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        return const ConversationPreferencesData();
      }
      final pinned = decoded['pinned_conversation_ids'];
      final remarks = decoded['group_remark_names'];
      final muted = decoded['muted_conversation_ids'];
      final hidden = decoded['hidden_conversation_ids'];
      return ConversationPreferencesData(
        pinnedConversationIds: pinned is List
            ? pinned
                .map((value) => '$value'.trim())
                .where((value) => value.isNotEmpty)
                .toSet()
            : const {},
        groupRemarkNames: remarks is Map
            ? Map.unmodifiable({
                for (final entry in remarks.entries)
                  if ('${entry.key}'.trim().isNotEmpty &&
                      '${entry.value}'.trim().isNotEmpty)
                    '${entry.key}'.trim(): '${entry.value}'.trim(),
              })
            : const {},
        mutedConversationIds: muted is List
            ? muted
                .map((value) => '$value'.trim())
                .where((value) => value.isNotEmpty)
                .toSet()
            : const {},
        hiddenConversationIds: hidden is List
            ? hidden
                .map((value) => '$value'.trim())
                .where((value) => value.isNotEmpty)
                .toSet()
            : const {},
      );
    } catch (_) {
      return const ConversationPreferencesData();
    }
  }

  @override
  Future<void> write(ConversationPreferencesData data) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'pinned_conversation_ids': data.pinnedConversationIds.toList()..sort(),
        'group_remark_names': data.groupRemarkNames,
        'muted_conversation_ids': data.mutedConversationIds.toList()..sort(),
        'hidden_conversation_ids': data.hiddenConversationIds.toList()..sort(),
      }),
      flush: true,
    );
  }
}

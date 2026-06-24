import 'dart:convert';
import 'dart:io';

class ConversationPreferencesData {
  const ConversationPreferencesData({
    this.pinnedConversationIds = const {},
    this.groupRemarkNames = const {},
    this.groupAvatarMemberOrders = const {},
    this.groupAvatarMemberAvatars = const {},
    Set<String> mutedConversationIds = const {},
    Set<String> hiddenConversationIds = const {},
  })  : _mutedConversationIds = mutedConversationIds,
        _hiddenConversationIds = hiddenConversationIds;

  final Set<String> pinnedConversationIds;
  final Map<String, String> groupRemarkNames;
  final Map<String, List<String>> groupAvatarMemberOrders;
  final Map<String, Map<String, String>> groupAvatarMemberAvatars;
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
      final avatarOrders = decoded['group_avatar_member_orders'];
      final avatarUrls = decoded['group_avatar_member_avatars'];
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
        groupAvatarMemberOrders: _readGroupAvatarMemberOrders(avatarOrders),
        groupAvatarMemberAvatars: _readGroupAvatarMemberAvatars(avatarUrls),
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
        'group_avatar_member_orders': data.groupAvatarMemberOrders,
        'group_avatar_member_avatars': data.groupAvatarMemberAvatars,
        'muted_conversation_ids': data.mutedConversationIds.toList()..sort(),
        'hidden_conversation_ids': data.hiddenConversationIds.toList()..sort(),
      }),
      flush: true,
    );
  }
}

Map<String, List<String>> _readGroupAvatarMemberOrders(Object? value) {
  if (value is! Map) return const {};
  final out = <String, List<String>>{};
  for (final entry in value.entries) {
    final roomId = '${entry.key}'.trim();
    final rawOrder = entry.value;
    if (roomId.isEmpty || rawOrder is! List) continue;
    final order = <String>[];
    for (final rawMemberId in rawOrder) {
      final memberId = '$rawMemberId'.trim();
      if (memberId.isNotEmpty) order.add(memberId);
    }
    if (order.isNotEmpty) out[roomId] = List.unmodifiable(order);
  }
  return Map.unmodifiable(out);
}

Map<String, Map<String, String>> _readGroupAvatarMemberAvatars(Object? value) {
  if (value is! Map) return const {};
  final out = <String, Map<String, String>>{};
  for (final entry in value.entries) {
    final roomId = '${entry.key}'.trim();
    final rawAvatars = entry.value;
    if (roomId.isEmpty || rawAvatars is! Map) continue;
    final avatars = <String, String>{};
    for (final avatarEntry in rawAvatars.entries) {
      final memberId = '${avatarEntry.key}'.trim();
      final url = '${avatarEntry.value}'.trim();
      if (memberId.isNotEmpty && url.isNotEmpty) avatars[memberId] = url;
    }
    if (avatars.isNotEmpty) out[roomId] = Map.unmodifiable(avatars);
  }
  return Map.unmodifiable(out);
}

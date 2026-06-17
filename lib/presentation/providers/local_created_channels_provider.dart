import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/as_client.dart';
import '../channel/channel_inbox_data.dart';
import 'auth_provider.dart';

final localCreatedChannelsProvider = StateNotifierProvider<
    LocalCreatedChannelsNotifier, List<ChannelCreatedCacheEntry>>((ref) {
  final userId = ref.watch(matrixClientProvider).userID ?? '';
  return LocalCreatedChannelsNotifier(userId)..load();
});

class LocalCreatedChannelsNotifier
    extends StateNotifier<List<ChannelCreatedCacheEntry>> {
  LocalCreatedChannelsNotifier(this.userId) : super(const []);

  final String userId;

  String get _key =>
      'local_created_channels.${userId.trim().isEmpty ? 'anonymous' : userId.trim()}';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final entries = decoded
          .whereType<Map>()
          .map((item) => _entryFromJson(Map<String, Object?>.from(item)))
          .whereType<ChannelCreatedCacheEntry>()
          .toList(growable: false);
      if (!mounted) return;
      state = _dedupeAndSort(entries);
    } on Object catch (error) {
      debugPrint('local created channels load failed: $error');
    }
  }

  Future<void> cacheCreatedChannel(
    AsChannel channel,
    DateTime createdAt,
  ) async {
    final entry = ChannelCreatedCacheEntry(
      channel: channel,
      createdAt: createdAt.toUtc(),
    );
    state = _dedupeAndSort([entry, ...state]);
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(state.take(80).map(_entryToJson).toList());
      await prefs.setString(_key, json);
    } on Object catch (error) {
      debugPrint('local created channels save failed: $error');
    }
  }
}

List<ChannelCreatedCacheEntry> _dedupeAndSort(
  List<ChannelCreatedCacheEntry> entries,
) {
  final seen = <String>{};
  final result = <ChannelCreatedCacheEntry>[];
  for (final entry in entries
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt))) {
    final channelId = entry.channel.channelId.trim();
    final roomId = entry.channel.roomId.trim();
    final key = channelId.isNotEmpty ? 'channel:$channelId' : 'room:$roomId';
    if (key == 'room:' || seen.contains(key)) continue;
    seen.add(key);
    result.add(entry);
  }
  return result;
}

Map<String, Object?> _entryToJson(ChannelCreatedCacheEntry entry) {
  return {
    'channel': entry.channel.toJson(),
    'created_at': entry.createdAt.toUtc().toIso8601String(),
  };
}

ChannelCreatedCacheEntry? _entryFromJson(Map<String, Object?> json) {
  final channelJson = json['channel'];
  if (channelJson is! Map) return null;
  final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
  if (createdAt == null) return null;
  final channel = AsChannel.fromJson(Map<String, Object?>.from(channelJson));
  if (channel.channelId.trim().isEmpty && channel.roomId.trim().isEmpty) {
    return null;
  }
  return ChannelCreatedCacheEntry(
    channel: channel,
    createdAt: createdAt.toUtc(),
  );
}

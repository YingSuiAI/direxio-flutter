import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'im_public_client.dart';

const imPublicChannelTagCacheTtl = Duration(days: 1);

class ImPublicTagCacheSnapshot {
  const ImPublicTagCacheSnapshot({
    required this.tags,
    required this.fetchedAt,
  });

  final List<ImPublicTag> tags;
  final DateTime fetchedAt;

  factory ImPublicTagCacheSnapshot.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as List? ?? const [];
    return ImPublicTagCacheSnapshot(
      tags: rawTags
          .whereType<Map>()
          .map((item) => ImPublicTag.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
      fetchedAt:
          DateTime.tryParse(json['fetched_at'] as String? ?? '')?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tags': tags.map((tag) => tag.toJson()).toList(growable: false),
      'fetched_at': fetchedAt.toUtc().toIso8601String(),
    };
  }

  bool isFresh(DateTime now, {Duration ttl = imPublicChannelTagCacheTtl}) {
    final fetched = fetchedAt.toUtc();
    final current = now.toUtc();
    if (current.isBefore(fetched)) return false;
    return current.difference(fetched) < ttl;
  }
}

abstract class ImPublicTagCacheStore {
  Future<ImPublicTagCacheSnapshot?> readChannelTags();

  Future<void> writeChannelTags(ImPublicTagCacheSnapshot snapshot);
}

class SharedPreferencesImPublicTagCacheStore implements ImPublicTagCacheStore {
  const SharedPreferencesImPublicTagCacheStore(this.preferences);

  static const _channelTagsKey = 'im_public_channel_tags.v1';

  final SharedPreferences preferences;

  @override
  Future<ImPublicTagCacheSnapshot?> readChannelTags() async {
    try {
      final raw = preferences.getString(_channelTagsKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ImPublicTagCacheSnapshot.fromJson(decoded.cast<String, dynamic>());
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writeChannelTags(ImPublicTagCacheSnapshot snapshot) async {
    await preferences.setString(_channelTagsKey, jsonEncode(snapshot.toJson()));
  }
}

Future<List<ImPublicTag>> loadCachedImPublicChannelTags({
  required ImPublicClient client,
  required ImPublicTagCacheStore store,
  DateTime? now,
  Duration ttl = imPublicChannelTagCacheTtl,
}) async {
  final current = (now ?? DateTime.now()).toUtc();
  final cached = await store.readChannelTags();
  if (cached != null &&
      cached.tags.isNotEmpty &&
      cached.isFresh(current, ttl: ttl)) {
    return cached.tags;
  }

  try {
    final tags = await client.listTags(type: 'channel');
    await store.writeChannelTags(
      ImPublicTagCacheSnapshot(tags: tags, fetchedAt: current),
    );
    return tags;
  } on Object {
    if (cached != null && cached.tags.isNotEmpty) return cached.tags;
    rethrow;
  }
}

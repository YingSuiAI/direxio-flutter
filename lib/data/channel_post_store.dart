import 'dart:convert';
import 'dart:io';

import 'as_client.dart';

abstract class ChannelPostStore {
  Future<List<AsChannelPost>> readChannel(String channelId);

  Future<void> upsertChannel(
    String channelId,
    Iterable<AsChannelPost> posts,
  );

  Future<void> upsertPost(AsChannelPost post);

  Future<void> removePost(String channelId, String postId);

  Future<void> clear();
}

class DeferredChannelPostStore implements ChannelPostStore {
  DeferredChannelPostStore(this._loadStore);

  final Future<ChannelPostStore> Function() _loadStore;

  @override
  Future<List<AsChannelPost>> readChannel(String channelId) async {
    final store = await _loadStore();
    return store.readChannel(channelId);
  }

  @override
  Future<void> upsertChannel(
    String channelId,
    Iterable<AsChannelPost> posts,
  ) async {
    final store = await _loadStore();
    await store.upsertChannel(channelId, posts);
  }

  @override
  Future<void> upsertPost(AsChannelPost post) async {
    final store = await _loadStore();
    await store.upsertPost(post);
  }

  @override
  Future<void> removePost(String channelId, String postId) async {
    final store = await _loadStore();
    await store.removePost(channelId, postId);
  }

  @override
  Future<void> clear() async {
    final store = await _loadStore();
    await store.clear();
  }
}

class FileChannelPostStore implements ChannelPostStore {
  const FileChannelPostStore(
    this.file, {
    this.maxEntries = 2000,
  });

  final File file;
  final int maxEntries;

  @override
  Future<List<AsChannelPost>> readChannel(String channelId) async {
    final trimmed = channelId.trim();
    if (trimmed.isEmpty) return const [];
    final posts = (await _readAll())
        .where((post) => post.channelId.trim() == trimmed)
        .toList(growable: false)
      ..sort((a, b) => b.originServerTs.compareTo(a.originServerTs));
    return posts;
  }

  @override
  Future<void> upsertChannel(
    String channelId,
    Iterable<AsChannelPost> posts,
  ) async {
    final trimmed = channelId.trim();
    if (trimmed.isEmpty) return;
    final normalized = [
      for (final post in posts)
        if (post.channelId.trim() == trimmed) _validOrNull(post),
    ].whereType<AsChannelPost>().toList(growable: false);
    await _replaceChannel(trimmed, normalized);
  }

  @override
  Future<void> upsertPost(AsChannelPost post) async {
    final valid = _validOrNull(post);
    if (valid == null) return;
    await _upsertAll([valid]);
  }

  @override
  Future<void> removePost(String channelId, String postId) async {
    final trimmedChannelId = channelId.trim();
    final trimmedPostId = postId.trim();
    if (trimmedChannelId.isEmpty || trimmedPostId.isEmpty) return;
    final next = (await _readAll()).where((post) {
      if (post.channelId.trim() != trimmedChannelId) return true;
      final id = post.postId.trim();
      if (id.isNotEmpty) return id != trimmedPostId;
      return post.eventId.trim() != trimmedPostId;
    }).toList(growable: false);
    await _write(next);
  }

  @override
  Future<void> clear() async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<List<AsChannelPost>> _readAll() async {
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
              AsChannelPost.fromJson(item.cast<String, dynamic>()),
            ),
      ].whereType<AsChannelPost>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _upsertAll(Iterable<AsChannelPost> posts) async {
    final byStableId = <String, AsChannelPost>{
      for (final post in await _readAll()) _stableId(post): post,
    };
    for (final post in posts) {
      byStableId[_stableId(post)] = post;
    }
    final next = byStableId.values.toList(growable: false)
      ..sort((a, b) => a.originServerTs.compareTo(b.originServerTs));
    final capped = next.length <= maxEntries
        ? next
        : next.sublist(next.length - maxEntries);
    await _write(capped);
  }

  Future<void> _replaceChannel(
    String channelId,
    Iterable<AsChannelPost> posts,
  ) async {
    final byStableId = <String, AsChannelPost>{
      for (final post in await _readAll())
        if (post.channelId.trim() != channelId) _stableId(post): post,
    };
    for (final post in posts) {
      byStableId[_stableId(post)] = post;
    }
    final next = byStableId.values.toList(growable: false)
      ..sort((a, b) => a.originServerTs.compareTo(b.originServerTs));
    final capped = next.length <= maxEntries
        ? next
        : next.sublist(next.length - maxEntries);
    await _write(capped);
  }

  AsChannelPost? _validOrNull(AsChannelPost post) {
    if (post.channelId.trim().isEmpty || _stableId(post).isEmpty) {
      return null;
    }
    return post;
  }

  String _stableId(AsChannelPost post) {
    final channelId = post.channelId.trim();
    if (channelId.isEmpty) return '';
    final postId = post.postId.trim();
    if (postId.isNotEmpty) return '$channelId|post:$postId';
    final eventId = post.eventId.trim();
    if (eventId.isNotEmpty) return '$channelId|event:$eventId';
    return '';
  }

  Future<void> _write(List<AsChannelPost> posts) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode([for (final post in posts) post.toJson()]),
      flush: true,
    );
  }
}

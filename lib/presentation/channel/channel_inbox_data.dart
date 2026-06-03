import '../../data/as_client.dart';

class ChannelInboxItem {
  const ChannelInboxItem({
    required this.id,
    required this.name,
    required this.domain,
    required this.avatarUrl,
    required this.latestPreview,
    required this.latestAt,
    required this.unreadCount,
    required this.isOwned,
    required this.tags,
  });

  final String id;
  final String name;
  final String domain;
  final String avatarUrl;
  final String latestPreview;
  final DateTime? latestAt;
  final int unreadCount;
  final bool isOwned;
  final List<String> tags;
}

class ChannelInboxData {
  const ChannelInboxData._();

  static List<ChannelInboxItem> fromBootstrap(
    AsSyncBootstrap bootstrap, {
    required String fallbackDomain,
  }) {
    final items = bootstrap.channels
        .where((channel) => channel.roomId.trim().isNotEmpty)
        .map(
          (channel) => ChannelInboxItem(
            id: channel.roomId,
            name: channel.name.trim().isEmpty ? '未命名频道' : channel.name.trim(),
            domain: _domainFromRoomId(channel.roomId) ?? fallbackDomain,
            avatarUrl: channel.avatarUrl,
            latestPreview:
                channel.topic.trim().isEmpty ? '暂无频道动态' : channel.topic.trim(),
            latestAt: channel.lastActivityAt,
            unreadCount: channel.unreadCount,
            isOwned: channel.isOwned,
            tags: channel.tags,
          ),
        )
        .toList();
    return _sortByLatest(items);
  }

  static List<String> categories(List<ChannelInboxItem> items) {
    final categories = <String>['全部', '我的频道'];
    final seen = categories.toSet();
    for (final item in items) {
      for (final tag in item.tags) {
        final trimmed = tag.trim();
        if (trimmed.isEmpty || seen.contains(trimmed)) continue;
        seen.add(trimmed);
        categories.add(trimmed);
      }
    }
    return categories;
  }

  static List<ChannelInboxItem> filtered(
    List<ChannelInboxItem> items,
    String category,
  ) {
    final filtered = switch (category) {
      '全部' => items,
      '我的频道' => items.where((item) => item.isOwned),
      _ => items.where((item) => item.tags.contains(category)),
    };
    return _sortByLatest(filtered.toList());
  }

  static List<ChannelInboxItem> _sortByLatest(List<ChannelInboxItem> items) {
    items.sort((a, b) {
      final aMs = a.latestAt?.millisecondsSinceEpoch ?? 0;
      final bMs = b.latestAt?.millisecondsSinceEpoch ?? 0;
      return bMs.compareTo(aMs);
    });
    return items;
  }

  static String? _domainFromRoomId(String roomId) {
    final idx = roomId.lastIndexOf(':');
    if (idx < 0 || idx == roomId.length - 1) return null;
    return roomId.substring(idx + 1);
  }
}

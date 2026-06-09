import '../../data/as_client.dart';

class ChannelInboxItem {
  const ChannelInboxItem({
    required this.id,
    required this.roomId,
    required this.name,
    required this.domain,
    required this.avatarUrl,
    required this.latestPreview,
    required this.latestAt,
    required this.unreadCount,
    required this.isOwned,
    required this.tags,
    this.description = '',
    this.visibility = asChannelVisibilityPublic,
    this.joinPolicy = asChannelJoinPolicyOpen,
    this.commentsEnabled = true,
    this.role = asChannelRoleMember,
    this.memberStatus = asChannelMemberStatusJoined,
    this.memberCount = 0,
    this.pendingJoinCount = 0,
  });

  /// Product-level channel id owned by AS. Use this for channel routes and AS
  /// channel APIs. It may fall back to [roomId] for legacy bootstrap data.
  final String id;

  /// Matrix room id used only for Matrix transport actions such as forwarding.
  final String roomId;
  final String name;
  final String domain;
  final String avatarUrl;
  final String latestPreview;
  final DateTime? latestAt;
  final int unreadCount;
  final bool isOwned;
  final List<String> tags;
  final String description;
  final String visibility;
  final String joinPolicy;
  final bool commentsEnabled;
  final String role;
  final String memberStatus;
  final int memberCount;
  final int pendingJoinCount;
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
      (channel) {
        final roomId = channel.roomId.trim();
        final channelId = channel.channelId.trim();
        final description = channel.description.trim();
        final topic = channel.topic.trim();
        return ChannelInboxItem(
          id: channelId.isEmpty ? roomId : channelId,
          roomId: roomId,
          name: channel.name.trim().isEmpty ? '未命名频道' : channel.name.trim(),
          domain: channel.homeDomain.trim().isEmpty
              ? _domainFromRoomId(roomId) ?? fallbackDomain
              : channel.homeDomain.trim(),
          avatarUrl: channel.avatarUrl,
          latestPreview: description.isNotEmpty
              ? description
              : topic.isEmpty
                  ? '暂无频道动态'
                  : topic,
          latestAt: channel.lastActivityAt,
          unreadCount: channel.unreadCount,
          isOwned: channel.isOwned,
          tags: channel.tags,
          description: description,
          visibility: channel.visibility,
          joinPolicy: channel.joinPolicy,
          commentsEnabled: channel.commentsEnabled,
          role: channel.role,
          memberStatus: channel.memberStatus,
          memberCount: channel.memberCount,
          pendingJoinCount: channel.pendingJoinCount,
        );
      },
    ).toList();
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

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
    this.channelType = asChannelTypeChat,
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
  final String channelType;
  final String role;
  final String memberStatus;
  final int memberCount;
  final int pendingJoinCount;

  ChannelInboxItem copyWith({
    String? id,
    String? roomId,
    String? name,
    String? domain,
    String? avatarUrl,
    String? latestPreview,
    DateTime? latestAt,
    int? unreadCount,
    bool? isOwned,
    List<String>? tags,
    String? description,
    String? visibility,
    String? joinPolicy,
    bool? commentsEnabled,
    String? channelType,
    String? role,
    String? memberStatus,
    int? memberCount,
    int? pendingJoinCount,
  }) {
    return ChannelInboxItem(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      domain: domain ?? this.domain,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      latestPreview: latestPreview ?? this.latestPreview,
      latestAt: latestAt ?? this.latestAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isOwned: isOwned ?? this.isOwned,
      tags: tags ?? this.tags,
      description: description ?? this.description,
      visibility: visibility ?? this.visibility,
      joinPolicy: joinPolicy ?? this.joinPolicy,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      channelType: channelType ?? this.channelType,
      role: role ?? this.role,
      memberStatus: memberStatus ?? this.memberStatus,
      memberCount: memberCount ?? this.memberCount,
      pendingJoinCount: pendingJoinCount ?? this.pendingJoinCount,
    );
  }
}

class ChannelCreatedCacheEntry {
  const ChannelCreatedCacheEntry({
    required this.channel,
    required this.createdAt,
  });

  final AsChannel channel;
  final DateTime createdAt;
}

class ChannelInboxData {
  const ChannelInboxData._();

  static List<ChannelInboxItem> fromBootstrap(
    AsSyncBootstrap bootstrap, {
    required String fallbackDomain,
    String Function(String roomId)? roomNameForRoomId,
    String Function(String roomId)? roomAvatarForRoomId,
  }) {
    final items = bootstrap.channels
        .where((channel) =>
            channel.roomId.trim().isNotEmpty &&
            _channelListMemberStatusVisible(channel.memberStatus))
        .map(
      (channel) {
        final roomId = channel.roomId.trim();
        final channelId = channel.channelId.trim();
        final description = _channelPreviewText(channel.description);
        final topic = _channelPreviewText(channel.topic);
        final name = _preferReadableChannelName(
          channel.name,
          roomNameForRoomId?.call(roomId),
          roomId,
        );
        return ChannelInboxItem(
          id: channelId.isEmpty ? roomId : channelId,
          roomId: roomId,
          name: name.isEmpty ? '未命名频道' : name,
          domain: channel.homeDomain.trim().isEmpty
              ? _domainFromRoomId(roomId) ?? fallbackDomain
              : channel.homeDomain.trim(),
          avatarUrl: _preferReadableText(
              channel.avatarUrl, roomAvatarForRoomId?.call(roomId)),
          latestPreview: description.isNotEmpty
              ? description
              : topic.isEmpty
                  ? '暂无频道动态'
                  : topic,
          latestAt: channel.lastActivityAt,
          unreadCount: channel.unreadCount,
          isOwned: _isChannelOwnerRole(channel.role) || channel.isOwned,
          tags: channel.tags,
          description: description,
          visibility: channel.visibility,
          joinPolicy: channel.joinPolicy,
          commentsEnabled: channel.commentsEnabled,
          channelType: normalizeAsChannelType(channel.channelType),
          role: channel.role,
          memberStatus: channel.memberStatus,
          memberCount: channel.memberCount,
          pendingJoinCount: channel.pendingJoinCount,
        );
      },
    ).toList();
    return _sortByLatest(items);
  }

  static List<ChannelInboxItem> fromChannels(
    List<AsChannel> channels, {
    required String fallbackDomain,
    AsSyncBootstrap? bootstrap,
    String Function(String roomId)? roomNameForRoomId,
    String Function(String roomId)? roomAvatarForRoomId,
  }) {
    final bootstrapByChannelId = <String, AsSyncRoomSummary>{};
    final bootstrapByRoomId = <String, AsSyncRoomSummary>{};
    for (final channel in bootstrap?.channels ?? const <AsSyncRoomSummary>[]) {
      final channelId = channel.channelId.trim();
      final roomId = channel.roomId.trim();
      if (channelId.isNotEmpty) bootstrapByChannelId[channelId] = channel;
      if (roomId.isNotEmpty) bootstrapByRoomId[roomId] = channel;
    }
    final items = channels.where((channel) {
      final channelId = channel.channelId.trim();
      final roomId = channel.roomId.trim();
      if (channelId.isEmpty || roomId.isEmpty) return false;
      final bootstrapChannel =
          bootstrapByChannelId[channelId] ?? bootstrapByRoomId[roomId];
      final status = _preferReadableText(
        channel.memberStatus,
        bootstrapChannel?.memberStatus,
      );
      return _channelListMemberStatusVisible(status);
    }).map((channel) {
      final roomId = channel.roomId.trim();
      final channelId = channel.channelId.trim();
      final bootstrapChannel =
          bootstrapByChannelId[channelId] ?? bootstrapByRoomId[roomId];
      final description = _channelPreviewText(
        _preferReadableText(channel.description, bootstrapChannel?.description),
      );
      final topic = _channelPreviewText(bootstrapChannel?.topic ?? '');
      final name = _preferReadableChannelName(
        channel.name,
        _preferReadableChannelName(
          bootstrapChannel?.name ?? '',
          roomNameForRoomId?.call(roomId),
          roomId,
        ),
        roomId,
      );
      return ChannelInboxItem(
        id: channelId,
        roomId: roomId,
        name: name.isEmpty ? '未命名频道' : name,
        domain: _preferReadableText(
          channel.homeDomain,
          bootstrapChannel?.homeDomain,
        ).isEmpty
            ? _domainFromRoomId(roomId) ?? fallbackDomain
            : _preferReadableText(
                channel.homeDomain, bootstrapChannel?.homeDomain),
        avatarUrl: _preferReadableText(
          channel.avatarUrl,
          _preferReadableText(
            bootstrapChannel?.avatarUrl ?? '',
            roomAvatarForRoomId?.call(roomId),
          ),
        ),
        latestPreview: description.isNotEmpty
            ? description
            : topic.isEmpty
                ? '暂无频道动态'
                : topic,
        latestAt: channel.latestActivityAt ?? bootstrapChannel?.lastActivityAt,
        unreadCount: bootstrapChannel?.unreadCount ?? 0,
        isOwned: _isChannelOwnerRole(channel.role) ||
            _isChannelOwnerRole(bootstrapChannel?.role ?? '') ||
            (bootstrapChannel?.isOwned ?? false),
        tags: channel.tags.isEmpty
            ? bootstrapChannel?.tags ?? const []
            : channel.tags,
        description: description,
        visibility: _preferReadableText(
            channel.visibility, bootstrapChannel?.visibility),
        joinPolicy: _preferReadableText(
            channel.joinPolicy, bootstrapChannel?.joinPolicy),
        commentsEnabled: channel.commentsEnabled,
        channelType: normalizeAsChannelType(
          _preferReadableText(
              channel.channelType, bootstrapChannel?.channelType),
        ),
        role: _preferReadableText(channel.role, bootstrapChannel?.role),
        memberStatus: _preferReadableText(
            channel.memberStatus, bootstrapChannel?.memberStatus),
        memberCount: channel.memberCount == 0
            ? bootstrapChannel?.memberCount ?? 0
            : channel.memberCount,
        pendingJoinCount: channel.pendingJoinCount == 0
            ? bootstrapChannel?.pendingJoinCount ?? 0
            : channel.pendingJoinCount,
      );
    }).toList();
    return _sortByLatest(items);
  }

  static List<ChannelInboxItem> mergeCreatedCache(
    List<ChannelInboxItem> items,
    List<ChannelCreatedCacheEntry> cached, {
    required String fallbackDomain,
    String Function(String roomId)? roomNameForRoomId,
    String Function(String roomId)? roomAvatarForRoomId,
    Set<String> hiddenChannelKeys = const <String>{},
  }) {
    if (cached.isEmpty) return _sortByLatest([...items]);
    final merged = [...items];
    for (final entry in cached) {
      if (_createdCacheEntryIsHidden(entry, hiddenChannelKeys)) continue;
      final cachedItems = fromChannels(
        [entry.channel],
        fallbackDomain: fallbackDomain,
        roomNameForRoomId: roomNameForRoomId,
        roomAvatarForRoomId: roomAvatarForRoomId,
      );
      if (cachedItems.isEmpty) continue;
      final cachedItem = cachedItems.single.copyWith(
        latestAt: _latestOf(cachedItems.single.latestAt, entry.createdAt),
        isOwned: true,
        role: cachedItems.single.role.trim().isEmpty
            ? asChannelRoleOwner
            : cachedItems.single.role,
        memberStatus: cachedItems.single.memberStatus.trim().isEmpty
            ? asChannelMemberStatusJoined
            : cachedItems.single.memberStatus,
      );
      final index = merged.indexWhere((item) {
        if (cachedItem.id.isNotEmpty && item.id == cachedItem.id) return true;
        if (cachedItem.roomId.isNotEmpty && item.roomId == cachedItem.roomId) {
          return true;
        }
        return false;
      });
      if (index < 0) {
        merged.add(cachedItem);
      } else {
        final mergedItem = merged[index];
        merged[index] = merged[index].copyWith(
          avatarUrl: _preferReadableText(
            mergedItem.avatarUrl,
            cachedItem.avatarUrl,
          ),
          latestAt: _latestOf(mergedItem.latestAt, entry.createdAt),
          isOwned: true,
          role: mergedItem.role.trim().isEmpty
              ? asChannelRoleOwner
              : mergedItem.role,
          memberStatus: mergedItem.memberStatus.trim().isEmpty
              ? asChannelMemberStatusJoined
              : mergedItem.memberStatus,
        );
      }
    }
    return _sortByLatest(merged);
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

  static DateTime _latestOf(DateTime? a, DateTime b) {
    if (a == null) return b;
    return a.isAfter(b) ? a : b;
  }

  static String? _domainFromRoomId(String roomId) {
    final idx = roomId.lastIndexOf(':');
    if (idx < 0 || idx == roomId.length - 1) return null;
    return roomId.substring(idx + 1);
  }
}

bool _createdCacheEntryIsHidden(
  ChannelCreatedCacheEntry entry,
  Set<String> hiddenChannelKeys,
) {
  if (hiddenChannelKeys.isEmpty) return false;
  final channelId = entry.channel.channelId.trim();
  final roomId = entry.channel.roomId.trim();
  return (channelId.isNotEmpty &&
          hiddenChannelKeys.contains('channel:$channelId')) ||
      (roomId.isNotEmpty && hiddenChannelKeys.contains('room:$roomId'));
}

bool _isChannelOwnerRole(String role) {
  final normalized = role.trim();
  return normalized == asChannelRoleOwner || normalized == asChannelRoleAdmin;
}

bool _channelListMemberStatusVisible(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized != 'left' &&
      normalized != 'removed' &&
      normalized != 'dissolved' &&
      normalized != 'deleted' &&
      normalized != 'closed';
}

String _channelPreviewText(String value) {
  final text = value.trim();
  if (_isChannelMemberCountText(text)) return '';
  return text;
}

String _preferReadableText(String primary, String? fallback) {
  final text = primary.trim();
  if (text.isNotEmpty) return text;
  return fallback?.trim() ?? '';
}

String _preferReadableChannelName(
  String primary,
  String? fallback,
  String roomId,
) {
  final text = primary.trim();
  if (text.isNotEmpty && !_looksLikeMatrixRoomId(text)) return text;
  final fallbackText = fallback?.trim() ?? '';
  if (fallbackText.isNotEmpty && !_looksLikeMatrixRoomId(fallbackText)) {
    return fallbackText;
  }
  return _looksLikeMatrixRoomId(text) ? '' : text;
}

bool _looksLikeMatrixRoomId(String text) {
  return text.startsWith('!') && text.contains(':');
}

bool _isChannelMemberCountText(String text) {
  if (text.isEmpty) return false;
  return RegExp(r'^\d+\s*名成员$').hasMatch(text) ||
      RegExp(r'^\d+\s*members?$', caseSensitive: false).hasMatch(text);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import '../chat/chat_unread_policy.dart';
import '../utils/chat_visibility_policy.dart';
import '../utils/contact_identity_label.dart';

class AsSyncCacheState {
  const AsSyncCacheState({
    this.bootstrap,
    this.localContactStatusesByRoomId = const {},
    this.localContactEntriesByRoomId = const {},
    this.localDeletedEventIdsByRoomId = const {},
    this.localReadMarkersByRoomId = const {},
    this.localClearedBeforeTs = 0,
    this.localRoomClearedBeforeTs = const {},
  });

  final AsSyncBootstrap? bootstrap;
  final Map<String, String> localContactStatusesByRoomId;
  final Map<String, ContactEntry> localContactEntriesByRoomId;
  final Map<String, Set<String>> localDeletedEventIdsByRoomId;
  final Map<String, DateTime> localReadMarkersByRoomId;
  final int localClearedBeforeTs;
  final Map<String, int> localRoomClearedBeforeTs;

  Set<String> get _localContactPeerIds {
    return localContactEntriesByRoomId.values
        .map((contact) => contact.peerMxid.trim())
        .where((peerMxid) => peerMxid.isNotEmpty)
        .toSet();
  }

  AsSyncContact _localEntryToSyncContact(
    ContactEntry contact, {
    String fallbackAvatarUrl = '',
  }) {
    return AsSyncContact(
      userId: contact.peerMxid,
      displayName: contact.displayName,
      avatarUrl: _firstNonEmpty(
        contact.productConversation?.avatarUrl,
        fallbackAvatarUrl,
      ),
      roomId: contact.roomId,
      domain: contact.domain,
      status: contact.status,
      remark: contact.remark,
      visibleAfterTs: contact.visibleAfterTs,
      deletedEventIds: contact.deletedEventIds,
    );
  }

  Map<String, String> get contactStatusesByRoomId {
    final statuses = <String, String>{};
    for (final contact in contacts) {
      final roomId = contact.roomId.trim();
      final status = contact.status.trim();
      if (roomId.isNotEmpty && status.isNotEmpty) {
        statuses[roomId] = status;
      }
    }
    statuses.addAll(localContactStatusesByRoomId);
    return statuses;
  }

  List<AsSyncContact> get contacts {
    final byPeer = <String, AsSyncContact>{};
    final peerOrder = <String>[];
    final byRoomNoPeer = <String, AsSyncContact>{};
    final roomOrder = <String>[];
    final shadowedPeerIds = _localContactPeerIds;

    void addContact(AsSyncContact contact) {
      final userId = contact.userId.trim();
      final roomId = contact.roomId.trim();
      final status = contact.status.trim();
      if (userId.isEmpty || roomId.isEmpty || status.isEmpty) return;
      if (userId.isNotEmpty) {
        final current = byPeer[userId];
        if (current == null) {
          peerOrder.add(userId);
          byPeer[userId] = contact;
          return;
        }
        byPeer[userId] = _preferredContact(current, contact);
        return;
      }
      final current = byRoomNoPeer[roomId];
      if (current == null) {
        roomOrder.add(roomId);
        byRoomNoPeer[roomId] = contact;
        return;
      }
      byRoomNoPeer[roomId] = _preferredContact(current, contact);
    }

    final bootstrapContacts = bootstrap?.contacts ?? const <AsSyncContact>[];
    for (final contact in bootstrapContacts) {
      if (shadowedPeerIds.contains(contact.userId.trim())) continue;
      addContact(contact);
    }
    for (final contact in localContactEntriesByRoomId.values) {
      final peerMxid = contact.peerMxid.trim();
      final bootstrapContact = peerMxid.isEmpty
          ? null
          : bootstrapContacts
              .where((item) => item.userId.trim() == peerMxid)
              .firstOrNull;
      addContact(
        _localEntryToSyncContact(
          contact,
          fallbackAvatarUrl: bootstrapContact?.avatarUrl ?? '',
        ),
      );
    }
    final peerRooms = byPeer.values
        .map((contact) => contact.roomId.trim())
        .where((roomId) => roomId.isNotEmpty)
        .toSet();
    final items = [
      for (final peer in peerOrder) byPeer[peer]!,
      for (final roomId in roomOrder)
        if (!peerRooms.contains(roomId)) byRoomNoPeer[roomId]!,
    ];
    return List.unmodifiable(items);
  }

  List<AsSyncContact> get acceptedContacts {
    return List.unmodifiable(
      contacts.where((contact) => contact.status.trim() == 'accepted'),
    );
  }

  List<AsSyncContact> get pendingOutboundContacts {
    return List.unmodifiable(
      contacts.where((contact) => contact.status.trim() == 'pending_outbound'),
    );
  }

  List<AsSyncContact> get rejectedOutboundContacts {
    return List.unmodifiable(
      contacts.where((contact) => contact.status.trim() == 'rejected_outbound'),
    );
  }

  List<AsSyncContact> get pendingInboundContacts {
    return List.unmodifiable(
      contacts.where((contact) => contact.status.trim() == 'pending_inbound'),
    );
  }

  List<AsSyncContact> get rejectedInboundContacts {
    return List.unmodifiable(
      contacts.where((contact) => contact.status.trim() == 'rejected_inbound'),
    );
  }

  List<AsSyncContact> get outgoingRequestContacts {
    return List.unmodifiable(
      contacts.where((contact) {
        final status = contact.status.trim();
        return status == 'pending_outbound' || status == 'rejected_outbound';
      }),
    );
  }

  Set<String> get acceptedDirectRoomIds {
    return contactStatusesByRoomId.entries
        .where((entry) => entry.value == 'accepted')
        .map((entry) => entry.key)
        .toSet();
  }

  Set<String> get nonAcceptedContactRoomIds {
    return contactStatusesByRoomId.entries
        .where((entry) => entry.value.isNotEmpty && entry.value != 'accepted')
        .map((entry) => entry.key)
        .toSet();
  }

  String? contactStatusForRoom(String roomId) {
    final trimmed = roomId.trim();
    if (trimmed.isEmpty) return null;
    return contactStatusesByRoomId[trimmed];
  }

  bool isPendingContactRoom(String roomId) {
    final status = contactStatusForRoom(roomId);
    return status == 'pending_outbound' || status == 'pending_inbound';
  }

  AsSyncContact? contactForRoom(String roomId) {
    final trimmed = roomId.trim();
    if (trimmed.isEmpty) return null;
    for (final contact in contacts) {
      if (contact.roomId == trimmed) {
        return contact;
      }
    }
    return null;
  }

  AsSyncContact? acceptedContactForRoom(String roomId) {
    final contact = contactForRoom(roomId);
    return contact?.status == 'accepted' ? contact : null;
  }

  AsSyncContact? contactForUserId(String userId) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return null;
    for (final contact in contacts) {
      if (contact.userId.trim() == trimmed) {
        return contact;
      }
    }
    return null;
  }

  AsSyncContact? acceptedContactForUserId(String userId) {
    final contact = contactForUserId(userId);
    return contact?.status == 'accepted' ? contact : null;
  }

  AsSyncCacheState copyWith({
    AsSyncBootstrap? bootstrap,
    Map<String, String>? localContactStatusesByRoomId,
    Map<String, ContactEntry>? localContactEntriesByRoomId,
    Map<String, Set<String>>? localDeletedEventIdsByRoomId,
    Map<String, DateTime>? localReadMarkersByRoomId,
    int? localClearedBeforeTs,
    Map<String, int>? localRoomClearedBeforeTs,
  }) {
    final nextReadMarkers =
        localReadMarkersByRoomId ?? this.localReadMarkersByRoomId;
    final nextBootstrap = bootstrap == null
        ? this.bootstrap
        : applyLocalReadMarkersToBootstrap(bootstrap, nextReadMarkers);
    var nextLocalStatuses =
        localContactStatusesByRoomId ?? this.localContactStatusesByRoomId;
    var nextLocalEntries =
        localContactEntriesByRoomId ?? this.localContactEntriesByRoomId;
    if (bootstrap != null && localContactStatusesByRoomId == null) {
      // A bootstrap response is authoritative for P2P contact state. Local
      // Optimistic pending entries are only a short bridge between a mutation
      // and the next successful bootstrap; keeping omitted pending rooms would
      // leave stale requests stuck in the UI. Locally derived outbound rejects
      // are preserved so the requester sees "已拒绝" instead of a disappearing
      // row when the P2P API has already cleaned up the pending Matrix room.
      final bootstrapRoomIds = bootstrap.contacts
          .map((contact) => contact.roomId.trim())
          .where((roomId) => roomId.isNotEmpty)
          .toSet();
      if (nextLocalStatuses.isNotEmpty) {
        nextLocalStatuses = Map<String, String>.from(nextLocalStatuses)
          ..removeWhere((roomId, status) {
            if (bootstrapRoomIds.contains(roomId)) return true;
            return status != 'accepted' &&
                status != 'rejected_outbound' &&
                status != 'rejected_inbound';
          });
      }
    }
    if (bootstrap != null && localContactEntriesByRoomId == null) {
      final bootstrapRoomIds = bootstrap.contacts
          .map((contact) => contact.roomId.trim())
          .where((roomId) => roomId.isNotEmpty)
          .toSet();
      final bootstrapPeerIds = bootstrap.contacts
          .map((contact) => contact.userId.trim())
          .where((userId) => userId.isNotEmpty)
          .toSet();
      if (nextLocalEntries.isNotEmpty) {
        nextLocalEntries = Map<String, ContactEntry>.from(nextLocalEntries)
          ..removeWhere((roomId, contact) {
            if (bootstrapRoomIds.contains(roomId)) return true;
            if (bootstrapPeerIds.contains(contact.peerMxid.trim())) {
              return true;
            }
            final status = contact.status.trim();
            return status != 'accepted' &&
                status != 'rejected_outbound' &&
                status != 'rejected_inbound';
          });
      }
    }
    return AsSyncCacheState(
      bootstrap: nextBootstrap,
      localContactStatusesByRoomId: Map.unmodifiable(nextLocalStatuses),
      localContactEntriesByRoomId: Map.unmodifiable(nextLocalEntries),
      localDeletedEventIdsByRoomId: _freezeDeletedMap(
        localDeletedEventIdsByRoomId ?? this.localDeletedEventIdsByRoomId,
      ),
      localReadMarkersByRoomId: Map.unmodifiable(nextReadMarkers),
      localClearedBeforeTs: localClearedBeforeTs ?? this.localClearedBeforeTs,
      localRoomClearedBeforeTs: Map.unmodifiable(
          localRoomClearedBeforeTs ?? this.localRoomClearedBeforeTs),
    );
  }

  AsSyncCacheState withContactEntry(ContactEntry contact) {
    final roomId = contact.roomId.trim();
    final status = contact.status.trim();
    if (roomId.isEmpty || status.isEmpty) return this;
    final statuses = Map<String, String>.from(localContactStatusesByRoomId);
    final entries = Map<String, ContactEntry>.from(localContactEntriesByRoomId);
    final peerMxid = contact.peerMxid.trim();
    if (peerMxid.isNotEmpty) {
      for (final entry in entries.entries.toList()) {
        if (entry.value.peerMxid.trim() == peerMxid) {
          entries.remove(entry.key);
          statuses.remove(entry.key);
        }
      }
      for (final bootstrapContact
          in bootstrap?.contacts ?? const <AsSyncContact>[]) {
        if (bootstrapContact.userId.trim() == peerMxid) {
          statuses.remove(bootstrapContact.roomId.trim());
        }
      }
    }
    statuses.remove(roomId);
    entries[roomId] = contact;
    return copyWith(
      localContactStatusesByRoomId: statuses,
      localContactEntriesByRoomId: entries,
    );
  }

  AsSyncCacheState withContactDisplayName({
    required String userId,
    required String displayName,
  }) {
    final trimmedUserId = userId.trim();
    final trimmedName = displayName.trim();
    if (trimmedUserId.isEmpty || trimmedName.isEmpty) return this;

    final entries = Map<String, ContactEntry>.from(localContactEntriesByRoomId);
    for (final entry in entries.entries.toList()) {
      final contact = entry.value;
      if (contact.peerMxid.trim() != trimmedUserId) continue;
      entries[entry.key] = ContactEntry(
        peerMxid: contact.peerMxid,
        displayName: trimmedName,
        domain: contact.domain,
        roomId: contact.roomId,
        status: contact.status,
        remark: contact.remark,
        visibleAfterTs: contact.visibleAfterTs,
        deletedEventIds: contact.deletedEventIds,
      );
    }

    final current = bootstrap;
    final updatedBootstrap = current == null
        ? null
        : AsSyncBootstrap(
            syncedAt: current.syncedAt,
            user: current.user,
            agentRoomId: current.agentRoomId,
            rooms: current.rooms,
            contacts: current.contacts.map((contact) {
              if (contact.userId.trim() != trimmedUserId) return contact;
              return AsSyncContact(
                userId: contact.userId,
                displayName: trimmedName,
                avatarUrl: contact.avatarUrl,
                roomId: contact.roomId,
                domain: contact.domain,
                status: contact.status,
                visibleAfterTs: contact.visibleAfterTs,
                deletedEventIds: contact.deletedEventIds,
              );
            }).toList(growable: false),
            groups: current.groups,
            channels: current.channels,
            pending: current.pending,
          );

    return copyWith(
      bootstrap: updatedBootstrap,
      localContactEntriesByRoomId: entries,
    );
  }

  ChatVisibilityPolicy chatVisibilityPolicyForRoom(String roomId) {
    final contact = contactForRoom(roomId);
    final deletedEventIds = <String>{
      ...?contact?.deletedEventIds,
      ...?localDeletedEventIdsByRoomId[roomId],
    };
    return ChatVisibilityPolicy(
      visibleAfterTs: contact?.visibleAfterTs ?? 0,
      clearedBeforeTs: _maxInt(
        localClearedBeforeTs,
        localRoomClearedBeforeTs[roomId] ?? 0,
      ),
      deletedEventIds: deletedEventIds,
    );
  }

  AsSyncCacheState withAllChatsClearedBefore(int timestamp) {
    if (timestamp <= localClearedBeforeTs) return this;
    return copyWith(localClearedBeforeTs: timestamp);
  }

  AsSyncCacheState withRoomClearedBefore(String roomId, int timestamp) {
    final trimmed = roomId.trim();
    if (trimmed.isEmpty || timestamp <= 0) return this;
    final current = localRoomClearedBeforeTs[trimmed] ?? 0;
    if (timestamp <= current) return this;
    final next = Map<String, int>.from(localRoomClearedBeforeTs)
      ..[trimmed] = timestamp;
    return copyWith(localRoomClearedBeforeTs: next);
  }

  AsSyncCacheState withDeletedMessage(String roomId, String eventId) {
    final trimmedRoomId = roomId.trim();
    final trimmedEventId = eventId.trim();
    if (trimmedRoomId.isEmpty || trimmedEventId.isEmpty) return this;
    final next = <String, Set<String>>{};
    for (final entry in localDeletedEventIdsByRoomId.entries) {
      next[entry.key] = {...entry.value};
    }
    next.putIfAbsent(trimmedRoomId, () => <String>{}).add(trimmedEventId);
    return copyWith(localDeletedEventIdsByRoomId: next);
  }

  AsSyncCacheState withRoomUnreadCleared(String roomId, {DateTime? readAt}) {
    final trimmed = roomId.trim();
    final current = bootstrap;
    if (trimmed.isEmpty) return this;

    final nextReadMarkers = Map<String, DateTime>.from(
      localReadMarkersByRoomId,
    );
    if (readAt != null) {
      nextReadMarkers[trimmed] = readAt.toUtc();
    }
    if (current == null) {
      return copyWith(localReadMarkersByRoomId: nextReadMarkers);
    }

    List<AsSyncRoomSummary> clear(List<AsSyncRoomSummary> rooms) {
      return rooms
          .map((room) =>
              room.roomId.trim() == trimmed ? room.withUnreadCount(0) : room)
          .toList(growable: false);
    }

    return copyWith(
      bootstrap: AsSyncBootstrap(
        syncedAt: current.syncedAt,
        user: current.user,
        rooms: clear(current.rooms),
        contacts: current.contacts,
        groups: clear(current.groups),
        channels: clear(current.channels),
        pending: current.pending,
      ),
      localReadMarkersByRoomId: nextReadMarkers,
    );
  }

  AsSyncCacheState withoutGroup(String roomId) {
    final trimmed = roomId.trim();
    final current = bootstrap;
    if (trimmed.isEmpty || current == null) return this;
    return copyWith(
      bootstrap: AsSyncBootstrap(
        syncedAt: current.syncedAt,
        user: current.user,
        rooms: current.rooms,
        contacts: current.contacts,
        groups: current.groups
            .where((group) => group.roomId.trim() != trimmed)
            .toList(growable: false),
        channels: current.channels,
        pending: current.pending,
      ),
    );
  }

  AsSyncCacheState withoutChannel(String channelIdOrRoomId) {
    final trimmed = channelIdOrRoomId.trim();
    final current = bootstrap;
    if (trimmed.isEmpty || current == null) return this;
    return copyWith(
      bootstrap: AsSyncBootstrap(
        syncedAt: current.syncedAt,
        user: current.user,
        agentRoomId: current.agentRoomId,
        rooms: current.rooms,
        contacts: current.contacts,
        groups: current.groups,
        channels: current.channels.where((channel) {
          return channel.channelId.trim() != trimmed &&
              channel.roomId.trim() != trimmed;
        }).toList(growable: false),
        pending: current.pending,
      ),
    );
  }

  AsSyncCacheState withChannelCommentsEnabled(
    String channelIdOrRoomId, {
    required bool commentsEnabled,
  }) {
    final trimmed = channelIdOrRoomId.trim();
    final current = bootstrap;
    if (trimmed.isEmpty || current == null) return this;
    var changed = false;
    final channels = current.channels.map((channel) {
      final matches = channel.channelId.trim() == trimmed ||
          channel.roomId.trim() == trimmed;
      if (!matches || channel.commentsEnabled == commentsEnabled) {
        return channel;
      }
      changed = true;
      return channel.withCommentsEnabled(commentsEnabled);
    }).toList(growable: false);
    if (!changed) return this;
    return copyWith(
      bootstrap: AsSyncBootstrap(
        syncedAt: current.syncedAt,
        user: current.user,
        agentRoomId: current.agentRoomId,
        rooms: current.rooms,
        contacts: current.contacts,
        groups: current.groups,
        channels: channels,
        pending: current.pending,
      ),
    );
  }

  AsSyncCacheState withChannelMuted(
    String channelIdOrRoomId, {
    required bool muted,
  }) {
    final trimmed = channelIdOrRoomId.trim();
    final current = bootstrap;
    if (trimmed.isEmpty || current == null) return this;
    var changed = false;
    final channels = current.channels.map((channel) {
      final matches = channel.channelId.trim() == trimmed ||
          channel.roomId.trim() == trimmed;
      if (!matches || channel.muted == muted) return channel;
      changed = true;
      return channel.withMuted(muted);
    }).toList(growable: false);
    if (!changed) return this;
    return copyWith(
      bootstrap: AsSyncBootstrap(
        syncedAt: current.syncedAt,
        user: current.user,
        agentRoomId: current.agentRoomId,
        rooms: current.rooms,
        contacts: current.contacts,
        groups: current.groups,
        channels: channels,
        pending: current.pending,
      ),
    );
  }

  AsSyncCacheState withGroupInvitePolicy(
    String roomId,
    String invitePolicy,
  ) {
    final trimmed = roomId.trim();
    final current = bootstrap;
    if (trimmed.isEmpty || current == null) return this;
    return copyWith(
      bootstrap: AsSyncBootstrap(
        syncedAt: current.syncedAt,
        user: current.user,
        rooms: current.rooms,
        contacts: current.contacts,
        groups: current.groups.map((group) {
          if (group.roomId.trim() != trimmed) return group;
          return group.withInvitePolicy(invitePolicy);
        }).toList(growable: false),
        channels: current.channels,
        pending: current.pending,
      ),
    );
  }

  AsSyncCacheState withGroupMuted(
    String roomId, {
    required bool muted,
  }) {
    final trimmed = roomId.trim();
    final current = bootstrap;
    if (trimmed.isEmpty || current == null) return this;
    return copyWith(
      bootstrap: AsSyncBootstrap(
        syncedAt: current.syncedAt,
        user: current.user,
        rooms: current.rooms,
        contacts: current.contacts,
        groups: current.groups.map((group) {
          if (group.roomId.trim() != trimmed) return group;
          return group.withMuted(muted);
        }).toList(growable: false),
        channels: current.channels,
        pending: current.pending,
      ),
    );
  }

  AsSyncCacheState withGroupName(
    String roomId,
    String name,
  ) {
    final trimmed = roomId.trim();
    final nextName = name.trim();
    final current = bootstrap;
    if (trimmed.isEmpty || nextName.isEmpty || current == null) return this;
    return copyWith(
      bootstrap: AsSyncBootstrap(
        syncedAt: current.syncedAt,
        user: current.user,
        rooms: current.rooms,
        contacts: current.contacts,
        groups: current.groups.map((group) {
          if (group.roomId.trim() != trimmed) return group;
          return group.withName(nextName);
        }).toList(growable: false),
        channels: current.channels,
        pending: current.pending,
      ),
    );
  }

  AsSyncCacheState withGroupProfile(
    String roomId, {
    String name = '',
    String avatarUrl = '',
    String topic = '',
  }) {
    final trimmed = roomId.trim();
    final current = bootstrap;
    if (trimmed.isEmpty || current == null) return this;
    return copyWith(
      bootstrap: AsSyncBootstrap(
        syncedAt: current.syncedAt,
        user: current.user,
        rooms: current.rooms,
        contacts: current.contacts,
        groups: current.groups.map((group) {
          if (group.roomId.trim() != trimmed) return group;
          return group.withProfile(
            name: name,
            avatarUrl: avatarUrl,
            topic: topic,
          );
        }).toList(growable: false),
        channels: current.channels,
        pending: current.pending,
      ),
    );
  }
}

int _maxInt(int a, int b) => a >= b ? a : b;

String _firstNonEmpty(String? first, String? second) {
  final firstValue = first?.trim() ?? '';
  if (firstValue.isNotEmpty) return firstValue;
  return second?.trim() ?? '';
}

AsSyncContact _preferredContact(AsSyncContact current, AsSyncContact next) {
  final currentRank = _contactStatusRank(current.status);
  final nextRank = _contactStatusRank(next.status);
  if (nextRank > currentRank) return next;
  if (nextRank < currentRank) return current;
  final currentNameRank = _contactDisplayNameRank(current);
  final nextNameRank = _contactDisplayNameRank(next);
  if (nextNameRank > currentNameRank) return next;
  if (nextNameRank < currentNameRank) return current;
  final currentHasAvatar = current.avatarUrl.trim().isNotEmpty;
  final nextHasAvatar = next.avatarUrl.trim().isNotEmpty;
  if (nextHasAvatar && !currentHasAvatar) return next;
  if (currentHasAvatar && !nextHasAvatar) return current;
  if (next.visibleAfterTs > current.visibleAfterTs) return next;
  if (current.visibleAfterTs > next.visibleAfterTs) return current;
  return next;
}

int _contactDisplayNameRank(AsSyncContact contact) {
  final name = contact.displayName.trim();
  if (name.isEmpty) return 0;
  final userId = contact.userId.trim();
  final localpart = localpartFromMxid(userId);
  if (name == userId || (localpart.isNotEmpty && name == localpart)) {
    return 1;
  }
  return 2;
}

int _contactStatusRank(String status) {
  switch (status.trim()) {
    case 'accepted':
      return 4;
    case 'pending_inbound':
    case 'pending_outbound':
      return 3;
    case 'rejected_outbound':
    case 'rejected_inbound':
      return 2;
    case 'deleted':
      return 1;
    default:
      return 0;
  }
}

final asSyncCacheProvider = StateProvider<AsSyncCacheState>((ref) {
  return const AsSyncCacheState();
});

bool asBootstrapBelongsToUser(AsSyncBootstrap? bootstrap, String? userId) {
  if (bootstrap == null) return true;
  final expectedUserId = userId?.trim() ?? '';
  if (expectedUserId.isEmpty) return true;
  final bootstrapUserId = bootstrap.user.userId.trim();
  return bootstrapUserId.isNotEmpty && bootstrapUserId == expectedUserId;
}

AsSyncCacheState asSyncCacheForUser(
  AsSyncCacheState state,
  String? userId,
) {
  if (asBootstrapBelongsToUser(state.bootstrap, userId)) return state;
  return const AsSyncCacheState();
}

Map<String, Set<String>> _freezeDeletedMap(Map<String, Set<String>> source) {
  return Map.unmodifiable(
    source.map(
      (key, value) => MapEntry(key, Set.unmodifiable(value)),
    ),
  );
}

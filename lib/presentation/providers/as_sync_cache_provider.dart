import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import '../../data/recovered_unread_store.dart';
import '../utils/chat_visibility_policy.dart';

class AsSyncCacheState {
  const AsSyncCacheState({
    this.bootstrap,
    this.unread,
    this.localContactStatusesByRoomId = const {},
    this.localContactEntriesByRoomId = const {},
    this.localDeletedEventIdsByRoomId = const {},
    this.localReadMarkersByRoomId = const {},
  });

  final AsSyncBootstrap? bootstrap;
  final AsSyncUnread? unread;
  final Map<String, String> localContactStatusesByRoomId;
  final Map<String, ContactEntry> localContactEntriesByRoomId;
  final Map<String, Set<String>> localDeletedEventIdsByRoomId;
  final Map<String, DateTime> localReadMarkersByRoomId;

  Set<String> get _localContactPeerIds {
    return localContactEntriesByRoomId.values
        .map((contact) => contact.peerMxid.trim())
        .where((peerMxid) => peerMxid.isNotEmpty)
        .toSet();
  }

  AsSyncContact _localEntryToSyncContact(ContactEntry contact) {
    return AsSyncContact(
      userId: contact.peerMxid,
      displayName: contact.displayName,
      avatarUrl: '',
      roomId: contact.roomId,
      domain: contact.domain,
      status: contact.status,
      visibleAfterTs: contact.visibleAfterTs,
      deletedEventIds: contact.deletedEventIds,
    );
  }

  Map<String, String> get contactStatusesByRoomId {
    final statuses = <String, String>{};
    final shadowedPeerIds = _localContactPeerIds;
    for (final contact in bootstrap?.contacts ?? const <AsSyncContact>[]) {
      if (shadowedPeerIds.contains(contact.userId.trim())) continue;
      final roomId = contact.roomId.trim();
      final status = contact.status.trim();
      if (roomId.isNotEmpty && status.isNotEmpty) {
        statuses[roomId] = status;
      }
    }
    statuses.addAll(localContactStatusesByRoomId);
    for (final entry in localContactEntriesByRoomId.entries) {
      final roomId = entry.key.trim();
      final status = entry.value.status.trim();
      if (roomId.isNotEmpty && status.isNotEmpty) {
        statuses[roomId] = status;
      }
    }
    return statuses;
  }

  List<AsSyncContact> get contacts {
    final items = <AsSyncContact>[];
    final shadowedPeerIds = _localContactPeerIds;
    for (final contact in bootstrap?.contacts ?? const <AsSyncContact>[]) {
      final userId = contact.userId.trim();
      final roomId = contact.roomId.trim();
      final status = contact.status.trim();
      if (userId.isEmpty || roomId.isEmpty || status.isEmpty) continue;
      if (shadowedPeerIds.contains(userId)) continue;
      items.add(contact);
    }
    for (final contact in localContactEntriesByRoomId.values) {
      final userId = contact.peerMxid.trim();
      final roomId = contact.roomId.trim();
      final status = contact.status.trim();
      if (userId.isEmpty || roomId.isEmpty || status.isEmpty) continue;
      items.add(_localEntryToSyncContact(contact));
    }
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
    final localEntry = localContactEntriesByRoomId[trimmed];
    if (localEntry != null) {
      return _localEntryToSyncContact(localEntry);
    }
    final shadowedPeerIds = _localContactPeerIds;
    for (final contact in bootstrap?.contacts ?? const <AsSyncContact>[]) {
      if (shadowedPeerIds.contains(contact.userId.trim())) continue;
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
    for (final contact in localContactEntriesByRoomId.values) {
      if (contact.peerMxid.trim() == trimmed) {
        return _localEntryToSyncContact(contact);
      }
    }
    for (final contact in bootstrap?.contacts ?? const <AsSyncContact>[]) {
      if (contact.userId == trimmed) {
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
    AsSyncUnread? unread,
    Map<String, String>? localContactStatusesByRoomId,
    Map<String, ContactEntry>? localContactEntriesByRoomId,
    Map<String, Set<String>>? localDeletedEventIdsByRoomId,
    Map<String, DateTime>? localReadMarkersByRoomId,
  }) {
    final nextReadMarkers =
        localReadMarkersByRoomId ?? this.localReadMarkersByRoomId;
    final nextBootstrap = bootstrap == null
        ? this.bootstrap
        : _bootstrapApplyingLocalReadMarkers(bootstrap, nextReadMarkers);
    var nextLocalStatuses =
        localContactStatusesByRoomId ?? this.localContactStatusesByRoomId;
    var nextLocalEntries =
        localContactEntriesByRoomId ?? this.localContactEntriesByRoomId;
    if (bootstrap != null && localContactStatusesByRoomId == null) {
      // A bootstrap response is authoritative for AS contact state. Local
      // Optimistic pending entries are only a short bridge between a mutation
      // and the next successful bootstrap; keeping omitted pending rooms would
      // leave stale requests stuck in the UI. Locally derived outbound rejects
      // are preserved so the requester sees "已拒绝" instead of a disappearing
      // row when AS has already cleaned up the pending Matrix room.
      final bootstrapRoomIds = bootstrap.contacts
          .map((contact) => contact.roomId.trim())
          .where((roomId) => roomId.isNotEmpty)
          .toSet();
      if (nextLocalStatuses.isNotEmpty) {
        nextLocalStatuses = Map<String, String>.from(nextLocalStatuses)
          ..removeWhere((roomId, status) {
            if (bootstrapRoomIds.contains(roomId)) return true;
            return status != 'accepted' && status != 'rejected_outbound';
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
            return status != 'accepted' && status != 'rejected_outbound';
          });
      }
    }
    return AsSyncCacheState(
      bootstrap: nextBootstrap,
      unread: unread ?? this.unread,
      localContactStatusesByRoomId: Map.unmodifiable(nextLocalStatuses),
      localContactEntriesByRoomId: Map.unmodifiable(nextLocalEntries),
      localDeletedEventIdsByRoomId: _freezeDeletedMap(
        localDeletedEventIdsByRoomId ?? this.localDeletedEventIdsByRoomId,
      ),
      localReadMarkersByRoomId: Map.unmodifiable(nextReadMarkers),
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

  List<AsUnreadMessage> unreadMessagesForRoom(String roomId) {
    return unread?.messagesForRoom(roomId) ?? const [];
  }

  ChatVisibilityPolicy chatVisibilityPolicyForRoom(String roomId) {
    final contact = contactForRoom(roomId);
    final deletedEventIds = <String>{
      ...?contact?.deletedEventIds,
      ...?localDeletedEventIdsByRoomId[roomId],
    };
    return ChatVisibilityPolicy(
      visibleAfterTs: contact?.visibleAfterTs ?? 0,
      deletedEventIds: deletedEventIds,
    );
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

  AsSyncCacheState mergeUnread(AsSyncUnread nextUnread) {
    return copyWith(unread: mergeRecoveredUnread(unread, nextUnread));
  }

  AsSyncCacheState withoutUnreadEvents(Iterable<String> eventIds) {
    final current = unread;
    if (current == null) return this;
    final ids = eventIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return this;
    return copyWith(unread: removeRecoveredUnreadEvents(current, ids));
  }

  AsSyncCacheState withoutUnreadRoom(String roomId) {
    final current = unread;
    if (current == null || roomId.isEmpty) return this;
    return copyWith(unread: removeRecoveredUnreadRoom(current, roomId));
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

AsSyncBootstrap _bootstrapApplyingLocalReadMarkers(
  AsSyncBootstrap bootstrap,
  Map<String, DateTime> readMarkers,
) {
  if (readMarkers.isEmpty) return bootstrap;

  List<AsSyncRoomSummary> apply(List<AsSyncRoomSummary> rooms) {
    return rooms.map((room) {
      final readAt = readMarkers[room.roomId.trim()];
      if (readAt == null || room.unreadCount <= 0) return room;
      final lastActivityAt = room.lastActivityAt?.toUtc();
      if (lastActivityAt != null && lastActivityAt.isAfter(readAt.toUtc())) {
        return room;
      }
      return room.withUnreadCount(0);
    }).toList(growable: false);
  }

  return AsSyncBootstrap(
    syncedAt: bootstrap.syncedAt,
    user: bootstrap.user,
    rooms: apply(bootstrap.rooms),
    contacts: bootstrap.contacts,
    groups: apply(bootstrap.groups),
    channels: apply(bootstrap.channels),
    pending: bootstrap.pending,
  );
}

Map<String, Set<String>> _freezeDeletedMap(Map<String, Set<String>> source) {
  return Map.unmodifiable(
    source.map(
      (key, value) => MapEntry(key, Set.unmodifiable(value)),
    ),
  );
}

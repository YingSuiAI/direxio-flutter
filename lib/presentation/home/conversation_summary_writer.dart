import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

import '../../data/as_client.dart';
import '../../data/conversation_summary_store.dart';
import '../../data/local_outbox_store.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/local_message_order_provider.dart';
import '../providers/local_outbox_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_display_name.dart';
import '../utils/contact_identity_label.dart';
import '../utils/direct_contact_status.dart';
import '../utils/message_preview.dart';

class VisibleHomeConversation {
  const VisibleHomeConversation._({
    required this.roomId,
    this.room,
    this.product,
    this.roomSummary,
    this.isAgent = false,
    this.isGroup = false,
  });

  factory VisibleHomeConversation.agent(Room room) {
    return VisibleHomeConversation._(
      roomId: room.id,
      room: room,
      product: _fallbackAgentConversation(room),
      isAgent: true,
    );
  }

  factory VisibleHomeConversation.agentBootstrap(String roomId) {
    return VisibleHomeConversation._(
      roomId: roomId.trim(),
      product: _fallbackAgentConversationForRoomId(roomId),
      isAgent: true,
    );
  }

  factory VisibleHomeConversation.product(
    AsConversation conversation,
    Room? room, [
    AsSyncRoomSummary? roomSummary,
  ]) {
    return VisibleHomeConversation._(
      roomId: conversation.roomId.trim(),
      room: room,
      product: conversation,
      roomSummary: roomSummary,
      isAgent: conversation.isAgent,
      isGroup: conversation.isGroup,
    );
  }

  factory VisibleHomeConversation.groupRoom(Room room) {
    return VisibleHomeConversation._(
      roomId: room.id,
      room: room,
      product: _fallbackGroupConversation(
        roomId: room.id,
        title: room.getLocalizedDisplayname(),
        lastActivityAt: room.lastEvent?.originServerTs,
      ),
      isGroup: true,
    );
  }

  final String roomId;
  final Room? room;
  final AsConversation? product;
  final AsSyncRoomSummary? roomSummary;
  final bool isAgent;
  final bool isGroup;
}

class HomeConversationSummaryResult {
  const HomeConversationSummaryResult({
    required this.projection,
    required this.productConversationsByRoomId,
  });

  final ConversationSummaryProjection projection;
  final Map<String, AsConversation> productConversationsByRoomId;

  List<ConversationSummaryEntry> get displayEntries =>
      projection.displayEntries;
  List<ConversationSummaryEntry> get storeEntries => projection.storeEntries;
  bool get shouldWriteStore => projection.shouldWriteStore;
}

HomeConversationSummaryResult buildHomeConversationSummaryProjection({
  required Client client,
  required Iterable<Room> rooms,
  required Iterable<AsConversation> productConversations,
  required bool productConversationsLoaded,
  required AsSyncCacheState syncCache,
  required ConversationSummaryState summaryState,
  required Set<String> hiddenConversationIds,
  required Set<String> pinnedConversationIds,
  required LocalOutboxState outbox,
  required LocalMessageOrderState messageOrder,
  required Map<String, String> groupRemarkNames,
  required String? currentUserId,
}) {
  final productList = productConversations.toList(growable: false);
  final canonicalAgentRoomId = syncCache.bootstrap?.agentRoomId.trim() ?? '';
  final productConversationsByRoomId = {
    for (final conversation in productList)
      if (conversation.roomId.trim().isNotEmpty)
        if (!(conversation.isAgent &&
            canonicalAgentRoomId.isNotEmpty &&
            conversation.roomId.trim() != canonicalAgentRoomId))
          conversation.roomId.trim(): conversation,
  };
  final visibleConversations = visibleHomeConversationsForSummary(
    client: client,
    rooms: rooms,
    productConversations: productList,
    syncCache: syncCache,
    outbox: outbox,
    messageOrder: messageOrder,
    pinnedConversationIds: pinnedConversationIds,
  );
  for (final conversation in visibleConversations) {
    final product = conversation.product;
    final roomId = product?.roomId.trim() ?? '';
    if (product == null || roomId.isEmpty) continue;
    productConversationsByRoomId[roomId] = product;
  }
  final liveSummaryEntries = [
    for (final conversation in visibleConversations)
      if (!hiddenConversationIds.contains(conversation.roomId))
        summaryEntryForVisibleConversation(
          client: client,
          syncCache: syncCache,
          outbox: outbox,
          messageOrder: messageOrder,
          groupRemarkNames: groupRemarkNames,
          conversation: conversation,
        ),
  ];
  return HomeConversationSummaryResult(
    productConversationsByRoomId: productConversationsByRoomId,
    projection: projectConversationSummaryEntries(
      state: summaryState,
      userId: currentUserId,
      hiddenConversationIds: hiddenConversationIds,
      pinnedConversationIds: pinnedConversationIds,
      liveEntries: liveSummaryEntries,
      includeCachedOnlyEntries: !productConversationsLoaded,
    ),
  );
}

List<VisibleHomeConversation> visibleHomeConversationsForSummary({
  required Client client,
  required Iterable<Room> rooms,
  required Iterable<AsConversation> productConversations,
  required AsSyncCacheState syncCache,
  required LocalOutboxState outbox,
  required LocalMessageOrderState messageOrder,
  required Set<String> pinnedConversationIds,
}) {
  final asRoomSummariesByRoomId = <String, AsSyncRoomSummary>{
    for (final room in syncCache.bootstrap?.rooms ?? const [])
      if (room.roomId.trim().isNotEmpty) room.roomId.trim(): room,
  };
  final asGroupSummariesByRoomId = <String, AsSyncRoomSummary>{
    for (final group in syncCache.bootstrap?.groups ?? const [])
      if (group.roomId.trim().isNotEmpty) group.roomId.trim(): group,
  };
  asRoomSummariesByRoomId.addAll(asGroupSummariesByRoomId);
  final directContactRoomIds = syncCache.acceptedContacts
      .map((contact) => contact.roomId.trim())
      .where((roomId) => roomId.isNotEmpty)
      .toSet();
  final visibleConversations = <VisibleHomeConversation>[];
  final visibleRoomIds = <String>{};

  void addVisibleConversation(VisibleHomeConversation conversation) {
    final roomId = conversation.roomId.trim();
    if (roomId.isEmpty || !visibleRoomIds.add(roomId)) return;
    visibleConversations.add(conversation);
  }

  final agentMxid = portalAgentMxidForClient(client);
  final canonicalAgentRoomId = syncCache.bootstrap?.agentRoomId.trim() ?? '';
  var fallbackAgentShown = false;
  for (final room in rooms) {
    if (room.membership != Membership.join) continue;
    if (isAgentRoom(room, agentMxid)) {
      if (canonicalAgentRoomId.isNotEmpty) {
        if (room.id != canonicalAgentRoomId) continue;
      } else {
        if (fallbackAgentShown) continue;
        fallbackAgentShown = true;
      }
      addVisibleConversation(VisibleHomeConversation.agent(room));
    }
  }

  for (final conversation in productConversations) {
    if (conversation.isChannel) continue;
    if (conversation.isAgent && canonicalAgentRoomId.isNotEmpty) {
      final canonicalRoom = client.getRoomById(canonicalAgentRoomId);
      addVisibleConversation(
        VisibleHomeConversation.product(
          _fallbackAgentConversationForRoomId(
            canonicalAgentRoomId,
            conversationId: conversation.conversationId,
            lastActivityAt: conversation.lastActivityAt ??
                canonicalRoom?.lastEvent?.originServerTs,
          ),
          canonicalRoom,
          asRoomSummariesByRoomId[canonicalAgentRoomId],
        ),
      );
      continue;
    }
    final roomId = conversation.roomId.trim();
    final room = client.getRoomById(roomId);
    final groupSummary = asGroupSummariesByRoomId[roomId];
    final visibleProduct = conversation.canOpen
        ? conversation
        : _openableFallbackForGroupConversation(
            conversation,
            room: room,
            roomSummary: groupSummary,
          );
    if (visibleProduct == null) continue;
    addVisibleConversation(
      VisibleHomeConversation.product(
        visibleProduct,
        room,
        asRoomSummariesByRoomId[roomId],
      ),
    );
  }

  if (canonicalAgentRoomId.isNotEmpty &&
      !visibleRoomIds.contains(canonicalAgentRoomId)) {
    addVisibleConversation(
      VisibleHomeConversation.agentBootstrap(canonicalAgentRoomId),
    );
  }

  for (final group in asGroupSummariesByRoomId.values) {
    final roomId = group.roomId.trim();
    if (directContactRoomIds.contains(roomId)) continue;
    final room = client.getRoomById(roomId);
    if (!_isJoinedGroupSummary(group, room)) continue;
    addVisibleConversation(
      VisibleHomeConversation.product(
        _fallbackGroupConversationForSummary(group),
        room,
        group,
      ),
    );
  }

  for (final room in rooms) {
    if (room.membership != Membership.join) continue;
    if (!_isNativeGroupRoom(room)) continue;
    addVisibleConversation(VisibleHomeConversation.groupRoom(room));
  }

  return visibleConversations
    ..sort((a, b) {
      if (a.isAgent != b.isAgent) return a.isAgent ? -1 : 1;
      final aPinned = pinnedConversationIds.contains(a.roomId);
      final bPinned = pinnedConversationIds.contains(b.roomId);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      return conversationSortTime(
        b,
        outbox: outbox,
        messageOrder: messageOrder,
      ).compareTo(
        conversationSortTime(
          a,
          outbox: outbox,
          messageOrder: messageOrder,
        ),
      );
    });
}

AsConversation? _openableFallbackForGroupConversation(
  AsConversation conversation, {
  required Room? room,
  required AsSyncRoomSummary? roomSummary,
}) {
  if (!conversation.isGroup) return null;
  final historyVisible = _isExitedGroupConversation(conversation);
  if (!_isActiveConversation(conversation) && !historyVisible) return null;
  final roomJoined = room?.membership == Membership.join;
  if (!roomJoined && room == null && roomSummary == null) return null;
  return _fallbackGroupConversation(
    roomId: conversation.roomId,
    conversationId: conversation.conversationId,
    title: conversation.title.trim().isNotEmpty
        ? conversation.title
        : roomSummary?.name ?? '',
    avatarUrl: conversation.avatarUrl.trim().isNotEmpty
        ? conversation.avatarUrl
        : roomSummary?.avatarUrl ?? '',
    lastActivityAt: conversation.lastActivityAt ?? roomSummary?.lastActivityAt,
    memberCount: conversation.memberCount > 0
        ? conversation.memberCount
        : roomSummary?.memberCount ?? 0,
    role: conversation.role,
    membership: conversation.membership,
    canSend: !historyVisible,
  );
}

AsConversation _fallbackAgentConversation(Room room) {
  return _fallbackAgentConversationForRoomId(
    room.id,
    lastActivityAt: room.lastEvent?.originServerTs,
  );
}

AsConversation _fallbackAgentConversationForRoomId(
  String roomId, {
  String conversationId = '',
  DateTime? lastActivityAt,
}) {
  final trimmedRoomId = roomId.trim();
  return AsConversation(
    conversationId: conversationId.trim(),
    roomId: trimmedRoomId,
    kind: asConversationKindAgent,
    lifecycle: 'active',
    title: 'Agent',
    avatarUrl: '',
    lastMessage: defaultAgentConversationPreview,
    lastActivityAt: lastActivityAt,
    memberCount: 2,
    membership: 'join',
    hydrationState: 'ready',
    capabilities: const AsConversationCapabilities(
      open: true,
      send: true,
      sendMedia: true,
      call: true,
    ),
  );
}

bool _isActiveConversation(AsConversation conversation) {
  final lifecycle = conversation.lifecycle.trim().toLowerCase();
  return lifecycle != 'deleted' &&
      lifecycle != 'left' &&
      lifecycle != 'dissolved';
}

bool _isExitedGroupConversation(AsConversation conversation) {
  if (!conversation.isGroup) return false;
  return _isExitedGroupStatus(conversation.lifecycle) ||
      _isExitedGroupStatus(conversation.membership) ||
      _isExitedGroupStatus(conversation.relationshipStatus) ||
      _isExitedGroupStatus(conversation.projectionState);
}

bool _isExitedGroupStatus(String? status) {
  switch (status?.trim().toLowerCase()) {
    case 'leave':
    case 'left':
    case 'ban':
    case 'banned':
    case 'kick':
    case 'kicked':
    case 'remove':
    case 'removed':
      return true;
  }
  return false;
}

AsConversation _fallbackGroupConversationForSummary(AsSyncRoomSummary group) {
  return _fallbackGroupConversation(
    roomId: group.roomId,
    title: group.name,
    avatarUrl: group.avatarUrl,
    lastActivityAt: group.lastActivityAt,
    memberCount: group.memberCount,
    role: group.role,
    membership: group.memberStatus,
  );
}

AsConversation _fallbackGroupConversation({
  required String roomId,
  String conversationId = '',
  String title = '',
  String avatarUrl = '',
  DateTime? lastActivityAt,
  int memberCount = 0,
  String role = '',
  String membership = '',
  bool canSend = true,
}) {
  final trimmedRoomId = roomId.trim();
  return AsConversation(
    conversationId: conversationId.trim(),
    roomId: trimmedRoomId,
    kind: asConversationKindGroup,
    lifecycle: 'active',
    title: title.trim().isEmpty ? trimmedRoomId : title.trim(),
    avatarUrl: avatarUrl.trim(),
    lastActivityAt: lastActivityAt,
    memberCount: memberCount,
    membership: membership.trim().isEmpty ? 'join' : membership.trim(),
    role: role.trim(),
    hydrationState: 'ready',
    capabilities: AsConversationCapabilities(
      open: true,
      send: canSend,
      sendMedia: canSend,
      call: canSend,
      invite: canSend,
    ),
  );
}

bool _isJoinedGroupSummary(AsSyncRoomSummary group, Room? room) {
  final status = group.memberStatus.trim().toLowerCase();
  if (status.isEmpty) return room?.membership == Membership.join;
  return status == asChannelMemberStatusJoined || status == 'join';
}

bool _isNativeGroupRoom(Room room) {
  final content = room.getState(nativeRoomProfileEventType)?.content;
  if (content == null) return false;
  return content['room_type'] == nativeGroupRoomType;
}

ConversationSummaryEntry summaryEntryForVisibleConversation({
  required Client client,
  required AsSyncCacheState syncCache,
  required LocalOutboxState outbox,
  required LocalMessageOrderState messageOrder,
  required Map<String, String> groupRemarkNames,
  required VisibleHomeConversation conversation,
}) {
  final room = conversation.room;
  final lastEvent = room?.lastEvent;
  final visibilityPolicy = syncCache.chatVisibilityPolicyForRoom(
    conversation.roomId,
  );
  final visibleLastEvent = lastEvent != null &&
          visibilityPolicy.allows(
            eventId: lastEvent.eventId,
            originServerTs: lastEvent.originServerTs.millisecondsSinceEpoch,
            redacted: lastEvent.redacted,
          )
      ? lastEvent
      : null;
  final failedOutbox = latestFailedMediaOutboxForConversation(
    outbox,
    conversation,
  );
  final lastEventSortTime = visibleLastEvent == null
      ? null
      : messageOrder.entryForEvent(visibleLastEvent.eventId)?.createdAt;
  final cleared = visibilityPolicy.clearedBeforeTs > 0 &&
      visibleLastEvent == null &&
      failedOutbox == null;
  final previewTime = _conversationPreviewTimeForConversation(
    conversation,
    lastEvent: visibleLastEvent,
    latestFailedOutbox: failedOutbox,
    lastEventSortTime: lastEventSortTime,
    cleared: cleared,
  );
  final lastMessage = _conversationPreviewTextForConversation(
    conversation,
    lastEvent: visibleLastEvent,
    latestFailedOutbox: failedOutbox,
    lastEventSortTime: lastEventSortTime,
    cleared: cleared,
  );
  final displayName = conversation.isAgent
      ? 'Agent'
      : conversationDisplayName(
          conversation,
          directContactDisplayName: syncCache
              .acceptedContactForRoom(conversation.roomId)
              ?.displayName,
          groupRemarkNames: groupRemarkNames,
        );
  final product = conversation.product;
  final directContact = conversation.isGroup || conversation.isAgent
      ? null
      : syncCache.acceptedContactForRoom(conversation.roomId);
  return ConversationSummaryEntry(
    conversationId: product?.conversationId ?? '',
    roomId: conversation.roomId.trim(),
    kind: product?.kind ?? '',
    name: displayName,
    lastMessage: lastMessage,
    previewTs: previewTime?.millisecondsSinceEpoch ?? 0,
    unread: _conversationHasUnreadSignal(conversation)
        ? conversationUnreadCountForSummary(conversation, room, syncCache)
        : 0,
    isGroup: conversation.isGroup,
    isAgent: conversation.isAgent,
    canOpen: product?.canOpen ?? true,
    avatarUrl: conversationAvatarUrl(
          client,
          conversation,
          room,
          directContact: directContact,
        ) ??
        '',
  );
}

bool _conversationHasUnreadSignal(VisibleHomeConversation conversation) {
  return conversation.room != null ||
      conversation.product != null ||
      conversation.roomSummary != null;
}

String? conversationAvatarUrl(
  Client client,
  VisibleHomeConversation conversation,
  Room? room, {
  AsSyncContact? directContact,
}) {
  if (conversation.isAgent) return null;
  final productAvatar = avatarHttpUrl(client, conversation.product?.avatarUrl);
  if (conversation.isGroup) {
    final roomAvatar = room == null ? null : roomAvatarHttpUrl(room);
    final resolved = productAvatar ?? roomAvatar;
    _debugAvatarResolution(
      source: 'conversation_group',
      roomId: conversation.roomId,
      productPeerMxid: conversation.product?.peerMxid,
      contactPeerMxid: directContact?.userId,
      productAvatar: conversation.product?.avatarUrl,
      contactAvatar: directContact?.avatarUrl,
      roomAvatar: roomAvatar,
      resolved: resolved,
      hasRoom: room != null,
    );
    return resolved;
  }

  final productPeerAvatar = directPeerMemberAvatarUrl(
    client,
    room,
    conversation.product?.peerMxid,
  );
  final contactPeerAvatar = directPeerMemberAvatarUrl(
    client,
    room,
    directContact?.userId,
  );
  final productPeerAvatarInRooms =
      directPeerAvatarUrlInRooms(client, conversation.product?.peerMxid);
  final contactPeerAvatarInRooms =
      directPeerAvatarUrlInRooms(client, directContact?.userId);
  final contactAvatar = avatarHttpUrl(client, directContact?.avatarUrl);
  final roomSummaryAvatar =
      avatarHttpUrl(client, conversation.roomSummary?.avatarUrl);
  final roomAvatar = room == null ? null : roomAvatarHttpUrl(room);
  final resolved = productAvatar ??
      productPeerAvatar ??
      contactPeerAvatar ??
      productPeerAvatarInRooms ??
      contactPeerAvatarInRooms ??
      contactAvatar ??
      roomSummaryAvatar ??
      roomAvatar;
  _debugAvatarResolution(
    source: 'conversation_direct',
    roomId: conversation.roomId,
    productPeerMxid: conversation.product?.peerMxid,
    contactPeerMxid: directContact?.userId,
    productAvatar: conversation.product?.avatarUrl,
    contactAvatar: directContact?.avatarUrl,
    roomAvatar: roomAvatar,
    resolved: resolved,
    hasRoom: room != null,
  );
  return resolved;
}

String? contactListAvatarUrl(Client client, AsSyncContact contact) {
  final room = client.getRoomById(contact.roomId.trim());
  final memberAvatar = directPeerMemberAvatarUrl(client, room, contact.userId);
  final roomProfileAvatar = room == null
      ? null
      : avatarHttpUrl(client, productDirectPeerAvatarUrl(room));
  final syncedRoomAvatar = directPeerAvatarUrlInRooms(client, contact.userId);
  final contactAvatar = avatarHttpUrl(client, contact.avatarUrl);
  final resolved =
      memberAvatar ?? roomProfileAvatar ?? syncedRoomAvatar ?? contactAvatar;
  _debugAvatarResolution(
    source: 'contact_list',
    roomId: contact.roomId,
    contactPeerMxid: contact.userId,
    contactAvatar: contact.avatarUrl,
    roomAvatar: roomProfileAvatar,
    resolved: resolved,
    hasRoom: room != null,
  );
  return resolved;
}

void _debugAvatarResolution({
  required String source,
  required String roomId,
  String? productPeerMxid,
  String? contactPeerMxid,
  String? productAvatar,
  String? contactAvatar,
  String? roomAvatar,
  String? resolved,
  required bool hasRoom,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[home.avatar] source=$source '
    'room=${_avatarLogValue(roomId)} '
    'has_room=$hasRoom '
    'product_peer=${_avatarLogValue(productPeerMxid)} '
    'contact_peer=${_avatarLogValue(contactPeerMxid)} '
    'product_avatar=${_avatarLogValue(productAvatar)} '
    'contact_avatar=${_avatarLogValue(contactAvatar)} '
    'room_avatar=${_avatarLogValue(roomAvatar)} '
    'resolved=${_avatarLogValue(resolved)}',
  );
}

String _avatarLogValue(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? '<empty>' : trimmed;
}

String? directPeerAvatarUrlInRooms(Client client, String? peerUserId) {
  final peerId = peerUserId?.trim() ?? '';
  if (peerId.isEmpty) return null;
  for (final room in client.rooms) {
    final avatar = directPeerMemberAvatarUrl(client, room, peerId);
    if (avatar != null) return avatar;
  }
  return null;
}

String? directPeerMemberAvatarUrl(
  Client client,
  Room? room,
  String? peerUserId,
) {
  final peerId = (peerUserId?.trim().isNotEmpty ?? false)
      ? peerUserId!.trim()
      : room == null
          ? ''
          : productDirectPeerMxid(room)?.trim() ?? '';
  if (room == null) return null;
  if (peerId.isEmpty) return _firstOtherMemberAvatarUrl(client, room);
  final memberState = room.getState(EventTypes.RoomMember, peerId);
  final memberStateAvatar = matrixContentHttpUrl(
    client,
    memberState?.asUser(room).avatarUrl,
  );
  if (memberStateAvatar != null) return memberStateAvatar;
  final member = room.unsafeGetUserFromMemoryOrFallback(peerId);
  return matrixContentHttpUrl(client, member.avatarUrl) ??
      _participantAvatarUrl(client, room, peerId) ??
      _firstOtherMemberAvatarUrl(client, room);
}

String? _firstOtherMemberAvatarUrl(Client client, Room room) {
  final self = client.userID;
  final memberStates = room.states[EventTypes.RoomMember]?.values ??
      const <StrippedStateEvent>[];
  for (final state in memberStates) {
    final mxid = state.stateKey;
    if (mxid == null || mxid.isEmpty || mxid == self) continue;
    final avatar = matrixContentHttpUrl(client, state.asUser(room).avatarUrl);
    if (avatar != null) return avatar;
  }
  for (final member in room.getParticipants()) {
    final mxid = member.id.trim();
    if (mxid.isEmpty || mxid == self) continue;
    final avatar = matrixContentHttpUrl(client, member.avatarUrl);
    if (avatar != null) return avatar;
  }
  return null;
}

String? _participantAvatarUrl(Client client, Room room, String peerId) {
  for (final member in room.getParticipants()) {
    if (member.id.trim() != peerId) continue;
    return matrixContentHttpUrl(client, member.avatarUrl);
  }
  return null;
}

LocalOutboxItem? latestFailedMediaOutboxForConversation(
  LocalOutboxState outbox,
  VisibleHomeConversation conversation,
) {
  final type = conversation.isGroup
      ? LocalOutboxConversationType.group
      : conversation.isAgent
          ? LocalOutboxConversationType.agent
          : LocalOutboxConversationType.direct;
  final items = outbox
      .itemsForConversation(conversation.roomId, type: type)
      .where(
        (item) =>
            item.status == LocalOutboxItemStatus.failed &&
            (item.messageKind == LocalOutboxMessageKind.image ||
                item.messageKind == LocalOutboxMessageKind.video ||
                item.messageKind == LocalOutboxMessageKind.file),
      )
      .toList();
  if (items.isEmpty && type != LocalOutboxConversationType.direct) {
    items.addAll(
      outbox.itemsForConversation(conversation.roomId).where(
            (item) =>
                item.status == LocalOutboxItemStatus.failed &&
                (item.messageKind == LocalOutboxMessageKind.image ||
                    item.messageKind == LocalOutboxMessageKind.video ||
                    item.messageKind == LocalOutboxMessageKind.file),
          ),
    );
  }
  if (items.isEmpty) return null;
  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items.first;
}

String conversationDisplayName(
  VisibleHomeConversation conversation, {
  String? directContactDisplayName,
  Map<String, String> groupRemarkNames = const {},
}) {
  if (conversation.isGroup) {
    final remark = groupRemarkNames[conversation.roomId]?.trim() ?? '';
    if (remark.isNotEmpty) return remark;
  }
  if (!conversation.isGroup && !conversation.isAgent) {
    final contactName = directContactDisplayName?.trim() ?? '';
    if (contactName.isNotEmpty) return contactName;
  }
  final productTitle = conversation.product?.title.trim() ?? '';
  if (productTitle.isNotEmpty) return productTitle;
  if (!conversation.isAgent) {
    final peerName = _directProductPeerDisplayName(
      conversation.product,
      conversation.room,
    );
    if (peerName.isNotEmpty) return peerName;
  }
  return conversation.room?.getLocalizedDisplayname() ?? '';
}

String _directProductPeerDisplayName(AsConversation? product, Room? room) {
  final peerMxid = product?.peerMxid.trim() ?? '';
  if (peerMxid.isEmpty) return '';
  final memberName = directPeerMemberDisplayName(room, peerMxid);
  if (memberName.isEmpty || memberName == localpartFromMxid(peerMxid)) {
    return '';
  }
  return memberName;
}

String _conversationPreviewTextForConversation(
  VisibleHomeConversation conversation, {
  required Event? lastEvent,
  required LocalOutboxItem? latestFailedOutbox,
  DateTime? lastEventSortTime,
  bool cleared = false,
}) {
  if (cleared) return '';
  final text = conversationPreviewText(
    lastEvent: lastEvent,
    latestFailedOutbox: latestFailedOutbox,
    lastEventSortTime: lastEventSortTime,
    isAgent: conversation.isAgent,
  );
  if (text.isNotEmpty) return text;
  final productLastMessage = conversation.product?.lastMessage.trim() ?? '';
  if (productLastMessage.isNotEmpty) return productLastMessage;
  if (conversation.isAgent) return defaultAgentConversationPreview;
  return '';
}

DateTime? _conversationPreviewTimeForConversation(
  VisibleHomeConversation conversation, {
  required Event? lastEvent,
  required LocalOutboxItem? latestFailedOutbox,
  DateTime? lastEventSortTime,
  bool cleared = false,
}) {
  if (cleared) return null;
  final previewTime = conversationPreviewTime(
    lastEvent: lastEvent,
    latestFailedOutbox: latestFailedOutbox,
    lastEventSortTime: lastEventSortTime,
  );
  if (previewTime != null) return previewTime;
  return conversation.product?.lastActivityAt ??
      conversation.roomSummary?.lastActivityAt;
}

bool isAgentRoom(Room room, String? agentMxid) {
  return isPortalAgentDirectRoom(room, agentMxid: agentMxid);
}

int conversationUnreadCountForSummary(
  VisibleHomeConversation conversation,
  Room? room,
  AsSyncCacheState syncCache,
) {
  final asRoomUnread = conversation.roomSummary?.unreadCount ?? 0;
  if (asRoomUnread > 0) return asRoomUnread;

  final matrixUnread = conversationUnreadCount(
    matrixUnreadCount: room?.notificationCount ?? 0,
  );
  if (matrixUnread > 0) return matrixUnread;

  if (room != null &&
      isChannelShareEvent(room.lastEvent) &&
      _lastEventIsUnreadForCurrentUser(room)) {
    return 1;
  }

  return 0;
}

bool _lastEventIsUnreadForCurrentUser(Room room) {
  final lastEvent = room.lastEvent;
  if (lastEvent == null) return false;
  if (lastEvent.senderId == room.client.userID) return false;
  final readAtMs = room.receiptState.global.latestOwnReceipt?.ts ?? 0;
  return readAtMs < lastEvent.originServerTs.millisecondsSinceEpoch;
}

int conversationSortTime(
  VisibleHomeConversation conversation, {
  required LocalOutboxState outbox,
  required LocalMessageOrderState messageOrder,
}) {
  final lastEvent = conversation.room?.lastEvent;
  final failedOutbox =
      latestFailedMediaOutboxForConversation(outbox, conversation);
  final lastEventSortTime = lastEvent == null
      ? null
      : messageOrder.entryForEvent(lastEvent.eventId)?.createdAt;
  return _conversationPreviewTimeForConversation(
        conversation,
        lastEvent: lastEvent,
        latestFailedOutbox: failedOutbox,
        lastEventSortTime: lastEventSortTime,
      )?.millisecondsSinceEpoch ??
      0;
}

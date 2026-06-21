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
  final productConversationsByRoomId = {
    for (final conversation in productList)
      if (conversation.roomId.trim().isNotEmpty)
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
    if (!conversation.canOpen) continue;
    final roomId = conversation.roomId.trim();
    addVisibleConversation(
      VisibleHomeConversation.product(
        conversation,
        client.getRoomById(roomId),
        asRoomSummariesByRoomId[roomId],
      ),
    );
  }

  return visibleConversations
    ..sort((a, b) {
      final aPinned = pinnedConversationIds.contains(a.roomId);
      final bPinned = pinnedConversationIds.contains(b.roomId);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      if (a.isAgent != b.isAgent) return a.isAgent ? -1 : 1;
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
          groupRemarkNames: groupRemarkNames,
        );
  final product = conversation.product;
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
    avatarUrl: conversationAvatarUrl(client, conversation, room) ?? '',
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
  Room? room,
) {
  if (conversation.isAgent) return null;
  final productAvatar = avatarHttpUrl(client, conversation.product?.avatarUrl);
  if (conversation.isGroup) {
    return productAvatar ?? (room == null ? null : roomAvatarHttpUrl(room));
  }

  return productAvatar ??
      directPeerMemberAvatarUrl(
        client,
        room,
        conversation.product?.peerMxid,
      ) ??
      avatarHttpUrl(client, conversation.roomSummary?.avatarUrl) ??
      (room == null ? null : roomAvatarHttpUrl(room));
}

String? contactListAvatarUrl(Client client, AsSyncContact contact) {
  final room = client.getRoomById(contact.roomId.trim());
  return directPeerMemberAvatarUrl(client, room, contact.userId) ??
      avatarHttpUrl(client, contact.avatarUrl);
}

String? directPeerMemberAvatarUrl(
  Client client,
  Room? room,
  String? peerUserId,
) {
  final peerId = peerUserId?.trim() ?? '';
  if (room == null || peerId.isEmpty) return null;
  final member = room.unsafeGetUserFromMemoryOrFallback(peerId);
  return matrixContentHttpUrl(client, member.avatarUrl);
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
  Map<String, String> groupRemarkNames = const {},
}) {
  if (conversation.isGroup) {
    final remark = groupRemarkNames[conversation.roomId]?.trim() ?? '';
    if (remark.isNotEmpty) return remark;
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

  return 0;
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

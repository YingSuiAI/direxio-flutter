import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/conversation_summary_store.dart';
import 'package:portal_app/presentation/home/conversation_summary_writer.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/local_message_order_provider.dart';
import 'package:portal_app/presentation/providers/local_outbox_provider.dart';
import 'package:portal_app/presentation/utils/direct_contact_status.dart';
import 'package:portal_app/presentation/utils/product_conversation_navigation.dart';

void main() {
  test('builds visible ProductCore conversations for summary writing', () {
    final client = Client('ConversationSummaryWriterTest')
      ..setUserId('@owner:p2p-im.com');
    final visible = visibleHomeConversationsForSummary(
      client: client,
      rooms: const [],
      productConversations: [
        _conversation(
          id: 'conv_recent',
          roomId: '!recent:p2p-im.com',
          kind: asConversationKindDirect,
          canOpen: true,
          lastActivityAt: DateTime.utc(2026, 6, 22, 10),
        ),
        _conversation(
          id: 'conv_old',
          roomId: '!old:p2p-im.com',
          kind: asConversationKindGroup,
          canOpen: true,
          lastActivityAt: DateTime.utc(2026, 6, 22, 9),
        ),
        _conversation(
          id: 'conv_closed',
          roomId: '!closed:p2p-im.com',
          kind: asConversationKindDirect,
          canOpen: false,
          lastActivityAt: DateTime.utc(2026, 6, 22, 11),
        ),
        _conversation(
          id: 'conv_channel',
          roomId: '!channel:p2p-im.com',
          kind: asConversationKindChannel,
          canOpen: true,
          lastActivityAt: DateTime.utc(2026, 6, 22, 12),
        ),
      ],
      syncCache: const AsSyncCacheState(),
      outbox: const LocalOutboxState(),
      messageOrder: const LocalMessageOrderState(),
      pinnedConversationIds: const {},
    );

    expect(
      visible.map((conversation) => conversation.roomId),
      ['!recent:p2p-im.com', '!old:p2p-im.com'],
    );
  });

  test('pinned ProductCore conversations sort before newer conversations', () {
    final client = Client('ConversationSummaryWriterPinnedTest')
      ..setUserId('@owner:p2p-im.com');

    final visible = visibleHomeConversationsForSummary(
      client: client,
      rooms: const [],
      productConversations: [
        _conversation(
          id: 'conv_recent',
          roomId: '!recent:p2p-im.com',
          kind: asConversationKindDirect,
          canOpen: true,
          lastActivityAt: DateTime.utc(2026, 6, 22, 10),
        ),
        _conversation(
          id: 'conv_pinned',
          roomId: '!pinned:p2p-im.com',
          kind: asConversationKindGroup,
          canOpen: true,
          lastActivityAt: DateTime.utc(2026, 6, 22, 8),
        ),
      ],
      syncCache: const AsSyncCacheState(),
      outbox: const LocalOutboxState(),
      messageOrder: const LocalMessageOrderState(),
      pinnedConversationIds: const {'!pinned:p2p-im.com'},
    );

    expect(
      visible.map((conversation) => conversation.roomId),
      ['!pinned:p2p-im.com', '!recent:p2p-im.com'],
    );
  });

  test('Agent ProductCore conversations sort before pinned conversations', () {
    final client = Client('ConversationSummaryWriterAgentFirstTest')
      ..setUserId('@owner:p2p-im.com');

    final visible = visibleHomeConversationsForSummary(
      client: client,
      rooms: const [],
      productConversations: [
        _conversation(
          id: 'conv_recent',
          roomId: '!recent:p2p-im.com',
          kind: asConversationKindDirect,
          canOpen: true,
          lastActivityAt: DateTime.utc(2026, 6, 22, 10),
        ),
        _conversation(
          id: 'conv_pinned',
          roomId: '!pinned:p2p-im.com',
          kind: asConversationKindGroup,
          canOpen: true,
          lastActivityAt: DateTime.utc(2026, 6, 22, 11),
        ),
        _conversation(
          id: 'conv_agent',
          roomId: '!agent:p2p-im.com',
          kind: asConversationKindAgent,
          canOpen: true,
          lastActivityAt: DateTime.utc(2026, 6, 22, 8),
        ),
      ],
      syncCache: const AsSyncCacheState(),
      outbox: const LocalOutboxState(),
      messageOrder: const LocalMessageOrderState(),
      pinnedConversationIds: const {'!pinned:p2p-im.com'},
    );

    expect(
      visible.map((conversation) => conversation.roomId),
      ['!agent:p2p-im.com', '!pinned:p2p-im.com', '!recent:p2p-im.com'],
    );
  });

  test('includes joined native group rooms before ProductCore sync catches up',
      () {
    final client = Client('ConversationSummaryWriterNativeGroupTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: '!new-group:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    room.setState(
      StrippedStateEvent(
        type: nativeRoomProfileEventType,
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: const {
          'room_type': nativeGroupRoomType,
          'name': '新的群聊',
        },
      ),
    );

    final visible = visibleHomeConversationsForSummary(
      client: client,
      rooms: [room],
      productConversations: const [],
      syncCache: const AsSyncCacheState(),
      outbox: const LocalOutboxState(),
      messageOrder: const LocalMessageOrderState(),
      pinnedConversationIds: const {},
    );

    expect(visible.map((conversation) => conversation.roomId), [
      '!new-group:p2p-im.com',
    ]);
    expect(visible.single.isGroup, isTrue);
    expect(visible.single.product?.canOpen, isTrue);
  });

  test('builds home summary from bootstrap groups before conversation sync',
      () {
    final client = Client('ConversationSummaryWriterBootstrapGroupTest')
      ..setUserId('@owner:p2p-im.com');
    const roomId = '!bootstrap-group:p2p-im.com';
    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: const [],
      productConversations: const [],
      productConversationsLoaded: true,
      syncCache: AsSyncCacheState(
        bootstrap: AsSyncBootstrap(
          syncedAt: DateTime.utc(2026, 6, 22, 12),
          user: const AsSyncUser(userId: '@owner:p2p-im.com'),
          rooms: const [],
          contacts: const [],
          groups: const [
            AsSyncRoomSummary(
              roomId: roomId,
              name: '对方创建的群',
              avatarUrl: '',
              unreadCount: 3,
              lastActivityAt: null,
              memberStatus: asChannelMemberStatusJoined,
            ),
          ],
          channels: const [],
          pending: const AsSyncPending.empty(),
        ),
      ),
      summaryState: const ConversationSummaryState(
        loaded: true,
        userId: '@owner:p2p-im.com',
        entries: [],
      ),
      hiddenConversationIds: const {},
      pinnedConversationIds: const {},
      outbox: const LocalOutboxState(),
      messageOrder: const LocalMessageOrderState(),
      groupRemarkNames: const {},
      currentUserId: '@owner:p2p-im.com',
    );

    expect(result.storeEntries.map((entry) => entry.roomId), [roomId]);
    expect(result.storeEntries.single.name, '对方创建的群');
    expect(result.storeEntries.single.isGroup, isTrue);
    expect(result.storeEntries.single.canOpen, isTrue);
    expect(result.productConversationsByRoomId[roomId]?.canOpen, isTrue);
  });

  test('builds openable fallback conversation for Agent rooms', () {
    final client = Client('ConversationSummaryWriterAgentFallbackTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: '!agent:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    room.summary.mHeroes = ['@agent:p2p-im.com'];
    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: [room],
      productConversations: const [],
      productConversationsLoaded: true,
      syncCache: AsSyncCacheState(
        bootstrap: AsSyncBootstrap(
          syncedAt: DateTime.utc(2026, 6, 22, 12),
          user: const AsSyncUser(userId: '@owner:p2p-im.com'),
          agentRoomId: '!agent:p2p-im.com',
          rooms: const [],
          contacts: const [],
          groups: const [],
          channels: const [],
          pending: const AsSyncPending.empty(),
        ),
      ),
      summaryState: const ConversationSummaryState(
        loaded: true,
        userId: '@owner:p2p-im.com',
        entries: [],
      ),
      hiddenConversationIds: const {},
      pinnedConversationIds: const {},
      outbox: const LocalOutboxState(),
      messageOrder: const LocalMessageOrderState(),
      groupRemarkNames: const {},
      currentUserId: '@owner:p2p-im.com',
    );

    final conversation =
        result.productConversationsByRoomId['!agent:p2p-im.com'];
    expect(result.storeEntries.single.isAgent, isTrue);
    expect(conversation?.isAgent, isTrue);
    expect(conversation?.canOpen, isTrue);
    expect(productConversationRoute(conversation), '/chat/!agent%3Ap2p-im.com');
  });

  test('builds home summary projection from ProductCore live inputs', () {
    final client = Client('ConversationSummaryWriterProjectionTest')
      ..setUserId('@owner:p2p-im.com');

    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: const [],
      productConversations: [
        _conversation(
          id: 'conv_recent',
          roomId: '!recent:p2p-im.com',
          kind: asConversationKindDirect,
          canOpen: true,
          lastActivityAt: DateTime.utc(2026, 6, 22, 10),
        ),
      ],
      productConversationsLoaded: true,
      syncCache: const AsSyncCacheState(),
      summaryState: const ConversationSummaryState(
        loaded: true,
        userId: '@owner:p2p-im.com',
        entries: [],
      ),
      hiddenConversationIds: const {},
      pinnedConversationIds: const {},
      outbox: const LocalOutboxState(),
      messageOrder: const LocalMessageOrderState(),
      groupRemarkNames: const {},
      currentUserId: '@owner:p2p-im.com',
    );

    expect(
      result.displayEntries.map((entry) => entry.roomId),
      ['!recent:p2p-im.com'],
    );
    expect(
      result.storeEntries.map((entry) => entry.roomId),
      ['!recent:p2p-im.com'],
    );
    expect(
      result.productConversationsByRoomId.keys,
      ['!recent:p2p-im.com'],
    );
    expect(result.shouldWriteStore, isTrue);
  });

  test('builds home summary projection that clears stale cached rows', () {
    final client = Client('ConversationSummaryWriterClearCacheTest')
      ..setUserId('@owner:p2p-im.com');
    const cached = ConversationSummaryEntry(
      conversationId: 'conv_stale',
      roomId: '!stale:p2p-im.com',
      kind: 'direct',
      name: 'Stale',
      lastMessage: 'old preview',
      previewTs: 1,
      unread: 0,
      isGroup: false,
      isAgent: false,
    );

    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: const [],
      productConversations: const [],
      productConversationsLoaded: true,
      syncCache: const AsSyncCacheState(),
      summaryState: ConversationSummaryState.fromSnapshot(
        ConversationSummarySnapshot(
          userId: '@owner:p2p-im.com',
          updatedAt: DateTime.utc(2026, 6, 22, 12),
          entries: const [cached],
        ),
      ),
      hiddenConversationIds: const {},
      pinnedConversationIds: const {},
      outbox: const LocalOutboxState(),
      messageOrder: const LocalMessageOrderState(),
      groupRemarkNames: const {},
      currentUserId: '@owner:p2p-im.com',
    );

    expect(result.displayEntries, isEmpty);
    expect(result.storeEntries, isEmpty);
    expect(result.productConversationsByRoomId, isEmpty);
    expect(result.shouldWriteStore, isTrue);
  });
}

AsConversation _conversation({
  required String id,
  required String roomId,
  required String kind,
  required bool canOpen,
  required DateTime lastActivityAt,
}) {
  return AsConversation(
    conversationId: id,
    roomId: roomId,
    kind: kind,
    lifecycle: 'active',
    title: id,
    avatarUrl: '',
    lastActivityAt: lastActivityAt,
    capabilities: AsConversationCapabilities(open: canOpen),
  );
}

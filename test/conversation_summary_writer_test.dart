import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/conversation_summary_store.dart';
import 'package:portal_app/presentation/home/conversation_summary_writer.dart';
import 'package:portal_app/presentation/utils/message_preview.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/local_message_order_provider.dart';
import 'package:portal_app/presentation/providers/local_outbox_provider.dart';
import 'package:portal_app/presentation/chat/chat_record_forwarding.dart';
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

  test('excludes channel conversations from home summaries', () {
    final client = Client('ConversationSummaryWriterChannelUnreadTest')
      ..setUserId('@owner:p2p-im.com');
    const roomId = '!channel:p2p-im.com';
    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: const [],
      productConversations: [
        _conversation(
          id: 'ch_updates',
          roomId: roomId,
          kind: asConversationKindChannel,
          canOpen: true,
          lastActivityAt: DateTime.utc(2026, 6, 24, 10),
        ),
      ],
      productConversationsLoaded: true,
      syncCache: AsSyncCacheState(
        bootstrap: AsSyncBootstrap(
          syncedAt: DateTime.utc(2026, 6, 24, 9),
          user: const AsSyncUser(userId: '@owner:p2p-im.com'),
          rooms: const [],
          contacts: const [],
          groups: const [],
          channels: const [
            AsSyncRoomSummary(
              channelId: 'ch_updates',
              roomId: roomId,
              name: '产品更新',
              avatarUrl: '',
              unreadCount: 7,
              lastActivityAt: null,
              memberStatus: asChannelMemberStatusJoined,
              channelType: asChannelTypeChat,
            ),
          ],
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

    expect(result.displayEntries, isEmpty);
    expect(result.storeEntries, isEmpty);
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
          roomId: '!agent-room:p2p-im.com',
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
      ['!agent-room:p2p-im.com', '!pinned:p2p-im.com', '!recent:p2p-im.com'],
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

  test('direct contact remark overrides ProductCore conversation title', () {
    final client = Client('ConversationSummaryWriterDirectRemarkTest')
      ..setUserId('@owner:p2p-im.com');
    const roomId = '!direct:p2p-im.com';
    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: const [],
      productConversations: [
        AsConversation(
          conversationId: 'conv_direct',
          roomId: roomId,
          kind: asConversationKindDirect,
          lifecycle: 'active',
          title: 'Product Alice',
          avatarUrl: '',
          peerMxid: '@alice:p2p-im.com',
          lastActivityAt: DateTime.utc(2026, 6, 22, 13),
          capabilities: const AsConversationCapabilities(open: true),
        ),
      ],
      productConversationsLoaded: true,
      syncCache: AsSyncCacheState(
        bootstrap: AsSyncBootstrap(
          syncedAt: DateTime.utc(2026, 6, 22, 12),
          user: const AsSyncUser(userId: '@owner:p2p-im.com'),
          rooms: const [],
          contacts: const [
            AsSyncContact(
              userId: '@alice:p2p-im.com',
              displayName: '备注 Alice',
              avatarUrl: '',
              roomId: roomId,
              domain: 'p2p-im.com',
              status: 'accepted',
            ),
          ],
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

    expect(result.storeEntries.single.name, '备注 Alice');
  });

  test('builds openable fallback conversation for Agent rooms', () {
    final client = Client('ConversationSummaryWriterAgentFallbackTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: '!agent-room:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    room.summary.mHeroes = ['@agent:p2p-im.com'];
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@agent:p2p-im.com',
        stateKey: '@agent:p2p-im.com',
        content: const {
          'membership': 'join',
          'displayname': 'Direxio AI',
        },
      ),
    );
    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: [room],
      productConversations: const [],
      productConversationsLoaded: true,
      syncCache: AsSyncCacheState(
        bootstrap: AsSyncBootstrap(
          syncedAt: DateTime.utc(2026, 6, 22, 12),
          user: const AsSyncUser(userId: '@owner:p2p-im.com'),
          agentRoomId: '!agent-room:p2p-im.com',
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
        result.productConversationsByRoomId['!agent-room:p2p-im.com'];
    expect(result.storeEntries.single.isAgent, isTrue);
    expect(result.storeEntries.single.name, 'Direxio AI');
    expect(conversation?.isAgent, isTrue);
    expect(conversation?.title, 'Direxio AI');
    expect(conversation?.canOpen, isTrue);
    expect(
      productConversationRoute(conversation),
      '/chat/!agent-room%3Ap2p-im.com',
    );
  });

  test('builds default Agent conversation from bootstrap before room hydrates',
      () {
    final client = Client('ConversationSummaryWriterBootstrapAgentTest')
      ..setUserId('@owner:p2p-im.com');

    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: const [],
      productConversations: const [],
      productConversationsLoaded: true,
      syncCache: AsSyncCacheState(
        bootstrap: AsSyncBootstrap(
          syncedAt: DateTime.utc(2026, 6, 23, 12),
          user: const AsSyncUser(userId: '@owner:p2p-im.com'),
          agentRoomId: '!agent-room:p2p-im.com',
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

    final entry = result.displayEntries.single;
    final conversation =
        result.productConversationsByRoomId['!agent-room:p2p-im.com'];
    expect(entry.name, 'Agent');
    expect(entry.isAgent, isTrue);
    expect(entry.lastMessage, defaultAgentConversationPreview);
    expect(conversation?.isAgent, isTrue);
    expect(conversation?.canOpen, isTrue);
    expect(
      productConversationRoute(conversation),
      '/chat/!agent-room%3Ap2p-im.com',
    );
  });

  test('does not build legacy Agent pseudo room without synced agent room', () {
    final client = Client('ConversationSummaryWriterFallbackAgentTest')
      ..setUserId('@owner:p2p-im.com');

    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: const [],
      productConversations: const [],
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
      includeDefaultAgentConversation: true,
    );

    expect(result.displayEntries, isEmpty);
    expect(
      result.productConversationsByRoomId.containsKey('!agent:p2p-im.com'),
      isFalse,
    );
  });

  test('does not duplicate fallback Agent when ProductCore Agent exists', () {
    final client = Client('ConversationSummaryWriterSingleAgentFallbackTest')
      ..setUserId('@owner:p2p-im.com');

    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: const [],
      productConversations: [
        AsConversation(
          conversationId: 'conv_agent',
          roomId: '!agent-product:p2p-im.com',
          kind: asConversationKindAgent,
          lifecycle: 'active',
          title: 'Agent',
          avatarUrl: '',
          lastActivityAt: DateTime.utc(2026, 6, 23, 12),
          capabilities: const AsConversationCapabilities(open: true),
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
      includeDefaultAgentConversation: true,
    );

    expect(result.displayEntries, hasLength(1));
    expect(result.displayEntries.single.roomId, '!agent-product:p2p-im.com');
    expect(result.displayEntries.single.isAgent, isTrue);
    expect(
      result.productConversationsByRoomId.containsKey('!agent:p2p-im.com'),
      isFalse,
    );
  });

  test('uses bootstrap agent room id over stale ProductCore agent room', () {
    final client = Client('ConversationSummaryWriterCanonicalAgentTest')
      ..setUserId('@owner:p2p-im.com');

    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: const [],
      productConversations: [
        AsConversation(
          conversationId: 'conv_agent',
          roomId: '!agent-old:p2p-im.com',
          kind: asConversationKindAgent,
          lifecycle: 'active',
          title: 'Agent',
          avatarUrl: '',
          lastActivityAt: DateTime.utc(2026, 6, 23, 12),
          capabilities: const AsConversationCapabilities(open: true),
        ),
      ],
      productConversationsLoaded: true,
      syncCache: AsSyncCacheState(
        bootstrap: AsSyncBootstrap(
          syncedAt: DateTime.utc(2026, 6, 23, 12),
          user: const AsSyncUser(userId: '@owner:p2p-im.com'),
          agentRoomId: '!agent-new:p2p-im.com',
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

    expect(result.displayEntries, hasLength(1));
    expect(result.displayEntries.single.roomId, '!agent-new:p2p-im.com');
    final conversation =
        result.productConversationsByRoomId['!agent-new:p2p-im.com'];
    expect(conversation?.conversationId, 'conv_agent');
    expect(
      productConversationRoute(conversation),
      '/chat/!agent-new%3Ap2p-im.com?conversation=conv_agent',
    );
    expect(result.productConversationsByRoomId['!agent-old:p2p-im.com'],
        isNot(isA<AsConversation>()));
  });

  test('uses Matrix peer member avatar when ProductCore avatar is missing', () {
    final client = Client('ConversationSummaryWriterPeerAvatarTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(
      id: '!direct:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@owner:p2p-im.com',
        stateKey: '@owner:p2p-im.com',
        content: const {'membership': 'join'},
      ),
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@alice:p2p-im.com',
        stateKey: '@alice:p2p-im.com',
        content: const {
          'membership': 'join',
          'avatar_url': 'mxc://p2p-im.com/alice-avatar',
        },
      ),
    );

    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: [room],
      productConversations: [
        const AsConversation(
          conversationId: 'conv_direct',
          roomId: '!direct:p2p-im.com',
          kind: asConversationKindDirect,
          lifecycle: 'active',
          title: 'Alice',
          avatarUrl: '',
          capabilities: AsConversationCapabilities(open: true),
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

    final avatarUrl = result.displayEntries.single.avatarUrl;
    expect(avatarUrl, contains('/download/p2p-im.com/alice-avatar'));
  });

  test('uses synced Matrix room avatar when contact room id is stale', () {
    final client = Client('ConversationSummaryWriterContactAvatarFallbackTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(
      id: '!actual-direct:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@alice:p2p-im.com',
        stateKey: '@alice:p2p-im.com',
        content: const {
          'membership': 'join',
          'avatar_url': 'mxc://p2p-im.com/alice-contact-avatar',
        },
      ),
    );

    final avatarUrl = contactListAvatarUrl(
      client,
      const AsSyncContact(
        userId: '@alice:p2p-im.com',
        displayName: 'Alice',
        avatarUrl: '',
        roomId: '!stale-direct:p2p-im.com',
        domain: 'p2p-im.com',
        status: 'accepted',
      ),
    );

    expect(avatarUrl, contains('/download/p2p-im.com/alice-contact-avatar'));
  });

  test('uses peer avatar from synced Matrix rooms for product-only row', () {
    final client = Client('ConversationSummaryWriterProductAvatarFallbackTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(
      id: '!actual-direct:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@alice:p2p-im.com',
        stateKey: '@alice:p2p-im.com',
        content: const {
          'membership': 'join',
          'avatar_url': 'mxc://p2p-im.com/alice-product-avatar',
        },
      ),
    );

    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: [room],
      productConversations: const [
        AsConversation(
          conversationId: 'conv_direct',
          roomId: '!product-direct:p2p-im.com',
          kind: asConversationKindDirect,
          lifecycle: 'active',
          peerMxid: '@alice:p2p-im.com',
          title: 'Alice',
          avatarUrl: '',
          capabilities: AsConversationCapabilities(open: true),
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

    final avatarUrl = result.displayEntries.single.avatarUrl;
    expect(avatarUrl, contains('/download/p2p-im.com/alice-product-avatar'));
  });

  test('uses accepted contact avatar when product row has no peer avatar', () {
    final client = Client('ConversationSummaryWriterContactAvatarTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');

    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: 'mxc://p2p-im.com/alice-bootstrap-avatar',
          roomId: '!direct:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: const [],
      productConversations: const [
        AsConversation(
          conversationId: 'conv_direct',
          roomId: '!direct:p2p-im.com',
          kind: asConversationKindDirect,
          lifecycle: 'active',
          title: 'Alice',
          avatarUrl: '',
          capabilities: AsConversationCapabilities(open: true),
        ),
      ],
      productConversationsLoaded: true,
      syncCache: const AsSyncCacheState().copyWith(bootstrap: bootstrap),
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

    final avatarUrl = result.displayEntries.single.avatarUrl;
    expect(avatarUrl, contains('/download/p2p-im.com/alice-bootstrap-avatar'));
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

  test('counts unread channel share cards even without Matrix notification',
      () {
    final client = Client('ConversationSummaryWriterChannelShareUnreadTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: '!direct:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    room.lastEvent = Event(
      room: room,
      eventId: r'$channel-share',
      senderId: '@alice:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 23, 10),
      content: {
        'msgtype': MessageTypes.Text,
        'body': '频道分享\n产品公告',
        chatRecordMatrixMarkerKey: 'channel_share',
      },
    );

    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: [room],
      productConversations: [
        _conversation(
          id: 'conv_direct',
          roomId: '!direct:p2p-im.com',
          kind: asConversationKindDirect,
          canOpen: true,
          lastActivityAt: DateTime.utc(2026, 6, 23, 10),
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

    expect(result.displayEntries.single.unread, 1);
  });

  test('counts unread visible chat messages without Matrix notification', () {
    final cases = <String, Map<String, Object?>>{
      'text': {
        'msgtype': MessageTypes.Text,
        'body': 'hello',
      },
      'image': {
        'msgtype': MessageTypes.Image,
        'body': 'photo.jpg',
      },
      'video': {
        'msgtype': MessageTypes.Video,
        'body': 'video.mp4',
      },
      'audio': {
        'msgtype': MessageTypes.Audio,
        'body': 'voice.m4a',
      },
      'file': {
        'msgtype': MessageTypes.File,
        'body': 'report.pdf',
      },
      'product card': {
        'msgtype': MessageTypes.Text,
        'body': '群邀请',
        chatRecordMatrixMarkerKey: 'p2p.group.invite.v1',
      },
    };

    for (final entry in cases.entries) {
      final result = _summaryForLastEventContent(
        clientName: 'ConversationSummaryWriterUnread${entry.key}Test',
        eventId: '\$${entry.key.replaceAll(' ', '-')}',
        senderId: '@alice:p2p-im.com',
        content: entry.value,
      );

      expect(
        result.displayEntries.single.unread,
        1,
        reason: entry.key,
      );
    }
  });

  test('does not count visible chat fallback unread for own or read messages',
      () {
    final ownMessage = _summaryForLastEventContent(
      clientName: 'ConversationSummaryWriterOwnUnreadTest',
      eventId: r'$own-file',
      senderId: '@owner:p2p-im.com',
      content: const {
        'msgtype': MessageTypes.File,
        'body': 'mine.pdf',
      },
    );
    expect(ownMessage.displayEntries.single.unread, 0);

    final readMessage = _summaryForLastEventContent(
      clientName: 'ConversationSummaryWriterReadUnreadTest',
      eventId: r'$read-file',
      senderId: '@alice:p2p-im.com',
      content: const {
        'msgtype': MessageTypes.File,
        'body': 'read.pdf',
      },
      ownReadAt: DateTime.utc(2026, 6, 23, 10, 0, 1),
    );
    expect(readMessage.displayEntries.single.unread, 0);
  });

  test('shows accepted direct share card before ProductCore conversation sync',
      () {
    final client = Client('ConversationSummaryWriterAcceptedShareFallbackTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: '!direct:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    room.lastEvent = Event(
      room: room,
      eventId: r'$channel-share',
      senderId: '@alice:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 23, 10),
      content: {
        'msgtype': MessageTypes.Text,
        'body': '频道分享\n产品公告',
        chatRecordMatrixMarkerKey: 'channel_share',
      },
    );

    final result = buildHomeConversationSummaryProjection(
      client: client,
      rooms: [room],
      productConversations: const [],
      productConversationsLoaded: true,
      syncCache: AsSyncCacheState(
        bootstrap: AsSyncBootstrap(
          syncedAt: DateTime.utc(2026, 6, 23, 9),
          user: const AsSyncUser(userId: '@owner:p2p-im.com'),
          rooms: const [],
          contacts: const [
            AsSyncContact(
              userId: '@alice:p2p-im.com',
              displayName: 'Alice',
              avatarUrl: '',
              roomId: '!direct:p2p-im.com',
              domain: 'p2p-im.com',
              status: 'accepted',
            ),
          ],
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

    expect(result.displayEntries.map((entry) => entry.roomId), [
      '!direct:p2p-im.com',
    ]);
    expect(result.displayEntries.single.unread, 1);
    expect(result.displayEntries.single.name, 'Alice');
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

HomeConversationSummaryResult _summaryForLastEventContent({
  required String clientName,
  required String eventId,
  required String senderId,
  required Map<String, Object?> content,
  DateTime? ownReadAt,
}) {
  final client = Client(clientName)..setUserId('@owner:p2p-im.com');
  final room = Room(
    id: '!direct:p2p-im.com',
    client: client,
    membership: Membership.join,
  );
  client.rooms.add(room);
  final eventAt = DateTime.utc(2026, 6, 23, 10);
  room.lastEvent = Event(
    room: room,
    eventId: eventId,
    senderId: senderId,
    type: EventTypes.Message,
    originServerTs: eventAt,
    content: content,
  );
  if (ownReadAt != null) {
    room.roomAccountData[LatestReceiptState.eventType] = BasicRoomEvent(
      type: LatestReceiptState.eventType,
      roomId: room.id,
      content: {
        'global': {
          'latest': {
            'e': eventId,
            'ts': ownReadAt.millisecondsSinceEpoch,
          },
          'others': <String, Object?>{},
        },
      },
    );
  }

  return buildHomeConversationSummaryProjection(
    client: client,
    rooms: [room],
    productConversations: [
      _conversation(
        id: 'conv_direct',
        roomId: '!direct:p2p-im.com',
        kind: asConversationKindDirect,
        canOpen: true,
        lastActivityAt: eventAt,
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
}

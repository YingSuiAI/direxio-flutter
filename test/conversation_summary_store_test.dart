import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/conversation_summary_store.dart';

void main() {
  test('filters cached summaries by user, signal, and hidden rooms', () {
    final snapshot = ConversationSummarySnapshot(
      userId: '@owner:p2p-im.com',
      updatedAt: DateTime.utc(2026, 6, 22),
      entries: [
        const ConversationSummaryEntry(
          roomId: '!blank:p2p-im.com',
          name: 'Blank',
          lastMessage: '',
          previewTs: 0,
          unread: 0,
          isGroup: false,
          isAgent: false,
        ),
        const ConversationSummaryEntry(
          roomId: '!hidden:p2p-im.com',
          name: 'Hidden',
          lastMessage: 'hidden',
          previewTs: 20,
          unread: 0,
          isGroup: false,
          isAgent: false,
        ),
        const ConversationSummaryEntry(
          roomId: '!visible:p2p-im.com',
          name: 'Visible',
          lastMessage: 'hello',
          previewTs: 10,
          unread: 0,
          isGroup: false,
          isAgent: false,
        ),
      ],
    );

    final entries = conversationSummaryEntriesForUser(
      snapshot,
      userId: '@owner:p2p-im.com',
      hiddenConversationIds: {'!hidden:p2p-im.com'},
      pinnedConversationIds: const {},
    );

    expect(entries.map((entry) => entry.roomId), ['!visible:p2p-im.com']);
  });

  test('merges live summaries over cached summaries without stale rows', () {
    final cached = [
      const ConversationSummaryEntry(
        roomId: '!a:p2p-im.com',
        name: 'Old A',
        lastMessage: 'old message',
        previewTs: 10,
        unread: 1,
        isGroup: false,
        isAgent: false,
      ),
      const ConversationSummaryEntry(
        roomId: '!stale:p2p-im.com',
        name: 'Stale',
        lastMessage: 'stale',
        previewTs: 99,
        unread: 2,
        isGroup: false,
        isAgent: false,
      ),
    ];
    final live = [
      const ConversationSummaryEntry(
        conversationId: 'conv_a',
        roomId: '!a:p2p-im.com',
        kind: 'direct',
        name: 'Live A',
        lastMessage: '',
        previewTs: 20,
        unread: 3,
        isGroup: false,
        isAgent: false,
        canOpen: true,
      ),
    ];

    final entries = mergeConversationSummaryEntries(
      cachedEntries: cached,
      liveEntries: live,
      includeCachedOnlyEntries: false,
      pinnedConversationIds: const {},
    );

    expect(entries.map((entry) => entry.roomId), ['!a:p2p-im.com']);
    expect(entries.single.conversationId, 'conv_a');
    expect(entries.single.kind, 'direct');
    expect(entries.single.name, 'Live A');
    expect(entries.single.lastMessage, 'old message');
    expect(entries.single.previewTs, 20);
    expect(entries.single.unread, 3);
  });

  test('keeps open ProductCore conversations without message previews', () {
    final snapshot = ConversationSummarySnapshot(
      userId: '@owner:p2p-im.com',
      updatedAt: DateTime.utc(2026, 6, 22),
      entries: const [
        ConversationSummaryEntry(
          conversationId: 'conv_empty_group',
          roomId: '!empty-group:p2p-im.com',
          kind: 'group',
          name: 'Empty Group',
          lastMessage: '',
          previewTs: 0,
          unread: 0,
          isGroup: true,
          isAgent: false,
          canOpen: true,
        ),
      ],
    );

    final entries = conversationSummaryEntriesForUser(
      snapshot,
      userId: '@owner:p2p-im.com',
      hiddenConversationIds: const {},
      pinnedConversationIds: const {},
    );

    expect(entries.map((entry) => entry.roomId), ['!empty-group:p2p-im.com']);
  });

  test('sorts agent summaries before pinned and recent normal summaries', () {
    final entries = mergeConversationSummaryEntries(
      cachedEntries: const [],
      liveEntries: const [
        ConversationSummaryEntry(
          roomId: '!normal:p2p-im.com',
          name: 'Normal',
          lastMessage: 'normal',
          previewTs: 300,
          unread: 0,
          isGroup: false,
          isAgent: false,
        ),
        ConversationSummaryEntry(
          roomId: '!agent:p2p-im.com',
          name: 'Agent',
          lastMessage: 'agent',
          previewTs: 100,
          unread: 0,
          isGroup: false,
          isAgent: true,
        ),
        ConversationSummaryEntry(
          roomId: '!pinned:p2p-im.com',
          name: 'Pinned',
          lastMessage: 'pinned',
          previewTs: 1,
          unread: 0,
          isGroup: false,
          isAgent: false,
        ),
      ],
      includeCachedOnlyEntries: false,
      pinnedConversationIds: const {'!pinned:p2p-im.com'},
    );

    expect(
      entries.map((entry) => entry.roomId),
      ['!agent:p2p-im.com', '!pinned:p2p-im.com', '!normal:p2p-im.com'],
    );
  });

  test('upserts ProductCore mutation conversation into summaries', () {
    final previous = [
      const ConversationSummaryEntry(
        conversationId: 'conv_direct',
        roomId: '!direct:p2p-im.com',
        kind: 'direct',
        name: 'Old B',
        lastMessage: 'cached preview',
        previewTs: 10,
        unread: 1,
        isGroup: false,
        isAgent: false,
      ),
    ];

    final entries = applyProductConversationSummary(
      existingEntries: previous,
      conversation: AsConversation(
        conversationId: 'conv_direct',
        roomId: '!direct:p2p-im.com',
        kind: asConversationKindDirect,
        lifecycle: 'active',
        title: 'B Bash',
        avatarUrl: 'mxc://p2p-im.com/avatar',
        lastActivityAt: DateTime.utc(2026, 6, 22, 10),
        capabilities: const AsConversationCapabilities(open: true),
      ),
      pinnedConversationIds: const {},
    );

    expect(entries, hasLength(1));
    expect(entries.single.conversationId, 'conv_direct');
    expect(entries.single.roomId, '!direct:p2p-im.com');
    expect(entries.single.name, 'B Bash');
    expect(entries.single.lastMessage, 'cached preview');
    expect(entries.single.previewTs,
        DateTime.utc(2026, 6, 22, 10).millisecondsSinceEpoch);
    expect(entries.single.unread, 0);
    expect(entries.single.avatarUrl, 'mxc://p2p-im.com/avatar');
  });

  test('removes ProductCore mutation conversation that cannot open', () {
    final entries = applyProductConversationSummary(
      existingEntries: const [
        ConversationSummaryEntry(
          conversationId: 'conv_deleted',
          roomId: '!direct:p2p-im.com',
          kind: 'direct',
          name: 'Deleted B',
          lastMessage: 'old preview',
          previewTs: 10,
          unread: 0,
          isGroup: false,
          isAgent: false,
        ),
      ],
      conversation: const AsConversation(
        conversationId: 'conv_deleted',
        roomId: '!direct:p2p-im.com',
        kind: asConversationKindDirect,
        lifecycle: 'deleted',
        title: 'Deleted B',
        avatarUrl: '',
        capabilities: AsConversationCapabilities(open: false),
      ),
      pinnedConversationIds: const {},
    );

    expect(entries, isEmpty);
  });

  test('does not keep ProductCore channel conversations in message summaries',
      () {
    final entries = applyProductConversationSummary(
      existingEntries: const [],
      conversation: const AsConversation(
        conversationId: 'conv_channel',
        roomId: '!channel:p2p-im.com',
        kind: asConversationKindChannel,
        lifecycle: 'active',
        title: 'Channel',
        avatarUrl: '',
        lastMessage: 'channel post',
        capabilities: AsConversationCapabilities(open: true),
      ),
      pinnedConversationIds: const {},
    );

    expect(entries, isEmpty);
  });

  test('projects empty live refresh as a store-clearing update', () {
    const cached = ConversationSummaryEntry(
      conversationId: 'conv_stale',
      roomId: '!stale:p2p-im.com',
      kind: 'direct',
      name: 'Stale B',
      lastMessage: 'old preview',
      previewTs: 1,
      unread: 0,
      isGroup: false,
      isAgent: false,
    );
    final projection = projectConversationSummaryEntries(
      state: ConversationSummaryState.fromSnapshot(
        ConversationSummarySnapshot(
          userId: '@owner:p2p-im.com',
          updatedAt: DateTime.utc(2026, 6, 22, 12),
          entries: const [cached],
        ),
      ),
      userId: '@owner:p2p-im.com',
      hiddenConversationIds: const {},
      pinnedConversationIds: const {},
      liveEntries: const [],
      includeCachedOnlyEntries: false,
    );

    expect(projection.displayEntries, isEmpty);
    expect(projection.storeEntries, isEmpty);
    expect(projection.shouldWriteStore, isTrue);
  });

  test('keeps cached summaries while ProductCore refresh is still loading', () {
    const cached = ConversationSummaryEntry(
      conversationId: 'conv_cached',
      roomId: '!cached:p2p-im.com',
      kind: 'direct',
      name: 'Cached B',
      lastMessage: 'cached preview',
      previewTs: 1,
      unread: 0,
      isGroup: false,
      isAgent: false,
    );
    final projection = projectConversationSummaryEntries(
      state: ConversationSummaryState.fromSnapshot(
        ConversationSummarySnapshot(
          userId: '@owner:p2p-im.com',
          updatedAt: DateTime.utc(2026, 6, 22, 12),
          entries: const [cached],
        ),
      ),
      userId: '@owner:p2p-im.com',
      hiddenConversationIds: const {},
      pinnedConversationIds: const {},
      liveEntries: const [],
      includeCachedOnlyEntries: true,
    );

    expect(projection.displayEntries, [cached]);
    expect(projection.storeEntries, [cached]);
    expect(projection.shouldWriteStore, isTrue);
  });
}

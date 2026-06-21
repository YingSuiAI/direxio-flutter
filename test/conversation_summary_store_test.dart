import 'package:flutter_test/flutter_test.dart';
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

  test('sorts pinned and agent summaries before recent normal summaries', () {
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
      ['!pinned:p2p-im.com', '!agent:p2p-im.com', '!normal:p2p-im.com'],
    );
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/conversation_summary_store.dart';
import 'package:portal_app/presentation/providers/conversation_summary_provider.dart';

void main() {
  test('applies ProductCore mutation conversation to summary state and store',
      () async {
    final store = _MemoryConversationSummaryStore(
      ConversationSummarySnapshot(
        userId: '@owner:p2p-im.com',
        updatedAt: DateTime.utc(2026, 6, 22, 9),
        entries: const [
          ConversationSummaryEntry(
            conversationId: 'conv_direct',
            roomId: '!direct:p2p-im.com',
            kind: 'direct',
            name: 'Old B',
            lastMessage: 'cached preview',
            previewTs: 1,
            unread: 2,
            isGroup: false,
            isAgent: false,
          ),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        conversationSummaryStoreProvider.overrideWith((ref) async => store),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(conversationSummaryProvider.notifier);
    await notifier.loaded;

    await notifier.applyProductConversationForUser(
      userId: '@owner:p2p-im.com',
      conversation: AsConversation(
        conversationId: 'conv_direct',
        roomId: '!direct:p2p-im.com',
        kind: asConversationKindDirect,
        lifecycle: 'active',
        title: 'B Bash',
        avatarUrl: '',
        lastActivityAt: DateTime.utc(2026, 6, 22, 10),
        capabilities: const AsConversationCapabilities(open: true),
      ),
    );

    final state = container.read(conversationSummaryProvider);
    expect(state.entries, hasLength(1));
    expect(state.entries.single.name, 'B Bash');
    expect(state.entries.single.lastMessage, 'cached preview');
    expect(state.entries.single.previewTs,
        DateTime.utc(2026, 6, 22, 10).millisecondsSinceEpoch);
    expect(store.snapshot?.entries.single.name, 'B Bash');
  });
}

class _MemoryConversationSummaryStore implements ConversationSummaryStore {
  _MemoryConversationSummaryStore(this.snapshot);

  ConversationSummarySnapshot? snapshot;

  @override
  Future<ConversationSummarySnapshot?> read() async => snapshot;

  @override
  Future<void> write(ConversationSummarySnapshot snapshot) async {
    this.snapshot = snapshot;
  }

  @override
  Future<void> clear() async {
    snapshot = null;
  }
}

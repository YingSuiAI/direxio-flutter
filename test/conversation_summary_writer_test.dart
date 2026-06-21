import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/home/conversation_summary_writer.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/local_message_order_provider.dart';
import 'package:portal_app/presentation/providers/local_outbox_provider.dart';

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

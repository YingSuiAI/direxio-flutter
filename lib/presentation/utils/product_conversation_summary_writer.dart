import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_summary_provider.dart';
import '../providers/product_conversations_provider.dart';

Future<void> recordProductConversationMutation(
  WidgetRef ref,
  AsConversation? conversation,
) async {
  if (conversation == null) return;
  await ref
      .read(conversationSummaryProvider.notifier)
      .applyProductConversationForUser(
        userId: ref.read(matrixClientProvider).userID,
        conversation: conversation,
      );
  ref.invalidate(productConversationsProvider);
}

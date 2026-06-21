import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/as_client.dart';
import 'as_client_provider.dart';

final productConversationsProvider =
    FutureProvider.autoDispose<List<AsConversation>>((ref) async {
  final conversations = await ref.watch(asClientProvider).listConversations();
  return [
    for (final conversation in conversations)
      if (conversation.roomId.trim().isNotEmpty &&
          conversation.lifecycle != 'deleted')
        conversation,
  ];
});

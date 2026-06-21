import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'conversation_preferences_provider.dart';

final homeHiddenConversationIdsProvider = Provider<Set<String>>(
  (ref) => ref.watch(hiddenConversationIdsProvider),
);

void hideHomeConversation(WidgetRef ref, String roomId) {
  final trimmed = roomId.trim();
  if (trimmed.isEmpty) return;
  ref.read(conversationPreferencesProvider.notifier).unpin(trimmed);
  setConversationHidden(ref, trimmed, true);
}

void showHomeConversation(WidgetRef ref, String roomId) {
  final trimmed = roomId.trim();
  if (trimmed.isEmpty) return;
  setConversationHidden(ref, trimmed, false);
}

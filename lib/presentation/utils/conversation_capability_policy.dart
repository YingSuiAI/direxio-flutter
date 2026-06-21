import '../../data/as_client.dart';

class ConversationCapabilityPolicy {
  const ConversationCapabilityPolicy({
    required this.canSendText,
    required this.canSendMedia,
    required this.canCall,
  });

  final bool canSendText;
  final bool canSendMedia;
  final bool canCall;
}

ConversationCapabilityPolicy conversationCapabilityPolicy({
  required AsConversation? conversation,
  required bool fallbackCanSend,
}) {
  if (conversation == null) {
    return ConversationCapabilityPolicy(
      canSendText: fallbackCanSend,
      canSendMedia: fallbackCanSend,
      canCall: fallbackCanSend,
    );
  }
  return ConversationCapabilityPolicy(
    canSendText: conversation.canSend,
    canSendMedia: conversation.canSendMedia,
    canCall: conversation.canCall,
  );
}

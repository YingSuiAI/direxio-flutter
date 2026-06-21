import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/utils/conversation_capability_policy.dart';

void main() {
  test('uses ProductCore capabilities when a conversation exists', () {
    final policy = conversationCapabilityPolicy(
      conversation: const AsConversation(
        conversationId: 'conv_1',
        roomId: '!room:p2p-im.com',
        kind: asConversationKindGroup,
        lifecycle: 'active',
        title: 'Group',
        avatarUrl: '',
        capabilities: AsConversationCapabilities(
          open: true,
          send: true,
          sendMedia: false,
          call: true,
        ),
      ),
      fallbackCanSend: true,
    );

    expect(policy.canSendText, isTrue);
    expect(policy.canSendMedia, isFalse);
    expect(policy.canCall, isTrue);
  });

  test('uses Matrix fallback only before ProductCore conversation exists', () {
    final policy = conversationCapabilityPolicy(
      conversation: null,
      fallbackCanSend: true,
    );

    expect(policy.canSendText, isTrue);
    expect(policy.canSendMedia, isTrue);
    expect(policy.canCall, isTrue);
  });
}

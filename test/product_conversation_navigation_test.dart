import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/utils/product_conversation_navigation.dart';

void main() {
  test('ProductCore kind decides route', () {
    const roomId = '!room:p2p-im.com';
    final route = productConversationRoute(
      const AsConversation(
        conversationId: 'conv_group',
        roomId: roomId,
        kind: asConversationKindGroup,
        lifecycle: 'joined',
        title: '群聊',
        avatarUrl: '',
        hydrationState: 'ready',
        capabilities: AsConversationCapabilities(open: true),
      ),
    );

    expect(route, '/group/!room%3Ap2p-im.com?conversation=conv_group');
  });

  test('ProductCore open capability gates route generation', () {
    const roomId = '!pending:p2p-im.com';
    final route = productConversationRoute(
      const AsConversation(
        conversationId: 'conv_pending',
        roomId: roomId,
        kind: asConversationKindGroup,
        lifecycle: 'active',
        title: 'Pending Group',
        avatarUrl: '',
        hydrationState: 'pending',
        capabilities: AsConversationCapabilities(open: false),
      ),
    );

    expect(route, isNull);
  });

  test('ProductCore channel kind keeps channel conversation route', () {
    const roomId = '!channel:p2p-im.com';
    final route = productConversationRoute(
      const AsConversation(
        conversationId: 'conv_channel',
        roomId: roomId,
        kind: asConversationKindChannel,
        lifecycle: 'active',
        title: '频道会话',
        avatarUrl: '',
        capabilities: AsConversationCapabilities(open: true),
      ),
      channelId: 'ch_product',
    );

    expect(
      route,
      '/channel/ch_product/conversation?conversation=conv_channel&name=%E9%A2%91%E9%81%93%E4%BC%9A%E8%AF%9D',
    );
  });

  test('ProductCore room lookup can be restricted by kind', () {
    const roomId = '!channel:p2p-im.com';
    const conversation = AsConversation(
      conversationId: 'conv_channel',
      roomId: roomId,
      kind: asConversationKindChannel,
      lifecycle: 'active',
      title: 'Channel',
      avatarUrl: '',
      capabilities: AsConversationCapabilities(open: true),
    );

    expect(
      productConversationForRoom(
        const [conversation],
        roomId,
        kinds: const {asConversationKindGroup},
      ),
      isNull,
    );
    expect(
      productConversationForRoom(
        const [conversation],
        roomId,
        kinds: const {asConversationKindChannel},
      ),
      conversation,
    );
  });
}

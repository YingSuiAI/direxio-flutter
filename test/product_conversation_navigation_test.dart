import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/utils/product_conversation_navigation.dart';

void main() {
  test('ProductCore kind decides route before Matrix direct fallback', () {
    const roomId = '!room:p2p-im.com';
    final client = Client('ConversationNavigationProductKindTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(id: roomId, client: client, membership: Membership.join);
    client.rooms.add(room);
    client.accountData['m.direct'] = BasicEvent(
      type: 'm.direct',
      content: {
        '@alice:p2p-im.com': <String>[roomId],
      },
    );

    final route = productConversationRouteForRoom(
      room: room,
      conversations: const [
        AsConversation(
          conversationId: 'conv_group',
          roomId: roomId,
          kind: asConversationKindGroup,
          lifecycle: 'joined',
          title: '群聊',
          avatarUrl: '',
        ),
      ],
    );

    expect(route, '/group/!room%3Ap2p-im.com?conversation=conv_group');
  });

  test('Matrix direct flag is fallback only without ProductCore data', () {
    const roomId = '!direct:p2p-im.com';
    final client = Client('ConversationNavigationFallbackTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(id: roomId, client: client, membership: Membership.join);
    client.rooms.add(room);
    client.accountData['m.direct'] = BasicEvent(
      type: 'm.direct',
      content: {
        '@alice:p2p-im.com': <String>[roomId],
      },
    );

    final route = productConversationRouteForRoom(
      room: room,
      conversations: const [],
    );

    expect(route, '/chat/!direct%3Ap2p-im.com');
  });
}

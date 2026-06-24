import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/utils/group_avatar_members.dart';

void main() {
  test('uses cached member avatar urls while Matrix member avatars hydrate',
      () {
    final client = Client('GroupAvatarMembersCachedUrlsTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(
      id: '!group:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@owner:p2p-im.com',
        stateKey: '@owner:p2p-im.com',
        content: const {'membership': 'join'},
      ),
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@alice:p2p-im.com',
        stateKey: '@alice:p2p-im.com',
        content: const {'membership': 'join'},
      ),
    );

    final result = stableGroupAvatarMembersForRoom(
      room: room,
      syncCache: const AsSyncCacheState(),
      cachedMemberOrder: const [
        '@alice:p2p-im.com',
        '@owner:p2p-im.com',
      ],
      cachedMemberAvatarUrls: const {
        '@alice:p2p-im.com':
            'https://p2p-im.com/_matrix/media/v3/download/p2p-im.com/alice',
      },
    );

    expect(result.members.map((member) => member.seed), [
      '@alice:p2p-im.com',
      '@owner:p2p-im.com',
    ]);
    expect(
      result.members.first.imageUrl,
      'https://p2p-im.com/_matrix/media/v3/download/p2p-im.com/alice',
    );
    expect(result.shouldPersistAvatarUrls, isFalse);
  });
}

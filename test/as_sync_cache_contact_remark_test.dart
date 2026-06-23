import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';

void main() {
  test('copyWith preserves real auth agent room id when bootstrap omits it',
      () {
    final state = AsSyncCacheState(
      bootstrap: AsSyncBootstrap(
        syncedAt: DateTime.utc(2026),
        user: const AsSyncUser(userId: '@owner:example.com'),
        agentRoomId: '!real-agent-room:example.com',
        rooms: const [],
        contacts: const [],
        groups: const [],
        channels: const [],
        pending: const AsSyncPending.empty(),
      ),
    );

    final next = state.copyWith(
      bootstrap: AsSyncBootstrap(
        syncedAt: DateTime.utc(2026, 6, 23),
        user: const AsSyncUser(userId: '@owner:example.com'),
        rooms: const [],
        contacts: const [],
        groups: const [],
        channels: const [],
        pending: const AsSyncPending.empty(),
      ),
    );

    expect(next.bootstrap?.agentRoomId, '!real-agent-room:example.com');
  });

  test('copyWith drops legacy pseudo agent room ids', () {
    const state = AsSyncCacheState();

    final next = state.copyWith(
      bootstrap: AsSyncBootstrap(
        syncedAt: DateTime.utc(2026),
        user: const AsSyncUser(userId: '@owner:example.com'),
        agentRoomId: '!agent:example.com',
        rooms: const [],
        contacts: const [],
        groups: const [],
        channels: const [],
        pending: const AsSyncPending.empty(),
      ),
    );

    expect(next.bootstrap?.agentRoomId, isEmpty);
  });

  test('withContactDisplayName updates bootstrap contact name', () {
    final state = AsSyncCacheState(
      bootstrap: AsSyncBootstrap(
        syncedAt: DateTime.utc(2026),
        user: const AsSyncUser(userId: '@owner:example.com'),
        rooms: const [],
        contacts: const [
          AsSyncContact(
            userId: '@alice:example.com',
            displayName: 'Alice',
            avatarUrl: 'mxc://example/avatar',
            roomId: '!alice:example.com',
            domain: 'example.com',
            status: 'accepted',
          ),
        ],
        groups: const [],
        channels: const [],
        pending: const AsSyncPending.empty(),
      ),
    );

    final next = state.withContactDisplayName(
      userId: '@alice:example.com',
      displayName: '  备注名  ',
    );

    final contact = next.acceptedContactForUserId('@alice:example.com');
    expect(contact?.displayName, '备注名');
    expect(contact?.avatarUrl, 'mxc://example/avatar');
    expect(contact?.roomId, '!alice:example.com');
  });

  test('withContactDisplayName updates local optimistic contact name', () {
    const entry = ContactEntry(
      peerMxid: '@bob:example.com',
      displayName: 'Bob',
      domain: 'example.com',
      roomId: '!bob:example.com',
      status: 'accepted',
    );
    const state = AsSyncCacheState(
      localContactEntriesByRoomId: {'!bob:example.com': entry},
    );

    final next = state.withContactDisplayName(
      userId: '@bob:example.com',
      displayName: 'Bobby',
    );

    expect(
      next.acceptedContactForUserId('@bob:example.com')?.displayName,
      'Bobby',
    );
  });

  test('local optimistic contact keeps ProductCore conversation avatar', () {
    const entry = ContactEntry(
      peerMxid: '@bob:example.com',
      displayName: 'Bob',
      domain: 'example.com',
      roomId: '!bob:example.com',
      status: 'accepted',
      productConversation: AsConversation(
        conversationId: 'conv_bob',
        roomId: '!bob:example.com',
        kind: asConversationKindDirect,
        lifecycle: 'active',
        title: 'Bob',
        avatarUrl: 'mxc://example/bob-product',
      ),
    );
    const state = AsSyncCacheState(
      localContactEntriesByRoomId: {'!bob:example.com': entry},
    );

    expect(
      state.acceptedContactForUserId('@bob:example.com')?.avatarUrl,
      'mxc://example/bob-product',
    );
  });

  test('local optimistic contact preserves bootstrap avatar fallback', () {
    final state = AsSyncCacheState(
      bootstrap: AsSyncBootstrap(
        syncedAt: DateTime.utc(2026),
        user: const AsSyncUser(userId: '@owner:example.com'),
        rooms: const [],
        contacts: const [
          AsSyncContact(
            userId: '@bob:example.com',
            displayName: 'Bob',
            avatarUrl: 'mxc://example/bob-bootstrap',
            roomId: '!bob:example.com',
            domain: 'example.com',
            status: 'accepted',
          ),
        ],
        groups: const [],
        channels: const [],
        pending: const AsSyncPending.empty(),
      ),
      localContactEntriesByRoomId: const {
        '!bob:example.com': ContactEntry(
          peerMxid: '@bob:example.com',
          displayName: 'Bob 备注',
          domain: 'example.com',
          roomId: '!bob:example.com',
          status: 'accepted',
        ),
      },
    );

    final contact = state.acceptedContactForUserId('@bob:example.com');
    expect(contact?.displayName, 'Bob 备注');
    expect(contact?.avatarUrl, 'mxc://example/bob-bootstrap');
  });

  test('bootstrap accepted contact replaces local optimistic pending request',
      () {
    const pending = ContactEntry(
      peerMxid: '@bob:example.com',
      displayName: 'Bob',
      domain: 'example.com',
      roomId: '!request:example.com',
      status: 'pending_outbound',
    );
    final state = const AsSyncCacheState().withContactEntry(pending);

    final next = state.copyWith(
      bootstrap: AsSyncBootstrap(
        syncedAt: DateTime.utc(2026),
        user: const AsSyncUser(userId: '@owner:example.com'),
        rooms: const [],
        contacts: const [
          AsSyncContact(
            userId: '@bob:example.com',
            displayName: 'Bob',
            avatarUrl: 'mxc://example/bob',
            roomId: '!accepted:example.com',
            domain: 'example.com',
            status: 'accepted',
          ),
        ],
        groups: const [],
        channels: const [],
        pending: const AsSyncPending.empty(),
      ),
    );

    expect(next.pendingOutboundContacts, isEmpty);
    expect(next.contactForRoom('!request:example.com'), isNull);
    expect(next.acceptedDirectRoomIds, {'!accepted:example.com'});
    expect(
      next.acceptedContactForUserId('@bob:example.com')?.roomId,
      '!accepted:example.com',
    );
  });

  test('contacts dedupe by peer mxid and prefer accepted direct room', () {
    final state = AsSyncCacheState(
      bootstrap: AsSyncBootstrap(
        syncedAt: DateTime.utc(2026),
        user: const AsSyncUser(userId: '@owner:example.com'),
        rooms: const [],
        contacts: const [
          AsSyncContact(
            userId: '@bob:example.com',
            displayName: 'owner',
            avatarUrl: '',
            roomId: '!request:example.com',
            domain: 'example.com',
            status: 'pending_outbound',
          ),
          AsSyncContact(
            userId: '@bob:example.com',
            displayName: 'Bobby',
            avatarUrl: 'mxc://example/bobby',
            roomId: '!accepted:example.com',
            domain: 'example.com',
            status: 'accepted',
          ),
        ],
        groups: const [],
        channels: const [],
        pending: const AsSyncPending.empty(),
      ),
    );

    expect(state.contacts, hasLength(1));
    expect(state.contacts.single.roomId, '!accepted:example.com');
    expect(state.contacts.single.displayName, 'Bobby');
    expect(state.acceptedDirectRoomIds, {'!accepted:example.com'});
    expect(state.nonAcceptedContactRoomIds, isEmpty);
    expect(state.contactForRoom('!request:example.com'), isNull);
    expect(state.contactForUserId('@bob:example.com')?.roomId,
        '!accepted:example.com');
  });

  test('contacts dedupe exact room duplicates and keep latest display metadata',
      () {
    final state = AsSyncCacheState(
      bootstrap: AsSyncBootstrap(
        syncedAt: DateTime.utc(2026),
        user: const AsSyncUser(userId: '@owner:example.com'),
        rooms: const [],
        contacts: const [
          AsSyncContact(
            userId: '@alice:example.com',
            displayName: 'owner',
            avatarUrl: '',
            roomId: '!alice:example.com',
            domain: 'example.com',
            status: 'accepted',
          ),
          AsSyncContact(
            userId: '@alice:example.com',
            displayName: 'Alice Chen',
            avatarUrl: 'mxc://example/alice',
            roomId: '!alice:example.com',
            domain: 'example.com',
            status: 'accepted',
          ),
        ],
        groups: const [],
        channels: const [],
        pending: const AsSyncPending.empty(),
      ),
    );

    expect(state.contacts, hasLength(1));
    expect(state.contacts.single.displayName, 'Alice Chen');
    expect(state.contacts.single.avatarUrl, 'mxc://example/alice');
  });

  test('contacts dedupe keeps real nickname when default owner arrives later',
      () {
    final state = AsSyncCacheState(
      bootstrap: AsSyncBootstrap(
        syncedAt: DateTime.utc(2026),
        user: const AsSyncUser(userId: '@owner:example.com'),
        rooms: const [],
        contacts: const [
          AsSyncContact(
            userId: '@owner:b.example.com',
            displayName: 'B 的昵称',
            avatarUrl: 'mxc://example/b',
            roomId: '!accepted:b.example.com',
            domain: 'b.example.com',
            status: 'accepted',
          ),
          AsSyncContact(
            userId: '@owner:b.example.com',
            displayName: 'owner',
            avatarUrl: '',
            roomId: '!accepted:b.example.com',
            domain: 'b.example.com',
            status: 'accepted',
          ),
        ],
        groups: const [],
        channels: const [],
        pending: const AsSyncPending.empty(),
      ),
    );

    expect(state.contacts, hasLength(1));
    expect(state.contacts.single.displayName, 'B 的昵称');
    expect(state.contacts.single.avatarUrl, 'mxc://example/b');
  });
}

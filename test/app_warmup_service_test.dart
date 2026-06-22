import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_call_session_store.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/channel_post_store.dart';
import 'package:portal_app/presentation/providers/app_warmup_provider.dart';

class _NoopAvatarPreloader implements AvatarPreloader {
  @override
  Future<void> preload(String url) async {}
}

class _RecordingAvatarPreloader implements AvatarPreloader {
  final urls = <String>[];

  @override
  Future<void> preload(String url) async {
    urls.add(url);
  }
}

class _RecordingMediaThumbnailPreloader implements MediaThumbnailPreloader {
  final eventIds = <String>[];

  @override
  Future<void> preload(Iterable<String> ids) async {
    eventIds.addAll(ids);
  }
}

void main() {
  test('warmup starts Matrix conversation sync for logged-in clients',
      () async {
    var syncCalls = 0;
    final client = Client('DirexioWarmupMatrixSyncTest')..accessToken = 'token';
    final service = AppWarmupService(
      client: client,
      avatarPreloader: _NoopAvatarPreloader(),
      loadCurrentUserProfile: () async => null,
      syncMatrixConversations: () async {
        syncCalls++;
      },
    );

    await service.warmup();

    expect(syncCalls, 1);
  });

  test('warmup starts Matrix sync and bootstrap in parallel', () async {
    final events = <String>[];
    final syncCompleter = Completer<void>();
    final bootstrapCompleter = Completer<AsSyncBootstrap>();
    final client = Client('DirexioWarmupTest')..accessToken = 'token';
    final service = AppWarmupService(
      client: client,
      avatarPreloader: _NoopAvatarPreloader(),
      loadCurrentUserProfile: () async => null,
      syncMatrixConversations: () {
        events.add('matrix-sync-start');
        return syncCompleter.future;
      },
      loadBootstrap: () {
        events.add('bootstrap-start');
        return bootstrapCompleter.future;
      },
      onBootstrapLoaded: (_) => events.add('bootstrap-apply'),
    );

    final warmup = service.warmup();
    await Future<void>.delayed(Duration.zero);

    expect(events, ['bootstrap-start', 'matrix-sync-start']);

    bootstrapCompleter.complete(AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-05-25T10:00:01Z'),
      user: const AsSyncUser(userId: '@owner:example.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    ));
    syncCompleter.complete();

    await warmup;

    expect(events, [
      'bootstrap-start',
      'matrix-sync-start',
      'bootstrap-apply',
    ]);
  });

  test('warmup preloads AS contact avatars from bootstrap metadata', () async {
    final avatarPreloader = _RecordingAvatarPreloader();
    final client = Client('DirexioWarmupContactAvatarTest')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final service = AppWarmupService(
      client: client,
      avatarPreloader: avatarPreloader,
      loadCurrentUserProfile: () async => null,
      loadBootstrap: () async => AsSyncBootstrap(
        syncedAt: DateTime.parse('2026-06-02T10:00:00Z'),
        user: const AsSyncUser(userId: '@owner:p2p-im.com'),
        rooms: const [],
        contacts: const [
          AsSyncContact(
            userId: '@lee:p2p-liyanan.com',
            displayName: 'Lee',
            avatarUrl: 'mxc://p2p-liyanan.com/lee-avatar',
            roomId: '!lee:p2p-liyanan.com',
            domain: 'p2p-liyanan.com',
            status: 'accepted',
          ),
          AsSyncContact(
            userId: '@test:p2p-im-test.com',
            displayName: 'Test Node',
            avatarUrl: 'https://cdn.example.com/test.png',
            roomId: '!test:p2p-im-test.com',
            domain: 'p2p-im-test.com',
            status: 'accepted',
          ),
        ],
        groups: const [],
        channels: const [],
        pending: const AsSyncPending.empty(),
      ),
    );

    await service.warmup();

    expect(
      avatarPreloader.urls,
      contains(contains('/download/p2p-liyanan.com/lee-avatar')),
    );
    expect(avatarPreloader.urls, contains('https://cdn.example.com/test.png'));
  });

  test('warmup applies cached bootstrap before slow network bootstrap',
      () async {
    final events = <String>[];
    final bootstrapCompleter = Completer<AsSyncBootstrap>();
    final service = AppWarmupService(
      client: Client('DirexioWarmupBootstrapCacheTest'),
      avatarPreloader: _NoopAvatarPreloader(),
      loadCurrentUserProfile: () async => null,
      loadCachedBootstrap: () async {
        events.add('bootstrap-cache-read');
        return _bootstrap('!cached:p2p-im.com');
      },
      loadBootstrap: () {
        events.add('bootstrap-network-start');
        return bootstrapCompleter.future;
      },
      onBootstrapLoaded: (bootstrap) {
        events.add('bootstrap-apply:${bootstrap.contacts.single.roomId}');
      },
    );

    final warmup = service.warmup();
    await Future<void>.delayed(Duration.zero);

    expect(events, [
      'bootstrap-cache-read',
      'bootstrap-network-start',
      'bootstrap-apply:!cached:p2p-im.com',
    ]);

    bootstrapCompleter.complete(_bootstrap('!fresh:p2p-im.com'));
    await warmup;

    expect(events, [
      'bootstrap-cache-read',
      'bootstrap-network-start',
      'bootstrap-apply:!cached:p2p-im.com',
      'bootstrap-apply:!fresh:p2p-im.com',
    ]);
  });

  test('warmup preloads local thumbnails for recent image rooms', () async {
    final client = Client('DirexioWarmupMediaTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: '!room:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    room.lastEvent = Event(
      room: room,
      eventId: r'$last-image',
      senderId: '@peer:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 28, 10),
      content: {
        'msgtype': MessageTypes.Image,
        'body': 'cached.jpg',
      },
    );
    client.rooms.add(room);

    final thumbnails = _RecordingMediaThumbnailPreloader();
    final service = AppWarmupService(
      client: client,
      avatarPreloader: _NoopAvatarPreloader(),
      mediaThumbnailPreloader: thumbnails,
      loadCurrentUserProfile: () async => null,
    );

    await service.warmup();

    expect(thumbnails.eventIds, [r'$last-image']);
  });

  test('warmup preloads missing or non-terminal AS call sessions', () async {
    final client = Client('DirexioWarmupCallTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: '!room:p2p-im.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    final store = _MemoryAsCallSessionStore()
      ..calls['as-ended'] = _callSession(
        callId: 'as-ended',
        state: asCallStateEnded,
      )
      ..calls['as-connected'] = _callSession(
        callId: 'as-connected',
        state: asCallStateConnected,
      );
    final loadedCallIds = <String>[];
    final events = [
      ..._callEvents(
        room,
        matrixCallId: 'call-ended',
        asCallId: 'as-ended',
        offsetSeconds: 0,
      ),
      ..._callEvents(
        room,
        matrixCallId: 'call-connected',
        asCallId: 'as-connected',
        offsetSeconds: 60,
      ),
      ..._callEvents(
        room,
        matrixCallId: 'call-missing',
        asCallId: 'as-missing',
        offsetSeconds: 120,
      ),
    ];
    final service = AppWarmupService(
      client: client,
      avatarPreloader: _NoopAvatarPreloader(),
      loadCurrentUserProfile: () async => null,
      callSessionStore: store,
      loadCallSession: (callId) async {
        loadedCallIds.add(callId);
        return _callSession(callId: callId, state: asCallStateEnded);
      },
      loadRecentRoomEvents: (_, __) async => events,
    );

    await service.warmup();

    expect(loadedCallIds, ['as-connected', 'as-missing']);
    expect(store.calls['as-ended']?.state, asCallStateEnded);
    expect(store.calls['as-connected']?.state, asCallStateEnded);
    expect(store.calls['as-missing']?.state, asCallStateEnded);
  });

  test('warmup preloads recent channel posts into local cache', () async {
    final store = _MemoryChannelPostStore();
    final loadedChannelIds = <String>[];
    final service = AppWarmupService(
      client: Client('DirexioWarmupChannelTest'),
      avatarPreloader: _NoopAvatarPreloader(),
      loadCurrentUserProfile: () async => null,
      loadBootstrap: () async => AsSyncBootstrap(
        syncedAt: DateTime.parse('2026-06-07T10:00:00Z'),
        user: const AsSyncUser(userId: '@owner:p2p-im.com'),
        rooms: const [],
        contacts: const [],
        groups: const [],
        channels: [
          AsSyncRoomSummary(
            channelId: 'ch_new',
            roomId: '!new:p2p-im.com',
            name: '新频道',
            avatarUrl: '',
            unreadCount: 0,
            lastActivityAt: DateTime.parse('2026-06-07T10:00:00Z'),
            memberStatus: asChannelMemberStatusJoined,
          ),
          AsSyncRoomSummary(
            channelId: 'ch_old',
            roomId: '!old:p2p-im.com',
            name: '旧频道',
            avatarUrl: '',
            unreadCount: 0,
            lastActivityAt: DateTime.parse('2026-06-06T10:00:00Z'),
            memberStatus: asChannelMemberStatusJoined,
          ),
        ],
        pending: const AsSyncPending.empty(),
      ),
      channelPostStore: store,
      loadChannelPosts: (channelId, {int limit = 50}) async {
        loadedChannelIds.add('$channelId:$limit');
        return [_channelPost(postId: 'post_$channelId', channelId: channelId)];
      },
    );

    await service.warmup();

    expect(loadedChannelIds, ['ch_new:50', 'ch_old:50']);
    expect(
      (await store.readChannel('ch_new')).map((post) => post.postId),
      ['post_ch_new'],
    );
    expect(
      (await store.readChannel('ch_old')).map((post) => post.postId),
      ['post_ch_old'],
    );
  });
}

class _MemoryAsCallSessionStore implements AsCallSessionStore {
  final calls = <String, AsCallSession>{};

  @override
  Future<List<AsCallSession>> readAll() async {
    return calls.values.toList(growable: false);
  }

  @override
  Future<AsCallSession?> read(String callId) async {
    return calls[callId.trim()];
  }

  @override
  Future<List<AsCallSession>> readRoomStable(String roomId) async {
    final trimmed = roomId.trim();
    return calls.values
        .where((session) => session.roomId.trim() == trimmed)
        .toList(growable: false);
  }

  @override
  Future<void> upsert(AsCallSession session) async {
    calls[session.callId.trim()] = session;
  }

  @override
  Future<void> upsertAll(Iterable<AsCallSession> sessions) async {
    for (final session in sessions) {
      calls[session.callId.trim()] = session;
    }
  }
}

class _MemoryChannelPostStore implements ChannelPostStore {
  final posts = <String, AsChannelPost>{};

  @override
  Future<List<AsChannelPost>> readChannel(String channelId) async {
    final trimmed = channelId.trim();
    return posts.values
        .where((post) => post.channelId.trim() == trimmed)
        .toList(growable: false)
      ..sort((a, b) => b.originServerTs.compareTo(a.originServerTs));
  }

  @override
  Future<void> upsertChannel(
    String channelId,
    Iterable<AsChannelPost> nextPosts,
  ) async {
    for (final post in nextPosts) {
      await upsertPost(post);
    }
  }

  @override
  Future<void> upsertPost(AsChannelPost post) async {
    posts['${post.channelId}:${post.postId}'] = post;
  }

  @override
  Future<void> removePost(String channelId, String postId) async {
    posts.removeWhere((_, post) {
      if (post.channelId.trim() != channelId.trim()) return false;
      final id = post.postId.trim();
      if (id.isNotEmpty) return id == postId.trim();
      return post.eventId.trim() == postId.trim();
    });
  }
}

AsChannelPost _channelPost({
  required String postId,
  required String channelId,
}) {
  return AsChannelPost(
    postId: postId,
    channelId: channelId,
    roomId: '!channel:p2p-im.com',
    eventId: '\$$postId',
    authorId: '@owner:p2p-im.com',
    authorName: 'Yanan',
    messageType: 'text',
    body: '频道预热内容',
    originServerTs:
        DateTime.parse('2026-06-07T10:00:00Z').millisecondsSinceEpoch,
  );
}

AsSyncBootstrap _bootstrap(String roomId) {
  return AsSyncBootstrap(
    syncedAt: DateTime.parse('2026-05-28T08:00:00Z'),
    user: const AsSyncUser(userId: '@owner:p2p-im.com'),
    rooms: const [],
    contacts: [
      AsSyncContact(
        userId: '@peer:p2p-liyanan.com',
        displayName: 'Peer',
        avatarUrl: '',
        roomId: roomId,
        domain: 'p2p-liyanan.com',
        status: 'accepted',
      ),
    ],
    groups: const [],
    channels: const [],
    pending: const AsSyncPending.empty(),
  );
}

List<Event> _callEvents(
  Room room, {
  required String matrixCallId,
  required String asCallId,
  required int offsetSeconds,
}) {
  final base = DateTime.utc(2026, 5, 31, 12).add(
    Duration(seconds: offsetSeconds),
  );
  return [
    Event(
      room: room,
      eventId: '\$intent-$matrixCallId',
      senderId: '@owner:p2p-im.com',
      type: 'p2p.call.intent.v1',
      originServerTs: base,
      content: {
        'call_id': asCallId,
        'call_type': 'voice',
        'target_user_id': '@peer:p2p-liyanan.com',
      },
    ),
    Event(
      room: room,
      eventId: '\$invite-$matrixCallId',
      senderId: '@owner:p2p-im.com',
      type: EventTypes.CallInvite,
      originServerTs: base.add(const Duration(seconds: 1)),
      content: {
        'call_id': matrixCallId,
        'version': 1,
      },
    ),
    Event(
      room: room,
      eventId: '\$hangup-$matrixCallId',
      senderId: '@owner:p2p-im.com',
      type: EventTypes.CallHangup,
      originServerTs: base.add(const Duration(seconds: 10)),
      content: {
        'call_id': matrixCallId,
        'version': 1,
        'reason': 'user_hangup',
      },
    ),
  ];
}

AsCallSession _callSession({
  required String callId,
  required String state,
}) {
  return AsCallSession(
    callId: callId,
    roomId: '!room:p2p-im.com',
    roomType: 'direct',
    mediaType: asCallMediaTypeVoice,
    createdByMxid: '@owner:p2p-im.com',
    state: state,
    createdAt: DateTime.utc(2026, 5, 31, 12),
    answeredAt: state == asCallStateEnded || state == asCallStateConnected
        ? DateTime.utc(2026, 5, 31, 12, 0, 2)
        : null,
    endedAt:
        state == asCallStateEnded ? DateTime.utc(2026, 5, 31, 12, 0, 10) : null,
    durationMs: state == asCallStateEnded ? 8000 : 0,
  );
}

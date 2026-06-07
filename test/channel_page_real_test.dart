import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/channel_post_store.dart';
import 'package:portal_app/data/mock_as_client.dart';
import 'package:portal_app/presentation/pages/channel_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/channel_provider.dart';

void main() {
  testWidgets('channel detail opens real bootstrap channel summary',
      (tester) async {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-05-26T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          roomId: '!real:p2p-im.com',
          name: '产品公告',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-05-26T10:20:00Z'),
          topic: '只发布重要产品更新',
          isOwned: true,
          tags: const ['产品', '公告'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(_NoPostChannelAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: '!real:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('产品公告'), findsAtLeastNWidgets(1));
    expect(find.text('p2p-im.com · 我的频道'), findsOneWidget);
    expect(find.text('只发布重要产品更新'), findsOneWidget);
    expect(find.text('频道帖子'), findsOneWidget);
    expect(find.text('发布帖子'), findsOneWidget);
    expect(find.text('频道不存在'), findsNothing);
  });

  testWidgets('channel detail loads public AS channel when not in bootstrap',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(_PublicChannelAsClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: 'ch_public'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('公开频道'), findsAtLeastNWidgets(1));
    expect(find.text('p2p-im.com'), findsOneWidget);
    expect(find.text('加入频道'), findsOneWidget);
    expect(find.text('频道不存在'), findsNothing);
  });

  testWidgets('channel detail renders AS posts and publishes text post',
      (tester) async {
    final asClient = _PostingChannelAsClient();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_real',
          roomId: '!real:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '产品公告',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          description: '只发布重要产品更新',
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          tags: const ['产品'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第一条帖子'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '新帖子');
    await tester.tap(find.text('发布帖子'));
    await tester.pumpAndSettle();

    expect(asClient.createdBody, '新帖子');
    expect(find.text('新帖子'), findsOneWidget);
  });

  testWidgets('channel detail toggles AS post reaction', (tester) async {
    final asClient = _PostingChannelAsClient();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_real',
          roomId: '!real:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '产品公告',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          description: '只发布重要产品更新',
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          tags: const ['产品'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('点赞 2'), findsOneWidget);

    await tester.tap(find.text('点赞 2'));
    await tester.pumpAndSettle();

    expect(asClient.toggledPostId, 'post1');
  });

  testWidgets('channel comments sheet sends comment and can close',
      (tester) async {
    final asClient = _PostingChannelAsClient();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_real',
          roomId: '!real:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '产品公告',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          description: '只发布重要产品更新',
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          tags: const ['产品'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('评论 0'));
    await tester.pumpAndSettle();

    expect(find.text('评论线程'), findsOneWidget);
    expect(find.text('写评论'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('channel_comments_close')), findsOneWidget);

    await tester.enterText(find.byType(TextField), '这条更新很有用');
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();

    expect(asClient.createdCommentBody, '这条更新很有用');

    await tester.tap(find.byKey(const ValueKey('channel_comments_close')));
    await tester.pumpAndSettle();

    expect(find.text('评论线程'), findsNothing);
  });

  testWidgets('owned channel management saves AS metadata', (tester) async {
    final asClient = _PostingChannelAsClient();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_real',
          roomId: '!real:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '产品公告',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          description: '只发布重要产品更新',
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          tags: const ['产品'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.more_horiz).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理频道'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '频道名称'), '产品更新');
    await tester.enterText(find.widgetWithText(TextField, '频道简介'), '每周产品更新');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(asClient.updatedChannel?.channelId, 'ch_real');
    expect(asClient.updatedChannel?.name, '产品更新');
    expect(asClient.updatedChannel?.description, '每周产品更新');
  });

  testWidgets('owned channel member management approves pending requests',
      (tester) async {
    final asClient = _PostingChannelAsClient();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_real',
          roomId: '!real:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '产品公告',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          pendingJoinCount: 1,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.more_horiz).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('成员管理'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('@alice:p2p-liyanan.com'), findsOneWidget);

    await tester.tap(find.text('同意'));
    await tester.pumpAndSettle();

    expect(asClient.approvedUserId, '@alice:p2p-liyanan.com');
  });

  testWidgets('real channel page marks latest post as read', (tester) async {
    final asClient = _PostingChannelAsClient();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_real',
          roomId: '!real:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '产品公告',
          avatarUrl: '',
          unreadCount: 3,
          lastActivityAt: DateTime.parse('2026-06-06T10:20:00Z'),
          isOwned: true,
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _channelPostStoreOverride(),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: 'ch_real'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(asClient.readMarkerChannelId, 'ch_real');
    expect(asClient.readMarkerEventId, r'$post1');
  });
}

Override _channelPostStoreOverride([ChannelPostStore? store]) {
  final resolved = store ?? _MemoryChannelPostStore();
  return channelPostStoreProvider.overrideWith((ref) async => resolved);
}

class _MemoryChannelPostStore implements ChannelPostStore {
  final _posts = <String, AsChannelPost>{};

  @override
  Future<List<AsChannelPost>> readChannel(String channelId) async {
    return _posts.values
        .where((post) => post.channelId.trim() == channelId.trim())
        .toList(growable: false)
      ..sort((a, b) => b.originServerTs.compareTo(a.originServerTs));
  }

  @override
  Future<void> upsertChannel(
    String channelId,
    Iterable<AsChannelPost> posts,
  ) async {
    for (final post in posts) {
      await upsertPost(post);
    }
  }

  @override
  Future<void> upsertPost(AsChannelPost post) async {
    final postId = post.postId.trim();
    final eventId = post.eventId.trim();
    _posts['${post.channelId}:${postId.isNotEmpty ? postId : eventId}'] = post;
  }
}

class _PublicChannelAsClient extends MockAsClient {
  @override
  Future<AsChannel> getPublicChannel(String channelId, {Uri? baseUri}) async {
    return const AsChannel(
      channelId: 'ch_public',
      roomId: '!ch_public:p2p-im.com',
      homeDomain: 'p2p-im.com',
      name: '公开频道',
      description: '公开频道说明',
      visibility: asChannelVisibilityPublic,
      joinPolicy: asChannelJoinPolicyOpen,
      commentsEnabled: true,
    );
  }
}

class _NoPostChannelAsClient extends MockAsClient {
  @override
  Future<List<AsChannelPost>> getChannelPosts(
    String channelId, {
    int limit = 50,
    int beforeTs = 0,
  }) async {
    return const [];
  }
}

class _PostingChannelAsClient extends MockAsClient {
  String? createdBody;
  String? createdCommentBody;
  AsChannel? updatedChannel;
  String? approvedUserId;
  String? rejectedUserId;
  String? readMarkerChannelId;
  String? readMarkerEventId;

  @override
  Future<List<AsChannelPost>> getChannelPosts(
    String channelId, {
    int limit = 50,
    int beforeTs = 0,
  }) async {
    return [
      AsChannelPost(
        postId: 'post1',
        channelId: channelId,
        roomId: '!real:p2p-im.com',
        eventId: r'$post1',
        authorId: '@owner:p2p-im.com',
        authorName: 'Yanan',
        messageType: 'text',
        body: createdBody ?? '第一条帖子',
        originServerTs:
            DateTime.parse('2026-06-06T10:20:00Z').millisecondsSinceEpoch,
        reactionCount: 2,
      ),
    ];
  }

  @override
  Future<AsChannelPost> createChannelPost(
    String channelId, {
    required String messageType,
    required String body,
    Map<String, Object?> media = const {},
  }) async {
    createdBody = body;
    return AsChannelPost(
      postId: 'post2',
      channelId: channelId,
      roomId: '!real:p2p-im.com',
      eventId: r'$post2',
      authorId: '@owner:p2p-im.com',
      authorName: 'Yanan',
      messageType: messageType,
      body: body,
      media: media,
      originServerTs:
          DateTime.parse('2026-06-06T10:21:00Z').millisecondsSinceEpoch,
    );
  }

  @override
  Future<List<AsChannelComment>> getChannelComments(
    String channelId,
    String postId, {
    int limit = 50,
    int beforeTs = 0,
  }) async {
    return const [];
  }

  @override
  Future<AsChannelComment> createChannelComment(
    String channelId,
    String postId, {
    required String messageType,
    required String body,
    Map<String, Object?> media = const {},
  }) async {
    createdCommentBody = body;
    return AsChannelComment(
      commentId: 'comment1',
      postId: postId,
      channelId: channelId,
      eventId: r'$comment1',
      authorId: '@owner:p2p-im.com',
      authorName: 'Yanan',
      messageType: messageType,
      body: body,
      media: media,
      originServerTs:
          DateTime.parse('2026-06-06T10:22:00Z').millisecondsSinceEpoch,
    );
  }

  @override
  Future<AsChannel> updateChannel(AsChannel draft) async {
    updatedChannel = draft;
    return draft;
  }

  String? toggledPostId;

  @override
  Future<AsChannelReaction> toggleChannelPostReaction(
    String channelId,
    String postId, {
    String reaction = 'like',
  }) async {
    toggledPostId = postId;
    return const AsChannelReaction(
      postId: 'post1',
      channelId: 'ch_real',
      reaction: 'like',
      active: true,
      reactionCount: 3,
    );
  }

  @override
  Future<List<AsChannelMember>> getChannelMembers(
    String channelId, {
    String status = '',
  }) async {
    return [
      const AsChannelMember(
        channelId: 'ch_real',
        userMxid: '@alice:p2p-liyanan.com',
        displayName: 'Alice',
        domain: 'p2p-liyanan.com',
        role: asChannelRoleMember,
        status: asChannelMemberStatusPending,
      ),
    ];
  }

  @override
  Future<AsChannel> approveChannelJoin(
    String channelId,
    String userMxid,
  ) async {
    approvedUserId = userMxid;
    return const AsChannel(
      channelId: 'ch_real',
      roomId: '!real:p2p-im.com',
      name: '产品公告',
      role: asChannelRoleOwner,
      memberStatus: asChannelMemberStatusJoined,
      pendingJoinCount: 0,
    );
  }

  @override
  Future<AsChannel> rejectChannelJoin(
    String channelId,
    String userMxid,
  ) async {
    rejectedUserId = userMxid;
    return const AsChannel(
      channelId: 'ch_real',
      roomId: '!real:p2p-im.com',
      name: '产品公告',
      role: asChannelRoleOwner,
      memberStatus: asChannelMemberStatusJoined,
      pendingJoinCount: 0,
    );
  }

  @override
  Future<void> updateChannelReadMarker(
    String channelId, {
    required String eventId,
    required int originServerTs,
  }) async {
    readMarkerChannelId = channelId;
    readMarkerEventId = eventId;
  }
}

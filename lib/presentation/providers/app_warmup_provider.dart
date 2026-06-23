import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';

import '../../data/as_call_session_store.dart';
import '../../data/as_client.dart';
import '../../data/channel_post_store.dart';
import '../../data/media_thumbnail_cache.dart';
import 'as_client_provider.dart';
import 'as_bootstrap_store_provider.dart';
import 'as_call_session_store_provider.dart';
import 'as_sync_cache_provider.dart';
import '../chat/call_timeline_events.dart';
import '../chat/chat_history_backfill_policy.dart';
import '../chat/chat_timeline_controller.dart';
import '../utils/avatar_url.dart';
import 'auth_provider.dart';
import 'channel_provider.dart';
import 'media_thumbnail_cache_provider.dart';
import 'profile_provider.dart';

typedef AsBootstrapLoader = Future<AsSyncBootstrap> Function();
typedef CachedAsBootstrapLoader = Future<AsSyncBootstrap?> Function();
typedef AsCallSessionLoader = Future<AsCallSession> Function(String callId);
typedef AsChannelPostsLoader = Future<List<AsChannelPost>> Function(
  String channelId, {
  int limit,
});
typedef RecentRoomEventsLoader = Future<List<Event>> Function(
  Room room,
  int limit,
);
typedef RecentRoomTimelinePrewarmer = Future<void> Function(
  Room room,
  int targetMessages,
);
typedef MatrixConversationSync = Future<void> Function();

abstract class AvatarPreloader {
  Future<void> preload(String url);
}

abstract class MediaThumbnailPreloader {
  Future<void> preload(Iterable<String> eventIds);
}

class FlutterAvatarPreloader implements AvatarPreloader {
  const FlutterAvatarPreloader({
    this.timeout = const Duration(seconds: 5),
  });

  final Duration timeout;

  @override
  Future<void> preload(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty || Uri.tryParse(trimmed) == null) return;

    final provider = NetworkImage(trimmed);
    final stream = provider.resolve(ImageConfiguration.empty);
    final completer = Completer<void>();
    var listenerRemoved = false;
    late final ImageStreamListener listener;

    void finish() {
      if (!listenerRemoved) {
        listenerRemoved = true;
        stream.removeListener(listener);
      }
      if (!completer.isCompleted) completer.complete();
    }

    listener = ImageStreamListener(
      (_, __) => finish(),
      onError: (_, __) => finish(),
    );
    stream.addListener(listener);

    try {
      await completer.future.timeout(timeout);
    } on TimeoutException {
      finish();
    } catch (_) {
      finish();
    }
  }
}

final avatarPreloaderProvider = Provider<AvatarPreloader>((ref) {
  return const FlutterAvatarPreloader();
});

final mediaThumbnailPreloaderProvider =
    Provider<MediaThumbnailPreloader>((ref) {
  return CacheMediaThumbnailPreloader(
    () => ref.read(mediaThumbnailCacheProvider.future),
  );
});

class CacheMediaThumbnailPreloader implements MediaThumbnailPreloader {
  const CacheMediaThumbnailPreloader(this._loadCache);

  final Future<MediaThumbnailCache> Function() _loadCache;

  @override
  Future<void> preload(Iterable<String> eventIds) async {
    final cache = await _loadCache();
    await cache.warm(eventIds);
  }
}

final appWarmupServiceProvider = Provider<AppWarmupService>((ref) {
  final bootstrapRepository = ref.watch(asBootstrapRepositoryProvider);
  final asClient = ref.watch(asClientProvider);
  return AppWarmupService(
    client: ref.watch(matrixClientProvider),
    avatarPreloader: ref.watch(avatarPreloaderProvider),
    mediaThumbnailPreloader: ref.watch(mediaThumbnailPreloaderProvider),
    loadCurrentUserProfile: () => ref.read(currentUserProfileProvider.future),
    syncMatrixConversations: () => ref.read(matrixClientProvider).oneShotSync(),
    loadCachedBootstrap: bootstrapRepository.readCached,
    loadBootstrap: bootstrapRepository.refresh,
    callSessionStore: DeferredAsCallSessionStore(
      () => ref.read(asCallSessionStoreProvider.future),
    ),
    loadCallSession: asClient.getCall,
    channelPostStore: DeferredChannelPostStore(
      () => ref.read(channelPostStoreProvider.future),
    ),
    loadChannelPosts: (channelId, {int limit = 50}) =>
        asClient.getChannelPosts(channelId, limit: limit),
    onBootstrapLoaded: (bootstrap) {
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
    },
  );
});

/// App 启动后的轻量预热。
///
/// 只预热首屏高概率使用的数据和图片，不做全量联系人/历史媒体同步。
final appWarmupProvider = FutureProvider<void>((ref) async {
  final auth = await ref.watch(authStateNotifierProvider.future);
  if (!auth.isLoggedIn) return;
  await ref.watch(appWarmupServiceProvider).warmup();
});

class AppWarmupService {
  AppWarmupService({
    required this.client,
    required this.avatarPreloader,
    this.mediaThumbnailPreloader,
    required this.loadCurrentUserProfile,
    this.syncMatrixConversations,
    this.loadBootstrap,
    this.loadCachedBootstrap,
    this.callSessionStore,
    this.loadCallSession,
    this.channelPostStore,
    this.loadChannelPosts,
    this.loadRecentRoomEvents,
    this.prewarmRecentRoomTimeline,
    this.onBootstrapLoaded,
    this.maxRoomAvatars = 20,
    this.maxMediaThumbnails = 40,
    this.maxCallSessions = 20,
    this.maxPrewarmRoomTimelines = 8,
    this.maxPrewarmChannels = 20,
    this.channelPostsPerChannel = 50,
    this.callContextEventsPerRoom = 80,
    this.preloadConcurrency = 3,
    this.profileTimeout = const Duration(seconds: 6),
    this.syncTimeout = const Duration(seconds: 10),
  });

  final Client client;
  final AvatarPreloader avatarPreloader;
  final MediaThumbnailPreloader? mediaThumbnailPreloader;
  final Future<Profile?> Function() loadCurrentUserProfile;
  final MatrixConversationSync? syncMatrixConversations;
  final AsBootstrapLoader? loadBootstrap;
  final CachedAsBootstrapLoader? loadCachedBootstrap;
  final AsCallSessionStore? callSessionStore;
  final AsCallSessionLoader? loadCallSession;
  final ChannelPostStore? channelPostStore;
  final AsChannelPostsLoader? loadChannelPosts;
  final RecentRoomEventsLoader? loadRecentRoomEvents;
  final RecentRoomTimelinePrewarmer? prewarmRecentRoomTimeline;
  final void Function(AsSyncBootstrap bootstrap)? onBootstrapLoaded;
  final int maxRoomAvatars;
  final int maxMediaThumbnails;
  final int maxCallSessions;
  final int maxPrewarmRoomTimelines;
  final int maxPrewarmChannels;
  final int channelPostsPerChannel;
  final int callContextEventsPerRoom;
  final int preloadConcurrency;
  final Duration profileTimeout;
  final Duration syncTimeout;

  Future<void> warmup() async {
    final cachedBootstrapFuture = _loadCachedBootstrapMetadata();
    final bootstrapFuture = _loadBootstrapMetadata();
    final profileFuture = _loadProfile();
    final matrixSyncFuture = _syncMatrixConversations();

    final cachedBootstrap = await cachedBootstrapFuture;
    final bootstrap = await bootstrapFuture ?? cachedBootstrap;
    final profile = await profileFuture;
    await matrixSyncFuture;

    final urls = <String>[];
    _addUnique(urls, profileAvatarHttpUrl(profile, client));
    if (bootstrap != null) {
      for (final room in bootstrap.rooms.take(maxRoomAvatars)) {
        _addUnique(urls, avatarHttpUrl(client, room.avatarUrl));
      }
      for (final contact in bootstrap.contacts.take(maxRoomAvatars)) {
        _addUnique(urls, avatarHttpUrl(client, contact.avatarUrl));
      }
      for (final channel in bootstrap.channels.take(maxRoomAvatars)) {
        _addUnique(urls, avatarHttpUrl(client, channel.avatarUrl));
      }
    }

    for (final room in _recentJoinedRooms().take(maxRoomAvatars)) {
      _addUnique(urls, roomAvatarHttpUrl(room));
    }

    await Future.wait([
      _preload(urls),
      _preloadMediaThumbnails(_mediaThumbnailEventIds()),
      _prewarmRecentRoomTimelines(),
      _prewarmCallSessions(),
      _prewarmChannelPosts(bootstrap),
    ]);
  }

  Future<AsSyncBootstrap?> _loadCachedBootstrapMetadata() async {
    final loader = loadCachedBootstrap;
    if (loader == null) return null;
    try {
      final bootstrap = await loader();
      if (bootstrap == null) return null;
      if (!asBootstrapBelongsToUser(bootstrap, client.userID)) {
        debugPrint(
          'app warmup ignored cached bootstrap for ${bootstrap.user.userId}; '
          'current user is ${client.userID}',
        );
        return null;
      }
      onBootstrapLoaded?.call(bootstrap);
      return bootstrap;
    } catch (e) {
      debugPrint('app warmup cached bootstrap failed: $e');
      return null;
    }
  }

  Future<AsSyncBootstrap?> _loadBootstrapMetadata() async {
    final loader = loadBootstrap;
    if (loader == null) return null;
    try {
      final bootstrap = await loader().timeout(syncTimeout);
      if (!asBootstrapBelongsToUser(bootstrap, client.userID)) {
        debugPrint(
          'app warmup ignored bootstrap for ${bootstrap.user.userId}; '
          'current user is ${client.userID}',
        );
        return null;
      }
      onBootstrapLoaded?.call(bootstrap);
      return bootstrap;
    } catch (e) {
      debugPrint('app warmup bootstrap failed: $e');
      return null;
    }
  }

  Future<Profile?> _loadProfile() async {
    try {
      return await loadCurrentUserProfile().timeout(profileTimeout);
    } catch (e) {
      debugPrint('app warmup profile failed: $e');
      return null;
    }
  }

  Future<void> _syncMatrixConversations() async {
    final sync = syncMatrixConversations;
    if (sync == null || !client.isLogged()) return;
    try {
      await sync().timeout(syncTimeout);
    } catch (e) {
      debugPrint('app warmup Matrix conversation sync failed: $e');
    }
  }

  List<Room> _recentJoinedRooms() {
    final rooms = client.rooms
        .where((room) => room.membership == Membership.join)
        .toList();
    rooms.sort((a, b) => _roomSortTime(b).compareTo(_roomSortTime(a)));
    return rooms;
  }

  int _roomSortTime(Room room) {
    return room.lastEvent?.originServerTs.millisecondsSinceEpoch ?? 0;
  }

  Future<void> _preload(List<String> urls) async {
    if (urls.isEmpty) return;
    final queue = Queue<String>.from(urls);
    final workerCount =
        queue.length < preloadConcurrency ? queue.length : preloadConcurrency;
    await Future.wait(
      List.generate(workerCount, (_) async {
        while (queue.isNotEmpty) {
          final url = queue.removeFirst();
          try {
            await avatarPreloader.preload(url);
          } catch (e) {
            debugPrint('avatar preload failed: $e');
          }
        }
      }),
    );
  }

  Future<void> _preloadMediaThumbnails(Iterable<String> eventIds) async {
    final preloader = mediaThumbnailPreloader;
    if (preloader == null) return;
    final ids = eventIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .take(maxMediaThumbnails)
        .toList(growable: false);
    if (ids.isEmpty) return;
    try {
      await preloader.preload(ids);
    } catch (e) {
      debugPrint('media thumbnail preload failed: $e');
    }
  }

  Future<void> _prewarmRecentRoomTimelines() async {
    final rooms = _recentJoinedRooms().take(maxPrewarmRoomTimelines).toList();
    if (rooms.isEmpty) return;
    final queue = Queue<Room>.from(rooms);
    final workerCount =
        queue.length < preloadConcurrency ? queue.length : preloadConcurrency;
    await Future.wait(
      List.generate(workerCount, (_) async {
        while (queue.isNotEmpty) {
          final room = queue.removeFirst();
          try {
            final injected = prewarmRecentRoomTimeline;
            if (injected != null) {
              await injected(room, chatOpenLocalHistoryTargetMessages);
              continue;
            }
            final timeline = await ChatTimelineController(
              room: room,
              rebuild: () {},
              debugLabel: 'warmup',
            ).openLocalTimelineForPrewarm();
            timeline?.cancelSubscriptions();
          } catch (e) {
            debugPrint('recent room timeline prewarm failed: $e');
          }
        }
      }),
    );
  }

  Future<void> _prewarmCallSessions() async {
    final store = callSessionStore;
    final loader = loadCallSession;
    if (store == null || loader == null) return;
    final callIds = await _recentAsCallIds();
    for (final callId in callIds.take(maxCallSessions)) {
      try {
        final cached = await store.read(callId);
        if (!shouldRefreshAsCallSessionSnapshot(cached)) continue;
        final fresh = await loader(callId).timeout(syncTimeout);
        await store.upsert(fresh);
      } catch (e) {
        debugPrint('P2P call session prewarm failed: $e');
      }
    }
  }

  Future<void> _prewarmChannelPosts(AsSyncBootstrap? bootstrap) async {
    final store = channelPostStore;
    final loader = loadChannelPosts;
    if (store == null || loader == null || bootstrap == null) return;
    final channels = bootstrap.channels
        .where((channel) =>
            channel.channelId.trim().isNotEmpty &&
            (channel.memberStatus.trim().isEmpty ||
                channel.memberStatus == asChannelMemberStatusJoined))
        .toList(growable: false)
      ..sort((a, b) => _channelSortTime(b).compareTo(_channelSortTime(a)));
    final queue = Queue<AsSyncRoomSummary>.from(
      channels.take(maxPrewarmChannels),
    );
    if (queue.isEmpty) return;
    final workerCount =
        queue.length < preloadConcurrency ? queue.length : preloadConcurrency;
    await Future.wait(
      List.generate(workerCount, (_) async {
        while (queue.isNotEmpty) {
          final channel = queue.removeFirst();
          try {
            final posts = await loader(
              channel.channelId,
              limit: channelPostsPerChannel,
            ).timeout(syncTimeout);
            await store.upsertChannel(channel.channelId, posts);
          } catch (e) {
            debugPrint('channel posts prewarm failed: $e');
          }
        }
      }),
    );
  }

  int _channelSortTime(AsSyncRoomSummary channel) {
    return channel.lastActivityAt?.millisecondsSinceEpoch ?? 0;
  }

  Future<List<String>> _recentAsCallIds() async {
    final ids = <String>[];
    final seen = <String>{};
    void emit(String? callId) {
      final trimmed = callId?.trim() ?? '';
      if (trimmed.isEmpty || seen.contains(trimmed)) return;
      seen.add(trimmed);
      ids.add(trimmed);
    }

    for (final room in _recentJoinedRooms()) {
      try {
        final events = await _recentRoomEvents(room);
        final context = callRecordContextEventsForTimeline(events);
        final visible = chatDisplayEventsForTimeline(events);
        for (final event in visible) {
          if (!isCallRecordEvent(event)) continue;
          emit(asCallIdForCallRecord(event, context));
        }
      } catch (e) {
        debugPrint('recent P2P call id scan failed: $e');
      }
      if (ids.length >= maxCallSessions) break;
    }
    return ids;
  }

  Future<List<Event>> _recentRoomEvents(Room room) async {
    final injectedLoader = loadRecentRoomEvents;
    if (injectedLoader != null) {
      return injectedLoader(room, callContextEventsPerRoom);
    }
    final eventsById = <String, Event>{};
    void add(Event? event) {
      if (event == null || event.eventId.trim().isEmpty) return;
      eventsById[event.eventId.trim()] = event;
    }

    add(room.lastEvent);
    final database = client.database;
    if (database != null) {
      try {
        final stored = await database.getEventList(
          room,
          start: 0,
          limit: callContextEventsPerRoom,
        );
        for (final event in stored) {
          add(event);
        }
      } catch (e) {
        debugPrint('local call event scan failed: $e');
      }
    }
    final events = eventsById.values.toList(growable: false)
      ..sort((a, b) => a.originServerTs.compareTo(b.originServerTs));
    return events;
  }

  Iterable<String> _mediaThumbnailEventIds() sync* {
    final yielded = <String>{};
    void emit(String eventId) {
      final trimmed = eventId.trim();
      if (trimmed.isEmpty || yielded.contains(trimmed)) return;
      yielded.add(trimmed);
    }

    for (final room in _recentJoinedRooms()) {
      final event = room.lastEvent;
      if (event == null || !_isImageEvent(event)) continue;
      emit(event.eventId);
    }

    yield* yielded;
  }

  void _addUnique(List<String> urls, String? url) {
    if (url == null || url.trim().isEmpty || urls.contains(url)) return;
    urls.add(url);
  }

  bool _isImageEvent(Event event) {
    return event.type == EventTypes.Message &&
        event.messageType == MessageTypes.Image &&
        event.eventId.trim().isNotEmpty;
  }
}

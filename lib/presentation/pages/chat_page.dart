import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/auth_provider.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_call_session_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_gateway_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../widgets/portal_avatar.dart';
import '../providers/local_message_order_provider.dart';
import '../providers/local_outbox_provider.dart';
import '../providers/media_thumbnail_cache_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/recovered_unread_store_provider.dart';
import '../channel/channel_share.dart';
import '../groups/group_invite_card.dart';
import '../groups/group_invite_content.dart';
import '../groups/group_invite_join_flow.dart';
import '../chat/cached_thumbnail_image.dart';
import '../chat/chat_attachment_panel.dart';
import '../chat/chat_capsule_chrome.dart';
import '../chat/chat_glass_background.dart';
import '../chat/chat_history_backfill_policy.dart';
import '../chat/chat_message_cards.dart';
import '../chat/call_timeline_events.dart';
import '../chat/chat_record_detail_page.dart';
import '../chat/chat_record_forwarding.dart';
import '../chat/chat_media_warmup.dart';
import '../chat/chat_media_send_flow.dart';
import '../chat/chat_timeline_items.dart';
import '../chat/chat_voice_player.dart';
import '../chat/chat_voice_recorder.dart';
import '../chat/favorite_message_mapper.dart';
import '../chat/local_outbox_image_thumb.dart';
import '../chat/product_media_outbox_flow.dart';
import '../chat/product_room_media_send_flow.dart';
import '../mock/mock_data.dart';
import '../mock/mcp_policy.dart';
import '../mock/mock_mcp_client.dart';
import '../utils/contact_display_name.dart';
import '../utils/direct_contact_status.dart';
import '../utils/avatar_url.dart';
import '../utils/chat_event_attachment.dart';
import '../utils/chat_file_actions.dart';
import '../utils/read_marker_sync.dart';
import '../utils/recovered_unread_events.dart';
import '../utils/chat_time_format.dart';
import '../utils/message_preview.dart';
import '../utils/room_read_state.dart';
import '../widgets/agent_message_body.dart';
import '../widgets/async_image_preview.dart';
import '../widgets/tool_call_bubble.dart';
import '../../data/as_client.dart';
import '../../data/as_call_session_store.dart';
import '../../data/as_gateway_client.dart';
import '../../data/local_outbox_store.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

const _mockAuthEnabled = bool.fromEnvironment(
  'P2P_MATRIX_MOCK_AUTH',
  defaultValue: false,
);

// ═══════════════════════════════════════════════════════════════════════════
// CHAT PAGE — index.html `s-chat` 1:1 复刻
//
// 真实数据通路（Matrix）+ Mock 数据通路（_MockChatScaffold）并存，业务逻辑全部
// 保留；仅 widget 树/视觉按 `s-chat` (index.html 第 392-505 行) 与 `s-agent`
// (第 245-371 行) 重写：头部 / 气泡 / 输入栏 / +号面板 / 表情面板 / 长按上下文
// 菜单 / 多选栏 / 回复栏。
// ═══════════════════════════════════════════════════════════════════════════

String _formatMsgTime(DateTime dt) {
  return formatChatMessageTime(dt);
}

bool _isProductDirectRoomForChat(Room room, AsSyncCacheState syncCache) {
  return isProductDirectContactRoom(
        room,
        acceptedRoomIds: syncCache.acceptedDirectRoomIds,
      ) ||
      syncCache.contactStatusForRoom(room.id) != null ||
      // Old Matrix rooms can lack m.direct / p2p.room.kind after delete/re-add
      // flows. A joined room with exactly one non-agent peer must still use
      // AS as the authority for whether it is a valid private chat.
      joinedPersonPeerMxid(room) != null;
}

void _openChatRecordDetail(
  BuildContext context,
  ChatRecordPayload payload,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChatRecordDetailPage(payload: payload),
    ),
  );
}

bool _canSendRoomMessage(Room room, AsSyncCacheState syncCache) {
  if (isPortalAgentDirectRoom(room)) return true;
  final isProductDirect = _isProductDirectRoomForChat(room, syncCache);
  if (!isProductDirect) return room.membership == Membership.join;
  if (syncCache.acceptedDirectRoomIds.contains(room.id)) {
    return true;
  }
  return syncCache.isPendingContactRoom(room.id) &&
      joinedPersonPeerMxid(room) != null;
}

/// 字节数 → 人类可读，如 `2.8 MB`。
Future<void> _popChatOrHome(BuildContext context) async {
  final didPop = await Navigator.of(context).maybePop();
  if (!context.mounted || didPop) return;
  context.go('/home');
}

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _msgCtrl = TextEditingController();
  Timeline? _timeline;
  bool _loading = true;
  bool _readMarkerInFlight = false;
  bool _readMarkerQueued = false;
  bool _thumbnailWarmupInFlight = false;
  bool _missingRoomSyncStarted = false;
  bool _missingRoomSyncFailed = false;
  StreamSubscription<SyncUpdate>? _roomSyncSub;
  final Set<String> _warmedThumbnailEventIds = {};
  final Set<String> _retryingOutboxIds = {};
  final Set<String> _downloadingFileEventIds = {};
  final Set<String> _downloadedFileEventIds = {};
  final Set<String> _downloadingImageEventIds = {};
  final Set<String> _downloadedImageEventIds = {};
  final Set<String> _favoritingEventIds = {};
  final Set<String> _joiningGroupInviteEventIds = {};
  final Map<String, AsCallSession> _asCallSessionCache = {};
  final Set<String> _loadingAsCallIds = {};
  final ChatInitialEntranceRegistry _initialTimelineEntrances =
      ChatInitialEntranceRegistry();
  Timer? _initialTimelineEntranceTimer;

  // s-chat 视觉状态
  bool _showPlusPanel = false;
  bool _showEmojiPanel = false;
  bool _multiSelect = false;
  final Set<String> _selected = {};
  Event? _replyTo;
  final ChatVoicePlayer _voicePlayer = ChatVoicePlayer();
  final ChatVoiceRecorder _voiceRecorder = ChatVoiceRecorder();
  bool _stoppingVoiceRecording = false;

  Room? get _room => ref.read(matrixClientProvider).getRoomById(widget.roomId);

  void _onVoicePlaybackChanged() {
    if (mounted) setState(() {});
  }

  /// 未登录且 roomId 命中演示数据时走本地渲染；
  /// 已登录则一律走真 Matrix timeline。
  bool get _useMock {
    final isLoggedIn =
        ref.read(authStateNotifierProvider).valueOrNull?.isLoggedIn ?? false;
    return (_mockAuthEnabled || !isLoggedIn) &&
        MockData.byId(widget.roomId) != null;
  }

  Object _timelineItemKey(ChatTimelineItem<Event, LocalOutboxItem> item) {
    return item.when<Object>(
      event: (event) {
        final id = event.eventId.trim();
        return id.isEmpty
            ? 'event-object-${identityHashCode(event)}'
            : 'event-$id';
      },
      outbox: (outbox) => 'outbox-${outbox.id}',
    );
  }

  void _seedInitialTimelineEntrances(List<Object> keys) {
    if (!_initialTimelineEntrances.seed(keys)) return;
    _initialTimelineEntranceTimer?.cancel();
    _initialTimelineEntranceTimer = Timer(
      ChatInitialEntranceRegistry.closeDelay,
      () {
        _initialTimelineEntrances.close();
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _voicePlayer.playback.addListener(_onVoicePlaybackChanged);
    if (_useMock) {
      _loading = false;
      return;
    }
    _roomSyncSub = ref.read(matrixClientProvider).onSync.stream.listen((_) {
      if (!mounted || _room == null) return;
      if (_timeline == null) {
        unawaited(_initTimeline());
      }
      setState(() {
        _missingRoomSyncFailed = false;
      });
    });
    _initTimeline();
  }

  Future<void> _initTimeline() async {
    final room = _room;
    if (room == null) return;
    void rebuild() {
      if (mounted) setState(() {});
      _removeRecoveredUnreadTimelineDuplicates();
      _scheduleTimelineThumbnailWarmup();
      unawaited(_markCurrentTimelineRead());
    }

    if (markRoomLocallyRead(room) && mounted) setState(() {});
    try {
      _timeline = await room.getTimeline(
        onUpdate: rebuild,
        onChange: (_) => rebuild(),
        onInsert: (_) => rebuild(),
        onRemove: (_) => rebuild(),
      );
    } on Object catch (e) {
      debugPrint('getTimeline failed: $e');
    }
    if (mounted) setState(() => _loading = false);
    _removeRecoveredUnreadTimelineDuplicates();
    _scheduleTimelineThumbnailWarmup();
    unawaited(_markCurrentTimelineRead());
    final tl = _timeline;
    if (tl != null) unawaited(_backfillLocalStoredHistory(tl));
  }

  bool _isKnownConversationRoom(AsSyncCacheState syncCache) {
    final roomId = widget.roomId.trim();
    if (roomId.isEmpty) return false;
    if (syncCache.contactForRoom(roomId) != null) return true;
    final bootstrap = syncCache.bootstrap;
    if (bootstrap == null) return false;
    if (bootstrap.agentRoomId.trim() == roomId) return true;
    bool hasRoom(List<AsSyncRoomSummary> rooms) {
      return rooms.any((room) => room.roomId.trim() == roomId);
    }

    return hasRoom(bootstrap.rooms) || hasRoom(bootstrap.groups);
  }

  void _ensureMissingRoomSync() {
    if (_missingRoomSyncStarted) return;
    _missingRoomSyncStarted = true;
    _missingRoomSyncFailed = false;
    unawaited(_syncMissingRoom());
  }

  void _retryMissingRoomSync() {
    setState(() {
      _missingRoomSyncStarted = false;
      _missingRoomSyncFailed = false;
    });
    _ensureMissingRoomSync();
  }

  Future<void> _syncMissingRoom() async {
    try {
      await ref
          .read(matrixClientProvider)
          .oneShotSync()
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('missing chat room sync failed: $e');
    }
    if (!mounted) return;
    if (_room != null && _timeline == null) {
      await _initTimeline();
      return;
    }
    if (mounted) {
      setState(() => _missingRoomSyncFailed = true);
    }
  }

  Widget _missingRoomScaffold(
    String message, {
    bool loading = false,
    VoidCallback? onRetry,
  }) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: t.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                CircularProgressIndicator(color: t.accent),
                const SizedBox(height: 16),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTheme.sans(size: 15, color: t.textMute),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Symbols.sync),
                  label: const Text('重试'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _backfillLocalStoredHistory(Timeline timeline) async {
    var attempts = 0;
    while (attempts < chatOpenLocalHistoryMaxAttempts &&
        timeline.canRequestHistory) {
      if (!shouldBackfillLocalChatOpenHistory(
        timelineEvents: timeline.events,
        hasStoredOlderEvents: true,
      )) {
        break;
      }

      try {
        final database = timeline.room.client.database;
        if (database == null) break;
        final storedEvents = await database.getEventList(
          timeline.room,
          start: timeline.events.length,
          limit: chatOpenLocalHistoryPageSize,
        );
        if (storedEvents.isEmpty) break;
        await _hydrateStoredEventSenders(timeline.room, storedEvents);
        timeline.events.addAll(storedEvents);
      } on Object catch (e) {
        debugPrint('local timeline backfill failed: $e');
        break;
      }
      attempts++;
    }
    if (mounted) setState(() {});
    _scheduleTimelineThumbnailWarmup();
    unawaited(_markCurrentTimelineRead());
  }

  Future<void> _hydrateStoredEventSenders(
    Room room,
    Iterable<Event> events,
  ) async {
    final database = room.client.database;
    if (database == null) return;
    for (final event in events) {
      if (room.getState(EventTypes.RoomMember, event.senderId) != null) {
        continue;
      }
      final user = await database.getUser(event.senderId, room);
      if (user != null) room.setState(user);
    }
  }

  void _scheduleTimelineThumbnailWarmup() {
    if (_thumbnailWarmupInFlight) return;
    final timeline = _timeline;
    if (timeline == null) return;
    final ids = thumbnailEventIdsForEvents(timeline.events)
        .where((id) => !_warmedThumbnailEventIds.contains(id))
        .toList(growable: false);
    if (ids.isEmpty) return;
    _warmedThumbnailEventIds.addAll(ids);
    _thumbnailWarmupInFlight = true;
    unawaited(() async {
      try {
        final cache = await ref.read(mediaThumbnailCacheProvider.future);
        await cache.warm(ids);
      } on Object catch (e) {
        debugPrint('chat thumbnail warmup failed: $e');
      } finally {
        _thumbnailWarmupInFlight = false;
        if (mounted) _scheduleTimelineThumbnailWarmup();
      }
    }());
  }

  void _scheduleAsCallSessionWarmup(
    Iterable<Event> visibleEvents,
    Iterable<Event> contextEvents,
  ) {
    final ids = <String>{};
    for (final event in visibleEvents) {
      if (!isCallRecordEvent(event)) continue;
      final callId = asCallIdForCallRecord(event, contextEvents);
      if (callId == null || _asCallSessionCache.containsKey(callId)) {
        continue;
      }
      ids.add(callId);
    }
    ids.removeWhere(_loadingAsCallIds.contains);
    if (ids.isEmpty) return;
    _loadingAsCallIds.addAll(ids);
    for (final id in ids) {
      unawaited(_loadAsCallSession(id));
    }
  }

  Future<void> _loadAsCallSession(String callId) async {
    final storeFuture = ref.read(asCallSessionStoreProvider.future);
    try {
      final store = await storeFuture;
      final cached = await store.read(callId);
      if (cached != null && mounted) {
        setState(() {
          _asCallSessionCache[callId] = cached;
        });
      }
      if (!shouldRefreshAsCallSessionSnapshot(cached)) {
        _loadingAsCallIds.remove(callId);
        return;
      }
    } on Object catch (e) {
      debugPrint('load cached AS call session failed: $e');
    }

    try {
      final session = await ref.read(asClientProvider).getCall(callId);
      try {
        final store = await storeFuture;
        await store.upsert(session);
      } on Object catch (e) {
        debugPrint('persist AS call session failed: $e');
      }
      if (!mounted) return;
      setState(() {
        _asCallSessionCache[callId] = session;
      });
    } on Object catch (e) {
      debugPrint('load AS call session failed: $e');
    } finally {
      _loadingAsCallIds.remove(callId);
    }
  }

  Future<void> _markCurrentTimelineRead() async {
    final room = _room;
    if (room == null) return;
    final timeline = _timeline;
    final markerEvent =
        timeline == null ? null : latestSyncedMessageEvent(timeline);
    final recoveredMarker =
        markerEvent == null ? _latestRecoveredUnreadMessage() : null;
    final readAt = markerEvent?.originServerTs ??
        recoveredMarker?.timestamp ??
        DateTime.now().toUtc();
    final changed = markRoomLocallyRead(room);
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.withRoomUnreadCleared(room.id, readAt: readAt),
        );
    if (changed && mounted) setState(() {});

    if (timeline == null) return;
    if (_readMarkerInFlight) {
      _readMarkerQueued = true;
      return;
    }

    _readMarkerInFlight = true;
    try {
      await timeline.setReadMarker(eventId: markerEvent?.eventId);
      if (markerEvent != null) {
        unawaited(_syncAsReadMarker(room, markerEvent).then((synced) {
          if (!synced) return;
          ref.read(asSyncCacheProvider.notifier).update(
                (state) => state.withRoomUnreadCleared(
                  room.id,
                  readAt: markerEvent.originServerTs,
                ),
              );
          unawaited(_clearRecoveredUnreadForRoom());
        }));
      } else {
        if (recoveredMarker != null) {
          unawaited(
            _syncAsReadMarkerForRecovered(room, recoveredMarker).then((synced) {
              if (!synced) return;
              ref.read(asSyncCacheProvider.notifier).update(
                    (state) => state.withRoomUnreadCleared(
                      room.id,
                      readAt: recoveredMarker.timestamp,
                    ),
                  );
              unawaited(_clearRecoveredUnreadForRoom());
            }),
          );
        }
      }
    } on Object catch (e) {
      debugPrint('setReadMarker failed: $e');
    } finally {
      _readMarkerInFlight = false;
      if (_readMarkerQueued && mounted) {
        _readMarkerQueued = false;
        unawaited(_markCurrentTimelineRead());
      }
    }
  }

  Future<bool> _syncAsReadMarker(Room room, Event event) async {
    try {
      await updateAsReadMarkerForEvent(
        asClient: ref.read(asClientProvider),
        room: room,
        event: event,
      );
      return true;
    } on Object catch (e) {
      debugPrint('AS read marker sync failed: $e');
      return false;
    }
  }

  Future<bool> _syncAsReadMarkerForRecovered(
    Room room,
    AsUnreadMessage message,
  ) async {
    try {
      await ref.read(asClientProvider).updateReadMarker(
            room.id,
            message.eventId,
            message.timestamp ?? DateTime.now().toUtc(),
          );
      return true;
    } on Object catch (e) {
      debugPrint('AS recovered read marker sync failed: $e');
      return false;
    }
  }

  AsUnreadMessage? _latestRecoveredUnreadMessage() {
    final messages = ref
        .read(asSyncCacheProvider)
        .unreadMessagesForRoom(widget.roomId)
        .where((message) => message.eventId.isNotEmpty)
        .toList();
    if (messages.isEmpty) return null;
    messages.sort((a, b) {
      final at = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return at.compareTo(bt);
    });
    return messages.last;
  }

  void _removeRecoveredUnreadTimelineDuplicates() {
    final timeline = _timeline;
    if (timeline == null) return;
    final timelineEventIds = timeline.events
        .where((event) => event.eventId.isNotEmpty)
        .map((event) => event.eventId)
        .toSet();
    if (timelineEventIds.isEmpty) return;
    final duplicateIds = ref
        .read(asSyncCacheProvider)
        .unreadMessagesForRoom(widget.roomId)
        .where((message) => timelineEventIds.contains(message.eventId))
        .map((message) => message.eventId)
        .toSet();
    if (duplicateIds.isEmpty) return;
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.withoutUnreadEvents(duplicateIds),
        );
    unawaited(_removePersistedRecoveredUnreadEvents(duplicateIds));
  }

  Future<void> _removePersistedRecoveredUnreadEvents(
      Set<String> eventIds) async {
    try {
      final store = await ref.read(recoveredUnreadStoreProvider.future);
      await store.removeEvents(eventIds);
    } on Object catch (e) {
      debugPrint('remove recovered unread duplicates failed: $e');
    }
  }

  Future<void> _clearRecoveredUnreadForRoom() async {
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.withoutUnreadRoom(widget.roomId),
        );
    try {
      final store = await ref.read(recoveredUnreadStoreProvider.future);
      await store.removeRoom(widget.roomId);
    } on Object catch (e) {
      debugPrint('clear recovered unread room failed: $e');
    }
  }

  @override
  void dispose() {
    _roomSyncSub?.cancel();
    _timeline?.cancelSubscriptions();
    _initialTimelineEntranceTimer?.cancel();
    _voicePlayer.playback.removeListener(_onVoicePlaybackChanged);
    unawaited(_voicePlayer.dispose());
    unawaited(_voiceRecorder.dispose());
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final room = _room;
    if (room == null) return;
    final replyTo = _replyTo;
    final syncCache = ref.read(asSyncCacheProvider);
    if (!_canSendRoomMessage(room, syncCache)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('对方接受好友请求后才能发送消息')),
      );
      return;
    }
    _msgCtrl.clear();
    setState(() => _replyTo = null);
    try {
      if (isPortalAgentDirectRoom(room)) {
        await room.sendTextEvent(text, inReplyTo: replyTo);
      } else if (_isProductDirectRoomForChat(room, syncCache)) {
        await ref.read(asClientProvider).sendRoomMessage(
              room.id,
              text,
              replyToEventId: replyTo?.eventId,
            );
        await ref.read(matrixClientProvider).oneShotSync();
      } else {
        await room.sendTextEvent(text, inReplyTo: replyTo);
      }
    } on Object catch (e) {
      if (!mounted) return;
      _msgCtrl.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(productSendFailureMessage(e))),
      );
    }
  }

  void _togglePlus() => setState(() {
        _showPlusPanel = !_showPlusPanel;
        if (_showPlusPanel) _showEmojiPanel = false;
      });

  void _toggleEmoji() => setState(() {
        _showEmojiPanel = !_showEmojiPanel;
        if (_showEmojiPanel) _showPlusPanel = false;
      });

  void _closePanels() => setState(() {
        _showPlusPanel = false;
        _showEmojiPanel = false;
      });

  void _startVoiceRecording() {
    unawaited(_startVoiceRecordingAsync());
  }

  Future<void> _startVoiceRecordingAsync() async {
    final room = _room;
    if (room == null) return;
    if (!_canSendRoomMessage(room, ref.read(asSyncCacheProvider))) {
      _showPendingContactToast(context);
      return;
    }
    try {
      await _voiceRecorder.start();
    } on ChatVoiceRecorderException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message), duration: const Duration(seconds: 2)),
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('语音录制失败：$e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _stopVoiceRecording() {
    unawaited(_stopVoiceRecordingAsync());
  }

  Future<void> _stopVoiceRecordingAsync() async {
    if (_stoppingVoiceRecording) return;
    _stoppingVoiceRecording = true;
    try {
      final recording = await _voiceRecorder.stop();
      if (recording == null) return;
      if (recording.durationMs < 700) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('说话时间太短'),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
      await _sendVoiceRecording(recording);
    } finally {
      _stoppingVoiceRecording = false;
    }
  }

  void _cancelVoiceRecording() {
    unawaited(_voiceRecorder.cancel());
  }

  Future<void> _sendVoiceRecording(ChatVoiceRecording recording) async {
    final room = _room;
    if (room == null) return;
    final replyTo = _replyTo;
    final attachment = ChatMediaAttachment.audio(
      name: recording.filename,
      bytes: recording.bytes,
      mimeType: recording.mimeType,
      durationMs: recording.durationMs,
    );
    final syncCache = ref.read(asSyncCacheProvider);
    setState(() => _replyTo = null);
    if (_isProductDirectRoomForChat(room, syncCache) &&
        !isPortalAgentDirectRoom(room)) {
      await sendProductMediaWithPendingState(
        messenger: ScaffoldMessenger.of(context),
        attachment: attachment,
        sendAttachment: createProductRoomMediaSender(
          matrixClient: ref.read(matrixClientProvider),
          asClient: ref.read(asClientProvider),
          roomId: widget.roomId,
        ),
        thumbnailCacheFuture: null,
        onStarted: () => _addPendingFileUpload(attachment),
        onDelivered: _recordDeliveredMediaUpload,
        onSucceeded: _removePendingMediaUpload,
        onFailed: _failPendingMediaUpload,
      );
      return;
    }

    try {
      await room.sendFileEvent(
        MatrixFile.fromMimeType(
          bytes: recording.bytes,
          name: recording.filename,
          mimeType: recording.mimeType,
        ),
        inReplyTo: replyTo,
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _replyTo = replyTo);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(productSendFailureMessage(e))),
      );
    }
  }

  Future<void> _onLongPressEvent(BuildContext ctx, Event e, Offset pos) async {
    final action = await _showMsgContextMenu(
      ctx,
      pos,
      canEdit: _canEditEvent(e),
      canRecall: e.canRedact,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: e.body));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已复制'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        break;
      case 'forward':
        await _forwardEvents(
          [e],
          sourceName: _sourceNameForCurrentRoom(),
          sourceRoomType: _favoriteRoomType(_room),
        );
        break;
      case 'quote':
        setState(() => _replyTo = e);
        break;
      case 'multi':
        setState(() {
          _multiSelect = true;
          _selected.add(e.eventId);
        });
        break;
      case 'delete':
        await _deleteEventForMe(e);
        break;
      case 'edit':
        await _editEvent(e);
        break;
      case 'recall':
        await _recallEvent(e);
        break;
      case 'fav':
        await _favoriteEvent(e);
        break;
    }
  }

  bool _canEditEvent(Event event) {
    final room = _room;
    if (room == null || event.room.id != room.id) return false;
    return event.senderId == room.client.userID &&
        event.type == EventTypes.Message &&
        event.messageType == MessageTypes.Text &&
        event.plaintextBody.trim().isNotEmpty &&
        !event.redacted;
  }

  Future<void> _editEvent(Event event) async {
    if (!_canEditEvent(event)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('只能编辑自己发送的文本消息')),
      );
      return;
    }
    final controller = TextEditingController(text: event.plaintextBody);
    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final t = dialogContext.tk;
        return AlertDialog(
          title: Text(
            '编辑消息',
            style: AppTheme.sans(size: 17, weight: FontWeight.w600),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: '输入消息内容',
              hintStyle: AppTheme.sans(size: 15, color: t.textMute),
            ),
            style: AppTheme.sans(size: 15, color: t.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                '取消',
                style: AppTheme.sans(size: 15, color: t.textMute),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(
                '保存',
                style: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: t.accent,
                ),
              ),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || next == null) return;
    if (next.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('消息内容不能为空')),
      );
      return;
    }
    try {
      await event.room.sendTextEvent(next, editEventId: event.eventId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('消息已编辑')),
      );
    } on Object catch (err) {
      debugPrint('edit message failed: $err');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('编辑消息失败：$err')),
      );
    }
  }

  Future<void> _recallEvent(Event event) async {
    if (!event.canRedact) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有权限撤回该消息')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final t = dialogContext.tk;
        return AlertDialog(
          title: Text(
            '撤回消息',
            style: AppTheme.sans(size: 17, weight: FontWeight.w600),
          ),
          content: Text(
            '撤回后，对方也将看不到这条消息。',
            style: AppTheme.sans(size: 15, color: t.textMute),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                '取消',
                style: AppTheme.sans(size: 15, color: t.textMute),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                '撤回',
                style: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: t.danger,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await event.redactEvent(reason: '撤回消息');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('消息已撤回')),
      );
    } on Object catch (err) {
      debugPrint('recall message failed: $err');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('撤回消息失败：$err')),
      );
    }
  }

  String _sourceNameForCurrentRoom() {
    final room = _room;
    if (room == null) return '当前会话';
    final syncCache = ref.read(asSyncCacheProvider);
    final contact = syncCache.contactForRoom(widget.roomId);
    final mxid = productDirectPeerMxid(room) ??
        joinedPersonPeerMxid(room) ??
        contact?.userId ??
        '';
    if (isPortalAgentDirectRoom(room)) return 'Agent';
    return directContactDisplayName(contact, room, peerMxid: mxid);
  }

  Future<void> _favoriteEvent(Event event) async {
    final eventId = event.eventId.trim();
    if (eventId.isEmpty || _favoritingEventIds.contains(eventId)) return;
    if (mounted) {
      setState(() => _favoritingEventIds.add(eventId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在收藏到我的节点…'),
          duration: Duration(milliseconds: 900),
        ),
      );
    }
    try {
      final draft = await _favoriteDraftForEvent(event);
      await ref.read(asClientProvider).favoriteMessage(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已收藏'),
          duration: Duration(seconds: 1),
        ),
      );
    } on Object catch (err) {
      debugPrint('favorite message failed: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('收藏失败：$err')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _favoritingEventIds.remove(eventId));
      }
    }
  }

  Future<void> _favoriteSelectedEvents(List<Event> events) async {
    final selectedEvents = events
        .where((event) => _selected.contains(event.eventId))
        .toList(growable: false);
    if (selectedEvents.isEmpty) return;
    for (final event in selectedEvents) {
      await _favoriteEvent(event);
    }
    if (!mounted) return;
    setState(() {
      _multiSelect = false;
      _selected.clear();
    });
  }

  Future<void> _forwardSelectedEvents(
    List<Event> events, {
    required String sourceName,
    required String sourceRoomType,
  }) async {
    final selectedEvents = events
        .where((event) => _selected.contains(event.eventId))
        .toList(growable: false)
      ..sort((a, b) => a.originServerTs.compareTo(b.originServerTs));
    return _forwardEvents(
      selectedEvents,
      sourceName: sourceName,
      sourceRoomType: sourceRoomType,
    );
  }

  Future<void> _forwardEvents(
    List<Event> selectedEvents, {
    required String sourceName,
    required String sourceRoomType,
  }) async {
    if (selectedEvents.isEmpty) return;
    final payload = buildChatRecordPayload(
      sourceRoomId: widget.roomId,
      sourceRoomType: sourceRoomType,
      sourceName: sourceName,
      messages: [
        for (final event in selectedEvents)
          ChatRecordSourceMessage(
            senderId: event.senderId,
            senderName: event.senderFromMemoryOrFallback.calcDisplayname(),
            isMe: event.senderId == ref.read(matrixClientProvider).userID,
            body: event.body,
            messageType: event.messageType,
            originServerTs: event.originServerTs.millisecondsSinceEpoch,
            content: Map<String, Object?>.from(event.content),
          ),
      ],
    );
    try {
      final sent = await showAndForwardChatRecord(
        context,
        ref,
        payload: payload,
        currentRoomId: widget.roomId,
        currentRoomName: sourceName,
        currentRoomType: sourceRoomType,
      );
      if (!mounted || !sent) return;
      setState(() {
        _multiSelect = false;
        _selected.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已转发聊天记录')),
      );
    } on Object catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转发失败：$err')),
      );
    }
  }

  Future<AsFavoriteMessageDraft> _favoriteDraftForEvent(Event event) async {
    final room = _room;
    final ownerUserId = ref.read(matrixClientProvider).userID ?? '';
    final baseDraft = favoriteDraftFromMatrixMessage(
      roomId: widget.roomId,
      eventId: event.eventId,
      roomType: _favoriteRoomType(room),
      senderId: event.senderId,
      senderName: event.senderFromMemoryOrFallback.calcDisplayname(),
      body: event.body,
      content: Map<String, Object?>.from(event.content),
      originServerTs: event.originServerTs.millisecondsSinceEpoch,
    );
    if (!isFavoriteMediaMessageType(baseDraft.messageType) ||
        baseDraft.url.isEmpty ||
        !favoriteMediaNeedsOwnerCopy(
          mediaUrl: baseDraft.url,
          ownerUserId: ownerUserId,
        )) {
      return baseDraft;
    }

    final savedMedia = await _copyEventMediaToOwnerNode(event);
    var savedThumbnail = '';
    if (baseDraft.thumbnailUrl.isNotEmpty &&
        favoriteMediaNeedsOwnerCopy(
          mediaUrl: baseDraft.thumbnailUrl,
          ownerUserId: ownerUserId,
        )) {
      savedThumbnail = await _copyEventThumbnailToOwnerNode(event);
    }
    return favoriteDraftFromMatrixMessage(
      roomId: widget.roomId,
      eventId: event.eventId,
      roomType: _favoriteRoomType(room),
      senderId: event.senderId,
      senderName: event.senderFromMemoryOrFallback.calcDisplayname(),
      body: event.body,
      content: Map<String, Object?>.from(event.content),
      originServerTs: event.originServerTs.millisecondsSinceEpoch,
      savedMediaUrl: savedMedia,
      savedThumbnailUrl: savedThumbnail,
    );
  }

  String _favoriteRoomType(Room? room) {
    if (room == null) return 'direct';
    if (isPortalAgentDirectRoom(room)) return 'agent';
    final syncCache = ref.read(asSyncCacheProvider);
    if (_isProductDirectRoomForChat(room, syncCache)) return 'direct';
    return 'group';
  }

  Future<String> _copyEventMediaToOwnerNode(Event event) async {
    final matrixFile = await event.downloadAndDecryptAttachment();
    final uploaded = await ref.read(matrixClientProvider).uploadContent(
          matrixFile.bytes,
          filename: matrixFile.name,
          contentType: event.attachmentMimetype.isEmpty
              ? null
              : event.attachmentMimetype,
        );
    return uploaded.toString();
  }

  Future<String> _copyEventThumbnailToOwnerNode(Event event) async {
    try {
      final matrixFile =
          await event.downloadAndDecryptAttachment(getThumbnail: true);
      final uploaded = await ref.read(matrixClientProvider).uploadContent(
            matrixFile.bytes,
            filename: 'favorite-thumb-${event.eventId}.jpg',
            contentType: event.thumbnailMimetype.isEmpty
                ? 'image/jpeg'
                : event.thumbnailMimetype,
          );
      return uploaded.toString();
    } on Object catch (err) {
      debugPrint('favorite thumbnail copy skipped: $err');
      return '';
    }
  }

  Future<void> _deleteEventForMe(Event event) async {
    final eventId = event.eventId.trim();
    if (eventId.isEmpty) return;
    try {
      await ref.read(asClientProvider).deleteRoomMessage(
            roomId: widget.roomId,
            eventId: eventId,
          );
      if (!mounted) return;
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withDeletedMessage(widget.roomId, eventId),
          );
      unawaited(_refreshBootstrapAfterVisibilityMutation());
      setState(() => _selected.remove(eventId));
    } on Object catch (err) {
      debugPrint('delete message for me failed: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除消息失败：$err')),
        );
      }
    }
  }

  Future<void> _refreshBootstrapAfterVisibilityMutation() async {
    try {
      final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
    } on Object catch (e) {
      debugPrint('refresh bootstrap after message delete failed: $e');
    }
  }

  Future<void> _joinGroupInvite(GroupInviteContent invite) async {
    final eventId = invite.inviteEventId.trim();
    if (eventId.isNotEmpty && _joiningGroupInviteEventIds.contains(eventId)) {
      return;
    }
    if (eventId.isNotEmpty && mounted) {
      setState(() => _joiningGroupInviteEventIds.add(eventId));
    }
    try {
      final roomId = await joinGroupInviteThroughAs(
        invite: invite,
        currentDirectRoomId: widget.roomId,
        joinGroup: ref.read(asClientProvider).joinGroup,
        oneShotSync: ref.read(matrixClientProvider).oneShotSync,
        refreshBootstrap: _refreshBootstrapAfterVisibilityMutation,
      );
      if (!mounted) return;
      context.push('/group/${Uri.encodeComponent(roomId)}');
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入群聊失败：$e')),
      );
    } finally {
      if (eventId.isNotEmpty && mounted) {
        setState(() => _joiningGroupInviteEventIds.remove(eventId));
      }
    }
  }

  /// 点击图片只做临时预览；长期保存必须由气泡右下角的下载标识触发。
  Future<void> _openImageEvent(Event e, String meta) async {
    final cacheKey = e.eventId.trim();
    final cacheFuture =
        cacheKey.isEmpty ? null : ref.read(mediaThumbnailCacheProvider.future);
    await showAsyncImagePreview(
      context,
      loadPreviewProvider: cacheFuture == null
          ? null
          : () async {
              final cache = await cacheFuture;
              final bytes = await cache.read(cacheKey);
              if (bytes == null) throw StateError('thumbnail cache miss');
              return MemoryImage(bytes);
            },
      loadProvider: () async {
        final file = await e.downloadAndDecryptAttachment();
        return MemoryImage(file.bytes);
      },
      meta: meta,
    );
  }

  Future<void> _downloadImageEvent(Event e) async {
    final eventId = e.eventId.trim();
    if (eventId.isNotEmpty && _downloadingImageEventIds.contains(eventId)) {
      return;
    }
    if (eventId.isNotEmpty && mounted) {
      setState(() {
        _downloadingImageEventIds.add(eventId);
        _downloadedImageEventIds.remove(eventId);
      });
    }
    try {
      final matrixFile = await e.downloadAndDecryptAttachment();
      final file = await writeChatActionFile(
        directory: Directory(
          '${(await getApplicationDocumentsDirectory()).path}/P2P IM Downloads',
        ),
        fileName: e.body,
        bytes: matrixFile.bytes,
      );
      if (mounted) {
        if (eventId.isNotEmpty) {
          setState(() {
            _downloadedImageEventIds.add(eventId);
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已保存到 Files / Portal App / P2P IM Downloads / ${file.uri.pathSegments.last}',
            ),
          ),
        );
      }
    } on Object catch (err) {
      debugPrint('download image failed: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：$err')),
        );
      }
    } finally {
      if (eventId.isNotEmpty && mounted) {
        setState(() {
          _downloadingImageEventIds.remove(eventId);
        });
      }
    }
  }

  Future<File> _materializeFileEvent(
    Event e, {
    required bool persistent,
    String? fileName,
  }) async {
    final matrixFile = await downloadChatEventAttachment(e);
    final baseDir = persistent
        ? Directory(
            '${(await getApplicationDocumentsDirectory()).path}/P2P IM Downloads',
          )
        : Directory('${(await getTemporaryDirectory()).path}/p2p-im-open');
    return writeChatActionFile(
      directory: baseDir,
      fileName: fileName ?? e.body,
      bytes: matrixFile.bytes,
    );
  }

  Future<void> _openFileEvent(Event e) async {
    if (_isVoiceEvent(e)) {
      await _playVoiceEvent(e);
      return;
    }
    try {
      final file = await _materializeFileEvent(e, persistent: false);
      await previewChatActionFile(file);
    } on Object catch (err) {
      debugPrint('open file failed: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开失败：$err')),
        );
      }
    }
  }

  Future<void> _playVoiceEvent(Event e) async {
    try {
      final matrixFile = await downloadChatEventAttachment(e);
      await _voicePlayer.playBytes(
        matrixFile.bytes,
        mimeType: e.attachmentMimetype,
        messageId: e.eventId.trim().isEmpty ? null : e.eventId.trim(),
      );
    } on Object catch (err) {
      debugPrint('play voice failed: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败：$err')),
        );
      }
    }
  }

  void _seekVoiceEvent(Event event, int seconds) {
    if (_voicePlayer.playback.value.messageId != event.eventId.trim()) return;
    unawaited(_voicePlayer.seek(Duration(seconds: seconds)));
  }

  Future<void> _downloadFileEvent(Event e) async {
    final eventId = e.eventId.trim();
    if (eventId.isNotEmpty && _downloadingFileEventIds.contains(eventId)) {
      return;
    }
    if (eventId.isNotEmpty && mounted) {
      setState(() {
        _downloadingFileEventIds.add(eventId);
        _downloadedFileEventIds.remove(eventId);
      });
    }
    try {
      final file = await _materializeFileEvent(e, persistent: true);
      if (mounted) {
        if (eventId.isNotEmpty) {
          setState(() {
            _downloadedFileEventIds.add(eventId);
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已保存到 Files / Portal App / P2P IM Downloads / ${file.uri.pathSegments.last}',
            ),
          ),
        );
      }
    } on Object catch (err) {
      debugPrint('download file failed: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：$err')),
        );
      }
    } finally {
      if (eventId.isNotEmpty && mounted) {
        setState(() {
          _downloadingFileEventIds.remove(eventId);
        });
      }
    }
  }

  void _openContactDetail(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return;
    context.push('/contact/${Uri.encodeComponent(id)}');
  }

  VoidCallback? _senderAvatarTap(Event event, bool isMe) {
    if (isMe) return null;
    final room = _room;
    if (room == null || isPortalAgentDirectRoom(room)) return null;

    final senderId = event.senderId.trim();
    if (!senderId.startsWith('@') || !senderId.contains(':')) return null;
    return () => _openContactDetail(senderId);
  }

  String? _senderAvatarUrl(Event event, Profile? currentUserProfile) {
    final client = event.room.client;
    final memberAvatarUrl = matrixContentHttpUrl(
      client,
      event.senderFromMemoryOrFallback.avatarUrl,
    );
    if (event.senderId == client.userID) {
      return profileAvatarHttpUrl(currentUserProfile, client) ??
          memberAvatarUrl;
    }
    return memberAvatarUrl;
  }

  Future<String> _addPendingImageUpload(ChatMediaAttachment attachment) async {
    return startMediaOutboxItem(
      notifier: ref.read(localOutboxProvider.notifier),
      conversationId: widget.roomId,
      conversationType: LocalOutboxConversationType.direct,
      attachment: attachment,
    );
  }

  Future<List<String>> _addPendingImageUploads(
    List<ChatMediaAttachment> attachments,
  ) async {
    return startImageOutboxItems(
      notifier: ref.read(localOutboxProvider.notifier),
      conversationId: widget.roomId,
      conversationType: LocalOutboxConversationType.direct,
      attachments: attachments,
    );
  }

  Future<String> _addPendingFileUpload(ChatMediaAttachment attachment) {
    return startMediaOutboxItem(
      notifier: ref.read(localOutboxProvider.notifier),
      conversationId: widget.roomId,
      conversationType: LocalOutboxConversationType.direct,
      attachment: attachment,
    );
  }

  Future<String> _addPendingVideoUpload(ChatMediaAttachment attachment) {
    return startMediaOutboxItem(
      notifier: ref.read(localOutboxProvider.notifier),
      conversationId: widget.roomId,
      conversationType: LocalOutboxConversationType.direct,
      attachment: attachment,
    );
  }

  Future<void> _removePendingMediaUpload(String id) {
    return ref.read(localOutboxProvider.notifier).completeItem(id);
  }

  Future<void> _recordDeliveredMediaUpload(String id, String eventId) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty || eventId.trim().isEmpty) return;
    LocalOutboxItem? item;
    for (final candidate in ref.read(localOutboxProvider).items) {
      if (candidate.id == trimmed) {
        item = candidate;
        break;
      }
    }
    if (item == null) return;
    await ref.read(localMessageOrderProvider.notifier).recordDeliveredOutbox(
          outbox: item,
          eventId: eventId,
        );
  }

  Future<void> _failPendingMediaUpload(String id) {
    return ref.read(localOutboxProvider.notifier).failItem(id);
  }

  Future<void> _retryFailedMediaUpload(LocalOutboxItem item) async {
    if (_retryingOutboxIds.contains(item.id)) return;
    final room = _room;
    if (room == null) return;
    if (!_canSendRoomMessage(room, ref.read(asSyncCacheProvider))) {
      _showPendingContactToast(context);
      return;
    }
    if (item.messageKind != LocalOutboxMessageKind.image &&
        item.messageKind != LocalOutboxMessageKind.video &&
        item.messageKind != LocalOutboxMessageKind.file) {
      return;
    }
    final bytes = item.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      final label = switch (item.messageKind) {
        LocalOutboxMessageKind.image => '图片',
        LocalOutboxMessageKind.video => '视频',
        _ => '文件',
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('本地原$label已丢失，请重新选择$label'),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }

    final retried = await ref.read(localOutboxProvider.notifier).retryItem(
          item.id,
        );
    if (!retried || !mounted) return;

    _retryingOutboxIds.add(item.id);
    try {
      final matrixClient = ref.read(matrixClientProvider);
      final asClient = ref.read(asClientProvider);
      final attachment = switch (item.messageKind) {
        LocalOutboxMessageKind.image => ChatMediaAttachment.image(
            name: item.filename.isEmpty ? 'image.jpg' : item.filename,
            bytes: bytes,
            mimeType: item.mimeType.isEmpty ? 'image/jpeg' : item.mimeType,
          ),
        LocalOutboxMessageKind.video => ChatMediaAttachment.video(
            name: item.filename.isEmpty ? 'video.mp4' : item.filename,
            bytes: bytes,
            mimeType: item.mimeType.isEmpty
                ? videoMimeTypeForName(item.filename)
                : item.mimeType,
            thumbnailBytes: item.thumbnailBytes,
            width: item.width,
            height: item.height,
            durationMs: item.durationMs,
          ),
        _ => item.mimeType.startsWith('audio/')
            ? ChatMediaAttachment.audio(
                name: item.filename.isEmpty ? 'voice.m4a' : item.filename,
                bytes: bytes,
                mimeType: item.mimeType.isEmpty ? 'audio/mp4' : item.mimeType,
                durationMs: item.durationMs,
              )
            : ChatMediaAttachment.file(
                name: item.filename.isEmpty ? 'file' : item.filename,
                bytes: bytes,
                mimeType: item.mimeType,
              ),
      };
      await sendProductMediaWithPendingState(
        messenger: ScaffoldMessenger.of(context),
        attachment: attachment,
        sendAttachment: createProductRoomMediaSender(
          matrixClient: matrixClient,
          asClient: asClient,
          roomId: widget.roomId,
        ),
        thumbnailCacheFuture:
            item.messageKind == LocalOutboxMessageKind.image ||
                    item.messageKind == LocalOutboxMessageKind.video
                ? ref.read(mediaThumbnailCacheProvider.future)
                : null,
        onStarted: () => item.id,
        onDelivered: _recordDeliveredMediaUpload,
        onSucceeded: _removePendingMediaUpload,
        onFailed: _failPendingMediaUpload,
      );
    } finally {
      _retryingOutboxIds.remove(item.id);
    }
  }

  Set<String> _deliveredOutboxMediaIds(
    List<LocalOutboxItem> outboxItems,
    List<Event> events,
  ) {
    final deliveredCounts = <String, int>{};
    for (final event in events) {
      final signature = _deliveredMediaSignature(event);
      if (signature == null) continue;
      deliveredCounts[signature] = (deliveredCounts[signature] ?? 0) + 1;
    }
    if (deliveredCounts.isEmpty) return const {};

    final deliveredOutboxIds = <String>{};
    for (final item in outboxItems) {
      final signature = _outboxMediaSignature(item);
      if (signature == null) continue;
      final count = deliveredCounts[signature] ?? 0;
      if (count <= 0) continue;
      deliveredOutboxIds.add(item.id);
      deliveredCounts[signature] = count - 1;
    }
    return deliveredOutboxIds;
  }

  String? _deliveredMediaSignature(Event event) {
    if (event.senderId != event.room.client.userID || !event.hasAttachment) {
      return null;
    }
    final kind = switch (event.messageType) {
      MessageTypes.Image => LocalOutboxMessageKind.image.name,
      MessageTypes.Video => LocalOutboxMessageKind.video.name,
      MessageTypes.File ||
      MessageTypes.Audio =>
        LocalOutboxMessageKind.file.name,
      _ => '',
    };
    if (kind.isEmpty) return null;
    final filename = event.body.trim();
    final size = event.infoMap['size'];
    if (filename.isEmpty || size is! num || size <= 0) return null;
    return '$kind:$filename:${size.toInt()}';
  }

  String? _outboxMediaSignature(LocalOutboxItem item) {
    if ((item.messageKind != LocalOutboxMessageKind.image &&
            item.messageKind != LocalOutboxMessageKind.video &&
            item.messageKind != LocalOutboxMessageKind.file) ||
        item.status == LocalOutboxItemStatus.failed) {
      return null;
    }
    final filename = item.filename.trim();
    final size = item.byteLength;
    if (filename.isEmpty || size <= 0) return null;
    return '${item.messageKind.name}:$filename:$size';
  }

  String? _topSystemNoticeText(List<Event> events) {
    for (final event in events) {
      if (event.messageType != MessageTypes.Notice) continue;
      final text = event.body.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  _QuotedMessagePreview? _replyPreviewForEvent(
    Event event,
    List<Event> visibleEvents,
  ) {
    final replyEventId = event.relationshipType == RelationshipTypes.reply
        ? event.relationshipEventId?.trim()
        : null;
    if (replyEventId == null || replyEventId.isEmpty) return null;
    Event? quoted;
    for (final candidate in visibleEvents) {
      if (candidate.eventId == replyEventId) {
        quoted = candidate;
        break;
      }
    }
    if (quoted == null) {
      return const _QuotedMessagePreview(
        sender: '引用消息',
        text: '原消息暂不可见',
      );
    }
    return _QuotedMessagePreview(
      sender: quoted.senderFromMemoryOrFallback.calcDisplayname(),
      text: quotedEventPreviewText(quoted),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_useMock) {
      return _MockChatScaffold(conv: MockData.byId(widget.roomId)!);
    }

    final room = _room;
    final t = context.tk;
    final syncCache = ref.watch(asSyncCacheProvider);
    final currentUserProfile =
        ref.watch(currentUserProfileProvider).valueOrNull;
    if (room == null) {
      if (_isKnownConversationRoom(syncCache)) {
        if (_missingRoomSyncFailed) {
          return _missingRoomScaffold(
            '会话同步超时，请检查网络后重试',
            onRetry: _retryMissingRoomSync,
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ensureMissingRoomSync();
        });
        return _missingRoomScaffold('正在同步会话', loading: true);
      }
      return _missingRoomScaffold('会话不存在');
    }

    final pendingMediaItems = ref
        .watch(localOutboxProvider)
        .itemsForConversation(
          widget.roomId,
          type: LocalOutboxConversationType.direct,
        )
        .where(
          (item) =>
              item.messageKind == LocalOutboxMessageKind.image ||
              item.messageKind == LocalOutboxMessageKind.video ||
              item.messageKind == LocalOutboxMessageKind.file,
        )
        .toList()
        .reversed
        .toList();
    final rawTimelineEvents = _timeline?.events ?? const <Event>[];
    final callRecordContextEvents =
        callRecordContextEventsForTimeline(rawTimelineEvents);
    final timelineEvents = chatDisplayEventsForTimeline(rawTimelineEvents);
    final events = syncCache.chatVisibilityPolicyForRoom(widget.roomId).filter(
          mergeRecoveredUnreadEvents(
            room: room,
            timelineEvents: timelineEvents,
            recoveredMessages: syncCache.unreadMessagesForRoom(widget.roomId),
          ),
          eventId: (event) => event.eventId,
          originServerTs: (event) =>
              event.originServerTs.millisecondsSinceEpoch,
          redacted: (event) => event.redacted,
        );
    final topSystemNoticeText = _topSystemNoticeText(events);
    final messageEvents = topSystemNoticeText == null
        ? events
        : events
            .where((event) =>
                event.messageType != MessageTypes.Notice ||
                event.body.trim() != topSystemNoticeText)
            .toList(growable: false);
    _scheduleAsCallSessionWarmup(events, callRecordContextEvents);
    final deliveredPendingMediaIds = _deliveredOutboxMediaIds(
      pendingMediaItems,
      messageEvents,
    );
    final pendingMedia = [
      for (final item in pendingMediaItems)
        if (!deliveredPendingMediaIds.contains(item.id)) item,
    ];
    final messageOrder = ref.watch(localMessageOrderProvider);
    final timelineItems = mergeChatTimelineItems<Event, LocalOutboxItem>(
      events: messageEvents,
      eventTimestamp: (event) => event.originServerTs,
      eventSortTimestamp: (event) =>
          messageOrder.entryForEvent(event.eventId)?.createdAt,
      outboxItems: pendingMedia,
      outboxTimestamp: (item) => item.createdAt,
    );
    final timelineItemKeys = [
      for (final item in timelineItems) _timelineItemKey(item),
    ];
    _seedInitialTimelineEntrances(timelineItemKeys);
    final newestTimelineItemKey =
        timelineItemKeys.isEmpty ? null : timelineItemKeys.first;
    if (deliveredPendingMediaIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifier = ref.read(localOutboxProvider.notifier);
        for (final id in deliveredPendingMediaIds) {
          unawaited(notifier.completeItem(id));
        }
      });
    }

    final contact = syncCache.contactForRoom(widget.roomId);
    final joinedPeerMxid = joinedPersonPeerMxid(room);
    final mxid =
        productDirectPeerMxid(room) ?? joinedPeerMxid ?? contact?.userId ?? '';
    final isAgent = isPortalAgentDirectRoom(room);
    final isProductDirect = _isProductDirectRoomForChat(room, syncCache);
    final canSendMessages = _canSendRoomMessage(room, syncCache);
    final isWaitingForAccept = isProductDirect && !isAgent && !canSendMessages;
    final name = isAgent
        ? 'Agent'
        : directContactDisplayName(contact, room, peerMxid: mxid);
    final peerMember =
        mxid.isEmpty ? null : room.unsafeGetUserFromMemoryOrFallback(mxid);
    final peerAvatarUrl = avatarHttpUrl(room.client, contact?.avatarUrl) ??
        matrixContentHttpUrl(room.client, peerMember?.avatarUrl);
    final agentConnected = isAgent
        ? ref.watch(agentStatusProvider).maybeWhen(
              data: (status) => status.connected,
              orElse: () => false,
            )
        : false;
    final headerAvatarTap =
        !isAgent && mxid.startsWith('@') && mxid.contains(':')
            ? () => _openContactDetail(mxid)
            : null;
    final messagePadding = chatMessageViewportPadding(
      context,
      replyBarVisible: _replyTo != null,
      selectionBarVisible: _multiSelect,
      bottomPanelVisible: _showPlusPanel || _showEmojiPanel,
    ).add(const EdgeInsets.symmetric(vertical: 12));

    return Scaffold(
      body: ChatGlassBackground(
        child: ChatLayeredLayout(
          header: _multiSelect
              ? ChatSelectionHeader(
                  count: _selected.length,
                  onCancel: () => setState(() {
                    _multiSelect = false;
                    _selected.clear();
                  }),
                )
              : ChatCapsuleHeader(
                  title: name,
                  subtitle: isWaitingForAccept
                      ? '等待对方接受'
                      : isAgent
                          ? (agentConnected ? '在线' : '离线')
                          : null,
                  onBack: () => unawaited(_popChatOrHome(context)),
                  leadingAvatar: _ChatHeaderAvatar(
                    key: ValueKey('chat_header_peer_avatar_${widget.roomId}'),
                    seed: name,
                    imageUrl: isAgent ? null : peerAvatarUrl,
                    online: isAgent && agentConnected,
                  ),
                  onAvatarTap: headerAvatarTap,
                  actions: [
                    ChatCapsuleAction(
                      icon: Symbols.call,
                      tooltip: '语音通话',
                      color: t.accent,
                      onTap: canSendMessages
                          ? () => context.push(
                                _privateVoiceCallRoute(
                                    widget.roomId, mxid, name),
                              )
                          : () => _showPendingContactToast(context),
                    ),
                    ChatCapsuleAction(
                      icon: Symbols.more_vert,
                      tooltip: '详情',
                      color: t.accent,
                      onTap: () => context.push(
                        '/chat-info/${Uri.encodeComponent(widget.roomId)}',
                      ),
                    ),
                  ],
                ),
          messageLayer: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closePanels,
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.accent,
                      ),
                    ),
                  )
                : timelineItems.isEmpty && topSystemNoticeText == null
                    ? Center(
                        child: Text(
                          '开始你们的第一条消息',
                          style: AppTheme.sans(size: 13, color: t.textMute),
                        ),
                      )
                    : ChatTimelineListMotion(
                        itemCount: timelineItems.length +
                            (topSystemNoticeText == null ? 0 : 1),
                        newestItemKey: newestTimelineItemKey,
                        child: ListView.builder(
                          reverse: true,
                          padding: messagePadding,
                          itemCount: timelineItems.length + 1,
                          itemBuilder: (context, i) {
                            if (i == timelineItems.length) {
                              if (topSystemNoticeText != null) {
                                return _SChatSystemNotice(
                                  text: topSystemNoticeText,
                                );
                              }
                              return const _E2eFooter();
                            }
                            final itemKey = timelineItemKeys[i];
                            Widget enter(
                              Widget child, {
                              required bool isMe,
                              required Object id,
                            }) {
                              return chatMessageEntrance(
                                key: ValueKey('private_message_enter_$id'),
                                isMe: isMe,
                                index: i,
                                enabled:
                                    _initialTimelineEntrances.contains(itemKey),
                                child: child,
                              );
                            }

                            return timelineItems[i].when(
                              outbox: (pending) {
                                if (_isVoiceOutboxItem(pending)) {
                                  final playback = _voicePlayer.playback.value;
                                  final isPlaying =
                                      playback.messageId == pending.id &&
                                          playback.playing;
                                  return enter(
                                    _SChatVoiceBubble(
                                      key: ValueKey(pending.id),
                                      isMe: true,
                                      time: _formatMsgTime(pending.createdAt),
                                      showRead: false,
                                      avatarSeed: 'me',
                                      durationSeconds:
                                          _voiceDurationSecondsFromMs(
                                        pending.durationMs,
                                      ),
                                      selected: false,
                                      multiSelect: false,
                                      isPlaying: isPlaying,
                                      currentPlaySeconds:
                                          playback.position.inSeconds,
                                      onTap: null,
                                    ),
                                    isMe: true,
                                    id: pending.id,
                                  );
                                }
                                if (pending.messageKind ==
                                    LocalOutboxMessageKind.file) {
                                  return enter(
                                    _SChatFileBubble(
                                      key: ValueKey(pending.id),
                                      isMe: true,
                                      time: _formatMsgTime(pending.createdAt),
                                      showRead: false,
                                      avatarSeed: 'me',
                                      leadingIcon: Symbols.description,
                                      fileName: pending.filename,
                                      sizeLabel: outboxFileSizeLabel(pending),
                                      trailing: _FileOutboxStatusIcon(
                                        status: pending.status,
                                        label: '文件',
                                        onRetry: () => unawaited(
                                          _retryFailedMediaUpload(pending),
                                        ),
                                      ),
                                      selected: false,
                                      multiSelect: false,
                                      onTap: null,
                                    ),
                                    isMe: true,
                                    id: pending.id,
                                  );
                                }
                                final isPendingVideo = pending.messageKind ==
                                    LocalOutboxMessageKind.video;
                                final displayBytes =
                                    pending.thumbnailBytes ?? pending.bytes;
                                return enter(
                                  _SChatImageBubble(
                                    key: ValueKey(pending.id),
                                    isMe: true,
                                    time: _formatMsgTime(pending.createdAt),
                                    showRead: false,
                                    avatarSeed: 'me',
                                    thumb: pending.status ==
                                            LocalOutboxItemStatus.failed
                                        ? FailedLocalOutboxImageThumb(
                                            bytes: displayBytes,
                                            placeholderIcon: isPendingVideo
                                                ? Symbols.movie
                                                : Symbols.image,
                                            overlay: isPendingVideo
                                                ? const _VideoPlayOverlay()
                                                : null,
                                            onRetry: () => unawaited(
                                              _retryFailedMediaUpload(
                                                pending,
                                              ),
                                            ),
                                          )
                                        : PendingLocalOutboxImageThumb(
                                            bytes: displayBytes!,
                                            overlay: isPendingVideo
                                                ? const _VideoPlayOverlay()
                                                : null,
                                          ),
                                    selected: false,
                                    multiSelect: false,
                                    onTap: () {
                                      final bytes = pending.bytes;
                                      if (bytes == null) return;
                                      if (isPendingVideo) return;
                                      _openImgPreview(
                                        context,
                                        provider: MemoryImage(bytes),
                                        meta:
                                            '我 · ${_formatMsgTime(pending.createdAt)}',
                                      );
                                    },
                                  ),
                                  isMe: true,
                                  id: pending.id,
                                );
                              },
                              event: (e) {
                                if (isCallRecordEvent(e)) {
                                  final selected =
                                      _selected.contains(e.eventId);
                                  void toggle() => setState(() {
                                        if (selected) {
                                          _selected.remove(e.eventId);
                                        } else {
                                          _selected.add(e.eventId);
                                        }
                                      });
                                  final asCallId = asCallIdForCallRecord(
                                    e,
                                    callRecordContextEvents,
                                  );
                                  final asCallSession = asCallId == null
                                      ? null
                                      : _asCallSessionCache[asCallId];
                                  final callerEvent = callRecordSenderEvent(
                                    e,
                                    callRecordContextEvents,
                                  );
                                  final callerId = callRecordSenderId(
                                    e,
                                    callRecordContextEvents,
                                  );
                                  final isMe = callerId == e.room.client.userID;
                                  final callerName = callerEvent
                                          ?.senderFromMemoryOrFallback
                                          .calcDisplayname() ??
                                      e.senderFromMemoryOrFallback
                                          .calcDisplayname();
                                  final callerAvatarUrl = _senderAvatarUrl(
                                    callerEvent ?? e,
                                    currentUserProfile,
                                  );
                                  final avatarTap = isMe
                                      ? null
                                      : _senderAvatarTap(
                                          callerEvent ?? e, isMe);
                                  return enter(
                                    _SChatCallRecordBubble(
                                      isMe: isMe,
                                      isVideo: callRecordIsVideo(
                                        e,
                                        callRecordContextEvents,
                                        asCallSession: asCallSession,
                                      ),
                                      text: callRecordText(
                                        e,
                                        callRecordContextEvents,
                                        asCallSession: asCallSession,
                                        asCallSessionPending:
                                            asCallId != null &&
                                                asCallSession == null,
                                      ),
                                      time: _formatMsgTime(e.originServerTs),
                                      showRead: false,
                                      avatarSeed: callerName,
                                      avatarUrl: callerAvatarUrl,
                                      onAvatarTap: avatarTap,
                                      selected: selected,
                                      multiSelect: _multiSelect,
                                      onTap: _multiSelect ? toggle : null,
                                      onLongPressAt: (pos) =>
                                          _onLongPressEvent(context, e, pos),
                                    ),
                                    isMe: isMe,
                                    id: e.eventId,
                                  );
                                }
                                final isMe = e.senderId == e.room.client.userID;
                                final selected = _selected.contains(e.eventId);
                                final senderName = e.senderFromMemoryOrFallback
                                    .calcDisplayname();
                                final senderAvatarUrl =
                                    _senderAvatarUrl(e, currentUserProfile);
                                final localOrder =
                                    messageOrder.entryForEvent(e.eventId);
                                final time = _formatMsgTime(
                                  localOrder?.createdAt ?? e.originServerTs,
                                );
                                final avatarTap = _senderAvatarTap(e, isMe);
                                void toggle() => setState(() {
                                      if (selected) {
                                        _selected.remove(e.eventId);
                                      } else {
                                        _selected.add(e.eventId);
                                      }
                                    });

                                final groupInvite = GroupInviteContent.tryParse(
                                  Map<String, Object?>.from(e.content),
                                  eventId: e.eventId,
                                  directRoomId: widget.roomId,
                                );
                                if (groupInvite != null) {
                                  return enter(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: Align(
                                        alignment: isMe
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                groupInviteCardMaxWidthFactor,
                                          ),
                                          child: GroupInviteCard(
                                            invite: groupInvite,
                                            inviterDisplayName:
                                                isMe ? '我' : name,
                                            joining: _joiningGroupInviteEventIds
                                                .contains(e.eventId),
                                            onJoin: () => unawaited(
                                              _joinGroupInvite(groupInvite),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    isMe: isMe,
                                    id: e.eventId,
                                  );
                                }

                                if (e.messageType == MessageTypes.Notice) {
                                  return _SChatSystemNotice(text: e.body);
                                }

                                final channelSharePayload =
                                    channelSharePayloadFromContent(
                                  Map<String, Object?>.from(e.content),
                                );
                                if (channelSharePayload != null) {
                                  return enter(
                                    _SChannelShareBubble(
                                      isMe: isMe,
                                      payload: channelSharePayload,
                                      time: time,
                                      showRead: isMe,
                                      avatarSeed: senderName,
                                      avatarUrl: senderAvatarUrl,
                                      onAvatarTap: avatarTap,
                                      selected: selected,
                                      multiSelect: _multiSelect,
                                      onTap: _multiSelect
                                          ? toggle
                                          : () => context.push(
                                                '/channel/${Uri.encodeComponent(channelSharePayload.channelId)}',
                                              ),
                                      onLongPressAt: (pos) =>
                                          _onLongPressEvent(context, e, pos),
                                    ),
                                    isMe: isMe,
                                    id: e.eventId,
                                  );
                                }

                                final chatRecordPayload =
                                    chatRecordPayloadFromContent(
                                  Map<String, Object?>.from(e.content),
                                );
                                if (chatRecordPayload != null) {
                                  return enter(
                                    _SChatRecordBubble(
                                      isMe: isMe,
                                      payload: chatRecordPayload,
                                      time: time,
                                      showRead: isMe,
                                      avatarSeed: senderName,
                                      avatarUrl: senderAvatarUrl,
                                      onAvatarTap: avatarTap,
                                      selected: selected,
                                      multiSelect: _multiSelect,
                                      onTap: _multiSelect
                                          ? toggle
                                          : () => _openChatRecordDetail(
                                                context,
                                                chatRecordPayload,
                                              ),
                                      onLongPressAt: (pos) =>
                                          _onLongPressEvent(context, e, pos),
                                    ),
                                    isMe: isMe,
                                    id: e.eventId,
                                  );
                                }

                                // 图片消息 → 缩略图气泡，点击全屏预览
                                if (e.messageType == MessageTypes.Image &&
                                    e.hasAttachment) {
                                  final eventId = e.eventId.trim();
                                  return enter(
                                    _SChatImageBubble(
                                      isMe: isMe,
                                      time: time,
                                      showRead: isMe,
                                      avatarSeed: senderName,
                                      avatarUrl: senderAvatarUrl,
                                      onAvatarTap: avatarTap,
                                      thumb: _MatrixThumb(
                                        key: ValueKey(
                                          'matrix_thumb_${e.eventId}_${e.originServerTs.millisecondsSinceEpoch}',
                                        ),
                                        event: e,
                                      ),
                                      statusOverlay: _multiSelect
                                          ? null
                                          : _ImageDownloadStatusBadge(
                                              downloading:
                                                  _downloadingImageEventIds
                                                      .contains(eventId),
                                              downloaded:
                                                  _downloadedImageEventIds
                                                      .contains(eventId),
                                              onDownload: () => unawaited(
                                                _downloadImageEvent(e),
                                              ),
                                            ),
                                      selected: selected,
                                      multiSelect: _multiSelect,
                                      onTap: _multiSelect
                                          ? toggle
                                          : () => _openImageEvent(
                                                e,
                                                '${isMe ? '我' : senderName} · $time',
                                              ),
                                      onLongPressAt: (pos) =>
                                          _onLongPressEvent(context, e, pos),
                                    ),
                                    isMe: isMe,
                                    id: e.eventId,
                                  );
                                }

                                if (e.messageType == MessageTypes.Video &&
                                    e.hasAttachment) {
                                  final eventId = e.eventId.trim();
                                  return enter(
                                    _SChatImageBubble(
                                      isMe: isMe,
                                      time: time,
                                      showRead: isMe,
                                      avatarSeed: senderName,
                                      avatarUrl: senderAvatarUrl,
                                      onAvatarTap: avatarTap,
                                      thumb: _MatrixThumb(
                                        key: ValueKey(
                                          'matrix_video_thumb_${e.eventId}_${e.originServerTs.millisecondsSinceEpoch}',
                                        ),
                                        event: e,
                                        fallbackIcon: Symbols.movie,
                                      ),
                                      statusOverlay: _multiSelect
                                          ? null
                                          : _ImageDownloadStatusBadge(
                                              label: '视频',
                                              downloading:
                                                  _downloadingFileEventIds
                                                      .contains(eventId),
                                              downloaded:
                                                  _downloadedFileEventIds
                                                      .contains(eventId),
                                              onDownload: () => unawaited(
                                                _downloadFileEvent(e),
                                              ),
                                            ),
                                      centerOverlay: const _VideoPlayOverlay(),
                                      selected: selected,
                                      multiSelect: _multiSelect,
                                      onTap: _multiSelect
                                          ? toggle
                                          : () => _openFileEvent(e),
                                      onLongPressAt: (pos) =>
                                          _onLongPressEvent(context, e, pos),
                                    ),
                                    isMe: isMe,
                                    id: e.eventId,
                                  );
                                }

                                if (_isVoiceEvent(e)) {
                                  final playback = _voicePlayer.playback.value;
                                  final eventId = e.eventId.trim();
                                  final isPlaying =
                                      playback.messageId == eventId &&
                                          playback.playing;
                                  return enter(
                                    _SChatVoiceBubble(
                                      isMe: isMe,
                                      time: time,
                                      showRead: isMe,
                                      avatarSeed: senderName,
                                      avatarUrl: senderAvatarUrl,
                                      onAvatarTap: avatarTap,
                                      durationSeconds:
                                          _voiceDurationSecondsForEvent(e),
                                      selected: selected,
                                      multiSelect: _multiSelect,
                                      isPlaying: isPlaying,
                                      currentPlaySeconds:
                                          playback.position.inSeconds,
                                      onSeek: isPlaying
                                          ? (seconds) =>
                                              _seekVoiceEvent(e, seconds)
                                          : null,
                                      onTap: _multiSelect
                                          ? toggle
                                          : () => _openFileEvent(e),
                                      onLongPressAt: (pos) =>
                                          _onLongPressEvent(context, e, pos),
                                    ),
                                    isMe: isMe,
                                    id: e.eventId,
                                  );
                                }

                                // 文件附件 → 文件卡片，点击预览，右侧下载。
                                if (e.messageType == MessageTypes.File &&
                                    !_isVoiceEvent(e) &&
                                    e.hasAttachment) {
                                  final size = e.infoMap['size'];
                                  final sizeBytes = size is int ? size : 0;
                                  final kind = fileKindLabel(
                                      e.attachmentMimetype, e.body);
                                  final sizeLabel = sizeBytes > 0
                                      ? '$kind · ${formatByteSize(sizeBytes)}'
                                      : kind;
                                  return enter(
                                    _SChatFileBubble(
                                      isMe: isMe,
                                      time: time,
                                      showRead: isMe,
                                      avatarSeed: senderName,
                                      avatarUrl: senderAvatarUrl,
                                      onAvatarTap: avatarTap,
                                      leadingIcon: Symbols.description,
                                      fileName: e.body,
                                      sizeLabel: sizeLabel,
                                      trailing: _FileDownloadStatusIcon(
                                        label: '文件',
                                        downloading: _downloadingFileEventIds
                                            .contains(e.eventId.trim()),
                                        downloaded: _downloadedFileEventIds
                                            .contains(e.eventId.trim()),
                                        onDownload: () => unawaited(
                                          _downloadFileEvent(e),
                                        ),
                                      ),
                                      selected: selected,
                                      multiSelect: _multiSelect,
                                      onTap: _multiSelect
                                          ? toggle
                                          : () => _openFileEvent(e),
                                      onLongPressAt: (pos) =>
                                          _onLongPressEvent(context, e, pos),
                                    ),
                                    isMe: isMe,
                                    id: e.eventId,
                                  );
                                }

                                return enter(
                                  _SChatBubble(
                                    isMe: isMe,
                                    text: _messageDisplayText(e),
                                    quote: _replyPreviewForEvent(
                                      e,
                                      messageEvents,
                                    ),
                                    time: time,
                                    showRead: isMe,
                                    avatarSeed: senderName,
                                    avatarUrl: senderAvatarUrl,
                                    onAvatarTap: avatarTap,
                                    selected: selected,
                                    multiSelect: _multiSelect,
                                    onTap: _multiSelect ? toggle : null,
                                    onLongPressAt: (pos) =>
                                        _onLongPressEvent(context, e, pos),
                                  ),
                                  isMe: isMe,
                                  id: e.eventId,
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
          bottomOverlay: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyTo != null)
                _ReplyBar(
                  text: _replyTo!.body,
                  sender:
                      _replyTo!.senderFromMemoryOrFallback.calcDisplayname(),
                  onClose: () => setState(() => _replyTo = null),
                ),
              if (_multiSelect)
                ChatRecordSelectionBar(
                  count: _selected.length,
                  compact: true,
                  onExit: () => setState(() {
                    _multiSelect = false;
                    _selected.clear();
                  }),
                  onFavorite: () => unawaited(_favoriteSelectedEvents(events)),
                  onForward: () => unawaited(
                    _forwardSelectedEvents(
                      events,
                      sourceName: name,
                      sourceRoomType: _favoriteRoomType(room),
                    ),
                  ),
                  onDelete: () async {
                    for (final id in _selected.toList()) {
                      Event? ev;
                      for (final e in events) {
                        if (e.eventId == id) {
                          ev = e;
                          break;
                        }
                      }
                      if (ev == null) continue;
                      await _deleteEventForMe(ev);
                    }
                    setState(() {
                      _multiSelect = false;
                      _selected.clear();
                    });
                  },
                )
              else
                ChatCapsuleInputBar(
                  ctrl: _msgCtrl,
                  onSend: _send,
                  onPlus: canSendMessages
                      ? _togglePlus
                      : () => _showPendingContactToast(context),
                  onEmoji: canSendMessages
                      ? _toggleEmoji
                      : () => _showPendingContactToast(context),
                  plusActive: _showPlusPanel,
                  emojiActive: _showEmojiPanel,
                  onVoiceRecordStart: _startVoiceRecording,
                  onVoiceRecordStop: _stopVoiceRecording,
                  onVoiceRecordCancel: _cancelVoiceRecording,
                  enabled: canSendMessages,
                  hintText: isWaitingForAccept ? '等待对方接受后才能发送消息' : '消息…',
                ),
              if (_showPlusPanel)
                ChatAttachmentPanel(
                  room: room,
                  roomId: widget.roomId,
                  canSend: canSendMessages,
                  useAsProductMedia: isProductDirect && !isAgent,
                  onClose: () => setState(() => _showPlusPanel = false),
                  onCannotSend: _showPendingContactToast,
                  onImageUploadStarted: _addPendingImageUpload,
                  onImageUploadsStarted: _addPendingImageUploads,
                  onImageUploadDelivered: _recordDeliveredMediaUpload,
                  onImageUploadFinished: _removePendingMediaUpload,
                  onImageUploadFailed: _failPendingMediaUpload,
                  onFileUploadStarted: _addPendingFileUpload,
                  onFileUploadDelivered: _recordDeliveredMediaUpload,
                  onFileUploadFinished: _removePendingMediaUpload,
                  onFileUploadFailed: _failPendingMediaUpload,
                  onVideoUploadStarted: _addPendingVideoUpload,
                  onVideoUploadDelivered: _recordDeliveredMediaUpload,
                  onVideoUploadFinished: _removePendingMediaUpload,
                  onVideoUploadFailed: _failPendingMediaUpload,
                  onVideoCall: isAgent
                      ? null
                      : () {
                          if (!canSendMessages) {
                            _showPendingContactToast(context);
                            return;
                          }
                          context.push(
                            _privateVideoCallRoute(widget.roomId, mxid, name),
                          );
                        },
                ),
              if (_showEmojiPanel)
                ChatEmojiPanel(
                  onPick: (e) {
                    final c = _msgCtrl;
                    final base = c.text;
                    c.text = base + e;
                    c.selection =
                        TextSelection.collapsed(offset: c.text.length);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Mock 聊天页：roomId 命中 MockData 时使用，无需 Matrix client。
// ═══════════════════════════════════════════════════════════════════════════

class _MockChatScaffold extends ConsumerStatefulWidget {
  const _MockChatScaffold({required this.conv});
  final MockConversation conv;

  @override
  ConsumerState<_MockChatScaffold> createState() => _MockChatScaffoldState();
}

class _PendingConfirm {
  _PendingConfirm({
    required this.tool,
    required this.args,
    required this.preview,
    required this.onConfirm,
  });
  final String tool;
  final Map<String, dynamic> args;
  final String preview;
  final VoidCallback onConfirm;
}

class _MockChatScaffoldState extends ConsumerState<_MockChatScaffold> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late List<MockMessage> _messages;
  bool _agentBusy = false;
  _PendingConfirm? _pendingConfirm;
  Timer? _streamTimer;
  Timer? _gatewaySyncTimer;
  bool _gatewaySyncing = false;
  int _gatewayFailureCount = 0;
  static const _agentId = 'local-aibot';

  // s-chat 视觉状态
  bool _showPlusPanel = false;
  bool _showEmojiPanel = false;
  bool _multiSelect = false;
  final Set<int> _selected = {};
  MockMessage? _replyTo;
  final ChatInitialEntranceRegistry _initialMockEntrances =
      ChatInitialEntranceRegistry();
  Timer? _initialMockEntranceTimer;

  bool get _isAiBot => widget.conv.id == 'mock_aibot';
  bool get _usesAsGatewaySync => !_mockAuthEnabled && _isAiBot;

  @override
  void initState() {
    super.initState();
    _messages = _isAiBot ? <MockMessage>[] : List.of(widget.conv.messages);
    if (_usesAsGatewaySync) {
      _scheduleGatewaySync(immediate: true);
    }
    _scrollToLatest(jump: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _streamTimer?.cancel();
    _gatewaySyncTimer?.cancel();
    _initialMockEntranceTimer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final replyTo = _replyTo;
    final sent = MockMessage(
      isMe: true,
      text: text,
      time: DateTime.now(),
      quotedSender: replyTo == null
          ? null
          : replyTo.isMe
              ? '我'
              : widget.conv.name,
      quotedText: replyTo?.text,
    );
    setState(() {
      _messages.add(sent);
      _ctrl.clear();
      _replyTo = null;
    });
    _scrollToLatest();

    if (!_usesAsGatewaySync) return;

    try {
      final gateway = ref.read(asGatewayClientProvider);
      await gateway.sendMessage(_gatewayRoomId, text);
      await _loadAsGatewayMessages();
      _scheduleGatewaySync();
    } on AsGatewayException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败：${e.message}')),
      );
      _scheduleGatewaySync();
    }
  }

  void _scheduleGatewaySync({bool immediate = false}) {
    if (!_usesAsGatewaySync) return;
    _gatewaySyncTimer?.cancel();
    final delay = immediate ? Duration.zero : _gatewayPollDelay;
    _gatewaySyncTimer = Timer(
      delay,
      () => unawaited(_loadAsGatewayMessages(scheduleNext: true)),
    );
  }

  Duration get _gatewayPollDelay {
    final seconds = math.min(15, 3 * (1 << math.min(_gatewayFailureCount, 3)));
    return Duration(seconds: seconds);
  }

  Future<void> _loadAsGatewayMessages({bool scheduleNext = false}) async {
    if (!_usesAsGatewaySync) return;
    if (_gatewaySyncing) {
      if (scheduleNext && mounted) _scheduleGatewaySync();
      return;
    }
    _gatewaySyncing = true;
    try {
      final gateway = ref.read(asGatewayClientProvider);
      final data = await gateway.readRoomMessages(_gatewayRoomId, limit: 80);
      final rows = (data['messages'] as List? ?? const []);
      final next = rows
          .whereType<Map>()
          .map((row) => _messageFromAs(Map<String, dynamic>.from(row)))
          .toList();
      if (!mounted) return;
      if (next.isEmpty && !_isAiBot) return;
      _gatewayFailureCount = 0;
      setState(() => _messages = next);
      _scrollToLatest();
    } on AsGatewayException catch (e) {
      _gatewayFailureCount = math.min(_gatewayFailureCount + 1, 4);
      debugPrint('AS Gateway sync failed: $e');
      // Non-agent demo conversations can still fall back to bundled data.
    } finally {
      _gatewaySyncing = false;
      if (scheduleNext && mounted) _scheduleGatewaySync();
    }
  }

  VoidCallback? _mockPeerAvatarTap(MockMessage message) {
    if (message.isMe || _isAiBot || widget.conv.isGroup) return null;
    final mxid = widget.conv.mxid.trim();
    if (!mxid.startsWith('@') || !mxid.contains(':')) return null;
    return () => _openMockContactDetail(mxid);
  }

  Key? _mockPeerAvatarKey(MockMessage message, int index) {
    if (message.isMe || _isAiBot || widget.conv.isGroup) return null;
    return ValueKey('chat_peer_avatar_${widget.conv.id}_$index');
  }

  VoidCallback? _mockHeaderAvatarTap() {
    if (_isAiBot || widget.conv.isGroup) return null;
    final mxid = widget.conv.mxid.trim();
    if (!mxid.startsWith('@') || !mxid.contains(':')) return null;
    return () => _openMockContactDetail(mxid);
  }

  void _openMockContactDetail(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return;
    context.push('/contact/${Uri.encodeComponent(id)}');
  }

  Object _mockMessageKey(MockMessage message) => message;

  void _seedInitialMockEntrances(List<Object> keys) {
    if (!_initialMockEntrances.seed(keys)) return;
    _initialMockEntranceTimer?.cancel();
    _initialMockEntranceTimer = Timer(
      ChatInitialEntranceRegistry.closeDelay,
      () {
        _initialMockEntrances.close();
        if (mounted) setState(() {});
      },
    );
  }

  void _scrollToLatest({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final offset = _scrollCtrl.position.maxScrollExtent;
      if (jump) {
        _scrollCtrl.jumpTo(offset);
        return;
      }
      unawaited(
        _scrollCtrl.animateTo(
          offset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  String get _gatewayRoomId => widget.conv.id;

  MockMessage _messageFromAs(Map<String, dynamic> row) {
    final sender = row['sender_mxid'] as String? ?? '';
    final senderName = row['sender_name'] as String? ?? '';
    final isMe = sender == '@me:mock.local' || senderName == '我';
    final timestamp = DateTime.tryParse(row['timestamp'] as String? ?? '');
    return MockMessage(
      isMe: isMe,
      text: row['content'] as String? ?? '',
      time: timestamp ?? DateTime.now(),
      senderName: isMe ? null : senderName,
    );
  }

  /// 流式输出：按字符 append，制造打字机感
  void _streamAgentReply(String full, {int charDelayMs = 12}) {
    _streamTimer?.cancel();
    setState(() {
      _agentBusy = true;
      _messages.add(MockMessage(isMe: false, text: '', time: DateTime.now()));
    });
    int i = 0;
    _streamTimer = Timer.periodic(Duration(milliseconds: charDelayMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (i >= full.length) {
        t.cancel();
        setState(() => _agentBusy = false);
        return;
      }
      i = (i + 2).clamp(0, full.length);
      setState(() {
        final last = _messages.last;
        _messages[_messages.length - 1] = MockMessage(
          isMe: last.isMe,
          text: full.substring(0, i),
          time: last.time,
        );
      });
    });
  }

  void _addToolBubble({
    required String tool,
    required Map<String, dynamic> args,
    required String summary,
    required int latencyMs,
    List<String> warnings = const [],
    bool denied = false,
    String? deniedReason,
  }) {
    setState(() {
      _messages.add(
        MockMessage(
          isMe: false,
          text: '',
          time: DateTime.now(),
          kind: MockMsgKind.toolCall,
          toolName: tool,
          toolArgs: args,
          toolResultSummary: denied ? (deniedReason ?? '被拒') : summary,
          toolLatencyMs: latencyMs,
          toolWarnings: [...warnings, if (denied) deniedReason ?? '权限不足'],
        ),
      );
    });
  }

  void _addUserAction(String text) {
    _messages.add(MockMessage(isMe: true, text: text, time: DateTime.now()));
  }

  // ignore: unused_element
  Future<void> _onTokenUsage() async {
    setState(() => _addUserAction('/查询 token 用量'));
    try {
      final r = await _callToolWithBubble('token_usage', {});
      final d = r.data;
      _streamAgentReply(
        '## 📊 本月 Token 用量\n\n'
        '| 类别 | 数量 |\n'
        '| --- | ---: |\n'
        '| 输入 | `${d['input']}` |\n'
        '| 输出 | `${d['output']}` |\n'
        '| **总计** | **${d['total']} / ${d['limit']}** |\n'
        '| 占比 | ${(d['total'] / d['limit'] * 100).toStringAsFixed(1)}% |\n\n'
        '**当前模型**：`${d['model']}`  \n'
        '**本月预计支出**：¥${d['cost_cny']}\n\n'
        '> ⏰ 配额重置时间：**2026-06-01**',
      );
    } on McpDeniedException {
      /* 已写气泡 */
    }
  }

  Future<void> _onTestAsConnector() async {
    setState(() => _addUserAction('/测试 AS Connector'));
    final gateway = ref.read(asGatewayClientProvider);

    try {
      final auth = await _callAsGatewayWithBubble(
          'p2p_auth_status',
          {
            'as_url': gateway.asUrl,
            'auth_mode': 'bearer_agent_token',
          },
          gateway.authProbe);
      final roomsData = await _callAsGatewayWithBubble(
        'p2p_rooms_list',
        {},
        gateway.listRooms,
      );
      final contactsData = await _callAsGatewayWithBubble(
        'p2p_contacts_list',
        {},
        gateway.listContacts,
      );

      final rooms = (roomsData['rooms'] as List? ?? const []);
      final contacts = (contactsData['contacts'] as List? ?? const []);
      Map<String, dynamic>? firstRoom;
      if (rooms.isNotEmpty && rooms.first is Map) {
        firstRoom = Map<String, dynamic>.from(rooms.first as Map);
      }

      Map<String, dynamic>? messagesData;
      if (firstRoom != null) {
        final roomId = firstRoom['room_id'] as String;
        messagesData = await _callAsGatewayWithBubble(
          'p2p_room_messages_read',
          {'room_id': roomId, 'limit': 5},
          () => gateway.readRoomMessages(roomId, limit: 5),
        );
        await _callAsGatewayWithBubble(
            'p2p_room_members_list',
            {
              'room_id': roomId,
            },
            () => gateway.listRoomMembers(roomId));
        await _callAsGatewayWithBubble(
          'p2p_messages_search',
          {'query': '评审', 'room_id': roomId, 'limit': 5},
          () => gateway.searchMessages('评审', roomId: roomId, limit: 5),
        );
      }

      final messages = (messagesData?['messages'] as List? ?? const []);
      _streamAgentReply(
        '## AS Connector 已接通\n\n'
        '- AS：`${auth['as_url']}`\n'
        '- 鉴权：`${auth['auth_mode']}`，token 已加载：`${auth['token_loaded']}`\n'
        '- 房间：**${rooms.length}** 个\n'
        '- 联系人：**${contacts.length}** 个\n'
        '- 首个房间：${firstRoom?['name'] ?? '无'}\n'
        '- 读取消息：**${messages.length}** 条\n\n'
        '这次测试走的是 `client -> p2p-matrix-as Gateway /api/*`。'
        '如果 Matrix homeserver 未启动，房间、联系人或发送步骤会返回 AS 后端错误。',
      );
    } on AsGatewayException catch (e) {
      _streamAgentReply(
        '## AS Connector 连接失败\n\n'
        '- AS：`${gateway.asUrl}`\n'
        '- 错误：`${e.toString()}`\n\n'
        '请确认 p2p-matrix-as Gateway 已启动，并且 `P2P_MATRIX_AGENT_TOKEN` 与 AS gateway token 一致。',
      );
    }
  }

  // ignore: unused_element
  Future<void> _onSummarizeRecent() async {
    setState(() => _addUserAction('/总结最近谁和我聊了什么'));
    try {
      final who = await _callToolWithBubble('list_conversations', {
        'query': 'jack',
      });
      final convs = who.data['conversations'] as List;
      if (convs.isEmpty) {
        _streamAgentReply('没有匹配到名为 Jack 的会话。');
        return;
      }
      final target = convs.first;
      final r = await _callToolWithBubble('get_recent_messages', {
        'room_id': target['id'],
        'limit': 50,
      });
      final msgs = (r.data['messages'] as List).cast<Map>();
      final preview = msgs
          .take(3)
          .map((m) => '> **${m['sender_name']}**：${m['text']}')
          .join('\n>\n');

      final policy = ref.read(mcpPolicyStoreProvider)[_agentId]!;
      final warnLines = <String>[
        if (r.warnings.isNotEmpty) ...r.warnings.map((w) => '> ⚠️ $w'),
        '> 当前窗口：**${policy.historyWindow.label}**；范围：**${policy.summary}**',
      ];

      _streamAgentReply(
        '## 📨 最近联系人活动\n\n'
        '### ${target['name']} `${target['mxid']}`\n\n'
        '共 **${msgs.length}** 条消息，未读 **${target['unread']}** 条。\n\n'
        '**关键内容**\n\n'
        '- 周一下午评审会改期至 **周二 10:00**，会议室 `A 区 3 楼`\n'
        '- 需带上次的 PRD 文档参会\n'
        '- 询问周末是否有空一起打球\n\n'
        '**消息预览**\n\n'
        '$preview\n\n'
        '---\n\n'
        '**建议行动**\n\n'
        '- ✅ 已在日历更新评审会时间\n'
        '- ⏰ 待办：整理 PRD 文档\n'
        '- 💬 待回复：周末是否打球（**提示**：点下方"代我回复"按钮，将经你确认后发送）\n\n'
        '${warnLines.join('\n')}',
      );
    } on McpDeniedException {
      /* 已写气泡 */
    }
  }

  void _onNewSession() {
    _streamTimer?.cancel();
    setState(() {
      _messages.clear();
      _agentBusy = false;
    });
  }

  /// AI Bot 头部右上角角标菜单：快捷指令两项（测试 AS 连接 / 新建会话）+ 管理。
  /// 原先在输入框上方的 `_AgentFloatingBar` 已收进此菜单。
  void _showAgentMenu(BuildContext anchorCtx, Offset offset) {
    final t = anchorCtx.tk;
    PopupMenuItem<void> item(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap,
    ) {
      return PopupMenuItem<void>(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: t.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTheme.sans(
                        size: 13,
                        color: t.text,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTheme.sans(size: 11, color: t.textMute),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    showMenu<void>(
      context: anchorCtx,
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: t.border),
      ),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        offset.dx + 1,
        offset.dy + 1,
      ),
      items: [
        item(
          Symbols.api,
          'AS 测试',
          '检查 Agent 与后端连接',
          _onTestAsConnector,
        ),
        item(
          Symbols.add_comment,
          '新建会话',
          '清空当前演示上下文',
          _onNewSession,
        ),
        item(
          Symbols.tune,
          '管理',
          'MCP 权限与策略',
          () => context.push('/mcp-permission/local-aibot'),
        ),
      ],
    );
  }

  // ignore: unused_element
  void _onAgentDraftReply() {
    setState(() {
      _pendingConfirm = _PendingConfirm(
        tool: 'send_message',
        args: {'room_id': 'mock_jack', 'text': '周日下午 3 点万体馆见，到时候打你电话。'},
        preview: '将发送给 **Jack**：\n\n> 周日下午 3 点万体馆见，到时候打你电话。',
        onConfirm: () async {
          final args = _pendingConfirm!.args;
          setState(() => _pendingConfirm = null);
          try {
            await _callToolWithBubble(
              'send_message',
              args,
              userConfirmed: true,
            );
            _streamAgentReply('✅ 已替你发送给 Jack。');
          } on McpDeniedException {
            /* 已写气泡 */
          }
        },
      );
    });
  }

  Future<void> _onLongPressMsg(MockMessage m, Offset pos) async {
    if (m.kind != MockMsgKind.text &&
        m.kind != MockMsgKind.image &&
        m.kind != MockMsgKind.file) {
      return;
    }
    final action = await _showMsgContextMenu(context, pos);
    if (!mounted || action == null) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已复制'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        break;
      case 'quote':
        setState(() => _replyTo = m);
        break;
      case 'forward':
        // 占位
        break;
      case 'fav':
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已收藏'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        break;
      case 'multi':
        setState(() {
          _multiSelect = true;
          _selected.add(_messages.indexOf(m));
        });
        break;
      case 'delete':
        setState(() => _messages.remove(m));
        break;
    }
  }

  String _mockMessageType(MockMessage message) {
    if (message.chatRecordContent.isNotEmpty) return chatRecordMessageType;
    return switch (message.kind) {
      MockMsgKind.image => MessageTypes.Image,
      MockMsgKind.file => MessageTypes.File,
      _ => MessageTypes.Text,
    };
  }

  Map<String, Object?> _mockMessageContent(MockMessage message) {
    if (message.chatRecordContent.isNotEmpty) {
      return message.chatRecordContent;
    }
    return switch (message.kind) {
      MockMsgKind.image => <String, Object?>{
          'msgtype': MessageTypes.Image,
          'body': message.text,
          if ((message.imageUrl ?? '').trim().isNotEmpty)
            'url': message.imageUrl!.trim(),
          'info': <String, Object?>{
            'mimetype': 'image/jpeg',
          },
        },
      MockMsgKind.file => <String, Object?>{
          'msgtype': MessageTypes.File,
          'body': (message.fileName ?? message.text).trim(),
          'filename': (message.fileName ?? message.text).trim(),
          'info': <String, Object?>{
            if ((message.fileMime ?? '').trim().isNotEmpty)
              'mimetype': message.fileMime!.trim(),
          },
        },
      _ => <String, Object?>{
          'msgtype': MessageTypes.Text,
          'body': message.text,
        },
    };
  }

  void _favoriteSelectedMockMessages() {
    if (_selected.isEmpty) return;
    setState(() {
      _multiSelect = false;
      _selected.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已收藏'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _forwardSelectedMockMessages() async {
    final selectedMessages = _selected
        .where((index) => index >= 0 && index < _messages.length)
        .toList(growable: false)
      ..sort();
    if (selectedMessages.isEmpty) return;
    final payload = buildChatRecordPayload(
      sourceRoomId: widget.conv.id,
      sourceRoomType: widget.conv.isGroup ? 'group' : 'direct',
      sourceName: widget.conv.name,
      messages: [
        for (final index in selectedMessages)
          ChatRecordSourceMessage(
            senderId:
                _messages[index].isMe ? '@me:mock.local' : widget.conv.mxid,
            senderName: _messages[index].isMe
                ? '我'
                : (_messages[index].senderName ?? widget.conv.name),
            isMe: _messages[index].isMe,
            body: _messages[index].text,
            messageType: _mockMessageType(_messages[index]),
            originServerTs: _messages[index].time.millisecondsSinceEpoch,
            content: _mockMessageContent(_messages[index]),
          ),
      ],
    );
    setState(() {
      _messages.add(
        MockMessage(
          isMe: true,
          text: payload.body,
          time: DateTime.now(),
          chatRecordContent: payload.matrixContent,
        ),
      );
      _multiSelect = false;
      _selected.clear();
    });
    _scrollToLatest();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已转发聊天记录')),
    );
  }

  /// 包装：先 precheck，需确认就弹 banner；否则直接调
  Future<ToolResult> _callToolWithBubble(
    String tool,
    Map<String, dynamic> args, {
    bool userConfirmed = false,
  }) async {
    final client = ref.read(mockMcpClientProvider);
    final pre = client.precheck(_agentId, tool);
    if (pre.needConfirm && !userConfirmed) {
      throw McpDeniedException('需用户二次确认');
    }
    try {
      final r = await client.call(
        _agentId,
        tool,
        args,
        userConfirmed: userConfirmed,
      );
      _addToolBubble(
        tool: tool,
        args: args,
        summary: r.summary,
        latencyMs: r.latencyMs,
        warnings: r.warnings,
      );
      return r;
    } on McpDeniedException catch (e) {
      _addToolBubble(
        tool: tool,
        args: args,
        summary: '',
        latencyMs: 0,
        denied: true,
        deniedReason: e.reason,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _callAsGatewayWithBubble(
    String tool,
    Map<String, dynamic> args,
    Future<Map<String, dynamic>> Function() call,
  ) async {
    final sw = Stopwatch()..start();
    try {
      final data = await call();
      sw.stop();
      _addToolBubble(
        tool: tool,
        args: args,
        summary: _asGatewaySummary(tool, data),
        latencyMs: sw.elapsedMilliseconds,
      );
      return data;
    } on AsGatewayException catch (e) {
      sw.stop();
      _addToolBubble(
        tool: tool,
        args: args,
        summary: '',
        latencyMs: sw.elapsedMilliseconds,
        denied: true,
        deniedReason: e.toString(),
      );
      rethrow;
    }
  }

  String _asGatewaySummary(String tool, Map<String, dynamic> data) {
    final key = switch (tool) {
      'p2p_rooms_list' => 'rooms',
      'p2p_contacts_list' => 'contacts',
      'p2p_room_messages_read' => 'messages',
      'p2p_room_members_list' => 'members',
      'p2p_messages_search' => 'results',
      _ => null,
    };
    if (key != null) {
      final count = (data[key] as List?)?.length ?? 0;
      return '$key: $count';
    }
    if (tool == 'p2p_auth_status') {
      return 'agent token loaded: ${data['token_loaded']}';
    }
    return 'ok';
  }

  void _togglePlus() => setState(() {
        _showPlusPanel = !_showPlusPanel;
        if (_showPlusPanel) _showEmojiPanel = false;
      });

  void _toggleEmoji() => setState(() {
        _showEmojiPanel = !_showEmojiPanel;
        if (_showEmojiPanel) _showPlusPanel = false;
      });

  void _closePanels() => setState(() {
        _showPlusPanel = false;
        _showEmojiPanel = false;
      });

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = widget.conv;
    final messagePadding = chatMessageViewportPadding(
      context,
      replyBarVisible: _replyTo != null || _pendingConfirm != null,
      selectionBarVisible: _multiSelect,
      bottomPanelVisible: _showPlusPanel || _showEmojiPanel,
    ).add(const EdgeInsets.symmetric(vertical: 12));
    final messageKeys = [
      for (final message in _messages) _mockMessageKey(message)
    ];
    _seedInitialMockEntrances(messageKeys);
    final newestMessageKey = messageKeys.isEmpty ? null : messageKeys.last;
    return Scaffold(
      body: ChatGlassBackground(
        child: ChatLayeredLayout(
          header: _multiSelect
              ? ChatSelectionHeader(
                  count: _selected.length,
                  onCancel: () => setState(() {
                    _multiSelect = false;
                    _selected.clear();
                  }),
                )
              : ChatCapsuleHeader(
                  title: _isAiBot ? 'Agent' : c.name,
                  subtitle: c.isGroup ? '6 名成员' : null,
                  onBack: () => unawaited(_popChatOrHome(context)),
                  leadingAvatar: _isAiBot
                      ? _AgentBadge(color: t.accent)
                      : c.isGroup
                          ? Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: t.surfaceHigh,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Symbols.groups,
                                size: 20,
                                color: t.textMute,
                                fill: 1,
                              ),
                            )
                          : _ChatHeaderAvatar(
                              key: ValueKey('chat_header_peer_avatar_${c.id}'),
                              seed: c.name,
                              imageUrl: c.avatarUrl,
                            ),
                  onAvatarTap:
                      c.isGroup || _isAiBot ? null : _mockHeaderAvatarTap(),
                  actions: [
                    ChatCapsuleAction(
                      icon: Symbols.call,
                      tooltip: '语音通话',
                      color: t.accent,
                      onTap: () {},
                    ),
                    ChatCapsuleAction(
                      icon: Symbols.more_vert,
                      tooltip: '详情',
                      color: t.accent,
                      onTap: _isAiBot
                          ? () => _showAgentMenu(
                                context,
                                Offset(
                                  MediaQuery.of(context).size.width - 64,
                                  88,
                                ),
                              )
                          : () => context.push(
                                '${c.isGroup ? '/group-detail' : '/chat-info'}/${Uri.encodeComponent(c.id)}',
                              ),
                    ),
                  ],
                ),
          messageLayer: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closePanels,
            child: _messages.isEmpty
                ? _EmptyState(isAiBot: _isAiBot)
                : ChatTimelineListMotion(
                    itemCount: _messages.length,
                    newestItemKey: newestMessageKey,
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: messagePadding,
                      itemCount: _messages.length + (_agentBusy ? 1 : 0) + 1,
                      itemBuilder: (context, i) {
                        if (_agentBusy && i == _messages.length) {
                          return const TypingIndicator();
                        }
                        if (i == _messages.length + (_agentBusy ? 1 : 0)) {
                          return const _E2eFooter();
                        }
                        final m = _messages[i];
                        final itemKey = messageKeys[i];
                        Widget enter(Widget child) {
                          return chatMessageEntrance(
                            key: ValueKey(
                              'mock_message_enter_${i}_${m.time.millisecondsSinceEpoch}_${m.isMe}_${m.text.hashCode}',
                            ),
                            isMe: m.isMe,
                            index: i,
                            enabled: _initialMockEntrances.contains(itemKey),
                            child: child,
                          );
                        }

                        if (m.kind == MockMsgKind.toolCall) {
                          return enter(
                            ToolCallBubble(
                              toolName: m.toolName ?? '',
                              args: m.toolArgs ?? const {},
                              resultSummary: m.toolResultSummary ?? '',
                              latencyMs: m.toolLatencyMs ?? 0,
                              warnings: m.toolWarnings ?? const [],
                              denied: m.toolResultSummary?.isEmpty == true &&
                                  (m.toolWarnings?.isNotEmpty ?? false),
                              deniedReason: m.toolResultSummary?.isEmpty == true
                                  ? m.toolWarnings?.first
                                  : null,
                            ),
                          );
                        }
                        final selected = _selected.contains(i);
                        final time = _formatMsgTime(m.time);
                        final avatarTap = _mockPeerAvatarTap(m);
                        final avatarKey = _mockPeerAvatarKey(m, i);
                        void toggle() => setState(() {
                              if (selected) {
                                _selected.remove(i);
                              } else {
                                _selected.add(i);
                              }
                            });

                        final chatRecordPayload = m.chatRecordContent.isEmpty
                            ? null
                            : chatRecordPayloadFromContent(
                                m.chatRecordContent,
                              );
                        if (chatRecordPayload != null) {
                          return enter(
                            _SChatRecordBubble(
                              isMe: m.isMe,
                              payload: chatRecordPayload,
                              time: time,
                              showRead: m.isMe,
                              avatarSeed: m.isMe ? 'me' : c.name,
                              avatarKey: avatarKey,
                              onAvatarTap: avatarTap,
                              selected: selected,
                              multiSelect: _multiSelect,
                              onTap: _multiSelect
                                  ? toggle
                                  : () => _openChatRecordDetail(
                                        context,
                                        chatRecordPayload,
                                      ),
                              onLongPressAt: (pos) => _onLongPressMsg(m, pos),
                            ),
                          );
                        }

                        // 图片消息 → 缩略图气泡，点击全屏预览
                        if (m.kind == MockMsgKind.image && m.imageUrl != null) {
                          return enter(
                            _SChatImageBubble(
                              isMe: m.isMe,
                              time: time,
                              showRead: m.isMe,
                              avatarSeed: m.isMe ? 'me' : c.name,
                              avatarKey: avatarKey,
                              onAvatarTap: avatarTap,
                              thumb: Image.network(
                                m.imageUrl!,
                                fit: BoxFit.cover,
                              ),
                              selected: selected,
                              multiSelect: _multiSelect,
                              onTap: _multiSelect
                                  ? toggle
                                  : () => _openImgPreview(
                                        context,
                                        provider: NetworkImage(m.imageUrl!),
                                        meta:
                                            '${m.isMe ? '我' : c.name} · $time',
                                      ),
                              onLongPressAt: (pos) => _onLongPressMsg(m, pos),
                            ),
                          );
                        }

                        // 文件消息 → 单击打开；长按/右键走消息菜单；右侧图标仅下载。
                        if (m.kind == MockMsgKind.file) {
                          final name = m.fileName ?? m.text;
                          return enter(
                            _SChatFileBubble(
                              isMe: m.isMe,
                              time: time,
                              showRead: m.isMe,
                              avatarSeed: m.isMe ? 'me' : c.name,
                              avatarKey: avatarKey,
                              onAvatarTap: avatarTap,
                              fileName: name,
                              sizeLabel: m.fileSize ?? '文件',
                              selected: selected,
                              multiSelect: _multiSelect,
                              onTap: _multiSelect
                                  ? toggle
                                  : () => ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(content: Text('打开文件')),
                                      ),
                              onLongPressAt: (pos) => _onLongPressMsg(m, pos),
                            ),
                          );
                        }

                        return enter(
                          _SChatBubble(
                            isMe: m.isMe,
                            text: m.text,
                            quote: (m.quotedSender?.trim().isNotEmpty == true ||
                                    m.quotedText?.trim().isNotEmpty == true)
                                ? _QuotedMessagePreview(
                                    sender: (m.quotedSender ?? '引用消息').trim(),
                                    text: (m.quotedText ?? '消息').trim(),
                                  )
                                : null,
                            time: time,
                            showRead: m.isMe,
                            avatarSeed: m.isMe ? 'me' : c.name,
                            avatarKey: avatarKey,
                            onAvatarTap: avatarTap,
                            markdownChild: (_isAiBot && !m.isMe)
                                ? AgentMessageBody(m.text)
                                : null,
                            selected: selected,
                            multiSelect: _multiSelect,
                            onTap: _multiSelect
                                ? () => setState(() {
                                      if (selected) {
                                        _selected.remove(i);
                                      } else {
                                        _selected.add(i);
                                      }
                                    })
                                : null,
                            onLongPressAt: (pos) => _onLongPressMsg(m, pos),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          bottomOverlay: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pendingConfirm != null)
                _ConfirmBanner(
                  pending: _pendingConfirm!,
                  onCancel: () => setState(() => _pendingConfirm = null),
                ),
              if (_replyTo != null)
                _ReplyBar(
                  text: _replyTo!.text,
                  sender: _replyTo!.isMe ? '我' : c.name,
                  onClose: () => setState(() => _replyTo = null),
                ),
              if (_multiSelect)
                ChatRecordSelectionBar(
                  count: _selected.length,
                  compact: true,
                  onExit: () => setState(() {
                    _multiSelect = false;
                    _selected.clear();
                  }),
                  onFavorite: _favoriteSelectedMockMessages,
                  onForward: () => unawaited(_forwardSelectedMockMessages()),
                  onDelete: () {
                    setState(() {
                      final idx = _selected.toList()..sort((a, b) => b - a);
                      for (final i in idx) {
                        if (i < _messages.length) _messages.removeAt(i);
                      }
                      _multiSelect = false;
                      _selected.clear();
                    });
                  },
                )
              else
                ChatCapsuleInputBar(
                  ctrl: _ctrl,
                  onSend: _send,
                  onPlus: _togglePlus,
                  onEmoji: _toggleEmoji,
                  plusActive: _showPlusPanel,
                  emojiActive: _showEmojiPanel,
                  suggestions:
                      _isAiBot ? const [] : const ['周日下午有空', '周日要加班，下次', '几点？'],
                  onPickSuggestion: (s) {
                    _ctrl.text = s;
                    _send();
                  },
                ),
              if (_showPlusPanel)
                ChatAttachmentPanel(
                  room: null,
                  roomId: '',
                  canSend: true,
                  useAsProductMedia: false,
                  onClose: () => setState(() => _showPlusPanel = false),
                  onCannotSend: _showPendingContactToast,
                  onVideoCall: c.isGroup || _isAiBot ? null : () {},
                ),
              if (_showEmojiPanel)
                ChatEmojiPanel(
                  onPick: (e) {
                    final c = _ctrl;
                    final base = c.text;
                    c.text = base + e;
                    c.selection =
                        TextSelection.collapsed(offset: c.text.length);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 共享 widget：气泡 / 输入栏 / 面板 / 长按菜单 / 回复栏 / 多选栏
// ═══════════════════════════════════════════════════════════════════════════

class _ChatHeaderAvatar extends StatelessWidget {
  const _ChatHeaderAvatar({
    super.key,
    required this.seed,
    this.imageUrl,
    this.online = false,
  });

  final String seed;
  final String? imageUrl;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          PortalAvatar(
            seed: seed,
            size: 40,
            imageUrl: imageUrl,
            shape: AvatarShape.squircle,
          ),
          if (online)
            const Positioned(
              bottom: 0,
              right: 0,
              child: OnlineDot(size: 10),
            ),
        ],
      ),
    );
  }
}

/// s-chat 私聊气泡：私聊顶部已经展示对方头像和名字，消息行本身不再重复显示头像。
/// 自己右对齐 + `accent` 气泡 + 时间戳行内 `done_all` 已读图标。
class _QuotedMessagePreview {
  const _QuotedMessagePreview({
    required this.sender,
    required this.text,
  });

  final String sender;
  final String text;
}

String _messageDisplayText(Event event) {
  final plain = event.plaintextBody.trim();
  if (plain.isNotEmpty && plain != event.body.trim()) return plain;
  return _stripMatrixReplyFallback(event.body).trim();
}

bool _isVoiceOutboxItem(LocalOutboxItem item) {
  return item.messageKind == LocalOutboxMessageKind.file &&
      item.mimeType.toLowerCase().startsWith('audio/');
}

bool _isVoiceEvent(Event event) {
  if (!event.hasAttachment) return false;
  if (event.messageType == MessageTypes.Audio) return true;
  if (event.messageType != MessageTypes.File) return false;
  final mime = event.attachmentMimetype.toLowerCase();
  if (mime.startsWith('audio/')) return true;
  final name = event.body.toLowerCase();
  return name.endsWith('.m4a') ||
      name.endsWith('.aac') ||
      name.endsWith('.mp3') ||
      name.endsWith('.wav') ||
      name.endsWith('.ogg') ||
      name.endsWith('.opus') ||
      name.endsWith('.amr');
}

int _voiceDurationSecondsForEvent(Event event) {
  final info = event.infoMap;
  final raw = info['duration'] ?? info['duration_ms'];
  final ms = raw is int
      ? raw
      : raw is num
          ? raw.toInt()
          : int.tryParse(raw?.toString() ?? '') ?? 0;
  return _voiceDurationSecondsFromMs(ms);
}

int _voiceDurationSecondsFromMs(int durationMs) {
  if (durationMs <= 0) return 1;
  return (durationMs / 1000).ceil().clamp(1, 60 * 60);
}

String _stripMatrixReplyFallback(String body) {
  final lines = body.split('\n');
  if (lines.isEmpty || !lines.first.startsWith('> ')) return body;
  var index = 0;
  while (index < lines.length && lines[index].startsWith('> ')) {
    index++;
  }
  if (index < lines.length && lines[index].trim().isEmpty) {
    return lines.skip(index + 1).join('\n');
  }
  return body;
}

class _SChatBubble extends StatelessWidget {
  const _SChatBubble({
    required this.isMe,
    required this.text,
    required this.time,
    required this.showRead,
    required this.avatarSeed,
    this.quote,
    this.avatarKey,
    this.avatarUrl,
    this.onAvatarTap,
    this.markdownChild,
    this.selected = false,
    this.multiSelect = false,
    this.onTap,
    this.onLongPressAt,
  });

  final bool isMe;
  final String text;
  final String time;
  final bool showRead;
  final String avatarSeed;
  final _QuotedMessagePreview? quote;
  final Key? avatarKey;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
  final Widget? markdownChild;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;
  final void Function(Offset globalPos)? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final bubbleColor = isMe ? t.accent : t.surfaceHigh;
    final textColor = isMe ? t.onAccent : t.text;
    Offset pos = Offset.zero;
    final bubble = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => pos = d.globalPosition,
      onTap: onTap,
      onLongPress: () => onLongPressAt?.call(pos),
      // 桌面端右键：记录位置 + 触发同一菜单。
      onSecondaryTapDown: (d) => pos = d.globalPosition,
      onSecondaryTap: () => onLongPressAt?.call(pos),
      child: ChatBubbleFrame(
        child: Container(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: chatDirectionalBubbleRadius(isMe),
            border: isMe ? null : Border.all(color: t.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (quote != null) ...[
                _QuotedMessageBlock(
                  quote: quote!,
                  isMe: isMe,
                ),
                const SizedBox(height: 10),
              ],
              markdownChild ??
                  Text(
                    text,
                    style: AppTheme.sans(
                      size: 17,
                      weight: FontWeight.w500,
                      color: textColor,
                    ).copyWith(height: 1.25),
                  ),
            ],
          ),
        ),
      ),
    );

    final timeRow = isMe && showRead
        ? Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: AppTheme.sans(size: 12, color: t.textMute)),
                const SizedBox(width: 4),
                Icon(Symbols.done_all, size: 14, color: t.textMute),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              time,
              style: AppTheme.sans(size: 12, color: t.textMute),
            ),
          );

    final column = Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [bubble, timeRow],
    );

    final row = Container(
      color: selected ? t.accent.withValues(alpha: 0.10) : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (multiSelect) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 14),
              child: _MessageSelectCheckmark(
                selected: selected,
                onTap: onTap,
              ),
            ),
          ],
          if (!isMe) ...[
            _MessageAvatar(
              seed: avatarSeed,
              avatarKey: avatarKey,
              imageUrl: avatarUrl,
              onAvatarTap: onAvatarTap,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.64,
              ),
              child: column,
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            _MessageAvatar(seed: avatarSeed, imageUrl: avatarUrl),
          ],
        ],
      ),
    );

    if (!multiSelect) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

class _QuotedMessageBlock extends StatelessWidget {
  const _QuotedMessageBlock({
    required this.quote,
    required this.isMe,
  });

  final _QuotedMessagePreview quote;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final senderColor = isMe ? t.onAccent.withValues(alpha: 0.88) : t.accent;
    final bodyColor = isMe ? t.onAccent.withValues(alpha: 0.86) : t.accent;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 168, minWidth: 92),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe
              ? t.onAccent.withValues(alpha: 0.18)
              : t.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              quote.sender,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 13,
                color: senderColor,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              quote.text.isEmpty ? '消息' : quote.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 13,
                color: bodyColor,
                weight: FontWeight.w500,
              ).copyWith(height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _SChatRecordBubble extends StatelessWidget {
  const _SChatRecordBubble({
    required this.isMe,
    required this.payload,
    required this.time,
    required this.showRead,
    required this.avatarSeed,
    this.avatarKey,
    this.avatarUrl,
    this.onAvatarTap,
    this.selected = false,
    this.multiSelect = false,
    this.onTap,
    this.onLongPressAt,
  });

  final bool isMe;
  final ChatRecordPayload payload;
  final String time;
  final bool showRead;
  final String avatarSeed;
  final Key? avatarKey;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;
  final void Function(Offset globalPos)? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    return _bubbleRow(
      context: context,
      isMe: isMe,
      multiSelect: multiSelect,
      selected: selected,
      avatarSeed: avatarSeed,
      avatarKey: avatarKey,
      avatarUrl: avatarUrl,
      onAvatarTap: onAvatarTap,
      onSelectTap: onTap,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ChatRecordPreviewCard(
            payload: payload,
            onTap: onTap,
            onLongPressAt: onLongPressAt,
          ),
          _bubbleTimeRow(context, time, showRead),
        ],
      ),
    );
  }
}

class _SChannelShareBubble extends StatelessWidget {
  const _SChannelShareBubble({
    required this.isMe,
    required this.payload,
    required this.time,
    required this.showRead,
    required this.avatarSeed,
    this.avatarUrl,
    this.onAvatarTap,
    this.selected = false,
    this.multiSelect = false,
    this.onTap,
    this.onLongPressAt,
  });

  final bool isMe;
  final ChannelSharePayload payload;
  final String time;
  final bool showRead;
  final String avatarSeed;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;
  final void Function(Offset globalPos)? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    return _bubbleRow(
      context: context,
      isMe: isMe,
      multiSelect: multiSelect,
      selected: selected,
      avatarSeed: avatarSeed,
      avatarUrl: avatarUrl,
      onAvatarTap: onAvatarTap,
      onSelectTap: onTap,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ChannelSharePreviewCard(
            payload: payload,
            onTap: onTap,
            onLongPressAt: onLongPressAt,
          ),
          _bubbleTimeRow(context, time, showRead),
        ],
      ),
    );
  }
}

class _SChatCallRecordBubble extends StatelessWidget {
  const _SChatCallRecordBubble({
    required this.isMe,
    required this.isVideo,
    required this.text,
    required this.time,
    required this.showRead,
    required this.avatarSeed,
    this.avatarUrl,
    this.onAvatarTap,
    this.selected = false,
    this.multiSelect = false,
    this.onTap,
    this.onLongPressAt,
  });

  final bool isMe;
  final bool isVideo;
  final String text;
  final String time;
  final bool showRead;
  final String avatarSeed;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;
  final void Function(Offset globalPos)? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    return _bubbleRow(
      context: context,
      isMe: isMe,
      multiSelect: multiSelect,
      selected: selected,
      avatarSeed: avatarSeed,
      avatarUrl: avatarUrl,
      onAvatarTap: onAvatarTap,
      onSelectTap: onTap,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ChatCallRecordBubble(
            isMe: isMe,
            isVideo: isVideo,
            text: text,
            selected: selected,
            onTap: multiSelect ? onTap : null,
            onLongPressAt: onLongPressAt,
          ),
          _bubbleTimeRow(context, time, showRead),
        ],
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({
    required this.seed,
    this.avatarKey,
    this.imageUrl,
    this.onAvatarTap,
  });

  final String? seed;
  final Key? avatarKey;
  final String? imageUrl;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final avatar = PortalAvatar(
      key: avatarKey,
      seed: (seed == null || seed!.trim().isEmpty) ? 'peer' : seed!,
      size: 40,
      imageUrl: imageUrl,
      shape: AvatarShape.squircle,
    );
    if (onAvatarTap == null) return avatar;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAvatarTap,
      child: avatar,
    );
  }
}

class _SChatSystemNotice extends StatelessWidget {
  const _SChatSystemNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      key: const ValueKey('chat_system_notice'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTheme.sans(size: 11, color: t.textMute),
          ),
        ),
      ),
    );
  }
}

/// 私聊气泡外层行：多选勾选框 + 限宽内容列。
/// 抽出来给文本 / 图片 / 文件三种气泡共用，保证三者排版一致。
Widget _bubbleRow({
  required BuildContext context,
  required bool isMe,
  required bool multiSelect,
  required bool selected,
  String? avatarSeed,
  Key? avatarKey,
  String? avatarUrl,
  VoidCallback? onAvatarTap,
  VoidCallback? onSelectTap,
  required Widget child,
}) {
  final t = context.tk;
  final row = Container(
    color: selected ? t.accent.withValues(alpha: 0.10) : Colors.transparent,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (multiSelect)
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 14),
            child: _MessageSelectCheckmark(
              selected: selected,
              onTap: onSelectTap,
            ),
          ),
        if (!isMe) ...[
          _MessageAvatar(
            seed: avatarSeed,
            avatarKey: avatarKey,
            imageUrl: avatarUrl,
            onAvatarTap: onAvatarTap,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.64,
            ),
            child: child,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 8),
          _MessageAvatar(seed: avatarSeed, imageUrl: avatarUrl),
        ],
      ],
    ),
  );

  if (!multiSelect) return row;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onSelectTap,
    child: row,
  );
}

/// 气泡时间戳行：自己发的（showRead）多一个 `done_all` 已读标记。
Widget _bubbleTimeRow(BuildContext context, String time, bool showRead) {
  final t = context.tk;
  if (showRead) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(time, style: AppTheme.sans(size: 12, color: t.textMute)),
          const SizedBox(width: 4),
          Icon(Symbols.done_all, size: 14, color: t.textMute),
        ],
      ),
    );
  }
  return Padding(
    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
    child: Text(time, style: AppTheme.sans(size: 12, color: t.textMute)),
  );
}

/// 图片消息气泡（`s-chat` 收/发图片）：208×160 圆角缩略图，
/// 点击 → 全屏预览，右下角 → 下载原图，长按 / 右键 → 上下文菜单。
class _SChatImageBubble extends StatelessWidget {
  const _SChatImageBubble({
    super.key,
    required this.isMe,
    required this.time,
    required this.showRead,
    required this.avatarSeed,
    required this.thumb,
    required this.onTap,
    this.statusOverlay,
    this.centerOverlay,
    this.avatarKey,
    this.avatarUrl,
    this.onAvatarTap,
    this.selected = false,
    this.multiSelect = false,
    this.onLongPressAt,
  });

  final bool isMe;
  final String time;
  final bool showRead;
  final String avatarSeed;
  final Widget thumb;
  final VoidCallback? onTap;
  final Widget? statusOverlay;
  final Widget? centerOverlay;
  final Key? avatarKey;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
  final bool selected;
  final bool multiSelect;
  final void Function(Offset globalPos)? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    Offset pos = Offset.zero;
    final image = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => pos = d.globalPosition,
      onTap: onTap,
      onLongPress: () => onLongPressAt?.call(pos),
      onSecondaryTapDown: (d) => pos = d.globalPosition,
      onSecondaryTap: () => onLongPressAt?.call(pos),
      child: ChatMediaBubbleFrame(
        width: chatMessageMediaWidth,
        height: chatMessageMediaHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            thumb,
            if (centerOverlay != null) Center(child: centerOverlay!),
            if (statusOverlay != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: statusOverlay!,
              ),
          ],
        ),
      ),
    );
    return _bubbleRow(
      context: context,
      isMe: isMe,
      multiSelect: multiSelect,
      selected: selected,
      avatarSeed: avatarSeed,
      avatarKey: avatarKey,
      avatarUrl: avatarUrl,
      onAvatarTap: onAvatarTap,
      onSelectTap: onTap,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [image, _bubbleTimeRow(context, time, showRead)],
      ),
    );
  }
}

class _SChatVoiceBubble extends StatelessWidget {
  const _SChatVoiceBubble({
    super.key,
    required this.isMe,
    required this.time,
    required this.showRead,
    required this.avatarSeed,
    required this.durationSeconds,
    required this.onTap,
    this.isPlaying = false,
    this.currentPlaySeconds = 0,
    this.onSeek,
    this.avatarUrl,
    this.onAvatarTap,
    this.selected = false,
    this.multiSelect = false,
    this.onLongPressAt,
  });

  final bool isMe;
  final String time;
  final bool showRead;
  final String avatarSeed;
  final int durationSeconds;
  final VoidCallback? onTap;
  final bool isPlaying;
  final int currentPlaySeconds;
  final ValueChanged<int>? onSeek;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
  final bool selected;
  final bool multiSelect;
  final void Function(Offset globalPos)? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Offset pos = Offset.zero;
    final bubble = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => pos = d.globalPosition,
      onTap: onTap,
      onLongPress: () => onLongPressAt?.call(pos),
      onSecondaryTapDown: (d) => pos = d.globalPosition,
      onSecondaryTap: () => onLongPressAt?.call(pos),
      child: ChatBubbleFrame(
        child: Container(
          constraints: const BoxConstraints(minWidth: 116, maxWidth: 220),
          decoration: BoxDecoration(
            color: isMe ? t.accent : t.surfaceHigh,
            borderRadius: chatDirectionalBubbleRadius(isMe),
            border: isMe ? null : Border.all(color: t.border),
            boxShadow: [
              BoxShadow(
                color: t.text.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ChatVoiceBubbleContent(
                  isMe: isMe,
                  durationSeconds: durationSeconds,
                  isPlaying: isPlaying,
                  currentPlaySeconds: currentPlaySeconds,
                  onSeek: onSeek,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return _bubbleRow(
      context: context,
      isMe: isMe,
      multiSelect: multiSelect,
      selected: selected,
      avatarSeed: avatarSeed,
      avatarUrl: avatarUrl,
      onAvatarTap: onAvatarTap,
      onSelectTap: onTap,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [bubble, _bubbleTimeRow(context, time, showRead)],
      ),
    );
  }
}

/// 文件消息气泡（`s-chat` 文件附件卡片）：红色文档图标 + 文件名 + 大小。
/// 点击文件卡片 → 直接预览；右侧图标 → 下载保存；长按 / 右键 → 上下文菜单。
class _SChatFileBubble extends StatelessWidget {
  const _SChatFileBubble({
    super.key,
    required this.isMe,
    required this.time,
    required this.showRead,
    required this.avatarSeed,
    required this.fileName,
    required this.sizeLabel,
    required this.onTap,
    this.leadingIcon = Symbols.description,
    this.avatarKey,
    this.avatarUrl,
    this.onAvatarTap,
    this.trailing,
    this.selected = false,
    this.multiSelect = false,
    this.onLongPressAt,
  });

  final bool isMe;
  final String time;
  final bool showRead;
  final String avatarSeed;
  final String fileName;
  final String sizeLabel;
  final VoidCallback? onTap;
  final IconData leadingIcon;
  final Key? avatarKey;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
  final Widget? trailing;
  final bool selected;
  final bool multiSelect;
  final void Function(Offset globalPos)? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Offset pos = Offset.zero;
    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => pos = d.globalPosition,
      onTap: onTap,
      onLongPress: () => onLongPressAt?.call(pos),
      onSecondaryTapDown: (d) => pos = d.globalPosition,
      onSecondaryTap: () => onLongPressAt?.call(pos),
      child: ChatBubbleFrame(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: isMe ? t.accent : t.surfaceHigh,
            borderRadius: chatDirectionalBubbleRadius(isMe),
            border: isMe ? null : Border.all(color: t.border),
            boxShadow: [
              BoxShadow(
                color: t.text.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isMe
                      ? t.onAccent.withValues(alpha: 0.20)
                      : t.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  leadingIcon,
                  size: 22,
                  color: isMe ? t.onAccent : t.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 15,
                        color: isMe ? t.onAccent : t.text,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sizeLabel,
                      style: AppTheme.sans(
                        size: 12,
                        weight: FontWeight.w500,
                        color: isMe
                            ? t.onAccent.withValues(alpha: 0.78)
                            : t.textMute,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              multiSelect
                  ? Icon(
                      Symbols.description,
                      size: 20,
                      color: isMe ? t.onAccent : t.textMute,
                    )
                  : trailing ??
                      Icon(
                        Symbols.download,
                        size: 20,
                        color: isMe ? t.onAccent : t.textMute,
                      ),
            ],
          ),
        ),
      ),
    );
    return _bubbleRow(
      context: context,
      isMe: isMe,
      multiSelect: multiSelect,
      selected: selected,
      avatarSeed: avatarSeed,
      avatarKey: avatarKey,
      avatarUrl: avatarUrl,
      onAvatarTap: onAvatarTap,
      onSelectTap: onTap,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [card, _bubbleTimeRow(context, time, showRead)],
      ),
    );
  }
}

class _MessageSelectCheckmark extends StatelessWidget {
  const _MessageSelectCheckmark({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      button: true,
      label: selected ? '取消选择消息' : '选择消息',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 40,
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? t.accent : Colors.transparent,
                border: selected
                    ? null
                    : Border.all(
                        color: t.textMute.withValues(alpha: 0.36),
                      ),
              ),
              child: selected
                  ? Icon(Symbols.check, size: 12, color: t.onAccent)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _FileOutboxStatusIcon extends StatelessWidget {
  const _FileOutboxStatusIcon({
    required this.status,
    required this.label,
    required this.onRetry,
  });

  final LocalOutboxItemStatus status;
  final String label;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (status == LocalOutboxItemStatus.sending) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: t.accent,
        ),
      );
    }
    return Semantics(
      button: true,
      label: '重新发送$label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRetry,
        child: SizedBox.square(
          dimension: 40,
          child: Center(
            child: Icon(Symbols.refresh, size: 22, color: t.danger),
          ),
        ),
      ),
    );
  }
}

class _FileDownloadStatusIcon extends StatelessWidget {
  const _FileDownloadStatusIcon({
    required this.label,
    required this.downloading,
    required this.downloaded,
    required this.onDownload,
  });

  final String label;
  final bool downloading;
  final bool downloaded;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (downloading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: t.accent,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '下载中',
            style: AppTheme.sans(
              size: 11,
              color: t.accent,
              weight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    if (downloaded) {
      return Text(
        '已下载',
        style: AppTheme.sans(
          size: 11,
          color: t.accent,
          weight: FontWeight.w600,
        ),
      );
    }
    return Semantics(
      button: true,
      label: '下载$label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDownload,
        child: SizedBox.square(
          dimension: 40,
          child: Center(
            child: Icon(Symbols.download, size: 20, color: t.textMute),
          ),
        ),
      ),
    );
  }
}

class _ImageDownloadStatusBadge extends StatelessWidget {
  const _ImageDownloadStatusBadge({
    this.label = '图片',
    required this.downloading,
    required this.downloaded,
    required this.onDownload,
  });

  final String label;
  final bool downloading;
  final bool downloaded;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    if (downloading) {
      return _ImageStatusPill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '下载中',
              style: AppTheme.sans(
                size: 10,
                color: Colors.white,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    if (downloaded) {
      return _ImageStatusPill(
        child: Text(
          '已下载',
          style: AppTheme.sans(
            size: 10,
            color: Colors.white,
            weight: FontWeight.w600,
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: '下载$label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDownload,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.48),
            shape: BoxShape.circle,
          ),
          child: const Icon(Symbols.download, color: Colors.white, size: 19),
        ),
      ),
    );
  }
}

class _ImageStatusPill extends StatelessWidget {
  const _ImageStatusPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}

class _VideoPlayOverlay extends StatelessWidget {
  const _VideoPlayOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        shape: BoxShape.circle,
      ),
      child: const Icon(Symbols.play_arrow, color: Colors.white, size: 32),
    );
  }
}

/// 真实 Matrix 图片事件的缩略图加载器：先下载并解密缩略图，
/// 失败时回退到占位图标。被 `_SChatImageBubble.thumb` 复用。
class _MatrixThumb extends ConsumerWidget {
  const _MatrixThumb({
    super.key,
    required this.event,
    this.fallbackIcon = Symbols.broken_image,
  });
  final Event event;
  final IconData fallbackIcon;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final cacheKey = event.eventId.trim();
    final cache = ref.watch(mediaThumbnailCacheProvider).valueOrNull;
    return CachedThumbnailImage(
      cacheKey: cacheKey,
      cache: cache,
      cacheFuture: cacheKey.isEmpty
          ? null
          : ref.read(mediaThumbnailCacheProvider.future),
      loadBytes: () async {
        final file = await event.downloadAndDecryptAttachment(
          getThumbnail: true,
        );
        return file.bytes;
      },
      loadingBuilder: (_) => Container(
        color: t.surfaceHigh,
        alignment: Alignment.center,
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
        ),
      ),
      failedBuilder: (_) => Container(
        color: t.surfaceHigh,
        alignment: Alignment.center,
        child: Icon(fallbackIcon, color: t.textMute, size: 28),
      ),
    );
  }
}

/// 图片全屏预览（index.html `img-lightbox` / openImgPreview 复刻）：
/// 黑底 + 顶部关闭 + 居中可缩放图片 + 底部说明。
Future<void> _openImgPreview(
  BuildContext context, {
  required ImageProvider provider,
  required String meta,
}) {
  return showAsyncImagePreview(
    context,
    loadProvider: () async => provider,
    meta: meta,
  );
}

/// s-chat 头部 AI 标记：`smart_toy` 圆形 36 像素徽章。
class _AgentBadge extends StatelessWidget {
  const _AgentBadge({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: t.primaryContainer.withValues(alpha: 0.30),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(Symbols.smart_toy, size: 20, color: color, fill: 1),
    );
  }
}

void _showPendingContactToast(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('对方接受好友请求后才能发送消息')),
  );
}

String _privateVoiceCallRoute(
  String roomId,
  String peerUserId,
  String peerName,
) {
  return _privateCallRoute('call', roomId, peerUserId, peerName);
}

String _privateVideoCallRoute(
  String roomId,
  String peerUserId,
  String peerName,
) {
  return _privateCallRoute('video-call', roomId, peerUserId, peerName);
}

String _privateCallRoute(
  String path,
  String roomId,
  String peerUserId,
  String peerName,
) {
  final peerQuery = peerUserId.trim().isEmpty
      ? ''
      : '?peer=${Uri.encodeQueryComponent(peerUserId.trim())}';
  final separator = peerQuery.isEmpty ? '?' : '&';
  final nameQuery = peerName.trim().isEmpty
      ? ''
      : '${separator}name=${Uri.encodeQueryComponent(peerName.trim())}';
  return '/$path/${Uri.encodeComponent(roomId)}$peerQuery$nameQuery';
}

/// 引用回复栏：消息上方一行预览 + 关闭按钮。
class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.text,
    required this.sender,
    required this.onClose,
  });
  final String text;
  final String sender;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceHover,
        border: Border(
          top: BorderSide(color: t.border.withValues(alpha: 0.5)),
          left: BorderSide(color: t.accent, width: 3),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Symbols.reply, size: 16, color: t.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '回复 $sender',
                  style: AppTheme.sans(
                    size: 11,
                    color: t.accent,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 13, color: t.textMute),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Symbols.close, size: 18, color: t.textMute),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// `msg-ctx-menu`：WeChat-style long-press popup from Figma node 73:3243.
Future<String?> _showMsgContextMenu(
  BuildContext context,
  Offset pos, {
  bool canEdit = false,
  bool canRecall = false,
}) {
  final size = MediaQuery.of(context).size;
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'msg-ctx',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, a1, a2) {
      const horizontalMargin = 16.0;
      final menuW = math.min(343.0, size.width - horizontalMargin * 2);
      const menuH = 168.0;
      var left = pos.dx - menuW / 2;
      var top = pos.dy - menuH - 12;
      var pointerOnTop = false;
      if (left < horizontalMargin) left = horizontalMargin;
      if (left + menuW > size.width - horizontalMargin) {
        left = size.width - menuW - horizontalMargin;
      }
      if (top < 60) {
        top = pos.dy + 12;
        pointerOnTop = true;
      }
      final pointerX = (pos.dx - left - 10).clamp(18.0, menuW - 38.0);
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: menuW,
            height: menuH,
            child: _MsgCtxMenuCard(
              pointerX: pointerX,
              pointerOnTop: pointerOnTop,
              canEdit: canEdit,
              canRecall: canRecall,
            ),
          ),
        ],
      );
    },
    transitionBuilder: (ctx, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

class _MsgCtxMenuCard extends StatelessWidget {
  const _MsgCtxMenuCard({
    required this.pointerX,
    required this.pointerOnTop,
    required this.canEdit,
    required this.canRecall,
  });

  final double pointerX;
  final bool pointerOnTop;
  final bool canEdit;
  final bool canRecall;

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF4A4A4A); // theme-fixed: Figma menu surface
    const divider = Color(0x17FFFFFF); // theme-fixed: Figma row divider
    const itemW = 68.6;
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: 168,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: pointerOnTop ? 10 : 0,
              height: 158,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: dark,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      left: 16,
                      right: 16,
                      top: 78,
                      child: Divider(height: 1, thickness: 1, color: divider),
                    ),
                    const Positioned(
                      left: 0,
                      top: 12,
                      right: 0,
                      height: 58,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MsgCtxMenuItem(
                            width: itemW,
                            icon: Symbols.content_copy,
                            label: '复制',
                            value: 'copy',
                          ),
                          _MsgCtxMenuItem(
                            width: itemW,
                            icon: Symbols.forward,
                            label: '转发',
                            value: 'forward',
                          ),
                          _MsgCtxMenuItem(
                            width: itemW,
                            icon: Symbols.deployed_code,
                            label: '收藏',
                            value: 'fav',
                          ),
                          _MsgCtxMenuItem(
                            width: itemW,
                            icon: Symbols.delete,
                            label: '删除',
                            value: 'delete',
                          ),
                          _MsgCtxMenuItem(
                            width: itemW,
                            icon: Symbols.format_list_bulleted,
                            label: '多选',
                            value: 'multi',
                          ),
                        ],
                      ),
                    ),
                    const Positioned(
                      left: 1,
                      top: 87,
                      width: 69,
                      height: 58,
                      child: _MsgCtxMenuItem(
                        width: 69,
                        icon: Symbols.format_quote_rounded,
                        label: '引用',
                        value: 'quote',
                      ),
                    ),
                    if (canEdit)
                      const Positioned(
                        left: 70,
                        top: 87,
                        width: 69,
                        height: 58,
                        child: _MsgCtxMenuItem(
                          width: 69,
                          icon: Symbols.edit,
                          label: '编辑',
                          value: 'edit',
                        ),
                      ),
                    if (canRecall)
                      const Positioned(
                        left: 139,
                        top: 87,
                        width: 69,
                        height: 58,
                        child: _MsgCtxMenuItem(
                          width: 69,
                          icon: Symbols.undo,
                          label: '撤回',
                          value: 'recall',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: pointerX,
              top: pointerOnTop ? 0 : 157,
              width: 20,
              height: 12,
              child: CustomPaint(
                painter: _MsgCtxPointerPainter(
                  color: dark,
                  pointsDown: !pointerOnTop,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MsgCtxMenuItem extends StatelessWidget {
  const _MsgCtxMenuItem({
    required this.width,
    required this.label,
    required this.value,
    this.icon,
  });

  final double width;
  final IconData? icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 58,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(value),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: Colors.white, // theme-fixed: Figma menu icon
                fill: 0,
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 24,
                child: Center(
                  child: Text(
                    label,
                    style: AppTheme.sans(
                      size: 15,
                      weight: FontWeight.w500,
                      color: Colors.white, // theme-fixed: Figma menu label
                    ).copyWith(height: 20 / 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MsgCtxPointerPainter extends CustomPainter {
  const _MsgCtxPointerPainter({
    required this.color,
    required this.pointsDown,
  });

  final Color color;
  final bool pointsDown;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsDown) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MsgCtxPointerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.pointsDown != pointsDown;
  }
}

/// 消息流底部「端对端加密」标签
class _E2eFooter extends StatelessWidget {
  const _E2eFooter();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Opacity(
          opacity: 0.6,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.lock, size: 12, color: t.textMute),
              const SizedBox(width: 4),
              Text('端对端加密', style: AppTheme.sans(size: 11, color: t.textMute)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isAiBot});
  final bool isAiBot;
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAiBot ? Symbols.auto_awesome : Symbols.chat_bubble,
            size: 36,
            color: t.textMute,
          ),
          const SizedBox(height: 12),
          Text(
            isAiBot ? '问点什么 / 用上方快捷指令' : '开始你们的第一条消息',
            style: AppTheme.sans(size: 13, color: t.textMute),
          ),
        ],
      ),
    );
  }
}

class _ConfirmBanner extends StatelessWidget {
  const _ConfirmBanner({required this.pending, required this.onCancel});
  final _PendingConfirm pending;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.accent, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.security, size: 16, color: t.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Agent 想调用 ',
                      style: AppTheme.sans(size: 12, color: t.textMute),
                    ),
                    Text(
                      pending.tool,
                      style: AppTheme.mono(
                        size: 12,
                        color: t.accent,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      ' · 需你确认',
                      style: AppTheme.sans(size: 12, color: t.textMute),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AgentMessageBody(pending.preview, selectable: false),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  minimumSize: const Size(60, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  '取消',
                  style: AppTheme.sans(size: 12, color: t.textMute),
                ),
              ),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: pending.onConfirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(60, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  backgroundColor: t.accent,
                ),
                child: Text(
                  '确认发送',
                  style: AppTheme.sans(
                    size: 12,
                    color: t.onAccent,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// AI Bot 输入框上方悬浮的两个胶囊按钮 —— 飞书风格
// ignore: unused_element
class _AgentFloatingBar extends ConsumerWidget {
  const _AgentFloatingBar({
    required this.onTestAsConnector,
    required this.onNewSession,
  });

  final VoidCallback onTestAsConnector;
  final VoidCallback onNewSession;

  void _showShortcuts(BuildContext context, Offset anchor) {
    final t = context.tk;
    showMenu<void>(
      context: context,
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: t.border),
      ),
      position: RelativeRect.fromLTRB(
        anchor.dx,
        anchor.dy,
        anchor.dx + 1,
        anchor.dy + 1,
      ),
      items: [
        _shortcutItem(
          t,
          Symbols.api,
          '测试 AS 连接',
          'Bearer token 调用 /api/*',
          onTestAsConnector,
        ),
        _shortcutItem(
          t,
          Symbols.add_comment,
          '新建会话',
          '清空当前对话开始新一轮',
          onNewSession,
        ),
      ],
    );
  }

  PopupMenuItem<void> _shortcutItem(
    PortalTokens t,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return PopupMenuItem<void>(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: t.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTheme.sans(
                      size: 13,
                      color: t.text,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.sans(size: 11, color: t.textMute),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final policy = ref.watch(mcpPolicyStoreProvider)['local-aibot'];
    return Container(
      color: t.bg,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (policy != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 2),
              child: Row(
                children: [
                  Icon(
                    Symbols.verified_user,
                    size: 11,
                    color: policy.enabled ? t.accent : t.textMute,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    policy.enabled ? '权限：${policy.summary}' : '权限：已禁用',
                    style: AppTheme.mono(size: 10, color: t.textMute),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Builder(
                builder: (btnCtx) {
                  return _CapsuleButton(
                    icon: Symbols.keyboard_arrow_down,
                    iconLeading: false,
                    label: '快捷指令',
                    onTap: () {
                      final box = btnCtx.findRenderObject() as RenderBox?;
                      final offset =
                          box?.localToGlobal(Offset.zero) ?? Offset.zero;
                      _showShortcuts(btnCtx, offset);
                    },
                  );
                },
              ),
              const SizedBox(width: 8),
              _CapsuleButton(
                icon: Symbols.tune,
                iconLeading: true,
                label: '管理',
                onTap: () => context.push('/mcp-permission/local-aibot'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapsuleButton extends StatelessWidget {
  const _CapsuleButton({
    required this.icon,
    required this.iconLeading,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final bool iconLeading;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.primaryContainer.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: t.accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconLeading) ...[
                Icon(icon, size: 15, color: t.accent),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: AppTheme.sans(
                  size: 13,
                  color: t.accent,
                  weight: FontWeight.w600,
                ),
              ),
              if (!iconLeading) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 15, color: t.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../data/local_outbox_store.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_call_session_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/local_message_order_provider.dart';
import '../providers/local_outbox_provider.dart';
import '../providers/media_thumbnail_cache_provider.dart';
import '../providers/recovered_unread_store_provider.dart';
import '../providers/voice_call_provider.dart';
import '../channel/channel_share.dart';
import '../chat/cached_thumbnail_image.dart';
import '../chat/call_timeline_events.dart';
import '../chat/chat_attachment_panel.dart';
import '../chat/chat_capsule_chrome.dart';
import '../chat/chat_glass_background.dart';
import '../chat/chat_media_warmup.dart';
import '../chat/chat_message_cards.dart';
import '../chat/chat_record_detail_page.dart';
import '../chat/chat_record_forwarding.dart';
import '../chat/chat_media_send_flow.dart';
import '../chat/favorite_message_mapper.dart';
import '../chat/group_call_history_merge.dart';
import '../chat/local_outbox_image_thumb.dart';
import '../chat/product_media_outbox_flow.dart';
import '../chat/product_room_media_send_flow.dart';
import '../call/voice_call_controller.dart';
import '../utils/message_history_policy.dart';
import '../utils/avatar_url.dart';
import 'group_call_member_select_page.dart';
import '../utils/read_marker_sync.dart';
import '../utils/recovered_unread_events.dart';
import '../utils/room_read_state.dart';
import '../utils/chat_file_actions.dart';
import '../widgets/async_image_preview.dart';
import '../widgets/portal_avatar.dart';

Future<void> _popGroupChatOrHome(BuildContext context) async {
  final didPop = await Navigator.of(context).maybePop();
  if (!context.mounted || didPop) return;
  context.go('/home');
}

class _GroupChatActiveCall {
  const _GroupChatActiveCall({
    required this.callId,
    required this.callType,
    required this.requiresJoin,
  });

  final String callId;
  final ProductCallType callType;
  final bool requiresJoin;
}

_GroupChatActiveCall? _activeGroupCallForHeader({
  required GroupCallUiState controllerState,
  required ActiveGroupCallEntry? timelineEntry,
  required String roomId,
}) {
  final controllerCallId = controllerState.callId?.trim();
  if (controllerState.roomId == roomId &&
      controllerState.isActive &&
      controllerCallId != null &&
      controllerCallId.isNotEmpty) {
    return _GroupChatActiveCall(
      callId: controllerCallId,
      callType: controllerState.callType,
      requiresJoin: controllerState.isIncoming ||
          controllerState.status == GroupCallStatus.ringing,
    );
  }

  final timelineCallId = timelineEntry?.callId.trim();
  if (timelineEntry != null &&
      timelineCallId != null &&
      timelineCallId.isNotEmpty) {
    return _GroupChatActiveCall(
      callId: timelineCallId,
      callType:
          timelineEntry.isVideo ? ProductCallType.video : ProductCallType.voice,
      requiresJoin: true,
    );
  }
  return null;
}

class _GroupTimelineItem {
  const _GroupTimelineItem._({
    required this.timestamp,
    required int sourceOrder,
    Event? event,
    LocalOutboxItem? outbox,
    AsCallSession? asCallSession,
  })  : _event = event,
        _outbox = outbox,
        _asCallSession = asCallSession,
        _sourceOrder = sourceOrder;

  factory _GroupTimelineItem.event({
    required Event event,
    required DateTime timestamp,
    required int sourceOrder,
  }) {
    return _GroupTimelineItem._(
      event: event,
      timestamp: timestamp,
      sourceOrder: sourceOrder,
    );
  }

  factory _GroupTimelineItem.outbox({
    required LocalOutboxItem outbox,
    required DateTime timestamp,
    required int sourceOrder,
  }) {
    return _GroupTimelineItem._(
      outbox: outbox,
      timestamp: timestamp,
      sourceOrder: sourceOrder,
    );
  }

  factory _GroupTimelineItem.asCall({
    required AsCallSession session,
    required DateTime timestamp,
    required int sourceOrder,
  }) {
    return _GroupTimelineItem._(
      asCallSession: session,
      timestamp: timestamp,
      sourceOrder: sourceOrder,
    );
  }

  final DateTime timestamp;
  final int _sourceOrder;
  final Event? _event;
  final LocalOutboxItem? _outbox;
  final AsCallSession? _asCallSession;

  TResult when<TResult>({
    required TResult Function(Event event) event,
    required TResult Function(LocalOutboxItem outbox) outbox,
    required TResult Function(AsCallSession session) asCall,
  }) {
    final eventValue = _event;
    if (eventValue != null) return event(eventValue);
    final outboxValue = _outbox;
    if (outboxValue != null) return outbox(outboxValue);
    final asCallValue = _asCallSession;
    if (asCallValue != null) return asCall(asCallValue);
    throw StateError('Group timeline item contains no source');
  }
}

List<_GroupTimelineItem> _mergeGroupTimelineItems({
  required List<Event> events,
  required DateTime Function(Event event) eventTimestamp,
  DateTime? Function(Event event)? eventSortTimestamp,
  required List<LocalOutboxItem> outboxItems,
  required DateTime Function(LocalOutboxItem outbox) outboxTimestamp,
  required List<AsCallSession> asCallSessions,
}) {
  final items = <_GroupTimelineItem>[];
  var sourceOrder = 0;
  for (final event in events) {
    items.add(
      _GroupTimelineItem.event(
        event: event,
        timestamp: eventSortTimestamp?.call(event) ?? eventTimestamp(event),
        sourceOrder: sourceOrder++,
      ),
    );
  }
  for (final outbox in outboxItems) {
    items.add(
      _GroupTimelineItem.outbox(
        outbox: outbox,
        timestamp: outboxTimestamp(outbox),
        sourceOrder: sourceOrder++,
      ),
    );
  }
  for (final session in asCallSessions) {
    items.add(
      _GroupTimelineItem.asCall(
        session: session,
        timestamp: asCallSessionStableTimestamp(session),
        sourceOrder: sourceOrder++,
      ),
    );
  }
  items.sort((a, b) {
    final timestampOrder = b.timestamp.compareTo(a.timestamp);
    if (timestampOrder != 0) return timestampOrder;
    return a._sourceOrder.compareTo(b._sourceOrder);
  });
  return items;
}

String _fallbackDisplayNameForMxid(String mxid) {
  final trimmed = mxid.trim();
  if (trimmed.isEmpty) return '未知成员';
  final match = RegExp(r'^@([^:]+):(.+)$').firstMatch(trimmed);
  if (match == null) return trimmed;
  final localpart = match.group(1) ?? '';
  final domain = match.group(2) ?? '';
  if (localpart.toLowerCase() == 'owner' && domain.isNotEmpty) {
    return domain;
  }
  return localpart.isEmpty ? trimmed : localpart;
}

class GroupChatPage extends ConsumerStatefulWidget {
  const GroupChatPage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends ConsumerState<GroupChatPage> {
  final _msgCtrl = TextEditingController();
  Timeline? _timeline;
  bool _loading = true;
  bool _readMarkerInFlight = false;
  bool _readMarkerQueued = false;
  bool _thumbnailWarmupInFlight = false;
  final Set<String> _warmedThumbnailEventIds = {};
  final Set<String> _favoritingEventIds = {};
  final Set<String> _retryingOutboxIds = {};
  final Set<String> _downloadingFileEventIds = {};
  final Set<String> _downloadedFileEventIds = {};
  final Map<String, AsCallSession> _roomAsCallHistory = {};
  final ChatInitialEntranceRegistry _initialTimelineEntrances =
      ChatInitialEntranceRegistry();
  Timer? _initialTimelineEntranceTimer;
  Timer? _asCallHistoryReloadTimer;
  bool _roomAsCallHistoryRefreshing = false;
  bool _multiSelect = false;
  bool _showPlusPanel = false;
  bool _showEmojiPanel = false;
  final Set<String> _selected = {};
  Event? _replyTo;

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

  void _openChatRecordDetail(ChatRecordPayload payload) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatRecordDetailPage(payload: payload),
      ),
    );
  }

  Object _timelineItemKey(_GroupTimelineItem item) {
    return item.when<Object>(
      event: (event) {
        final id = event.eventId.trim();
        return id.isEmpty
            ? 'group-event-object-${identityHashCode(event)}'
            : 'group-event-$id';
      },
      outbox: (outbox) => 'group-outbox-${outbox.id}',
      asCall: (session) => 'group-as-call-${session.callId}',
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

  Future<void> _openImageEvent(Event event, String meta) {
    final cacheKey = event.eventId.trim();
    final cacheFuture =
        cacheKey.isEmpty ? null : ref.read(mediaThumbnailCacheProvider.future);
    return showAsyncImagePreview(
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
        final file = await event.downloadAndDecryptAttachment();
        return MemoryImage(file.bytes);
      },
      meta: meta,
    );
  }

  Future<File> _materializeFileEvent(
    Event event, {
    required bool persistent,
  }) async {
    final matrixFile = await event.downloadAndDecryptAttachment();
    final baseDir = persistent
        ? Directory(
            '${(await getApplicationDocumentsDirectory()).path}/P2P IM Downloads',
          )
        : Directory('${(await getTemporaryDirectory()).path}/p2p-im-open');
    return writeChatActionFile(
      directory: baseDir,
      fileName: event.body,
      bytes: matrixFile.bytes,
    );
  }

  Future<void> _openFileEvent(Event event) async {
    try {
      final file = await _materializeFileEvent(event, persistent: false);
      await previewChatActionFile(file);
    } on Object catch (err) {
      debugPrint('open group file failed: $err');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开失败：$err')),
      );
    }
  }

  Future<void> _downloadFileEvent(Event event) async {
    final eventId = event.eventId.trim();
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
      final file = await _materializeFileEvent(event, persistent: true);
      if (!mounted) return;
      if (eventId.isNotEmpty) {
        setState(() => _downloadedFileEventIds.add(eventId));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已保存到 Files / Portal App / P2P IM Downloads / ${file.uri.pathSegments.last}',
          ),
        ),
      );
    } on Object catch (err) {
      debugPrint('download group file failed: $err');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载失败：$err')),
      );
    } finally {
      if (eventId.isNotEmpty && mounted) {
        setState(() => _downloadingFileEventIds.remove(eventId));
      }
    }
  }

  Room? get _room => ref.read(matrixClientProvider).getRoomById(widget.roomId);

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocalAsCallHistory());
    _initTimeline();
  }

  Future<void> _initTimeline() async {
    final room = _room;
    if (room == null) return;
    void rebuild() {
      if (mounted) setState(() {});
      _scheduleAsCallHistoryReloadForTimeline();
      _removeRecoveredUnreadTimelineDuplicates();
      _scheduleTimelineThumbnailWarmup();
      unawaited(_markCurrentTimelineRead());
    }

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
    if (tl != null &&
        shouldRequestHistoricalMessages(MessageHistoryLoadTrigger.chatOpen)) {
      unawaited(() async {
        var attempts = 0;
        while (attempts < 5 &&
            tl.canRequestHistory &&
            tl.events.where((e) => e.type == EventTypes.Message).length < 50) {
          try {
            await tl.requestHistory(historyCount: 30);
          } on Object catch (e) {
            debugPrint('timeline.requestHistory failed: $e');
            break;
          }
          attempts++;
        }
        if (mounted) setState(() {});
        _scheduleTimelineThumbnailWarmup();
      }());
    }
  }

  Future<void> _loadLocalAsCallHistory() async {
    try {
      final store = await ref.read(asCallSessionStoreProvider.future);
      final sessions = await store.readRoomStable(widget.roomId);
      if (!mounted) return;
      _replaceRoomAsCallHistory(sessions);
    } on Object catch (e) {
      debugPrint('load local group AS call history failed: $e');
    }
    unawaited(_refreshAsCallHistoryFromAs());
  }

  void _scheduleAsCallHistoryReloadForTimeline() {
    final rawTimelineEvents = _timeline?.events ?? const <Event>[];
    if (rawTimelineEvents.isEmpty) return;
    final callRecordContextEvents =
        callRecordContextEventsForTimeline(rawTimelineEvents);
    final visibleEvents = chatDisplayEventsForTimeline(rawTimelineEvents);
    if (!shouldReloadAsCallSessionsForGroupTimeline(
      visibleEvents: visibleEvents,
      callRecordContextEvents: callRecordContextEvents,
      currentSessions: _roomAsCallHistory.values,
    )) {
      return;
    }
    _asCallHistoryReloadTimer?.cancel();
    _asCallHistoryReloadTimer = Timer(
      const Duration(milliseconds: 150),
      () {
        if (mounted) unawaited(_loadLocalAsCallHistory());
      },
    );
  }

  Future<void> _refreshAsCallHistoryFromAs() async {
    if (_roomAsCallHistoryRefreshing) return;
    _roomAsCallHistoryRefreshing = true;
    try {
      final asClient = ref.read(asClientProvider);
      final store = await ref.read(asCallSessionStoreProvider.future);
      final sessions = await asClient.listCalls(
        roomId: widget.roomId,
        limit: 100,
      );
      await store.upsertAll(sessions);
      final stable = await store.readRoomStable(widget.roomId);
      if (!mounted) return;
      _replaceRoomAsCallHistory(stable);
    } on Object catch (e) {
      debugPrint('refresh group AS call history failed: $e');
    } finally {
      _roomAsCallHistoryRefreshing = false;
    }
  }

  void _replaceRoomAsCallHistory(Iterable<AsCallSession> sessions) {
    final next = <String, AsCallSession>{};
    for (final session in sessions) {
      final callId = session.callId.trim();
      if (callId.isEmpty) continue;
      next[callId] = session;
    }
    if (!mounted) return;
    setState(() {
      _roomAsCallHistory
        ..clear()
        ..addAll(next);
    });
  }

  String _displayNameForMxid(
    Room room,
    AsSyncCacheState syncCache,
    String mxid,
  ) {
    final trimmed = mxid.trim();
    if (trimmed.isEmpty) return '未知成员';
    for (final member in room.getParticipants()) {
      if (member.id.trim() != trimmed) continue;
      final displayName = member.calcDisplayname().trim();
      if (displayName.isNotEmpty && displayName.toLowerCase() != 'owner') {
        return displayName;
      }
      break;
    }
    final contact = syncCache.contactForUserId(trimmed);
    final contactName = contact?.displayName.trim() ?? '';
    if (contactName.isNotEmpty && contactName.toLowerCase() != 'owner') {
      return contactName;
    }
    return _fallbackDisplayNameForMxid(trimmed);
  }

  String? _avatarUrlForMxid(
    Room room,
    AsSyncCacheState syncCache,
    String mxid,
  ) {
    final trimmed = mxid.trim();
    if (trimmed.isEmpty) return null;
    final contact = syncCache.contactForUserId(trimmed);
    final member = room.unsafeGetUserFromMemoryOrFallback(trimmed);
    return avatarHttpUrl(room.client, contact?.avatarUrl) ??
        matrixContentHttpUrl(room.client, member.avatarUrl);
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
        debugPrint('group thumbnail warmup failed: $e');
      } finally {
        _thumbnailWarmupInFlight = false;
        if (mounted) _scheduleTimelineThumbnailWarmup();
      }
    }());
  }

  Future<void> _markCurrentTimelineRead() async {
    final room = _room;
    final timeline = _timeline;
    if (room == null || timeline == null) return;
    final markerEvent = latestSyncedMessageEvent(timeline);
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
    _timeline?.cancelSubscriptions();
    _initialTimelineEntranceTimer?.cancel();
    _asCallHistoryReloadTimer?.cancel();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final room = _room;
    if (room == null) return;
    _msgCtrl.clear();
    setState(() => _replyTo = null);
    try {
      await ref.read(asClientProvider).sendRoomMessage(room.id, text);
      await ref.read(matrixClientProvider).oneShotSync();
    } on Object catch (e) {
      if (!mounted) return;
      _msgCtrl.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败：$e')),
      );
    }
  }

  bool _canSendGroupMessage(Room room, AsSyncCacheState syncCache) {
    final isJoinedAsGroup = syncCache.bootstrap?.groups.any(
          (group) => group.roomId.trim() == room.id,
        ) ??
        false;
    return isJoinedAsGroup && room.membership == Membership.join;
  }

  void _showGroupCannotSendToast(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('加入群聊后才能发送消息')),
    );
  }

  Future<String> _addPendingImageUpload(ChatMediaAttachment attachment) {
    return startMediaOutboxItem(
      notifier: ref.read(localOutboxProvider.notifier),
      conversationId: widget.roomId,
      conversationType: LocalOutboxConversationType.group,
      attachment: attachment,
    );
  }

  Future<List<String>> _addPendingImageUploads(
    List<ChatMediaAttachment> attachments,
  ) {
    return startImageOutboxItems(
      notifier: ref.read(localOutboxProvider.notifier),
      conversationId: widget.roomId,
      conversationType: LocalOutboxConversationType.group,
      attachments: attachments,
    );
  }

  Future<String> _addPendingFileUpload(ChatMediaAttachment attachment) {
    return startMediaOutboxItem(
      notifier: ref.read(localOutboxProvider.notifier),
      conversationId: widget.roomId,
      conversationType: LocalOutboxConversationType.group,
      attachment: attachment,
    );
  }

  Future<String> _addPendingVideoUpload(ChatMediaAttachment attachment) {
    return startMediaOutboxItem(
      notifier: ref.read(localOutboxProvider.notifier),
      conversationId: widget.roomId,
      conversationType: LocalOutboxConversationType.group,
      attachment: attachment,
    );
  }

  Future<void> _removePendingMediaUpload(String id) {
    return ref.read(localOutboxProvider.notifier).completeItem(id);
  }

  Future<void> _failPendingMediaUpload(String id) {
    return ref.read(localOutboxProvider.notifier).failItem(id);
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

  Future<void> _retryFailedMediaUpload(LocalOutboxItem item) async {
    if (_retryingOutboxIds.contains(item.id)) return;
    final room = _room;
    if (room == null) return;
    if (!_canSendGroupMessage(room, ref.read(asSyncCacheProvider))) {
      _showGroupCannotSendToast(context);
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
        _ => ChatMediaAttachment.file(
            name: item.filename.isEmpty ? 'file' : item.filename,
            bytes: bytes,
            mimeType: item.mimeType,
          ),
      };
      await sendProductMediaWithPendingState(
        messenger: ScaffoldMessenger.of(context),
        attachment: attachment,
        sendAttachment: createProductRoomMediaSender(
          matrixClient: ref.read(matrixClientProvider),
          asClient: ref.read(asClientProvider),
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

  Future<void> _onLongPressEvent(
    Event event,
    Offset position, {
    required String roomName,
  }) async {
    final action = await _showGroupMessageContextMenu(context, position);
    if (!mounted || action == null) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: event.body));
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
        await _forwardEvents([event], roomName);
        break;
      case 'quote':
        setState(() => _replyTo = event);
        break;
      case 'delete':
        await _deleteEventForMe(event);
        break;
      case 'fav':
        await _favoriteEvent(event);
        break;
      case 'multi':
        setState(() {
          _multiSelect = true;
          _selected.add(event.eventId);
        });
        break;
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
      debugPrint('delete group message for me failed: $err');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除消息失败：$err')),
      );
    }
  }

  Future<void> _refreshBootstrapAfterVisibilityMutation() async {
    try {
      final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
    } on Object catch (e) {
      debugPrint('refresh bootstrap after group message delete failed: $e');
    }
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
      debugPrint('favorite group message failed: $err');
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

  Future<AsFavoriteMessageDraft> _favoriteDraftForEvent(Event event) async {
    final ownerUserId = ref.read(matrixClientProvider).userID ?? '';
    final baseDraft = favoriteDraftFromMatrixMessage(
      roomId: widget.roomId,
      eventId: event.eventId,
      roomType: 'group',
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
    return favoriteDraftFromMatrixMessage(
      roomId: widget.roomId,
      eventId: event.eventId,
      roomType: 'group',
      senderId: event.senderId,
      senderName: event.senderFromMemoryOrFallback.calcDisplayname(),
      body: event.body,
      content: Map<String, Object?>.from(event.content),
      originServerTs: event.originServerTs.millisecondsSinceEpoch,
      savedMediaUrl: savedMedia,
    );
  }

  Future<void> _forwardSelectedEvents(List<Event> events, String roomName) {
    final selectedEvents = events
        .where((event) => _selected.contains(event.eventId))
        .toList(growable: false)
      ..sort((a, b) => a.originServerTs.compareTo(b.originServerTs));
    return _forwardEvents(selectedEvents, roomName);
  }

  Future<void> _forwardEvents(
      List<Event> selectedEvents, String roomName) async {
    if (selectedEvents.isEmpty) return;
    final payload = buildChatRecordPayload(
      sourceRoomId: widget.roomId,
      sourceRoomType: 'group',
      sourceName: roomName,
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
        currentRoomName: roomName,
        currentRoomType: 'group',
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

  @override
  Widget build(BuildContext context) {
    final room = _room;
    if (room == null) {
      final t = context.tk;
      return Scaffold(
        body: ChatGlassBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ChatCapsuleHeader(
                  title: '群组不存在',
                  onBack: () => unawaited(_popGroupChatOrHome(context)),
                  leadingAvatar: const _GroupAvatar(seed: '#'),
                  actions: const [],
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '这个群聊暂时无法打开',
                    style: AppTheme.sans(size: 15, color: t.textMute),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final t = context.tk;
    final name = room.getLocalizedDisplayname();
    final memberCount = room.summary.mJoinedMemberCount ?? 0;
    final syncCache = ref.watch(asSyncCacheProvider);
    final rawTimelineEvents = _timeline?.events ?? const <Event>[];
    final callRecordContextEvents =
        callRecordContextEventsForTimeline(rawTimelineEvents);
    final timelineEvents = chatDisplayEventsForTimeline(rawTimelineEvents);
    final activeTimelineGroupCall =
        activeGroupCallEntryForTimeline(rawTimelineEvents);
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
    final pendingMedia = ref
        .watch(localOutboxProvider)
        .itemsForConversation(
          widget.roomId,
          type: LocalOutboxConversationType.group,
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
    final messageOrder = ref.watch(localMessageOrderProvider);
    final asCallRecords = asCallSessionsForGroupTimeline(
      sessions: _roomAsCallHistory.values,
      roomId: widget.roomId,
      rawTimelineEvents: rawTimelineEvents,
      visibleEvents: events,
      callRecordContextEvents: callRecordContextEvents,
    );
    final visibleEvents = groupTimelineEventsReplacingAsCallSnapshots(
      visibleEvents: events,
      callRecordContextEvents: callRecordContextEvents,
      asCallSessions: asCallRecords,
    );
    final timelineItems = _mergeGroupTimelineItems(
      events: visibleEvents,
      eventTimestamp: (event) => event.originServerTs,
      eventSortTimestamp: (event) =>
          messageOrder.entryForEvent(event.eventId)?.createdAt,
      outboxItems: pendingMedia,
      outboxTimestamp: (item) => item.createdAt,
      asCallSessions: asCallRecords,
    );
    final timelineItemKeys = [
      for (final item in timelineItems) _timelineItemKey(item),
    ];
    _seedInitialTimelineEntrances(timelineItemKeys);
    final newestTimelineItemKey =
        timelineItemKeys.isEmpty ? null : timelineItemKeys.first;
    final canSendMessages = _canSendGroupMessage(room, syncCache);
    final myId = ref.read(matrixClientProvider).userID;
    final messagePadding = chatMessageViewportPadding(
      context,
      horizontal: 16,
      replyBarVisible: _replyTo != null,
      selectionBarVisible: _multiSelect,
      bottomPanelVisible: _showPlusPanel || _showEmojiPanel,
    ).add(const EdgeInsets.symmetric(vertical: 12));
    final voiceCallController = ref.watch(voiceCallControllerProvider);

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
              : StreamBuilder<GroupCallUiState>(
                  stream: voiceCallController.groupStateStream,
                  initialData: voiceCallController.currentGroupState,
                  builder: (context, snapshot) {
                    final activeGroupCall = _activeGroupCallForHeader(
                      controllerState: snapshot.data ?? GroupCallUiState.idle,
                      timelineEntry: activeTimelineGroupCall,
                      roomId: widget.roomId,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: ChatCapsuleHeader(
                        title: name,
                        subtitle: activeGroupCall == null
                            ? '$memberCount 名成员'
                            : '正在群通话',
                        onTitleTap: activeGroupCall == null
                            ? null
                            : () => context.push(
                                  groupCallJoinRoute(
                                    roomId: widget.roomId,
                                    roomName: name,
                                    callType: activeGroupCall.callType,
                                    callId: activeGroupCall.callId,
                                    incoming: activeGroupCall.requiresJoin,
                                  ),
                                ),
                        onBack: () => unawaited(_popGroupChatOrHome(context)),
                        leadingAvatar: _GroupAvatar(
                          seed: name,
                          imageUrl: roomAvatarHttpUrl(room),
                        ),
                        actions: [
                          ChatCapsuleAction(
                            icon: Symbols.call,
                            tooltip: '语音通话',
                            color: t.accent,
                            onTap: () => context.push(
                              groupCallInviteRoute(
                                roomId: widget.roomId,
                                roomName: name,
                                callType: ProductCallType.voice,
                              ),
                            ),
                          ),
                          ChatCapsuleAction(
                            icon: Symbols.more_vert,
                            tooltip: '详情',
                            color: t.accent,
                            onTap: () => context.push(
                              '/group-info/${Uri.encodeComponent(widget.roomId)}',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
                : timelineItems.isEmpty
                    ? Center(
                        child: Text(
                          '还没有消息',
                          style: AppTheme.sans(size: 13, color: t.textMute),
                        ),
                      )
                    : ChatTimelineListMotion(
                        itemCount: timelineItems.length,
                        newestItemKey: newestTimelineItemKey,
                        child: ListView.builder(
                          reverse: true,
                          padding: messagePadding,
                          itemCount: timelineItems.length,
                          itemBuilder: (context, i) {
                            final itemKey = timelineItemKeys[i];
                            Widget enter(
                              Widget child, {
                              required bool isMe,
                              required Object id,
                            }) {
                              return chatMessageEntrance(
                                key: ValueKey('group_message_enter_$id'),
                                isMe: isMe,
                                index: i,
                                enabled:
                                    _initialTimelineEntrances.contains(itemKey),
                                child: child,
                              );
                            }

                            return timelineItems[i].when(
                              outbox: (pending) => enter(
                                _GroupPendingMediaBubble(
                                  item: pending,
                                  onRetry: () => unawaited(
                                    _retryFailedMediaUpload(pending),
                                  ),
                                ),
                                isMe: true,
                                id: pending.id,
                              ),
                              asCall: (session) {
                                final callerId = session.createdByMxid.trim();
                                final callerIsMe = callerId == myId;
                                final senderName = _displayNameForMxid(
                                  room,
                                  syncCache,
                                  callerId,
                                );
                                final senderAvatarUrl = _avatarUrlForMxid(
                                  room,
                                  syncCache,
                                  callerId,
                                );
                                return enter(
                                  _GroupAsCallRecordMessageBubble(
                                    isMe: callerIsMe,
                                    senderId: callerId,
                                    senderName: senderName,
                                    senderAvatarUrl: senderAvatarUrl,
                                    isVideo:
                                        asCallSessionRecordIsVideo(session),
                                    text: asCallSessionRecordText(session),
                                    time: DateFormat('HH:mm').format(
                                      asCallSessionStableTimestamp(session)
                                          .toLocal(),
                                    ),
                                  ),
                                  isMe: callerIsMe,
                                  id: session.callId,
                                );
                              },
                              event: (e) {
                                final selected = _selected.contains(e.eventId);
                                final chatRecordPayload =
                                    chatRecordPayloadFromContent(
                                  Map<String, Object?>.from(e.content),
                                );
                                final channelSharePayload =
                                    channelSharePayloadFromContent(
                                  Map<String, Object?>.from(e.content),
                                );
                                final isMe = e.senderId == myId;
                                final senderAvatarUrl = _avatarUrlForMxid(
                                  room,
                                  syncCache,
                                  e.senderId,
                                );
                                void toggle() => setState(() {
                                      if (selected) {
                                        _selected.remove(e.eventId);
                                      } else {
                                        _selected.add(e.eventId);
                                      }
                                    });
                                if (isCallRecordEvent(e)) {
                                  final callId = asCallIdForCallRecord(
                                    e,
                                    callRecordContextEvents,
                                  );
                                  final pendingAsGroupCall =
                                      isProductGroupCallEvent(e) &&
                                          callId != null &&
                                          !_roomAsCallHistory.containsKey(
                                            callId.trim(),
                                          );
                                  final callerEvent = callRecordSenderEvent(
                                    e,
                                    callRecordContextEvents,
                                  );
                                  final callerId = callRecordSenderId(
                                    e,
                                    callRecordContextEvents,
                                  );
                                  final callerIsMe = callerId == myId;
                                  final callerName = callerEvent
                                          ?.senderFromMemoryOrFallback
                                          .calcDisplayname() ??
                                      e.senderFromMemoryOrFallback
                                          .calcDisplayname();
                                  return enter(
                                    _GroupCallRecordMessageBubble(
                                      event: callerEvent ?? e,
                                      isMe: callerIsMe,
                                      isVideo: callRecordIsVideo(
                                        e,
                                        callRecordContextEvents,
                                      ),
                                      text: callRecordText(
                                        e,
                                        callRecordContextEvents,
                                        asCallSessionPending:
                                            pendingAsGroupCall,
                                      ),
                                      senderName: callerName,
                                      senderAvatarUrl: _avatarUrlForMxid(
                                        room,
                                        syncCache,
                                        callerId,
                                      ),
                                      time: DateFormat('HH:mm').format(
                                        e.originServerTs.toLocal(),
                                      ),
                                      selected: selected,
                                      multiSelect: _multiSelect,
                                      onTap: _multiSelect ? toggle : null,
                                      onLongPressAt: (position) =>
                                          _onLongPressEvent(
                                        e,
                                        position,
                                        roomName: name,
                                      ),
                                    ),
                                    isMe: callerIsMe,
                                    id: e.eventId,
                                  );
                                }
                                if (e.messageType == MessageTypes.Image &&
                                    e.hasAttachment) {
                                  final senderName = e
                                      .senderFromMemoryOrFallback
                                      .calcDisplayname();
                                  final localOrder =
                                      messageOrder.entryForEvent(e.eventId);
                                  final time = DateFormat('HH:mm').format(
                                    (localOrder?.createdAt ?? e.originServerTs)
                                        .toLocal(),
                                  );
                                  return enter(
                                    _GroupImageMessageBubble(
                                      event: e,
                                      isMe: isMe,
                                      senderAvatarUrl: senderAvatarUrl,
                                      selected: selected,
                                      multiSelect: _multiSelect,
                                      onTap: _multiSelect
                                          ? toggle
                                          : () => unawaited(
                                                _openImageEvent(
                                                  e,
                                                  '${isMe ? '我' : senderName} · $time',
                                                ),
                                              ),
                                      onLongPressAt: (position) =>
                                          _onLongPressEvent(
                                        e,
                                        position,
                                        roomName: name,
                                      ),
                                    ),
                                    isMe: isMe,
                                    id: e.eventId,
                                  );
                                }
                                if (e.messageType == MessageTypes.Video &&
                                    e.hasAttachment) {
                                  return enter(
                                    _GroupImageMessageBubble(
                                      event: e,
                                      isMe: isMe,
                                      senderAvatarUrl: senderAvatarUrl,
                                      selected: selected,
                                      multiSelect: _multiSelect,
                                      fallbackIcon: Symbols.movie,
                                      centerOverlay:
                                          const _GroupVideoPlayOverlay(),
                                      onTap: _multiSelect
                                          ? toggle
                                          : () => unawaited(_openFileEvent(e)),
                                      onLongPressAt: (position) =>
                                          _onLongPressEvent(
                                        e,
                                        position,
                                        roomName: name,
                                      ),
                                    ),
                                    isMe: isMe,
                                    id: e.eventId,
                                  );
                                }
                                if ((e.messageType == MessageTypes.File ||
                                        e.messageType == MessageTypes.Audio) &&
                                    e.hasAttachment) {
                                  final localOrder =
                                      messageOrder.entryForEvent(e.eventId);
                                  final time = DateFormat('HH:mm').format(
                                    (localOrder?.createdAt ?? e.originServerTs)
                                        .toLocal(),
                                  );
                                  final size = e.infoMap['size'];
                                  final sizeBytes = size is int ? size : 0;
                                  final kind = fileKindLabel(
                                    e.attachmentMimetype,
                                    e.body,
                                  );
                                  final sizeLabel = sizeBytes > 0
                                      ? '$kind · ${formatByteSize(sizeBytes)}'
                                      : kind;
                                  final eventId = e.eventId.trim();
                                  return enter(
                                    _GroupFileMessageBubble(
                                      event: e,
                                      isMe: isMe,
                                      senderAvatarUrl: senderAvatarUrl,
                                      time: time,
                                      fileName: e.body,
                                      sizeLabel: sizeLabel,
                                      selected: selected,
                                      multiSelect: _multiSelect,
                                      trailing: _GroupFileDownloadStatusIcon(
                                        downloading: _downloadingFileEventIds
                                            .contains(eventId),
                                        downloaded: _downloadedFileEventIds
                                            .contains(eventId),
                                        onDownload: () => unawaited(
                                          _downloadFileEvent(e),
                                        ),
                                      ),
                                      onTap: _multiSelect
                                          ? toggle
                                          : () => unawaited(_openFileEvent(e)),
                                      onLongPressAt: (position) =>
                                          _onLongPressEvent(
                                        e,
                                        position,
                                        roomName: name,
                                      ),
                                    ),
                                    isMe: isMe,
                                    id: e.eventId,
                                  );
                                }
                                return enter(
                                  _GroupMessageBubble(
                                    event: e,
                                    isMe: isMe,
                                    senderAvatarUrl: senderAvatarUrl,
                                    selected: selected,
                                    multiSelect: _multiSelect,
                                    onTap: _multiSelect
                                        ? toggle
                                        : channelSharePayload != null
                                            ? () => context.push(
                                                  '/channel/${Uri.encodeComponent(channelSharePayload.channelId)}',
                                                )
                                            : chatRecordPayload == null
                                                ? null
                                                : () => _openChatRecordDetail(
                                                      chatRecordPayload,
                                                    ),
                                    onLongPressAt: (position) =>
                                        _onLongPressEvent(
                                      e,
                                      position,
                                      roomName: name,
                                    ),
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
                _GroupReplyBar(
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
                  onForward: () =>
                      unawaited(_forwardSelectedEvents(events, name)),
                  onDelete: () async {
                    for (final id in _selected.toList()) {
                      Event? selectedEvent;
                      for (final event in events) {
                        if (event.eventId == id) {
                          selectedEvent = event;
                          break;
                        }
                      }
                      if (selectedEvent != null) {
                        await _deleteEventForMe(selectedEvent);
                      }
                    }
                    if (!mounted) return;
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
                      : () => _showGroupCannotSendToast(context),
                  onEmoji: canSendMessages
                      ? _toggleEmoji
                      : () => _showGroupCannotSendToast(context),
                  plusActive: _showPlusPanel,
                  emojiActive: _showEmojiPanel,
                  enabled: canSendMessages,
                ),
              if (_showPlusPanel)
                ChatAttachmentPanel(
                  room: room,
                  roomId: widget.roomId,
                  canSend: canSendMessages,
                  useAsProductMedia: true,
                  onClose: () => setState(() => _showPlusPanel = false),
                  onCannotSend: _showGroupCannotSendToast,
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
                  onVideoCall: () {
                    context.push(
                      groupCallInviteRoute(
                        roomId: widget.roomId,
                        roomName: name,
                        callType: ProductCallType.video,
                      ),
                    );
                  },
                ),
              if (_showEmojiPanel)
                ChatEmojiPanel(
                  onPick: (emoji) {
                    final text = _msgCtrl.text;
                    _msgCtrl.text = text + emoji;
                    _msgCtrl.selection = TextSelection.collapsed(
                      offset: _msgCtrl.text.length,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 头部群头像：squircle, tertiary-container 底, 白色字。
class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.seed, this.imageUrl});
  final String seed;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return PortalAvatar(
      seed: seed,
      size: 36,
      imageUrl: imageUrl,
      shape: AvatarShape.squircle,
    );
  }
}

class _GroupImageMessageBubble extends StatelessWidget {
  const _GroupImageMessageBubble({
    required this.event,
    required this.isMe,
    required this.onLongPressAt,
    required this.selected,
    required this.multiSelect,
    this.senderAvatarUrl,
    this.fallbackIcon = Symbols.broken_image,
    this.centerOverlay,
    this.onTap,
  });

  final Event event;
  final bool isMe;
  final ValueChanged<Offset> onLongPressAt;
  final bool selected;
  final bool multiSelect;
  final String? senderAvatarUrl;
  final IconData fallbackIcon;
  final Widget? centerOverlay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final image = GestureDetector(
      onTap: onTap,
      onLongPressStart: (details) => onLongPressAt(details.globalPosition),
      child: ChatMediaBubbleFrame(
        width: 208,
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _GroupMatrixThumb(
              key: ValueKey(
                'group_matrix_thumb_${event.eventId}_${event.originServerTs.millisecondsSinceEpoch}',
              ),
              event: event,
              fallbackIcon: fallbackIcon,
            ),
            if (centerOverlay != null) centerOverlay!,
            if (selected)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.18),
                ),
              ),
          ],
        ),
      ),
    );

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (multiSelect) ...[
            _GroupMessageSelectCheckmark(selected: selected, onTap: onTap),
            const SizedBox(width: 8),
          ],
          if (!isMe) ...[
            _MemberAvatar(
              seed: event.senderId,
              name: senderName,
              imageUrl: senderAvatarUrl,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        senderName,
                        style: AppTheme.sans(size: 11, color: t.textMute),
                      ),
                    ),
                  image,
                  Padding(
                    padding: EdgeInsets.only(
                      top: 4,
                      left: isMe ? 0 : 4,
                      right: isMe ? 4 : 0,
                    ),
                    child: Text(
                      DateFormat('HH:mm')
                          .format(event.originServerTs.toLocal()),
                      style: AppTheme.sans(size: 11, color: t.textMute),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

class _GroupMatrixThumb extends ConsumerWidget {
  const _GroupMatrixThumb({
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

class _GroupFileMessageBubble extends StatelessWidget {
  const _GroupFileMessageBubble({
    required this.event,
    required this.isMe,
    required this.time,
    required this.fileName,
    required this.sizeLabel,
    required this.trailing,
    required this.onLongPressAt,
    required this.selected,
    required this.multiSelect,
    this.senderAvatarUrl,
    this.onTap,
  });

  final Event event;
  final bool isMe;
  final String time;
  final String fileName;
  final String sizeLabel;
  final Widget trailing;
  final ValueChanged<Offset> onLongPressAt;
  final bool selected;
  final bool multiSelect;
  final String? senderAvatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final cardColor = selected ? t.accent.withValues(alpha: 0.18) : t.surface;
    final card = _GroupFileCardSurface(
      isMe: isMe,
      color: cardColor,
      borderRadius: chatMessageBubbleRadius,
      fileName: fileName,
      sizeLabel: sizeLabel,
      trailing: multiSelect
          ? Icon(Symbols.description, size: 20, color: t.textMute)
          : trailing,
      selected: selected,
      onTap: onTap,
      onLongPressAt: onLongPressAt,
    );

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (multiSelect) ...[
            _GroupMessageSelectCheckmark(selected: selected, onTap: onTap),
            const SizedBox(width: 8),
          ],
          if (!isMe) ...[
            _MemberAvatar(
              seed: event.senderId,
              name: senderName,
              imageUrl: senderAvatarUrl,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        senderName,
                        style: AppTheme.sans(size: 11, color: t.textMute),
                      ),
                    ),
                  card,
                  Padding(
                    padding: EdgeInsets.only(
                      top: 4,
                      left: isMe ? 0 : 4,
                      right: isMe ? 4 : 0,
                    ),
                    child: Text(
                      time,
                      style: AppTheme.sans(size: 11, color: t.textMute),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

class _GroupFileCardSurface extends StatelessWidget {
  const _GroupFileCardSurface({
    required this.isMe,
    required this.color,
    required this.borderRadius,
    required this.fileName,
    required this.sizeLabel,
    required this.trailing,
    this.selected = false,
    this.onTap,
    this.onLongPressAt,
  });

  final bool isMe;
  final Color color;
  final BorderRadius borderRadius;
  final String fileName;
  final String sizeLabel;
  final Widget trailing;
  final bool selected;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Offset pressPosition = Offset.zero;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => pressPosition = details.globalPosition,
      onTap: onTap,
      onLongPress:
          onLongPressAt == null ? null : () => onLongPressAt!(pressPosition),
      onSecondaryTapDown: (details) => pressPosition = details.globalPosition,
      onSecondaryTap:
          onLongPressAt == null ? null : () => onLongPressAt!(pressPosition),
      child: ChatBubbleFrame(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: t.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(Symbols.description, size: 22, color: t.danger),
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
                        size: 13,
                        color: t.text,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sizeLabel,
                      style: AppTheme.sans(size: 11, color: t.textMute),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// 群消息气泡：他人 = 头像 + 姓名 + surface 气泡 + 左上小圆角;
/// 我方 = 右对齐 accent 气泡 + 右上小圆角，无头像无姓名。
class _GroupMessageSelectCheckmark extends StatelessWidget {
  const _GroupMessageSelectCheckmark({
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

class _GroupMessageBubble extends StatelessWidget {
  const _GroupMessageBubble({
    required this.event,
    required this.isMe,
    required this.onLongPressAt,
    required this.selected,
    required this.multiSelect,
    this.senderAvatarUrl,
    this.onTap,
  });
  final Event event;
  final bool isMe;
  final ValueChanged<Offset> onLongPressAt;
  final bool selected;
  final bool multiSelect;
  final String? senderAvatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final body = event.body;
    final chatRecordPayload = chatRecordPayloadFromContent(
      Map<String, Object?>.from(event.content),
    );
    final channelSharePayload = channelSharePayloadFromContent(
      Map<String, Object?>.from(event.content),
    );
    final bubbleColor = selected
        ? t.accent.withValues(alpha: 0.18)
        : isMe
            ? t.accent
            : t.surface;

    final bubble = channelSharePayload != null
        ? ChannelSharePreviewCard(
            payload: channelSharePayload,
            onTap: onTap,
            onLongPressAt: onLongPressAt,
          )
        : chatRecordPayload == null
            ? GestureDetector(
                onTap: onTap,
                onLongPressStart: (details) =>
                    onLongPressAt(details.globalPosition),
                child: ChatBubbleFrame(
                  child: Container(
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: chatMessageBubbleRadius,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Text(
                      body,
                      style: AppTheme.sans(
                        size: 17,
                        color: selected
                            ? t.text
                            : isMe
                                ? t.onAccent
                                : t.text,
                      ),
                    ),
                  ),
                ),
              )
            : ChatRecordPreviewCard(
                payload: chatRecordPayload,
                onTap: onTap,
                onLongPressAt: onLongPressAt,
              );

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (multiSelect) ...[
            _GroupMessageSelectCheckmark(selected: selected, onTap: onTap),
            const SizedBox(width: 8),
          ],
          if (!isMe) ...[
            _MemberAvatar(
              seed: event.senderId,
              name: senderName,
              imageUrl: senderAvatarUrl,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        senderName,
                        style: AppTheme.sans(size: 11, color: t.textMute),
                      ),
                    ),
                  bubble,
                  Padding(
                    padding: EdgeInsets.only(
                      top: 4,
                      left: isMe ? 0 : 4,
                      right: isMe ? 4 : 0,
                    ),
                    child: Text(
                      DateFormat('HH:mm')
                          .format(event.originServerTs.toLocal()),
                      style: AppTheme.sans(size: 11, color: t.textMute),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

class _GroupCallRecordMessageBubble extends StatelessWidget {
  const _GroupCallRecordMessageBubble({
    required this.event,
    required this.isMe,
    required this.isVideo,
    required this.text,
    required this.senderName,
    this.senderAvatarUrl,
    required this.time,
    required this.onLongPressAt,
    required this.selected,
    required this.multiSelect,
    this.onTap,
  });

  final Event event;
  final bool isMe;
  final bool isVideo;
  final String text;
  final String senderName;
  final String? senderAvatarUrl;
  final String time;
  final ValueChanged<Offset> onLongPressAt;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (multiSelect) ...[
            _GroupMessageSelectCheckmark(selected: selected, onTap: onTap),
            const SizedBox(width: 8),
          ],
          if (!isMe) ...[
            _MemberAvatar(
              seed: event.senderId,
              name: senderName,
              imageUrl: senderAvatarUrl,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        senderName,
                        style: AppTheme.sans(size: 11, color: t.textMute),
                      ),
                    ),
                  ChatCallRecordBubble(
                    isMe: isMe,
                    isVideo: isVideo,
                    text: text,
                    selected: selected,
                    onTap: multiSelect ? onTap : null,
                    onLongPressAt: onLongPressAt,
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: 4,
                      left: isMe ? 0 : 4,
                      right: isMe ? 4 : 0,
                    ),
                    child: Text(
                      time,
                      style: AppTheme.sans(size: 11, color: t.textMute),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

class _GroupAsCallRecordMessageBubble extends StatelessWidget {
  const _GroupAsCallRecordMessageBubble({
    required this.isMe,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.isVideo,
    required this.text,
    required this.time,
  });

  final bool isMe;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final bool isVideo;
  final String text;
  final String time;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _MemberAvatar(
              seed: senderId,
              name: senderName,
              imageUrl: senderAvatarUrl,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        senderName,
                        style: AppTheme.sans(size: 11, color: t.textMute),
                      ),
                    ),
                  ChatCallRecordBubble(
                    isMe: isMe,
                    isVideo: isVideo,
                    text: text,
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: 4,
                      left: isMe ? 0 : 4,
                      right: isMe ? 4 : 0,
                    ),
                    child: Text(
                      time,
                      style: AppTheme.sans(size: 11, color: t.textMute),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupPendingMediaBubble extends StatelessWidget {
  const _GroupPendingMediaBubble({
    required this.item,
    required this.onRetry,
  });

  final LocalOutboxItem item;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isFile = item.messageKind == LocalOutboxMessageKind.file;
    final isVideo = item.messageKind == LocalOutboxMessageKind.video;
    final time = DateFormat('HH:mm').format(item.createdAt.toLocal());
    final content = isFile
        ? _GroupPendingFileCard(item: item, onRetry: onRetry)
        : _GroupPendingImageCard(
            item: item,
            isVideo: isVideo,
            onRetry: onRetry,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  content,
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4),
                    child: Text(
                      time,
                      style: AppTheme.sans(
                        size: 11,
                        color: context.tk.textMute,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupPendingImageCard extends StatelessWidget {
  const _GroupPendingImageCard({
    required this.item,
    required this.isVideo,
    required this.onRetry,
  });

  final LocalOutboxItem item;
  final bool isVideo;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final displayBytes = item.thumbnailBytes ?? item.bytes;
    final thumb = item.status == LocalOutboxItemStatus.failed
        ? FailedLocalOutboxImageThumb(
            bytes: displayBytes,
            placeholderIcon: isVideo ? Symbols.movie : Symbols.image,
            overlay: isVideo ? const _GroupVideoPlayOverlay() : null,
            onRetry: onRetry,
          )
        : PendingLocalOutboxImageThumb(
            bytes: displayBytes!,
            overlay: isVideo ? const _GroupVideoPlayOverlay() : null,
          );
    return ChatMediaBubbleFrame(
      width: 208,
      height: 160,
      child: thumb,
    );
  }
}

class _GroupPendingFileCard extends StatelessWidget {
  const _GroupPendingFileCard({
    required this.item,
    required this.onRetry,
  });

  final LocalOutboxItem item;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return _GroupFileCardSurface(
      isMe: true,
      color: t.surface,
      borderRadius: chatMessageBubbleRadius,
      fileName: item.filename,
      sizeLabel: outboxFileSizeLabel(item),
      trailing: _GroupFileOutboxStatusIcon(
        status: item.status,
        onRetry: onRetry,
      ),
    );
  }
}

class _GroupFileOutboxStatusIcon extends StatelessWidget {
  const _GroupFileOutboxStatusIcon({
    required this.status,
    required this.onRetry,
  });

  final LocalOutboxItemStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (status == LocalOutboxItemStatus.sending) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
      );
    }
    return Semantics(
      button: true,
      label: '重新发送文件',
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

class _GroupFileDownloadStatusIcon extends StatelessWidget {
  const _GroupFileDownloadStatusIcon({
    required this.downloading,
    required this.downloaded,
    required this.onDownload,
  });

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
      label: '下载文件',
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

class _GroupVideoPlayOverlay extends StatelessWidget {
  const _GroupVideoPlayOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.48),
          shape: BoxShape.circle,
        ),
        child: const Icon(Symbols.play_arrow, color: Colors.white, size: 32),
      ),
    );
  }
}

Future<String?> _showGroupMessageContextMenu(
  BuildContext context,
  Offset position,
) {
  final size = MediaQuery.of(context).size;
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'group-msg-ctx',
    barrierColor: Colors.black.withValues(alpha: 0.15),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, a1, a2) {
      const menuW = 300.0;
      const menuH = 168.0;
      var left = position.dx - menuW / 2;
      var top = position.dy - menuH - 12;
      if (left < 12) left = 12;
      if (left + menuW > size.width - 12) left = size.width - menuW - 12;
      if (top < 60) top = position.dy + 12;
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: menuW,
            child: const _GroupMsgCtxMenuCard(),
          ),
        ],
      );
    },
    transitionBuilder: (ctx, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _GroupMsgCtxMenuCard extends StatelessWidget {
  const _GroupMsgCtxMenuCard();

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF1E2026);
    const divider = Color(0x1AFFFFFF);
    const labelColor = Color(0xB3FFFFFF);
    const iconColor = Color(0xCCFFFFFF);
    const danger = Color(0xFFFF6B6B);
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: dark,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicHeight(
              child: Row(
                children: [
                  _ctxBtn(
                    context,
                    Symbols.content_copy,
                    '复制',
                    'copy',
                    iconColor,
                    labelColor,
                  ),
                  const VerticalDivider(width: 1, color: divider),
                  _ctxBtn(
                    context,
                    Symbols.forward,
                    '转发',
                    'forward',
                    iconColor,
                    labelColor,
                  ),
                  const VerticalDivider(width: 1, color: divider),
                  _ctxBtn(
                    context,
                    Symbols.star,
                    '收藏',
                    'fav',
                    iconColor,
                    labelColor,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: divider),
            IntrinsicHeight(
              child: Row(
                children: [
                  _ctxBtn(
                    context,
                    Symbols.delete,
                    '删除',
                    'delete',
                    danger,
                    danger,
                  ),
                  const VerticalDivider(width: 1, color: divider),
                  _ctxBtn(
                    context,
                    Symbols.checklist,
                    '多选',
                    'multi',
                    iconColor,
                    labelColor,
                  ),
                  const VerticalDivider(width: 1, color: divider),
                  _ctxBtn(
                    context,
                    Symbols.format_quote,
                    '引用',
                    'quote',
                    iconColor,
                    labelColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctxBtn(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color iconColor,
    Color labelColor,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () => Navigator.of(context).pop(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTheme.sans(size: 12, color: labelColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupReplyBar extends StatelessWidget {
  const _GroupReplyBar({
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
        color: t.bg.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: t.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Icon(Symbols.reply, size: 16, color: t.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$sender: $text',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(size: 13, color: t.textMute),
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

/// 成员色彩头像：32×32 圆形，按 seed 取色。
class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.seed,
    required this.name,
    this.imageUrl,
  });
  final String seed;
  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return PortalAvatar(
      seed: name.isNotEmpty ? name : seed,
      size: 32,
      imageUrl: imageUrl,
    );
  }
}

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
import '../providers/agent_bridge_presence_provider.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_call_session_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/agent_offline_reply_provider.dart';
import '../providers/chat_clear_state_provider.dart';
import '../providers/conversation_summary_provider.dart';
import '../widgets/portal_avatar.dart';
import '../providers/local_message_order_provider.dart';
import '../providers/local_outbox_provider.dart';
import '../providers/matrix_message_clients_provider.dart';
import '../providers/media_thumbnail_cache_provider.dart';
import '../providers/product_conversations_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/voice_call_provider.dart';
import '../channel/channel_join_flow.dart';
import '../channel/channel_join_debug_log.dart';
import '../channel/channel_share.dart';
import '../channel/public_channel_target.dart';
import '../chat/agent_thinking_bubble.dart';
import '../chat/agent_message_content.dart';
import '../chat/agent_room_send_policy.dart';
import '../chat/agent_slash_commands.dart';
import '../chat/cached_thumbnail_image.dart';
import '../chat/chat_attachment_panel.dart';
import '../chat/chat_capsule_chrome.dart';
import '../chat/chat_event_preview_thumbnail.dart';
import '../chat/chat_glass_background.dart';
import '../chat/chat_event_open_guard.dart';
import '../chat/chat_avatar_snapshot_cache.dart';
import '../chat/chat_room_recovery_controller.dart';
import '../chat/chat_room_recovery_sync.dart';
import '../chat/chat_timeline_controller.dart';
import '../chat/chat_timeline_event_source.dart';
import '../chat/chat_message_cards.dart';
import '../chat/call_timeline_events.dart';
import '../chat/chat_record_detail_page.dart';
import '../chat/chat_record_forwarding.dart';
import '../chat/group_call_history_merge.dart';
import '../chat/chat_scroll_metrics.dart';
import '../chat/chat_scroll_to_latest.dart';
import '../chat/chat_media_warmup.dart';
import '../chat/chat_media_send_flow.dart';
import '../chat/chat_timeline_items.dart';
import '../chat/chat_video_preview_page.dart';
import '../chat/chat_voice_player.dart';
import '../chat/chat_voice_recorder.dart';
import '../chat/favorite_message_mapper.dart';
import '../chat/local_outbox_image_thumb.dart';
import '../chat/product_media_outbox_flow.dart';
import '../chat/product_room_media_send_flow.dart';
import '../chat/red_packet_message.dart';
import '../groups/group_invite_card.dart';
import '../groups/group_invite_content.dart';
import '../groups/group_invite_join_flow.dart';
import '../utils/agent_identity.dart';
import '../utils/contact_display_name.dart';
import '../utils/conversation_capability_policy.dart';
import '../utils/direct_contact_status.dart';
import '../utils/avatar_url.dart';
import '../utils/chat_event_attachment.dart';
import '../utils/chat_file_actions.dart';
import '../utils/chat_time_format.dart';
import '../utils/message_preview.dart';
import '../utils/product_conversation_navigation.dart';
import '../utils/product_conversation_summary_writer.dart';
import '../utils/save_image_to_gallery.dart';
import '../widgets/async_image_preview.dart';
import '../widgets/agent_message_body.dart';
import '../../data/as_client.dart';
import '../../data/as_call_session_store.dart';
import '../../data/conversation_summary_store.dart';
import '../../data/local_outbox_store.dart';
import '../../data/matrix_room_history_sync.dart';
import '../../data/media_thumbnail_cache.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../call/voice_call_controller.dart';

void _chatGestureLog(String message) {
  debugPrint('[chat gesture] $message');
}

String _chatEventMimeType(Event event, {required String fallback}) {
  final mimeType = event.attachmentMimetype.trim();
  return mimeType.isEmpty ? fallback : mimeType;
}

// ═══════════════════════════════════════════════════════════════════════════
// CHAT PAGE — index.html `s-chat` 1:1 复刻
//
// 产品聊天页只保留真实 ProductCore / Matrix room 通路；占位 id 不再进入聊天。
// 视觉按 `s-chat` (index.html 第 392-505 行) 重写：头部 / 气泡 / 输入栏 /
// +号面板 / 表情面板 / 长按上下文菜单 / 多选栏 / 回复栏。
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
      // Old Matrix rooms can lack m.direct / native Direxio room profile after delete/re-add
      // flows. A joined room with exactly one non-agent peer must still use
      // P2P API as the authority for whether it is a valid private chat.
      joinedPersonPeerMxid(room) != null;
}

void _openChatRecordDetail(BuildContext context, ChatRecordPayload payload) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChatRecordDetailPage(payload: payload),
    ),
  );
}

bool _canSendRoomMessage(Room room, AsSyncCacheState syncCache) {
  if (isPortalAgentDirectRoom(room) || isBootstrapAgentRoom(room, syncCache)) {
    return true;
  }
  final isProductDirect = _isProductDirectRoomForChat(room, syncCache);
  if (!isProductDirect) return room.membership == Membership.join;
  if (syncCache.acceptedDirectRoomIds.contains(room.id)) {
    return true;
  }
  return syncCache.isPendingContactRoom(room.id) &&
      joinedPersonPeerMxid(room) != null;
}

const _privateConversationKinds = {
  asConversationKindDirect,
  asConversationKindAgent,
};

ConversationCapabilityPolicy _privateRoomCapabilityPolicy(
  Iterable<AsConversation> productConversations,
  Room room,
  AsSyncCacheState syncCache,
) {
  return conversationCapabilityPolicy(
    conversation: productConversationForRoom(
      productConversations,
      room.id,
      kinds: _privateConversationKinds,
    ),
    fallbackCanSend: _canSendRoomMessage(room, syncCache),
  );
}

bool _isAgentRoomForChat(
  Room room,
  AsSyncCacheState syncCache,
  Iterable<AsConversation> productConversations,
) {
  if (isPortalAgentDirectRoom(room)) return true;
  final roomId = room.id.trim();
  if (roomId.isEmpty) return false;
  if ((syncCache.bootstrap?.agentRoomId.trim() ?? '') == roomId) return true;
  return productConversationForRoom(
        productConversations,
        roomId,
        kinds: const {asConversationKindAgent},
      ) !=
      null;
}

bool _isPeerTyping(Room room, String peerMxid) {
  final peerId = peerMxid.trim();
  if (peerId.isEmpty) return false;
  return room.typingUsers.any((user) => user.id == peerId);
}

PresenceType? _peerPresence(Client client, String peerMxid) {
  final peerId = peerMxid.trim();
  if (peerId.isEmpty) return null;
  // The header needs the latest sync cache without doing network work in build.
  // ignore: deprecated_member_use
  return client.presences[peerId]?.presence;
}

bool _hasAgentReplyAfter(
  Iterable<Event> events,
  String? agentMxid,
  DateTime since,
) {
  final agent = agentMxid?.trim() ?? '';
  if (agent.isEmpty) return false;
  for (final event in events) {
    if (event.senderId.trim() != agent) continue;
    if (event.originServerTs.isAfter(since)) return true;
  }
  return false;
}

bool _conversationSummaryHasCachedMessage(
  ConversationSummaryState state,
  String roomId,
) {
  final normalizedRoomId = roomId.trim();
  if (normalizedRoomId.isEmpty || !state.loaded) return false;
  for (final entry in state.entries) {
    if (entry.roomId.trim() != normalizedRoomId) continue;
    return entry.lastMessage.trim().isNotEmpty || entry.previewTs > 0;
  }
  return false;
}

/// 字节数 → 人类可读，如 `2.8 MB`。
Future<void> _popChatOrHome(BuildContext context) async {
  final didPop = await Navigator.of(context).maybePop();
  if (!context.mounted || didPop) return;
  context.go('/home');
}

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.roomId, this.targetEventId});
  final String roomId;
  final String? targetEventId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _DirectTimelineItem {
  const _DirectTimelineItem._({
    required this.timestamp,
    required int sourceOrder,
    Event? event,
    LocalOutboxItem? outbox,
    AsCallSession? asCallSession,
  })  : _event = event,
        _outbox = outbox,
        _asCallSession = asCallSession,
        _sourceOrder = sourceOrder;

  factory _DirectTimelineItem.event({
    required Event event,
    required DateTime timestamp,
    required int sourceOrder,
  }) {
    return _DirectTimelineItem._(
      event: event,
      timestamp: timestamp,
      sourceOrder: sourceOrder,
    );
  }

  factory _DirectTimelineItem.outbox({
    required LocalOutboxItem outbox,
    required DateTime timestamp,
    required int sourceOrder,
  }) {
    return _DirectTimelineItem._(
      outbox: outbox,
      timestamp: timestamp,
      sourceOrder: sourceOrder,
    );
  }

  factory _DirectTimelineItem.asCall({
    required AsCallSession session,
    required DateTime timestamp,
    required int sourceOrder,
  }) {
    return _DirectTimelineItem._(
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
    throw StateError('Direct timeline item contains no source');
  }
}

class _DirectChatDisplayItem {
  const _DirectChatDisplayItem.timeline(this.timeline)
      : agentOfflineReplyIndex = null;

  const _DirectChatDisplayItem.agentOfflineReply(this.agentOfflineReplyIndex)
      : timeline = null;

  final _DirectTimelineItem? timeline;
  final int? agentOfflineReplyIndex;
}

bool _isCurrentUserTextTimelineItem(
  _DirectTimelineItem item,
  String? currentUserId,
) {
  final self = currentUserId?.trim() ?? '';
  return item.when(
    event: (event) =>
        self.isNotEmpty &&
        event.senderId.trim() == self &&
        event.messageType == MessageTypes.Text &&
        !event.redacted,
    outbox: (outbox) => outbox.messageKind == LocalOutboxMessageKind.text,
    asCall: (_) => false,
  );
}

List<_DirectChatDisplayItem> _buildDirectChatDisplayItems(
  List<_DirectTimelineItem> timelineItems, {
  required int agentOfflineReplyCount,
  required String? currentUserId,
}) {
  if (agentOfflineReplyCount <= 0) {
    return [
      for (final item in timelineItems) _DirectChatDisplayItem.timeline(item),
    ];
  }

  final anchorCount = timelineItems
      .where((item) => _isCurrentUserTextTimelineItem(item, currentUserId))
      .length;
  final anchoredReplyCount = math.min(agentOfflineReplyCount, anchorCount);
  final skippedAnchorCount = anchorCount - anchoredReplyCount;
  final displayItems = <_DirectChatDisplayItem>[];
  var seenAnchors = 0;
  var insertedReplies = 0;
  for (final item in timelineItems) {
    displayItems.add(_DirectChatDisplayItem.timeline(item));
    if (!_isCurrentUserTextTimelineItem(item, currentUserId)) continue;
    seenAnchors += 1;
    if (seenAnchors <= skippedAnchorCount) continue;
    displayItems.add(
      _DirectChatDisplayItem.agentOfflineReply(insertedReplies++),
    );
  }
  while (insertedReplies < agentOfflineReplyCount) {
    displayItems.add(
      _DirectChatDisplayItem.agentOfflineReply(insertedReplies++),
    );
  }
  return displayItems;
}

List<_DirectTimelineItem> _mergeDirectTimelineItems({
  required List<Event> events,
  required DateTime Function(Event event) eventTimestamp,
  DateTime? Function(Event event)? eventSortTimestamp,
  required List<LocalOutboxItem> outboxItems,
  required DateTime Function(LocalOutboxItem outbox) outboxTimestamp,
  required List<AsCallSession> asCallSessions,
}) {
  final items = <_DirectTimelineItem>[];
  var sourceOrder = 0;
  for (final event in events) {
    items.add(
      _DirectTimelineItem.event(
        event: event,
        timestamp: eventSortTimestamp?.call(event) ?? eventTimestamp(event),
        sourceOrder: sourceOrder++,
      ),
    );
  }
  for (final outbox in outboxItems) {
    items.add(
      _DirectTimelineItem.outbox(
        outbox: outbox,
        timestamp: outboxTimestamp(outbox),
        sourceOrder: sourceOrder++,
      ),
    );
  }
  for (final session in asCallSessions) {
    items.add(
      _DirectTimelineItem.asCall(
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

class _ChatPageState extends ConsumerState<ChatPage> {
  final _msgCtrl = TextEditingController();
  Timeline? _timeline;
  bool _readMarkerInFlight = false;
  bool _readMarkerQueued = false;
  bool _thumbnailWarmupInFlight = false;
  bool _historyRequestInFlight = false;
  final _missingRoomRecovery = ChatRoomRecoveryController();
  StreamSubscription<SyncUpdate>? _roomSyncSub;
  final Set<String> _warmedThumbnailEventIds = {};
  final Set<String> _retryingOutboxIds = {};
  final Set<String> _openingFileEventIds = {};
  final ChatEventOpenGuard _videoOpenGuard = ChatEventOpenGuard();
  final Set<String> _downloadingFileEventIds = {};
  final Set<String> _downloadedFileEventIds = {};
  final Set<String> _downloadingImageEventIds = {};
  final Set<String> _downloadedImageEventIds = {};
  final Set<String> _favoritingEventIds = {};
  final Set<String> _joiningGroupInviteEventIds = {};
  final Set<String> _joiningChannelShareIds = {};
  final Set<String> _requestedChannelShareIds = {};
  final Set<String> _locallyHiddenEventIds = {};
  final ChatAvatarSnapshotCache _avatarSnapshotCache =
      ChatAvatarSnapshotCache();
  final Map<String, AsCallSession> _asCallSessionCache = {};
  final Map<String, AsCallSession> _roomAsCallHistory = {};
  final Set<String> _loadingAsCallIds = {};
  // s-chat 视觉状态
  bool _showPlusPanel = false;
  bool _showEmojiPanel = false;
  bool _multiSelect = false;
  final Set<String> _selected = {};
  Event? _replyTo;
  final Map<String, _QuotedMessagePreview> _localReplyPreviews = {};
  final Map<String, GlobalKey> _messageAnchorKeys = {};
  final Map<String, int> _messageListIndexes = {};
  final ChatInitialEntranceRegistry _initialTimelineEntrances =
      ChatInitialEntranceRegistry();
  final ScrollController _messageScrollCtrl = ScrollController();
  final ChatScrollToLatestCoordinator _scrollToLatestCoordinator =
      ChatScrollToLatestCoordinator();
  Timer? _scrollToLatestRetryTimer;
  bool _pendingViewportScrollToBottom = false;
  double _lastKeyboardInsetBottom = 0;
  double _emojiPanelHeight = chatEmojiPanelDefaultHeight;
  bool _lastBottomPanelVisible = false;
  String? _pendingTargetEventId;
  int _targetEventScrollAttempts = 0;
  Timer? _targetEventScrollTimer;
  Timer? _initialTimelineEntranceTimer;
  Timer? _asCallHistoryReloadTimer;
  String? _flashingMessageEventId;
  Timer? _flashingMessageTimer;
  bool _roomAsCallHistoryRefreshing = false;
  final ChatVoicePlayer _voicePlayer = ChatVoicePlayer();
  final ChatVoiceRecorder _voiceRecorder = ChatVoiceRecorder();
  bool _stoppingVoiceRecording = false;
  StreamSubscription<VoiceCallUiState>? _voiceCallStateSub;
  Timer? _callHistoryFastReloadTimer;
  Timer? _callHistorySlowReloadTimer;
  DateTime? _agentThinkingSince;

  Room? get _room => ref.read(matrixClientProvider).getRoomById(widget.roomId);
  AppLocalizations? get _l10n =>
      Localizations.of<AppLocalizations>(context, AppLocalizations);

  void _debugMissingRoomState(String phase, {Object? error}) {
    final client = ref.read(matrixClientProvider);
    final syncCache = ref.read(asSyncCacheProvider);
    final bootstrap = syncCache.bootstrap;
    final targetRoomId = widget.roomId.trim();
    final agentMxid = portalAgentMxidForClient(client);
    final productConversations =
        ref.read(productConversationsProvider).valueOrNull ??
            const <AsConversation>[];
    final targetProducts = productConversations
        .where((conversation) => conversation.roomId.trim() == targetRoomId)
        .map(
          (conversation) =>
              '${conversation.conversationId}:${conversation.kind}:${conversation.roomId}:life=${conversation.lifecycle}:proj=${conversation.projectionState}:hydr=${conversation.hydrationState}:${conversation.title}',
        )
        .join('|');
    final matrixRooms = client.rooms
        .map(
          (room) =>
              '${room.id}:${room.membership.name}:agent=${isPortalAgentDirectRoom(room, agentMxid: agentMxid)}:name=${safeRoomDisplayName(room)}',
        )
        .join('|');
    debugPrint(
      '[chat-missing-room] phase=$phase targetRoomId=$targetRoomId '
      'error=${error ?? ""} userId=${client.userID} homeserver=${client.homeserver} '
      'agentMxid=$agentMxid '
      'bootstrapAgentRoomId=${bootstrap?.agentRoomId ?? ""} '
      'knownConversation=${_isKnownConversationRoom(syncCache)} '
      'recoveryInFlight=${_missingRoomRecovery.inFlight} '
      'recoveryAttempted=${_missingRoomRecovery.attempted} '
      'recoveryFailed=${_missingRoomRecovery.failed} '
      'productMatches=[$targetProducts] matrixRooms=[$matrixRooms]',
    );
  }

  void _onVoicePlaybackChanged() {
    if (mounted) setState(() {});
  }

  Object _timelineItemKey(_DirectTimelineItem item) {
    return item.when<Object>(
      event: (event) {
        final id = event.eventId.trim();
        return id.isEmpty
            ? 'event-object-${identityHashCode(event)}'
            : 'event-$id';
      },
      outbox: (outbox) => 'outbox-${outbox.id}',
      asCall: (session) => 'as-call-${session.callId}',
    );
  }

  GlobalKey _messageAnchorKey(String eventId) {
    final trimmed = eventId.trim();
    return _messageAnchorKeys.putIfAbsent(trimmed, GlobalKey.new);
  }

  void _scrollToQuotedEvent(String? eventId) {
    final trimmed = eventId?.trim() ?? '';
    if (trimmed.isEmpty) {
      _showQuotedMessageUnavailable();
      return;
    }
    if (_ensureQuotedEventVisible(trimmed)) return;
    final index = _messageListIndexes[trimmed];
    if (index == null ||
        chatScrollPositionWithDimensions(_messageScrollCtrl) == null) {
      _showQuotedMessageUnavailable();
      return;
    }
    unawaited(_scrollToQuotedEventIndex(trimmed, index));
  }

  bool _ensureQuotedEventVisible(String eventId) {
    final key = _messageAnchorKeys[eventId];
    final targetContext = key?.currentContext;
    if (targetContext == null) return false;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.35,
    );
    _flashMessage(eventId);
    return true;
  }

  Future<void> _scrollToQuotedEventIndex(
    String eventId,
    int index, {
    bool showUnavailable = true,
  }) async {
    final position = chatScrollPositionWithDimensions(_messageScrollCtrl);
    if (position == null) {
      if (showUnavailable) _showQuotedMessageUnavailable();
      return;
    }
    final estimate = (index * 88.0).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await _messageScrollCtrl.animateTo(
      estimate,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_ensureQuotedEventVisible(eventId) && showUnavailable) {
        _showQuotedMessageUnavailable();
      }
    });
  }

  void _scheduleTargetEventScroll() {
    final eventId = _pendingTargetEventId?.trim() ?? '';
    if (eventId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryScrollToTargetEvent();
    });
  }

  void _tryScrollToTargetEvent() {
    final eventId = _pendingTargetEventId?.trim() ?? '';
    if (eventId.isEmpty) return;
    if (_ensureQuotedEventVisible(eventId)) {
      _pendingTargetEventId = null;
      _targetEventScrollTimer?.cancel();
      return;
    }
    final index = _messageListIndexes[eventId];
    if (index != null &&
        chatScrollPositionWithDimensions(_messageScrollCtrl) != null) {
      _pendingTargetEventId = null;
      _targetEventScrollTimer?.cancel();
      unawaited(
        _scrollToQuotedEventIndex(eventId, index, showUnavailable: false),
      );
      return;
    }
    _targetEventScrollAttempts++;
    if (_targetEventScrollAttempts >= 12) {
      _pendingTargetEventId = null;
      return;
    }
    _targetEventScrollTimer?.cancel();
    _targetEventScrollTimer = Timer(
      const Duration(milliseconds: 120),
      _scheduleTargetEventScroll,
    );
  }

  void _showQuotedMessageUnavailable() {
    if (!mounted) return;
    final l10n = _l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(l10n?.groupChatOriginalMessageUnavailable ?? '原消息暂不可见')),
    );
  }

  void _flashMessage(String eventId) {
    final trimmed = eventId.trim();
    if (trimmed.isEmpty) return;
    _flashingMessageTimer?.cancel();
    if (mounted) setState(() => _flashingMessageEventId = trimmed);
    _flashingMessageTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _flashingMessageEventId = null);
    });
  }

  void _syncMessageListIndexes(
    List<_DirectTimelineItem> items, {
    required int leadingItems,
  }) {
    _messageListIndexes.clear();
    for (var i = 0; i < items.length; i++) {
      items[i].when(
        event: (event) {
          final id = event.eventId.trim();
          if (id.isNotEmpty) _messageListIndexes[id] = i + leadingItems;
        },
        outbox: (_) {},
        asCall: (_) {},
      );
    }
  }

  void _pruneMessageAnchors() {
    _messageAnchorKeys.removeWhere(
      (eventId, _) => !_messageListIndexes.containsKey(eventId),
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

  void _scheduleScrollToLatest(Object? newestItemKey) {
    final targetEventPending = (_pendingTargetEventId?.trim() ?? '').isNotEmpty;
    if (!_scrollToLatestCoordinator.request(
      newestItemKey,
      targetEventPending: targetEventPending,
    )) {
      return;
    }
    _runScheduledScrollToLatest(
      newestItemKey!,
      instant: _scrollToLatestCoordinator.shouldJump,
    );
  }

  void _runScheduledScrollToLatest(
    Object newestItemKey, {
    required bool instant,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetEventPending =
          (_pendingTargetEventId?.trim() ?? '').isNotEmpty;
      if (!_scrollToLatestCoordinator.shouldRun(
        newestItemKey,
        targetEventPending: targetEventPending,
      )) {
        return;
      }
      final position = chatScrollPositionWithDimensions(_messageScrollCtrl);
      final hasPosition = position != null;
      final target = position?.maxScrollExtent ?? 0;
      final isAtLatest = position != null &&
          (position.pixels - target).abs() < chatLatestAutoScrollTolerance;
      if (position != null && !isAtLatest) {
        if (instant) {
          _messageScrollCtrl.jumpTo(target);
        } else {
          unawaited(
            _messageScrollCtrl.animateTo(
              target,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            ),
          );
        }
      }
      final shouldRetry = _scrollToLatestCoordinator.shouldRetryAfterAttempt(
            newestItemKey,
            hasPosition: hasPosition,
            isAtLatest: isAtLatest,
            allowSettling: instant,
          ) &&
          (instant || !hasPosition);
      if (shouldRetry) {
        _scrollToLatestRetryTimer?.cancel();
        _scrollToLatestRetryTimer = Timer(
          chatLatestInitialAutoScrollRetryDelay,
          () {
            if (mounted) {
              _runScheduledScrollToLatest(newestItemKey, instant: instant);
            }
          },
        );
        return;
      }
      if (position == null) {
        _scrollToLatestCoordinator.cancel();
      } else {
        _scrollToLatestCoordinator.complete(newestItemKey);
      }
    });
  }

  void _scheduleViewportScrollToBottom() {
    if (_pendingViewportScrollToBottom) return;
    _pendingViewportScrollToBottom = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pendingViewportScrollToBottom = false;
      final position = chatScrollPositionWithDimensions(_messageScrollCtrl);
      if (position == null) return;
      final target = position.maxScrollExtent;
      if ((position.pixels - target).abs() < 1) return;
      unawaited(
        _messageScrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _pendingTargetEventId = widget.targetEventId?.trim();
    _voicePlayer.playback.addListener(_onVoicePlaybackChanged);
    _messageScrollCtrl.addListener(_onMessageScroll);
    _roomSyncSub = ref.read(matrixClientProvider).onSync.stream.listen((_) {
      if (!mounted) return;
      if (_room == null) {
        _debugMissingRoomState('sync-update-room-still-missing');
        return;
      }
      if (_timeline == null) {
        _debugMissingRoomState('sync-update-room-recovered');
        unawaited(_initTimeline());
      }
      setState(_missingRoomRecovery.reset);
    });
    _voiceCallStateSub ??= ref
        .read(voiceCallControllerProvider)
        .stateStream
        .listen(_handleVoiceCallHistoryState);
    unawaited(_loadLocalAsCallHistory());
    _initTimeline();
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _avatarSnapshotCache.clear();
    }
    if (oldWidget.targetEventId == widget.targetEventId) return;
    final eventId = widget.targetEventId?.trim() ?? '';
    if (eventId.isEmpty) return;
    _pendingTargetEventId = eventId;
    _targetEventScrollAttempts = 0;
    _scheduleTargetEventScroll();
  }

  void _onMessageScroll() {
    if (!_messageScrollCtrl.hasClients) return;
    final position = _messageScrollCtrl.position;
    if (position.pixels > position.minScrollExtent + 96) return;
    unawaited(_requestOlderMessages());
  }

  Future<void> _initTimeline() async {
    final room = _room;
    if (room == null) {
      _debugMissingRoomState('init-timeline-room-missing');
      return;
    }
    void rebuild() {
      if (!mounted) return;
      setState(() {});
      _scheduleTimelineThumbnailWarmup();
      _scheduleAsCallHistoryReloadForTimeline();
      unawaited(_markCurrentTimelineRead());
    }

    _timeline = await ChatTimelineController(
      room: room,
      rebuild: rebuild,
      debugLabel: 'private',
    ).openInitialTimeline();
    if (mounted) setState(() {});
    _scheduleTimelineThumbnailWarmup();
    unawaited(_markCurrentTimelineRead());
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
    _debugMissingRoomState('ensure-missing-room-sync');
    unawaited(_recoverMissingRoom());
  }

  void _retryMissingRoomSync() {
    _debugMissingRoomState('retry-missing-room-sync');
    setState(_missingRoomRecovery.retry);
    _ensureMissingRoomSync();
  }

  Future<void> _recoverMissingRoom() async {
    _debugMissingRoomState('recover-start');
    final result = await _missingRoomRecovery.runAttempt(
      attempt: () async {
        try {
          await _syncMissingRoomFromServer();
        } catch (e) {
          _debugMissingRoomState('recover-sync-error', error: e);
          debugPrint('missing chat room sync failed: $e');
        }
        _debugMissingRoomState('recover-after-sync');
        return mounted && _room != null;
      },
    );
    _debugMissingRoomState('recover-finish-$result');
    if (!mounted) return;
    if (result == ChatRoomRecoveryAttemptResult.recovered) {
      if (_timeline == null) await _initTimeline();
      return;
    }
    if (result == ChatRoomRecoveryAttemptResult.failed) setState(() {});
  }

  Future<void> _syncMissingRoomFromServer() async {
    final client = ref.read(matrixClientProvider);
    _debugMissingRoomState('sync-missing-room-request');
    await syncMissingRoomHistoryFromServer(
      roomId: widget.roomId,
      syncHistory: ({required roomId, required timelineLimit}) {
        debugPrint(
          '[chat-missing-room] sync-history roomId=$roomId '
          'timelineLimit=$timelineLimit userId=${client.userID} '
          'homeserver=${client.homeserver}',
        );
        return syncMatrixRoomHistory(
          client,
          roomId: roomId,
          timelineLimit: timelineLimit,
        );
      },
    );
  }

  Widget _missingRoomScaffold(
    String message, {
    bool loading = false,
    VoidCallback? onRetry,
  }) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
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
                  label: Text(l10n?.commonRetry ?? '重试'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestOlderMessages() async {
    if (_historyRequestInFlight) return;
    final timeline = _timeline;
    if (timeline == null) return;
    _historyRequestInFlight = true;
    try {
      await ChatTimelineController(
        room: timeline.room,
        rebuild: () {
          if (!mounted) return;
          setState(() {});
          _scheduleTimelineThumbnailWarmup();
          unawaited(_markCurrentTimelineRead());
        },
        debugLabel: 'private',
      ).requestOlderMessages(timeline);
    } finally {
      _historyRequestInFlight = false;
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

  Future<void> _loadLocalAsCallHistory() async {
    try {
      final store = await ref.read(asCallSessionStoreProvider.future);
      final sessions = await store.readRoomStable(widget.roomId);
      debugPrint(
        'chat direct call history local room=${widget.roomId} '
        'count=${sessions.length}',
      );
      if (!mounted) return;
      _replaceRoomAsCallHistory(sessions);
    } on Object catch (e) {
      debugPrint('load local direct P2P call history failed: $e');
    }
    unawaited(_refreshAsCallHistoryFromAs());
  }

  void _scheduleAsCallHistoryReloadForTimeline() {
    final room = _room;
    if (room == null) return;
    final rawTimelineEvents = timelineEventsIncludingRoomLastEvent(
      room,
      _timeline,
    );
    if (rawTimelineEvents.isEmpty) return;
    final callRecordContextEvents = callRecordContextEventsForTimeline(
      rawTimelineEvents,
    );
    final visibleEvents = chatDisplayEventsForTimeline(rawTimelineEvents);
    if (!shouldReloadAsCallSessionsForGroupTimeline(
      visibleEvents: visibleEvents,
      callRecordContextEvents: callRecordContextEvents,
      currentSessions: _roomAsCallHistory.values,
    )) {
      return;
    }
    _asCallHistoryReloadTimer?.cancel();
    _asCallHistoryReloadTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) unawaited(_loadLocalAsCallHistory());
    });
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
      debugPrint(
        'chat direct call history AS room=${widget.roomId} '
        'count=${sessions.length}',
      );
      await store.upsertAll(sessions);
      final stable = await store.readRoomStable(widget.roomId);
      if (!mounted) return;
      _replaceRoomAsCallHistory(stable);
    } on Object catch (e) {
      debugPrint('refresh direct P2P call history failed: $e');
    } finally {
      _roomAsCallHistoryRefreshing = false;
    }
  }

  void _handleVoiceCallHistoryState(VoiceCallUiState state) {
    if (!mounted || state.roomId != widget.roomId) return;
    if (state.status != VoiceCallStatus.ended &&
        state.status != VoiceCallStatus.failed) {
      return;
    }
    debugPrint(
      'chat direct call history schedule after call '
      'room=${widget.roomId} call_id=${state.callId ?? ""} '
      'status=${state.status.name}',
    );
    unawaited(_loadLocalAsCallHistory());
    _callHistoryFastReloadTimer?.cancel();
    _callHistorySlowReloadTimer?.cancel();
    _callHistoryFastReloadTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) unawaited(_loadLocalAsCallHistory());
    });
    _callHistorySlowReloadTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) unawaited(_loadLocalAsCallHistory());
    });
  }

  void _replaceRoomAsCallHistory(Iterable<AsCallSession> sessions) {
    final next = <String, AsCallSession>{};
    for (final session in sessions) {
      final callId = session.callId.trim();
      if (callId.isEmpty) continue;
      next[callId] = session;
      _asCallSessionCache[callId] = session;
    }
    if (!mounted) return;
    debugPrint(
      'chat direct call history replace room=${widget.roomId} '
      'terminal=${next.values.where(asCallSessionSnapshotIsTerminal).length} '
      'total=${next.length}',
    );
    setState(() {
      _roomAsCallHistory
        ..clear()
        ..addAll(next);
    });
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
      debugPrint('load cached P2P call session failed: $e');
    }

    try {
      final session = await ref.read(asClientProvider).getCall(callId);
      try {
        final store = await storeFuture;
        await store.upsert(session);
      } on Object catch (e) {
        debugPrint('persist P2P call session failed: $e');
      }
      if (!mounted) return;
      setState(() {
        _asCallSessionCache[callId] = session;
      });
    } on Object catch (e) {
      debugPrint('load P2P call session failed: $e');
    } finally {
      _loadingAsCallIds.remove(callId);
    }
  }

  Future<void> _markCurrentTimelineRead() async {
    if (!mounted) return;
    final room = _room;
    if (room == null) return;
    final timeline = _timeline;
    if (_readMarkerInFlight) {
      _readMarkerQueued = true;
      return;
    }

    _readMarkerInFlight = true;
    try {
      final changed = await ChatTimelineController(
        room: room,
        rebuild: () {
          if (mounted) setState(() {});
        },
        debugLabel: 'private',
      ).markCurrentTimelineRead(
        timeline: timeline,
        asClient: ref.read(asClientProvider),
        onUnreadCleared: (readAt) {
          if (!mounted) return;
          ref.read(asSyncCacheProvider.notifier).update(
                (state) => state.withRoomUnreadCleared(room.id, readAt: readAt),
              );
        },
      );
      if (changed && mounted) setState(() {});
    } finally {
      _readMarkerInFlight = false;
      if (_readMarkerQueued && mounted) {
        _readMarkerQueued = false;
        unawaited(_markCurrentTimelineRead());
      }
    }
  }

  @override
  void dispose() {
    _roomSyncSub?.cancel();
    _scrollToLatestRetryTimer?.cancel();
    _targetEventScrollTimer?.cancel();
    _initialTimelineEntranceTimer?.cancel();
    _asCallHistoryReloadTimer?.cancel();
    _callHistoryFastReloadTimer?.cancel();
    _callHistorySlowReloadTimer?.cancel();
    unawaited(_voiceCallStateSub?.cancel());
    _timeline?.cancelSubscriptions();
    _flashingMessageTimer?.cancel();
    _voicePlayer.playback.removeListener(_onVoicePlaybackChanged);
    unawaited(_voicePlayer.dispose());
    unawaited(_voiceRecorder.dispose());
    _messageScrollCtrl.dispose();
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
    final productConversations =
        ref.read(productConversationsProvider).valueOrNull ??
            const <AsConversation>[];
    final isAgent = _isAgentRoomForChat(room, syncCache, productConversations);
    final agentPresence =
        isAgent ? ref.read(agentBridgePresenceProvider) : null;
    final agentIsOffline =
        agentPresence?.state == AgentBridgePresenceState.offline;
    final capabilityPolicy = _privateRoomCapabilityPolicy(
      productConversations,
      room,
      syncCache,
    );
    if (!capabilityPolicy.canSendText) {
      final l10n = _l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n?.chatPeerAcceptBeforeSend ?? '对方接受好友请求后才能发送消息')),
      );
      return;
    }
    _msgCtrl.clear();
    setState(() => _replyTo = null);
    String? pendingId;
    try {
      pendingId = await ref.read(localOutboxProvider.notifier).startItem(
            conversationId: widget.roomId,
            conversationType: LocalOutboxConversationType.direct,
            draft: LocalOutboxDraft.text(text: text),
          );
    } on Object catch (e) {
      debugPrint('start local text outbox failed: $e');
    }
    try {
      if (isAgent) {
        if (!agentIsOffline && mounted) {
          setState(() => _agentThinkingSince = DateTime.now());
          _scheduleViewportScrollToBottom();
        } else {
          ref
              .read(agentOfflineReplyCacheProvider.notifier)
              .increment(widget.roomId);
          _scheduleViewportScrollToBottom();
        }
        await sendAgentRoomText(room, text, inReplyTo: replyTo);
      } else if (_isProductDirectRoomForChat(room, syncCache)) {
        final eventId = await _sendProductDirectText(room, text, replyTo);
        _rememberLocalReplyPreview(eventId, replyTo);
        try {
          await ref.read(matrixClientProvider).oneShotSync();
        } on Object catch (e) {
          debugPrint('post-send Matrix sync failed: $e');
        }
      } else {
        await room.sendTextEvent(text, inReplyTo: replyTo);
      }
      if (pendingId != null) {
        await ref.read(localOutboxProvider.notifier).completeItem(pendingId);
      }
    } on Object catch (e) {
      if (isAgent && mounted) {
        setState(() {
          _agentThinkingSince = null;
        });
        if (agentIsOffline) {
          ref
              .read(agentOfflineReplyCacheProvider.notifier)
              .decrement(widget.roomId);
        }
      }
      if (pendingId != null) {
        await ref.read(localOutboxProvider.notifier).failItem(pendingId);
      }
      if (!mounted) return;
      final l10n = _l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(productSendFailureMessage(e, l10n: l10n))),
      );
    }
  }

  void _pickAgentSlashCommand(String command) {
    final value = command.trim();
    if (value.isEmpty) return;
    _msgCtrl.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {});
  }

  void _handleComposerTextChanged(String value) {
    setState(() {});
  }

  void _togglePlus() {
    final nextVisible = !_showPlusPanel;
    if (nextVisible) FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _showPlusPanel = nextVisible;
      if (_showPlusPanel) _showEmojiPanel = false;
    });
  }

  void _toggleEmoji() {
    final nextVisible = !_showEmojiPanel;
    if (nextVisible) {
      final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
      if (keyboardBottom > 1) {
        _emojiPanelHeight = keyboardBottom.clamp(240.0, 420.0).toDouble();
      }
      FocusManager.instance.primaryFocus?.unfocus();
    }
    setState(() {
      _showEmojiPanel = nextVisible;
      if (_showEmojiPanel) _showPlusPanel = false;
    });
  }

  void _closePanels() {
    final hadFocus = FocusManager.instance.primaryFocus != null;
    final hadPanels = _showPlusPanel || _showEmojiPanel;
    _chatGestureLog(
      'messageLayer pointer closePanels hadFocus=$hadFocus hadPanels=$hadPanels plus=$_showPlusPanel emoji=$_showEmojiPanel',
    );
    if (!hadPanels) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _showPlusPanel = false;
      _showEmojiPanel = false;
    });
  }

  void _startVoiceRecording() {
    unawaited(_startVoiceRecordingAsync());
  }

  Future<void> _startVoiceRecordingAsync() async {
    final room = _room;
    if (room == null) return;
    final syncCache = ref.read(asSyncCacheProvider);
    final capabilityPolicy = _privateRoomCapabilityPolicy(
      ref.read(productConversationsProvider).valueOrNull ??
          const <AsConversation>[],
      room,
      syncCache,
    );
    if (!capabilityPolicy.canSendMedia) {
      _showPendingContactToast(context);
      return;
    }
    try {
      await _voiceRecorder.start();
    } on ChatVoiceRecorderException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          duration: const Duration(seconds: 2),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      final l10n = _l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.groupChatVoiceRecordFailed('$e') ?? '语音录制失败：$e'),
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
        final l10n = _l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.groupChatRecordingTooShort ?? '说话时间太短'),
            duration: const Duration(seconds: 1),
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
    final capabilityPolicy = _privateRoomCapabilityPolicy(
      ref.read(productConversationsProvider).valueOrNull ??
          const <AsConversation>[],
      room,
      syncCache,
    );
    if (!capabilityPolicy.canSendMedia) {
      _showPendingContactToast(context);
      return;
    }
    setState(() => _replyTo = null);
    if (_isProductDirectRoomForChat(room, syncCache) &&
        !isPortalAgentDirectRoom(room)) {
      final l10n = _l10n;
      await sendProductMediaWithPendingState(
        messenger: ScaffoldMessenger.of(context),
        attachment: attachment,
        sendAttachment: createProductRoomMediaSender(
          matrixClient: ref.read(matrixClientProvider),
          roomId: room.id,
        ),
        thumbnailCacheFuture: null,
        onStarted: () => _addPendingFileUpload(attachment),
        onDelivered: _recordDeliveredMediaUpload,
        onSucceeded: _removePendingMediaUpload,
        onFailed: _failPendingMediaUpload,
        l10n: l10n,
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
      final l10n = _l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(productSendFailureMessage(e, l10n: l10n))),
      );
    }
  }

  Future<void> _onLongPressEvent(
    BuildContext ctx,
    Event e,
    _MessageContextAnchor anchor, {
    required _MessageContextMenuPlacement placement,
  }) async {
    final isOwnEvent = e.senderId == e.room.client.userID;
    final supportsTextActions = !isCallRecordEvent(e);
    final canRecall = supportsTextActions && isOwnEvent && e.canRedact;
    _chatGestureLog(
      'event longPress handler eventId=${e.eventId} type=${e.type} msgtype=${e.messageType} sender=${e.senderId} me=${e.room.client.userID} isOwn=$isOwnEvent pos=${anchor.position} rect=${anchor.bubbleRect} placement=$placement canRedact=${e.canRedact} canRecall=$canRecall',
    );
    final action = await _showMsgContextMenu(
      ctx,
      anchor,
      placement: placement,
      canCopy: supportsTextActions,
      canQuote: supportsTextActions,
      canRecall: canRecall,
    );
    _chatGestureLog(
      'event context menu result eventId=${e.eventId} action=$action',
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: e.body));
        if (mounted) {
          final l10n = _l10n;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.groupChatCopied ?? '已复制'),
              duration: const Duration(seconds: 1),
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
      case 'recall':
        await _recallEvent(e);
        break;
      case 'fav':
        await _favoriteEvent(e);
        break;
    }
  }

  Future<void> _onLongPressOutboxItem(
    BuildContext ctx,
    LocalOutboxItem item,
    _MessageContextAnchor anchor, {
    required _MessageContextMenuPlacement placement,
  }) async {
    _chatGestureLog(
      'outbox longPress handler id=${item.id} kind=${item.messageKind} pos=${anchor.position} rect=${anchor.bubbleRect} placement=$placement',
    );
    final action = await _showMsgContextMenu(
      ctx,
      anchor,
      placement: placement,
      canCopy: true,
      canQuote: false,
      canRecall: false,
    );
    _chatGestureLog('outbox context menu result id=${item.id} action=$action');
    if (!mounted || action == null) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: _outboxCopyText(item)));
        if (mounted) {
          final l10n = _l10n;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.groupChatCopied ?? '已复制'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
        break;
      case 'delete':
        await ref.read(localOutboxProvider.notifier).completeItem(item.id);
        if (mounted) {
          final l10n = _l10n;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.groupChatDeleted ?? '已删除'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
        break;
      case 'fav':
        if (mounted) {
          final l10n = _l10n;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(l10n?.groupChatCannotFavoriteSending ?? '发送中的消息暂不能收藏'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
        break;
      case 'forward':
      case 'multi':
      case 'quote':
      case 'recall':
        if (mounted) {
          final l10n = _l10n;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  l10n?.groupChatActionAvailableAfterSent ?? '消息发送完成后可使用该操作'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
        break;
    }
  }

  Future<void> _recallEvent(Event event) async {
    final l10n = _l10n;
    if (!event.canRedact) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n?.groupChatNoRecallPermission ?? '没有权限撤回该消息')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final t = dialogContext.tk;
        return AlertDialog(
          title: Text(
            l10n?.groupChatRecallTitle ?? '撤回消息',
            style: AppTheme.sans(size: 17, weight: FontWeight.w600),
          ),
          content: Text(
            l10n?.chatRecallBody ?? '撤回后，对方也将看不到这条消息。',
            style: AppTheme.sans(size: 15, color: t.textMute),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                l10n?.commonCancel ?? '取消',
                style: AppTheme.sans(size: 15, color: t.textMute),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n?.groupChatRecall ?? '撤回',
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
      try {
        await ref.read(matrixClientProvider).oneShotSync();
      } on Object catch (e) {
        debugPrint('post-redaction Matrix sync failed: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.groupChatRecalled ?? '消息已撤回')),
      );
    } on Object catch (err) {
      debugPrint('recall message failed: $err');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(l10n?.groupChatRecallFailed('$err') ?? '撤回消息失败：$err')),
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
    if (isPortalAgentDirectRoom(room)) return agentDisplayNameForRoom(room);
    return directContactDisplayName(contact, room, peerMxid: mxid);
  }

  String _eventSenderDisplayName(
    Event event, {
    required bool isMe,
    required String peerDisplayName,
  }) {
    if (!isMe && event.senderId.trim().isNotEmpty) {
      final contact =
          ref.read(asSyncCacheProvider).contactForUserId(event.senderId);
      final roomMemberName = directPeerMemberDisplayName(_room, event.senderId);
      if (roomMemberName.isNotEmpty) return roomMemberName;
      final name = contact?.displayName.trim();
      if (name != null && name.isNotEmpty) return name;
      final peerName = peerDisplayName.trim();
      if (peerName.isNotEmpty) return peerName;
    }
    return event.senderFromMemoryOrFallback.calcDisplayname();
  }

  bool _isEventFromCurrentUser(Event event, String? fallbackUserId) {
    final senderId = event.senderId.trim();
    if (senderId.isEmpty) return false;
    final matrixUserId = event.room.client.userID?.trim() ?? '';
    if (matrixUserId.isNotEmpty) return senderId == matrixUserId;
    final authUserId = fallbackUserId?.trim() ?? '';
    return authUserId.isNotEmpty && senderId == authUserId;
  }

  Future<void> _favoriteEvent(Event event) async {
    final eventId = event.eventId.trim();
    if (eventId.isEmpty || _favoritingEventIds.contains(eventId)) return;
    if (mounted) {
      final l10n = _l10n;
      setState(() => _favoritingEventIds.add(eventId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.groupChatFavoriting ?? '正在收藏到我的节点…'),
          duration: const Duration(milliseconds: 900),
        ),
      );
    }
    try {
      final draft = await _favoriteDraftForEvent(event);
      await ref.read(asClientProvider).favoriteMessage(draft);
      if (!mounted) return;
      final l10n = _l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.groupChatFavorited ?? '已收藏'),
          duration: const Duration(seconds: 1),
        ),
      );
    } on Object catch (err) {
      debugPrint('favorite message failed: $err');
      if (mounted) {
        final l10n = _l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n?.groupChatFavoriteFailed('$err') ?? '收藏失败：$err')),
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
      final l10n = _l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.chatRecordForwarded ?? '已转发聊天记录')),
      );
    } on Object catch (err) {
      if (!mounted) return;
      final l10n = _l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(l10n?.chatRecordForwardFailed('$err') ?? '转发失败：$err')),
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
      senderAvatarUrl:
          event.senderFromMemoryOrFallback.avatarUrl?.toString() ?? '',
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
      senderAvatarUrl:
          event.senderFromMemoryOrFallback.avatarUrl?.toString() ?? '',
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
      final matrixFile = await event.downloadAndDecryptAttachment(
        getThumbnail: true,
      );
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
    await _deleteEventIdsForMe([eventId]);
  }

  Future<void> _deleteSelectedEventsForMe(List<Event> events) async {
    final eventIds = events
        .where((event) => _selected.contains(event.eventId))
        .map((event) => event.eventId.trim())
        .where((eventId) => eventId.isNotEmpty)
        .toList(growable: false);
    if (eventIds.isEmpty) return;
    await _deleteEventIdsForMe(eventIds, closeSelection: true);
  }

  Future<void> _deleteEventIdsForMe(
    Iterable<String> eventIds, {
    bool closeSelection = false,
  }) async {
    final ids = <String>[];
    final seen = <String>{};
    for (final rawId in eventIds) {
      final eventId = rawId.trim();
      if (eventId.isEmpty || !seen.add(eventId)) continue;
      ids.add(eventId);
    }
    if (ids.isEmpty) return;
    try {
      await ref
          .read(matrixMessageVisibilityClientProvider)
          .hideEvents(roomId: widget.roomId, eventIds: ids);
      await ref.read(chatClearStateStoreProvider.future).then(
            (store) => store.writeDeletedEventIds(widget.roomId, ids),
          );
      if (!mounted) return;
      ref.read(asSyncCacheProvider.notifier).update((state) {
        var next = state;
        for (final eventId in ids) {
          next = next.withDeletedMessage(widget.roomId, eventId);
        }
        return next;
      });
      unawaited(_refreshBootstrapAfterVisibilityMutation());
      setState(() {
        _locallyHiddenEventIds.addAll(ids);
        _selected.removeWhere(ids.contains);
        if (closeSelection) {
          _multiSelect = false;
          _selected.clear();
        }
      });
    } on Object catch (err) {
      debugPrint('delete message for me failed: $err');
      if (mounted) {
        final l10n = _l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n?.groupChatDeleteFailed('$err') ?? '删除消息失败：$err')),
        );
      }
    }
  }

  Future<void> _refreshBootstrapAfterVisibilityMutation() async {
    try {
      final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
      ref
          .read(asSyncCacheProvider.notifier)
          .update((state) => state.copyWith(bootstrap: bootstrap));
    } on Object catch (e) {
      debugPrint('refresh bootstrap after message delete failed: $e');
    }
  }

  bool _isJoinedGroupRoom(String roomId) {
    final normalized = roomId.trim();
    if (normalized.isEmpty) return false;
    return ref.read(matrixClientProvider).getRoomById(normalized)?.membership ==
        Membership.join;
  }

  String _joinGroupInviteFailureMessage(Object error) {
    final l10n = _l10n;
    if (error is AsClientException && error.statusCode == 403) {
      return l10n?.chatGroupInviteExpired ?? '你未被邀请或邀请已失效';
    }
    return l10n?.chatJoinGroupFailed('$error') ?? '加入群聊失败: $error';
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
      final group = await joinGroupInviteThroughAs(
        invite: invite,
        currentDirectRoomId: widget.roomId,
        joinGroup: ref.read(asClientProvider).joinGroup,
        oneShotSync: ref.read(matrixClientProvider).oneShotSync,
        refreshBootstrap: _refreshBootstrapAfterVisibilityMutation,
        hasJoinedMatrixRoom: _isJoinedGroupRoom,
      );
      await recordProductConversationMutation(ref, group.productConversation);
      if (!mounted) return;
      final route = productConversationRoute(group.productConversation);
      if (route == null) {
        final l10n = _l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n?.chatGroupSyncingRetryLater ?? '群聊正在同步，请稍后重试')),
        );
        return;
      }
      context.push(route);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_joinGroupInviteFailureMessage(e))),
      );
    } finally {
      if (eventId.isNotEmpty && mounted) {
        setState(() => _joiningGroupInviteEventIds.remove(eventId));
      }
    }
  }

  Future<void> _joinChannelShare(ChannelSharePayload payload) async {
    final key = channelShareJoinKey(payload);
    if (key.isEmpty || _joiningChannelShareIds.contains(key)) return;
    if (mounted) setState(() => _joiningChannelShareIds.add(key));
    try {
      final roomId = payload.roomId.trim();
      if (roomId.isEmpty) throw StateError('频道 room_id 为空');
      final channelId = payload.channelId.trim();
      logChannelShareJoinStart(
        source: 'chat_channel_share',
        payload: payload,
        action: channelShareHasInviteGrant(payload)
            ? 'channels.join'
            : 'channels.public.join_request',
        targetId: channelShareHasInviteGrant(payload)
            ? (channelId.isEmpty ? roomId : channelId)
            : channelShareJoinRequestTargetId(payload),
      );
      final joined = channelShareHasInviteGrant(payload)
          ? await joinChannelShareWithInviteProjection(
              ref,
              () => ref.read(asClientProvider).joinChannel(
                    channelId.isEmpty ? roomId : channelId,
                    roomId: roomId,
                    grantId: payload.grantId,
                    shareRoomId: payload.shareRoomId,
                    discoveredChannel: payload.asDiscoveredChannel,
                  ),
              channelId: channelId,
              roomId: roomId,
              debugSource: 'chat_channel_share',
            )
          : await ref.read(asClientProvider).joinChannelByRoomId(
                channelShareJoinRequestTargetId(payload),
                discoveredChannel: payload.asDiscoveredChannel,
                remoteNodeBaseUri: publicBaseUriForMatrixRoomId(roomId),
              );
      logChannelShareJoinResult(
        source: 'chat_channel_share',
        payload: payload,
        channel: joined,
        stage: isAsChannelMemberJoined(joined.memberStatus)
            ? 'joined_or_projected'
            : 'waiting',
      );
      if (isAsChannelMemberJoined(joined.memberStatus)) {
        await _refreshBootstrapAfterVisibilityMutation();
      }
      if (!mounted) return;
      if (!isAsChannelMemberJoined(joined.memberStatus)) {
        setState(() => _requestedChannelShareIds.add(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              channelJoinStatusText(joined.memberStatus, l10n: _l10n),
            ),
          ),
        );
        return;
      }
      context.push(channelShareJoinedRoute(payload, joined), extra: payload);
    } on Object catch (e) {
      logChannelShareJoinError(
        e,
        source: 'chat_channel_share',
        payload: payload,
      );
      logChannelShareJoinForbidden(
        e,
        source: 'chat_channel_share',
        payload: payload,
      );
      if (!mounted) return;
      final l10n = _l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.channelJoinFailed('$e') ?? '加入频道失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _joiningChannelShareIds.remove(key));
    }
  }

  /// 点击图片进入临时预览；长期保存由预览页底部下载按钮触发。
  Future<void> _openImageEvent(Event e, String meta) async {
    final cacheKey = e.eventId.trim();
    final cache = cacheKey.isEmpty
        ? null
        : ref.read(mediaThumbnailCacheProvider).valueOrNull;
    final initialPreviewBytes = cacheKey.isEmpty ? null : cache?.peek(cacheKey);
    final cacheFuture =
        cacheKey.isEmpty ? null : ref.read(mediaThumbnailCacheProvider.future);
    await showAsyncImagePreview(
      context,
      initialPreviewProvider:
          initialPreviewBytes == null ? null : MemoryImage(initialPreviewBytes),
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
        if (cacheKey.isNotEmpty && cacheFuture != null) {
          unawaited(_rememberImagePreviewBytes(
            cacheFuture,
            cacheKey,
            file.bytes,
          ));
        }
        return MemoryImage(file.bytes);
      },
      meta: meta,
      onDownload: () => _downloadImageEvent(e),
    );
  }

  Future<void> _rememberImagePreviewBytes(
    Future<MediaThumbnailCache> cacheFuture,
    String cacheKey,
    Uint8List bytes,
  ) async {
    await writeSentMediaThumbnail(
      cacheFuture,
      cacheKey,
      bytes,
      resizeImage: true,
    );
    if (mounted) setState(() {});
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
          '${(await getTemporaryDirectory()).path}/p2p-im-save',
        ),
        fileName: e.body,
        bytes: matrixFile.bytes,
      );
      await saveMediaFileToGallery(
        path: file.path,
        fileName: file.uri.pathSegments.last,
        mimeType: _chatEventMimeType(e, fallback: 'image/jpeg'),
      );
      if (mounted) {
        if (eventId.isNotEmpty) {
          setState(() {
            _downloadedImageEventIds.add(eventId);
          });
        }
        final l10n = _l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.chatImageSavedToAlbum ?? '已保存原图到相册')),
        );
      }
    } on Object catch (err) {
      debugPrint('download image failed: $err');
      if (mounted) {
        final l10n = _l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n?.groupChatDownloadFailed('$err') ?? '下载失败：$err')),
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
    final resolvedFileName = chatEventAttachmentFileName(
      e,
      matrixFile,
      fallbackName: fileName ?? e.body,
    );
    final baseDir = persistent
        ? Directory(
            '${(await getApplicationDocumentsDirectory()).path}/P2P IM Downloads',
          )
        : Directory('${(await getTemporaryDirectory()).path}/p2p-im-open');
    return writeChatActionFile(
      directory: baseDir,
      fileName: resolvedFileName,
      bytes: matrixFile.bytes,
    );
  }

  Future<void> _openFileEvent(Event e) async {
    if (_isVoiceEvent(e)) {
      await _playVoiceEvent(e);
      return;
    }
    final openKey = _fileActionKey(e);
    if (_openingFileEventIds.contains(openKey)) return;
    _openingFileEventIds.add(openKey);
    try {
      final file = await _materializeFileEvent(e, persistent: false);
      await previewChatActionFile(file);
    } on Object catch (err) {
      debugPrint('open file failed: $err');
      if (mounted) {
        final l10n = _l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n?.groupChatOpenFailed('$err') ?? '打开失败：$err')),
        );
      }
    } finally {
      _openingFileEventIds.remove(openKey);
    }
  }

  Future<void> _openVideoEvent(Event e) async {
    final openKey = _fileActionKey(e);
    await _videoOpenGuard.runOnce(openKey, () => _openVideoEventOnce(e));
  }

  Future<void> _openVideoEventOnce(Event e) async {
    try {
      final file = await _materializeFileEvent(e, persistent: false);
      if (!mounted) return;
      await openChatVideoPreview(
        context,
        file: file,
        title: e.body,
        onSaveToAlbum: () {
          return saveMediaFileToGallery(
            path: file.path,
            fileName: file.uri.pathSegments.last,
            mimeType: _chatEventMimeType(e, fallback: 'video/mp4'),
          );
        },
      );
    } on Object catch (err) {
      debugPrint('open video failed: $err');
      if (mounted) {
        final l10n = _l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n?.groupChatPlaybackFailed('$err') ?? '播放失败：$err')),
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
        final l10n = _l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n?.groupChatPlaybackFailed('$err') ?? '播放失败：$err')),
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
        final l10n = _l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.groupChatDownloadSaved(file.uri.pathSegments.last) ??
                  '已保存到 Files / Portal App / P2P IM Downloads / ${file.uri.pathSegments.last}',
            ),
          ),
        );
      }
    } on Object catch (err) {
      debugPrint('download file failed: $err');
      if (mounted) {
        final l10n = _l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n?.groupChatDownloadFailed('$err') ?? '下载失败：$err')),
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
    context.push('/contact/${Uri.encodeComponent(id)}?source=chat_avatar');
  }

  void _openContactInfo(String userId) {
    context.push('/chat-info/${Uri.encodeComponent(widget.roomId)}');
  }

  void _openMyProfileFromChat() {
    final userId = ref.read(matrixClientProvider).userID?.trim() ?? '';
    if (userId.isEmpty) return;
    _openContactDetail(userId);
  }

  VoidCallback? _senderAvatarTap(
    Event event,
    bool isMe, {
    required bool isAgentRoom,
  }) {
    if (isMe) return _openMyProfileFromChat;
    if (isAgentRoom) return null;
    final room = _room;
    if (room == null || isPortalAgentDirectRoom(room)) return null;

    final senderId = event.senderId.trim();
    if (!senderId.startsWith('@') || !senderId.contains(':')) return null;
    return () => _openContactDetail(senderId);
  }

  String? _senderAvatarUrl(
    Event event,
    Profile? currentUserProfile, {
    String? fallbackUserId,
  }) {
    final client = event.room.client;
    final memberAvatarUrl = matrixContentHttpUrl(
      client,
      event.senderFromMemoryOrFallback.avatarUrl,
    );
    final isCurrentUser = _isEventFromCurrentUser(event, fallbackUserId);
    final syncCache = ref.read(asSyncCacheProvider);
    final contact = syncCache.contactForUserId(event.senderId) ??
        syncCache.contactForRoom(widget.roomId);
    return _avatarSnapshotCache.resolve(
      senderId: event.senderId,
      candidates: [
        if (isCurrentUser)
          ChatAvatarCandidate(
            url: profileAvatarHttpUrl(currentUserProfile, client),
            priority: ChatAvatarCandidatePriority.currentUserProfile,
          ),
        ChatAvatarCandidate(
          url: memberAvatarUrl,
          priority: ChatAvatarCandidatePriority.matrixMember,
        ),
        ChatAvatarCandidate(
          url: avatarHttpUrl(client, contact?.avatarUrl),
          priority: ChatAvatarCandidatePriority.productContact,
        ),
      ],
    );
  }

  String? _currentUserAvatarUrl(Profile? currentUserProfile, Room room) {
    final currentUserId = room.client.userID?.trim() ?? '';
    final memberAvatarUrl = currentUserId.isEmpty
        ? null
        : localRoomMemberAvatarHttpUrl(room, currentUserId);
    return _avatarSnapshotCache.resolve(
      senderId: currentUserId.isEmpty ? 'me' : currentUserId,
      candidates: [
        ChatAvatarCandidate(
          url: profileAvatarHttpUrl(currentUserProfile, room.client),
          priority: ChatAvatarCandidatePriority.currentUserProfile,
        ),
        ChatAvatarCandidate(
          url: memberAvatarUrl,
          priority: ChatAvatarCandidatePriority.matrixMember,
        ),
      ],
    );
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
      onQueued: _scheduleViewportScrollToBottom,
    );
  }

  Future<String> _addPendingFileUpload(ChatMediaAttachment attachment) {
    return startMediaOutboxItem(
      notifier: ref.read(localOutboxProvider.notifier),
      conversationId: widget.roomId,
      conversationType: LocalOutboxConversationType.direct,
      attachment: attachment,
      onQueued: _scheduleViewportScrollToBottom,
    );
  }

  Future<String> _addPendingVideoUpload(ChatMediaAttachment attachment) {
    return startMediaOutboxItem(
      notifier: ref.read(localOutboxProvider.notifier),
      conversationId: widget.roomId,
      conversationType: LocalOutboxConversationType.direct,
      attachment: attachment,
      onQueued: _scheduleViewportScrollToBottom,
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
    await ref
        .read(localMessageOrderProvider.notifier)
        .recordDeliveredOutbox(outbox: item, eventId: eventId);
  }

  Future<void> _failPendingMediaUpload(String id) {
    return ref.read(localOutboxProvider.notifier).failItem(id);
  }

  Future<void> _retryFailedMediaUpload(LocalOutboxItem item) async {
    if (_retryingOutboxIds.contains(item.id)) return;
    final room = _room;
    if (room == null) return;
    final capabilityPolicy = _privateRoomCapabilityPolicy(
      ref.read(productConversationsProvider).valueOrNull ??
          const <AsConversation>[],
      room,
      ref.read(asSyncCacheProvider),
    );
    if (!capabilityPolicy.canSendMedia) {
      _showPendingContactToast(context);
      return;
    }
    if (item.messageKind != LocalOutboxMessageKind.image &&
        item.messageKind != LocalOutboxMessageKind.video &&
        item.messageKind != LocalOutboxMessageKind.file) {
      return;
    }
    final l10n = _l10n;
    final bytes = item.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      final label = switch (item.messageKind) {
        LocalOutboxMessageKind.image => l10n?.groupChatImage ?? '图片',
        LocalOutboxMessageKind.video => l10n?.groupChatVideo ?? '视频',
        _ => l10n?.groupChatFile ?? '文件',
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n?.groupChatLocalMediaMissing(label) ??
                '本地原$label已丢失，请重新选择$label'),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }

    final retried =
        await ref.read(localOutboxProvider.notifier).retryItem(item.id);
    if (!retried || !mounted) return;

    _retryingOutboxIds.add(item.id);
    try {
      final matrixClient = ref.read(matrixClientProvider);
      final attachment = switch (item.messageKind) {
        LocalOutboxMessageKind.image => ChatMediaAttachment.image(
            name: item.filename.isEmpty ? 'image.jpg' : item.filename,
            bytes: bytes,
            mimeType: item.mimeType.isEmpty ? 'image/jpeg' : item.mimeType,
            width: item.width,
            height: item.height,
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
          roomId: room.id,
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
        l10n: l10n,
      );
    } finally {
      _retryingOutboxIds.remove(item.id);
    }
  }

  Future<void> _retryFailedTextMessage(LocalOutboxItem item) async {
    if (_retryingOutboxIds.contains(item.id)) return;
    final room = _room;
    if (room == null) return;
    final capabilityPolicy = _privateRoomCapabilityPolicy(
      ref.read(productConversationsProvider).valueOrNull ??
          const <AsConversation>[],
      room,
      ref.read(asSyncCacheProvider),
    );
    if (!capabilityPolicy.canSendText) {
      _showPendingContactToast(context);
      return;
    }
    if (item.messageKind != LocalOutboxMessageKind.text) return;
    final text = item.text.trim();
    if (text.isEmpty) return;
    final retried =
        await ref.read(localOutboxProvider.notifier).retryItem(item.id);
    if (!retried || !mounted) return;

    _retryingOutboxIds.add(item.id);
    try {
      final syncCache = ref.read(asSyncCacheProvider);
      final productConversations =
          ref.read(productConversationsProvider).valueOrNull ??
              const <AsConversation>[];
      if (_isAgentRoomForChat(room, syncCache, productConversations)) {
        await sendAgentRoomText(room, text);
      } else if (_isProductDirectRoomForChat(room, syncCache)) {
        await _sendProductDirectText(room, text, null);
        try {
          await ref.read(matrixClientProvider).oneShotSync();
        } on Object catch (e) {
          debugPrint('post-retry Matrix sync failed: $e');
        }
      } else {
        await room.sendTextEvent(text);
      }
      await ref.read(localOutboxProvider.notifier).completeItem(item.id);
    } on Object catch (e) {
      await ref.read(localOutboxProvider.notifier).failItem(item.id);
      if (!mounted) return;
      final l10n = _l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(productSendFailureMessage(e, l10n: l10n))),
      );
    } finally {
      _retryingOutboxIds.remove(item.id);
    }
  }

  Future<String> _sendProductDirectText(
    Room room,
    String text,
    Event? replyTo,
  ) {
    final content = <String, Object?>{
      'msgtype': MessageTypes.Text,
      'body': text,
      if (replyTo?.eventId.trim().isNotEmpty ?? false)
        'reply_to': replyTo!.eventId,
      if (replyTo?.eventId.trim().isNotEmpty ?? false)
        'm.relates_to': {
          'm.in_reply_to': {'event_id': replyTo!.eventId},
        },
    };
    return room.client.sendMessage(
      room.id,
      EventTypes.Message,
      room.client.generateUniqueTransactionId(),
      content,
    );
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

  String? _deliveredTextSignature(Event event) {
    if (event.senderId != event.room.client.userID ||
        event.hasAttachment ||
        event.messageType != MessageTypes.Text) {
      return null;
    }
    final text = event.body.trim();
    if (text.isEmpty) return null;
    return 'text:$text';
  }

  String? _outboxTextSignature(LocalOutboxItem item) {
    if (item.messageKind != LocalOutboxMessageKind.text) return null;
    final text = item.text.trim();
    if (text.isEmpty) return null;
    return 'text:$text';
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
    final localPreview = _localReplyPreviews[event.eventId.trim()];
    if (localPreview != null) return localPreview;
    final fallbackPreview = _replyPreviewFromMatrixFallbackBody(event.body);
    final replyEventId = _replyEventIdForEvent(event);
    if (replyEventId == null || replyEventId.isEmpty) return fallbackPreview;
    Event? quoted;
    for (final candidate in visibleEvents) {
      if (candidate.eventId == replyEventId) {
        quoted = candidate;
        break;
      }
    }
    if (quoted == null) {
      return fallbackPreview?.withEventId(replyEventId) ??
          _missingQuotedMessagePreview.withEventId(replyEventId);
    }
    return _QuotedMessagePreview(
      eventId: quoted.eventId,
      sender: quoted.senderFromMemoryOrFallback.calcDisplayname(),
      text: quotedEventPreviewText(
        quoted,
        l10n: Localizations.of<AppLocalizations>(context, AppLocalizations),
      ),
    );
  }

  void _rememberLocalReplyPreview(String eventId, Event? replyTo) {
    final trimmed = eventId.trim();
    if (trimmed.isEmpty || replyTo == null) return;
    _localReplyPreviews[trimmed] = _QuotedMessagePreview(
      eventId: replyTo.eventId,
      sender: replyTo.senderFromMemoryOrFallback.calcDisplayname(),
      text: quotedEventPreviewText(
        replyTo,
        l10n: Localizations.of<AppLocalizations>(context, AppLocalizations),
      ),
    );
  }

  Future<void> _openRedPacketDetail(RedPacketPayload payload) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RedPacketDetailPage(payload: payload),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final syncCache = ref.watch(asSyncCacheProvider);
    final summaryState = ref.watch(conversationSummaryProvider);
    final currentUserProfile =
        ref.watch(currentUserProfileProvider).valueOrNull;
    final authUserId = ref.watch(authStateNotifierProvider).valueOrNull?.userId;
    if (room == null) {
      _debugMissingRoomState('build-room-null');
      if (_isKnownConversationRoom(syncCache)) {
        if (_missingRoomRecovery.failed) {
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
    final currentUserId = room.client.userID?.trim();
    final currentUserAvatarSeed =
        currentUserId == null || currentUserId.isEmpty ? 'me' : currentUserId;
    final currentUserAvatarUrl = _currentUserAvatarUrl(
      currentUserProfile,
      room,
    );

    final pendingOutboxItems = ref
        .watch(localOutboxProvider)
        .itemsForConversation(
          widget.roomId,
          type: LocalOutboxConversationType.direct,
        )
        .toList()
        .reversed
        .toList();
    final rawTimelineEvents = timelineEventsIncludingRoomLastEvent(
      room,
      _timeline,
    );
    final callRecordContextEvents = callRecordContextEventsForTimeline(
      rawTimelineEvents,
    );
    final timelineEvents = chatDisplayEventsForTimeline(rawTimelineEvents);
    final filteredEvents = syncCache
        .chatVisibilityPolicyForRoom(widget.roomId)
        .filter(
          timelineEvents,
          eventId: (event) => event.eventId,
          originServerTs: (event) =>
              event.originServerTs.millisecondsSinceEpoch,
          redacted: (event) => event.redacted,
        )
        .where((event) {
      final id = event.eventId.trim();
      return id.isEmpty || !_locallyHiddenEventIds.contains(id);
    }).toList(growable: false);
    final asCallRecords = asCallSessionsForDirectTimeline(
      sessions: _roomAsCallHistory.values,
      roomId: widget.roomId,
      rawTimelineEvents: rawTimelineEvents,
      callRecordContextEvents: callRecordContextEvents,
    );
    debugPrint(
      'chat direct call history merge room=${widget.roomId} '
      'as_records=${asCallRecords.length} '
      'ids=${asCallRecords.map((session) => session.callId).join(",")}',
    );
    final visibleEvents = groupTimelineEventsReplacingAsCallSnapshots(
      visibleEvents: filteredEvents,
      callRecordContextEvents: callRecordContextEvents,
      asCallSessions: asCallRecords,
    );
    final contact = syncCache.contactForRoom(widget.roomId);
    final joinedPeerMxid = joinedPersonPeerMxid(room);
    final mxid =
        productDirectPeerMxid(room) ?? joinedPeerMxid ?? contact?.userId ?? '';
    final productConversations =
        ref.watch(productConversationsProvider).valueOrNull ??
            const <AsConversation>[];
    final isAgent = _isAgentRoomForChat(room, syncCache, productConversations);
    final topSystemNoticeText = _topSystemNoticeText(visibleEvents);
    var messageEvents = visibleEvents
        .where(
          (event) =>
              topSystemNoticeText == null ||
              event.messageType != MessageTypes.Notice ||
              event.body.trim() != topSystemNoticeText,
        )
        .toList(growable: false);
    final agentMessageProjection = isAgent
        ? projectAgentMessageEvents<Event>(
            messageEvents,
            eventId: (event) => event.eventId,
            content: (event) => agentDisplayContentForEvent(event, _timeline),
            fallbackBody: (event) =>
                agentDisplayFallbackBodyForEvent(event, _timeline),
            timestampMs: (event) => event.originServerTs.millisecondsSinceEpoch,
          )
        : null;
    if (agentMessageProjection != null) {
      messageEvents = agentMessageProjection.visibleEvents;
    }
    _scheduleAsCallSessionWarmup(visibleEvents, callRecordContextEvents);
    final deliveredPendingMediaIds = _deliveredOutboxMediaIds(
      pendingOutboxItems,
      messageEvents,
    );
    final pendingOutboxWithoutDeliveredMedia = [
      for (final item in pendingOutboxItems)
        if (!deliveredPendingMediaIds.contains(item.id)) item,
    ];
    final pendingOutbox =
        filterOutboxItemsShadowedByEvents<Event, LocalOutboxItem>(
      events: messageEvents,
      outboxItems: pendingOutboxWithoutDeliveredMedia,
      eventSignature: _deliveredTextSignature,
      eventTimestamp: (event) => event.originServerTs,
      outboxSignature: _outboxTextSignature,
      outboxTimestamp: (item) => item.createdAt,
    );
    final messageOrder = ref.watch(localMessageOrderProvider);
    final timelineItems = _mergeDirectTimelineItems(
      events: messageEvents,
      eventTimestamp: (event) => event.originServerTs,
      eventSortTimestamp: (event) =>
          messageOrder.entryForEvent(event.eventId)?.createdAt,
      outboxItems: pendingOutbox,
      outboxTimestamp: (item) => item.createdAt,
      asCallSessions: asCallRecords,
    );
    final timelineItemKeys = [
      for (final item in timelineItems) _timelineItemKey(item),
    ];
    final displayTimelineItems = timelineItems.reversed.toList(growable: false);
    _syncMessageListIndexes(displayTimelineItems, leadingItems: 1);
    _pruneMessageAnchors();
    _seedInitialTimelineEntrances(timelineItemKeys);
    _scheduleTargetEventScroll();
    final newestTimelineItemKey =
        timelineItemKeys.isEmpty ? null : timelineItemKeys.first;
    _scheduleScrollToLatest(newestTimelineItemKey);
    final suppressFirstMessageEmpty = topSystemNoticeText == null &&
        timelineItems.isEmpty &&
        (_timeline == null ||
            !summaryState.loaded ||
            _conversationSummaryHasCachedMessage(summaryState, widget.roomId));
    if (deliveredPendingMediaIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifier = ref.read(localOutboxProvider.notifier);
        for (final id in deliveredPendingMediaIds) {
          unawaited(notifier.completeItem(id));
        }
      });
    }

    final agentThinkingSince = _agentThinkingSince;
    final hasAgentReply = agentThinkingSince != null &&
        _hasAgentReplyAfter(messageEvents, mxid, agentThinkingSince);
    if (isAgent && hasAgentReply) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _agentThinkingSince = null);
      });
    }
    final agentPresence =
        isAgent ? ref.watch(agentBridgePresenceProvider) : null;
    final agentIsOnline = agentPresence?.bridgeConnected ?? false;
    final agentIsOffline =
        agentPresence?.state == AgentBridgePresenceState.offline;
    final cachedAgentOfflineReplyCount = isAgent
        ? ref.watch(agentOfflineReplyCacheProvider)[widget.roomId.trim()] ?? 0
        : 0;
    if (isAgent && agentIsOnline && cachedAgentOfflineReplyCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(agentOfflineReplyCacheProvider.notifier)
              .clear(widget.roomId);
        }
      });
    }
    final showAgentThinking = isAgent &&
        !agentIsOffline &&
        agentThinkingSince != null &&
        !hasAgentReply;
    final showAgentOfflineReply = isAgent && agentIsOffline;
    final agentOfflineReplyCount =
        showAgentOfflineReply ? cachedAgentOfflineReplyCount : 0;
    final chatDisplayItems = _buildDirectChatDisplayItems(
      displayTimelineItems,
      agentOfflineReplyCount: agentOfflineReplyCount,
      currentUserId: currentUserId,
    );
    final showDefaultAgentOfflineReply = isAgent &&
        !agentIsOnline &&
        agentOfflineReplyCount == 0 &&
        chatDisplayItems.isEmpty;
    final isProductDirect = _isProductDirectRoomForChat(room, syncCache);
    final productConversation = productDirectConversationForPeer(
      productConversations,
      peerMxid: mxid,
      roomId: widget.roomId,
    );
    final capabilityPolicy = _privateRoomCapabilityPolicy(
      productConversations,
      room,
      syncCache,
    );
    final canSendMessages = capabilityPolicy.canSendText;
    final canSendMedia = capabilityPolicy.canSendMedia;
    final canStartCall = capabilityPolicy.canCall;
    final locale = Localizations.localeOf(context);
    final agentSlashSuggestions =
        isAgent && canSendMessages && _msgCtrl.text.trimLeft().startsWith('/')
            ? agentSlashCommandsForLocale(
                locale,
                query: _msgCtrl.text.trimLeft(),
              )
                .map(
                  (command) => ChatInputSuggestion(
                    label: command.command,
                    description: '${command.title} · ${command.description}',
                  ),
                )
                .toList(growable: false)
            : const <ChatInputSuggestion>[];
    final isWaitingForAccept = isProductDirect && !isAgent && !canSendMessages;
    final name = isAgent
        ? agentDisplayNameForRoom(room)
        : directContactDisplayName(contact, room, peerMxid: mxid);
    final peerAvatarUrl =
        avatarHttpUrl(room.client, productConversation?.avatarUrl) ??
            localRoomMemberAvatarHttpUrl(room, mxid) ??
            avatarHttpUrl(room.client, contact?.avatarUrl);
    final peerReadEventIds = _peerReadEventIds(
      room: room,
      peerMxid: mxid,
      events: messageEvents,
    );
    final peerIsTyping = !isAgent && _isPeerTyping(room, mxid);
    final peerPresence = isAgent ? null : _peerPresence(room.client, mxid);
    final peerIsOnline =
        peerPresence != null && peerPresence != PresenceType.offline;
    final peerIsOffline = peerPresence == PresenceType.offline;
    final onlineLabel = l10n?.commonOnline ?? '在线';
    final offlineLabel = l10n?.commonOffline ?? '离线';
    final agentPresenceState = agentPresence?.state;
    final agentHeaderSubtitle = agentIsOnline ? onlineLabel : offlineLabel;
    final headerSubtitle = isWaitingForAccept
        ? l10n?.requestsWaitingPeerAccept ?? '等待对方接受'
        : isAgent
            ? agentHeaderSubtitle
            : peerIsTyping
                ? '在想'
                : peerIsOnline
                    ? onlineLabel
                    : peerIsOffline
                        ? offlineLabel
                        : null;
    final headerSubtitleStatus = isAgent
        ? switch (agentPresenceState) {
            AgentBridgePresenceState.online => ChatCapsuleSubtitleStatus.online,
            _ => ChatCapsuleSubtitleStatus.offline,
          }
        : (peerIsTyping || peerIsOnline
            ? ChatCapsuleSubtitleStatus.online
            : peerIsOffline
                ? ChatCapsuleSubtitleStatus.offline
                : null);
    final replyBarVisible = _replyTo != null;
    final selectionBarVisible = _multiSelect;
    final keyboardInsetBottom = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardInsetBottom > 1) {
      _emojiPanelHeight = keyboardInsetBottom.clamp(240.0, 420.0).toDouble();
    }
    final bottomPanelVisible =
        keyboardInsetBottom <= 1 && (_showPlusPanel || _showEmojiPanel);
    final showEmojiPanelContent = _showEmojiPanel && keyboardInsetBottom <= 1;
    final bottomViewportChanged =
        keyboardInsetBottom != _lastKeyboardInsetBottom ||
            bottomPanelVisible != _lastBottomPanelVisible;
    if (bottomViewportChanged &&
        (keyboardInsetBottom > 0 || bottomPanelVisible)) {
      _scheduleViewportScrollToBottom();
    }
    _lastKeyboardInsetBottom = keyboardInsetBottom;
    _lastBottomPanelVisible = bottomPanelVisible;
    final messageTopInset = chatMessageTopOverlayClearance(context);
    final messageBottomInset = chatMessageBottomOverlayClearance(
      context,
      replyBarVisible: replyBarVisible,
      selectionBarVisible: selectionBarVisible,
      bottomPanelVisible: bottomPanelVisible,
    );
    final messagePadding = chatMessageViewportPadding(
      context,
      replyBarVisible: replyBarVisible,
      selectionBarVisible: selectionBarVisible,
      bottomPanelVisible: bottomPanelVisible,
      reserveTopOverlay: false,
      reserveBottomOverlay: false,
    ).add(const EdgeInsets.symmetric(vertical: 12));

    return Scaffold(
      body: ChatGlassBackground(
        child: ChatLayeredLayout(
          messageTopInset: messageTopInset,
          messageBottomInset: messageBottomInset,
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
                  subtitle: headerSubtitle,
                  subtitleStatus: headerSubtitleStatus,
                  onBack: () => unawaited(_popChatOrHome(context)),
                  showEncryptionIcon: true,
                  actions: isAgent
                      ? const []
                      : [
                          ChatCapsuleAction(
                            icon: Symbols.call,
                            tooltip: l10n?.groupChatVoiceCall ?? '语音通话',
                            color: t.accent,
                            onTap: canStartCall
                                ? () => context.push(
                                      _privateVoiceCallRoute(
                                        widget.roomId,
                                        mxid,
                                        name,
                                        peerAvatarUrl,
                                      ),
                                    )
                                : () => _showPendingContactToast(context),
                          ),
                          ChatCapsuleAction(
                            icon: Symbols.more_vert,
                            tooltip: l10n?.groupChatDetails ?? '详情',
                            color: t.accent,
                            onTap: () => _openContactInfo(mxid),
                          ),
                        ],
                ),
          messageLayer: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _closePanels(),
            child: timelineItems.isEmpty &&
                    topSystemNoticeText == null &&
                    !showAgentThinking &&
                    !showDefaultAgentOfflineReply
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final emptyHeight = math.max(
                        0.0,
                        constraints.maxHeight - messagePadding.vertical,
                      );
                      return RefreshIndicator(
                        color: t.accent,
                        onRefresh: _requestOlderMessages,
                        child: ListView(
                          controller: _messageScrollCtrl,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: messagePadding,
                          children: [
                            SizedBox(
                              height: emptyHeight,
                              child: suppressFirstMessageEmpty
                                  ? const SizedBox.shrink()
                                  : Center(
                                      child: Text(
                                        isAgent
                                            ? l10n?.agentChatEmptyTitle ??
                                                '开始我们的聊天吧'
                                            : '开始你们的第一条消息',
                                        style: AppTheme.sans(
                                          size: 13,
                                          color: t.textMute,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : ChatTimelineListMotion(
                    itemCount: chatDisplayItems.length +
                        (topSystemNoticeText == null ? 0 : 1) +
                        (showAgentThinking ? 1 : 0) +
                        (showDefaultAgentOfflineReply ? 1 : 0),
                    newestItemKey: newestTimelineItemKey,
                    child: RefreshIndicator(
                      color: t.accent,
                      onRefresh: _requestOlderMessages,
                      child: ListView.builder(
                        controller: _messageScrollCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: messagePadding,
                        itemCount: chatDisplayItems.length +
                            1 +
                            (showAgentThinking ? 1 : 0) +
                            (showDefaultAgentOfflineReply ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            if (topSystemNoticeText != null) {
                              return _SChatSystemNotice(
                                text: topSystemNoticeText,
                              );
                            }
                            return const _E2eFooter();
                          }
                          final itemIndex = i - 1;
                          if (itemIndex >= chatDisplayItems.length) {
                            if (showDefaultAgentOfflineReply) {
                              return chatMessageEntrance(
                                key: const ValueKey(
                                  'private_message_enter_agent_offline_reply_default',
                                ),
                                isMe: false,
                                index: itemIndex,
                                enabled: true,
                                child: _SAgentOfflineReplyBubble(
                                  text: l10n?.agentChatOfflineReply ??
                                      '目前Agent离线，请耐心等待',
                                  avatarSeed: name,
                                  avatarUrl: peerAvatarUrl,
                                  avatarAsset: agentAvatarAsset,
                                ),
                              );
                            }
                            if (!showAgentThinking) {
                              return const SizedBox.shrink();
                            }
                            return chatMessageEntrance(
                              key: const ValueKey(
                                'private_message_enter_agent_thinking',
                              ),
                              isMe: false,
                              index: itemIndex,
                              enabled: true,
                              child: _SAgentThinkingBubble(
                                avatarSeed: name,
                                avatarUrl: peerAvatarUrl,
                                avatarAsset: agentAvatarAsset,
                              ),
                            );
                          }
                          final chatDisplayItem = chatDisplayItems[itemIndex];
                          final agentOfflineReplyIndex =
                              chatDisplayItem.agentOfflineReplyIndex;
                          if (agentOfflineReplyIndex != null) {
                            return chatMessageEntrance(
                              key: ValueKey(
                                'private_message_enter_agent_offline_reply_$agentOfflineReplyIndex',
                              ),
                              isMe: false,
                              index: itemIndex,
                              enabled: true,
                              child: _SAgentOfflineReplyBubble(
                                text: l10n?.agentChatOfflineReply ??
                                    '目前Agent离线，请耐心等待',
                                avatarSeed: name,
                                avatarUrl: peerAvatarUrl,
                                avatarAsset: agentAvatarAsset,
                              ),
                            );
                          }
                          final timelineItem = chatDisplayItem.timeline;
                          if (timelineItem == null) {
                            return const SizedBox.shrink();
                          }
                          final timelineItemIndex =
                              displayTimelineItems.indexOf(timelineItem);
                          final itemKey = _timelineItemKey(timelineItem);
                          final contextMenuPlacement =
                              _messageContextMenuPlacement(
                            timelineItemIndex < 0
                                ? itemIndex
                                : timelineItemIndex,
                            displayTimelineItems.length,
                          );
                          Widget enter(
                            Widget child, {
                            required bool isMe,
                            required Object id,
                            GlobalKey? anchorKey,
                            bool flashing = false,
                          }) {
                            return chatMessageEntrance(
                              key: ValueKey('private_message_enter_$id'),
                              isMe: isMe,
                              index: itemIndex,
                              enabled: _initialTimelineEntrances.contains(
                                itemKey,
                              ),
                              child: anchorKey == null
                                  ? _MessageJumpFlash(
                                      flashing: flashing,
                                      child: child,
                                    )
                                  : KeyedSubtree(
                                      key: anchorKey,
                                      child: _MessageJumpFlash(
                                        flashing: flashing,
                                        child: child,
                                      ),
                                    ),
                            );
                          }

                          return timelineItem.when(
                            outbox: (pending) {
                              if (pending.messageKind ==
                                  LocalOutboxMessageKind.text) {
                                return enter(
                                  _SChatBubble(
                                    key: ValueKey(pending.id),
                                    isMe: true,
                                    text: pending.text,
                                    time: _formatMsgTime(pending.createdAt),
                                    showRead: false,
                                    avatarSeed: currentUserAvatarSeed,
                                    avatarUrl: currentUserAvatarUrl,
                                    outboxStatus: _InlineOutboxStatusIcon(
                                      status: pending.status,
                                      label: l10n?.groupChatMessageFallback ??
                                          'Message',
                                      onRetry: () => unawaited(
                                        _retryFailedTextMessage(pending),
                                      ),
                                    ),
                                    onLongPressAt: (pos) =>
                                        _onLongPressOutboxItem(
                                      context,
                                      pending,
                                      pos,
                                      placement: contextMenuPlacement,
                                    ),
                                  ),
                                  isMe: true,
                                  id: pending.id,
                                );
                              }
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
                                    avatarSeed: currentUserAvatarSeed,
                                    avatarUrl: currentUserAvatarUrl,
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
                                    onLongPressAt: (pos) =>
                                        _onLongPressOutboxItem(
                                      context,
                                      pending,
                                      pos,
                                      placement: contextMenuPlacement,
                                    ),
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
                                    avatarSeed: currentUserAvatarSeed,
                                    avatarUrl: currentUserAvatarUrl,
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
                                    onLongPressAt: (pos) =>
                                        _onLongPressOutboxItem(
                                      context,
                                      pending,
                                      pos,
                                      placement: contextMenuPlacement,
                                    ),
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
                                  avatarSeed: currentUserAvatarSeed,
                                  avatarUrl: currentUserAvatarUrl,
                                  mediaSize: isPendingVideo
                                      ? chatMessageDefaultMediaSize
                                      : chatMediaBubbleSizeFor(
                                          width: pending.width,
                                          height: pending.height,
                                        ),
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
                                            _retryFailedMediaUpload(pending),
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
                                  onLongPressAt: (pos) =>
                                      _onLongPressOutboxItem(
                                    context,
                                    pending,
                                    pos,
                                    placement: contextMenuPlacement,
                                  ),
                                ),
                                isMe: true,
                                id: pending.id,
                              );
                            },
                            asCall: (session) {
                              debugPrint(
                                'chat direct call history render '
                                'call_id=${session.callId} '
                                'state=${session.state} '
                                'duration_ms=${session.durationMs} '
                                'answered_at=${session.answeredAt?.toIso8601String() ?? ""} '
                                'ended_at=${session.endedAt?.toIso8601String() ?? ""} '
                                'text=${asCallSessionRecordText(session, l10n: l10n)}',
                              );
                              final callerId = session.createdByMxid.trim();
                              final isMe = authUserId != null &&
                                  callerId.isNotEmpty &&
                                  callerId == authUserId.trim();
                              final callerName = isMe
                                  ? (currentUserProfile?.displayName
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ==
                                          true
                                      ? currentUserProfile!.displayName!
                                          .toString()
                                          .trim()
                                      : '我')
                                  : name;
                              final callerAvatarUrl = isMe
                                  ? profileAvatarHttpUrl(
                                      currentUserProfile,
                                      room.client,
                                    )
                                  : peerAvatarUrl;
                              final callerAvatarAsset =
                                  isAgent && !isMe ? agentAvatarAsset : null;
                              return enter(
                                _SChatCallRecordBubble(
                                  isMe: isMe,
                                  isVideo: asCallSessionRecordIsVideo(session),
                                  text: asCallSessionRecordText(
                                    session,
                                    l10n: l10n,
                                  ),
                                  time: _formatMsgTime(
                                    asCallSessionStableTimestamp(session),
                                  ),
                                  showRead: false,
                                  avatarSeed: callerName,
                                  avatarUrl: callerAvatarUrl,
                                  avatarAsset: callerAvatarAsset,
                                  onAvatarTap: isMe || isAgent
                                      ? null
                                      : () => _openContactInfo(mxid),
                                  selected: false,
                                  multiSelect: false,
                                ),
                                isMe: isMe,
                                id: 'as-call-${session.callId}',
                              );
                            },
                            event: (e) {
                              if (isCallRecordEvent(e)) {
                                final selected = _selected.contains(e.eventId);
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
                                final isMe = callerId.trim().isNotEmpty &&
                                    _isEventFromCurrentUser(
                                      callerEvent ?? e,
                                      authUserId,
                                    );
                                final callerName = callerEvent
                                        ?.senderFromMemoryOrFallback
                                        .calcDisplayname() ??
                                    e.senderFromMemoryOrFallback
                                        .calcDisplayname();
                                final callerAvatarUrl = _senderAvatarUrl(
                                  callerEvent ?? e,
                                  currentUserProfile,
                                  fallbackUserId: authUserId,
                                );
                                final callerAvatarAsset =
                                    isAgent && !isMe ? agentAvatarAsset : null;
                                final avatarTap = isMe
                                    ? null
                                    : _senderAvatarTap(
                                        callerEvent ?? e,
                                        isMe,
                                        isAgentRoom: isAgent,
                                      );
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
                                      asCallSessionPending: asCallId != null &&
                                          asCallSession == null,
                                      l10n: l10n,
                                    ),
                                    time: _formatMsgTime(e.originServerTs),
                                    showRead: false,
                                    avatarSeed: callerName,
                                    avatarUrl: callerAvatarUrl,
                                    avatarAsset: callerAvatarAsset,
                                    onAvatarTap: avatarTap,
                                    selected: selected,
                                    multiSelect: _multiSelect,
                                    onTap: _multiSelect ? toggle : null,
                                    onLongPressAt: (pos) => _onLongPressEvent(
                                      context,
                                      e,
                                      pos,
                                      placement: contextMenuPlacement,
                                    ),
                                  ),
                                  isMe: isMe,
                                  id: e.eventId,
                                );
                              }
                              final isMe = _isEventFromCurrentUser(
                                e,
                                authUserId,
                              );
                              final anchorKey = _messageAnchorKey(e.eventId);
                              final flashing =
                                  _flashingMessageEventId == e.eventId.trim();
                              final selected = _selected.contains(e.eventId);
                              final agentMessageContent = isAgent && !isMe
                                  ? agentMessageProjection?.contentForEvent(e)
                                  : null;
                              final senderName = _eventSenderDisplayName(
                                e,
                                isMe: isMe,
                                peerDisplayName: name,
                              );
                              final senderAvatarUrl = _senderAvatarUrl(
                                e,
                                currentUserProfile,
                                fallbackUserId: authUserId,
                              );
                              final senderAvatarAsset =
                                  isAgent && !isMe ? agentAvatarAsset : null;
                              final localOrder = messageOrder.entryForEvent(
                                e.eventId,
                              );
                              final time = _formatMsgTime(
                                localOrder?.createdAt ?? e.originServerTs,
                              );
                              final avatarTap = _senderAvatarTap(
                                e,
                                isMe,
                                isAgentRoom: isAgent,
                              );
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
                                final alreadyJoined = _isJoinedGroupRoom(
                                      groupInvite.groupRoomId,
                                    ) ||
                                    isMe;
                                return enter(
                                  _SGroupInviteBubble(
                                    isMe: isMe,
                                    invite: groupInvite,
                                    time: time,
                                    showRead: isMe &&
                                        peerReadEventIds.contains(e.eventId),
                                    avatarSeed: senderName,
                                    avatarUrl: senderAvatarUrl,
                                    avatarAsset: senderAvatarAsset,
                                    onAvatarTap: avatarTap,
                                    selected: selected,
                                    multiSelect: _multiSelect,
                                    inviterDisplayName: isMe ? '我' : senderName,
                                    joining: _joiningGroupInviteEventIds
                                        .contains(e.eventId),
                                    alreadyJoined: alreadyJoined,
                                    onJoin: () => unawaited(
                                      _joinGroupInvite(groupInvite),
                                    ),
                                    onTap: _multiSelect ? toggle : null,
                                  ),
                                  isMe: isMe,
                                  id: e.eventId,
                                  anchorKey: anchorKey,
                                  flashing: flashing,
                                );
                              }

                              if (e.messageType == MessageTypes.Notice) {
                                return _SChatSystemNotice(text: e.body);
                              }

                              final channelSharePayload =
                                  channelSharePayloadFromContent(
                                Map<String, Object?>.from(e.content),
                              );
                              final redPacketPayload =
                                  redPacketPayloadFromContent(
                                Map<String, Object?>.from(e.content),
                                body: e.body,
                              );
                              if (redPacketPayload != null) {
                                return enter(
                                  _SBusinessCardBubble(
                                    isMe: isMe,
                                    time: time,
                                    showRead: isMe &&
                                        peerReadEventIds.contains(e.eventId),
                                    avatarSeed: senderName,
                                    avatarUrl: senderAvatarUrl,
                                    avatarAsset: senderAvatarAsset,
                                    onAvatarTap: avatarTap,
                                    selected: selected,
                                    multiSelect: _multiSelect,
                                    onTap: _multiSelect
                                        ? toggle
                                        : () => _openRedPacketDetail(
                                              redPacketPayload,
                                            ),
                                    onLongPressAt: (pos) => _onLongPressEvent(
                                      context,
                                      e,
                                      pos,
                                      placement: contextMenuPlacement,
                                    ),
                                    child: RedPacketMessageCard(
                                      payload: redPacketPayload,
                                      isMe: isMe,
                                      selected: selected,
                                    ),
                                  ),
                                  isMe: isMe,
                                  id: e.eventId,
                                  anchorKey: anchorKey,
                                  flashing: flashing,
                                );
                              }
                              if (channelSharePayload != null) {
                                final shareKey = channelShareJoinKey(
                                  channelSharePayload,
                                );
                                return enter(
                                  _SChannelShareBubble(
                                    isMe: isMe,
                                    payload: channelSharePayload,
                                    time: time,
                                    showRead: isMe &&
                                        peerReadEventIds.contains(e.eventId),
                                    avatarSeed: senderName,
                                    avatarUrl: senderAvatarUrl,
                                    avatarAsset: senderAvatarAsset,
                                    onAvatarTap: avatarTap,
                                    selected: selected,
                                    multiSelect: _multiSelect,
                                    joining: _joiningChannelShareIds.contains(
                                      shareKey,
                                    ),
                                    alreadyJoined: channelShareIsJoined(
                                          ref.read(asSyncCacheProvider),
                                          channelSharePayload,
                                        ) ||
                                        isMe,
                                    alreadyRequested: _requestedChannelShareIds
                                        .contains(shareKey),
                                    onJoin: () => unawaited(
                                      _joinChannelShare(channelSharePayload),
                                    ),
                                    onTap: _multiSelect
                                        ? toggle
                                        : () => context.push(
                                              channelShareOpenRoute(
                                                ref.read(asSyncCacheProvider),
                                                channelSharePayload,
                                                productConversations: ref
                                                        .read(
                                                          productConversationsProvider,
                                                        )
                                                        .valueOrNull ??
                                                    const [],
                                              ),
                                              extra: channelSharePayload,
                                            ),
                                    onLongPressAt: (pos) => _onLongPressEvent(
                                      context,
                                      e,
                                      pos,
                                      placement: contextMenuPlacement,
                                    ),
                                  ),
                                  isMe: isMe,
                                  id: e.eventId,
                                  anchorKey: anchorKey,
                                  flashing: flashing,
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
                                    showRead: isMe &&
                                        peerReadEventIds.contains(e.eventId),
                                    avatarSeed: senderName,
                                    avatarUrl: senderAvatarUrl,
                                    avatarAsset: senderAvatarAsset,
                                    onAvatarTap: avatarTap,
                                    selected: selected,
                                    multiSelect: _multiSelect,
                                    onTap: _multiSelect
                                        ? toggle
                                        : () => _openChatRecordDetail(
                                              context,
                                              chatRecordPayload,
                                            ),
                                    onLongPressAt: (pos) => _onLongPressEvent(
                                      context,
                                      e,
                                      pos,
                                      placement: contextMenuPlacement,
                                    ),
                                  ),
                                  isMe: isMe,
                                  id: e.eventId,
                                  anchorKey: anchorKey,
                                  flashing: flashing,
                                );
                              }

                              // 图片消息 → 缩略图气泡，点击全屏预览
                              if (e.messageType == MessageTypes.Image &&
                                  e.hasAttachment) {
                                return enter(
                                  _SChatImageBubble(
                                    isMe: isMe,
                                    time: time,
                                    showRead: isMe &&
                                        peerReadEventIds.contains(e.eventId),
                                    avatarSeed: senderName,
                                    avatarUrl: senderAvatarUrl,
                                    avatarAsset: senderAvatarAsset,
                                    onAvatarTap: avatarTap,
                                    mediaSize: chatMediaBubbleSizeForEvent(e),
                                    thumb: _MatrixThumb(
                                      key: ValueKey(
                                        'matrix_thumb_${e.eventId}_${e.originServerTs.millisecondsSinceEpoch}',
                                      ),
                                      event: e,
                                    ),
                                    selected: selected,
                                    multiSelect: _multiSelect,
                                    onTap: _multiSelect
                                        ? toggle
                                        : () => _openImageEvent(
                                              e,
                                              '${isMe ? '我' : senderName} · $time',
                                            ),
                                    onLongPressAt: (pos) => _onLongPressEvent(
                                      context,
                                      e,
                                      pos,
                                      placement: contextMenuPlacement,
                                    ),
                                  ),
                                  isMe: isMe,
                                  id: e.eventId,
                                  anchorKey: anchorKey,
                                  flashing: flashing,
                                );
                              }

                              if (e.messageType == MessageTypes.Video &&
                                  e.hasAttachment) {
                                final eventId = e.eventId.trim();
                                return enter(
                                  _SChatImageBubble(
                                    isMe: isMe,
                                    time: time,
                                    showRead: isMe &&
                                        peerReadEventIds.contains(e.eventId),
                                    avatarSeed: senderName,
                                    avatarUrl: senderAvatarUrl,
                                    avatarAsset: senderAvatarAsset,
                                    onAvatarTap: avatarTap,
                                    mediaSize: chatMessageDefaultMediaSize,
                                    thumb: _MatrixThumb(
                                      key: ValueKey(
                                        'matrix_video_thumb_${e.eventId}_${e.originServerTs.millisecondsSinceEpoch}',
                                      ),
                                      event: e,
                                      fallbackIcon: Symbols.movie,
                                      fit: BoxFit.cover,
                                    ),
                                    statusOverlay: _multiSelect
                                        ? null
                                        : _ImageDownloadStatusBadge(
                                            label: '视频',
                                            downloading:
                                                _downloadingFileEventIds
                                                    .contains(eventId),
                                            downloaded: _downloadedFileEventIds
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
                                        : () => _openVideoEvent(e),
                                    onLongPressAt: (pos) => _onLongPressEvent(
                                      context,
                                      e,
                                      pos,
                                      placement: contextMenuPlacement,
                                    ),
                                  ),
                                  isMe: isMe,
                                  id: e.eventId,
                                  anchorKey: anchorKey,
                                  flashing: flashing,
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
                                    showRead: isMe &&
                                        peerReadEventIds.contains(e.eventId),
                                    avatarSeed: senderName,
                                    avatarUrl: senderAvatarUrl,
                                    avatarAsset: senderAvatarAsset,
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
                                    onLongPressAt: (pos) => _onLongPressEvent(
                                      context,
                                      e,
                                      pos,
                                      placement: contextMenuPlacement,
                                    ),
                                  ),
                                  isMe: isMe,
                                  id: e.eventId,
                                  anchorKey: anchorKey,
                                  flashing: flashing,
                                );
                              }

                              // 文件附件 → 文件卡片，点击预览，右侧下载。
                              if (e.messageType == MessageTypes.File &&
                                  !_isVoiceEvent(e) &&
                                  e.hasAttachment) {
                                final size = e.infoMap['size'];
                                final sizeBytes = size is int ? size : 0;
                                final kind = fileKindLabel(
                                  e.attachmentMimetype,
                                  e.body,
                                );
                                final sizeLabel = sizeBytes > 0
                                    ? '$kind · ${formatByteSize(sizeBytes)}'
                                    : kind;
                                return enter(
                                  _SChatFileBubble(
                                    isMe: isMe,
                                    time: time,
                                    showRead: isMe &&
                                        peerReadEventIds.contains(e.eventId),
                                    avatarSeed: senderName,
                                    avatarUrl: senderAvatarUrl,
                                    avatarAsset: senderAvatarAsset,
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
                                      onDownload: () =>
                                          unawaited(_downloadFileEvent(e)),
                                    ),
                                    selected: selected,
                                    multiSelect: _multiSelect,
                                    onTap: _multiSelect
                                        ? toggle
                                        : () => _openFileEvent(e),
                                    onLongPressAt: (pos) => _onLongPressEvent(
                                      context,
                                      e,
                                      pos,
                                      placement: contextMenuPlacement,
                                    ),
                                  ),
                                  isMe: isMe,
                                  id: e.eventId,
                                  anchorKey: anchorKey,
                                  flashing: flashing,
                                );
                              }

                              return enter(
                                _SChatBubble(
                                  isMe: isMe,
                                  text: _messageDisplayText(e),
                                  agentContent: agentMessageContent,
                                  quote: _replyPreviewForEvent(
                                    e,
                                    messageEvents,
                                  ),
                                  onTapQuote: _scrollToQuotedEvent,
                                  time: time,
                                  showRead: isMe &&
                                      peerReadEventIds.contains(e.eventId),
                                  avatarSeed: senderName,
                                  avatarUrl: senderAvatarUrl,
                                  avatarAsset: senderAvatarAsset,
                                  onAvatarTap: avatarTap,
                                  selected: selected,
                                  multiSelect: _multiSelect,
                                  onTap: _multiSelect ? toggle : null,
                                  onLongPressAt: (pos) => _onLongPressEvent(
                                    context,
                                    e,
                                    pos,
                                    placement: contextMenuPlacement,
                                  ),
                                ),
                                isMe: isMe,
                                id: e.eventId,
                                anchorKey: anchorKey,
                                flashing: flashing,
                              );
                            },
                          );
                        },
                      ),
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
                  onFavorite: () =>
                      unawaited(_favoriteSelectedEvents(visibleEvents)),
                  onForward: () => unawaited(
                    _forwardSelectedEvents(
                      visibleEvents,
                      sourceName: name,
                      sourceRoomType: _favoriteRoomType(room),
                    ),
                  ),
                  onDelete: () =>
                      unawaited(_deleteSelectedEventsForMe(visibleEvents)),
                )
              else
                ChatCapsuleInputBar(
                  ctrl: _msgCtrl,
                  onSend: _send,
                  onPlus: canSendMedia
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
                  suggestionItems: agentSlashSuggestions,
                  suggestionsLabel: agentSlashCommandPickerLabel(locale),
                  onPickSuggestion: _pickAgentSlashCommand,
                  onTextChanged: _handleComposerTextChanged,
                  enabled: canSendMessages,
                  hintText: isWaitingForAccept
                      ? l10n?.chatPeerAcceptBeforeSend ?? '等待对方接受后才能发送消息'
                      : '',
                ),
              if (_showPlusPanel)
                ChatAttachmentPanel(
                  room: room,
                  roomId: widget.roomId,
                  canSend: canSendMedia,
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
                  onVoiceCall: isAgent
                      ? null
                      : () {
                          if (!canStartCall) {
                            _showPendingContactToast(context);
                            return;
                          }
                          context.push(
                            _privateVoiceCallRoute(
                              widget.roomId,
                              mxid,
                              name,
                              peerAvatarUrl,
                            ),
                          );
                        },
                  onVideoCall: isAgent
                      ? null
                      : () {
                          if (!canStartCall) {
                            _showPendingContactToast(context);
                            return;
                          }
                          context.push(
                            _privateVideoCallRoute(
                              widget.roomId,
                              mxid,
                              name,
                              peerAvatarUrl,
                            ),
                          );
                        },
                ),
              if (showEmojiPanelContent)
                ChatEmojiPanel(
                  height: _emojiPanelHeight,
                  onPick: (e) {
                    final c = _msgCtrl;
                    final base = c.text;
                    c.text = base + e;
                    c.selection = TextSelection.collapsed(
                      offset: c.text.length,
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

Set<String> _peerReadEventIds({
  required Room room,
  required String peerMxid,
  required List<Event> events,
}) {
  final peerId = peerMxid.trim();
  if (peerId.isEmpty) return const {};
  final receiptEventId =
      room.receiptState.global.otherUsers[peerId]?.eventId.trim() ?? '';
  if (receiptEventId.isEmpty) return const {};

  final ordered = events.toList(growable: false)
    ..sort((a, b) {
      final byTime = a.originServerTs.compareTo(b.originServerTs);
      if (byTime != 0) return byTime;
      return a.eventId.compareTo(b.eventId);
    });
  final receiptIndex = ordered.indexWhere(
    (event) => event.eventId == receiptEventId,
  );
  if (receiptIndex < 0) return const {};

  final myUserId = room.client.userID;
  return {
    for (var i = 0; i <= receiptIndex; i++)
      if (ordered[i].senderId == myUserId &&
          ordered[i].eventId.trim().isNotEmpty)
        ordered[i].eventId,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// 共享 widget：气泡 / 输入栏 / 面板 / 长按菜单 / 回复栏 / 多选栏
// ═══════════════════════════════════════════════════════════════════════════

/// s-chat 私聊气泡：私聊顶部已经展示对方头像和名字，消息行本身不再重复显示头像。
/// 自己右对齐 + `accent` 气泡 + 时间戳行内 `done_all` 已读图标。
class _QuotedMessagePreview {
  const _QuotedMessagePreview({
    this.eventId,
    required this.sender,
    required this.text,
  });

  final String? eventId;
  final String sender;
  final String text;

  _QuotedMessagePreview withEventId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || eventId == trimmed) return this;
    return _QuotedMessagePreview(eventId: trimmed, sender: sender, text: text);
  }
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

String _outboxCopyText(LocalOutboxItem item) {
  final text = item.text.trim();
  if (text.isNotEmpty) return text;
  final filename = item.filename.trim();
  if (filename.isNotEmpty) return filename;
  return switch (item.messageKind) {
    LocalOutboxMessageKind.image => '图片',
    LocalOutboxMessageKind.video => '视频',
    LocalOutboxMessageKind.file => '文件',
    LocalOutboxMessageKind.text => '',
  };
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

String _fileActionKey(Event event) {
  final eventId = event.eventId.trim();
  if (eventId.isNotEmpty) return eventId;
  final url = event.content.tryGet<String>('url')?.trim() ?? '';
  if (url.isNotEmpty) return url;
  return '${event.room.id}:${event.senderId}:${event.body}:${event.originServerTs.millisecondsSinceEpoch}';
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

String? _replyEventIdForEvent(Event event) {
  if (event.relationshipType == RelationshipTypes.reply) {
    final id = event.relationshipEventId?.trim();
    if (id != null && id.isNotEmpty) return id;
  }
  final relationshipEventId = event.relationshipEventId?.trim();
  if (relationshipEventId != null && relationshipEventId.isNotEmpty) {
    return relationshipEventId;
  }
  return _replyEventIdFromContent(event.content);
}

String? _replyEventIdFromContent(Map<String, dynamic> content) {
  String? nonEmpty(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  final productReply = nonEmpty(content['reply_to']) ??
      nonEmpty(content['replyTo']) ??
      nonEmpty(content['reply_to_event_id']);
  if (productReply != null) return productReply;

  final relatesTo = content['m.relates_to'];
  if (relatesTo is Map) {
    final inReplyTo = relatesTo['m.in_reply_to'];
    if (inReplyTo is Map) {
      final id = nonEmpty(inReplyTo['event_id']);
      if (id != null) return id;
    }
    final id = nonEmpty(relatesTo['event_id']);
    if (id != null) return id;
  }

  final inReplyTo = content['m.in_reply_to'];
  if (inReplyTo is Map) {
    return nonEmpty(inReplyTo['event_id']);
  }
  return null;
}

const _missingQuotedMessagePreview = _QuotedMessagePreview(
  sender: '引用消息',
  text: '原消息暂不可见',
);

_QuotedMessagePreview? _replyPreviewFromMatrixFallbackBody(String body) {
  final parsed = _parseMatrixReplyFallbackBody(body);
  if (parsed == null) return null;
  return _QuotedMessagePreview(sender: parsed.sender, text: parsed.text);
}

class _ParsedMatrixReplyFallback {
  const _ParsedMatrixReplyFallback({required this.sender, required this.text});

  final String sender;
  final String text;
}

_ParsedMatrixReplyFallback? _parseMatrixReplyFallbackBody(String body) {
  final lines = body.split('\n');
  if (lines.isEmpty || !lines.first.startsWith('> ')) return null;

  final quotedLines = <String>[];
  var index = 0;
  while (index < lines.length && lines[index].startsWith('> ')) {
    quotedLines.add(lines[index].substring(2));
    index++;
  }
  if (quotedLines.isEmpty ||
      index >= lines.length ||
      lines[index].trim().isNotEmpty) {
    return null;
  }

  var sender = '引用消息';
  final textParts = <String>[];
  for (var i = 0; i < quotedLines.length; i++) {
    var line = quotedLines[i].trim();
    if (i == 0 && line.startsWith('<')) {
      final senderEnd = line.indexOf('>');
      if (senderEnd > 1) {
        sender = line.substring(1, senderEnd).trim();
        line = line.substring(senderEnd + 1).trim();
      }
    }
    if (line.isNotEmpty) textParts.add(line);
  }

  final text = textParts.join('\n').trim();
  if (text.isEmpty) return null;
  return _ParsedMatrixReplyFallback(sender: sender, text: text);
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

class _MessageJumpFlash extends StatelessWidget {
  const _MessageJumpFlash({required this.flashing, required this.child});

  final bool flashing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: flashing ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SAgentThinkingBubble extends StatelessWidget {
  const _SAgentThinkingBubble({
    required this.avatarSeed,
    this.avatarUrl,
    this.avatarAsset,
  });

  final String avatarSeed;
  final String? avatarUrl;
  final String? avatarAsset;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return _bubbleRow(
      context: context,
      isMe: false,
      multiSelect: false,
      selected: false,
      avatarSeed: avatarSeed,
      avatarUrl: avatarUrl,
      avatarAsset: avatarAsset,
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          key: const ValueKey('agent_thinking_bubble'),
          decoration: BoxDecoration(
            color: t.surfaceHigh,
            borderRadius: chatDirectionalBubbleRadius(false),
            border: Border.all(color: t.border),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: AgentThinkingBubble(),
          ),
        ),
      ),
    );
  }
}

class _SAgentOfflineReplyBubble extends StatelessWidget {
  const _SAgentOfflineReplyBubble({
    required this.text,
    required this.avatarSeed,
    this.avatarUrl,
    this.avatarAsset,
  });

  final String text;
  final String avatarSeed;
  final String? avatarUrl;
  final String? avatarAsset;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return _bubbleRow(
      context: context,
      isMe: false,
      multiSelect: false,
      selected: false,
      avatarSeed: avatarSeed,
      avatarUrl: avatarUrl,
      avatarAsset: avatarAsset,
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          key: const ValueKey('agent_offline_reply_bubble'),
          decoration: BoxDecoration(
            color: t.surfaceHigh,
            borderRadius: chatDirectionalBubbleRadius(false),
            border: Border.all(color: t.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              text,
              style: AppTheme.sans(
                size: 17,
                weight: FontWeight.w500,
                color: t.text,
              ).copyWith(height: 1.25),
            ),
          ),
        ),
      ),
    );
  }
}

class _SChatBubble extends StatelessWidget {
  const _SChatBubble({
    super.key,
    required this.isMe,
    required this.text,
    required this.time,
    required this.showRead,
    required this.avatarSeed,
    this.agentContent,
    this.quote,
    this.avatarUrl,
    this.avatarAsset,
    this.onAvatarTap,
    this.selected = false,
    this.multiSelect = false,
    this.onTap,
    this.onTapQuote,
    this.onLongPressAt,
    this.outboxStatus,
  });

  final bool isMe;
  final String text;
  final String time;
  final bool showRead;
  final String avatarSeed;
  final AgentMessageContent? agentContent;
  final _QuotedMessagePreview? quote;
  final String? avatarUrl;
  final String? avatarAsset;
  final VoidCallback? onAvatarTap;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;
  final ValueChanged<String?>? onTapQuote;
  final _MessageContextAnchorCallback? onLongPressAt;
  final Widget? outboxStatus;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final bubbleColor = isMe ? t.accent : t.surfaceHigh;
    final textColor = isMe ? t.onAccent : t.text;
    Offset pos = Offset.zero;
    final bubbleKey = GlobalKey();
    final bubble = GestureDetector(
      key: bubbleKey,
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        pos = d.globalPosition;
        _chatGestureLog(
          'text bubble tapDown isMe=$isMe selected=$selected multi=$multiSelect pos=$pos hasTap=${onTap != null} hasLong=${onLongPressAt != null}',
        );
      },
      onTap: () {
        _chatGestureLog(
          'text bubble tap fire isMe=$isMe hasTap=${onTap != null}',
        );
        onTap?.call();
      },
      onTapCancel: () {
        _chatGestureLog('text bubble tapCancel isMe=$isMe pos=$pos');
      },
      onLongPressStart: (details) {
        pos = details.globalPosition;
        final anchor = _messageContextAnchorFor(bubbleKey, pos);
        _chatGestureLog(
          'text bubble longPressStart fire isMe=$isMe pos=$pos rect=${anchor.bubbleRect} hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(anchor);
      },
      onLongPressCancel: () {
        _chatGestureLog('text bubble longPressCancel isMe=$isMe pos=$pos');
      },
      onSecondaryTapDown: (d) {
        pos = d.globalPosition;
        _chatGestureLog(
          'text bubble secondaryTapDown isMe=$isMe pos=$pos hasLong=${onLongPressAt != null}',
        );
      },
      onSecondaryTap: () {
        final anchor = _messageContextAnchorFor(bubbleKey, pos);
        _chatGestureLog(
          'text bubble secondaryTap fire isMe=$isMe pos=$pos rect=${anchor.bubbleRect} hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(anchor);
      },
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
                  onTap: multiSelect ? null : onTapQuote,
                ),
                const SizedBox(height: 10),
              ],
              if (agentContent != null)
                AgentMessageBody(
                  agentContent!.markdown,
                  selectable: false,
                  cards: agentContent!.cards,
                  isGenerating: agentContent!.isGenerating,
                  animateUpdates: true,
                )
              else
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

    final status = outboxStatus;
    final timeRow = Padding(
      padding: EdgeInsets.only(top: 4, left: isMe ? 0 : 4, right: isMe ? 4 : 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(time, style: AppTheme.sans(size: 12, color: t.textMute)),
          if (status != null) ...[
            const SizedBox(width: 4),
            status,
          ] else if (isMe && showRead) ...[
            const SizedBox(width: 4),
            Icon(Symbols.done_all, size: 14, color: t.textMute),
          ],
        ],
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
              child: _MessageSelectCheckmark(selected: selected, onTap: onTap),
            ),
          ],
          if (!isMe) ...[
            _MessageAvatar(
              seed: avatarSeed,
              imageUrl: avatarUrl,
              imageAsset: avatarAsset,
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
            _MessageAvatar(
              seed: avatarSeed,
              imageUrl: avatarUrl,
              imageAsset: avatarAsset,
              onAvatarTap: onAvatarTap,
            ),
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
    this.onTap,
  });

  final _QuotedMessagePreview quote;
  final bool isMe;
  final ValueChanged<String?>? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final senderColor = isMe ? t.onAccent.withValues(alpha: 0.88) : t.accent;
    final bodyColor = isMe ? t.onAccent.withValues(alpha: 0.78) : t.textMute;
    final block = Container(
      key: const ValueKey('chat_quote_block'),
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMe
            ? t.onAccent.withValues(alpha: 0.18)
            : t.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
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
            quote.text.isEmpty
                ? l10n?.groupChatMessageFallback ?? '消息'
                : quote.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(
              size: 12,
              color: bodyColor,
              weight: FontWeight.w500,
            ).copyWith(height: 1.2),
          ),
        ],
      ),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: onTap == null
          ? block
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap?.call(quote.eventId),
              child: block,
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
    this.avatarUrl,
    this.avatarAsset,
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
  final String? avatarUrl;
  final String? avatarAsset;
  final VoidCallback? onAvatarTap;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;
  final _MessageContextAnchorCallback? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final cardKey = GlobalKey();
    return _bubbleRow(
      context: context,
      isMe: isMe,
      multiSelect: multiSelect,
      selected: selected,
      avatarSeed: avatarSeed,
      avatarUrl: avatarUrl,
      avatarAsset: avatarAsset,
      onAvatarTap: onAvatarTap,
      onSelectTap: onTap,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ChatRecordPreviewCard(
            key: cardKey,
            payload: payload,
            onTap: onTap,
            onLongPressAt: (position) => onLongPressAt?.call(
              _messageContextAnchorFor(cardKey, position),
            ),
          ),
          _bubbleTimeRow(context, time, showRead),
        ],
      ),
    );
  }
}

class _SBusinessCardBubble extends StatelessWidget {
  const _SBusinessCardBubble({
    required this.isMe,
    required this.child,
    required this.time,
    required this.showRead,
    required this.avatarSeed,
    this.avatarUrl,
    this.avatarAsset,
    this.onAvatarTap,
    this.selected = false,
    this.multiSelect = false,
    this.onTap,
    this.onLongPressAt,
  });

  final bool isMe;
  final Widget child;
  final String time;
  final bool showRead;
  final String avatarSeed;
  final String? avatarUrl;
  final String? avatarAsset;
  final VoidCallback? onAvatarTap;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;
  final _MessageContextAnchorCallback? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    return _bubbleRow(
      context: context,
      isMe: isMe,
      multiSelect: multiSelect,
      selected: selected,
      avatarSeed: avatarSeed,
      avatarUrl: avatarUrl,
      avatarAsset: avatarAsset,
      onAvatarTap: onAvatarTap,
      onSelectTap: multiSelect ? onTap : null,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [child, _bubbleTimeRow(context, time, showRead)],
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
    this.avatarAsset,
    this.onAvatarTap,
    this.selected = false,
    this.multiSelect = false,
    this.joining = false,
    this.alreadyJoined = false,
    this.alreadyRequested = false,
    this.onJoin,
    this.onTap,
    this.onLongPressAt,
  });

  final bool isMe;
  final ChannelSharePayload payload;
  final String time;
  final bool showRead;
  final String avatarSeed;
  final String? avatarUrl;
  final String? avatarAsset;
  final VoidCallback? onAvatarTap;
  final bool selected;
  final bool multiSelect;
  final bool joining;
  final bool alreadyJoined;
  final bool alreadyRequested;
  final VoidCallback? onJoin;
  final VoidCallback? onTap;
  final _MessageContextAnchorCallback? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final cardKey = GlobalKey();
    return _bubbleRow(
      context: context,
      isMe: isMe,
      multiSelect: multiSelect,
      selected: selected,
      avatarSeed: avatarSeed,
      avatarUrl: avatarUrl,
      avatarAsset: avatarAsset,
      onAvatarTap: onAvatarTap,
      onSelectTap: onTap,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ChannelSharePreviewCard(
            key: cardKey,
            payload: payload,
            joining: joining,
            alreadyJoined: alreadyJoined,
            alreadyRequested: alreadyRequested,
            onJoin: onJoin,
            onTap: onTap,
            onLongPressAt: (position) => onLongPressAt?.call(
              _messageContextAnchorFor(cardKey, position),
            ),
          ),
          _bubbleTimeRow(context, time, showRead),
        ],
      ),
    );
  }
}

class _SGroupInviteBubble extends StatelessWidget {
  const _SGroupInviteBubble({
    required this.isMe,
    required this.invite,
    required this.time,
    required this.showRead,
    required this.avatarSeed,
    this.avatarUrl,
    this.avatarAsset,
    this.onAvatarTap,
    this.selected = false,
    this.multiSelect = false,
    this.inviterDisplayName = '',
    this.joining = false,
    this.alreadyJoined = false,
    this.onJoin,
    this.onTap,
  });

  final bool isMe;
  final GroupInviteContent invite;
  final String time;
  final bool showRead;
  final String avatarSeed;
  final String? avatarUrl;
  final String? avatarAsset;
  final VoidCallback? onAvatarTap;
  final bool selected;
  final bool multiSelect;
  final String inviterDisplayName;
  final bool joining;
  final bool alreadyJoined;
  final VoidCallback? onJoin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _bubbleRow(
      context: context,
      isMe: isMe,
      multiSelect: multiSelect,
      selected: selected,
      avatarSeed: avatarSeed,
      avatarUrl: avatarUrl,
      avatarAsset: avatarAsset,
      onAvatarTap: onAvatarTap,
      onSelectTap: onTap,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GroupInviteCard(
            invite: invite,
            inviterDisplayName: inviterDisplayName,
            joining: joining,
            alreadyJoined: alreadyJoined,
            onJoin: onJoin ?? () {},
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
    this.avatarAsset,
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
  final String? avatarAsset;
  final VoidCallback? onAvatarTap;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;
  final _MessageContextAnchorCallback? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final cardKey = GlobalKey();
    return _bubbleRow(
      context: context,
      isMe: isMe,
      multiSelect: multiSelect,
      selected: selected,
      avatarSeed: avatarSeed,
      avatarUrl: avatarUrl,
      avatarAsset: avatarAsset,
      onAvatarTap: onAvatarTap,
      onSelectTap: onTap,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ChatCallRecordBubble(
            key: cardKey,
            isMe: isMe,
            isVideo: isVideo,
            text: text,
            selected: selected,
            onTap: multiSelect ? onTap : null,
            onLongPressAt: (position) => onLongPressAt?.call(
              _messageContextAnchorFor(cardKey, position),
            ),
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
    this.imageUrl,
    this.imageAsset,
    this.onAvatarTap,
  });

  final String? seed;
  final String? imageUrl;
  final String? imageAsset;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final avatar = PortalAvatar(
      seed: (seed == null || seed!.trim().isEmpty) ? 'peer' : seed!,
      size: 40,
      imageUrl: imageUrl,
      imageAsset: imageAsset,
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
  String? avatarUrl,
  String? avatarAsset,
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
            imageUrl: avatarUrl,
            imageAsset: avatarAsset,
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
          _MessageAvatar(
            seed: avatarSeed,
            imageUrl: avatarUrl,
            imageAsset: avatarAsset,
            onAvatarTap: onAvatarTap,
          ),
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
    this.mediaSize = chatMessageDefaultImageMediaSize,
    this.statusOverlay,
    this.centerOverlay,
    this.avatarUrl,
    this.avatarAsset,
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
  final ChatMediaBubbleSize mediaSize;
  final Widget? statusOverlay;
  final Widget? centerOverlay;
  final String? avatarUrl;
  final String? avatarAsset;
  final VoidCallback? onAvatarTap;
  final bool selected;
  final bool multiSelect;
  final _MessageContextAnchorCallback? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    Offset pos = Offset.zero;
    final imageKey = GlobalKey();
    final image = GestureDetector(
      key: imageKey,
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        pos = d.globalPosition;
        _chatGestureLog(
          'image bubble tapDown isMe=$isMe selected=$selected multi=$multiSelect pos=$pos hasTap=${onTap != null} hasLong=${onLongPressAt != null}',
        );
      },
      onTap: () {
        _chatGestureLog(
          'image bubble tap fire isMe=$isMe hasTap=${onTap != null}',
        );
        onTap?.call();
      },
      onTapCancel: () {
        _chatGestureLog('image bubble tapCancel isMe=$isMe pos=$pos');
      },
      onLongPressStart: (details) {
        pos = details.globalPosition;
        final anchor = _messageContextAnchorFor(imageKey, pos);
        _chatGestureLog(
          'image bubble longPressStart fire isMe=$isMe pos=$pos rect=${anchor.bubbleRect} hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(anchor);
      },
      onLongPressCancel: () {
        _chatGestureLog('image bubble longPressCancel isMe=$isMe pos=$pos');
      },
      onSecondaryTapDown: (d) {
        pos = d.globalPosition;
        _chatGestureLog(
          'image bubble secondaryTapDown isMe=$isMe pos=$pos hasLong=${onLongPressAt != null}',
        );
      },
      onSecondaryTap: () {
        final anchor = _messageContextAnchorFor(imageKey, pos);
        _chatGestureLog(
          'image bubble secondaryTap fire isMe=$isMe pos=$pos rect=${anchor.bubbleRect} hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(anchor);
      },
      child: ChatMediaBubbleFrame(
        width: mediaSize.width,
        height: mediaSize.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            thumb,
            if (centerOverlay != null) Center(child: centerOverlay!),
            if (statusOverlay != null)
              Positioned(right: 8, bottom: 8, child: statusOverlay!),
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
      avatarUrl: avatarUrl,
      avatarAsset: avatarAsset,
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
    this.avatarAsset,
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
  final String? avatarAsset;
  final VoidCallback? onAvatarTap;
  final bool selected;
  final bool multiSelect;
  final _MessageContextAnchorCallback? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Offset pos = Offset.zero;
    final bubbleKey = GlobalKey();
    final bubble = GestureDetector(
      key: bubbleKey,
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        pos = d.globalPosition;
        _chatGestureLog(
          'voice bubble tapDown isMe=$isMe selected=$selected multi=$multiSelect pos=$pos hasTap=${onTap != null} hasLong=${onLongPressAt != null}',
        );
      },
      onTap: () {
        _chatGestureLog(
          'voice bubble tap fire isMe=$isMe hasTap=${onTap != null}',
        );
        onTap?.call();
      },
      onTapCancel: () {
        _chatGestureLog('voice bubble tapCancel isMe=$isMe pos=$pos');
      },
      onLongPressStart: (details) {
        pos = details.globalPosition;
        final anchor = _messageContextAnchorFor(bubbleKey, pos);
        _chatGestureLog(
          'voice bubble longPressStart fire isMe=$isMe pos=$pos rect=${anchor.bubbleRect} hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(anchor);
      },
      onLongPressCancel: () {
        _chatGestureLog('voice bubble longPressCancel isMe=$isMe pos=$pos');
      },
      onSecondaryTapDown: (d) {
        pos = d.globalPosition;
        _chatGestureLog(
          'voice bubble secondaryTapDown isMe=$isMe pos=$pos hasLong=${onLongPressAt != null}',
        );
      },
      onSecondaryTap: () {
        final anchor = _messageContextAnchorFor(bubbleKey, pos);
        _chatGestureLog(
          'voice bubble secondaryTap fire isMe=$isMe pos=$pos rect=${anchor.bubbleRect} hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(anchor);
      },
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
      avatarAsset: avatarAsset,
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
    this.avatarUrl,
    this.avatarAsset,
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
  final String? avatarUrl;
  final String? avatarAsset;
  final VoidCallback? onAvatarTap;
  final Widget? trailing;
  final bool selected;
  final bool multiSelect;
  final _MessageContextAnchorCallback? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Offset pos = Offset.zero;
    final cardKey = GlobalKey();
    final card = GestureDetector(
      key: cardKey,
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        pos = d.globalPosition;
        _chatGestureLog(
          'file bubble tapDown isMe=$isMe selected=$selected multi=$multiSelect pos=$pos hasTap=${onTap != null} hasLong=${onLongPressAt != null}',
        );
      },
      onTap: () {
        _chatGestureLog(
          'file bubble tap fire isMe=$isMe hasTap=${onTap != null}',
        );
        onTap?.call();
      },
      onTapCancel: () {
        _chatGestureLog('file bubble tapCancel isMe=$isMe pos=$pos');
      },
      onLongPressStart: (details) {
        pos = details.globalPosition;
        final anchor = _messageContextAnchorFor(cardKey, pos);
        _chatGestureLog(
          'file bubble longPressStart fire isMe=$isMe pos=$pos rect=${anchor.bubbleRect} hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(anchor);
      },
      onLongPressCancel: () {
        _chatGestureLog('file bubble longPressCancel isMe=$isMe pos=$pos');
      },
      onSecondaryTapDown: (d) {
        pos = d.globalPosition;
        _chatGestureLog(
          'file bubble secondaryTapDown isMe=$isMe pos=$pos hasLong=${onLongPressAt != null}',
        );
      },
      onSecondaryTap: () {
        final anchor = _messageContextAnchorFor(cardKey, pos);
        _chatGestureLog(
          'file bubble secondaryTap fire isMe=$isMe pos=$pos rect=${anchor.bubbleRect} hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(anchor);
      },
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
      avatarUrl: avatarUrl,
      avatarAsset: avatarAsset,
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
  const _MessageSelectCheckmark({required this.selected, required this.onTap});

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
                    : Border.all(color: t.textMute.withValues(alpha: 0.36)),
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
        child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
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

class _InlineOutboxStatusIcon extends StatelessWidget {
  const _InlineOutboxStatusIcon({
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
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: t.textMute),
      );
    }
    return Semantics(
      button: true,
      label: '重新发送$label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRetry,
        child: SizedBox.square(
          dimension: 28,
          child: Center(
            child: Icon(Symbols.refresh, size: 16, color: t.danger),
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
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    if (downloading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
          ),
          const SizedBox(width: 4),
          Text(
            l10n?.groupChatDownloading ?? '下载中',
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
        l10n?.groupChatDownloaded ?? '已下载',
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
              _savingLabel(label),
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
          _savedLabel(label),
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
      label: _downloadSemanticLabel(label),
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

String _downloadSemanticLabel(String label) {
  return switch (label) {
    '视频' => '保存原视频',
    '图片' => '保存原图',
    _ => '下载$label',
  };
}

String _savingLabel(String label) {
  return switch (label) {
    '视频' => '保存中',
    '图片' => '保存中',
    _ => '下载中',
  };
}

String _savedLabel(String label) {
  return switch (label) {
    '视频' => '原视频已保存',
    '图片' => '原图已保存',
    _ => '已下载',
  };
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
    this.fit = BoxFit.contain,
  });
  final Event event;
  final IconData fallbackIcon;
  final BoxFit fit;
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
        return loadChatEventPreviewThumbnail(event);
      },
      validateBytes: isSupportedChatPreviewImageBytes,
      fit: fit,
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

void _showPendingContactToast(BuildContext context) {
  if (!context.mounted) return;
  final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
        content: Text(l10n?.chatPeerAcceptBeforeSend ?? '对方接受好友请求后才能发送消息')),
  );
}

String _privateVoiceCallRoute(
  String roomId,
  String peerUserId,
  String peerName,
  String? peerAvatarUrl,
) {
  return _privateCallRoute('call', roomId, peerUserId, peerName, peerAvatarUrl);
}

String _privateVideoCallRoute(
  String roomId,
  String peerUserId,
  String peerName,
  String? peerAvatarUrl,
) {
  return _privateCallRoute(
    'video-call',
    roomId,
    peerUserId,
    peerName,
    peerAvatarUrl,
  );
}

String _privateCallRoute(
  String path,
  String roomId,
  String peerUserId,
  String peerName,
  String? peerAvatarUrl,
) {
  final peerQuery = peerUserId.trim().isEmpty
      ? ''
      : '?peer=${Uri.encodeQueryComponent(peerUserId.trim())}';
  var separator = peerQuery.isEmpty ? '?' : '&';
  final nameQuery = peerName.trim().isEmpty
      ? ''
      : '${separator}name=${Uri.encodeQueryComponent(peerName.trim())}';
  if (nameQuery.isNotEmpty) separator = '&';
  final avatar = peerAvatarUrl?.trim();
  final avatarQuery = avatar == null || avatar.isEmpty
      ? ''
      : '${separator}avatar=${Uri.encodeQueryComponent(avatar)}';
  return '/$path/${Uri.encodeComponent(roomId)}$peerQuery$nameQuery$avatarQuery';
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
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
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
                  l10n?.chatReplyTo(sender) ?? '回复 $sender',
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
class _MessageContextAnchor {
  const _MessageContextAnchor({required this.position, this.bubbleRect});

  final Offset position;
  final Rect? bubbleRect;
}

typedef _MessageContextAnchorCallback = void Function(
    _MessageContextAnchor anchor);

_MessageContextAnchor _messageContextAnchorFor(GlobalKey key, Offset position) {
  final renderObject = key.currentContext?.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    return _MessageContextAnchor(
      position: position,
      bubbleRect: renderObject.localToGlobal(Offset.zero) & renderObject.size,
    );
  }
  return _MessageContextAnchor(position: position);
}

Future<String?> _showMsgContextMenu(
  BuildContext context,
  _MessageContextAnchor anchor, {
  required _MessageContextMenuPlacement placement,
  bool canCopy = true,
  bool canQuote = true,
  bool canRecall = false,
}) {
  final size = MediaQuery.of(context).size;
  final pos = anchor.position;
  final bubbleRect = anchor.bubbleRect;
  _chatGestureLog(
    'show menu request pos=$pos rect=$bubbleRect placement=$placement size=$size canCopy=$canCopy canQuote=$canQuote canRecall=$canRecall',
  );
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
      const menuVisibleH = 169.0;
      const bubbleGap = 10.0;
      var left = pos.dx - menuW / 2;
      final pointerOnTop = placement == _MessageContextMenuPlacement.below;
      final bubbleEdge = pointerOnTop
          ? bubbleRect?.bottom ?? pos.dy
          : bubbleRect?.top ?? pos.dy;
      var top = pointerOnTop
          ? bubbleEdge + bubbleGap
          : bubbleEdge - menuVisibleH - bubbleGap;
      if (left < horizontalMargin) left = horizontalMargin;
      if (left + menuW > size.width - horizontalMargin) {
        left = size.width - menuW - horizontalMargin;
      }
      top = top.clamp(12.0, math.max(12.0, size.height - menuH - 12));
      final pointerX = (pos.dx - left - 10).clamp(18.0, menuW - 38.0);
      _chatGestureLog(
        'show menu layout left=$left top=$top width=$menuW pointerX=$pointerX pointerOnTop=$pointerOnTop',
      );
      return SizedBox.expand(
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: menuW,
              height: menuH,
              child: _MsgCtxMenuCard(
                pointerX: pointerX,
                pointerOnTop: pointerOnTop,
                canCopy: canCopy,
                canQuote: canQuote,
                canRecall: canRecall,
              ),
            ),
          ],
        ),
      );
    },
    transitionBuilder: (ctx, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

enum _MessageContextMenuPlacement { above, below }

_MessageContextMenuPlacement _messageContextMenuPlacement(
  int visualIndex,
  int messageCount,
) {
  if (visualIndex <= 0) return _MessageContextMenuPlacement.below;
  if (messageCount > 0 && visualIndex == messageCount - 1) {
    return _MessageContextMenuPlacement.above;
  }
  return _MessageContextMenuPlacement.below;
}

class _MsgCtxMenuCard extends StatelessWidget {
  const _MsgCtxMenuCard({
    required this.pointerX,
    required this.pointerOnTop,
    required this.canCopy,
    required this.canQuote,
    required this.canRecall,
  });

  final double pointerX;
  final bool pointerOnTop;
  final bool canCopy;
  final bool canQuote;
  final bool canRecall;

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF4A4A4A); // theme-fixed: Figma menu surface
    const divider = Color(0x17FFFFFF); // theme-fixed: Figma row divider
    const itemW = 68.6;
    final l10n = AppLocalizations.of(context);
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
                    Positioned(
                      left: 0,
                      top: 12,
                      right: 0,
                      height: 58,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (canCopy)
                            _MsgCtxMenuItem(
                              width: itemW,
                              icon: Symbols.content_copy,
                              label: l10n.groupChatCopy,
                              value: 'copy',
                            ),
                          _MsgCtxMenuItem(
                            width: itemW,
                            icon: Symbols.forward,
                            label: l10n.groupChatForward,
                            value: 'forward',
                          ),
                          _MsgCtxMenuItem(
                            width: itemW,
                            icon: Symbols.bookmark,
                            label: l10n.groupChatFavorite,
                            value: 'fav',
                          ),
                          _MsgCtxMenuItem(
                            width: itemW,
                            icon: Symbols.delete,
                            label: l10n.groupChatDelete,
                            value: 'delete',
                          ),
                          _MsgCtxMenuItem(
                            width: itemW,
                            icon: Symbols.format_list_bulleted,
                            label: l10n.groupChatMultiSelect,
                            value: 'multi',
                          ),
                        ],
                      ),
                    ),
                    if (canQuote)
                      Positioned(
                        left: 1,
                        top: 87,
                        width: 69,
                        height: 58,
                        child: _MsgCtxMenuItem(
                          width: 69,
                          icon: Symbols.format_quote_rounded,
                          label: l10n.groupChatQuote,
                          value: 'quote',
                        ),
                      ),
                    if (canRecall)
                      Positioned(
                        left: 70,
                        top: 87,
                        width: 69,
                        height: 58,
                        child: _MsgCtxMenuItem(
                          width: 69,
                          icon: Symbols.undo,
                          label: l10n.groupChatRecall,
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
  const _MsgCtxPointerPainter({required this.color, required this.pointsDown});

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
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
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
              Text(
                l10n?.channelManageMessageEncryption ?? '消息加密',
                style: AppTheme.sans(size: 11, color: t.textMute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

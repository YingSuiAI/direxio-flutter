import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_zh.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../data/local_outbox_store.dart';
import '../../data/matrix_room_history_sync.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_call_session_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_clear_state_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../providers/local_message_order_provider.dart';
import '../providers/local_outbox_provider.dart';
import '../providers/matrix_message_clients_provider.dart';
import '../providers/media_thumbnail_cache_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/product_conversations_provider.dart';
import '../providers/voice_call_provider.dart';
import '../channel/channel_join_flow.dart';
import '../channel/channel_join_debug_log.dart';
import '../channel/channel_share.dart';
import '../channel/public_channel_target.dart';
import '../chat/cached_thumbnail_image.dart';
import '../chat/call_timeline_events.dart';
import '../chat/chat_attachment_panel.dart';
import '../chat/chat_avatar_snapshot_cache.dart';
import '../chat/chat_capsule_chrome.dart';
import '../chat/chat_glass_background.dart';
import '../chat/chat_room_recovery_controller.dart';
import '../chat/chat_room_recovery_sync.dart';
import '../chat/chat_timeline_controller.dart';
import '../chat/chat_timeline_event_source.dart';
import '../chat/chat_media_warmup.dart';
import '../chat/chat_message_cards.dart';
import '../chat/chat_record_detail_page.dart';
import '../chat/chat_record_forwarding.dart';
import '../chat/chat_media_send_flow.dart';
import '../chat/chat_scroll_metrics.dart';
import '../chat/chat_timeline_items.dart';
import '../chat/chat_video_preview_page.dart';
import '../chat/chat_voice_player.dart';
import '../chat/chat_voice_recorder.dart';
import '../chat/favorite_message_mapper.dart';
import '../chat/group_call_history_merge.dart';
import '../chat/local_outbox_image_thumb.dart';
import '../chat/product_media_outbox_flow.dart';
import '../chat/product_room_media_send_flow.dart';
import '../chat/red_packet_message.dart';
import '../call/voice_call_controller.dart';
import '../groups/group_invite_join_flow.dart';
import '../utils/avatar_url.dart';
import '../utils/chat_event_attachment.dart';
import '../utils/contact_display_name.dart';
import '../utils/conversation_capability_policy.dart';
import '../utils/direct_contact_status.dart';
import 'group_call_member_select_page.dart';
import '../utils/message_preview.dart';
import '../utils/product_conversation_navigation.dart';
import '../utils/chat_file_actions.dart';
import '../utils/save_image_to_gallery.dart';
import '../widgets/async_image_preview.dart';
import '../widgets/portal_avatar.dart';

void _groupChatGestureLog(String message) {
  debugPrint('[group chat gesture] $message');
}

String _groupChatEventMimeType(Event event, {required String fallback}) {
  final mimeType = event.attachmentMimetype.trim();
  return mimeType.isEmpty ? fallback : mimeType;
}

final AppLocalizations _fallbackGroupChatL10n = AppLocalizationsZh();

AppLocalizations _groupChatL10n(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      _fallbackGroupChatL10n;
}

Future<void> _popGroupChatOrHome(BuildContext context) async {
  final didPop = await Navigator.of(context).maybePop();
  if (!context.mounted || didPop) return;
  context.go('/home');
}

const _memberConversationKinds = {
  asConversationKindGroup,
  asConversationKindChannel,
};

Color _groupBubbleColor(PortalTokens t,
    {required bool isMe, bool selected = false}) {
  if (selected) return t.accent.withValues(alpha: 0.18);
  return isMe ? t.accent : t.surfaceHigh;
}

BoxBorder? _groupPeerBubbleBorder(PortalTokens t, {required bool isMe}) {
  if (isMe) return null;
  return Border.all(color: t.border.withValues(alpha: 0.55));
}

Color _groupBubbleShadowColor(PortalTokens t) {
  return t.text.withValues(alpha: 0.04);
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

String _fallbackDisplayNameForMxid(
  String mxid, {
  required String unknownMember,
}) {
  final trimmed = mxid.trim();
  if (trimmed.isEmpty) return unknownMember;
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
  const GroupChatPage({
    super.key,
    required this.roomId,
    this.targetEventId,
    this.channelId,
    this.channelName,
  });

  final String roomId;
  final String? targetEventId;
  final String? channelId;
  final String? channelName;

  @override
  ConsumerState<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends ConsumerState<GroupChatPage> {
  final _msgCtrl = TextEditingController();
  StreamSubscription<SyncUpdate>? _matrixSyncSub;
  Timeline? _timeline;
  bool _matrixMembershipLeft = false;
  bool _readMarkerInFlight = false;
  bool _readMarkerQueued = false;
  bool _thumbnailWarmupInFlight = false;
  bool _historyRequestInFlight = false;
  final _roomRecovery = ChatRoomRecoveryController();
  final Set<String> _warmedThumbnailEventIds = {};
  final Set<String> _favoritingEventIds = {};
  final Set<String> _retryingOutboxIds = {};
  final Set<String> _openingFileEventIds = {};
  final Set<String> _downloadingFileEventIds = {};
  final Set<String> _downloadedFileEventIds = {};
  final Set<String> _joiningChannelShareIds = {};
  final Set<String> _requestedChannelShareIds = {};
  final Map<String, AsCallSession> _roomAsCallHistory = {};
  final ChatInitialEntranceRegistry _initialTimelineEntrances =
      ChatInitialEntranceRegistry();
  Timer? _initialTimelineEntranceTimer;
  Timer? _asCallHistoryReloadTimer;
  bool _roomAsCallHistoryRefreshing = false;
  bool _multiSelect = false;
  bool _showPlusPanel = false;
  bool _showEmojiPanel = false;
  bool _mentionSheetOpen = false;
  bool _suppressMentionTrigger = false;
  final Set<String> _selected = {};
  final Set<String> _locallyHiddenEventIds = {};
  final ChatAvatarSnapshotCache _avatarSnapshotCache =
      ChatAvatarSnapshotCache();
  final Map<String, String> _atUserMap = {};
  Event? _replyTo;
  final Map<String, _GroupQuotedMessagePreview> _localReplyPreviews = {};
  final Map<String, GlobalKey> _messageAnchorKeys = {};
  final Map<String, int> _messageListIndexes = {};
  final ScrollController _messageScrollCtrl = ScrollController();
  Object? _lastAutoScrolledTimelineItemKey;
  Object? _pendingAutoScrollTimelineItemKey;
  Timer? _latestAutoScrollRetryTimer;
  bool _pendingViewportScrollToBottom = false;
  double _lastKeyboardInsetBottom = 0;
  double _emojiPanelHeight = chatEmojiPanelDefaultHeight;
  bool _lastBottomPanelVisible = false;
  String? _pendingTargetEventId;
  int _targetEventScrollAttempts = 0;
  Timer? _targetEventScrollTimer;
  String? _flashingMessageEventId;
  Timer? _flashingMessageTimer;
  final ChatVoicePlayer _voicePlayer = ChatVoicePlayer();
  final ChatVoiceRecorder _voiceRecorder = ChatVoiceRecorder();
  bool _stoppingVoiceRecording = false;

  String get _infoRoute {
    final channelId = widget.channelId?.trim();
    if (channelId != null && channelId.isNotEmpty) {
      return '/channel/${Uri.encodeComponent(channelId)}/info';
    }
    return '/group-info/${Uri.encodeComponent(_resolvedRoomId)}';
  }

  bool get _isChannelConversation =>
      widget.channelId?.trim().isNotEmpty ?? false;

  void _onVoicePlaybackChanged() {
    if (mounted) setState(() {});
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
    _groupChatGestureLog(
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
    final capabilityPolicy = _groupCapabilityPolicy(
      ref.read(productConversationsProvider).valueOrNull ??
          const <AsConversation>[],
      room,
      ref.read(asSyncCacheProvider),
    );
    if (!capabilityPolicy.canSendMedia) {
      _showGroupCannotSendToast(context);
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
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.groupChatVoiceRecordFailed('$e')),
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
        final l10n = _groupChatL10n(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.groupChatRecordingTooShort),
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
    final capabilityPolicy = _groupCapabilityPolicy(
      ref.read(productConversationsProvider).valueOrNull ??
          const <AsConversation>[],
      room,
      ref.read(asSyncCacheProvider),
    );
    if (!capabilityPolicy.canSendMedia) {
      _showGroupCannotSendToast(context);
      return;
    }
    final attachment = ChatMediaAttachment.audio(
      name: recording.filename,
      bytes: recording.bytes,
      mimeType: recording.mimeType,
      durationMs: recording.durationMs,
    );
    setState(() => _replyTo = null);
    final l10n = _groupChatL10n(context);
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
  }

  void _openChatRecordDetail(ChatRecordPayload payload) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatRecordDetailPage(payload: payload),
      ),
    );
  }

  void _openContactDetailFromAvatar(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return;
    context.push('/contact/${Uri.encodeComponent(id)}?source=chat_avatar');
  }

  VoidCallback? _memberAvatarTap(String userId) {
    final id = userId.trim();
    if (!id.startsWith('@') || !id.contains(':')) return null;
    return () => _openContactDetailFromAvatar(id);
  }

  VoidCallback? _memberAvatarMention(String userId, String displayName) {
    final id = userId.trim();
    if (!id.startsWith('@') || !id.contains(':')) return null;
    if (id == ref.read(matrixClientProvider).userID?.trim()) return null;
    return () {
      _insertMention(
        GroupCallInviteMember(
          userId: id,
          displayName: displayName.trim().isEmpty
              ? _fallbackDisplayNameForMxid(
                  id,
                  unknownMember: _groupChatL10n(context).groupChatUnknownMember,
                )
              : displayName.trim(),
        ),
      );
    };
  }

  Future<void> _openRedPacketDetail(RedPacketPayload payload) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RedPacketDetailPage(payload: payload),
      ),
    );
  }

  Future<void> _joinChannelShare(ChannelSharePayload payload) async {
    final key = channelShareJoinKey(payload);
    if (key.isEmpty || _joiningChannelShareIds.contains(key)) return;
    if (mounted) setState(() => _joiningChannelShareIds.add(key));
    try {
      final roomId = payload.roomId.trim();
      if (roomId.isEmpty) {
        final l10n = _groupChatL10n(context);
        throw StateError(l10n.groupChatCannotOpen(l10n.groupChatChannel));
      }
      final channelId = payload.channelId.trim();
      logChannelShareJoinStart(
        source: 'group_chat_channel_share',
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
              debugSource: 'group_chat_channel_share',
            )
          : await ref.read(asClientProvider).joinChannelByRoomId(
                channelShareJoinRequestTargetId(payload),
                discoveredChannel: payload.asDiscoveredChannel,
                remoteNodeBaseUri: publicBaseUriForMatrixRoomId(roomId),
              );
      logChannelShareJoinResult(
        source: 'group_chat_channel_share',
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
              channelJoinStatusText(
                joined.memberStatus,
                l10n: _groupChatL10n(context),
              ),
            ),
          ),
        );
        return;
      }
      context.push(channelShareJoinedRoute(payload, joined), extra: payload);
    } on Object catch (e) {
      logChannelShareJoinError(
        e,
        source: 'group_chat_channel_share',
        payload: payload,
      );
      logChannelShareJoinForbidden(
        e,
        source: 'group_chat_channel_share',
        payload: payload,
      );
      if (!mounted) return;
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.channelJoinFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _joiningChannelShareIds.remove(key));
    }
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
        _scrollToQuotedEventIndex(
          eventId,
          index,
          showUnavailable: false,
        ),
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
    final l10n = _groupChatL10n(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.groupChatOriginalMessageUnavailable)),
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

  void _syncMessageListIndexes(List<_GroupTimelineItem> items) {
    _messageListIndexes.clear();
    for (var i = 0; i < items.length; i++) {
      items[i].when(
        event: (event) {
          final id = event.eventId.trim();
          if (id.isNotEmpty) _messageListIndexes[id] = i;
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
    if ((_pendingTargetEventId?.trim() ?? '').isNotEmpty) return;
    if (newestItemKey == null) return;
    if (_lastAutoScrolledTimelineItemKey == newestItemKey ||
        _pendingAutoScrollTimelineItemKey == newestItemKey) {
      return;
    }
    _pendingAutoScrollTimelineItemKey = newestItemKey;
    _latestAutoScrollRetryTimer?.cancel();
    _scheduleLatestAutoScrollAttempt(
      newestItemKey,
      attempt: 0,
      instant: _lastAutoScrolledTimelineItemKey == null,
    );
  }

  void _scheduleLatestAutoScrollAttempt(
    Object newestItemKey, {
    required int attempt,
    required bool instant,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pendingAutoScrollTimelineItemKey != newestItemKey) return;
      final position = chatScrollPositionWithDimensions(_messageScrollCtrl);
      final hasPosition = position != null;
      final target = position?.maxScrollExtent ?? 0;
      final isAtLatest = position != null &&
          (position.pixels - target).abs() < chatLatestAutoScrollTolerance;
      if (position != null && !isAtLatest) {
        if (instant) {
          _messageScrollCtrl.jumpTo(target);
        } else {
          unawaited(_messageScrollCtrl.animateTo(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          ));
        }
      }
      final shouldRetry = shouldRetryLatestInitialAutoScroll(
            hasPosition: hasPosition,
            isAtLatest: isAtLatest,
            attempt: attempt,
          ) &&
          (instant || !hasPosition);
      if (shouldRetry) {
        _latestAutoScrollRetryTimer?.cancel();
        _latestAutoScrollRetryTimer = Timer(
          chatLatestInitialAutoScrollRetryDelay,
          () {
            if (!mounted) return;
            _scheduleLatestAutoScrollAttempt(
              newestItemKey,
              attempt: attempt + 1,
              instant: instant,
            );
          },
        );
        return;
      }
      _pendingAutoScrollTimelineItemKey = null;
      if (position != null) {
        _lastAutoScrolledTimelineItemKey = newestItemKey;
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
      onDownload: () => _saveImageEventToAlbum(event),
    );
  }

  Future<void> _saveImageEventToAlbum(Event event) async {
    try {
      final matrixFile = await event.downloadAndDecryptAttachment();
      final file = await writeChatActionFile(
        directory:
            Directory('${(await getTemporaryDirectory()).path}/p2p-im-save'),
        fileName: event.body,
        bytes: matrixFile.bytes,
      );
      await saveMediaFileToGallery(
        path: file.path,
        fileName: file.uri.pathSegments.last,
        mimeType: _groupChatEventMimeType(event, fallback: 'image/jpeg'),
      );
      if (!mounted) return;
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.chatImageSavedToAlbum ?? '已保存原图到相册')),
      );
    } on Object catch (err) {
      debugPrint('save group image failed: $err');
      if (!mounted) return;
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.chatSaveFailed('$err') ?? '保存失败：$err')),
      );
    }
  }

  Future<File> _materializeFileEvent(
    Event event, {
    required bool persistent,
    String? fileName,
  }) async {
    final matrixFile = await downloadChatEventAttachment(event);
    final baseDir = persistent
        ? Directory(
            '${(await getApplicationDocumentsDirectory()).path}/P2P IM Downloads',
          )
        : Directory('${(await getTemporaryDirectory()).path}/p2p-im-open');
    return writeChatActionFile(
      directory: baseDir,
      fileName: fileName ?? event.body,
      bytes: matrixFile.bytes,
    );
  }

  Future<void> _openFileEvent(Event event) async {
    if (_isGroupVoiceEvent(event)) {
      await _playVoiceEvent(event);
      return;
    }
    final openKey = _groupFileActionKey(event);
    if (_openingFileEventIds.contains(openKey)) return;
    _openingFileEventIds.add(openKey);
    try {
      final file = await _materializeFileEvent(event, persistent: false);
      await previewChatActionFile(file);
    } on Object catch (err) {
      debugPrint('open group file failed: $err');
      if (!mounted) return;
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupChatOpenFailed('$err'))),
      );
    } finally {
      _openingFileEventIds.remove(openKey);
    }
  }

  Future<void> _openVideoEvent(Event event) async {
    try {
      final file = await _materializeFileEvent(event, persistent: false);
      if (!mounted) return;
      await openChatVideoPreview(
        context,
        file: file,
        title: event.body,
        onSaveToAlbum: () {
          return saveMediaFileToGallery(
            path: file.path,
            fileName: file.uri.pathSegments.last,
            mimeType: _groupChatEventMimeType(event, fallback: 'video/mp4'),
          );
        },
      );
    } on Object catch (err) {
      debugPrint('open group video failed: $err');
      if (!mounted) return;
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupChatPlaybackFailed('$err'))),
      );
    }
  }

  Future<void> _playVoiceEvent(Event event) async {
    try {
      final matrixFile = await downloadChatEventAttachment(event);
      await _voicePlayer.playBytes(
        matrixFile.bytes,
        mimeType: event.attachmentMimetype,
        messageId: event.eventId.trim().isEmpty ? null : event.eventId.trim(),
      );
    } on Object catch (err) {
      debugPrint('play group voice failed: $err');
      if (!mounted) return;
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupChatPlaybackFailed('$err'))),
      );
    }
  }

  void _seekVoiceEvent(Event event, int seconds) {
    if (_voicePlayer.playback.value.messageId != event.eventId.trim()) return;
    unawaited(_voicePlayer.seek(Duration(seconds: seconds)));
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
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.groupChatDownloadSaved(file.uri.pathSegments.last),
          ),
        ),
      );
    } on Object catch (err) {
      debugPrint('download group file failed: $err');
      if (!mounted) return;
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupChatDownloadFailed('$err'))),
      );
    } finally {
      if (eventId.isNotEmpty && mounted) {
        setState(() => _downloadingFileEventIds.remove(eventId));
      }
    }
  }

  String get _resolvedRoomId {
    final currentChannel =
        _currentChannelSummary(ref.read(asSyncCacheProvider));
    final channelRoomId = currentChannel?.roomId.trim() ?? '';
    return channelRoomId.isNotEmpty ? channelRoomId : widget.roomId;
  }

  Room? get _room =>
      ref.read(matrixClientProvider).getRoomById(_resolvedRoomId);

  AsSyncRoomSummary? _groupSummary(AsSyncCacheState syncCache) {
    final resolvedRoomId = _resolvedRoomId;
    for (final group
        in syncCache.bootstrap?.groups ?? const <AsSyncRoomSummary>[]) {
      if (group.roomId.trim() == resolvedRoomId ||
          group.roomId.trim() == widget.roomId) {
        return group;
      }
    }
    return null;
  }

  AsSyncRoomSummary? _conversationSummary(AsSyncCacheState syncCache) {
    return _currentChannelSummary(syncCache) ?? _groupSummary(syncCache);
  }

  @override
  void initState() {
    super.initState();
    _pendingTargetEventId = widget.targetEventId?.trim();
    _msgCtrl.addListener(_onComposerTextChanged);
    _voicePlayer.playback.addListener(_onVoicePlaybackChanged);
    _messageScrollCtrl.addListener(_onMessageScroll);
    _matrixMembershipLeft = _currentRoomHasLeftMatrixMembership();
    _matrixSyncSub = ref.read(matrixClientProvider).onSync.stream.listen((_) {
      if (!mounted) return;
      final left = _currentRoomHasLeftMatrixMembership();
      if (!mounted || left == _matrixMembershipLeft) return;
      setState(() {
        _matrixMembershipLeft = left;
        if (left) {
          _showPlusPanel = false;
          _showEmojiPanel = false;
          _replyTo = null;
        }
      });
    });
    if (!_isChannelConversation) {
      unawaited(_loadLocalAsCallHistory());
    }
    _initTimeline();
  }

  @override
  void didUpdateWidget(covariant GroupChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId ||
        oldWidget.channelId != widget.channelId) {
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
      return;
    }
    void rebuild() {
      if (!mounted) return;
      setState(() {});
      if (!_isChannelConversation) {
        _scheduleAsCallHistoryReloadForTimeline();
      }
      _scheduleTimelineThumbnailWarmup();
      unawaited(_markCurrentTimelineRead());
    }

    _timeline = await ChatTimelineController(
      room: room,
      rebuild: rebuild,
      debugLabel: _isChannelConversation ? 'channel' : 'group',
    ).openInitialTimeline();
    if (mounted) setState(() {});
    _scheduleTimelineThumbnailWarmup();
    unawaited(_markCurrentTimelineRead());
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
        debugLabel: _isChannelConversation ? 'channel' : 'group',
      ).requestOlderMessages(timeline);
    } finally {
      _historyRequestInFlight = false;
    }
  }

  Future<void> _recoverMissingGroupRoom({bool force = false}) async {
    final result = await _roomRecovery.runAttempt(
      force: force,
      attempt: () async {
        if (!mounted) return false;
        var syncCache = ref.read(asSyncCacheProvider);
        var summary = _conversationSummary(syncCache);
        if (summary == null && syncCache.bootstrap == null) {
          try {
            if (!mounted) return false;
            final bootstrap =
                await ref.read(asBootstrapRepositoryProvider).refresh();
            if (!mounted) return false;
            ref.read(asSyncCacheProvider.notifier).update(
                  (state) => state.copyWith(bootstrap: bootstrap),
                );
            if (!mounted) return false;
            syncCache = ref.read(asSyncCacheProvider);
            summary = _conversationSummary(syncCache);
          } on Object catch (e) {
            debugPrint('group chat bootstrap recovery failed: $e');
          }
        }
        if (summary == null && !force) return false;
        final recoveryRoomId = summary?.roomId.trim().isNotEmpty == true
            ? summary!.roomId.trim()
            : _resolvedRoomId;
        await waitForJoinedGroupMatrixRoom(
          roomId: recoveryRoomId,
          oneShotSync: () => _syncMissingGroupRoomFromServer(recoveryRoomId),
          refreshBootstrap: _refreshBootstrapForRoomRecovery,
          hasJoinedMatrixRoom: (roomId) {
            if (!mounted) return false;
            return ref
                    .read(matrixClientProvider)
                    .getRoomById(roomId)
                    ?.membership ==
                Membership.join;
          },
          timeout: const Duration(seconds: 45),
          interval: const Duration(seconds: 2),
          shouldContinue: () => mounted,
        );
        return mounted && _room != null;
      },
    );
    if (!mounted) return;
    if (result == ChatRoomRecoveryAttemptResult.recovered) {
      await _initTimeline();
      return;
    }
    if (result == ChatRoomRecoveryAttemptResult.failed) {
      setState(() {});
    }
  }

  void _ensureMissingGroupRoomRecovery() {
    if (_roomRecovery.inFlight || _roomRecovery.attempted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _room != null) return;
      unawaited(_recoverMissingGroupRoom());
    });
  }

  Future<void> _refreshBootstrapForRoomRecovery() async {
    try {
      if (!mounted) return;
      final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
      if (!mounted) return;
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
    } on Object catch (e) {
      debugPrint('group chat bootstrap recovery failed: $e');
    }
  }

  Future<void> _syncMissingGroupRoomFromServer(String roomId) async {
    if (!mounted) return;
    final client = ref.read(matrixClientProvider);
    await syncMissingRoomHistoryFromServer(
      roomId: roomId,
      syncHistory: ({required roomId, required timelineLimit}) {
        return syncMatrixRoomHistory(
          client,
          roomId: roomId,
          timelineLimit: timelineLimit,
        );
      },
    );
  }

  void _retryMissingGroupRoomRecovery() {
    setState(_roomRecovery.retry);
    unawaited(_recoverMissingGroupRoom(force: true));
  }

  Future<void> _loadLocalAsCallHistory() async {
    if (_isChannelConversation) return;
    try {
      final store = await ref.read(asCallSessionStoreProvider.future);
      final sessions = await store.readRoomStable(widget.roomId);
      if (!mounted) return;
      _replaceRoomAsCallHistory(sessions);
    } on Object catch (e) {
      debugPrint('load local group P2P call history failed: $e');
    }
    unawaited(_refreshAsCallHistoryFromAs());
  }

  void _scheduleAsCallHistoryReloadForTimeline() {
    if (_isChannelConversation) return;
    final room = _room;
    if (room == null) return;
    final rawTimelineEvents = timelineEventsIncludingRoomLastEvent(
      room,
      _timeline,
    );
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
    if (_isChannelConversation) return;
    if (_roomAsCallHistoryRefreshing) return;
    _roomAsCallHistoryRefreshing = true;
    try {
      final asClient = ref.read(asClientProvider);
      final store = await ref.read(asCallSessionStoreProvider.future);
      final sessions = await asClient.listCalls(
        roomId: _resolvedRoomId,
        limit: 100,
      );
      await store.upsertAll(sessions);
      final stable = await store.readRoomStable(_resolvedRoomId);
      if (!mounted) return;
      _replaceRoomAsCallHistory(stable);
    } on Object catch (e) {
      debugPrint('refresh group P2P call history failed: $e');
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
    final l10n = _groupChatL10n(context);
    if (trimmed.isEmpty) return l10n.groupChatUnknownMember;
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
    return _fallbackDisplayNameForMxid(
      trimmed,
      unknownMember: l10n.groupChatUnknownMember,
    );
  }

  String? _avatarUrlForMxid(
    Room room,
    AsSyncCacheState syncCache,
    String mxid,
    Profile? currentUserProfile,
  ) {
    final trimmed = mxid.trim();
    if (trimmed.isEmpty) return null;
    final contact = syncCache.contactForUserId(trimmed);
    final memberAvatarUrl = localRoomMemberAvatarHttpUrl(room, trimmed);
    final contactAvatarUrl = avatarHttpUrl(room.client, contact?.avatarUrl);
    final currentUserId = room.client.userID?.trim() ?? '';
    final isCurrentUser = currentUserId.isNotEmpty && trimmed == currentUserId;
    return _avatarSnapshotCache.resolve(
      senderId: trimmed,
      candidates: [
        if (isCurrentUser)
          ChatAvatarCandidate(
            url: profileAvatarHttpUrl(currentUserProfile, room.client),
            priority: ChatAvatarCandidatePriority.currentUserProfile,
          ),
        ChatAvatarCandidate(
          url: memberAvatarUrl,
          priority: ChatAvatarCandidatePriority.matrixMember,
        ),
        ChatAvatarCandidate(
          url: contactAvatarUrl,
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
    if (!mounted) return;
    final room = _room;
    final timeline = _timeline;
    if (room == null) return;
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
        debugLabel: _isChannelConversation ? 'channel' : 'group',
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

  _GroupQuotedMessagePreview? _replyPreviewForEvent(
    Event event,
    List<Event> visibleEvents,
  ) {
    final localPreview = _localReplyPreviews[event.eventId.trim()];
    if (localPreview != null) return localPreview;
    final l10n = _groupChatL10n(context);
    final fallbackPreview = _groupReplyPreviewFromMatrixFallbackBody(
      event.body,
      l10n,
    );
    final replyEventId = _groupReplyEventIdForEvent(event);
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
          _missingGroupQuotedMessagePreview(l10n).withEventId(replyEventId);
    }
    return _GroupQuotedMessagePreview(
      eventId: quoted.eventId,
      sender: quoted.senderFromMemoryOrFallback.calcDisplayname(),
      text: quotedEventPreviewText(quoted, l10n: l10n),
    );
  }

  void _rememberLocalReplyPreview(String eventId, Event? replyTo) {
    final trimmed = eventId.trim();
    if (trimmed.isEmpty || replyTo == null) return;
    _localReplyPreviews[trimmed] = _GroupQuotedMessagePreview(
      eventId: replyTo.eventId,
      sender: replyTo.senderFromMemoryOrFallback.calcDisplayname(),
      text: quotedEventPreviewText(replyTo, l10n: _groupChatL10n(context)),
    );
  }

  @override
  void dispose() {
    unawaited(_matrixSyncSub?.cancel());
    _timeline?.cancelSubscriptions();
    _initialTimelineEntranceTimer?.cancel();
    _targetEventScrollTimer?.cancel();
    _latestAutoScrollRetryTimer?.cancel();
    _asCallHistoryReloadTimer?.cancel();
    _flashingMessageTimer?.cancel();
    _voicePlayer.playback.removeListener(_onVoicePlaybackChanged);
    unawaited(_voicePlayer.dispose());
    unawaited(_voiceRecorder.dispose());
    _messageScrollCtrl.dispose();
    _msgCtrl.removeListener(_onComposerTextChanged);
    _msgCtrl.dispose();
    super.dispose();
  }

  void _onComposerTextChanged() {
    if (_suppressMentionTrigger || _mentionSheetOpen || !mounted) return;
    final value = _msgCtrl.value;
    final selection = value.selection;
    if (selection.isValid && !selection.isCollapsed) return;
    final cursor =
        selection.isValid ? selection.extentOffset : value.text.length;
    if (cursor <= 0 || cursor > value.text.length) return;
    if (value.text.substring(cursor - 1, cursor) != '@') return;
    final room = _room;
    if (room == null) return;
    unawaited(_showMentionMemberPicker(room));
  }

  Future<void> _showMentionMemberPicker(Room room) async {
    if (_mentionSheetOpen) return;
    _mentionSheetOpen = true;
    try {
      if (!mounted) return;
      final members = mentionMembersForRoom(
        room,
        currentUserId: ref.read(matrixClientProvider).userID,
        isChannelConversation: _isChannelConversation,
      );
      final selected = await showModalBottomSheet<GroupCallInviteMember>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _GroupMentionMemberSheet(members: members),
      );
      if (selected == null || !mounted) return;
      _insertMention(selected);
    } finally {
      _mentionSheetOpen = false;
    }
  }

  void _insertMention(GroupCallInviteMember member) {
    final nickname = member.displayName.trim().isEmpty
        ? _fallbackDisplayNameForMxid(
            member.userId,
            unknownMember: _groupChatL10n(context).groupChatUnknownMember,
          )
        : member.displayName.trim();
    final mentionText = '@$nickname ';
    final value = _msgCtrl.value;
    final text = value.text;
    final selection = value.selection;
    final cursor = selection.isValid ? selection.extentOffset : text.length;
    final safeCursor = cursor.clamp(0, text.length);
    final replaceAt =
        safeCursor > 0 && text.substring(safeCursor - 1, safeCursor) == '@';
    final start = replaceAt ? safeCursor - 1 : safeCursor;
    final nextText = text.replaceRange(start, safeCursor, mentionText);
    final nextCursor = start + mentionText.length;
    _suppressMentionTrigger = true;
    _msgCtrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
    _suppressMentionTrigger = false;
    _atUserMap[member.userId] = nickname;
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final room = _room;
    if (room == null) return;
    final syncCache = ref.read(asSyncCacheProvider);
    final productConversations =
        ref.read(productConversationsProvider).valueOrNull ??
            const <AsConversation>[];
    if (_isRemovedFromGroupConversation(
      room: room,
      syncCache: syncCache,
      productConversations: productConversations,
    )) {
      _showGroupCannotSendToast(context);
      return;
    }
    final capabilityPolicy = _groupCapabilityPolicy(
      productConversations,
      room,
      syncCache,
    );
    if (!capabilityPolicy.canSendText) {
      _showGroupCannotSendToast(context);
      return;
    }
    final replyTo = _replyTo;
    final mentions = _mentionsForText(text);
    _msgCtrl.clear();
    _atUserMap.clear();
    setState(() => _replyTo = null);
    String? pendingId;
    try {
      pendingId = await ref.read(localOutboxProvider.notifier).startItem(
            conversationId: room.id,
            conversationType: LocalOutboxConversationType.group,
            draft: LocalOutboxDraft.text(text: text),
          );
    } on Object catch (e) {
      debugPrint('start group local text outbox failed: $e');
    }
    try {
      final eventId = await _sendGroupOrChannelText(
        room,
        text,
        replyTo: replyTo,
        mentions: mentions,
      );
      _rememberLocalReplyPreview(eventId, replyTo);
      try {
        final client = ref.read(matrixClientProvider);
        if (client.onLoginStateChanged.value == LoginState.loggedIn) {
          await client.oneShotSync();
        }
      } on Object catch (e) {
        debugPrint('post-send group Matrix sync failed: $e');
      }
      if (pendingId != null) {
        await ref.read(localOutboxProvider.notifier).completeItem(pendingId);
      }
    } on Object catch (e) {
      if (pendingId != null) {
        await ref.read(localOutboxProvider.notifier).failItem(pendingId);
      }
      if (!mounted) return;
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupChatSendFailed('$e'))),
      );
    }
  }

  Future<String> _sendGroupOrChannelText(
    Room room,
    String text, {
    Event? replyTo,
    List<Map<String, String>> mentions = const [],
  }) async {
    final content = <String, Object?>{
      'msgtype': MessageTypes.Text,
      'body': text,
      if (replyTo?.eventId.trim().isNotEmpty ?? false)
        'reply_to': replyTo!.eventId,
      if (replyTo?.eventId.trim().isNotEmpty ?? false)
        'm.relates_to': {
          'm.in_reply_to': {
            'event_id': replyTo!.eventId,
          },
        },
      if (mentions.isNotEmpty) ...{
        'mentions': mentions,
        'mentions_json': jsonEncode(mentions),
      },
    };
    return room.client.sendMessage(
      room.id,
      EventTypes.Message,
      room.client.generateUniqueTransactionId(),
      content,
    );
  }

  List<Map<String, String>> _mentionsForText(String text) {
    final result = <Map<String, String>>[];
    for (final entry in _atUserMap.entries) {
      final userId = entry.key.trim();
      final name = entry.value.trim();
      if (userId.isEmpty || name.isEmpty) continue;
      if (!text.contains('@$name')) continue;
      result.add({
        'user_id': userId,
        'display_name': name,
      });
    }
    return result;
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

  bool _canSendGroupMessage(Room room, AsSyncCacheState syncCache) {
    if (room.membership != Membership.join) return false;
    final channelId = widget.channelId?.trim();
    if (channelId != null && channelId.isNotEmpty) {
      return _isJoinedChannelConversation(room, syncCache);
    }
    final isJoinedAsGroup = syncCache.bootstrap?.groups.any(
          (group) => group.roomId.trim() == room.id,
        ) ??
        false;
    return isJoinedAsGroup;
  }

  bool _currentRoomHasLeftMatrixMembership() {
    final room = _room;
    if (room == null) return false;
    return _isLeftMatrixMembership(room.membership);
  }

  bool _isRemovedFromGroupConversation({
    required Room room,
    required AsSyncCacheState syncCache,
    required Iterable<AsConversation> productConversations,
  }) {
    if (_isChannelConversation) return false;
    if (_matrixMembershipLeft || _isLeftMatrixMembership(room.membership)) {
      return true;
    }
    final group = _groupSummary(syncCache);
    if (_isNonJoinedGroupMembership(group?.memberStatus)) return true;
    final conversation = productConversationForRoom(
      productConversations,
      room.id,
      kinds: const {asConversationKindGroup},
    );
    return _isNonJoinedGroupMembership(conversation?.membership) ||
        _isNonJoinedGroupMembership(conversation?.relationshipStatus) ||
        _isNonJoinedGroupMembership(conversation?.projectionState);
  }

  bool _isLeftMatrixMembership(Membership membership) {
    return membership == Membership.leave || membership == Membership.ban;
  }

  bool _isNonJoinedGroupMembership(String? status) {
    switch (status?.trim().toLowerCase()) {
      case 'leave':
      case 'left':
      case 'ban':
      case 'banned':
      case 'kick':
      case 'kicked':
      case 'remove':
      case 'removed':
      case 'rejected':
      case 'reject':
        return true;
    }
    return false;
  }

  ConversationCapabilityPolicy _groupCapabilityPolicy(
    Iterable<AsConversation> productConversations,
    Room room,
    AsSyncCacheState syncCache,
  ) {
    return conversationCapabilityPolicy(
      conversation: productConversationForRoom(
        productConversations,
        room.id,
        kinds: _memberConversationKinds,
      ),
      fallbackCanSend: _canSendGroupMessage(room, syncCache),
    );
  }

  bool _isJoinedChannelConversation(Room room, AsSyncCacheState syncCache) {
    if (room.membership != Membership.join) return false;
    final channelId = widget.channelId?.trim();
    if (channelId == null || channelId.isEmpty) return false;
    final channels = syncCache.bootstrap?.channels ?? const [];
    for (final channel in channels) {
      final cachedChannelId = channel.channelId.trim();
      final cachedRoomId = channel.roomId.trim();
      final matchesChannel = cachedChannelId == channelId ||
          cachedRoomId == channelId ||
          cachedRoomId == room.id;
      if (!matchesChannel) continue;
      return isAsChannelMemberJoined(channel.memberStatus);
    }
    return false;
  }

  void _showGroupCannotSendToast(BuildContext context) {
    if (!context.mounted) return;
    final l10n = _groupChatL10n(context);
    final isChannelConversation = widget.channelId?.trim().isNotEmpty ?? false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isChannelConversation
            ? l10n.groupChatCannotSendChannel
            : l10n.groupChatCannotSendGroup),
      ),
    );
  }

  String _channelConversationTitle(
    AsSyncCacheState syncCache,
    String channelId,
    String fallback,
  ) {
    final trimmedChannelId = channelId.trim();
    final explicitName = widget.channelName?.trim() ?? '';
    if (trimmedChannelId.isEmpty) {
      return explicitName.isNotEmpty ? explicitName : fallback;
    }
    final channels = syncCache.bootstrap?.channels ?? const [];
    for (final channel in channels) {
      final cachedChannelId = channel.channelId.trim();
      final cachedRoomId = channel.roomId.trim();
      final matches = cachedChannelId == trimmedChannelId ||
          cachedRoomId == trimmedChannelId ||
          cachedRoomId == widget.roomId;
      if (!matches) continue;
      final name = channel.name.trim();
      if (_isReadableChannelTitle(
        name,
        channelId: cachedChannelId,
        roomId: cachedRoomId,
      )) {
        return name;
      }
    }
    if (_isReadableChannelTitle(
      explicitName,
      channelId: trimmedChannelId,
      roomId: widget.roomId,
    )) {
      return explicitName;
    }
    final trimmedFallback = fallback.trim();
    if (_isReadableChannelTitle(
      trimmedFallback,
      channelId: trimmedChannelId,
      roomId: widget.roomId,
    )) {
      return trimmedFallback;
    }
    return _groupChatL10n(context).groupChatChannel;
  }

  bool _isReadableChannelTitle(
    String value, {
    required String channelId,
    required String roomId,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed == channelId.trim()) return false;
    if (trimmed == roomId.trim()) return false;
    if (trimmed == widget.roomId.trim()) return false;
    return !_looksLikeMatrixRoomId(trimmed);
  }

  bool _looksLikeMatrixRoomId(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('!') && trimmed.contains(':');
  }

  AsSyncRoomSummary? _currentChannelSummary(AsSyncCacheState syncCache) {
    final explicitChannelId = widget.channelId?.trim() ?? '';
    final roomId = widget.roomId.trim();
    for (final channel in syncCache.bootstrap?.channels ?? const []) {
      final channelId = channel.channelId.trim();
      final channelRoomId = channel.roomId.trim();
      final matchesExplicit = explicitChannelId.isNotEmpty &&
          (channelId == explicitChannelId ||
              channelRoomId == explicitChannelId);
      final matchesRoom = roomId.isNotEmpty && channelRoomId == roomId;
      if (matchesExplicit || matchesRoom) return channel;
    }
    return null;
  }

  Future<String> _addPendingImageUpload(ChatMediaAttachment attachment) {
    return startMediaOutboxItem(
      notifier: ref.read(localOutboxProvider.notifier),
      conversationId: _room?.id ?? _resolvedRoomId,
      conversationType: LocalOutboxConversationType.group,
      attachment: attachment,
    );
  }

  Future<List<String>> _addPendingImageUploads(
    List<ChatMediaAttachment> attachments,
  ) {
    return startImageOutboxItems(
      notifier: ref.read(localOutboxProvider.notifier),
      conversationId: _room?.id ?? _resolvedRoomId,
      conversationType: LocalOutboxConversationType.group,
      attachments: attachments,
    );
  }

  Future<String> _addPendingFileUpload(ChatMediaAttachment attachment) {
    return startMediaOutboxItem(
      notifier: ref.read(localOutboxProvider.notifier),
      conversationId: _room?.id ?? _resolvedRoomId,
      conversationType: LocalOutboxConversationType.group,
      attachment: attachment,
    );
  }

  Future<String> _addPendingVideoUpload(ChatMediaAttachment attachment) {
    return startMediaOutboxItem(
      notifier: ref.read(localOutboxProvider.notifier),
      conversationId: _room?.id ?? _resolvedRoomId,
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
    final capabilityPolicy = _groupCapabilityPolicy(
      ref.read(productConversationsProvider).valueOrNull ??
          const <AsConversation>[],
      room,
      ref.read(asSyncCacheProvider),
    );
    if (!capabilityPolicy.canSendMedia) {
      _showGroupCannotSendToast(context);
      return;
    }
    final l10n = _groupChatL10n(context);
    final bytes = item.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      final label = switch (item.messageKind) {
        LocalOutboxMessageKind.image => l10n.groupChatImage,
        LocalOutboxMessageKind.video => l10n.groupChatVideo,
        _ => l10n.groupChatFile,
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.groupChatLocalMediaMissing(label)),
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
          matrixClient: ref.read(matrixClientProvider),
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
    final capabilityPolicy = _groupCapabilityPolicy(
      ref.read(productConversationsProvider).valueOrNull ??
          const <AsConversation>[],
      room,
      ref.read(asSyncCacheProvider),
    );
    if (!capabilityPolicy.canSendText) {
      _showGroupCannotSendToast(context);
      return;
    }
    if (item.messageKind != LocalOutboxMessageKind.text) return;
    final text = item.text.trim();
    if (text.isEmpty) return;
    final retried = await ref.read(localOutboxProvider.notifier).retryItem(
          item.id,
        );
    if (!retried || !mounted) return;

    _retryingOutboxIds.add(item.id);
    try {
      await _sendGroupOrChannelText(room, text);
      try {
        await ref.read(matrixClientProvider).oneShotSync();
      } on Object catch (e) {
        debugPrint('post-retry group Matrix sync failed: $e');
      }
      await ref.read(localOutboxProvider.notifier).completeItem(item.id);
    } on Object catch (e) {
      await ref.read(localOutboxProvider.notifier).failItem(item.id);
      if (!mounted) return;
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupChatSendFailed('$e'))),
      );
    } finally {
      _retryingOutboxIds.remove(item.id);
    }
  }

  Future<void> _onLongPressEvent(
    Event event,
    _MessageContextAnchor anchor, {
    required String roomName,
    required _MessageContextMenuPlacement placement,
  }) async {
    final isOwnEvent = event.senderId == event.room.client.userID;
    final supportsTextActions = !isCallRecordEvent(event);
    final canRecall = supportsTextActions && isOwnEvent && event.canRedact;
    _groupChatGestureLog(
      'event longPress handler eventId=${event.eventId} type=${event.type} msgtype=${event.messageType} sender=${event.senderId} me=${event.room.client.userID} isOwn=$isOwnEvent pos=${anchor.position} rect=${anchor.bubbleRect} placement=$placement canRedact=${event.canRedact} canRecall=$canRecall',
    );
    final action = await _showGroupMessageContextMenu(
      context,
      anchor,
      placement: placement,
      canCopy: supportsTextActions,
      canQuote: supportsTextActions,
      canRecall: canRecall,
    );
    _groupChatGestureLog(
      'event context menu result eventId=${event.eventId} action=$action',
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: event.body));
        if (mounted) {
          final l10n = _groupChatL10n(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.groupChatCopied),
              duration: const Duration(seconds: 1),
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
      case 'recall':
        await _recallEvent(event);
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

  Future<void> _onLongPressOutboxItem(
    LocalOutboxItem item,
    _MessageContextAnchor anchor, {
    required _MessageContextMenuPlacement placement,
  }) async {
    _groupChatGestureLog(
      'outbox longPress handler id=${item.id} kind=${item.messageKind} pos=${anchor.position} rect=${anchor.bubbleRect} placement=$placement',
    );
    final action = await _showGroupMessageContextMenu(
      context,
      anchor,
      placement: placement,
      canCopy: true,
      canQuote: false,
      canRecall: false,
    );
    _groupChatGestureLog(
        'outbox context menu result id=${item.id} action=$action');
    if (!mounted || action == null) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(
          ClipboardData(
            text: _groupOutboxCopyText(
              item,
              _groupChatL10n(context),
            ),
          ),
        );
        if (mounted) {
          final l10n = _groupChatL10n(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.groupChatCopied),
              duration: const Duration(seconds: 1),
            ),
          );
        }
        break;
      case 'delete':
        await ref.read(localOutboxProvider.notifier).completeItem(item.id);
        if (mounted) {
          final l10n = _groupChatL10n(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.groupChatDeleted),
              duration: const Duration(seconds: 1),
            ),
          );
        }
        break;
      case 'fav':
        if (mounted) {
          final l10n = _groupChatL10n(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.groupChatCannotFavoriteSending),
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
          final l10n = _groupChatL10n(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.groupChatActionAvailableAfterSent),
              duration: const Duration(seconds: 1),
            ),
          );
        }
        break;
    }
  }

  Future<void> _recallEvent(Event event) async {
    if (!event.canRedact) {
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupChatNoRecallPermission)),
      );
      return;
    }
    final l10n = _groupChatL10n(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final t = dialogContext.tk;
        return AlertDialog(
          title: Text(
            l10n.groupChatRecallTitle,
            style: AppTheme.sans(size: 17, weight: FontWeight.w600),
          ),
          content: Text(
            l10n.groupChatRecallBody,
            style: AppTheme.sans(size: 15, color: t.textMute),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                l10n.groupChatCancel,
                style: AppTheme.sans(size: 15, color: t.textMute),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n.groupChatRecall,
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
      await event.redactEvent(reason: l10n.groupChatRecallTitle);
      try {
        await ref.read(matrixClientProvider).oneShotSync();
      } on Object catch (e) {
        debugPrint('post-redaction group Matrix sync failed: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupChatRecalled)),
      );
    } on Object catch (err) {
      debugPrint('recall group message failed: $err');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupChatRecallFailed('$err'))),
      );
    }
  }

  Future<void> _deleteEventForMe(Event event) async {
    final eventId = event.eventId.trim();
    if (eventId.isEmpty) return;
    try {
      await ref.read(matrixMessageVisibilityClientProvider).hideEvents(
        roomId: widget.roomId,
        eventIds: [eventId],
      );
      await ref.read(chatClearStateStoreProvider.future).then(
          (store) => store.writeDeletedEventIds(widget.roomId, [eventId]));
      if (!mounted) return;
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withDeletedMessage(widget.roomId, eventId),
          );
      unawaited(_refreshBootstrapAfterVisibilityMutation());
      setState(() {
        _locallyHiddenEventIds.add(eventId);
        _selected.remove(eventId);
      });
    } on Object catch (err) {
      debugPrint('delete group message for me failed: $err');
      if (!mounted) return;
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupChatDeleteFailed('$err'))),
      );
    }
  }

  Future<void> _deleteSelectedEventsForMe(List<Event> events) async {
    final eventIds = events
        .where((event) => _selected.contains(event.eventId))
        .map((event) => event.eventId.trim())
        .where((eventId) => eventId.isNotEmpty)
        .toList(growable: false);
    if (eventIds.isEmpty) return;
    try {
      await ref.read(matrixMessageVisibilityClientProvider).hideEvents(
            roomId: widget.roomId,
            eventIds: eventIds,
          );
      await ref
          .read(chatClearStateStoreProvider.future)
          .then((store) => store.writeDeletedEventIds(widget.roomId, eventIds));
      if (!mounted) return;
      ref.read(asSyncCacheProvider.notifier).update((state) {
        var next = state;
        for (final eventId in eventIds) {
          next = next.withDeletedMessage(widget.roomId, eventId);
        }
        return next;
      });
      unawaited(_refreshBootstrapAfterVisibilityMutation());
      setState(() {
        _multiSelect = false;
        _selected.removeWhere(eventIds.contains);
      });
    } on Object catch (err) {
      debugPrint('delete selected group messages for me failed: $err');
      if (!mounted) return;
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupChatDeleteFailed('$err'))),
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
      final l10n = _groupChatL10n(context);
      setState(() => _favoritingEventIds.add(eventId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.groupChatFavoriting),
          duration: const Duration(milliseconds: 900),
        ),
      );
    }
    try {
      final draft = await _favoriteDraftForEvent(event);
      await ref.read(asClientProvider).favoriteMessage(draft);
      if (!mounted) return;
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.groupChatFavorited),
          duration: const Duration(seconds: 1),
        ),
      );
    } on Object catch (err) {
      debugPrint('favorite group message failed: $err');
      if (mounted) {
        final l10n = _groupChatL10n(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.groupChatFavoriteFailed('$err'))),
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
    return favoriteDraftFromMatrixMessage(
      roomId: widget.roomId,
      eventId: event.eventId,
      roomType: 'group',
      senderId: event.senderId,
      senderName: event.senderFromMemoryOrFallback.calcDisplayname(),
      senderAvatarUrl:
          event.senderFromMemoryOrFallback.avatarUrl?.toString() ?? '',
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
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupChatForwardedRecord)),
      );
    } on Object catch (err) {
      if (!mounted) return;
      final l10n = _groupChatL10n(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupChatForwardFailed('$err'))),
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
      final l10n = _groupChatL10n(context);
      final syncCache = ref.watch(asSyncCacheProvider);
      final channel = _currentChannelSummary(syncCache);
      final group = channel == null ? _groupSummary(syncCache) : null;
      final summary = channel ?? group;
      final knownConversation = summary != null;
      final isChannel = _isChannelConversation || channel != null;
      final canRecover = knownConversation || _isChannelConversation;
      final recoveryPending =
          canRecover && !_roomRecovery.failed && !_roomRecovery.attempted;
      final recovering = canRecover &&
          !_roomRecovery.failed &&
          (recoveryPending || _roomRecovery.inFlight);
      final fallbackTitle =
          isChannel ? l10n.groupChatChannel : l10n.groupChatGroup;
      final title = summary?.name.trim().isNotEmpty == true
          ? summary!.name.trim()
          : fallbackTitle;
      if (recoveryPending) _ensureMissingGroupRoomRecovery();
      return Scaffold(
        body: ChatGlassBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ChatCapsuleHeader(
                  title: knownConversation
                      ? title
                      : l10n.groupChatMissingTitle(fallbackTitle),
                  onBack: () => unawaited(_popGroupChatOrHome(context)),
                  actions: const [],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (recovering) ...[
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.accent,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        recovering
                            ? l10n.groupChatRecovering(fallbackTitle)
                            : knownConversation
                                ? l10n.groupChatSyncTimeout(fallbackTitle)
                                : l10n.groupChatCannotOpen(fallbackTitle),
                        style: AppTheme.sans(size: 15, color: t.textMute),
                      ),
                      if (!recovering) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _retryMissingGroupRoomRecovery,
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final t = context.tk;
    final currentUserProfile =
        ref.watch(currentUserProfileProvider).valueOrNull;
    final currentUserId = room.client.userID?.trim();
    final currentUserAvatarSeed =
        currentUserId == null || currentUserId.isEmpty ? 'me' : currentUserId;
    final currentUserAvatarUrl = _currentUserAvatarUrl(
      currentUserProfile,
      room,
    );
    final activeRoomId = room.id;
    final remarkName =
        ref.watch(groupRemarkNamesProvider)[activeRoomId]?.trim() ?? '';
    final syncCache = ref.watch(asSyncCacheProvider);
    final currentChannel = _currentChannelSummary(syncCache);
    final currentGroup =
        currentChannel == null ? _groupSummary(syncCache) : null;
    final productName = (currentChannel?.name.trim().isNotEmpty ?? false)
        ? currentChannel!.name.trim()
        : currentGroup?.name.trim() ?? '';
    final name = remarkName.isNotEmpty
        ? remarkName
        : productName.isNotEmpty
            ? productName
            : safeRoomDisplayName(room);
    final memberCount = room.summary.mJoinedMemberCount ?? 0;
    final explicitChannelId = widget.channelId?.trim() ?? '';
    final resolvedChannelId = explicitChannelId.isNotEmpty
        ? explicitChannelId
        : currentChannel?.channelId.trim().isNotEmpty ?? false
            ? currentChannel!.channelId.trim()
            : currentChannel?.roomId.trim() ?? '';
    final isChannelConversation =
        explicitChannelId.isNotEmpty || currentChannel != null;
    final channelTitle = isChannelConversation
        ? _channelConversationTitle(syncCache, resolvedChannelId, name)
        : name;
    final channelMemberCount = currentChannel?.memberCount ?? 0;
    final headerMemberCount = isChannelConversation && channelMemberCount > 0
        ? channelMemberCount
        : memberCount;
    final rawTimelineEvents = timelineEventsIncludingRoomLastEvent(
      room,
      _timeline,
    );
    final callRecordContextEvents = isChannelConversation
        ? const <Event>[]
        : callRecordContextEventsForTimeline(rawTimelineEvents);
    final timelineEvents = chatDisplayEventsForTimeline(rawTimelineEvents);
    final activeTimelineGroupCall = isChannelConversation
        ? null
        : activeGroupCallEntryForTimeline(rawTimelineEvents);
    final events = syncCache
        .chatVisibilityPolicyForRoom(activeRoomId)
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
    final pendingOutbox = ref
        .watch(localOutboxProvider)
        .itemsForConversation(
          activeRoomId,
          type: LocalOutboxConversationType.group,
        )
        .toList()
        .reversed
        .toList();
    final messageOrder = ref.watch(localMessageOrderProvider);
    final asCallRecords = isChannelConversation
        ? const <AsCallSession>[]
        : asCallSessionsForGroupTimeline(
            sessions: _roomAsCallHistory.values,
            roomId: activeRoomId,
            rawTimelineEvents: rawTimelineEvents,
            visibleEvents: events,
            callRecordContextEvents: callRecordContextEvents,
          );
    final visibleEvents = isChannelConversation
        ? events
        : groupTimelineEventsReplacingAsCallSnapshots(
            visibleEvents: events,
            callRecordContextEvents: callRecordContextEvents,
            asCallSessions: asCallRecords,
          );
    final filteredPendingOutbox =
        filterOutboxItemsShadowedByEvents<Event, LocalOutboxItem>(
      events: visibleEvents,
      outboxItems: pendingOutbox,
      eventSignature: _deliveredTextSignature,
      eventTimestamp: (event) => event.originServerTs,
      outboxSignature: _outboxTextSignature,
      outboxTimestamp: (item) => item.createdAt,
    );
    final timelineItems = _mergeGroupTimelineItems(
      events: visibleEvents,
      eventTimestamp: (event) => event.originServerTs,
      eventSortTimestamp: (event) =>
          messageOrder.entryForEvent(event.eventId)?.createdAt,
      outboxItems: filteredPendingOutbox,
      outboxTimestamp: (item) => item.createdAt,
      asCallSessions: asCallRecords,
    );
    final timelineItemKeys = [
      for (final item in timelineItems) _timelineItemKey(item),
    ];
    final displayTimelineItems = timelineItems.reversed.toList(growable: false);
    final displayTimelineItemKeys = timelineItemKeys.reversed.toList(
      growable: false,
    );
    _syncMessageListIndexes(displayTimelineItems);
    _pruneMessageAnchors();
    _seedInitialTimelineEntrances(timelineItemKeys);
    _scheduleTargetEventScroll();
    final newestTimelineItemKey =
        timelineItemKeys.isEmpty ? null : timelineItemKeys.first;
    _scheduleScrollToLatest(newestTimelineItemKey);
    final productConversations =
        ref.watch(productConversationsProvider).valueOrNull ??
            const <AsConversation>[];
    final capabilityPolicy = _groupCapabilityPolicy(
      productConversations,
      room,
      syncCache,
    );
    final removedFromGroup = _isRemovedFromGroupConversation(
      room: room,
      syncCache: syncCache,
      productConversations: productConversations,
    );
    final canSendMessages = !removedFromGroup && capabilityPolicy.canSendText;
    final canSendMedia = !removedFromGroup && capabilityPolicy.canSendMedia;
    final canQueueChannelTextFailure = !removedFromGroup &&
        !canSendMessages &&
        _isJoinedChannelConversation(room, syncCache);
    final myId = ref.read(matrixClientProvider).userID;
    final replyBarVisible = _replyTo != null && !removedFromGroup;
    final selectionBarVisible = _multiSelect;
    final keyboardInsetBottom = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardInsetBottom > 1) {
      _emojiPanelHeight = keyboardInsetBottom.clamp(240.0, 420.0).toDouble();
    }
    final bottomPanelVisible = !removedFromGroup &&
        keyboardInsetBottom <= 1 &&
        (_showPlusPanel || _showEmojiPanel);
    final showEmojiPanelContent =
        !removedFromGroup && _showEmojiPanel && keyboardInsetBottom <= 1;
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
      horizontal: 16,
      replyBarVisible: replyBarVisible,
      selectionBarVisible: selectionBarVisible,
      bottomPanelVisible: bottomPanelVisible,
      reserveTopOverlay: false,
      reserveBottomOverlay: false,
    ).add(const EdgeInsets.symmetric(vertical: 12));
    final voiceCallController = ref.watch(voiceCallControllerProvider);
    final l10n = _groupChatL10n(context);

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
              : StreamBuilder<GroupCallUiState>(
                  stream: voiceCallController.groupStateStream,
                  initialData: voiceCallController.currentGroupState,
                  builder: (context, snapshot) {
                    final activeGroupCall = _activeGroupCallForHeader(
                      controllerState: snapshot.data ?? GroupCallUiState.idle,
                      timelineEntry: activeTimelineGroupCall,
                      roomId: activeRoomId,
                    );
                    return ChatCapsuleHeader(
                      title: channelTitle,
                      subtitle: activeGroupCall == null
                          ? l10n.groupChatMemberCount(headerMemberCount)
                          : l10n.groupChatCalling,
                      onTitleTap: activeGroupCall == null
                          ? null
                          : () => context.push(
                                groupCallJoinRoute(
                                  roomId: activeRoomId,
                                  roomName: name,
                                  callType: activeGroupCall.callType,
                                  callId: activeGroupCall.callId,
                                  incoming: activeGroupCall.requiresJoin,
                                ),
                              ),
                      onBack: () => unawaited(_popGroupChatOrHome(context)),
                      showEncryptionIcon: true,
                      actions: [
                        ChatCapsuleAction(
                          icon: Symbols.more_vert,
                          tooltip: l10n.groupChatDetails,
                          color: t.accent,
                          onTap: () => context.push(_infoRoute),
                        ),
                      ],
                    );
                  },
                ),
          messageLayer: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _closePanels(),
            child: timelineItems.isEmpty
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
                              child: Center(
                                child: Text(
                                  l10n.groupChatEmpty,
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
                    itemCount: timelineItems.length,
                    newestItemKey: newestTimelineItemKey,
                    child: RefreshIndicator(
                      color: t.accent,
                      onRefresh: _requestOlderMessages,
                      child: ListView.builder(
                        controller: _messageScrollCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: messagePadding,
                        itemCount: timelineItems.length,
                        itemBuilder: (context, i) {
                          final itemKey = displayTimelineItemKeys[i];
                          final contextMenuPlacement =
                              _messageContextMenuPlacement(
                            i,
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
                              key: ValueKey('group_message_enter_$id'),
                              isMe: isMe,
                              index: i,
                              enabled:
                                  _initialTimelineEntrances.contains(itemKey),
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

                          return displayTimelineItems[i].when(
                            outbox: (pending) {
                              if (pending.messageKind ==
                                  LocalOutboxMessageKind.text) {
                                return enter(
                                  _GroupPendingTextBubble(
                                    text: pending.text,
                                    time: DateFormat('HH:mm').format(
                                      pending.createdAt.toLocal(),
                                    ),
                                    status: pending.status,
                                    avatarSeed: currentUserAvatarSeed,
                                    avatarUrl: currentUserAvatarUrl,
                                    onRetry: () => unawaited(
                                      _retryFailedTextMessage(pending),
                                    ),
                                    onLongPressAt: (position) =>
                                        _onLongPressOutboxItem(
                                      pending,
                                      position,
                                      placement: contextMenuPlacement,
                                    ),
                                  ),
                                  isMe: true,
                                  id: pending.id,
                                );
                              }
                              final playback = _voicePlayer.playback.value;
                              final isPlaying =
                                  playback.messageId == pending.id &&
                                      playback.playing;
                              return enter(
                                _isGroupVoiceOutboxItem(pending)
                                    ? _GroupVoiceMessageBubble(
                                        isMe: true,
                                        time: DateFormat('HH:mm').format(
                                          pending.createdAt.toLocal(),
                                        ),
                                        durationSeconds:
                                            _groupVoiceDurationSecondsFromMs(
                                          pending.durationMs,
                                        ),
                                        selected: false,
                                        multiSelect: false,
                                        isPlaying: isPlaying,
                                        currentPlaySeconds:
                                            playback.position.inSeconds,
                                        senderAvatarUrl: currentUserAvatarUrl,
                                        onLongPressAt: (position) =>
                                            _onLongPressOutboxItem(
                                          pending,
                                          position,
                                          placement: contextMenuPlacement,
                                        ),
                                      )
                                    : _GroupPendingMediaBubble(
                                        item: pending,
                                        avatarSeed: currentUserAvatarSeed,
                                        avatarUrl: currentUserAvatarUrl,
                                        onRetry: () => unawaited(
                                          _retryFailedMediaUpload(pending),
                                        ),
                                        onLongPressAt: (position) =>
                                            _onLongPressOutboxItem(
                                          pending,
                                          position,
                                          placement: contextMenuPlacement,
                                        ),
                                      ),
                                isMe: true,
                                id: pending.id,
                              );
                            },
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
                                currentUserProfile,
                              );
                              return enter(
                                _GroupAsCallRecordMessageBubble(
                                  isMe: callerIsMe,
                                  senderId: callerId,
                                  senderName: senderName,
                                  senderAvatarUrl: senderAvatarUrl,
                                  onAvatarTap: isChannelConversation
                                      ? null
                                      : _memberAvatarTap(callerId),
                                  onAvatarLongPress: _memberAvatarMention(
                                    callerId,
                                    senderName,
                                  ),
                                  isVideo: asCallSessionRecordIsVideo(session),
                                  text: asCallSessionRecordText(
                                    session,
                                    l10n: l10n,
                                  ),
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
                              final channelShareJoinId =
                                  channelSharePayload == null
                                      ? ''
                                      : channelShareJoinKey(
                                          channelSharePayload,
                                        );
                              final redPacketPayload =
                                  redPacketPayloadFromContent(
                                Map<String, Object?>.from(e.content),
                                body: e.body,
                              );
                              final isMe = e.senderId == myId;
                              final anchorKey = _messageAnchorKey(e.eventId);
                              final flashing =
                                  _flashingMessageEventId == e.eventId.trim();
                              final senderAvatarUrl = _avatarUrlForMxid(
                                room,
                                syncCache,
                                e.senderId,
                                currentUserProfile,
                              );
                              final senderAvatarTap = isChannelConversation
                                  ? null
                                  : _memberAvatarTap(e.senderId);
                              final senderAvatarLongPress =
                                  _memberAvatarMention(
                                e.senderId,
                                e.senderFromMemoryOrFallback.calcDisplayname(),
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
                                      asCallSessionPending: pendingAsGroupCall,
                                      l10n: l10n,
                                    ),
                                    senderName: callerName,
                                    senderAvatarUrl: _avatarUrlForMxid(
                                      room,
                                      syncCache,
                                      callerId,
                                      currentUserProfile,
                                    ),
                                    onAvatarTap: isChannelConversation
                                        ? null
                                        : _memberAvatarTap(callerId),
                                    onAvatarLongPress: _memberAvatarMention(
                                      callerId,
                                      callerName,
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
                                      placement: contextMenuPlacement,
                                    ),
                                  ),
                                  isMe: callerIsMe,
                                  id: e.eventId,
                                  anchorKey: anchorKey,
                                  flashing: flashing,
                                );
                              }
                              if (e.messageType == MessageTypes.Image &&
                                  e.hasAttachment) {
                                final senderName = e.senderFromMemoryOrFallback
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
                                    onAvatarTap: senderAvatarTap,
                                    onAvatarLongPress: senderAvatarLongPress,
                                    selected: selected,
                                    multiSelect: _multiSelect,
                                    mediaSize: chatMediaBubbleSizeForEvent(e),
                                    onTap: _multiSelect
                                        ? toggle
                                        : () => unawaited(
                                              _openImageEvent(
                                                e,
                                                '${isMe ? l10n.groupChatMe : senderName} · $time',
                                              ),
                                            ),
                                    onLongPressAt: (position) =>
                                        _onLongPressEvent(
                                      e,
                                      position,
                                      roomName: name,
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
                                return enter(
                                  _GroupImageMessageBubble(
                                    event: e,
                                    isMe: isMe,
                                    senderAvatarUrl: senderAvatarUrl,
                                    onAvatarTap: senderAvatarTap,
                                    onAvatarLongPress: senderAvatarLongPress,
                                    selected: selected,
                                    multiSelect: _multiSelect,
                                    fallbackIcon: Symbols.movie,
                                    fit: BoxFit.cover,
                                    mediaSize: chatMessageDefaultMediaSize,
                                    centerOverlay:
                                        const _GroupVideoPlayOverlay(),
                                    onTap: _multiSelect
                                        ? toggle
                                        : () => unawaited(_openVideoEvent(e)),
                                    onLongPressAt: (position) =>
                                        _onLongPressEvent(
                                      e,
                                      position,
                                      roomName: name,
                                      placement: contextMenuPlacement,
                                    ),
                                  ),
                                  isMe: isMe,
                                  id: e.eventId,
                                  anchorKey: anchorKey,
                                  flashing: flashing,
                                );
                              }
                              if (_isGroupVoiceEvent(e)) {
                                final playback = _voicePlayer.playback.value;
                                final eventId = e.eventId.trim();
                                final isPlaying =
                                    playback.messageId == eventId &&
                                        playback.playing;
                                final localOrder =
                                    messageOrder.entryForEvent(e.eventId);
                                final time = DateFormat('HH:mm').format(
                                  (localOrder?.createdAt ?? e.originServerTs)
                                      .toLocal(),
                                );
                                return enter(
                                  _GroupVoiceMessageBubble(
                                    event: e,
                                    isMe: isMe,
                                    senderAvatarUrl: senderAvatarUrl,
                                    onAvatarTap: senderAvatarTap,
                                    onAvatarLongPress: senderAvatarLongPress,
                                    time: time,
                                    durationSeconds:
                                        _groupVoiceDurationSecondsForEvent(e),
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
                                        : () => unawaited(_openFileEvent(e)),
                                    onLongPressAt: (position) =>
                                        _onLongPressEvent(
                                      e,
                                      position,
                                      roomName: name,
                                      placement: contextMenuPlacement,
                                    ),
                                  ),
                                  isMe: isMe,
                                  id: e.eventId,
                                  anchorKey: anchorKey,
                                  flashing: flashing,
                                );
                              }
                              if (e.messageType == MessageTypes.File &&
                                  !_isGroupVoiceEvent(e) &&
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
                                    onAvatarTap: senderAvatarTap,
                                    onAvatarLongPress: senderAvatarLongPress,
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
                                _GroupMessageBubble(
                                  event: e,
                                  redPacketPayload: redPacketPayload,
                                  quote: _replyPreviewForEvent(
                                    e,
                                    visibleEvents,
                                  ),
                                  onTapQuote: _scrollToQuotedEvent,
                                  isMe: isMe,
                                  senderAvatarUrl: senderAvatarUrl,
                                  onAvatarTap: senderAvatarTap,
                                  onAvatarLongPress: senderAvatarLongPress,
                                  channelShareJoining: _joiningChannelShareIds
                                      .contains(channelShareJoinId),
                                  channelShareAlreadyJoined:
                                      channelSharePayload != null &&
                                          (channelShareIsJoined(
                                                ref.read(asSyncCacheProvider),
                                                channelSharePayload,
                                              ) ||
                                              isMe),
                                  channelShareAlreadyRequested:
                                      _requestedChannelShareIds
                                          .contains(channelShareJoinId),
                                  onJoinChannelShare:
                                      channelSharePayload == null
                                          ? null
                                          : () => unawaited(
                                                _joinChannelShare(
                                                  channelSharePayload,
                                                ),
                                              ),
                                  selected: selected,
                                  multiSelect: _multiSelect,
                                  onTap: _multiSelect
                                      ? toggle
                                      : redPacketPayload != null
                                          ? () => _openRedPacketDetail(
                                                redPacketPayload,
                                              )
                                          : channelSharePayload != null
                                              ? () => context.push(
                                                    channelShareOpenRoute(
                                                      ref.read(
                                                        asSyncCacheProvider,
                                                      ),
                                                      channelSharePayload,
                                                      productConversations: ref
                                                              .read(
                                                                productConversationsProvider,
                                                              )
                                                              .valueOrNull ??
                                                          const [],
                                                    ),
                                                    extra: channelSharePayload,
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
              if (_replyTo != null && !removedFromGroup)
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
                  onDelete: () => unawaited(_deleteSelectedEventsForMe(events)),
                )
              else if (removedFromGroup)
                const _GroupRemovedComposerBar()
              else
                ChatCapsuleInputBar(
                  ctrl: _msgCtrl,
                  onSend: _send,
                  onPlus: canSendMedia
                      ? _togglePlus
                      : () => _showGroupCannotSendToast(context),
                  onEmoji: canSendMessages
                      ? _toggleEmoji
                      : () => _showGroupCannotSendToast(context),
                  plusActive: _showPlusPanel,
                  emojiActive: _showEmojiPanel,
                  enabled: canSendMessages,
                  textEnabled: canSendMessages || canQueueChannelTextFailure,
                  sendEnabled: canSendMessages || canQueueChannelTextFailure,
                  onVoiceRecordStart: _startVoiceRecording,
                  onVoiceRecordStop: _stopVoiceRecording,
                  onVoiceRecordCancel: _cancelVoiceRecording,
                ),
              if (_showPlusPanel && !removedFromGroup)
                ChatAttachmentPanel(
                  room: room,
                  roomId: activeRoomId,
                  canSend: canSendMedia,
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
                  onVoiceCall: null,
                  onVideoCall: null,
                  visibleActions: const {
                    ChatAttachmentAction.album,
                    ChatAttachmentAction.camera,
                    ChatAttachmentAction.video,
                    ChatAttachmentAction.file,
                  },
                ),
              if (showEmojiPanelContent)
                ChatEmojiPanel(
                  height: _emojiPanelHeight,
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

class _GroupImageMessageBubble extends StatelessWidget {
  const _GroupImageMessageBubble({
    required this.event,
    required this.isMe,
    required this.onLongPressAt,
    required this.selected,
    required this.multiSelect,
    this.senderAvatarUrl,
    this.fallbackIcon = Symbols.broken_image,
    this.fit = BoxFit.contain,
    this.mediaSize = chatMessageDefaultImageMediaSize,
    this.centerOverlay,
    this.onAvatarTap,
    this.onAvatarLongPress,
    this.onTap,
  });

  final Event event;
  final bool isMe;
  final _MessageContextAnchorCallback onLongPressAt;
  final bool selected;
  final bool multiSelect;
  final String? senderAvatarUrl;
  final IconData fallbackIcon;
  final BoxFit fit;
  final ChatMediaBubbleSize mediaSize;
  final Widget? centerOverlay;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarLongPress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final imageKey = GlobalKey();
    var pressPosition = Offset.zero;
    final image = GestureDetector(
      key: imageKey,
      onTap: () {
        _groupChatGestureLog(
          'image bubble tap fire eventId=${event.eventId} isMe=$isMe hasTap=${onTap != null}',
        );
        onTap?.call();
      },
      onTapDown: (details) {
        pressPosition = details.globalPosition;
        _groupChatGestureLog(
          'image bubble tapDown eventId=${event.eventId} isMe=$isMe selected=$selected multi=$multiSelect pos=$pressPosition hasTap=${onTap != null}',
        );
      },
      onLongPress: () {
        final anchor = _messageContextAnchorFor(imageKey, pressPosition);
        _groupChatGestureLog(
          'image bubble longPress fire eventId=${event.eventId} isMe=$isMe pos=$pressPosition rect=${anchor.bubbleRect}',
        );
        onLongPressAt(anchor);
      },
      onSecondaryTapDown: (details) {
        pressPosition = details.globalPosition;
        _groupChatGestureLog(
          'image bubble secondaryTapDown eventId=${event.eventId} pos=$pressPosition',
        );
      },
      onSecondaryTap: () {
        final anchor = _messageContextAnchorFor(imageKey, pressPosition);
        _groupChatGestureLog(
          'image bubble secondaryTap fire eventId=${event.eventId} pos=$pressPosition rect=${anchor.bubbleRect}',
        );
        onLongPressAt(anchor);
      },
      child: ChatMediaBubbleFrame(
        width: mediaSize.width,
        height: mediaSize.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _GroupMatrixThumb(
              key: ValueKey(
                'group_matrix_thumb_${event.eventId}_${event.originServerTs.millisecondsSinceEpoch}',
              ),
              event: event,
              fallbackIcon: fallbackIcon,
              fit: fit,
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
              onTap: onAvatarTap,
              onLongPress: onAvatarLongPress,
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
          if (isMe) ...[
            const SizedBox(width: 8),
            _MemberAvatar(
              seed: event.senderId,
              name: senderName,
              imageUrl: senderAvatarUrl,
              onTap: onAvatarTap,
              onLongPress: onAvatarLongPress,
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

List<GroupCallInviteMember> mentionMembersForRoom(
  Room room, {
  required String? currentUserId,
  required bool isChannelConversation,
}) {
  final members = groupCallInviteMembersFromRoom(
    room,
    currentUserId: currentUserId,
  );
  if (!isChannelConversation) return members;
  final agentMxid = portalAgentMxidForClient(room.client);
  if (agentMxid == null || agentMxid.isEmpty) return members;
  return members
      .where((member) => member.userId.trim() != agentMxid)
      .toList(growable: false);
}

class _GroupMentionMemberSheet extends StatefulWidget {
  const _GroupMentionMemberSheet({required this.members});

  final List<GroupCallInviteMember> members;

  @override
  State<_GroupMentionMemberSheet> createState() =>
      _GroupMentionMemberSheetState();
}

class _GroupMentionMemberSheetState extends State<_GroupMentionMemberSheet> {
  final _searchCtrl = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = _groupChatL10n(context);
    final keyword = _keyword.trim().toLowerCase();
    final members = keyword.isEmpty
        ? widget.members
        : widget.members
            .where((member) =>
                member.displayName.toLowerCase().contains(keyword) ||
                member.userId.toLowerCase().contains(keyword))
            .toList(growable: false);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.surface.withValues(alpha: 0.94),
                border: Border.all(color: t.border.withValues(alpha: 0.7)),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.68,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                      child: Row(
                        children: [
                          Text(
                            l10n.groupChatMentionTitle,
                            style: AppTheme.sans(
                              size: 17,
                              weight: FontWeight.w700,
                              color: t.text,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: l10n.groupChatClose,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Symbols.close, color: t.textMute),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: TextField(
                        key: const ValueKey('group_mention_search_field'),
                        controller: _searchCtrl,
                        onChanged: (value) => setState(() => _keyword = value),
                        style: AppTheme.sans(size: 15, color: t.text),
                        decoration: InputDecoration(
                          hintText: l10n.groupChatMentionSearchHint,
                          prefixIcon: Icon(Symbols.search, color: t.textMute),
                          isDense: true,
                          filled: true,
                          fillColor: t.surfaceHigh.withValues(alpha: 0.72),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: members.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Text(
                                  widget.members.isEmpty
                                      ? l10n.groupChatNoMentionMembers
                                      : l10n.groupChatNoMembersFound,
                                  style: AppTheme.sans(
                                    size: 15,
                                    color: t.textMute,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.only(bottom: 10),
                              itemCount: members.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                indent: 72,
                                color: t.border.withValues(alpha: 0.58),
                              ),
                              itemBuilder: (context, index) {
                                final member = members[index];
                                return Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    key: ValueKey(
                                      'group_mention_member_${member.userId}',
                                    ),
                                    leading: PortalAvatar(
                                      seed: member.userId,
                                      imageUrl: member.avatarUrl,
                                      size: 42,
                                    ),
                                    title: Text(
                                      member.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.sans(
                                        size: 16,
                                        weight: FontWeight.w600,
                                        color: t.text,
                                      ),
                                    ),
                                    subtitle: Text(
                                      member.userId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.sans(
                                        size: 12,
                                        color: t.textMute,
                                      ),
                                    ),
                                    onTap: () =>
                                        Navigator.of(context).pop(member),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupMatrixThumb extends ConsumerWidget {
  const _GroupMatrixThumb({
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
        final file = await downloadChatEventThumbnail(event);
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
      fit: fit,
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
    this.onAvatarTap,
    this.onAvatarLongPress,
    this.onTap,
  });

  final Event event;
  final bool isMe;
  final String time;
  final String fileName;
  final String sizeLabel;
  final Widget trailing;
  final _MessageContextAnchorCallback onLongPressAt;
  final bool selected;
  final bool multiSelect;
  final String? senderAvatarUrl;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarLongPress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final cardColor = _groupBubbleColor(t, isMe: isMe, selected: selected);
    final card = _GroupFileCardSurface(
      isMe: isMe,
      color: cardColor,
      borderRadius: chatDirectionalBubbleRadius(isMe),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
              onTap: onAvatarTap,
              onLongPress: onAvatarLongPress,
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
          if (isMe) ...[
            const SizedBox(width: 8),
            _MemberAvatar(
              seed: event.senderId,
              name: senderName,
              imageUrl: senderAvatarUrl,
              onTap: onAvatarTap,
              onLongPress: onAvatarLongPress,
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

class _GroupVoiceMessageBubble extends StatelessWidget {
  const _GroupVoiceMessageBubble({
    required this.isMe,
    required this.time,
    required this.durationSeconds,
    required this.selected,
    required this.multiSelect,
    this.isPlaying = false,
    this.currentPlaySeconds = 0,
    this.onSeek,
    this.event,
    this.senderAvatarUrl,
    this.onAvatarTap,
    this.onAvatarLongPress,
    this.onLongPressAt,
    this.onTap,
  });

  final Event? event;
  final bool isMe;
  final String time;
  final int durationSeconds;
  final bool selected;
  final bool multiSelect;
  final bool isPlaying;
  final int currentPlaySeconds;
  final ValueChanged<int>? onSeek;
  final String? senderAvatarUrl;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarLongPress;
  final _MessageContextAnchorCallback? onLongPressAt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final senderName =
        event?.senderFromMemoryOrFallback.calcDisplayname() ?? '';
    final senderId = event?.senderId ?? 'me';
    final cardColor = _groupBubbleColor(t, isMe: isMe, selected: selected);
    Offset pos = Offset.zero;
    final bubbleKey = GlobalKey();
    final bubble = GestureDetector(
      key: bubbleKey,
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        pos = d.globalPosition;
        _groupChatGestureLog(
          'voice bubble tapDown eventId=${event?.eventId} isMe=$isMe selected=$selected multi=$multiSelect pos=$pos hasTap=${onTap != null} hasLong=${onLongPressAt != null}',
        );
      },
      onTap: () {
        _groupChatGestureLog(
          'voice bubble tap fire eventId=${event?.eventId} isMe=$isMe hasTap=${onTap != null}',
        );
        onTap?.call();
      },
      onLongPress: () {
        final anchor = _messageContextAnchorFor(bubbleKey, pos);
        _groupChatGestureLog(
          'voice bubble longPress fire eventId=${event?.eventId} isMe=$isMe pos=$pos rect=${anchor.bubbleRect} hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(anchor);
      },
      onSecondaryTapDown: (d) {
        pos = d.globalPosition;
        _groupChatGestureLog(
          'voice bubble secondaryTapDown eventId=${event?.eventId} pos=$pos hasLong=${onLongPressAt != null}',
        );
      },
      onSecondaryTap: () {
        final anchor = _messageContextAnchorFor(bubbleKey, pos);
        _groupChatGestureLog(
          'voice bubble secondaryTap fire eventId=${event?.eventId} pos=$pos rect=${anchor.bubbleRect} hasLong=${onLongPressAt != null}',
        );
        onLongPressAt?.call(anchor);
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 116, maxWidth: 220),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: chatDirectionalBubbleRadius(isMe),
          border: _groupPeerBubbleBorder(t, isMe: isMe),
          boxShadow: [
            BoxShadow(
              color: _groupBubbleShadowColor(t),
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
    );

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (multiSelect) ...[
            _GroupMessageSelectCheckmark(selected: selected, onTap: onTap),
            const SizedBox(width: 8),
          ],
          if (!isMe) ...[
            _MemberAvatar(
              seed: senderId,
              name: senderName,
              imageUrl: senderAvatarUrl,
              onTap: onAvatarTap,
              onLongPress: onAvatarLongPress,
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
                      time,
                      style: AppTheme.sans(size: 11, color: t.textMute),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            _MemberAvatar(
              seed: senderId,
              name: senderName,
              imageUrl: senderAvatarUrl,
              onTap: onAvatarTap,
              onLongPress: onAvatarLongPress,
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
  final _MessageContextAnchorCallback? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Offset pressPosition = Offset.zero;
    final cardKey = GlobalKey();
    return GestureDetector(
      key: cardKey,
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        pressPosition = details.globalPosition;
        _groupChatGestureLog(
          'file bubble tapDown isMe=$isMe selected=$selected pos=$pressPosition hasTap=${onTap != null} hasLong=${onLongPressAt != null}',
        );
      },
      onTap: () {
        _groupChatGestureLog('file bubble tap fire hasTap=${onTap != null}');
        onTap?.call();
      },
      onLongPress: onLongPressAt == null
          ? null
          : () {
              final anchor = _messageContextAnchorFor(cardKey, pressPosition);
              _groupChatGestureLog(
                'file bubble longPress fire pos=$pressPosition rect=${anchor.bubbleRect}',
              );
              onLongPressAt!(anchor);
            },
      onSecondaryTapDown: (details) {
        pressPosition = details.globalPosition;
        _groupChatGestureLog(
          'file bubble secondaryTapDown pos=$pressPosition hasLong=${onLongPressAt != null}',
        );
      },
      onSecondaryTap: onLongPressAt == null
          ? null
          : () {
              final anchor = _messageContextAnchorFor(cardKey, pressPosition);
              _groupChatGestureLog(
                'file bubble secondaryTap fire pos=$pressPosition rect=${anchor.bubbleRect}',
              );
              onLongPressAt!(anchor);
            },
      child: ChatBubbleFrame(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
            border: _groupPeerBubbleBorder(t, isMe: isMe),
            boxShadow: [
              BoxShadow(
                color: _groupBubbleShadowColor(t),
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
                  Symbols.description,
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
    final l10n = _groupChatL10n(context);
    return Semantics(
      button: true,
      label: selected
          ? l10n.groupChatCancelSelectMessage
          : l10n.groupChatSelectMessage,
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

class _GroupQuotedMessagePreview {
  const _GroupQuotedMessagePreview({
    this.eventId,
    required this.sender,
    required this.text,
  });

  final String? eventId;
  final String sender;
  final String text;

  _GroupQuotedMessagePreview withEventId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || eventId == trimmed) return this;
    return _GroupQuotedMessagePreview(
      eventId: trimmed,
      sender: sender,
      text: text,
    );
  }
}

String _groupMessageDisplayText(Event event) {
  final plain = event.plaintextBody.trim();
  if (plain.isNotEmpty && plain != event.body.trim()) return plain;
  return _stripGroupMatrixReplyFallback(event.body).trim();
}

bool _isGroupVoiceOutboxItem(LocalOutboxItem item) {
  return item.messageKind == LocalOutboxMessageKind.file &&
      item.mimeType.toLowerCase().startsWith('audio/');
}

String _groupOutboxCopyText(
  LocalOutboxItem item,
  AppLocalizations l10n,
) {
  final text = item.text.trim();
  if (text.isNotEmpty) return text;
  final filename = item.filename.trim();
  if (filename.isNotEmpty) return filename;
  return switch (item.messageKind) {
    LocalOutboxMessageKind.image => l10n.groupChatImage,
    LocalOutboxMessageKind.video => l10n.groupChatVideo,
    LocalOutboxMessageKind.file => l10n.groupChatFile,
    LocalOutboxMessageKind.text => '',
  };
}

bool _isGroupVoiceEvent(Event event) {
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

String _groupFileActionKey(Event event) {
  final eventId = event.eventId.trim();
  if (eventId.isNotEmpty) return eventId;
  final url = event.content.tryGet<String>('url')?.trim() ?? '';
  if (url.isNotEmpty) return url;
  return '${event.room.id}:${event.senderId}:${event.body}:${event.originServerTs.millisecondsSinceEpoch}';
}

int _groupVoiceDurationSecondsForEvent(Event event) {
  final info = event.infoMap;
  final raw = info['duration'] ?? info['duration_ms'];
  final ms = raw is int
      ? raw
      : raw is num
          ? raw.toInt()
          : int.tryParse(raw?.toString() ?? '') ?? 0;
  return _groupVoiceDurationSecondsFromMs(ms);
}

int _groupVoiceDurationSecondsFromMs(int durationMs) {
  if (durationMs <= 0) return 1;
  return (durationMs / 1000).ceil().clamp(1, 60 * 60);
}

String _stripGroupMatrixReplyFallback(String body) {
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
  const _MessageJumpFlash({
    required this.flashing,
    required this.child,
  });

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

class _GroupMessageBubble extends StatelessWidget {
  const _GroupMessageBubble({
    required this.event,
    this.redPacketPayload,
    required this.isMe,
    required this.onLongPressAt,
    required this.selected,
    required this.multiSelect,
    this.quote,
    this.senderAvatarUrl,
    this.onAvatarTap,
    this.onAvatarLongPress,
    this.channelShareJoining = false,
    this.channelShareAlreadyJoined = false,
    this.channelShareAlreadyRequested = false,
    this.onJoinChannelShare,
    this.onTap,
    this.onTapQuote,
  });
  final Event event;
  final RedPacketPayload? redPacketPayload;
  final bool isMe;
  final _MessageContextAnchorCallback onLongPressAt;
  final bool selected;
  final bool multiSelect;
  final _GroupQuotedMessagePreview? quote;
  final String? senderAvatarUrl;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarLongPress;
  final bool channelShareJoining;
  final bool channelShareAlreadyJoined;
  final bool channelShareAlreadyRequested;
  final VoidCallback? onJoinChannelShare;
  final VoidCallback? onTap;
  final ValueChanged<String?>? onTapQuote;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final body = _groupMessageDisplayText(event);
    final chatRecordPayload = chatRecordPayloadFromContent(
      Map<String, Object?>.from(event.content),
    );
    final channelSharePayload = channelSharePayloadFromContent(
      Map<String, Object?>.from(event.content),
    );
    final bubbleColor = _groupBubbleColor(t, isMe: isMe, selected: selected);
    final textBubbleKey = GlobalKey();
    final chatRecordKey = GlobalKey();
    var pressPosition = Offset.zero;

    final bubble = redPacketPayload != null
        ? RedPacketMessageCard(
            payload: redPacketPayload!,
            isMe: isMe,
            selected: selected,
            onTap: onTap,
            onLongPressAt: (position) => onLongPressAt(
              _MessageContextAnchor(position: position),
            ),
          )
        : channelSharePayload != null
            ? ChannelSharePreviewCard(
                payload: channelSharePayload,
                joining: channelShareJoining,
                alreadyJoined: channelShareAlreadyJoined,
                alreadyRequested: channelShareAlreadyRequested,
                onJoin: onJoinChannelShare,
                onTap: onTap,
                onLongPressAt: (position) => onLongPressAt(
                  _MessageContextAnchor(position: position),
                ),
              )
            : chatRecordPayload == null
                ? GestureDetector(
                    key: textBubbleKey,
                    onTap: () {
                      _groupChatGestureLog(
                        'text bubble tap fire eventId=${event.eventId} isMe=$isMe hasTap=${onTap != null}',
                      );
                      onTap?.call();
                    },
                    onTapDown: (details) {
                      pressPosition = details.globalPosition;
                      _groupChatGestureLog(
                        'text bubble tapDown eventId=${event.eventId} isMe=$isMe selected=$selected multi=$multiSelect pos=$pressPosition hasTap=${onTap != null}',
                      );
                    },
                    onLongPress: () {
                      final anchor = _messageContextAnchorFor(
                          textBubbleKey, pressPosition);
                      _groupChatGestureLog(
                        'text bubble longPress fire eventId=${event.eventId} isMe=$isMe pos=$pressPosition rect=${anchor.bubbleRect}',
                      );
                      onLongPressAt(anchor);
                    },
                    onSecondaryTapDown: (details) {
                      pressPosition = details.globalPosition;
                      _groupChatGestureLog(
                        'text bubble secondaryTapDown eventId=${event.eventId} pos=$pressPosition',
                      );
                    },
                    onSecondaryTap: () {
                      final anchor = _messageContextAnchorFor(
                          textBubbleKey, pressPosition);
                      _groupChatGestureLog(
                        'text bubble secondaryTap fire eventId=${event.eventId} pos=$pressPosition rect=${anchor.bubbleRect}',
                      );
                      onLongPressAt(anchor);
                    },
                    child: ChatBubbleFrame(
                      child: Container(
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: chatDirectionalBubbleRadius(isMe),
                          border: _groupPeerBubbleBorder(t, isMe: isMe),
                          boxShadow: [
                            BoxShadow(
                              color: _groupBubbleShadowColor(t),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (quote != null) ...[
                              _GroupQuotedMessageBlock(
                                quote: quote!,
                                isMe: isMe,
                                onTap: multiSelect ? null : onTapQuote,
                              ),
                              const SizedBox(height: 10),
                            ],
                            Text(
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
                          ],
                        ),
                      ),
                    ),
                  )
                : ChatRecordPreviewCard(
                    key: chatRecordKey,
                    payload: chatRecordPayload,
                    onTap: onTap,
                    onLongPressAt: (position) => onLongPressAt(
                      _messageContextAnchorFor(chatRecordKey, position),
                    ),
                  );

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              onTap: onAvatarTap,
              onLongPress: onAvatarLongPress,
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
          if (isMe) ...[
            const SizedBox(width: 8),
            _MemberAvatar(
              seed: event.senderId,
              name: senderName,
              imageUrl: senderAvatarUrl,
              onTap: onAvatarTap,
              onLongPress: onAvatarLongPress,
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

class _GroupPendingTextBubble extends StatelessWidget {
  const _GroupPendingTextBubble({
    required this.text,
    required this.time,
    required this.status,
    required this.avatarSeed,
    this.avatarUrl,
    required this.onRetry,
    required this.onLongPressAt,
  });

  final String text;
  final String time;
  final LocalOutboxItemStatus status;
  final String avatarSeed;
  final String? avatarUrl;
  final VoidCallback onRetry;
  final _MessageContextAnchorCallback onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final bubbleKey = GlobalKey();
    var pressPosition = Offset.zero;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  GestureDetector(
                    key: bubbleKey,
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      pressPosition = details.globalPosition;
                      _groupChatGestureLog(
                        'pending text tapDown pos=$pressPosition status=$status',
                      );
                    },
                    onLongPress: () {
                      final anchor =
                          _messageContextAnchorFor(bubbleKey, pressPosition);
                      _groupChatGestureLog(
                        'pending text longPress fire pos=$pressPosition rect=${anchor.bubbleRect}',
                      );
                      onLongPressAt(anchor);
                    },
                    onSecondaryTapDown: (details) {
                      pressPosition = details.globalPosition;
                      _groupChatGestureLog(
                        'pending text secondaryTapDown pos=$pressPosition status=$status',
                      );
                    },
                    onSecondaryTap: () {
                      final anchor =
                          _messageContextAnchorFor(bubbleKey, pressPosition);
                      _groupChatGestureLog(
                        'pending text secondaryTap fire pos=$pressPosition rect=${anchor.bubbleRect}',
                      );
                      onLongPressAt(anchor);
                    },
                    child: ChatBubbleFrame(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _groupBubbleColor(t, isMe: true),
                          borderRadius: chatDirectionalBubbleRadius(true),
                          border: _groupPeerBubbleBorder(t, isMe: true),
                          boxShadow: [
                            BoxShadow(
                              color: _groupBubbleShadowColor(t),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Text(
                          text,
                          style: AppTheme.sans(size: 17, color: t.onAccent),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: AppTheme.sans(size: 11, color: t.textMute),
                        ),
                        const SizedBox(width: 4),
                        _GroupInlineOutboxStatusIcon(
                          status: status,
                          onRetry: onRetry,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _MemberAvatar(
            seed: avatarSeed,
            name: '',
            imageUrl: avatarUrl,
          ),
        ],
      ),
    );
  }
}

class _GroupQuotedMessageBlock extends StatelessWidget {
  const _GroupQuotedMessageBlock({
    required this.quote,
    required this.isMe,
    this.onTap,
  });

  final _GroupQuotedMessagePreview quote;
  final bool isMe;
  final ValueChanged<String?>? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = _groupChatL10n(context);
    final senderColor = isMe ? t.onAccent.withValues(alpha: 0.88) : t.accent;
    final bodyColor = isMe ? t.onAccent.withValues(alpha: 0.78) : t.textMute;
    final block = Container(
      key: const ValueKey('group_chat_quote_block'),
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
            quote.text.isEmpty ? l10n.groupChatMessageFallback : quote.text,
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

String? _groupReplyEventIdForEvent(Event event) {
  if (event.relationshipType == RelationshipTypes.reply) {
    final id = event.relationshipEventId?.trim();
    if (id != null && id.isNotEmpty) return id;
  }
  final relationshipEventId = event.relationshipEventId?.trim();
  if (relationshipEventId != null && relationshipEventId.isNotEmpty) {
    return relationshipEventId;
  }
  return _groupReplyEventIdFromContent(event.content);
}

String? _groupReplyEventIdFromContent(Map<String, dynamic> content) {
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

_GroupQuotedMessagePreview _missingGroupQuotedMessagePreview(
  AppLocalizations l10n,
) {
  return _GroupQuotedMessagePreview(
    sender: l10n.groupChatQuotedMessage,
    text: l10n.groupChatOriginalMessageUnavailable,
  );
}

_GroupQuotedMessagePreview? _groupReplyPreviewFromMatrixFallbackBody(
  String body,
  AppLocalizations l10n,
) {
  final parsed = _parseMatrixReplyFallbackBody(body, l10n);
  if (parsed == null) return null;
  return _GroupQuotedMessagePreview(sender: parsed.sender, text: parsed.text);
}

class _ParsedMatrixReplyFallback {
  const _ParsedMatrixReplyFallback({required this.sender, required this.text});

  final String sender;
  final String text;
}

_ParsedMatrixReplyFallback? _parseMatrixReplyFallbackBody(
  String body,
  AppLocalizations l10n,
) {
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

  var sender = l10n.groupChatQuotedMessage;
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

class _GroupCallRecordMessageBubble extends StatelessWidget {
  const _GroupCallRecordMessageBubble({
    required this.event,
    required this.isMe,
    required this.isVideo,
    required this.text,
    required this.senderName,
    this.senderAvatarUrl,
    this.onAvatarTap,
    this.onAvatarLongPress,
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
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarLongPress;
  final String time;
  final _MessageContextAnchorCallback onLongPressAt;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final callRecordKey = GlobalKey();
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              onTap: onAvatarTap,
              onLongPress: onAvatarLongPress,
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
                    key: callRecordKey,
                    isMe: isMe,
                    isVideo: isVideo,
                    text: text,
                    selected: selected,
                    onTap: multiSelect ? onTap : null,
                    onLongPressAt: (position) => onLongPressAt(
                      _messageContextAnchorFor(callRecordKey, position),
                    ),
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
          if (isMe) ...[
            const SizedBox(width: 8),
            _MemberAvatar(
              seed: event.senderId,
              name: senderName,
              imageUrl: senderAvatarUrl,
              onTap: onAvatarTap,
              onLongPress: onAvatarLongPress,
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

class _GroupAsCallRecordMessageBubble extends StatelessWidget {
  const _GroupAsCallRecordMessageBubble({
    required this.isMe,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    this.onAvatarTap,
    this.onAvatarLongPress,
    required this.isVideo,
    required this.text,
    required this.time,
  });

  final bool isMe;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarLongPress;
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
              onTap: onAvatarTap,
              onLongPress: onAvatarLongPress,
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
          if (isMe) ...[
            const SizedBox(width: 8),
            _MemberAvatar(
              seed: senderId,
              name: senderName,
              imageUrl: senderAvatarUrl,
              onTap: onAvatarTap,
              onLongPress: onAvatarLongPress,
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupPendingMediaBubble extends StatelessWidget {
  const _GroupPendingMediaBubble({
    required this.item,
    required this.avatarSeed,
    this.avatarUrl,
    required this.onRetry,
    required this.onLongPressAt,
  });

  final LocalOutboxItem item;
  final String avatarSeed;
  final String? avatarUrl;
  final VoidCallback onRetry;
  final _MessageContextAnchorCallback onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final isFile = item.messageKind == LocalOutboxMessageKind.file;
    final isVideo = item.messageKind == LocalOutboxMessageKind.video;
    final contentKey = GlobalKey();
    var pressPosition = Offset.zero;
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
                  GestureDetector(
                    key: contentKey,
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      pressPosition = details.globalPosition;
                      _groupChatGestureLog(
                        'pending media tapDown id=${item.id} kind=${item.messageKind} pos=$pressPosition',
                      );
                    },
                    onLongPress: () {
                      final anchor =
                          _messageContextAnchorFor(contentKey, pressPosition);
                      _groupChatGestureLog(
                        'pending media longPress fire id=${item.id} kind=${item.messageKind} pos=$pressPosition rect=${anchor.bubbleRect}',
                      );
                      onLongPressAt(anchor);
                    },
                    onSecondaryTapDown: (details) {
                      pressPosition = details.globalPosition;
                      _groupChatGestureLog(
                        'pending media secondaryTapDown id=${item.id} kind=${item.messageKind} pos=$pressPosition',
                      );
                    },
                    onSecondaryTap: () {
                      final anchor =
                          _messageContextAnchorFor(contentKey, pressPosition);
                      _groupChatGestureLog(
                        'pending media secondaryTap fire id=${item.id} kind=${item.messageKind} pos=$pressPosition rect=${anchor.bubbleRect}',
                      );
                      onLongPressAt(anchor);
                    },
                    child: content,
                  ),
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
          const SizedBox(width: 8),
          _MemberAvatar(
            seed: avatarSeed,
            name: '',
            imageUrl: avatarUrl,
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
      width: isVideo
          ? chatMessageDefaultMediaSize.width
          : chatMediaBubbleSizeFor(
              width: item.width,
              height: item.height,
            ).width,
      height: isVideo
          ? chatMessageDefaultMediaSize.height
          : chatMediaBubbleSizeFor(
              width: item.width,
              height: item.height,
            ).height,
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
    final l10n = _groupChatL10n(context);
    if (status == LocalOutboxItemStatus.sending) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
      );
    }
    return Semantics(
      button: true,
      label: l10n.groupChatRetryFile,
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

class _GroupInlineOutboxStatusIcon extends StatelessWidget {
  const _GroupInlineOutboxStatusIcon({
    required this.status,
    required this.onRetry,
  });

  final LocalOutboxItemStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = _groupChatL10n(context);
    if (status == LocalOutboxItemStatus.sending) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: t.textMute),
      );
    }
    return Semantics(
      button: true,
      label: l10n.groupChatRetryMessage,
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
    final l10n = _groupChatL10n(context);
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
            l10n.groupChatDownloading,
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
        l10n.groupChatDownloaded,
        style: AppTheme.sans(
          size: 11,
          color: t.accent,
          weight: FontWeight.w600,
        ),
      );
    }
    return Semantics(
      button: true,
      label: l10n.groupChatDownloadFile,
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
  _MessageContextAnchor anchor, {
  required _MessageContextMenuPlacement placement,
  bool canCopy = true,
  bool canQuote = true,
  bool canRecall = false,
}) async {
  FocusScope.of(context).unfocus();
  FocusManager.instance.primaryFocus?.unfocus();
  await Future<void>.delayed(const Duration(milliseconds: 80));
  if (!context.mounted) return null;
  final size = MediaQuery.of(context).size;
  final position = anchor.position;
  final bubbleRect = anchor.bubbleRect;
  _groupChatGestureLog(
    'show menu request pos=$position rect=$bubbleRect placement=$placement size=$size canCopy=$canCopy canQuote=$canQuote canRecall=$canRecall',
  );
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'group-msg-ctx',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, a1, a2) {
      const horizontalMargin = 16.0;
      final menuW = math.min(343.0, size.width - horizontalMargin * 2);
      const menuH = 168.0;
      const menuVisibleH = 169.0;
      const bubbleGap = 10.0;
      var left = position.dx - menuW / 2;
      final pointerOnTop = placement == _MessageContextMenuPlacement.below;
      final bubbleEdge = pointerOnTop
          ? bubbleRect?.bottom ?? position.dy
          : bubbleRect?.top ?? position.dy;
      var top = pointerOnTop
          ? bubbleEdge + bubbleGap
          : bubbleEdge - menuVisibleH - bubbleGap;
      if (left < horizontalMargin) left = horizontalMargin;
      if (left + menuW > size.width - horizontalMargin) {
        left = size.width - menuW - horizontalMargin;
      }
      top = top.clamp(12.0, math.max(12.0, size.height - menuH - 12));
      final pointerX = (position.dx - left - 10).clamp(18.0, menuW - 38.0);
      _groupChatGestureLog(
        'show menu layout left=$left top=$top width=$menuW pointerX=$pointerX pointerOnTop=$pointerOnTop',
      );
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: menuW,
            height: menuH,
            child: _GroupMsgCtxMenuCard(
              pointerX: pointerX,
              pointerOnTop: pointerOnTop,
              canCopy: canCopy,
              canQuote: canQuote,
              canRecall: canRecall,
            ),
          ),
        ],
      );
    },
    transitionBuilder: (ctx, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

enum _MessageContextMenuPlacement { above, below }

class _MessageContextAnchor {
  const _MessageContextAnchor({
    required this.position,
    this.bubbleRect,
  });

  final Offset position;
  final Rect? bubbleRect;
}

typedef _MessageContextAnchorCallback = void Function(
  _MessageContextAnchor anchor,
);

_MessageContextAnchor _messageContextAnchorFor(
  GlobalKey key,
  Offset position,
) {
  final renderObject = key.currentContext?.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    return _MessageContextAnchor(
      position: position,
      bubbleRect: renderObject.localToGlobal(Offset.zero) & renderObject.size,
    );
  }
  return _MessageContextAnchor(position: position);
}

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

class _GroupMsgCtxMenuCard extends StatelessWidget {
  const _GroupMsgCtxMenuCard({
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
    final l10n = _groupChatL10n(context);
    const dark = Color(0xFF4A4A4A);
    const divider = Color(0x17FFFFFF);
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
                    Positioned(
                      left: 0,
                      top: 12,
                      right: 0,
                      height: 58,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (canCopy)
                            _GroupMsgCtxMenuItem(
                              width: itemW,
                              icon: Symbols.content_copy,
                              label: l10n.groupChatCopy,
                              value: 'copy',
                            ),
                          _GroupMsgCtxMenuItem(
                            width: itemW,
                            icon: Symbols.forward,
                            label: l10n.groupChatForward,
                            value: 'forward',
                          ),
                          _GroupMsgCtxMenuItem(
                            width: itemW,
                            icon: Symbols.bookmark,
                            label: l10n.groupChatFavorite,
                            value: 'fav',
                          ),
                          _GroupMsgCtxMenuItem(
                            width: itemW,
                            icon: Symbols.delete,
                            label: l10n.groupChatDelete,
                            value: 'delete',
                          ),
                          _GroupMsgCtxMenuItem(
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
                        child: _GroupMsgCtxMenuItem(
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
                        child: _GroupMsgCtxMenuItem(
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
                painter: _GroupMsgCtxPointerPainter(
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

class _GroupMsgCtxMenuItem extends StatelessWidget {
  const _GroupMsgCtxMenuItem({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
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
              Icon(icon, size: 24, color: Colors.white, fill: 0),
              const SizedBox(height: 4),
              SizedBox(
                height: 24,
                child: Center(
                  child: Text(
                    label,
                    style: AppTheme.sans(
                      size: 15,
                      weight: FontWeight.w500,
                      color: Colors.white,
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

class _GroupMsgCtxPointerPainter extends CustomPainter {
  const _GroupMsgCtxPointerPainter({
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
  bool shouldRepaint(covariant _GroupMsgCtxPointerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.pointsDown != pointsDown;
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

class _GroupRemovedComposerBar extends StatelessWidget {
  const _GroupRemovedComposerBar();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = _groupChatL10n(context);
    return Container(
      height: 56,
      width: double.infinity,
      color: t.surfaceHover,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.error, size: 16, color: t.textMute, fill: 1),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l10n.groupChatRemovedCannotSend,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(size: 15, color: t.textMute),
            ),
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
    this.onTap,
    this.onLongPress,
  });
  final String seed;
  final String name;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final avatarKey = ValueKey('group_member_avatar_$seed');
    final avatar = PortalAvatar(
      seed: name.isNotEmpty ? name : seed,
      size: 40,
      imageUrl: imageUrl,
      shape: AvatarShape.squircle,
    );
    if (onTap == null && onLongPress == null) {
      return KeyedSubtree(key: avatarKey, child: avatar);
    }
    return GestureDetector(
      key: avatarKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: avatar,
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/core/theme/design_tokens.dart';
import 'package:portal_app/data/as_bootstrap_store.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/data/channel_post_store.dart';
import 'package:portal_app/data/chat_clear_state_store.dart';
import 'package:portal_app/data/conversation_preferences_store.dart';
import 'package:portal_app/data/friend_request_read_store.dart';
import 'package:portal_app/data/conversation_summary_store.dart';
import 'package:portal_app/data/im_public_client.dart';
import 'package:portal_app/data/local_outbox_store.dart';
import 'package:portal_app/data/matrix_message_search_client.dart';
import 'package:portal_app/data/matrix_message_visibility_client.dart';
import 'package:portal_app/data/media_thumbnail_cache.dart';
import 'package:portal_app/presentation/channel/create_channel_sheet.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/call/voice_call_controller.dart';
import 'package:portal_app/presentation/channel/channel_home_tab.dart';
import 'package:portal_app/presentation/channel/channel_inbox_data.dart';
import 'package:portal_app/presentation/pages/add_contact_detail_page.dart';
import 'package:portal_app/presentation/pages/add_contact_page.dart';
import 'package:portal_app/presentation/pages/add_contact_verification_page.dart';
import 'package:portal_app/presentation/pages/about_us_page.dart';
import 'package:portal_app/presentation/pages/channel_page.dart';
import 'package:portal_app/presentation/pages/channel_post_detail_page.dart';
import 'package:portal_app/presentation/pages/channel_search_page.dart';
import 'package:portal_app/presentation/pages/chat_info_page.dart';
import 'package:portal_app/presentation/pages/chat_page.dart';
import 'package:portal_app/presentation/pages/contact_detail_page.dart';
import 'package:portal_app/presentation/pages/contact_channels_page.dart';
import 'package:portal_app/presentation/pages/contact_home_page.dart';
import 'package:portal_app/presentation/pages/follows_list_page.dart';
import 'package:portal_app/presentation/pages/login_page.dart';
import 'package:portal_app/presentation/pages/home_page.dart';
import 'package:portal_app/presentation/pages/group_chat_page.dart';
import 'package:portal_app/presentation/pages/group_detail_page.dart';
import 'package:portal_app/presentation/pages/group_info_page.dart';
import 'package:portal_app/presentation/pages/group_manage_page.dart';
import 'package:portal_app/presentation/pages/groups_list_page.dart';
import 'package:portal_app/presentation/groups/group_member_invite_flow.dart';
import 'package:portal_app/presentation/pages/init_page.dart';
import 'package:portal_app/presentation/pages/me_account_page.dart';
import 'package:portal_app/presentation/pages/me_home_tab.dart';
import 'package:portal_app/presentation/pages/me_menu_page.dart';
import 'package:portal_app/presentation/pages/me_notifications_page.dart';
import 'package:portal_app/presentation/pages/me_qr_page.dart';
import 'package:portal_app/presentation/pages/profile_info_page.dart';
import 'package:portal_app/presentation/pages/requests_page.dart';
import 'package:portal_app/presentation/pages/search_page.dart';
import 'package:portal_app/presentation/pages/settings_page.dart';
import 'package:portal_app/presentation/providers/as_bootstrap_store_provider.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/app_warmup_provider.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/channel_provider.dart';
import 'package:portal_app/presentation/providers/chat_clear_state_provider.dart';
import 'package:portal_app/presentation/providers/conversation_preferences_provider.dart';
import 'package:portal_app/presentation/providers/friend_request_read_provider.dart';
import 'package:portal_app/presentation/providers/conversation_summary_provider.dart';
import 'package:portal_app/presentation/providers/home_hidden_conversations_provider.dart';
import 'package:portal_app/presentation/providers/im_public_client_provider.dart';
import 'package:portal_app/presentation/providers/local_outbox_provider.dart';
import 'package:portal_app/presentation/providers/matrix_message_clients_provider.dart';
import 'package:portal_app/presentation/providers/media_thumbnail_cache_provider.dart';
import 'package:portal_app/presentation/providers/message_sound_provider.dart';
import 'package:portal_app/presentation/providers/profile_provider.dart';
import 'package:portal_app/presentation/providers/product_conversations_provider.dart';
import 'package:portal_app/presentation/providers/voice_call_provider.dart';
import 'package:portal_app/presentation/chat/cached_thumbnail_image.dart';
import 'package:portal_app/presentation/chat/chat_history_backfill_policy.dart';
import 'package:portal_app/presentation/utils/group_creation_flow.dart';
import 'package:portal_app/presentation/utils/direct_contact_status.dart';
import 'package:portal_app/presentation/utils/room_read_state.dart';
import 'package:portal_app/presentation/widgets/group_composite_avatar.dart';
import 'package:portal_app/presentation/widgets/info_rows.dart';
import 'package:portal_app/presentation/widgets/m3/glass_header.dart';
import 'package:portal_app/presentation/widgets/m3/m3_search_field.dart';
import 'package:portal_app/presentation/widgets/portal_avatar.dart';

final _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lGt2qQAAAABJRU5ErkJggg==',
);

void _mockAudioRecorderPlugins(WidgetTester tester) {
  const audioPlayer = MethodChannel('xyz.luan/audioplayers');
  const audioGlobal = MethodChannel('xyz.luan/audioplayers.global');
  const audioEvents = MethodChannel('xyz.luan/audioplayers.global/events');
  const recordMessages = MethodChannel('com.llfbandit.record/messages');
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  final playerEventChannels = <MethodChannel>[];

  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    audioPlayer,
    (call) async {
      if (call.method == 'create') {
        final args = call.arguments;
        final playerId = args is Map ? args['playerId']?.toString() : null;
        if (playerId != null && playerId.isNotEmpty) {
          final events =
              MethodChannel('xyz.luan/audioplayers/events/$playerId');
          playerEventChannels.add(events);
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            events,
            (_) async => null,
          );
        }
      }
      return null;
    },
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    audioGlobal,
    (_) async => null,
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    audioEvents,
    (_) async => null,
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    recordMessages,
    (call) async {
      switch (call.method) {
        case 'hasPermission':
        case 'isEncoderSupported':
          return true;
        case 'isRecording':
        case 'isPaused':
          return false;
        case 'getAmplitude':
          return {'current': 0.0, 'max': 0.0};
        case 'stop':
          return '';
        default:
          return null;
      }
    },
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    pathProvider,
    (_) async => '.',
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      audioPlayer,
      null,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      audioGlobal,
      null,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      audioEvents,
      null,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      recordMessages,
      null,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProvider,
      null,
    );
    for (final channel in playerEventChannels) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    }
  });
}

class _FakeAuthStateNotifier extends AuthStateNotifier {
  @override
  Future<AuthState> build() async => const AuthState(isLoggedIn: false);
}

class _RecordingLogoutAuthStateNotifier extends AuthStateNotifier {
  static int logoutCalls = 0;

  @override
  Future<AuthState> build() async => const AuthState(
        isLoggedIn: true,
        userId: '@owner:p2p-im.com',
        homeserver: 'https://p2p-im.com',
      );

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AsyncData(AuthState(isLoggedIn: false));
  }
}

class _LoggedInAuthStateNotifier extends AuthStateNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        isLoggedIn: true,
        userId: '@owner:p2p-im.com',
        homeserver: 'https://p2p-im.com',
      );
}

class _MemberLoggedInAuthStateNotifier extends AuthStateNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        isLoggedIn: true,
        userId: '@member:p2p-im.com',
        homeserver: 'https://p2p-im.com',
      );
}

class _LoadingAuthStateNotifier extends AuthStateNotifier {
  @override
  Future<AuthState> build() => Completer<AuthState>().future;
}

class _MemoryChatClearStateStore implements ChatClearStateStore {
  int clearedBeforeTs = 0;
  final Map<String, int> roomClearedBeforeTs = {};

  @override
  Future<int> readClearedBeforeTs() async => clearedBeforeTs;

  @override
  Future<Map<String, int>> readRoomClearedBeforeTs() async =>
      Map.unmodifiable(roomClearedBeforeTs);

  @override
  Future<void> writeClearedBeforeTs(int timestamp) async {
    clearedBeforeTs = timestamp;
  }

  @override
  Future<void> writeRoomClearedBeforeTs(String roomId, int timestamp) async {
    roomClearedBeforeTs[roomId] = timestamp;
  }

  @override
  Future<void> clear() async {
    clearedBeforeTs = 0;
    roomClearedBeforeTs.clear();
  }
}

class _EmptyAsClient implements AsClient {
  String? updatedOwnerDisplayName;
  Uri? lastPublicChannelLookupBaseUri;
  String? lastPublicChannelSearchQuery;

  @override
  Future<OwnerProfile> getOwnerProfile() async => const OwnerProfile(
        userId: '@owner:example.com',
        displayName: '测试用户',
        domain: 'example.com',
      );

  @override
  Future<OwnerProfile> updateOwnerProfile({
    required String displayName,
    String avatarUrl = '',
    String gender = '',
    String birthday = '',
    String phone = '',
    String email = '',
  }) async {
    updatedOwnerDisplayName = displayName.trim();
    return OwnerProfile(
      userId: '@owner:p2p-im.com',
      displayName: updatedOwnerDisplayName!,
      domain: 'p2p-im.com',
      avatarUrl: avatarUrl.trim(),
      gender: gender.trim(),
      birthday: birthday.trim(),
      phone: phone.trim(),
      email: email.trim(),
    );
  }

  @override
  Future<AsSyncBootstrap> syncBootstrap() async => AsSyncBootstrap(
        syncedAt: DateTime.now().toUtc(),
        user: const AsSyncUser(userId: '@owner:example.com'),
        rooms: const [],
        contacts: const [],
        groups: const [],
        channels: const [],
        pending: const AsSyncPending.empty(),
      );

  @override
  Future<List<AsConversation>> listConversations() async => const [];

  @override
  Future<AsConversation> getConversation({
    String conversationId = '',
    String roomId = '',
  }) async {
    throw AsClientException('test conversation is not available');
  }

  @override
  Stream<AsEventStreamEvent> streamEvents({
    int? since,
    String? lastEventId,
  }) {
    return Completer<AsEventStreamEvent>().future.asStream();
  }

  @override
  Future<List<AsChannelCommentHistory>> getMyChannelComments({
    int limit = 50,
  }) async =>
      const [];

  @override
  Future<List<AsChannelReactionHistory>> getMyChannelReactions({
    int limit = 50,
  }) async =>
      const [];

  @override
  Future<void> addFollow(String domain) async {}

  @override
  Future<AsPortalSession> changePortalPassword({
    required String oldPassword,
    required String newPassword,
    String? deviceId,
  }) async {
    throw UnsupportedError('Test AS fake does not issue auth tokens');
  }

  @override
  Future<AsCallSession> createCall({
    required String roomId,
    required String mediaType,
    List<String> invitedUserIds = const [],
  }) async =>
      AsCallSession(
        callId: 'test-call',
        roomId: roomId,
        roomType: roomId.contains('group') ? 'group' : 'direct',
        mediaType: mediaType,
        createdByMxid: '@owner:example.com',
        state: asCallStateRinging,
        createdAt: DateTime.now().toUtc(),
        invitedUserIds: invitedUserIds,
      );

  @override
  Future<AsCallSession> getCall(String callId) async => AsCallSession(
        callId: callId,
        roomId: '!room:example.com',
        roomType: 'direct',
        mediaType: asCallMediaTypeVoice,
        createdByMxid: '@owner:example.com',
        state: asCallStateRinging,
        createdAt: DateTime.now().toUtc(),
      );

  @override
  Future<List<AsCallSession>> getActiveCalls() async => const [];

  @override
  Future<List<AsCallSession>> listCalls({
    required String roomId,
    int limit = 50,
  }) async =>
      const [];

  @override
  Future<AsCallSession> registerIncomingCall({
    required String callId,
    required String roomId,
    required String mediaType,
    required String createdByMxid,
    DateTime? createdAt,
    List<String> invitedUserIds = const [],
  }) async =>
      AsCallSession(
        callId: callId,
        roomId: roomId,
        roomType: roomId.contains('group') ? 'group' : 'direct',
        mediaType: mediaType,
        createdByMxid: createdByMxid,
        state: asCallStateRinging,
        createdAt: createdAt ?? DateTime.now().toUtc(),
        invitedUserIds: invitedUserIds,
      );

  @override
  Future<AsCallSession> updateCallEvent({
    required String callId,
    required String event,
    String reason = '',
    int durationMs = 0,
  }) async =>
      AsCallSession(
        callId: callId,
        roomId: '!room:example.com',
        roomType: 'direct',
        mediaType: asCallMediaTypeVoice,
        createdByMxid: '@owner:example.com',
        state: event,
        createdAt: DateTime.now().toUtc(),
        endReason: reason,
        durationMs: durationMs,
      );

  @override
  Future<AsChannel> createChannel({
    required String name,
    String topic = '',
    String description = '',
    String avatarUrl = '',
    String visibility = asChannelVisibilityPublic,
    String joinPolicy = asChannelJoinPolicyOpen,
    String channelType = 'chat',
    bool commentsEnabled = true,
    List<String> tags = const [],
  }) async =>
      AsChannel(
        channelId: 'ch_created',
        roomId: '!created:example.com',
        name: name,
        homeDomain: 'example.com',
        description: description.trim().isEmpty ? topic : description,
        avatarUrl: avatarUrl,
        visibility: visibility,
        joinPolicy: joinPolicy,
        commentsEnabled: commentsEnabled,
        role: asChannelRoleOwner,
        memberStatus: asChannelMemberStatusJoined,
        memberCount: 1,
        tags: tags,
      );

  @override
  Future<List<AsChannel>> listChannels() async => const [];

  @override
  Future<List<AsChannel>> searchPublicChannels(
    String query, {
    Uri? baseUri,
    int limit = 20,
  }) async {
    lastPublicChannelSearchQuery = query;
    return [
      AsChannel(
        channelId: 'ch_search',
        roomId: '!search:example.com',
        name: query,
        homeDomain: 'example.com',
      ),
    ];
  }

  @override
  Future<AsChannel> getPublicChannel(String channelId, {Uri? baseUri}) async =>
      AsChannel(
        channelId: channelId,
        roomId: '!$channelId:example.com',
        name: '频道',
        homeDomain: 'example.com',
      );

  @override
  Future<AsChannel> getPublicChannelByRoomId(
    String roomId, {
    Uri? baseUri,
    Uri? remoteNodeBaseUri,
  }) async {
    lastPublicChannelLookupBaseUri = baseUri;
    return AsChannel(
      channelId: roomId,
      roomId: roomId,
      name: '频道',
      homeDomain: 'example.com',
    );
  }

  @override
  Future<List<AsChannel>> getUserPublicChannels(
    String userId, {
    Uri? baseUri,
    Uri? remoteNodeBaseUri,
  }) async =>
      const [];

  @override
  Future<AsChannel> updateChannel(AsChannel draft) async => draft;

  @override
  Future<AsChannel> joinChannelByRoomId(
    String roomId, {
    String shareToken = '',
    String grantId = '',
    String shareRoomId = '',
    AsChannel? discoveredChannel,
    Uri? remoteNodeBaseUri,
    Uri? requesterNodeBaseUri,
    List<String> serverNames = const [],
  }) async =>
      AsChannel(
        channelId: discoveredChannel?.channelId ?? roomId,
        roomId: roomId,
        name: '频道',
        homeDomain: 'example.com',
        role: asChannelRoleMember,
        memberStatus: asChannelMemberStatusJoined,
      );

  @override
  Future<AsChannel> joinChannel(
    String channelId, {
    String roomId = '',
    String shareToken = '',
    String grantId = '',
    String shareRoomId = '',
    AsChannel? discoveredChannel,
    List<String> serverNames = const [],
  }) async =>
      AsChannel(
        channelId: channelId,
        roomId: '!$channelId:example.com',
        name: '频道',
        homeDomain: 'example.com',
        role: asChannelRoleMember,
        memberStatus: asChannelMemberStatusJoined,
      );

  @override
  Future<List<AsChannelMember>> getChannelMembers(
    String channelId, {
    String status = '',
  }) async =>
      const [];

  @override
  Future<void> inviteChannelMembers({
    required String channelId,
    required List<String> invite,
  }) async {}

  @override
  Future<AsChannelJoinReviewResult> approveChannelJoin(
          String channelId, String userMxid) async =>
      AsChannelJoinReviewResult(
        status: asChannelMemberStatusJoined,
        channel: AsChannel(
          channelId: channelId,
          roomId: '!$channelId:example.com',
          name: '频道',
          homeDomain: 'example.com',
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
        ),
      );

  @override
  Future<AsChannelJoinReviewResult> rejectChannelJoin(
          String channelId, String userMxid) async =>
      AsChannelJoinReviewResult(
        status: asChannelMemberStatusRejected,
        channel: AsChannel(
          channelId: channelId,
          roomId: '!$channelId:example.com',
          name: '频道',
          homeDomain: 'example.com',
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
        ),
      );

  @override
  Future<void> removeChannelMember(String channelId, String userMxid) async {}

  @override
  Future<void> muteChannel(String channelId) async {}

  @override
  Future<void> unmuteChannel(String channelId) async {}

  @override
  Future<void> muteChannelMember(String channelId, String userId) async {}

  @override
  Future<void> unmuteChannelMember(String channelId, String userId) async {}

  @override
  Future<void> leaveChannel(String channelId) async {}

  @override
  Future<void> dissolveChannel(String channelId) async {}

  @override
  Future<List<AsChannelPost>> getChannelPosts(
    String channelId, {
    int limit = 50,
    int beforeTs = 0,
  }) async =>
      const [];

  @override
  Future<AsChannelPost> createChannelPost(
    String channelId, {
    required String messageType,
    required String body,
    Map<String, Object?> media = const {},
  }) async =>
      AsChannelPost(
        postId: 'post',
        channelId: channelId,
        roomId: '!$channelId:example.com',
        eventId: r'$post',
        authorId: '@owner:example.com',
        messageType: messageType,
        body: body,
        media: media,
        originServerTs: 1,
      );

  @override
  Future<void> recallChannelPost(
    String channelId,
    String postId, {
    String reason = 'recall post',
  }) async {}

  @override
  Future<List<AsChannelComment>> getChannelComments(
    String channelId,
    String postId, {
    int page = 1,
    int pageSize = 50,
  }) async =>
      const [];

  @override
  Future<AsChannelComment> createChannelComment(
    String channelId,
    String postId, {
    required String messageType,
    required String body,
    Map<String, Object?> media = const {},
    String replyToCommentId = '',
    String replyToAuthorId = '',
    List<Map<String, Object?>> mentions = const [],
  }) async =>
      AsChannelComment(
        commentId: 'comment',
        postId: postId,
        channelId: channelId,
        eventId: r'$comment',
        authorId: '@owner:example.com',
        messageType: messageType,
        body: body,
        media: media,
        replyToCommentId: replyToCommentId,
        replyToAuthorId: replyToAuthorId,
        mentions: mentions,
        originServerTs: 1,
      );

  @override
  Future<AsChannelReaction> toggleChannelPostReaction(
    String channelId,
    String postId, {
    String reaction = 'like',
  }) async =>
      AsChannelReaction(
        postId: postId,
        channelId: channelId,
        reaction: reaction,
        active: true,
        reactionCount: 1,
      );

  @override
  Future<AsChannelReaction> toggleChannelCommentReaction(
    String channelId,
    String postId,
    String commentId, {
    String reaction = 'like',
  }) async =>
      AsChannelReaction(
        postId: postId,
        channelId: channelId,
        reaction: reaction,
        active: true,
        reactionCount: 1,
      );

  @override
  Future<void> updateChannelReadMarker(
    String channelId, {
    required String eventId,
    required int originServerTs,
  }) async {}

  @override
  Future<AgentConfig> getAgentConfig() async =>
      const AgentConfig(displayName: '小A', contextWindow: 20);

  @override
  Future<AgentStatus> getAgentStatus() async => const AgentStatus(
        connected: false,
        lastSeen: null,
        roomsJoined: 0,
        messagesToday: 0,
      );

  @override
  Future<List<FollowEntry>> getFollows() async => const [];

  @override
  Future<List<AsFavoriteMessage>> getFavorites({
    String messageType = '',
    int limit = 100,
  }) async =>
      const [];

  @override
  Future<AsFavoriteMessage> favoriteMessage(
      AsFavoriteMessageDraft draft) async {
    return AsFavoriteMessage(
      id: 1,
      ownerUserId: '@owner:example.com',
      roomId: draft.roomId,
      eventId: draft.eventId,
      roomType: draft.roomType,
      messageType: draft.messageType,
      senderId: draft.senderId,
      senderName: draft.senderName,
      senderAvatarUrl: draft.senderAvatarUrl,
      body: draft.body,
      url: draft.url,
      filename: draft.filename,
      mimeType: draft.mimeType,
      size: draft.size,
      thumbnailUrl: draft.thumbnailUrl,
      thumbnailMimeType: draft.thumbnailMimeType,
      thumbnailSize: draft.thumbnailSize,
      width: draft.width,
      height: draft.height,
      durationMs: draft.durationMs,
      originServerTs: draft.originServerTs,
      favoritedAt: DateTime.utc(2026, 5, 29),
    );
  }

  @override
  Future<void> deleteFavorite(int id) async {}

  @override
  Future<Map<String, dynamic>> submitReport({
    required String reporterDomain,
    required String reportedDomain,
    required String reason,
    int targetType = 1,
    List<String> images = const [],
  }) async =>
      {
        'id': 'report-1',
        'reporter_domain': reporterDomain,
        'reported_domain': reportedDomain,
        'target_type': targetType,
        'reason': reason,
        'images': images,
      };

  @override
  Future<PortalStatus> getPortalStatus() async => const PortalStatus(
        dendrite: 'connected',
        federation: 'ok',
        agent: 'connected',
        uptime: '',
      );

  @override
  Future<void> removeFollow(String domain) async {}

  @override
  Future<ContactEntry> createContactRequest({
    required String mxid,
    String displayName = '',
    String avatarUrl = '',
    String domain = '',
    String remark = '',
  }) async =>
      ContactEntry(
        peerMxid: mxid,
        displayName: displayName,
        avatarUrl: avatarUrl,
        domain: domain,
        roomId: '!contact:example.com',
        status: 'pending_outbound',
        remark: remark.trim(),
      );

  @override
  Future<List<ContactEntry>> listContacts() async => const [];

  @override
  Future<Map<String, dynamic>> reactivateContact({
    required String roomId,
    required String requesterMxid,
    Uri? remoteNodeBaseUri,
  }) async =>
      {
        'status': 'invited',
        'room_id': roomId.trim(),
        'requester_mxid': requesterMxid.trim(),
        if (remoteNodeBaseUri != null)
          'remote_node_base_url': remoteNodeBaseUri.toString(),
      };

  @override
  Future<ContactEntry> acceptContactRequest({
    required String roomId,
    required String peerMxid,
    String displayName = '',
    String avatarUrl = '',
    String domain = '',
  }) async =>
      ContactEntry(
        peerMxid: peerMxid,
        displayName: displayName,
        avatarUrl: avatarUrl,
        domain: domain,
        roomId: roomId,
        status: 'accepted',
      );

  @override
  Future<ContactEntry> rejectContactRequest({
    required String roomId,
    required String peerMxid,
    String displayName = '',
    String domain = '',
  }) async =>
      ContactEntry(
        peerMxid: peerMxid,
        displayName: displayName,
        domain: domain,
        roomId: roomId,
        status: 'rejected',
      );

  @override
  Future<ContactEntry> deleteContact(String roomId) async => ContactEntry(
        peerMxid: '@contact:example.com',
        displayName: '',
        domain: 'example.com',
        roomId: roomId,
        status: 'rejected',
      );

  @override
  Future<ContactEntry> updateContact({
    required String roomId,
    required String displayName,
    String avatarUrl = '',
    String domain = '',
  }) async =>
      ContactEntry(
        peerMxid: '@contact:example.com',
        displayName: displayName.trim(),
        avatarUrl: avatarUrl.trim(),
        domain: domain.trim(),
        roomId: roomId,
        status: 'accepted',
      );

  @override
  Future<AsGroupResult> createGroup({
    required String name,
    required List<String> invite,
    String avatarUrl = '',
  }) async =>
      AsGroupResult(
        roomId: '!group:example.com',
        name: name,
        memberCount: 1,
        invitedCount: invite.length,
        role: 'owner',
      );

  @override
  Future<AsGroupResult> updateGroupProfile({
    required String roomId,
    String name = '',
    String topic = '',
    String avatarUrl = '',
  }) async =>
      AsGroupResult(
        roomId: roomId,
        name: name.trim().isEmpty ? '群聊' : name.trim(),
        memberCount: 1,
        role: 'owner',
      );

  @override
  Future<AsGroupResult> inviteGroupMembers({
    required String roomId,
    required List<String> invite,
  }) async =>
      AsGroupResult(
        roomId: roomId,
        name: '群聊',
        memberCount: 1,
        invitedCount: invite.length,
      );

  @override
  Future<List<AsGroupMember>> getGroupMembers(
    String roomId, {
    String status = '',
  }) async =>
      const [];

  @override
  Future<void> removeGroupMember({
    required String roomId,
    required String peerMxid,
  }) async {}

  @override
  Future<void> muteGroup(String roomId) async {}

  @override
  Future<void> unmuteGroup(String roomId) async {}

  @override
  Future<void> muteGroupMember({
    required String roomId,
    required String userId,
  }) async {}

  @override
  Future<void> unmuteGroupMember({
    required String roomId,
    required String userId,
  }) async {}

  @override
  Future<AsGroupResult> updateGroupInvitePolicy({
    required String roomId,
    required String invitePolicy,
  }) async =>
      AsGroupResult(
        roomId: roomId,
        name: '群聊',
        memberCount: 1,
        invitePolicy: invitePolicy,
      );

  @override
  Future<AsGroupResult> joinGroup({
    required String roomId,
    String groupName = '',
    String inviterMxid = '',
    String inviteEventId = '',
    String directRoomId = '',
  }) async =>
      AsGroupResult(
        roomId: roomId,
        name: groupName,
        memberCount: 2,
        role: 'member',
      );

  @override
  Future<void> leaveGroup(String roomId) async {}

  @override
  Future<void> dissolveGroup(String roomId) async {}

  @override
  Future<AsChannelInviteGrant> createChannelInviteGrant({
    String channelId = '',
    String roomId = '',
    required String shareRoomId,
    String grantId = '',
    String reason = '',
  }) async =>
      AsChannelInviteGrant(
        grantId: grantId.trim().isEmpty ? 'grant-test' : grantId.trim(),
        roomId: roomId.trim(),
        channelId: channelId.trim(),
        shareRoomId: shareRoomId.trim(),
        status: 'active',
      );

  @override
  Future<void> updateReadMarker(
    String roomId,
    String eventId,
    DateTime timestamp,
  ) async {}

  @override
  Future<AgentConfig> updateAgentConfig(AgentConfig config) async => config;
}

class _WidgetImPublicClient extends ImPublicClient {
  _WidgetImPublicClient()
      : super(
          baseUri: Uri.parse('https://api.example.com'),
          secret: 'test-secret',
        );

  String? lastName;

  @override
  Future<ImPublicChannelPage> listChannels({
    int page = 1,
    int pageSize = 10,
    String name = '',
    String sortBy = 'createdAt',
    bool desc = false,
  }) async {
    lastName = name;
    return ImPublicChannelPage(
      items: [
        ImPublicChannelListing(
          id: 1,
          channelDomain: 'https://example.com',
          roomId: '!search:example.com',
          ownerDomain: 'example.com',
          intro: '频道说明',
          channel: AsChannel(
            channelId: 'ch_search',
            roomId: '!search:example.com',
            name: name,
            homeDomain: 'example.com',
            description: '频道说明',
            visibility: asChannelVisibilityPublic,
          ),
          tagId: 0,
          tag: null,
          status: 1,
          syncStatus: 0,
          failureCount: 0,
          reportCount: 0,
          joinCount: 0,
          lastJoinTime: null,
        ),
      ],
      total: 1,
      page: page,
      pageSize: pageSize,
    );
  }
}

class _MissingPublicChannelAsClient extends _EmptyAsClient {
  @override
  Future<AsChannel> getPublicChannel(String channelId, {Uri? baseUri}) async {
    throw StateError('channel not found');
  }

  @override
  Future<AsChannel> getPublicChannelByRoomId(
    String roomId, {
    Uri? baseUri,
    Uri? remoteNodeBaseUri,
  }) async {
    throw StateError('channel not found');
  }
}

class _PendingChannelReviewAsClient extends _EmptyAsClient {
  _PendingChannelReviewAsClient({
    this.approveStatus = asChannelMemberStatusJoined,
  });

  final String approveStatus;

  @override
  Future<AsSyncBootstrap> syncBootstrap() async => AsSyncBootstrap(
        syncedAt: DateTime.now().toUtc(),
        user: const AsSyncUser(userId: '@owner:p2p-im.com'),
        rooms: const [],
        contacts: const [],
        groups: const [],
        channels: const [],
        pending: const AsSyncPending.empty(),
      );

  @override
  Future<List<AsChannel>> listChannels() async => const [
        AsChannel(
          channelId: 'ch_review',
          roomId: '!review:p2p-im.com',
          name: '频道审核',
          homeDomain: 'p2p-im.com',
          role: asChannelRoleOwner,
          memberStatus: asChannelMemberStatusJoined,
          pendingJoinCount: 1,
        ),
      ];

  @override
  Future<List<AsChannelMember>> getChannelMembers(
    String channelId, {
    String status = '',
  }) async =>
      const [
        AsChannelMember(
          channelId: 'ch_review',
          userMxid: '@pending:p2p-im.com',
          displayName: '',
          avatarUrl: '',
          status: asChannelMemberStatusPending,
          role: asChannelRoleMember,
          joinedAtMs: 1760000000000,
        ),
      ];

  @override
  Future<AsChannelJoinReviewResult> approveChannelJoin(
    String channelId,
    String userMxid,
  ) async {
    return AsChannelJoinReviewResult(
      status: approveStatus,
      channel: const AsChannel(
        channelId: 'ch_review',
        roomId: '!review:p2p-im.com',
        name: '频道审核',
        homeDomain: 'p2p-im.com',
        role: asChannelRoleOwner,
        memberStatus: asChannelMemberStatusJoined,
        pendingJoinCount: 0,
      ),
    );
  }
}

class _ReadMarkerFailingAsClient extends _EmptyAsClient {
  @override
  Future<void> updateReadMarker(
    String roomId,
    String eventId,
    DateTime timestamp,
  ) async {
    throw StateError('keep recovered notice visible for test');
  }
}

class _StaticMatrixMessageSearchClient extends MatrixMessageSearchClient {
  _StaticMatrixMessageSearchClient(this.results)
      : super(Client('StaticMatrixMessageSearchClient'));

  final List<MatrixMessageSearchResult> results;

  @override
  Future<List<MatrixMessageSearchResult>> search(
    String query, {
    String? roomId,
    Iterable<String> roomIds = const [],
    int limit = 20,
  }) async =>
      results;
}

class _RecordingMatrixMessageVisibilityClient
    extends MatrixMessageVisibilityClient {
  _RecordingMatrixMessageVisibilityClient()
      : super(Client('RecordingMatrixMessageVisibilityClient'));

  int clearCalls = 0;
  final hiddenEventIdsByRoom = <String, List<String>>{};

  @override
  Future<MatrixLocalDeleteResult> clearRoom(String roomId) async {
    clearCalls++;
    return MatrixLocalDeleteResult(roomId: roomId.trim(), clear: true);
  }

  @override
  Future<MatrixLocalDeleteResult> hideEvents({
    required String roomId,
    required Iterable<String> eventIds,
  }) async {
    final ids = eventIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    hiddenEventIdsByRoom[roomId.trim()] = [
      ...?hiddenEventIdsByRoom[roomId.trim()],
      ...ids,
    ];
    return MatrixLocalDeleteResult(roomId: roomId.trim(), hiddenEventIds: ids);
  }
}

class _ConversationListAsClient extends _EmptyAsClient {
  _ConversationListAsClient(this.conversations);

  final List<AsConversation> conversations;

  @override
  Future<AsSyncBootstrap> syncBootstrap() async {
    return _bootstrapFromConversations(conversations);
  }
}

class _ConversationListWithPublicChannelsAsClient
    extends _ConversationListAsClient {
  _ConversationListWithPublicChannelsAsClient(
    super.conversations, {
    this.userPublicChannels = const [],
  });

  final List<AsChannel> userPublicChannels;
  String? requestedUserPublicChannelsUserId;

  @override
  Future<List<AsChannel>> getUserPublicChannels(
    String userId, {
    Uri? baseUri,
    Uri? remoteNodeBaseUri,
  }) async {
    requestedUserPublicChannelsUserId = userId;
    return userPublicChannels;
  }
}

class _StatefulPendingContactAsClient extends _EmptyAsClient {
  var _accepted = false;

  @override
  Future<AsSyncBootstrap> syncBootstrap() async =>
      _pendingFriendRequestBootstrap(
        status: _accepted ? 'accepted' : 'pending_inbound',
      );

  @override
  Future<ContactEntry> acceptContactRequest({
    required String roomId,
    required String peerMxid,
    String displayName = '',
    String avatarUrl = '',
    String domain = '',
  }) async {
    _accepted = true;
    return super.acceptContactRequest(
      roomId: roomId,
      peerMxid: peerMxid,
      displayName: displayName,
      avatarUrl: avatarUrl,
      domain: domain,
    );
  }
}

class _RejectingPendingContactAsClient extends _EmptyAsClient {
  var _rejected = false;

  @override
  Future<AsSyncBootstrap> syncBootstrap() async =>
      _pendingFriendRequestBootstrap(
        status: _rejected ? 'rejected' : 'pending_inbound',
      );

  @override
  Future<ContactEntry> rejectContactRequest({
    required String roomId,
    required String peerMxid,
    String displayName = '',
    String domain = '',
  }) async {
    _rejected = true;
    return super.rejectContactRequest(
      roomId: roomId,
      peerMxid: peerMxid,
      displayName: displayName,
      domain: domain,
    );
  }
}

class _IdleVoiceCallController implements VoiceCallController {
  _IdleVoiceCallController({
    GroupCallUiState initialGroupState = GroupCallUiState.idle,
  }) : _groupState = initialGroupState;

  final _controller = StreamController<VoiceCallUiState>.broadcast();
  final _groupController = StreamController<GroupCallUiState>.broadcast();
  final GroupCallUiState _groupState;

  @override
  VoiceCallUiState get currentState => VoiceCallUiState.idle;

  @override
  CallSession? get activeSession => null;

  @override
  Stream<VoiceCallUiState> get stateStream => _controller.stream;

  @override
  GroupCallUiState get currentGroupState => _groupState;

  @override
  GroupCallSession? get activeGroupSession => null;

  @override
  Stream<GroupCallUiState> get groupStateStream => _groupController.stream;

  @override
  Future<void> attachClient(Client client) async {}

  @override
  Future<void> startOutgoing({
    required String roomId,
    required String peerUserId,
    String? peerDisplayName,
    ProductCallType callType = ProductCallType.voice,
  }) async {}

  @override
  Future<void> answer() async {}

  @override
  Future<void> reject() async {}

  @override
  Future<void> hangup() async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> setCameraMuted(bool muted) async {}

  @override
  Future<void> setSpeakerOn(bool enabled) async {}

  @override
  Future<void> startOrJoinGroupCall({
    required String roomId,
    required String roomName,
    ProductCallType callType = ProductCallType.voice,
    List<String> invitedUserIds = const [],
    bool joinExistingInvite = false,
    String? existingCallId,
  }) async {}

  @override
  Future<void> leaveGroupCall() async {}

  @override
  Future<void> setGroupMuted(bool muted) async {}

  @override
  Future<void> setGroupCameraMuted(bool muted) async {}

  @override
  Future<void> setGroupSpeakerOn(bool enabled) async {}

  @override
  void dispose() {
    _controller.close();
    _groupController.close();
  }
}

class _FavoritesAsClient extends _EmptyAsClient {
  _FavoritesAsClient({
    this.videoThumbnail = true,
    this.imageUrl = 'mxc://p2p-im.com/image',
    this.imageThumbnailUrl = '',
    this.textSenderAvatarUrl = 'https://cdn.example.com/alice-favorite.png',
  });

  static const generatedImageName =
      'image_picker_11111111-AAAA-BBBB-CCCC-generated-photo.jpg';
  static const generatedVideoName =
      'image_picker_22545629-08B6-4C45-B8ED-generated-video.mov';
  final bool videoThumbnail;
  final String imageUrl;
  final String imageThumbnailUrl;
  final String textSenderAvatarUrl;
  final deletedFavoriteIds = <int>{};

  @override
  Future<List<AsFavoriteMessage>> getFavorites({
    String messageType = '',
    int limit = 100,
  }) async {
    final favorites = [
      AsFavoriteMessage(
        id: 1,
        ownerUserId: '@owner:p2p-im.com',
        roomId: '!dm:p2p-im.com',
        eventId: r'$text',
        roomType: 'direct',
        messageType: 'text',
        senderId: '@alice:p2p-liyanan.com',
        senderName: 'Alice',
        senderAvatarUrl: textSenderAvatarUrl,
        body: '明天上午继续测试',
        url: '',
        filename: '',
        mimeType: '',
        size: 0,
        thumbnailUrl: '',
        thumbnailMimeType: '',
        thumbnailSize: 0,
        width: 0,
        height: 0,
        durationMs: 0,
        originServerTs: 1779685200000,
        favoritedAt: DateTime.utc(2026, 5, 29, 10),
      ),
      AsFavoriteMessage(
        id: 2,
        ownerUserId: '@owner:p2p-im.com',
        roomId: '!group:p2p-im.com',
        eventId: r'$file',
        roomType: 'group',
        messageType: 'file',
        senderId: '@bob:p2p-im.com',
        senderName: 'Bob',
        body: 'report.pdf',
        url: 'mxc://p2p-im.com/report',
        filename: 'report.pdf',
        mimeType: 'application/pdf',
        size: 4096,
        thumbnailUrl: '',
        thumbnailMimeType: '',
        thumbnailSize: 0,
        width: 0,
        height: 0,
        durationMs: 0,
        originServerTs: 1779685300000,
        favoritedAt: DateTime.utc(2026, 5, 29, 11),
      ),
      AsFavoriteMessage(
        id: 3,
        ownerUserId: '@owner:p2p-im.com',
        roomId: '!dm:p2p-im.com',
        eventId: r'$video',
        roomType: 'direct',
        messageType: 'video',
        senderId: '@alice:p2p-liyanan.com',
        senderName: 'Alice',
        body: generatedVideoName,
        url: 'mxc://p2p-im.com/video',
        filename: generatedVideoName,
        mimeType: 'video/quicktime',
        size: 149790,
        thumbnailUrl: videoThumbnail ? 'mxc://p2p-im.com/thumb' : '',
        thumbnailMimeType: 'image/jpeg',
        thumbnailSize: 2048,
        width: 640,
        height: 360,
        durationMs: 2100,
        originServerTs: 1779685400000,
        favoritedAt: DateTime.utc(2026, 5, 29, 12),
      ),
      AsFavoriteMessage(
        id: 4,
        ownerUserId: '@owner:p2p-im.com',
        roomId: '!dm:p2p-im.com',
        eventId: r'$image',
        roomType: 'direct',
        messageType: 'image',
        senderId: '@alice:p2p-liyanan.com',
        senderName: 'Alice',
        body: generatedImageName,
        url: imageUrl,
        filename: generatedImageName,
        mimeType: 'image/jpeg',
        size: 102400,
        thumbnailUrl: imageThumbnailUrl,
        thumbnailMimeType: 'image/jpeg',
        thumbnailSize: 0,
        width: 1280,
        height: 720,
        durationMs: 0,
        originServerTs: 1779685500000,
        favoritedAt: DateTime.utc(2026, 5, 29, 13),
      ),
      AsFavoriteMessage(
        id: 5,
        ownerUserId: '@owner:p2p-im.com',
        roomId: '!dm:p2p-im.com',
        eventId: r'$direct-record',
        roomType: 'direct',
        messageType: 'chat_record',
        senderId: '@alice:p2p-liyanan.com',
        senderName: 'Alice',
        body: '',
        url: '',
        filename: '',
        mimeType: '',
        size: 0,
        thumbnailUrl: '',
        thumbnailMimeType: '',
        thumbnailSize: 0,
        width: 0,
        height: 0,
        durationMs: 0,
        originServerTs: 1779685600000,
        favoritedAt: DateTime.utc(2026, 5, 29, 14),
        chatRecord: const {
          'title': '与 Alice 的聊天记录',
          'source_room_id': '!dm:p2p-im.com',
          'source_room_type': 'direct',
          'item_count': 2,
          'items': [
            {
              'sender_id': '@alice:p2p-liyanan.com',
              'sender_name': 'Alice',
              'is_me': false,
              'body': '第一条',
              'message_type': 'm.text',
              'origin_server_ts': 1779685200000,
              'content': {'msgtype': 'm.text', 'body': '第一条'},
            },
            {
              'sender_id': '@owner:p2p-im.com',
              'sender_name': 'Yanan',
              'is_me': true,
              'body': '第二条',
              'message_type': 'm.text',
              'origin_server_ts': 1779685300000,
              'content': {'msgtype': 'm.text', 'body': '第二条'},
            },
          ],
        },
      ),
      AsFavoriteMessage(
        id: 6,
        ownerUserId: '@owner:p2p-im.com',
        roomId: '!group:p2p-im.com',
        eventId: r'$group-record',
        roomType: 'group',
        messageType: 'chat_record',
        senderId: '@bob:p2p-im.com',
        senderName: 'Bob',
        body: '群聊「产品测试群」的聊天记录',
        url: '',
        filename: '',
        mimeType: '',
        size: 0,
        thumbnailUrl: '',
        thumbnailMimeType: '',
        thumbnailSize: 0,
        width: 0,
        height: 0,
        durationMs: 0,
        originServerTs: 1779685700000,
        favoritedAt: DateTime.utc(2026, 5, 29, 15),
      ),
      AsFavoriteMessage(
        id: 7,
        ownerUserId: '@owner:p2p-im.com',
        roomId: '!dm:p2p-im.com',
        eventId: r'$audio',
        roomType: 'direct',
        messageType: 'audio',
        senderId: '@alice:p2p-liyanan.com',
        senderName: 'Alice',
        body: '',
        url: 'mxc://p2p-im.com/audio',
        filename: '',
        mimeType: 'audio/ogg',
        size: 2048,
        thumbnailUrl: '',
        thumbnailMimeType: '',
        thumbnailSize: 0,
        width: 0,
        height: 0,
        durationMs: 60000,
        originServerTs: 1779685800000,
        favoritedAt: DateTime.utc(2026, 5, 29, 16),
      ),
    ];
    final visible = favorites
        .where((favorite) => !deletedFavoriteIds.contains(favorite.id))
        .toList(growable: false);
    if (messageType.trim().isEmpty) return visible;
    return visible
        .where((favorite) => favorite.messageType == messageType.trim())
        .toList(growable: false);
  }

  @override
  Future<void> deleteFavorite(int id) async {
    deletedFavoriteIds.add(id);
  }
}

class _ChannelActivityAsClient extends _EmptyAsClient {
  int reactionsCallCount = 0;
  int? lastReactionsLimit;
  int commentsCallCount = 0;
  int? lastCommentsLimit;

  static const _channel = AsChannel(
    channelId: 'ch_product',
    roomId: '!ch_product:p2p-im.com',
    homeDomain: 'p2p-im.com',
    name: '产品公告',
    description: '只发布重要产品更新',
    memberStatus: asChannelMemberStatusJoined,
  );

  static const _post = AsChannelPost(
    postId: 'post1',
    channelId: 'ch_product',
    roomId: '!ch_product:p2p-im.com',
    eventId: r'$post1',
    authorId: '@owner:p2p-im.com',
    authorName: 'Yanan',
    messageType: 'text',
    body: '频道发帖已打通',
    originServerTs: 1780731600000,
    reactionCount: 1,
    reactedByMe: true,
  );

  @override
  Future<List<AsChannelReactionHistory>> getMyChannelReactions({
    int limit = 50,
  }) async {
    reactionsCallCount += 1;
    lastReactionsLimit = limit;
    return const [
      AsChannelReactionHistory(
        postId: 'post1',
        channelId: 'ch_product',
        reaction: 'like',
        originServerTs: 1780731700000,
        channel: _channel,
        post: _post,
      ),
    ];
  }

  @override
  Future<List<AsChannelCommentHistory>> getMyChannelComments({
    int limit = 50,
  }) async {
    commentsCallCount += 1;
    lastCommentsLimit = limit;
    return const [
      AsChannelCommentHistory(
        comment: AsChannelComment(
          commentId: 'comment1',
          postId: 'post1',
          channelId: 'ch_product',
          eventId: r'$comment1',
          authorId: '@owner:p2p-im.com',
          authorName: 'Yanan',
          authorDomain: 'p2p-im.com',
          messageType: 'text',
          body: '这条评论来自真实用户名',
          originServerTs: 1780731800000,
        ),
        channel: _channel,
        post: _post,
      ),
    ];
  }
}

class _MemoryConversationPreferencesStore
    implements ConversationPreferencesStore {
  _MemoryConversationPreferencesStore([
    this.data = const ConversationPreferencesData(),
  ]);

  ConversationPreferencesData data;

  @override
  Future<ConversationPreferencesData> read() async => data;

  @override
  Future<void> write(ConversationPreferencesData data) async {
    this.data = data;
  }
}

class _MemoryConversationSummaryStore implements ConversationSummaryStore {
  _MemoryConversationSummaryStore([this.snapshot]);

  ConversationSummarySnapshot? snapshot;

  @override
  Future<ConversationSummarySnapshot?> read() async => snapshot;

  @override
  Future<void> write(ConversationSummarySnapshot snapshot) async {
    this.snapshot = snapshot;
  }

  @override
  Future<void> clear() async {
    snapshot = null;
  }
}

EventUpdate _messageSoundUpdate({
  required String roomId,
  required String sender,
}) {
  return EventUpdate(
    roomID: roomId,
    type: EventUpdateType.timeline,
    content: {
      'type': EventTypes.Message,
      'sender': sender,
      'content': {
        'msgtype': MessageTypes.Text,
        'body': 'hello',
      },
    },
  );
}

class _MemoryMediaThumbnailCache implements MediaThumbnailCache {
  final items = <String, Uint8List>{};

  @override
  Uint8List? peek(String key) => items[key.trim()];

  @override
  Future<Uint8List?> read(String key) async => items[key.trim()];

  @override
  Future<void> write(String key, List<int> bytes) async {
    final normalized = key.trim();
    if (normalized.isEmpty || bytes.isEmpty) return;
    items[normalized] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> warm(Iterable<String> keys) async {}
}

class _MemoryFriendRequestReadStore implements FriendRequestReadStore {
  Set<String> ids = {};

  @override
  Future<Set<String>> readRoomIds() async => ids;

  @override
  Future<void> writeRoomIds(Set<String> roomIds) async {
    ids = {...roomIds};
  }
}

AsSyncBootstrap _pendingFriendRequestBootstrap({
  String status = 'pending_inbound',
}) {
  return AsSyncBootstrap(
    syncedAt: DateTime.utc(2026, 5, 28, 12),
    user: const AsSyncUser(userId: '@owner:p2p-im.com'),
    rooms: const [],
    contacts: [
      AsSyncContact(
        userId: '@alice:portal.local',
        displayName: 'Alice',
        avatarUrl: '',
        roomId: '!person-invite:p2p-im.com',
        domain: 'portal.local',
        status: status,
        remark: '请通过一下',
      ),
    ],
    groups: const [],
    channels: const [],
    pending: const AsSyncPending.empty(),
  );
}

class _NeverListChannelsAsClient extends _EmptyAsClient {
  @override
  Future<List<AsChannel>> listChannels() => Completer<List<AsChannel>>().future;
}

class _StaticListChannelsAsClient extends _EmptyAsClient {
  _StaticListChannelsAsClient(this.channels);

  final List<AsChannel> channels;

  @override
  Future<List<AsChannel>> listChannels() async => channels;
}

class _NeverListChannelsWithConversationsAsClient
    extends _NeverListChannelsAsClient {
  _NeverListChannelsWithConversationsAsClient(this.conversations);

  final List<AsConversation> conversations;

  @override
  Future<AsSyncBootstrap> syncBootstrap() async {
    return _bootstrapFromConversations(conversations);
  }
}

class _TrackingAsClient extends _EmptyAsClient {
  int createContactRequestCalls = 0;
  Object? createContactRequestError;
  String? createdContactMxid;
  String? createdContactDisplayName;
  String? createdContactAvatarUrl;
  String? createdContactDomain;
  String? createdContactRemark;
  AsConversation? createdContactProductConversation;
  int deleteContactCalls = 0;
  String? deletedContactRoomId;
  int updateContactCalls = 0;
  String? updatedContactRoomId;
  String? updatedContactDisplayName;
  String? updatedContactAvatarUrl;
  String? updatedContactDomain;
  int createGroupCalls = 0;
  String? createdGroupName;
  String? createdGroupAvatarUrl;
  List<String> createdGroupInvites = const [];
  AsConversation? createdGroupProductConversation;
  int inviteGroupMembersCalls = 0;
  String? invitedGroupRoomId;
  List<String> invitedGroupMembers = const [];
  Object? inviteGroupMembersError;
  int joinGroupCalls = 0;
  String? joinedGroupRoomId;
  String? joinedGroupName;
  int syncBootstrapCalls = 0;
  AsSyncBootstrap? bootstrapAfterCreate;
  int leaveGroupCalls = 0;
  String? leftGroupRoomId;
  int dissolveGroupCalls = 0;
  String? dissolvedGroupRoomId;
  int removeGroupMemberCalls = 0;
  String? removedGroupRoomId;
  String? removedGroupPeerMxid;
  List<AsGroupMember> groupMembers = const [];
  AsSyncBootstrap? bootstrapAfterLeave;
  int updateGroupInvitePolicyCalls = 0;
  String? updatedGroupInvitePolicyRoomId;
  String? updatedGroupInvitePolicy;
  int updateGroupProfileCalls = 0;
  String? updatedGroupProfileRoomId;
  String? updatedGroupProfileName;
  String? updatedGroupProfileTopic;
  String? updatedGroupProfileAvatarUrl;
  int muteGroupCalls = 0;
  String? mutedGroupRoomId;
  int unmuteGroupCalls = 0;
  String? unmutedGroupRoomId;
  int listCallsCount = 0;
  List<AsChannel> userPublicChannels = const [];
  String? requestedUserPublicChannelsUserId;
  Uri? requestedUserPublicChannelsBaseUri;
  String? requestedPublicChannelRoomId;

  @override
  Future<ContactEntry> createContactRequest({
    required String mxid,
    String displayName = '',
    String avatarUrl = '',
    String domain = '',
    String remark = '',
  }) async {
    createContactRequestCalls++;
    createdContactMxid = mxid;
    createdContactDisplayName = displayName;
    createdContactAvatarUrl = avatarUrl;
    createdContactDomain = domain;
    createdContactRemark = remark;
    final error = createContactRequestError;
    if (error != null) throw error;
    return ContactEntry(
      peerMxid: mxid,
      displayName: displayName,
      avatarUrl: avatarUrl,
      domain: domain,
      roomId: '!new-request:example.com',
      status: 'pending_outbound',
      remark: remark.trim(),
      productConversation: createdContactProductConversation,
    );
  }

  @override
  Future<List<AsChannel>> getUserPublicChannels(
    String userId, {
    Uri? baseUri,
    Uri? remoteNodeBaseUri,
  }) async {
    requestedUserPublicChannelsUserId = userId;
    requestedUserPublicChannelsBaseUri = remoteNodeBaseUri ?? baseUri;
    return userPublicChannels;
  }

  @override
  Future<AsChannel> getPublicChannelByRoomId(
    String roomId, {
    Uri? baseUri,
    Uri? remoteNodeBaseUri,
  }) async {
    requestedPublicChannelRoomId = roomId;
    final channel = userPublicChannels.where((item) => item.roomId == roomId);
    if (channel.isNotEmpty) return channel.first;
    return super.getPublicChannelByRoomId(
      roomId,
      baseUri: baseUri,
      remoteNodeBaseUri: remoteNodeBaseUri,
    );
  }

  @override
  Future<ContactEntry> deleteContact(String roomId) async {
    deleteContactCalls++;
    deletedContactRoomId = roomId;
    return ContactEntry(
      peerMxid: '@alice:portal.local',
      displayName: 'Alice',
      domain: 'portal.local',
      roomId: roomId,
      status: 'rejected',
    );
  }

  @override
  Future<ContactEntry> updateContact({
    required String roomId,
    required String displayName,
    String avatarUrl = '',
    String domain = '',
  }) async {
    updateContactCalls++;
    updatedContactRoomId = roomId;
    updatedContactDisplayName = displayName;
    updatedContactAvatarUrl = avatarUrl;
    updatedContactDomain = domain;
    return ContactEntry(
      peerMxid: '@alice:portal.local',
      displayName: displayName.trim(),
      avatarUrl: avatarUrl.trim(),
      domain: domain.trim(),
      roomId: roomId,
      status: 'accepted',
    );
  }

  @override
  Future<List<AsCallSession>> listCalls({
    required String roomId,
    int limit = 50,
  }) async {
    listCallsCount++;
    return const [];
  }

  @override
  Future<AsGroupResult> createGroup({
    required String name,
    required List<String> invite,
    String avatarUrl = '',
  }) async {
    createGroupCalls++;
    createdGroupName = name;
    createdGroupAvatarUrl = avatarUrl;
    createdGroupInvites = List.unmodifiable(invite);
    return AsGroupResult(
      roomId: '!new-group:p2p-im.com',
      name: name,
      memberCount: 1,
      invitedCount: invite.length,
      role: 'owner',
      productConversation: createdGroupProductConversation,
    );
  }

  @override
  Future<AsGroupResult> updateGroupProfile({
    required String roomId,
    String name = '',
    String topic = '',
    String avatarUrl = '',
  }) async {
    updateGroupProfileCalls++;
    updatedGroupProfileRoomId = roomId;
    updatedGroupProfileName = name;
    updatedGroupProfileTopic = topic;
    updatedGroupProfileAvatarUrl = avatarUrl;
    return AsGroupResult(
      roomId: roomId,
      name: name.trim().isEmpty ? '真实群' : name.trim(),
      memberCount: 3,
      role: 'owner',
    );
  }

  @override
  Future<AsGroupResult> inviteGroupMembers({
    required String roomId,
    required List<String> invite,
  }) async {
    inviteGroupMembersCalls++;
    invitedGroupRoomId = roomId;
    invitedGroupMembers = List.unmodifiable(invite);
    final error = inviteGroupMembersError;
    if (error != null) throw error;
    return AsGroupResult(
      roomId: roomId,
      name: '真实群',
      memberCount: 2,
      invitedCount: invite.length,
    );
  }

  @override
  Future<List<AsGroupMember>> getGroupMembers(
    String roomId, {
    String status = '',
  }) async {
    return [
      for (final member in groupMembers)
        if (member.roomId.trim() == roomId.trim()) member,
    ];
  }

  @override
  Future<AsGroupResult> joinGroup({
    required String roomId,
    String groupName = '',
    String inviterMxid = '',
    String inviteEventId = '',
    String directRoomId = '',
  }) async {
    joinGroupCalls++;
    joinedGroupRoomId = roomId;
    joinedGroupName = groupName;
    return AsGroupResult(
      roomId: roomId,
      name: groupName.trim().isEmpty ? '真实群' : groupName.trim(),
      memberCount: 2,
      role: 'member',
    );
  }

  @override
  Future<void> removeGroupMember({
    required String roomId,
    required String peerMxid,
  }) async {
    removeGroupMemberCalls++;
    removedGroupRoomId = roomId;
    removedGroupPeerMxid = peerMxid;
  }

  @override
  Future<void> leaveGroup(String roomId) async {
    leaveGroupCalls++;
    leftGroupRoomId = roomId;
  }

  @override
  Future<void> dissolveGroup(String roomId) async {
    dissolveGroupCalls++;
    dissolvedGroupRoomId = roomId;
  }

  @override
  Future<AsGroupResult> updateGroupInvitePolicy({
    required String roomId,
    required String invitePolicy,
  }) async {
    updateGroupInvitePolicyCalls++;
    updatedGroupInvitePolicyRoomId = roomId;
    updatedGroupInvitePolicy = invitePolicy;
    return AsGroupResult(
      roomId: roomId,
      name: '真实群',
      memberCount: 3,
      invitePolicy: invitePolicy,
    );
  }

  @override
  Future<void> muteGroup(String roomId) async {
    muteGroupCalls++;
    mutedGroupRoomId = roomId;
  }

  @override
  Future<void> unmuteGroup(String roomId) async {
    unmuteGroupCalls++;
    unmutedGroupRoomId = roomId;
  }

  @override
  Future<AsSyncBootstrap> syncBootstrap() async {
    syncBootstrapCalls++;
    return bootstrapAfterCreate ??
        bootstrapAfterLeave ??
        await super.syncBootstrap();
  }
}

class _MemoryAsBootstrapStore implements AsBootstrapStore {
  AsSyncBootstrap? value;

  @override
  Future<void> clear() async {
    value = null;
  }

  @override
  Future<AsSyncBootstrap?> read() async => value;

  @override
  Future<void> write(AsSyncBootstrap bootstrap) async {
    value = bootstrap;
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
    final trimmed = channelId.trim();
    posts.removeWhere((_, post) => post.channelId.trim() == trimmed);
    for (final post in nextPosts) {
      await upsertPost(post);
    }
  }

  @override
  Future<void> upsertPost(AsChannelPost post) async {
    final key = '${post.channelId}:${post.postId}:${post.eventId}';
    posts[key] = post;
  }

  @override
  Future<void> removePost(String channelId, String postId) async {
    final trimmedChannel = channelId.trim();
    final trimmedPost = postId.trim();
    posts.removeWhere((_, post) {
      if (post.channelId.trim() != trimmedChannel) return false;
      if (post.postId.trim().isNotEmpty) {
        return post.postId.trim() == trimmedPost;
      }
      return post.eventId.trim() == trimmedPost;
    });
  }
}

class _MemoryLocalOutboxStore implements LocalOutboxStore {
  _MemoryLocalOutboxStore([List<LocalOutboxItem>? items]) : items = [...?items];

  final List<LocalOutboxItem> items;

  @override
  Future<List<LocalOutboxItem>> readAll() async => [...items];

  @override
  Future<void> upsert(LocalOutboxItem item) async {
    items.removeWhere((existing) => existing.id == item.id);
    items.add(item);
  }

  @override
  Future<void> remove(String id) async {
    items.removeWhere((item) => item.id == id);
  }
}

class _PendingInboundAddContactAsClient extends _EmptyAsClient {
  @override
  Future<ContactEntry> createContactRequest({
    required String mxid,
    String displayName = '',
    String avatarUrl = '',
    String domain = '',
    String remark = '',
  }) async {
    return ContactEntry(
      peerMxid: mxid,
      displayName: displayName,
      avatarUrl: avatarUrl,
      domain: domain,
      roomId: '!incoming:portal.local',
      status: 'pending_inbound',
      remark: remark.trim(),
    );
  }
}

class _FollowsAsClient extends _EmptyAsClient {
  @override
  Future<List<FollowEntry>> getFollows() async => [
        FollowEntry(
          domain: 'alice.portal.local',
          name: 'Alice Chen',
          followedAt: DateTime.utc(2026, 5, 26, 8),
        ),
      ];
}

class _CompletingConversationsAsClient extends _EmptyAsClient {
  _CompletingConversationsAsClient(this.conversationCompleter);

  final Completer<List<AsConversation>> conversationCompleter;

  @override
  Future<AsSyncBootstrap> syncBootstrap() async {
    return _bootstrapFromConversations(await conversationCompleter.future);
  }
}

class _StaticBootstrapAsClient extends _EmptyAsClient {
  _StaticBootstrapAsClient(this.bootstrap);

  final AsSyncBootstrap bootstrap;

  @override
  Future<AsSyncBootstrap> syncBootstrap() async => bootstrap;
}

class _RefreshingBootstrapAsClient extends _EmptyAsClient {
  int syncBootstrapCalls = 0;

  @override
  Future<AsSyncBootstrap> syncBootstrap() async {
    syncBootstrapCalls++;
    final showAcceptedContact = syncBootstrapCalls >= 2;
    return AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 28, 14, syncBootstrapCalls),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [
        AsSyncRoomSummary(
          roomId: '!current:p2p-im.com',
          name: 'Yanan',
          avatarUrl: '',
          unreadCount: 7,
          lastActivityAt: null,
        ),
      ],
      contacts: [
        if (showAcceptedContact)
          const AsSyncContact(
            userId: '@owner:p2p-liyanan.com',
            displayName: 'Yanan',
            avatarUrl: '',
            roomId: '!accepted:p2p-im.com',
            domain: 'p2p-liyanan.com',
            status: 'accepted',
          ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
  }
}

AsSyncBootstrap _bootstrapFromConversations(
  List<AsConversation> conversations,
) {
  final rooms = <AsSyncRoomSummary>[];
  final contacts = <AsSyncContact>[];
  final groups = <AsSyncRoomSummary>[];
  final channels = <AsSyncRoomSummary>[];
  var agentRoomId = '';

  for (final conversation in conversations) {
    final roomId = conversation.roomId.trim();
    if (roomId.isEmpty) continue;
    if (conversation.isDirect) {
      contacts.add(AsSyncContact(
        userId: conversation.peerMxid.trim().isNotEmpty
            ? conversation.peerMxid.trim()
            : '@peer:p2p-im.com',
        displayName: conversation.title,
        avatarUrl: conversation.avatarUrl,
        roomId: roomId,
        status: 'accepted',
      ));
      rooms.add(_summaryFromConversation(conversation));
    } else if (conversation.isGroup) {
      groups.add(_summaryFromConversation(conversation));
    } else if (conversation.isChannel) {
      channels.add(_summaryFromConversation(conversation));
    } else if (conversation.isAgent) {
      agentRoomId = roomId;
      rooms.add(_summaryFromConversation(conversation));
    }
  }

  return AsSyncBootstrap(
    syncedAt: DateTime.now().toUtc(),
    user: const AsSyncUser(userId: '@owner:p2p-im.com'),
    agentRoomId: agentRoomId,
    rooms: rooms,
    contacts: contacts,
    groups: groups,
    channels: channels,
    pending: const AsSyncPending.empty(),
  );
}

AsSyncRoomSummary _summaryFromConversation(AsConversation conversation) {
  return AsSyncRoomSummary(
    channelId: conversation.isChannel ? conversation.conversationId.trim() : '',
    roomId: conversation.roomId.trim(),
    name: conversation.title.trim(),
    avatarUrl: conversation.avatarUrl.trim(),
    unreadCount: 0,
    lastActivityAt: conversation.lastActivityAt,
    memberStatus: conversation.membership.trim().isNotEmpty
        ? conversation.membership.trim()
        : asChannelMemberStatusJoined,
    role: conversation.role.trim(),
    memberCount: conversation.memberCount,
    commentsEnabled: conversation.commentsEnabled,
  );
}

class _RefreshingFriendRequestBootstrapAsClient extends _EmptyAsClient {
  int syncBootstrapCalls = 0;
  bool showPendingFriendRequest = false;
  bool showPendingGroupInvite = false;

  @override
  Future<AsSyncBootstrap> syncBootstrap() async {
    syncBootstrapCalls++;
    return AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 19, 13, syncBootstrapCalls),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: AsSyncPending(
        friendRequests: showPendingFriendRequest
            ? const [
                AsSyncPendingItem(
                  id: '!pending-live:p2p-im.com',
                  title: 'Alice',
                  createdAt: null,
                ),
              ]
            : const [],
        groupInvites: showPendingGroupInvite
            ? const [
                AsSyncPendingItem(
                  id: '!pending-group-live:p2p-im.com',
                  title: '实时群聊',
                  createdAt: null,
                ),
              ]
            : const [],
        channelNotices: const [],
      ),
    );
  }
}

class _RecordingAvatarPreloader implements AvatarPreloader {
  final urls = <String>[];

  @override
  Future<void> preload(String url) async {
    urls.add(url);
  }
}

Finder _headerTitle(String title) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Text && widget.data == title && widget.style?.fontSize == 24,
  );
}

Room _addTestRoom(
  Client client, {
  required String roomId,
  required Membership roomMembership,
  String? directPeerMxid,
  String? directPeerName,
  Membership directPeerMembership = Membership.join,
}) {
  final room = Room(
    id: roomId,
    client: client,
    membership: roomMembership,
  );
  client.rooms.add(room);
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: client.userID ?? '@owner:p2p-im.com',
      stateKey: client.userID,
      content: {'membership': roomMembership.name},
    ),
  );
  if (directPeerMxid != null) {
    final directContent = Map<String, dynamic>.from(
      client.accountData['m.direct']?.content ?? const <String, dynamic>{},
    );
    directContent[directPeerMxid] = <String>[roomId];
    client.accountData['m.direct'] = BasicEvent(
      type: 'm.direct',
      content: directContent,
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: directPeerMxid,
        stateKey: directPeerMxid,
        content: {
          'membership': directPeerMembership.name,
          if (directPeerName?.trim().isNotEmpty == true)
            'displayname': directPeerName!.trim(),
        },
      ),
    );
  }
  return room;
}

Room _addUndirectedJoinedRoom(
  Client client, {
  required String roomId,
  required String peerMxid,
  required String peerName,
  String peerAvatarUrl = '',
  Membership peerMembership = Membership.join,
  bool includePeerMemberAvatar = true,
}) {
  final room = Room(
    id: roomId,
    client: client,
    membership: Membership.join,
  );
  client.rooms.add(room);
  final selfMxid = client.userID ?? '@owner:p2p-im.com';
  room.setState(
    StrippedStateEvent(
      type: 'io.direxio.room.profile',
      senderId: selfMxid,
      stateKey: '',
      content: {
        'room_type': 'io.direxio.room.direct',
        'room_id': roomId,
        'requester_mxid': selfMxid,
        'target_mxid': peerMxid,
        'display_name': peerName,
        if (peerAvatarUrl.isNotEmpty) 'avatar_url': peerAvatarUrl,
      },
    ),
  );
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: selfMxid,
      stateKey: selfMxid,
      content: {'membership': Membership.join.name},
    ),
  );
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: peerMxid,
      stateKey: peerMxid,
      content: {
        'membership': peerMembership.name,
        'displayname': peerName,
        if (includePeerMemberAvatar && peerAvatarUrl.isNotEmpty)
          'avatar_url': peerAvatarUrl,
      },
    ),
  );
  room.lastEvent = Event(
    room: room,
    eventId: r'$undirected',
    senderId: peerMxid,
    type: EventTypes.Message,
    originServerTs: DateTime(2026, 5, 26, 23, 41),
    content: {
      'msgtype': MessageTypes.Text,
      'body': 'friend flow accepted message',
    },
  );
  return room;
}

Room _addNamedGroupRoom(
  Client client, {
  required String roomId,
  required String name,
  String? creatorMxid,
  Membership membership = Membership.join,
  Map<String, String> members = const {},
  Map<String, String> memberAvatarUrls = const {},
}) {
  final selfMxid = client.userID ?? '@owner:p2p-im.com';
  final creator = creatorMxid ?? selfMxid;
  final room = Room(
    id: roomId,
    client: client,
    membership: membership,
  );
  client.rooms.add(room);
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: selfMxid,
      stateKey: selfMxid,
      content: {'membership': membership.name},
    ),
  );
  for (final entry in members.entries) {
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: entry.key,
        stateKey: entry.key,
        content: {
          'membership': Membership.join.name,
          'displayname': entry.value,
          if ((memberAvatarUrls[entry.key] ?? '').trim().isNotEmpty)
            'avatar_url': memberAvatarUrls[entry.key]!.trim(),
        },
      ),
    );
  }
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomName,
      senderId: selfMxid,
      stateKey: '',
      content: {'name': name},
    ),
  );
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomCreate,
      senderId: creator,
      stateKey: '',
      content: {'creator': creator},
    ),
  );
  room.lastEvent = Event(
    room: room,
    eventId: r'$group',
    senderId: creator,
    type: EventTypes.RoomCreate,
    originServerTs: DateTime(2026, 5, 27, 16, 12),
    content: const {},
  );
  return room;
}

class _RecoveringGroupRoomClient extends Client {
  _RecoveringGroupRoomClient({
    required this.recoveryRoomId,
    required this.recoveryUserId,
  }) : super('DirexioGroupChatMissingRoomRecoveryTest') {
    setUserId(recoveryUserId);
  }

  final String recoveryRoomId;
  final String recoveryUserId;
  final syncRequests =
      <({String? filter, bool? fullState, String? since, int? timeout})>[];

  @override
  Future<SyncUpdate> sync({
    String? filter,
    String? since,
    bool? fullState,
    PresenceType? setPresence,
    int? timeout,
  }) async {
    syncRequests.add((
      filter: filter,
      fullState: fullState,
      since: since,
      timeout: timeout,
    ));
    return SyncUpdate(
      nextBatch: 's-full-state',
      rooms: RoomsUpdate(
        join: {
          recoveryRoomId: JoinedRoomUpdate(
            state: [
              MatrixEvent(
                type: EventTypes.RoomMember,
                eventId: r'$self-member',
                senderId: recoveryUserId,
                stateKey: recoveryUserId,
                originServerTs: DateTime.fromMillisecondsSinceEpoch(
                  1780000000000,
                ),
                content: const {'membership': 'join'},
              ),
              MatrixEvent(
                type: EventTypes.RoomName,
                eventId: r'$room-name',
                senderId: recoveryUserId,
                stateKey: '',
                originServerTs: DateTime.fromMillisecondsSinceEpoch(
                  1780000000001,
                ),
                content: const {'name': '真实群'},
              ),
              MatrixEvent(
                type: EventTypes.RoomCreate,
                eventId: r'$room-create',
                senderId: recoveryUserId,
                stateKey: '',
                originServerTs: DateTime.fromMillisecondsSinceEpoch(
                  1780000000002,
                ),
                content: {'creator': recoveryUserId},
              ),
            ],
            timeline: TimelineUpdate(events: const [], prevBatch: 't0'),
          ),
        },
      ),
    );
  }
}

class _RecoveringDirectRoomClient extends Client {
  _RecoveringDirectRoomClient({
    required this.recoveryRoomId,
    required this.ownerMxid,
    required this.peerMxid,
  }) : super('DirexioMissingRoomRecoveryTest') {
    setUserId(ownerMxid);
  }

  final String recoveryRoomId;
  final String ownerMxid;
  final String peerMxid;
  final syncRequests =
      <({String? filter, bool? fullState, String? since, int? timeout})>[];

  @override
  Future<SyncUpdate> sync({
    String? filter,
    String? since,
    bool? fullState,
    PresenceType? setPresence,
    int? timeout,
  }) async {
    syncRequests.add((
      filter: filter,
      fullState: fullState,
      since: since,
      timeout: timeout,
    ));
    return SyncUpdate(
      nextBatch: 's-direct-full-state',
      rooms: RoomsUpdate(
        join: {
          recoveryRoomId: JoinedRoomUpdate(
            state: [
              MatrixEvent(
                type: EventTypes.RoomMember,
                eventId: r'$owner-member',
                senderId: ownerMxid,
                stateKey: ownerMxid,
                originServerTs: DateTime.fromMillisecondsSinceEpoch(
                  1780000000000,
                ),
                content: const {'membership': 'join'},
              ),
              MatrixEvent(
                type: EventTypes.RoomMember,
                eventId: r'$peer-member',
                senderId: peerMxid,
                stateKey: peerMxid,
                originServerTs: DateTime.fromMillisecondsSinceEpoch(
                  1780000000001,
                ),
                content: const {
                  'membership': 'join',
                  'displayname': 'Alice',
                },
              ),
              MatrixEvent(
                type: EventTypes.RoomCreate,
                eventId: r'$direct-create',
                senderId: ownerMxid,
                stateKey: '',
                originServerTs: DateTime.fromMillisecondsSinceEpoch(
                  1780000000002,
                ),
                content: {'creator': ownerMxid},
              ),
            ],
            timeline: TimelineUpdate(events: const [], prevBatch: 't0'),
          ),
        },
      ),
    );
  }
}

class _GroupMembersAsClient extends _EmptyAsClient {
  _GroupMembersAsClient(this.members);

  final List<AsGroupMember> members;

  @override
  Future<List<AsGroupMember>> getGroupMembers(
    String roomId, {
    String status = '',
  }) async {
    return [
      for (final member in members)
        if (member.roomId.trim() == roomId.trim()) member,
    ];
  }
}

class _GroupChatHarness {
  const _GroupChatHarness({
    required this.client,
    required this.asClient,
    required this.bootstrapStore,
    required this.visibilityClient,
    this.sentMatrixEvents = const [],
    this.matrixRedactionPaths = const [],
    this.matrixLocalDeleteBodies = const [],
  });

  final Client client;
  final _TrackingAsClient asClient;
  final _MemoryAsBootstrapStore bootstrapStore;
  final _RecordingMatrixMessageVisibilityClient visibilityClient;
  final List<Map<String, dynamic>> sentMatrixEvents;
  final List<String> matrixRedactionPaths;
  final List<Map<String, dynamic>> matrixLocalDeleteBodies;
}

class _DirectChatHarness {
  const _DirectChatHarness({
    required this.client,
    required this.asClient,
    this.matrixRedactionPaths = const [],
    this.matrixLocalDeleteBodies = const [],
  });

  final Client client;
  final _TrackingAsClient asClient;
  final List<String> matrixRedactionPaths;
  final List<Map<String, dynamic>> matrixLocalDeleteBodies;
}

Future<_GroupChatHarness> _pumpGroupChatWithTextEvent(
  WidgetTester tester, {
  String roomId = '!group:p2p-im.com',
  String roomName = '真实群',
  String eventId = r'$group-text',
  String body = '群聊长按消息',
  String senderMxid = '@alice:p2p-im.com',
  List<LocalOutboxItem> initialOutboxItems = const [],
  bool sendTextEvent = true,
  bool loggedInAuth = false,
  GoRouter? router,
  Profile? currentUserProfile,
}) async {
  final sentMatrixEvents = <Map<String, dynamic>>[];
  final matrixRedactionPaths = <String>[];
  final matrixLocalDeleteBodies = <Map<String, dynamic>>[];
  final visibilityClient = _RecordingMatrixMessageVisibilityClient();
  final client = Client(
    'DirexioGroupActionTest',
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/local_delete')) {
        matrixLocalDeleteBodies.add(
          (jsonDecode(request.body) as Map).cast<String, dynamic>(),
        );
        return http.Response(
          jsonEncode({
            'room_id': roomId,
            'hidden_event_ids': [eventId]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.contains('/redact/')) {
        matrixRedactionPaths.add(request.url.path);
        return http.Response(
          r'{"event_id":"$group-redaction"}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.contains('/send/m.room.message/')) {
        sentMatrixEvents.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          r'{"event_id":"$group-sent"}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        '{"next_batch":"s1","rooms":{}}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  )..setUserId('@owner:p2p-im.com');
  client.homeserver = Uri.parse('https://p2p-im.com');
  client.accessToken = 'test-token';
  _addNamedGroupRoom(
    client,
    roomId: roomId,
    name: roomName,
    creatorMxid: '@owner:p2p-im.com',
    members: const {'@alice:p2p-im.com': 'Alice'},
  );
  final bootstrap = AsSyncBootstrap(
    syncedAt: DateTime.utc(2026, 5, 30, 8),
    user: const AsSyncUser(userId: '@owner:p2p-im.com'),
    rooms: const [],
    contacts: const [],
    groups: [
      AsSyncRoomSummary(
        roomId: roomId,
        name: roomName,
        avatarUrl: '',
        unreadCount: 0,
        lastActivityAt: null,
      ),
    ],
    channels: const [],
    pending: const AsSyncPending.empty(),
  );
  final asClient = _TrackingAsClient()..bootstrapAfterLeave = bootstrap;
  final bootstrapStore = _MemoryAsBootstrapStore();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        matrixClientProvider.overrideWithValue(client),
        if (loggedInAuth)
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
        asClientProvider.overrideWithValue(asClient),
        matrixMessageVisibilityClientProvider.overrideWithValue(
          visibilityClient,
        ),
        asBootstrapRepositoryProvider.overrideWithValue(
          AsBootstrapRepository(
            loadBootstrap: asClient.syncBootstrap,
            store: bootstrapStore,
          ),
        ),
        asSyncCacheProvider.overrideWith(
          (ref) => AsSyncCacheState(bootstrap: bootstrap),
        ),
        localOutboxStoreProvider.overrideWith(
          (ref) async => _MemoryLocalOutboxStore(initialOutboxItems),
        ),
        if (currentUserProfile != null)
          currentUserProfileProvider.overrideWith(
            (ref) async => currentUserProfile,
          ),
      ],
      child: router == null
          ? MaterialApp(
              theme: AppTheme.light,
              home: GroupChatPage(roomId: roomId),
            )
          : MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
            ),
    ),
  );
  await tester.pumpAndSettle();

  if (!sendTextEvent) {
    return _GroupChatHarness(
      client: client,
      asClient: asClient,
      bootstrapStore: bootstrapStore,
      visibilityClient: visibilityClient,
      sentMatrixEvents: sentMatrixEvents,
      matrixRedactionPaths: matrixRedactionPaths,
      matrixLocalDeleteBodies: matrixLocalDeleteBodies,
    );
  }

  await client.handleSync(
    SyncUpdate(
      nextBatch: 'after-group-action-message',
      rooms: RoomsUpdate(
        join: {
          roomId: JoinedRoomUpdate(
            timeline: TimelineUpdate(
              events: [
                MatrixEvent(
                  type: EventTypes.Message,
                  eventId: eventId,
                  roomId: roomId,
                  senderId: senderMxid,
                  originServerTs: DateTime.utc(2026, 5, 30, 10),
                  content: {
                    'msgtype': MessageTypes.Text,
                    'body': body,
                  },
                ),
              ],
            ),
          ),
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  return _GroupChatHarness(
    client: client,
    asClient: asClient,
    bootstrapStore: bootstrapStore,
    visibilityClient: visibilityClient,
    sentMatrixEvents: sentMatrixEvents,
    matrixRedactionPaths: matrixRedactionPaths,
    matrixLocalDeleteBodies: matrixLocalDeleteBodies,
  );
}

Future<_DirectChatHarness> _pumpDirectChatWithPeerTextEvent(
  WidgetTester tester, {
  String roomId = '!direct:p2p-im.com',
  String peerMxid = '@alice:p2p-liyanan.com',
  String peerName = 'Alice',
  String eventId = r'$direct-text',
  String body = '别人发来的消息',
  String? senderMxid,
  List<LocalOutboxItem> initialOutboxItems = const [],
  bool sendPeerEvent = true,
  Locale? locale,
}) async {
  final matrixRedactionPaths = <String>[];
  final matrixLocalDeleteBodies = <Map<String, dynamic>>[];
  final client = Client(
    'DirexioDirectActionTest',
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/local_delete')) {
        matrixLocalDeleteBodies.add(
          (jsonDecode(request.body) as Map).cast<String, dynamic>(),
        );
        return http.Response(
          jsonEncode({
            'room_id': roomId,
            'hidden_event_ids': [eventId]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.contains('/redact/')) {
        matrixRedactionPaths.add(request.url.path);
        return http.Response(
          r'{"event_id":"$direct-redaction"}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        '{"next_batch":"s1","rooms":{}}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  )..setUserId('@owner:p2p-im.com');
  client.homeserver = Uri.parse('https://p2p-im.com');
  client.accessToken = 'test-token';
  _addUndirectedJoinedRoom(
    client,
    roomId: roomId,
    peerMxid: peerMxid,
    peerName: peerName,
  );
  final bootstrap = AsSyncBootstrap(
    syncedAt: DateTime.utc(2026, 5, 30, 12),
    user: const AsSyncUser(userId: '@owner:p2p-im.com'),
    rooms: const [],
    contacts: [
      AsSyncContact(
        userId: peerMxid,
        displayName: peerName,
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
  final asClient = _TrackingAsClient();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        matrixClientProvider.overrideWithValue(client),
        authStateNotifierProvider.overrideWith(_LoggedInAuthStateNotifier.new),
        asClientProvider.overrideWithValue(asClient),
        asSyncCacheProvider.overrideWith(
          (ref) => AsSyncCacheState(bootstrap: bootstrap),
        ),
        localOutboxStoreProvider.overrideWith(
          (ref) async => _MemoryLocalOutboxStore(initialOutboxItems),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ChatPage(roomId: roomId),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (!sendPeerEvent) {
    return _DirectChatHarness(
      client: client,
      asClient: asClient,
      matrixRedactionPaths: matrixRedactionPaths,
      matrixLocalDeleteBodies: matrixLocalDeleteBodies,
    );
  }

  await client.handleSync(
    SyncUpdate(
      nextBatch: 'after-direct-action-message',
      rooms: RoomsUpdate(
        join: {
          roomId: JoinedRoomUpdate(
            timeline: TimelineUpdate(
              events: [
                MatrixEvent(
                  type: EventTypes.Message,
                  eventId: eventId,
                  roomId: roomId,
                  senderId: senderMxid ?? peerMxid,
                  originServerTs: DateTime.utc(2026, 5, 30, 12, 10),
                  content: {
                    'msgtype': MessageTypes.Text,
                    'body': body,
                  },
                ),
              ],
            ),
          ),
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return _DirectChatHarness(
    client: client,
    asClient: asClient,
    matrixRedactionPaths: matrixRedactionPaths,
    matrixLocalDeleteBodies: matrixLocalDeleteBodies,
  );
}

Room _addHeroSummaryRoom(
  Client client, {
  required String roomId,
  required String peerMxid,
  required String peerName,
}) {
  final room = Room(
    id: roomId,
    client: client,
    membership: Membership.join,
    summary: RoomSummary.fromJson({
      'm.heroes': [peerMxid],
      'm.joined_member_count': 2,
      'm.invited_member_count': 0,
    }),
  );
  client.rooms.add(room);
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: client.userID ?? '@owner:p2p-im.com',
      stateKey: client.userID,
      content: {'membership': Membership.join.name},
    ),
  );
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomMember,
      senderId: peerMxid,
      stateKey: peerMxid,
      content: {
        'membership': Membership.join.name,
        'displayname': peerName,
      },
    ),
  );
  room.lastEvent = Event(
    room: room,
    eventId: r'$hero',
    senderId: peerMxid,
    type: EventTypes.Message,
    originServerTs: DateTime(2026, 5, 27, 19, 56),
    content: {
      'msgtype': MessageTypes.Text,
      'body': 'm.room.member',
    },
  );
  return room;
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  test('placeholder smoke test', () {
    expect(1 + 1, 2);
  });

  test('markRoomLocallyRead clears Matrix unread counters immediately', () {
    final client = Client('DirexioTest');
    final room = Room(
      id: '!room:example.com',
      client: client,
      notificationCount: 3,
      highlightCount: 1,
    );

    markRoomLocallyRead(room);

    expect(room.notificationCount, 0);
    expect(room.highlightCount, 0);
  });

  test('marking a room read clears cached AS unread counts', () {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 4, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: 'Group',
          avatarUrl: '',
          unreadCount: 1,
          lastActivityAt: DateTime.utc(2026, 6, 4, 12),
        ),
      ],
      contacts: const [],
      groups: [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: 'Group',
          avatarUrl: '',
          unreadCount: 1,
          lastActivityAt: DateTime.utc(2026, 6, 4, 12),
        ),
        AsSyncRoomSummary(
          roomId: '!other:p2p-im.com',
          name: 'Other',
          avatarUrl: '',
          unreadCount: 2,
          lastActivityAt: DateTime.utc(2026, 6, 4, 11),
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    final next = AsSyncCacheState(bootstrap: bootstrap)
        .withRoomUnreadCleared('!group:p2p-im.com');

    expect(next.bootstrap!.rooms.single.unreadCount, 0);
    expect(next.bootstrap!.groups.first.unreadCount, 0);
    expect(next.bootstrap!.groups.last.unreadCount, 2);
  });

  test('stale bootstrap refresh cannot restore locally read room unread', () {
    const roomId = '!group:p2p-im.com';
    final readAt = DateTime.utc(2026, 6, 4, 12);
    final staleBootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 4, 12, 0, 1),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: [
        AsSyncRoomSummary(
          roomId: roomId,
          name: 'Group',
          avatarUrl: '',
          unreadCount: 1,
          lastActivityAt: readAt,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final newerBootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 4, 12, 1),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: [
        AsSyncRoomSummary(
          roomId: roomId,
          name: 'Group',
          avatarUrl: '',
          unreadCount: 1,
          lastActivityAt: readAt.add(const Duration(seconds: 1)),
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    final locallyRead =
        const AsSyncCacheState().withRoomUnreadCleared(roomId, readAt: readAt);
    final staleRefresh = locallyRead.copyWith(bootstrap: staleBootstrap);
    final newerRefresh = locallyRead.copyWith(bootstrap: newerBootstrap);

    expect(staleRefresh.bootstrap!.groups.single.unreadCount, 0);
    expect(newerRefresh.bootstrap!.groups.single.unreadCount, 1);
  });

  test('bootstrap refresh clears local optimistic contacts omitted by AS', () {
    const state = AsSyncCacheState(
      localContactStatusesByRoomId: {
        '!stale:p2p-im.com': 'pending_outbound',
      },
    );

    final next = state.copyWith(
      bootstrap: AsSyncBootstrap(
        syncedAt: DateTime.utc(2026, 5, 27, 12),
        user: const AsSyncUser(userId: '@owner:p2p-im.com'),
        rooms: const [],
        contacts: const [],
        groups: const [],
        channels: const [],
        pending: const AsSyncPending.empty(),
      ),
    );

    expect(next.contactStatusForRoom('!stale:p2p-im.com'), isNull);
  });

  test('new local contact entry for same peer clears stale accepted room', () {
    const accepted = ContactEntry(
      peerMxid: '@owner:p2p-liyanan.com',
      displayName: 'Yanan',
      domain: 'p2p-liyanan.com',
      roomId: '!old:p2p-im.com',
      status: 'accepted',
    );
    const pending = ContactEntry(
      peerMxid: '@owner:p2p-liyanan.com',
      displayName: 'Yanan',
      domain: 'p2p-liyanan.com',
      roomId: '!new:p2p-im.com',
      status: 'pending_outbound',
    );

    final state = const AsSyncCacheState()
        .withContactEntry(accepted)
        .withContactEntry(pending);

    expect(state.contactStatusForRoom('!old:p2p-im.com'), isNull);
    expect(
      state.contactStatusForRoom('!new:p2p-im.com'),
      'pending_outbound',
    );
    expect(state.acceptedDirectRoomIds, isNot(contains('!old:p2p-im.com')));
  });

  test(
      'new local accepted contact shadows stale bootstrap accepted room for same peer',
      () {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 28, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [
        AsSyncRoomSummary(
          roomId: '!current:p2p-im.com',
          name: 'Yanan',
          avatarUrl: '',
          unreadCount: 7,
          lastActivityAt: null,
        ),
      ],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'Yanan',
          avatarUrl: '',
          roomId: '!old:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    const accepted = ContactEntry(
      peerMxid: '@owner:p2p-liyanan.com',
      displayName: 'Yanan',
      domain: 'p2p-liyanan.com',
      roomId: '!new:p2p-im.com',
      status: 'accepted',
    );

    final state =
        AsSyncCacheState(bootstrap: bootstrap).withContactEntry(accepted);

    expect(state.contactStatusForRoom('!old:p2p-im.com'), isNull);
    expect(state.contactForRoom('!old:p2p-im.com'), isNull);
    expect(state.contactStatusForRoom('!new:p2p-im.com'), 'accepted');
    expect(state.contactForRoom('!new:p2p-im.com')?.displayName, 'Yanan');
    expect(state.acceptedDirectRoomIds, {'!new:p2p-im.com'});
  });

  test('group member invite candidates prefer sendable duplicate contacts', () {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 20, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@carol:p2p-carol.com',
          displayName: 'Carol',
          avatarUrl: '',
          roomId: '',
          domain: 'p2p-carol.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    const localCarol = ContactEntry(
      peerMxid: '@carol:p2p-carol.com',
      displayName: 'Carol',
      domain: 'p2p-carol.com',
      roomId: '!carol:p2p-im.com',
      status: 'accepted',
    );

    final state =
        AsSyncCacheState(bootstrap: bootstrap).withContactEntry(localCarol);

    final candidates = groupMemberInviteCandidates(state, const {});

    expect(candidates, hasLength(1));
    expect(candidates.single.userId, '@carol:p2p-carol.com');
    expect(candidates.single.roomId, '!carol:p2p-im.com');
  });

  test(
      'group member invite candidates hide bootstrap contact shadowed by pending duplicate',
      () {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 20, 11),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@carol:p2p-carol.com',
          displayName: 'Carol',
          avatarUrl: '',
          roomId: '!old-carol:p2p-im.com',
          domain: 'p2p-carol.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    const pendingCarol = ContactEntry(
      peerMxid: '@carol:p2p-carol.com',
      displayName: 'Carol',
      domain: 'p2p-carol.com',
      roomId: '!carol:p2p-im.com',
      status: 'pending_outbound',
    );

    final state =
        AsSyncCacheState(bootstrap: bootstrap).withContactEntry(pendingCarol);

    final candidates = groupMemberInviteCandidates(state, const {});

    expect(candidates, isEmpty);
  });

  testWidgets('messages home header does not duplicate the me avatar shortcut',
      (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.size == 32 &&
            widget.imageUrl != null,
      ),
      findsNothing,
    );
  });

  testWidgets(
      'messages list does not flash mock conversations while auth loads',
      (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(
            _LoadingAuthStateNotifier.new,
          ),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agent'), findsNothing);
    expect(find.text('正在同步消息'), findsOneWidget);
  });

  testWidgets(
      'messages render bootstrap contacts instead of undirected room fallback',
      (tester) async {
    final client = Client('DirexioUndirectedRoomMetadataTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!owner:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'owner',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 22, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [
        AsSyncRoomSummary(
          roomId: '!owner:p2p-im.com',
          name: 'owner',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'owner',
          avatarUrl: '',
          roomId: '!owner:p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_MemberLoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Group with'), findsNothing);
    expect(find.text('owner'), findsOneWidget);
    expect(find.text('推荐给朋友'), findsNothing);
  });

  testWidgets('messages open direct chats with ProductCore conversation id',
      (tester) async {
    const roomId = '!alice:p2p-im.com';
    const conversationId = 'conv_alice';
    final client = Client('DirexioProductConversationOpenTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: roomId,
      peerMxid: '@alice:p2p-im.com',
      peerName: 'Alice',
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, state) => Scaffold(
            body: Text(
              'chat:${state.pathParameters['roomId']};'
              'conversation:${state.uri.queryParameters['conversation']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(
            _ConversationListAsClient(const [
              AsConversation(
                conversationId: conversationId,
                roomId: roomId,
                kind: asConversationKindDirect,
                lifecycle: 'active',
                title: 'Alice',
                avatarUrl: '',
                hydrationState: 'ready',
                capabilities: AsConversationCapabilities(open: true),
              ),
            ]),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(
        find.text('chat:$roomId;conversation:$conversationId'), findsOneWidget);
  });

  testWidgets('messages conversation avatar uses ProductCore avatar',
      (tester) async {
    final client = Client('DirexioConversationAsAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!owner:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
      peerAvatarUrl: 'https://matrix.example.com/yanan.png',
    );
    final asClient = _ConversationListAsClient(const [
      AsConversation(
        conversationId: 'conv_owner',
        roomId: '!owner:p2p-im.com',
        kind: asConversationKindDirect,
        lifecycle: 'active',
        title: 'Yanan',
        avatarUrl: 'https://product.example.com/yanan.png',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_MemberLoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yanan'), findsAtLeastNWidgets(1));
    expect(find.text('Yanan 新昵称'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.size == 42 &&
            widget.imageUrl == 'https://product.example.com/yanan.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('messages keeps ProductCore avatar after Matrix member sync',
      (tester) async {
    final client = Client('DirexioConversationAvatarSyncTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!owner:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
      peerAvatarUrl: 'https://matrix.example.com/old.png',
    );
    final asClient = _ConversationListAsClient(const [
      AsConversation(
        conversationId: 'conv_owner',
        roomId: '!owner:p2p-im.com',
        kind: asConversationKindDirect,
        lifecycle: 'active',
        title: 'Yanan',
        avatarUrl: 'https://product.example.com/yanan.png',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_MemberLoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.size == 42 &&
            widget.imageUrl == 'https://product.example.com/yanan.png',
      ),
      findsOneWidget,
    );

    client.getRoomById('!owner:p2p-im.com')!.setState(
          StrippedStateEvent(
            type: EventTypes.RoomMember,
            senderId: '@owner:p2p-liyanan.com',
            stateKey: '@owner:p2p-liyanan.com',
            content: const {
              'membership': 'join',
              'displayname': 'Yanan 新昵称',
              'avatar_url': 'https://matrix.example.com/new.png',
            },
          ),
        );
    await client.handleSync(SyncUpdate(nextBatch: 'after-avatar-change'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.size == 42 &&
            widget.imageUrl == 'https://product.example.com/yanan.png',
      ),
      findsOneWidget,
    );
    expect(find.text('Yanan 新昵称'), findsNothing);
  });

  testWidgets('messages contact conversation does not show online dot',
      (tester) async {
    final client = Client('DirexioConversationNoContactOnlineDotTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!owner:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
      peerAvatarUrl: 'https://matrix.example.com/yanan.png',
    );
    final asClient = _ConversationListAsClient(const [
      AsConversation(
        conversationId: 'conv_owner',
        roomId: '!owner:p2p-im.com',
        kind: asConversationKindDirect,
        lifecycle: 'active',
        title: 'Yanan',
        avatarUrl: '',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yanan'), findsOneWidget);
    expect(find.byType(OnlineDot), findsNothing);
  });

  testWidgets('messages preview hides last event after room chat clear',
      (tester) async {
    const roomId = '!owner:p2p-im.com';
    const peerMxid = '@owner:p2p-liyanan.com';
    final client = Client('DirexioConversationClearPreviewTest')
      ..setUserId('@owner:p2p-im.com');
    final room = _addUndirectedJoinedRoom(
      client,
      roomId: roomId,
      peerMxid: peerMxid,
      peerName: 'Yanan',
    );
    final asClient = _ConversationListAsClient(const [
      AsConversation(
        conversationId: 'conv_owner',
        roomId: roomId,
        kind: asConversationKindDirect,
        lifecycle: 'active',
        title: 'Yanan',
        avatarUrl: '',
      ),
    ]);
    final clearAfterLastEvent =
        room.lastEvent!.originServerTs.millisecondsSinceEpoch + 1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(
              localRoomClearedBeforeTs: {roomId: clearAfterLastEvent},
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yanan'), findsOneWidget);
    expect(find.text('friend flow accepted message'), findsNothing);
  });

  testWidgets('messages conversation avatar uses ProductCore fallback avatar',
      (tester) async {
    final client = Client('DirexioConversationMatrixAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!owner:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
      peerAvatarUrl: 'https://matrix.example.com/yanan.png',
    );
    final asClient = _ConversationListAsClient(const [
      AsConversation(
        conversationId: 'conv_owner',
        roomId: '!owner:p2p-im.com',
        kind: asConversationKindDirect,
        lifecycle: 'active',
        title: 'Yanan',
        avatarUrl: 'https://product.example.com/fallback.png',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.size == 42 &&
            widget.imageUrl == 'https://product.example.com/fallback.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('messages direct conversation uses peer member identity',
      (tester) async {
    final client = Client('DirexioConversationPeerIdentityTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!owner:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan Matrix',
      peerAvatarUrl: 'https://matrix.example.com/yanan.png',
    );
    final asClient = _ConversationListAsClient(const [
      AsConversation(
        conversationId: 'conv_owner',
        roomId: '!owner:p2p-im.com',
        kind: asConversationKindDirect,
        lifecycle: 'active',
        peerMxid: '@owner:p2p-liyanan.com',
        title: '',
        avatarUrl: '',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yanan Matrix'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.size == 42 &&
            widget.imageUrl == 'https://matrix.example.com/yanan.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('messages hide pending outbound contact rooms from AS metadata',
      (tester) async {
    final client = Client('DirexioPendingOutboundHomeListTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!pending:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'owner',
      peerMembership: Membership.invite,
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'owner',
          avatarUrl: 'https://cdn.example.com/pending-owner.png',
          roomId: '!pending:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'pending_outbound',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Group with'), findsNothing);
    expect(find.text('friend flow accepted message'), findsNothing);
    expect(find.text('还没有会话'), findsOneWidget);
  });

  testWidgets('messages keep pending contact hidden until AS accepts it',
      (tester) async {
    final client = Client('DirexioPendingJoinedHomeListTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!pending:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'owner',
      peerMembership: Membership.join,
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'owner',
          avatarUrl: 'https://cdn.example.com/pending-owner.png',
          roomId: '!pending:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'pending_outbound',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    expect(find.text('owner'), findsNothing);
    expect(find.text('friend flow accepted message'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
    expect(find.text('还没有会话'), findsOneWidget);
  });

  testWidgets('messages refresh AS metadata after Matrix sync events',
      (tester) async {
    final client = Client('DirexioMatrixSyncRefreshesAsMetadataTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!accepted:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'owner',
      peerMembership: Membership.join,
    );
    final asClient = _RefreshingBootstrapAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(asClient.syncBootstrapCalls, 1);
    expect(find.text('Yanan'), findsNothing);

    await tester.pump(const Duration(seconds: 9));
    await client.handleSync(SyncUpdate(nextBatch: 'after-accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.syncBootstrapCalls, 2);
    expect(find.text('Yanan'), findsWidgets);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets('messages render ProductCore direct before Matrix room hydrates',
      (tester) async {
    final client = Client('DirexioAsAcceptedContactOnlyHomeListTest')
      ..setUserId('@owner:p2p-im.com');
    final asClient = _ConversationListAsClient(
      const [
        AsConversation(
          conversationId: 'conv_current',
          roomId: '!current:p2p-im.com',
          kind: asConversationKindDirect,
          lifecycle: 'active',
          title: 'Yanan',
          avatarUrl: '',
        ),
      ],
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 28, 11),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [
        AsSyncRoomSummary(
          roomId: '!current:p2p-im.com',
          name: 'Yanan',
          avatarUrl: '',
          unreadCount: 7,
          lastActivityAt: null,
        ),
      ],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    expect(find.text('Yanan'), findsWidgets);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('还没有会话'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets(
      'messages render ProductCore conversations before Matrix room hydrates',
      (tester) async {
    final client = Client('DirexioProductCoreConversationHomeListTest')
      ..setUserId('@owner:p2p-im.com');
    final asClient = _ConversationListAsClient(
      const [
        AsConversation(
          conversationId: 'conv_direct',
          roomId: '!product-direct:p2p-im.com',
          kind: asConversationKindDirect,
          lifecycle: 'active',
          title: 'Product Alice',
          avatarUrl: '',
          lastActivityAt: null,
          projectionState: 'ready',
          capabilities: AsConversationCapabilities(open: true),
        ),
      ],
    );
    final snapshotStore = _MemoryConversationSummaryStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          conversationSummaryStoreProvider.overrideWith(
            (ref) async => snapshotStore,
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Product Alice'), findsWidgets);
    expect(find.text('还没有会话'), findsNothing);
  });

  testWidgets('messages use ProductCore preview before Matrix room hydrates',
      (tester) async {
    final client = Client('DirexioAsConversationPreviewHomeListTest')
      ..setUserId('@owner:p2p-im.com');
    final asClient = _ConversationListAsClient(
      [
        AsConversation(
          conversationId: 'conv_preview',
          roomId: '!preview:p2p-im.com',
          kind: asConversationKindDirect,
          lifecycle: 'active',
          title: 'B Bash Smoke',
          avatarUrl: '',
          lastMessage: 'server side latest message',
          lastActivityAt: DateTime.utc(2026, 6, 22, 11),
          relationshipStatus: 'accepted',
          capabilities: const AsConversationCapabilities(open: true),
        ),
      ],
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 22, 11),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final snapshotStore = _MemoryConversationSummaryStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          conversationSummaryStoreProvider.overrideWith(
            (ref) async => snapshotStore,
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('B Bash Smoke'), findsWidgets);
    expect(find.text('server side latest message'), findsOneWidget);
    expect(find.text('还没有会话'), findsNothing);
  });

  testWidgets('messages render ProductCore group before Matrix room hydrates',
      (tester) async {
    final client = Client('DirexioAsJoinedGroupOnlyHomeListTest')
      ..setUserId('@owner:example.test');
    final asClient = _ConversationListAsClient(
      const [
        AsConversation(
          conversationId: 'conv_bca',
          roomId: '!bca:example.test',
          kind: asConversationKindGroup,
          lifecycle: 'active',
          title: 'BCA',
          avatarUrl: '',
          capabilities: AsConversationCapabilities(open: true),
        ),
      ],
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 21, 11),
      user: const AsSyncUser(userId: '@owner:example.test'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final snapshotStore = _MemoryConversationSummaryStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          conversationSummaryStoreProvider.overrideWith(
            (ref) async => snapshotStore,
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('BCA'), findsWidgets);
    expect(find.text('还没有会话'), findsNothing);
  });

  testWidgets('messages hide ProductCore conversations that cannot open',
      (tester) async {
    final client = Client('DirexioHiddenPendingProductConversationTest')
      ..setUserId('@owner:p2p-im.com');
    final asClient = _ConversationListAsClient(
      const [
        AsConversation(
          conversationId: 'conv_active',
          roomId: '!active:p2p-im.com',
          kind: asConversationKindDirect,
          lifecycle: 'active',
          title: 'Active B',
          avatarUrl: '',
          relationshipStatus: 'accepted',
          capabilities: AsConversationCapabilities(open: true),
        ),
        AsConversation(
          conversationId: 'conv_pending',
          roomId: '!pending:p2p-im.com',
          kind: asConversationKindDirect,
          lifecycle: 'pending',
          title: 'Pending B',
          avatarUrl: '',
          relationshipStatus: 'pending_outbound',
          capabilities: AsConversationCapabilities(open: false),
        ),
      ],
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 22, 11),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Active B'), findsWidgets);
    expect(find.text('Pending B'), findsNothing);
    expect(find.text('还没有会话'), findsNothing);
  });

  testWidgets('messages keep removed group and open read-only chat',
      (tester) async {
    const roomId = '!removed-home:p2p-im.com';
    final client = Client(
      'DirexioRemovedGroupHomeListTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: '被移除群聊',
      membership: Membership.leave,
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final asClient = _ConversationListAsClient(
      const [
        AsConversation(
          conversationId: 'conv_removed_home',
          roomId: roomId,
          kind: asConversationKindGroup,
          lifecycle: 'active',
          title: '被移除群聊',
          avatarUrl: '',
          membership: 'removed',
          capabilities: AsConversationCapabilities(open: false),
        ),
      ],
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: '被移除群聊',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: 'removed',
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/group/:roomId',
          builder: (_, state) => GroupChatPage(
            roomId: state.pathParameters['roomId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('被移除群聊'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('home_conversation_$roomId')));
    await tester.pumpAndSettle();

    expect(find.text('无法在已退出的群聊中发送消息'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('messages prefer direct contact over stale group for same room',
      (tester) async {
    final client = Client('DirexioDirectContactOverStaleGroupHomeListTest')
      ..setUserId('@owner:example.test');
    const roomId = '!direct:example.test';
    final asClient = _ConversationListAsClient(
      const [
        AsConversation(
          conversationId: 'conv_direct',
          roomId: roomId,
          kind: asConversationKindDirect,
          lifecycle: 'active',
          title: 'C Direct',
          avatarUrl: '',
          capabilities: AsConversationCapabilities(open: true),
        ),
      ],
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 21, 12),
      user: const AsSyncUser(userId: '@owner:example.test'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: 'C Stale Group',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 2,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/chat/:roomId',
          builder: (context, state) => const Text('direct route'),
        ),
        GoRoute(
          path: '/group/:roomId',
          builder: (context, state) => const Text('group route'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('C Direct'), findsWidgets);
    expect(find.text('C Stale Group'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home_conversation_$roomId')));
    await tester.pumpAndSettle();

    expect(find.text('direct route'), findsOneWidget);
    expect(find.text('group route'), findsNothing);
  });

  testWidgets('messages render cached home conversations before rooms hydrate',
      (tester) async {
    final client = Client('DirexioCachedHomeConversationListTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final snapshotStore = _MemoryConversationSummaryStore(
      ConversationSummarySnapshot(
        userId: '@owner:p2p-im.com',
        updatedAt: DateTime.utc(2026, 6, 21, 10),
        entries: [
          ConversationSummaryEntry(
            roomId: '!cached-direct:p2p-im.com',
            name: '缓存联系人',
            lastMessage: '本地缓存消息',
            previewTs: DateTime.utc(2026, 6, 21, 10).millisecondsSinceEpoch,
            unread: 4,
            isGroup: false,
            isAgent: false,
            avatarUrl: 'mxc://p2p-im.com/cached-avatar',
          ),
          ConversationSummaryEntry(
            roomId: '!cached-group:p2p-im.com',
            name: '缓存群聊',
            lastMessage: '群聊缓存消息',
            previewTs: DateTime.utc(2026, 6, 21, 9).millisecondsSinceEpoch,
            unread: 0,
            isGroup: true,
            isAgent: false,
            avatarUrl: 'mxc://p2p-im.com/cached-group-avatar',
          ),
        ],
      ),
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 21, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@cached-direct:p2p-im.com',
          displayName: '缓存联系人',
          status: 'accepted',
          roomId: '!cached-direct:p2p-im.com',
          avatarUrl: '',
        ),
      ],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!cached-group:p2p-im.com',
          name: '缓存群聊',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: 'join',
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          conversationSummaryStoreProvider.overrideWith(
            (ref) async => snapshotStore,
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('缓存联系人'), findsOneWidget);
    expect(find.text('本地缓存消息'), findsOneWidget);
    expect(find.text('缓存群聊'), findsOneWidget);
    expect(find.text('群聊缓存消息'), findsOneWidget);
    expect(
      tester.widgetList<PortalAvatar>(find.byType(PortalAvatar)).any((avatar) =>
          avatar.imageUrl?.contains('/download/p2p-im.com/cached-avatar') ??
          false),
      isTrue,
    );
    expect(
      tester
          .widgetList<GroupCompositeAvatar>(
            find.byType(GroupCompositeAvatar),
          )
          .any((avatar) =>
              avatar.imageUrl
                  ?.contains('/download/p2p-im.com/cached-group-avatar') ??
              false),
      isTrue,
    );
    expect(find.text('还没有会话'), findsNothing);
  });

  testWidgets('messages ignore blank cached-only conversations while loading',
      (tester) async {
    final client = Client('DirexioBlankCachedHomeConversationListTest')
      ..setUserId('@owner:p2p-im.com');
    final conversationCompleter = Completer<List<AsConversation>>();
    final snapshotStore = _MemoryConversationSummaryStore(
      ConversationSummarySnapshot(
        userId: '@owner:p2p-im.com',
        updatedAt: DateTime.utc(2026, 6, 21, 10),
        entries: [
          const ConversationSummaryEntry(
            roomId: '!blank-direct:p2p-im.com',
            name: 'B Bash Smoke 1781942406-9885',
            lastMessage: '',
            previewTs: 0,
            unread: 0,
            isGroup: false,
            isAgent: false,
          ),
          ConversationSummaryEntry(
            roomId: '!cached-direct:p2p-im.com',
            name: '缓存联系人',
            lastMessage: '本地缓存消息',
            previewTs: DateTime.utc(2026, 6, 21, 10).millisecondsSinceEpoch,
            unread: 0,
            isGroup: false,
            isAgent: false,
          ),
        ],
      ),
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 21, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(
            _CompletingConversationsAsClient(conversationCompleter),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          conversationSummaryStoreProvider.overrideWith(
            (ref) async => snapshotStore,
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('缓存联系人'), findsOneWidget);
    expect(find.text('本地缓存消息'), findsOneWidget);
    expect(find.text('B Bash Smoke 1781942406-9885'), findsNothing);
    expect(find.text('还没有会话'), findsNothing);
  });

  testWidgets('messages prune stale cached conversations after ProductCore',
      (tester) async {
    final client = Client('DirexioCachedHomeConversationMergeTest')
      ..setUserId('@owner:p2p-im.com');
    final liveAt = DateTime.utc(2026, 6, 21, 12);
    final snapshotStore = _MemoryConversationSummaryStore(
      ConversationSummarySnapshot(
        userId: '@owner:p2p-im.com',
        updatedAt: DateTime.utc(2026, 6, 21, 10),
        entries: [
          ConversationSummaryEntry(
            roomId: '!a:p2p-im.com',
            name: '旧联系人A',
            lastMessage: '旧消息A',
            previewTs: DateTime.utc(2026, 6, 21, 10).millisecondsSinceEpoch,
            unread: 1,
            isGroup: false,
            isAgent: false,
          ),
          ConversationSummaryEntry(
            roomId: '!b:p2p-im.com',
            name: '缓存B',
            lastMessage: '缓存B消息',
            previewTs: DateTime.utc(2026, 6, 21, 9).millisecondsSinceEpoch,
            unread: 2,
            isGroup: false,
            isAgent: false,
          ),
        ],
      ),
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: liveAt,
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: [
        AsSyncRoomSummary(
          roomId: '!a:p2p-im.com',
          name: 'Yanan',
          avatarUrl: '',
          unreadCount: 9,
          lastActivityAt: liveAt,
        ),
      ],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _ConversationListAsClient([
      AsConversation(
        conversationId: 'conv_a',
        roomId: '!a:p2p-im.com',
        kind: asConversationKindDirect,
        lifecycle: 'active',
        title: 'Yanan',
        avatarUrl: '',
        lastActivityAt: liveAt,
        capabilities: const AsConversationCapabilities(open: true),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          conversationSummaryStoreProvider.overrideWith(
            (ref) async => snapshotStore,
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Yanan'), findsWidgets);
    expect(find.text('旧消息A'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('缓存B'), findsNothing);
    expect(find.text('缓存B消息'), findsNothing);
    expect(find.text('还没有会话'), findsNothing);

    await tester.pump();
    final persisted = snapshotStore.snapshot;
    expect(
      persisted?.entries.map((entry) => entry.roomId),
      ['!a:p2p-im.com'],
    );
    final updated = persisted!.entries.firstWhere(
      (entry) => entry.roomId == '!a:p2p-im.com',
    );
    expect(updated.name, 'Yanan');
    expect(updated.lastMessage, '旧消息A');
    expect(updated.unread, 9);
    expect(updated.previewTs, liveAt.millisecondsSinceEpoch);
  });

  testWidgets('messages clear stale cache after empty ProductCore refresh',
      (tester) async {
    final client = Client('DirexioEmptyProductCorePrunesCacheTest')
      ..setUserId('@owner:p2p-im.com');
    final snapshotStore = _MemoryConversationSummaryStore(
      ConversationSummarySnapshot(
        userId: '@owner:p2p-im.com',
        updatedAt: DateTime.utc(2026, 6, 22, 10),
        entries: const [
          ConversationSummaryEntry(
            roomId: '!stale:p2p-im.com',
            name: '多余联系人',
            lastMessage: '旧预览',
            previewTs: 1,
            unread: 0,
            isGroup: false,
            isAgent: false,
          ),
        ],
      ),
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 22, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(
            _ConversationListAsClient(const []),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          conversationSummaryStoreProvider.overrideWith(
            (ref) async => snapshotStore,
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(snapshotStore.snapshot?.entries, isEmpty);
    expect(find.text('多余联系人'), findsNothing);
  });

  testWidgets('messages hide AS group until Matrix room is joined',
      (tester) async {
    final client = Client('DirexioAsJoinedGroupOnlyHomeListTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 11),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '产品测试群',
          avatarUrl: '',
          unreadCount: 3,
          lastActivityAt: null,
          topic: '群聊已创建，等待同步',
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    expect(find.text('消息(3)'), findsNothing);
    expect(find.text('产品测试群'), findsNothing);
    expect(find.text('群聊已创建，等待同步'), findsNothing);
    expect(find.text('3'), findsNothing);
    expect(find.text('还没有会话'), findsOneWidget);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets(
      'contacts hide pending metadata until AS marks the contact accepted',
      (tester) async {
    final client = Client('DirexioPendingContactListTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!pending:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'owner',
      peerMembership: Membership.join,
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!pending:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'pending_outbound',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('通讯录').last);
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets('messages hide unknown raw Matrix rooms after AS bootstrap',
      (tester) async {
    final client = Client('DirexioUnknownRawRoomHomeListTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!raw:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'owner',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Group with'), findsNothing);
    expect(find.text('friend flow accepted message'), findsNothing);
    expect(find.text('还没有会话'), findsOneWidget);
  });

  testWidgets('messages show only canonical AS agent room', (tester) async {
    final client = Client('DirexioCanonicalAgentHomeListTest')
      ..setUserId('@owner:p2p-im.com');
    final canonicalRoom = _addHeroSummaryRoom(
      client,
      roomId: '!agent-canonical:p2p-im.com',
      peerMxid: '@agent:p2p-im.com',
      peerName: 'Agent',
    );
    canonicalRoom.lastEvent = Event(
      room: canonicalRoom,
      eventId: r'$canonical-agent',
      senderId: '@agent:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime(2026, 5, 27, 20, 1),
      content: {
        'msgtype': MessageTypes.Text,
        'body': 'canonical agent message',
      },
    );
    final legacyRoom = _addHeroSummaryRoom(
      client,
      roomId: '!agent-legacy:p2p-im.com',
      peerMxid: '@agent:p2p-im.com',
      peerName: 'Agent',
    );
    legacyRoom.lastEvent = Event(
      room: legacyRoom,
      eventId: r'$legacy-agent',
      senderId: '@agent:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime(2026, 5, 27, 20, 2),
      content: {
        'msgtype': MessageTypes.Text,
        'body': 'legacy agent message',
      },
    );
    final bootstrap = AsSyncBootstrap.fromJson({
      'synced_at': DateTime.utc(2026, 5, 27, 10).toIso8601String(),
      'agent_room_id': '!agent-canonical:p2p-im.com',
      'user': {'user_id': '@owner:p2p-im.com'},
      'rooms': [],
      'contacts': [],
      'groups': [],
      'channels': [],
      'pending': {},
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    expect(find.text('Agent'), findsOneWidget);
    expect(find.text('canonical agent message'), findsOneWidget);
    expect(find.text('legacy agent message'), findsNothing);
  });

  testWidgets('messages Agent tap uses bootstrap agent room id',
      (tester) async {
    final client = Client('DirexioCanonicalAgentTapTest')
      ..setUserId('@owner:p2p-im.com');
    _addHeroSummaryRoom(
      client,
      roomId: '!agent-old:p2p-im.com',
      peerMxid: '@agent:p2p-im.com',
      peerName: 'Agent',
    );
    final bootstrap = AsSyncBootstrap.fromJson({
      'synced_at': DateTime.utc(2026, 5, 27, 10).toIso8601String(),
      'agent_room_id': '!agent-new:p2p-im.com',
      'user': {'user_id': '@owner:p2p-im.com'},
      'rooms': [],
      'contacts': [],
      'groups': [],
      'channels': [],
      'pending': {},
    });
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, state) => Text(
            'agent route ${state.pathParameters['roomId']};'
            'conversation ${state.uri.queryParameters['conversation']}',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(
            _ConversationListAsClient(const [
              AsConversation(
                conversationId: 'conv_agent',
                roomId: '!agent-old:p2p-im.com',
                kind: asConversationKindAgent,
                lifecycle: 'active',
                title: 'Agent',
                avatarUrl: '',
                capabilities: AsConversationCapabilities(open: true),
              ),
            ]),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agent'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'agent route !agent-new:p2p-im.com;'
        'conversation bootstrap:!agent-new:p2p-im.com',
      ),
      findsOneWidget,
    );
  });

  testWidgets('contacts Agent tap refreshes bootstrap before unsynced notice',
      (tester) async {
    final client = Client(
      'DirexioAgentContactRefreshTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'test-token';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 22, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      agentRoomId: '!agent-room:p2p-im.com',
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _StaticBootstrapAsClient(bootstrap);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, state) => Text(
            'agent route ${state.pathParameters['roomId']}',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asBootstrapRepositoryProvider.overrideWithValue(
            AsBootstrapRepository(
              loadBootstrap: asClient.syncBootstrap,
              store: _MemoryAsBootstrapStore(),
            ),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('通讯录'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('contacts_agent_entry')));
    await tester.pumpAndSettle();

    expect(find.text('Agent 会话还未同步'), findsNothing);
    expect(find.text('agent route !agent-room:p2p-im.com'), findsOneWidget);
  });

  testWidgets('contacts Agent tap prefers cached login agent room id',
      (tester) async {
    final client = Client('DirexioAgentContactCachedRoomTest')
      ..setUserId('@owner:p2p-im.com');
    _addHeroSummaryRoom(
      client,
      roomId: '!agent-old:p2p-im.com',
      peerMxid: '@agent:p2p-im.com',
      peerName: 'Agent',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      agentRoomId: '!agent-login:p2p-im.com',
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, state) => Text(
            'agent route ${state.pathParameters['roomId']}',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('通讯录'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('contacts_agent_entry')));
    await tester.pumpAndSettle();

    expect(find.text('agent route !agent-login:p2p-im.com'), findsOneWidget);
    expect(find.text('agent route !agent-old:p2p-im.com'), findsNothing);
  });

  testWidgets('contacts Agent tap opens existing Matrix room without agent id',
      (tester) async {
    var createRoomCalls = 0;
    final client = Client(
      'DirexioAgentContactNoCreateRoomTest',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/createRoom')) {
          createRoomCalls++;
          return http.Response(
            '{"errcode":"M_FORBIDDEN","error":"create disabled"}',
            403,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'test-token';
    _addHeroSummaryRoom(
      client,
      roomId: '!agent-old:p2p-im.com',
      peerMxid: '@agent:p2p-im.com',
      peerName: 'Agent',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 11),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      agentRoomId: '',
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _StaticBootstrapAsClient(bootstrap);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, state) => Text(
            'agent route ${state.pathParameters['roomId']}',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asBootstrapRepositoryProvider.overrideWithValue(
            AsBootstrapRepository(
              loadBootstrap: asClient.syncBootstrap,
              store: _MemoryAsBootstrapStore(),
            ),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('通讯录'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('contacts_agent_entry')));
    await tester.pumpAndSettle();

    expect(createRoomCalls, 0);
    expect(find.text('Agent 会话还未同步'), findsNothing);
    expect(find.text('agent route !agent-old:p2p-im.com'), findsOneWidget);
  });

  testWidgets('contacts Agent tap warns when no Agent room exists',
      (tester) async {
    var createRoomCalls = 0;
    final client = Client(
      'DirexioAgentContactNoRoomTest',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/createRoom')) {
          createRoomCalls++;
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'test-token';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      agentRoomId: '',
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _StaticBootstrapAsClient(bootstrap);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, state) => Text(
            'agent route ${state.pathParameters['roomId']}',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asBootstrapRepositoryProvider.overrideWithValue(
            AsBootstrapRepository(
              loadBootstrap: asClient.syncBootstrap,
              store: _MemoryAsBootstrapStore(),
            ),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('通讯录'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('contacts_agent_entry')));
    await tester.pumpAndSettle();

    expect(createRoomCalls, 0);
    expect(find.text('Agent 会话还未同步'), findsOneWidget);
    expect(find.text('agent route !agent:p2p-im.com'), findsNothing);
  });

  testWidgets('contacts list keeps each friend avatar separate',
      (tester) async {
    final client = Client('DirexioContactsDistinctAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!alice:p2p-im.com',
      peerMxid: '@alice:p2p-im.com',
      peerName: 'Alice',
      peerAvatarUrl: 'https://example.com/alice.png',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 14),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: 'https://example.com/alice-as.png',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
        AsSyncContact(
          userId: '@bob:p2p-im.com',
          displayName: 'Bob',
          avatarUrl: 'https://example.com/bob-as.png',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/contact/:userId',
          builder: (_, state) => Text(
            'contact route ${state.pathParameters['userId']} '
            'source ${state.uri.queryParameters['source']}',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('通讯录'));
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.seed == 'Alice' &&
            widget.imageUrl == 'https://example.com/alice.png',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.seed == 'Bob' &&
            widget.imageUrl == 'https://example.com/bob-as.png',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(
      find.text('contact route @alice:p2p-im.com source chat_avatar'),
      findsOneWidget,
    );
  });

  testWidgets('contacts list falls back to Matrix direct room avatar',
      (tester) async {
    final client = Client('DirexioContactsMatrixAvatarFallbackTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!alice:p2p-im.com',
      peerMxid: '@alice:p2p-im.com',
      peerName: 'Alice',
      peerAvatarUrl: 'https://example.com/alice-matrix.png',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 14),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('通讯录'));
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.seed == 'Alice' &&
            widget.imageUrl == 'https://example.com/alice-matrix.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('create group contact avatars do not reuse another friend avatar',
      (tester) async {
    final client = Client('DirexioCreateGroupDistinctAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!alice:p2p-im.com',
      peerMxid: '@alice:p2p-im.com',
      peerName: 'Alice',
      peerAvatarUrl: 'https://example.com/alice.png',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 14),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: 'https://example.com/alice-as.png',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
        AsSyncContact(
          userId: '@bob:p2p-im.com',
          displayName: 'Bob',
          avatarUrl: 'https://example.com/bob-as.png',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/groups',
      routes: [
        GoRoute(path: '/groups', builder: (_, __) => const GroupsListPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.group_add));
    await tester.pumpAndSettle();

    expect(find.text('发起群聊'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.seed == 'Alice' &&
            widget.imageUrl == 'https://example.com/alice.png',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.seed == 'Bob' &&
            widget.imageUrl == 'https://example.com/bob-as.png',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.seed == 'Bob' &&
            widget.imageUrl == 'https://example.com/alice.png',
      ),
      findsNothing,
    );
  });

  testWidgets('create group name field shows selected friends without avatars',
      (tester) async {
    final client = Client('DirexioCreateGroupNameFieldInitialsTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 24, 16),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
        AsSyncContact(
          userId: '@bob:p2p-im.com',
          displayName: 'Bob',
          avatarUrl: '',
          roomId: '!bob:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/groups',
      routes: [
        GoRoute(path: '/groups', builder: (_, __) => const GroupsListPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith(
            (ref) async => Profile(
              userId: '@owner:p2p-im.com',
              displayName: 'Owner',
              avatarUrl: Uri.parse('mxc://p2p-im.com/owner-avatar'),
            ),
          ),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.group_add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice'));
    await tester.tap(find.text('Bob'));
    await tester.pump();
    await tester.tap(find.text('完成(2)'));
    await tester.pumpAndSettle();

    final composite = find.byKey(
      const ValueKey('create_group_composite_avatar'),
    );
    expect(composite, findsOneWidget);
    expect(
      find.descendant(
        of: composite,
        matching: find.byWidgetPredicate(
          (widget) => widget is PortalAvatar && widget.seed == 'Alice',
        ),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: composite,
        matching: find.byWidgetPredicate(
          (widget) => widget is PortalAvatar && widget.seed == 'Bob',
        ),
      ),
      findsNothing,
    );
    final avatarSeeds = tester
        .widgetList<PortalAvatar>(
          find.descendant(of: composite, matching: find.byType(PortalAvatar)),
        )
        .map((avatar) => avatar.seed)
        .toList(growable: false);
    expect(avatarSeeds, ['我']);
    final ownerAvatarFinder =
        find.descendant(of: composite, matching: find.byType(PortalAvatar));
    final ownerAvatar = tester.widget<PortalAvatar>(ownerAvatarFinder.first);
    expect(ownerAvatar.size, closeTo(23.5, 0.001));
    expect(ownerAvatar.imageUrl, contains('/download/p2p-im.com/owner-avatar'));
    expect(tester.getTopLeft(ownerAvatarFinder.first),
        tester.getTopLeft(composite));
  });

  testWidgets('messages hide duplicate Matrix direct rooms not accepted by AS',
      (tester) async {
    final client = Client('DirexioDuplicateDirectRoomHomeListTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!canonical:p2p-liyanan.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
    );
    final duplicateRoom = _addUndirectedJoinedRoom(
      client,
      roomId: '!duplicate:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'default owner',
    );
    duplicateRoom.lastEvent = Event(
      room: duplicateRoom,
      eventId: r'$duplicate',
      senderId: '@owner:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime(2026, 5, 27, 23, 41),
      content: {
        'msgtype': MessageTypes.Notice,
        'body': 'duplicate accepted notice',
      },
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _ConversationListAsClient(const [
      AsConversation(
        conversationId: 'conv_canonical',
        roomId: '!canonical:p2p-liyanan.com',
        kind: asConversationKindDirect,
        lifecycle: 'active',
        title: 'Yanan',
        avatarUrl: '',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    expect(find.text('Yanan'), findsWidgets);
    expect(find.text('duplicate accepted notice'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets(
      'messages prefer new local accepted room over stale bootstrap room',
      (tester) async {
    final client = Client('DirexioLocalAcceptedShadowsBootstrapHomeTest')
      ..setUserId('@owner:p2p-im.com');
    final oldRoom = _addUndirectedJoinedRoom(
      client,
      roomId: '!old:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
    );
    oldRoom.lastEvent = Event(
      room: oldRoom,
      eventId: r'$old-history',
      senderId: '@owner:p2p-liyanan.com',
      type: EventTypes.Message,
      originServerTs: DateTime(2026, 5, 28, 10),
      content: {
        'msgtype': MessageTypes.Text,
        'body': 'old private history',
      },
    );
    final newRoom = _addUndirectedJoinedRoom(
      client,
      roomId: '!new:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
    );
    newRoom.lastEvent = Event(
      room: newRoom,
      eventId: r'$new-room',
      senderId: '@owner:p2p-liyanan.com',
      type: EventTypes.Message,
      originServerTs: DateTime(2026, 5, 28, 11),
      content: {
        'msgtype': MessageTypes.Text,
        'body': 'fresh accepted room',
      },
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 28, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'Yanan',
          avatarUrl: '',
          roomId: '!old:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final syncState = AsSyncCacheState(bootstrap: bootstrap).withContactEntry(
      const ContactEntry(
        peerMxid: '@owner:p2p-liyanan.com',
        displayName: 'Yanan',
        domain: 'p2p-liyanan.com',
        roomId: '!new:p2p-im.com',
        status: 'accepted',
      ),
    );
    final asClient = _ConversationListAsClient(const [
      AsConversation(
        conversationId: 'conv_new',
        roomId: '!new:p2p-im.com',
        kind: asConversationKindDirect,
        lifecycle: 'active',
        title: 'Yanan',
        avatarUrl: '',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith((ref) => syncState),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    expect(find.text('Yanan'), findsWidgets);
    expect(find.text('fresh accepted room'), findsOneWidget);
    expect(find.text('old private history'), findsNothing);
  });

  testWidgets('contacts hide duplicate Matrix direct rooms not accepted by AS',
      (tester) async {
    final client = Client('DirexioDuplicateDirectContactListTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!canonical:p2p-liyanan.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
    );
    _addUndirectedJoinedRoom(
      client,
      roomId: '!duplicate:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'default owner',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'Yanan',
          avatarUrl: '',
          roomId: '!canonical:p2p-liyanan.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('通讯录').last);
    await tester.pumpAndSettle();

    expect(find.text('ID/昵称/邮箱'), findsOneWidget);
    expect(find.text('A'), findsWidgets);
    expect(find.text('Yanan'), findsOneWidget);
    expect(find.text('default owner'), findsNothing);
  });

  testWidgets(
      'messages and contacts hide rejected direct rooms with joined peer',
      (tester) async {
    final client = Client('DirexioRejectedDirectRoomListTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!rejected:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 28, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'Yanan',
          avatarUrl: '',
          roomId: '!rejected:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'rejected',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    expect(find.text('Yanan'), findsNothing);
    expect(find.text('friend flow accepted message'), findsNothing);
    expect(find.text('还没有会话'), findsOneWidget);

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    expect(find.text('ID/昵称/邮箱'), findsOneWidget);
    expect(find.text('Yanan'), findsNothing);
  });

  testWidgets('chat info uses AS contact metadata for undirected direct rooms',
      (tester) async {
    const roomId = '!owner:p2p-im.com';
    const peerMxid = '@owner:p2p-liyanan.com';
    var clipboardText = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboardText = (call.arguments as Map)['text'] as String? ?? '';
            return null;
          case 'Clipboard.getData':
            return {'text': clipboardText};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final client = Client('DirexioChatInfoDirectMetadataTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: roomId,
      peerMxid: peerMxid,
      peerName: 'owner',
    );
    final bootstrapStore = _MemoryAsBootstrapStore();
    final asClient = _TrackingAsClient();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 26, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: peerMxid,
          displayName: 'owner',
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          asBootstrapStoreProvider.overrideWith((ref) async => bootstrapStore),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatInfoPage(roomId: roomId),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('搜索聊天记录'), findsOneWidget);
    expect(find.text('owner'), findsOneWidget);
    expect(find.text(peerMxid), findsOneWidget);
    expect(find.text('推荐给朋友'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);

    await tester.tap(find.text(peerMxid));
    await tester.pump();
    expect(find.text('已复制 UID'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final copied = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copied?.text, peerMxid);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Owner Remark');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('备注已更新'), findsOneWidget);
    expect(asClient.updateContactCalls, 1);
    expect(asClient.updatedContactRoomId, roomId);
    expect(asClient.updatedContactDisplayName, 'Owner Remark');
    expect(asClient.updatedContactDomain, 'p2p-liyanan.com');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('chat info rejects mock conversation ids', (tester) async {
    final client = Client('DirexioChatInfoRejectMockTest')
      ..setUserId('@owner:p2p-im.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatInfoPage(roomId: 'mock_dave'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('会话不存在'), findsOneWidget);
    expect(find.text('Dave Lee'), findsNothing);
    expect(find.text('查找聊天记录'), findsNothing);
  });

  testWidgets('chat info clear room history writes room clear boundary',
      (tester) async {
    const roomId = '!owner:p2p-im.com';
    final client = Client(
      'DirexioChatInfoClearHistoryTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    _addUndirectedJoinedRoom(
      client,
      roomId: roomId,
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'owner',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 26, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'owner',
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
    final clearStore = _MemoryChatClearStateStore();
    final asClient = _TrackingAsClient();
    final visibilityClient = _RecordingMatrixMessageVisibilityClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          matrixMessageVisibilityClientProvider.overrideWithValue(
            visibilityClient,
          ),
          chatClearStateStoreProvider.overrideWith((ref) async => clearStore),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatInfoPage(roomId: roomId),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('清空聊天记录'));
    await tester.tap(find.text('清空聊天记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '清空'));
    await tester.pumpAndSettle();

    expect(visibilityClient.clearCalls, 1);
  });

  testWidgets('home starts app warmup on launch', (tester) async {
    final client = Client('DirexioTest');
    var warmupCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          appWarmupProvider.overrideWith((ref) async {
            warmupCalls++;
          }),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    expect(warmupCalls, 1);
  });

  test('app warmup preloads current user and recent room avatars', () async {
    final client = Client('DirexioTest')
      ..homeserver = Uri.parse('https://hs.example.com');
    final room = Room(
      id: '!room:example.com',
      client: client,
      membership: Membership.join,
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomAvatar,
        senderId: '@owner:example.com',
        stateKey: '',
        content: {'url': 'https://cdn.example.com/room.png'},
      ),
    );
    client.rooms.add(room);

    final preloader = _RecordingAvatarPreloader();
    final service = AppWarmupService(
      client: client,
      avatarPreloader: preloader,
      loadCurrentUserProfile: () async => Profile(
        userId: '@owner:example.com',
        displayName: 'Owner',
        avatarUrl: Uri.parse('https://cdn.example.com/me.png'),
      ),
    );

    await service.warmup();

    expect(preloader.urls, [
      'https://cdn.example.com/me.png',
      'https://cdn.example.com/room.png',
    ]);
  });

  testWidgets('primary glass header defaults to neutral title color',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: GlassHeader.primary(title: '标题'),
        ),
      ),
    );

    expect(
      tester.widget<Text>(_headerTitle('标题')).style?.color,
      PortalTokens.light.text,
    );
  });

  testWidgets('main content page titles use the same neutral color',
      (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    for (final title in ['消息', '通讯录']) {
      if (title != '消息') {
        await tester.tap(find.text(title).last);
        await tester.pump();
      }
      expect(
        tester.widget<Text>(_headerTitle(title)).style?.color,
        PortalTokens.light.text,
      );
    }
  });

  testWidgets('messages contacts and channel share header actions',
      (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_PendingChannelReviewAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(
              bootstrap: AsSyncBootstrap(
                syncedAt: DateTime.utc(2026, 6, 25),
                user: const AsSyncUser(userId: '@owner:p2p-im.com'),
                rooms: const [],
                contacts: const [
                  AsSyncContact(
                    userId: '@pending:p2p-im.com',
                    displayName: '待审核用户',
                    avatarUrl: 'https://cdn.example.com/pending-review.png',
                    roomId: '!pending:p2p-im.com',
                    domain: 'p2p-im.com',
                    status: 'accepted',
                  ),
                ],
                groups: const [],
                channels: const [],
                pending: const AsSyncPending.empty(),
              ),
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    for (final title in ['消息', '通讯录', '频道']) {
      if (title != '消息') {
        await tester.tap(find.text(title).last);
        await tester.pump();
      }
      if (title == '频道') {
        expect(find.byKey(const ValueKey('channel_search_button')),
            findsOneWidget);
        expect(
            find.byKey(const ValueKey('channel_post_button')), findsOneWidget);
      } else {
        expect(find.byIcon(Symbols.add), findsOneWidget);
      }
    }
  });

  testWidgets('third home tab is channel without explore subpages',
      (tester) async {
    final client = Client('DirexioChannelTabTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    expect(find.text('探索'), findsNothing);
    expect(find.text('频道'), findsOneWidget);

    await tester.tap(find.text('频道'));
    await tester.pump();

    expect(find.text('关注'), findsNothing);
    expect(find.text('Agent'), findsNothing);
    expect(find.byType(PageView), findsNothing);
    expect(find.text('已加入'), findsNothing);
    expect(find.text('我创建'), findsNothing);
    expect(find.text('频道列表'), findsNothing);
    expect(find.text('全部'), findsNothing);
    expect(find.text('#综合讨论'), findsNothing);
    expect(find.text('#新手问答'), findsNothing);
    expect(find.text('还没有频道'), findsOneWidget);
    expect(find.text('草稿箱'), findsNothing);
    expect(find.byIcon(Symbols.search), findsOneWidget);
    expect(find.byKey(const ValueKey('channel_post_button')), findsOneWidget);
  });

  testWidgets('channel tab matches figma header controls', (tester) async {
    final client = Client('DirexioChannelHeaderTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('频道'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('channel_tab_title')), findsOneWidget);
    expect(find.byKey(const ValueKey('channel_search_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('channel_filter_bar')), findsNothing);
    expect(find.text('已加入'), findsNothing);
    expect(find.text('我创建'), findsNothing);
    expect(find.text('全部'), findsNothing);
    expect(find.byKey(const ValueKey('channel_post_button')), findsOneWidget);
  });

  testWidgets('me channels page shows only owned channel inbox items',
      (tester) async {
    final client = Client('DirexioMeChannelsTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 17, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'owned-channel',
          roomId: '!owned:p2p-im.com',
          name: '我创建的频道',
          avatarUrl: '',
          unreadCount: 2,
          lastActivityAt: DateTime.utc(2026, 1, 2, 9, 30),
          description: '频道列表 item 样式',
          isOwned: true,
          tags: const ['文字'],
        ),
        AsSyncRoomSummary(
          channelId: 'joined-channel',
          roomId: '!joined:p2p-im.com',
          name: '我加入的频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.utc(2026, 1, 3, 9),
          description: '不应该显示',
          isOwned: false,
          tags: const ['帖子'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const MeChannelsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('我的频道'), findsOneWidget);
    expect(find.text('已加入'), findsOneWidget);
    expect(find.text('我创建'), findsOneWidget);
    expect(find.byKey(const ValueKey('channel_inbox_tile_owned-channel')),
        findsOneWidget);
    expect(find.text('我创建的频道'), findsOneWidget);
    expect(find.text('频道列表 item 样式'), findsNothing);
    expect(find.text('1/2'), findsNothing);
    expect(find.text('我加入的频道'), findsNothing);
    expect(find.byKey(const ValueKey('channel_inbox_tile_joined-channel')),
        findsNothing);

    await tester.tap(find.text('已加入'));
    await tester.pump();

    expect(find.text('我加入的频道'), findsOneWidget);
    expect(find.byKey(const ValueKey('channel_inbox_tile_joined-channel')),
        findsOneWidget);
    expect(find.text('我创建的频道'), findsNothing);
    expect(find.text('1/3'), findsNothing);
  });

  testWidgets('channel search page matches figma empty state', (tester) async {
    final client = Client('DirexioChannelSearchTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child:
            MaterialApp(theme: AppTheme.light, home: const ChannelSearchPage()),
      ),
    );
    await tester.pump();

    expect(find.text('搜索频道...'), findsOneWidget);
    expect(find.text('搜索频道'), findsOneWidget);
    expect(find.text('输入频道ID查找频道'), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_back), findsOneWidget);
    expect(find.byIcon(Symbols.search), findsWidgets);
    for (final label in ['消息', '通讯录', '频道', '我的']) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('channel search keeps Matrix room id lookup on configured AS',
      (tester) async {
    final client = Client('DirexioChannelSearchRoomIdTargetTest');
    final asClient = _EmptyAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(asClient),
        ],
        child:
            MaterialApp(theme: AppTheme.light, home: const ChannelSearchPage()),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byType(M3SearchField),
      '!room123:node.example.com',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.lastPublicChannelLookupBaseUri, isNull);
  });

  testWidgets('channel search uses IM public list for keywords',
      (tester) async {
    final client = Client('DirexioChannelSearchUnifiedTest');
    final asClient = _EmptyAsClient();
    final imPublicClient = _WidgetImPublicClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(asClient),
          imPublicClientProvider.overrideWithValue(imPublicClient),
        ],
        child:
            MaterialApp(theme: AppTheme.light, home: const ChannelSearchPage()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(M3SearchField), 'garden');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.lastPublicChannelSearchQuery, isNull);
    expect(imPublicClient.lastName, 'garden');
    expect(find.text('garden'), findsWidgets);
  });

  testWidgets('create channel entry opens figma form', (tester) async {
    final client = Client('DirexioCreateChannelTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('频道'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('channel_post_button')));
    await tester.pumpAndSettle();

    expect(find.text('创建频道'), findsWidgets);
    expect(find.text('频道名称'), findsOneWidget);
    expect(find.text('请输入'), findsOneWidget);
    expect(find.text('上传频道头像'), findsOneWidget);
    expect(find.text('支持图片上传，作为频道展示头像'), findsOneWidget);
    expect(find.text('选择频道类型'), findsOneWidget);
    expect(find.text('文字'), findsAtLeastNWidgets(1));
    expect(find.text('帖子'), findsAtLeastNWidgets(1));
    final accent = AppTheme.light.extension<PortalTokens>()!.accent;
    final selectedTypeBorder = find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      if (decoration is! BoxDecoration) return false;
      final border = decoration.border;
      return border is Border &&
          border.top.color == accent &&
          border.top.width == 1.5;
    });
    expect(selectedTypeBorder, findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -260));
    await tester.pump();
    expect(find.text('频道权限'), findsOneWidget);
    expect(find.text('是否公开'), findsOneWidget);
    expect(find.text('加入是否需要审核'), findsOneWidget);
  });

  test('create channel join policy follows approval switch', () {
    expect(
      createChannelJoinPolicyForApproval(true),
      asChannelJoinPolicyApproval,
    );
    expect(
      createChannelJoinPolicyForApproval(false),
      asChannelJoinPolicyOpen,
    );
  });

  test('create channel directory domain prefers reachable homeserver', () {
    const channel = AsChannel(
      channelId: 'ch_local',
      roomId: '!local:host.docker.internal:18448',
      homeDomain: 'host.docker.internal:18448',
      name: 'Local public channel',
    );

    expect(
      channelDirectoryDomainForCreatedChannel(
        channel,
        Uri.parse('http://127.0.0.1:18008/_matrix/client'),
      ),
      'http://127.0.0.1:18008',
    );
    expect(
      channelDirectoryDomainForCreatedChannel(channel, null),
      'https://host.docker.internal:18448',
    );
  });

  testWidgets('create channel empty name stays on form with prompt',
      (tester) async {
    final client = Client('DirexioCreateChannelEmptyNameTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('频道'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('channel_post_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('创建频道').last);
    await tester.pump();

    expect(find.text('频道名称不能为空'), findsAtLeastNWidgets(1));
    expect(find.text('频道名称'), findsOneWidget);
    expect(find.text('上传频道头像'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
  });

  testWidgets('channel review entry opens figma review page', (tester) async {
    final client = Client('DirexioChannelReviewTest')
      ..setUserId('@owner:p2p-im.com');
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/channels/review',
          builder: (_, __) => const ChannelReviewPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_PendingChannelReviewAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(
              bootstrap: AsSyncBootstrap(
                syncedAt: DateTime.utc(2026, 6, 25),
                user: const AsSyncUser(userId: '@owner:p2p-im.com'),
                rooms: const [],
                contacts: const [
                  AsSyncContact(
                    userId: '@pending:p2p-im.com',
                    displayName: '待审核用户',
                    avatarUrl: 'https://cdn.example.com/pending-review.png',
                    roomId: '!pending:p2p-im.com',
                    domain: 'p2p-im.com',
                    status: 'accepted',
                  ),
                ],
                groups: const [],
                channels: const [],
                pending: const AsSyncPending.empty(),
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('频道'));
    await tester.pumpAndSettle();
    final reviewButton = find.byKey(const ValueKey('channel_review_button'));
    expect(
      find.descendant(of: reviewButton, matching: find.text('1')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('channel_review_button')));
    await tester.pumpAndSettle();

    expect(find.text('频道审核'), findsAtLeastNWidgets(1));
    expect(find.text('待审核用户'), findsOneWidget);
    expect(find.text('#待审核用户'), findsNothing);
    final avatars = tester.widgetList<PortalAvatar>(find.byType(PortalAvatar));
    expect(
      avatars.any(
        (avatar) =>
            avatar.imageUrl == 'https://cdn.example.com/pending-review.png',
      ),
      isTrue,
    );
    expect(find.text('待审核'), findsOneWidget);
    expect(find.text('通过'), findsOneWidget);
    expect(find.text('拒绝'), findsOneWidget);
  });

  testWidgets('channel review page follows app locale', (tester) async {
    final client = Client('DirexioChannelReviewLocaleTest')
      ..setUserId('@owner:p2p-im.com');
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/channels/review',
          builder: (_, __) => const ChannelReviewPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_PendingChannelReviewAsClient()),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Channels'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('channel_review_button')));
    await tester.pumpAndSettle();

    expect(find.text('Channel Review'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('频道审核'), findsOneWidget);
    expect(find.text('待审核'), findsNothing);
    expect(find.text('通过'), findsNothing);
  });

  testWidgets('channel review approve surfaces join failure', (tester) async {
    final client = Client('DirexioChannelReviewJoinFailedTest')
      ..setUserId('@owner:p2p-im.com');
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/channels/review',
          builder: (_, __) => const ChannelReviewPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(
            _PendingChannelReviewAsClient(
              approveStatus: asChannelMemberStatusJoinFailed,
            ),
          ),
          appWarmupProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('频道'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('channel_review_button')));
    await tester.pumpAndSettle();
    final approveButton = find.byKey(
      const ValueKey('channel-review-approve-@pending:p2p-im.com'),
    );
    final approveInkWell = tester.widget<InkWell>(
      find.descendant(of: approveButton, matching: find.byType(InkWell)),
    );
    approveInkWell.onTap!();
    await tester.pumpAndSettle();

    expect(find.text('加入失败'), findsOneWidget);
    expect(find.text('已加入'), findsNothing);
    expect(find.text('已同意'), findsNothing);
  });

  testWidgets('channel review button ignores AS channel invite notices',
      (tester) async {
    final client = Client('DirexioChannelNoticeBadgeTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending(
        friendRequests: [],
        groupInvites: [],
        channelNotices: [
          AsSyncPendingItem(
            id: 'ch_pending_application',
            title: '频道申请',
            createdAt: null,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('频道').last);
    await tester.pump();

    final reviewButton = find.byKey(const ValueKey('channel_review_button'));
    expect(reviewButton, findsOneWidget);
    expect(
      find.descendant(of: reviewButton, matching: find.text('1')),
      findsNothing,
    );
  });

  testWidgets('home plus menu has the unified action order', (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('chat_input_plus_circle')));
    await tester.pumpAndSettle();

    expect(find.text('文件传输'), findsNothing);
    for (final label in ['添加好友', '创建群聊', '创建频道', '扫一扫']) {
      expect(find.text(label), findsOneWidget);
    }

    final positions = [
      for (final label in ['添加好友', '创建群聊', '创建频道', '扫一扫'])
        tester.getTopLeft(find.text(label)).dy,
    ];
    expect(positions, orderedEquals([...positions]..sort()));
  });

  testWidgets('home plus menu uses dark surface in dark mode', (tester) async {
    final client = Client('DirexioHomePlusDarkTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const HomePage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('chat_input_plus_circle')));
    await tester.pumpAndSettle();

    final panel = tester.widget<Container>(
      find.byKey(const ValueKey('home_plus_menu_panel')),
    );
    final decoration = panel.decoration! as BoxDecoration;
    expect(
      decoration.color,
      PortalTokens.dark.surfaceHigh.withValues(alpha: 0.86),
    );
    expect(find.text('添加好友'), findsOneWidget);
  });

  testWidgets('home plus group creation uses accepted contacts and opens group',
      (tester) async {
    final asClient = _TrackingAsClient()
      ..createdGroupProductConversation = const AsConversation(
        conversationId: 'conv_new_group',
        roomId: '!new-group:p2p-im.com',
        kind: asConversationKindGroup,
        lifecycle: 'active',
        title: '项目群',
        avatarUrl: '',
        capabilities: AsConversationCapabilities(open: true),
      );
    final client = Client('DirexioHomeGroupCreateTest')
      ..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';

    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-liyanan.com',
          displayName: 'Alice Chen',
          avatarUrl: 'https://example.com/alice.png',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
        AsSyncContact(
          userId: '@pending:p2p-liyanan.com',
          displayName: 'Pending User',
          avatarUrl: '',
          roomId: '!pending:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'pending_outbound',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/group/:roomId',
          builder: (_, state) => Scaffold(
            body: Text(
              'group:${state.pathParameters['roomId']!};'
              'conversation:${state.uri.queryParameters['conversation']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          groupCreationSyncAfterCreateProvider.overrideWithValue(false),
          voiceCallControllerProvider.overrideWithValue(
            _IdleVoiceCallController(),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Symbols.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建群聊').last);
    await tester.pumpAndSettle();

    expect(find.text('发起群聊'), findsOneWidget);
    expect(find.text('Alice Chen'), findsWidgets);
    expect(find.text('Pending User'), findsNothing);
    expect(
      tester
          .widgetList<PortalAvatar>(find.byType(PortalAvatar))
          .any((avatar) => avatar.imageUrl == 'https://example.com/alice.png'),
      isTrue,
    );

    await tester.tap(find.text('Alice Chen').last);
    await tester.pump();
    await tester.tap(find.text('完成(1)'));
    await tester.pumpAndSettle();

    expect(find.text('创建群聊'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('create_group_name_field')),
      findsOneWidget,
    );
    expect(find.text('群成员'), findsOneWidget);
    expect(find.text('1人'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('create_group_name_field')),
      '项目群',
    );
    await tester.pump();
    await tester.tap(find.text('完成创建'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(asClient.createdGroupName, '项目群');
    expect(asClient.createdGroupInvites, ['@alice:p2p-liyanan.com']);
    expect(find.text('群组不存在'), findsNothing);
    expect(
      find.text('group:!new-group:p2p-im.com;conversation:conv_new_group'),
      findsOneWidget,
    );
  });

  testWidgets(
      'home plus group creation falls back when ProductCore conversation is absent',
      (tester) async {
    final asClient = _TrackingAsClient();
    final snapshotStore = _MemoryConversationSummaryStore();
    final client = Client('DirexioHomeGroupCreateFallbackTest')
      ..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';

    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-liyanan.com',
          displayName: 'Alice Chen',
          avatarUrl: '',
          roomId: '!direct-alice:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/group/:roomId',
          builder: (_, state) => Scaffold(
            body: Text(
              'group:${state.pathParameters['roomId']!};'
              'conversation:${state.uri.queryParameters['conversation']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          groupCreationSyncAfterCreateProvider.overrideWithValue(false),
          voiceCallControllerProvider.overrideWithValue(
            _IdleVoiceCallController(),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          conversationSummaryStoreProvider.overrideWith(
            (ref) async => snapshotStore,
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Symbols.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建群聊').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice Chen').last);
    await tester.pump();
    await tester.tap(find.text('完成(1)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('create_group_name_field')),
      '项目群',
    );
    await tester.pump();
    await tester.tap(find.text('完成创建'));
    await tester.pumpAndSettle();

    expect(asClient.createdGroupName, '项目群');
    expect(
      find.text(
        'group:!new-group:p2p-im.com;conversation:group:!new-group:p2p-im.com',
      ),
      findsOneWidget,
    );

    router.go('/home');
    await tester.pumpAndSettle();

    expect(find.text('项目群'), findsOneWidget);
  });

  testWidgets('missing group page keeps a usable back button', (tester) async {
    final client = Client('DirexioMissingGroupBackTest')
      ..setUserId('@owner:p2p-im.com');
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HomeRoot')),
        ),
        GoRoute(
          path: '/group/:roomId',
          builder: (_, state) => GroupChatPage(
            roomId: state.pathParameters['roomId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    router.push('/group/${Uri.encodeComponent('!missing:p2p-im.com')}');
    await tester.pumpAndSettle();

    expect(find.text('群聊不存在'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('HomeRoot'), findsOneWidget);
  });

  testWidgets('contacts empty state does not render mock friends',
      (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    expect(find.text('ID/昵称/邮箱'), findsOneWidget);
    expect(find.text('Alice Chen'), findsNothing);
    expect(find.text('Bob Smith'), findsNothing);
    expect(find.text('Dave Lee'), findsNothing);
    expect(find.text('Eve Wang'), findsNothing);
    expect(find.text('Jack'), findsNothing);
  });

  testWidgets('contacts use Matrix member avatar when AS avatar is empty',
      (tester) async {
    final client = Client('DirexioContactsMatrixAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!alice:p2p-im.com',
      peerMxid: '@alice:p2p-liyanan.com',
      peerName: 'Alice',
      peerAvatarUrl: 'https://matrix.example.com/alice.png',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 16, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-liyanan.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.size == 28 &&
            widget.imageUrl == 'https://matrix.example.com/alice.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'contacts use direct room profile avatar when member avatar empty',
      (tester) async {
    final client = Client('DirexioContactsProfileAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!alice-profile:p2p-im.com',
      peerMxid: '@alice:p2p-liyanan.com',
      peerName: 'Alice',
      peerAvatarUrl: 'https://profile.example.com/alice.png',
      includePeerMemberAvatar: false,
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-liyanan.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice-profile:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.size == 28 &&
            widget.imageUrl == 'https://profile.example.com/alice.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('contact action shortcuts match contact design', (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    expect(find.text('新朋友'), findsOneWidget);
    expect(find.text('新的群聊'), findsNothing);
    expect(find.text('我的群组'), findsOneWidget);
    expect(find.text('关注'), findsNothing);
  });

  testWidgets('contact page has inline search box', (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    expect(find.text('ID/昵称/邮箱'), findsOneWidget);
  });

  testWidgets('new friend badge counts AS pending inbound contacts',
      (tester) async {
    final client = Client('DirexioInviteBadgeTest')
      ..setUserId('@owner:p2p-im.com');
    final readStore = _MemoryFriendRequestReadStore();
    _addTestRoom(
      client,
      roomId: '!group-invite:p2p-im.com',
      roomMembership: Membership.invite,
    );
    _addTestRoom(
      client,
      roomId: '!agent-invite:p2p-im.com',
      roomMembership: Membership.invite,
      directPeerMxid: '@agent:p2p-im.com',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_StatefulPendingContactAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(
              bootstrap: _pendingFriendRequestBootstrap(),
            ),
          ),
          friendRequestReadStoreProvider.overrideWith((ref) async => readStore),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    expect(find.text('新朋友'), findsOneWidget);
    final contactSectionBadge =
        find.byKey(const ValueKey('section_action_badge_新朋友'));
    expect(contactSectionBadge, findsOneWidget);
  });

  testWidgets('new friend badge counts AS pending friend request notices',
      (tester) async {
    final client = Client('DirexioPendingFriendNoticeBadgeTest')
      ..setUserId('@owner:p2p-im.com');
    final readStore = _MemoryFriendRequestReadStore();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 19, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending(
        friendRequests: [
          AsSyncPendingItem(
            id: '!pending-notice:p2p-im.com',
            title: 'Alice',
            createdAt: null,
          ),
        ],
        groupInvites: [],
        channelNotices: [],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          friendRequestReadStoreProvider.overrideWith((ref) async => readStore),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('bottom_nav_badge_通讯录')), findsOneWidget);

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    final contactSectionBadge =
        find.byKey(const ValueKey('section_action_badge_新朋友'));
    expect(contactSectionBadge, findsOneWidget);
    expect(
      find.descendant(of: contactSectionBadge, matching: find.text('1')),
      findsOneWidget,
    );
  });

  testWidgets('new friend badge reappears for a renewed inbound request',
      (tester) async {
    final client = Client('DirexioRenewedFriendRequestBadgeTest')
      ..setUserId('@owner:p2p-im.com');
    final readStore = _MemoryFriendRequestReadStore()
      ..ids = {'!renewed:p2p-im.com@1000'};
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 19, 13),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!renewed:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'pending_inbound',
          visibleAfterTs: 2000,
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          friendRequestReadStoreProvider.overrideWith((ref) async => readStore),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('bottom_nav_badge_通讯录')), findsOneWidget);

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    final contactSectionBadge =
        find.byKey(const ValueKey('section_action_badge_新朋友'));
    expect(contactSectionBadge, findsOneWidget);
    expect(
      find.descendant(of: contactSectionBadge, matching: find.text('1')),
      findsOneWidget,
    );
  });

  testWidgets('new friend badge ignores AS group invites and channel notices',
      (tester) async {
    final client = Client('DirexioPendingRoomInviteBadgeTest')
      ..setUserId('@owner:p2p-im.com');
    final readStore = _MemoryFriendRequestReadStore();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 20, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending(
        friendRequests: [],
        groupInvites: [
          AsSyncPendingItem(
            id: '!pending-group:p2p-im.com',
            title: '项目群',
            createdAt: null,
          ),
        ],
        channelNotices: [
          AsSyncPendingItem(
            id: '!pending-channel:p2p-im.com',
            title: '产品频道',
            createdAt: null,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          friendRequestReadStoreProvider.overrideWith((ref) async => readStore),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('bottom_nav_badge_通讯录')), findsNothing);

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('section_action_badge_新朋友')),
      findsNothing,
    );
  });

  testWidgets('new friend badge refreshes AS pending notices after Matrix sync',
      (tester) async {
    final client = Client('DirexioPendingFriendNoticeSyncTest')
      ..setUserId('@owner:p2p-im.com');
    final readStore = _MemoryFriendRequestReadStore();
    final asClient = _RefreshingFriendRequestBootstrapAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          friendRequestReadStoreProvider.overrideWith((ref) async => readStore),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(asClient.syncBootstrapCalls, 1);
    expect(find.byKey(const ValueKey('bottom_nav_badge_通讯录')), findsNothing);

    asClient.showPendingFriendRequest = true;
    _addTestRoom(
      client,
      roomId: '!pending-live:p2p-im.com',
      roomMembership: Membership.invite,
      directPeerMxid: '@alice:p2p-im.com',
      directPeerMembership: Membership.invite,
    );
    await tester.pump(const Duration(seconds: 9));
    await client.handleSync(SyncUpdate(nextBatch: 'friend-request'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.syncBootstrapCalls, 2);
    expect(find.byKey(const ValueKey('bottom_nav_badge_通讯录')), findsOneWidget);

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    final contactSectionBadge =
        find.byKey(const ValueKey('section_action_badge_新朋友'));
    expect(contactSectionBadge, findsOneWidget);
    expect(
      find.descendant(of: contactSectionBadge, matching: find.text('1')),
      findsOneWidget,
    );
  });

  testWidgets(
      'new friend badge refreshes AS pending notices without Matrix sync',
      (tester) async {
    final client = Client('DirexioPendingFriendNoticeLiveRefreshTest')
      ..setUserId('@owner:p2p-im.com');
    final readStore = _MemoryFriendRequestReadStore();
    final asClient = _RefreshingFriendRequestBootstrapAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asBootstrapLiveRefreshIntervalProvider.overrideWithValue(
            const Duration(seconds: 1),
          ),
          friendRequestReadStoreProvider.overrideWith((ref) async => readStore),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(asClient.syncBootstrapCalls, 1);
    expect(find.byKey(const ValueKey('bottom_nav_badge_通讯录')), findsNothing);

    asClient.showPendingFriendRequest = true;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.syncBootstrapCalls, 2);
    expect(find.byKey(const ValueKey('bottom_nav_badge_通讯录')), findsOneWidget);
  });

  testWidgets('home does not poll AS bootstrap by default while idle',
      (tester) async {
    final client = Client('DirexioPendingFriendNoticeNoDefaultPollTest')
      ..setUserId('@owner:p2p-im.com');
    final readStore = _MemoryFriendRequestReadStore();
    final asClient = _RefreshingFriendRequestBootstrapAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          friendRequestReadStoreProvider.overrideWith((ref) async => readStore),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(asClient.syncBootstrapCalls, 1);

    asClient.showPendingFriendRequest = true;
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();

    expect(asClient.syncBootstrapCalls, 1);
    expect(find.byKey(const ValueKey('bottom_nav_badge_通讯录')), findsNothing);
  });

  testWidgets('new friend badge ignores refreshed AS pending group invites',
      (tester) async {
    final client = Client('DirexioPendingGroupInviteLiveRefreshTest')
      ..setUserId('@owner:p2p-im.com');
    final readStore = _MemoryFriendRequestReadStore();
    final asClient = _RefreshingFriendRequestBootstrapAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          asBootstrapLiveRefreshIntervalProvider.overrideWithValue(
            const Duration(seconds: 1),
          ),
          friendRequestReadStoreProvider.overrideWith((ref) async => readStore),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(asClient.syncBootstrapCalls, 1);
    expect(find.byKey(const ValueKey('bottom_nav_badge_通讯录')), findsNothing);

    asClient.showPendingGroupInvite = true;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.syncBootstrapCalls, 2);
    expect(find.byKey(const ValueKey('bottom_nav_badge_通讯录')), findsNothing);
  });

  testWidgets('new friend badge counts Matrix invites after AS bootstrap',
      (tester) async {
    final client = Client('DirexioInviteBadgeBootstrapTest')
      ..setUserId('@owner:p2p-im.com');
    final readStore = _MemoryFriendRequestReadStore();
    _addTestRoom(
      client,
      roomId: '!person-invite:p2p-remote.com',
      roomMembership: Membership.invite,
      directPeerMxid: '@alice:p2p-remote.com',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 19, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          friendRequestReadStoreProvider.overrideWith((ref) async => readStore),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    final contactSectionBadge =
        find.byKey(const ValueKey('section_action_badge_新朋友'));
    expect(contactSectionBadge, findsOneWidget);
    expect(
      find.descendant(of: contactSectionBadge, matching: find.text('1')),
      findsOneWidget,
    );
  });

  testWidgets('chat list shows group unread badge from AS room summary',
      (tester) async {
    const roomId = '!group-unread:p2p-im.com';
    final client = Client('DirexioHomeGroupUnreadBadgeTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: 'Group unread',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 18, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: 'Group unread',
          avatarUrl: '',
          unreadCount: 9,
          lastActivityAt: null,
        ),
      ],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: 'Group unread',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    expect(find.text('消息(9)'), findsOneWidget);
    final groupRow = find.ancestor(
      of: find.text('Group unread'),
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_ConvRow',
      ),
    );
    expect(groupRow, findsOneWidget);
    expect(
      find.descendant(of: groupRow, matching: find.text('9')),
      findsOneWidget,
    );
  });

  testWidgets('chat tab badge shows Matrix unread message count',
      (tester) async {
    const roomId = '!direct-unread:p2p-im.com';
    final client = Client('DirexioHomeChatTabUnreadBadgeTest')
      ..setUserId('@owner:p2p-im.com');
    final room = _addUndirectedJoinedRoom(
      client,
      roomId: roomId,
      peerMxid: '@alice:p2p-im.com',
      peerName: 'Alice',
    );
    room.notificationCount = 3;
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 17),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: 'Alice',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: roomId,
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider
              .overrideWithValue(_StaticBootstrapAsClient(bootstrap)),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final chatTabBadge = find.byKey(const ValueKey('bottom_nav_badge_消息'));
    expect(chatTabBadge, findsOneWidget);
    expect(
      find.descendant(of: chatTabBadge, matching: find.text('3')),
      findsOneWidget,
    );
  });

  testWidgets('chat list group avatar includes members without avatar images',
      (tester) async {
    const roomId = '!group-avatar-members:p2p-im.com';
    final client = Client('DirexioHomeGroupAvatarMembersTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: '三人群',
      members: const {
        '@alice:p2p-im.com': 'Alice',
        '@bob:p2p-im.com': 'Bob',
        '@carol:p2p-im.com': 'Carol',
      },
      memberAvatarUrls: const {
        '@alice:p2p-im.com': 'https://example.com/alice.png',
        '@bob:p2p-im.com': 'https://example.com/bob.png',
      },
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 16),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: '三人群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(
            _ConversationListAsClient(const [
              AsConversation(
                conversationId: 'conv_group_avatar_members',
                roomId: roomId,
                kind: asConversationKindGroup,
                lifecycle: 'active',
                title: '三人群',
                avatarUrl: '',
                capabilities: AsConversationCapabilities(open: true),
              ),
            ]),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    final groupRow = find.byKey(const ValueKey('home_conversation_$roomId'));
    expect(groupRow, findsOneWidget);
    expect(
      find.descendant(
        of: groupRow,
        matching: find.byKey(const ValueKey('https://example.com/alice.png')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: groupRow,
        matching: find.byKey(const ValueKey('https://example.com/bob.png')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: groupRow,
        matching: find.byKey(
          const ValueKey('group_composite_avatar_member_@carol:p2p-im.com'),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('chat list group avatar prefers explicit group image',
      (tester) async {
    const roomId = '!group-explicit-avatar:p2p-im.com';
    const avatarUrl = 'https://example.com/group.png';
    final client = Client('DirexioHomeGroupExplicitAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: '头像群',
      members: const {
        '@alice:p2p-im.com': 'Alice',
        '@bob:p2p-im.com': 'Bob',
      },
      memberAvatarUrls: const {
        '@alice:p2p-im.com': 'https://example.com/alice.png',
        '@bob:p2p-im.com': 'https://example.com/bob.png',
      },
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 16),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: '头像群',
          avatarUrl: avatarUrl,
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    final groupRow = find.byKey(const ValueKey('home_conversation_$roomId'));
    expect(groupRow, findsOneWidget);
    final avatars = tester.widgetList<GroupCompositeAvatar>(
      find.descendant(
        of: groupRow,
        matching: find.byType(GroupCompositeAvatar),
      ),
    );
    expect(
      avatars.any((avatar) => avatar.imageUrl == avatarUrl),
      isTrue,
    );
    expect(
      find.descendant(
        of: groupRow,
        matching: find.byKey(const ValueKey('https://example.com/alice.png')),
      ),
      findsNothing,
    );
  });

  testWidgets('viewing new friends clears unread badges but keeps request',
      (tester) async {
    final client = Client('DirexioFriendRequestReadBadgeTest')
      ..setUserId('@owner:p2p-im.com');
    final readStore = _MemoryFriendRequestReadStore();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(path: '/requests', builder: (_, __) => const RequestsPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_StatefulPendingContactAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(
              bootstrap: _pendingFriendRequestBootstrap(),
            ),
          ),
          friendRequestReadStoreProvider.overrideWith((ref) async => readStore),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('bottom_nav_badge_通讯录')), findsOneWidget);

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    expect(
        find.byKey(const ValueKey('section_action_badge_新朋友')), findsOneWidget);

    await tester.tap(find.text('新朋友'));
    await tester.pumpAndSettle();

    expect(find.text('待接受'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('请通过一下'), findsOneWidget);

    router.go('/home');
    await tester.pumpAndSettle();
    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    expect(find.byKey(const ValueKey('bottom_nav_badge_通讯录')), findsNothing);
    expect(
        find.byKey(const ValueKey('section_action_badge_新朋友')), findsNothing);

    router.go('/requests');
    await tester.pumpAndSettle();

    expect(find.text('待接受'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('new friends page only lists incoming direct contact invites',
      (tester) async {
    final client = Client('DirexioRequestsFilterTest')
      ..setUserId('@owner:p2p-im.com');
    _addTestRoom(
      client,
      roomId: '!person-invite:p2p-im.com',
      roomMembership: Membership.invite,
      directPeerMxid: '@alice:portal.local',
    );
    _addTestRoom(
      client,
      roomId: '!group-invite:p2p-im.com',
      roomMembership: Membership.invite,
    );
    _addTestRoom(
      client,
      roomId: '!agent-invite:p2p-im.com',
      roomMembership: Membership.invite,
      directPeerMxid: '@agent:p2p-im.com',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('暂无好友请求'), findsNothing);
    expect(find.text('查看'), findsOneWidget);
  });

  testWidgets('new friends page uses localized English copy', (tester) async {
    final client = Client('DirexioRequestsEnglishLocaleTest')
      ..setUserId('@owner:p2p-im.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const RequestsPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('New Friends'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('No friend requests'), findsOneWidget);
    expect(find.text('新的好友'), findsNothing);
    expect(find.text('暂无好友请求'), findsNothing);
  });

  testWidgets('new friends page refreshes AS pending notices after Matrix sync',
      (tester) async {
    final client = Client('DirexioRequestsLivePendingTest')
      ..setUserId('@owner:p2p-im.com');
    final asClient = _RefreshingFriendRequestBootstrapAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(asClient.syncBootstrapCalls, 1);
    expect(find.text('暂无好友请求'), findsOneWidget);

    asClient.showPendingFriendRequest = true;
    await client.handleSync(SyncUpdate(nextBatch: 'friend-request'));
    await tester.pump();
    await tester.pump();

    expect(asClient.syncBootstrapCalls, 2);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('new friends page labels rejected friend notices as rejected',
      (tester) async {
    final client = Client('DirexioRequestsRejectedFriendNoticeTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 16),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending(
        friendRequests: [
          AsSyncPendingItem(
            id: '!rejected-notice:p2p-im.com',
            title: 'Alice',
            createdAt: null,
            remark: '已拒绝添加好友',
          ),
        ],
        groupInvites: [],
        channelNotices: [],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('已拒绝添加好友'), findsOneWidget);
    expect(find.text('已拒绝'), findsOneWidget);
    expect(find.text('查看'), findsNothing);
  });

  testWidgets('new friends page hides AS pending group invites after sync',
      (tester) async {
    final client = Client('DirexioRequestsLiveGroupInviteTest')
      ..setUserId('@owner:p2p-im.com');
    final asClient = _RefreshingFriendRequestBootstrapAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(asClient.syncBootstrapCalls, 1);
    expect(find.text('暂无好友请求'), findsOneWidget);

    asClient.showPendingGroupInvite = true;
    await client.handleSync(SyncUpdate(nextBatch: 'group-invite'));
    await tester.pump();
    await tester.pump();

    expect(asClient.syncBootstrapCalls, 2);
    expect(find.text('暂无好友请求'), findsOneWidget);
    expect(find.text('实时群聊'), findsNothing);
    expect(find.text('邀请加入群聊'), findsNothing);
  });

  testWidgets('new friends page hides Matrix group room invites',
      (tester) async {
    final client = Client('DirexioRequestsMatrixGroupInviteTest')
      ..setUserId('@owner:p2p-im.com');
    _addTestRoom(
      client,
      roomId: '!matrix-group-invite:p2p-im.com',
      roomMembership: Membership.invite,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('暂无好友请求'), findsOneWidget);
    expect(find.text('邀请加入群聊'), findsNothing);
    expect(find.text('查看'), findsNothing);
  });

  testWidgets('new friends page still lists Matrix invites after AS bootstrap',
      (tester) async {
    final client = Client('DirexioRequestsBootstrapInviteTest')
      ..setUserId('@owner:p2p-im.com');
    _addTestRoom(
      client,
      roomId: '!person-invite:p2p-remote.com',
      roomMembership: Membership.invite,
      directPeerMxid: '@alice:p2p-remote.com',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 19, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('暂无好友请求'), findsNothing);
    expect(find.text('查看'), findsOneWidget);
  });

  testWidgets('new friends page uses AS metadata for outgoing pending contacts',
      (tester) async {
    final client = Client('DirexioOutgoingPendingMetadataTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'owner',
          avatarUrl: 'https://cdn.example.com/pending-owner.png',
          roomId: '!pending:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'pending_outbound',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('等待对方接受'), findsWidgets);
    expect(find.text('owner'), findsOneWidget);
    expect(find.text('申请添加对方为朋友'), findsOneWidget);
    expect(find.text('请求添加你为朋友'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.size == 28 &&
            widget.imageUrl == 'https://cdn.example.com/pending-owner.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('new friends page uses Matrix avatar when AS avatar is empty',
      (tester) async {
    final client = Client('DirexioRequestsMatrixAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!alice-request:p2p-im.com',
      peerMxid: '@alice:p2p-im.com',
      peerName: 'Alice',
      peerAvatarUrl: 'https://matrix.example.com/alice-request.png',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 13),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice-request:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'pending_inbound',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('请求添加你为朋友'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.size == 28 &&
            widget.imageUrl == 'https://matrix.example.com/alice-request.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('new friends Matrix direct invite shows request remark in sheet',
      (tester) async {
    final client = Client('DirexioRequestsMatrixInviteRemarkTest')
      ..setUserId('@owner:p2p-im.com');
    final room = Room(
      id: '!direct-invite:p2p-im.com',
      client: client,
      membership: Membership.invite,
    );
    client.rooms.add(room);
    room.setState(
      StrippedStateEvent(
        type: 'io.direxio.room.profile',
        senderId: '@c:p2p-c.com',
        stateKey: '',
        content: {
          'room_type': 'io.direxio.room.direct',
          'requester_mxid': '@c:p2p-c.com',
          'target_mxid': '@owner:p2p-im.com',
          'display_name': 'C',
          'domain': 'p2p-c.com',
          'remark': '我是 C，请通过好友申请',
        },
      ),
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@c:p2p-c.com',
        stateKey: '@owner:p2p-im.com',
        content: {'membership': Membership.invite.name},
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('C'), findsWidgets);
    expect(find.text('我是 C，请通过好友申请'), findsOneWidget);

    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();

    expect(find.text('我是 C，请通过好友申请'), findsWidgets);
  });

  testWidgets('new friends page uses directional copy for room notices',
      (tester) async {
    final client = Client('DirexioRequestsRoomNoticeCopyTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 14),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending(
        friendRequests: [],
        groupInvites: [
          AsSyncPendingItem(
            id: '!group-invite:p2p-im.com',
            title: '项目群',
            createdAt: null,
          ),
        ],
        channelNotices: [
          AsSyncPendingItem(
            id: '!channel-invite:p2p-im.com',
            title: '产品频道',
            createdAt: null,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('项目群'), findsOneWidget);
    expect(find.text('邀请你加入群聊'), findsOneWidget);
    expect(find.text('产品频道'), findsOneWidget);
    expect(find.text('邀请你加入频道'), findsOneWidget);
  });

  testWidgets('new friends search matches add friend Figma list style',
      (tester) async {
    final client = Client('DirexioRequestsSearchStyleTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'owner',
          avatarUrl: '',
          roomId: '!pending:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'pending_outbound',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('新的好友'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'own');
    await tester.pump();

    expect(find.text('添加好友'), findsOneWidget);
    expect(find.text('owner', findRichText: true), findsOneWidget);
    final requestsSearchRect = tester.getRect(find.byType(M3SearchField));
    final requestsResultRect = tester
        .getRect(find.byKey(const ValueKey('requests_search_result_row')));
    expect(requestsResultRect.top - requestsSearchRect.bottom, 12);
    expect(find.text('等待对方接受'), findsNothing);
  });

  testWidgets('new friends page shows rejected outbound contacts separately',
      (tester) async {
    final client = Client('DirexioOutgoingRejectedBootstrapTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 28, 18),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'owner',
          avatarUrl: '',
          roomId: '!rejected:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'rejected_outbound',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('已拒绝'), findsAtLeastNWidgets(1));
    expect(find.text('对方已拒绝'), findsOneWidget);
    expect(find.text('owner'), findsOneWidget);
    expect(find.text('申请添加对方为朋友'), findsOneWidget);
    expect(find.text('等待接受'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets('new friends page shows rejected inbound contacts separately',
      (tester) async {
    final client = Client('DirexioInboundRejectedBootstrapTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 28, 19),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!rejected-in:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'rejected_inbound',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('已拒绝'), findsAtLeastNWidgets(1));
    expect(find.text('查看'), findsNothing);
    expect(find.text('等待接受'), findsNothing);
  });

  testWidgets('new friends keeps outgoing requests visible after peer rejects',
      (tester) async {
    final client = Client('DirexioOutgoingRejectedMetadataTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!pending:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'owner',
      peerMembership: Membership.leave,
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 28, 16),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'owner',
          avatarUrl: '',
          roomId: '!pending:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'pending_outbound',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('owner'), findsOneWidget);
    expect(find.text('已拒绝'), findsAtLeastNWidgets(1));
    expect(find.text('对方已拒绝'), findsOneWidget);
    expect(find.text('等待接受'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets('new friends hides stale outgoing invite omitted by AS bootstrap',
      (tester) async {
    final client = Client('DirexioStaleOutgoingInviteTest')
      ..setUserId('@owner:p2p-im.com');
    _addTestRoom(
      client,
      roomId: '!old-request:p2p-im.com',
      roomMembership: Membership.join,
      directPeerMxid: '@alice:example.com',
      directPeerMembership: Membership.invite,
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('等待对方接受'), findsNothing);
    expect(find.text('暂无好友请求'), findsOneWidget);
  });

  testWidgets('new friends re-add ignores stale Matrix invite absent from AS',
      (tester) async {
    final client = Client('DirexioReaddAfterRejectedTest')
      ..setUserId('@owner:p2p-im.com');
    _addTestRoom(
      client,
      roomId: '!old-request:p2p-im.com',
      roomMembership: Membership.join,
      directPeerMxid: '@alice:example.com',
      directPeerMembership: Membership.invite,
    );
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '@alice:example.com');
    tester.widget<TextField>(find.byType(TextField)).onSubmitted?.call(
          '@alice:example.com',
        );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(asClient.createContactRequestCalls, 1);
    expect(asClient.createdContactMxid, '@alice:example.com');
    expect(find.textContaining('发送好友请求'), findsOneWidget);
  });

  testWidgets('new friends rejects domains without portal owner discovery',
      (tester) async {
    final client = Client(
      'DirexioRequestsUnknownDomainTest',
      httpClient: MockClient((request) async {
        expect(request.url.toString(),
            'https://unknown.portal.local/.well-known/portal/owner.json');
        return http.Response('internal error', 500);
      }),
    )..setUserId('@owner:p2p-im.com');
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'unknown.portal.local');
    await tester.pump();
    tester.widget<TextField>(find.byType(TextField)).onSubmitted?.call(
          'unknown.portal.local',
        );
    await tester.pumpAndSettle();

    expect(find.textContaining('该域名不是产品用户'), findsOneWidget);
    expect(asClient.createContactRequestCalls, 0);

    await client.dispose(closeDatabase: false);
  });

  testWidgets('new friends page exposes accept and reject actions',
      (tester) async {
    final client = Client('DirexioRequestsActionsTest')
      ..setUserId('@owner:p2p-im.com');
    _addTestRoom(
      client,
      roomId: '!person-invite:p2p-im.com',
      roomMembership: Membership.invite,
      directPeerMxid: '@alice:portal.local',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('查看'), findsOneWidget);
    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();

    expect(find.text('接受'), findsOneWidget);
    expect(find.text('拒绝'), findsOneWidget);
  });

  testWidgets('rejecting friend request shows rejected state and hides view',
      (tester) async {
    final client = Client('DirexioRequestsRejectCacheTest')
      ..setUserId('@owner:p2p-im.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider
              .overrideWithValue(_RejectingPendingContactAsClient()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('查看'), findsOneWidget);
    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('拒绝'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('已拒绝'), findsAtLeastNWidgets(1));
    expect(find.text('查看'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await client.abortSync();
  });

  testWidgets('accepting friend request updates local accepted room cache',
      (tester) async {
    final client = Client('DirexioRequestsAcceptCacheTest')
      ..setUserId('@owner:p2p-im.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_StatefulPendingContactAsClient()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('接受'));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RequestsPage)),
    );
    expect(
      container.read(asSyncCacheProvider).acceptedDirectRoomIds,
      contains('!person-invite:p2p-im.com'),
    );
    await tester.pump(const Duration(seconds: 3));
    await client.abortSync();
  });

  testWidgets('contact page does not show follows shortcut', (tester) async {
    final client = Client('DirexioTest');
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(_FollowsAsClient()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    expect(find.text('关注'), findsNothing);
    expect(find.text('新的群聊'), findsNothing);
    expect(find.text('我的群组'), findsOneWidget);
  });

  testWidgets('follows list renders AS entries without mock avatars',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_FollowsAsClient()),
        ],
        child:
            MaterialApp(theme: AppTheme.light, home: const FollowsListPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.seed == 'alice.portal.local' &&
            widget.imageUrl == null,
      ),
      findsOneWidget,
    );
    expect(find.text('Alice Chen'), findsOneWidget);
    expect(find.byIcon(Symbols.person_check), findsNothing);
  });

  testWidgets('follows list does not render mock entries while logged out',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_FollowsAsClient()),
        ],
        child:
            MaterialApp(theme: AppTheme.light, home: const FollowsListPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice Chen'), findsNothing);
    expect(find.text('还没有关注'), findsOneWidget);
  });

  testWidgets('tapping a followed user opens visitor home', (tester) async {
    final router = GoRouter(
      initialLocation: '/follows',
      routes: [
        GoRoute(path: '/follows', builder: (_, __) => const FollowsListPage()),
        GoRoute(
          path: '/contact-home/:userId',
          builder: (_, state) => Text(
            'home:${state.pathParameters['userId']}',
            textDirection: TextDirection.ltr,
          ),
        ),
        GoRoute(
          path: '/add-contact/detail/:userId',
          builder: (_, state) => AddContactDetailPage(
            userId: state.pathParameters['userId']!,
            displayName: state.uri.queryParameters['name'],
          ),
        ),
        GoRoute(
          path: '/add-contact/verify/:userId',
          builder: (_, state) => AddContactVerificationPage(
            userId: state.pathParameters['userId']!,
            displayName: state.uri.queryParameters['name'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_FollowsAsClient()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice Chen'));
    await tester.pumpAndSettle();

    expect(find.text('home:@owner:alice.portal.local'), findsOneWidget);
  });

  testWidgets('add contact resolves portal url only after submit',
      (tester) async {
    var clipboardText = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboardText = (call.arguments as Map)['text'] as String? ?? '';
            return null;
          case 'Clipboard.getData':
            return {'text': clipboardText};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final client = Client(
      'DirexioAddContactTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"matrix_user_id":"@alice:portal.local","display_name":"Alice Chen","avatar_url":"https://cdn.example.com/alice-search.png"}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final router = GoRouter(
      initialLocation: '/add-contact',
      routes: [
        GoRoute(
            path: '/add-contact', builder: (_, __) => const AddContactPage()),
        GoRoute(
          path: '/add-contact/detail/:userId',
          builder: (_, state) => AddContactDetailPage(
            userId: state.pathParameters['userId']!,
            displayName: state.uri.queryParameters['name'],
            avatarUrl: state.uri.queryParameters['avatar'],
          ),
        ),
        GoRoute(
          path: '/add-contact/verify/:userId',
          builder: (_, state) => AddContactVerificationPage(
            userId: state.pathParameters['userId']!,
            displayName: state.uri.queryParameters['name'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加好友'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'alice.portal.local');
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == 'Alice Chen',
      ),
      findsNothing,
    );

    tester.widget<TextField>(find.byType(TextField)).onSubmitted?.call(
          'alice.portal.local',
        );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == 'Alice Chen',
      ),
      findsOneWidget,
    );
    expect(find.text('@alice:portal.local'), findsOneWidget);
    final searchAvatar = tester
        .widgetList<PortalAvatar>(find.byType(PortalAvatar))
        .where((item) => item.size == 28)
        .single;
    expect(searchAvatar.imageUrl?.trim().isNotEmpty, isTrue);
    expect(find.text('添加'), findsNothing);
    final addContactSearchRect = tester.getRect(find.byType(M3SearchField));
    final addContactResultRect =
        tester.getRect(find.byKey(const ValueKey('add_contact_result_row')));
    expect(addContactResultRect.top - addContactSearchRect.bottom, 12);

    await tester.tap(find.byKey(const ValueKey('add_contact_result_avatar')));
    await tester.pumpAndSettle();

    expect(find.text('添加好友'), findsOneWidget);
    expect(find.text('发消息'), findsNothing);
    expect(find.text('音频通话'), findsNothing);
    expect(find.text('视频通话'), findsNothing);
    expect(find.text('消息免打扰'), findsNothing);
    expect(find.text('屏蔽用户'), findsNothing);
    expect(find.text('举报用户'), findsNothing);
    expect(find.text('@alice:portal.local'), findsOneWidget);

    await tester.tap(find.text('@alice:portal.local'));
    await tester.pump();

    expect(find.text('已复制 UID'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final copied = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copied?.text, '@alice:portal.local');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('add contact falls back to Matrix profile for default owner name',
      (tester) async {
    final requestPaths = <String>[];
    final client = Client(
      'DirexioAddContactProfileFallbackTest',
      httpClient: MockClient((request) async {
        requestPaths.add(request.url.path);
        if (request.url.path == '/.well-known/portal/owner.json') {
          return http.Response(
            '{"matrix_user_id":"@owner:portal.local","display_name":"owner","avatar_url":"mxc://portal/default"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path.startsWith('/_matrix/client/v3/profile/')) {
          return http.Response.bytes(
            utf8.encode(
              '{"displayname":"B 的昵称","avatar_url":"https://cdn.example.com/b.png"}',
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 404);
      }),
    )..homeserver = Uri.parse('https://portal.local');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AddContactPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'portal.local');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const ValueKey('add_contact_result_row'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    expect(requestPaths, contains('/.well-known/portal/owner.json'));
    expect(
      requestPaths
          .any((path) => path.startsWith('/_matrix/client/v3/profile/')),
      isTrue,
    );
    expect(
        find.byKey(const ValueKey('add_contact_result_row')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == 'B 的昵称',
      ),
      findsOneWidget,
    );
    expect(find.text('owner'), findsNothing);
  });

  testWidgets('add contact uses contacts-style background and search field',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AddContactPage(),
        ),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('add_contact_scaffold')),
    );
    expect(scaffold.backgroundColor, PortalTokens.light.bg);

    final searchMaterial = tester.widget<Material>(
      find.descendant(
        of: find.byType(M3SearchField),
        matching: find.byType(Material),
      ),
    );
    expect(searchMaterial.color, PortalTokens.light.surfaceHover);
  });

  testWidgets(
      'add contact search does not render demo results while logged out',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AddContactPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'ben');
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('benjamin'), findsNothing);
    expect(find.byKey(const ValueKey('add_contact_result_row')), findsNothing);
  });

  testWidgets('add contact submit does not resolve mock portal owners',
      (tester) async {
    final client = Client(
      'DirexioAddContactNoMockOwnerTest',
      httpClient: MockClient((request) async {
        expect(request.url.toString(),
            'https://alice.portal.local/.well-known/portal/owner.json');
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AddContactPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'alice.portal.local');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Alice Chen'), findsNothing);
    expect(find.text('@alice:portal.local'), findsNothing);
    expect(find.text('该域名不是产品用户'), findsOneWidget);

    await client.dispose(closeDatabase: false);
  });

  testWidgets('add contact detail opens chat for accepted contact',
      (tester) async {
    const roomId = '!alice-chat:p2p-im.com';
    const conversationId = 'bootstrap:$roomId';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 16, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:portal.local',
          displayName: 'Alice Chen',
          avatarUrl: '',
          roomId: roomId,
          domain: 'portal.local',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation:
          '/add-contact/detail/%40alice%3Aportal.local?name=Alice%20Chen',
      routes: [
        GoRoute(
          path: '/add-contact/detail/:userId',
          builder: (_, state) => AddContactDetailPage(
            userId: state.pathParameters['userId']!,
            displayName: state.uri.queryParameters['name'],
            avatarUrl: state.uri.queryParameters['avatar'],
          ),
        ),
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, state) => Text(
            'chat:${state.pathParameters['roomId']};'
            'conversation:${state.uri.queryParameters['conversation']}',
            textDirection: TextDirection.ltr,
          ),
        ),
      ],
    );

    final preferencesStore = _MemoryConversationPreferencesStore(
      const ConversationPreferencesData(hiddenConversationIds: {roomId}),
    );
    final container = ProviderContainer(
      overrides: [
        authStateNotifierProvider.overrideWith(_LoggedInAuthStateNotifier.new),
        asSyncCacheProvider.overrideWith(
          (ref) => AsSyncCacheState(bootstrap: bootstrap),
        ),
        asClientProvider.overrideWithValue(
          _ConversationListAsClient(
            const [
              AsConversation(
                conversationId: conversationId,
                roomId: roomId,
                kind: asConversationKindDirect,
                lifecycle: 'active',
                peerMxid: '@alice:portal.local',
                title: 'Alice Chen',
                avatarUrl: '',
                capabilities: AsConversationCapabilities(open: true),
              ),
            ],
          ),
        ),
        conversationPreferencesStoreProvider.overrideWith(
          (ref) async => preferencesStore,
        ),
      ],
    );
    container.read(conversationPreferencesProvider);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加好友'), findsNothing);
    expect(find.text('发消息'), findsWidgets);
    expect(container.read(homeHiddenConversationIdsProvider), contains(roomId));

    await tester.tap(find.text('发消息').first);
    await tester.pumpAndSettle();

    expect(
      find.text('chat:$roomId;conversation:$conversationId'),
      findsOneWidget,
    );
    expect(
      container.read(homeHiddenConversationIdsProvider),
      isNot(contains(roomId)),
    );
  });

  testWidgets('add contact detail message action opens friend request',
      (tester) async {
    final router = GoRouter(
      initialLocation:
          '/add-contact/detail/%40alice%3Aportal.local?name=Alice%20Chen',
      routes: [
        GoRoute(
          path: '/add-contact/detail/:userId',
          builder: (_, state) => AddContactDetailPage(
            userId: state.pathParameters['userId']!,
            displayName: state.uri.queryParameters['name'],
            avatarUrl: state.uri.queryParameters['avatar'],
          ),
        ),
        GoRoute(
          path: '/add-contact/verify/:userId',
          builder: (_, state) => AddContactVerificationPage(
            userId: state.pathParameters['userId']!,
            displayName: state.uri.queryParameters['name'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加好友'), findsOneWidget);
    await tester.tap(find.text('添加好友'));
    await tester.pumpAndSettle();

    expect(find.text('发送好友申请'), findsOneWidget);
    expect(find.text('发送申请'), findsOneWidget);
  });

  testWidgets('add contact detail uses provided avatar url', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AddContactDetailPage(
            userId: '@remote:portal.local',
            displayName: 'Alice Chen',
            avatarUrl: 'https://cdn.example.com/alice.png',
          ),
        ),
      ),
    );
    await tester.pump();

    final avatar = tester
        .widgetList<PortalAvatar>(find.byType(PortalAvatar))
        .where((item) => item.size == 60)
        .single;
    expect(avatar.imageUrl, 'https://cdn.example.com/alice.png');
  });

  testWidgets('add contact detail uses display name for avatar fallback seed',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AddContactDetailPage(
            userId: '@2alice:portal.local',
            displayName: 'A',
          ),
        ),
      ),
    );
    await tester.pump();

    final avatar = tester
        .widgetList<PortalAvatar>(find.byType(PortalAvatar))
        .where((item) => item.size == 60)
        .single;
    expect(avatar.seed, 'A');
  });

  testWidgets('add contact detail loads public channels from remote owner node',
      (tester) async {
    final asClient = _TrackingAsClient()
      ..userPublicChannels = const [
        AsChannel(
          channelId: 'ch_remote_alice',
          roomId: '!alice-channel:remote.example',
          name: 'Alice 远端频道',
        ),
      ];
    final remoteNodeBaseUri = Uri.parse('https://remote.example/_p2p');
    final router = GoRouter(
      initialLocation:
          '/add-contact/detail/%40alice%3Aremote.example?name=Alice&remote_node_base_url=${Uri.encodeComponent(remoteNodeBaseUri.toString())}',
      routes: [
        GoRoute(
          path: '/add-contact/detail/:userId',
          builder: (_, state) => AddContactDetailPage(
            userId: state.pathParameters['userId']!,
            displayName: state.uri.queryParameters['name'],
            remoteNodeBaseUri: Uri.tryParse(
              state.uri.queryParameters['remote_node_base_url'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: '/contact-channels/:userId',
          builder: (_, state) => ContactChannelsPage(
            userId: state.pathParameters['userId']!,
            remoteNodeBaseUri: Uri.tryParse(
              state.uri.queryParameters['remote_node_base_url'] ?? '',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(asClient.requestedUserPublicChannelsUserId, '@alice:remote.example');
    expect(asClient.requestedUserPublicChannelsBaseUri, remoteNodeBaseUri);
    expect(
      find.byKey(const ValueKey('add_contact_channel_ch_remote_alice')),
      findsOneWidget,
    );

    await tester.tap(find.text('他的频道'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactChannelsPage), findsOneWidget);
    expect(asClient.requestedUserPublicChannelsBaseUri, remoteNodeBaseUri);
  });

  testWidgets('contact channels list opens channel from list item',
      (tester) async {
    final asClient = _TrackingAsClient()
      ..userPublicChannels = const [
        AsChannel(
          channelId: 'ch_alice_public',
          roomId: '!alice-public:remote.example',
          name: 'Alice 公开频道',
          avatarUrl: 'https://cdn.example.com/alice-public.png',
          visibility: asChannelVisibilityPublic,
          joinPolicy: asChannelJoinPolicyApproval,
          memberStatus: asChannelMemberStatusJoined,
        ),
      ];
    final router = GoRouter(
      initialLocation: '/contact-channels/%40alice%3Aremote.example',
      routes: [
        GoRoute(
          path: '/contact-channels/:userId',
          builder: (_, state) => ContactChannelsPage(
            userId: state.pathParameters['userId']!,
          ),
        ),
        GoRoute(
          path: '/channel/:channelId/detail',
          builder: (_, state) => Scaffold(
            body: Column(
              children: [
                Text('opened ${state.pathParameters['channelId']}'),
                Text('avatar:${state.uri.queryParameters['avatar']}'),
              ],
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice 公开频道'));
    await tester.pumpAndSettle();

    expect(find.text('opened !alice-public:remote.example'), findsOneWidget);
    expect(
      find.text('avatar:https://cdn.example.com/alice-public.png'),
      findsOneWidget,
    );
  });

  testWidgets('contact channels list opens joined channel by channel id',
      (tester) async {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 24, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          roomId: '!alice-joined:remote.example',
          channelId: 'ch_alice_joined',
          name: 'Alice 已加入频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient()
      ..userPublicChannels = const [
        AsChannel(
          channelId: 'ch_alice_joined',
          roomId: '!alice-joined:remote.example',
          name: 'Alice 已加入频道',
          avatarUrl: 'https://cdn.example.com/alice-joined.png',
          visibility: asChannelVisibilityPublic,
          joinPolicy: asChannelJoinPolicyOpen,
          memberStatus: asChannelMemberStatusJoined,
        ),
      ];
    final router = GoRouter(
      initialLocation: '/contact-channels/%40alice%3Aremote.example',
      routes: [
        GoRoute(
          path: '/contact-channels/:userId',
          builder: (_, state) => ContactChannelsPage(
            userId: state.pathParameters['userId']!,
          ),
        ),
        GoRoute(
          path: '/channel/:channelId/detail',
          builder: (_, state) => Scaffold(
            body: Column(
              children: [
                Text('opened ${state.pathParameters['channelId']}'),
                Text('avatar:${state.uri.queryParameters['avatar']}'),
              ],
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice 已加入频道'));
    await tester.pumpAndSettle();

    expect(find.text('opened ch_alice_joined'), findsOneWidget);
    expect(
      find.text('avatar:https://cdn.example.com/alice-joined.png'),
      findsOneWidget,
    );
  });

  testWidgets(
      'add contact detail keeps routed avatar when accepted contact avatar is empty',
      (tester) async {
    const routedAvatarUrl = 'https://cdn.example.com/alice-search.png';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 24, 9),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:portal.local',
          displayName: 'Alice Chen',
          avatarUrl: '',
          roomId: '!alice-chat:p2p-im.com',
          domain: 'portal.local',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AddContactDetailPage(
            userId: '@alice:portal.local',
            displayName: 'Alice Chen',
            avatarUrl: routedAvatarUrl,
          ),
        ),
      ),
    );
    await tester.pump();

    final avatar = tester
        .widgetList<PortalAvatar>(find.byType(PortalAvatar))
        .where((item) => item.size == 60)
        .single;
    expect(avatar.imageUrl, routedAvatarUrl);
  });

  testWidgets('add contact detail forwards avatar url to verification route',
      (tester) async {
    final asClient = _TrackingAsClient();
    final router = GoRouter(
      initialLocation:
          '/add-contact/detail/%40alice%3Aportal.local?name=Alice&avatar=mxc%3A%2F%2Fportal.local%2Falice',
      routes: [
        GoRoute(
          path: '/add-contact/detail/:userId',
          builder: (_, state) => AddContactDetailPage(
            userId: state.pathParameters['userId']!,
            displayName: state.uri.queryParameters['name'],
            avatarUrl: state.uri.queryParameters['avatar'],
          ),
        ),
        GoRoute(
          path: '/add-contact/verify/:userId',
          builder: (_, state) => AddContactVerificationPage(
            userId: state.pathParameters['userId']!,
            displayName: state.uri.queryParameters['name'],
            avatarUrl: state.uri.queryParameters['avatar'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('添加好友'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送申请'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(asClient.createdContactMxid, '@alice:portal.local');
    expect(asClient.createdContactAvatarUrl, 'mxc://portal.local/alice');
    await tester.pumpAndSettle();
  });

  testWidgets('add contact detail does not hydrate mock profile',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AddContactDetailPage(
            userId: '@alice:portal.local',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('alice'), findsOneWidget);
    expect(find.text('Alice Chen'), findsNothing);
    final avatar = tester
        .widgetList<PortalAvatar>(find.byType(PortalAvatar))
        .where((item) => item.size == 60)
        .single;
    expect(avatar.imageUrl, isNull);
  });

  testWidgets('add contact rejects domains without portal owner discovery',
      (tester) async {
    final asClient = _TrackingAsClient();
    final client = Client(
      'DirexioAddContactUnknownDomainTest',
      httpClient: MockClient((request) async {
        expect(request.url.toString(),
            'https://unknown.portal.local/.well-known/portal/owner.json');
        return http.Response('internal error', 500);
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AddContactPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'unknown.portal.local');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('该域名不是产品用户'), findsOneWidget);
    expect(find.text('@owner:unknown.portal.local'), findsNothing);
    expect(find.text('添加'), findsNothing);
    expect(asClient.createContactRequestCalls, 0);

    await client.dispose(closeDatabase: false);
  });

  testWidgets('add contact verification page sends friend request',
      (tester) async {
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          initialRoute: '/verify',
          routes: {
            '/': (_) => const Scaffold(body: Text('上一页')),
            '/verify': (_) => const AddContactVerificationPage(
                  userId: '@alice:portal.local',
                  displayName: 'Alice Chen',
                  avatarUrl: 'mxc://portal.local/alice',
                ),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('好友验证'), findsOneWidget);
    expect(find.text('发送好友申请'), findsOneWidget);
    expect(find.text('0/200'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '我是 Niki');
    await tester.pump();
    expect(find.text('7/200'), findsOneWidget);

    await tester.tap(find.text('发送申请'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(asClient.createContactRequestCalls, 1);
    expect(asClient.createdContactMxid, '@alice:portal.local');
    expect(asClient.createdContactAvatarUrl, 'mxc://portal.local/alice');
    expect(asClient.createdContactRemark, '我是 Niki');
    expect(find.text('好友请求已发送，等待对方接受。'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('上一页'), findsOneWidget);
    expect(find.text('好友验证'), findsNothing);
  });

  testWidgets('add contact verification records returned product conversation',
      (tester) async {
    final client = Client('DirexioAddContactConversationSummaryTest')
      ..setUserId('@owner:p2p-im.com');
    final asClient = _TrackingAsClient()
      ..createdContactProductConversation = AsConversation(
        conversationId: 'conv_alice',
        roomId: '!alice:p2p-im.com',
        kind: asConversationKindDirect,
        lifecycle: 'active',
        title: 'Alice Chen',
        avatarUrl: '',
        lastMessage: 'restored preview',
        lastActivityAt: DateTime.utc(2026, 6, 22, 11),
        capabilities: const AsConversationCapabilities(open: true),
      );
    final snapshotStore = _MemoryConversationSummaryStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
          conversationSummaryStoreProvider.overrideWith(
            (ref) async => snapshotStore,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          initialRoute: '/verify',
          routes: {
            '/': (_) => const Scaffold(body: Text('上一页')),
            '/verify': (_) => const AddContactVerificationPage(
                  userId: '@alice:portal.local',
                  displayName: 'Alice Chen',
                ),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('发送申请'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(asClient.createContactRequestCalls, 1);
    expect(snapshotStore.snapshot?.userId, '@owner:p2p-im.com');
    expect(snapshotStore.snapshot?.entries.single.conversationId, 'conv_alice');
    expect(
      snapshotStore.snapshot?.entries.single.lastMessage,
      'restored preview',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('add contact verification maps self request error',
      (tester) async {
    final asClient = _TrackingAsClient()
      ..createContactRequestError = AsClientException(
        'mxid must be a remote peer',
        statusCode: 400,
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          initialRoute: '/verify',
          routes: {
            '/': (_) => const Scaffold(body: Text('上一页')),
            '/verify': (_) => const AddContactVerificationPage(
                  userId: '@owner:portal.local',
                  displayName: 'Me',
                ),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('发送申请'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(asClient.createContactRequestCalls, 1);
    expect(find.text('不能添加自己'), findsOneWidget);
    expect(find.textContaining('AsClientException'), findsNothing);
    expect(find.textContaining('mxid must be a remote peer'), findsNothing);
    expect(find.text('好友验证'), findsOneWidget);
  });

  testWidgets('add contact verification preserves mxid server name with port',
      (tester) async {
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AddContactVerificationPage(
            userId: '@owner:dendrite-b:8448',
            displayName: 'Owner B',
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('发送申请'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(asClient.createContactRequestCalls, 1);
    expect(asClient.createdContactMxid, '@owner:dendrite-b:8448');
    expect(asClient.createdContactDomain, 'dendrite-b:8448');
    await tester.pumpAndSettle();
  });

  testWidgets('add contact verification does not send mock display names',
      (tester) async {
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AddContactVerificationPage(
            userId: '@alice:portal.local',
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('发送申请'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(asClient.createContactRequestCalls, 1);
    expect(asClient.createdContactMxid, '@alice:portal.local');
    expect(asClient.createdContactDisplayName, 'alice');
    expect(asClient.createdContactDomain, 'portal.local');
    await tester.pumpAndSettle();
  });

  testWidgets('add contact verification page uses dark tokens in dark mode',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AddContactVerificationPage(
            userId: '@alice:portal.local',
            displayName: 'Alice Chen',
          ),
        ),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('add_contact_verification_scaffold')),
    );
    final card = tester.widget<Container>(
      find.byKey(const ValueKey('add_contact_verification_card')),
    );
    final messageBox = tester.widget<Container>(
      find.byKey(const ValueKey('add_contact_verification_message_box')),
    );
    final cardDecoration = card.decoration! as BoxDecoration;
    final messageDecoration = messageBox.decoration! as BoxDecoration;

    expect(scaffold.backgroundColor, PortalTokens.dark.surfaceHover);
    expect(cardDecoration.color, PortalTokens.dark.surface);
    expect(messageDecoration.color, PortalTokens.dark.surfaceHover);
    expect(find.text('好友验证'), findsOneWidget);
  });

  testWidgets('add contact search detail can request friend', (tester) async {
    final client = Client(
      'DirexioAddContactInboundRequestTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"matrix_user_id":"@alice:portal.local","display_name":"Alice Chen"}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final router = GoRouter(
      initialLocation: '/add-contact',
      routes: [
        GoRoute(
            path: '/add-contact', builder: (_, __) => const AddContactPage()),
        GoRoute(
          path: '/add-contact/detail/:userId',
          builder: (_, state) => AddContactDetailPage(
            userId: state.pathParameters['userId']!,
            displayName: state.uri.queryParameters['name'],
          ),
        ),
        GoRoute(
          path: '/add-contact/verify/:userId',
          builder: (_, state) => AddContactVerificationPage(
            userId: state.pathParameters['userId']!,
            displayName: state.uri.queryParameters['name'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider
              .overrideWithValue(_PendingInboundAddContactAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'alice.portal.local');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_contact_result_avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加好友'));
    await tester.pumpAndSettle();
    expect(find.text('好友验证'), findsOneWidget);
    expect(find.text('发送好友申请'), findsOneWidget);
    await tester.tap(find.text('发送申请'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('好友请求已发送，等待对方接受。'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('好友验证'), findsNothing);
    expect(find.text('添加好友'), findsOneWidget);

    await client.dispose(closeDatabase: false);
  });

  testWidgets('groups empty state does not render mock group list',
      (tester) async {
    final client = Client('DirexioGroupsNoMockListTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const GroupsListPage()),
      ),
    );
    await tester.pump();

    expect(find.text('P2P IM 核心群'), findsNothing);
    expect(find.text('产品设计组'), findsNothing);
    expect(find.text('Agent 创作小组'), findsNothing);
    expect(find.text('群主'), findsNothing);
    expect(find.text('还没有群聊'), findsOneWidget);
  });

  testWidgets('groups empty state does not expose mock group routes',
      (tester) async {
    final client = Client('DirexioGroupsNoMockRouteTest');
    final router = GoRouter(
      initialLocation: '/groups',
      routes: [
        GoRoute(path: '/groups', builder: (_, __) => const GroupsListPage()),
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, __) => const Scaffold(body: Text('opened-chat')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('opened-chat'), findsNothing);
    expect(find.text('产品设计组'), findsNothing);
    expect(find.text('还没有群聊'), findsOneWidget);
  });

  testWidgets('groups list excludes AS accepted undirected direct contacts',
      (tester) async {
    final client = Client('DirexioGroupsExcludeDirectMetadataTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!owner:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'owner',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'owner',
          avatarUrl: '',
          roomId: '!owner:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const GroupsListPage()),
      ),
    );
    await tester.pump();

    expect(find.text('owner'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets('groups list excludes stale AS group for accepted contact room',
      (tester) async {
    final client = Client('DirexioGroupsExcludeStaleAsGroupForDirectTest')
      ..setUserId('@owner:example.test');
    const roomId = '!direct:example.test';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 21, 12),
      user: const AsSyncUser(userId: '@owner:example.test'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@peer:example.test',
          displayName: 'C Direct',
          avatarUrl: '',
          roomId: roomId,
          domain: 'example.test',
          status: 'accepted',
        ),
      ],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: 'C Stale Group',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 2,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(
            _ConversationListAsClient(const [
              AsConversation(
                conversationId: 'conv_direct',
                roomId: roomId,
                kind: asConversationKindDirect,
                lifecycle: 'active',
                title: 'C Direct',
                avatarUrl: '',
              ),
            ]),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const GroupsListPage()),
      ),
    );
    await tester.pump();

    expect(find.text('C Stale Group'), findsNothing);
    expect(find.text('还没有群聊'), findsOneWidget);
  });

  testWidgets('groups list only shows AS joined groups', (tester) async {
    final client = Client('DirexioGroupsExcludeStaleDirectRoomsTest')
      ..setUserId('@owner:p2p-im.com');
    _addHeroSummaryRoom(
      client,
      roomId: '!deleted-contact:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Owner',
    );
    _addHeroSummaryRoom(
      client,
      roomId: '!raw-one-to-one:p2p-im.com',
      peerMxid: '@vivid:p2p-liyanan.com',
      peerName: 'Vivid Dusk',
    );
    _addHeroSummaryRoom(
      client,
      roomId: '!agent-room:p2p-im.com',
      peerMxid: '@agent:p2p-im.com',
      peerName: 'agent',
    );
    _addNamedGroupRoom(client, roomId: '!group:p2p-im.com', name: '群');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'Owner',
          avatarUrl: '',
          roomId: '!deleted-contact:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'rejected',
        ),
      ],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!as-group:p2p-im.com',
          name: 'AS 产品群',
          avatarUrl: '',
          unreadCount: 2,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(
            _ConversationListAsClient(const [
              AsConversation(
                conversationId: 'conv_as_group',
                roomId: '!as-group:p2p-im.com',
                kind: asConversationKindGroup,
                lifecycle: 'active',
                title: 'AS 产品群',
                avatarUrl: '',
              ),
            ]),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const GroupsListPage()),
      ),
    );
    await tester.pump();

    expect(find.text('AS 产品群'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('群'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
    expect(find.text('agent'), findsNothing);
    expect(find.text('Owner'), findsNothing);
    expect(find.text('Vivid Dusk'), findsNothing);
  });

  testWidgets('groups list hides non-joined group projections', (tester) async {
    final client = Client('DirexioGroupsHideNonJoinedStatusTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 22, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!joined:p2p-im.com',
          name: '已加入群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: 'joined',
        ),
        AsSyncRoomSummary(
          roomId: '!invite:p2p-im.com',
          name: '待加入群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: 'invite',
        ),
        AsSyncRoomSummary(
          roomId: '!pending:p2p-im.com',
          name: '等待同意群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: 'pending',
        ),
        AsSyncRoomSummary(
          roomId: '!rejected:p2p-im.com',
          name: '未同意群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: 'rejected',
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(
            _ConversationListAsClient(const [
              AsConversation(
                conversationId: 'conv_joined',
                roomId: '!joined:p2p-im.com',
                kind: asConversationKindGroup,
                lifecycle: 'active',
                title: '已加入群',
                avatarUrl: '',
                membership: 'joined',
              ),
              AsConversation(
                conversationId: 'conv_invite',
                roomId: '!invite:p2p-im.com',
                kind: asConversationKindGroup,
                lifecycle: 'active',
                title: '待加入群',
                avatarUrl: '',
                membership: 'invite',
              ),
              AsConversation(
                conversationId: 'conv_pending',
                roomId: '!pending:p2p-im.com',
                kind: asConversationKindGroup,
                lifecycle: 'active',
                title: '等待同意群',
                avatarUrl: '',
                membership: 'pending',
              ),
              AsConversation(
                conversationId: 'conv_rejected',
                roomId: '!rejected:p2p-im.com',
                kind: asConversationKindGroup,
                lifecycle: 'active',
                title: '未同意群',
                avatarUrl: '',
                membership: 'rejected',
              ),
            ]),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const GroupsListPage()),
      ),
    );
    await tester.pump();

    expect(find.text('已加入群'), findsOneWidget);
    expect(find.text('待加入群'), findsNothing);
    expect(find.text('等待同意群'), findsNothing);
    expect(find.text('未同意群'), findsNothing);
  });

  testWidgets('groups list keeps removed groups as history', (tester) async {
    const roomId = '!removed-list:p2p-im.com';
    final client = Client('DirexioGroupsKeepRemovedGroupTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: '被移除的群',
      membership: Membership.leave,
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: '被移除的群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: 'removed',
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/groups',
      routes: [
        GoRoute(path: '/groups', builder: (_, __) => const GroupsListPage()),
        GoRoute(
          path: '/group/:roomId',
          builder: (_, state) =>
              Text('group:${state.pathParameters['roomId']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(
            _ConversationListAsClient(const [
              AsConversation(
                conversationId: 'conv_removed_list',
                roomId: roomId,
                kind: asConversationKindGroup,
                lifecycle: 'active',
                title: '被移除的群',
                avatarUrl: '',
                membership: 'removed',
                capabilities: AsConversationCapabilities(open: false),
              ),
            ]),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('被移除的群'), findsOneWidget);

    await tester.tap(find.text('被移除的群'));
    await tester.pumpAndSettle();

    expect(find.text('group:$roomId'), findsOneWidget);
  });

  testWidgets('groups list hides bootstrap groups missing ProductCore record',
      (tester) async {
    final client = Client('DirexioGroupsRequireProductConversationTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 21, 14),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!bootstrap-only:p2p-im.com',
          name: '旧群缓存',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider
              .overrideWithValue(_ConversationListAsClient(const [])),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const GroupsListPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('旧群缓存'), findsNothing);
    expect(find.text('还没有群聊'), findsOneWidget);
  });

  testWidgets('groups list opens ProductCore group conversation route',
      (tester) async {
    const roomId = '!group:p2p-im.com';
    const conversationId = 'conv_group';
    final client = Client('DirexioGroupsProductOpenTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 21, 14),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: '产品群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/groups',
      routes: [
        GoRoute(path: '/groups', builder: (_, __) => const GroupsListPage()),
        GoRoute(
          path: '/group/:roomId',
          builder: (_, state) => Scaffold(
            body: Text(
              'group:${state.pathParameters['roomId']};'
              'conversation:${state.uri.queryParameters['conversation']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(
            _ConversationListAsClient(const [
              AsConversation(
                conversationId: conversationId,
                roomId: roomId,
                kind: asConversationKindGroup,
                lifecycle: 'active',
                title: '产品群',
                avatarUrl: '',
                capabilities: AsConversationCapabilities(open: true),
              ),
            ]),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('产品群'));
    await tester.pumpAndSettle();

    expect(find.text('group:$roomId;conversation:$conversationId'),
        findsOneWidget);
  });

  testWidgets('groups list renders bootstrap group avatar', (tester) async {
    const roomId = '!group:p2p-im.com';
    const avatarUrl = 'https://cdn.example.com/group.png';
    final client = Client('DirexioGroupsProductAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 21, 14),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: '产品群',
          avatarUrl: avatarUrl,
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(
            _ConversationListAsClient(const [
              AsConversation(
                conversationId: 'conv_group',
                roomId: roomId,
                kind: asConversationKindGroup,
                lifecycle: 'active',
                title: '产品群',
                avatarUrl: avatarUrl,
                capabilities: AsConversationCapabilities(open: true),
              ),
            ]),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const GroupsListPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('产品群'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('group_avatar_!group:p2p-im.com')),
      findsOneWidget,
    );
    final avatars = tester.widgetList<PortalAvatar>(find.byType(PortalAvatar));
    expect(
      avatars.any((avatar) => avatar.imageUrl == avatarUrl),
      isTrue,
    );
  });

  testWidgets(
      'groups list falls back to Matrix room avatar before opening chat',
      (tester) async {
    const roomId = '!group-room-avatar:p2p-im.com';
    const avatarUrl = 'https://cdn.example.com/room-group.png';
    final client = Client('DirexioGroupsRoomAvatarFallbackTest')
      ..setUserId('@owner:p2p-im.com');
    final room = _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: '真实群',
      members: const {},
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomAvatar,
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: const {'url': avatarUrl},
      ),
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 21, 14),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(
            _ConversationListAsClient(const [
              AsConversation(
                conversationId: 'conv_group_room_avatar',
                roomId: roomId,
                kind: asConversationKindGroup,
                lifecycle: 'active',
                title: '真实群',
                avatarUrl: '',
                capabilities: AsConversationCapabilities(open: true),
              ),
            ]),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const GroupsListPage()),
      ),
    );
    await tester.pumpAndSettle();

    final groupAvatar = find.byKey(const ValueKey('group_avatar_$roomId'));
    expect(groupAvatar, findsOneWidget);
    final avatars = tester.widgetList<PortalAvatar>(
      find.descendant(of: groupAvatar, matching: find.byType(PortalAvatar)),
    );
    expect(
      avatars.any((avatar) => avatar.imageUrl == avatarUrl),
      isTrue,
    );
  });

  testWidgets('groups list labels image previews instead of filenames',
      (tester) async {
    const imageName =
        'image_picker_11111111-AAAA-BBBB-CCCC-generated-photo.jpg';
    final client = Client('DirexioGroupListImagePreviewTest')
      ..setUserId('@owner:p2p-im.com');
    final room = _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    room.lastEvent = Event(
      room: room,
      eventId: r'$group-image-preview',
      senderId: '@alice:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 30, 10),
      content: const {
        'msgtype': MessageTypes.Image,
        'body': imageName,
        'url': 'mxc://p2p-im.com/image',
      },
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(
            _ConversationListAsClient(const [
              AsConversation(
                conversationId: 'conv_group_image',
                roomId: '!group:p2p-im.com',
                kind: asConversationKindGroup,
                lifecycle: 'active',
                title: '真实群',
                avatarUrl: '',
              ),
            ]),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const GroupsListPage()),
      ),
    );
    await tester.pump();

    expect(find.text('真实群'), findsOneWidget);
    expect(find.text('收到图片'), findsOneWidget);
    expect(find.text(imageName), findsNothing);
  });

  testWidgets('group creation invites only selected accepted contacts',
      (tester) async {
    final sentInviteCards = <Map<String, dynamic>>[];
    final requestPaths = <String>[];
    final client = Client(
      'DirexioGroupCreateInviteTest',
      httpClient: MockClient((request) async {
        requestPaths.add(request.url.path);
        if (request.url.path.contains('/send/m.room.message')) {
          sentInviteCards.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({
              'event_id':
                  '\$group-create-invite-card-${sentInviteCards.length}',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addUndirectedJoinedRoom(
      client,
      roomId: '!alice:p2p-im.com',
      peerMxid: '@alice:p2p-liyanan.com',
      peerName: 'Alice Chen',
      peerAvatarUrl: 'https://example.com/alice.png',
    );
    _addUndirectedJoinedRoom(
      client,
      roomId: '!bob:p2p-im.com',
      peerMxid: '@bob:p2p-liyanan.com',
      peerName: 'Bob Lin',
      peerAvatarUrl: 'https://example.com/bob.png',
    );
    final asClient = _TrackingAsClient();

    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-liyanan.com',
          displayName: 'Alice Chen',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
        AsSyncContact(
          userId: '@bob:p2p-liyanan.com',
          displayName: 'Bob Lin',
          avatarUrl: '',
          roomId: '!bob:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
        AsSyncContact(
          userId: '@pending:p2p-liyanan.com',
          displayName: 'Pending User',
          avatarUrl: '',
          roomId: '!pending:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'pending_outbound',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/groups',
      routes: [
        GoRoute(
          path: '/groups',
          builder: (_, __) => const GroupsListPage(),
        ),
        GoRoute(
          path: '/group/:roomId',
          builder: (_, state) => Scaffold(
            body: Text(state.pathParameters['roomId']!),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          groupCreationSyncAfterCreateProvider.overrideWithValue(false),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          currentUserProfileProvider.overrideWith(
            (ref) async => Profile(
              userId: '@owner:p2p-im.com',
              displayName: 'Owner',
              avatarUrl: Uri.parse('mxc://p2p-im.com/owner-avatar'),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Symbols.group_add));
    await tester.pumpAndSettle();

    expect(find.text('发起群聊'), findsOneWidget);
    expect(find.text('Alice Chen'), findsOneWidget);
    expect(find.text('Bob Lin'), findsOneWidget);
    expect(find.text('Pending User'), findsNothing);
    final avatars = tester.widgetList<PortalAvatar>(find.byType(PortalAvatar));
    expect(
      avatars
          .any((avatar) => avatar.imageUrl == 'https://example.com/alice.png'),
      isTrue,
    );
    expect(
      avatars.any((avatar) => avatar.imageUrl == 'https://example.com/bob.png'),
      isTrue,
    );

    await tester.tap(find.text('Alice Chen'));
    await tester.tap(find.text('Bob Lin'));
    await tester.pump();
    await tester.tap(find.text('完成(2)'));
    await tester.pumpAndSettle();

    expect(find.text('创建群聊'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('create_group_name_field')),
      findsOneWidget,
    );
    expect(find.text('群成员'), findsOneWidget);
    expect(find.text('2人'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('create_group_avatar_picker')), findsNothing);
    expect(
      find.byKey(const ValueKey('create_group_composite_avatar')),
      findsOneWidget,
    );

    await tester.tap(find.text('完成创建'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 10 && sentInviteCards.length < 2; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0;
        i < 10 && client.getRoomById('!new-group:p2p-im.com') == null;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(asClient.createdGroupName, 'Alice Chen、Bob Lin的群聊');
    expect(asClient.createdGroupAvatarUrl, '');
    expect(
      asClient.createdGroupInvites,
      ['@alice:p2p-liyanan.com', '@bob:p2p-liyanan.com'],
    );
    expect(asClient.inviteGroupMembersCalls, 1);
    expect(asClient.invitedGroupRoomId, '!new-group:p2p-im.com');
    expect(
      asClient.invitedGroupMembers,
      ['@alice:p2p-liyanan.com', '@bob:p2p-liyanan.com'],
    );
    expect(sentInviteCards, hasLength(2), reason: requestPaths.join('\n'));
    expect(
      sentInviteCards.map((body) => body['direct_room_id']).toSet(),
      {'!alice:p2p-im.com', '!bob:p2p-im.com'},
    );
    for (final body in sentInviteCards) {
      expect(body['msgtype'], 'p2p.group.invite.v1');
      expect(body['group_room_id'], '!new-group:p2p-im.com');
      expect(body['group_name'], 'Alice Chen、Bob Lin的群聊');
      expect(body['inviter_mxid'], '@owner:p2p-im.com');
      expect(
        body['inviter_avatar_url'],
        'https://p2p-im.com/_matrix/media/v3/download/p2p-im.com/owner-avatar',
      );
      expect(body['body'], '邀请加入群聊\nAlice Chen、Bob Lin的群聊');
    }
    final createdRoom = client.getRoomById('!new-group:p2p-im.com');
    expect(createdRoom, isNotNull);
    expect(createdRoom!.avatar, isNull);
    expect(
      createdRoom.getState(EventTypes.RoomMember, '@owner:p2p-im.com'),
      isNotNull,
    );
    expect(
      createdRoom.getState(EventTypes.RoomMember, '@alice:p2p-liyanan.com'),
      isNull,
    );
    expect(
      createdRoom.getState(EventTypes.RoomMember, '@bob:p2p-liyanan.com'),
      isNull,
    );
  });

  testWidgets('messages hide Matrix group invite room before AS join',
      (tester) async {
    final client = Client('DirexioGroupInviteRoomHiddenHomeListTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!invited-group:p2p-im.com',
      name: '未加入群',
      membership: Membership.invite,
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    expect(find.text('未加入群'), findsNothing);
    expect(find.text('还没有会话'), findsOneWidget);
  });

  testWidgets(
      'group detail shows real members and hides management for members',
      (tester) async {
    final client = Client('DirexioGroupDetailMemberTest')
      ..setUserId('@member:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [matrixClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupDetailPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('聊天信息(2)'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Carol'), findsNothing);
    expect(find.text('群管理'), findsNothing);
    expect(find.text('群公告'), findsNothing);
    expect(find.text('设置当前聊天背景'), findsNothing);
  });

  testWidgets('group detail rejects mock group ids', (tester) async {
    final client = Client('DirexioGroupDetailRejectMockTest')
      ..setUserId('@owner:p2p-im.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupDetailPage(roomId: 'mock_core_group'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('群组不存在'), findsOneWidget);
    expect(find.text('聊天信息(6)'), findsNothing);
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('group detail keeps management visible for group owner',
      (tester) async {
    final client = Client('DirexioGroupDetailOwnerTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [matrixClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupDetailPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('聊天信息(2)'), findsOneWidget);
    expect(find.text('群管理'), findsOneWidget);
    expect(find.text('群公告'), findsNothing);
    expect(find.text('设置当前聊天背景'), findsNothing);
  });

  testWidgets('group detail owner dissolves through AS and refreshes bootstrap',
      (tester) async {
    final client = Client('DirexioGroupDetailLeaveAsTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final initialBootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final refreshedBootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 8, 1),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient()
      ..bootstrapAfterLeave = refreshedBootstrap;
    final bootstrapStore = _MemoryAsBootstrapStore();
    final router = GoRouter(
      initialLocation:
          '/group-detail/${Uri.encodeComponent('!group:p2p-im.com')}',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HomeRoot')),
        ),
        GoRoute(
          path: '/group-detail/:roomId',
          builder: (_, state) => GroupDetailPage(
            roomId: state.pathParameters['roomId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(asClient),
          asBootstrapRepositoryProvider.overrideWithValue(
            AsBootstrapRepository(
              loadBootstrap: asClient.syncBootstrap,
              store: bootstrapStore,
            ),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: initialBootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('解散群聊'));
    await tester.tap(find.text('解散群聊'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('解散').last);
    await tester.pumpAndSettle();

    expect(asClient.dissolveGroupCalls, 1);
    expect(asClient.dissolvedGroupRoomId, '!group:p2p-im.com');
    expect(asClient.leaveGroupCalls, 0);
    expect(find.text('HomeRoot'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
    );
    expect(container.read(asSyncCacheProvider).bootstrap?.groups, isEmpty);
    expect(bootstrapStore.value?.groups, isEmpty);
  });

  testWidgets('group detail invites accepted non-members through AS',
      (tester) async {
    var matrixInviteCardSends = 0;
    final client = Client(
      'DirexioGroupDetailInviteAsTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
          matrixInviteCardSends++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['msgtype'], 'p2p.group.invite.v1');
          expect(body['group_room_id'], '!group:p2p-im.com');
          expect(body['group_name'], '真实群');
          expect(body['direct_room_id'], '!carol:p2p-im.com');
          return http.Response(
            r'{"event_id":"$group-invite-card"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-liyanan.com': 'Alice'},
    );
    _addUndirectedJoinedRoom(
      client,
      roomId: '!carol:p2p-im.com',
      peerMxid: '@carol:p2p-carol.com',
      peerName: 'Carol',
    );
    expect(client.getRoomById('!carol:p2p-im.com'), isNotNull);
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 9),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-liyanan.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
        AsSyncContact(
          userId: '@carol:p2p-carol.com',
          displayName: 'Carol',
          avatarUrl: '',
          roomId: '!carol:p2p-im.com',
          domain: 'p2p-carol.com',
          status: 'accepted',
        ),
        AsSyncContact(
          userId: '@pending:p2p-pending.com',
          displayName: 'Pending',
          avatarUrl: '',
          roomId: '!pending:p2p-im.com',
          domain: 'p2p-pending.com',
          status: 'pending_outbound',
        ),
      ],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(asClient),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupDetailPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('邀请'));
    await tester.pumpAndSettle();

    expect(find.text('添加群成员'), findsOneWidget);
    expect(find.text('Carol'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);

    await tester.tap(find.text('Carol'));
    await tester.pump();
    await tester.tap(find.text('发送邀请'));
    await tester.pumpAndSettle();

    expect(asClient.inviteGroupMembersCalls, 1);
    expect(asClient.invitedGroupRoomId, '!group:p2p-im.com');
    expect(asClient.invitedGroupMembers, ['@carol:p2p-carol.com']);
    expect(matrixInviteCardSends, 1);
  });

  testWidgets('group info invite button posts member invites through AS',
      (tester) async {
    var matrixInviteCardSends = 0;
    final matrixRequestPaths = <String>[];
    final client = Client(
      'DirexioGroupInfoInviteAsTest',
      httpClient: MockClient((request) async {
        matrixRequestPaths.add(request.url.path);
        if (request.url.path.contains('/send/m.room.message')) {
          matrixInviteCardSends++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['msgtype'], 'p2p.group.invite.v1');
          expect(body['group_room_id'], '!group:p2p-im.com');
          expect(body['group_name'], '真实群');
          expect(body['direct_room_id'], '!carol:p2p-im.com');
          return http.Response(
            r'{"event_id":"$group-invite-card"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-liyanan.com': 'Alice'},
    );
    _addUndirectedJoinedRoom(
      client,
      roomId: '!carol:p2p-im.com',
      peerMxid: '@carol:p2p-carol.com',
      peerName: 'Carol',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 15, 9),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-liyanan.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
        AsSyncContact(
          userId: '@carol:p2p-carol.com',
          displayName: 'Carol',
          avatarUrl: '',
          roomId: '!carol:p2p-im.com',
          domain: 'p2p-carol.com',
          status: 'accepted',
        ),
      ],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(asClient),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupInfoPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    final inviteChip = find.byKey(const ValueKey('group_info_invite_member'));
    await tester.ensureVisible(inviteChip);
    await tester.pump();
    await tester.tap(inviteChip);
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .ancestor(
            of: find.text('Carol'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(find.text('发送邀请'));
    await tester.pumpAndSettle();

    expect(asClient.inviteGroupMembersCalls, 1);
    expect(asClient.invitedGroupRoomId, '!group:p2p-im.com');
    expect(asClient.invitedGroupMembers, ['@carol:p2p-carol.com']);
    expect(matrixInviteCardSends, 1, reason: matrixRequestPaths.join('\n'));
  });

  testWidgets('group info prefers product group name over empty Matrix title',
      (tester) async {
    const roomId = '!group:p2p-im.com';
    final client = Client('DirexioGroupInfoProductNameTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: 'Empty chat',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 24, 9),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: '产品群名',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupInfoPage(roomId: roomId),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('产品群名'), findsOneWidget);
    expect(find.text('Empty chat'), findsNothing);
  });

  testWidgets('group detail reports roomless invite contacts as skipped',
      (tester) async {
    final client = Client('DirexioGroupDetailInviteRoomlessTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-liyanan.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 20, 9),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-liyanan.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
        AsSyncContact(
          userId: '@roomless:p2p-roomless.com',
          displayName: 'Roomless',
          avatarUrl: '',
          roomId: '',
          domain: 'p2p-roomless.com',
          status: 'accepted',
        ),
      ],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupDetailPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('邀请'));
    await tester.pumpAndSettle();

    expect(find.text('添加群成员'), findsOneWidget);
    expect(find.text('Roomless'), findsOneWidget);

    await tester.tap(find.text('Roomless'));
    await tester.pump();
    await tester.tap(find.text('发送邀请'));
    await tester.pumpAndSettle();

    expect(asClient.inviteGroupMembersCalls, 0);
    expect(find.text('已发送 0 个群邀请卡片，1 个联系人缺少私聊，已跳过'), findsOneWidget);
  });

  testWidgets('group info shows management only to group owner',
      (tester) async {
    final memberClient = Client('DirexioGroupInfoMemberManageTest')
      ..setUserId('@member:p2p-im.com');
    _addNamedGroupRoom(
      memberClient,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [matrixClientProvider.overrideWithValue(memberClient)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupInfoPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('群管理'), findsNothing);
    expect(find.text('移除'), findsNothing);

    final ownerClient = Client('DirexioGroupInfoOwnerManageTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      ownerClient,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [matrixClientProvider.overrideWithValue(ownerClient)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupInfoPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('群管理'), findsOneWidget);
    expect(find.text('移除'), findsOneWidget);
  });

  testWidgets('group info member count uses Matrix and AS union',
      (tester) async {
    final client = Client('DirexioGroupInfoMemberCountUnionTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(
            _GroupMembersAsClient(
              const [
                AsGroupMember(
                  roomId: '!group:p2p-im.com',
                  userMxid: '@owner:p2p-im.com',
                  role: 'owner',
                  status: 'joined',
                  displayName: 'Owner',
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupInfoPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('聊天信息(2)'), findsOneWidget);
    expect(find.text('聊天信息(1)'), findsNothing);
  });

  testWidgets('group info persists message mute toggle for notification sound',
      (tester) async {
    const roomId = '!group-muted:p2p-im.com';
    final client = Client('DirexioGroupInfoMuteTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: '免打扰群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final store = _MemoryConversationPreferencesStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          conversationPreferencesStoreProvider.overrideWith(
            (ref) async => store,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupInfoPage(roomId: roomId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final muteSwitch = find.widgetWithText(InfoSwitchRow, '消息免打扰');
    expect(muteSwitch, findsOneWidget);
    expect(
      tester
          .widget<Switch>(
            find.descendant(of: muteSwitch, matching: find.byType(Switch)),
          )
          .value,
      isFalse,
    );

    await tester.tap(
      find.descendant(of: muteSwitch, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(store.data.mutedConversationIds, contains(roomId));
    expect(
      shouldPlayMessageSound(
        _messageSoundUpdate(roomId: roomId, sender: '@alice:p2p-im.com'),
        currentUserId: '@owner:p2p-im.com',
        mutedConversationIds: store.data.mutedConversationIds,
      ),
      isFalse,
    );
  });

  testWidgets('group info identity header shows and copies room uid',
      (tester) async {
    var clipboardText = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboardText = (call.arguments as Map)['text'] as String? ?? '';
            return null;
          case 'Clipboard.getData':
            return {'text': clipboardText};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final client = Client('DirexioGroupInfoHeaderUidTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [matrixClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupInfoPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('真实群'), findsOneWidget);
    expect(find.text('!group:p2p-im.com'), findsOneWidget);

    await tester.tap(find.text('!group:p2p-im.com'));
    await tester.pump();

    expect(find.text('已复制 UID'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final copied = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copied?.text, '!group:p2p-im.com');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('group info identity header uses composite member avatar',
      (tester) async {
    const roomId = '!group-info-avatar:p2p-im.com';
    final client = Client('DirexioGroupInfoCompositeAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    final room = _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {
        '@alice:p2p-im.com': 'Alice',
        '@bob:p2p-im.com': 'Bob',
      },
      memberAvatarUrls: const {
        '@alice:p2p-im.com': 'https://example.com/alice.png',
        '@bob:p2p-im.com': 'https://example.com/bob.png',
      },
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomAvatar,
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: const {'url': 'https://example.com/room-avatar.png'},
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asSyncCacheProvider.overrideWith(
            (ref) => const AsSyncCacheState(),
          ),
          groupAvatarMemberOrdersProvider.overrideWith((ref) => const {}),
          groupAvatarMemberAvatarsProvider.overrideWith((ref) => const {}),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupInfoPage(roomId: roomId),
        ),
      ),
    );
    await tester.pump();

    final identityHeader = find.byKey(
      const ValueKey('group_info_identity_header_$roomId'),
    );
    expect(identityHeader, findsOneWidget);
    expect(
      find.descendant(
        of: identityHeader,
        matching: find.byType(GroupCompositeAvatar),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: identityHeader,
        matching: find.byKey(
          const ValueKey(
            'group_composite_avatar_member_@alice:p2p-im.com_https://example.com/alice.png',
          ),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('group info member avatars wrap into a scrollable grid',
      (tester) async {
    final client = Client('DirexioGroupInfoMemberGridTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {
        '@member01:p2p-im.com': 'Member 01',
        '@member02:p2p-im.com': 'Member 02',
        '@member03:p2p-im.com': 'Member 03',
        '@member04:p2p-im.com': 'Member 04',
        '@member05:p2p-im.com': 'Member 05',
        '@member06:p2p-im.com': 'Member 06',
        '@member07:p2p-im.com': 'Member 07',
        '@member08:p2p-im.com': 'Member 08',
        '@member09:p2p-im.com': 'Member 09',
        '@member10:p2p-im.com': 'Member 10',
        '@member11:p2p-im.com': 'Member 11',
        '@member12:p2p-im.com': 'Member 12',
        '@member13:p2p-im.com': 'Member 13',
        '@member14:p2p-im.com': 'Member 14',
        '@member15:p2p-im.com': 'Member 15',
        '@member16:p2p-im.com': 'Member 16',
        '@member17:p2p-im.com': 'Member 17',
        '@member18:p2p-im.com': 'Member 18',
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [matrixClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupInfoPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    final memberGrid = tester.widget<SizedBox>(
      find.byKey(const ValueKey('group_info_member_grid')),
    );
    expect(memberGrid.height, 316);
    final gridContent = tester.widget<SizedBox>(
      find.byKey(const ValueKey('group_info_member_grid_content')),
    );
    expect(gridContent.width, 308);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('group_info_member_grid')),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });

  testWidgets('group info uses current profile for owner member chip',
      (tester) async {
    final client = Client('DirexioGroupInfoOwnerProfileTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          currentUserProfileProvider.overrideWith(
            (ref) async => Profile(
              userId: '@owner:p2p-im.com',
              displayName: '群主 Owner',
              avatarUrl: Uri.parse('mxc://p2p-im.com/owner-avatar'),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupInfoPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('群主'), findsOneWidget);
    expect(find.text('owner'), findsNothing);
    final ownerChip = find.byKey(
      const ValueKey('group_info_member_@owner:p2p-im.com'),
    );
    expect(ownerChip, findsOneWidget);
    final ownerAvatar = tester.widget<PortalAvatar>(
      find.descendant(of: ownerChip, matching: find.byType(PortalAvatar)),
    );
    expect(ownerAvatar.imageUrl, contains('/download/p2p-im.com/owner-avatar'));
  });

  testWidgets('group info hides owner fallback for my group nickname',
      (tester) async {
    final client = Client('DirexioGroupInfoOwnerNicknameTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {
        '@owner:p2p-im.com': 'owner',
        '@alice:p2p-im.com': 'Alice',
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          currentUserProfileProvider.overrideWith(
            (ref) async => Profile(
              userId: '@owner:p2p-im.com',
              displayName: '真实昵称',
              avatarUrl: null,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupInfoPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('真实昵称'), findsWidgets);
    expect(find.text('owner'), findsNothing);
  });

  testWidgets('group info member avatar opens chat avatar profile',
      (tester) async {
    final client = Client('DirexioGroupInfoMemberProfileTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation:
          '/group-info/${Uri.encodeComponent('!group:p2p-im.com')}',
      routes: [
        GoRoute(
          path: '/group-info/:roomId',
          builder: (_, state) => GroupInfoPage(
            roomId: state.pathParameters['roomId']!,
          ),
        ),
        GoRoute(
          path: '/contact/:userId',
          builder: (_, state) => ContactDetailPage(
            userId: state.pathParameters['userId']!,
            fromChatAvatar:
                state.uri.queryParameters['source'] == 'chat_avatar',
          ),
        ),
        GoRoute(
          path: '/me/profile',
          builder: (_, __) => const Scaffold(body: Text('我的资料')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('group_info_member_@alice:p2p-im.com')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ContactDetailPage), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('group_info_member_@owner:p2p-im.com')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ContactDetailPage), findsOneWidget);
    expect(find.text('owner'), findsWidgets);
  });

  testWidgets('group owner can remove member from group info', (tester) async {
    final client = Client('DirexioGroupInfoRemoveMemberTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final asClient = _TrackingAsClient()
      ..groupMembers = const [
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@owner:p2p-im.com',
          role: asChannelRoleOwner,
          status: asChannelMemberStatusJoined,
        ),
        AsGroupMember(
          roomId: '!group:p2p-im.com',
          userMxid: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: 'https://example.com/alice.png',
          role: asChannelRoleMember,
          status: asChannelMemberStatusJoined,
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupInfoPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('group_info_member_@alice:p2p-im.com')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey(
          'group_composite_avatar_member_@alice:p2p-im.com_https://example.com/alice.png',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey(
      'group_info_remove_member_@alice:p2p-im.com',
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '移除'));
    await tester.pumpAndSettle();

    expect(asClient.removeGroupMemberCalls, 1);
    expect(asClient.removedGroupRoomId, '!group:p2p-im.com');
    expect(asClient.removedGroupPeerMxid, '@alice:p2p-im.com');
    expect(
      find.byKey(const ValueKey('group_info_member_@alice:p2p-im.com')),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey(
          'group_composite_avatar_member_@alice:p2p-im.com_https://example.com/alice.png',
        ),
      ),
      findsNothing,
    );

    final room = client.getRoomById('!group:p2p-im.com')!;
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@owner:p2p-im.com',
        stateKey: '@alice:p2p-im.com',
        content: const {
          'membership': 'join',
          'displayname': 'Alice',
          'avatar_url': 'https://example.com/alice.png',
        },
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GroupInfoPage)),
    );
    container.invalidate(
      groupMembersProvider(
        const GroupMembersKey(
          roomId: '!group:p2p-im.com',
          status: asChannelMemberStatusJoined,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('聊天信息(2)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('group_info_member_@alice:p2p-im.com')),
      findsOneWidget,
    );
  });

  testWidgets(
      'group info edits remark, pins, nickname, and clears room history',
      (tester) async {
    final nicknameRequests = <http.Request>[];
    final client = Client(
      'DirexioGroupInfoSettingsTest',
      httpClient: MockClient((request) async {
        nicknameRequests.add(request);
        return http.Response(
          '{"event_id":"\$nickname"}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addUndirectedJoinedRoom(
      client,
      roomId: '!alice:p2p-im.com',
      peerMxid: '@alice:p2p-im.com',
      peerName: 'Alice',
      peerAvatarUrl: 'https://example.com/alice.png',
    );
    _addUndirectedJoinedRoom(
      client,
      roomId: '!bob:p2p-im.com',
      peerMxid: '@bob:p2p-im.com',
      peerName: 'Bob',
      peerAvatarUrl: 'https://example.com/bob.png',
    );
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@owner:p2p-im.com': 'Owner'},
    );
    final clearStore = _MemoryChatClearStateStore();
    final asClient = _TrackingAsClient();
    final visibilityClient = _RecordingMatrixMessageVisibilityClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          matrixMessageVisibilityClientProvider.overrideWithValue(
            visibilityClient,
          ),
          chatClearStateStoreProvider.overrideWith((ref) async => clearStore),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupInfoPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('设置备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '项目群');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('项目群'), findsOneWidget);
    expect(find.text('群聊备注已更新'), findsOneWidget);

    await tester.ensureVisible(find.text('置顶聊天'));
    await tester.pump();
    await tester.tap(find.byType(Switch).at(1));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GroupInfoPage)),
    );
    expect(
      container.read(pinnedConversationIdsProvider),
      contains('!group:p2p-im.com'),
    );

    await tester.ensureVisible(find.text('我在本群昵称'));
    await tester.pump();
    await tester.tap(find.text('我在本群昵称'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '群内 Owner');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect(nicknameRequests, isNotEmpty);
    expect(nicknameRequests.last.body, contains('群内 Owner'));

    await tester.ensureVisible(find.text('清空聊天记录'));
    await tester.pump();
    await tester.tap(find.text('清空聊天记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '清空'));
    await tester.pumpAndSettle();
    expect(clearStore.roomClearedBeforeTs['!group:p2p-im.com'], greaterThan(0));
    expect(visibilityClient.clearCalls, 1);
    expect(
      container
          .read(asSyncCacheProvider)
          .localRoomClearedBeforeTs['!group:p2p-im.com'],
      greaterThan(0),
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('group detail shows owner invite permission failure',
      (tester) async {
    final client = Client('DirexioGroupInvitePermissionFailureTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-liyanan.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 14),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@carol:p2p-carol.com',
          displayName: 'Carol',
          avatarUrl: '',
          roomId: '!dm-carol:p2p-im.com',
          domain: 'p2p-carol.com',
          status: 'accepted',
        ),
      ],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          invitePolicy: groupInvitePolicyOwner,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient()
      ..inviteGroupMembersError = AsClientException(
        'group invite requires owner',
        statusCode: 403,
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupDetailPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('邀请'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carol'));
    await tester.pump();
    await tester.tap(find.text('发送邀请'));
    await tester.pumpAndSettle();

    expect(asClient.inviteGroupMembersCalls, 1);
    expect(find.text('该群只有群主可添加成员'), findsOneWidget);
    expect(find.textContaining('发送群邀请失败'), findsNothing);
  });

  testWidgets('group management renders name and mute controls',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupManagePage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('群管理'), findsOneWidget);
    expect(find.text('群名称'), findsOneWidget);
    expect(find.text('全员禁言'), findsOneWidget);
    expect(find.text('退出群聊'), findsOneWidget);
    expect(find.text('二维码进群'), findsNothing);
    expect(find.text('群主管理权转让'), findsNothing);
  });

  testWidgets('group management name value and chevron stay on row right',
      (tester) async {
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 13),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          isOwned: true,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupManagePage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    final labelRight = tester.getTopRight(find.text('群名称')).dx;
    final valueRight = tester
        .getTopRight(
          find.byKey(const ValueKey('group_manage_nav_value_群名称')),
        )
        .dx;
    final chevronRight = tester
        .getTopRight(
          find.byKey(const ValueKey('group_manage_nav_chevron_群名称')),
        )
        .dx;
    final screenRight =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;

    expect(find.text('真实群'), findsOneWidget);
    expect(valueRight, greaterThan(labelRight));
    expect(chevronRight, greaterThan(valueRight));
    expect(chevronRight, greaterThan(screenRight - 60));
  });

  testWidgets('group management mute switch calls AS APIs', (tester) async {
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupManagePage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(asClient.muteGroupCalls, 1);
    expect(asClient.mutedGroupRoomId, '!group:p2p-im.com');
    expect(find.text('已开启全员禁言'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(asClient.unmuteGroupCalls, 1);
    expect(asClient.unmutedGroupRoomId, '!group:p2p-im.com');
    expect(find.text('已解除全员禁言'), findsOneWidget);
  });

  testWidgets('group management mute switch reflects bootstrap mute state',
      (tester) async {
    final asClient = _TrackingAsClient();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          isOwned: true,
          muted: true,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupManagePage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(asClient.unmuteGroupCalls, 1);
    expect(asClient.unmutedGroupRoomId, '!group:p2p-im.com');
  });

  testWidgets('group management edits group name through AS', (tester) async {
    final asClient = _TrackingAsClient();
    final client = Client('DirexioGroupManageRenameTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 13),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          isOwned: true,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupManagePage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('群名称'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新的群名称');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(asClient.updateGroupProfileCalls, 1);
    expect(asClient.updatedGroupProfileRoomId, '!group:p2p-im.com');
    expect(asClient.updatedGroupProfileName, '新的群名称');
    expect(asClient.updatedGroupProfileAvatarUrl, isEmpty);

    expect(find.text('新的群名称'), findsOneWidget);
  });

  testWidgets('group management updates invite policy through AS',
      (tester) async {
    final asClient = _TrackingAsClient();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 13),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          isOwned: true,
          invitePolicy: 'all_members',
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupManagePage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('添加成员权限'), findsOneWidget);
    expect(find.text('所有成员可添加'), findsOneWidget);
    expect(find.text('群主可添加'), findsOneWidget);

    await tester.tap(find.text('群主可添加'));
    await tester.pumpAndSettle();

    expect(asClient.updateGroupInvitePolicyCalls, 1);
    expect(asClient.updatedGroupInvitePolicyRoomId, '!group:p2p-im.com');
    expect(asClient.updatedGroupInvitePolicy, 'owner');
    expect(find.text('已更新添加成员权限'), findsOneWidget);
  });

  testWidgets('group chat text send uses Matrix SDK room send endpoint',
      (tester) async {
    var matrixSendCalls = 0;
    final client = Client(
      'DirexioGroupTextSendAsTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
          matrixSendCalls++;
          return http.Response(
            r'{"event_id":"$group-message"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '群聊走 Matrix');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pump(const Duration(seconds: 3));

    expect(matrixSendCalls, 1);
  });

  testWidgets('group chat header omits the title avatar', (tester) async {
    final client = Client('DirexioGroupChatCompositeHeaderAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {
        '@alice:p2p-im.com': 'Alice',
        '@bob:p2p-im.com': 'Bob',
      },
    );
    client.getRoomById('!group:p2p-im.com')!.setState(
          StrippedStateEvent(
            type: EventTypes.RoomAvatar,
            senderId: '@owner:p2p-im.com',
            stateKey: '',
            content: const {'url': 'https://example.com/single-owner.png'},
          ),
        );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 9),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: 'https://example.com/alice.png',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
        AsSyncContact(
          userId: '@bob:p2p-im.com',
          displayName: 'Bob',
          avatarUrl: 'https://example.com/bob.png',
          roomId: '!bob:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          currentUserProfileProvider.overrideWith(
            (ref) async => Profile(
              userId: '@owner:p2p-im.com',
              displayName: 'Owner',
              avatarUrl: Uri.parse('https://example.com/owner.png'),
            ),
          ),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('group_chat_header_avatar_!group:p2p-im.com')),
      findsNothing,
    );
    expect(find.text('真实群'), findsOneWidget);
  });

  testWidgets('group chat shows removed banner after Matrix leave',
      (tester) async {
    var matrixSendCalls = 0;
    final client = Client(
      'DirexioGroupRemovedComposerBannerTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
          matrixSendCalls++;
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: '!removed-group:p2p-im.com',
      name: '已退出群',
      creatorMxid: '@owner:p2p-im.com',
      membership: Membership.leave,
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 22, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!removed-group:p2p-im.com',
          name: '已退出群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: 'left',
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(roomId: '!removed-group:p2p-im.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无法在已退出的群聊中发送消息'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('发送'), findsNothing);
    expect(matrixSendCalls, 0);
  });

  testWidgets('channel conversation text input is enabled for joined channel',
      (tester) async {
    var matrixSendCalls = 0;
    final client = Client(
      'DirexioChannelTextSendAsTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
          matrixSendCalls++;
          return http.Response(
            r'{"event_id":"$channel-message"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: '!channel:p2p-im.com',
      name: '频道会话',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 17, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          channelId: 'ch_joined',
          roomId: '!channel:p2p-im.com',
          name: '频道会话',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: asChannelMemberStatusJoined,
          tags: ['文字'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(
            roomId: '!channel:p2p-im.com',
            channelId: 'ch_joined',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '频道消息');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pump(const Duration(seconds: 3));

    expect(matrixSendCalls, 1);
  });

  testWidgets('channel conversation opened with channel id uses cached room id',
      (tester) async {
    var matrixSendCalls = 0;
    final client = Client(
      'DirexioChannelConversationChannelIdRouteTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
          matrixSendCalls++;
          return http.Response(
            r'{"event_id":"$cached-channel-message"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: '!cached-channel:p2p-im.com',
      name: '缓存文字频道',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 20, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          channelId: 'ch_cached_chat',
          roomId: '!cached-channel:p2p-im.com',
          name: '缓存文字频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: asChannelMemberStatusJoined,
          channelType: asChannelTypeChat,
          tags: ['文字'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(
            roomId: 'ch_cached_chat',
            channelId: 'ch_cached_chat',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('缓存文字频道'), findsOneWidget);
    expect(find.text('频道不存在'), findsNothing);

    await tester.enterText(find.byType(TextField), '频道缓存消息');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pump(const Duration(seconds: 3));

    expect(matrixSendCalls, 1);
  });

  testWidgets(
      'channel conversation blocks invited channel before Matrix join projection',
      (tester) async {
    var matrixSendCalls = 0;
    final client = Client(
      'DirexioChannelInvitedSendBlockTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
          matrixSendCalls++;
          return http.Response(
            r'{"event_id":"$channel-message"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: '!channel-invite:p2p-im.com',
      name: '待加入频道',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 19, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          channelId: 'ch_invite',
          roomId: '!channel-invite:p2p-im.com',
          name: '待加入频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: asChannelMemberStatusInvite,
          tags: ['文字'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(
            roomId: '!channel-invite:p2p-im.com',
            channelId: 'ch_invite',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发送'), findsNothing);
    expect(matrixSendCalls, 0);
  });

  testWidgets('joined channel sends through Matrix SDK under ProductPolicy',
      (tester) async {
    _mockAudioRecorderPlugins(tester);
    var matrixSendCalls = 0;
    final client = Client(
      'DirexioMutedChannelTextSendTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
          matrixSendCalls++;
          return http.Response(
            r'{"event_id":"$channel-product-policy-message"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    final room = _addNamedGroupRoom(
      client,
      roomId: '!muted-channel:p2p-im.com',
      name: '禁言频道',
      creatorMxid: '@creator:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomPowerLevels,
        senderId: '@creator:p2p-im.com',
        stateKey: '',
        content: const {
          'users_default': 0,
          'events_default': 50,
          'events': {'m.room.message': 50},
        },
      ),
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 18, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          channelId: 'ch_muted',
          roomId: '!muted-channel:p2p-im.com',
          name: '禁言频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: asChannelMemberStatusJoined,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );
    final outboxStore = _MemoryLocalOutboxStore();
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith((ref) async => outboxStore),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(
            roomId: '!muted-channel:p2p-im.com',
            channelId: 'ch_muted',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '禁言消息');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(matrixSendCalls, 1);
    expect(outboxStore.items, isEmpty);
  });

  testWidgets('channel conversation title prefers channel name over room id',
      (tester) async {
    final client = Client(
      'DirexioChannelTitleTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: '!channel-title:p2p-im.com',
      name: '!channel-title:p2p-im.com',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith((ref) => const AsSyncCacheState()),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(
            roomId: '!channel-title:p2p-im.com',
            channelId: 'ch_title',
            channelName: '综合讨论',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('综合讨论'), findsOneWidget);
    expect(find.text('!channel-title:p2p-im.com'), findsNothing);
  });

  testWidgets('joined channel opened as group route uses channel title',
      (tester) async {
    final client = Client(
      'DirexioChannelGroupRouteTitleTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: '!joined-channel:p2p-im.com',
      name: '!joined-channel:p2p-im.com',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 17, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          channelId: 'ch_group_route',
          roomId: '!joined-channel:p2p-im.com',
          name: '已加入频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: asChannelMemberStatusJoined,
          tags: ['文字'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(roomId: '!joined-channel:p2p-im.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已加入频道'), findsOneWidget);
    expect(find.text('!joined-channel:p2p-im.com'), findsNothing);
  });

  testWidgets('channel conversation ignores id-shaped bootstrap title',
      (tester) async {
    final client = Client(
      'DirexioChannelIdTitleTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: '!invited-channel:p2p-im.com',
      name: '真实频道名',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 17, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          channelId: 'ch_invited',
          roomId: '!invited-channel:p2p-im.com',
          name: 'ch_invited',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: asChannelMemberStatusJoined,
          tags: ['文字'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(
            roomId: '!invited-channel:p2p-im.com',
            channelId: 'ch_invited',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('真实频道名'), findsOneWidget);
    expect(find.text('ch_invited'), findsNothing);
  });

  testWidgets('channel conversation header shows member count', (tester) async {
    final client = Client(
      'DirexioChannelMemberCountHeaderTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: '!member-count-channel:p2p-im.com',
      name: '成员频道',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 17, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          channelId: 'ch_members',
          roomId: '!member-count-channel:p2p-im.com',
          name: '成员频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: asChannelMemberStatusJoined,
          memberCount: 18,
          tags: ['文字'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(
            roomId: '!member-count-channel:p2p-im.com',
            channelId: 'ch_members',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('成员频道'), findsOneWidget);
    expect(find.text('18 名成员'), findsOneWidget);
  });

  testWidgets('channel conversation skips call API and limits attachment tools',
      (tester) async {
    final client = Client(
      'DirexioChannelAttachmentToolsTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: '!channel-tools:p2p-im.com',
      name: '频道会话',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 17, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          channelId: 'ch_tools',
          roomId: '!channel-tools:p2p-im.com',
          name: '频道会话',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: asChannelMemberStatusJoined,
          tags: ['文字'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(
            roomId: '!channel-tools:p2p-im.com',
            channelId: 'ch_tools',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(asClient.listCallsCount, 0);

    await tester.tap(find.byKey(const ValueKey('chat_input_plus_circle')));
    await tester.pumpAndSettle();

    for (final label in ['相册', '拍摄', '视频', '文件']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final label in ['语音通话', '视频通话', '位置', '个人名片']) {
      expect(find.text(label), findsNothing);
    }
    expect(asClient.listCallsCount, 0);
  });

  testWidgets('group chat @ mention picker inserts member and sends metadata',
      (tester) async {
    Map<String, dynamic>? sentMatrixContent;
    final client = Client(
      'DirexioGroupMentionSendTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
          sentMatrixContent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            r'{"event_id":"$group-mention-message"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '@');
    await tester.pumpAndSettle();
    expect(find.text('选择提醒的人'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('group_mention_member_@alice:p2p-im.com')),
    );
    await tester.pumpAndSettle();

    expect(find.text('选择提醒的人'), findsNothing);
    await tester.enterText(find.byType(TextField), '@Alice hello');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pump(const Duration(seconds: 3));

    expect(sentMatrixContent?['body'], '@Alice hello');
    expect(sentMatrixContent?['mentions'], [
      {
        'user_id': '@alice:p2p-im.com',
        'display_name': 'Alice',
      },
    ]);
    expect(sentMatrixContent?['mentions_json'], isA<String>());
  });

  testWidgets('channel chat @ mention picker excludes portal agent',
      (tester) async {
    final client = Client(
      'DirexioChannelMentionAgentFilterTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: '!channel:p2p-im.com',
      name: '频道会话',
      creatorMxid: '@owner:p2p-im.com',
      members: const {
        '@alice:p2p-im.com': 'Alice',
        '@agent:p2p-im.com': 'Agent',
      },
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          channelId: 'ch_mention',
          roomId: '!channel:p2p-im.com',
          name: '频道会话',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: asChannelMemberStatusJoined,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(
            roomId: '!channel:p2p-im.com',
            channelId: 'ch_mention',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '@');
    await tester.pumpAndSettle();

    expect(find.text('选择提醒的人'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('group_mention_member_@alice:p2p-im.com')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('group_mention_member_@agent:p2p-im.com')),
      findsNothing,
    );
    expect(find.text('@agent:p2p-im.com'), findsNothing);
  });

  testWidgets('group chat recovers when Matrix room cache is missing',
      (tester) async {
    const roomId = '!group:p2p-im.com';
    const userId = '@owner:p2p-im.com';
    final client = _RecoveringGroupRoomClient(
      recoveryRoomId: roomId,
      recoveryUserId: userId,
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 8),
      user: const AsSyncUser(userId: userId),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(roomId: roomId),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('真实群'), findsOneWidget);
    expect(find.text('这个群聊暂时无法打开'), findsNothing);

    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(client.getRoomById(roomId), isNotNull);
    expect(client.syncRequests, isNotEmpty);
    expect(client.syncRequests.single.fullState, isTrue);
    expect(client.syncRequests.single.since, isNull);
    expect(client.syncRequests.single.timeout, 0);
    final filter =
        jsonDecode(client.syncRequests.single.filter!) as Map<String, Object?>;
    final roomFilter = filter['room']! as Map<String, Object?>;
    final timelineFilter = roomFilter['timeline']! as Map<String, Object?>;
    expect(roomFilter['rooms'], [roomId]);
    expect(timelineFilter['limit'], chatOpenLocalHistoryPageSize);
    expect(find.text('正在恢复群聊...'), findsNothing);
    expect(find.text('群聊同步超时，请检查网络后重试'), findsNothing);
  });

  testWidgets('private chat rows use the same initial entrance motion as group',
      (tester) async {
    await _pumpDirectChatWithPeerTextEvent(
      tester,
      eventId: r'$direct-opened-history',
      body: '历史消息',
    );

    expect(
      find.byKey(
          const ValueKey(r'private_message_enter_$direct-opened-history')),
      findsOneWidget,
    );
  });

  testWidgets('empty group chat can pull to load server history',
      (tester) async {
    const roomId = '!empty-group:p2p-im.com';
    final client = Client('DirexioEmptyGroupPullHistoryTest')
      ..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'matrix-token';
    _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: '空群聊',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 20),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: '空群聊',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(roomId: roomId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有消息'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
  });

  testWidgets('group chat header opens active group call from title capsule',
      (tester) async {
    const roomId = '!group:p2p-im.com';
    final client = Client(
      'DirexioGroupActiveCallHeaderTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final voiceCallController = _IdleVoiceCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.connected,
        callType: ProductCallType.voice,
        roomId: roomId,
        roomName: '真实群',
        callId: 'as-group-call-1',
      ),
    );
    final router = GoRouter(
      initialLocation: '/group/${Uri.encodeComponent(roomId)}',
      routes: [
        GoRoute(
          path: '/group/:roomId',
          builder: (_, state) =>
              GroupChatPage(roomId: state.pathParameters['roomId']!),
        ),
        GoRoute(
          path: '/group-call/:roomId',
          builder: (_, state) => Text(
            '${state.pathParameters['roomId']} '
            '${state.uri.queryParameters['call_id']} '
            '${state.uri.queryParameters['incoming']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          voiceCallControllerProvider.overrideWithValue(voiceCallController),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('正在群通话'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat_header_title_capsule')));
    await tester.pumpAndSettle();

    expect(find.text('$roomId as-group-call-1 null'), findsOneWidget);
  });

  testWidgets('group chat renders group local media outbox items',
      (tester) async {
    final client = Client(
      'DirexioGroupMediaOutboxTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: '!group:p2p-im.com',
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final outboxStore = _MemoryLocalOutboxStore([
      LocalOutboxItem(
        id: 'group-file-1',
        conversationId: '!group:p2p-im.com',
        conversationType: LocalOutboxConversationType.group,
        messageKind: LocalOutboxMessageKind.file,
        text: '',
        filename: 'report.pdf',
        mimeType: 'application/pdf',
        bytes: _transparentPng,
        createdAt: DateTime.utc(2026, 5, 30, 9),
        status: LocalOutboxItemStatus.failed,
        runtimeId: 'old-runtime',
        batchId: 'batch-1',
        batchIndex: 0,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith((ref) async => outboxStore),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.byIcon(Symbols.refresh), findsOneWidget);
  });

  testWidgets('group chat renders received image as media instead of filename',
      (tester) async {
    const roomId = '!group:p2p-im.com';
    const imageName =
        'image_picker_11111111-AAAA-BBBB-CCCC-generated-photo.jpg';
    final client = Client(
      'DirexioGroupReceivedImageTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(roomId: roomId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await client.handleSync(
      SyncUpdate(
        nextBatch: 'after-image',
        rooms: RoomsUpdate(
          join: {
            roomId: JoinedRoomUpdate(
              timeline: TimelineUpdate(
                events: [
                  MatrixEvent(
                    type: EventTypes.Message,
                    eventId: r'$group-image',
                    roomId: roomId,
                    senderId: '@alice:p2p-im.com',
                    originServerTs: DateTime.utc(2026, 5, 30, 10),
                    content: const {
                      'msgtype': MessageTypes.Image,
                      'body': imageName,
                      'url': 'mxc://p2p-im.com/image',
                      'info': {
                        'mimetype': 'image/jpeg',
                        'size': 1024,
                        'w': 120,
                        'h': 80,
                      },
                    },
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(imageName), findsNothing);
    expect(find.byType(CachedThumbnailImage), findsOneWidget);
  });

  testWidgets('group chat renders received file as file card', (tester) async {
    const roomId = '!group:p2p-im.com';
    const fileName = 'quarterly-plan.pdf';
    final client = Client(
      'DirexioGroupReceivedFileTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(roomId: roomId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await client.handleSync(
      SyncUpdate(
        nextBatch: 'after-file',
        rooms: RoomsUpdate(
          join: {
            roomId: JoinedRoomUpdate(
              timeline: TimelineUpdate(
                events: [
                  MatrixEvent(
                    type: EventTypes.Message,
                    eventId: r'$group-file',
                    roomId: roomId,
                    senderId: '@alice:p2p-im.com',
                    originServerTs: DateTime.utc(2026, 5, 30, 10),
                    content: const {
                      'msgtype': MessageTypes.File,
                      'body': fileName,
                      'url': 'mxc://p2p-im.com/file',
                      'info': {
                        'mimetype': 'application/pdf',
                        'size': 2048,
                      },
                    },
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(fileName), findsOneWidget);
    expect(find.text('PDF · 2.0 KB'), findsOneWidget);
    expect(find.byIcon(Symbols.download), findsOneWidget);
  });

  testWidgets('group chat renders received video as media card',
      (tester) async {
    const roomId = '!group:p2p-im.com';
    const videoName = 'camera-roll-clip.mov';
    final client = Client(
      'DirexioGroupReceivedVideoTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addNamedGroupRoom(
      client,
      roomId: roomId,
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 30, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [
        AsSyncRoomSummary(
          roomId: roomId,
          name: '真实群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const GroupChatPage(roomId: roomId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await client.handleSync(
      SyncUpdate(
        nextBatch: 'after-video',
        rooms: RoomsUpdate(
          join: {
            roomId: JoinedRoomUpdate(
              timeline: TimelineUpdate(
                events: [
                  MatrixEvent(
                    type: EventTypes.Message,
                    eventId: r'$group-video',
                    roomId: roomId,
                    senderId: '@alice:p2p-im.com',
                    originServerTs: DateTime.utc(2026, 5, 30, 10),
                    content: const {
                      'msgtype': MessageTypes.Video,
                      'body': videoName,
                      'url': 'mxc://p2p-im.com/video',
                      'info': {
                        'mimetype': 'video/quicktime',
                        'size': 4096,
                        'thumbnail_url': 'mxc://p2p-im.com/thumb',
                      },
                    },
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(videoName), findsNothing);
    expect(find.byType(CachedThumbnailImage), findsOneWidget);
    expect(find.byIcon(Symbols.play_arrow), findsOneWidget);
  });

  testWidgets('group chat long press exposes direct chat actions',
      (tester) async {
    await _pumpGroupChatWithTextEvent(tester);

    await tester.longPress(find.text('群聊长按消息'));
    await tester.pumpAndSettle();

    expect(find.text('复制'), findsOneWidget);
    expect(find.text('转发'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('多选'), findsOneWidget);
    expect(find.text('引用'), findsOneWidget);
  });

  testWidgets('group chat recalls own message through Matrix redaction',
      (tester) async {
    final harness = await _pumpGroupChatWithTextEvent(
      tester,
      eventId: r'$group-own-text',
      body: '我发出的群聊消息',
      senderMxid: '@owner:p2p-im.com',
    );

    await tester.longPress(find.text('我发出的群聊消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('撤回'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '撤回'));
    await tester.pumpAndSettle();

    expect(harness.matrixRedactionPaths, hasLength(1));
    expect(harness.matrixRedactionPaths.single,
        contains('/redact/%24group-own-text/'));
  });

  testWidgets('group chat uses current profile avatar for own messages',
      (tester) async {
    await _pumpGroupChatWithTextEvent(
      tester,
      eventId: r'$group-own-avatar',
      body: '我自己的群聊头像消息',
      senderMxid: '@owner:p2p-im.com',
      currentUserProfile: Profile(
        userId: '@owner:p2p-im.com',
        displayName: 'Owner',
        avatarUrl: Uri.parse('https://cdn.example.com/group-me.png'),
      ),
    );

    expect(find.text('我自己的群聊头像消息'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.size == 40 &&
            widget.imageUrl == 'https://cdn.example.com/group-me.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('group chat long press exposes local outbox actions',
      (tester) async {
    await _pumpGroupChatWithTextEvent(
      tester,
      sendTextEvent: false,
      initialOutboxItems: [
        LocalOutboxItem(
          id: 'group-text-pending-1',
          conversationId: '!group:p2p-im.com',
          conversationType: LocalOutboxConversationType.group,
          messageKind: LocalOutboxMessageKind.text,
          text: '群聊本地待发送消息',
          filename: '',
          mimeType: 'text/plain',
          createdAt: DateTime.utc(2026, 5, 30, 9),
          status: LocalOutboxItemStatus.failed,
          runtimeId: '',
          batchId: 'group-text-batch-1',
          batchIndex: 0,
        ),
      ],
    );

    await tester.longPress(find.text('群聊本地待发送消息'));
    await tester.pumpAndSettle();

    expect(find.text('复制'), findsOneWidget);
    expect(find.text('转发'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('多选'), findsOneWidget);
  });

  testWidgets('group chat member avatar opens chat avatar profile',
      (tester) async {
    const roomId = '!group:p2p-im.com';
    final router = GoRouter(
      initialLocation: '/group/${Uri.encodeComponent(roomId)}',
      routes: [
        GoRoute(
          path: '/group/:roomId',
          builder: (_, state) => GroupChatPage(
            roomId: state.pathParameters['roomId']!,
          ),
        ),
        GoRoute(
          path: '/contact/:userId',
          builder: (_, state) => ContactDetailPage(
            userId: state.pathParameters['userId']!,
            fromChatAvatar:
                state.uri.queryParameters['source'] == 'chat_avatar',
          ),
        ),
        GoRoute(
          path: '/channel/:channelId',
          builder: (_, state) => ChannelPage(
            channelId: state.pathParameters['channelId']!,
          ),
        ),
      ],
    );

    final harness = await _pumpGroupChatWithTextEvent(tester,
        roomId: roomId, loggedInAuth: true, router: router);
    harness.asClient.userPublicChannels = const [
      AsChannel(
        channelId: 'ch_alice_group',
        roomId: '!alice-public:p2p-im.com',
        name: 'Alice 群成员公开频道',
        visibility: asChannelVisibilityPublic,
        joinPolicy: asChannelJoinPolicyApproval,
        memberCount: 3,
      ),
    ];
    await tester.pumpAndSettle();

    final avatar = tester.widget<GestureDetector>(
      find.byKey(const ValueKey('group_member_avatar_@alice:p2p-im.com')),
    );
    expect(avatar.onTap, isNotNull);
    expect(avatar.onLongPress, isNotNull);

    avatar.onTap!();
    await tester.pumpAndSettle();

    expect(find.byType(ContactDetailPage), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('他的频道'), findsOneWidget);
    expect(find.text('添加好友'), findsOneWidget);
    expect(find.text('发消息'), findsNothing);
    expect(find.text('音频通话'), findsNothing);
    expect(find.text('视频通话'), findsNothing);
  });

  testWidgets('group chat long pressing member avatar inserts mention',
      (tester) async {
    await _pumpGroupChatWithTextEvent(tester);
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey('group_member_avatar_@alice:p2p-im.com')),
    );
    await tester.pump();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, '@Alice ');
  });

  testWidgets('group chat quote shows reply bar and clears after send',
      (tester) async {
    _mockAudioRecorderPlugins(tester);
    final harness = await _pumpGroupChatWithTextEvent(tester);

    await tester.longPress(find.text('群聊长按消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('引用'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byIcon(Symbols.reply), findsOneWidget);
    expect(find.text('Alice'), findsWidgets);

    await tester.enterText(find.byType(TextField), '引用后的回复');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(harness.sentMatrixEvents.single['body'], contains('引用后的回复'));
    expect(harness.sentMatrixEvents.single['reply_to'], r'$group-text');
    expect(find.byIcon(Symbols.reply), findsNothing);

    await harness.client.handleSync(
      SyncUpdate(
        nextBatch: 'after-local-reply-event',
        rooms: RoomsUpdate(
          join: {
            '!group:p2p-im.com': JoinedRoomUpdate(
              timeline: TimelineUpdate(
                events: [
                  MatrixEvent(
                    type: EventTypes.Message,
                    eventId: r'$group-sent',
                    roomId: '!group:p2p-im.com',
                    senderId: '@owner:p2p-im.com',
                    originServerTs: DateTime.utc(2026, 5, 30, 10, 1),
                    content: const {
                      'msgtype': MessageTypes.Text,
                      'body': '引用后的回复',
                    },
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
        find.byKey(const ValueKey('group_chat_quote_block')), findsOneWidget);
  });

  testWidgets('group chat renders AS reply_to as quoted bubble',
      (tester) async {
    final harness = await _pumpGroupChatWithTextEvent(tester);

    await harness.client.handleSync(
      SyncUpdate(
        nextBatch: 'after-group-reply',
        rooms: RoomsUpdate(
          join: {
            '!group:p2p-im.com': JoinedRoomUpdate(
              timeline: TimelineUpdate(
                events: [
                  MatrixEvent(
                    type: EventTypes.Message,
                    eventId: r'$group-reply',
                    roomId: '!group:p2p-im.com',
                    senderId: '@owner:p2p-im.com',
                    originServerTs: DateTime.utc(2026, 5, 30, 10, 1),
                    content: const {
                      'msgtype': MessageTypes.Text,
                      'body': '引用后的回复',
                      'reply_to': r'$group-text',
                    },
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
        find.byKey(const ValueKey('group_chat_quote_block')), findsOneWidget);
    expect(find.text('引用后的回复'), findsOneWidget);
    expect(find.text('群聊长按消息'), findsNWidgets(2));
  });

  testWidgets('group chat renders Matrix reply fallback as quoted bubble',
      (tester) async {
    final harness = await _pumpGroupChatWithTextEvent(tester);

    await harness.client.handleSync(
      SyncUpdate(
        nextBatch: 'after-group-matrix-reply',
        rooms: RoomsUpdate(
          join: {
            '!group:p2p-im.com': JoinedRoomUpdate(
              timeline: TimelineUpdate(
                events: [
                  MatrixEvent(
                    type: EventTypes.Message,
                    eventId: r'$group-matrix-reply',
                    roomId: '!group:p2p-im.com',
                    senderId: '@owner:p2p-im.com',
                    originServerTs: DateTime.utc(2026, 5, 30, 10, 2),
                    content: const {
                      'msgtype': MessageTypes.Text,
                      'body': '> <@alice:p2p-im.com> 群聊长按消息\n\n引用后的回复',
                      'm.relates_to': {
                        'm.in_reply_to': {'event_id': r'$group-text'},
                      },
                    },
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
        find.byKey(const ValueKey('group_chat_quote_block')), findsOneWidget);
    expect(find.text('引用后的回复'), findsOneWidget);
    expect(find.text('群聊长按消息'), findsNWidgets(2));
  });

  testWidgets('group chat single forward opens target sheet', (tester) async {
    await _pumpGroupChatWithTextEvent(tester);

    await tester.longPress(find.text('群聊长按消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('转发'));
    await tester.pumpAndSettle();

    expect(find.text('转发聊天记录'), findsOneWidget);
    expect(find.text('真实群'), findsWidgets);
  });

  testWidgets('group chat multi-select bar exposes delete', (tester) async {
    await _pumpGroupChatWithTextEvent(tester);

    await tester.longPress(find.text('群聊长按消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('多选'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1条消息'), findsOneWidget);
    expect(find.byTooltip('转发'), findsOneWidget);
    expect(find.byTooltip('删除'), findsOneWidget);
  });

  testWidgets('group chat delete hides message through Matrix local delete',
      (tester) async {
    final harness = await _pumpGroupChatWithTextEvent(tester);

    await tester.longPress(find.text('群聊长按消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(harness.visibilityClient.hiddenEventIdsByRoom['!group:p2p-im.com'], [
      r'$group-text',
    ]);
    expect(find.text('群聊长按消息'), findsNothing);
  });

  testWidgets('home empty state does not render mock conversations or contacts',
      (tester) async {
    final client = Client('DirexioHomeNoMockListsTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 21, 16),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dave Lee'), findsNothing);
    expect(find.text('Agent'), findsNothing);
    expect(find.text('还没有会话'), findsOneWidget);

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    expect(find.text('ID/昵称/邮箱'), findsOneWidget);
    expect(find.text('Alice Chen'), findsNothing);
  });

  testWidgets(
      'home conversation delete clears Matrix local history after confirm',
      (tester) async {
    final client = Client(
      'DirexioHomeDeleteConversationMatrixTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    final asClient = _TrackingAsClient();
    final clearStore = _MemoryChatClearStateStore();
    final visibilityClient = _RecordingMatrixMessageVisibilityClient();
    const roomId = '!direct:p2p-im.com';
    const conversationKey = ValueKey('home_conversation_$roomId');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 19, 9),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: roomId,
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(asClient),
          matrixMessageVisibilityClientProvider.overrideWithValue(
            visibilityClient,
          ),
          chatClearStateStoreProvider.overrideWith((ref) async => clearStore),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);

    await tester.longPress(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除聊天'));
    await tester.pumpAndSettle();

    expect(find.text('删除聊天记录'), findsOneWidget);

    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(visibilityClient.clearCalls, 1);
    expect(clearStore.roomClearedBeforeTs[roomId], isNotNull);
    expect(find.textContaining('删除聊天记录失败'), findsNothing);
    expect(find.textContaining('已删除'), findsOneWidget);
    expect(find.byKey(conversationKey), findsNothing);
  });

  testWidgets('home empty state does not expose mock chat rows',
      (tester) async {
    final client = Client('DirexioHomeMockNoOpenTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 21, 16),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, __) => const Scaffold(body: Text('opened-chat')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice Chen'), findsNothing);
    expect(find.text('opened-chat'), findsNothing);
    expect(find.text('还没有会话'), findsOneWidget);
  });

  testWidgets('chat route rejects mock conversation ids', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: 'mock_dave'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('会话不存在'), findsOneWidget);
    expect(find.text('Dave Lee'), findsNothing);
  });

  testWidgets('groups list empty state does not render mock groups',
      (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const GroupsListPage()),
      ),
    );
    await tester.pump();

    expect(find.text('P2P IM 核心群'), findsNothing);
    expect(find.text('群主'), findsNothing);
    expect(find.text('还没有群聊'), findsOneWidget);
  });

  testWidgets('empty channel tab does not show mock channels', (tester) async {
    final client = Client('DirexioTest');
    final emptyBootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-05-26T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asBootstrapLiveRefreshIntervalProvider.overrideWith((ref) => null),
          asClientProvider.overrideWithValue(_NeverListChannelsAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: emptyBootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('频道'));
    await tester.pumpAndSettle();

    expect(find.text('正在同步频道'), findsNothing);
    expect(find.text('P2P IM 官方'), findsNothing);
    expect(find.text('Agent 工作流'), findsNothing);
    expect(find.text('还没有频道'), findsOneWidget);
  });

  testWidgets('channel tab does not render removed sample categories',
      (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('频道'));
    await tester.pumpAndSettle();

    expect(find.text('搜索频道、群体、话题'), findsNothing);
    expect(find.textContaining('推荐频道'), findsNothing);
    expect(find.text('关注'), findsNothing);
    for (final label in ['已加入', '我创建', '频道列表', '全部']) {
      expect(find.text(label), findsNothing);
    }
    expect(find.text('文字'), findsNothing);
    expect(find.text('帖子'), findsNothing);
    expect(find.text('草稿'), findsNothing);

    expect(find.text('#综合讨论'), findsNothing);
    expect(find.text('#新手问答'), findsNothing);
    expect(find.text('草稿箱'), findsNothing);
    expect(find.text('自由讨论、技术交流与闲聊'), findsNothing);
    expect(find.text('还没有频道'), findsOneWidget);
  });

  testWidgets('channel unread dot appears only for chat channels',
      (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChannelInboxList(
              storageKey: const PageStorageKey('channel_unread_test'),
              channels: [
                ChannelInboxItem(
                  id: 'ch_updates',
                  roomId: '!updates:p2p-im.com',
                  domain: 'p2p-im.com',
                  name: '产品更新',
                  avatarUrl: '',
                  latestPreview: '今天发布了新版本',
                  latestAt: DateTime.parse('2026-06-07T10:20:00Z'),
                  unreadCount: 12,
                  tags: const ['产品'],
                  isOwned: true,
                  channelType: asChannelTypeChat,
                ),
                ChannelInboxItem(
                  id: 'ch_posts',
                  roomId: '!posts:p2p-im.com',
                  domain: 'p2p-im.com',
                  name: '帖子频道',
                  avatarUrl: '',
                  latestPreview: '帖子更新',
                  latestAt: DateTime.parse('2026-06-07T10:15:00Z'),
                  unreadCount: 8,
                  tags: const ['帖子'],
                  isOwned: true,
                  channelType: asChannelTypePost,
                ),
              ],
              bottomPadding: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('channel_unread_dot_ch_updates')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('channel_unread_dot_ch_posts')),
        findsNothing);
    expect(find.text('12'), findsNothing);
    expect(find.text('8'), findsNothing);
  });

  testWidgets('home message list excludes channel conversations',
      (tester) async {
    const roomId = '!channel-home-unread:p2p-im.com';
    final client = Client('DirexioHomeChannelUnreadTest')
      ..setUserId('@member:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 24, 10),
      user: const AsSyncUser(userId: '@member:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_home_unread',
          roomId: roomId,
          homeDomain: 'p2p-im.com',
          name: '产品更新',
          avatarUrl: '',
          unreadCount: 6,
          lastActivityAt: DateTime.utc(2026, 6, 24, 9),
          memberStatus: asChannelMemberStatusJoined,
          channelType: asChannelTypeChat,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_MemberLoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          conversationSummaryStoreProvider.overrideWith(
            (ref) async => _MemoryConversationSummaryStore(null),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final row = find.byKey(const ValueKey('home_conversation_$roomId'));
    expect(row, findsNothing);
    expect(find.text('产品更新'), findsNothing);
    expect(find.text('6'), findsNothing);
  });

  testWidgets('home message list keeps channel events out of messages',
      (tester) async {
    const roomId = '!channel-home-live-unread:p2p-im.com';
    final client = Client('DirexioHomeChannelLiveUnreadTest')
      ..setUserId('@member:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com');
    final room = Room(
      id: roomId,
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 24, 10),
      user: const AsSyncUser(userId: '@member:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        const AsSyncRoomSummary(
          channelId: 'ch_home_live_unread',
          roomId: roomId,
          homeDomain: 'p2p-im.com',
          name: '产品更新',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: asChannelMemberStatusJoined,
          channelType: asChannelTypeChat,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_MemberLoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          conversationSummaryStoreProvider.overrideWith(
            (ref) async => _MemoryConversationSummaryStore(null),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final row = find.byKey(const ValueKey('home_conversation_$roomId'));
    expect(row, findsNothing);

    room.lastEvent = Event(
      room: room,
      eventId: r'$channel-live-unread',
      senderId: '@alice:p2p-im.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 6, 24, 10, 1),
      content: {
        'msgtype': MessageTypes.Text,
        'body': '频道新消息',
      },
    );
    client.onEvent.add(EventUpdate(
      roomID: roomId,
      type: EventUpdateType.timeline,
      content: {
        'type': EventTypes.Message,
        'event_id': r'$channel-live-unread',
        'sender': '@alice:p2p-im.com',
        'origin_server_ts':
            DateTime.utc(2026, 6, 24, 10, 1).millisecondsSinceEpoch,
        'content': {
          'msgtype': MessageTypes.Text,
          'body': '频道新消息',
        },
      },
    ));
    await tester.pump();
    await tester.pump();

    expect(row, findsNothing);
    expect(find.text('频道新消息'), findsNothing);
  });

  testWidgets('channel tab hides legacy discover switch', (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('频道'));
    await tester.pumpAndSettle();

    expect(find.text('频道列表'), findsNothing);
    expect(find.text('#综合讨论'), findsNothing);
    expect(find.text('#新手问答'), findsNothing);
    expect(find.text('还没有频道'), findsOneWidget);
  });

  testWidgets('channel filters are hidden on channel tab', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('频道'));
    await tester.pumpAndSettle();

    for (final label in ['已加入', '我创建', '频道列表', '全部']) {
      expect(find.text(label), findsNothing);
    }
    expect(find.byKey(const ValueKey('channel_filter_bar')), findsNothing);
    expect(find.text('草稿'), findsNothing);
    expect(find.text('活动'), findsNothing);
    expect(find.text('节点'), findsNothing);
  });

  testWidgets('channel list does not expose mock channel detail rows',
      (tester) async {
    final client = Client('DirexioTest');
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/channel/:channelId',
          builder: (_, state) => ChannelPage(
            channelId: state.pathParameters['channelId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('频道'));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('channel_inbox_tile_p2p-im')), findsNothing);
    expect(find.text('P2P IM 官方'), findsNothing);
    expect(find.text('#综合讨论'), findsNothing);
    expect(find.text('#新手问答'), findsNothing);
    expect(find.text('还没有频道'), findsOneWidget);
  });

  testWidgets('channel tab opens chat channels through ProductCore route',
      (tester) async {
    const roomId = '!channel-chat:p2p-im.com';
    const conversationId = 'conv_channel_chat';
    final client = Client('DirexioChannelProductRouteTest')
      ..setUserId('@member:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 21, 10),
      user: const AsSyncUser(userId: '@member:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_chat',
          roomId: roomId,
          homeDomain: 'p2p-im.com',
          name: '产品交流群',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.utc(2026, 6, 21, 9),
          description: '产品交流',
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          channelType: asChannelTypeChat,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/channels',
      routes: [
        GoRoute(
          path: '/channels',
          builder: (_, __) => const ChannelExplorePage(),
        ),
        GoRoute(
          path: '/channel/:channelId/conversation',
          builder: (_, state) => Text(
            'channel:${state.pathParameters['channelId']};'
            'conversation:${state.uri.queryParameters['conversation']};'
            'name:${state.uri.queryParameters['name']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_MemberLoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(
            _NeverListChannelsWithConversationsAsClient(
              const [
                AsConversation(
                  conversationId: conversationId,
                  roomId: roomId,
                  kind: asConversationKindChannel,
                  lifecycle: 'active',
                  title: '产品交流群',
                  avatarUrl: '',
                  capabilities: AsConversationCapabilities(open: true),
                ),
              ],
            ),
          ),
          productConversationsProvider.overrideWith(
            (ref) async => const [
              AsConversation(
                conversationId: conversationId,
                roomId: roomId,
                kind: asConversationKindChannel,
                lifecycle: 'active',
                title: '产品交流群',
                avatarUrl: '',
                capabilities: AsConversationCapabilities(open: true),
              ),
            ],
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('产品交流群'));
    await tester.pumpAndSettle();

    expect(
      find.text('channel:ch_chat;conversation:$conversationId;name:产品交流群'),
      findsOneWidget,
    );
  });

  testWidgets('channel conversation route keeps channel context',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/channel/ch_legacy_chat/conversation?name=旧入口频道',
      routes: [
        GoRoute(
          path: '/channel/:channelId/conversation',
          builder: (_, state) => Text(
            'channel:${state.pathParameters['channelId']};'
            'name:${state.uri.queryParameters['name']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.pump();

    expect(
      find.text('channel:ch_legacy_chat;name:旧入口频道'),
      findsOneWidget,
    );
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/channel/ch_legacy_chat/conversation?name=%E6%97%A7%E5%85%A5%E5%8F%A3%E9%A2%91%E9%81%93',
    );
  });

  testWidgets('channel detail restores real channel from cached bootstrap',
      (tester) async {
    final client = Client('DirexioCachedChannelDetailTest')
      ..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'matrix-token';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 20, 8),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [
        AsSyncRoomSummary(
          channelId: 'ch_cached',
          roomId: '!cached-channel:p2p-im.com',
          name: '缓存频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: null,
          memberStatus: asChannelMemberStatusJoined,
          channelType: asChannelTypePost,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );
    final bootstrapStore = _MemoryAsBootstrapStore()..value = bootstrap;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider
              .overrideWithValue(_StaticBootstrapAsClient(bootstrap)),
          asSyncCacheProvider.overrideWith((ref) => const AsSyncCacheState()),
          asBootstrapStoreProvider.overrideWith((ref) async => bootstrapStore),
          channelPostStoreProvider.overrideWith(
            (ref) async => _MemoryChannelPostStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelPage(channelId: 'ch_cached'),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('缓存频道'), findsOneWidget);
    expect(find.text('频道不存在'), findsNothing);
  });

  testWidgets('joined dissolved channel is hidden from channel list',
      (tester) async {
    final client = Client('DirexioDissolvedChannelHintTest')
      ..setUserId('@member:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-18T10:30:00Z'),
      user: const AsSyncUser(userId: '@member:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_removed',
          roomId: '!removed:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '旧频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-18T10:20:00Z'),
          description: '历史频道',
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: 'removed',
          channelType: asChannelTypeChat,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_MemberLoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(_NeverListChannelsAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelExplorePage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('旧频道'), findsNothing);
    expect(find.text('频道已经解散'), findsNothing);
  });

  testWidgets('terminal bootstrap channel suppresses stale listed channel',
      (tester) async {
    final client = Client('DirexioTerminalChannelSuppressListTest')
      ..setUserId('@member:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-18T10:30:00Z'),
      user: const AsSyncUser(userId: '@member:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_stale',
          roomId: '!stale:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '旧频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-18T10:20:00Z'),
          memberStatus: asChannelMemberStatusJoined,
          lifecycle: 'dissolved',
          channelType: asChannelTypeChat,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_MemberLoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(
            _StaticListChannelsAsClient(const [
              AsChannel(
                channelId: 'ch_stale',
                roomId: '!stale:p2p-im.com',
                homeDomain: 'p2p-im.com',
                name: '旧频道',
                role: asChannelRoleMember,
                memberStatus: asChannelMemberStatusJoined,
                channelType: asChannelTypeChat,
              ),
            ]),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelExplorePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('旧频道'), findsNothing);
    expect(find.text('频道已经解散'), findsNothing);
  });

  testWidgets('channel inbox long press shows channel actions', (tester) async {
    final client = Client('DirexioChannelInboxMenuTest')
      ..setUserId('@member:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-18T10:30:00Z'),
      user: const AsSyncUser(userId: '@member:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_menu',
          roomId: '!menu:p2p-im.com',
          homeDomain: 'p2p-im.com',
          name: '频道菜单',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.parse('2026-06-18T10:20:00Z'),
          isOwned: false,
          role: asChannelRoleMember,
          memberStatus: asChannelMemberStatusJoined,
          channelType: asChannelTypeChat,
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_MemberLoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(_NeverListChannelsAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChannelExplorePage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.longPress(find.text('频道菜单'));
    await tester.pumpAndSettle();

    expect(find.text('置顶'), findsOneWidget);
    expect(find.text('不显示'), findsOneWidget);
    expect(find.text('删除频道'), findsOneWidget);
    expect(find.text('删除聊天'), findsNothing);
  });

  testWidgets('empty real channel inbox does not show mock sample channels',
      (tester) async {
    final client = Client('DirexioTest');
    final emptyBootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-05-26T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/channel/:channelId',
          builder: (_, state) => ChannelPage(
            channelId: state.pathParameters['channelId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: emptyBootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('频道'));
    await tester.pumpAndSettle();

    expect(find.text('还没有频道'), findsOneWidget);
    expect(find.text('搜索频道'), findsNothing);
    expect(find.text('草稿箱'), findsNothing);
    expect(find.text('2 条帖子待发布'), findsNothing);
    expect(find.text('AI'), findsNothing);
    expect(find.text('产品'), findsNothing);
    expect(find.text('样例频道'), findsNothing);
    expect(find.text('P2P IM 官方'), findsNothing);
  });

  testWidgets('unknown channel detail does not render mock posts',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/channel/agent-workflows',
      routes: [
        GoRoute(
          path: '/channel/:channelId/post/:postId',
          builder: (_, state) => ChannelPostDetailPage(
            channelId: state.pathParameters['channelId']!,
            postId: state.pathParameters['postId']!,
          ),
        ),
        GoRoute(
          path: '/channel/:channelId',
          builder: (_, state) => ChannelPage(
            channelId: state.pathParameters['channelId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(_MissingPublicChannelAsClient()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('已关注'), findsNothing);
    expect(find.text('接收通知'), findsNothing);
    expect(find.text('频道主Diana发布帖子，成员可评论和恢复'), findsNothing);
    expect(find.text('频道不存在'), findsOneWidget);
    expect(find.text('发布帖子'), findsNothing);
  });

  testWidgets('unknown channel detail uses dark tokens without mock posts',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/channel/agent-workflows',
      routes: [
        GoRoute(
          path: '/channel/:channelId/post/:postId',
          builder: (_, state) => ChannelPostDetailPage(
            channelId: state.pathParameters['channelId']!,
            postId: state.pathParameters['postId']!,
          ),
        ),
        GoRoute(
          path: '/channel/:channelId',
          builder: (_, state) => ChannelPage(
            channelId: state.pathParameters['channelId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(_MissingPublicChannelAsClient()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    final title = tester.widget<Text>(
      find.text('频道不存在'),
    );
    expect(title.style?.color, PortalTokens.dark.text);
    expect(title.style?.letterSpacing, 0);
    expect(find.textContaining('有人分享了群聊总结模板'), findsNothing);
  });

  testWidgets('global search excludes mock contacts and groups',
      (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SearchPage()),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Alice Chen'), findsNothing);
    expect(find.text('没有找到包含「Alice」的内容'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '产品');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('产品设计组'), findsNothing);
    expect(find.text('P2P IM 官方'), findsNothing);
  });

  testWidgets('global search uses localized chrome and empty state',
      (tester) async {
    final client = Client('DirexioSearchLocaleTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SearchPage(),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Search'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('No content found for "Alice"'), findsOneWidget);
  });

  testWidgets('global search does not expose mock contact routes',
      (tester) async {
    final client = Client('DirexioSearchMockNoOpenTest');
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(path: '/search', builder: (_, __) => const SearchPage()),
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, __) => const Scaffold(body: Text('opened-chat')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Alice Chen'), findsNothing);
    expect(find.text('opened-chat'), findsNothing);
    expect(find.text('没有找到包含「Alice」的内容'), findsOneWidget);
  });

  testWidgets('global search does not expose mock channel routes',
      (tester) async {
    final client = Client('DirexioTest');
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(path: '/search', builder: (_, __) => const SearchPage()),
        GoRoute(
          path: '/channel/:channelId',
          builder: (_, state) => ChannelPage(
            channelId: state.pathParameters['channelId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'P2P IM 官方');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('没有找到包含「P2P IM 官方」的内容'), findsOneWidget);
  });

  testWidgets('global search indexes real bootstrap channels', (tester) async {
    final client = Client('DirexioTest');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 26, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
          channelId: 'ch_real_channel',
          roomId: '!real-channel:p2p-im.com',
          name: '真实产品频道',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.utc(2026, 5, 26, 9),
          topic: '真实频道索引内容',
          isOwned: true,
          tags: const ['真实标签'],
        ),
      ],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SearchPage()),
      ),
    );

    await tester.enterText(find.byType(TextField), '真实标签');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('真实产品频道'), findsOneWidget);
    expect(find.textContaining('真实频道索引内容'), findsOneWidget);
  });

  testWidgets('global search renders avatars for contacts groups and channels',
      (tester) async {
    final client = Client('DirexioGlobalSearchAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!alice:p2p-im.com',
      peerMxid: '@alice:p2p-im.com',
      peerName: 'Alice',
    );
    _addNamedGroupRoom(
      client,
      roomId: '!group-avatar:p2p-im.com',
      name: '头像群',
      members: const {
        '@alice:p2p-im.com': 'Alice',
        '@bob:p2p-im.com': 'Bob',
      },
      memberAvatarUrls: const {
        '@alice:p2p-im.com': 'https://cdn.example.com/alice-member.png',
        '@bob:p2p-im.com': 'https://cdn.example.com/bob-member.png',
      },
    );
    const conversations = [
      AsConversation(
        conversationId: 'conv_alice',
        roomId: '!alice:p2p-im.com',
        kind: asConversationKindDirect,
        lifecycle: 'active',
        peerMxid: '@alice:p2p-im.com',
        title: 'Alice',
        avatarUrl: 'https://cdn.example.com/alice.png',
        capabilities: AsConversationCapabilities(open: true),
      ),
      AsConversation(
        conversationId: 'conv_group_avatar',
        roomId: '!group-avatar:p2p-im.com',
        kind: asConversationKindGroup,
        lifecycle: 'active',
        title: '头像群',
        avatarUrl: '',
        capabilities: AsConversationCapabilities(open: true),
      ),
      AsConversation(
        conversationId: 'channel_avatar',
        roomId: '!channel-avatar:p2p-im.com',
        kind: asConversationKindChannel,
        lifecycle: 'active',
        title: '头像频道',
        avatarUrl: 'https://cdn.example.com/channel.png',
        capabilities: AsConversationCapabilities(open: true),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(
            _ConversationListAsClient(conversations),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(
              bootstrap: _bootstrapFromConversations(conversations),
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SearchPage()),
      ),
    );

    await tester.enterText(find.byType(TextField), '头像');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('头像群'), findsOneWidget);
    expect(find.text('头像频道'), findsOneWidget);
    final groupAvatar = tester
        .widgetList<GroupCompositeAvatar>(find.byType(GroupCompositeAvatar))
        .singleWhere((avatar) => avatar.seed == '!group-avatar:p2p-im.com');
    expect(
        groupAvatar.members.map((member) => member.imageUrl),
        contains(
          'https://cdn.example.com/alice-member.png',
        ));
    var avatars = tester.widgetList<PortalAvatar>(find.byType(PortalAvatar));
    expect(
      avatars.any(
          (avatar) => avatar.imageUrl == 'https://cdn.example.com/channel.png'),
      isTrue,
    );

    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    avatars = tester.widgetList<PortalAvatar>(find.byType(PortalAvatar));
    expect(
      avatars.any(
          (avatar) => avatar.imageUrl == 'https://cdn.example.com/alice.png'),
      isTrue,
    );
  });

  testWidgets(
      'global search hides Matrix rooms without ProductCore conversation',
      (tester) async {
    final client = Client('DirexioTestSearchRequiresProductRoom')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!orphan-room:p2p-im.com',
      name: '孤儿群 orphan-room-needle',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          asClientProvider
              .overrideWithValue(_ConversationListAsClient(const [])),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SearchPage()),
      ),
    );

    await tester.enterText(find.byType(TextField), 'orphan-room-needle');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('孤儿群 orphan-room-needle'), findsNothing);
    expect(
      find.text('没有找到包含「orphan-room-needle」的内容'),
      findsOneWidget,
    );
  });

  testWidgets('contact detail shows user info actions', (tester) async {
    var clipboardText = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboardText = (call.arguments as Map)['text'] as String? ?? '';
            return null;
          case 'Clipboard.getData':
            return {'text': clipboardText};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContactDetailPage(userId: '@alice:portal.local'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('发消息'), findsOneWidget);
    expect(find.text('语音通话'), findsOneWidget);
    expect(find.text('视频通话'), findsOneWidget);
    expect(find.text('搜索聊天'), findsOneWidget);
    expect(find.text('主页'), findsNothing);
    expect(find.text('设置备注'), findsOneWidget);
    expect(find.text('推荐给朋友'), findsOneWidget);
    expect(find.text('消息免打扰'), findsOneWidget);
    expect(find.text('拉黑用户'), findsOneWidget);
    expect(find.text('举报用户'), findsOneWidget);
    expect(find.text('删除好友'), findsOneWidget);
    expect(find.text('@alice:portal.local'), findsOneWidget);

    await tester.tap(find.text('@alice:portal.local'));
    await tester.pump();

    expect(find.text('已复制 UID'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final copied = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copied?.text, '@alice:portal.local');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('contact detail uses localized user info actions',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const ContactDetailPage(userId: '@alice:portal.local'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Voice call'), findsOneWidget);
    expect(find.text('Video Call'), findsOneWidget);
    expect(find.text('Search Chat'), findsOneWidget);
    expect(find.text('Set Remark'), findsOneWidget);
    expect(find.text('Recommend to Friends'), findsOneWidget);
    expect(find.text('Mute Messages'), findsOneWidget);
    expect(find.text('Block User'), findsOneWidget);
    expect(find.text('Report User'), findsOneWidget);
    expect(find.text('Delete Friend'), findsOneWidget);
  });

  testWidgets('contact detail without room does not hydrate mock profile',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContactDetailPage(userId: '@alice:portal.local'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('alice'), findsOneWidget);
    expect(find.text('Alice Chen'), findsNothing);
    final avatar = tester
        .widgetList<PortalAvatar>(find.byType(PortalAvatar))
        .where((item) => item.size == 60)
        .single;
    expect(avatar.imageUrl, isNull);
  });

  testWidgets('contact detail uses display name for avatar fallback seed',
      (tester) async {
    const peerMxid = '@2alice:portal.local';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 24, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: peerMxid,
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'portal.local',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContactDetailPage(userId: peerMxid),
        ),
      ),
    );
    await tester.pump();

    final avatar = tester
        .widgetList<PortalAvatar>(find.byType(PortalAvatar))
        .where((item) => item.size == 60)
        .single;
    expect(find.text('Alice'), findsOneWidget);
    expect(avatar.seed, 'Alice');
  });

  testWidgets('contact detail persists message mute toggle after re-entry',
      (tester) async {
    const roomId = '!contact-mute:p2p-im.com';
    const peerMxid = '@alice:p2p-im.com';
    final client = Client('DirexioContactMuteTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: roomId,
      peerMxid: peerMxid,
      peerName: 'Alice',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 16, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: peerMxid,
          displayName: 'Alice',
          avatarUrl: '',
          roomId: roomId,
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final store = _MemoryConversationPreferencesStore(
      const ConversationPreferencesData(mutedConversationIds: {roomId}),
    );

    Future<void> pumpContactDetail() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixClientProvider.overrideWithValue(client),
            authStateNotifierProvider
                .overrideWith(_LoggedInAuthStateNotifier.new),
            asSyncCacheProvider.overrideWith(
              (ref) => AsSyncCacheState(bootstrap: bootstrap),
            ),
            conversationPreferencesStoreProvider.overrideWith(
              (ref) async => store,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ContactDetailPage(userId: peerMxid),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpContactDetail();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(store.data.mutedConversationIds, isNot(contains(roomId)));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpContactDetail();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets(
      'contact detail uses Matrix member nickname when AS name is empty',
      (tester) async {
    final client = Client('DirexioContactDetailMatrixNameTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!alice:p2p-im.com',
      peerMxid: '@alice:p2p-liyanan.com',
      peerName: 'Alice 昵称',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 16, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-liyanan.com',
          displayName: '',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContactDetailPage(userId: '@alice:p2p-liyanan.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Alice 昵称'), findsOneWidget);
    expect(find.text('alice'), findsNothing);
  });

  testWidgets('contact detail does not open chat without ProductCore direct',
      (tester) async {
    const roomId = '!alice:p2p-im.com';
    const peerMxid = '@alice:p2p-im.com';
    final client = Client('DirexioContactDetailProductOpenGuardTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: roomId,
      peerMxid: peerMxid,
      peerName: 'Alice',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 21, 14),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/contact/${Uri.encodeComponent(peerMxid)}',
      routes: [
        GoRoute(
          path: '/contact/:userId',
          builder: (_, state) =>
              ContactDetailPage(userId: state.pathParameters['userId']!),
        ),
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, __) => const Scaffold(body: Text('opened-chat')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider
              .overrideWithValue(_ConversationListAsClient(const [])),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('发消息'));
    await tester.pumpAndSettle();

    expect(find.text('opened-chat'), findsNothing);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets(
      'chat avatar contact detail keeps friend profile while ProductCore loads',
      (tester) async {
    const roomId = '!alice:p2p-im.com';
    const peerMxid = '@alice:p2p-im.com';
    var clipboardText = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboardText = (call.arguments as Map)['text'] as String? ?? '';
            return null;
          case 'Clipboard.getData':
            return {'text': clipboardText};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final client = Client('DirexioChatAvatarFriendProfileTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: roomId,
      peerMxid: peerMxid,
      peerName: 'Alice',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: peerMxid,
          displayName: 'Alice',
          avatarUrl: '',
          roomId: roomId,
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _ConversationListWithPublicChannelsAsClient(
      const [],
      userPublicChannels: const [
        AsChannel(
          channelId: 'ch_avatar_1',
          roomId: '!avatar-1:p2p-im.com',
          name: 'Alice 频道一',
          avatarUrl: 'https://example.com/channel-1.png',
        ),
        AsChannel(
          channelId: 'ch_avatar_2',
          roomId: '!avatar-2:p2p-im.com',
          name: 'Alice 频道二',
          avatarUrl: 'https://example.com/channel-2.png',
        ),
        AsChannel(
          channelId: 'ch_avatar_3',
          roomId: '!avatar-3:p2p-im.com',
          name: 'Alice 频道三',
          avatarUrl: 'https://example.com/channel-3.png',
        ),
      ],
    );
    final router = GoRouter(
      initialLocation:
          '/contact/${Uri.encodeComponent(peerMxid)}?source=chat_avatar',
      routes: [
        GoRoute(
          path: '/contact/:userId',
          builder: (_, state) => ContactDetailPage(
            userId: state.pathParameters['userId']!,
            fromChatAvatar:
                state.uri.queryParameters['source'] == 'chat_avatar',
            fromChatInfo: state.uri.queryParameters['source'] == 'chat_info',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text(peerMxid), findsOneWidget);
    expect(find.text('发消息'), findsOneWidget);
    expect(find.text('音频通话'), findsOneWidget);
    expect(find.text('视频通话'), findsOneWidget);
    expect(asClient.requestedUserPublicChannelsUserId, peerMxid);
    for (final channelId in const [
      'ch_avatar_1',
      'ch_avatar_2',
      'ch_avatar_3',
    ]) {
      expect(
        find.byKey(ValueKey('avatar_profile_channel_$channelId')),
        findsOneWidget,
      );
    }
    await tester.tap(find.text(peerMxid));
    await tester.pump();
    expect(find.text('已复制 UID'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final copied = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copied?.text, peerMxid);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('把他推荐给朋友'), findsOneWidget);
    expect(find.text('添加好友'), findsNothing);
  });

  testWidgets('contact detail hides delete friend action for self',
      (tester) async {
    final client = Client('DirexioContactDetailSelfTest')
      ..setUserId('@owner:p2p-im.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith(
            (ref) async => Profile(
              userId: '@owner:p2p-im.com',
              displayName: 'Owner',
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContactDetailPage(userId: '@owner:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('设置备注'), findsNothing);
    expect(find.text('删除好友'), findsNothing);
  });

  testWidgets('contact detail updates remark without dialog disposal crash',
      (tester) async {
    final client = Client('DirexioContactDetailRemarkTest')
      ..setUserId('@owner:p2p-im.com');
    _addTestRoom(
      client,
      roomId: '!alice:p2p-im.com',
      roomMembership: Membership.join,
      directPeerMxid: '@alice:portal.local',
    );
    final bootstrapStore = _MemoryAsBootstrapStore();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 22),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:portal.local',
          displayName: 'Alice',
          avatarUrl: 'mxc://portal.local/alice',
          roomId: '!alice:p2p-im.com',
          domain: 'portal.local',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          asBootstrapStoreProvider.overrideWith((ref) async => bootstrapStore),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContactDetailPage(userId: '@alice:portal.local'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('设置备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Alice 备注');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('备注已更新'), findsOneWidget);
    expect(find.text('Alice 备注'), findsOneWidget);
    expect(bootstrapStore.value?.contacts.single.displayName, 'Alice 备注');
    expect(asClient.updateContactCalls, 1);
    expect(asClient.updatedContactRoomId, '!alice:p2p-im.com');
    expect(asClient.updatedContactDisplayName, 'Alice 备注');
    expect(asClient.updatedContactAvatarUrl, 'mxc://portal.local/alice');
    expect(asClient.updatedContactDomain, 'portal.local');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
      'contact detail deletes contact through AS and returns to messages',
      (tester) async {
    final client = Client('DirexioContactDetailDeleteTest')
      ..setUserId('@owner:p2p-im.com');
    _addTestRoom(
      client,
      roomId: '!alice:p2p-im.com',
      roomMembership: Membership.join,
      directPeerMxid: '@alice:portal.local',
    );
    final asClient = _TrackingAsClient();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 22),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:portal.local',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'portal.local',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/contact/${Uri.encodeComponent('@alice:portal.local')}',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('messages-home')),
        ),
        GoRoute(
          path: '/contact/:userId',
          builder: (_, state) => ContactDetailPage(
            userId: state.pathParameters['userId']!,
            fromChatAvatar:
                state.uri.queryParameters['source'] == 'chat_avatar',
            fromChatInfo: state.uri.queryParameters['source'] == 'chat_info',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('删除好友'));
    await tester.pump();
    await tester.tap(find.text('删除好友'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(asClient.deleteContactCalls, 1);
    expect(asClient.deletedContactRoomId, '!alice:p2p-im.com');
    expect(client.getRoomById('!alice:p2p-im.com'), isNull);
    expect(find.text('messages-home'), findsOneWidget);
  });

  testWidgets('contact detail blocks contact through AS delete flow',
      (tester) async {
    final client = Client('DirexioContactDetailBlockTest')
      ..setUserId('@owner:p2p-im.com');
    _addTestRoom(
      client,
      roomId: '!alice:p2p-im.com',
      roomMembership: Membership.join,
      directPeerMxid: '@alice:portal.local',
    );
    final asClient = _TrackingAsClient();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 22),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:portal.local',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'portal.local',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/contact/${Uri.encodeComponent('@alice:portal.local')}',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('messages-home')),
        ),
        GoRoute(
          path: '/contact/:userId',
          builder: (_, state) => ContactDetailPage(
            userId: state.pathParameters['userId']!,
            fromChatAvatar:
                state.uri.queryParameters['source'] == 'chat_avatar',
            fromChatInfo: state.uri.queryParameters['source'] == 'chat_info',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('拉黑用户'));
    await tester.pump();
    await tester.tap(find.text('拉黑用户'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '拉黑'));
    await tester.pumpAndSettle();

    expect(asClient.deleteContactCalls, 1);
    expect(asClient.deletedContactRoomId, '!alice:p2p-im.com');
    expect(client.getRoomById('!alice:p2p-im.com'), isNull);
    expect(find.text('messages-home'), findsOneWidget);
  });

  testWidgets(
      'contact visitor home delete returns to messages instead of stale chat',
      (tester) async {
    final client = Client('DirexioContactHomeDeleteNavigationTest')
      ..setUserId('@owner:p2p-im.com');
    _addTestRoom(
      client,
      roomId: '!alice:p2p-im.com',
      roomMembership: Membership.join,
      directPeerMxid: '@alice:portal.local',
    );
    final asClient = _TrackingAsClient();
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 28, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:portal.local',
          displayName: 'Alice Chen',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'alice.portal.local',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final router = GoRouter(
      initialLocation: '/chat/${Uri.encodeComponent('!alice:p2p-im.com')}',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('messages-home')),
        ),
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, __) => const Scaffold(body: Text('会话不存在')),
        ),
        GoRoute(
          path: '/contact-home/:userId',
          builder: (_, state) => ContactHomePage(
            userId: state.pathParameters['userId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.push('/contact-home/${Uri.encodeComponent('@alice:portal.local')}');
    await tester.pumpAndSettle();

    final friendButton =
        find.byKey(const ValueKey('contact_home_add_friend_button'));
    expect(find.descendant(of: friendButton, matching: find.text('删除好友')),
        findsOneWidget);

    await tester.tap(friendButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(asClient.deleteContactCalls, 1);
    expect(asClient.deletedContactRoomId, '!alice:p2p-im.com');
    expect(client.getRoomById('!alice:p2p-im.com'), isNull);
    expect(find.text('messages-home'), findsOneWidget);
    expect(find.text('会话不存在'), findsNothing);
  });

  testWidgets('global search includes locally cached Matrix messages',
      (tester) async {
    final client = Client('DirexioTestCachedSearch')
      ..setUserId('@owner:example.com');
    final room = Room(
      id: '!cached:example.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: '@alice:example.com',
        stateKey: '@alice:example.com',
        content: {
          'membership': Membership.join.name,
          'displayname': 'Alice Chen',
        },
      ),
    );
    room.lastEvent = Event(
      room: room,
      eventId: r'$cached-message',
      senderId: '@alice:example.com',
      type: EventTypes.Message,
      originServerTs: DateTime(2026, 5, 25, 10),
      content: {
        'msgtype': MessageTypes.Text,
        'body': '这是一条 cached-history-needle 历史消息',
      },
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 25, 10),
      user: const AsSyncUser(userId: '@owner:example.com'),
      rooms: [
        AsSyncRoomSummary(
          roomId: '!cached:example.com',
          name: 'Alice Chen',
          avatarUrl: '',
          unreadCount: 0,
          lastActivityAt: DateTime.utc(2026, 5, 25, 10),
        ),
      ],
      contacts: const [
        AsSyncContact(
          userId: '@alice:example.com',
          displayName: 'Alice Chen',
          avatarUrl: '',
          roomId: '!cached:example.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SearchPage()),
      ),
    );

    await tester.enterText(find.byType(TextField), 'cached-history-needle');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Alice Chen'), findsOneWidget);
    expect(find.text('这是一条 cached-history-needle 历史消息'), findsOneWidget);
  });

  testWidgets(
      'global search hides message results without ProductCore conversation',
      (tester) async {
    final client = Client('DirexioTestSearchRequiresProductConversation')
      ..setUserId('@owner:example.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          asClientProvider
              .overrideWithValue(_ConversationListAsClient(const [])),
          matrixMessageSearchClientProvider.overrideWithValue(
            _StaticMatrixMessageSearchClient(
              [
                MatrixMessageSearchResult(
                  eventId: r'$orphan-message',
                  roomId: '!orphan:example.com',
                  senderId: '@alice:example.com',
                  body: '远端孤儿消息 orphan-product-conversation-needle',
                  timestamp: DateTime(2026, 5, 25, 12),
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SearchPage()),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'orphan-product-conversation-needle',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('远端孤儿消息 orphan-product-conversation-needle'),
      findsNothing,
    );
    expect(
      find.text('没有找到包含「orphan-product-conversation-needle」的内容'),
      findsOneWidget,
    );
  });

  testWidgets('global search hides group invite messages', (tester) async {
    final client = Client('DirexioTestGroupInviteSearch')
      ..setUserId('@owner:example.com');
    final room = Room(
      id: '!invite-direct:example.com',
      client: client,
      membership: Membership.join,
    );
    client.rooms.add(room);
    room.lastEvent = Event(
      room: room,
      eventId: r'$local-group-invite',
      senderId: '@alice:example.com',
      type: EventTypes.Message,
      originServerTs: DateTime(2026, 5, 25, 11),
      content: {
        'msgtype': 'p2p.group.invite.v1',
        'body': '邀请加入群聊 hidden-invite-needle',
        'group_room_id': '!group:example.com',
        'group_name': '测试群',
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          matrixMessageSearchClientProvider.overrideWithValue(
            _StaticMatrixMessageSearchClient(
              [
                MatrixMessageSearchResult(
                  eventId: r'$remote-group-invite',
                  roomId: '!invite-direct:example.com',
                  senderId: '@alice:example.com',
                  body: '邀请进群 hidden-invite-needle',
                  timestamp: DateTime(2026, 5, 25, 11),
                  messageType: 'p2p.group.invite.v1',
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SearchPage()),
      ),
    );

    await tester.enterText(find.byType(TextField), 'hidden-invite-needle');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump();

    expect(find.text('邀请加入群聊 hidden-invite-needle'), findsNothing);
    expect(find.text('邀请进群 hidden-invite-needle'), findsNothing);
    expect(find.text('没有找到包含「hidden-invite-needle」的内容'), findsOneWidget);
  });

  testWidgets('me page presents origin niki-dev settings list', (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );

    await tester.tap(find.text('我的'));
    await tester.pump();

    expect(find.text('个性签名'), findsNothing);
    expect(find.text('用自己的节点，连接重要的人和内容。'), findsNothing);
    expect(find.text('我的频道'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('赞'), findsOneWidget);
    expect(find.text('评论'), findsOneWidget);
    expect(find.text('帮助与反馈'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == Symbols.settings,
      ),
      findsOneWidget,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text('动态'), findsNothing);
    expect(find.byKey(const ValueKey('me_dynamics_timeline')), findsNothing);
    expect(find.text('第三方平台一键安装'), findsNothing);
    expect(find.text('作品墙'), findsNothing);
    expect(find.text('账号与安全'), findsNothing);
    expect(find.text('通知设置'), findsNothing);
    expect(find.text('通用'), findsNothing);
    expect(find.text('退出登录'), findsNothing);
  });

  testWidgets('me page does not render removed dynamic feature',
      (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );

    await tester.tap(find.text('我的'));
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(find.text('动态'), findsNothing);
    expect(find.byKey(const ValueKey('me_dynamics_timeline')), findsNothing);
    expect(find.text('第三方平台一键安装'), findsNothing);
    expect(find.text('最后问一声，还有要加仓股票的吗'), findsNothing);
  });

  testWidgets('me page uses profile row without duplicate page title',
      (tester) async {
    var clipboardText = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboardText = (call.arguments as Map)['text'] as String? ?? '';
            return null;
          case 'Clipboard.getData':
            return {'text': clipboardText};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final client = Client('DirexioTest')..setUserId('@owner:p2p-im.com');
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(path: '/me/qr', builder: (_, __) => const MeQrPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('我的'));
    await tester.pump();

    expect(find.text('我的'), findsWidgets);
    expect(find.text('owner'), findsOneWidget);
    expect(find.text('https://p2p-im.com'), findsOneWidget);
    expect(find.text('我的频道'), findsOneWidget);
    expect(find.text('@me'), findsNothing);
    expect(find.textContaining('Node:'), findsNothing);

    await tester.tap(find.text('https://p2p-im.com'));
    await tester.pump();
    expect(find.text('已复制 UID'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final copied = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copied?.text, 'https://p2p-im.com');
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byIcon(Symbols.content_copy));
    await tester.pumpAndSettle();
    final copiedFromIcon = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copiedFromIcon?.text, 'https://p2p-im.com');

    await tester.tap(find.byIcon(Symbols.qr_code_2));
    await tester.pumpAndSettle();

    expect(find.text('我的二维码'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('UID https://p2p-im.com'), findsOneWidget);
    expect(find.text('保存到相册'), findsOneWidget);
  });

  testWidgets('me page hides language row', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'language': '1'});
    final client = Client('DirexioMeNoLanguageRowTest')
      ..setUserId('@owner:p2p-im.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: MePage(client: client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('语言'), findsNothing);
    expect(find.byIcon(Symbols.language), findsNothing);
  });

  testWidgets('me page keeps long uid within profile row height',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final client = Client('DirexioLongUidTest')
      ..setUserId('@owner:very-long-personal-node-domain.example.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MePage(client: client),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('owner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('me settings button opens unified settings page', (tester) async {
    final client = Client('DirexioTest');
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(path: '/me/menu', builder: (_, __) => const MeMenuPage()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('我的'));
    await tester.pump();
    await tester.tap(find.byIcon(Symbols.settings));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('通用设置'), findsOneWidget);
    expect(find.text('隐私与安全'), findsOneWidget);
    expect(find.text('消息与通知'), findsOneWidget);
    expect(find.text('其他'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
    expect(find.text('注销登录'), findsOneWidget);
  });

  testWidgets('me favorites page renders AS favorite messages', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(_FavoritesAsClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('明天上午继续测试'), findsOneWidget);
    expect(
      tester.widgetList<PortalAvatar>(find.byType(PortalAvatar)).any(
            (avatar) =>
                avatar.imageUrl == 'https://cdn.example.com/alice-favorite.png',
          ),
      isTrue,
    );
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text(_FavoritesAsClient.generatedVideoName), findsNothing);
    expect(find.text(_FavoritesAsClient.generatedImageName), findsNothing);
    expect(find.text('视频'), findsAtLeastNWidgets(1));
    expect(find.text('图片'), findsAtLeastNWidgets(1));
    expect(find.byIcon(Symbols.folder), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('favorite-card-5')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('与 Alice 的聊天记录'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('favorite-card-6')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('群聊「产品测试群」的聊天记录'), findsAtLeastNWidgets(1));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('favorite-card-7')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('60s'), findsOneWidget);
    expect(find.text('Alice'), findsAtLeastNWidgets(1));
  });

  testWidgets('me favorites page uses cached sender avatar fallback',
      (tester) async {
    final client = Client('FavoritesSenderAvatarFallbackTest')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.parse('2026-06-06T10:30:00Z'),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-liyanan.com',
          displayName: 'Alice',
          domain: 'p2p-liyanan.com',
          avatarUrl: 'mxc://p2p-im.com/alice-cached-avatar',
          roomId: '!dm:p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(
            _FavoritesAsClient(textSenderAvatarUrl: ''),
          ),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      tester.widgetList<PortalAvatar>(find.byType(PortalAvatar)).any(
            (avatar) =>
                avatar.imageUrl?.contains(
                  '/download/p2p-im.com/alice-cached-avatar',
                ) ??
                false,
          ),
      isTrue,
    );
  });

  testWidgets('me favorites page uses unified dark background and back button',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(_FavoritesAsClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('me_favorites_scaffold')),
    );
    final backIcon = tester.widget<Icon>(find.byIcon(Symbols.arrow_back));

    expect(scaffold.backgroundColor, PortalTokens.dark.bg);
    expect(backIcon.color, PortalTokens.dark.text);
    expect(find.text('收藏'), findsOneWidget);
  });

  testWidgets('me likes page renders AS channel reaction history',
      (tester) async {
    final asClient = _ChannelActivityAsClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeLikesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(asClient.reactionsCallCount, 1);
    expect(asClient.lastReactionsLimit, 50);
    expect(find.text('赞'), findsOneWidget);
    expect(find.text('产品公告'), findsOneWidget);
    expect(find.text('你赞了这条帖子'), findsOneWidget);
    expect(find.text('频道发帖已打通'), findsAtLeastNWidgets(1));
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('me comments page renders AS channel comment history',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(_ChannelActivityAsClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeCommentsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('评论'), findsOneWidget);
    expect(find.text('产品公告'), findsOneWidget);
    expect(find.text('你评论了：这条评论来自真实用户名'), findsOneWidget);
    expect(find.text('频道发帖已打通'), findsOneWidget);
  });

  testWidgets('me comments page follows dark mode tokens', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(_ChannelActivityAsClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const MeCommentsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('me_comments_scaffold')),
    );

    expect(scaffold.backgroundColor, PortalTokens.dark.bg);
    expect(find.text('评论'), findsOneWidget);
  });

  testWidgets('me comments page loads API data and opens related post',
      (tester) async {
    final asClient = _ChannelActivityAsClient();
    final router = GoRouter(
      initialLocation: '/me/comments',
      routes: [
        GoRoute(
          path: '/me/comments',
          builder: (_, __) => const MeCommentsPage(),
        ),
        GoRoute(
          path: '/channel/:channelId/post/:postId',
          builder: (_, state) => Text(
            'post:${state.pathParameters['channelId']}:'
            '${state.pathParameters['postId']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(asClient.commentsCallCount, 1);
    expect(asClient.lastCommentsLimit, 50);
    expect(find.text('你评论了：这条评论来自真实用户名'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('my-comment-comment1')));
    await tester.pumpAndSettle();

    expect(find.text('post:ch_product:post1'), findsOneWidget);
  });

  testWidgets('me favorites page shows mixed favorite types as cards',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(_FavoritesAsClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('明天上午继续测试'), findsOneWidget);
    expect(find.text('report.pdf'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('favorite-card-5')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('与 Alice 的聊天记录'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('favorite-card-7')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('60s'), findsOneWidget);
  });

  testWidgets('me favorites cards keep only the video preview play badge',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(_FavoritesAsClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Symbols.chevron_right), findsNothing);
    expect(find.byIcon(Symbols.play_arrow), findsOneWidget);
  });

  testWidgets('me favorites media previews match figma card size',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(_FavoritesAsClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    for (final id in [3, 4]) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('favorite-preview-$id')),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        tester.getSize(find.byKey(ValueKey('favorite-preview-$id'))),
        const Size.square(109),
      );
    }
    expect(
      tester.getSize(find.byKey(const ValueKey('favorite-preview-2'))),
      const Size.square(70),
    );
  });

  testWidgets('me favorites image lightbox falls back to original media',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final requested = <Uri>[];
    final cache = _MemoryMediaThumbnailCache();
    final client = Client(
      'DirexioFavoritePreviewTest',
      httpClient: MockClient((request) async {
        requested.add(request.url);
        return http.Response.bytes(
          _transparentPng,
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          mediaThumbnailCacheProvider.overrideWith((ref) async => cache),
          asClientProvider
              .overrideWithValue(_FavoritesAsClient(videoThumbnail: false)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('favorite-card-4')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('favorite-preview-4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      requested.any(
        (uri) => uri.path.contains('/download/p2p-im.com/image'),
      ),
      isTrue,
    );
  });

  testWidgets('me favorites image card opens favorite detail outside preview',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider
              .overrideWithValue(_FavoritesAsClient(videoThumbnail: false)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('favorite-card-4')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    final cardTopLeft =
        tester.getTopLeft(find.byKey(const ValueKey('favorite-card-4')));
    await tester.tapAt(cardTopLeft + const Offset(260, 26));
    await tester.pumpAndSettle();

    expect(find.text('收藏详情'), findsOneWidget);
    expect(find.byIcon(Symbols.close), findsNothing);
    expect(find.text('消息详情'), findsNothing);
  });

  testWidgets('me favorites image thumbnail opens image preview',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final client = Client(
      'DirexioFavoriteImageOpenTest',
      httpClient: MockClient((request) async {
        return http.Response.bytes(
          _transparentPng,
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider
              .overrideWithValue(_FavoritesAsClient(videoThumbnail: false)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorite-preview-4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byIcon(Symbols.close), findsOneWidget);
    expect(find.textContaining('来自与 Alice 的私聊'), findsOneWidget);
    expect(find.text('收藏详情'), findsNothing);
    expect(find.text('消息详情'), findsNothing);
  });

  testWidgets('me favorites image preview falls back to thumbnail URL',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final client = Client(
      'DirexioFavoriteImageThumbnailFallbackTest',
      httpClient: MockClient((request) async {
        return http.Response.bytes(
          _transparentPng,
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          asClientProvider.overrideWithValue(
            _FavoritesAsClient(
              videoThumbnail: false,
              imageUrl: '',
              imageThumbnailUrl: 'mxc://p2p-im.com/image-thumb',
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorite-preview-4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byIcon(Symbols.close), findsOneWidget);
    expect(find.textContaining('收藏图片地址为空'), findsNothing);
  });

  testWidgets('me favorites image preview uses cached media bytes',
      (tester) async {
    final requested = <Uri>[];
    final cache = _MemoryMediaThumbnailCache()
      ..items['favorite-media:mxc://p2p-im.com/image'] = _transparentPng;
    final client = Client(
      'DirexioFavoriteImageCachedPreviewTest',
      httpClient: MockClient((request) async {
        requested.add(request.url);
        return http.Response.bytes(
          _transparentPng,
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          mediaThumbnailCacheProvider.overrideWith((ref) async => cache),
          asClientProvider
              .overrideWithValue(_FavoritesAsClient(videoThumbnail: false)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      requested.any(
        (uri) => uri.path.contains('/download/p2p-im.com/image'),
      ),
      isFalse,
    );
  });

  testWidgets('me favorites media cards open favorite detail', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider
              .overrideWithValue(_FavoritesAsClient(videoThumbnail: false)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('favorite-card-3')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('favorite-card-3')));
    await tester.pumpAndSettle();

    expect(find.text('收藏详情'), findsOneWidget);
    expect(find.text('消息详情'), findsNothing);
  });

  testWidgets('me favorites card can be deleted from long press menu',
      (tester) async {
    final asClient = _FavoritesAsClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('report.pdf'), findsOneWidget);

    await tester.longPress(find.byKey(const ValueKey('favorite-card-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除收藏'));
    await tester.pumpAndSettle();

    expect(asClient.deletedFavoriteIds, contains(2));
    await tester.pump();
    expect(find.text('report.pdf'), findsNothing);
  });

  testWidgets('me favorites page matches figma without search filters',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(_FavoritesAsClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('搜索收藏内容'), findsNothing);
    expect(find.text('全部'), findsNothing);
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('明天上午继续测试'), findsOneWidget);
  });

  testWidgets('me favorites card can be deleted by swipe confirmation',
      (tester) async {
    final asClient = _FavoritesAsClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(asClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('report.pdf'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('favorite-card-2')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('取消收藏'), findsOneWidget);
    expect(find.text('确认删除该收藏吗？'), findsOneWidget);

    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(asClient.deletedFavoriteIds, contains(2));
    expect(find.text('report.pdf'), findsNothing);
  });

  testWidgets('me favorites page opens text favorite as favorite detail',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(_FavoritesAsClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorite-card-1')));
    await tester.pumpAndSettle();

    expect(find.text('收藏详情'), findsOneWidget);
    expect(find.text('消息详情'), findsNothing);
    expect(find.text('复制内容'), findsNothing);
    expect(find.text('明天上午继续测试'), findsWidgets);
    expect(find.text('来自与 Alice 的私聊'), findsOneWidget);
  });

  testWidgets('me favorites media cards do not bypass favorite detail',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider
              .overrideWithValue(_FavoritesAsClient(videoThumbnail: false)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('favorite-card-3')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('favorite-card-3')));
    await tester.pumpAndSettle();

    expect(find.text('消息详情'), findsNothing);
    expect(find.text('收藏详情'), findsOneWidget);
    expect(find.textContaining('打开失败'), findsNothing);
  });

  testWidgets('me favorites chat record cards open as favorite detail',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          asClientProvider.overrideWithValue(_FavoritesAsClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MeFavoritesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('favorite-card-5')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorite-card-5')));
    await tester.pumpAndSettle();

    expect(find.text('收藏详情'), findsOneWidget);
    expect(find.text('消息详情'), findsNothing);
    expect(find.text('与 Alice 的聊天记录'), findsWidgets);
    expect(find.text('第一条'), findsOneWidget);
    expect(find.text('第二条'), findsOneWidget);
  });

  testWidgets('me settings button stays below the status safe area',
      (tester) async {
    final client = Client('DirexioTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(
              padding: EdgeInsets.only(top: 44),
            ),
            child: HomePage(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('我的'));
    await tester.pump();

    final topLeft = tester.getTopLeft(find.byIcon(Symbols.settings));
    expect(topLeft.dy, greaterThanOrEqualTo(52));
  });

  testWidgets('me profile header opens editable profile info page',
      (tester) async {
    var clipboardText = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboardText = (call.arguments as Map)['text'] as String? ?? '';
            return null;
          case 'Clipboard.getData':
            return {'text': clipboardText};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final client = Client('DirexioTest')..setUserId('@owner:p2p-im.com');
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/me/profile',
          builder: (_, __) => const ProfileInfoPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('我的'));
    await tester.pump();

    await tester.tap(find.text('owner'));
    await tester.pumpAndSettle();

    expect(find.text('我的信息'), findsOneWidget);
    expect(find.text('修改'), findsOneWidget);
    expect(find.text('昵称'), findsOneWidget);
    expect(find.text('UID: https://p2p-im.com'), findsOneWidget);
    expect(find.text('性别'), findsOneWidget);
    expect(find.text('生日'), findsOneWidget);
    expect(find.text('邮箱'), findsOneWidget);

    await tester.tap(find.text('UID: https://p2p-im.com'));
    await tester.pump();
    expect(find.text('已复制 UID'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final copied = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copied?.text, 'https://p2p-im.com');
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byIcon(Symbols.content_copy));
    await tester.pumpAndSettle();
    final copiedFromIcon = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copiedFromIcon?.text, 'https://p2p-im.com');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('profile info does not use mock avatar fallback', (tester) async {
    final client = Client('DirexioProfileInfoNoMockAvatarTest')
      ..setUserId('@owner:p2p-im.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const ProfileInfoPage(),
        ),
      ),
    );
    await tester.pump();

    final avatar = tester
        .widgetList<PortalAvatar>(find.byType(PortalAvatar))
        .where((item) => item.size == 98)
        .single;
    expect(avatar.imageUrl, isNull);
  });

  testWidgets('profile info page localizes English labels and dialogs',
      (tester) async {
    final client = Client('DirexioProfileInfoEnglishTest')
      ..setUserId('@owner:p2p-im.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const ProfileInfoPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('My Info'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Nickname'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Birthday'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Not set'), findsAtLeastNWidgets(1));
    expect(find.text('我的信息'), findsNothing);
    expect(find.text('未设置'), findsNothing);

    await tester.tap(find.text('Gender'));
    await tester.pumpAndSettle();

    expect(find.text('Male'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('男'), findsNothing);
    expect(find.text('女'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nickname'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Nickname'), findsOneWidget);
    expect(find.text('Enter Nickname'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('修改昵称'), findsNothing);
  });

  testWidgets('me qr page does not use mock avatar fallback', (tester) async {
    final client = Client('DirexioMeQrNoMockAvatarTest')
      ..setUserId('@owner:p2p-im.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const MeQrPage(),
        ),
      ),
    );
    await tester.pump();

    final avatar = tester
        .widgetList<PortalAvatar>(find.byType(PortalAvatar))
        .where((item) => item.size == 60)
        .single;
    expect(avatar.imageUrl, isNull);
  });

  test('me qr payload includes current avatar url', () {
    final payload = Uri.parse(
      buildMeQrPayload(
        userId: '@owner:p2p-im.com',
        domain: 'https://p2p-im.com',
        displayName: 'Owner',
        avatarUrl:
            'https://p2p-im.com/_matrix/media/v3/download/p2p-im.com/owner-avatar',
      ),
    );

    expect(payload.queryParameters['mxid'], '@owner:p2p-im.com');
    expect(
      payload.queryParameters['avatar_url'],
      'https://p2p-im.com/_matrix/media/v3/download/p2p-im.com/owner-avatar',
    );
  });

  testWidgets('editing profile name updates me page header', (tester) async {
    final client = Client('DirexioTest')..setUserId('@owner:p2p-im.com');
    final asClient = _EmptyAsClient();
    final router = GoRouter(
      initialLocation: '/me/profile',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/me/profile',
          builder: (_, __) => const ProfileInfoPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('昵称'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '破局');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(asClient.updatedOwnerDisplayName, '破局');
    expect(find.text('破局'), findsAtLeastNWidgets(1));

    router.go('/home');
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pump();

    expect(find.text('破局'), findsOneWidget);
  });

  testWidgets('settings page matches Direxio settings sections',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('通用设置'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('收藏'), findsNothing);
    expect(find.text('隐私与安全'), findsOneWidget);
    expect(find.text('通讯录黑名单'), findsNothing);
    expect(find.text('消息与通知'), findsOneWidget);
    expect(find.text('勿扰模式'), findsOneWidget);
    expect(find.text('新消息提示音'), findsOneWidget);
    expect(find.text('新消息震动'), findsOneWidget);
    expect(find.text('其他'), findsOneWidget);
    expect(find.text('关于我们'), findsOneWidget);
    expect(find.text('清空聊天记录'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
    expect(find.text('注销登录'), findsOneWidget);
  });

  testWidgets('settings blacklist row is hidden', (tester) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Blocked Contacts'), findsNothing);
    expect(find.text('通讯录黑名单'), findsNothing);
  });

  testWidgets('settings deactivate login shows cancellation window',
      (tester) async {
    _RecordingLogoutAuthStateNotifier.logoutCalls = 0;
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider
              .overrideWith(_RecordingLogoutAuthStateNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('注销登录'));
    await tester.tap(find.text('注销登录'));
    await tester.pumpAndSettle();

    expect(find.text('注销登录'), findsWidgets);
    expect(find.text('14天内，只要登录一次账号，注销就会自动取消'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);

    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(_RecordingLogoutAuthStateNotifier.logoutCalls, 1);
  });

  testWidgets('settings page row icons use primary text color', (tester) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    for (final icon in [
      Symbols.language,
      Symbols.contrast,
      Symbols.key,
      Symbols.do_not_disturb_on,
      Symbols.notifications,
      Symbols.vibration,
      Symbols.info,
      Symbols.delete,
    ]) {
      expect(tester.widget<Icon>(find.byIcon(icon)).color,
          PortalTokens.light.text);
    }
  });

  testWidgets('about us page uses bundled logo asset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AboutUsPage()),
    );
    await tester.pump();

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('about_us_logo_asset')),
    );
    expect(image.image, const AssetImage('assets/images/logo.png'));
  });

  testWidgets('account security page setting icons are neutral',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const MeAccountPage()),
    );
    await tester.pump();

    for (final icon in [
      Symbols.shield_person,
      Symbols.key,
      Symbols.fingerprint,
      Symbols.lock,
      Symbols.devices,
    ]) {
      expect(tester.widget<Icon>(find.byIcon(icon)).color,
          PortalTokens.light.textMute);
    }
    for (final icon
        in tester.widgetList<Icon>(find.byIcon(Symbols.chevron_right))) {
      expect(icon.color, PortalTokens.light.textMute);
    }
  });

  testWidgets('notification settings page setting icons are neutral',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
            theme: AppTheme.light, home: const MeNotificationsPage()),
      ),
    );
    await tester.pump();

    for (final icon in [
      Symbols.notifications,
      Symbols.do_not_disturb_on,
      Symbols.vibration,
      Symbols.schedule,
    ]) {
      expect(tester.widget<Icon>(find.byIcon(icon)).color,
          PortalTokens.light.textMute);
    }
    for (final icon
        in tester.widgetList<Icon>(find.byIcon(Symbols.chevron_right))) {
      expect(icon.color, PortalTokens.light.textMute);
    }
  });

  testWidgets('agent chat back falls home when chat is the root route',
      (tester) async {
    const roomId = '!agent-room:p2p-im.com';
    final client = Client('DirexioTest')..setUserId('@owner:p2p-im.com');
    final room = _addTestRoom(
      client,
      roomId: roomId,
      roomMembership: Membership.join,
      directPeerMxid: '@agent:p2p-im.com',
    );
    room.summary.mHeroes = ['@agent:p2p-im.com'];
    final router = GoRouter(
      initialLocation: '/chat/${Uri.encodeComponent(roomId)}',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HomeRoot')),
        ),
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, state) =>
              ChatPage(roomId: state.pathParameters['roomId']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Agent'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('HomeRoot'), findsOneWidget);
  });

  testWidgets('agent chat header uses AS connection status', (tester) async {
    final client = Client('DirexioTest')..setUserId('@owner:p2p-im.com');
    final room = _addTestRoom(
      client,
      roomId: '!agent-room:p2p-im.com',
      roomMembership: Membership.join,
      directPeerMxid: '@agent:p2p-im.com',
      directPeerName: 'Direxio AI',
    );
    room.summary.mHeroes = ['@agent:p2p-im.com'];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: '!agent-room:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Direxio AI'), findsOneWidget);
    expect(find.text('Agent'), findsNothing);
    expect(find.text('离线'), findsOneWidget);
    expect(find.text('在线'), findsNothing);
  });

  testWidgets('private chat hides first-message empty state for cached preview',
      (tester) async {
    const roomId = '!cached-direct:p2p-im.com';
    const peerMxid = '@alice:p2p-im.com';
    final client = Client('DirexioCachedChatPreviewTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: roomId,
      peerMxid: peerMxid,
      peerName: 'Alice',
    );
    final snapshotStore = _MemoryConversationSummaryStore(
      ConversationSummarySnapshot(
        userId: '@owner:p2p-im.com',
        updatedAt: DateTime.utc(2026, 6, 23, 10),
        entries: [
          ConversationSummaryEntry(
            roomId: roomId,
            name: 'Alice',
            lastMessage: '本地缓存消息',
            previewTs: DateTime.utc(2026, 6, 23, 10).millisecondsSinceEpoch,
            unread: 0,
            isGroup: false,
            isAgent: false,
          ),
        ],
      ),
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 23, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: peerMxid,
          displayName: 'Alice',
          avatarUrl: '',
          roomId: roomId,
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          conversationSummaryStoreProvider.overrideWith(
            (ref) async => snapshotStore,
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: roomId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('开始你们的第一条消息'), findsNothing);
  });

  testWidgets('private chat toolbar uses localized action tooltips',
      (tester) async {
    await _pumpDirectChatWithPeerTextEvent(
      tester,
      sendPeerEvent: false,
      locale: const Locale('en'),
    );

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Message Encryption'), findsOneWidget);
    expect(find.byTooltip('Details'), findsOneWidget);
    expect(find.byTooltip('返回'), findsNothing);
    expect(find.byTooltip('端对端加密'), findsNothing);
    expect(find.byTooltip('详情'), findsNothing);
  });

  testWidgets('private chat header shows peer offline and typing status',
      (tester) async {
    const roomId = '!peer-status:p2p-im.com';
    const peerMxid = '@alice:p2p-im.com';
    final client = Client('DirexioPeerStatusTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: roomId,
      peerMxid: peerMxid,
      peerName: 'Alice',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 16, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: peerMxid,
          displayName: 'Alice',
          avatarUrl: '',
          roomId: roomId,
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: roomId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('离线'), findsNothing);
    expect(find.text('在线'), findsNothing);

    await client.handleSync(
      SyncUpdate(
        nextBatch: 'after-peer-online',
        presence: [
          Presence.fromJson(
            const {
              'type': 'm.presence',
              'sender': peerMxid,
              'content': {
                'presence': 'online',
                'currently_active': true,
              },
            },
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('在线'), findsOneWidget);
    expect(find.text('离线'), findsNothing);

    await client.handleSync(
      SyncUpdate(
        nextBatch: 'after-peer-typing',
        rooms: RoomsUpdate(
          join: {
            roomId: JoinedRoomUpdate(
              ephemeral: [
                BasicRoomEvent(
                  type: 'm.typing',
                  content: const {
                    'user_ids': [peerMxid],
                  },
                ),
              ],
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('在想'), findsOneWidget);
    expect(find.text('离线'), findsNothing);
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('private chat can forward a peer message from long press',
      (tester) async {
    await _pumpDirectChatWithPeerTextEvent(tester);

    await tester.longPress(find.text('别人发来的消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('转发'));
    await tester.pumpAndSettle();

    expect(find.text('转发聊天记录'), findsOneWidget);
    expect(find.text('Alice'), findsWidgets);
  });

  testWidgets('private chat long press exposes message actions',
      (tester) async {
    await _pumpDirectChatWithPeerTextEvent(tester);

    await tester.longPress(find.text('别人发来的消息'));
    await tester.pumpAndSettle();

    expect(find.text('复制'), findsOneWidget);
    expect(find.text('转发'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('多选'), findsOneWidget);
    expect(find.text('引用'), findsOneWidget);
  });

  testWidgets('private chat recalls own message through Matrix redaction',
      (tester) async {
    final harness = await _pumpDirectChatWithPeerTextEvent(
      tester,
      eventId: r'$direct-own-text',
      body: '我发出的单聊消息',
      senderMxid: '@owner:p2p-im.com',
    );

    await tester.longPress(find.text('我发出的单聊消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('撤回'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '撤回'));
    await tester.pumpAndSettle();

    expect(harness.matrixRedactionPaths, hasLength(1));
    expect(harness.matrixRedactionPaths.single,
        contains('/redact/%24direct-own-text/'));
  });

  testWidgets('private chat long press exposes local outbox actions',
      (tester) async {
    await _pumpDirectChatWithPeerTextEvent(
      tester,
      sendPeerEvent: false,
      initialOutboxItems: [
        LocalOutboxItem(
          id: 'direct-text-pending-1',
          conversationId: '!direct:p2p-im.com',
          conversationType: LocalOutboxConversationType.direct,
          messageKind: LocalOutboxMessageKind.text,
          text: '单聊本地待发送消息',
          filename: '',
          mimeType: 'text/plain',
          createdAt: DateTime.utc(2026, 5, 30, 12),
          status: LocalOutboxItemStatus.failed,
          runtimeId: '',
          batchId: 'direct-text-batch-1',
          batchIndex: 0,
        ),
      ],
    );

    await tester.longPress(find.text('单聊本地待发送消息'));
    await tester.pumpAndSettle();

    expect(find.text('复制'), findsOneWidget);
    expect(find.text('转发'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('多选'), findsOneWidget);
  });

  testWidgets('private chat uses current profile avatar for own messages',
      (tester) async {
    const roomId = '!own-avatar:p2p-im.com';
    final client = Client(
      'DirexioOwnMessageAvatarTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addUndirectedJoinedRoom(
      client,
      roomId: roomId,
      peerMxid: '@alice:p2p-liyanan.com',
      peerName: 'Alice',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 12, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-liyanan.com',
          displayName: 'Alice',
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          currentUserProfileProvider.overrideWith(
            (ref) async => Profile(
              userId: '@owner:p2p-im.com',
              displayName: 'Owner',
              avatarUrl: Uri.parse('https://cdn.example.com/me.png'),
            ),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: roomId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await client.handleSync(
      SyncUpdate(
        nextBatch: 'after-own-message',
        rooms: RoomsUpdate(
          join: {
            roomId: JoinedRoomUpdate(
              timeline: TimelineUpdate(
                events: [
                  MatrixEvent(
                    type: EventTypes.Message,
                    eventId: r'$own-avatar-message',
                    roomId: roomId,
                    senderId: '@owner:p2p-im.com',
                    originServerTs: DateTime.utc(2026, 6, 12, 12, 10),
                    content: const {
                      'msgtype': MessageTypes.Text,
                      'body': '我发出的消息',
                    },
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('我发出的消息'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.size == 40 &&
            widget.imageUrl == 'https://cdn.example.com/me.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('private chat shows read icon only after peer receipt',
      (tester) async {
    const roomId = '!read-receipt:p2p-im.com';
    const peerMxid = '@alice:p2p-liyanan.com';
    const eventId = r'$read-target';
    final client = Client(
      'DirexioReadReceiptIconTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    _addUndirectedJoinedRoom(
      client,
      roomId: roomId,
      peerMxid: peerMxid,
      peerName: 'Alice',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 12, 12),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: peerMxid,
          displayName: 'Alice',
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: roomId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await client.handleSync(
      SyncUpdate(
        nextBatch: 'after-own-unread-message',
        rooms: RoomsUpdate(
          join: {
            roomId: JoinedRoomUpdate(
              timeline: TimelineUpdate(
                events: [
                  MatrixEvent(
                    type: EventTypes.Message,
                    eventId: eventId,
                    roomId: roomId,
                    senderId: '@owner:p2p-im.com',
                    originServerTs: DateTime.utc(2026, 6, 12, 12, 10),
                    content: const {
                      'msgtype': MessageTypes.Text,
                      'body': '等待对方读取',
                    },
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('等待对方读取'), findsOneWidget);
    expect(find.byIcon(Symbols.done_all), findsNothing);

    await client.handleSync(
      SyncUpdate(
        nextBatch: 'after-peer-read-receipt',
        rooms: RoomsUpdate(
          join: {
            roomId: JoinedRoomUpdate(
              ephemeral: [
                BasicRoomEvent(
                  type: 'm.receipt',
                  content: {
                    eventId: {
                      'm.read': {
                        peerMxid: {'ts': 1781250000000},
                      },
                    },
                  },
                ),
              ],
            ),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byIcon(Symbols.done_all), findsOneWidget);
  });

  testWidgets('chat renders accepted-friend notice as system hint',
      (tester) async {
    final client = Client('DirexioSystemNoticeChatTest')
      ..setUserId('@owner:p2p-im.com');
    final room = _addUndirectedJoinedRoom(
      client,
      roomId: '!accepted:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'owner',
    );
    room.lastEvent = Event(
      room: room,
      eventId: r'$accepted-notice',
      senderId: '@owner:p2p-liyanan.com',
      type: EventTypes.Message,
      originServerTs: DateTime.utc(2026, 5, 27, 16, 10),
      content: const {
        'msgtype': MessageTypes.Notice,
        'body': '你们已成为好友，现在可以开始聊天了',
      },
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 27, 16),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'owner',
          avatarUrl: '',
          roomId: '!accepted:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_ReadMarkerFailingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: '!accepted:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();
    await client.handleSync(
      SyncUpdate(
        nextBatch: 'after-accepted-notice',
        rooms: RoomsUpdate(
          join: {
            '!accepted:p2p-im.com': JoinedRoomUpdate(
              timeline: TimelineUpdate(
                events: [
                  MatrixEvent(
                    type: EventTypes.Message,
                    eventId: r'$accepted-notice',
                    roomId: '!accepted:p2p-im.com',
                    senderId: '@owner:p2p-liyanan.com',
                    originServerTs: DateTime.utc(2026, 5, 27, 16, 10),
                    content: const {
                      'msgtype': MessageTypes.Notice,
                      'body': '你们已成为好友，现在可以开始聊天了',
                    },
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('chat_system_notice')), findsOneWidget);
    final noticeFinder = find.text('你们已成为好友，现在可以开始聊天了');
    expect(noticeFinder, findsOneWidget);
    final noticeText = tester.widget<Text>(noticeFinder);
    expect(noticeText.style?.fontSize, 11);
    expect(find.text('端对端加密'), findsNothing);
  });

  testWidgets('accepted private chat text send uses Matrix SDK',
      (tester) async {
    var matrixSendCalls = 0;
    final client = Client(
      'DirexioAcceptedPrivateMatrixSendTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
          matrixSendCalls++;
          return http.Response(
            r'{"event_id":"$private-message"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'matrix-token';
    _addTestRoom(
      client,
      roomId: '!accepted:p2p-im.com',
      roomMembership: Membership.join,
      directPeerMxid: '@alice:p2p-im.com',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 20),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-im.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!accepted:p2p-im.com',
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: '!accepted:p2p-im.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '私聊走 Matrix');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pump(const Duration(seconds: 3));

    expect(matrixSendCalls, 1);
  });

  testWidgets('agent chat shows thinking animation after send', (tester) async {
    const roomId = '!agent-room:p2p-im.com';
    const ownerMxid = '@owner:p2p-im.com';
    const agentMxid = '@agent:p2p-im.com';
    var matrixSendCalls = 0;
    final client = Client(
      'DirexioAgentThinkingBubbleTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
          matrixSendCalls++;
          return http.Response(
            r'{"event_id":"$agent-question"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId(ownerMxid);
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'matrix-token';
    final room = Room(
      id: roomId,
      client: client,
      membership: Membership.join,
      summary: RoomSummary.fromJson({
        'm.joined_member_count': 2,
        'm.invited_member_count': 0,
      }),
    );
    client.rooms.add(room);
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: ownerMxid,
        stateKey: ownerMxid,
        content: const {'membership': 'join'},
      ),
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: agentMxid,
        stateKey: agentMxid,
        content: const {
          'membership': 'join',
          'displayname': 'Agent',
        },
      ),
    );
    expect(isPortalAgentDirectRoom(room), isFalse);
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 24),
      user: const AsSyncUser(userId: ownerMxid),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
      agentRoomId: roomId,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_TrackingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: roomId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '帮我想一下');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(matrixSendCalls, 1);
    expect(find.byKey(const ValueKey('agent_thinking_bubble')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent_thinking_dots')), findsOneWidget);

    await client.handleSync(
      SyncUpdate(
        nextBatch: 'after-agent-reply',
        rooms: RoomsUpdate(
          join: {
            roomId: JoinedRoomUpdate(
              timeline: TimelineUpdate(
                events: [
                  MatrixEvent(
                    type: EventTypes.Message,
                    eventId: r'$agent-reply',
                    roomId: roomId,
                    senderId: agentMxid,
                    originServerTs: DateTime.now().add(
                      const Duration(seconds: 1),
                    ),
                    content: const {
                      'msgtype': MessageTypes.Text,
                      'body': '我想好了',
                    },
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('agent_thinking_bubble')), findsNothing);
    expect(find.text('我想好了'), findsOneWidget);
  });

  testWidgets('chat waits for Matrix room load when AS knows conversation',
      (tester) async {
    const roomId = '!alice:p2p-im.com';
    const ownerMxid = '@owner:p2p-im.com';
    const peerMxid = '@alice:p2p-im.com';
    final client = _RecoveringDirectRoomClient(
      recoveryRoomId: roomId,
      ownerMxid: ownerMxid,
      peerMxid: peerMxid,
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 12, 9),
      user: const AsSyncUser(userId: ownerMxid),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: peerMxid,
          displayName: 'Alice',
          avatarUrl: '',
          roomId: roomId,
          domain: 'p2p-im.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: roomId),
        ),
      ),
    );

    expect(find.text('正在同步会话'), findsOneWidget);
    expect(find.text('会话不存在'), findsNothing);

    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(client.getRoomById(roomId), isNotNull);
    expect(client.syncRequests, isNotEmpty);
    expect(client.syncRequests.single.fullState, isTrue);
    expect(client.syncRequests.single.since, isNull);
    expect(client.syncRequests.single.timeout, 0);
    final filter =
        jsonDecode(client.syncRequests.single.filter!) as Map<String, Object?>;
    final roomFilter = filter['room']! as Map<String, Object?>;
    final timelineFilter = roomFilter['timeline']! as Map<String, Object?>;
    expect(roomFilter['rooms'], [roomId]);
    expect(timelineFilter['limit'], chatOpenLocalHistoryPageSize);
    expect(find.text('正在同步会话'), findsNothing);
    expect(find.text('会话同步超时，请检查网络后重试'), findsNothing);
    expect(find.text('会话不存在'), findsNothing);
  });

  testWidgets('private chat shows friendly failure when peer deleted contact',
      (tester) async {
    _mockAudioRecorderPlugins(tester);
    final client = Client(
      'DirexioPeerDeletedSendTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
          return http.Response(
            '{"errcode":"M_FORBIDDEN","error":"peer deleted contact"}',
            403,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          '{"next_batch":"s1","rooms":{}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'matrix-token';
    _addTestRoom(
      client,
      roomId: '!alice:p2p-im.com',
      roomMembership: Membership.join,
      directPeerMxid: '@alice:p2p-liyanan.com',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 28),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-liyanan.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!alice:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'accepted',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
          localOutboxStoreProvider.overrideWith(
            (ref) async => _MemoryLocalOutboxStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: '!alice:p2p-im.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.text('对方已删除联系人关系，消息未送达'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('private chat blocks duplicate direct rooms omitted by AS',
      (tester) async {
    final client = Client('DirexioDuplicateDirectSendTest')
      ..setUserId('@owner:p2p-im.com');
    _addTestRoom(
      client,
      roomId: '!duplicate:p2p-im.com',
      roomMembership: Membership.join,
      directPeerMxid: '@alice:p2p-liyanan.com',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 28),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: '!duplicate:p2p-im.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('等待对方接受后才能发送消息'), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_upward), findsNothing);
  });

  testWidgets('private chat blocks unclassified one-to-one rooms omitted by AS',
      (tester) async {
    final client = Client('DirexioUnclassifiedOneToOneSendTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!old:p2p-im.com',
      peerMxid: '@alice:p2p-liyanan.com',
      peerName: 'Alice',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 28),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: '!old:p2p-im.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('等待对方接受后才能发送消息'), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_upward), findsNothing);
  });

  testWidgets('private chat blocks rejected direct rooms with joined peer',
      (tester) async {
    final client = Client('DirexioRejectedDirectSendTest')
      ..setUserId('@owner:p2p-im.com');
    _addTestRoom(
      client,
      roomId: '!rejected:p2p-im.com',
      roomMembership: Membership.join,
      directPeerMxid: '@alice:p2p-liyanan.com',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 28),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@alice:p2p-liyanan.com',
          displayName: 'Alice',
          avatarUrl: '',
          roomId: '!rejected:p2p-im.com',
          domain: 'p2p-liyanan.com',
          status: 'rejected',
        ),
      ],
      groups: const [],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: '!rejected:p2p-im.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('等待对方接受后才能发送消息'), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_upward), findsNothing);
  });

  testWidgets('login page hides setup shortcuts below login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('或'), findsNothing);
    expect(find.text('扫码添加服务器'), findsNothing);
    expect(find.text('初始化 Portal'), findsNothing);
  });

  testWidgets('init page shows weak prompt for required avatar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const InitPage(),
        ),
      ),
    );
    await tester.pump();

    final placeholderFrame = tester.widget<SizedBox>(
      find.byKey(const ValueKey('init_avatar_placeholder_frame')),
    );
    expect(placeholderFrame.width, 96);
    expect(placeholderFrame.height, 97);
    final placeholder = tester.widget<Image>(
      find.byKey(const ValueKey('init_avatar_placeholder_asset')),
    );
    expect(placeholder.image, const AssetImage('assets/images/2d-logo.png'));

    await tester.tap(find.text('确认'));
    await tester.pump();

    expect(find.byKey(const ValueKey('init_inline_weak_hint')), findsNothing);
    expect(find.byKey(const ValueKey('init_center_weak_hint')), findsOneWidget);
    expect(find.text('请设置头像'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byKey(const ValueKey('init_center_weak_hint')), findsNothing);
  });

  testWidgets('login page does not default to a real node', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('https://p2p-im.com'), findsNothing);
    expect(find.text('https://'), findsOneWidget);
  });

  testWidgets('login page warns about local Matrix API ports', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '127.0.0.1:28008');
    await tester.pump();

    expect(
      find.text('本地三节点测试请填写 host.docker.internal:28448'),
      findsOneWidget,
    );
  });

  testWidgets('login page leaves password empty after session expiration',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      AuthStateNotifier.lastLoginHomeserverKey: 'https://example.com',
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('old-password'), findsNothing);
    final editableTexts = tester.widgetList<EditableText>(
      find.byType(EditableText),
    );
    expect(editableTexts.last.controller.text, isEmpty);
  });

  testWidgets('login page follows app locale', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.light,
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('登录'), findsNothing);
  });
}

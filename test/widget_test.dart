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
import 'package:portal_app/data/chat_clear_state_store.dart';
import 'package:portal_app/data/conversation_preferences_store.dart';
import 'package:portal_app/data/friend_request_read_store.dart';
import 'package:portal_app/data/local_outbox_store.dart';
import 'package:portal_app/presentation/channel/create_channel_sheet.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/call/voice_call_controller.dart';
import 'package:portal_app/presentation/channel/channel_home_tab.dart';
import 'package:portal_app/presentation/channel/channel_inbox_data.dart';
import 'package:portal_app/presentation/pages/add_contact_detail_page.dart';
import 'package:portal_app/presentation/pages/add_contact_page.dart';
import 'package:portal_app/presentation/pages/add_contact_verification_page.dart';
import 'package:portal_app/presentation/pages/channel_page.dart';
import 'package:portal_app/presentation/pages/channel_post_detail_page.dart';
import 'package:portal_app/presentation/pages/channel_search_page.dart';
import 'package:portal_app/presentation/pages/chat_info_page.dart';
import 'package:portal_app/presentation/pages/chat_page.dart';
import 'package:portal_app/presentation/pages/contact_detail_page.dart';
import 'package:portal_app/presentation/pages/contact_home_page.dart';
import 'package:portal_app/presentation/pages/dynamic_detail_page.dart';
import 'package:portal_app/presentation/pages/follows_list_page.dart';
import 'package:portal_app/presentation/pages/login_page.dart';
import 'package:portal_app/presentation/mock/mock_data.dart';
import 'package:portal_app/presentation/pages/home_page.dart';
import 'package:portal_app/presentation/pages/group_chat_page.dart';
import 'package:portal_app/presentation/pages/group_detail_page.dart';
import 'package:portal_app/presentation/pages/group_info_page.dart';
import 'package:portal_app/presentation/pages/group_manage_page.dart';
import 'package:portal_app/presentation/pages/groups_list_page.dart';
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
import 'package:portal_app/presentation/providers/chat_clear_state_provider.dart';
import 'package:portal_app/presentation/providers/conversation_preferences_provider.dart';
import 'package:portal_app/presentation/providers/friend_request_read_provider.dart';
import 'package:portal_app/presentation/providers/local_outbox_provider.dart';
import 'package:portal_app/presentation/providers/profile_provider.dart';
import 'package:portal_app/presentation/providers/voice_call_provider.dart';
import 'package:portal_app/presentation/chat/cached_thumbnail_image.dart';
import 'package:portal_app/presentation/utils/group_creation_flow.dart';
import 'package:portal_app/presentation/utils/room_read_state.dart';
import 'package:portal_app/presentation/widgets/m3/glass_header.dart';
import 'package:portal_app/presentation/widgets/m3/m3_search_field.dart';
import 'package:portal_app/presentation/widgets/portal_avatar.dart';

final _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lGt2qQAAAABJRU5ErkJggg==',
);

class _FakeAuthStateNotifier extends AuthStateNotifier {
  @override
  Future<AuthState> build() async => const AuthState(isLoggedIn: false);
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
  Future<AsSyncUnread> syncUnread({int limitPerRoom = 200}) async =>
      AsSyncUnread(syncedAt: DateTime.now().toUtc(), rooms: const []);

  @override
  Future<AsSyncMessages> syncMessages({
    String roomId = '',
    int page = 1,
    int pageSize = 20,
    int fromTs = 0,
    int toTs = 0,
  }) async =>
      AsSyncMessages(
        syncedAt: DateTime.now().toUtc(),
        page: page,
        pageSize: pageSize,
        rooms: const [],
      );

  @override
  Future<List<AsSearchResult>> search(
    String query, {
    String? roomId,
    int limit = 20,
  }) async =>
      const [];

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
  }) async =>
      const [];

  @override
  Future<AsChannel> updateChannel(AsChannel draft) async => draft;

  @override
  Future<AsChannel> joinChannelByRoomId(
    String roomId, {
    String shareToken = '',
    AsChannel? discoveredChannel,
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
    String shareToken = '',
    AsChannel? discoveredChannel,
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
  Future<AsChannel> approveChannelJoin(
          String channelId, String userMxid) async =>
      AsChannel(
        channelId: channelId,
        roomId: '!$channelId:example.com',
        name: '频道',
        homeDomain: 'example.com',
        role: asChannelRoleOwner,
        memberStatus: asChannelMemberStatusJoined,
      );

  @override
  Future<AsChannel> rejectChannelJoin(
          String channelId, String userMxid) async =>
      AsChannel(
        channelId: channelId,
        roomId: '!$channelId:example.com',
        name: '频道',
        homeDomain: 'example.com',
        role: asChannelRoleOwner,
        memberStatus: asChannelMemberStatusJoined,
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
    String domain = '',
  }) async =>
      ContactEntry(
        peerMxid: mxid,
        displayName: displayName,
        domain: domain,
        roomId: '!contact:example.com',
        status: 'pending_outbound',
      );

  @override
  Future<ContactEntry> acceptContactRequest({
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
    String domain = '',
  }) async =>
      ContactEntry(
        peerMxid: '@contact:example.com',
        displayName: displayName.trim(),
        domain: domain.trim(),
        roomId: roomId,
        status: 'accepted',
      );

  @override
  Future<void> deleteRoomMessage({
    required String roomId,
    required String eventId,
  }) async {}

  @override
  Future<void> recallRoomMessage({
    required String roomId,
    required String eventId,
    String reason = '撤回消息',
  }) async {}

  @override
  Future<void> deleteRoomMessagesByRange({
    required String roomId,
    required int fromTs,
    required int toTs,
  }) async {}

  @override
  Future<String> sendRoomMessage(
    String roomId,
    String content, {
    String? replyToEventId,
    List<Map<String, String>> mentions = const [],
  }) async =>
      'event';

  @override
  Future<String> sendChatRecordMessage({
    required String roomId,
    required String body,
    required String title,
    required String sourceRoomId,
    required String sourceRoomType,
    required int itemCount,
    List<Map<String, Object?>> items = const [],
  }) async =>
      'chat-record-event';

  @override
  Future<String> sendChannelShareMessage({
    required String roomId,
    required String body,
    required AsChannelShareDraft channel,
  }) async =>
      'channel-share-event';

  @override
  Future<String> sendRoomMediaMessage({
    required String roomId,
    required String msgType,
    required String body,
    required String filename,
    required String mediaUrl,
    String mimeType = '',
    int size = 0,
    String thumbnailUrl = '',
    String thumbnailMimeType = '',
    int thumbnailSize = 0,
    int width = 0,
    int height = 0,
    int durationMs = 0,
  }) async =>
      'media-event';

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
  Future<void> updateReadMarker(
    String roomId,
    String eventId,
    DateTime timestamp,
  ) async {}

  @override
  Future<AgentConfig> updateAgentConfig(AgentConfig config) async => config;
}

class _SearchResultsAsClient extends _EmptyAsClient {
  _SearchResultsAsClient(this.results);

  final List<AsSearchResult> results;

  @override
  Future<List<AsSearchResult>> search(
    String query, {
    String? roomId,
    int limit = 20,
  }) async =>
      results;
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
    String domain = '',
  }) async {
    _accepted = true;
    return super.acceptContactRequest(
      roomId: roomId,
      peerMxid: peerMxid,
      displayName: displayName,
      domain: domain,
    );
  }
}

class _PeerDeletedAsClient extends _EmptyAsClient {
  @override
  Future<String> sendRoomMessage(
    String roomId,
    String content, {
    String? replyToEventId,
    List<Map<String, String>> mentions = const [],
  }) async {
    throw AsClientException('peer deleted contact', statusCode: 403);
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
  _FavoritesAsClient({this.videoThumbnail = true});

  static const generatedImageName =
      'image_picker_11111111-AAAA-BBBB-CCCC-generated-photo.jpg';
  static const generatedVideoName =
      'image_picker_22545629-08B6-4C45-B8ED-generated-video.mov';
  final bool videoThumbnail;
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
        url: 'mxc://p2p-im.com/image',
        filename: generatedImageName,
        mimeType: 'image/jpeg',
        size: 102400,
        thumbnailUrl: '',
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

class _TrackingAsClient extends _EmptyAsClient {
  int createContactRequestCalls = 0;
  String? createdContactMxid;
  String? createdContactDomain;
  int deleteContactCalls = 0;
  String? deletedContactRoomId;
  int updateContactCalls = 0;
  String? updatedContactRoomId;
  String? updatedContactDisplayName;
  String? updatedContactDomain;
  int deleteRoomMessageCalls = 0;
  String? deletedRoomMessageRoomId;
  String? deletedRoomMessageEventId;
  int recallRoomMessageCalls = 0;
  String? recalledRoomId;
  String? recalledEventId;
  String? recallRoomMessageReason;
  int deleteRoomMessagesByRangeCalls = 0;
  String? deletedRoomMessagesByRangeRoomId;
  int? deletedRoomMessagesByRangeFromTs;
  int? deletedRoomMessagesByRangeToTs;
  int sendRoomMessageCalls = 0;
  String? sentRoomId;
  String? sentContent;
  String? sentReplyToEventId;
  List<Map<String, String>> sentMentions = const [];
  int createGroupCalls = 0;
  String? createdGroupName;
  String? createdGroupAvatarUrl;
  List<String> createdGroupInvites = const [];
  int inviteGroupMembersCalls = 0;
  String? invitedGroupRoomId;
  List<String> invitedGroupMembers = const [];
  Object? inviteGroupMembersError;
  int syncBootstrapCalls = 0;
  AsSyncBootstrap? bootstrapAfterCreate;
  int leaveGroupCalls = 0;
  String? leftGroupRoomId;
  int removeGroupMemberCalls = 0;
  String? removedGroupRoomId;
  String? removedGroupPeerMxid;
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

  @override
  Future<ContactEntry> createContactRequest({
    required String mxid,
    String displayName = '',
    String domain = '',
  }) async {
    createContactRequestCalls++;
    createdContactMxid = mxid;
    createdContactDomain = domain;
    return ContactEntry(
      peerMxid: mxid,
      displayName: displayName,
      domain: domain,
      roomId: '!new-request:example.com',
      status: 'pending_outbound',
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
    String domain = '',
  }) async {
    updateContactCalls++;
    updatedContactRoomId = roomId;
    updatedContactDisplayName = displayName;
    updatedContactDomain = domain;
    return ContactEntry(
      peerMxid: '@alice:portal.local',
      displayName: displayName.trim(),
      domain: domain.trim(),
      roomId: roomId,
      status: 'accepted',
    );
  }

  @override
  Future<void> deleteRoomMessage({
    required String roomId,
    required String eventId,
  }) async {
    deleteRoomMessageCalls++;
    deletedRoomMessageRoomId = roomId;
    deletedRoomMessageEventId = eventId;
  }

  @override
  Future<void> recallRoomMessage({
    required String roomId,
    required String eventId,
    String reason = '撤回消息',
  }) async {
    recallRoomMessageCalls++;
    recalledRoomId = roomId;
    recalledEventId = eventId;
    recallRoomMessageReason = reason;
  }

  @override
  Future<void> deleteRoomMessagesByRange({
    required String roomId,
    required int fromTs,
    required int toTs,
  }) async {
    deleteRoomMessagesByRangeCalls++;
    deletedRoomMessagesByRangeRoomId = roomId;
    deletedRoomMessagesByRangeFromTs = fromTs;
    deletedRoomMessagesByRangeToTs = toTs;
  }

  @override
  Future<String> sendRoomMessage(
    String roomId,
    String content, {
    String? replyToEventId,
    List<Map<String, String>> mentions = const [],
  }) async {
    sendRoomMessageCalls++;
    sentRoomId = roomId;
    sentContent = content;
    sentReplyToEventId = replyToEventId;
    sentMentions = List.unmodifiable(mentions);
    return 'event';
  }

  @override
  Future<String> sendChatRecordMessage({
    required String roomId,
    required String body,
    required String title,
    required String sourceRoomId,
    required String sourceRoomType,
    required int itemCount,
    List<Map<String, Object?>> items = const [],
  }) async {
    sendRoomMessageCalls++;
    sentRoomId = roomId;
    sentContent = body;
    return 'chat-record-event';
  }

  @override
  Future<String> sendChannelShareMessage({
    required String roomId,
    required String body,
    required AsChannelShareDraft channel,
  }) async {
    sendRoomMessageCalls++;
    sentRoomId = roomId;
    sentContent = body;
    return 'channel-share-event';
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
    String domain = '',
  }) async {
    return ContactEntry(
      peerMxid: mxid,
      displayName: displayName,
      domain: domain,
      roomId: '!incoming:portal.local',
      status: 'pending_inbound',
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

class _CompletingBootstrapAsClient extends _EmptyAsClient {
  _CompletingBootstrapAsClient(this.bootstrapCompleter);

  final Completer<AsSyncBootstrap> bootstrapCompleter;

  @override
  Future<AsSyncBootstrap> syncBootstrap() => bootstrapCompleter.future;
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

class _RefreshingFriendRequestBootstrapAsClient extends _EmptyAsClient {
  int syncBootstrapCalls = 0;
  bool showPendingFriendRequest = false;

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
      pending: showPendingFriendRequest
          ? const AsSyncPending(
              friendRequests: [
                AsSyncPendingItem(
                  id: '!pending-live:p2p-im.com',
                  title: 'Alice',
                  createdAt: null,
                ),
              ],
              groupInvites: [],
              channelNotices: [],
            )
          : const AsSyncPending.empty(),
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
        content: {'membership': directPeerMembership.name},
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
}) {
  final room = Room(
    id: roomId,
    client: client,
    membership: Membership.join,
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
        'membership': peerMembership.name,
        'displayname': peerName,
        if (peerAvatarUrl.isNotEmpty) 'avatar_url': peerAvatarUrl,
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

class _GroupChatHarness {
  const _GroupChatHarness({
    required this.client,
    required this.asClient,
    required this.bootstrapStore,
  });

  final Client client;
  final _TrackingAsClient asClient;
  final _MemoryAsBootstrapStore bootstrapStore;
}

class _DirectChatHarness {
  const _DirectChatHarness({
    required this.client,
    required this.asClient,
  });

  final Client client;
  final _TrackingAsClient asClient;
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
  GoRouter? router,
}) async {
  final client = Client(
    'PortalIMGroupActionTest',
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
        asClientProvider.overrideWithValue(asClient),
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
}) async {
  final client = Client(
    'PortalIMDirectActionTest',
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
        home: ChatPage(roomId: roomId),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (!sendPeerEvent) {
    return _DirectChatHarness(client: client, asClient: asClient);
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
  return _DirectChatHarness(client: client, asClient: asClient);
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
    final client = Client('PortalIMTest');
    final room = Room(
      id: '!agent:example.com',
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

  testWidgets('messages home header does not duplicate the me avatar shortcut',
      (tester) async {
    final client = Client('PortalIMTest');

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
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PortalAvatar &&
            widget.size == 32 &&
            widget.imageUrl == MockAvatars.me,
      ),
      findsNothing,
    );
  });

  testWidgets(
      'messages list does not flash mock conversations while auth loads',
      (tester) async {
    final client = Client('PortalIMTest');

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
    await tester.pump();

    expect(find.text('Agent'), findsNothing);
    expect(find.text('正在同步消息'), findsOneWidget);
  });

  testWidgets('messages wait for AS metadata before rendering undirected rooms',
      (tester) async {
    final client = Client('PortalIMUndirectedRoomMetadataTest')
      ..setUserId('@owner:p2p-im.com');
    final room = _addUndirectedJoinedRoom(
      client,
      roomId: '!owner:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'owner',
    );
    room.setState(
      StrippedStateEvent(
        type: 'p2p.room.kind',
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: {'kind': 'direct'},
      ),
    );
    final bootstrapCompleter = Completer<AsSyncBootstrap>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_MemberLoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          asClientProvider.overrideWithValue(
            _CompletingBootstrapAsClient(bootstrapCompleter),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Group with'), findsNothing);
    expect(find.text('正在同步联系人信息'), findsOneWidget);

    bootstrapCompleter.complete(
      AsSyncBootstrap(
        syncedAt: DateTime.utc(2026, 5, 26, 10),
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
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('owner'), findsOneWidget);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets('messages conversation avatar prefers fresh Matrix member avatar',
      (tester) async {
    final client = Client('PortalIMConversationAsAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!owner:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
      peerAvatarUrl: 'https://matrix.example.com/yanan.png',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 3, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'Yanan',
          avatarUrl: 'https://as-cache.example.com/yanan.png',
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
              .overrideWith(_MemberLoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider
              .overrideWithValue(_StaticBootstrapAsClient(bootstrap)),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
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
            widget.imageUrl == 'https://matrix.example.com/yanan.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('messages update contact avatar after Matrix member sync',
      (tester) async {
    final client = Client('PortalIMConversationAvatarSyncTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!owner:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
      peerAvatarUrl: 'https://matrix.example.com/old.png',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 3, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'Yanan',
          avatarUrl: 'https://as-cache.example.com/yanan.png',
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
              .overrideWith(_MemberLoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider
              .overrideWithValue(_StaticBootstrapAsClient(bootstrap)),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
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
            widget.imageUrl == 'https://matrix.example.com/old.png',
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
            widget.imageUrl == 'https://matrix.example.com/new.png',
      ),
      findsOneWidget,
    );
    expect(find.text('Yanan 新昵称'), findsAtLeastNWidgets(1));
  });

  testWidgets('messages contact conversation does not show online dot',
      (tester) async {
    final client = Client('PortalIMConversationNoContactOnlineDotTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!owner:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
      peerAvatarUrl: 'https://matrix.example.com/yanan.png',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 3, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'Yanan',
          avatarUrl: 'https://as-cache.example.com/yanan.png',
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

    expect(find.text('Yanan'), findsOneWidget);
    expect(find.byType(OnlineDot), findsNothing);
  });

  testWidgets('messages preview hides last event after room chat clear',
      (tester) async {
    const roomId = '!owner:p2p-im.com';
    const peerMxid = '@owner:p2p-liyanan.com';
    final client = Client('PortalIMConversationClearPreviewTest')
      ..setUserId('@owner:p2p-im.com');
    final room = _addUndirectedJoinedRoom(
      client,
      roomId: roomId,
      peerMxid: peerMxid,
      peerName: 'Yanan',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 3, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: peerMxid,
          displayName: 'Yanan',
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
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(
              bootstrap: bootstrap,
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

  testWidgets('messages conversation avatar falls back to Matrix peer avatar',
      (tester) async {
    final client = Client('PortalIMConversationMatrixAvatarTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!owner:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
      peerAvatarUrl: 'https://matrix.example.com/yanan.png',
    );
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 3, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'Yanan',
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
    final client = Client('PortalIMPendingOutboundHomeListTest')
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
    final client = Client('PortalIMPendingJoinedHomeListTest')
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
    final client = Client('PortalIMMatrixSyncRefreshesAsMetadataTest')
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

  testWidgets('messages render AS accepted contact before Matrix room hydrates',
      (tester) async {
    final client = Client('PortalIMAsAcceptedContactOnlyHomeListTest')
      ..setUserId('@owner:p2p-im.com');
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
      contacts: const [
        AsSyncContact(
          userId: '@owner:p2p-liyanan.com',
          displayName: 'Yanan',
          avatarUrl: '',
          roomId: '!current:p2p-im.com',
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

    expect(find.text('Yanan'), findsWidgets);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('还没有会话'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets('messages render AS joined group before Matrix room hydrates',
      (tester) async {
    final client = Client('PortalIMAsJoinedGroupOnlyHomeListTest')
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

    expect(find.text('产品测试群'), findsOneWidget);
    expect(find.text('群聊已创建，等待同步'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('还没有会话'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets(
      'contacts hide pending metadata until AS marks the contact accepted',
      (tester) async {
    final client = Client('PortalIMPendingContactListTest')
      ..setUserId('@owner:p2p-im.com');
    final room = _addUndirectedJoinedRoom(
      client,
      roomId: '!pending:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'owner',
      peerMembership: Membership.join,
    );
    room.setState(
      StrippedStateEvent(
        type: 'p2p.room.kind',
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: {'kind': 'direct'},
      ),
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
    await tester.pump();

    expect(find.text('Alice'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets('messages hide unknown raw Matrix rooms after AS bootstrap',
      (tester) async {
    final client = Client('PortalIMUnknownRawRoomHomeListTest')
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
    final client = Client('PortalIMCanonicalAgentHomeListTest')
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

  testWidgets('messages hide duplicate Matrix direct rooms not accepted by AS',
      (tester) async {
    final client = Client('PortalIMDuplicateDirectRoomHomeListTest')
      ..setUserId('@owner:p2p-im.com');
    final canonicalRoom = _addUndirectedJoinedRoom(
      client,
      roomId: '!canonical:p2p-liyanan.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
    );
    canonicalRoom.setState(
      StrippedStateEvent(
        type: 'p2p.room.kind',
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: {'kind': 'direct'},
      ),
    );
    final duplicateRoom = _addUndirectedJoinedRoom(
      client,
      roomId: '!duplicate:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'default owner',
    );
    duplicateRoom.setState(
      StrippedStateEvent(
        type: 'p2p.room.kind',
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: {'kind': 'direct'},
      ),
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

    expect(find.text('Yanan'), findsWidgets);
    expect(find.text('duplicate accepted notice'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets(
      'messages prefer new local accepted room over stale bootstrap room',
      (tester) async {
    final client = Client('PortalIMLocalAcceptedShadowsBootstrapHomeTest')
      ..setUserId('@owner:p2p-im.com');
    final oldRoom = _addUndirectedJoinedRoom(
      client,
      roomId: '!old:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
    );
    oldRoom.setState(
      StrippedStateEvent(
        type: 'p2p.room.kind',
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: {'kind': 'direct'},
      ),
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
    newRoom.setState(
      StrippedStateEvent(
        type: 'p2p.room.kind',
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: {'kind': 'direct'},
      ),
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {}),
          asClientProvider.overrideWithValue(_EmptyAsClient()),
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
    final client = Client('PortalIMDuplicateDirectContactListTest')
      ..setUserId('@owner:p2p-im.com');
    final canonicalRoom = _addUndirectedJoinedRoom(
      client,
      roomId: '!canonical:p2p-liyanan.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
    );
    canonicalRoom.setState(
      StrippedStateEvent(
        type: 'p2p.room.kind',
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: {'kind': 'direct'},
      ),
    );
    final duplicateRoom = _addUndirectedJoinedRoom(
      client,
      roomId: '!duplicate:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'default owner',
    );
    duplicateRoom.setState(
      StrippedStateEvent(
        type: 'p2p.room.kind',
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: {'kind': 'direct'},
      ),
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
    await tester.pump();

    expect(find.text('ID/昵称/邮箱'), findsOneWidget);
    expect(find.text('A'), findsWidgets);
    expect(find.text('Yanan'), findsOneWidget);
    expect(find.text('default owner'), findsNothing);
  });

  testWidgets(
      'messages and contacts hide rejected direct rooms with joined peer',
      (tester) async {
    final client = Client('PortalIMRejectedDirectRoomListTest')
      ..setUserId('@owner:p2p-im.com');
    final rejectedRoom = _addUndirectedJoinedRoom(
      client,
      roomId: '!rejected:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'Yanan',
    );
    rejectedRoom.setState(
      StrippedStateEvent(
        type: 'p2p.room.kind',
        senderId: '@owner:p2p-im.com',
        stateKey: '',
        content: {'kind': 'direct'},
      ),
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
    expect(find.text('还没有联系人'), findsOneWidget);
    expect(find.text('Yanan'), findsNothing);
  });

  testWidgets('chat info uses AS contact metadata for undirected direct rooms',
      (tester) async {
    final client = Client('PortalIMChatInfoDirectMetadataTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!owner:p2p-im.com',
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
          currentUserProfileProvider.overrideWith((ref) async => null),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatInfoPage(roomId: '!owner:p2p-im.com'),
        ),
      ),
    );

    expect(find.text('owner'), findsOneWidget);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets('chat info clear room history writes room clear boundary',
      (tester) async {
    const roomId = '!owner:p2p-im.com';
    final client = Client('PortalIMChatInfoClearHistoryTest')
      ..setUserId('@owner:p2p-im.com');
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
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

    expect(clearStore.roomClearedBeforeTs[roomId], greaterThan(0));
    expect(asClient.deleteRoomMessagesByRangeCalls, 1);
    expect(asClient.deletedRoomMessagesByRangeRoomId, roomId);
    expect(asClient.deletedRoomMessagesByRangeFromTs, 0);
    expect(
      asClient.deletedRoomMessagesByRangeToTs,
      clearStore.roomClearedBeforeTs[roomId],
    );
  });

  testWidgets('home starts app warmup on launch', (tester) async {
    const mockAuthEnabled = bool.fromEnvironment(
      'P2P_MATRIX_MOCK_AUTH',
      defaultValue: false,
    );
    final client = Client('PortalIMTest');
    var warmupCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
          appWarmupProvider.overrideWith((ref) async {
            warmupCalls++;
          }),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    expect(warmupCalls, mockAuthEnabled ? 0 : 1);
  });

  test('app warmup preloads current user and recent room avatars', () async {
    final client = Client('PortalIMTest')
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
    final client = Client('PortalIMTest');

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

    for (final title in ['消息', '联系人']) {
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
    final client = Client('PortalIMTest');

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
    final client = Client('PortalIMChannelTabTest');

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
    expect(find.text('#综合讨论'), findsOneWidget);
    expect(find.text('#新手问答'), findsOneWidget);
    expect(find.text('草稿箱'), findsNothing);
    expect(find.byIcon(Symbols.search), findsOneWidget);
    expect(find.byKey(const ValueKey('channel_post_button')), findsOneWidget);
  });

  testWidgets('channel tab matches figma header controls', (tester) async {
    final client = Client('PortalIMChannelHeaderTest');

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
    final client = Client('PortalIMMeChannelsTest')
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
    final client = Client('PortalIMChannelSearchTest');

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

  testWidgets('channel search routes Matrix room id lookup to owner node',
      (tester) async {
    final client = Client('PortalIMChannelSearchRoomIdTargetTest');
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

    expect(asClient.lastPublicChannelLookupBaseUri, isNotNull);
    expect(asClient.lastPublicChannelLookupBaseUri!.scheme, 'https');
    expect(asClient.lastPublicChannelLookupBaseUri!.host, 'node.example.com');
    expect(asClient.lastPublicChannelLookupBaseUri!.path, '/_p2p');
  });

  testWidgets('channel search uses unified AS public search for keywords',
      (tester) async {
    final client = Client('PortalIMChannelSearchUnifiedTest');
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

    await tester.enterText(find.byType(M3SearchField), 'garden');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(asClient.lastPublicChannelSearchQuery, 'garden');
    expect(find.text('garden'), findsWidgets);
    expect(find.text('example.com'), findsOneWidget);
  });

  testWidgets('create channel entry opens figma form', (tester) async {
    final client = Client('PortalIMCreateChannelTest');

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

  testWidgets('create channel empty name stays on form with prompt',
      (tester) async {
    final client = Client('PortalIMCreateChannelEmptyNameTest');

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
    final client = Client('PortalIMChannelReviewTest');
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
    await tester.tap(find.byKey(const ValueKey('channel_review_button')));
    await tester.pumpAndSettle();

    expect(find.text('频道审核'), findsOneWidget);
    expect(find.text('待审核'), findsOneWidget);
    expect(find.text('已通过'), findsOneWidget);
    expect(find.text('已拒绝'), findsOneWidget);
    expect(find.text('通过'), findsOneWidget);
    expect(find.text('拒绝'), findsOneWidget);
  });

  testWidgets('home plus menu has the unified action order', (tester) async {
    final client = Client('PortalIMTest');

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
    final client = Client('PortalIMHomePlusDarkTest');

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
    final asClient = _TrackingAsClient();
    final client = Client('PortalIMHomeGroupCreateTest')
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
              'group:${state.pathParameters['roomId']!}',
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
    expect(find.text('group:!new-group:p2p-im.com'), findsOneWidget);
  });

  testWidgets('missing group page keeps a usable back button', (tester) async {
    final client = Client('PortalIMMissingGroupBackTest')
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

    expect(find.text('群组不存在'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.text('HomeRoot'), findsOneWidget);
  });

  testWidgets('mock contacts show exactly three friends', (tester) async {
    final client = Client('PortalIMTest');

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
    expect(find.text('A'), findsWidgets);
    expect(find.text('B'), findsWidgets);
    expect(find.text('D'), findsWidgets);
    expect(find.text('Alice Chen'), findsOneWidget);
    expect(find.text('Bob Smith'), findsOneWidget);
    expect(find.text('Dave Lee'), findsOneWidget);
    expect(find.text('Eve Wang'), findsNothing);
    expect(find.text('Jack'), findsNothing);
  });

  testWidgets('contacts use Matrix member avatar when AS avatar is empty',
      (tester) async {
    final client = Client('PortalIMContactsMatrixAvatarTest')
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

  testWidgets('contact action shortcuts match contact design', (tester) async {
    final client = Client('PortalIMTest');

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
    final client = Client('PortalIMTest');

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
    final client = Client('PortalIMInviteBadgeTest')
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
    expect(
      find.descendant(of: contactSectionBadge, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: contactSectionBadge, matching: find.text('2')),
      findsNothing,
    );
    expect(
      find.descendant(of: contactSectionBadge, matching: find.text('3')),
      findsNothing,
    );
  });

  testWidgets('new friend badge counts AS pending friend request notices',
      (tester) async {
    final client = Client('PortalIMPendingFriendNoticeBadgeTest')
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

  testWidgets('new friend badge refreshes AS pending notices after Matrix sync',
      (tester) async {
    final client = Client('PortalIMPendingFriendNoticeSyncTest')
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
    final client = Client('PortalIMPendingFriendNoticeLiveRefreshTest')
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

  testWidgets('new friend badge counts Matrix invites after AS bootstrap',
      (tester) async {
    final client = Client('PortalIMInviteBadgeBootstrapTest')
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
    final client = Client('PortalIMHomeGroupUnreadBadgeTest')
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

    expect(find.text('Chats(9)'), findsOneWidget);
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

  testWidgets('viewing new friends clears unread badges but keeps request',
      (tester) async {
    final client = Client('PortalIMFriendRequestReadBadgeTest')
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
    final client = Client('PortalIMRequestsFilterTest')
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

  testWidgets('new friends page refreshes AS pending notices after Matrix sync',
      (tester) async {
    final client = Client('PortalIMRequestsLivePendingTest')
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

  testWidgets('new friends page still lists Matrix invites after AS bootstrap',
      (tester) async {
    final client = Client('PortalIMRequestsBootstrapInviteTest')
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
          asClientProvider.overrideWithValue(_EmptyAsClient()),
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
    final client = Client('PortalIMOutgoingPendingMetadataTest')
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

  testWidgets('new friends search matches add friend Figma list style',
      (tester) async {
    final client = Client('PortalIMRequestsSearchStyleTest')
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
    final client = Client('PortalIMOutgoingRejectedBootstrapTest')
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
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RequestsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('已拒绝'), findsOneWidget);
    expect(find.text('对方已拒绝'), findsOneWidget);
    expect(find.text('owner'), findsOneWidget);
    expect(find.text('等待接受'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets('new friends keeps outgoing requests visible after peer rejects',
      (tester) async {
    final client = Client('PortalIMOutgoingRejectedMetadataTest')
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
    expect(find.text('已拒绝'), findsOneWidget);
    expect(find.text('对方已拒绝'), findsOneWidget);
    expect(find.text('等待接受'), findsNothing);
    expect(find.textContaining('Group with'), findsNothing);
  });

  testWidgets('new friends hides stale outgoing invite omitted by AS bootstrap',
      (tester) async {
    final client = Client('PortalIMStaleOutgoingInviteTest')
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
    final client = Client('PortalIMReaddAfterRejectedTest')
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
      'PortalIMRequestsUnknownDomainTest',
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
    final client = Client('PortalIMRequestsActionsTest')
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

  testWidgets('accepting friend request updates local accepted room cache',
      (tester) async {
    final client = Client('PortalIMRequestsAcceptCacheTest')
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
    final client = Client('PortalIMTest');
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

  testWidgets('follows list renders contact avatars', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
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
            widget.seed == '@alice:portal.local' &&
            widget.imageUrl == MockAvatars.alice,
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Symbols.person_check), findsNothing);
  });

  testWidgets('tapping a followed user opens visitor home', (tester) async {
    final router = GoRouter(
      initialLocation: '/follows',
      routes: [
        GoRoute(path: '/follows', builder: (_, __) => const FollowsListPage()),
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
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
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

    expect(find.text('主页'), findsOneWidget);
    expect(find.text('alice.portal.local'), findsOneWidget);
    expect(find.text('她的动态'), findsOneWidget);
  });

  testWidgets('add contact searches portal url and opens detail',
      (tester) async {
    final client = Client(
      'PortalIMAddContactTest',
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
    await tester.enterText(find.byType(TextField), 'Alice');
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

    expect(find.text('申请好友'), findsOneWidget);
    expect(find.text('发消息'), findsOneWidget);
    expect(find.text('音频通话'), findsOneWidget);
    expect(find.text('视频通话'), findsOneWidget);
    expect(find.text('消息免打扰'), findsOneWidget);
    expect(find.text('屏蔽用户'), findsOneWidget);
    expect(find.text('举报用户'), findsOneWidget);
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

  testWidgets('add contact detail opens chat for accepted contact',
      (tester) async {
    const roomId = '!alice-chat:p2p-im.com';
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
            'chat:${state.pathParameters['roomId']}',
            textDirection: TextDirection.ltr,
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

    expect(find.text('申请好友'), findsNothing);
    expect(find.text('发消息'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, '发消息'));
    await tester.pumpAndSettle();

    expect(find.text('chat:$roomId'), findsOneWidget);
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

    expect(find.text('申请好友'), findsOneWidget);
    await tester.tap(find.text('发消息'));
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

  testWidgets('add contact rejects domains without portal owner discovery',
      (tester) async {
    final asClient = _TrackingAsClient();
    final client = Client(
      'PortalIMAddContactUnknownDomainTest',
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
    expect(find.text('好友请求已发送，等待对方接受。'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('上一页'), findsOneWidget);
    expect(find.text('好友验证'), findsNothing);
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
      'PortalIMAddContactInboundRequestTest',
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
    await tester.tap(find.text('申请好友'));
    await tester.pumpAndSettle();
    expect(find.text('好友验证'), findsOneWidget);
    expect(find.text('发送好友申请'), findsOneWidget);
    await tester.tap(find.text('发送申请'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('好友请求已发送，等待对方接受。'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('好友验证'), findsNothing);
    expect(find.text('申请好友'), findsOneWidget);

    await client.dispose(closeDatabase: false);
  });

  testWidgets('mock groups show three groups with one owner badge',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const GroupsListPage()),
      ),
    );
    await tester.pump();

    expect(find.text('P2P IM 核心群'), findsOneWidget);
    expect(find.text('产品设计组'), findsOneWidget);
    expect(find.text('Agent 创作小组'), findsOneWidget);
    expect(find.text('群主'), findsOneWidget);
  });

  testWidgets('groups list excludes AS accepted undirected direct contacts',
      (tester) async {
    final client = Client('PortalIMGroupsExcludeDirectMetadataTest')
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

  testWidgets('groups list only shows AS joined groups', (tester) async {
    final client = Client('PortalIMGroupsExcludeStaleDirectRoomsTest')
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

  testWidgets('groups list labels image previews instead of filenames',
      (tester) async {
    const imageName =
        'image_picker_11111111-AAAA-BBBB-CCCC-generated-photo.jpg';
    final client = Client('PortalIMGroupListImagePreviewTest')
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
    final client = Client(
      'PortalIMGroupCreateInviteTest',
      httpClient: MockClient((request) async {
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..setUserId('@owner:p2p-im.com');
    client.homeserver = Uri.parse('https://p2p-im.com');
    client.accessToken = 'test-token';
    final asClient = _TrackingAsClient();

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
          userId: '@bob:p2p-liyanan.com',
          displayName: 'Bob Lin',
          avatarUrl: 'https://example.com/bob.png',
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

    await tester.tap(find.text('完成创建'));
    await tester.pumpAndSettle();

    expect(asClient.createdGroupName, 'Alice Chen、Bob Lin的群聊');
    expect(
      asClient.createdGroupInvites,
      ['@alice:p2p-liyanan.com', '@bob:p2p-liyanan.com'],
    );
    expect(asClient.syncBootstrapCalls, 1);
    final createdRoom = client.getRoomById('!new-group:p2p-im.com');
    expect(createdRoom, isNotNull);
    expect(createdRoom!.avatar?.toString(), 'mxc://p2p-im.com/owner-avatar');
  });

  testWidgets('messages hide Matrix group invite room before AS join',
      (tester) async {
    final client = Client('PortalIMGroupInviteRoomHiddenHomeListTest')
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
    final client = Client('PortalIMGroupDetailMemberTest')
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

  testWidgets('group detail keeps management visible for group owner',
      (tester) async {
    final client = Client('PortalIMGroupDetailOwnerTest')
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

  testWidgets('group detail leaves through AS and refreshes bootstrap',
      (tester) async {
    final client = Client('PortalIMGroupDetailLeaveAsTest')
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

    await tester.ensureVisible(find.text('退出群聊'));
    await tester.tap(find.text('退出群聊'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出').last);
    await tester.pumpAndSettle();

    expect(asClient.leaveGroupCalls, 1);
    expect(asClient.leftGroupRoomId, '!group:p2p-im.com');
    expect(find.text('HomeRoot'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
    );
    expect(container.read(asSyncCacheProvider).bootstrap?.groups, isEmpty);
    expect(bootstrapStore.value?.groups, isEmpty);
  });

  testWidgets('group detail invites accepted non-members through AS',
      (tester) async {
    final client = Client('PortalIMGroupDetailInviteAsTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-liyanan.com': 'Alice'},
    );
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
    expect(find.text('已发送 1 个群邀请'), findsOneWidget);
  });

  testWidgets('group info invite button posts member invites through AS',
      (tester) async {
    final client = Client('PortalIMGroupInfoInviteAsTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-liyanan.com': 'Alice'},
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

    await tester.tap(find.text('邀请'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carol'));
    await tester.pump();
    await tester.tap(find.text('发送邀请'));
    await tester.pumpAndSettle();

    expect(asClient.inviteGroupMembersCalls, 1);
    expect(asClient.invitedGroupRoomId, '!group:p2p-im.com');
    expect(asClient.invitedGroupMembers, ['@carol:p2p-carol.com']);
  });

  testWidgets('group info shows management only to group owner',
      (tester) async {
    final memberClient = Client('PortalIMGroupInfoMemberManageTest')
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

    final ownerClient = Client('PortalIMGroupInfoOwnerManageTest')
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

  testWidgets('group owner can remove member from group info', (tester) async {
    final client = Client('PortalIMGroupInfoRemoveMemberTest')
      ..setUserId('@owner:p2p-im.com');
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    final asClient = _TrackingAsClient();

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
  });

  testWidgets(
      'group info edits remark, pins, nickname, and clears room history',
      (tester) async {
    final nicknameRequests = <http.Request>[];
    final client = Client(
      'PortalIMGroupInfoSettingsTest',
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
    _addNamedGroupRoom(
      client,
      roomId: '!group:p2p-im.com',
      name: '真实群',
      creatorMxid: '@owner:p2p-im.com',
      members: const {'@owner:p2p-im.com': 'Owner'},
    );
    final clearStore = _MemoryChatClearStateStore();
    final asClient = _TrackingAsClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(asClient),
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
    expect(asClient.deleteRoomMessagesByRangeCalls, 1);
    expect(asClient.deletedRoomMessagesByRangeRoomId, '!group:p2p-im.com');
    expect(asClient.deletedRoomMessagesByRangeFromTs, 0);
    expect(
      asClient.deletedRoomMessagesByRangeToTs,
      clearStore.roomClearedBeforeTs['!group:p2p-im.com'],
    );
    expect(
      container
          .read(asSyncCacheProvider)
          .localRoomClearedBeforeTs['!group:p2p-im.com'],
      greaterThan(0),
    );
  });

  testWidgets('group detail shows owner-admin invite permission failure',
      (tester) async {
    final client = Client('PortalIMGroupInvitePermissionFailureTest')
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
          invitePolicy: groupInvitePolicyOwnerAdmin,
        ),
      ],
      channels: const [],
      pending: const AsSyncPending.empty(),
    );
    final asClient = _TrackingAsClient()
      ..inviteGroupMembersError = AsClientException(
        'group invite requires owner or admin',
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
    expect(find.text('该群只有群主/管理员可添加成员'), findsOneWidget);
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

  testWidgets('group management edits group name through AS', (tester) async {
    final asClient = _TrackingAsClient();
    final client = Client('PortalIMGroupManageRenameTest')
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
    expect(find.text('群主/管理员可添加'), findsOneWidget);

    await tester.tap(find.text('群主/管理员可添加'));
    await tester.pumpAndSettle();

    expect(asClient.updateGroupInvitePolicyCalls, 1);
    expect(asClient.updatedGroupInvitePolicyRoomId, '!group:p2p-im.com');
    expect(asClient.updatedGroupInvitePolicy, 'owner_admin');
    expect(find.text('已更新添加成员权限'), findsOneWidget);
  });

  testWidgets('group chat text send uses AS room send endpoint',
      (tester) async {
    final client = Client(
      'PortalIMGroupTextSendAsTest',
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

    await tester.enterText(find.byType(TextField), '群聊走 AS');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pump(const Duration(seconds: 3));

    expect(asClient.sendRoomMessageCalls, 1);
    expect(asClient.sentRoomId, '!group:p2p-im.com');
    expect(asClient.sentContent, '群聊走 AS');
  });

  testWidgets('channel conversation text input is enabled for joined channel',
      (tester) async {
    final client = Client(
      'PortalIMChannelTextSendAsTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
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

    expect(asClient.sendRoomMessageCalls, 0);
  });

  testWidgets('muted channel text send creates failed local message',
      (tester) async {
    final client = Client(
      'PortalIMMutedChannelTextSendTest',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/send/m.room.message/')) {
          return http.Response(
            '{"errcode":"M_FORBIDDEN","error":"频道已全员禁言"}',
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
    client.accessToken = 'test-token';
    final room = _addNamedGroupRoom(
      client,
      roomId: '!muted-channel:p2p-im.com',
      name: '禁言频道',
      creatorMxid: '@admin:p2p-im.com',
      members: const {'@alice:p2p-im.com': 'Alice'},
    );
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomPowerLevels,
        senderId: '@admin:p2p-im.com',
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

    expect(find.text('禁言消息'), findsOneWidget);
    expect(outboxStore.items, hasLength(1));
    expect(outboxStore.items.single.status, LocalOutboxItemStatus.failed);
  });

  testWidgets('channel conversation title prefers channel name over room id',
      (tester) async {
    final client = Client(
      'PortalIMChannelTitleTest',
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
      'PortalIMChannelGroupRouteTitleTest',
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
      'PortalIMChannelIdTitleTest',
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

  testWidgets('channel conversation header hides member count', (tester) async {
    final client = Client(
      'PortalIMChannelMemberCountHeaderTest',
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
    expect(find.text('18 名成员'), findsNothing);
  });

  testWidgets('channel conversation skips call API and limits attachment tools',
      (tester) async {
    final client = Client(
      'PortalIMChannelAttachmentToolsTest',
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
    final client = Client(
      'PortalIMGroupMentionSendTest',
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

    expect(asClient.sendRoomMessageCalls, 1);
    expect(asClient.sentContent, '@Alice hello');
    expect(asClient.sentMentions, [
      {
        'user_id': '@alice:p2p-im.com',
        'display_name': 'Alice',
      },
    ]);
  });

  testWidgets('channel chat @ mention picker excludes portal agent',
      (tester) async {
    final client = Client(
      'PortalIMChannelMentionAgentFilterTest',
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
    final client = Client('PortalIMGroupChatMissingRoomRecoveryTest')
      ..setUserId('@owner:p2p-im.com');
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
          home: const GroupChatPage(roomId: '!group:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('真实群'), findsOneWidget);
    expect(find.text('正在恢复群聊...'), findsOneWidget);
    expect(find.text('这个群聊暂时无法打开'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('group chat header opens active group call from title capsule',
      (tester) async {
    const roomId = '!group:p2p-im.com';
    final client = Client(
      'PortalIMGroupActiveCallHeaderTest',
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
      'PortalIMGroupMediaOutboxTest',
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
      'PortalIMGroupReceivedImageTest',
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
      'PortalIMGroupReceivedFileTest',
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
      'PortalIMGroupReceivedVideoTest',
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

  testWidgets('group chat recalls own message through AS', (tester) async {
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

    expect(harness.asClient.recallRoomMessageCalls, 1);
    expect(harness.asClient.recalledRoomId, '!group:p2p-im.com');
    expect(harness.asClient.recalledEventId, r'$group-own-text');
    expect(harness.asClient.recallRoomMessageReason, '撤回消息');
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

  testWidgets('group chat member avatar opens visitor home', (tester) async {
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
          path: '/contact-home/:userId',
          builder: (_, state) => Scaffold(
            body: Text(
              'contact-home:${state.pathParameters['userId']}',
            ),
          ),
        ),
      ],
    );

    await _pumpGroupChatWithTextEvent(tester, roomId: roomId, router: router);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('group_member_avatar_@alice:p2p-im.com')),
    );
    await tester.pumpAndSettle();

    expect(find.text('contact-home:@alice:p2p-im.com'), findsOneWidget);
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
    final harness = await _pumpGroupChatWithTextEvent(tester);

    await tester.longPress(find.text('群聊长按消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('引用'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Symbols.reply), findsOneWidget);
    expect(find.text('Alice'), findsWidgets);

    await tester.enterText(find.byType(TextField), '引用后的回复');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(harness.asClient.sentRoomId, '!group:p2p-im.com');
    expect(harness.asClient.sentContent, '引用后的回复');
    expect(harness.asClient.sentReplyToEventId, r'$group-text');
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
                    eventId: 'event',
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

  testWidgets('group chat delete hides message through AS', (tester) async {
    final harness = await _pumpGroupChatWithTextEvent(tester);

    await tester.longPress(find.text('群聊长按消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(harness.asClient.deleteRoomMessageCalls, 1);
    expect(harness.asClient.deletedRoomMessageRoomId, '!group:p2p-im.com');
    expect(harness.asClient.deletedRoomMessageEventId, r'$group-text');
    expect(find.text('群聊长按消息'), findsNothing);
  });

  testWidgets('mock auth build ignores cached login for contacts',
      (tester) async {
    const mockAuthEnabled = bool.fromEnvironment(
      'P2P_MATRIX_MOCK_AUTH',
      defaultValue: false,
    );
    if (!mockAuthEnabled) return;

    final client = Client('PortalIMTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('通讯录').last);
    await tester.pump();

    expect(find.text('ID/昵称/邮箱'), findsOneWidget);
    expect(find.text('Alice Chen'), findsOneWidget);
  });

  testWidgets('mock auth build shows mock conversations despite cached login',
      (tester) async {
    const mockAuthEnabled = bool.fromEnvironment(
      'P2P_MATRIX_MOCK_AUTH',
      defaultValue: false,
    );
    if (!mockAuthEnabled) return;

    final client = Client('PortalIMTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dave Lee'), findsOneWidget);
    expect(find.text('Agent'), findsOneWidget);
  });

  testWidgets('home conversation long press delete hides row', (tester) async {
    const mockAuthEnabled = bool.fromEnvironment(
      'P2P_MATRIX_MOCK_AUTH',
      defaultValue: false,
    );
    if (!mockAuthEnabled) return;

    final client = Client('PortalIMHomeDeleteConversationTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dave Lee'), findsOneWidget);

    await tester.longPress(find.text('Dave Lee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除聊天'));
    await tester.pumpAndSettle();

    expect(find.text('Dave Lee'), findsNothing);
    expect(find.textContaining('已删除'), findsOneWidget);
  });

  testWidgets('home conversation delete clears AS room history after confirm',
      (tester) async {
    final client = Client('PortalIMHomeDeleteConversationAsTest')
      ..setUserId('@owner:p2p-im.com')
      ..homeserver = Uri.parse('https://p2p-im.com')
      ..accessToken = 'matrix-token';
    final asClient = _TrackingAsClient();
    final clearStore = _MemoryChatClearStateStore();
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

    expect(asClient.deleteRoomMessagesByRangeCalls, 1);
    expect(asClient.deletedRoomMessagesByRangeRoomId, roomId);
    expect(asClient.deletedRoomMessagesByRangeFromTs, 0);
    expect(
      asClient.deletedRoomMessagesByRangeToTs,
      clearStore.roomClearedBeforeTs[roomId],
    );
    expect(find.textContaining('删除聊天记录失败'), findsNothing);
    expect(find.textContaining('已删除'), findsOneWidget);
    expect(find.byKey(conversationKey), findsNothing);
  });

  testWidgets('mock auth build opens mock chat despite cached login',
      (tester) async {
    const mockAuthEnabled = bool.fromEnvironment(
      'P2P_MATRIX_MOCK_AUTH',
      defaultValue: false,
    );
    if (!mockAuthEnabled) return;

    final router = GoRouter(
      initialLocation: '/chat/mock_dave',
      routes: [
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, state) =>
              ChatPage(roomId: state.pathParameters['roomId']!),
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
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Dave Lee'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('chat_peer_avatar_mock_dave_1')));
    await tester.pumpAndSettle();

    expect(find.text('发消息'), findsOneWidget);
    expect(find.text('语音通话'), findsOneWidget);
    expect(find.text('删除好友'), findsOneWidget);
  });

  testWidgets('mock auth chat stays local', (tester) async {
    const mockAuthEnabled = bool.fromEnvironment(
      'P2P_MATRIX_MOCK_AUTH',
      defaultValue: false,
    );
    if (!mockAuthEnabled) return;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: 'mock_dave'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Dave Lee'), findsOneWidget);
  });

  testWidgets('mock direct chat multi-select checkbox toggles selection',
      (tester) async {
    const mockAuthEnabled = bool.fromEnvironment(
      'P2P_MATRIX_MOCK_AUTH',
      defaultValue: false,
    );
    if (!mockAuthEnabled) return;

    final router = GoRouter(
      initialLocation: '/chat/mock_jack',
      routes: [
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
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.longPress(find.text('改到几点？'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('多选'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1条消息'), findsOneWidget);

    final visibleUncheckedMessage = find.text('另外周末有空吗？想约你打球');
    final messageCenter = tester.getCenter(visibleUncheckedMessage);
    await tester.tapAt(Offset(36, messageCenter.dy));
    await tester.pump();

    expect(find.text('已选择 2条消息'), findsOneWidget);

    await tester.tapAt(
      Offset(
        tester.view.physicalSize.width / tester.view.devicePixelRatio - 24,
        messageCenter.dy,
      ),
    );
    await tester.pump();

    expect(find.text('已选择 1条消息'), findsOneWidget);
  });

  testWidgets('mock forwarded chat record opens detail with source messages',
      (tester) async {
    const mockAuthEnabled = bool.fromEnvironment(
      'P2P_MATRIX_MOCK_AUTH',
      defaultValue: false,
    );
    if (!mockAuthEnabled) return;

    final router = GoRouter(
      initialLocation: '/chat/mock_jack',
      routes: [
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
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.longPress(find.text('改到几点？'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('多选'));
    await tester.pumpAndSettle();

    final secondMessage = find.text('另外周末有空吗？想约你打球');
    final secondMessageCenter = tester.getCenter(secondMessage);
    await tester.tapAt(Offset(36, secondMessageCenter.dy));
    await tester.pump();
    await tester.tap(find.byTooltip('转发'));
    await tester.pumpAndSettle();

    final recordBubble = find.text('聊天记录\n与 Jack 的聊天记录\n共 2 条消息');
    expect(recordBubble, findsOneWidget);

    await tester.tap(recordBubble);
    await tester.pumpAndSettle();

    expect(find.text('与 Jack 的聊天记录'), findsOneWidget);
    expect(find.text('共 2 条消息'), findsOneWidget);
    expect(find.text('改到几点？'), findsOneWidget);
    expect(find.text('另外周末有空吗？想约你打球'), findsOneWidget);
  });

  testWidgets('mock auth build ignores cached login for groups',
      (tester) async {
    const mockAuthEnabled = bool.fromEnvironment(
      'P2P_MATRIX_MOCK_AUTH',
      defaultValue: false,
    );
    if (!mockAuthEnabled) return;

    final client = Client('PortalIMTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const GroupsListPage()),
      ),
    );
    await tester.pump();

    expect(find.text('P2P IM 核心群'), findsOneWidget);
    expect(find.text('群主'), findsOneWidget);
  });

  testWidgets('mock auth build shows mock channels despite cached login',
      (tester) async {
    const mockAuthEnabled = bool.fromEnvironment(
      'P2P_MATRIX_MOCK_AUTH',
      defaultValue: false,
    );
    if (!mockAuthEnabled) return;

    final client = Client('PortalIMTest');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          currentUserProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('频道'));
    await tester.pumpAndSettle();

    expect(find.text('正在同步频道'), findsNothing);
    expect(find.text('P2P IM 官方'), findsOneWidget);
    expect(find.text('Agent 工作流'), findsOneWidget);
  });

  testWidgets('channel tab presents personal channel inbox categories',
      (tester) async {
    final client = Client('PortalIMTest');

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
    expect(find.text('文字'), findsAtLeastNWidgets(1));
    expect(find.text('帖子'), findsAtLeastNWidgets(1));
    expect(find.text('草稿'), findsNothing);

    expect(find.text('#综合讨论'), findsOneWidget);
    expect(find.text('#新手问答'), findsOneWidget);
    expect(find.text('草稿箱'), findsNothing);
    expect(find.text('自由讨论、技术交流与闲聊'), findsOneWidget);

    final firstTop = tester.getTopLeft(find.text('#综合讨论')).dy;
    final secondTop = tester.getTopLeft(find.text('#新手问答')).dy;
    expect(firstTop, lessThan(secondTop));
  });

  testWidgets('channel unread badge appears only for chat channels',
      (tester) async {
    const mockAuthEnabled = bool.fromEnvironment(
      'P2P_MATRIX_MOCK_AUTH',
      defaultValue: false,
    );
    if (mockAuthEnabled) return;

    final client = Client('PortalIMTest');

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

    expect(find.byKey(const ValueKey('channel_unread_count_ch_updates')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('channel_unread_count_ch_posts')),
        findsNothing);
  });

  testWidgets('channel tab hides legacy discover switch', (tester) async {
    final client = Client('PortalIMTest');

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
    expect(find.text('#综合讨论'), findsOneWidget);
    expect(find.text('#新手问答'), findsOneWidget);
  });

  testWidgets('channel filters are hidden on channel tab', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final client = Client('PortalIMTest');

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

  testWidgets('channel list opens the selected channel detail page',
      (tester) async {
    final client = Client('PortalIMTest');
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
    await tester.tap(find.byKey(const ValueKey('channel_inbox_tile_p2p-im')));
    await tester.pumpAndSettle();

    expect(find.text('p2p-im.com · 我的频道'), findsNothing);
    expect(find.text('#P2P IM 官方'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('channel_post_create_fab')), findsOneWidget);
    expect(find.text('频道主Diana发布帖子，成员可评论和恢复'), findsOneWidget);
    expect(find.textContaining('后端部署清单已更新'), findsWidgets);
  });

  testWidgets('joined dissolved channel is hidden from channel list',
      (tester) async {
    const mockAuthEnabled = bool.fromEnvironment(
      'P2P_MATRIX_MOCK_AUTH',
      defaultValue: false,
    );
    if (mockAuthEnabled) return;

    final client = Client('PortalIMDissolvedChannelHintTest')
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

  testWidgets('channel inbox long press shows channel actions', (tester) async {
    const mockAuthEnabled = bool.fromEnvironment(
      'P2P_MATRIX_MOCK_AUTH',
      defaultValue: false,
    );
    if (mockAuthEnabled) return;

    final client = Client('PortalIMChannelInboxMenuTest')
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
    const mockAuthEnabled = bool.fromEnvironment(
      'P2P_MATRIX_MOCK_AUTH',
      defaultValue: false,
    );
    if (mockAuthEnabled) return;

    final client = Client('PortalIMTest');
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

  testWidgets('joined channel detail uses read-only joined status bar',
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
          asClientProvider.overrideWithValue(_EmptyAsClient()),
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
    expect(find.text('频道主Diana发布帖子，成员可评论和恢复'), findsOneWidget);
    expect(find.text('36'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('发布帖子'), findsNothing);

    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();

    expect(find.text('帖子详情'), findsOneWidget);
    expect(find.text('输入评论...'), findsOneWidget);
    expect(find.textContaining('有人分享了群聊总结模板'), findsWidgets);
    expect(find.text('已关注'), findsNothing);
    expect(find.text('接收通知'), findsNothing);
  });

  testWidgets('channel detail and post route use dark tokens and app font',
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
          asClientProvider.overrideWithValue(_EmptyAsClient()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    final intro = tester.widget<Text>(
      find.text('频道主Diana发布帖子，成员可评论和恢复'),
    );
    expect(intro.style?.fontSize, 13);
    expect(intro.style?.letterSpacing, 0);

    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();

    final detailTitle = tester.widget<Text>(find.text('帖子详情'));
    expect(detailTitle.style?.color, PortalTokens.dark.text);
    expect(detailTitle.style?.fontSize, 20);
    expect(detailTitle.style?.letterSpacing, 0);
  });

  testWidgets('global search includes contacts groups and channels',
      (tester) async {
    final client = Client('PortalIMTest');

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
    expect(find.text('Alice Chen'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '产品');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('产品设计组'), findsOneWidget);
    expect(find.text('P2P IM 官方'), findsOneWidget);
  });

  testWidgets('global search opens channel detail results', (tester) async {
    final client = Client('PortalIMTest');
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
    await tester.tap(find.text('P2P IM 官方').last);
    await tester.pumpAndSettle();

    expect(find.text('p2p-im.com · 我的频道'), findsNothing);
    expect(find.text('频道详情功能待接入'), findsNothing);
  });

  testWidgets('global search indexes real bootstrap channels', (tester) async {
    final client = Client('PortalIMTest');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 5, 26, 10),
      user: const AsSyncUser(userId: '@owner:p2p-im.com'),
      rooms: const [],
      contacts: const [],
      groups: const [],
      channels: [
        AsSyncRoomSummary(
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
    expect(find.text('UID portal.local'), findsOneWidget);

    await tester.tap(find.text('UID portal.local'));
    await tester.pumpAndSettle();

    expect(find.text('已复制 UID'), findsOneWidget);
    final copied = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copied?.text, 'portal.local');
  });

  testWidgets('contact detail persists message mute toggle after re-entry',
      (tester) async {
    const roomId = '!contact-mute:p2p-im.com';
    const peerMxid = '@alice:p2p-im.com';
    final client = Client('PortalIMContactMuteTest')
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
    final client = Client('PortalIMContactDetailMatrixNameTest')
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

  testWidgets('contact detail hides delete friend action for self',
      (tester) async {
    final client = Client('PortalIMContactDetailSelfTest')
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
    expect(find.text('删除好友'), findsNothing);
  });

  testWidgets('contact detail updates remark without dialog disposal crash',
      (tester) async {
    final client = Client('PortalIMContactDetailRemarkTest')
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
    expect(asClient.updatedContactDomain, 'portal.local');
  });

  testWidgets(
      'contact detail deletes contact through AS and returns to messages',
      (tester) async {
    final client = Client('PortalIMContactDetailDeleteTest')
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
    final client = Client('PortalIMContactDetailBlockTest')
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
    final client = Client('PortalIMContactHomeDeleteNavigationTest')
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

  testWidgets('mock direct chat peer avatar opens contact detail page',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/chat/mock_dave',
      routes: [
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, state) =>
              ChatPage(roomId: state.pathParameters['roomId']!),
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
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester
        .tap(find.byKey(const ValueKey('chat_peer_avatar_mock_dave_1')));
    await tester.pumpAndSettle();

    expect(find.text('Dave Lee'), findsOneWidget);
    expect(find.text('发消息'), findsOneWidget);
    expect(find.text('语音通话'), findsOneWidget);
    expect(find.text('视频通话'), findsOneWidget);
    expect(find.text('设置备注'), findsOneWidget);
    expect(find.text('推荐给朋友'), findsOneWidget);
    expect(find.text('搜索聊天'), findsNothing);
    expect(find.text('消息免打扰'), findsNothing);
    expect(find.text('拉黑用户'), findsNothing);
    expect(find.text('举报用户'), findsNothing);
    expect(find.text('删除好友'), findsOneWidget);
  });

  testWidgets('mock direct chat header detail opens full contact page',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/chat/mock_dave',
      routes: [
        GoRoute(
          path: '/chat/:roomId',
          builder: (_, state) =>
              ChatPage(roomId: state.pathParameters['roomId']!),
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
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('详情').last);
    await tester.pumpAndSettle();

    expect(find.text('Dave Lee'), findsOneWidget);
    expect(find.text('发消息'), findsOneWidget);
    expect(find.text('搜索聊天'), findsOneWidget);
    expect(find.text('设置备注'), findsOneWidget);
    expect(find.text('推荐给朋友'), findsNothing);
    expect(find.text('消息免打扰'), findsOneWidget);
    expect(find.text('拉黑用户'), findsOneWidget);
    expect(find.text('举报用户'), findsOneWidget);
    expect(find.text('删除好友'), findsOneWidget);
  });

  testWidgets('contact visitor home follow button toggles locally',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContactHomePage(userId: '@alice:portal.local'),
        ),
      ),
    );
    await tester.pump();

    final followButton =
        find.byKey(const ValueKey('contact_home_follow_button'));
    final addButton =
        find.byKey(const ValueKey('contact_home_add_friend_button'));
    expect(followButton, findsOneWidget);
    expect(addButton, findsOneWidget);
    expect(find.descendant(of: followButton, matching: find.text('关注')),
        findsOneWidget);
    expect(find.descendant(of: addButton, matching: find.text('加好友')),
        findsOneWidget);
    expect(tester.getTopLeft(addButton).dy,
        greaterThan(tester.getTopLeft(followButton).dy));

    await tester.tap(followButton);
    await tester.pump();

    expect(find.descendant(of: followButton, matching: find.text('取关')),
        findsOneWidget);
  });

  testWidgets('contact visitor home add friend button marks requested locally',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContactHomePage(userId: '@alice:portal.local'),
        ),
      ),
    );
    await tester.pump();

    final addButton =
        find.byKey(const ValueKey('contact_home_add_friend_button'));
    expect(find.descendant(of: addButton, matching: find.text('加好友')),
        findsOneWidget);

    await tester.tap(addButton);
    await tester.pump();

    expect(find.descendant(of: addButton, matching: find.text('已申请')),
        findsOneWidget);
    expect(find.text('好友请求已发送，等待对方接受。'), findsOneWidget);
  });

  testWidgets('global search includes locally cached Matrix messages',
      (tester) async {
    final client = Client('PortalIMTestCachedSearch')
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

    await tester.enterText(find.byType(TextField), 'cached-history-needle');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Alice Chen'), findsOneWidget);
    expect(find.text('这是一条 cached-history-needle 历史消息'), findsOneWidget);
  });

  testWidgets('global search hides group invite messages', (tester) async {
    final client = Client('PortalIMTestGroupInviteSearch')
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
          asClientProvider.overrideWithValue(
            _SearchResultsAsClient(
              [
                AsSearchResult(
                  eventId: r'$remote-group-invite',
                  roomId: '!invite-direct:example.com',
                  senderName: 'Alice Chen',
                  content: '邀请进群 hidden-invite-needle',
                  timestamp: DateTime(2026, 5, 25, 11),
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

  testWidgets('me page presents personal space instead of settings list',
      (tester) async {
    final client = Client('PortalIMTest');

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
    expect(find.text('用自己的节点，连接重要的人和内容。'), findsOneWidget);
    expect(find.text('我的频道'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text('动态'), findsOneWidget);
    expect(find.text('作品墙'), findsNothing);
    expect(find.text('账号与安全'), findsNothing);
    expect(find.text('通知设置'), findsNothing);
    expect(find.text('通用'), findsNothing);
    expect(find.text('退出登录'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is GlassHeaderButton && widget.icon == Symbols.menu,
      ),
      findsOneWidget,
    );
  });

  testWidgets('me page renders dynamics as a moments-style timeline',
      (tester) async {
    final client = Client('PortalIMTest');

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

    expect(find.byKey(const ValueKey('me_dynamics_timeline')), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('五月'), findsAtLeastNWidgets(1));
    expect(find.text('06'), findsOneWidget);

    final todayTop = tester.getTopLeft(find.text('今天')).dy;
    final maySixTop = tester.getTopLeft(find.text('06')).dy;
    expect(todayTop, lessThan(maySixTop));

    final timeLeft = tester.getTopLeft(find.text('今天')).dx;
    final contentLeft = tester.getTopLeft(find.text('第三方平台一键安装')).dx;
    expect(contentLeft - timeLeft, greaterThan(100));
  });

  testWidgets('me dynamic timeline opens a detail page', (tester) async {
    final client = Client('PortalIMTest');
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/me/dynamic/:dynamicId',
          builder: (_, state) => DynamicDetailPage(
            dynamicId: state.pathParameters['dynamicId']!,
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

    await tester.tap(find.text('我的'));
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第三方平台一键安装'));
    await tester.pumpAndSettle();

    expect(find.text('动态详情'), findsOneWidget);
    expect(find.textContaining('云端服务能用吗'), findsOneWidget);
    expect(find.text('评论'), findsOneWidget);
    expect(find.text('转发'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);
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

    final client = Client('PortalIMTest')..setUserId('@owner:p2p-im.com');
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

    expect(_headerTitle('我的'), findsNothing);
    expect(find.text('owner'), findsOneWidget);
    expect(find.text('UID: https://p2p-im.com'), findsOneWidget);
    expect(find.text('我的频道'), findsOneWidget);
    expect(find.text('@me'), findsNothing);
    expect(find.textContaining('Node:'), findsNothing);

    await tester.tap(find.text('UID: https://p2p-im.com'));
    await tester.pumpAndSettle();
    expect(find.text('已复制 UID'), findsOneWidget);
    final copied = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copied?.text, 'https://p2p-im.com');

    await tester.tap(find.byIcon(Symbols.content_copy));
    await tester.pumpAndSettle();
    final copiedFromIcon = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copiedFromIcon?.text, 'https://p2p-im.com');

    await tester.tap(find.byKey(const ValueKey('me_domain_qr_button')));
    await tester.pumpAndSettle();

    expect(find.text('我的二维码'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('UID owner'), findsOneWidget);
    expect(find.text('保存到相册'), findsOneWidget);
  });

  testWidgets('me page keeps long uid within profile row height',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final client = Client('PortalIMLongUidTest')
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

  testWidgets('me menu opens private tools and unified settings page',
      (tester) async {
    final client = Client('PortalIMTest');
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
    await tester.tap(find.byIcon(Symbols.menu));
    await tester.pumpAndSettle();

    expect(find.text('菜单'), findsOneWidget);
    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.text('我的点赞'), findsOneWidget);
    expect(find.text('我的评论'), findsOneWidget);
    expect(find.text('草稿箱'), findsOneWidget);
    expect(find.text('浏览记录'), findsNothing);
    expect(find.text('我的钱包'), findsOneWidget);
    expect(find.text('通用设置'), findsOneWidget);

    await tester.tap(find.text('通用设置'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('通用设置'), findsOneWidget);
    expect(find.text('隐私与安全'), findsOneWidget);
    expect(find.text('消息与通知'), findsOneWidget);
    expect(find.text('其他'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
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
    expect(find.text('Yanan'), findsOneWidget);
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
    expect(find.text('Yanan'), findsOneWidget);
    expect(find.text('这条评论来自真实用户名'), findsOneWidget);
    expect(find.textContaining('产品公告'), findsNothing);
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
    expect(find.text('这条评论来自真实用户名'), findsOneWidget);

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

  testWidgets('me favorites image preview falls back to original media',
      (tester) async {
    final requested = <Uri>[];
    final client = Client(
      'PortalIMFavoritePreviewTest',
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
      isTrue,
    );
  });

  testWidgets('me favorites image card opens favorite detail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final client = Client(
      'PortalIMFavoriteImageOpenTest',
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
    await tester.tap(find.byKey(const ValueKey('favorite-card-4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('收藏详情'), findsOneWidget);
    expect(find.text('消息详情'), findsNothing);
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

  testWidgets('me menu button stays below the status safe area',
      (tester) async {
    final client = Client('PortalIMTest');

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

    final topLeft = tester.getTopLeft(find.byKey(
      const ValueKey('me_menu_button'),
    ));
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

    final client = Client('PortalIMTest')..setUserId('@owner:p2p-im.com');
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

    await tester.tap(find.byKey(const ValueKey('me_profile_entry')));
    await tester.pumpAndSettle();

    expect(find.text('我的信息'), findsOneWidget);
    expect(find.text('修改'), findsOneWidget);
    expect(find.text('名字'), findsOneWidget);
    expect(find.text('UID: https://p2p-im.com'), findsOneWidget);
    expect(find.text('性别'), findsOneWidget);
    expect(find.text('生日'), findsOneWidget);
    expect(find.text('手机号码'), findsOneWidget);
    expect(find.text('邮箱'), findsOneWidget);

    await tester.tap(find.text('UID: https://p2p-im.com'));
    await tester.pumpAndSettle();
    expect(find.text('已复制 UID'), findsOneWidget);
    final copied = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copied?.text, 'https://p2p-im.com');

    await tester.tap(find.byIcon(Symbols.content_copy));
    await tester.pumpAndSettle();
    final copiedFromIcon = await Clipboard.getData(Clipboard.kTextPlain);
    expect(copiedFromIcon?.text, 'https://p2p-im.com');
  });

  testWidgets('editing profile name updates me page header', (tester) async {
    final client = Client('PortalIMTest')..setUserId('@owner:p2p-im.com');
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

    await tester.tap(find.text('名字'));
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

  testWidgets('settings page matches TokLink settings sections',
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
    expect(find.text('通讯录黑名单'), findsOneWidget);
    expect(find.text('消息与通知'), findsOneWidget);
    expect(find.text('勿扰模式'), findsOneWidget);
    expect(find.text('新消息提示音'), findsOneWidget);
    expect(find.text('新消息震动'), findsOneWidget);
    expect(find.text('其他'), findsOneWidget);
    expect(find.text('关于我们'), findsOneWidget);
    expect(find.text('清空聊天记录'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
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
      Symbols.bookmarks,
      Symbols.person_remove,
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
      MaterialApp(theme: AppTheme.light, home: const MeNotificationsPage()),
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
    final client = Client('PortalIMTest');
    final router = GoRouter(
      initialLocation: '/chat/mock_aibot',
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
          authStateNotifierProvider.overrideWith(_FakeAuthStateNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Agent'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.text('HomeRoot'), findsOneWidget);
  });

  testWidgets('agent chat header uses AS connection status', (tester) async {
    final client = Client('PortalIMTest')..setUserId('@owner:p2p-im.com');
    _addTestRoom(
      client,
      roomId: '!agent:p2p-im.com',
      roomMembership: Membership.join,
      directPeerMxid: '@agent:p2p-im.com',
    );

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
          home: const ChatPage(roomId: '!agent:p2p-im.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Agent'), findsOneWidget);
    expect(find.text('离线'), findsOneWidget);
    expect(find.text('在线'), findsNothing);
  });

  testWidgets('private chat header shows peer offline and typing status',
      (tester) async {
    const roomId = '!peer-status:p2p-im.com';
    const peerMxid = '@alice:p2p-im.com';
    final client = Client('PortalIMPeerStatusTest')
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

  testWidgets('private chat recalls own message through AS', (tester) async {
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

    expect(harness.asClient.recallRoomMessageCalls, 1);
    expect(harness.asClient.recalledRoomId, '!direct:p2p-im.com');
    expect(harness.asClient.recalledEventId, r'$direct-own-text');
    expect(harness.asClient.recallRoomMessageReason, '撤回消息');
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
      'PortalIMOwnMessageAvatarTest',
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
      'PortalIMReadReceiptIconTest',
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
    final client = Client('PortalIMSystemNoticeChatTest')
      ..setUserId('@owner:p2p-im.com');
    _addUndirectedJoinedRoom(
      client,
      roomId: '!accepted:p2p-im.com',
      peerMxid: '@owner:p2p-liyanan.com',
      peerName: 'owner',
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
    final unread = AsSyncUnread(
      syncedAt: DateTime.utc(2026, 5, 27, 16, 10),
      rooms: [
        AsUnreadRoom(
          roomId: '!accepted:p2p-im.com',
          messages: [
            AsUnreadMessage(
              eventId: r'$accepted-notice',
              senderId: '@owner:p2p-liyanan.com',
              senderName: 'owner',
              content: '你们已成为好友，现在可以开始聊天了',
              messageType: MessageTypes.Notice,
              timestamp: DateTime.utc(2026, 5, 27, 16, 10),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          authStateNotifierProvider
              .overrideWith(_LoggedInAuthStateNotifier.new),
          asClientProvider.overrideWithValue(_ReadMarkerFailingAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap, unread: unread),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: '!accepted:p2p-im.com'),
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

  testWidgets('chat waits for Matrix room load when AS knows conversation',
      (tester) async {
    final client = Client('PortalIMMissingRoomRecoveryTest')
      ..setUserId('@owner:p2p-im.com');
    final bootstrap = AsSyncBootstrap(
      syncedAt: DateTime.utc(2026, 6, 12, 9),
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
          asClientProvider.overrideWithValue(_EmptyAsClient()),
          asSyncCacheProvider.overrideWith(
            (ref) => AsSyncCacheState(bootstrap: bootstrap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatPage(roomId: '!alice:p2p-im.com'),
        ),
      ),
    );

    expect(find.text('正在同步会话'), findsOneWidget);
    expect(find.text('会话不存在'), findsNothing);

    await tester.pump(const Duration(seconds: 13));
    await tester.pump();
    expect(find.text('会话同步超时，请检查网络后重试'), findsOneWidget);
    expect(find.text('会话不存在'), findsNothing);
  });

  testWidgets('private chat shows friendly failure when peer deleted contact',
      (tester) async {
    final client = Client('PortalIMPeerDeletedSendTest')
      ..setUserId('@owner:p2p-im.com');
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
          asClientProvider.overrideWithValue(_PeerDeletedAsClient()),
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

    expect(find.text('对方已删除联系人关系，消息未送达'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('private chat blocks duplicate direct rooms omitted by AS',
      (tester) async {
    final client = Client('PortalIMDuplicateDirectSendTest')
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
    expect(asClient.sendRoomMessageCalls, 0);
  });

  testWidgets('private chat blocks unclassified one-to-one rooms omitted by AS',
      (tester) async {
    final client = Client('PortalIMUnclassifiedOneToOneSendTest')
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
    expect(asClient.sendRoomMessageCalls, 0);
  });

  testWidgets('private chat blocks rejected direct rooms with joined peer',
      (tester) async {
    final client = Client('PortalIMRejectedDirectSendTest')
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
    expect(asClient.sendRoomMessageCalls, 0);
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

    expect(find.text('https://example.com'), findsOneWidget);
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

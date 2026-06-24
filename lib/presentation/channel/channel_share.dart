import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../chat/chat_message_cards.dart';
import '../chat/chat_record_forwarding.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/product_conversation_navigation.dart';
import '../widgets/portal_avatar.dart';

const channelShareMessageType = 'channel_share';
const channelShareMatrixPayloadKey = 'p2p.channel_share';

class ChannelSharePayload {
  const ChannelSharePayload({
    required this.channelId,
    required this.roomId,
    this.grantId = '',
    this.shareRoomId = '',
    required this.homeDomain,
    required this.name,
    this.description = '',
    this.avatarUrl = '',
    this.visibility = asChannelVisibilityPublic,
    this.joinPolicy = asChannelJoinPolicyOpen,
    this.commentsEnabled = true,
    this.channelType = asChannelTypeChat,
    this.tags = const [],
    this.memberCount = -1,
  });

  final String channelId;
  final String roomId;
  final String grantId;
  final String shareRoomId;
  final String homeDomain;
  final String name;
  final String description;
  final String avatarUrl;
  final String visibility;
  final String joinPolicy;
  final bool commentsEnabled;
  final String channelType;
  final List<String> tags;
  final int memberCount;

  String get displayName => name.trim().isEmpty ? '未命名频道' : name.trim();

  String get body => '频道分享\n$displayName';

  AsChannelShareDraft get asDraft => AsChannelShareDraft(
        channelId: channelId,
        roomId: roomId,
        grantId: grantId,
        shareRoomId: shareRoomId,
        homeDomain: homeDomain,
        name: displayName,
        description: description,
        avatarUrl: avatarUrl,
        visibility: visibility,
        joinPolicy: joinPolicy,
        commentsEnabled: commentsEnabled,
        channelType: channelType,
        tags: tags,
        memberCount: memberCount,
      );

  AsChannel get asDiscoveredChannel => AsChannel(
        channelId: channelId,
        roomId: roomId,
        homeDomain: homeDomain,
        name: displayName,
        description: description,
        avatarUrl: avatarUrl,
        visibility: visibility,
        joinPolicy: joinPolicy,
        commentsEnabled: commentsEnabled,
        channelType: channelType,
        tags: tags,
        memberCount: memberCount,
      );
}

String channelShareOpenRoute(
  AsSyncCacheState syncCache,
  ChannelSharePayload payload, {
  Iterable<AsConversation> productConversations = const [],
}) {
  final channelId = payload.channelId.trim();
  final roomId = payload.roomId.trim();
  final routeId = channelId.isEmpty ? roomId : channelId;
  final encodedRouteId = Uri.encodeComponent(routeId);
  if (_channelShareIsJoined(syncCache, payload)) {
    if (_channelShareIsPostType(payload)) return '/channel/$encodedRouteId';
    final productRoute = productConversationRoute(
      productConversationForRoom(
        productConversations,
        roomId,
        kinds: const {asConversationKindChannel},
      ),
      channelId:
          payload.channelId.trim().isEmpty ? payload.roomId : payload.channelId,
    );
    if (productRoute != null) return productRoute;
    final fallbackRoute = joinedTextChannelConversationRoute(
      channelId: payload.channelId,
      roomId: payload.roomId,
      memberStatus: asChannelMemberStatusJoined,
      channelType: payload.channelType,
      name: payload.name,
    );
    if (fallbackRoute != null) return fallbackRoute;
  }
  return '/channel/$encodedRouteId/detail';
}

bool channelShareIsJoined(
  AsSyncCacheState syncCache,
  ChannelSharePayload payload,
) =>
    _channelShareIsJoined(syncCache, payload);

bool channelShareHasInviteGrant(ChannelSharePayload payload) =>
    payload.grantId.trim().isNotEmpty && payload.shareRoomId.trim().isNotEmpty;

String channelShareJoinRequestTargetId(ChannelSharePayload payload) {
  final roomId = payload.roomId.trim();
  if (roomId.isNotEmpty) return roomId;
  return payload.channelId.trim();
}

String channelShareJoinKey(ChannelSharePayload payload) {
  final channelId = payload.channelId.trim();
  if (channelId.isNotEmpty) return channelId;
  return payload.roomId.trim();
}

String channelShareJoinedRoute(
  ChannelSharePayload payload,
  AsChannel joined,
) {
  final channelId = joined.channelId.trim().isEmpty
      ? payload.channelId.trim()
      : joined.channelId.trim();
  final encodedId = Uri.encodeComponent(
    channelId.isEmpty ? payload.roomId.trim() : channelId,
  );
  if (_channelShareIsPostType(payload)) {
    return '/channel/$encodedId';
  }
  final productRoute = productConversationRoute(
    joined.productConversation,
    channelId: channelId.isEmpty ? payload.roomId : channelId,
  );
  if (productRoute != null) return productRoute;
  final fallbackRoute = joinedTextChannelConversationRoute(
    channelId: channelId,
    roomId: joined.roomId.trim().isEmpty ? payload.roomId : joined.roomId,
    memberStatus: joined.memberStatus,
    channelType: joined.channelType,
    name: joined.name.trim().isEmpty ? payload.name : joined.name,
  );
  if (fallbackRoute != null) return fallbackRoute;
  return '/channel/$encodedId/detail';
}

bool _channelShareIsPostType(ChannelSharePayload payload) {
  if (normalizeAsChannelType(payload.channelType) == asChannelTypePost) {
    return true;
  }
  return payload.tags
      .any((tag) => normalizeAsChannelType(tag) == asChannelTypePost);
}

bool _channelShareIsJoined(
  AsSyncCacheState syncCache,
  ChannelSharePayload payload,
) {
  final channelId = payload.channelId.trim();
  final roomId = payload.roomId.trim();
  for (final channel in syncCache.bootstrap?.channels ?? const []) {
    final existingChannelId = channel.channelId.trim();
    final existingRoomId = channel.roomId.trim();
    if ((channelId.isNotEmpty && existingChannelId == channelId) ||
        (roomId.isNotEmpty && existingRoomId == roomId)) {
      return isAsChannelMemberJoined(channel.memberStatus);
    }
  }
  return false;
}

ChannelSharePayload channelSharePayloadFromChannel({
  required String channelId,
  required String roomId,
  String grantId = '',
  String shareRoomId = '',
  required String homeDomain,
  required String name,
  String description = '',
  String avatarUrl = '',
  String visibility = asChannelVisibilityPublic,
  String joinPolicy = asChannelJoinPolicyOpen,
  bool commentsEnabled = true,
  String channelType = asChannelTypeChat,
  List<String> tags = const [],
  int memberCount = -1,
}) {
  return ChannelSharePayload(
    channelId: channelId,
    roomId: roomId,
    grantId: grantId,
    shareRoomId: shareRoomId,
    homeDomain: homeDomain,
    name: name,
    description: description,
    avatarUrl: avatarUrl,
    visibility: visibility,
    joinPolicy: joinPolicy,
    commentsEnabled: commentsEnabled,
    channelType: channelType,
    tags: tags,
    memberCount: memberCount,
  );
}

ChannelSharePayload? channelSharePayloadFromContent(
  Map<String, Object?> content,
) {
  final messageType = _stringValue(
    content[chatRecordMatrixMarkerKey] ?? content['message_type'],
  ).trim();
  if (messageType != channelShareMessageType) {
    return null;
  }
  final raw = _objectMap(
    content[channelShareMatrixPayloadKey] ?? content['channel_share'],
  );
  final channelId = _stringValue(raw['channel_id']).trim();
  final roomId = _stringValue(raw['room_id']).trim();
  final name = _stringValue(raw['name']).trim();
  if (channelId.isEmpty || roomId.isEmpty || name.isEmpty) return null;
  return ChannelSharePayload(
    channelId: channelId,
    roomId: roomId,
    grantId: _stringValue(raw['grant_id']).trim(),
    shareRoomId: _stringValue(raw['share_room_id']).trim(),
    homeDomain: _stringValue(raw['home_domain']).trim(),
    name: name,
    description: _stringValue(raw['description']).trim(),
    avatarUrl: _stringValue(raw['avatar_url']).trim(),
    visibility: _stringValue(raw['visibility']).trim().isEmpty
        ? asChannelVisibilityPublic
        : _stringValue(raw['visibility']).trim(),
    joinPolicy: _stringValue(raw['join_policy']).trim().isEmpty
        ? asChannelJoinPolicyOpen
        : _stringValue(raw['join_policy']).trim(),
    commentsEnabled: raw['comments_enabled'] is bool
        ? raw['comments_enabled'] as bool
        : true,
    channelType: normalizeAsChannelType(_stringValue(raw['channel_type'])),
    tags: _stringList(raw['tags']),
    memberCount: _intValue(raw['member_count'], fallback: -1),
  );
}

Future<bool> showAndShareChannel(
  BuildContext context,
  WidgetRef ref, {
  required ChannelSharePayload payload,
  required String currentRoomId,
  required String currentRoomName,
}) async {
  final targets = chatRecordForwardTargets(
    ref.read(asSyncCacheProvider),
    currentRoomId: currentRoomId,
    currentRoomName: currentRoomName,
    currentRoomType: 'channel',
  )
      .where(
          (target) => target.roomType == 'direct' || target.roomType == 'group')
      .toList(growable: false);
  if (targets.isEmpty) {
    throw StateError('暂无可分享的私聊或群聊');
  }
  final target = await showModalBottomSheet<ChatRecordForwardTarget>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ChannelShareTargetSheet(targets: targets),
  );
  if (target == null) return false;
  debugPrint(
    '[channel.share.send.start] '
    'target_room_id=${_logChannelShareValue(target.roomId)} '
    'target_type=${_logChannelShareValue(target.roomType)} '
    'channel_id=${_logChannelShareValue(payload.channelId)} '
    'room_id=${_logChannelShareValue(payload.roomId)}',
  );
  debugPrint(
    '[channel.share.send.payload] '
    'has_grant=${channelShareHasInviteGrant(payload)} '
    'channel_id=${_logChannelShareValue(payload.channelId)} '
    'room_id=${_logChannelShareValue(payload.roomId)} '
    'grant_id=${_logChannelShareValue(payload.grantId)} '
    'share_room_id=${_logChannelShareValue(payload.shareRoomId)} '
    'join_policy=${_logChannelShareValue(payload.joinPolicy)} '
    'visibility=${_logChannelShareValue(payload.visibility)}',
  );
  final matrixClient = ref.read(matrixClientProvider);
  final room = matrixClient.getRoomById(target.roomId);
  if (room == null) {
    throw StateError('目标会话未同步到本地');
  }
  await room.sendEvent({
    'msgtype': MessageTypes.Text,
    'body': payload.body,
    'message_type': channelShareMessageType,
    chatRecordMatrixMarkerKey: channelShareMessageType,
    channelShareMatrixPayloadKey: payload.asDraft.toJson(),
  });
  await matrixClient.oneShotSync();
  return true;
}

ChannelSharePayload channelSharePayloadWithInviteGrant(
  ChannelSharePayload payload, {
  required String grantId,
  required String shareRoomId,
}) {
  return ChannelSharePayload(
    channelId: payload.channelId,
    roomId: payload.roomId,
    grantId: grantId,
    shareRoomId: shareRoomId,
    homeDomain: payload.homeDomain,
    name: payload.name,
    description: payload.description,
    avatarUrl: payload.avatarUrl,
    visibility: payload.visibility,
    joinPolicy: payload.joinPolicy,
    commentsEnabled: payload.commentsEnabled,
    channelType: payload.channelType,
    tags: payload.tags,
    memberCount: payload.memberCount,
  );
}

class ChannelSharePreviewCard extends StatelessWidget {
  const ChannelSharePreviewCard({
    super.key,
    required this.payload,
    this.joining = false,
    this.alreadyJoined = false,
    this.alreadyRequested = false,
    this.onJoin,
    this.onTap,
    this.onLongPressAt,
  });

  final ChannelSharePayload payload;
  final bool joining;
  final bool alreadyJoined;
  final bool alreadyRequested;
  final VoidCallback? onJoin;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final subtitle = payload.description.trim().isEmpty
        ? payload.homeDomain.trim()
        : payload.description.trim();
    final typeLabel = _channelShareTypeLabel(payload);
    final buttonDisabled = joining || alreadyJoined || alreadyRequested;
    final buttonTap = buttonDisabled ? () {} : onJoin;
    return ChatCardBubbleFrame(
      onTap: onTap,
      onLongPressAt: onLongPressAt,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _ChannelShareAvatar(payload: payload),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              payload.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(
                                size: 16,
                                weight: FontWeight.w700,
                                color: t.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _ChannelShareTypePill(label: typeLabel),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle.isEmpty ? '公开频道' : subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(size: 12, color: t.textMute)
                            .copyWith(height: 1.18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: Material(
              color:
                  buttonDisabled ? t.accent.withValues(alpha: 0.48) : t.accent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: buttonTap,
                borderRadius: BorderRadius.circular(8),
                child: Center(
                  child: Text(
                    joining
                        ? '加入中…'
                        : alreadyJoined
                            ? '已加入'
                            : alreadyRequested
                                ? '已申请加入频道'
                                : '加入频道',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: t.onAccent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelShareTypePill extends StatelessWidget {
  const _ChannelShareTypePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      key: ValueKey('channel_share_type_$label'),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.sans(
          size: 11,
          weight: FontWeight.w600,
          color: t.accent,
        ),
      ),
    );
  }
}

String _channelShareTypeLabel(ChannelSharePayload payload) {
  return normalizeAsChannelType(payload.channelType) == asChannelTypePost
      ? '帖子'
      : '文字';
}

class _ChannelShareAvatar extends StatelessWidget {
  const _ChannelShareAvatar({required this.payload});

  final ChannelSharePayload payload;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final initial = payload.displayName.isEmpty ? '#' : payload.displayName[0];
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: t.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: payload.avatarUrl.trim().isEmpty
            ? Text(
                initial,
                style: AppTheme.sans(
                  size: 19,
                  weight: FontWeight.w800,
                  color: t.text,
                ),
              )
            : Icon(Symbols.campaign, color: t.text, size: 24),
      ),
    );
  }
}

class _ChannelShareTargetSheet extends ConsumerWidget {
  const _ChannelShareTargetSheet({required this.targets});

  final List<ChatRecordForwardTarget> targets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final client = ref.watch(matrixClientProvider);
    final syncCache = ref.watch(asSyncCacheProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.64,
      minChildSize: 0.36,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            itemCount: targets.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '分享频道到',
                    style: AppTheme.sans(
                      size: 17,
                      weight: FontWeight.w700,
                      color: t.text,
                    ),
                  ),
                );
              }
              final target = targets[index - 1];
              final avatarUrl = _targetAvatarUrl(client, syncCache, target);
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: t.border.withValues(alpha: 0.16)),
                ),
                tileColor: t.surface,
                leading: PortalAvatar(
                  seed: target.name,
                  size: 40,
                  imageUrl: avatarUrl,
                  shape: AvatarShape.squircle,
                ),
                title: Text(
                  target.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context).pop(target),
              );
            },
          ),
        );
      },
    );
  }
}

String _logChannelShareValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '<empty>' : trimmed;
}

String? _targetAvatarUrl(
  Client client,
  AsSyncCacheState syncCache,
  ChatRecordForwardTarget target,
) {
  final roomId = target.roomId.trim();
  final room = roomId.isEmpty ? null : client.getRoomById(roomId);
  if (target.roomType == 'direct') {
    final contact = syncCache.acceptedContactForRoom(roomId);
    final peerMxid = contact?.userId.trim() ?? '';
    final member = peerMxid.isEmpty
        ? null
        : room?.unsafeGetUserFromMemoryOrFallback(peerMxid);
    return avatarHttpUrl(client, contact?.avatarUrl) ??
        matrixContentHttpUrl(client, member?.avatarUrl) ??
        (room == null ? null : roomAvatarHttpUrl(room));
  }
  if (target.roomType == 'group') {
    return room == null ? null : roomAvatarHttpUrl(room);
  }
  return null;
}

String _stringValue(Object? value) => value is String ? value : '';

int _intValue(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ];
}

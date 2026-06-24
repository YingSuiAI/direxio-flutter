import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_zh.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../providers/product_conversations_provider.dart';
import '../utils/group_creation_flow.dart';
import '../utils/group_avatar_members.dart';
import '../utils/avatar_url.dart';
import '../utils/message_preview.dart';
import '../utils/product_conversation_navigation.dart';
import '../widgets/group_composite_avatar.dart';
import '../widgets/m3/m3_search_field.dart';

const _groupsToolbarHeight = 62.0;

final AppLocalizations _fallbackGroupsListL10n = AppLocalizationsZh();

AppLocalizations _groupsListL10n(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      _fallbackGroupsListL10n;
}

/// `s-groups-list` — 群聊列表 (index.html L1566-1643)
///
/// 通讯录 → 群聊 入口。展示所有群聊房间，点击进入群聊。
class GroupsListPage extends ConsumerStatefulWidget {
  const GroupsListPage({super.key});

  @override
  ConsumerState<GroupsListPage> createState() => _GroupsListPageState();
}

class _GroupsListPageState extends ConsumerState<GroupsListPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = _groupsListL10n(context);
    final client = ref.watch(matrixClientProvider);
    final syncCache = ref.watch(asSyncCacheProvider);
    final productConversationsAsync = ref.watch(productConversationsProvider);
    final productConversations =
        productConversationsAsync.valueOrNull ?? const [];
    final groupRemarkNames = ref.watch(groupRemarkNamesProvider);
    final groupAvatarMemberOrders = ref.watch(groupAvatarMemberOrdersProvider);
    final groupAvatarMemberAvatars =
        ref.watch(groupAvatarMemberAvatarsProvider);
    final directContactRoomIds = syncCache.acceptedContacts
        .map((contact) => contact.roomId.trim())
        .where((roomId) => roomId.isNotEmpty)
        .toSet();

    final items = <_GroupItem>[];
    final groupsByRoomId = {
      for (final group in syncCache.bootstrap?.groups ?? const [])
        if (group.roomId.trim().isNotEmpty) group.roomId.trim(): group,
    };
    final groupConversations = [
      for (final conversation in productConversations)
        if (conversation.isGroup) conversation,
    ]..sort((a, b) {
        final ta = a.lastActivityAt?.millisecondsSinceEpoch ?? 0;
        final tb = b.lastActivityAt?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
    for (final conversation in groupConversations) {
      final roomId = conversation.roomId.trim();
      if (roomId.isEmpty) continue;
      if (directContactRoomIds.contains(roomId)) continue;
      final group = groupsByRoomId[roomId];
      if (!_isVisibleGroupForList(group, conversation)) continue;
      final room = client.getRoomById(roomId);
      final lastEvent = room?.lastEvent;
      final lastActivityAt = lastEvent?.originServerTs ??
          group?.lastActivityAt ??
          conversation.lastActivityAt;
      final productTitle = conversation.title.trim();
      final groupName = group?.name.trim() ?? '';
      final authoritativeGroupMembers = ref
              .watch(
                groupMembersProvider(
                  GroupMembersKey(
                    roomId: roomId,
                    status: asChannelMemberStatusJoined,
                  ),
                ),
              )
              .valueOrNull ??
          const <AsGroupMember>[];
      final groupAvatarMembers = room == null
          ? null
          : stableGroupAvatarMembersForRoom(
              room: room,
              syncCache: syncCache,
              cachedMemberOrder: groupAvatarMemberOrders[roomId] ?? const [],
              cachedMemberAvatarUrls:
                  groupAvatarMemberAvatars[roomId] ?? const {},
              authoritativeMembers: authoritativeGroupMembers,
            );
      if (groupAvatarMembers != null) {
        scheduleGroupAvatarMemberOrderPersist(
          ref,
          roomId,
          groupAvatarMembers,
        );
      }
      final avatarUrl = avatarHttpUrl(client, conversation.avatarUrl) ??
          avatarHttpUrl(client, group?.avatarUrl) ??
          (room == null ? null : roomAvatarHttpUrl(room)) ??
          '';
      items.add(
        _GroupItem(
          id: roomId,
          name: (groupRemarkNames[roomId]?.trim().isNotEmpty ?? false)
              ? groupRemarkNames[roomId]!.trim()
              : productTitle.isNotEmpty
                  ? productTitle
                  : groupName.isNotEmpty
                      ? groupName
                      : room?.getLocalizedDisplayname() ?? l10n.contactsGroups,
          preview: lastEvent == null
              ? _previewText(group?.topic ?? '')
              : roomEventPreviewText(lastEvent, isAgent: false),
          avatarMembers: groupAvatarMembers?.members ??
              cachedGroupAvatarMembers(
                cachedMemberOrder: groupAvatarMemberOrders[roomId] ?? const [],
                cachedMemberAvatarUrls:
                    groupAvatarMemberAvatars[roomId] ?? const {},
              ),
          time: lastActivityAt == null
              ? ''
              : _formatTime(lastActivityAt.millisecondsSinceEpoch, l10n),
          unread: (group?.unreadCount ?? 0) > 0
              ? group!.unreadCount
              : room?.notificationCount ?? 0,
          avatarUrl: avatarUrl,
          isOwner: group?.isOwned ?? false,
          productConversation: _openableGroupConversationForList(conversation),
        ),
      );
    }

    final filtered = _query.isEmpty
        ? items
        : items
            .where((g) => g.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          _GroupsToolbar(
            title: l10n.contactsGroups,
            onBack: () => Navigator.of(context).maybePop(),
            onCreate: () => showCreateGroupFlow(context, ref),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _SearchBar(
              hint: l10n.groupsListSearchHint,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      productConversationsAsync.isLoading
                          ? l10n.groupsListSyncing
                          : _query.isEmpty
                              ? l10n.groupsListEmpty
                              : l10n.groupsListNoMatches,
                      style: AppTheme.sans(size: 13, color: t.textMute),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _GroupRow(item: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

bool _isVisibleGroupForList(
  AsSyncRoomSummary? group,
  AsConversation conversation,
) {
  if (_isExitedGroupStatus(group?.memberStatus) ||
      _isExitedGroupStatus(conversation.lifecycle) ||
      _isExitedGroupStatus(conversation.membership) ||
      _isExitedGroupStatus(conversation.relationshipStatus) ||
      _isExitedGroupStatus(conversation.projectionState)) {
    return true;
  }
  if (_isHiddenGroupStatus(group?.memberStatus) ||
      _isHiddenGroupStatus(conversation.membership) ||
      _isHiddenGroupStatus(conversation.relationshipStatus) ||
      _isHiddenGroupStatus(conversation.projectionState)) {
    return false;
  }
  if (_isJoinedGroupStatus(group?.memberStatus) ||
      _isJoinedGroupStatus(conversation.membership) ||
      _isJoinedGroupStatus(conversation.relationshipStatus) ||
      _isJoinedGroupStatus(conversation.projectionState) ||
      _isJoinedGroupRole(group?.role) ||
      _isJoinedGroupRole(conversation.role) ||
      conversation.canOpen) {
    return true;
  }

  return group?.memberStatus.trim().isEmpty != false &&
      conversation.membership.trim().isEmpty &&
      conversation.relationshipStatus.trim().isEmpty &&
      conversation.projectionState.trim().isEmpty;
}

AsConversation _openableGroupConversationForList(AsConversation conversation) {
  if (conversation.canOpen) return conversation;
  return AsConversation(
    conversationId: conversation.conversationId,
    roomId: conversation.roomId,
    kind: conversation.kind,
    lifecycle: conversation.lifecycle,
    title: conversation.title,
    avatarUrl: conversation.avatarUrl,
    peerMxid: conversation.peerMxid,
    lastEventId: conversation.lastEventId,
    lastMessage: conversation.lastMessage,
    lastActivityAt: conversation.lastActivityAt,
    projectionState: conversation.projectionState,
    projectionReason: conversation.projectionReason,
    memberCount: conversation.memberCount,
    membership: conversation.membership,
    relationshipStatus: conversation.relationshipStatus,
    role: conversation.role,
    hydrationState: conversation.hydrationState,
    hydrationReason: conversation.hydrationReason,
    capabilities: const AsConversationCapabilities(open: true),
  );
}

bool _isJoinedGroupStatus(String? status) {
  switch (status?.trim().toLowerCase()) {
    case 'join':
    case 'joined':
    case 'active':
    case 'member':
      return true;
  }
  return false;
}

bool _isHiddenGroupStatus(String? status) {
  switch (status?.trim().toLowerCase()) {
    case 'invite':
    case 'invited':
    case 'pending':
    case 'pending_inbound':
    case 'pending_outbound':
    case 'requested':
    case 'request':
    case 'rejected':
    case 'reject':
      return true;
  }
  return false;
}

bool _isExitedGroupStatus(String? status) {
  switch (status?.trim().toLowerCase()) {
    case 'left':
    case 'leave':
    case 'kick':
    case 'kicked':
    case 'remove':
    case 'removed':
    case 'ban':
    case 'banned':
      return true;
  }
  return false;
}

bool _isJoinedGroupRole(String? role) {
  switch (role?.trim().toLowerCase()) {
    case 'owner':
    case 'admin':
    case 'member':
      return true;
  }
  return false;
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return M3SearchField(hint: hint, onChanged: onChanged);
  }
}

class _GroupsToolbar extends StatelessWidget {
  const _GroupsToolbar({
    required this.title,
    required this.onBack,
    required this.onCreate,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: _groupsToolbarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _GroupsHeaderButton(
                  icon: Symbols.arrow_back,
                  onTap: onBack,
                ),
              ),
              Text(
                title,
                style: AppTheme.sans(
                  size: 16,
                  weight: FontWeight.w600,
                  color: t.text,
                ).copyWith(letterSpacing: 0),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _GroupsHeaderButton(
                  icon: Symbols.group_add,
                  color: t.accent,
                  onTap: onCreate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupsHeaderButton extends StatelessWidget {
  const _GroupsHeaderButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: 0.08),
            blurRadius: 36,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: Material(
          color: t.surface.withValues(alpha: 0.72),
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: 40,
              child: Icon(icon, size: 24, color: color ?? t.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupItem {
  const _GroupItem({
    required this.id,
    required this.name,
    required this.preview,
    this.avatarUrl = '',
    this.avatarMembers = const [],
    required this.time,
    required this.unread,
    this.isOwner = false,
    this.productConversation,
  });
  final String id;
  final String name;
  final String preview;
  final String avatarUrl;
  final List<GroupCompositeAvatarMember> avatarMembers;
  final String time;
  final int unread;
  final bool isOwner;
  final AsConversation? productConversation;
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.item});
  final _GroupItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final name = item.name;
    final preview = item.preview;
    final time = item.time;
    final unread = item.unread;

    return Material(
      color: t.surface.withValues(alpha: 0),
      child: InkWell(
        onTap: item.productConversation == null
            ? null
            : () {
                final productRoute =
                    productConversationRoute(item.productConversation!);
                if (productRoute != null) context.push(productRoute);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              GroupCompositeAvatar(
                key: ValueKey('group_avatar_${item.id}'),
                seed: name,
                size: 48,
                imageUrl: item.avatarUrl,
                members: item.avatarUrl.trim().isEmpty
                    ? item.avatarMembers
                    : const [],
                radius: 12,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: preview.isEmpty ? 56 : 64,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: t.border.withValues(alpha: 0.45),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.sans(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: t.text,
                                    ),
                                  ),
                                ),
                                if (item.isOwner) ...[
                                  const SizedBox(width: 6),
                                  _OwnerBadge(),
                                ],
                              ],
                            ),
                            if (preview.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.sans(
                                  size: 12,
                                  color: t.textMute,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: AppTheme.sans(
                                size: 12,
                                color: unread > 0 ? t.accent : t.textMute,
                              ),
                            ),
                          if (unread > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              height: 20,
                              constraints: const BoxConstraints(minWidth: 20),
                              padding: EdgeInsets.symmetric(
                                horizontal: unread > 99 ? 5 : 0,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: t.accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                textAlign: TextAlign.center,
                                style: AppTheme.sans(
                                  size: unread > 99 ? 9 : 11,
                                  weight: FontWeight.w700,
                                  color: t.onAccent,
                                ).copyWith(height: 1),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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

class _OwnerBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = _groupsListL10n(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: t.surfaceHover,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        l10n.groupsListOwnerBadge,
        style: AppTheme.sans(
          size: 10,
          weight: FontWeight.w600,
          color: t.textMute,
        ),
      ),
    );
  }
}

String _previewText(String raw) {
  return raw
      .replaceAll(RegExp(r'[*_`#~]'), '')
      .replaceAll(RegExp(r'\s*\n+\s*'), ' ')
      .trim();
}

String _formatTime(
  int ts,
  AppLocalizations l10n,
) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ts);
  final now = DateTime.now();
  final diffDays = now.difference(dt).inDays;
  if (diffDays == 0) return DateFormat('HH:mm').format(dt);
  if (diffDays == 1) return l10n.groupsListYesterday;
  if (diffDays < 7) {
    return DateFormat.E(l10n.localeName).format(dt);
  }
  return DateFormat.Md(l10n.localeName).format(dt);
}

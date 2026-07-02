import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_zh.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/block_list_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../providers/product_conversations_provider.dart';
import '../utils/group_creation_flow.dart';
import '../utils/group_avatar_members.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_display_name.dart';
import '../utils/product_conversation_navigation.dart';
import '../widgets/group_composite_avatar.dart';
import '../widgets/m3/m3_search_field.dart';

const _groupsToolbarHeight = 62.0;
const _groupSectionHeaderHeight = 28.0;
const _groupRowHeight = 52.0;
const _groupAvatarSize = 28.0;
const _groupsAlphabetIndexLift = 240.0;
const _groupsAlphabetIndexTop =
    _groupSectionHeaderHeight - _groupsAlphabetIndexLift;

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
    final blocks = ref.watch(blockListProvider).valueOrNull;
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
    ];
    for (final conversation in groupConversations) {
      final roomId = conversation.roomId.trim();
      if (roomId.isEmpty) continue;
      if (isGroupBlocked(blocks, roomId)) continue;
      if (directContactRoomIds.contains(roomId)) continue;
      final group = groupsByRoomId[roomId];
      if (!_isVisibleGroupForList(group, conversation)) continue;
      final room = client.getRoomById(roomId);
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
                      : safeRoomDisplayName(room).isNotEmpty
                          ? safeRoomDisplayName(room)
                          : l10n.contactsGroups,
          avatarMembers: groupAvatarMembers?.members ??
              cachedGroupAvatarMembers(
                cachedMemberOrder: groupAvatarMemberOrders[roomId] ?? const [],
                cachedMemberAvatarUrls:
                    groupAvatarMemberAvatars[roomId] ?? const {},
              ),
          avatarUrl: avatarUrl,
          productConversation: _openableGroupConversationForList(conversation),
        ),
      );
    }

    final filtered = _query.isEmpty
        ? items
        : items
            .where((g) => g.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();
    final groupedItems = _groupItemsByInitial(filtered);
    final sectionKeys = groupedItems.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          _GroupsToolbar(
            title: l10n.contactsMyGroups,
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
                : Stack(
                    children: [
                      ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          for (final sectionKey in sectionKeys) ...[
                            _GroupSectionHeader(label: sectionKey),
                            for (final item in groupedItems[sectionKey]!)
                              _GroupRow(item: item),
                          ],
                        ],
                      ),
                      Positioned(
                        key: const ValueKey('groups_alphabet_index'),
                        top: _groupsAlphabetIndexTop,
                        right: 8,
                        bottom: 24,
                        child: _GroupsAlphabetIndex(
                          activeLetters: sectionKeys.toSet(),
                        ),
                      ),
                    ],
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
    this.avatarUrl = '',
    this.avatarMembers = const [],
    this.productConversation,
  });
  final String id;
  final String name;
  final String avatarUrl;
  final List<GroupCompositeAvatarMember> avatarMembers;
  final AsConversation? productConversation;
}

Map<String, List<_GroupItem>> _groupItemsByInitial(List<_GroupItem> items) {
  final grouped = <String, List<_GroupItem>>{};
  final sorted = [...items]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  for (final item in sorted) {
    final key = _groupInitial(item.name);
    grouped.putIfAbsent(key, () => []).add(item);
  }
  return grouped;
}

String _groupInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '#';
  final first = trimmed.characters.first.toUpperCase();
  final unit = first.codeUnitAt(0);
  if (unit >= 65 && unit <= 90) return first;
  return '#';
}

class _GroupSectionHeader extends StatelessWidget {
  const _GroupSectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: _groupSectionHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: AppTheme.sans(
              size: 16,
              weight: FontWeight.w600,
              color: t.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupsAlphabetIndex extends StatelessWidget {
  const _GroupsAlphabetIndex({required this.activeLetters});

  static const _letters = [
    '#',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  final Set<String> activeLetters;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return IgnorePointer(
      child: SizedBox(
        width: 12,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _letters
                .map(
                  (letter) => Text(
                    letter,
                    style: AppTheme.sans(
                      size: 10,
                      weight: activeLetters.contains(letter)
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color:
                          activeLetters.contains(letter) ? t.text : t.textMute,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.item});
  final _GroupItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final name = item.name;

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
                size: _groupAvatarSize,
                imageUrl: item.avatarUrl,
                stableCacheKey: 'group:${item.id}',
                members: item.avatarUrl.trim().isEmpty
                    ? item.avatarMembers
                    : const [],
                minimumSlots: 4,
                radius: 6,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: _groupRowHeight,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: t.border.withValues(alpha: 0.45),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 14,
                        weight: FontWeight.w500,
                        color: t.text,
                      ),
                    ),
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

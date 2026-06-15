import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../data/as_client.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_identity_label.dart';
import '../utils/direct_contact_status.dart';
import '../widgets/portal_avatar.dart';

final groupCreationSyncAfterCreateProvider = Provider<bool>((ref) => true);

Future<void> showCreateGroupFlow(BuildContext context, WidgetRef ref) async {
  final client = ref.read(matrixClientProvider);
  final contacts = _acceptedInviteContacts(ref.read(asSyncCacheProvider));
  final result = await showGeneralDialog<_CreateGroupResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, animation, secondaryAnimation) => _CreateGroupScreen(
      client: client,
      contacts: contacts,
    ),
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
  if (result == null || !context.mounted) return;

  try {
    final group = await ref.read(asClientProvider).createGroup(
          name: result.name,
          invite: result.inviteMxids,
        );
    final roomId = group.roomId;
    _ensureOptimisticGroupRoom(
      client,
      roomId: roomId,
      name: group.name.trim().isEmpty ? result.name : group.name,
      inviteMxids: result.inviteMxids,
    );
    _cacheCreatedGroup(ref, group, fallbackName: result.name);
    unawaited(_refreshCreatedGroupBootstrap(ref));
    if (ref.read(groupCreationSyncAfterCreateProvider)) {
      unawaited(client.oneShotSync().catchError((Object e) {
        debugPrint('sync after group create failed: $e');
      }));
    }
    if (context.mounted) {
      context.push('/group/${Uri.encodeComponent(roomId)}');
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('创建失败: $e')),
    );
  }
}

Future<void> _refreshCreatedGroupBootstrap(WidgetRef ref) async {
  try {
    final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
    ref
        .read(asSyncCacheProvider.notifier)
        .update((state) => state.copyWith(bootstrap: bootstrap));
  } catch (e) {
    debugPrint('AS bootstrap refresh after group create failed: $e');
  }
}

void _cacheCreatedGroup(
  WidgetRef ref,
  AsGroupResult group, {
  required String fallbackName,
}) {
  final roomId = group.roomId.trim();
  if (roomId.isEmpty) return;
  ref.read(asSyncCacheProvider.notifier).update((state) {
    final bootstrap = state.bootstrap;
    if (bootstrap == null) return state;
    final groups = [
      for (final item in bootstrap.groups)
        if (item.roomId.trim() != roomId) item,
      AsSyncRoomSummary(
        roomId: roomId,
        name: group.name.trim().isEmpty ? fallbackName : group.name,
        avatarUrl: '',
        unreadCount: 0,
        lastActivityAt: DateTime.now().toUtc(),
        isOwned: group.role.trim().isEmpty || group.role == 'owner',
      ),
    ];
    return state.copyWith(
      bootstrap: AsSyncBootstrap(
        syncedAt: bootstrap.syncedAt,
        user: bootstrap.user,
        rooms: bootstrap.rooms,
        contacts: bootstrap.contacts,
        groups: groups,
        channels: bootstrap.channels,
        pending: bootstrap.pending,
      ),
    );
  });
}

List<AsSyncContact> _acceptedInviteContacts(AsSyncCacheState syncCache) {
  return (syncCache.bootstrap?.contacts ?? const <AsSyncContact>[])
      .where(
        (contact) =>
            contact.status == 'accepted' && contact.userId.trim().isNotEmpty,
      )
      .toList(growable: false);
}

void _ensureOptimisticGroupRoom(
  Client client, {
  required String roomId,
  required String name,
  required List<String> inviteMxids,
}) {
  final existing = client.getRoomById(roomId);
  final room =
      existing ?? Room(id: roomId, client: client, membership: Membership.join);
  if (existing == null) {
    client.rooms.add(room);
  } else {
    room.membership = Membership.join;
  }
  final self = client.userID;
  final sender = self ?? (inviteMxids.isNotEmpty ? inviteMxids.first : roomId);
  if (self != null && self.isNotEmpty) {
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: self,
        stateKey: self,
        content: {'membership': Membership.join.name},
      ),
    );
  }
  for (final mxid in inviteMxids) {
    room.setState(
      StrippedStateEvent(
        type: EventTypes.RoomMember,
        senderId: sender,
        stateKey: mxid,
        content: {'membership': Membership.invite.name},
      ),
    );
  }
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomName,
      senderId: sender,
      stateKey: '',
      content: {'name': name},
    ),
  );
  room.setState(
    StrippedStateEvent(
      type: productRoomKindEventType,
      senderId: sender,
      stateKey: '',
      content: {'kind': 'group'},
    ),
  );
  room.setState(
    StrippedStateEvent(
      type: EventTypes.RoomCreate,
      senderId: sender,
      stateKey: '',
      content: {'creator': sender},
    ),
  );
  room.lastEvent = Event(
    room: room,
    eventId: '\$optimistic-${DateTime.now().microsecondsSinceEpoch}',
    senderId: sender,
    type: EventTypes.RoomCreate,
    originServerTs: DateTime.now(),
    content: const {},
  );
}

class _CreateGroupResult {
  const _CreateGroupResult({
    required this.name,
    required this.inviteMxids,
  });

  final String name;
  final List<String> inviteMxids;
}

class _CreateGroupScreen extends StatefulWidget {
  const _CreateGroupScreen({
    required this.client,
    required this.contacts,
  });

  final Client client;
  final List<AsSyncContact> contacts;

  @override
  State<_CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<_CreateGroupScreen> {
  final TextEditingController _queryController = TextEditingController();
  final Set<String> _selectedMxids = <String>{};

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final filteredContacts = _filteredContacts();
    final groupedContacts = _groupCreateContacts(filteredContacts);
    final sectionKeys = groupedContacts.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });
    final canComplete = _selectedMxids.isNotEmpty;

    return Material(
      color: const Color(0xFFEFEFF3),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 16,
                        top: 8,
                        child: _CreateGroupCircleButton(
                          tooltip: '返回',
                          icon: Symbols.arrow_back,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Text(
                        '发起群聊',
                        style: AppTheme.sans(
                          size: 16,
                          weight: FontWeight.w700,
                          color: const Color(0xFF262628),
                        ),
                      ),
                      Positioned(
                        right: 16,
                        top: 14,
                        child: _CreateGroupDoneButton(
                          enabled: canComplete,
                          onTap: canComplete ? _complete : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
                  child: _CreateGroupSearchField(controller: _queryController),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: widget.contacts.isEmpty
                      ? const _CreateGroupEmptyState(
                          title: '暂无可邀请联系人',
                          subtitle: '先添加好友后再发起群聊',
                        )
                      : filteredContacts.isEmpty
                          ? const _CreateGroupEmptyState(
                              title: '没有找到好友',
                              subtitle: '换个 ID、昵称或邮箱试试',
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
                              children: [
                                for (final sectionKey in sectionKeys) ...[
                                  _CreateGroupSectionHeader(sectionKey),
                                  ...groupedContacts[sectionKey]!.map(
                                    (contact) {
                                      final mxid = contact.userId.trim();
                                      return _CreateGroupContactRow(
                                        name: _contactName(contact),
                                        avatarUrl: avatarHttpUrl(
                                          widget.client,
                                          contact.avatarUrl,
                                        ),
                                        selected: _selectedMxids.contains(mxid),
                                        onTap: () => _toggle(mxid),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                ),
              ],
            ),
            if (filteredContacts.isNotEmpty)
              Positioned(
                top: 194,
                right: 10,
                bottom: 28,
                child: _CreateGroupAlphabetIndex(
                  activeLetters: sectionKeys.toSet(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<AsSyncContact> _filteredContacts() {
    final query = _queryController.text.trim().toLowerCase();
    final sorted = [...widget.contacts]..sort((a, b) {
        return _contactName(a).toLowerCase().compareTo(
              _contactName(b).toLowerCase(),
            );
      });
    if (query.isEmpty) return sorted;
    return sorted.where((contact) {
      final name = _contactName(contact).toLowerCase();
      return name.contains(query) ||
          contact.userId.toLowerCase().contains(query) ||
          contact.domain.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  String _contactName(AsSyncContact contact) {
    final mxid = contact.userId.trim();
    return contactDisplayNameFromIdentity(
      mxid: mxid,
      displayName: contact.displayName,
      domain: contact.domain,
    );
  }

  void _toggle(String mxid) {
    if (mxid.isEmpty) return;
    setState(() {
      if (_selectedMxids.contains(mxid)) {
        _selectedMxids.remove(mxid);
      } else {
        _selectedMxids.add(mxid);
      }
    });
  }

  void _complete() {
    if (_selectedMxids.isEmpty) return;
    final selectedContacts = widget.contacts
        .where((contact) => _selectedMxids.contains(contact.userId.trim()))
        .toList(growable: false);
    Navigator.of(context).pop(
      _CreateGroupResult(
        name: _defaultGroupName(selectedContacts),
        inviteMxids: _selectedMxids.toList(growable: false),
      ),
    );
  }
}

String _defaultGroupName(List<AsSyncContact> contacts) {
  final names = contacts
      .map(
        (contact) => contactDisplayNameFromIdentity(
          mxid: contact.userId.trim(),
          displayName: contact.displayName,
          domain: contact.domain,
        ),
      )
      .where((name) => name.trim().isNotEmpty)
      .toList(growable: false);
  if (names.isEmpty) return '群聊';
  final prefix = names.take(3).join('、');
  return contacts.length > 3 ? '$prefix等人的群聊' : '$prefix的群聊';
}

Map<String, List<AsSyncContact>> _groupCreateContacts(
  List<AsSyncContact> contacts,
) {
  final grouped = <String, List<AsSyncContact>>{};
  for (final contact in contacts) {
    final key = _createContactInitial(
      contactDisplayNameFromIdentity(
        mxid: contact.userId.trim(),
        displayName: contact.displayName,
        domain: contact.domain,
      ),
    );
    grouped.putIfAbsent(key, () => []).add(contact);
  }
  return grouped;
}

String _createContactInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '#';
  final first = trimmed.characters.first.toUpperCase();
  final code = first.codeUnitAt(0);
  return code >= 65 && code <= 90 ? first : '#';
}

class _CreateGroupCircleButton extends StatelessWidget {
  const _CreateGroupCircleButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.65),
        shape: const CircleBorder(),
        elevation: 7,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 40,
            child: Icon(icon, size: 24, color: const Color(0xFF262628)),
          ),
        ),
      ),
    );
  }
}

class _CreateGroupDoneButton extends StatelessWidget {
  const _CreateGroupDoneButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? const Color(0xFF2FA0D0) : const Color(0xFFA3A3A4),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 30,
          width: 48,
          child: Center(
            child: Text(
              '完成',
              style: AppTheme.sans(
                size: 12,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateGroupSearchField extends StatelessWidget {
  const _CreateGroupSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0x1F767680),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Symbols.search, size: 18, color: Color(0xFF999999)),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'ID/昵称/邮箱',
                hintStyle: AppTheme.sans(
                  size: 16,
                  color: const Color(0xFF999999),
                ),
                isCollapsed: true,
                border: InputBorder.none,
              ),
              style: AppTheme.sans(
                size: 16,
                color: const Color(0xFF262628),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateGroupSectionHeader extends StatelessWidget {
  const _CreateGroupSectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: AppTheme.sans(
              size: 16,
              weight: FontWeight.w700,
              color: const Color(0xFF262628),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateGroupContactRow extends StatelessWidget {
  const _CreateGroupContactRow({
    required this.name,
    required this.selected,
    required this.onTap,
    this.avatarUrl,
  });

  final String name;
  final String? avatarUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              PortalAvatar(
                seed: name,
                size: 28,
                imageUrl: avatarUrl,
                shape: AvatarShape.squircle,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.only(right: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE6E6E6), width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(
                            size: 14,
                            weight: FontWeight.w500,
                            color: const Color(0xFF262628),
                          ),
                        ),
                      ),
                      _CreateGroupCheck(selected: selected),
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

class _CreateGroupCheck extends StatelessWidget {
  const _CreateGroupCheck({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFF2FA0D0) : Colors.transparent,
        border: Border.all(
          color: selected ? const Color(0xFF2FA0D0) : const Color(0xFFE6E6E6),
          width: 1,
        ),
      ),
      child: selected
          ? const Icon(Symbols.check, size: 12, color: Colors.white)
          : null,
    );
  }
}

class _CreateGroupAlphabetIndex extends StatelessWidget {
  const _CreateGroupAlphabetIndex({required this.activeLetters});

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
                          : FontWeight.w500,
                      color: const Color(0xFF333333),
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

class _CreateGroupEmptyState extends StatelessWidget {
  const _CreateGroupEmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.group_add,
              size: 38,
              color: const Color(0xFFA3A3A4).withValues(alpha: 0.86),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w700,
                color: const Color(0xFF262628),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 13, color: const Color(0xFF999999)),
            ),
          ],
        ),
      ),
    );
  }
}

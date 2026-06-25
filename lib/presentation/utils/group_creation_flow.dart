import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../home/conversation_summary_writer.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_identity_label.dart';
import '../utils/direct_contact_status.dart';
import '../utils/product_conversation_navigation.dart';
import '../utils/product_conversation_summary_writer.dart';
import '../groups/group_invite_content.dart';
import '../widgets/m3/m3_search_field.dart';
import '../widgets/group_composite_avatar.dart';
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
    var productConversation = group.productConversation;
    final invitedContacts =
        _contactsForInviteMxids(contacts, result.inviteMxids);
    if (result.inviteMxids.isNotEmpty) {
      final invitedGroup = await ref.read(asClientProvider).inviteGroupMembers(
            roomId: roomId,
            invite: result.inviteMxids,
          );
      productConversation =
          invitedGroup.productConversation ?? productConversation;
      final currentUserProfile =
          await ref.read(currentUserProfileProvider.future).catchError(
                (_) => null,
              );
      _sendGroupInviteCards(
        client,
        contacts: invitedContacts,
        groupRoomId: roomId,
        groupName: group.name.trim().isEmpty ? result.name : group.name,
        inviterAvatarUrl: profileAvatarHttpUrl(
              currentUserProfile,
              client,
            ) ??
            '',
      );
    }
    final resolvedConversation = productConversation ??
        _fallbackGroupConversation(
          group,
          fallbackName: result.name,
          inviteCount: result.inviteMxids.length,
        );
    _ensureOptimisticGroupRoom(
      client,
      roomId: roomId,
      name: group.name.trim().isEmpty ? result.name : group.name,
    );
    _cacheCreatedGroup(
      ref,
      group,
      fallbackName: result.name,
    );
    await recordProductConversationMutation(ref, resolvedConversation);
    unawaited(_refreshCreatedGroupBootstrap(ref));
    if (ref.read(groupCreationSyncAfterCreateProvider)) {
      unawaited(client.oneShotSync().catchError((Object e) {
        debugPrint('sync after group create failed: $e');
      }));
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('群聊已创建')),
      );
      final route = productConversationRoute(resolvedConversation);
      if (route == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('群聊正在同步，请稍后重试')),
        );
        return;
      }
      context.push(route);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('创建失败: $e')),
    );
  }
}

List<AsSyncContact> _contactsForInviteMxids(
  List<AsSyncContact> contacts,
  List<String> inviteMxids,
) {
  final selected = inviteMxids
      .map((mxid) => mxid.trim())
      .where((mxid) => mxid.isNotEmpty)
      .toSet();
  return [
    for (final contact in contacts)
      if (selected.contains(contact.userId.trim())) contact,
  ];
}

void _sendGroupInviteCards(
  Client client, {
  required List<AsSyncContact> contacts,
  required String groupRoomId,
  required String groupName,
  String inviterAvatarUrl = '',
}) {
  final roomId = groupRoomId.trim();
  if (roomId.isEmpty || contacts.isEmpty) return;
  final title = groupName.trim().isEmpty ? '群聊' : groupName.trim();
  final inviterMxid = client.userID?.trim() ?? '';
  final sends = [
    for (final contact in contacts)
      _sendSingleGroupInviteCard(
        client,
        contact: contact,
        groupRoomId: roomId,
        groupName: title,
        inviterMxid: inviterMxid,
        inviterAvatarUrl: inviterAvatarUrl,
      ),
  ];
  unawaited(_observeGroupInviteCardSends(client, sends));
}

Future<void> _observeGroupInviteCardSends(
  Client client,
  List<Future<bool>> sends,
) async {
  final results = await Future.wait(sends);
  final sent = results.where((sent) => sent).length;
  final failed = results.length - sent;
  if (sent > 0) {
    unawaited(client.oneShotSync().catchError((Object e) {
      debugPrint('sync after group invite cards failed: $e');
    }));
  }
  if (failed > 0) {
    debugPrint(
      'group create invite cards partially failed: sent=$sent failed=$failed',
    );
  }
}

Future<bool> _sendSingleGroupInviteCard(
  Client client, {
  required AsSyncContact contact,
  required String groupRoomId,
  required String groupName,
  required String inviterMxid,
  String inviterAvatarUrl = '',
}) async {
  final directRoomId = contact.roomId.trim();
  if (directRoomId.isEmpty) {
    return false;
  }
  final directRoom = client.getRoomById(directRoomId);
  if (directRoom == null) {
    return false;
  }
  try {
    await directRoom.sendEvent({
      'msgtype': GroupInviteContent.msgTypeV1,
      'body': '邀请加入群聊\n$groupName',
      'group_room_id': groupRoomId,
      'group_name': groupName,
      if (inviterMxid.isNotEmpty) 'inviter_mxid': inviterMxid,
      if (inviterAvatarUrl.trim().isNotEmpty)
        'inviter_avatar_url': inviterAvatarUrl.trim(),
      'direct_room_id': directRoomId,
    });
    return true;
  } on Object catch (e) {
    debugPrint('send group invite card after group create failed: $e');
    return false;
  }
}

AsConversation _fallbackGroupConversation(
  AsGroupResult group, {
  required String fallbackName,
  required int inviteCount,
}) {
  final roomId = group.roomId.trim();
  return AsConversation(
    conversationId: _createdGroupConversationId(group),
    roomId: roomId,
    kind: asConversationKindGroup,
    lifecycle: 'active',
    title: group.name.trim().isEmpty ? fallbackName : group.name.trim(),
    avatarUrl: group.productConversation?.avatarUrl.trim() ?? '',
    lastActivityAt: DateTime.now().toUtc(),
    memberCount: group.memberCount > 0 ? group.memberCount : inviteCount + 1,
    membership: 'join',
    role: group.role.trim().isEmpty ? 'owner' : group.role.trim(),
    hydrationState: 'ready',
    capabilities: const AsConversationCapabilities(
      open: true,
      send: true,
      sendMedia: true,
      call: true,
      invite: true,
      manageMembers: true,
      rename: true,
      removeMembers: true,
      leave: true,
    ),
  );
}

String _createdGroupConversationId(AsGroupResult group) {
  final operationConversationId = group.operation.conversationId.trim();
  if (operationConversationId.isNotEmpty) return operationConversationId;
  final roomId = group.roomId.trim();
  return roomId.isEmpty ? '' : 'group:$roomId';
}

Future<void> _refreshCreatedGroupBootstrap(WidgetRef ref) async {
  try {
    final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
    ref
        .read(asSyncCacheProvider.notifier)
        .update((state) => state.copyWith(bootstrap: bootstrap));
  } catch (e) {
    debugPrint('P2P bootstrap refresh after group create failed: $e');
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
        avatarUrl: group.productConversation?.avatarUrl.trim() ?? '',
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
  final sender = self ?? roomId;
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
      type: nativeRoomProfileEventType,
      senderId: sender,
      stateKey: '',
      content: {
        'room_type': nativeGroupRoomType,
        'room_id': room.id,
        'name': name,
      },
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

class _CreateGroupScreen extends ConsumerStatefulWidget {
  const _CreateGroupScreen({
    required this.client,
    required this.contacts,
  });

  final Client client;
  final List<AsSyncContact> contacts;

  @override
  ConsumerState<_CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<_CreateGroupScreen> {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final FocusNode _groupNameFocusNode = FocusNode();
  final Set<String> _selectedMxids = <String>{};
  bool _showGroupSetup = false;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
    _groupNameController.addListener(_onGroupNameChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onQueryChanged);
    _groupNameController.removeListener(_onGroupNameChanged);
    _queryController.dispose();
    _groupNameController.dispose();
    _groupNameFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() => setState(() {});
  void _onGroupNameChanged() => setState(() {});

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
    final selectedContacts = _selectedContacts();
    final currentUserProfile =
        ref.watch(currentUserProfileProvider).valueOrNull;

    final t = context.tk;
    return Material(
      color: t.surfaceHover,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  SizedBox(
                    height: 56,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 16,
                          top: 4,
                          child: _CreateGroupCircleButton(
                            tooltip: '返回',
                            icon: Symbols.arrow_back,
                            onTap: _showGroupSetup
                                ? () => setState(() => _showGroupSetup = false)
                                : () => Navigator.of(context).pop(),
                          ),
                        ),
                        Positioned.fill(
                          top: 13,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Text(
                              _showGroupSetup ? '创建群聊' : '发起群聊',
                              style: AppTheme.sans(
                                size: _showGroupSetup ? 20 : 16,
                                weight: FontWeight.w700,
                                color: t.text,
                              ),
                            ),
                          ),
                        ),
                        if (_showGroupSetup)
                          const Positioned(
                            right: 16,
                            top: 10,
                            child: SizedBox(width: 48, height: 30),
                          )
                        else
                          Positioned(
                            right: 16,
                            top: 10,
                            child: _CreateGroupDoneButton(
                              enabled: canComplete,
                              count: _selectedMxids.length,
                              onTap: canComplete ? _showSetup : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_showGroupSetup)
                    Expanded(
                      child: _CreateGroupSetupStep(
                        client: widget.client,
                        currentUserProfile: currentUserProfile,
                        controller: _groupNameController,
                        focusNode: _groupNameFocusNode,
                        selectedContacts: selectedContacts,
                        contactName: _contactName,
                        contactAvatarUrl: (contact) =>
                            contactListAvatarUrl(widget.client, contact),
                        canSubmit: canComplete,
                        onSubmit: canComplete ? _complete : null,
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: _CreateGroupSearchField(
                        controller: _queryController,
                      ),
                    ),
                    const SizedBox(height: 13),
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
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 0, 0, 28),
                                  children: [
                                    for (final sectionKey in sectionKeys) ...[
                                      _CreateGroupSectionHeader(sectionKey),
                                      ...groupedContacts[sectionKey]!.map(
                                        (contact) {
                                          final mxid = contact.userId.trim();
                                          return _CreateGroupContactRow(
                                            name: _contactName(contact),
                                            avatarUrl: contactListAvatarUrl(
                                              widget.client,
                                              contact,
                                            ),
                                            selected:
                                                _selectedMxids.contains(mxid),
                                            onTap: () => _toggle(mxid),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                    ),
                  ],
                ],
              ),
              if (!_showGroupSetup && filteredContacts.isNotEmpty)
                Positioned(
                  top: 193,
                  right: 12,
                  bottom: 30,
                  child: _CreateGroupAlphabetIndex(
                    activeLetters: sectionKeys.toSet(),
                  ),
                ),
            ],
          ),
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

  List<AsSyncContact> _selectedContacts() {
    return widget.contacts
        .where((contact) => _selectedMxids.contains(contact.userId.trim()))
        .toList(growable: false);
  }

  void _showSetup() {
    if (_selectedMxids.isEmpty) return;
    setState(() => _showGroupSetup = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _groupNameFocusNode.requestFocus();
    });
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
    final selectedContacts = _selectedContacts();
    final typedName = _groupNameController.text.trim();
    Navigator.of(context).pop(
      _CreateGroupResult(
        name:
            typedName.isEmpty ? _defaultGroupName(selectedContacts) : typedName,
        inviteMxids: _selectedMxids.toList(growable: false),
      ),
    );
  }
}

class _CreateGroupSetupStep extends StatelessWidget {
  const _CreateGroupSetupStep({
    required this.client,
    required this.currentUserProfile,
    required this.controller,
    required this.focusNode,
    required this.selectedContacts,
    required this.contactName,
    required this.contactAvatarUrl,
    required this.canSubmit,
    required this.onSubmit,
  });

  final Client client;
  final Profile? currentUserProfile;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<AsSyncContact> selectedContacts;
  final String Function(AsSyncContact contact) contactName;
  final String? Function(AsSyncContact contact) contactAvatarUrl;
  final bool canSubmit;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _CreateGroupInfoCard(
                client: client,
                currentUserProfile: currentUserProfile,
                controller: controller,
                focusNode: focusNode,
              ),
              const SizedBox(height: 12),
              _CreateGroupSelectedMembersCard(
                selectedContacts: selectedContacts,
                contactName: contactName,
                contactAvatarUrl: contactAvatarUrl,
              ),
            ],
          ),
        ),
        _CreateGroupSubmitBar(enabled: canSubmit, onTap: onSubmit),
      ],
    );
  }
}

class _CreateGroupInfoCard extends StatelessWidget {
  const _CreateGroupInfoCard({
    required this.client,
    required this.currentUserProfile,
    required this.controller,
    required this.focusNode,
  });

  final Client client;
  final Profile? currentUserProfile;
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final avatarMembers = <GroupCompositeAvatarMember>[
      GroupCompositeAvatarMember(
        seed: '我',
        imageUrl: profileAvatarHttpUrl(currentUserProfile, client),
      ),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          GroupCompositeAvatar(
            key: const ValueKey('create_group_composite_avatar'),
            seed: '我',
            size: 48,
            members: avatarMembers,
            minimumSlots: 4,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('create_group_name_field'),
              controller: controller,
              focusNode: focusNode,
              maxLength: 16,
              cursorColor: t.accent,
              style: AppTheme.sans(size: 17, color: t.text),
              decoration: InputDecoration(
                hintText: '请输入群聊名称',
                hintStyle: AppTheme.sans(size: 17, color: t.textMute),
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateGroupSelectedMembersCard extends StatelessWidget {
  const _CreateGroupSelectedMembersCard({
    required this.selectedContacts,
    required this.contactName,
    required this.contactAvatarUrl,
  });

  final List<AsSyncContact> selectedContacts;
  final String Function(AsSyncContact contact) contactName;
  final String? Function(AsSyncContact contact) contactAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Text(
                  '群成员',
                  style: AppTheme.sans(size: 15, color: t.textMute),
                ),
                const Spacer(),
                Text(
                  '${selectedContacts.length}人',
                  style: AppTheme.sans(size: 15, color: t.textMute),
                ),
              ],
            ),
          ),
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount:
                selectedContacts.length > 8 ? 8 : selectedContacts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 3,
              mainAxisExtent: 74,
            ),
            itemBuilder: (context, index) {
              final contact = selectedContacts[index];
              final name = contactName(contact);
              return Column(
                children: [
                  PortalAvatar(
                    seed: name,
                    size: 48,
                    imageUrl: contactAvatarUrl(contact),
                    shape: AvatarShape.squircle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(size: 10, color: t.textMute),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CreateGroupSubmitBar extends StatelessWidget {
  const _CreateGroupSubmitBar({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      color: t.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Material(
          color: enabled ? t.accent : t.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: Center(
                child: Text(
                  '完成创建',
                  style: AppTheme.sans(
                    size: 17,
                    weight: FontWeight.w700,
                    color: enabled ? t.onAccent : t.textMute,
                  ),
                ),
              ),
            ),
          ),
        ),
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
    final t = context.tk;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: t.surface.withValues(alpha: 0.78),
        shape: const CircleBorder(),
        elevation: 7,
        shadowColor: t.text.withValues(alpha: 0.12),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 40,
            child: Icon(icon, size: 24, color: t.text),
          ),
        ),
      ),
    );
  }
}

class _CreateGroupDoneButton extends StatelessWidget {
  const _CreateGroupDoneButton({
    required this.enabled,
    required this.count,
    required this.onTap,
  });

  final bool enabled;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: enabled ? t.accent : t.surfaceHigh,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 30,
          constraints: const BoxConstraints(minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: Text(
              count > 0 ? '完成($count)' : '完成',
              style: AppTheme.sans(
                size: 12,
                weight: FontWeight.w700,
                color: enabled ? t.onAccent : t.textMute,
              ).copyWith(letterSpacing: -0.4011),
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
    return M3SearchField(
      key: const ValueKey('create_group_search_field'),
      controller: controller,
      hint: 'ID/昵称/邮箱',
    );
  }
}

class _CreateGroupSectionHeader extends StatelessWidget {
  const _CreateGroupSectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
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
              color: t.text,
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
    final t = context.tk;
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
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: t.border, width: 0.5),
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
                            color: t.text,
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
    final t = context.tk;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? t.accent : Colors.transparent,
        border: Border.all(
          color: selected ? t.accent : t.border,
          width: 1,
        ),
      ),
      child: selected ? Icon(Symbols.check, size: 12, color: t.onAccent) : null,
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
                          : FontWeight.w500,
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

class _CreateGroupEmptyState extends StatelessWidget {
  const _CreateGroupEmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.group_add,
              size: 38,
              color: t.textMute.withValues(alpha: 0.86),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w700,
                color: t.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 13, color: t.textMute),
            ),
          ],
        ),
      ),
    );
  }
}

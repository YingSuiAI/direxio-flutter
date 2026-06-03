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
import '../utils/contact_identity_label.dart';
import '../utils/direct_contact_status.dart';
import '../widgets/m3/m3_card.dart';

final groupCreationSyncAfterCreateProvider = Provider<bool>((ref) => true);

Future<void> showCreateGroupFlow(BuildContext context, WidgetRef ref) async {
  final client = ref.read(matrixClientProvider);
  final contacts = _acceptedInviteContacts(ref.read(asSyncCacheProvider));
  final result = await showDialog<_CreateGroupResult>(
    context: context,
    builder: (ctx) => _CreateGroupDialog(contacts: contacts),
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

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog({required this.contacts});

  final List<AsSyncContact> contacts;

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedMxids = <String>{};

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final canCreate =
        _nameController.text.trim().isNotEmpty && _selectedMxids.isNotEmpty;
    return AlertDialog(
      title: Text(
        '创建群聊',
        style: AppTheme.sans(
          size: 17,
          weight: FontWeight.w600,
          color: t.text,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            M3InputField(
              controller: _nameController,
              icon: Symbols.group,
              hint: '群聊名称',
            ),
            const SizedBox(height: 16),
            Text(
              '选择成员',
              style: AppTheme.sans(
                size: 14,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '暂无可邀请联系人，先添加好友',
                  style: AppTheme.sans(size: 13, color: t.textMute),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.contacts.length,
                  itemBuilder: (context, index) {
                    final contact = widget.contacts[index];
                    final mxid = contact.userId.trim();
                    final selected = _selectedMxids.contains(mxid);
                    final name = contactDisplayNameFromIdentity(
                      mxid: mxid,
                      displayName: contact.displayName,
                      domain: contact.domain,
                    );
                    return CheckboxListTile(
                      value: selected,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: t.accent,
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(size: 15, color: t.text),
                      ),
                      subtitle: contact.domain.trim().isEmpty
                          ? null
                          : Text(
                              contact.domain.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(
                                size: 12,
                                color: t.textMute,
                              ),
                            ),
                      onChanged: (_) => setState(() {
                        if (selected) {
                          _selectedMxids.remove(mxid);
                        } else {
                          _selectedMxids.add(mxid);
                        }
                      }),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: canCreate
              ? () => Navigator.of(context).pop(
                    _CreateGroupResult(
                      name: _nameController.text.trim(),
                      inviteMxids: _selectedMxids.toList(growable: false),
                    ),
                  )
              : null,
          child: const Text('创建'),
        ),
      ],
    );
  }
}

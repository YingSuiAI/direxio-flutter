import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_identity_label.dart';
import '../utils/product_conversation_summary_writer.dart';
import 'group_invite_content.dart';
import '../widgets/portal_avatar.dart';

Future<void> showInviteGroupMembersFlow(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required Set<String> existingMemberMxids,
}) async {
  final trimmedRoomId = roomId.trim();
  if (trimmedRoomId.isEmpty) return;

  final candidates = groupMemberInviteCandidates(
    ref.read(asSyncCacheProvider),
    existingMemberMxids,
  );
  final client = ref.read(matrixClientProvider);
  final selected = await showDialog<List<String>>(
    context: context,
    builder: (ctx) => _InviteGroupMembersDialog(
      contacts: candidates,
      client: client,
    ),
  );
  if (selected == null || selected.isEmpty || !context.mounted) return;

  try {
    final selectedContacts = [
      for (final contact in candidates)
        if (selected.contains(contact.userId.trim())) contact,
    ];
    final sendableContacts = selectedContacts
        .where((contact) => contact.roomId.trim().isNotEmpty)
        .toList(growable: false);
    final skippedCount = selectedContacts.length - sendableContacts.length;
    final asClient = ref.read(asClientProvider);
    var recordedCount = 0;
    if (sendableContacts.isNotEmpty) {
      final result = await asClient.inviteGroupMembers(
        roomId: trimmedRoomId,
        invite: [
          for (final contact in sendableContacts) contact.userId.trim(),
        ],
      );
      recordedCount = result.invitedCount;
      await recordProductConversationMutation(
        ref,
        result.productConversation,
      );
    }
    var sentCount = 0;
    var failedCount = 0;
    final groupName = _groupInviteRoomName(ref, trimmedRoomId);
    final inviterMxid =
        ref.read(asSyncCacheProvider).bootstrap?.user.userId ?? '';
    final matrixClient = ref.read(matrixClientProvider);
    for (final contact in sendableContacts) {
      try {
        final directRoomId = contact.roomId.trim();
        final directRoom = matrixClient.getRoomById(directRoomId);
        if (directRoom == null) {
          throw StateError('目标私聊未同步到本地');
        }
        await directRoom.sendEvent({
          'msgtype': GroupInviteContent.msgTypeV1,
          'body': '邀请加入群聊\n$groupName',
          'group_room_id': trimmedRoomId,
          'group_name': groupName,
          if (inviterMxid.trim().isNotEmpty) 'inviter_mxid': inviterMxid,
          'direct_room_id': directRoomId,
        });
        sentCount++;
      } on Object {
        failedCount++;
      }
    }
    if (sentCount > 0) {
      unawaited(matrixClient.oneShotSync());
    }
    unawaited(_refreshBootstrapAfterInvite(ref));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _groupInviteResultMessage(
            sentCount: sentCount,
            skippedCount: skippedCount,
            failedCount: failedCount,
            recordedCount: recordedCount,
          ),
        ),
      ),
    );
  } on Object catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_groupInviteFailureMessage(e))),
    );
  }
}

String _groupInviteRoomName(WidgetRef ref, String roomId) {
  final syncCache = ref.read(asSyncCacheProvider);
  for (final group in syncCache.bootstrap?.groups ?? const []) {
    if (group.roomId.trim() == roomId.trim() && group.name.trim().isNotEmpty) {
      return group.name.trim();
    }
  }
  return '群聊';
}

String _groupInviteResultMessage({
  required int sentCount,
  required int skippedCount,
  required int failedCount,
  required int recordedCount,
}) {
  if (sentCount == 0 && recordedCount == 0 && skippedCount == 0) {
    return '所选联系人已在群聊中';
  }
  final parts = <String>['已发送 $sentCount 个群邀请卡片'];
  if (skippedCount > 0) parts.add('$skippedCount 个联系人缺少私聊，已跳过');
  if (failedCount > 0) parts.add('$failedCount 个发送失败');
  return parts.join('，');
}

String _groupInviteFailureMessage(Object error) {
  if (error is AsClientException && error.statusCode == 403) {
    final message = error.message.toLowerCase();
    if (message.contains('group invite requires owner or admin')) {
      return '该群只有群主可添加成员';
    }
  }
  return '发送群邀请失败: $error';
}

List<AsSyncContact> groupMemberInviteCandidates(
  AsSyncCacheState syncCache,
  Set<String> existingMemberMxids,
) {
  final existing = existingMemberMxids
      .map((mxid) => mxid.trim())
      .where((mxid) => mxid.isNotEmpty)
      .toSet();
  final seen = <String>{};
  final out = <AsSyncContact>[];
  final mergedMxids = {
    for (final contact in syncCache.contacts)
      if (contact.userId.trim().isNotEmpty) contact.userId.trim(),
  };
  final rawContacts = <AsSyncContact>[
    ...syncCache.contacts,
    for (final contact
        in syncCache.bootstrap?.contacts ?? const <AsSyncContact>[])
      if (!mergedMxids.contains(contact.userId.trim())) contact,
  ];
  for (final contact in rawContacts) {
    final mxid = contact.userId.trim();
    if (mxid.isEmpty ||
        contact.status.trim() != 'accepted' ||
        existing.contains(mxid) ||
        !seen.add(mxid)) {
      continue;
    }
    out.add(contact);
  }
  return List.unmodifiable(out);
}

Future<void> _refreshBootstrapAfterInvite(WidgetRef ref) async {
  try {
    final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.copyWith(bootstrap: bootstrap),
        );
  } on Object catch (e) {
    debugPrint('refresh bootstrap after group member invite failed: $e');
  }
}

class _InviteGroupMembersDialog extends StatefulWidget {
  const _InviteGroupMembersDialog({
    required this.contacts,
    required this.client,
  });

  final List<AsSyncContact> contacts;
  final Client client;

  @override
  State<_InviteGroupMembersDialog> createState() =>
      _InviteGroupMembersDialogState();
}

class _InviteGroupMembersDialogState extends State<_InviteGroupMembersDialog> {
  final Set<String> _selectedMxids = <String>{};

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AlertDialog(
      title: Text(
        '添加群成员',
        style: AppTheme.sans(
          size: 17,
          weight: FontWeight.w600,
          color: t.text,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.contacts.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '暂无可邀请联系人',
                  style: AppTheme.sans(size: 13, color: t.textMute),
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
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
                    return _InviteGroupContactRow(
                      name: name,
                      subtitle: contact.domain.trim(),
                      avatarUrl: avatarHttpUrl(
                        widget.client,
                        contact.avatarUrl,
                      ),
                      selected: selected,
                      onTap: () => setState(() {
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _selectedMxids.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    _selectedMxids.toList(growable: false),
                  ),
          child: const Text('发送邀请'),
        ),
      ],
    );
  }
}

class _InviteGroupContactRow extends StatelessWidget {
  const _InviteGroupContactRow({
    required this.name,
    required this.selected,
    required this.onTap,
    this.subtitle = '',
    this.avatarUrl,
  });

  final String name;
  final String subtitle;
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
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              PortalAvatar(
                seed: name,
                size: 32,
                imageUrl: avatarUrl,
                shape: AvatarShape.squircle,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: subtitle.isEmpty ? 52 : 58,
                  padding: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: t.surfaceHigh,
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
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(
                                size: 15,
                                weight: FontWeight.w500,
                                color: t.text,
                              ),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
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
                      const SizedBox(width: 12),
                      _InviteGroupCheck(selected: selected),
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

class _InviteGroupCheck extends StatelessWidget {
  const _InviteGroupCheck({required this.selected});

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

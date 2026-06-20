import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../utils/contact_identity_label.dart';

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
  final selected = await showDialog<List<String>>(
    context: context,
    builder: (ctx) => _InviteGroupMembersDialog(contacts: candidates),
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
    }
    var sentCount = 0;
    var failedCount = 0;
    final groupName = _groupInviteRoomName(ref, trimmedRoomId);
    final inviterMxid =
        ref.read(asSyncCacheProvider).bootstrap?.user.userId ?? '';
    for (final contact in sendableContacts) {
      try {
        await asClient.sendGroupInviteMessage(
          directRoomId: contact.roomId.trim(),
          groupRoomId: trimmedRoomId,
          groupName: groupName,
          inviterMxid: inviterMxid,
        );
        sentCount++;
      } on Object {
        failedCount++;
      }
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
      return '该群只有群主/管理员可添加成员';
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
  const _InviteGroupMembersDialog({required this.contacts});

  final List<AsSyncContact> contacts;

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

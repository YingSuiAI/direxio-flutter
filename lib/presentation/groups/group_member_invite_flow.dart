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
    final result = await ref.read(asClientProvider).inviteGroupMembers(
          roomId: trimmedRoomId,
          invite: selected,
        );
    unawaited(_refreshBootstrapAfterInvite(ref));
    if (!context.mounted) return;
    final count = result.invitedCount;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(count > 0 ? '已发送 $count 个群邀请' : '所选联系人已在群聊中'),
      ),
    );
  } on Object catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_groupInviteFailureMessage(e))),
    );
  }
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
  for (final contact in syncCache.acceptedContacts) {
    final mxid = contact.userId.trim();
    if (mxid.isEmpty || existing.contains(mxid) || !seen.add(mxid)) {
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

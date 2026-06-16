import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../chat/chat_glass_background.dart';
import '../groups/group_leave_flow.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../widgets/m3/glass_header.dart';

/// `s-group-manage` — 群管理 (index.html L809-841)
class GroupManagePage extends ConsumerStatefulWidget {
  const GroupManagePage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<GroupManagePage> createState() => _GroupManagePageState();
}

class _GroupManagePageState extends ConsumerState<GroupManagePage> {
  bool _leaving = false;
  bool _updatingInvitePolicy = false;

  @override
  Widget build(BuildContext context) {
    final currentInvitePolicy = _currentInvitePolicy();

    return Scaffold(
      backgroundColor: chatPageBackgroundColor(context),
      body: ChatGlassBackground(
        child: Column(
          children: [
            GlassHeader.detail(title: '群管理'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GroupedCard(
                      children: [
                        const _SectionHeader(label: '添加成员权限'),
                        _PolicyRow(
                          label: '群主/管理员可添加',
                          selected: currentInvitePolicy ==
                              groupInvitePolicyOwnerAdmin,
                          enabled: !_updatingInvitePolicy,
                          onTap: () => _updateInvitePolicy(
                            groupInvitePolicyOwnerAdmin,
                          ),
                        ),
                        const _DividerInset(),
                        _PolicyRow(
                          label: '所有成员可添加',
                          selected: currentInvitePolicy ==
                              groupInvitePolicyAllMembers,
                          enabled: !_updatingInvitePolicy,
                          onTap: () => _updateInvitePolicy(
                            groupInvitePolicyAllMembers,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _GroupedCard(
                      children: [
                        _RowDanger(
                          label: '退出群聊',
                          onTap: () => _confirmDismiss(context, () async {
                            if (_leaving) return;
                            setState(() => _leaving = true);
                            if (!context.mounted) return;
                            try {
                              await leaveGroupThroughAs(ref, widget.roomId);
                              if (!context.mounted) return;
                              context.go('/home');
                            } finally {
                              if (mounted) setState(() => _leaving = false);
                            }
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _currentInvitePolicy() {
    final groups = ref.watch(asSyncCacheProvider).bootstrap?.groups ??
        const <AsSyncRoomSummary>[];
    for (final group in groups) {
      if (group.roomId.trim() == widget.roomId.trim()) {
        return group.invitePolicy == groupInvitePolicyOwnerAdmin
            ? groupInvitePolicyOwnerAdmin
            : groupInvitePolicyAllMembers;
      }
    }
    return groupInvitePolicyAllMembers;
  }

  Future<void> _updateInvitePolicy(String invitePolicy) async {
    if (_updatingInvitePolicy || invitePolicy == _currentInvitePolicy()) {
      return;
    }
    setState(() => _updatingInvitePolicy = true);
    try {
      final result = await ref.read(asClientProvider).updateGroupInvitePolicy(
            roomId: widget.roomId,
            invitePolicy: invitePolicy,
          );
      final applied = result.invitePolicy.trim().isEmpty
          ? invitePolicy
          : result.invitePolicy.trim();
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withGroupInvitePolicy(widget.roomId, applied),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已更新添加成员权限')),
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新添加成员权限失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingInvitePolicy = false);
    }
  }

  Future<void> _confirmDismiss(
    BuildContext context,
    Future<void> Function() onConfirm,
  ) async {
    final t = context.tk;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          '退出群聊',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          '退出后你将不再接收该群聊消息。',
          style: AppTheme.sans(size: 15, color: t.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(
              '取消',
              style: AppTheme.sans(size: 15, color: t.textMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(
              '退出',
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: t.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await onConfirm();
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('退出群聊失败: $e')),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Text(
        label,
        style: AppTheme.sans(
          size: 13,
          weight: FontWeight.w600,
          color: t.textMute,
        ),
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final textColor = enabled ? t.text : t.textMute;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.sans(
                    size: 16,
                    weight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: t.text,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DividerInset extends StatelessWidget {
  const _DividerInset();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Divider(height: 1, thickness: 0.7, color: t.border),
    );
  }
}

class _GroupedCard extends StatelessWidget {
  const _GroupedCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _RowDanger extends StatelessWidget {
  const _RowDanger({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Center(
            child: Text(
              label,
              style: AppTheme.sans(
                size: 17,
                weight: FontWeight.w500,
                color: t.danger,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

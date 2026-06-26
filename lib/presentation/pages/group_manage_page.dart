import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_glass_background.dart';
import '../groups/group_leave_flow.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_display_name.dart';
import '../widgets/avatar_adjust_sheet.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/portal_avatar.dart';

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
  bool _muted = false;
  bool _muteChanging = false;
  bool _renaming = false;
  bool _avatarChanging = false;
  String? _groupNameOverride;
  String? _groupAvatarOverride;

  @override
  Widget build(BuildContext context) {
    final currentInvitePolicy = _currentInvitePolicy();
    final groupName = _currentGroupName();
    final groupAvatarUrl = _currentGroupAvatarUrl();
    final canDissolveGroup = _canDissolveGroup();

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
                        _AvatarNavRow(
                          label: '群头像',
                          name: groupName,
                          avatarUrl: groupAvatarUrl,
                          busy: _avatarChanging,
                          enabled: !_avatarChanging,
                          onTap: _pickGroupAvatar,
                        ),
                        const _DividerInset(),
                        _NavRow(
                          label: '群名称',
                          value: groupName.isEmpty ? null : groupName,
                          enabled: !_renaming,
                          onTap: () => _showRenameDialog(groupName),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _GroupedCard(
                      children: [
                        _SwitchRow(
                          label: '全员禁言',
                          value: _displayedGroupMuted(),
                          busy: _muteChanging,
                          onChanged: _setGroupMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _GroupedCard(
                      children: [
                        const _SectionHeader(label: '添加成员权限'),
                        _PolicyRow(
                          label: '群主可添加',
                          selected:
                              currentInvitePolicy == groupInvitePolicyOwner,
                          enabled: !_updatingInvitePolicy,
                          onTap: () => _updateInvitePolicy(
                            groupInvitePolicyOwner,
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
                          label: canDissolveGroup ? '解散群聊' : '退出群聊',
                          onTap: () => _confirmDismiss(
                            context,
                            title: canDissolveGroup ? '解散群聊' : '退出群聊',
                            content: canDissolveGroup
                                ? '解散后群聊将从当前服务移除。'
                                : '退出后你将不再接收该群聊消息。',
                            confirmLabel: canDissolveGroup ? '解散' : '退出',
                            failurePrefix:
                                canDissolveGroup ? '解散群聊失败' : '退出群聊失败',
                            onConfirm: () async {
                              if (_leaving) return;
                              setState(() => _leaving = true);
                              if (!context.mounted) return;
                              try {
                                if (canDissolveGroup) {
                                  await dissolveGroupThroughAs(
                                    ref,
                                    widget.roomId,
                                  );
                                } else {
                                  await leaveGroupThroughAs(ref, widget.roomId);
                                }
                                if (!context.mounted) return;
                                context.go('/home');
                              } finally {
                                if (mounted) setState(() => _leaving = false);
                              }
                            },
                          ),
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
        return group.invitePolicy == groupInvitePolicyOwner
            ? groupInvitePolicyOwner
            : groupInvitePolicyAllMembers;
      }
    }
    return groupInvitePolicyAllMembers;
  }

  bool _displayedGroupMuted() {
    if (_muteChanging) return _muted;
    final groups = ref.watch(asSyncCacheProvider).bootstrap?.groups ??
        const <AsSyncRoomSummary>[];
    for (final group in groups) {
      if (group.roomId.trim() == widget.roomId.trim()) {
        return group.muted;
      }
    }
    return _muted;
  }

  String _currentGroupName() {
    final override = _groupNameOverride?.trim() ?? '';
    if (override.isNotEmpty) return override;
    final room =
        ref.watch(matrixClientProvider).getRoomById(widget.roomId.trim());
    final roomName = safeRoomDisplayName(room).trim();
    if (roomName.isNotEmpty && !_looksLikeRoomId(roomName)) return roomName;
    final groups = ref.watch(asSyncCacheProvider).bootstrap?.groups ??
        const <AsSyncRoomSummary>[];
    for (final group in groups) {
      if (group.roomId.trim() == widget.roomId.trim()) {
        return group.name.trim();
      }
    }
    return '';
  }

  String _currentGroupAvatarUrl() {
    final override = _groupAvatarOverride?.trim() ?? '';
    if (override.isNotEmpty) {
      return avatarHttpUrl(ref.watch(matrixClientProvider), override) ??
          override;
    }
    final groups = ref.watch(asSyncCacheProvider).bootstrap?.groups ??
        const <AsSyncRoomSummary>[];
    for (final group in groups) {
      if (group.roomId.trim() == widget.roomId.trim()) {
        final avatar = group.avatarUrl.trim();
        if (avatar.isNotEmpty) {
          return avatarHttpUrl(ref.watch(matrixClientProvider), avatar) ??
              avatar;
        }
      }
    }
    final room =
        ref.watch(matrixClientProvider).getRoomById(widget.roomId.trim());
    return matrixContentHttpUrl(
            ref.watch(matrixClientProvider), room?.avatar) ??
        '';
  }

  bool _canDissolveGroup() {
    final room =
        ref.read(matrixClientProvider).getRoomById(widget.roomId.trim());
    final self = room?.client.userID;
    if (room == null || self == null || self.isEmpty) return false;
    if (room.getState(EventTypes.RoomCreate)?.senderId == self) return true;
    return room.getPowerLevelByUserId(self) >= 100;
  }

  Future<void> _showRenameDialog(String currentName) async {
    if (_renaming) return;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final next = await _showTextEditDialog(
      context,
      title: l10n?.groupManageNameTitle ?? '群名称',
      initialValue: currentName,
      hintText: l10n?.groupManageNameHint ?? '输入群名称',
    );
    if (!mounted || next == null) return;
    final name = next.trim();
    if (name.isEmpty) {
      _showSnack(l10n?.groupManageNameEmpty ?? '群名称不能为空');
      return;
    }
    await _renameGroup(name);
  }

  Future<void> _renameGroup(String name) async {
    if (_renaming) return;
    final previousName = _currentGroupName();
    setState(() => _renaming = true);
    try {
      final result = await ref.read(asClientProvider).updateGroupProfile(
            roomId: widget.roomId,
            name: name,
          );
      final appliedName = result.name.trim().isEmpty ? name : result.name;
      final client = ref.read(matrixClientProvider);
      final room = client.getRoomById(widget.roomId);
      setState(() => _groupNameOverride = appliedName);
      try {
        room?.setState(
          StrippedStateEvent(
            type: EventTypes.RoomName,
            senderId: client.userID ?? '',
            stateKey: '',
            content: {'name': appliedName},
          ),
        );
      } on Object {
        // P2P API is canonical here; local Matrix cache refresh is best-effort.
      }
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withGroupProfile(widget.roomId, name: appliedName),
          );
      if (!mounted) return;
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      _showSnack(l10n?.groupManageNameUpdated ?? '群名称已更新');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _groupNameOverride = previousName);
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      _showSnack(
        l10n?.groupManageNameUpdateFailed('$e') ?? '修改群名称失败: $e',
      );
    } finally {
      if (mounted) setState(() => _renaming = false);
    }
  }

  Future<void> _pickGroupAvatar() async {
    if (_avatarChanging) return;
    setState(() => _avatarChanging = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2048,
        maxHeight: 2048,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await showAvatarAdjustSheet(
        context,
        imageBytes: bytes,
        onConfirm: _updateGroupAvatar,
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      _showSnack(
        l10n?.groupManageAvatarUpdateFailed('$e') ?? '修改群头像失败: $e',
      );
    } finally {
      if (mounted) setState(() => _avatarChanging = false);
    }
  }

  Future<void> _updateGroupAvatar(Uint8List bytes) async {
    final client = ref.read(matrixClientProvider);
    final avatarMxc = await client.uploadContent(
      bytes,
      filename: 'group-avatar.png',
      contentType: 'image/png',
    );
    final avatarUrl = avatarMxc.toString();
    await ref.read(asClientProvider).updateGroupProfile(
          roomId: widget.roomId,
          avatarUrl: avatarUrl,
        );
    final room = client.getRoomById(widget.roomId);
    try {
      room?.setState(
        StrippedStateEvent(
          type: EventTypes.RoomAvatar,
          senderId: client.userID ?? '',
          stateKey: '',
          content: {'url': avatarUrl},
        ),
      );
    } on Object {
      // P2P API is canonical here; local Matrix cache refresh is best-effort.
    }
    if (!mounted) return;
    setState(() => _groupAvatarOverride = avatarUrl);
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.withGroupProfile(
            widget.roomId,
            avatarUrl: avatarUrl,
          ),
        );
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    _showSnack(l10n?.groupManageAvatarUpdated ?? '群头像已更新');
  }

  Future<void> _setGroupMuted(bool muted) async {
    if (_muteChanging) return;
    final previous = _displayedGroupMuted();
    setState(() {
      _muted = muted;
      _muteChanging = true;
    });
    try {
      final asClient = ref.read(asClientProvider);
      if (muted) {
        await asClient.muteGroup(widget.roomId);
      } else {
        await asClient.unmuteGroup(widget.roomId);
      }
      if (!mounted) return;
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withGroupMuted(widget.roomId, muted: muted),
          );
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      _showSnack(
        muted
            ? l10n?.groupManageMuteEnabled ?? '已开启全员禁言'
            : l10n?.groupManageMuteDisabled ?? '已解除全员禁言',
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _muted = previous);
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      _showSnack(
        muted
            ? l10n?.groupManageMuteEnableFailed('$e') ?? '开启全员禁言失败: $e'
            : l10n?.groupManageMuteDisableFailed('$e') ?? '解除全员禁言失败: $e',
      );
    } finally {
      if (mounted) setState(() => _muteChanging = false);
    }
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
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      _showSnack(l10n?.groupManageInvitePolicyUpdated ?? '已更新添加成员权限');
    } on Object catch (e) {
      if (!mounted) return;
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      _showSnack(
        l10n?.groupManageInvitePolicyUpdateFailed('$e') ?? '更新添加成员权限失败: $e',
      );
    } finally {
      if (mounted) setState(() => _updatingInvitePolicy = false);
    }
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDismiss(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmLabel,
    required String failurePrefix,
    required Future<void> Function() onConfirm,
  }) async {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          title,
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          content,
          style: AppTheme.sans(size: 15, color: t.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(
              l10n?.commonCancel ?? '取消',
              style: AppTheme.sans(size: 15, color: t.textMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(
              confirmLabel,
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
        SnackBar(content: Text('$failurePrefix: $e')),
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

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.value,
  });

  final String label;
  final String? value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
          child: Row(
            children: [
              Text(
                label,
                style: AppTheme.sans(
                  size: 16,
                  weight: FontWeight.w500,
                  color: enabled ? t.text : t.textMute,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (value != null) ...[
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              key: ValueKey('group_manage_nav_value_$label'),
                              value!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: AppTheme.sans(
                                size: 13,
                                color: t.textMute,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Icon(
                        key: ValueKey('group_manage_nav_chevron_$label'),
                        Symbols.chevron_right,
                        size: 20,
                        color: t.textMute,
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

class _AvatarNavRow extends StatelessWidget {
  const _AvatarNavRow({
    required this.label,
    required this.name,
    required this.avatarUrl,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String name;
  final String avatarUrl;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.sans(
                    size: 16,
                    weight: FontWeight.w500,
                    color: enabled ? t.text : t.textMute,
                  ),
                ),
              ),
              busy
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.accent,
                      ),
                    )
                  : PortalAvatar(
                      seed: name.isEmpty ? label : name,
                      size: 42,
                      imageUrl: avatarUrl.trim().isEmpty ? null : avatarUrl,
                      shape: AvatarShape.squircle,
                    ),
              const SizedBox(width: 6),
              Icon(
                key: ValueKey('group_manage_nav_chevron_$label'),
                Symbols.chevron_right,
                size: 20,
                color: t.textMute,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTheme.sans(size: 16, color: t.text),
            ),
          ),
          busy
              ? SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.accent,
                  ),
                )
              : Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: t.onAccent,
                  activeTrackColor: t.accent,
                ),
        ],
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

Future<String?> _showTextEditDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  required String hintText,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _GroupManageTextEditDialog(
      title: title,
      initialValue: initialValue,
      hintText: hintText,
    ),
  );
}

class _GroupManageTextEditDialog extends StatefulWidget {
  const _GroupManageTextEditDialog({
    required this.title,
    required this.initialValue,
    required this.hintText,
  });

  final String title;
  final String initialValue;
  final String hintText;

  @override
  State<_GroupManageTextEditDialog> createState() =>
      _GroupManageTextEditDialogState();
}

class _GroupManageTextEditDialogState
    extends State<_GroupManageTextEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return AlertDialog(
      title: Text(
        widget.title,
        style: AppTheme.sans(size: 17, weight: FontWeight.w600),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hintText),
        style: AppTheme.sans(size: 15, color: t.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n?.commonCancel ?? '取消',
            style: AppTheme.sans(size: 15, color: t.textMute),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(
            l10n?.commonSave ?? '保存',
            style: AppTheme.sans(
              size: 15,
              weight: FontWeight.w600,
              color: t.accent,
            ),
          ),
        ),
      ],
    );
  }
}

bool _looksLikeRoomId(String value) {
  final trimmed = value.trim();
  return trimmed.startsWith('!') && trimmed.contains(':');
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

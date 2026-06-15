import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../mock/mock_data.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_identity_label.dart';
import '../utils/direct_contact_status.dart';
import '../widgets/portal_avatar.dart';

class ContactDetailPage extends ConsumerStatefulWidget {
  const ContactDetailPage({
    super.key,
    required this.userId,
    this.fromChatAvatar = false,
  });

  final String userId;
  final bool fromChatAvatar;

  @override
  ConsumerState<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends ConsumerState<ContactDetailPage> {
  bool _muted = true;
  bool _blocked = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final client = ref.read(matrixClientProvider);
    final syncCache = ref.watch(asSyncCacheProvider);
    final userId = widget.userId;
    final acceptedContactForUser = syncCache.acceptedContactForUserId(userId);
    final acceptedRoom = acceptedContactForUser == null
        ? null
        : client.getRoomById(acceptedContactForUser.roomId);
    final room = acceptedRoom ??
        client.rooms.where((r) {
          final acceptedContact = syncCache.acceptedContactForRoom(r.id);
          return r.directChatMatrixID == userId ||
              productDirectPeerMxid(r) == userId ||
              acceptedContact?.userId == userId;
        }).firstOrNull;
    final agentMxid = portalAgentMxidForClient(client);
    final acceptedRoomIds = syncCache.acceptedDirectRoomIds;
    final canUseRealRoom = room != null &&
        acceptedContactForUser != null &&
        room.id == acceptedContactForUser.roomId &&
        acceptedRoomIds.contains(room.id) &&
        canSendDirectChatMessage(
          room,
          agentMxid: agentMxid,
          acceptedRoomIds: acceptedRoomIds,
        );
    final mock = room == null ? MockData.byMxid(userId) : null;
    final canUseMock = room == null && mock != null;
    final canOpenChat = canUseRealRoom || canUseMock;
    final acceptedContact = acceptedContactForUser ??
        (room == null ? null : syncCache.acceptedContactForRoom(room.id));
    final domain = userId.contains(':') ? userId.split(':').last : userId;
    final uidDomain = _contactDomain(userId, acceptedContact?.domain);
    final displayName = contactDisplayNameFromIdentity(
      mxid: userId,
      displayName: acceptedContact?.displayName ??
          room?.getLocalizedDisplayname() ??
          mock?.name ??
          '',
      domain: acceptedContact?.domain ?? domain,
      fallback: mock?.name ?? userId,
    );
    final peerMember = room?.unsafeGetUserFromMemoryOrFallback(userId);
    final avatarUrl = avatarHttpUrl(client, acceptedContact?.avatarUrl) ??
        (room == null
            ? mock?.avatarUrl
            : matrixContentHttpUrl(client, peerMember?.avatarUrl));
    final roomId = room?.id ?? mock?.id;
    final hideChatAvatarEntries = widget.fromChatAvatar;

    return Scaffold(
      backgroundColor: t.surfaceHover,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _ContactBackButton(
                        onTap: () => context.pop(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _UserHeader(
                      name: displayName,
                      badge: _roleBadge(acceptedContact?.domain),
                      uid: uidDomain,
                      onUidTap: () => _copyUid(context, uidDomain),
                      avatarUrl: avatarUrl,
                      seed: userId,
                    ),
                    const SizedBox(height: 24),
                    _QuickActionGrid(
                      onMessage: canOpenChat && roomId != null
                          ? () => context.go(
                                '/chat/${Uri.encodeComponent(roomId)}',
                              )
                          : null,
                      onVoice: room != null
                          ? () => context.push(
                                _callRoute(
                                  'call',
                                  room.id,
                                  userId,
                                  displayName,
                                ),
                              )
                          : null,
                      onVideo: room != null
                          ? () => context.push(
                                _callRoute(
                                  'video-call',
                                  room.id,
                                  userId,
                                  displayName,
                                ),
                              )
                          : null,
                      onSearch: hideChatAvatarEntries
                          ? null
                          : roomId == null
                              ? () => _toast(context, '缺少联系人房间信息，无法搜索聊天')
                              : () => context.push(
                                    '/room-search/${Uri.encodeComponent(roomId)}',
                                  ),
                    ),
                    const SizedBox(height: 26),
                    _ContactSettingRow(
                      label: '设置备注',
                      onTap: () => _showRemarkDialog(
                        context,
                        userId: userId,
                        currentName: displayName,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ContactSettingRow(
                      label: '推荐给朋友',
                      onTap: () => _shareContact(displayName, userId),
                    ),
                    if (!hideChatAvatarEntries) ...[
                      const SizedBox(height: 16),
                      _ContactSwitchRow(
                        label: '消息免打扰',
                        value: _muted,
                        onChanged: (value) => setState(() => _muted = value),
                      ),
                      const SizedBox(height: 16),
                      _ContactSwitchRow(
                        label: '屏蔽用户',
                        value: _blocked,
                        onChanged: (value) => setState(() => _blocked = value),
                        activeColor: t.surfaceHigh,
                      ),
                      const SizedBox(height: 16),
                      _ContactSettingRow(
                        label: '举报用户',
                        onTap: () => _showReportDialog(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _DeleteFriendButton(
              onTap: room == null
                  ? () => _toast(context, '删除好友失败: 缺少联系人房间信息')
                  : () => _confirmDeleteContact(context, room.id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteContact(
      BuildContext context, String roomId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '删除好友',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          '删除后将不再显示该联系人，会话关系也会同步更新。',
          style: AppTheme.sans(size: 15, color: context.tk.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '删除',
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: context.tk.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _deleteContact(context, roomId);
  }

  Future<void> _showReportDialog(BuildContext context) async {
    final submitted = await showDialog<bool>(
      context: context,
      barrierColor: context.tk.text.withValues(alpha: 0.7),
      builder: (_) => const _ReportReasonDialog(),
    );
    if (submitted == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('举报已提交')),
      );
    }
  }

  Future<void> _showRemarkDialog(
    BuildContext context, {
    required String userId,
    required String currentName,
  }) async {
    final controller = TextEditingController(text: currentName);
    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final t = dialogContext.tk;
        return AlertDialog(
          title: Text(
            '设置备注',
            style: AppTheme.sans(size: 17, weight: FontWeight.w600),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 32,
            decoration: InputDecoration(
              hintText: '输入备注名',
              hintStyle: AppTheme.sans(size: 15, color: t.textMute),
            ),
            style: AppTheme.sans(size: 15, color: t.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                '取消',
                style: AppTheme.sans(size: 15, color: t.textMute),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(
                '保存',
                style: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: t.accent,
                ),
              ),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!context.mounted || next == null) return;
    if (next.trim().isEmpty) {
      _toast(context, '备注不能为空');
      return;
    }
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.withContactDisplayName(
            userId: userId,
            displayName: next,
          ),
        );
    final bootstrap = ref.read(asSyncCacheProvider).bootstrap;
    if (bootstrap != null) {
      unawaited(
        ref
            .read(asBootstrapStoreProvider.future)
            .then((store) => store.write(bootstrap))
            .catchError((error) {
          debugPrint('persist contact remark bootstrap failed: $error');
        }),
      );
    }
    _toast(context, '备注已更新');
  }

  Future<void> _shareContact(String displayName, String userId) async {
    final name = displayName.trim().isEmpty ? userId : displayName.trim();
    await Share.share('推荐联系人：$name\n$userId');
  }

  Future<void> _copyUid(BuildContext context, String uid) async {
    await Clipboard.setData(ClipboardData(text: uid));
    if (!context.mounted) return;
    _toast(context, '已复制 UID');
  }

  Future<void> _deleteContact(BuildContext context, String roomId) async {
    final client = ref.read(matrixClientProvider);
    try {
      final contact = await ref.read(asClientProvider).deleteContact(roomId);
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withContactEntry(contact),
          );
      unawaited(
        ref.read(asBootstrapRepositoryProvider).refresh().then((bootstrap) {
          ref.read(asSyncCacheProvider.notifier).update(
                (state) => state.copyWith(bootstrap: bootstrap),
              );
        }).catchError((Object e) {
          debugPrint('refresh bootstrap after contact delete failed: $e');
        }),
      );
      final room = client.getRoomById(roomId);
      if (room != null) client.rooms.remove(room);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除好友')),
      );
      context.go('/home');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除好友失败: $e')),
      );
    }
  }
}

class _ContactBackButton extends StatelessWidget {
  const _ContactBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: 0.12),
            blurRadius: 36,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: t.surface.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Symbols.arrow_back,
                  size: 24,
                  color: t.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader({
    required this.name,
    required this.badge,
    required this.uid,
    required this.onUidTap,
    required this.seed,
    this.avatarUrl,
  });

  final String name;
  final String badge;
  final String uid;
  final VoidCallback onUidTap;
  final String seed;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      children: [
        PortalAvatar(
          seed: seed,
          size: 60,
          imageUrl: avatarUrl,
          shape: AvatarShape.squircle,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
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
                        size: 16,
                        weight: FontWeight.w600,
                        color: t.text,
                      ).copyWith(letterSpacing: -0.4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _RoleBadge(text: badge),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onUidTap,
                child: Text(
                  'UID $uid',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 14, color: t.textMute),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: t.accent),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTheme.sans(size: 10, color: t.accent).copyWith(
          letterSpacing: -0.4,
          height: 1.1,
        ),
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({
    required this.onMessage,
    required this.onVoice,
    required this.onVideo,
    required this.onSearch,
  });

  final VoidCallback? onMessage;
  final VoidCallback? onVoice;
  final VoidCallback? onVideo;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ContactQuickAction(
            icon: Symbols.chat_bubble,
            label: '发消息',
            onTap: onMessage,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ContactQuickAction(
            icon: Symbols.call,
            label: '音频通话',
            onTap: onVoice,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ContactQuickAction(
            icon: Symbols.videocam,
            label: '视频通话',
            onTap: onVideo,
          ),
        ),
        if (onSearch != null) ...[
          const SizedBox(width: 16),
          Expanded(
            child: _ContactQuickAction(
              icon: Symbols.search,
              label: '搜索聊天',
              onTap: onSearch,
            ),
          ),
        ],
      ],
    );
  }
}

class _ContactQuickAction extends StatelessWidget {
  const _ContactQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final t = context.tk;
    final color = enabled ? t.accent : t.accent.withValues(alpha: 0.35);
    return Material(
      color: t.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color, fill: 1),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactSettingRow extends StatelessWidget {
  const _ContactSettingRow({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: t.text,
                    ).copyWith(letterSpacing: -0.4),
                  ),
                ),
                Icon(
                  Symbols.chevron_right,
                  size: 24,
                  color: t.textMute.withValues(alpha: 0.65),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactSwitchRow extends StatelessWidget {
  const _ContactSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 12, right: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 14,
                weight: FontWeight.w500,
                color: t.text,
              ).copyWith(letterSpacing: -0.4),
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: t.surface,
              activeTrackColor: activeColor ?? t.accent,
              inactiveThumbColor: t.surface,
              inactiveTrackColor: t.surfaceHigh,
              trackOutlineColor: WidgetStateProperty.all(
                t.surface.withValues(alpha: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteFriendButton extends StatelessWidget {
  const _DeleteFriendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Material(
          color: t.surface.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.danger),
              ),
              child: Text(
                '删除好友',
                style: AppTheme.sans(
                  size: 14,
                  weight: FontWeight.w500,
                  color: t.danger,
                ).copyWith(letterSpacing: -0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportReasonDialog extends StatefulWidget {
  const _ReportReasonDialog();

  @override
  State<_ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<_ReportReasonDialog> {
  static const _reasons = [
    '骚扰/辱骂',
    '垃圾信息/广告',
    '色情/不当内容',
    '暴力内容',
    '欺诈',
    '其他',
  ];

  String _selected = '其他';
  final TextEditingController _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor: t.surface.withValues(alpha: 0),
      elevation: 0,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 343),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: BoxDecoration(
          color: t.surfaceHover,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '请选择举报原因',
                    style: AppTheme.sans(
                      size: 16,
                      weight: FontWeight.w500,
                      color: t.text,
                    ).copyWith(letterSpacing: -0.4),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(false),
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: Icon(
                      Symbols.close,
                      size: 18,
                      color: t.textMute,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final reason in _reasons) ...[
              if (reason == '其他')
                _OtherReasonTile(
                  selected: _selected == reason,
                  controller: _otherController,
                  onTap: () => setState(() => _selected = reason),
                )
              else
                _ReportReasonTile(
                  label: reason,
                  selected: _selected == reason,
                  onTap: () => setState(() => _selected = reason),
                ),
              if (reason != _reasons.last) const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '提交',
                  style: AppTheme.sans(
                    size: 14,
                    weight: FontWeight.w500,
                    color: t.onAccent,
                  ).copyWith(letterSpacing: -0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportReasonTile extends StatelessWidget {
  const _ReportReasonTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: t.text,
                    ).copyWith(letterSpacing: -0.4),
                  ),
                ),
                _ReportRadio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtherReasonTile extends StatelessWidget {
  const _OtherReasonTile({
    required this.selected,
    required this.controller,
    required this.onTap,
  });

  final bool selected;
  final TextEditingController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '其他',
                      style: AppTheme.sans(
                        size: 14,
                        weight: FontWeight.w500,
                        color: t.text,
                      ).copyWith(letterSpacing: -0.4),
                    ),
                  ),
                  _ReportRadio(selected: selected),
                ],
              ),
              if (selected) ...[
                const SizedBox(height: 8),
                Container(
                  height: 74,
                  decoration: BoxDecoration(
                    color: t.bg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: AppTheme.sans(
                      size: 12,
                      color: t.text,
                    ).copyWith(letterSpacing: -0.4),
                    decoration: InputDecoration(
                      hintText: '请填写举报原因',
                      hintStyle: AppTheme.sans(
                        size: 12,
                        color: t.textMute.withValues(alpha: 0.68),
                      ).copyWith(letterSpacing: -0.4),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportRadio extends StatelessWidget {
  const _ReportRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: selected ? t.accent : t.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? t.accent : t.border.withValues(alpha: 0.55),
          width: selected ? 0 : 1,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: t.onAccent,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

String _contactDomain(String userId, String? domain) {
  final value = domain?.trim() ?? '';
  if (value.isNotEmpty) return value;
  final idx = userId.indexOf(':');
  if (idx >= 0 && idx < userId.length - 1) {
    return userId.substring(idx + 1);
  }
  return userId;
}

String _roleBadge(String? domain) {
  final value = domain?.trim() ?? '';
  if (value.contains('agent') || value.contains('support')) return '客服经理';
  return '客服经理';
}

String _callRoute(String path, String roomId, String peerUserId, String name) {
  final room = Uri.encodeComponent(roomId);
  final peer = Uri.encodeQueryComponent(peerUserId);
  final displayName = Uri.encodeQueryComponent(name);
  return '/$path/$room?peer=$peer&name=$displayName';
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

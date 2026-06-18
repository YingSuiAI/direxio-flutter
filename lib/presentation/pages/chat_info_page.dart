import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../mock/mock_data.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../providers/p2p_api_provider.dart';
import '../utils/contact_display_name.dart';
import '../utils/avatar_url.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/report_reason_dialog.dart';

/// `s-chat-info` — 单聊聊天信息 (index.html L597-675)
///
/// 单聊点击右上角 more_vert 进入；区别于「好友个人详情」(contact_detail_page)。
/// 这里只放聊天本身的设置：免打扰 / 置顶 / 提醒 / 背景 / 清空记录。
class ChatInfoPage extends ConsumerStatefulWidget {
  const ChatInfoPage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<ChatInfoPage> createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends ConsumerState<ChatInfoPage> {
  bool _blocking = false;
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final client = ref.read(matrixClientProvider);
    final syncCache = ref.watch(asSyncCacheProvider);
    final room = client.getRoomById(widget.roomId);
    // 真房间走 Matrix；否则回退 mock 数据（id 以 mock_ 开头，例如 mock_jack）。
    final mock = room == null ? MockData.byId(widget.roomId) : null;
    final acceptedContact =
        room == null ? null : syncCache.acceptedContactForRoom(widget.roomId);
    final peerId =
        acceptedContact?.userId ?? room?.directChatMatrixID ?? mock?.mxid;
    final name = _chatInfoDisplayName(
      room: room,
      acceptedContact: acceptedContact,
      mockName: mock?.name,
      peerId: peerId,
      roomId: widget.roomId,
    );
    final peerMember =
        peerId == null ? null : room?.unsafeGetUserFromMemoryOrFallback(peerId);
    final avatarUrl = avatarHttpUrl(client, acceptedContact?.avatarUrl) ??
        (room == null
            ? mock?.avatarUrl
            : matrixContentHttpUrl(client, peerMember?.avatarUrl));
    final preferenceKey = room?.id ?? mock?.id ?? widget.roomId;
    final muted = ref.watch(mutedConversationIdsProvider).contains(
          preferenceKey,
        );
    final canUseContactActions = room != null && peerId != null;
    final isSelf = peerId != null && peerId == client.userID;
    final peerDomain = peerId == null
        ? widget.roomId
        : reportDomainForUserId(peerId, acceptedContact?.domain);

    return Scaffold(
      backgroundColor: t.surfaceHover,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ChatInfoHeader(onBack: () => context.pop()),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _PeerAvatar(
                      name: name,
                      avatarUrl: avatarUrl,
                      onTap: canUseContactActions
                          ? () => context.push(
                                '/contact/${Uri.encodeComponent(peerId)}?source=chat_avatar',
                              )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ChatInfoRow(
                    label: '搜索聊天记录',
                    onTap: () => context.push(
                      '/room-search/${Uri.encodeComponent(widget.roomId)}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ChatInfoRow(
                    label: '设置备注',
                    onTap: peerId == null
                        ? () => _toast(context, '缺少联系人信息，无法设置备注')
                        : () => _showRemarkDialog(
                              context,
                              userId: peerId,
                              currentName: name,
                            ),
                  ),
                  const SizedBox(height: 12),
                  _ChatInfoRow(
                    label: '推荐给朋友',
                    onTap: peerId == null || isSelf
                        ? () => _toast(context, '当前联系人无法推荐')
                        : () => _shareContact(name, peerId),
                  ),
                  const SizedBox(height: 12),
                  _ChatInfoSwitchRow(
                    label: '消息免打扰',
                    value: muted,
                    onChanged: (value) => setConversationMuted(
                      ref,
                      preferenceKey,
                      value,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ChatInfoRow(
                    label: '清空聊天记录',
                    onTap: () => _confirmClear(context),
                  ),
                  const SizedBox(height: 12),
                  _ChatInfoRow(
                    label: '拉黑用户',
                    onTap: room == null || isSelf
                        ? () => _toast(context, '拉黑用户失败: 缺少联系人房间信息')
                        : () => _confirmBlockContact(context, room.id),
                  ),
                  const SizedBox(height: 12),
                  _ChatInfoRow(
                    label: '举报用户',
                    onTap: peerId == null || isSelf
                        ? () => _toast(context, '当前用户无法举报')
                        : () => _showReportDialog(
                              context,
                              reportedDomain: peerDomain,
                            ),
                  ),
                ],
              ),
            ),
            if (!isSelf)
              Align(
                alignment: Alignment.bottomCenter,
                child: _DeleteFriendButton(
                  busy: _deleting,
                  onTap: room == null
                      ? () => _toast(context, '删除好友失败: 缺少联系人房间信息')
                      : () => _confirmDeleteContact(context, room.id),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRemarkDialog(
    BuildContext context, {
    required String userId,
    required String currentName,
  }) async {
    final next = await showDialog<String>(
      context: context,
      builder: (_) => _RemarkDialog(initialValue: currentName),
    );
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

  Future<void> _showReportDialog(
    BuildContext context, {
    required String reportedDomain,
  }) async {
    final reason = await showDialog<String>(
      context: context,
      barrierColor: context.tk.text.withValues(alpha: 0.7),
      builder: (_) => const ReportReasonDialog(),
    );
    if (reason == null || reason.trim().isEmpty || !context.mounted) return;

    final reporterDomain = reportDomainForUserId(
      ref.read(matrixClientProvider).userID ?? '',
      null,
    );
    try {
      await ref.read(p2pApiClientProvider).submitReport(
            reporterDomain: reporterDomain,
            reportedDomain: reportedDomain,
            targetType: 1,
            reason: reason.trim(),
          );
      if (!context.mounted) return;
      _toast(context, '举报已提交');
    } catch (error) {
      if (!context.mounted) return;
      _toast(context, '举报提交失败: $error');
    }
  }

  Future<void> _confirmDeleteContact(
    BuildContext context,
    String roomId,
  ) async {
    if (_deleting) return;
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
            child: Text(
              '取消',
              style: AppTheme.sans(size: 15, color: context.tk.textMute),
            ),
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
    setState(() => _deleting = true);
    try {
      await _removeContact(
        context,
        roomId,
        successMessage: '已删除好友',
        failurePrefix: '删除好友失败',
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _confirmBlockContact(
    BuildContext context,
    String roomId,
  ) async {
    if (_blocking) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '拉黑用户',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          '拉黑后将移除该联系人和会话关系。',
          style: AppTheme.sans(size: 15, color: context.tk.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              '取消',
              style: AppTheme.sans(size: 15, color: context.tk.textMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '拉黑',
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
    setState(() => _blocking = true);
    try {
      await _removeContact(
        context,
        roomId,
        successMessage: '已拉黑用户',
        failurePrefix: '拉黑用户失败',
      );
    } finally {
      if (mounted) setState(() => _blocking = false);
    }
  }

  Future<void> _removeContact(
    BuildContext context,
    String roomId, {
    required String successMessage,
    required String failurePrefix,
  }) async {
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
      _toast(context, successMessage);
      context.go('/home');
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, '$failurePrefix: $e');
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final t = context.tk;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          '清空聊天记录',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          '确定清空所有聊天记录？该操作不可恢复。',
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
              '清空',
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
      await ref
          .read(authStateNotifierProvider.notifier)
          .clearRoomChatHistory(widget.roomId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('聊天记录已清空')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清空聊天记录失败: $e')),
      );
    }
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String _chatInfoDisplayName({
  required Room? room,
  required AsSyncContact? acceptedContact,
  required String? mockName,
  required String? peerId,
  required String roomId,
}) {
  if (room != null && acceptedContact != null) {
    return directContactDisplayName(acceptedContact, room);
  }
  if (room != null && !room.isDirectChat) {
    return '正在同步联系人信息';
  }
  return room?.getLocalizedDisplayname() ?? mockName ?? peerId ?? roomId;
}

class _ChatInfoHeader extends StatelessWidget {
  const _ChatInfoHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
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
                child: Material(
                  color: t.surface.withValues(alpha: 0.65),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onBack,
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
          ),
          Text(
            '聊天信息',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(
              size: 20,
              weight: FontWeight.w600,
              color: t.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  const _PeerAvatar({required this.name, this.onTap, this.avatarUrl});
  final String name;
  final VoidCallback? onTap;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: PortalAvatar(
          seed: name,
          size: 60,
          shape: AvatarShape.squircle,
          imageUrl: avatarUrl,
        ),
      ),
    );
  }
}

class _ChatInfoRow extends StatelessWidget {
  const _ChatInfoRow({required this.label, required this.onTap});
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
            padding: const EdgeInsets.only(left: 12, right: 10),
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
                    ),
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

class _ChatInfoSwitchRow extends StatelessWidget {
  const _ChatInfoSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

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
              ),
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: t.surface,
              activeTrackColor: t.accent,
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
  const _DeleteFriendButton({required this.busy, required this.onTap});

  final bool busy;
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
            onTap: busy ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.danger),
              ),
              child: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.danger,
                      ),
                    )
                  : Text(
                      '删除好友',
                      style: AppTheme.sans(
                        size: 14,
                        weight: FontWeight.w500,
                        color: t.danger,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RemarkDialog extends StatefulWidget {
  const _RemarkDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_RemarkDialog> createState() => _RemarkDialogState();
}

class _RemarkDialogState extends State<_RemarkDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AlertDialog(
      title: Text(
        '设置备注',
        style: AppTheme.sans(size: 17, weight: FontWeight.w600),
      ),
      content: TextField(
        controller: _controller,
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
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '取消',
            style: AppTheme.sans(size: 15, color: t.textMute),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
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
  }
}

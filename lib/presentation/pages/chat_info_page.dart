import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_glass_background.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/block_list_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../providers/im_public_client_provider.dart';
import '../providers/matrix_message_clients_provider.dart';
import '../utils/contact_display_name.dart';
import '../utils/contact_identity_label.dart';
import '../utils/avatar_url.dart';
import '../widgets/center_toast.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/report_reason_dialog.dart';

AppLocalizations? _chatInfoL10n(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations);
}

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
    final l10n = _chatInfoL10n(context);
    final client = ref.read(matrixClientProvider);
    final syncCache = ref.watch(asSyncCacheProvider);
    final room = client.getRoomById(widget.roomId);
    if (room == null) {
      return Scaffold(
        backgroundColor: chatPageBackgroundColor(context),
        body: ChatGlassBackground(
          child: Center(
            child: Text(l10n?.chatInfoMissingConversation ?? '会话不存在'),
          ),
        ),
      );
    }

    final acceptedContact = syncCache.acceptedContactForRoom(widget.roomId);
    final peerId = acceptedContact?.userId ?? room.directChatMatrixID;
    final name = _chatInfoDisplayName(
      room: room,
      acceptedContact: acceptedContact,
      peerId: peerId,
      roomId: widget.roomId,
      l10n: l10n,
    );
    final avatarUrl = localRoomMemberAvatarHttpUrl(room, peerId) ??
        avatarHttpUrl(client, acceptedContact?.avatarUrl);
    final preferenceKey = room.id;
    final muted = ref.watch(mutedConversationIdsProvider).contains(
          preferenceKey,
        );
    final canUseContactActions = peerId != null;
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
                    child: _PeerIdentityHeader(
                      name: name,
                      uid: displayUidFromMxid(peerId ?? widget.roomId),
                      avatarUrl: avatarUrl,
                      onAvatarTap: canUseContactActions
                          ? () => context.push(
                                '/contact/${Uri.encodeComponent(peerId)}?source=chat_avatar',
                              )
                          : null,
                      onUidTap: () =>
                          _copyUid(context, peerId ?? widget.roomId),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ChatInfoRow(
                    label: l10n?.chatInfoSearchRecords ?? '搜索聊天记录',
                    onTap: () => context.push(
                      '/room-search/${Uri.encodeComponent(widget.roomId)}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ChatInfoRow(
                    label: l10n?.contactSetRemark ?? '设置备注',
                    onTap: peerId == null
                        ? () => _toast(
                              context,
                              l10n?.chatInfoContactMissingRemark ??
                                  '缺少联系人信息，无法设置备注',
                            )
                        : () => _showRemarkDialog(
                              context,
                              userId: peerId,
                              roomId: widget.roomId,
                              domain: acceptedContact?.domain ?? '',
                              currentName: name,
                            ),
                  ),
                  const SizedBox(height: 12),
                  _ChatInfoSwitchRow(
                    label: l10n?.contactMuteMessages ?? '消息免打扰',
                    value: muted,
                    onChanged: (value) => setConversationMuted(
                      ref,
                      preferenceKey,
                      value,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ChatInfoRow(
                    label: l10n?.chatInfoClearHistory ?? '清空聊天记录',
                    onTap: () => _confirmClear(context),
                  ),
                  const SizedBox(height: 12),
                  _ChatInfoRow(
                    label: l10n?.contactBlockUserDetail ?? '拉黑用户',
                    onTap: isSelf
                        ? () => _toast(
                              context,
                              l10n?.chatInfoSelfBlockDisabled ?? '当前用户无法拉黑',
                            )
                        : peerId == null
                            ? () => _toast(
                                  context,
                                  l10n?.contactRoomMissingBlock ??
                                      '拉黑用户失败: 缺少联系人信息',
                                )
                            : () => _confirmBlockContact(
                                  context,
                                  peerMxid: peerId,
                                  displayName: name,
                                  avatarUrl: avatarUrl,
                                ),
                  ),
                  const SizedBox(height: 12),
                  _ChatInfoRow(
                    label: l10n?.contactReportUser ?? '举报用户',
                    onTap: peerId == null || isSelf
                        ? () => _toast(
                              context,
                              l10n?.chatInfoSelfReportDisabled ?? '当前用户无法举报',
                            )
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
                  onTap: () => _confirmDeleteContact(context, room.id),
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
    required String roomId,
    required String domain,
    required String currentName,
  }) async {
    final l10n = _chatInfoL10n(context);
    final next = await showDialog<String>(
      context: context,
      builder: (_) => _RemarkDialog(initialValue: currentName),
    );
    if (!context.mounted || next == null) return;
    if (next.trim().isEmpty) {
      _toast(context, l10n?.contactRemarkEmpty ?? '备注不能为空');
      return;
    }
    final cleanRoomId = roomId.trim();
    if (cleanRoomId.isEmpty) {
      _toast(context, l10n?.contactRoomMissingRemark ?? '缺少联系人房间信息，无法保存备注');
      return;
    }
    ContactEntry updated;
    try {
      updated = await ref.read(asClientProvider).updateContact(
            roomId: cleanRoomId,
            displayName: next,
            domain: domain,
          );
    } catch (error) {
      if (!context.mounted) return;
      _toast(
        context,
        l10n?.contactRemarkUpdateFailed('$error') ?? '备注更新失败: $error',
      );
      return;
    }
    if (!context.mounted) return;
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.withContactDisplayName(
            userId: userId,
            displayName:
                updated.displayName.trim().isEmpty ? next : updated.displayName,
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
    _toast(context, l10n?.contactRemarkUpdated ?? '备注已更新');
  }

  Future<void> _showReportDialog(
    BuildContext context, {
    required String reportedDomain,
  }) async {
    final l10n = _chatInfoL10n(context);
    final result = await showDialog<ReportReasonResult>(
      context: context,
      barrierColor: context.tk.text.withValues(alpha: 0.7),
      builder: (_) => const ReportReasonDialog(),
    );
    if (result == null || result.reason.trim().isEmpty || !context.mounted) {
      return;
    }

    final reporterDomain = reportDomainForUserId(
      ref.read(matrixClientProvider).userID ?? '',
      null,
    );
    try {
      await ref.read(imPublicClientProvider).submitReport(
            reporterDomain: reporterDomain,
            reportedDomain: reportedDomain,
            targetType: 1,
            reason: result.reason.trim(),
            files: result.toImPublicFiles(),
          );
      if (!context.mounted) return;
      _toast(context, l10n?.contactReportSubmitted ?? '举报已提交');
    } catch (error) {
      if (!context.mounted) return;
      _toast(
        context,
        l10n?.contactReportSubmitFailed('$error') ?? '举报提交失败: $error',
      );
    }
  }

  Future<void> _confirmDeleteContact(
    BuildContext context,
    String roomId,
  ) async {
    if (_deleting) return;
    final l10n = _chatInfoL10n(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n?.contactDeleteConfirmTitle ?? '删除好友',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          l10n?.contactDeleteConfirmBody ?? '删除后将不再显示该联系人，会话关系也会同步更新。',
          style: AppTheme.sans(size: 15, color: context.tk.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n?.commonCancel ?? '取消',
              style: AppTheme.sans(size: 15, color: context.tk.textMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n?.contactDeleteAction ?? '删除',
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
        successMessage: l10n?.contactDeleted ?? '已删除好友',
        failureMessage: (error) =>
            l10n?.contactDeleteFailed(error) ?? '删除好友失败: $error',
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _confirmBlockContact(
    BuildContext context, {
    required String peerMxid,
    required String displayName,
    String? avatarUrl,
  }) async {
    if (_blocking) return;
    final l10n = _chatInfoL10n(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n?.contactBlockConfirmTitle ?? '拉黑用户',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          l10n?.contactBlockConfirmBody ?? '拉黑后将不能继续发送消息。',
          style: AppTheme.sans(size: 15, color: context.tk.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n?.commonCancel ?? '取消',
              style: AppTheme.sans(size: 15, color: context.tk.textMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n?.contactBlockAction ?? '拉黑',
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
      await _blockContact(
        context,
        peerMxid: peerMxid,
        displayName: displayName,
        avatarUrl: avatarUrl,
        successMessage: l10n?.contactBlocked ?? '已拉黑用户',
        failureMessage: (error) =>
            l10n?.contactBlockFailed(error) ?? '拉黑用户失败: $error',
      );
    } finally {
      if (mounted) setState(() => _blocking = false);
    }
  }

  Future<void> _removeContact(
    BuildContext context,
    String roomId, {
    required String successMessage,
    required String Function(String error) failureMessage,
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
      _toast(context, failureMessage('$e'));
    }
  }

  Future<void> _blockContact(
    BuildContext context, {
    required String peerMxid,
    required String displayName,
    String? avatarUrl,
    required String successMessage,
    required String Function(String error) failureMessage,
  }) async {
    try {
      await ref.read(blockListProvider.notifier).blockContact(
            peerMxid: peerMxid.trim(),
            displayName: displayName.trim(),
            avatarUrl: avatarUrl?.trim() ?? '',
          );
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withoutContact(
              peerMxid: peerMxid,
              roomId: widget.roomId,
            ),
          );
      final room = ref.read(matrixClientProvider).getRoomById(widget.roomId);
      if (room != null) {
        ref.read(matrixClientProvider).rooms.remove(room);
      }
      if (!context.mounted) return;
      _toast(context, successMessage);
      context.go('/home');
    } catch (e) {
      if (!context.mounted) return;
      final message = _alreadyBlockedMessage(e)
          ? _chatInfoL10n(context)?.blockAlreadyBlocked ?? '已经拉黑'
          : failureMessage('$e');
      _toast(context, message);
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final t = context.tk;
    final l10n = _chatInfoL10n(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          l10n?.chatInfoClearHistory ?? '清空聊天记录',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          l10n?.chatInfoClearHistoryConfirm ?? '确定清空所有聊天记录？该操作不可恢复。',
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
              l10n?.chatInfoClearHistoryAction ?? '清空',
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
      final clearedBeforeTs = DateTime.now().toUtc().millisecondsSinceEpoch + 1;
      await ref
          .read(matrixMessageVisibilityClientProvider)
          .clearRoom(widget.roomId);
      await ref.read(authStateNotifierProvider.notifier).clearRoomChatHistory(
            widget.roomId,
            clearedBeforeTs: clearedBeforeTs,
          );
      if (!context.mounted) return;
      showTopSnackBar(
        context,
        SnackBar(
          content: Text(l10n?.chatInfoClearHistoryCleared ?? '聊天记录已清空'),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!context.mounted) return;
      showTopSnackBar(
        context,
        SnackBar(
          content: Text(
            l10n?.chatInfoClearHistoryFailed('$e') ?? '清空聊天记录失败: $e',
          ),
        ),
      );
    }
  }
}

void _toast(BuildContext context, String message) {
  showCenterToast(context, message);
}

Future<void> _copyUid(BuildContext context, String uid) async {
  await Clipboard.setData(ClipboardData(text: displayUidFromMxid(uid)));
  if (!context.mounted) return;
  final l10n = _chatInfoL10n(context);
  _toast(context, l10n?.chatInfoUidCopied ?? '已复制 UID');
}

String _chatInfoDisplayName({
  required Room? room,
  required AsSyncContact? acceptedContact,
  required String? peerId,
  required String roomId,
  AppLocalizations? l10n,
}) {
  if (room != null && acceptedContact != null) {
    return directContactDisplayName(acceptedContact, room);
  }
  if (room != null && !room.isDirectChat) {
    return l10n?.chatInfoContactSyncing ?? '正在同步联系人信息';
  }
  final roomName = safeRoomDisplayName(room);
  return roomName.isNotEmpty ? roomName : peerId ?? roomId;
}

class _ChatInfoHeader extends StatelessWidget {
  const _ChatInfoHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = _chatInfoL10n(context);
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
            l10n?.chatInfoTitle ?? '聊天信息',
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

class _PeerIdentityHeader extends StatelessWidget {
  const _PeerIdentityHeader({
    required this.name,
    required this.uid,
    required this.onUidTap,
    this.onAvatarTap,
    this.avatarUrl,
  });

  final String name;
  final String uid;
  final VoidCallback onUidTap;
  final VoidCallback? onAvatarTap;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onAvatarTap,
              borderRadius: BorderRadius.circular(12),
              child: PortalAvatar(
                seed: name,
                size: 60,
                shape: AvatarShape.squircle,
                imageUrl: avatarUrl,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 20,
                    weight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onUidTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          uid,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(size: 13, color: t.textMute),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Symbols.content_copy,
                        size: 14,
                        color: t.textMute,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInfoRow extends StatelessWidget {
  const _ChatInfoRow({
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
    final l10n = _chatInfoL10n(context);
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
                      l10n?.contactDeleteFriend ?? '删除好友',
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
    final l10n = _chatInfoL10n(context);
    return AlertDialog(
      title: Text(
        l10n?.contactSetRemark ?? '设置备注',
        style: AppTheme.sans(size: 17, weight: FontWeight.w600),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 32,
        decoration: InputDecoration(
          hintText: l10n?.contactRemarkHint ?? '输入备注名',
          hintStyle: AppTheme.sans(size: 15, color: t.textMute),
        ),
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
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(
            l10n?.contactRemarkSave ?? '保存',
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

bool _alreadyBlockedMessage(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('already blocked') || message.contains('已经拉黑');
}

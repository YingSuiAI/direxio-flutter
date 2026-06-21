import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../chat/chat_glass_background.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/matrix_message_clients_provider.dart';
import '../utils/contact_display_name.dart';
import '../utils/avatar_url.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/portal_avatar.dart';

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
  bool _mute = false;
  bool _pinned = true;
  bool _alert = false;

  @override
  Widget build(BuildContext context) {
    final client = ref.read(matrixClientProvider);
    final syncCache = ref.watch(asSyncCacheProvider);
    final room = client.getRoomById(widget.roomId);
    if (room == null) {
      return Scaffold(
        backgroundColor: chatPageBackgroundColor(context),
        body: const ChatGlassBackground(
          child: Center(child: Text('会话不存在')),
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
    );
    final peerMember =
        peerId == null ? null : room.unsafeGetUserFromMemoryOrFallback(peerId);
    final avatarUrl = avatarHttpUrl(client, acceptedContact?.avatarUrl) ??
        matrixContentHttpUrl(client, peerMember?.avatarUrl);

    return Scaffold(
      backgroundColor: chatPageBackgroundColor(context),
      body: ChatGlassBackground(
        child: Column(
          children: [
            GlassHeader.detail(title: '聊天信息'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PeerHeader(
                      name: name,
                      avatarUrl: avatarUrl,
                      onTap: peerId != null
                          ? () => context.push(
                                '/contact/${Uri.encodeComponent(peerId)}',
                              )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _GroupedCard(
                            children: [
                              _RowChevron(
                                label: '查找聊天记录',
                                onTap: () => context.push(
                                  '/room-search/${Uri.encodeComponent(widget.roomId)}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _GroupedCard(
                            children: [
                              _RowSwitch(
                                label: '消息免打扰',
                                value: _mute,
                                onChanged: (v) => setState(() => _mute = v),
                              ),
                              _Divider(),
                              _RowSwitch(
                                label: '置顶聊天',
                                value: _pinned,
                                onChanged: (v) => setState(() => _pinned = v),
                              ),
                              _Divider(),
                              _RowSwitch(
                                label: '提醒',
                                value: _alert,
                                onChanged: (v) => setState(() => _alert = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _GroupedCard(
                            children: [
                              _RowChevron(label: '设置当前聊天背景', onTap: () {}),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _GroupedCard(
                            children: [
                              _RowDanger(
                                label: '清空聊天记录',
                                onTap: () => _confirmClear(context),
                              ),
                            ],
                          ),
                        ],
                      ),
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
      final clearedBeforeTs = DateTime.now().toUtc().millisecondsSinceEpoch + 1;
      await ref
          .read(matrixMessageVisibilityClientProvider)
          .clearRoom(widget.roomId);
      await ref.read(authStateNotifierProvider.notifier).clearRoomChatHistory(
            widget.roomId,
            clearedBeforeTs: clearedBeforeTs,
          );
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

String _chatInfoDisplayName({
  required Room? room,
  required AsSyncContact? acceptedContact,
  required String? peerId,
  required String roomId,
}) {
  if (room != null && acceptedContact != null) {
    return directContactDisplayName(acceptedContact, room);
  }
  if (room != null && !room.isDirectChat) {
    return '正在同步联系人信息';
  }
  return room?.getLocalizedDisplayname() ?? peerId ?? roomId;
}

class _PeerHeader extends StatelessWidget {
  const _PeerHeader({required this.name, this.onTap, this.avatarUrl});
  final String name;
  final VoidCallback? onTap;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              PortalAvatar(
                seed: name,
                size: 56,
                shape: AvatarShape.squircle,
                imageUrl: avatarUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 17,
                    weight: FontWeight.w500,
                    color: t.text,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Symbols.chevron_right, size: 22, color: t.border),
            ],
          ),
        ),
      ),
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

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: context.tk.border.withValues(alpha: 0.2));
}

class _RowChevron extends StatelessWidget {
  const _RowChevron({required this.label, required this.onTap});
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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.sans(size: 17, color: t.text),
                ),
              ),
              Icon(Symbols.chevron_right, size: 22, color: t.border),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowSwitch extends StatelessWidget {
  const _RowSwitch({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTheme.sans(size: 17, color: t.text)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: t.accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: t.secondaryContainer,
          ),
        ],
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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.sans(size: 17, color: t.danger),
                ),
              ),
              Icon(Symbols.chevron_right, size: 22, color: t.border),
            ],
          ),
        ),
      ),
    );
  }
}

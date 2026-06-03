import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../mock/mock_data.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_identity_label.dart';
import '../utils/direct_contact_status.dart';
import '../widgets/glass_list_tile.dart';
import '../widgets/m3/glass_header.dart';

class ContactDetailPage extends ConsumerWidget {
  const ContactDetailPage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final client = ref.read(matrixClientProvider);
    final syncCache = ref.watch(asSyncCacheProvider);
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
    final isWaitingForAccept =
        room != null && isPendingDirectContact(room, agentMxid: agentMxid);
    // 找不到真房间时按 mxid 回退到 mock，否则名字会显示成原始 mxid。
    final mock = room == null ? MockData.byMxid(userId) : null;
    final canUseMock = room == null && mock != null;
    final canOpenChat = canUseRealRoom || canUseMock;
    final acceptedContact = acceptedContactForUser ??
        (room == null ? null : syncCache.acceptedContactForRoom(room.id));
    // @username 取 userId 的 localpart（@xxx:domain → xxx）
    final localpart = userId.startsWith('@') && userId.contains(':')
        ? userId.substring(1, userId.indexOf(':'))
        : userId;
    // Node URL：用 mxid 后半段作为节点占位
    final domain = userId.contains(':') ? userId.split(':').last : userId;
    final displayName = contactDisplayNameFromIdentity(
      mxid: userId,
      displayName: acceptedContact?.displayName ??
          room?.getLocalizedDisplayname() ??
          mock?.name ??
          '',
      domain: acceptedContact?.domain ?? domain,
      fallback: mock?.name ?? userId,
    );
    final nodeUrl = 'Node: $domain';
    final initial = displayName.isNotEmpty
        ? displayName.characters.first.toUpperCase()
        : '?';
    final peerMember = room?.unsafeGetUserFromMemoryOrFallback(userId);
    final avatarUrl = avatarHttpUrl(client, acceptedContact?.avatarUrl) ??
        (room == null
            ? mock?.avatarUrl
            : matrixContentHttpUrl(client, peerMember?.avatarUrl));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(
            title: '个人信息',
            actions: [
              GlassHeaderButton(
                icon: Symbols.more_horiz,
                color: t.textMute,
                onTap: () {},
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 672),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 头像 + 基本信息
                      _ProfileHeader(
                        name: displayName,
                        initial: initial,
                        username: '@$localpart',
                        nodeUrl: nodeUrl,
                        avatarUrl: avatarUrl,
                      ),
                      // 快捷操作 —— 真房间用 room.id，mock 路径用 mock.id。
                      _QuickActions(
                        onMessage: canOpenChat
                            ? () {
                                final id = room?.id ?? mock?.id;
                                if (id != null) {
                                  context.go(
                                    '/chat/${Uri.encodeComponent(id)}',
                                  );
                                }
                              }
                            : null,
                        onHome: () => context.push(
                          '/contact-home/${Uri.encodeComponent(userId)}',
                        ),
                      ),
                      if (isWaitingForAccept)
                        const _RelationshipNotice(message: '等待对方接受后才能聊天'),
                      // 详细信息卡片
                      const Padding(
                        padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
                        child: _InfoGroup(
                          children: [
                            _InfoRow(label: '备注', value: 'Alice'),
                            _InfoRow(label: '地区', value: '上海'),
                            _InfoRow(
                              label: '个签',
                              value: '设计让世界更美好 ✨',
                              valueMuted: true,
                              valueSmall: true,
                            ),
                          ],
                        ),
                      ),
                      // 操作列表卡片
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                        child: _ActionGroup(
                          children: [
                            _ActionRow(label: '设置备注和标签', onTap: () {}),
                            _ActionRow(label: '朋友权限', onTap: () {}),
                            _ActionRow(label: '加入黑名单', onTap: () {}),
                            _ActionRow(
                              label: '删除联系人',
                              danger: true,
                              onTap: room != null
                                  ? () async {
                                      try {
                                        final contact = await ref
                                            .read(asClientProvider)
                                            .deleteContact(room.id);
                                        ref
                                            .read(asSyncCacheProvider.notifier)
                                            .update(
                                              (state) => state.withContactEntry(
                                                contact,
                                              ),
                                            );
                                        unawaited(
                                          ref
                                              .read(
                                                asBootstrapRepositoryProvider,
                                              )
                                              .refresh()
                                              .then((bootstrap) {
                                            ref
                                                .read(
                                                  asSyncCacheProvider.notifier,
                                                )
                                                .update(
                                                  (state) => state.copyWith(
                                                    bootstrap: bootstrap,
                                                  ),
                                                );
                                          }).catchError((Object e) {
                                            debugPrint(
                                              'refresh bootstrap after contact delete failed: $e',
                                            );
                                          }),
                                        );
                                        client.rooms.remove(room);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('已删除联系人'),
                                          ),
                                        );
                                        context.go('/home');
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('删除联系人失败: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  : () {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部：方形 72×72 头像 + 名字 + 在线点 + @username + Node URL
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.initial,
    required this.username,
    required this.nodeUrl,
    this.avatarUrl,
  });
  final String name;
  final String initial;
  final String username;
  final String nodeUrl;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: t.border.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // 方形 72×72 头像 —— 有图就用图，没图退回首字母色块
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: avatarUrl != null
                ? Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    width: 72,
                    height: 72,
                    errorBuilder: (_, __, ___) => Text(
                      initial,
                      style: AppTheme.sans(
                        size: 30,
                        weight: FontWeight.w600,
                        color: t.onAccent,
                      ),
                    ),
                  )
                : Text(
                    initial,
                    style: AppTheme.sans(
                      size: 30,
                      weight: FontWeight.w600,
                      color: t.onAccent,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(
                          size: 20,
                          weight: FontWeight.w600,
                          color: t.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: t.tertiaryFixed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 15, color: t.textMute),
                ),
                const SizedBox(height: 2),
                Text(
                  nodeUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 15, color: t.textMute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 中间快捷操作横排：发消息 + 主页。
class _QuickActions extends StatelessWidget {
  const _QuickActions({this.onMessage, required this.onHome});
  final VoidCallback? onMessage;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: t.border.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QuickAction(
            icon: Symbols.chat,
            label: '发消息',
            background: t.surfaceHover,
            iconColor: t.textMute,
            onTap: onMessage,
          ),
          _QuickAction(
            icon: Symbols.home,
            label: '主页',
            background: t.surfaceHover,
            iconColor: t.textMute,
            onTap: onHome,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.iconColor,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color background;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: enabled ? background : t.surfaceHover,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 24,
              color: enabled ? iconColor : t.textMute.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w500,
              color: enabled ? t.textMute : t.textMute.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationshipNotice extends StatelessWidget {
  const _RelationshipNotice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.accentCool.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: t.accentCool.withValues(alpha: 0.24)),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTheme.sans(size: 14, color: t.textMute),
        ),
      ),
    );
  }
}

/// 详细信息卡片组：surface 底 + 圆角 + 细边 + 内部分隔线
class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(children: children);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueMuted = false,
    this.valueSmall = false,
  });
  final String label;
  final String value;
  final bool valueMuted;
  final bool valueSmall;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GlassListTile(
      title: label,
      trailing: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.48,
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: AppTheme.sans(
            size: valueSmall ? 13 : 15,
            color: valueMuted ? t.textMute : t.text,
          ),
        ),
      ),
      showChevron: false,
      titleStyle:
          AppTheme.sans(size: 20, weight: FontWeight.w600, color: t.text),
    );
  }
}

/// 操作列表卡片
class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(children: children);
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, this.danger = false, this.onTap});
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GlassListTile(
      title: label,
      onTap: onTap,
      titleStyle: AppTheme.sans(
        size: 20,
        weight: FontWeight.w600,
        color: danger ? t.danger : t.text,
      ),
    );
  }
}

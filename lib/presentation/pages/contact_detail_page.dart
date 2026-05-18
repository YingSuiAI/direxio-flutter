import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../mock/mock_data.dart';
import '../providers/auth_provider.dart';
import '../widgets/m3/glass_header.dart';

class ContactDetailPage extends ConsumerWidget {
  const ContactDetailPage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final client = ref.read(matrixClientProvider);
    final room =
        client.rooms.where((r) => r.directChatMatrixID == userId).firstOrNull;
    // 找不到真房间时按 mxid 回退到 mock，否则名字会显示成原始 mxid。
    final mock = room == null ? MockData.byMxid(userId) : null;
    final displayName =
        room?.getLocalizedDisplayname() ?? mock?.name ?? userId;
    // @username 取 userId 的 localpart（@xxx:domain → xxx）
    final localpart = userId.startsWith('@') && userId.contains(':')
        ? userId.substring(1, userId.indexOf(':'))
        : userId;
    // Node URL：用 mxid 后半段作为节点占位
    final domain = userId.contains(':') ? userId.split(':').last : userId;
    final nodeUrl = 'Node: $domain';
    final initial =
        displayName.isNotEmpty ? displayName.characters.first.toUpperCase() : '?';

    return Scaffold(
      backgroundColor: t.bg,
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
                      ),
                      // 快捷操作 —— 真房间用 room.id，mock 路径用 mock.id。
                      _QuickActions(
                        onMessage: () {
                          final id = room?.id ?? mock?.id;
                          if (id != null) {
                            context.go('/chat/${Uri.encodeComponent(id)}');
                          }
                        },
                        onCall: () {
                          final id = room?.id ?? mock?.id;
                          if (id != null) {
                            context.push('/call/${Uri.encodeComponent(id)}');
                          }
                        },
                        onVideo: () {
                          final id = room?.id ?? mock?.id;
                          if (id != null) {
                            context.push('/call/${Uri.encodeComponent(id)}');
                          }
                        },
                      ),
                      // 详细信息卡片
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                                      await room.leave();
                                      if (context.mounted) context.pop();
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
  });
  final String name;
  final String initial;
  final String username;
  final String nodeUrl;

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
          // 方形 72×72 头像
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
            alignment: Alignment.center,
            child: Text(
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

/// 中间快捷操作横排（3 个圆按钮）
class _QuickActions extends StatelessWidget {
  const _QuickActions({this.onMessage, this.onCall, this.onVideo});
  final VoidCallback? onMessage;
  final VoidCallback? onCall;
  final VoidCallback? onVideo;

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
            iconFilled: true,
            background: t.accent,
            iconColor: t.onAccent,
            onTap: onMessage,
          ),
          _QuickAction(
            icon: Symbols.call,
            label: '语音',
            background: t.surfaceHover,
            iconColor: t.textMute,
            onTap: onCall,
          ),
          _QuickAction(
            icon: Symbols.videocam,
            label: '视频',
            background: t.surfaceHover,
            iconColor: t.textMute,
            onTap: onVideo,
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
    this.iconFilled = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color background;
  final Color iconColor;
  final bool iconFilled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
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
              color: background,
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
              color: iconColor,
              fill: iconFilled ? 1 : 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w500,
              color: t.textMute,
            ),
          ),
        ],
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
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(children.length, (i) {
          return Column(
            children: [
              children[i],
              if (i != children.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: t.border.withValues(alpha: 0.2),
                ),
            ],
          );
        }),
      ),
    );
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: AppTheme.sans(size: 15, color: t.textMute)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: valueSmall
                  ? AppTheme.sans(
                      size: 15, color: valueMuted ? t.textMute : t.text)
                  : AppTheme.sans(
                      size: 17, color: valueMuted ? t.textMute : t.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作列表卡片
class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(children.length, (i) {
          return Column(
            children: [
              children[i],
              if (i != children.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: t.border.withValues(alpha: 0.2),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    this.danger = false,
    this.onTap,
  });
  final String label;
  final bool danger;
  final VoidCallback? onTap;

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
                  style: AppTheme.sans(
                    size: 17,
                    color: danger ? t.danger : t.text,
                  ),
                ),
              ),
              Icon(Symbols.chevron_right, size: 22, color: t.textMute),
            ],
          ),
        ),
      ),
    );
  }
}

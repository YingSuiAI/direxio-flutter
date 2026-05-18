/// 联系人详情 —— 对应 s-chat-info / s-contact-profile。M3 风格。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';
import '../widgets/portal_avatar.dart';

class ContactDetailPage extends ConsumerWidget {
  const ContactDetailPage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final client = ref.read(matrixClientProvider);
    final room = client.rooms
        .where((r) => r.directChatMatrixID == userId)
        .firstOrNull;
    final displayName = room?.getLocalizedDisplayname() ?? userId;
    final domain = userId.contains(':') ? userId.split(':').last : userId;

    return Scaffold(
      body: Column(
        children: [
          GlassHeader.detail(title: '联系人信息'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Column(
                  children: [
                    PortalAvatar(seed: displayName, size: 96),
                    const SizedBox(height: 12),
                    Text(displayName,
                        style: AppTheme.sans(
                            size: 20,
                            weight: FontWeight.w600,
                            color: t.text)),
                    const SizedBox(height: 4),
                    Text(domain,
                        style:
                            AppTheme.sans(size: 13, color: t.textMute)),
                  ],
                ),
                const SizedBox(height: 24),
                if (room != null) ...[
                  M3Card(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _ActionRow(
                          icon: Symbols.chat_bubble,
                          label: '发消息',
                          color: t.accent,
                          onTap: () => context.go(
                              '/chat/${Uri.encodeComponent(room.id)}'),
                        ),
                        Divider(
                            height: 1, color: t.border, indent: 52),
                        _ActionRow(
                          icon: Symbols.videocam,
                          label: '视频通话',
                          color: t.accentCool,
                          onTap: () => context.push(
                              '/call/${Uri.encodeComponent(room.id)}'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  M3Card(
                    padding: EdgeInsets.zero,
                    child: _ActionRow(
                      icon: Symbols.person_remove,
                      label: '删除联系人',
                      color: t.danger,
                      danger: true,
                      onTap: () async {
                        await room.leave();
                        if (context.mounted) context.pop();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Text(label,
                style: AppTheme.sans(
                    size: 15, color: danger ? t.danger : t.text)),
          ],
        ),
      ),
    );
  }
}

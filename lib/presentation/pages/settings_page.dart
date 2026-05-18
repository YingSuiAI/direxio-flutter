import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import '../mock/mcp_policy.dart';
import '../providers/auth_provider.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/m3/glass_header.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final client = ref.watch(matrixClientProvider);
    final userId = client.userID ?? '';
    final domain = userId.contains(':') ? userId.split(':').last : userId;
    final mcpPolicies = ref.watch(mcpPolicyStoreProvider);
    final mcpActive = mcpPolicies.values.where((p) => p.enabled).length;

    return Scaffold(
      body: Column(
        children: [
          GlassHeader.detail(title: '设置'),
          Expanded(
            child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          // Profile card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.border),
            ),
            child: Row(
              children: [
                PortalAvatar(seed: domain, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<Profile?>(
                        future: client.userID != null
                            ? client.getProfileFromUserId(client.userID!)
                            : Future.value(null),
                        builder: (_, snap) => Text(
                          snap.data?.displayName ?? '未设置昵称',
                          style: AppTheme.sans(
                              size: 17,
                              weight: FontWeight.w600,
                              color: t.text),
                        ),
                      ),
                      const SizedBox(height: 4),
                      PortalMxid(userId, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _SectionHeader('账号'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Symbols.person,
                label: '显示名称',
                value: client.userID != null ? '点击编辑' : '',
                onTap: () {},
              ),
              _SettingsRow(
                icon: Symbols.language,
                label: 'Portal 域名',
                value: domain,
                valueIsMono: true,
              ),
              _SettingsRow(
                icon: Symbols.lock,
                label: '修改密码',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),
          _SectionHeader('安全与加密'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Symbols.shield,
                label: '端到端加密',
                value: '已启用',
                valueColor: t.accent,
              ),
              _SettingsRow(
                icon: Symbols.key,
                label: '密钥备份',
                onTap: () {},
              ),
              _SettingsRow(
                icon: Symbols.smartphone,
                label: '已登录设备',
                onTap: () {},
              ),
              _SettingsRow(
                icon: Symbols.robot_2,
                label: 'MCP / Agent 权限',
                value: '$mcpActive 个 Agent 已授权',
                onTap: () => context.push('/mcp-permission'),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _SectionHeader('关于'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Symbols.sell,
                label: '版本',
                value: 'v2.0.0',
                valueIsMono: true,
              ),
              _SettingsRow(
                icon: Symbols.dns,
                label: 'Matrix Server',
                value: 'continuwuity',
                valueIsMono: true,
              ),
              _SettingsRow(
                icon: Symbols.menu_book,
                label: '帮助与文档',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () =>
                  ref.read(authStateNotifierProvider.notifier).logout(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.danger.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.logout, size: 16, color: t.danger),
                      const SizedBox(width: 8),
                      Text('退出登录',
                          style: AppTheme.sans(
                              size: 14,
                              weight: FontWeight.w500,
                              color: t.danger)),
                    ],
                  ),
                ),
              ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.mono(
            size: 11,
            color: context.tk.textMute,
            weight: FontWeight.w600),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: List.generate(children.length, (i) {
          return Column(
            children: [
              children[i],
              if (i != children.length - 1)
                Divider(height: 1, color: t.border, indent: 44),
            ],
          );
        }),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueColor,
    this.valueIsMono = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final bool valueIsMono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: t.textMute),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: AppTheme.sans(size: 14, color: t.text)),
              ),
              if (value != null && value!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value!,
                    style: valueIsMono
                        ? AppTheme.mono(
                            size: 12, color: valueColor ?? t.textMute)
                        : AppTheme.sans(
                            size: 13, color: valueColor ?? t.textMute),
                  ),
                ),
              if (onTap != null)
                Icon(Symbols.chevron_right,
                    size: 14, color: t.textMute),
            ],
          ),
        ),
      ),
    );
  }
}

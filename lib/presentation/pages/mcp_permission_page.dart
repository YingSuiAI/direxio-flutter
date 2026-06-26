// MCP / Agent 权限：入口列表页
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../mcp/mcp_policy.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/m3/glass_header.dart';

class McpPermissionPage extends ConsumerWidget {
  const McpPermissionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final policies = ref.watch(mcpPolicyStoreProvider);

    return Scaffold(
      body: Column(
        children: [
          GlassHeader.detail(
              title: l10n?.mcpPermissionTitle ?? 'MCP / Agent 权限'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Symbols.info, size: 16, color: t.textMute),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n?.mcpPermissionDescription ??
                              '已授权 Agent 通过 MCP 访问你的聊天数据。点击进入可配置范围、时间、内容脱敏等。',
                          style: AppTheme.sans(size: 12, color: t.textMute),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...policies.values.map((p) => _AgentRow(policy: p)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Symbols.add, size: 14),
                  label: Text(
                      l10n?.mcpPermissionAuthorizeNewAgent ?? '授权新的 Agent'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.policy});
  final McpPolicy policy;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push('/mcp-permission/${policy.agentId}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.border),
            ),
            child: Row(
              children: [
                PortalAvatar(seed: policy.mxid, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            policy.displayName,
                            style: AppTheme.sans(
                              size: 15,
                              weight: FontWeight.w600,
                              color: t.text,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (policy.enabled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: t.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.mcpPermissionAuthorized,
                                style: AppTheme.mono(
                                  size: 10,
                                  weight: FontWeight.w600,
                                  color: t.accent,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: t.textMute.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.mcpPermissionDisabled,
                                style: AppTheme.mono(
                                  size: 10,
                                  weight: FontWeight.w600,
                                  color: t.textMute,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        policy.mxid,
                        style: AppTheme.mono(size: 11, color: t.textMute),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        policy.summary,
                        style: AppTheme.sans(size: 12, color: t.textMute),
                      ),
                    ],
                  ),
                ),
                Icon(Symbols.chevron_right, size: 16, color: t.textMute),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

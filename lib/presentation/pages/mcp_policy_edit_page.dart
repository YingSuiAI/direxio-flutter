/// MCP / Agent 权限：编辑页
/// 按维度分组：总开关 / 工具 / 会话 / 时间 / 内容 / 频次 / 生命周期
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../mock/mcp_policy.dart';
import '../mock/mock_data.dart';
import '../mock/mcp_audit.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/m3/glass_header.dart';

class McpPolicyEditPage extends ConsumerStatefulWidget {
  const McpPolicyEditPage({super.key, required this.agentId});
  final String agentId;

  @override
  ConsumerState<McpPolicyEditPage> createState() => _McpPolicyEditPageState();
}

class _McpPolicyEditPageState extends ConsumerState<McpPolicyEditPage> {
  late McpPolicy _draft;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final orig = ref.read(mcpPolicyStoreProvider)[widget.agentId];
      if (orig != null) {
        _draft = orig.copy();
        _initialized = true;
      }
    }
  }

  void _save() {
    ref.read(mcpPolicyStoreProvider.notifier).update(widget.agentId, _draft);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final t = context.tk;
    final audit = ref
        .watch(mcpAuditStoreProvider)
        .where((e) => e.agentId == widget.agentId)
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            GlassHeader.detail(
              title: _draft.displayName,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: _save,
                    child: Text(
                      '保存',
                      style: AppTheme.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: t.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: t.bg,
                border: Border(
                  bottom: BorderSide(color: t.border.withValues(alpha: 0.5)),
                ),
              ),
              child: TabBar(
                labelColor: t.accent,
                unselectedLabelColor: t.textMute,
                indicatorColor: t.accent,
                labelStyle: AppTheme.sans(size: 14, weight: FontWeight.w600),
                unselectedLabelStyle: AppTheme.sans(size: 14),
                tabs: [
                  const Tab(text: '配置'),
                  Tab(text: '今日活动 (${audit.length})'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildConfigTab(t),
                  _AuditTab(entries: audit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigTab(PortalTokens t) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        // 顶部 Agent 卡片
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              PortalAvatar(seed: _draft.mxid, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _draft.displayName,
                      style: AppTheme.sans(
                        size: 15,
                        weight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _draft.mxid,
                      style: AppTheme.mono(size: 11, color: t.textMute),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _draft.enabled,
                onChanged: (v) => setState(() => _draft.enabled = v),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _SectionHeader('可用工具'),
        _Group(
          children: McpToolDef.all.map((tool) {
            final allowed = _draft.allowedTools.contains(tool.id);
            final needConfirm = _draft.confirmTools.contains(tool.id);
            return _ToolRow(
              tool: tool,
              allowed: allowed,
              needConfirm: needConfirm,
              onToggleAllow: (v) => setState(() {
                if (v) {
                  _draft.allowedTools.add(tool.id);
                } else {
                  _draft.allowedTools.remove(tool.id);
                  _draft.confirmTools.remove(tool.id);
                }
              }),
              onToggleConfirm: (v) => setState(() {
                if (v) {
                  _draft.confirmTools.add(tool.id);
                } else {
                  _draft.confirmTools.remove(tool.id);
                }
              }),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),
        _SectionHeader('聊天记录范围'),
        _Group(
          children: [
            _RadioRow(
              label: '所有会话',
              selected: _draft.roomScope == RoomScope.all,
              onTap: () => setState(() => _draft.roomScope = RoomScope.all),
            ),
            _RadioRow(
              label: '仅以下会话（白名单）',
              selected: _draft.roomScope == RoomScope.whitelist,
              onTap: () =>
                  setState(() => _draft.roomScope = RoomScope.whitelist),
            ),
            _RadioRow(
              label: '排除以下会话（黑名单）',
              selected: _draft.roomScope == RoomScope.blacklist,
              onTap: () =>
                  setState(() => _draft.roomScope = RoomScope.blacklist),
            ),
            if (_draft.roomScope != RoomScope.all)
              _RoomPicker(draft: _draft, onChange: () => setState(() {})),
          ],
        ),

        const SizedBox(height: 16),
        _SectionHeader('时间范围'),
        _Group(
          children: [
            _ChoiceRow<HistoryWindow>(
              icon: Symbols.schedule,
              label: '历史窗口',
              value: _draft.historyWindow,
              options: HistoryWindow.values,
              labelOf: (h) => h.label,
              onPick: (v) => setState(() => _draft.historyWindow = v),
            ),
            _SwitchRow(
              icon: Symbols.light_mode,
              label: '活跃时段',
              subtitle: _draft.activeHours?.toString() ?? '全天可用',
              value: _draft.activeHours != null,
              onChanged: (v) => setState(() {
                _draft.activeHours = v ? const TimeRange(9, 22) : null;
              }),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _SectionHeader('内容脱敏'),
        _Group(
          children: [
            _SwitchRow(
              icon: Symbols.hide_image,
              label: '图片/文件只给元数据',
              subtitle: '不向 Agent 暴露原始媒体内容',
              value: _draft.maskMedia,
              onChanged: (v) => setState(() => _draft.maskMedia = v),
            ),
            _ChipsRow(
              icon: Symbols.visibility_off,
              label: '屏蔽关键词',
              chips: _draft.redactKeywords.toList(),
              onAdd: (kw) => setState(() => _draft.redactKeywords.add(kw)),
              onRemove: (kw) =>
                  setState(() => _draft.redactKeywords.remove(kw)),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _SectionHeader('频次限制'),
        _Group(
          children: [
            _ChoiceRow<int>(
              icon: Symbols.speed,
              label: '每日调用上限',
              value: _draft.dailyCallLimit ?? 0,
              options: const [50, 100, 200, 500, 1000, 0],
              labelOf: (n) => n == 0 ? '不限' : '$n 次',
              onPick: (v) =>
                  setState(() => _draft.dailyCallLimit = v == 0 ? null : v),
            ),
            _ChoiceRow<int>(
              icon: Symbols.list,
              label: '单次返回消息上限',
              value: _draft.perCallMessageLimit ?? 0,
              options: const [20, 50, 100, 200, 0],
              labelOf: (n) => n == 0 ? '不限' : '$n 条',
              onPick: (v) => setState(
                () => _draft.perCallMessageLimit = v == 0 ? null : v,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _SectionHeader('生命周期'),
        _Group(
          children: [
            _ChoiceRow<ExpiryOption>(
              icon: Symbols.timer,
              label: '授权有效期',
              value: _draft.expiryOption,
              options: ExpiryOption.values,
              labelOf: (e) => e.label,
              onPick: (v) => setState(() {
                _draft.expiryOption = v;
                _draft.grantedAt = DateTime.now();
              }),
            ),
            if (_draft.expiresAt != null)
              _InfoRow(
                icon: Symbols.calendar_today,
                label: '到期时间',
                value: DateFormat('yyyy-MM-dd HH:mm').format(_draft.expiresAt!),
              ),
            _InfoRow(
              icon: Symbols.verified_user,
              label: '审计日志',
              value: '强制开启',
              valueColor: t.accent,
            ),
          ],
        ),

        const SizedBox(height: 24),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('撤销授权？'),
                  content: const Text('Agent 将立即失去全部 MCP 权限。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _draft.enabled = false);
                        _save();
                      },
                      child: Text(
                        '撤销',
                        style: TextStyle(color: context.tk.danger),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.danger.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Symbols.gpp_bad, size: 16, color: t.danger),
                    const SizedBox(width: 8),
                    Text(
                      '撤销授权',
                      style: AppTheme.sans(
                        size: 14,
                        weight: FontWeight.w500,
                        color: t.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuditTab extends StatelessWidget {
  const _AuditTab({required this.entries});
  final List<McpAuditEntry> entries;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.description, size: 32, color: t.textMute),
            const SizedBox(height: 8),
            Text('暂无活动', style: AppTheme.sans(size: 13, color: t.textMute)),
            const SizedBox(height: 4),
            Text(
              'Agent 调用任何工具都会留下记录',
              style: AppTheme.sans(size: 11, color: t.textMute),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _AuditRow(e: entries[i]),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.e});
  final McpAuditEntry e;

  IconData get _icon {
    switch (e.outcome) {
      case McpAuditOutcome.ok:
      case McpAuditOutcome.confirmed:
        return Symbols.check_circle;
      case McpAuditOutcome.denied:
        return Symbols.cancel;
      case McpAuditOutcome.confirmRequired:
        return Symbols.gpp_maybe;
      case McpAuditOutcome.cancelled:
        return Symbols.do_not_disturb_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final color = e.outcome == McpAuditOutcome.denied
        ? t.danger
        : e.outcome == McpAuditOutcome.confirmRequired
        ? Colors.amber
        : t.accent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 14, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      e.tool,
                      style: AppTheme.mono(
                        size: 12,
                        color: t.text,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (e.latencyMs != null)
                      Text(
                        '${e.latencyMs}ms',
                        style: AppTheme.mono(size: 10, color: t.textMute),
                      ),
                    const Spacer(),
                    Text(
                      DateFormat('HH:mm:ss').format(e.ts),
                      style: AppTheme.mono(size: 10, color: t.textMute),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  e.deniedReason ?? e.resultSummary ?? '已完成',
                  style: AppTheme.sans(size: 12, color: t.textMute),
                ),
                if (e.warnings.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...e.warnings.map(
                    (w) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Symbols.warning, size: 11, color: Colors.amber),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            w,
                            style: AppTheme.sans(size: 11, color: t.textMute),
                          ),
                        ),
                      ],
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

// ──────────────────────────── 子组件 ────────────────────────────

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
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
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

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.tool,
    required this.allowed,
    required this.needConfirm,
    required this.onToggleAllow,
    required this.onToggleConfirm,
  });
  final McpToolDef tool;
  final bool allowed;
  final bool needConfirm;
  final ValueChanged<bool> onToggleAllow;
  final ValueChanged<bool> onToggleConfirm;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Icon(
            tool.isWrite ? Symbols.edit : Symbols.visibility,
            size: 16,
            color: tool.isWrite ? t.danger : t.textMute,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tool.label,
                      style: AppTheme.sans(size: 14, color: t.text),
                    ),
                    const SizedBox(width: 6),
                    if (tool.isWrite)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: t.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '写',
                          style: AppTheme.mono(
                            size: 9,
                            weight: FontWeight.w600,
                            color: t.danger,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  tool.description,
                  style: AppTheme.sans(size: 11, color: t.textMute),
                ),
                if (allowed && tool.isWrite) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Checkbox(
                        value: needConfirm,
                        onChanged: (v) => onToggleConfirm(v ?? false),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Text(
                        '调用前需我确认',
                        style: AppTheme.sans(size: 12, color: t.textMute),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Switch(value: allowed, onChanged: onToggleAllow),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              selected
                  ? Symbols.radio_button_checked
                  : Symbols.radio_button_unchecked,
              size: 18,
              color: selected ? t.accent : t.textMute,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: AppTheme.sans(size: 14, color: t.text)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomPicker extends StatelessWidget {
  const _RoomPicker({required this.draft, required this.onChange});
  final McpPolicy draft;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final allRooms = MockData.conversations;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            draft.roomScope == RoomScope.whitelist ? '已选会话' : '已排除会话',
            style: AppTheme.mono(size: 11, color: t.textMute),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...draft.roomIds.map((id) {
                final c = MockData.byId(id);
                return Chip(
                  label: Text(
                    c?.name ?? id,
                    style: AppTheme.sans(size: 12, color: t.text),
                  ),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () {
                    draft.roomIds.remove(id);
                    onChange();
                  },
                );
              }),
              ActionChip(
                label: const Text('+ 添加'),
                onPressed: () async {
                  final picked = await showModalBottomSheet<String>(
                    context: context,
                    builder: (_) => Container(
                      color: t.bg,
                      child: ListView(
                        shrinkWrap: true,
                        children: allRooms
                            .where((r) => !draft.roomIds.contains(r.id))
                            .map(
                              (r) => ListTile(
                                leading: PortalAvatar(seed: r.mxid, size: 32),
                                title: Text(r.name),
                                subtitle: Text(
                                  r.mxid,
                                  style: AppTheme.mono(
                                    size: 11,
                                    color: t.textMute,
                                  ),
                                ),
                                onTap: () => Navigator.pop(context, r.id),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  );
                  if (picked != null) {
                    draft.roomIds.add(picked);
                    onChange();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onPick,
  });
  final IconData icon;
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: () async {
        final picked = await showModalBottomSheet<T>(
          context: context,
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options
                  .map(
                    (o) => ListTile(
                      title: Text(labelOf(o)),
                      trailing: o == value
                          ? Icon(Symbols.check, size: 16, color: t.accent)
                          : null,
                      onTap: () => Navigator.pop(context, o),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: t.textMute),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: AppTheme.sans(size: 14, color: t.text)),
            ),
            Text(
              labelOf(value),
              style: AppTheme.sans(size: 13, color: t.textMute),
            ),
            const SizedBox(width: 4),
            Icon(Symbols.chevron_right, size: 14, color: t.textMute),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: t.textMute),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.sans(size: 14, color: t.text)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTheme.sans(size: 11, color: t.textMute),
                  ),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({
    required this.icon,
    required this.label,
    required this.chips,
    required this.onAdd,
    required this.onRemove,
  });
  final IconData icon;
  final String label;
  final List<String> chips;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: t.textMute),
              const SizedBox(width: 12),
              Text(label, style: AppTheme.sans(size: 14, color: t.text)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...chips.map(
                (kw) => Chip(
                  label: Text(
                    kw,
                    style: AppTheme.sans(size: 12, color: t.text),
                  ),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => onRemove(kw),
                ),
              ),
              ActionChip(
                label: const Text('+ 添加'),
                onPressed: () async {
                  final ctrl = TextEditingController();
                  final result = await showDialog<String>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('添加屏蔽关键词'),
                      content: TextField(
                        controller: ctrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: '命中该词的消息将被遮蔽',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, ctrl.text.trim()),
                          child: const Text('添加'),
                        ),
                      ],
                    ),
                  );
                  if (result != null && result.isNotEmpty) onAdd(result);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: t.textMute),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppTheme.sans(size: 14, color: t.text)),
          ),
          Text(
            value,
            style: AppTheme.sans(size: 13, color: valueColor ?? t.textMute),
          ),
        ],
      ),
    );
  }
}

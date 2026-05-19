import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/m3/glass_header.dart';

/// `s-group-manage` — 群管理 (index.html L809-841)
class GroupManagePage extends ConsumerStatefulWidget {
  const GroupManagePage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<GroupManagePage> createState() => _GroupManagePageState();
}

class _GroupManagePageState extends ConsumerState<GroupManagePage> {
  bool _qrJoin = true;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final client = ref.read(matrixClientProvider);
    final room = client.getRoomById(widget.roomId);

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          GlassHeader.detail(title: '群管理'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GroupedCard(
                    children: [
                      _RowSwitch(
                        label: '二维码进群',
                        value: _qrJoin,
                        onChanged: (v) => setState(() => _qrJoin = v),
                      ),
                      _Divider(),
                      _RowChevron(label: '群主管理权转让', onTap: () {}),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _GroupedCard(
                    children: [
                      _RowDanger(
                        label: '退出群聊',
                        onTap: () => _confirmDismiss(context, () async {
                          await room?.leave();
                          if (!mounted) return;
                          Navigator.of(context).maybePop();
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDismiss(
    BuildContext context,
    Future<void> Function() onConfirm,
  ) async {
    final t = context.tk;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          '退出群聊',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          '退出后你将不再接收该群聊消息。',
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
              '退出',
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
    if (ok == true) await onConfirm();
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
            activeColor: Colors.white,
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
          child: Center(
            child: Text(
              label,
              style: AppTheme.sans(
                size: 17,
                weight: FontWeight.w500,
                color: t.danger,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../widgets/m3/glass_header.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

/// `s-me-general` — 通用设置 (index.html L1283-1339)
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          GlassHeader.detail(title: '通用'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _GeneralRow(
                      icon: Symbols.folder_data,
                      label: '存储空间',
                      value: '128 MB',
                      onTap: () {},
                    ),
                    _RowDivider(),
                    _GeneralRow(
                      icon: Symbols.translate,
                      label: '语言',
                      value: '简体中文',
                      onTap: () {},
                    ),
                    _RowDivider(),
                    _GeneralRow(
                      icon: Symbols.dark_mode,
                      label: '外观',
                      value: '跟随系统',
                      onTap: () {},
                    ),
                    _RowDivider(),
                    _GeneralRow(
                      icon: Symbols.info,
                      label: '关于 Agent P2P',
                      value: 'v1.0.0',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.tk.border.withValues(alpha: 0.2),
    );
  }
}

class _GeneralRow extends StatelessWidget {
  const _GeneralRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: t.surfaceHover,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: t.textMute),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.sans(size: 17, color: t.text),
                ),
              ),
              Text(value, style: AppTheme.sans(size: 15, color: t.textMute)),
              const SizedBox(width: 8),
              Icon(Symbols.chevron_right, size: 22, color: t.textMute),
            ],
          ),
        ),
      ),
    );
  }
}

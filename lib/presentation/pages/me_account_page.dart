import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/m3/glass_header.dart';

/// `s-me-account` — 账号与安全 (index.html L1167-1224)
class MeAccountPage extends StatefulWidget {
  const MeAccountPage({super.key});

  @override
  State<MeAccountPage> createState() => _MeAccountPageState();
}

class _MeAccountPageState extends State<MeAccountPage> {
  bool _biometric = true;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          GlassHeader.detail(title: '账号与安全'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: _GroupedCard(children: [
                _IconChevronRow(
                  icon: Symbols.shield_person,
                  label: '账号安全',
                  onTap: () {},
                ),
                _Divider(),
                _IconChevronRow(
                  icon: Symbols.key,
                  label: '修改密码',
                  onTap: () {},
                ),
                _Divider(),
                _IconSwitchRow(
                  icon: Symbols.fingerprint,
                  label: '生物识别解锁',
                  value: _biometric,
                  onChanged: (v) => setState(() => _biometric = v),
                ),
                _Divider(),
                _IconChevronRow(
                  icon: Symbols.lock,
                  label: '隐私设置',
                  onTap: () {},
                ),
                _Divider(),
                _IconChevronRow(
                  icon: Symbols.devices,
                  label: '已登录设备',
                  trailingText: '2 台',
                  onTap: () {},
                ),
              ]),
            ),
          ),
        ],
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

/// 行：左侧 32 圆角图标方块（accent 10% 底 + accent 图标）+ 标签 + 右侧文本/箭头。
class _IconChevronRow extends StatelessWidget {
  const _IconChevronRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailingText;

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
              _IconBadge(icon: icon, color: t.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: AppTheme.sans(size: 17, color: t.text)),
              ),
              if (trailingText != null) ...[
                Text(trailingText!,
                    style: AppTheme.sans(size: 15, color: t.textMute)),
                const SizedBox(width: 4),
              ],
              Icon(Symbols.chevron_right, size: 22, color: t.border),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconSwitchRow extends StatelessWidget {
  const _IconSwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
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
          _IconBadge(icon: icon, color: t.accent),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Text(label, style: AppTheme.sans(size: 17, color: t.text))),
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

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/m3/glass_header.dart';

/// `s-me-notifications` — 通知设置 (index.html L1227-1280)
class MeNotificationsPage extends StatefulWidget {
  const MeNotificationsPage({super.key});

  @override
  State<MeNotificationsPage> createState() => _MeNotificationsPageState();
}

class _MeNotificationsPageState extends State<MeNotificationsPage> {
  bool _msgPush = true;
  bool _dnd = false;

  // 与 home_page.dart Me tab 一致的橙色 (#FF9500)，HTML 中通知设置类目用此色。
  static const _orange = Color(0xFFFF9500);

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          GlassHeader.detail(title: '通知设置'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: _GroupedCard(children: [
                _IconSwitchRow(
                  icon: Symbols.notifications,
                  color: _orange,
                  label: '消息通知',
                  value: _msgPush,
                  onChanged: (v) => setState(() => _msgPush = v),
                ),
                _Divider(),
                _IconSwitchRow(
                  icon: Symbols.do_not_disturb_on,
                  color: _orange,
                  label: '勿扰模式',
                  value: _dnd,
                  onChanged: (v) => setState(() => _dnd = v),
                ),
                _Divider(),
                _IconChevronRow(
                  icon: Symbols.vibration,
                  color: _orange,
                  label: '声音与震动',
                  onTap: () {},
                ),
                _Divider(),
                _IconChevronRow(
                  icon: Symbols.schedule,
                  color: _orange,
                  label: '勿扰时段',
                  trailingText: '22:00–08:00',
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

class _IconChevronRow extends StatelessWidget {
  const _IconChevronRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.trailingText,
  });
  final IconData icon;
  final Color color;
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
              _IconBadge(icon: icon, color: color),
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
    required this.color,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final Color color;
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
          _IconBadge(icon: icon, color: color),
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_list_tile.dart';
import '../widgets/m3/glass_header.dart';

/// Unified settings page for account, notifications, general options, and logout.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _biometric = true;
  bool _msgPush = true;
  bool _dnd = false;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('退出', style: TextStyle(color: context.tk.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authStateNotifierProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(title: '设置'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsSection(
                    title: '账号与安全',
                    children: [
                      _SettingsRow(
                        icon: Symbols.key,
                        label: '修改密码',
                        onTap: () => context.push('/me/account/password'),
                      ),
                      _SettingsDivider(),
                      _SettingsSwitchRow(
                        icon: Symbols.fingerprint,
                        label: '生物识别解锁',
                        value: _biometric,
                        onChanged: (v) => setState(() => _biometric = v),
                      ),
                      _SettingsDivider(),
                      _SettingsRow(
                        icon: Symbols.lock,
                        label: '隐私设置',
                        onTap: () {},
                      ),
                      _SettingsDivider(),
                      _SettingsRow(
                        icon: Symbols.devices,
                        label: '已登录设备',
                        trailingText: '2 台',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: '通知设置',
                    children: [
                      _SettingsSwitchRow(
                        icon: Symbols.notifications,
                        label: '消息通知',
                        value: _msgPush,
                        onChanged: (v) => setState(() => _msgPush = v),
                      ),
                      _SettingsDivider(),
                      _SettingsSwitchRow(
                        icon: Symbols.do_not_disturb_on,
                        label: '勿扰模式',
                        value: _dnd,
                        onChanged: (v) => setState(() => _dnd = v),
                      ),
                      _SettingsDivider(),
                      _SettingsRow(
                        icon: Symbols.vibration,
                        label: '声音与震动',
                        onTap: () {},
                      ),
                      _SettingsDivider(),
                      _SettingsRow(
                        icon: Symbols.schedule,
                        label: '勿扰时段',
                        trailingText: '22:00-08:00',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: '通用',
                    children: [
                      _SettingsRow(
                        icon: Symbols.tune,
                        label: '偏好设置',
                        trailingText: '默认',
                        onTap: () {},
                      ),
                      _SettingsDivider(),
                      _SettingsRow(
                        icon: Symbols.folder_data,
                        label: '存储空间',
                        trailingText: '128 MB',
                        onTap: () {},
                      ),
                      _SettingsDivider(),
                      _SettingsRow(
                        icon: Symbols.translate,
                        label: '语言',
                        trailingText: '简体中文',
                        onTap: () {},
                      ),
                      _SettingsDivider(),
                      _SettingsRow(
                        icon: Symbols.dark_mode,
                        label: '外观',
                        trailingText: '跟随系统',
                        onTap: () {},
                      ),
                      _SettingsDivider(),
                      _SettingsRow(
                        icon: Symbols.info,
                        label: '关于 P2P IM',
                        trailingText: 'v1.0.0',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _LogoutButton(onTap: _logout),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title,
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w600,
              color: t.textMute,
            ),
          ),
        ),
        Column(children: children),
      ],
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
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
    return _SettingsRowShell(
      icon: icon,
      label: label,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText!,
              style: AppTheme.sans(size: 15, color: context.tk.textMute),
            ),
            const SizedBox(width: 8),
          ],
          Icon(Symbols.chevron_right, size: 22, color: context.tk.textMute),
        ],
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
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
    return _SettingsRowShell(
      icon: icon,
      label: label,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        activeThumbColor: context.tk.accent,
        onChanged: onChanged,
      ),
    );
  }
}

class _SettingsRowShell extends StatelessWidget {
  const _SettingsRowShell({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassListTile(
      leading: GlassListIcon(icon: icon),
      title: label,
      trailing: trailing,
      showChevron: false,
      onTap: onTap,
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                '退出登录',
                style: AppTheme.sans(
                  size: 17,
                  weight: FontWeight.w500,
                  color: t.danger,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

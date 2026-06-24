import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../providers/app_locale_provider.dart';
import '../providers/app_theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/message_notification_preferences_provider.dart';

/// Settings page matching the Direxio settings design.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _clearingChats = false;

  Future<void> _clearChatHistory() async {
    if (_clearingChats) return;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.settingsClearChats ?? '清空聊天记录'),
        content: Text(
          l10n?.settingsClearChatsConfirmMessage ??
              '将清空本机聊天记录、未读恢复和媒体缩略图缓存。服务器上的消息不会被删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n?.commonCancel ?? '取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n?.settingsClearChats ?? '清空聊天记录',
              style: TextStyle(color: context.tk.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearingChats = true);
    try {
      await ref.read(authStateNotifierProvider.notifier).clearChatHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.settingsClearChatsSuccess ?? '聊天记录已清空')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.settingsClearChatsFailure ?? '清空聊天记录失败，请稍后重试',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _clearingChats = false);
      }
    }
  }

  Future<void> _logout() async {
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.settingsLogoutConfirmTitle ?? '退出登录'),
        content: Text(l10n?.settingsLogoutConfirmMessage ?? '确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n?.commonCancel ?? '取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n?.settingsLogout ?? '退出登录',
              style: TextStyle(color: context.tk.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authStateNotifierProvider.notifier).logout();
    }
  }

  Future<void> _deactivateLogin() async {
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.settingsDeactivateLoginConfirmTitle ?? '注销登录'),
        content: Text(
          l10n?.settingsDeactivateLoginConfirmMessage ??
              '14天内，只要登录一次账号，注销就会自动取消',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n?.commonCancel ?? '取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n?.commonOk ?? '确认',
              style: TextStyle(color: context.tk.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authStateNotifierProvider.notifier).logout();
    }
  }

  Future<void> _showLanguagePicker() async {
    final selected = ref.read(appLocaleProvider).mode;
    final picked = await showModalBottomSheet<AppLocaleMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final l10n = Localizations.of<AppLocalizations>(
          ctx,
          AppLocalizations,
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _languageDialogTitle(l10n),
                    style: AppTheme.sans(
                      size: 20,
                      weight: FontWeight.w600,
                      color: ctx.tk.text,
                    ),
                  ),
                ),
              ),
              for (final mode in _supportedLanguageModes)
                ListTile(
                  title: Text(_languageLabel(l10n, mode)),
                  trailing: mode == selected
                      ? Icon(Symbols.check, color: ctx.tk.accent)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(mode),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null || picked == selected) return;
    await ref.read(appLocaleProvider.notifier).setMode(picked);
  }

  Future<void> _showThemePicker() async {
    final selected = ref.read(appThemeProvider);
    final picked = await showModalBottomSheet<AppThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final l10n = Localizations.of<AppLocalizations>(
          ctx,
          AppLocalizations,
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n?.settingsTheme ?? '主题',
                    style: AppTheme.sans(
                      size: 20,
                      weight: FontWeight.w600,
                      color: ctx.tk.text,
                    ),
                  ),
                ),
              ),
              for (final mode in AppThemeMode.values)
                ListTile(
                  title: Text(_themeLabel(l10n, mode)),
                  trailing: mode == selected
                      ? Icon(Symbols.check, color: ctx.tk.accent)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(mode),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null || picked == selected) return;
    await ref.read(appThemeProvider.notifier).setMode(picked);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final localeMode = ref.watch(appLocaleProvider).mode;
    final themeMode = ref.watch(appThemeProvider);
    final notificationPrefs = ref.watch(messageNotificationPreferencesProvider);
    final notificationPrefsNotifier =
        ref.read(messageNotificationPreferencesProvider.notifier);
    return Scaffold(
      backgroundColor: t.surfaceHover,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _SettingsHeader(topInset: topInset),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(23, 18, 23, 20 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingsSection(
                      title: l10n?.settingsGeneral ?? '通用设置',
                      rows: [
                        _SettingsRow(
                          icon: Symbols.language,
                          label: l10n?.settingsLanguage ?? '语言',
                          trailingText: _languageLabel(l10n, localeMode),
                          onTap: _showLanguagePicker,
                        ),
                        _SettingsRow(
                          icon: Symbols.contrast,
                          label: l10n?.settingsTheme ?? '主题',
                          trailingText: _themeLabel(l10n, themeMode),
                          onTap: _showThemePicker,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsSection(
                      title: l10n?.settingsPrivacySecurity ?? '隐私与安全',
                      rows: [
                        _SettingsRow(
                          icon: Symbols.key,
                          label: l10n?.settingsChangePassword ?? '修改密码',
                          onTap: () => context.push('/me/account/password'),
                        ),
                        _SettingsRow(
                          icon: Symbols.person_remove,
                          label: l10n?.settingsBlacklist ?? '通讯录黑名单',
                          onTap: () => context.push('/settings/blacklist'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsSection(
                      title: l10n?.settingsMessagesNotifications ?? '消息与通知',
                      rows: [
                        _SettingsSwitchRow(
                          icon: Symbols.do_not_disturb_on,
                          label: l10n?.settingsDoNotDisturb ?? '勿扰模式',
                          value: notificationPrefs.doNotDisturb,
                          onChanged: (v) => unawaited(
                            notificationPrefsNotifier.setDoNotDisturb(v),
                          ),
                        ),
                        _SettingsSwitchRow(
                          icon: Symbols.notifications,
                          label: l10n?.settingsMessageSound ?? '新消息提示音',
                          value: notificationPrefs.messageSound,
                          onChanged: (v) => unawaited(
                            notificationPrefsNotifier.setMessageSound(v),
                          ),
                        ),
                        _SettingsSwitchRow(
                          icon: Symbols.vibration,
                          label: l10n?.settingsMessageVibration ?? '新消息震动',
                          value: notificationPrefs.messageVibration,
                          onChanged: (v) => unawaited(
                            notificationPrefsNotifier.setMessageVibration(v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsSection(
                      title: l10n?.settingsOther ?? '其他',
                      rows: [
                        _SettingsRow(
                          icon: Symbols.info,
                          label: l10n?.settingsAboutUs ?? '关于我们',
                          onTap: () => context.push('/settings/about'),
                        ),
                        _SettingsRow(
                          icon: Symbols.delete,
                          label: _clearingChats
                              ? l10n?.settingsClearChatsClearing ?? '正在清空...'
                              : l10n?.settingsClearChats ?? '清空聊天记录',
                          onTap: _clearChatHistory,
                        ),
                      ],
                    ),
                    const SizedBox(height: 47),
                    _LogoutButton(
                      label: l10n?.settingsLogout ?? '退出登录',
                      onTap: _logout,
                    ),
                    const SizedBox(height: 12),
                    _LogoutButton(
                      label: l10n?.settingsDeactivateLogin ?? '注销登录',
                      onTap: _deactivateLogin,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _languageDialogTitle(AppLocalizations? l10n) {
  return l10n?.languageDialogTitle ?? '语言';
}

const _supportedLanguageModes = [
  AppLocaleMode.system,
  AppLocaleMode.zh,
  AppLocaleMode.en,
  AppLocaleMode.ja,
];

String _languageLabel(AppLocalizations? l10n, AppLocaleMode mode) {
  return switch (mode) {
    AppLocaleMode.system => l10n?.languageSystem ?? '跟随系统',
    AppLocaleMode.zh => l10n?.languageChinese ?? '简体中文',
    AppLocaleMode.en => l10n?.languageEnglish ?? 'English',
    AppLocaleMode.ja => l10n?.languageJapanese ?? '日本語',
  };
}

String _themeLabel(AppLocalizations? l10n, AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.system => l10n?.settingsFollowSystem ?? '跟随系统',
    AppThemeMode.light => l10n?.settingsThemeLight ?? '浅色',
    AppThemeMode.dark => l10n?.settingsThemeDark ?? '深色',
  };
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return SizedBox(
      height: topInset + 62,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topInset + 4, 16, 0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _SettingsGlassButton(
                icon: Symbols.arrow_back,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            Text(
              l10n?.settingsTitle ?? '设置',
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGlassButton extends StatelessWidget {
  const _SettingsGlassButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: 0.12),
            blurRadius: 36,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: t.surface.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, size: 24, color: t.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: AppTheme.sans(
            size: 16,
            weight: FontWeight.w500,
            color: t.text,
          ),
        ),
        const SizedBox(height: 12),
        ...rows.expand((row) sync* {
          yield row;
          if (row != rows.last) yield const SizedBox(height: 12);
        }),
      ],
    );
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
    final t = context.tk;
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
              style: AppTheme.sans(size: 12, color: t.textMute),
            ),
            const SizedBox(width: 6),
          ],
          Icon(Symbols.chevron_right, size: 24, color: t.text),
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
      trailing: _SettingsSwitch(value: value, onChanged: onChanged),
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
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 24, color: t.text),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: t.text,
                    ),
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: 64,
        height: 28,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: value ? t.accent : t.surfaceHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 35,
                height: 24,
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: value ? t.accent : t.border,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.danger),
          ),
          child: Text(
            label,
            style: AppTheme.sans(
              size: 14,
              weight: FontWeight.w500,
              color: t.danger,
            ),
          ),
        ),
      ),
    );
  }
}

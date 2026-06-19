import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/design_tokens.dart';
import '../providers/message_notification_preferences_provider.dart';
import '../widgets/glass_list_tile.dart';
import '../widgets/m3/glass_header.dart';

/// `s-me-notifications` — 通知设置 (index.html L1227-1280)
class MeNotificationsPage extends ConsumerStatefulWidget {
  const MeNotificationsPage({super.key});

  @override
  ConsumerState<MeNotificationsPage> createState() =>
      _MeNotificationsPageState();
}

class _MeNotificationsPageState extends ConsumerState<MeNotificationsPage> {
  bool _msgPush = true;

  @override
  Widget build(BuildContext context) {
    final notificationPrefs = ref.watch(messageNotificationPreferencesProvider);
    final notificationPrefsNotifier =
        ref.read(messageNotificationPreferencesProvider.notifier);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(title: '通知设置'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 32),
              child: _GroupedCard(
                children: [
                  _IconSwitchRow(
                    icon: Symbols.notifications,
                    label: '消息通知',
                    value: _msgPush,
                    onChanged: (v) => setState(() => _msgPush = v),
                  ),
                  _Divider(),
                  _IconSwitchRow(
                    icon: Symbols.do_not_disturb_on,
                    label: '勿扰模式',
                    value: notificationPrefs.doNotDisturb,
                    onChanged: (v) => unawaited(
                      notificationPrefsNotifier.setDoNotDisturb(v),
                    ),
                  ),
                  _Divider(),
                  _IconSwitchRow(
                    icon: Symbols.volume_up,
                    label: '新消息提示音',
                    value: notificationPrefs.messageSound,
                    onChanged: (v) => unawaited(
                      notificationPrefsNotifier.setMessageSound(v),
                    ),
                  ),
                  _Divider(),
                  _IconSwitchRow(
                    icon: Symbols.vibration,
                    label: '新消息震动',
                    value: notificationPrefs.messageVibration,
                    onChanged: (v) => unawaited(
                      notificationPrefsNotifier.setMessageVibration(v),
                    ),
                  ),
                  _Divider(),
                  _IconChevronRow(
                    icon: Symbols.schedule,
                    label: '勿扰时段',
                    trailingText: '22:00–08:00',
                    onTap: () {},
                  ),
                ],
              ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

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
    return GlassListTile(
      leading: GlassListIcon(icon: icon),
      title: label,
      trailingText: trailingText,
      onTap: onTap,
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
    return GlassListTile(
      leading: GlassListIcon(icon: icon),
      title: label,
      showChevron: false,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: t.accent,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: t.secondaryContainer,
      ),
    );
  }
}

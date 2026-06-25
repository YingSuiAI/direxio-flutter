import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';

const _iconMenuAddFriend = 'assets/icons/menu_add_friend.svg';
const _iconMenuCreateGroup = 'assets/icons/menu_create_group.svg';
const _iconMenuScan = 'assets/icons/menu_scan.svg';

enum HomePlusAction { contact, group, scan }

class HomePlusMenuPanel extends StatelessWidget {
  const HomePlusMenuPanel({super.key, this.onSelected});

  static const width = 188.0;
  static const height = 126.0;

  final ValueChanged<HomePlusAction>? onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor =
        (isDark ? t.surfaceHigh : t.surface).withValues(alpha: 0.86);
    final borderColor =
        (isDark ? t.border : t.surface).withValues(alpha: isDark ? 0.9 : 1);
    final labels = _HomePlusMenuLabels.from(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          key: const ValueKey('home_plus_menu_panel'),
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
                blurRadius: 36,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Column(
                children: [
                  _HomePlusMenuTile(
                    iconAsset: _iconMenuAddFriend,
                    label: labels.addFriend,
                    value: HomePlusAction.contact,
                    onSelected: _select,
                  ),
                  const SizedBox(height: 5),
                  _HomePlusMenuTile(
                    iconAsset: _iconMenuCreateGroup,
                    label: labels.createGroup,
                    value: HomePlusAction.group,
                    onSelected: _select,
                  ),
                  const SizedBox(height: 5),
                  _HomePlusMenuTile(
                    iconAsset: _iconMenuScan,
                    label: labels.scan,
                    value: HomePlusAction.scan,
                    onSelected: _select,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _select(BuildContext context, HomePlusAction action) {
    final callback = onSelected;
    if (callback != null) {
      callback(action);
      return;
    }
    Navigator.of(context).pop(action);
  }
}

class _HomePlusMenuLabels {
  const _HomePlusMenuLabels({
    required this.addFriend,
    required this.createGroup,
    required this.scan,
  });

  final String addFriend;
  final String createGroup;
  final String scan;

  static _HomePlusMenuLabels from(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return _HomePlusMenuLabels(
      addFriend: l10n?.addContactTitle ?? '添加好友',
      createGroup: l10n?.createGroupTitle ?? '创建群聊',
      scan: _scanLabelFor(context, l10n),
    );
  }
}

String _scanLabelFor(BuildContext context, AppLocalizations? l10n) {
  if (l10n == null) return '扫一扫';
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => 'Scan',
    'ja' => 'スキャン',
    _ => '扫一扫',
  };
}

class _HomePlusMenuTile extends StatelessWidget {
  const _HomePlusMenuTile({
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.onSelected,
  });

  final String iconAsset;
  final String label;
  final HomePlusAction value;
  final void Function(BuildContext context, HomePlusAction value) onSelected;

  @override
  Widget build(BuildContext context) {
    final textColor = context.tk.text;
    return InkWell(
      onTap: () => onSelected(context, value),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            const SizedBox(width: 20),
            _HomePlusAssetIcon(
              assetName: iconAsset,
              size: 20,
              color: textColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

class _HomePlusAssetIcon extends StatelessWidget {
  const _HomePlusAssetIcon({
    required this.assetName,
    required this.size,
    required this.color,
  });

  final String assetName;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetName,
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      placeholderBuilder: (_) => Icon(
        _fallbackIconForAsset(assetName),
        size: size,
        color: color,
      ),
    );
  }
}

IconData _fallbackIconForAsset(String assetName) {
  if (assetName.contains('scan')) return Symbols.qr_code_scanner;
  if (assetName.contains('group')) return Symbols.group_add;
  return Symbols.person_add;
}

// M3 底部导航 —— 对齐 Agent P2P 设计稿 #main-nav / .nav-pill
//
// 特征：紧凑 iOS tab 高度、glass 背景、滑动 pill 指示器（secondary-container 色），
// 图标 active 时填充（FILL 1），文字 label-sm。
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/app_theme.dart';

class M3NavItem {
  const M3NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badge;
}

class M3BottomNav extends StatelessWidget {
  const M3BottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<M3NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _height = 52.0;
  static const _pillHeight = 36.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? t.onAccent : t.textMute;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.58),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: _height,
              child: LayoutBuilder(
                builder: (context, c) {
                  final tabWidth = c.maxWidth / items.length;
                  return Stack(
                    children: [
                      // 滑动 pill 指示器
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeInOutCubic,
                        left: tabWidth * currentIndex +
                            (tabWidth - _pillWidth(tabWidth)) / 2,
                        top: (_height - _pillHeight) / 2,
                        child: Container(
                          width: _pillWidth(tabWidth),
                          height: _pillHeight,
                          decoration: BoxDecoration(
                            color: t.secondaryContainer,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(items.length, (i) {
                          final item = items[i];
                          final active = i == currentIndex;
                          final foreground = active ? t.accent : inactiveColor;
                          return Expanded(
                            child: InkWell(
                              onTap: () => onTap(i),
                              customBorder: const StadiumBorder(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(
                                        active ? item.activeIcon : item.icon,
                                        size: 23,
                                        color: foreground,
                                        fill: active ? 1 : 0,
                                      ),
                                      if (item.badge != null)
                                        Positioned(
                                          key: ValueKey(
                                            'bottom_nav_badge_${item.label}',
                                          ),
                                          right: -8,
                                          top: -6,
                                          child: _NavBadge(
                                            label: item.badge!,
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    item.label,
                                    style: AppTheme.sans(
                                      size: 11,
                                      color: foreground,
                                      weight: active
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _pillWidth(double tabWidth) => (tabWidth - 24).clamp(48.0, 96.0);
}

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.danger,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.sans(
          size: 9,
          weight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

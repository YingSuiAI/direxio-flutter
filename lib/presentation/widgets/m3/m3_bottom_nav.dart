/// M3 底部导航 —— 对齐 Agent P2P 设计稿 #main-nav / .nav-pill
///
/// 特征：64 高、glass 背景、滑动 pill 指示器（secondary-container 色），
/// 图标 active 时填充（FILL 1），文字 label-sm。
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/app_theme.dart';

class M3NavItem {
  const M3NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
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

  static const _height = 64.0;
  static const _pillHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: t.bg.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(color: t.border.withValues(alpha: 0.5)),
            ),
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
                          return Expanded(
                            child: InkWell(
                              onTap: () => onTap(i),
                              customBorder: const StadiumBorder(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    active ? item.activeIcon : item.icon,
                                    size: 24,
                                    color: active ? t.accent : t.textMute,
                                    fill: active ? 1 : 0,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.label,
                                    style: AppTheme.sans(
                                      size: 11,
                                      color: active ? t.accent : t.textMute,
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

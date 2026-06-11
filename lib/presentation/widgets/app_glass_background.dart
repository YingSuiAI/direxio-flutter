import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

class AppGlassBackground extends StatelessWidget {
  const AppGlassBackground({
    super.key,
    required this.child,
  });

  static const assetName = 'assets/images/chat_glass_background.png';

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (_AppGlassBackgroundScope.isActive(context)) {
      return child;
    }

    final t = context.tk;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _AppGlassBackgroundScope(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: t.bg),
            Opacity(
              opacity: dark ? 0.16 : 1,
              child: Image.asset(
                assetName,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: dark
                      ? t.bg.withValues(alpha: 0.82)
                      : t.surface.withValues(alpha: 0.42),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _AppGlassBackgroundScope extends InheritedWidget {
  const _AppGlassBackgroundScope({required super.child});

  static bool isActive(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_AppGlassBackgroundScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(_AppGlassBackgroundScope oldWidget) => false;
}

class AppGlassPanel extends StatelessWidget {
  const AppGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.24 : 0.08),
            blurRadius: dark ? 40 : 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: dark
                  ? Colors.black.withValues(alpha: 0.42)
                  : t.surface.withValues(alpha: 0.52),
              borderRadius: borderRadius,
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : t.surface.withValues(alpha: 0.72),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

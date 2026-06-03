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
    return _AppGlassBackgroundScope(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              assetName,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.surface.withValues(alpha: 0.42),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: 0.08),
            blurRadius: 18,
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
              color: t.surface.withValues(alpha: 0.52),
              borderRadius: borderRadius,
              border: Border.all(
                color: t.surface.withValues(alpha: 0.72),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

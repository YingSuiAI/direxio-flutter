import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

OverlayEntry? _activeCenterToast;
Timer? _activeCenterToastTimer;

void showCenterToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 1400),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || message.trim().isEmpty) return;
  _activeCenterToastTimer?.cancel();
  _activeCenterToast?.remove();

  final t = context.tk;
  final entry = OverlayEntry(
    builder: (context) {
      return Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.text.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: t.text.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTheme.sans(
                      size: 15,
                      weight: FontWeight.w500,
                      color: t.surface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  _activeCenterToast = entry;
  overlay.insert(entry);
  _activeCenterToastTimer = Timer(duration, () {
    if (_activeCenterToast == entry) {
      _activeCenterToast = null;
      _activeCenterToastTimer = null;
    }
    entry.remove();
  });
}

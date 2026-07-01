import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

OverlayEntry? _activeCenterToast;
Timer? _activeCenterToastTimer;

const Duration appToastDuration = Duration(seconds: 2);

class AppToastMessenger {
  const AppToastMessenger(this.context);

  final BuildContext context;

  bool get mounted => context.mounted;

  void hideCurrentSnackBar() => hideTopToast();

  void showSnackBar(SnackBar snackBar) => showTopSnackBar(context, snackBar);
}

void showCenterToast(
  BuildContext context,
  String message, {
  Duration duration = appToastDuration,
}) {
  showTopToast(context, message, duration: duration);
}

void showTopToast(
  BuildContext context,
  String message, {
  Duration duration = appToastDuration,
}) {
  if (!context.mounted) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || message.trim().isEmpty) return;
  hideTopToast();

  final t = context.tk;
  final entry = OverlayEntry(
    builder: (context) {
      final top = MediaQuery.paddingOf(context).top + 78;
      return Positioned(
        top: top,
        left: 16,
        right: 16,
        child: IgnorePointer(
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 130,
                  minHeight: 35,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.toastBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      message.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTheme.sans(
                        size: 14,
                        weight: FontWeight.w500,
                        color: t.onToastBackground,
                      ),
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

void showTopSnackBar(BuildContext context, SnackBar snackBar) {
  final text = _snackBarText(snackBar.content);
  if (text == null) return;
  showTopToast(context, text);
}

void hideTopToast() {
  _activeCenterToastTimer?.cancel();
  _activeCenterToastTimer = null;
  _activeCenterToast?.remove();
  _activeCenterToast = null;
}

String? _snackBarText(Widget content) {
  if (content is Text) {
    return content.data ?? content.textSpan?.toPlainText();
  }
  return null;
}

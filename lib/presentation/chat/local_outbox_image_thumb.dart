import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/design_tokens.dart';

class LocalOutboxImageThumbDefaults {
  const LocalOutboxImageThumbDefaults._();

  static const decodeWidth = 360;
}

class PendingLocalOutboxImageThumb extends StatelessWidget {
  const PendingLocalOutboxImageThumb({
    super.key,
    required this.bytes,
    this.overlay,
  });

  final Uint8List bytes;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Stack(
      fit: StackFit.expand,
      children: [
        _LocalOutboxImage(bytes: bytes),
        if (overlay != null) overlay!,
        ColoredBox(color: t.text.withValues(alpha: 0.18)),
        Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: t.onAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class FailedLocalOutboxImageThumb extends StatelessWidget {
  const FailedLocalOutboxImageThumb({
    super.key,
    required this.bytes,
    this.placeholderIcon = Symbols.image,
    this.overlay,
    this.onRetry,
  });

  final Uint8List? bytes;
  final IconData placeholderIcon;
  final Widget? overlay;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bytes case final imageBytes?)
          _LocalOutboxImage(bytes: imageBytes)
        else
          ColoredBox(
            color: t.surfaceHigh,
            child: Center(
              child: Icon(
                placeholderIcon,
                size: 28,
                color: t.textMute.withValues(alpha: 0.62),
              ),
            ),
          ),
        if (overlay != null) overlay!,
        if (bytes != null)
          ColoredBox(color: Colors.black.withValues(alpha: 0.06)),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Semantics(
              button: true,
              label: '重新发送',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRetry,
                child: SizedBox.square(
                  dimension: 40,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.surface.withValues(alpha: 0.94),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: t.text.withValues(alpha: 0.14),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Icon(Symbols.refresh, color: t.danger, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocalOutboxImage extends StatelessWidget {
  const _LocalOutboxImage({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      fit: BoxFit.contain,
      cacheWidth: LocalOutboxImageThumbDefaults.decodeWidth,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
    );
  }
}

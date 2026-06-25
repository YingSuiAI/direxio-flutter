import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';

const double _minAvatarScale = 1;
const double _maxAvatarScale = 4;
const int _avatarOutputSize = 512;

@visibleForTesting
Size avatarCoverSize(Size imageSize, double cropSize) {
  if (imageSize.width <= 0 || imageSize.height <= 0) {
    return Size.square(cropSize);
  }
  final scale = cropSize / math.min(imageSize.width, imageSize.height);
  return Size(imageSize.width * scale, imageSize.height * scale);
}

@visibleForTesting
Offset clampAvatarOffset(
  Offset offset, {
  required Size baseSize,
  required double cropSize,
  required double scale,
}) {
  final width = baseSize.width * scale;
  final height = baseSize.height * scale;
  final maxDx = math.max(0, (width - cropSize) / 2);
  final maxDy = math.max(0, (height - cropSize) / 2);
  return Offset(
    offset.dx.clamp(-maxDx, maxDx).toDouble(),
    offset.dy.clamp(-maxDy, maxDy).toDouble(),
  );
}

Future<void> showAvatarAdjustSheet(
  BuildContext context, {
  required Uint8List imageBytes,
  required Future<void> Function(Uint8List bytes) onConfirm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AvatarAdjustSheet(
      imageBytes: imageBytes,
      onConfirm: onConfirm,
    ),
  );
}

class AvatarAdjustSheet extends StatefulWidget {
  const AvatarAdjustSheet({
    super.key,
    required this.imageBytes,
    this.onConfirm,
    @visibleForTesting this.initialImageSize,
    @visibleForTesting this.exportForTesting,
  });

  final Uint8List imageBytes;
  final Future<void> Function(Uint8List bytes)? onConfirm;
  final Size? initialImageSize;
  final Future<Uint8List> Function()? exportForTesting;

  @override
  State<AvatarAdjustSheet> createState() => _AvatarAdjustSheetState();
}

class _AvatarAdjustSheetState extends State<AvatarAdjustSheet> {
  final _cropKey = GlobalKey();
  Size? _imageSize;
  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  double _scale = _minAvatarScale;
  double _startScale = _minAvatarScale;
  bool _exporting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _imageSize = widget.initialImageSize;
    if (_imageSize == null) {
      unawaited(_decodeImage());
    }
  }

  Future<void> _decodeImage() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      codec.dispose();
      if (!mounted) return;
      setState(() => _imageSize = size);
    } catch (e) {
      debugPrint('Avatar image decode failed: $e');
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_exporting) return;
    _startScale = _scale;
    _startOffset = _offset;
    _startFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(
    ScaleUpdateDetails details,
    Size baseSize,
    double cropSize,
  ) {
    if (_exporting) return;
    final nextScale =
        (_startScale * details.scale).clamp(_minAvatarScale, _maxAvatarScale);
    final nextOffset = _startOffset + details.localFocalPoint - _startFocal;
    setState(() {
      _scale = nextScale.toDouble();
      _offset = clampAvatarOffset(
        nextOffset,
        baseSize: baseSize,
        cropSize: cropSize,
        scale: _scale,
      );
    });
  }

  void _setScale(double value, Size baseSize, double cropSize) {
    if (_exporting) return;
    setState(() {
      _scale = value;
      _offset = clampAvatarOffset(
        _offset,
        baseSize: baseSize,
        cropSize: cropSize,
        scale: _scale,
      );
    });
  }

  void _reset(Size baseSize, double cropSize) {
    if (_exporting) return;
    setState(() {
      _scale = _minAvatarScale;
      _offset = clampAvatarOffset(
        Offset.zero,
        baseSize: baseSize,
        cropSize: cropSize,
        scale: _scale,
      );
    });
  }

  Future<void> _finish() async {
    final l10n = _avatarAdjustL10n(context);
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _errorText = null;
    });
    try {
      final bytes = await _exportAvatarBytes();
      final onConfirm = widget.onConfirm;
      if (onConfirm != null) {
        await onConfirm(bytes);
      }
      if (mounted) {
        if (onConfirm == null) {
          Navigator.of(context).pop(bytes);
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('Avatar export failed: $e');
      if (mounted) {
        setState(() {
          _errorText = e is StateError
              ? e.message
              : l10n?.avatarAdjustUpdateFailed('$e') ?? '头像更新失败: $e';
          _exporting = false;
        });
      }
    }
  }

  Future<Uint8List> _exportAvatarBytes() async {
    final exportForTesting = widget.exportForTesting;
    if (exportForTesting != null) return exportForTesting();

    final l10n = _avatarAdjustL10n(context);
    final boundary =
        _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError(l10n?.avatarAdjustPreviewNotReady ?? '头像预览尚未准备好');
    }
    final image = await boundary.toImage(
      pixelRatio: _avatarOutputSize / boundary.size.width,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError(l10n?.avatarAdjustExportFailed ?? '头像导出失败');
    }
    return byteData.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = _avatarAdjustL10n(context);
    final imageSize = _imageSize;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final previewBg = isDark ? t.surface : t.text;
    final overlayDimColor = t.bg.withValues(alpha: isDark ? 0.62 : 0.54);
    final cropRingColor = t.onAccent.withValues(alpha: 0.96);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: imageSize == null
            ? SizedBox(
                height: 420,
                child: Center(
                  child: CircularProgressIndicator(color: t.accent),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final cropSize = math.min(
                    math.min(constraints.maxWidth, 360.0),
                    MediaQuery.sizeOf(context).height * 0.48,
                  );
                  final baseSize = avatarCoverSize(imageSize, cropSize);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Header(
                        exporting: _exporting,
                        onCancel: () => Navigator.of(context).pop(),
                        onDone: _finish,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n?.avatarAdjustHint ?? '双指缩放或拖动图片',
                        style: AppTheme.sans(size: 13, color: t.textMute),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 12),
                        _StatusBanner(
                          text: _errorText!,
                        ),
                      ],
                      const SizedBox(height: 16),
                      GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: (details) =>
                            _onScaleUpdate(details, baseSize, cropSize),
                        child: SizedBox.square(
                          dimension: cropSize,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              RepaintBoundary(
                                key: _cropKey,
                                child: ClipRect(
                                  child: ColoredBox(
                                    color: previewBg,
                                    child: Center(
                                      child: Transform.translate(
                                        offset: _offset,
                                        child: Transform.scale(
                                          scale: _scale,
                                          child: SizedBox(
                                            width: baseSize.width,
                                            height: baseSize.height,
                                            child: Image.memory(
                                              widget.imageBytes,
                                              fit: BoxFit.fill,
                                              gaplessPlayback: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: _AvatarCropOverlayPainter(
                                    dimColor: overlayDimColor,
                                    ringColor: cropRingColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Icon(Symbols.zoom_out, size: 22, color: t.textMute),
                          Expanded(
                            child: Slider(
                              min: _minAvatarScale,
                              max: _maxAvatarScale,
                              value: _scale,
                              onChanged: _exporting
                                  ? null
                                  : (v) => _setScale(v, baseSize, cropSize),
                            ),
                          ),
                          Icon(Symbols.zoom_in, size: 22, color: t.textMute),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _exporting
                            ? null
                            : () => _reset(baseSize, cropSize),
                        icon: const Icon(Symbols.refresh, size: 18),
                        label: Text(l10n?.avatarAdjustReset ?? '重置'),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

AppLocalizations? _avatarAdjustL10n(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.exporting,
    required this.onCancel,
    required this.onDone,
  });

  final bool exporting;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = _avatarAdjustL10n(context);
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: TextButton(
            onPressed: exporting ? null : onCancel,
            child: Text(l10n?.commonCancel ?? '取消'),
          ),
        ),
        Expanded(
          child: Text(
            l10n?.avatarAdjustTitle ?? '调整头像',
            textAlign: TextAlign.center,
            style:
                AppTheme.sans(size: 17, color: t.text, weight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: exporting ? null : onDone,
          child: exporting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.accent,
                  ),
                )
              : Text(l10n?.avatarAdjustDone ?? '完成'),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final color = t.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            Symbols.error,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTheme.sans(size: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCropOverlayPainter extends CustomPainter {
  const _AvatarCropOverlayPainter({
    required this.dimColor,
    required this.ringColor,
  });

  final Color dimColor;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final oval = Rect.fromCircle(
      center: rect.center,
      radius: size.shortestSide / 2,
    );
    final overlayPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addOval(oval);
    canvas.drawPath(overlayPath, Paint()..color = dimColor);
    canvas.drawOval(
      oval.deflate(1),
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_AvatarCropOverlayPainter oldDelegate) {
    return dimColor != oldDelegate.dimColor ||
        ringColor != oldDelegate.ringColor;
  }
}

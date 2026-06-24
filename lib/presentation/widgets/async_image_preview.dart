import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';

typedef ImageProviderLoader = Future<ImageProvider> Function();
typedef ImagePreviewAction = FutureOr<void> Function();

Future<void> showAsyncImagePreview(
  BuildContext context, {
  ImageProviderLoader? loadPreviewProvider,
  required ImageProviderLoader loadProvider,
  required String meta,
  ImagePreviewAction? onDownload,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.95),
    barrierDismissible: true,
    barrierLabel: 'img-lightbox',
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, a1, a2) {
      return _AsyncImagePreviewDialog(
        loadPreviewProvider: loadPreviewProvider,
        loadProvider: loadProvider,
        meta: meta,
        onDownload: onDownload,
      );
    },
  );
}

class _AsyncImagePreviewDialog extends StatefulWidget {
  const _AsyncImagePreviewDialog({
    this.loadPreviewProvider,
    required this.loadProvider,
    required this.meta,
    this.onDownload,
  });

  final ImageProviderLoader? loadPreviewProvider;
  final ImageProviderLoader loadProvider;
  final String meta;
  final ImagePreviewAction? onDownload;

  @override
  State<_AsyncImagePreviewDialog> createState() =>
      _AsyncImagePreviewDialogState();
}

class _AsyncImagePreviewDialogState extends State<_AsyncImagePreviewDialog> {
  Future<ImageProvider>? _previewProviderFuture;
  late final Future<ImageProvider> _providerFuture;
  bool _downloading = false;
  bool _downloaded = false;

  @override
  void initState() {
    super.initState();
    _previewProviderFuture = widget.loadPreviewProvider?.call();
    _providerFuture = widget.loadProvider();
  }

  Future<void> _download() async {
    final onDownload = widget.onDownload;
    if (onDownload == null || _downloading) return;
    setState(() {
      _downloading = true;
      _downloaded = false;
    });
    try {
      await onDownload();
      if (mounted) setState(() => _downloaded = true);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Symbols.close,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 48, height: 48),
                ],
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {},
              child: Center(
                child: FutureBuilder<ImageProvider>(
                    future: _providerFuture,
                    builder: (context, fullSnapshot) {
                      final fullProvider = fullSnapshot.data;
                      if (fullProvider != null) {
                        return _PreviewImage(provider: fullProvider);
                      }
                      if (_previewProviderFuture != null) {
                        return FutureBuilder<ImageProvider>(
                          future: _previewProviderFuture,
                          builder: (context, previewSnapshot) {
                            final previewProvider = previewSnapshot.data;
                            if (previewProvider != null) {
                              return _PreviewImage(provider: previewProvider);
                            }
                            if (fullSnapshot.hasError &&
                                previewSnapshot.connectionState ==
                                    ConnectionState.done) {
                              return const _PreviewErrorIcon();
                            }
                            return const _PreviewLoadingIndicator();
                          },
                        );
                      }
                      if (fullSnapshot.hasError) {
                        return const _PreviewErrorIcon();
                      }
                      return const _PreviewLoadingIndicator();
                    }),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      widget.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTheme.sans(
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: widget.onDownload == null
                        ? const SizedBox.shrink()
                        : _PreviewDownloadButton(
                            downloading: _downloading,
                            downloaded: _downloaded,
                            onTap: _download,
                          ),
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

class _PreviewDownloadButton extends StatelessWidget {
  const _PreviewDownloadButton({
    required this.downloading,
    required this.downloaded,
    required this.onTap,
  });

  final bool downloading;
  final bool downloaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: downloading ? null : onTap,
      tooltip: downloaded ? '原图已保存' : '保存原图到相册',
      icon: downloading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              downloaded ? Symbols.check : Symbols.download,
              color: Colors.white,
              size: 26,
            ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.provider});

  final ImageProvider provider;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: 4,
      child: Image(image: provider, fit: BoxFit.contain),
    );
  }
}

class _PreviewLoadingIndicator extends StatelessWidget {
  const _PreviewLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        color: Colors.white,
      ),
    );
  }
}

class _PreviewErrorIcon extends StatelessWidget {
  const _PreviewErrorIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Symbols.broken_image,
      color: Colors.white70,
      size: 42,
    );
  }
}

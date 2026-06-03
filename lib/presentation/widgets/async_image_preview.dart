import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';

typedef ImageProviderLoader = Future<ImageProvider> Function();

Future<void> showAsyncImagePreview(
  BuildContext context, {
  ImageProviderLoader? loadPreviewProvider,
  required ImageProviderLoader loadProvider,
  required String meta,
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
      );
    },
  );
}

class _AsyncImagePreviewDialog extends StatefulWidget {
  const _AsyncImagePreviewDialog({
    this.loadPreviewProvider,
    required this.loadProvider,
    required this.meta,
  });

  final ImageProviderLoader? loadPreviewProvider;
  final ImageProviderLoader loadProvider;
  final String meta;

  @override
  State<_AsyncImagePreviewDialog> createState() =>
      _AsyncImagePreviewDialogState();
}

class _AsyncImagePreviewDialogState extends State<_AsyncImagePreviewDialog> {
  Future<ImageProvider>? _previewProviderFuture;
  late final Future<ImageProvider> _providerFuture;

  @override
  void initState() {
    super.initState();
    _previewProviderFuture = widget.loadPreviewProvider?.call();
    _providerFuture = widget.loadProvider();
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              widget.meta,
              style: AppTheme.sans(
                size: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
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

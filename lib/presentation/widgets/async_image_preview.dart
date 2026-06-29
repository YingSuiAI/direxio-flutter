import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';

typedef ImageProviderLoader = Future<ImageProvider> Function();
typedef ImagePreviewAction = FutureOr<void> Function();

class AsyncImageGalleryItem {
  const AsyncImageGalleryItem({
    this.initialPreviewProvider,
    this.loadPreviewProvider,
    required this.loadProvider,
    required this.meta,
    this.onDownload,
  });

  final ImageProvider? initialPreviewProvider;
  final ImageProviderLoader? loadPreviewProvider;
  final ImageProviderLoader loadProvider;
  final String meta;
  final ImagePreviewAction? onDownload;
}

Future<void> showAsyncImagePreview(
  BuildContext context, {
  ImageProvider? initialPreviewProvider,
  ImageProviderLoader? loadPreviewProvider,
  required ImageProviderLoader loadProvider,
  required String meta,
  ImagePreviewAction? onDownload,
}) {
  return showAsyncImageGalleryPreview(
    context,
    items: [
      AsyncImageGalleryItem(
        initialPreviewProvider: initialPreviewProvider,
        loadPreviewProvider: loadPreviewProvider,
        loadProvider: loadProvider,
        meta: meta,
        onDownload: onDownload,
      ),
    ],
  );
}

Future<void> showAsyncImageGalleryPreview(
  BuildContext context, {
  required List<AsyncImageGalleryItem> items,
  int initialIndex = 0,
}) {
  if (items.isEmpty) return Future<void>.value();
  return showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.95),
    barrierDismissible: true,
    barrierLabel: 'img-lightbox',
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, a1, a2) {
      return _AsyncImageGalleryDialog(
        items: items,
        initialIndex: initialIndex,
      );
    },
  );
}

class _AsyncImageGalleryDialog extends StatefulWidget {
  const _AsyncImageGalleryDialog({
    required this.items,
    required this.initialIndex,
  });

  final List<AsyncImageGalleryItem> items;
  final int initialIndex;

  @override
  State<_AsyncImageGalleryDialog> createState() =>
      _AsyncImageGalleryDialogState();
}

class _AsyncImageGalleryDialogState extends State<_AsyncImageGalleryDialog> {
  late final PageController _pageController;
  late int _index;
  final Set<int> _downloadingIndexes = <int>{};
  final Set<int> _downloadedIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1).toInt();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    final onDownload = widget.items[_index].onDownload;
    if (onDownload == null || _downloadingIndexes.contains(_index)) return;
    final index = _index;
    setState(() {
      _downloadingIndexes.add(index);
      _downloadedIndexes.remove(index);
    });
    try {
      await onDownload();
      if (mounted) setState(() => _downloadedIndexes.add(index));
    } finally {
      if (mounted) setState(() => _downloadingIndexes.remove(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];
    final meta = widget.items.length == 1
        ? item.meta
        : '${item.meta}  ${_index + 1}/${widget.items.length}';
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
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.items.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return Center(
                    child: _AsyncImageGalleryPage(
                      key:
                          ValueKey('async_image_gallery_${index}_${item.meta}'),
                      item: item,
                      interactive: widget.items.length == 1,
                    ),
                  );
                },
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
                      meta,
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
                    child: item.onDownload == null
                        ? const SizedBox.shrink()
                        : _PreviewDownloadButton(
                            downloading: _downloadingIndexes.contains(_index),
                            downloaded: _downloadedIndexes.contains(_index),
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

class _AsyncImageGalleryPage extends StatefulWidget {
  const _AsyncImageGalleryPage({
    super.key,
    required this.item,
    required this.interactive,
  });

  final AsyncImageGalleryItem item;
  final bool interactive;

  @override
  State<_AsyncImageGalleryPage> createState() => _AsyncImageGalleryPageState();
}

class _AsyncImageGalleryPageState extends State<_AsyncImageGalleryPage> {
  Future<ImageProvider>? _previewProviderFuture;
  late Future<ImageProvider> _providerFuture;
  ImageProvider? _visibleProvider;
  bool _previewDone = false;
  bool _fullFailed = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  @override
  void didUpdateWidget(covariant _AsyncImageGalleryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      _startLoading();
    }
  }

  void _startLoading() {
    final generation = ++_loadGeneration;
    _visibleProvider = widget.item.initialPreviewProvider;
    _previewDone = false;
    _fullFailed = false;
    _previewProviderFuture = widget.item.loadPreviewProvider?.call();
    _providerFuture = widget.item.loadProvider();
    _loadPreviewProvider(generation);
    _loadFullProvider(generation);
  }

  Future<void> _loadPreviewProvider(int generation) async {
    final future = _previewProviderFuture;
    if (future == null) {
      _previewDone = true;
      return;
    }
    try {
      final provider = await future;
      if (!mounted || generation != _loadGeneration) return;
      if (_visibleProvider == null) {
        setState(() => _visibleProvider = provider);
      }
    } catch (_) {
      // Preview bytes are an optimization. The full image loader decides
      // whether the dialog can ultimately render an image.
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _previewDone = true);
      }
    }
  }

  Future<void> _loadFullProvider(int generation) async {
    try {
      final provider = await _providerFuture;
      if (!mounted || generation != _loadGeneration) return;
      if (_visibleProvider != null) {
        await _precacheProvider(provider, generation);
        if (!mounted || generation != _loadGeneration) return;
      }
      setState(() => _visibleProvider = provider);
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _fullFailed = true);
    }
  }

  Future<void> _precacheProvider(
    ImageProvider provider,
    int generation,
  ) async {
    try {
      await precacheImage(
        provider,
        context,
        onError: (_, __) {},
      );
    } catch (_) {
      // If Flutter cannot precache this provider, still let the Image widget
      // attempt to render it while keeping gapless playback enabled.
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _visibleProvider;
    if (provider != null) {
      return _PreviewImage(
        provider: provider,
        interactive: widget.interactive,
      );
    }
    if (_fullFailed && _previewDone) {
      return const _PreviewErrorIcon();
    }
    return const _PreviewLoadingIndicator();
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
  const _PreviewImage({
    required this.provider,
    required this.interactive,
  });

  final ImageProvider provider;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    if (!interactive) {
      return Image(
        image: provider,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }
    return InteractiveViewer(
      maxScale: 4,
      child: Image(
        image: provider,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      ),
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

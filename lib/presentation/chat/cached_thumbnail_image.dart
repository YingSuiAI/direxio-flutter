import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/media_thumbnail_cache.dart';

typedef ThumbnailBytesLoader = Future<Uint8List> Function();
typedef ThumbnailImageBuilder = Widget Function(
  BuildContext context,
  Uint8List bytes,
);

class CachedThumbnailImage extends StatefulWidget {
  const CachedThumbnailImage({
    super.key,
    required this.cacheKey,
    this.cache,
    required this.cacheFuture,
    required this.loadBytes,
    this.fit = BoxFit.cover,
    this.imageBuilder,
    this.loadingBuilder,
    this.failedBuilder,
  });

  final String cacheKey;
  final MediaThumbnailCache? cache;
  final Future<MediaThumbnailCache>? cacheFuture;
  final ThumbnailBytesLoader loadBytes;
  final BoxFit fit;
  final ThumbnailImageBuilder? imageBuilder;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? failedBuilder;

  @override
  State<CachedThumbnailImage> createState() => _CachedThumbnailImageState();
}

class _CachedThumbnailImageState extends State<CachedThumbnailImage> {
  Uint8List? _bytes;
  bool _failed = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadMemoryBytes();
    _load();
  }

  @override
  void didUpdateWidget(covariant CachedThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey) {
      _bytes = null;
      _failed = false;
      _loadMemoryBytes();
      _load();
      return;
    }
    if (_bytes == null && oldWidget.cache != widget.cache) {
      if (_loadMemoryBytes()) setState(() {});
    }
  }

  bool _loadMemoryBytes() {
    final cacheKey = widget.cacheKey.trim();
    if (cacheKey.isEmpty) return false;
    final bytes = widget.cache?.peek(cacheKey);
    if (bytes == null) return false;
    _bytes = bytes;
    _precache(bytes);
    return true;
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final cacheKey = widget.cacheKey.trim();
    final cache = await _readCache(cacheKey, generation);
    if (!mounted || generation != _loadGeneration || _bytes != null) return;

    try {
      final bytes = await widget.loadBytes();
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _bytes = bytes);
      if (cacheKey.isNotEmpty && cache != null) {
        unawaited(_writeCache(cache, cacheKey, bytes));
      }
    } on Object {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _failed = true);
    }
  }

  Future<MediaThumbnailCache?> _readCache(
    String cacheKey,
    int generation,
  ) async {
    if (cacheKey.isEmpty) return null;
    try {
      final cache = widget.cache ?? await widget.cacheFuture;
      if (cache == null) return null;
      final cached = cache.peek(cacheKey) ?? await cache.read(cacheKey);
      if (!mounted || generation != _loadGeneration) return cache;
      if (cached != null) {
        setState(() => _bytes = cached);
        _precache(cached);
      }
      return cache;
    } on Object {
      return null;
    }
  }

  Future<void> _writeCache(
    MediaThumbnailCache cache,
    String cacheKey,
    Uint8List bytes,
  ) async {
    try {
      await cache.write(cacheKey, bytes);
    } on Object {
      // Thumbnail caching is an optimization; render success must not depend on
      // local disk writes.
    }
  }

  void _precache(Uint8List bytes) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        precacheImage(
          MemoryImage(bytes),
          context,
          onError: (_, __) {},
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      final imageBuilder = widget.imageBuilder;
      if (imageBuilder != null) return imageBuilder(context, bytes);
      return Image.memory(bytes, fit: widget.fit);
    }
    if (_failed) {
      return widget.failedBuilder?.call(context) ?? const SizedBox.shrink();
    }
    return widget.loadingBuilder?.call(context) ?? const SizedBox.shrink();
  }
}

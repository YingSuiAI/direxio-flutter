import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/media_thumbnail_cache.dart';

typedef ThumbnailBytesLoader = Future<Uint8List> Function();
typedef ThumbnailImageBuilder = Widget Function(
  BuildContext context,
  Uint8List bytes,
);
typedef ThumbnailBytesValidator = bool Function(Uint8List bytes);

class CachedThumbnailImage extends StatefulWidget {
  const CachedThumbnailImage({
    super.key,
    required this.cacheKey,
    this.cache,
    required this.cacheFuture,
    required this.loadBytes,
    this.initialBytes,
    this.fit = BoxFit.cover,
    this.imageBuilder,
    this.loadingBuilder,
    this.failedBuilder,
    this.validateBytes,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 8),
      Duration(seconds: 30),
    ],
    this.keepRetrying = true,
  });

  final String cacheKey;
  final MediaThumbnailCache? cache;
  final Future<MediaThumbnailCache>? cacheFuture;
  final ThumbnailBytesLoader loadBytes;
  final Uint8List? initialBytes;
  final BoxFit fit;
  final ThumbnailImageBuilder? imageBuilder;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? failedBuilder;
  final ThumbnailBytesValidator? validateBytes;
  final List<Duration> retryDelays;
  final bool keepRetrying;

  @override
  State<CachedThumbnailImage> createState() => _CachedThumbnailImageState();
}

class _CachedThumbnailImageState extends State<CachedThumbnailImage>
    with WidgetsBindingObserver {
  Uint8List? _bytes;
  bool _failed = false;
  int _loadGeneration = 0;
  int _retryAttempt = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialBytes();
    _loadMemoryBytes();
    _load();
  }

  @override
  void didUpdateWidget(covariant CachedThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey) {
      _retryTimer?.cancel();
      _retryAttempt = 0;
      _bytes = null;
      _failed = false;
      _loadInitialBytes();
      _loadMemoryBytes();
      _load();
      return;
    }
    if (_bytes == null && oldWidget.initialBytes != widget.initialBytes) {
      if (_loadInitialBytes()) setState(() {});
    }
    if (_bytes == null && oldWidget.cache != widget.cache) {
      if (_loadMemoryBytes()) setState(() {});
    }
    if (_bytes == null && _failed && _loadMemoryBytes()) {
      _retryTimer?.cancel();
      _retryAttempt = 0;
      setState(() => _failed = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _bytes != null) return;
    _retryTimer?.cancel();
    _retryAttempt = 0;
    if (_loadMemoryBytes()) {
      setState(() => _failed = false);
      return;
    }
    if (_failed) setState(() => _failed = false);
    _load();
  }

  bool _loadMemoryBytes() {
    final cacheKey = widget.cacheKey.trim();
    if (cacheKey.isEmpty) return false;
    final bytes = widget.cache?.peek(cacheKey);
    if (bytes == null) return false;
    if (!_isUsableBytes(bytes)) return false;
    _bytes = bytes;
    _precache(bytes);
    return true;
  }

  bool _loadInitialBytes() {
    final bytes = widget.initialBytes;
    if (bytes == null || !_isUsableBytes(bytes)) return false;
    _bytes = bytes;
    _precache(bytes);
    final cacheKey = widget.cacheKey.trim();
    if (cacheKey.isNotEmpty) {
      unawaited(_writeCacheWhenReady(_resolveCache(), cacheKey, bytes));
    }
    return true;
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final cacheKey = widget.cacheKey.trim();
    final cacheRead = _readCache(cacheKey, generation);

    try {
      final bytes = await widget.loadBytes();
      if (!mounted || generation != _loadGeneration || _bytes != null) return;
      if (!_isUsableBytes(bytes)) {
        throw StateError('thumbnail bytes failed validation');
      }
      _retryTimer?.cancel();
      _retryAttempt = 0;
      setState(() {
        _bytes = bytes;
        _failed = false;
      });
      if (cacheKey.isNotEmpty) {
        unawaited(_writeCacheWhenReady(cacheRead, cacheKey, bytes));
      }
    } on Object {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _failed = true);
      _scheduleRetry();
    }
  }

  Future<void> _writeCacheWhenReady(
    Future<MediaThumbnailCache?> cacheFuture,
    String cacheKey,
    Uint8List bytes,
  ) async {
    final cache = await cacheFuture;
    if (cache == null) return;
    await _writeCache(cache, cacheKey, bytes);
  }

  Future<MediaThumbnailCache?> _resolveCache() async {
    final cache = widget.cache;
    if (cache != null) return cache;
    final cacheFuture = widget.cacheFuture;
    if (cacheFuture == null) return null;
    return cacheFuture;
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    if (widget.retryDelays.isEmpty) return;
    if (!widget.keepRetrying && _retryAttempt >= widget.retryDelays.length) {
      return;
    }
    final delay = widget.retryDelays[_retryAttempt < widget.retryDelays.length
        ? _retryAttempt
        : widget.retryDelays.length - 1];
    if (_retryAttempt < widget.retryDelays.length) _retryAttempt += 1;
    _retryTimer = Timer(delay, () {
      if (!mounted || _bytes != null) return;
      setState(() => _failed = false);
      _load();
    });
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
        if (_bytes != null) return cache;
        if (!_isUsableBytes(cached)) return cache;
        setState(() => _bytes = cached);
        _precache(cached);
      }
      return cache;
    } on Object {
      return null;
    }
  }

  bool _isUsableBytes(Uint8List bytes) {
    final validate = widget.validateBytes;
    return validate == null || validate(bytes);
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
      return Image.memory(
        bytes,
        fit: widget.fit,
        errorBuilder: (_, __, ___) =>
            widget.failedBuilder?.call(context) ?? const SizedBox.shrink(),
      );
    }
    if (_failed) {
      return widget.failedBuilder?.call(context) ?? const SizedBox.shrink();
    }
    return widget.loadingBuilder?.call(context) ?? const SizedBox.shrink();
  }
}

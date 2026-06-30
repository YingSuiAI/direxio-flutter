import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

enum AvatarShape { circle, squircle }

/// 头像 —— M3 风格。
/// 默认圆形（IM 会话/联系人头像）；登录 app icon 等用 squircle（22.5% 圆角）。
class PortalAvatar extends StatefulWidget {
  const PortalAvatar({
    super.key,
    required this.seed,
    this.size = 40,
    this.imageUrl,
    this.imageAsset,
    this.imageBytes,
    this.stableCacheKey,
    this.shape = AvatarShape.circle,
  });

  final String seed;
  final double size;
  final String? imageUrl;
  final String? imageAsset;
  final Uint8List? imageBytes;
  final String? stableCacheKey;
  final AvatarShape shape;

  @override
  State<PortalAvatar> createState() => _PortalAvatarState();
}

class _PortalAvatarState extends State<PortalAvatar> {
  Uint8List? _lastNetworkBytes;
  String? _lastNetworkSeed;
  String? _lastNetworkImageUrl;
  String? _lastNetworkStableKey;
  String? _lastNetworkAuthKey;

  @override
  void didUpdateWidget(covariant PortalAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextImageUrl = widget.imageUrl?.trim() ?? '';
    if (nextImageUrl.isEmpty) {
      _clearRetainedNetworkBytes();
      return;
    }
    final oldStableKey = _normalizedStableCacheKey(oldWidget.stableCacheKey);
    final nextStableKey = _normalizedStableCacheKey(widget.stableCacheKey);
    if (oldStableKey != null && oldStableKey == nextStableKey) return;
    final oldImageUrl = oldWidget.imageUrl?.trim() ?? '';
    if (oldImageUrl.isNotEmpty && oldImageUrl == nextImageUrl) return;
    if (oldWidget.seed == widget.seed) return;
    _clearRetainedNetworkBytes();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final hash = widget.seed.codeUnits.fold<int>(0, (a, b) => a + b);
    // M3 容器色系——克制、和谐
    final palette = <(Color bg, Color fg)>[
      (t.primaryContainer, t.onPrimaryContainer),
      (const Color(0xFFE0DFE4), const Color(0xFF1A1B1F)), // secondary-container
      (const Color(0xFFD8E2FF), const Color(0xFF001A41)), // primary-fixed
      (const Color(0xFFC8E6C9), const Color(0xFF002107)), // tertiary tint
    ];
    final (bg, fg) = palette[hash % palette.length];
    // Matrix ID @localpart:domain → use localpart's first letter, not '@'
    final effective = (widget.seed.startsWith('@') && widget.seed.contains(':'))
        ? widget.seed.substring(1, widget.seed.indexOf(':'))
        : widget.seed;
    final letter =
        effective.isNotEmpty ? effective.characters.first.toUpperCase() : '?';

    final radius = widget.shape == AvatarShape.circle
        ? BorderRadius.circular(widget.size / 2)
        : BorderRadius.circular(widget.size * 0.225);
    final imageHeaders = avatarImageHeadersForUrl(
      _matrixClientOf(context),
      widget.imageUrl,
    );
    final networkImageUrl = widget.imageUrl;
    final stableCacheKey = _normalizedStableCacheKey(widget.stableCacheKey);
    final networkCacheKey = networkImageUrl == null
        ? null
        : _portalAvatarMemoryCacheKey(networkImageUrl, imageHeaders);
    final stableMemoryCacheKey = stableCacheKey == null
        ? null
        : _portalAvatarStableMemoryCacheKey(stableCacheKey, imageHeaders);
    final stableDiskCacheKey = stableCacheKey == null
        ? null
        : _portalAvatarStableDiskCacheKey(stableCacheKey, imageHeaders);
    final networkDiskCacheKey =
        networkImageUrl == null ? null : stableDiskCacheKey ?? networkImageUrl;
    final cachedNetworkBytes = _cachedPortalAvatarBytes(
      stableMemoryCacheKey: stableMemoryCacheKey,
      urlMemoryCacheKey: networkCacheKey,
    );
    final retainedNetworkBytes = _retainedNetworkBytes(
      networkImageUrl,
      imageHeaders,
      stableCacheKey,
    );
    if (networkImageUrl != null &&
        cachedNetworkBytes == null &&
        widget.imageBytes == null) {
      _warmPortalAvatarMemoryCache(
        urlMemoryCacheKey: networkCacheKey!,
        stableMemoryCacheKey: stableMemoryCacheKey,
        stableDiskCacheKey: stableDiskCacheKey,
        networkDiskCacheKey: networkDiskCacheKey!,
        imageUrl: networkImageUrl,
        headers: imageHeaders,
        onLoaded: () {
          if (mounted) setState(() {});
        },
      );
    }
    final displayedImageBytes =
        widget.imageBytes ?? cachedNetworkBytes ?? retainedNetworkBytes;
    if (networkImageUrl != null &&
        displayedImageBytes != null &&
        displayedImageBytes.isNotEmpty) {
      if (networkCacheKey != null) {
        _putPortalAvatarMemoryBytes(networkCacheKey, displayedImageBytes);
      }
      if (stableMemoryCacheKey != null) {
        _putPortalAvatarMemoryBytes(stableMemoryCacheKey, displayedImageBytes);
      }
      _rememberNetworkBytes(
        bytes: displayedImageBytes,
        imageUrl: networkImageUrl,
        stableCacheKey: stableCacheKey,
        headers: imageHeaders,
      );
    }

    return RepaintBoundary(
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: displayedImageBytes != null
            ? Image.memory(
                displayedImageBytes,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, error, ___) => _imageError(letter, fg, error),
              )
            : cachedNetworkBytes != null
                ? Image.memory(
                    cachedNetworkBytes,
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, error, ___) =>
                        _imageError(letter, fg, error),
                  )
                : networkImageUrl != null
                    ? Image(
                        key: ValueKey(
                          Object.hash(
                            networkDiskCacheKey,
                            imageHeaders?['authorization'],
                          ),
                        ),
                        image: CachedNetworkImageProvider(
                          networkImageUrl,
                          cacheKey: networkDiskCacheKey,
                          headers: imageHeaders,
                        ),
                        width: widget.size,
                        height: widget.size,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        frameBuilder:
                            (_, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded || frame != null) {
                            return child;
                          }
                          return const SizedBox.expand();
                        },
                        errorBuilder: (_, error, ___) =>
                            _imageError(letter, fg, error),
                      )
                    : widget.imageAsset != null
                        ? Image.asset(
                            widget.imageAsset!,
                            width: widget.size,
                            height: widget.size,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, error, ___) =>
                                _imageError(letter, fg, error),
                          )
                        : _letter(letter, fg),
      ),
    );
  }

  Uint8List? _retainedNetworkBytes(
    String? imageUrl,
    Map<String, String>? headers,
    String? stableCacheKey,
  ) {
    final bytes = _lastNetworkBytes;
    if (imageUrl == null || bytes == null || bytes.isEmpty) return null;
    if (_lastNetworkAuthKey != _portalAvatarAuthKey(headers)) return null;
    if (stableCacheKey != null && stableCacheKey == _lastNetworkStableKey) {
      return bytes;
    }
    if (imageUrl == _lastNetworkImageUrl) return bytes;
    if (_lastNetworkSeed != widget.seed) return null;
    return bytes;
  }

  void _rememberNetworkBytes({
    required Uint8List bytes,
    required String? imageUrl,
    required String? stableCacheKey,
    required Map<String, String>? headers,
  }) {
    if (bytes.isEmpty) return;
    _lastNetworkBytes = bytes;
    _lastNetworkSeed = widget.seed;
    _lastNetworkImageUrl = imageUrl;
    _lastNetworkStableKey = stableCacheKey;
    _lastNetworkAuthKey = _portalAvatarAuthKey(headers);
  }

  void _clearRetainedNetworkBytes() {
    _lastNetworkBytes = null;
    _lastNetworkSeed = null;
    _lastNetworkImageUrl = null;
    _lastNetworkStableKey = null;
    _lastNetworkAuthKey = null;
  }

  Widget _imageError(String letter, Color fg, Object error) {
    if (kDebugMode) {
      debugPrint(
        '[avatar.image] failed seed=${widget.seed} '
        'url=${widget.imageUrl?.trim().isEmpty == false ? widget.imageUrl : '<memory>'} '
        'error=$error',
      );
    }
    return _letter(letter, fg);
  }

  Widget _letter(String letter, Color fg) => Text(
        letter,
        style: AppTheme.sans(
            size: widget.size * 0.42, color: fg, weight: FontWeight.w600),
      );
}

const int _portalAvatarMemoryCacheLimit = 2048;
final _portalAvatarMemoryBytes = <String, Uint8List>{};
final _portalAvatarMemoryLoads = <String, Future<void>>{};

String _portalAvatarMemoryCacheKey(
  String imageUrl,
  Map<String, String>? headers,
) {
  return '$imageUrl\n${_portalAvatarAuthKey(headers)}';
}

String _portalAvatarStableMemoryCacheKey(
  String stableCacheKey,
  Map<String, String>? headers,
) {
  return 'stable:$stableCacheKey\n${_portalAvatarAuthKey(headers)}';
}

String _portalAvatarStableDiskCacheKey(
  String stableCacheKey,
  Map<String, String>? headers,
) {
  return 'portal-avatar:$stableCacheKey\n${_portalAvatarAuthKey(headers)}';
}

String _portalAvatarAuthKey(Map<String, String>? headers) {
  return headers?['authorization'] ?? '';
}

String? _normalizedStableCacheKey(String? stableCacheKey) {
  final trimmed = stableCacheKey?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

Uint8List? _cachedPortalAvatarBytes({
  required String? stableMemoryCacheKey,
  required String? urlMemoryCacheKey,
}) {
  if (stableMemoryCacheKey != null) {
    final stableBytes = _portalAvatarMemoryBytes[stableMemoryCacheKey];
    if (stableBytes != null && stableBytes.isNotEmpty) return stableBytes;
  }
  if (urlMemoryCacheKey == null) return null;
  final urlBytes = _portalAvatarMemoryBytes[urlMemoryCacheKey];
  return urlBytes == null || urlBytes.isEmpty ? null : urlBytes;
}

void _putPortalAvatarMemoryBytes(String key, Uint8List bytes) {
  _portalAvatarMemoryBytes.remove(key);
  _portalAvatarMemoryBytes[key] = bytes;
  while (_portalAvatarMemoryBytes.length > _portalAvatarMemoryCacheLimit) {
    _portalAvatarMemoryBytes.remove(_portalAvatarMemoryBytes.keys.first);
  }
}

void _warmPortalAvatarMemoryCache({
  required String urlMemoryCacheKey,
  required String? stableMemoryCacheKey,
  required String? stableDiskCacheKey,
  required String networkDiskCacheKey,
  required String imageUrl,
  required Map<String, String>? headers,
  required VoidCallback onLoaded,
}) {
  if (_portalAvatarMemoryLoads.containsKey(urlMemoryCacheKey)) return;
  final load = _loadStablePortalAvatarBytes(
    stableMemoryCacheKey: stableMemoryCacheKey,
    stableDiskCacheKey: stableDiskCacheKey,
    onLoaded: onLoaded,
  )
      .then(
        (_) => CachedNetworkImageProvider.defaultCacheManager.getSingleFile(
          imageUrl,
          key: networkDiskCacheKey,
          headers: headers ?? const {},
        ),
      )
      .then((file) => file.readAsBytes())
      .then((bytes) {
    if (bytes.isEmpty) return;
    _putPortalAvatarMemoryBytes(urlMemoryCacheKey, bytes);
    if (stableMemoryCacheKey != null) {
      _putPortalAvatarMemoryBytes(stableMemoryCacheKey, bytes);
    }
    if (stableDiskCacheKey != null) {
      unawaited(_persistStablePortalAvatarBytes(
        imageUrl: imageUrl,
        stableDiskCacheKey: stableDiskCacheKey,
        bytes: bytes,
      ));
    }
    onLoaded();
  }).catchError((_) {
    _portalAvatarMemoryBytes.remove(urlMemoryCacheKey);
  }).whenComplete(() {
    _portalAvatarMemoryLoads.remove(urlMemoryCacheKey);
  });
  _portalAvatarMemoryLoads[urlMemoryCacheKey] = load;
}

Future<void> _loadStablePortalAvatarBytes({
  required String? stableMemoryCacheKey,
  required String? stableDiskCacheKey,
  required VoidCallback onLoaded,
}) async {
  if (stableMemoryCacheKey == null || stableDiskCacheKey == null) return;
  if (_portalAvatarMemoryBytes.containsKey(stableMemoryCacheKey)) return;
  try {
    final cached = await CachedNetworkImageProvider.defaultCacheManager
        .getFileFromCache(stableDiskCacheKey);
    final file = cached?.file;
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;
    _putPortalAvatarMemoryBytes(stableMemoryCacheKey, bytes);
    onLoaded();
  } catch (_) {
    // The URL cache path still has a chance to load the image.
  }
}

Future<void> _persistStablePortalAvatarBytes({
  required String imageUrl,
  required String stableDiskCacheKey,
  required Uint8List bytes,
}) async {
  try {
    await CachedNetworkImageProvider.defaultCacheManager.putFile(
      imageUrl,
      bytes,
      key: stableDiskCacheKey,
      fileExtension: _avatarFileExtension(imageUrl),
    );
  } catch (_) {
    // Memory still keeps the visible avatar stable for this session.
  }
}

@visibleForTesting
void cachePortalAvatarBytesForTesting({
  required String imageUrl,
  required Map<String, String>? headers,
  required Uint8List bytes,
  String? stableCacheKey,
}) {
  _putPortalAvatarMemoryBytes(
    _portalAvatarMemoryCacheKey(imageUrl, headers),
    bytes,
  );
  final stableKey = _normalizedStableCacheKey(stableCacheKey);
  if (stableKey != null) {
    _putPortalAvatarMemoryBytes(
      _portalAvatarStableMemoryCacheKey(stableKey, headers),
      bytes,
    );
  }
}

@visibleForTesting
void clearPortalAvatarMemoryCacheForTesting() {
  _portalAvatarMemoryBytes.clear();
  _portalAvatarMemoryLoads.clear();
}

@visibleForTesting
Map<String, String>? avatarImageHeadersForUrl(Client? client, String? url) {
  final token = client?.accessToken?.trim() ?? '';
  if (token.isEmpty) return null;
  final homeserver = client?.homeserver;
  if (homeserver == null || homeserver.host.isEmpty) return null;
  final uri = Uri.tryParse(url?.trim() ?? '');
  if (uri == null || uri.host.isEmpty) return null;
  if (!_sameOrigin(uri, homeserver)) return null;
  return {'authorization': 'Bearer $token'};
}

Client? _matrixClientOf(BuildContext context) {
  try {
    return ProviderScope.containerOf(context, listen: false)
        .read(matrixClientProvider);
  } catch (_) {
    return null;
  }
}

bool _sameOrigin(Uri left, Uri right) {
  return left.scheme == right.scheme &&
      left.host.toLowerCase() == right.host.toLowerCase() &&
      left.port == right.port;
}

String _avatarFileExtension(String imageUrl) {
  final path = Uri.tryParse(imageUrl)?.path.toLowerCase() ?? '';
  if (path.endsWith('.png')) return 'png';
  if (path.endsWith('.webp')) return 'webp';
  if (path.endsWith('.gif')) return 'gif';
  return 'jpg';
}

/// 在线状态绿点 —— 叠在头像右下角。
class OnlineDot extends StatelessWidget {
  const OnlineDot({super.key, this.size = 12});
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.tertiaryFixed,
        shape: BoxShape.circle,
        border: Border.all(color: t.bg, width: 2),
      ),
    );
  }
}

/// MXID 文本：小号，dim 色，可选中复制。
class PortalMxid extends StatelessWidget {
  const PortalMxid(this.mxid, {super.key, this.size = 12});
  final String mxid;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      mxid,
      style: AppTheme.mono(size: size, color: context.tk.textMute),
    );
  }
}

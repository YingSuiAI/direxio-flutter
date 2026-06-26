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
    this.shape = AvatarShape.circle,
  });

  final String seed;
  final double size;
  final String? imageUrl;
  final String? imageAsset;
  final Uint8List? imageBytes;
  final AvatarShape shape;

  @override
  State<PortalAvatar> createState() => _PortalAvatarState();
}

class _PortalAvatarState extends State<PortalAvatar> {
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
    final networkCacheKey = networkImageUrl == null
        ? null
        : _portalAvatarMemoryCacheKey(networkImageUrl, imageHeaders);
    final cachedNetworkBytes = networkCacheKey == null
        ? null
        : _portalAvatarMemoryBytes[networkCacheKey];
    if (networkImageUrl != null && cachedNetworkBytes == null) {
      _warmPortalAvatarMemoryCache(
        cacheKey: networkCacheKey!,
        imageUrl: networkImageUrl,
        headers: imageHeaders,
        onLoaded: () {
          if (mounted) setState(() {});
        },
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: widget.imageBytes != null
          ? Image.memory(
              widget.imageBytes!,
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
                          networkImageUrl,
                          imageHeaders?['authorization'],
                        ),
                      ),
                      image: CachedNetworkImageProvider(
                        networkImageUrl,
                        cacheKey: networkImageUrl,
                        headers: imageHeaders,
                      ),
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
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
    );
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

const int _portalAvatarMemoryCacheLimit = 256;
final _portalAvatarMemoryBytes = <String, Uint8List>{};
final _portalAvatarMemoryLoads = <String, Future<void>>{};

String _portalAvatarMemoryCacheKey(
  String imageUrl,
  Map<String, String>? headers,
) {
  return '$imageUrl\n${headers?['authorization'] ?? ''}';
}

void _putPortalAvatarMemoryBytes(String key, Uint8List bytes) {
  _portalAvatarMemoryBytes.remove(key);
  _portalAvatarMemoryBytes[key] = bytes;
  while (_portalAvatarMemoryBytes.length > _portalAvatarMemoryCacheLimit) {
    _portalAvatarMemoryBytes.remove(_portalAvatarMemoryBytes.keys.first);
  }
}

void _warmPortalAvatarMemoryCache({
  required String cacheKey,
  required String imageUrl,
  required Map<String, String>? headers,
  required VoidCallback onLoaded,
}) {
  if (_portalAvatarMemoryLoads.containsKey(cacheKey)) return;
  final load = CachedNetworkImageProvider.defaultCacheManager
      .getSingleFile(imageUrl, key: imageUrl, headers: headers ?? const {})
      .then((file) => file.readAsBytes())
      .then((bytes) {
    if (bytes.isEmpty) return;
    _putPortalAvatarMemoryBytes(cacheKey, bytes);
    onLoaded();
  }).catchError((_) {
    _portalAvatarMemoryBytes.remove(cacheKey);
  }).whenComplete(() {
    _portalAvatarMemoryLoads.remove(cacheKey);
  });
  _portalAvatarMemoryLoads[cacheKey] = load;
}

@visibleForTesting
void cachePortalAvatarBytesForTesting({
  required String imageUrl,
  required Map<String, String>? headers,
  required Uint8List bytes,
}) {
  _putPortalAvatarMemoryBytes(
    _portalAvatarMemoryCacheKey(imageUrl, headers),
    bytes,
  );
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

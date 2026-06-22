import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../providers/auth_provider.dart';
import '../providers/matrix_media_cache_provider.dart';

const channelPostMaxImages = 9;

class ChannelPostMediaImage {
  const ChannelPostMediaImage({
    required this.url,
    this.name = '',
    this.mimeType = '',
    this.size,
  });

  final String url;
  final String name;
  final String mimeType;
  final int? size;

  Map<String, Object?> toJson() {
    return {
      'url': url,
      if (name.isNotEmpty) 'name': name,
      if (mimeType.isNotEmpty || size != null)
        'info': {
          if (mimeType.isNotEmpty) 'mimetype': mimeType,
          if (size != null) 'size': size,
        },
    };
  }
}

Map<String, Object?> channelPostMediaForImages(
  List<ChannelPostMediaImage> images,
) {
  final normalized = images
      .where((image) => image.url.trim().isNotEmpty)
      .take(channelPostMaxImages)
      .toList(growable: false);
  if (normalized.isEmpty) return const {};
  final first = normalized.first;
  return {
    'url': first.url,
    if (first.name.isNotEmpty) 'name': first.name,
    if (first.mimeType.isNotEmpty || first.size != null)
      'info': {
        if (first.mimeType.isNotEmpty) 'mimetype': first.mimeType,
        if (first.size != null) 'size': first.size,
      },
    'images': [for (final image in normalized) image.toJson()],
  };
}

List<ChannelPostMediaImage> channelPostImagesFromPost(AsChannelPost post) {
  return channelPostImagesFromMedia(post.media);
}

List<ChannelPostMediaImage> channelPostImagesFromMedia(
  Map<String, Object?> media,
) {
  final images = <ChannelPostMediaImage>[];
  final rawImages = media['images'];
  if (rawImages is List) {
    for (final item in rawImages) {
      final parsed = _imageFromAny(item);
      if (parsed != null) images.add(parsed);
    }
  }

  final fallback = _imageFromAny(media);
  if (fallback != null &&
      images.every((image) => image.url.trim() != fallback.url.trim())) {
    images.insert(0, fallback);
  }

  return images
      .where((image) => image.url.trim().isNotEmpty)
      .take(channelPostMaxImages)
      .toList(growable: false);
}

ChannelPostMediaImage? _imageFromAny(Object? raw) {
  if (raw is String) {
    final url = raw.trim();
    if (url.isEmpty) return null;
    return ChannelPostMediaImage(url: url);
  }
  if (raw is! Map) return null;
  final map = raw.cast<String, Object?>();
  final url = (map['url'] as String? ?? '').trim();
  if (url.isEmpty) return null;
  final info = map['info'] is Map
      ? (map['info'] as Map).cast<String, Object?>()
      : const <String, Object?>{};
  return ChannelPostMediaImage(
    url: url,
    name: map['name'] as String? ?? '',
    mimeType: info['mimetype'] as String? ?? map['mimetype'] as String? ?? '',
    size: info['size'] is int ? info['size'] as int : null,
  );
}

class ChannelPostImageGrid extends StatelessWidget {
  const ChannelPostImageGrid({
    super.key,
    required this.images,
    this.spacing = 5,
    this.maxColumns = 3,
  });

  final List<ChannelPostMediaImage> images;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    final visible = images.take(channelPostMaxImages).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = maxColumns.clamp(1, channelPostMaxImages);
        final itemSize =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final image in visible)
              SizedBox.square(
                dimension: itemSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: _ChannelPostImageTile(image: image),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChannelPostImageTile extends ConsumerWidget {
  const _ChannelPostImageTile({required this.image});

  final ChannelPostMediaImage image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final url = image.url.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(t),
      );
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isScheme('mxc')) return _fallback(t);
    return FutureBuilder<Uint8List>(
      future: ref
          .read(matrixMediaBytesCacheProvider)
          .read(ref.read(matrixClientProvider), uri),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(bytes, fit: BoxFit.cover);
        }
        if (snapshot.hasError) return _fallback(t);
        return Container(
          color: t.surfaceHigh,
          alignment: Alignment.center,
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
          ),
        );
      },
    );
  }

  Widget _fallback(PortalTokens t) {
    return Container(
      color: t.surfaceHigh,
      alignment: Alignment.center,
      child: Icon(Symbols.broken_image, color: t.textMute, size: 28),
    );
  }
}

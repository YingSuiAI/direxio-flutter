import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/media_thumbnail_cache.dart';

final mediaThumbnailCacheProvider = FutureProvider<MediaThumbnailCache>((
  ref,
) async {
  final dir = await getApplicationSupportDirectory();
  return MemoryBackedMediaThumbnailCache(
    FileMediaThumbnailCache(
      Directory('${dir.path}/portal_im_media_thumbnails'),
    ),
  );
});

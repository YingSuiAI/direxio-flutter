import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/media_thumbnail_cache.dart';

void main() {
  late Directory tempDir;
  late FileMediaThumbnailCache cache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('portal_media_cache_test');
    cache = FileMediaThumbnailCache(tempDir);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('persists thumbnail bytes by Matrix event id', () async {
    const eventId = r'$event/with:unsafe?chars';

    await cache.write(eventId, Uint8List.fromList([1, 2, 3]));

    expect(await cache.read(eventId), [1, 2, 3]);
    expect(tempDir.listSync(), hasLength(1));
    expect(tempDir.listSync().single.path, isNot(contains('/unsafe')));
  });

  test('ignores empty keys and oversized payloads', () async {
    final smallCache = FileMediaThumbnailCache(tempDir, maxBytes: 2);

    await smallCache.write('', Uint8List.fromList([1]));
    await smallCache.write(r'$too-large', Uint8List.fromList([1, 2, 3]));

    expect(await smallCache.read(''), isNull);
    expect(await smallCache.read(r'$too-large'), isNull);
    expect(tempDir.listSync(), isEmpty);
  });

  test('memory-backed cache warms disk thumbnails into synchronous memory',
      () async {
    await cache.write(r'$event-1', Uint8List.fromList([1, 2, 3]));
    final memoryCache = MemoryBackedMediaThumbnailCache(cache);

    expect(memoryCache.peek(r'$event-1'), isNull);

    await memoryCache.warm([r'$event-1']);

    expect(memoryCache.peek(r'$event-1'), [1, 2, 3]);
    expect(await memoryCache.read(r'$event-1'), [1, 2, 3]);
  });

  test('memory-backed cache keeps writes readable before disk is touched',
      () async {
    final memoryCache = MemoryBackedMediaThumbnailCache(cache);

    await memoryCache.write(r'$event-2', Uint8List.fromList([4, 5, 6]));

    expect(memoryCache.peek(r'$event-2'), [4, 5, 6]);
    expect(await cache.read(r'$event-2'), [4, 5, 6]);
  });
}

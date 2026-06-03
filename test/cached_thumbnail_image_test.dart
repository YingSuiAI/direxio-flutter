import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/data/media_thumbnail_cache.dart';
import 'package:portal_app/presentation/chat/cached_thumbnail_image.dart';

void main() {
  testWidgets('reloads bytes when reused for a different cache key',
      (tester) async {
    final cache = _MemoryThumbnailCache();

    await tester.pumpWidget(_App(
      child: CachedThumbnailImage(
        cacheKey: r'$first',
        cacheFuture: Future.value(cache),
        loadBytes: () async => Uint8List.fromList([1]),
        imageBuilder: (_, bytes) => Text(bytes.join(',')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    await tester.pumpWidget(_App(
      child: CachedThumbnailImage(
        cacheKey: r'$second',
        cacheFuture: Future.value(cache),
        loadBytes: () async => Uint8List.fromList([2]),
        imageBuilder: (_, bytes) => Text(bytes.join(',')),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('renders memory-warmed bytes without showing loading',
      (tester) async {
    final cache = _MemoryThumbnailCache();
    await cache.write(r'$warm', Uint8List.fromList([7]));

    await tester.pumpWidget(_App(
      child: CachedThumbnailImage(
        cacheKey: r'$warm',
        cache: cache,
        cacheFuture: Future.value(cache),
        loadBytes: () async => Uint8List.fromList([9]),
        imageBuilder: (_, bytes) => Text(bytes.join(',')),
        loadingBuilder: (_) => const Text('loading'),
      ),
    ));

    expect(find.text('7'), findsOneWidget);
    expect(find.text('loading'), findsNothing);
  });
}

class _App extends StatelessWidget {
  const _App({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: child));
  }
}

class _MemoryThumbnailCache implements MediaThumbnailCache {
  final _items = <String, Uint8List>{};

  @override
  Uint8List? peek(String key) => _items[key];

  @override
  Future<Uint8List?> read(String key) async => _items[key];

  @override
  Future<void> write(String key, List<int> bytes) async {
    _items[key] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> warm(Iterable<String> keys) async {}
}

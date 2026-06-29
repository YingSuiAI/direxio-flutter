import 'dart:async';
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

  testWidgets('starts preview load without waiting for pending cache',
      (tester) async {
    final cacheCompleter = Completer<MediaThumbnailCache>();
    var loadAttempts = 0;

    await tester.pumpWidget(_App(
      child: CachedThumbnailImage(
        cacheKey: r'$pending-cache',
        cacheFuture: cacheCompleter.future,
        loadBytes: () async {
          loadAttempts += 1;
          return Uint8List.fromList([5]);
        },
        imageBuilder: (_, bytes) => Text(bytes.join(',')),
        loadingBuilder: (_) => const Text('loading'),
      ),
    ));

    await tester.pump();

    expect(loadAttempts, 1);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('loading'), findsNothing);

    cacheCompleter.complete(_MemoryThumbnailCache());
    await tester.pump();
  });

  testWidgets('ignores invalid cached bytes and reloads preview',
      (tester) async {
    final cache = _MemoryThumbnailCache();
    await cache.write(r'$bad-cache', Uint8List.fromList([1, 2, 3]));
    var loadAttempts = 0;

    await tester.pumpWidget(_App(
      child: CachedThumbnailImage(
        cacheKey: r'$bad-cache',
        cache: cache,
        cacheFuture: Future.value(cache),
        validateBytes: (bytes) =>
            bytes.length >= 3 &&
            bytes[0] == 0xFF &&
            bytes[1] == 0xD8 &&
            bytes[2] == 0xFF,
        loadBytes: () async {
          loadAttempts += 1;
          return Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
        },
        imageBuilder: (_, bytes) => Text(bytes.join(',')),
        loadingBuilder: (_) => const Text('loading'),
      ),
    ));

    await tester.pump();

    expect(loadAttempts, 1);
    expect(find.text('255,216,255,224'), findsOneWidget);
    expect(find.text('1,2,3'), findsNothing);
  });

  testWidgets('renders failed placeholder when thumbnail bytes are invalid',
      (tester) async {
    await tester.pumpWidget(_App(
      child: CachedThumbnailImage(
        cacheKey: r'$bad',
        cacheFuture: null,
        loadBytes: () async => Uint8List.fromList([1, 2, 3]),
        failedBuilder: (_) => const Text('bad thumbnail'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('bad thumbnail'), findsOneWidget);
  });

  testWidgets('retries transient load failures for the same thumbnail',
      (tester) async {
    var attempts = 0;

    await tester.pumpWidget(_App(
      child: CachedThumbnailImage(
        cacheKey: r'$flaky',
        cacheFuture: null,
        retryDelays: const [Duration(milliseconds: 10)],
        loadBytes: () async {
          attempts += 1;
          if (attempts == 1) {
            throw StateError('offline');
          }
          return Uint8List.fromList([4]);
        },
        imageBuilder: (_, bytes) => Text(bytes.join(',')),
        failedBuilder: (_) => const Text('temporary failure'),
      ),
    ));

    await tester.pump();
    expect(find.text('temporary failure'), findsOneWidget);
    expect(attempts, 1);

    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();

    expect(find.text('4'), findsOneWidget);
    expect(find.text('temporary failure'), findsNothing);
    expect(attempts, 2);
  });

  testWidgets('keeps retrying visible thumbnails after retry delays are used',
      (tester) async {
    var attempts = 0;
    var online = false;

    await tester.pumpWidget(_App(
      child: CachedThumbnailImage(
        cacheKey: r'$eventual',
        cacheFuture: null,
        retryDelays: const [
          Duration(milliseconds: 10),
          Duration(milliseconds: 20),
        ],
        loadBytes: () async {
          attempts += 1;
          if (!online) throw StateError('offline');
          return Uint8List.fromList([6]);
        },
        imageBuilder: (_, bytes) => Text(bytes.join(',')),
        failedBuilder: (_) => Text('failed $attempts'),
      ),
    ));

    await tester.pump();
    expect(find.text('failed 1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(find.text('failed 2'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(find.text('failed 3'), findsOneWidget);

    online = true;
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(find.text('6'), findsOneWidget);
    expect(attempts, 4);
  });

  testWidgets('retries immediately when app resumes from background',
      (tester) async {
    var attempts = 0;
    var online = false;

    await tester.pumpWidget(_App(
      child: CachedThumbnailImage(
        cacheKey: r'$foreground',
        cacheFuture: null,
        retryDelays: const [Duration(hours: 1)],
        loadBytes: () async {
          attempts += 1;
          if (!online) throw StateError('offline');
          return Uint8List.fromList([3]);
        },
        imageBuilder: (_, bytes) => Text(bytes.join(',')),
        failedBuilder: (_) => Text('failed $attempts'),
      ),
    ));

    await tester.pump();
    expect(find.text('failed 1'), findsOneWidget);
    expect(attempts, 1);

    online = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('failed 1'), findsNothing);
    expect(attempts, 2);
  });

  testWidgets(
      'recovers from failed state when parent rebuild finds cache bytes',
      (tester) async {
    final cache = _MemoryThumbnailCache();
    var version = 0;

    Widget buildSubject() {
      return _App(
        child: Column(
          children: [
            Text('version $version'),
            CachedThumbnailImage(
              cacheKey: r'$recover',
              cache: cache,
              cacheFuture: Future.value(cache),
              loadBytes: () async => throw StateError('offline'),
              imageBuilder: (_, bytes) => Text(bytes.join(',')),
              failedBuilder: (_) => const Text('failed'),
              loadingBuilder: (_) => const Text('loading'),
            ),
          ],
        ),
      );
    }

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('failed'), findsOneWidget);

    await cache.write(r'$recover', Uint8List.fromList([8]));
    version += 1;
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('8'), findsOneWidget);
    expect(find.text('failed'), findsNothing);
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

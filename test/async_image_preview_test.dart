import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:portal_app/presentation/widgets/async_image_preview.dart';

void main() {
  testWidgets('opens preview shell before image bytes finish loading',
      (tester) async {
    final completer = Completer<ImageProvider>();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                unawaited(showAsyncImagePreview(
                  context,
                  loadProvider: () => completer.future,
                  meta: '我 · 16:25',
                ));
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('我 · 16:25'), findsOneWidget);

    completer.complete(MemoryImage(_transparentPng));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('shows preview image while full image is still loading',
      (tester) async {
    final fullCompleter = Completer<ImageProvider>();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                unawaited(showAsyncImagePreview(
                  context,
                  loadPreviewProvider: () async => MemoryImage(_transparentPng),
                  loadProvider: () => fullCompleter.future,
                  meta: '我 · 16:25',
                ));
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    fullCompleter.complete(MemoryImage(_transparentPng));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('shows initial preview before async loaders settle',
      (tester) async {
    final previewCompleter = Completer<ImageProvider>();
    final fullCompleter = Completer<ImageProvider>();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                unawaited(showAsyncImagePreview(
                  context,
                  initialPreviewProvider: MemoryImage(_transparentPng),
                  loadPreviewProvider: () => previewCompleter.future,
                  loadProvider: () => fullCompleter.future,
                  meta: '我 · 16:25',
                ));
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('keeps the previous frame while swapping preview to full image',
      (tester) async {
    final fullCompleter = Completer<ImageProvider>();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                unawaited(showAsyncImagePreview(
                  context,
                  loadPreviewProvider: () async => MemoryImage(_transparentPng),
                  loadProvider: () => fullCompleter.future,
                  meta: '我 · 16:25',
                ));
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final previewImage = tester.widget<Image>(find.byType(Image));
    expect(previewImage.gaplessPlayback, isTrue);

    fullCompleter.complete(MemoryImage(_transparentPng));
    await tester.pumpAndSettle();

    final fullImage = tester.widget<Image>(find.byType(Image));
    expect(fullImage.gaplessPlayback, isTrue);
  });

  testWidgets('does not expose separate forward or download toolbar actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                unawaited(showAsyncImagePreview(
                  context,
                  loadProvider: () async => MemoryImage(_transparentPng),
                  meta: '我 · 16:25',
                ));
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Symbols.close), findsOneWidget);
    expect(find.byIcon(Symbols.forward), findsNothing);
    expect(find.byIcon(Symbols.download), findsNothing);
  });

  testWidgets('shows bottom save-to-album action when provided',
      (tester) async {
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                unawaited(showAsyncImagePreview(
                  context,
                  loadProvider: () async => MemoryImage(_transparentPng),
                  meta: '我 · 16:25',
                  onDownload: () async => saves++,
                ));
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('保存原图到相册'), findsOneWidget);
    expect(find.byIcon(Symbols.download), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.download));
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(find.byIcon(Symbols.check), findsOneWidget);
    expect(find.byTooltip('原图已保存'), findsOneWidget);
  });
}

final _transparentPng = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

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

  testWidgets('shows bottom download action when provided', (tester) async {
    var downloads = 0;
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
                  onDownload: () async => downloads++,
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

    expect(find.byIcon(Symbols.download), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.download));
    await tester.pumpAndSettle();

    expect(downloads, 1);
    expect(find.byIcon(Symbols.check), findsOneWidget);
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

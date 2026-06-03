import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/chat/local_outbox_image_thumb.dart';

void main() {
  testWidgets('pending outbox image uses bounded memory decode',
      (tester) async {
    await tester.pumpWidget(_App(
      child: PendingLocalOutboxImageThumb(bytes: _transparentPng),
    ));

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(provider.width, LocalOutboxImageThumbDefaults.decodeWidth);
    expect(image.filterQuality, FilterQuality.low);
  });

  testWidgets('failed outbox image avoids expensive color filter',
      (tester) async {
    await tester.pumpWidget(_App(
      child: FailedLocalOutboxImageThumb(bytes: _transparentPng),
    ));

    expect(find.byType(ColorFiltered), findsNothing);
    expect(find.byIcon(Symbols.refresh), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(provider.width, LocalOutboxImageThumbDefaults.decodeWidth);
  });

  testWidgets('failed outbox image can render without decoding original bytes',
      (tester) async {
    await tester.pumpWidget(const _App(
      child: FailedLocalOutboxImageThumb(bytes: null),
    ));

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Symbols.refresh), findsOneWidget);
  });

  testWidgets('failed outbox image keeps thumbnail visible behind retry badge',
      (tester) async {
    await tester.pumpWidget(_App(
      child: FailedLocalOutboxImageThumb(bytes: _transparentPng),
    ));

    expect(find.byType(Image), findsOneWidget);
    final align = tester.widget<Align>(
      find.ancestor(
        of: find.byIcon(Symbols.refresh),
        matching: find.byType(Align),
      ),
    );
    expect(align.alignment, Alignment.bottomRight);
  });

  testWidgets('failed outbox retry badge invokes callback', (tester) async {
    var retried = false;

    await tester.pumpWidget(_App(
      child: FailedLocalOutboxImageThumb(
        bytes: _transparentPng,
        onRetry: () => retried = true,
      ),
    ));

    await tester.tap(find.byIcon(Symbols.refresh));

    expect(retried, isTrue);
  });
}

class _App extends StatelessWidget {
  const _App({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
          body: Center(child: SizedBox.square(dimension: 120, child: child))),
    );
  }
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

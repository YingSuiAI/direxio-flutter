import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/main.dart';

void main() {
  testWidgets('startup splash overlay uses only the launch image',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StartupSplashOverlay(
          child: SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('startup splash does not reveal child before launch image loads',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: _NeverCompletesAssetBundle(),
          child: const StartupSplashOverlay(
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1600));

    final opacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacity.opacity, 1);
  });
}

class _NeverCompletesAssetBundle extends CachingAssetBundle {
  final Completer<ByteData> _bytes = Completer<ByteData>();
  final Completer<ui.ImmutableBuffer> _buffer = Completer<ui.ImmutableBuffer>();

  @override
  Future<ByteData> load(String key) => _bytes.future;

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) => _buffer.future;
}

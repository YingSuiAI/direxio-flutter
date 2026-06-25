import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/core/theme/design_tokens.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/widgets/avatar_adjust_sheet.dart';

final _png1x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
);

void main() {
  test('avatarCoverSize always covers the square crop box', () {
    final wide = avatarCoverSize(const Size(1200, 800), 300);
    expect(wide.width, 450);
    expect(wide.height, 300);

    final tall = avatarCoverSize(const Size(800, 1200), 300);
    expect(tall.width, 300);
    expect(tall.height, 450);
  });

  test('clampAvatarOffset prevents exposing empty crop edges', () {
    final clamped = clampAvatarOffset(
      const Offset(500, -500),
      baseSize: const Size(450, 300),
      cropSize: 300,
      scale: 1,
    );

    expect(clamped.dx, 75);
    expect(clamped.dy, 0);
  });

  testWidgets('avatar adjust sheet exposes pan zoom controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: AvatarAdjustSheet(
            imageBytes: Uint8List.fromList(_png1x1),
            initialImageSize: const Size(1, 1),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Adjust avatar'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Pinch to zoom or drag the image'), findsOneWidget);
    expect(find.text('调整头像'), findsNothing);
  });

  testWidgets('avatar adjust sheet uses dark theme surface tokens',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AvatarAdjustSheet(
            imageBytes: Uint8List.fromList(_png1x1),
            initialImageSize: const Size(1, 1),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final rootDecoration = tester
        .widget<DecoratedBox>(find.byType(DecoratedBox).first)
        .decoration as BoxDecoration;
    expect(rootDecoration.color, PortalTokens.dark.bg);

    final previewBg = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .map((widget) => widget.color)
        .where((color) => color == PortalTokens.dark.surface)
        .toList();
    expect(previewBg, isNotEmpty);
  });

  testWidgets('avatar adjust sheet closes after successful upload',
      (tester) async {
    var uploaded = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: AvatarAdjustSheet(
                        imageBytes: Uint8List.fromList(_png1x1),
                        initialImageSize: const Size(1, 1),
                        exportForTesting: () async =>
                            Uint8List.fromList([1, 2, 3]),
                        onConfirm: (_) async {
                          uploaded = true;
                        },
                      ),
                    ),
                  ),
                );
              },
              child: const Text('打开头像编辑'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('打开头像编辑'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('完成'));
    for (var i = 0; i < 10 && !uploaded; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(uploaded, isTrue);
    expect(find.byType(AvatarAdjustSheet), findsNothing);
  });
}

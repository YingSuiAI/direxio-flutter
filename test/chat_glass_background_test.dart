import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/chat/chat_glass_background.dart';

void main() {
  testWidgets('chat glass background provides translucent blur layer',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ChatGlassBackground(
            child: Text('message area'),
          ),
        ),
      ),
    );

    expect(find.text('message area'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                ChatGlassBackground.assetName,
      ),
      findsOneWidget,
    );
    expect(find.byType(BackdropFilter), findsOneWidget);

    final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    final imageFilter = filter.filter;
    expect(imageFilter, isA<ImageFilter>());
  });
}

import 'package:flutter/material.dart';
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
}

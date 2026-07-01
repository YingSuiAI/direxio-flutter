import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/widgets/center_toast.dart';

void main() {
  testWidgets('showCenterToast displays near the top for two seconds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showCenterToast(context, '聊天记录已清空'),
              child: const Text('show toast'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('show toast'));
    await tester.pump();

    final toastFinder = find.text('聊天记录已清空');
    expect(toastFinder, findsOneWidget);
    expect(tester.getTopLeft(toastFinder).dy, inInclusiveRange(80, 140));
    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(Overlay),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      (decoratedBox.decoration as BoxDecoration).color,
      const Color(0x4D000000),
    );

    await tester.pump(const Duration(milliseconds: 1900));
    expect(toastFinder, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 101));
    expect(toastFinder, findsNothing);
  });
}

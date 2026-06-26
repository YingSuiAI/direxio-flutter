import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/widgets/user_action_debounce.dart';

void main() {
  testWidgets('debounces repeated user actions for 200ms', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UserActionDebounce(
          child: Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('Submit'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.tap(find.text('Submit'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 199));

    expect(taps, 1);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(taps, 2);
  });
}

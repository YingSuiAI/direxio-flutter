import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/chat/chat_capsule_chrome.dart';

void main() {
  testWidgets('slash picker suggestion fills the composer', (tester) async {
    final controller = TextEditingController(text: '/');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Align(
                alignment: Alignment.bottomCenter,
                child: ChatCapsuleInputBar(
                  ctrl: controller,
                  onSend: () {},
                  onPlus: () {},
                  onEmoji: () {},
                  suggestionItems: const [
                    ChatInputSuggestion(
                      label: '/help',
                      description: 'Help · Show commands',
                    ),
                  ],
                  suggestionsLabel: 'Quick commands',
                  onPickSuggestion: (value) {
                    controller.value = TextEditingValue(
                      text: value,
                      selection: TextSelection.collapsed(offset: value.length),
                    );
                    setState(() {});
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Quick commands'), findsOneWidget);
    expect(find.text('/help'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat_input_suggestion_/help')));
    await tester.pump();

    expect(controller.text, '/help');
    expect(controller.selection.baseOffset, '/help'.length);
  });
}

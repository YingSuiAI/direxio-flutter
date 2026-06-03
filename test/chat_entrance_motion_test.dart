import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/chat/chat_capsule_chrome.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('chat entrance motion enters from requested edge',
      (tester) async {
    await tester.pumpWidget(
      Theme(
        data: AppTheme.light,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: ChatDirectionalEntrance(
            key: ValueKey('left_entrance'),
            direction: ChatEntranceDirection.left,
            child: Text('left message'),
          ),
        ),
      ),
    );

    final entrance = find.byKey(const ValueKey('left_entrance'));
    final initialSlide = tester.widget<SlideTransition>(
      find.descendant(of: entrance, matching: find.byType(SlideTransition)),
    );
    final initialFade = tester.widget<FadeTransition>(
      find.descendant(of: entrance, matching: find.byType(FadeTransition)),
    );
    expect(initialSlide.position.value.dx, lessThan(0));
    expect(initialSlide.position.value.dy, 0);
    expect(initialFade.opacity.value, lessThan(1));

    await tester.pump(ChatDirectionalEntrance.duration);
    await tester.pumpAndSettle();

    final settledSlide = tester.widget<SlideTransition>(
      find.descendant(of: entrance, matching: find.byType(SlideTransition)),
    );
    final settledFade = tester.widget<FadeTransition>(
      find.descendant(of: entrance, matching: find.byType(FadeTransition)),
    );
    expect(settledSlide.position.value, Offset.zero);
    expect(settledFade.opacity.value, 1);
  });

  testWidgets('bottom and top entrance directions use vertical offsets',
      (tester) async {
    await tester.pumpWidget(
      Theme(
        data: AppTheme.light,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              ChatDirectionalEntrance(
                key: ValueKey('top_entrance'),
                direction: ChatEntranceDirection.top,
                child: Text('top capsule'),
              ),
              ChatDirectionalEntrance(
                key: ValueKey('bottom_entrance'),
                direction: ChatEntranceDirection.bottom,
                child: Text('bottom capsule'),
              ),
            ],
          ),
        ),
      ),
    );

    final topSlide = tester.widget<SlideTransition>(
      find.descendant(
        of: find.byKey(const ValueKey('top_entrance')),
        matching: find.byType(SlideTransition),
      ),
    );
    final bottomSlide = tester.widget<SlideTransition>(
      find.descendant(
        of: find.byKey(const ValueKey('bottom_entrance')),
        matching: find.byType(SlideTransition),
      ),
    );
    expect(topSlide.position.value.dy, lessThan(0));
    expect(bottomSlide.position.value.dy, greaterThan(0));
  });

  testWidgets('new message list motion shifts the whole timeline upward',
      (tester) async {
    await tester.pumpWidget(
      Theme(
        data: AppTheme.light,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: ChatTimelineListMotion(
            itemCount: 2,
            newestItemKey: 'event-a',
            child: Text('timeline'),
          ),
        ),
      ),
    );

    SlideTransition slide() => tester.widget<SlideTransition>(
          find.byKey(const ValueKey('chat_timeline_list_motion_slide')),
        );

    expect(slide().position.value, Offset.zero);

    await tester.pumpWidget(
      Theme(
        data: AppTheme.light,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: ChatTimelineListMotion(
            itemCount: 3,
            newestItemKey: 'event-b',
            child: Text('timeline'),
          ),
        ),
      ),
    );

    expect(slide().position.value.dx, 0);
    expect(slide().position.value.dy, greaterThan(0));

    await tester.pump(ChatTimelineListMotion.duration);
    await tester.pumpAndSettle();

    expect(slide().position.value, Offset.zero);
  });

  testWidgets('newer message rows can skip directional entrance',
      (tester) async {
    await tester.pumpWidget(
      Theme(
        data: AppTheme.light,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: chatMessageEntrance(
            enabled: false,
            isMe: true,
            index: 0,
            child: const Text('new message'),
          ),
        ),
      ),
    );

    expect(find.byType(SlideTransition), findsNothing);
    expect(find.text('new message'), findsOneWidget);
  });

  test('initial entrance registry ignores empty preloading lists', () {
    final registry = ChatInitialEntranceRegistry();

    registry.seed(const []);
    expect(registry.contains('event-a'), isFalse);

    registry.seed(const ['event-a', 'event-b']);
    expect(registry.contains('event-a'), isTrue);
    expect(registry.contains('event-b'), isTrue);

    registry.seed(const ['event-c']);
    expect(registry.contains('event-c'), isFalse);
  });

  test('initial entrance registry closes after first entrance window', () {
    final registry = ChatInitialEntranceRegistry();

    registry.seed(const ['event-a', 'event-b']);
    expect(registry.contains('event-a'), isTrue);

    registry.close();
    expect(registry.contains('event-a'), isFalse);

    registry.seed(const ['event-c']);
    expect(registry.contains('event-c'), isFalse);
  });
}

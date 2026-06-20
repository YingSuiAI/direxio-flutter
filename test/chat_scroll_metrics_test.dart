import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/chat/chat_scroll_metrics.dart';

void main() {
  testWidgets(
    'returns null while an attached scroll position has no content dimensions',
    (tester) async {
      late BuildContext storageContext;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              storageContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final controller = ScrollController();
      final position = ScrollPositionWithSingleContext(
        physics: const ClampingScrollPhysics(),
        context: _FakeScrollContext(storageContext),
      );
      controller.attach(position);
      addTearDown(() {
        controller.detach(position);
        position.dispose();
        controller.dispose();
      });

      expect(controller.hasClients, isTrue);
      expect(position.hasContentDimensions, isFalse);
      expect(chatScrollPositionWithDimensions(controller), isNull);
    },
  );

  testWidgets('returns the attached scroll position after dimensions are ready',
      (tester) async {
    late BuildContext storageContext;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            storageContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final controller = ScrollController();
    final position = ScrollPositionWithSingleContext(
      physics: const ClampingScrollPhysics(),
      context: _FakeScrollContext(storageContext),
    );
    controller.attach(position);
    addTearDown(() {
      controller.detach(position);
      position.dispose();
      controller.dispose();
    });

    position.applyViewportDimension(320);
    position.applyContentDimensions(0, 800);

    expect(chatScrollPositionWithDimensions(controller), same(position));
  });
}

class _FakeScrollContext implements ScrollContext {
  _FakeScrollContext(this.storageContext);

  @override
  final BuildContext storageContext;

  @override
  BuildContext? get notificationContext => storageContext;

  @override
  TickerProvider get vsync => const TestVSync();

  @override
  AxisDirection get axisDirection => AxisDirection.down;

  @override
  double get devicePixelRatio => 1;

  @override
  void saveOffset(double offset) {}

  @override
  void setCanDrag(bool value) {}

  @override
  void setIgnorePointer(bool value) {}

  @override
  void setSemanticsActions(Set<SemanticsAction> actions) {}
}

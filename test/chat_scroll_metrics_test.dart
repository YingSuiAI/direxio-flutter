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

  testWidgets('chat message controller opens at latest on first layout',
      (tester) async {
    final controller = chatMessageScrollController(openAtLatest: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 200,
          child: ListView.builder(
            controller: controller,
            itemCount: 40,
            itemBuilder: (context, index) => SizedBox(
              height: 40,
              child: Text('message $index'),
            ),
          ),
        ),
      ),
    );

    final position = chatScrollPositionWithDimensions(controller);
    expect(position, isNotNull);
    expect(controller.offset, position!.maxScrollExtent);
  });

  testWidgets('chat message controller follows latest when final item grows',
      (tester) async {
    final controller = chatMessageScrollController(openAtLatest: true);
    addTearDown(controller.dispose);
    var expanded = false;
    late StateSetter updateHeight;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setState) {
            updateHeight = setState;
            return SizedBox(
              height: 200,
              child: ListView.builder(
                controller: controller,
                itemCount: 40,
                itemBuilder: (context, index) {
                  final isLast = index == 39;
                  return SizedBox(
                    height: isLast && expanded ? 160 : 40,
                    child: Text('message $index'),
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    final firstPosition = chatScrollPositionWithDimensions(controller);
    expect(firstPosition, isNotNull);
    expect(controller.offset, firstPosition!.maxScrollExtent);

    updateHeight(() => expanded = true);
    await tester.pump();

    final grownPosition = chatScrollPositionWithDimensions(controller);
    expect(grownPosition, isNotNull);
    expect(controller.offset, grownPosition!.maxScrollExtent);
  });

  testWidgets('chat message position follows latest when dimensions grow',
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

    final controller = chatMessageScrollController(openAtLatest: true);
    final position = controller.createScrollPosition(
      const AlwaysScrollableScrollPhysics(),
      _FakeScrollContext(storageContext),
      null,
    );
    controller.attach(position);
    addTearDown(() {
      controller.detach(position);
      position.dispose();
      controller.dispose();
    });

    position.applyViewportDimension(300);
    position.applyContentDimensions(0, 500);
    expect(position.pixels, 500);

    position.applyContentDimensions(0, 650);
    expect(position.pixels, 650);
  });

  test(
    'latest initial auto-scroll retries while dimensions are missing',
    () {
      expect(
        shouldRetryLatestInitialAutoScroll(
          hasPosition: false,
          isAtLatest: false,
          attempt: 0,
        ),
        isTrue,
      );
      expect(
        shouldRetryLatestInitialAutoScroll(
          hasPosition: false,
          isAtLatest: false,
          attempt: chatLatestInitialAutoScrollMaxAttempts,
        ),
        isFalse,
      );
    },
  );

  test(
    'latest initial auto-scroll keeps settling until it reaches latest',
    () {
      expect(
        shouldRetryLatestInitialAutoScroll(
          hasPosition: true,
          isAtLatest: false,
          attempt: 1,
        ),
        isTrue,
      );
      expect(
        shouldRetryLatestInitialAutoScroll(
          hasPosition: true,
          isAtLatest: true,
          attempt: 3,
        ),
        isFalse,
      );
    },
  );

  test(
    'latest initial auto-scroll keeps settling briefly after reaching latest',
    () {
      expect(
        shouldRetryLatestInitialAutoScroll(
          hasPosition: true,
          isAtLatest: true,
          attempt: 0,
        ),
        isTrue,
      );
      expect(
        shouldRetryLatestInitialAutoScroll(
          hasPosition: true,
          isAtLatest: true,
          attempt: 3,
        ),
        isFalse,
      );
    },
  );
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

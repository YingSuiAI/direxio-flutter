import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/chat/chat_glass_background.dart';
import 'package:portal_app/presentation/widgets/app_glass_background.dart';
import 'package:portal_app/presentation/widgets/m3/glass_header.dart';
import 'package:portal_app/presentation/widgets/m3/m3_bottom_nav.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('app scaffold background is transparent for full-screen image', () {
    expect(AppTheme.light.scaffoldBackgroundColor, Colors.transparent);
  });

  testWidgets('app glass background is not duplicated by chat backgrounds',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const AppGlassBackground(
          child: ChatGlassBackground(
            child: Text('content'),
          ),
        ),
      ),
    );

    expect(find.text('content'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                AppGlassBackground.assetName,
      ),
      findsOneWidget,
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('main-page header and bottom nav have no horizontal borders',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              GlassHeader.primary(title: '消息'),
              const Spacer(),
              M3BottomNav(
                currentIndex: 0,
                onTap: (_) {},
                items: const [
                  M3NavItem(
                    icon: Symbols.chat_bubble,
                    activeIcon: Symbols.chat_bubble,
                    label: '消息',
                  ),
                  M3NavItem(
                    icon: Symbols.contacts,
                    activeIcon: Symbols.contacts,
                    label: '联系人',
                  ),
                  M3NavItem(
                    icon: Symbols.campaign,
                    activeIcon: Symbols.campaign,
                    label: '探索',
                  ),
                  M3NavItem(
                    icon: Symbols.person,
                    activeIcon: Symbols.person,
                    label: '我',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final headerContainers = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(GlassHeader),
        matching: find.byType(Container),
      ),
    );
    final navContainers = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(M3BottomNav),
        matching: find.byType(Container),
      ),
    );

    final borderedHeaderContainers = headerContainers.where(_hasBorder);
    final borderedNavContainers = navContainers.where(_hasBorder);
    expect(borderedHeaderContainers, isEmpty);
    expect(borderedNavContainers, isEmpty);
  });

  testWidgets('glass panel creates an independent frosted surface',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const AppGlassBackground(
          child: Center(
            child: AppGlassPanel(
              child: Text('ice row'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('ice row'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNWidgets(2));

    final panelContainer = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppGlassPanel),
        matching: find.byType(Container),
      ),
    );
    final decoration = panelContainer.decoration;
    expect(decoration, isA<BoxDecoration>());
    final box = decoration as BoxDecoration;
    expect(box.borderRadius, isNotNull);
    expect(box.border, isNotNull);

    final shadowDecoratedBox = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppGlassPanel),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final shadowDecoration = shadowDecoratedBox.decoration;
    expect(shadowDecoration, isA<BoxDecoration>());
    expect((shadowDecoration as BoxDecoration).boxShadow, isNotEmpty);
  });
}

bool _hasBorder(Container container) {
  final decoration = container.decoration;
  return decoration is BoxDecoration && decoration.border != null;
}

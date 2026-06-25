import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/chat/chat_glass_background.dart';
import 'package:portal_app/presentation/widgets/app_glass_background.dart';
import 'package:portal_app/presentation/widgets/m3/glass_header.dart';
import 'package:portal_app/presentation/widgets/m3/m3_bottom_nav.dart';

void main() {
  test('app scaffold background is transparent for full-screen image', () {
    expect(AppTheme.light.scaffoldBackgroundColor, Colors.transparent);
  });

  test('app font uses the bundled Noto Sans SC family', () {
    final regular = AppTheme.sans();
    final semibold = AppTheme.sans(weight: FontWeight.w600);

    expect(regular.fontFamily, 'NotoSansSC');
    expect(regular.fontFamilyFallback, contains('Noto Sans CJK SC'));
    expect(semibold.fontFamily, 'NotoSansSC');
    expect(semibold.fontWeight, FontWeight.w600);
  });

  testWidgets('bundled Noto Sans SC variable font is available',
      (tester) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    expect(
      manifest.listAssets(),
      contains('assets/fonts/NotoSansSC-Variable.ttf'),
    );
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

  testWidgets('bottom nav inactive items are white in dark mode',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: M3BottomNav(
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
              ],
            ),
          ),
        ),
      ),
    );

    final inactiveText = tester.widget<Text>(find.text('联系人'));
    final inactiveIcon = tester.widget<Icon>(
      find.byIcon(Symbols.contacts).first,
    );

    expect(inactiveText.style?.color, Colors.white);
    expect(inactiveIcon.color, Colors.white);
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

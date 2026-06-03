import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/widgets/app_glass_background.dart';
import 'package:portal_app/presentation/widgets/glass_list_tile.dart';

void main() {
  testWidgets('glass list tile matches message conversation spacing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: GlassListTile(
            leading: GlassListIcon(icon: Symbols.person),
            title: '联系人',
            subtitle: 'p2p-im.com',
          ),
        ),
      ),
    );

    expect(find.byType(AppGlassPanel), findsOneWidget);

    final tilePadding = tester.widget<Padding>(
      find
          .ancestor(
            of: find.byType(AppGlassPanel),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(tilePadding.padding, glassListTileMargin);

    final contentPadding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byType(InkWell),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(contentPadding.padding, glassListTileContentPadding);
  });
}

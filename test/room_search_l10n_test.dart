import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/matrix_message_search_client.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/pages/room_search_page.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/matrix_message_clients_provider.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('room search page localizes private chat labels in English',
      (tester) async {
    final client = Client('RoomSearchEnglishL10nTest')
      ..setUserId('@owner:p2p-im.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(client),
          matrixMessageSearchClientProvider.overrideWithValue(
            _EmptyMatrixMessageSearchClient(client),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const RoomSearchPage(roomId: '!direct:p2p-im.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search Chat History'), findsOneWidget);
    expect(find.text('Search this chat'), findsOneWidget);
    expect(find.text('Enter keywords to search this chat'), findsOneWidget);
    expect(find.text('查找聊天记录'), findsNothing);
    expect(find.text('搜索当前会话'), findsNothing);
    expect(find.text('输入关键词搜索当前会话'), findsNothing);

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('No messages found for "alpha"'), findsOneWidget);
    expect(find.text('没有找到包含「alpha」的消息'), findsNothing);
  });
}

class _EmptyMatrixMessageSearchClient extends MatrixMessageSearchClient {
  _EmptyMatrixMessageSearchClient(super.client);

  @override
  Future<List<MatrixMessageSearchResult>> search(
    String query, {
    String? roomId,
    Iterable<String> roomIds = const [],
    int limit = 20,
  }) async {
    return const [];
  }
}

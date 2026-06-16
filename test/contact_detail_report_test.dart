import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/p2p_api_client.dart';
import 'package:portal_app/presentation/pages/contact_detail_page.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/p2p_api_provider.dart';

void main() {
  testWidgets('contact detail submits user report to IM public API',
      (tester) async {
    late http.Request seen;
    final matrixClient = Client('ContactDetailReportTest')
      ..setUserId('@owner:p2p-im.com');
    final p2pClient = P2pApiClient(
      baseUri: Uri.parse('http://localhost:8888'),
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'code': 0,
            'data': {'ID': 7},
            'msg': 'success'
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(matrixClient),
          p2pApiClientProvider.overrideWithValue(p2pClient),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContactDetailPage(userId: '@alice:portal.local'),
        ),
      ),
    );

    await tester.tap(find.text('举报用户'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('欺诈'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();

    expect(seen.method, 'POST');
    expect(seen.url.path, '/im/report');
    expect(jsonDecode(seen.body), {
      'reporterDomain': 'p2p-im.com',
      'reportedDomain': 'portal.local',
      'targetType': 1,
      'reason': '欺诈',
    });
    expect(find.text('举报已提交'), findsOneWidget);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/data/http_as_client.dart';
import 'package:portal_app/presentation/pages/contact_detail_page.dart';
import 'package:portal_app/presentation/providers/as_client_provider.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/profile_provider.dart';

void main() {
  testWidgets('contact detail submits user report through unified AS API',
      (tester) async {
    late http.Request seen;
    final matrixClient = Client('ContactDetailReportTest')
      ..setUserId('@owner:p2p-im.com');
    final asClient = HttpAsClient(
      baseUri: Uri.parse('http://portal.local/_p2p'),
      portalToken: 'access-token',
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'id': 'report-7',
            'reporter_domain': 'p2p-im.com',
            'reported_domain': 'portal.local',
            'target_type': 1,
            'reason': '欺诈',
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixClientProvider.overrideWithValue(matrixClient),
          asClientProvider.overrideWithValue(asClient),
          currentUserProfileProvider.overrideWith((ref) async => null),
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
    expect(seen.url.path, '/_p2p/command');
    expect(jsonDecode(seen.body), {
      'action': 'reports.submit',
      'params': {
        'reporter_domain': 'p2p-im.com',
        'reported_domain': 'portal.local',
        'target_type': 1,
        'reason': '欺诈',
      },
    });
    expect(find.text('举报已提交'), findsOneWidget);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/presentation/call/voice_call_controller.dart';
import 'package:portal_app/presentation/pages/group_call_member_select_page.dart';

void main() {
  testWidgets('requires at least one invitee before starting a group call',
      (tester) async {
    var startedInvitees = const <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GroupCallMemberSelectView(
          roomName: '产品群',
          callType: ProductCallType.voice,
          members: const [
            GroupCallInviteMember(
              userId: '@alice:p2p-im.com',
              displayName: 'Alice',
            ),
            GroupCallInviteMember(
              userId: '@bob:p2p-im.com',
              displayName: 'Bob',
            ),
          ],
          onStart: (invitees) => startedInvitees = invitees,
        ),
      ),
    );

    expect(find.text('发起语音通话'), findsOneWidget);
    await tester.tap(find.text('发起语音通话'));
    await tester.pump();
    expect(startedInvitees, isEmpty);

    await tester.tap(find.text('Alice'));
    await tester.pump();
    await tester.tap(find.text('发起语音通话'));

    expect(startedInvitees, ['@alice:p2p-im.com']);
  });

  test('builds member-selection and call-start routes with encoded values', () {
    expect(
      groupCallInviteRoute(
        roomId: '!room:p2p-im.com',
        roomName: '产品 群',
        callType: ProductCallType.video,
      ),
      '/group-call-invite/!room%3Ap2p-im.com?name=%E4%BA%A7%E5%93%81%20%E7%BE%A4&type=video',
    );

    expect(
      groupCallStartRoute(
        roomId: '!room:p2p-im.com',
        roomName: '产品 群',
        callType: ProductCallType.voice,
        inviteeIds: const ['@alice:p2p-im.com', '@bob:p2p-im.com'],
      ),
      '/group-call/!room%3Ap2p-im.com?name=%E4%BA%A7%E5%93%81%20%E7%BE%A4&invitees=%40alice%3Ap2p-im.com,%40bob%3Ap2p-im.com',
    );
    expect(
      groupCallJoinRoute(
        roomId: '!room:p2p-im.com',
        roomName: '产品 群',
        callType: ProductCallType.voice,
        callId: 'as-group-call-1',
      ),
      '/group-call/!room%3Ap2p-im.com?name=%E4%BA%A7%E5%93%81%20%E7%BE%A4&call_id=as-group-call-1&incoming=1',
    );
    expect(
      groupCallJoinRoute(
        roomId: '!room:p2p-im.com',
        roomName: '产品 群',
        callType: ProductCallType.video,
        callId: 'as-group-call-2',
      ),
      '/group-video-call/!room%3Ap2p-im.com?name=%E4%BA%A7%E5%93%81%20%E7%BE%A4&call_id=as-group-call-2&incoming=1',
    );
    expect(
      groupCallInviteesFromQuery('%40alice%3Ap2p-im.com,%40bob%3Ap2p-im.com'),
      ['@alice:p2p-im.com', '@bob:p2p-im.com'],
    );
  });

  testWidgets('starting a group call replaces the invite selection page',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('群聊页')),
        ),
        GoRoute(
          path: '/select',
          builder: (context, __) => Scaffold(
            body: TextButton(
              onPressed: () => replaceGroupCallInviteSelection(
                context,
                '/group-call/!room%3Ap2p-im.com?name=%E4%BA%A7%E5%93%81%E7%BE%A4',
              ),
              child: const Text('发起语音通话'),
            ),
          ),
        ),
        GoRoute(
          path: '/group-call/:roomId',
          builder: (_, __) => const Scaffold(body: Text('群通话页')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
    unawaited(router.push('/select'));
    await tester.pumpAndSettle();

    expect(find.text('发起语音通话'), findsOneWidget);

    await tester.tap(find.text('发起语音通话'));
    await tester.pumpAndSettle();
    expect(find.text('群通话页'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('群聊页'), findsOneWidget);
    expect(find.text('发起语音通话'), findsNothing);
  });
}

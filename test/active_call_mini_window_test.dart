import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/core/theme/app_theme.dart';
import 'package:portal_app/l10n/app_localizations.dart';
import 'package:portal_app/presentation/call/active_call_mini_window.dart';
import 'package:portal_app/presentation/call/voice_call_controller.dart';
import 'package:portal_app/presentation/providers/voice_call_provider.dart';

void main() {
  test('direct mini window restores the active call route', () {
    final route = activeCallMiniWindowRoute(
      const ActiveCallMiniWindow(
        kind: ActiveCallMiniWindowKind.direct,
        roomId: '!room:p2p-im.com',
        isVideo: true,
        callId: 'call-1',
        peerUserId: '@alice:p2p-im.com',
        title: 'Alice',
        avatarUrl: 'mxc://avatar',
        incoming: true,
      ),
    );

    expect(route, contains('/video-call/'));
    expect(route, contains('call_id=call-1'));
    expect(route, contains('peer=%40alice%3Ap2p-im.com'));
    expect(route, contains('name=Alice'));
    expect(route, contains('incoming=1'));
    expect(route, contains('restore=1'));
  });

  test('group mini window restores the group call route', () {
    final route = activeCallMiniWindowRoute(
      const ActiveCallMiniWindow(
        kind: ActiveCallMiniWindowKind.group,
        roomId: '!group:p2p-im.com',
        isVideo: false,
        callId: 'group-call-1',
        title: 'Project Group',
      ),
    );

    expect(route, startsWith('/group-call/'));
    expect(route, contains('call_id=group-call-1'));
    expect(route, contains('name=Project+Group'));
    expect(route, isNot(contains('peer=')));
    expect(route, contains('restore=1'));
  });

  test('mini window only stays visible for active direct calls', () {
    expect(
      directCallMiniWindowShouldStayVisible(
        const VoiceCallUiState(status: VoiceCallStatus.connected),
      ),
      isTrue,
    );
    expect(
      directCallMiniWindowShouldStayVisible(
        const VoiceCallUiState(status: VoiceCallStatus.ended),
      ),
      isFalse,
    );
  });

  test('mini window only stays visible for active group calls', () {
    expect(
      groupCallMiniWindowShouldStayVisible(
        const GroupCallUiState(status: GroupCallStatus.connected),
      ),
      isTrue,
    );
    expect(
      groupCallMiniWindowShouldStayVisible(
        const GroupCallUiState(status: GroupCallStatus.idle),
      ),
      isFalse,
    );
  });

  testWidgets('mini window can render outside a Navigator overlay',
      (tester) async {
    final controller = _MiniWindowVoiceCallController(
      const VoiceCallUiState(
        status: VoiceCallStatus.connected,
        roomId: '!room:p2p-im.com',
        callId: 'call-1',
        peerName: 'Alice',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeCallMiniWindowProvider.overrideWith(
            (ref) => const ActiveCallMiniWindow(
              kind: ActiveCallMiniWindowKind.direct,
              roomId: '!room:p2p-im.com',
              isVideo: false,
              callId: 'call-1',
              title: 'Alice',
            ),
          ),
          voiceCallControllerProvider.overrideWithValue(controller),
        ],
        child: Localizations(
          locale: const Locale('en'),
          delegates: AppLocalizations.localizationsDelegates,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(390, 844)),
              child: Theme(
                data: AppTheme.light,
                child: const ActiveCallMiniWindowOverlay(
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('active_call_mini_window')), findsOneWidget);
  });

  testWidgets('tapping mini window restores the call route from app builder',
      (tester) async {
    final controller = _MiniWindowVoiceCallController(
      const VoiceCallUiState(
        status: VoiceCallStatus.connected,
        roomId: '!room:p2p-im.com',
        callId: 'call-1',
        peerName: 'Alice',
      ),
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Text('home-route'),
        ),
        GoRoute(
          path: '/call/:roomId',
          builder: (_, state) => Text(
            'call-route:${state.pathParameters['roomId']}',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeCallMiniWindowProvider.overrideWith(
            (ref) => const ActiveCallMiniWindow(
              kind: ActiveCallMiniWindowKind.direct,
              roomId: '!room:p2p-im.com',
              isVideo: false,
              callId: 'call-1',
              title: 'Alice',
            ),
          ),
          voiceCallControllerProvider.overrideWithValue(controller),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
          builder: (context, child) => ActiveCallMiniWindowOverlay(
            onRestoreRoute: router.push,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('home-route'), findsOneWidget);
    expect(find.byKey(const Key('active_call_mini_window')), findsOneWidget);

    await tester.tap(find.byKey(const Key('active_call_mini_window')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('call-route:!room:p2p-im.com'), findsOneWidget);
  });
}

class _MiniWindowVoiceCallController implements VoiceCallController {
  _MiniWindowVoiceCallController(this._state);

  final VoiceCallUiState _state;
  final _stateController = StreamController<VoiceCallUiState>.broadcast();
  final _groupStateController = StreamController<GroupCallUiState>.broadcast();

  @override
  VoiceCallUiState get currentState => _state;

  @override
  CallSession? get activeSession => null;

  @override
  Stream<VoiceCallUiState> get stateStream => _stateController.stream;

  @override
  GroupCallUiState get currentGroupState => GroupCallUiState.idle;

  @override
  GroupCallSession? get activeGroupSession => null;

  @override
  Stream<GroupCallUiState> get groupStateStream => _groupStateController.stream;

  @override
  Future<void> attachClient(Client client) async {}

  @override
  Future<void> startOutgoing({
    required String roomId,
    required String peerUserId,
    String? peerDisplayName,
    ProductCallType callType = ProductCallType.voice,
  }) async {}

  @override
  Future<void> answer() async {}

  @override
  Future<void> reject() async {}

  @override
  Future<void> hangup() async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> setCameraMuted(bool muted) async {}

  @override
  Future<void> switchCamera() async {}

  @override
  Future<void> setSpeakerOn(bool enabled) async {}

  @override
  Future<void> startOrJoinGroupCall({
    required String roomId,
    required String roomName,
    ProductCallType callType = ProductCallType.voice,
    List<String> invitedUserIds = const [],
    bool joinExistingInvite = false,
    String? existingCallId,
  }) async {}

  @override
  Future<void> leaveGroupCall() async {}

  @override
  Future<void> setGroupMuted(bool muted) async {}

  @override
  Future<void> setGroupCameraMuted(bool muted) async {}

  @override
  Future<void> switchGroupCamera() async {}

  @override
  Future<void> setGroupSpeakerOn(bool enabled) async {}

  @override
  void dispose() {
    _stateController.close();
    _groupStateController.close();
  }
}

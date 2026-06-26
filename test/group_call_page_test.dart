import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:portal_app/data/as_client.dart';
import 'package:portal_app/presentation/call/voice_call_controller.dart';
import 'package:portal_app/presentation/pages/group_call_page.dart';
import 'package:portal_app/presentation/providers/auth_provider.dart';
import 'package:portal_app/presentation/providers/as_sync_cache_provider.dart';
import 'package:portal_app/presentation/providers/personal_space_provider.dart';
import 'package:portal_app/presentation/providers/profile_provider.dart';
import 'package:portal_app/presentation/providers/voice_call_provider.dart';

void main() {
  test('group call auto-answer route is gated by autotest flag', () {
    expect(
      groupCallRouteShouldAutoAnswer(
        requestedByRoute: true,
        autotestEnabled: true,
      ),
      isTrue,
    );
    expect(
      groupCallRouteShouldAutoAnswer(
        requestedByRoute: true,
        autotestEnabled: false,
      ),
      isFalse,
    );
    expect(
      groupCallRouteShouldAutoAnswer(
        requestedByRoute: false,
        autotestEnabled: true,
      ),
      isFalse,
    );
  });

  test('restored active group call route does not start or join again', () {
    const connected = GroupCallUiState(
      status: GroupCallStatus.connected,
      roomId: '!group:p2p-im.com',
      callId: 'group-call-1',
    );

    expect(
      groupCallPageShouldStartOrJoinCall(
        connected,
        routeRoomId: '!group:p2p-im.com',
        routeCallId: 'group-call-1',
        routeIsIncoming: false,
        routeIsRestore: true,
        alreadyStarted: false,
      ),
      isFalse,
    );
    expect(
      groupCallPageShouldStartOrJoinCall(
        const GroupCallUiState(
          status: GroupCallStatus.connected,
          roomId: '!group:p2p-im.com',
        ),
        routeRoomId: '!group:p2p-im.com',
        routeCallId: 'group-call-1',
        routeIsIncoming: false,
        routeIsRestore: true,
        alreadyStarted: false,
      ),
      isFalse,
    );
    expect(
      groupCallPageShouldStartOrJoinCall(
        GroupCallUiState.idle,
        routeRoomId: '!group:p2p-im.com',
        routeCallId: 'group-call-1',
        routeIsIncoming: false,
        routeIsRestore: true,
        alreadyStarted: false,
      ),
      isTrue,
    );
  });

  testWidgets('group voice call page starts room voice call', (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.connected,
        callType: ProductCallType.voice,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        participantCount: 2,
        participants: [
          GroupCallParticipantInfo(
            userId: '@owner:p2p-im.com',
            displayName: 'Yanan',
            isLocal: true,
          ),
          GroupCallParticipantInfo(
            userId: '@lee:p2p-liyanan.com',
            displayName: 'Lee',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(controller, isVideo: false));
    await tester.pump();

    expect(controller.startedRoomId, '!group:p2p-im.com');
    expect(controller.startedCallType, ProductCallType.voice);
    expect(find.text('群语音通话'), findsOneWidget);
    expect(find.text('2 人通话中'), findsOneWidget);
    expect(find.text('Yanan'), findsOneWidget);
    expect(find.text('Lee'), findsOneWidget);
    expect(find.byKey(const Key('group-call-leave-button')), findsOneWidget);
  });

  testWidgets('group video call page uses full screen video stage',
      (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.connected,
        callType: ProductCallType.video,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        participantCount: 3,
      ),
    );

    await tester.pumpWidget(_wrap(controller, isVideo: true));
    await tester.pump();

    expect(controller.startedCallType, ProductCallType.video);
    expect(find.byKey(const Key('group-video-call-stage')), findsOneWidget);
    expect(find.text('群视频通话'), findsOneWidget);
    expect(find.text('3 人通话中'), findsOneWidget);
  });

  testWidgets('group video call page renders available video feeds',
      (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.connected,
        callType: ProductCallType.video,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        participantCount: 2,
        mediaUserIds: [
          '@owner:p2p-im.com',
          '@lee:p2p-liyanan.com',
        ],
        videoStreams: [
          GroupCallVideoStreamInfo(
            userId: '@owner:p2p-im.com',
            isLocal: true,
            hasVideo: true,
          ),
          GroupCallVideoStreamInfo(
            userId: '@lee:p2p-liyanan.com',
            hasVideo: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(controller, isVideo: true));
    await tester.pump();

    expect(find.byKey(const Key('group-video-tile-local')), findsOneWidget);
    expect(
      find.byKey(const Key('group-video-tile-@lee:p2p-liyanan.com')),
      findsOneWidget,
    );
    expect(find.text('等待群成员视频画面'), findsNothing);
  });

  testWidgets('group video call page distinguishes unavailable camera',
      (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.connected,
        callType: ProductCallType.video,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        participantCount: 1,
        videoStreams: [
          GroupCallVideoStreamInfo(
            userId: '@owner:p2p-im.com',
            isLocal: true,
            hasVideo: false,
            isMuted: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(controller, isVideo: true));
    await tester.pump();

    expect(find.byKey(const Key('group-video-tile-local')), findsOneWidget);
    expect(find.text('摄像头不可用'), findsWidgets);
    expect(find.text('摄像头已关'), findsNothing);
  });

  testWidgets(
      'group video camera control is disabled without local video track',
      (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.connected,
        callType: ProductCallType.video,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        participantCount: 1,
        videoStreams: [
          GroupCallVideoStreamInfo(
            userId: '@owner:p2p-im.com',
            isLocal: true,
            hasVideo: false,
            isMuted: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(controller, isVideo: true));
    await tester.pump();

    expect(find.text('摄像头不可用'), findsNWidgets(2));
    await tester.tap(find.text('摄像头不可用').last);
    await tester.pump();

    expect(controller.groupCameraMutedValues, isEmpty);
  });

  testWidgets(
      'group video camera control toggles when local video track exists',
      (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.connected,
        callType: ProductCallType.video,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        participantCount: 1,
        videoStreams: [
          GroupCallVideoStreamInfo(
            userId: '@owner:p2p-im.com',
            isLocal: true,
            hasVideo: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(controller, isVideo: true));
    await tester.pump();

    await tester.tap(find.text('关摄像头'));
    await tester.pump();

    expect(controller.groupCameraMutedValues, [true]);
  });

  testWidgets('group call page shows explicit controller failure',
      (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.failed,
        callType: ProductCallType.voice,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        error: '该群暂不支持群通话',
      ),
    );

    await tester.pumpWidget(_wrap(controller, isVideo: false));

    expect(find.text('该群暂不支持群通话'), findsOneWidget);
  });

  testWidgets('incoming group call keeps join action until accepted',
      (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.joining,
        callType: ProductCallType.voice,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        callId: 'group-call-1',
        isIncoming: true,
      ),
    );

    await tester.pumpWidget(_wrap(
      controller,
      isVideo: false,
      incoming: true,
      callId: 'group-call-1',
    ));
    await tester.pump();

    expect(find.text('加入'), findsOneWidget);
    expect(find.text('挂断'), findsOneWidget);

    await tester.tap(find.text('加入'));
    await tester.pump();

    expect(controller.joinExistingInvite, isTrue);
    expect(controller.existingCallId, 'group-call-1');
    expect(controller.startedRoomId, '!group:p2p-im.com');
  });

  testWidgets('group call page closes when active group call ends',
      (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.connected,
        callType: ProductCallType.voice,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        participantCount: 2,
      ),
    );

    await tester.pumpWidget(_wrapWithLaunchButton(controller));
    await tester.tap(find.text('open group call'));
    await tester.pumpAndSettle();

    expect(find.byType(GroupCallPage), findsOneWidget);

    controller.emitGroupState(const GroupCallUiState(
      status: GroupCallStatus.ended,
      callType: ProductCallType.voice,
      roomId: '!group:p2p-im.com',
      roomName: '测试群',
      participantCount: 1,
    ));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(GroupCallPage), findsNothing);
    expect(find.text('launcher'), findsOneWidget);
  });

  testWidgets('group call waiting page shows invited members as pending',
      (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.connected,
        callType: ProductCallType.voice,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        participantCount: 1,
        mediaUserIds: [
          '@owner:p2p-im.com',
        ],
        initiator: GroupCallParticipantInfo(
          userId: '@owner:p2p-im.com',
          displayName: 'Yanan',
          isLocal: true,
        ),
        participants: [
          GroupCallParticipantInfo(
            userId: '@owner:p2p-im.com',
            displayName: 'Yanan',
            isLocal: true,
          ),
        ],
        invitedParticipants: [
          GroupCallParticipantInfo(
            userId: '@owner:p2p-im.com',
            displayName: 'Yanan',
            isLocal: true,
          ),
          GroupCallParticipantInfo(
            userId: '@lee:p2p-liyanan.com',
            displayName: 'Lee',
          ),
          GroupCallParticipantInfo(
            userId: '@bob:p2p-im-test.com',
            displayName: 'Bob',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(controller, isVideo: false));
    await tester.pump();

    expect(find.text('1'), findsNothing);
    expect(find.text('Yanan'), findsOneWidget);
    expect(find.text('Lee'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('等待成员加入'), findsWidgets);
    final yanan = tester.widget<Opacity>(
      find.byKey(const ValueKey('group-call-participant-@owner:p2p-im.com')),
    );
    final lee = tester.widget<Opacity>(
      find.byKey(const ValueKey('group-call-participant-@lee:p2p-liyanan.com')),
    );
    expect(yanan.opacity, 1);
    expect(lee.opacity, lessThan(1));
  });

  testWidgets('incoming group call invitation shows all invited members',
      (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.ringing,
        callType: ProductCallType.voice,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        callId: 'group-call-2',
        isIncoming: true,
        createdByMxid: '@lee:p2p-liyanan.com',
        initiator: GroupCallParticipantInfo(
          userId: '@lee:p2p-liyanan.com',
          displayName: 'Lee',
        ),
        invitedParticipants: [
          GroupCallParticipantInfo(
            userId: '@lee:p2p-liyanan.com',
            displayName: 'Lee',
          ),
          GroupCallParticipantInfo(
            userId: '@owner:p2p-im.com',
            displayName: 'Yanan',
          ),
          GroupCallParticipantInfo(
            userId: '@bob:p2p-im-test.com',
            displayName: 'Bob',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(
      controller,
      isVideo: false,
      incoming: true,
      callId: 'group-call-2',
    ));
    await tester.pump();

    expect(find.text('Lee'), findsOneWidget);
    expect(find.text('Yanan'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('加入'), findsOneWidget);
    final lee = tester.widget<Opacity>(
      find.byKey(const ValueKey('group-call-participant-@lee:p2p-liyanan.com')),
    );
    final bob = tester.widget<Opacity>(
      find.byKey(const ValueKey('group-call-participant-@bob:p2p-im-test.com')),
    );
    expect(lee.opacity, 1);
    expect(bob.opacity, lessThan(1));
  });

  testWidgets('group call page shows joined elapsed timer', (tester) async {
    final connectedAt =
        DateTime.now().subtract(const Duration(minutes: 1, seconds: 5));
    final controller = _FakeGroupCallController(
      initialGroupState: GroupCallUiState(
        status: GroupCallStatus.connected,
        callType: ProductCallType.voice,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        connectedAt: connectedAt,
        joinedUserIds: const [
          '@owner:p2p-im.com',
          '@lee:p2p-liyanan.com',
        ],
        mediaUserIds: const [
          '@owner:p2p-im.com',
          '@lee:p2p-liyanan.com',
        ],
        participants: const [
          GroupCallParticipantInfo(
            userId: '@owner:p2p-im.com',
            displayName: 'Yanan',
            isLocal: true,
          ),
          GroupCallParticipantInfo(
            userId: '@lee:p2p-liyanan.com',
            displayName: 'Lee',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(controller, isVideo: false));
    await tester.pump();

    expect(find.text('1:05'), findsOneWidget);
  });

  testWidgets('media-connected users mark invited members as joined',
      (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.connected,
        callType: ProductCallType.voice,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        joinedUserIds: [
          '@owner:p2p-im.com',
          '@lee:p2p-liyanan.com',
        ],
        mediaUserIds: [
          '@owner:p2p-im.com',
          '@lee:p2p-liyanan.com',
        ],
        initiator: GroupCallParticipantInfo(
          userId: '@owner:p2p-im.com',
          displayName: 'Yanan',
          isLocal: true,
        ),
        invitedParticipants: [
          GroupCallParticipantInfo(
            userId: '@owner:p2p-im.com',
            displayName: 'Yanan',
            isLocal: true,
          ),
          GroupCallParticipantInfo(
            userId: '@lee:p2p-liyanan.com',
            displayName: 'Lee',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(controller, isVideo: false));
    await tester.pump();

    final lee = tester.widget<Opacity>(
      find.byKey(const ValueKey('group-call-participant-@lee:p2p-liyanan.com')),
    );
    expect(lee.opacity, 1);
  });

  testWidgets('product joined users are shown joined while media catches up',
      (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.joining,
        callType: ProductCallType.voice,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        joinedUserIds: [
          '@owner:p2p-im.com',
          '@lee:p2p-liyanan.com',
        ],
        mediaUserIds: [
          '@owner:p2p-im.com',
        ],
        initiator: GroupCallParticipantInfo(
          userId: '@owner:p2p-im.com',
          displayName: 'Yanan',
          isLocal: true,
        ),
        invitedParticipants: [
          GroupCallParticipantInfo(
            userId: '@owner:p2p-im.com',
            displayName: 'Yanan',
            isLocal: true,
          ),
          GroupCallParticipantInfo(
            userId: '@lee:p2p-liyanan.com',
            displayName: 'Lee',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(controller, isVideo: false));
    await tester.pump();

    final lee = tester.widget<Opacity>(
      find.byKey(const ValueKey('group-call-participant-@lee:p2p-liyanan.com')),
    );
    expect(lee.opacity, 1);
  });

  testWidgets('product joined users outside invite roster are displayed',
      (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.connected,
        callType: ProductCallType.voice,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        joinedUserIds: [
          '@owner:p2p-im.com',
          '@lee:p2p-liyanan.com',
          '@test:p2p-im-test.com',
        ],
        mediaUserIds: [
          '@owner:p2p-im.com',
          '@lee:p2p-liyanan.com',
        ],
        initiator: GroupCallParticipantInfo(
          userId: '@owner:p2p-im.com',
          displayName: 'Yanan',
          isLocal: true,
        ),
        invitedParticipants: [
          GroupCallParticipantInfo(
            userId: '@owner:p2p-im.com',
            displayName: 'Yanan',
            isLocal: true,
          ),
          GroupCallParticipantInfo(
            userId: '@lee:p2p-liyanan.com',
            displayName: 'Lee',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(controller, isVideo: false));
    await tester.pump();

    expect(
      find.byKey(
          const ValueKey('group-call-participant-@test:p2p-im-test.com')),
      findsOneWidget,
    );
    final testNode = tester.widget<Opacity>(
      find.byKey(
          const ValueKey('group-call-participant-@test:p2p-im-test.com')),
    );
    expect(testNode.opacity, 1);
  });

  testWidgets('matrix participants do not mark invited users as joined',
      (tester) async {
    final controller = _FakeGroupCallController(
      initialGroupState: const GroupCallUiState(
        status: GroupCallStatus.connected,
        callType: ProductCallType.voice,
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        joinedUserIds: [
          '@owner:p2p-im.com',
        ],
        initiator: GroupCallParticipantInfo(
          userId: '@owner:p2p-im.com',
          displayName: 'Yanan',
          isLocal: true,
        ),
        invitedParticipants: [
          GroupCallParticipantInfo(
            userId: '@owner:p2p-im.com',
            displayName: 'Yanan',
            isLocal: true,
          ),
          GroupCallParticipantInfo(
            userId: '@lee:p2p-liyanan.com',
            displayName: 'Lee',
          ),
        ],
        participants: [
          GroupCallParticipantInfo(
            userId: '@owner:p2p-im.com',
            displayName: 'Yanan',
            isLocal: true,
          ),
          GroupCallParticipantInfo(
            userId: '@lee:p2p-liyanan.com',
            displayName: 'Lee',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(controller, isVideo: false));
    await tester.pump();

    final lee = tester.widget<Opacity>(
      find.byKey(const ValueKey('group-call-participant-@lee:p2p-liyanan.com')),
    );
    expect(lee.opacity, lessThan(1));
  });

  test('group call display uses AS contact profile before Matrix fallback', () {
    final state = groupCallStateWithResolvedProfiles(
      const GroupCallUiState(
        status: GroupCallStatus.connected,
        participants: [
          GroupCallParticipantInfo(
            userId: '@owner:p2p-liyanan.com',
            displayName: 'Owner',
          ),
          GroupCallParticipantInfo(
            userId: '@owner:p2p-im-test.com',
            displayName: 'Owner',
          ),
        ],
        invitedParticipants: [
          GroupCallParticipantInfo(
            userId: '@owner:p2p-liyanan.com',
            displayName: 'Owner',
          ),
        ],
      ),
      syncCache: AsSyncCacheState(
        bootstrap: AsSyncBootstrap(
          syncedAt: DateTime.utc(2026, 5, 31, 14),
          user: const AsSyncUser(userId: '@owner:p2p-im.com'),
          rooms: const [],
          contacts: const [
            AsSyncContact(
              userId: '@owner:p2p-liyanan.com',
              displayName: 'Lee',
              avatarUrl: 'https://example.com/lee.png',
              roomId: '!direct1:p2p-im.com',
              status: 'accepted',
            ),
            AsSyncContact(
              userId: '@owner:p2p-im-test.com',
              displayName: 'Test Node',
              avatarUrl: 'https://example.com/test.png',
              roomId: '!direct2:p2p-im.com',
              status: 'accepted',
            ),
          ],
          groups: const [],
          channels: const [],
          pending: const AsSyncPending.empty(),
        ),
      ),
    );

    expect(
      state.participants.map((participant) => participant.displayName),
      ['Lee', 'Test Node'],
    );
    expect(state.participants.first.avatarUrl, 'https://example.com/lee.png');
    expect(state.invitedParticipants.single.displayName, 'Lee');
  });

  test('group call display uses local profile for current user', () {
    final state = groupCallStateWithResolvedProfiles(
      const GroupCallUiState(
        status: GroupCallStatus.connected,
        participants: [
          GroupCallParticipantInfo(
            userId: '@owner:p2p-im.com',
            displayName: 'Owner',
            isLocal: true,
          ),
        ],
      ),
      syncCache: const AsSyncCacheState(),
      currentUserProfile: Profile(
        userId: '@owner:p2p-im.com',
        displayName: 'Yanan',
        avatarUrl: Uri.parse('https://example.com/me.png'),
      ),
      localDisplayNameOverride: '',
      client: Client('test'),
    );

    expect(state.participants.single.displayName, 'Yanan');
    expect(state.participants.single.avatarUrl, 'https://example.com/me.png');
  });
}

Widget _wrap(
  _FakeGroupCallController controller, {
  required bool isVideo,
  bool incoming = false,
  String? callId,
}) {
  return ProviderScope(
    overrides: [
      voiceCallControllerProvider.overrideWithValue(controller),
      matrixClientProvider.overrideWithValue(Client('test')),
      currentUserProfileProvider.overrideWith((ref) async => null),
      personalProfileProvider
          .overrideWith((ref) => const PersonalProfileData()),
    ],
    child: MaterialApp(
      home: GroupCallPage(
        roomId: '!group:p2p-im.com',
        roomName: '测试群',
        callId: callId,
        isVideo: isVideo,
        incoming: incoming,
      ),
    ),
  );
}

Widget _wrapWithLaunchButton(_FakeGroupCallController controller) {
  return ProviderScope(
    overrides: [
      voiceCallControllerProvider.overrideWithValue(controller),
      matrixClientProvider.overrideWithValue(Client('test')),
      currentUserProfileProvider.overrideWith((ref) async => null),
      personalProfileProvider
          .overrideWith((ref) => const PersonalProfileData()),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              const Text('launcher'),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GroupCallPage(
                        roomId: '!group:p2p-im.com',
                        roomName: '测试群',
                      ),
                    ),
                  );
                },
                child: const Text('open group call'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FakeGroupCallController implements VoiceCallController {
  _FakeGroupCallController({required GroupCallUiState initialGroupState})
      : _groupState = initialGroupState;

  final _stateController = StreamController<VoiceCallUiState>.broadcast();
  final _groupStateController = StreamController<GroupCallUiState>.broadcast();
  GroupCallUiState _groupState;
  String? startedRoomId;
  ProductCallType? startedCallType;
  bool joinExistingInvite = false;
  String? existingCallId;
  final groupCameraMutedValues = <bool>[];

  @override
  VoiceCallUiState get currentState => VoiceCallUiState.idle;

  @override
  CallSession? get activeSession => null;

  @override
  Stream<VoiceCallUiState> get stateStream => _stateController.stream;

  @override
  GroupCallUiState get currentGroupState => _groupState;

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
  Future<void> setSpeakerOn(bool enabled) async {}

  @override
  Future<void> startOrJoinGroupCall({
    required String roomId,
    required String roomName,
    ProductCallType callType = ProductCallType.voice,
    List<String> invitedUserIds = const [],
    bool joinExistingInvite = false,
    String? existingCallId,
  }) async {
    startedRoomId = roomId;
    startedCallType = callType;
    this.joinExistingInvite = joinExistingInvite;
    this.existingCallId = existingCallId;
    _groupState = _groupState.copyWith(
      roomId: roomId,
      roomName: roomName,
      callType: callType,
    );
    _groupStateController.add(_groupState);
  }

  void emitGroupState(GroupCallUiState state) {
    _groupState = state;
    _groupStateController.add(state);
  }

  @override
  Future<void> leaveGroupCall() async {}

  @override
  Future<void> setGroupMuted(bool muted) async {}

  @override
  Future<void> setGroupCameraMuted(bool muted) async {
    groupCameraMutedValues.add(muted);
  }

  @override
  Future<void> setGroupSpeakerOn(bool enabled) async {}

  @override
  void dispose() {
    unawaited(_stateController.close());
    unawaited(_groupStateController.close());
  }
}

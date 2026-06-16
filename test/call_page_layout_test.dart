import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/call/voice_call_controller.dart';
import 'package:portal_app/presentation/pages/call_page.dart';

void main() {
  test('connected video calls use full screen video layout', () {
    expect(
      shouldUseConnectedVideoCallLayout(
        const VoiceCallUiState(
          status: VoiceCallStatus.connected,
          callType: ProductCallType.video,
        ),
      ),
      isTrue,
    );
    expect(
      shouldUseConnectedVideoCallLayout(
        const VoiceCallUiState(
          status: VoiceCallStatus.connected,
          callType: ProductCallType.voice,
        ),
      ),
      isFalse,
    );
  });

  test('voice calls and pre-connected video calls keep call sheet layout', () {
    expect(
      shouldUseConnectedVideoCallLayout(
        const VoiceCallUiState(
          status: VoiceCallStatus.connected,
          callType: ProductCallType.voice,
        ),
      ),
      isFalse,
    );
    expect(
      shouldUseConnectedVideoCallLayout(
        const VoiceCallUiState(
          status: VoiceCallStatus.connecting,
          callType: ProductCallType.video,
        ),
      ),
      isFalse,
    );
  });

  test('active controller state overrides stale video route intent', () {
    expect(
      callPageUsesVideoControls(
        const VoiceCallUiState(
          status: VoiceCallStatus.ringing,
          roomId: '!room:p2p-im.com',
          callType: ProductCallType.voice,
        ),
        routeIsVideo: true,
        routeRoomId: '!room:p2p-im.com',
      ),
      isFalse,
    );
    expect(
      callPageUsesVideoControls(
        const VoiceCallUiState(status: VoiceCallStatus.idle),
        routeIsVideo: true,
        routeRoomId: '!room:p2p-im.com',
      ),
      isTrue,
    );
  });

  test('video calls keep camera open intent even before local track exists',
      () {
    expect(
      localVideoControlState(
        isVideoCall: true,
        hasLocalVideoTrack: false,
        isCameraMuted: false,
      ),
      LocalVideoControlState.active,
    );
    expect(
      localVideoControlLabel(LocalVideoControlState.active),
      '关摄像头',
    );
    expect(
      localVideoControlCanToggle(LocalVideoControlState.active),
      isTrue,
    );
  });

  test('camera control labels active and muted local video tracks', () {
    expect(
      localVideoControlState(
        isVideoCall: true,
        hasLocalVideoTrack: true,
        isCameraMuted: false,
      ),
      LocalVideoControlState.active,
    );
    expect(localVideoControlLabel(LocalVideoControlState.active), '关摄像头');

    expect(
      localVideoControlState(
        isVideoCall: true,
        hasLocalVideoTrack: true,
        isCameraMuted: true,
      ),
      LocalVideoControlState.muted,
    );
    expect(localVideoControlLabel(LocalVideoControlState.muted), '开摄像头');
  });

  test('voice calls do not expose keypad camera placeholder', () {
    expect(
      localVideoControlState(
        isVideoCall: false,
        hasLocalVideoTrack: false,
        isCameraMuted: false,
      ),
      LocalVideoControlState.inactive,
    );
    expect(localVideoControlLabel(LocalVideoControlState.inactive), isEmpty);
  });

  test('speaker control label reflects output route state', () {
    expect(speakerControlLabel(true), '扬声器');
    expect(speakerControlLabel(false), '听筒');
  });

  test('call ringtone plays only while waiting for an answer', () {
    expect(
      shouldPlayCallRingtone(
        voiceStatus: VoiceCallStatus.calling,
        voiceIsIncoming: false,
        groupStatus: GroupCallStatus.idle,
      ),
      isTrue,
    );
    expect(
      shouldPlayCallRingtone(
        voiceStatus: VoiceCallStatus.ringing,
        voiceIsIncoming: true,
        groupStatus: GroupCallStatus.idle,
      ),
      isTrue,
    );
    expect(
      shouldPlayCallRingtone(
        voiceStatus: VoiceCallStatus.connecting,
        voiceIsIncoming: false,
        groupStatus: GroupCallStatus.idle,
      ),
      isTrue,
    );
    expect(
      shouldPlayCallRingtone(
        voiceStatus: VoiceCallStatus.connecting,
        voiceIsIncoming: true,
        groupStatus: GroupCallStatus.idle,
      ),
      isFalse,
    );
    expect(
      shouldPlayCallRingtone(
        voiceStatus: VoiceCallStatus.connected,
        voiceIsIncoming: false,
        groupStatus: GroupCallStatus.idle,
      ),
      isFalse,
    );
    expect(
      shouldPlayCallRingtone(
        voiceStatus: VoiceCallStatus.idle,
        voiceIsIncoming: false,
        groupStatus: GroupCallStatus.ringing,
      ),
      isTrue,
    );
    expect(
      shouldPlayCallRingtone(
        voiceStatus: VoiceCallStatus.idle,
        voiceIsIncoming: false,
        groupStatus: GroupCallStatus.joining,
      ),
      isFalse,
    );
  });

  test('connected video call without remote video shows peer unavailable', () {
    expect(
      remoteVideoPlaceholderTitle(
        const VoiceCallUiState(
          status: VoiceCallStatus.connected,
          callType: ProductCallType.video,
        ),
      ),
      '对方摄像头不可用',
    );
    expect(
      remoteVideoPlaceholderTitle(
        const VoiceCallUiState(
          status: VoiceCallStatus.connecting,
          callType: ProductCallType.video,
        ),
      ),
      '等待对方画面',
    );
  });

  test('connected call status shows network warning before elapsed timer', () {
    final connectedAt = DateTime.utc(2026, 5, 30, 1);
    final now = connectedAt.add(const Duration(seconds: 42));

    expect(
      callStatusDisplayText(
        VoiceCallUiState(
          status: VoiceCallStatus.connected,
          connectedAt: connectedAt,
          error: connectedCallUnstableMessage,
        ),
        now: now,
      ),
      connectedCallUnstableMessage,
    );
    expect(
      callStatusDisplayText(
        VoiceCallUiState(
          status: VoiceCallStatus.connected,
          connectedAt: connectedAt,
        ),
        now: now,
      ),
      '0:42',
    );
  });

  test('stale unanswered calls should auto close the call page', () {
    expect(
      callPageShouldAutoCloseForState(
        const VoiceCallUiState(
          status: VoiceCallStatus.failed,
          roomId: '!room:p2p-im.com',
          error: peerNoResponseMessage,
        ),
        routeRoomId: '!room:p2p-im.com',
        routeCallId: null,
        callWasConnected: false,
      ),
      isTrue,
    );
    expect(
      callPageShouldAutoCloseForState(
        const VoiceCallUiState(
          status: VoiceCallStatus.failed,
          roomId: '!other:p2p-im.com',
          error: peerNoResponseMessage,
        ),
        routeRoomId: '!room:p2p-im.com',
        routeCallId: null,
        callWasConnected: false,
      ),
      isFalse,
    );
    expect(
      callPageShouldAutoCloseForState(
        const VoiceCallUiState(
          status: VoiceCallStatus.failed,
          roomId: '!room:p2p-im.com',
          error: outgoingCallNetworkFailureMessage,
        ),
        routeRoomId: '!room:p2p-im.com',
        routeCallId: null,
        callWasConnected: false,
      ),
      isFalse,
    );
  });

  test('call page auto close prefers AS call id over room id', () {
    expect(
      callPageShouldAutoCloseForState(
        const VoiceCallUiState(
          status: VoiceCallStatus.failed,
          callId: 'as-call-old',
          roomId: '!room:p2p-im.com',
          error: peerNoResponseMessage,
        ),
        routeRoomId: '!room:p2p-im.com',
        routeCallId: 'as-call-new',
        callWasConnected: false,
      ),
      isFalse,
    );
    expect(
      callPageShouldAutoCloseForState(
        const VoiceCallUiState(
          status: VoiceCallStatus.failed,
          callId: 'as-call-new',
          roomId: '!room:p2p-im.com',
          error: peerNoResponseMessage,
        ),
        routeRoomId: '!room:p2p-im.com',
        routeCallId: 'as-call-new',
        callWasConnected: false,
      ),
      isTrue,
    );
  });

  test('outgoing retry ignores stale terminal state from previous call', () {
    const staleFailed = VoiceCallUiState(
      status: VoiceCallStatus.failed,
      roomId: '!room:p2p-im.com',
      error: peerNoResponseMessage,
    );

    expect(
      callPageShouldInspectInitialStateForClose(
        staleFailed,
        routeIsIncoming: false,
      ),
      isFalse,
    );
    expect(
      callPageShouldInspectInitialStateForClose(
        staleFailed,
        routeIsIncoming: true,
      ),
      isTrue,
    );
    expect(
      callPageShouldInspectInitialStateForClose(
        const VoiceCallUiState(
          status: VoiceCallStatus.calling,
          roomId: '!room:p2p-im.com',
        ),
        routeIsIncoming: false,
      ),
      isTrue,
    );
  });
}

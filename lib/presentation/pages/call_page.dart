import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../call/voice_call_controller.dart';
import '../call/voice_call_display_name.dart';
import '../providers/auth_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/voice_call_provider.dart';
import '../utils/direct_contact_status.dart';
import '../utils/read_marker_sync.dart';
import '../utils/room_read_state.dart';

const _callBg = Color(0xFF1A1C1F); // theme-fixed: call surface is fixed dark.
const _callBgTop = Color(0xFF2C2C2E); // theme-fixed.
const _callText = Colors.white; // theme-fixed.
const _callDanger = Color(0xFFBA1A1A); // theme-fixed.
const _callSuccess = Color(0xFF32D74B); // theme-fixed.
const _callSecure = Color(0xFF72FE88); // theme-fixed.

bool callPageUsesVideoControls(
  VoiceCallUiState state, {
  required bool routeIsVideo,
  required String routeRoomId,
}) {
  final hasActiveRouteCall = state.roomId == routeRoomId && state.isActive;
  return hasActiveRouteCall ? state.isVideo : routeIsVideo;
}

bool shouldUseConnectedVideoCallLayout(VoiceCallUiState state) {
  return state.isVideo && state.status == VoiceCallStatus.connected;
}

enum LocalVideoControlState {
  inactive,
  unavailable,
  active,
  muted,
}

LocalVideoControlState localVideoControlState({
  required bool isVideoCall,
  required bool hasLocalVideoTrack,
  required bool isCameraMuted,
}) {
  if (!isVideoCall) return LocalVideoControlState.inactive;
  return isCameraMuted
      ? LocalVideoControlState.muted
      : LocalVideoControlState.active;
}

String localVideoControlLabel(LocalVideoControlState state) {
  return switch (state) {
    LocalVideoControlState.inactive => '键盘',
    LocalVideoControlState.unavailable => '开摄像头',
    LocalVideoControlState.active => '关摄像头',
    LocalVideoControlState.muted => '开摄像头',
  };
}

bool localVideoControlCanToggle(LocalVideoControlState state) {
  return state == LocalVideoControlState.active ||
      state == LocalVideoControlState.unavailable ||
      state == LocalVideoControlState.muted;
}

String remoteVideoPlaceholderTitle(VoiceCallUiState state) {
  return state.status == VoiceCallStatus.connected ? '对方摄像头不可用' : '等待对方画面';
}

String speakerControlLabel(bool isSpeakerOn) {
  return isSpeakerOn ? '扬声器' : '听筒';
}

String callStatusDisplayText(
  VoiceCallUiState state, {
  String? overrideText,
  required DateTime now,
}) {
  final stateError = state.error?.trim();
  if (overrideText?.trim().isNotEmpty ?? false) return overrideText!.trim();
  if (stateError != null && stateError.isNotEmpty) return stateError;
  if (state.status == VoiceCallStatus.connected && state.connectedAt != null) {
    return _formatCallElapsed(now.difference(state.connectedAt!));
  }
  return voiceCallStatusLabel(state);
}

bool callPageShouldAutoCloseForState(
  VoiceCallUiState state, {
  required String routeRoomId,
  String? routeCallId,
  required bool callWasConnected,
}) {
  if (!callPageStateMatchesRoute(
    state,
    routeRoomId: routeRoomId,
    routeCallId: routeCallId,
  )) {
    return false;
  }
  if (state.status == VoiceCallStatus.ended) return true;
  if (state.status != VoiceCallStatus.failed) return false;
  final error = state.error?.trim();
  return error == peerNoResponseMessage ||
      (callWasConnected && error == connectedCallInterruptedMessage);
}

bool callPageStateMatchesRoute(
  VoiceCallUiState state, {
  required String routeRoomId,
  String? routeCallId,
}) {
  final expectedCallId = routeCallId?.trim();
  final actualCallId = state.callId?.trim();
  if (expectedCallId != null && expectedCallId.isNotEmpty) {
    return actualCallId != null &&
        actualCallId.isNotEmpty &&
        actualCallId == expectedCallId;
  }
  return state.roomId == routeRoomId;
}

bool callPageShouldInspectInitialStateForClose(
  VoiceCallUiState state, {
  required bool routeIsIncoming,
}) {
  if (routeIsIncoming) return true;
  return state.isActive;
}

bool _hasLocalVideoTrack(CallSession? session) {
  final stream = session?.localUserMediaStream?.stream;
  return stream?.getVideoTracks().isNotEmpty ?? false;
}

class CallPage extends ConsumerStatefulWidget {
  const CallPage({
    super.key,
    required this.roomId,
    this.isVideo = false,
    this.callId,
    this.peerUserId,
    this.peerDisplayName,
    this.incoming = false,
  });

  final String roomId;
  final bool isVideo;
  final String? callId;
  final String? peerUserId;
  final String? peerDisplayName;
  final bool incoming;

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  bool _startedOutgoing = false;
  bool _mutatingMute = false;
  bool _closingAfterEnd = false;
  bool _syncedConnectedCallRead = false;
  bool _callWasConnected = false;
  StreamSubscription<VoiceCallUiState>? _callStateSub;
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _listenForEndedCall();
      unawaited(_prepareCall());
    });
  }

  @override
  void didUpdateWidget(covariant CallPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId ||
        oldWidget.callId != widget.callId ||
        oldWidget.peerUserId != widget.peerUserId ||
        oldWidget.incoming != widget.incoming) {
      _startedOutgoing = false;
      _closingAfterEnd = false;
      _syncedConnectedCallRead = false;
      _callWasConnected = false;
      _localError = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_prepareCall());
      });
    }
  }

  @override
  void dispose() {
    unawaited(_callStateSub?.cancel());
    super.dispose();
  }

  void _listenForEndedCall() {
    final controller = ref.read(voiceCallControllerProvider);
    _callStateSub ??= controller.stateStream.listen(_handleCallStateForClose);
    final currentState = controller.currentState;
    if (callPageShouldInspectInitialStateForClose(
      currentState,
      routeIsIncoming: widget.incoming,
    )) {
      _handleCallStateForClose(currentState);
    }
  }

  void _handleCallStateForClose(VoiceCallUiState state) {
    if (!mounted || _closingAfterEnd) {
      return;
    }
    if (!callPageStateMatchesRoute(
      state,
      routeRoomId: widget.roomId,
      routeCallId: widget.callId,
    )) {
      return;
    }
    if (state.status == VoiceCallStatus.connected) {
      _callWasConnected = true;
      return;
    }
    if (!callPageShouldAutoCloseForState(
      state,
      routeRoomId: widget.roomId,
      routeCallId: widget.callId,
      callWasConnected: _callWasConnected,
    )) {
      return;
    }
    _closingAfterEnd = true;
    if (_callWasConnected) {
      unawaited(_markConnectedCallRecordRead());
    }
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _closePage();
    });
  }

  Future<void> _markConnectedCallRecordRead() async {
    if (_syncedConnectedCallRead) return;
    _syncedConnectedCallRead = true;
    final controller = ref.read(voiceCallControllerProvider);
    final session = controller.activeSession;
    final room = session?.room ??
        ref.read(matrixClientProvider).getRoomById(
              widget.roomId,
            );
    if (room == null || session == null) return;

    markRoomLocallyRead(room);

    final event = latestCallHangupEventForCall(
      room: room,
      callId: session.callId,
    );
    if (event == null) return;
    try {
      await room.setReadMarker(event.eventId, mRead: event.eventId);
      await updateAsReadMarkerForEvent(
        asClient: ref.read(asClientProvider),
        room: room,
        event: event,
      );
    } on Object catch (e) {
      debugPrint('call read marker sync failed: $e');
    }
  }

  Future<void> _prepareCall() async {
    final controller = ref.read(voiceCallControllerProvider);
    final client = ref.read(matrixClientProvider);
    await controller.attachClient(client);

    if (widget.incoming || _startedOutgoing) return;

    _startedOutgoing = true;
    final peerUserId = _resolvePeerUserId(client);
    if (peerUserId == null) {
      if (mounted) {
        setState(() => _localError = '无法确定通话对象');
      }
      return;
    }
    await controller.startOutgoing(
      roomId: widget.roomId,
      peerUserId: peerUserId,
      peerDisplayName: widget.peerDisplayName,
      callType: widget.isVideo ? ProductCallType.video : ProductCallType.voice,
    );
  }

  String? _resolvePeerUserId(Client client) {
    final fromRoute = widget.peerUserId?.trim();
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    final room = client.getRoomById(widget.roomId);
    if (room == null) return null;
    return productDirectPeerMxid(room) ?? joinedPersonPeerMxid(room);
  }

  Future<void> _hangupAndClose() async {
    await ref.read(voiceCallControllerProvider).hangup();
    if (!mounted) return;
    _closePage();
  }

  void _closePage() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _toggleMute(VoiceCallUiState state) async {
    if (_mutatingMute) return;
    setState(() => _mutatingMute = true);
    try {
      await ref.read(voiceCallControllerProvider).setMuted(!state.isMuted);
    } finally {
      if (mounted) setState(() => _mutatingMute = false);
    }
  }

  Future<void> _toggleCamera(VoiceCallUiState state) async {
    if (!state.isVideo) return;
    await ref
        .read(voiceCallControllerProvider)
        .setCameraMuted(!state.isCameraMuted);
  }

  Future<void> _toggleSpeaker(VoiceCallUiState state) {
    return ref
        .read(voiceCallControllerProvider)
        .setSpeakerOn(!state.isSpeakerOn);
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(matrixClientProvider);
    final room = client.getRoomById(widget.roomId);
    final controller = ref.watch(voiceCallControllerProvider);

    return StreamBuilder<VoiceCallUiState>(
      stream: controller.stateStream,
      initialData: controller.currentState,
      builder: (context, snapshot) {
        final rawState = snapshot.data ?? controller.currentState;
        final state =
            rawState.roomId == widget.roomId || rawState.roomId == null
                ? rawState
                : const VoiceCallUiState(
                    status: VoiceCallStatus.failed,
                    error: '已有通话正在进行',
                  );
        final syncCache = ref.watch(asSyncCacheProvider);
        final peerMxid =
            widget.peerUserId ?? state.peerUserId ?? _resolvePeerUserId(client);
        final contact = peerMxid == null
            ? syncCache.contactForRoom(widget.roomId)
            : syncCache.contactForUserId(peerMxid) ??
                syncCache.contactForRoom(widget.roomId);
        final displayName = voiceCallPeerDisplayName(
          peerMxid: peerMxid,
          contactDisplayName: contact?.displayName ?? '',
          contactDomain: contact?.domain ?? '',
          routeDisplayName: widget.peerDisplayName,
          statePeerName: state.peerName,
          roomDisplayName: room?.getLocalizedDisplayname(),
        );
        final isError =
            state.status == VoiceCallStatus.failed || _localError != null;
        final isVideoCall = callPageUsesVideoControls(
          state,
          routeIsVideo: widget.isVideo,
          routeRoomId: widget.roomId,
        );
        final hasLocalVideoTrack =
            _hasLocalVideoTrack(controller.activeSession);

        if (shouldUseConnectedVideoCallLayout(state)) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: _ConnectedVideoCallScreen(
              controller: controller,
              state: state.copyWith(callType: ProductCallType.video),
              displayName: displayName,
              overrideText: _localError,
              isError: isError,
              onClose: _hangupAndClose,
              onToggleMute: () => unawaited(_toggleMute(state)),
              onToggleCamera: () => unawaited(_toggleCamera(state)),
              onToggleSpeaker: () => unawaited(_toggleSpeaker(state)),
              onHangup: _hangupAndClose,
            ),
          );
        }

        return Scaffold(
          backgroundColor: _callBg,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_callBgTop, _callBg],
                stops: [0.0, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                    child: Row(
                      children: [
                        _CloseButton(onTap: _hangupAndClose),
                        Expanded(
                          child: Center(
                            child: Text(
                              isVideoCall ? '视频通话' : '语音通话',
                              style: AppTheme.sans(
                                size: 13,
                                weight: FontWeight.w500,
                                color: _callText.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  Expanded(
                    child: isVideoCall
                        ? _VideoCallStage(
                            controller: controller,
                            state: state.copyWith(
                              callType: ProductCallType.video,
                            ),
                            displayName: displayName,
                            overrideText: _localError,
                            isError: isError,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _CallAvatar(name: displayName),
                              const SizedBox(height: 20),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.sans(
                                    size: 28,
                                    weight: FontWeight.w700,
                                    color: _callText,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _CallStatusText(
                                state: state,
                                overrideText: _localError,
                                isError: isError,
                              ),
                              const SizedBox(height: 20),
                              const _SecureBadge(),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                    child: state.canAnswer
                        ? _IncomingControls(
                            onAnswer: () => unawaited(
                              ref.read(voiceCallControllerProvider).answer(),
                            ),
                            onReject: _hangupAndClose,
                          )
                        : _ActiveControls(
                            state: state,
                            isVideo: isVideoCall,
                            hasLocalVideoTrack: hasLocalVideoTrack,
                            onToggleMute: () => unawaited(_toggleMute(state)),
                            onToggleCamera: () =>
                                unawaited(_toggleCamera(state)),
                            onToggleSpeaker: () =>
                                unawaited(_toggleSpeaker(state)),
                            onHangup: _hangupAndClose,
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConnectedVideoCallScreen extends StatefulWidget {
  const _ConnectedVideoCallScreen({
    required this.controller,
    required this.state,
    required this.displayName,
    required this.isError,
    required this.onClose,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onToggleSpeaker,
    required this.onHangup,
    this.overrideText,
  });

  final VoiceCallController controller;
  final VoiceCallUiState state;
  final String displayName;
  final String? overrideText;
  final bool isError;
  final VoidCallback onClose;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onHangup;

  @override
  State<_ConnectedVideoCallScreen> createState() =>
      _ConnectedVideoCallScreenState();
}

class _ConnectedVideoCallScreenState extends State<_ConnectedVideoCallScreen> {
  static const double _previewWidth = 112;
  static const double _previewHeight = 156;
  static const double _previewMargin = 18;

  Offset? _previewOffset;

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.activeSession;
    final remoteStream = session?.remoteUserMediaStream?.stream;
    final localStream = session?.localUserMediaStream?.stream;
    final hasRemoteVideo = remoteStream?.getVideoTracks().isNotEmpty ?? false;
    final hasLocalVideo = localStream?.getVideoTracks().isNotEmpty ?? false;
    final viewPadding = MediaQuery.of(context).viewPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final previewOffset = _clampedPreviewOffset(
          _previewOffset ?? _defaultPreviewOffset(size, viewPadding),
          size,
          viewPadding,
        );

        return Stack(
          key: const Key('video-call-connected-stage'),
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: _ConnectedRemoteVideoSurface(
                stream: remoteStream,
                hasVideo: hasRemoteVideo,
                displayName: widget.displayName,
                state: widget.state,
                overrideText: widget.overrideText,
                isError: widget.isError,
              ),
            ),
            Positioned(
              left: previewOffset.dx,
              top: previewOffset.dy,
              child: GestureDetector(
                key: const Key('video-call-local-preview-draggable'),
                onPanUpdate: (details) {
                  setState(() {
                    _previewOffset = _clampedPreviewOffset(
                      previewOffset + details.delta,
                      size,
                      viewPadding,
                    );
                  });
                },
                child: _LocalVideoPreview(
                  stream: localStream,
                  hasLocalVideoTrack: hasLocalVideo,
                  isCameraMuted: widget.state.isCameraMuted,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                  child: Row(
                    children: [
                      _CloseButton(onTap: widget.onClose),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTheme.sans(
                                size: 16,
                                weight: FontWeight.w700,
                                color: _callText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _CallStatusText(
                              state: widget.state,
                              overrideText: widget.overrideText,
                              isError: widget.isError,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 52, 32, 28),
                    child: _ActiveControls(
                      state: widget.state,
                      isVideo: true,
                      hasLocalVideoTrack: hasLocalVideo,
                      onToggleMute: widget.onToggleMute,
                      onToggleCamera: widget.onToggleCamera,
                      onToggleSpeaker: widget.onToggleSpeaker,
                      onHangup: widget.onHangup,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Offset _defaultPreviewOffset(Size size, EdgeInsets padding) {
    return Offset(
      size.width - _previewWidth - _previewMargin,
      padding.top + 72,
    );
  }

  Offset _clampedPreviewOffset(
    Offset offset,
    Size size,
    EdgeInsets padding,
  ) {
    const minX = _previewMargin;
    final minY = padding.top + _previewMargin;
    final maxX = math.max(minX, size.width - _previewWidth - _previewMargin);
    final hardMaxY = math.max(
      minY,
      size.height - _previewHeight - padding.bottom - _previewMargin,
    );
    final controlsAwareMaxY =
        size.height - _previewHeight - padding.bottom - 212;
    final maxY = math.max(minY, math.min(hardMaxY, controlsAwareMaxY));
    return Offset(
      offset.dx.clamp(minX, maxX).toDouble(),
      offset.dy.clamp(minY, maxY).toDouble(),
    );
  }
}

class _ConnectedRemoteVideoSurface extends StatelessWidget {
  const _ConnectedRemoteVideoSurface({
    required this.stream,
    required this.hasVideo,
    required this.displayName,
    required this.state,
    required this.isError,
    this.overrideText,
  });

  final webrtc.MediaStream? stream;
  final bool hasVideo;
  final String displayName;
  final VoiceCallUiState state;
  final String? overrideText;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    if (hasVideo) {
      return ColoredBox(
        key: const Key('video-call-remote-stage'),
        color: Colors.black,
        child: _RtcVideoSurface(stream: stream, mirror: false),
      );
    }

    return DecoratedBox(
      key: const Key('video-call-remote-waiting-stage'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101114), Color(0xFF000000)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _callText.withValues(alpha: 0.10),
                  border: Border.all(
                    color: _callText.withValues(alpha: 0.14),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Symbols.videocam,
                  size: 42,
                  color: _callText.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                remoteVideoPlaceholderTitle(state),
                style: AppTheme.sans(
                  size: 22,
                  weight: FontWeight.w700,
                  color: _callText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTheme.sans(
                  size: 15,
                  color: _callText.withValues(alpha: 0.58),
                ),
              ),
              const SizedBox(height: 8),
              _CallStatusText(
                state: state,
                overrideText: overrideText,
                isError: isError,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalVideoPreview extends StatelessWidget {
  const _LocalVideoPreview({
    required this.stream,
    required this.hasLocalVideoTrack,
    required this.isCameraMuted,
  });

  final webrtc.MediaStream? stream;
  final bool hasLocalVideoTrack;
  final bool isCameraMuted;

  @override
  Widget build(BuildContext context) {
    final hasActiveVideo = hasLocalVideoTrack && !isCameraMuted;
    final placeholderLabel = isCameraMuted ? '摄像头已关' : '摄像头打开中';
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _callText.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          key: const Key('video-call-local-preview'),
          width: _ConnectedVideoCallScreenState._previewWidth,
          height: _ConnectedVideoCallScreenState._previewHeight,
          child: hasActiveVideo
              ? _RtcVideoSurface(stream: stream, mirror: true)
              : ColoredBox(
                  color: const Color(0xFF1C1C1E),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Symbols.videocam_off,
                        size: 30,
                        color: _callText.withValues(alpha: 0.70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        placeholderLabel,
                        style: AppTheme.sans(
                          size: 12,
                          color: _callText.withValues(alpha: 0.70),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _VideoCallStage extends StatelessWidget {
  const _VideoCallStage({
    required this.controller,
    required this.state,
    required this.displayName,
    required this.isError,
    this.overrideText,
  });

  final VoiceCallController controller;
  final VoiceCallUiState state;
  final String displayName;
  final String? overrideText;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final session = controller.activeSession;
    final remoteStream = session?.remoteUserMediaStream?.stream;
    final localStream = session?.localUserMediaStream?.stream;
    final hasRemoteVideo = remoteStream?.getVideoTracks().isNotEmpty ?? false;
    final hasLocalVideo = localStream?.getVideoTracks().isNotEmpty ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasRemoteVideo)
          _RtcVideoSurface(stream: remoteStream, mirror: false)
        else
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CallAvatar(name: displayName),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 28,
                      weight: FontWeight.w700,
                      color: _callText,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _CallStatusText(
                  state: state,
                  overrideText: overrideText,
                  isError: isError,
                ),
                const SizedBox(height: 20),
                const _SecureBadge(),
              ],
            ),
          ),
        if (hasRemoteVideo)
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Column(
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTheme.sans(
                    size: 22,
                    weight: FontWeight.w700,
                    color: _callText,
                  ),
                ),
                const SizedBox(height: 6),
                _CallStatusText(
                  state: state,
                  overrideText: overrideText,
                  isError: isError,
                ),
              ],
            ),
          ),
        if (hasLocalVideo)
          Positioned(
            top: 12,
            right: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _callText.withValues(alpha: 0.18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 112,
                  height: 156,
                  child: _RtcVideoSurface(stream: localStream, mirror: true),
                ),
              ),
            ),
          ),
        if (state.isCameraMuted)
          Positioned(
            top: 24,
            right: 28,
            child: _MutedVideoBadge(hasLocalPreview: hasLocalVideo),
          ),
      ],
    );
  }
}

class _RtcVideoSurface extends StatefulWidget {
  const _RtcVideoSurface({
    required this.stream,
    required this.mirror,
  });

  final webrtc.MediaStream? stream;
  final bool mirror;

  @override
  State<_RtcVideoSurface> createState() => _RtcVideoSurfaceState();
}

class _RtcVideoSurfaceState extends State<_RtcVideoSurface> {
  late final webrtc.RTCVideoRenderer _renderer;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _renderer = webrtc.RTCVideoRenderer();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _renderer.initialize();
    if (!mounted) return;
    _renderer.srcObject = widget.stream;
    setState(() => _ready = true);
  }

  @override
  void didUpdateWidget(covariant _RtcVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream && _ready) {
      _renderer.srcObject = widget.stream;
    }
  }

  @override
  void dispose() {
    _renderer.srcObject = null;
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || widget.stream == null) {
      return ColoredBox(color: Colors.black.withValues(alpha: 0.35));
    }
    return webrtc.RTCVideoView(
      _renderer,
      mirror: widget.mirror,
      objectFit: webrtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}

class _MutedVideoBadge extends StatelessWidget {
  const _MutedVideoBadge({required this.hasLocalPreview});

  final bool hasLocalPreview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: hasLocalPreview ? 0.55 : 0.32),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.videocam_off, size: 16, color: _callText),
          const SizedBox(width: 6),
          Text(
            '摄像头已关',
            style: AppTheme.sans(size: 12, color: _callText),
          ),
        ],
      ),
    );
  }
}

class _CallStatusText extends StatefulWidget {
  const _CallStatusText({
    required this.state,
    required this.isError,
    this.overrideText,
  });

  final VoiceCallUiState state;
  final String? overrideText;
  final bool isError;

  @override
  State<_CallStatusText> createState() => _CallStatusTextState();
}

class _CallStatusTextState extends State<_CallStatusText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _CallStatusText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.status != widget.state.status ||
        oldWidget.state.connectedAt != widget.state.connectedAt) {
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (widget.state.status != VoiceCallStatus.connected ||
        widget.state.connectedAt == null) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = callStatusDisplayText(
      widget.state,
      overrideText: widget.overrideText,
      now: DateTime.now(),
    );
    return Text(
      text,
      style: AppTheme.sans(
        size: 17,
        color: widget.isError ? _callDanger : _callText.withValues(alpha: 0.5),
      ),
    );
  }
}

String _formatCallElapsed(Duration elapsed) {
  final seconds = elapsed.inSeconds.clamp(0, 24 * 60 * 60);
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

class _CallAvatar extends StatelessWidget {
  const _CallAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _callText.withValues(alpha: 0.1),
        border: Border.all(
          color: _callText.withValues(alpha: 0.15),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
        style: AppTheme.sans(
          size: 44,
          weight: FontWeight.w700,
          color: _callText.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _SecureBadge extends StatelessWidget {
  const _SecureBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _callSecure.withValues(alpha: 0.20),
        border: Border.all(color: _callSecure.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _callSecure,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '端到端加密',
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w500,
              color: _callSecure,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingControls extends StatelessWidget {
  const _IncomingControls({
    required this.onAnswer,
    required this.onReject,
  });

  final VoidCallback onAnswer;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundActionButton(
          icon: Symbols.call_end,
          label: '拒绝',
          color: _callDanger,
          onTap: onReject,
        ),
        _RoundActionButton(
          icon: Symbols.call,
          label: '接听',
          color: _callSuccess,
          onTap: onAnswer,
        ),
      ],
    );
  }
}

class _ActiveControls extends StatelessWidget {
  const _ActiveControls({
    required this.state,
    required this.isVideo,
    required this.hasLocalVideoTrack,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onToggleSpeaker,
    required this.onHangup,
  });

  final VoiceCallUiState state;
  final bool isVideo;
  final bool hasLocalVideoTrack;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onHangup;

  @override
  Widget build(BuildContext context) {
    final videoState = localVideoControlState(
      isVideoCall: isVideo,
      hasLocalVideoTrack: hasLocalVideoTrack,
      isCameraMuted: state.isCameraMuted,
    );
    final canToggleVideo = localVideoControlCanToggle(videoState);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ControlButton(
              icon: state.isMuted ? Symbols.mic_off : Symbols.mic,
              label: state.isMuted ? '已静音' : '静音',
              selected: state.isMuted,
              onTap: onToggleMute,
            ),
            _ControlButton(
              icon: switch (videoState) {
                LocalVideoControlState.inactive => Symbols.dialpad,
                LocalVideoControlState.active => Symbols.videocam,
                LocalVideoControlState.muted ||
                LocalVideoControlState.unavailable =>
                  Symbols.videocam_off,
              },
              label: localVideoControlLabel(videoState),
              selected: videoState == LocalVideoControlState.muted ||
                  videoState == LocalVideoControlState.unavailable,
              enabled: !isVideo || canToggleVideo,
              onTap: isVideo && canToggleVideo ? onToggleCamera : null,
            ),
            _ControlButton(
              icon: state.isSpeakerOn ? Symbols.volume_up : Symbols.volume_off,
              label: speakerControlLabel(state.isSpeakerOn),
              selected: state.isSpeakerOn,
              onTap: onToggleSpeaker,
            ),
          ],
        ),
        const SizedBox(height: 32),
        _HangupButton(onTap: onHangup),
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Symbols.keyboard_arrow_down,
          size: 28,
          color: _callText.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.selected = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: enabled ? onTap : null,
      radius: 38,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? _callText.withValues(alpha: enabled ? 0.22 : 0.12)
                  : _callText.withValues(alpha: enabled ? 0.1 : 0.06),
              border: Border.all(
                color: _callText.withValues(alpha: enabled ? 0.12 : 0.06),
              ),
            ),
            child: Icon(
              icon,
              size: 26,
              color: _callText.withValues(alpha: enabled ? 1 : 0.42),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTheme.sans(
              size: 11,
              color: _callText.withValues(alpha: enabled ? 0.5 : 0.32),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 42,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, size: 32, color: _callText, fill: 1),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTheme.sans(
              size: 11,
              color: _callText.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _HangupButton extends StatefulWidget {
  const _HangupButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_HangupButton> createState() => _HangupButtonState();
}

class _HangupButtonState extends State<_HangupButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _pulse = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final t = _pulse.value;
              return Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _callDanger,
                  boxShadow: [
                    BoxShadow(
                      color: _callDanger.withValues(alpha: 0.6 * (1.0 - t)),
                      blurRadius: 0,
                      spreadRadius: 18 * t,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: const Icon(
              Symbols.call_end,
              size: 32,
              color: _callText,
              fill: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '挂断',
            style: AppTheme.sans(
              size: 11,
              color: _callText.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

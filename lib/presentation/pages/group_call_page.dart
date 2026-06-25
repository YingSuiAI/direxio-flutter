import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:matrix/matrix.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../call/voice_call_controller.dart';
import '../providers/auth_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/personal_space_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/voice_call_provider.dart';
import '../utils/avatar_url.dart';

const _groupCallBg =
    Color(0xFF1A1C1F); // theme-fixed: call surface is fixed dark.
const _groupCallBgTop = Color(0xFF2C2C2E); // theme-fixed.
const _groupCallText = Colors.white; // theme-fixed.
const _groupCallDanger = Color(0xFFBA1A1A); // theme-fixed.
const _groupCallAutotestEnabled = bool.fromEnvironment(
  'P2P_CALL_AUTOTEST',
  defaultValue: false,
);

bool groupCallRouteShouldAutoAnswer({
  required bool requestedByRoute,
  required bool autotestEnabled,
}) {
  return requestedByRoute && autotestEnabled;
}

class GroupCallPage extends ConsumerStatefulWidget {
  const GroupCallPage({
    super.key,
    required this.roomId,
    this.roomName,
    this.callId,
    this.inviteeIds = const [],
    this.isVideo = false,
    this.incoming = false,
    this.autoAnswer = false,
  });

  final String roomId;
  final String? roomName;
  final String? callId;
  final List<String> inviteeIds;
  final bool isVideo;
  final bool incoming;
  final bool autoAnswer;

  @override
  ConsumerState<GroupCallPage> createState() => _GroupCallPageState();
}

class _GroupCallPageState extends ConsumerState<GroupCallPage> {
  bool _started = false;
  bool _answeredIncoming = false;
  bool _sawConnectedCall = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_prepareGroupCall());
    });
  }

  Future<void> _prepareGroupCall() async {
    if (_started) return;
    _started = true;
    final controller = ref.read(voiceCallControllerProvider);
    await controller.attachClient(ref.read(matrixClientProvider));
    if (widget.incoming) {
      if (groupCallRouteShouldAutoAnswer(
        requestedByRoute: widget.autoAnswer,
        autotestEnabled: _groupCallAutotestEnabled,
      )) {
        await _answerIncoming();
      }
      return;
    }
    await controller.startOrJoinGroupCall(
      roomId: widget.roomId,
      roomName: _roomName,
      callType: widget.isVideo ? ProductCallType.video : ProductCallType.voice,
      invitedUserIds: widget.inviteeIds,
    );
  }

  String get _roomName {
    final name = widget.roomName?.trim();
    return name == null || name.isEmpty ? '群聊' : name;
  }

  Future<void> _leaveAndClose() async {
    _closing = true;
    await ref.read(voiceCallControllerProvider).leaveGroupCall();
    if (mounted) unawaited(Navigator.of(context).maybePop());
  }

  Future<void> _answerIncoming() async {
    if (_answeredIncoming) return;
    setState(() {
      _answeredIncoming = true;
    });
    await ref.read(voiceCallControllerProvider).startOrJoinGroupCall(
          roomId: widget.roomId,
          roomName: _roomName,
          callType:
              widget.isVideo ? ProductCallType.video : ProductCallType.voice,
          joinExistingInvite: true,
          existingCallId: widget.callId,
        );
  }

  GroupCallUiState _initialState() {
    return GroupCallUiState(
      status:
          widget.incoming ? GroupCallStatus.ringing : GroupCallStatus.joining,
      callType: widget.isVideo ? ProductCallType.video : ProductCallType.voice,
      roomId: widget.roomId,
      roomName: _roomName,
      callId: widget.callId,
      isIncoming: widget.incoming,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(voiceCallControllerProvider);
    return StreamBuilder<GroupCallUiState>(
      stream: controller.groupStateStream,
      initialData: controller.currentGroupState.roomId == widget.roomId
          ? controller.currentGroupState
          : _initialState(),
      builder: (context, snapshot) {
        final rawState = snapshot.data ?? _initialState();
        final state = groupCallStateWithResolvedProfiles(
          rawState,
          syncCache: ref.watch(asSyncCacheProvider),
          currentUserProfile: ref.watch(currentUserProfileProvider).valueOrNull,
          localDisplayNameOverride:
              ref.watch(personalProfileProvider).displayName,
          client: ref.watch(matrixClientProvider),
        );
        final isVideo = state.isVideo || widget.isVideo;
        _trackAndCloseEndedCall(state);
        final awaitingIncomingAnswer = widget.incoming &&
            !_answeredIncoming &&
            state.status != GroupCallStatus.ended &&
            state.status != GroupCallStatus.failed;

        return Scaffold(
          backgroundColor: _groupCallBg,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: isVideo
                      ? _GroupVideoStage(state: state)
                      : _GroupVoiceStage(state: state),
                ),
                Positioned(
                  left: 16,
                  top: 12,
                  right: 16,
                  child: _GroupCallHeader(
                    roomName: state.roomName ?? _roomName,
                    isVideo: isVideo,
                    onClose: () => unawaited(_leaveAndClose()),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 28,
                  child: _GroupCallControls(
                    state: state,
                    isVideo: isVideo,
                    onAnswer: awaitingIncomingAnswer
                        ? () => unawaited(_answerIncoming())
                        : null,
                    onToggleMute: () => unawaited(
                      controller.setGroupMuted(!state.isMuted),
                    ),
                    onToggleCamera: () => unawaited(
                      controller.setGroupCameraMuted(!state.isCameraMuted),
                    ),
                    onToggleSpeaker: () => unawaited(
                      controller.setGroupSpeakerOn(!state.isSpeakerOn),
                    ),
                    onLeave: () => unawaited(_leaveAndClose()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _trackAndCloseEndedCall(GroupCallUiState state) {
    if (state.roomId == widget.roomId &&
        state.status == GroupCallStatus.connected) {
      _sawConnectedCall = true;
    }
    if (_closing || !_sawConnectedCall) return;
    final sameRoom = state.roomId == null || state.roomId == widget.roomId;
    final shouldClose = sameRoom &&
        (state.status == GroupCallStatus.ended ||
            state.status == GroupCallStatus.idle);
    if (!shouldClose) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(Navigator.of(context).maybePop());
    });
  }
}

class _GroupCallHeader extends StatelessWidget {
  const _GroupCallHeader({
    required this.roomName,
    required this.isVideo,
    required this.onClose,
  });

  final String roomName;
  final bool isVideo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundCallButton(
          icon: Symbols.arrow_back,
          label: Localizations.of<AppLocalizations>(context, AppLocalizations)
                  ?.groupCallBack ??
              '返回',
          onTap: onClose,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _groupCallBgTop.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    roomName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 17,
                      weight: FontWeight.w700,
                      color: _groupCallText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isVideo
                        ? Localizations.of<AppLocalizations>(
                              context,
                              AppLocalizations,
                            )?.groupCallTitleVideo ??
                            '群视频通话'
                        : Localizations.of<AppLocalizations>(
                              context,
                              AppLocalizations,
                            )?.groupCallTitleVoice ??
                            '群语音通话',
                    style: AppTheme.sans(
                      size: 12,
                      color: _groupCallText.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 52),
      ],
    );
  }
}

class _GroupVoiceStage extends StatelessWidget {
  const _GroupVoiceStage({required this.state});

  final GroupCallUiState state;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_groupCallBgTop, _groupCallBg],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GroupCallParticipants(state: state),
            const SizedBox(height: 24),
            Text(
              groupCallStatusLabel(
                state,
                l10n: Localizations.of<AppLocalizations>(
                  context,
                  AppLocalizations,
                ),
              ),
              style: AppTheme.sans(
                size: 24,
                weight: FontWeight.w700,
                color: _groupCallText,
              ),
            ),
            const SizedBox(height: 8),
            _ParticipantCountText(state: state),
          ],
        ),
      ),
    );
  }
}

class _GroupVideoStage extends StatelessWidget {
  const _GroupVideoStage({required this.state});

  final GroupCallUiState state;

  @override
  Widget build(BuildContext context) {
    final videoStreams = state.videoStreams;
    final hasVideoFeeds = videoStreams.isNotEmpty;
    return DecoratedBox(
      key: const Key('group-video-call-stage'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101114), Color(0xFF000000)], // theme-fixed.
        ),
      ),
      child: hasVideoFeeds
          ? _GroupVideoGrid(state: state, videoStreams: videoStreams)
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GroupCallParticipants(state: state),
                    const SizedBox(height: 16),
                    Text(
                      groupCallStatusLabel(
                        state,
                        l10n: Localizations.of<AppLocalizations>(
                          context,
                          AppLocalizations,
                        ),
                      ),
                      style: AppTheme.sans(
                        size: 24,
                        weight: FontWeight.w700,
                        color: _groupCallText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ParticipantCountText(state: state),
                    const SizedBox(height: 16),
                    Text(
                      Localizations.of<AppLocalizations>(
                            context,
                            AppLocalizations,
                          )?.groupCallWaitingMembersVideo ??
                          '等待群成员视频画面',
                      textAlign: TextAlign.center,
                      style: AppTheme.sans(
                        size: 14,
                        color: _groupCallText.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _GroupVideoGrid extends StatelessWidget {
  const _GroupVideoGrid({
    required this.state,
    required this.videoStreams,
  });

  final GroupCallUiState state;
  final List<GroupCallVideoStreamInfo> videoStreams;

  @override
  Widget build(BuildContext context) {
    final tileCount = videoStreams.length;
    final crossAxisCount = tileCount <= 1 ? 1 : 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 112, 12, 132),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: tileCount <= 2 ? 0.72 : 0.68,
            ),
            itemCount: tileCount,
            itemBuilder: (context, index) {
              final stream = videoStreams[index];
              return _GroupVideoTile(
                stream: stream,
                participant: _participantForStream(stream.userId),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.34),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 56, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        groupCallStatusLabel(
                          state,
                          l10n: Localizations.of<AppLocalizations>(
                            context,
                            AppLocalizations,
                          ),
                        ),
                        textAlign: TextAlign.center,
                        style: AppTheme.sans(
                          size: 20,
                          weight: FontWeight.w700,
                          color: _groupCallText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _ParticipantCountText(state: state),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  GroupCallParticipantInfo? _participantForStream(String userId) {
    for (final participant in state.participants) {
      if (participant.userId == userId) return participant;
    }
    for (final participant in state.invitedParticipants) {
      if (participant.userId == userId) return participant;
    }
    return null;
  }
}

class _GroupVideoTile extends StatelessWidget {
  const _GroupVideoTile({
    required this.stream,
    required this.participant,
  });

  final GroupCallVideoStreamInfo stream;
  final GroupCallParticipantInfo? participant;

  @override
  Widget build(BuildContext context) {
    final displayName = participant?.displayName.trim().isNotEmpty == true
        ? participant!.displayName
        : _fallbackName(stream.userId);
    final canRender = stream.canRender;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final streamStatusLabel = !stream.hasVideo
        ? l10n?.groupCallCameraUnavailable ?? '摄像头不可用'
        : stream.isMuted
            ? l10n?.callCameraOffState ?? '摄像头已关'
            : l10n?.groupCallWaitingVideo ?? '等待视频画面';
    return ClipRRect(
      key: ValueKey(
        stream.isLocal
            ? 'group-video-tile-local'
            : 'group-video-tile-${stream.userId}',
      ),
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.44),
            ),
            child: canRender
                ? _GroupRtcVideoSurface(
                    stream: stream.stream,
                    mirror: stream.isLocal,
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (participant == null)
                          _FallbackVideoAvatar(name: displayName)
                        else
                          _GroupCallParticipantAvatar(
                              participant: participant!),
                        const SizedBox(height: 12),
                        Text(
                          streamStatusLabel,
                          style: AppTheme.sans(
                            size: 13,
                            color: _groupCallText.withValues(alpha: 0.70),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTheme.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: _groupCallText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupRtcVideoSurface extends StatefulWidget {
  const _GroupRtcVideoSurface({
    required this.stream,
    required this.mirror,
  });

  final webrtc.MediaStream? stream;
  final bool mirror;

  @override
  State<_GroupRtcVideoSurface> createState() => _GroupRtcVideoSurfaceState();
}

class _GroupRtcVideoSurfaceState extends State<_GroupRtcVideoSurface> {
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
  void didUpdateWidget(covariant _GroupRtcVideoSurface oldWidget) {
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

class _FallbackVideoAvatar extends StatelessWidget {
  const _FallbackVideoAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final letter =
        name.characters.isEmpty ? '?' : name.characters.first.toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _groupCallText.withValues(alpha: 0.12),
        border: Border.all(color: _groupCallText.withValues(alpha: 0.18)),
      ),
      child: SizedBox(
        width: 76,
        height: 76,
        child: Center(
          child: Text(
            letter,
            style: AppTheme.sans(
              size: 30,
              weight: FontWeight.w700,
              color: _groupCallText,
            ),
          ),
        ),
      ),
    );
  }
}

String _fallbackName(String userId) {
  final normalized = userId.trim();
  if (normalized.startsWith('@') && normalized.contains(':')) {
    return normalized.substring(1, normalized.indexOf(':'));
  }
  return normalized.isEmpty ? '成员' : normalized;
}

class _ParticipantCountText extends StatefulWidget {
  const _ParticipantCountText({required this.state});

  final GroupCallUiState state;

  @override
  State<_ParticipantCountText> createState() => _ParticipantCountTextState();
}

class _ParticipantCountTextState extends State<_ParticipantCountText> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _ParticipantCountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.connectedAt != widget.state.connectedAt ||
        oldWidget.state.status != widget.state.status) {
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
    _now = DateTime.now();
    if (widget.state.status != GroupCallStatus.connected ||
        widget.state.connectedAt == null) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final connectedAt = state.connectedAt;
    final count = state.effectiveParticipantCount <= 0
        ? 1
        : state.effectiveParticipantCount;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final label =
        state.status == GroupCallStatus.connected && connectedAt != null
            ? _formatGroupCallElapsed(_now.difference(connectedAt))
            : state.status == GroupCallStatus.connected
                ? count <= 1
                    ? l10n?.groupCallWaitingMembers ?? '等待成员加入'
                    : l10n?.groupCallParticipantCount(count) ?? '$count 人通话中'
                : l10n?.groupCallReadyToJoin ?? '准备加入';
    return Text(
      label,
      style: AppTheme.sans(
        size: 15,
        color: _groupCallText.withValues(alpha: 0.64),
      ),
    );
  }
}

String _formatGroupCallElapsed(Duration duration) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;
  final twoDigits = remainingSeconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$twoDigits';
  }
  return '$minutes:$twoDigits';
}

GroupCallUiState groupCallStateWithResolvedProfiles(
  GroupCallUiState state, {
  required AsSyncCacheState syncCache,
  Profile? currentUserProfile,
  String? localDisplayNameOverride,
  Client? client,
}) {
  final initiator = state.initiator == null
      ? null
      : _groupCallParticipantWithResolvedProfile(
          state.initiator!,
          syncCache: syncCache,
          currentUserProfile: currentUserProfile,
          localDisplayNameOverride: localDisplayNameOverride,
          client: client,
        );
  final invitedParticipants = [
    for (final participant in state.invitedParticipants)
      _groupCallParticipantWithResolvedProfile(
        participant,
        syncCache: syncCache,
        currentUserProfile: currentUserProfile,
        localDisplayNameOverride: localDisplayNameOverride,
        client: client,
      ),
  ];
  final participants = <GroupCallParticipantInfo>[];
  final seenParticipantIds = <String>{};
  void addParticipant(GroupCallParticipantInfo participant) {
    final resolved = _groupCallParticipantWithResolvedProfile(
      participant,
      syncCache: syncCache,
      currentUserProfile: currentUserProfile,
      localDisplayNameOverride: localDisplayNameOverride,
      client: client,
    );
    if (seenParticipantIds.add(resolved.userId)) {
      participants.add(resolved);
    }
  }

  for (final participant in state.participants) {
    addParticipant(participant);
  }
  for (final userId in state.joinedUserIds) {
    final normalized = userId.trim();
    if (normalized.isEmpty || seenParticipantIds.contains(normalized)) {
      continue;
    }
    addParticipant(
      GroupCallParticipantInfo(
        userId: normalized,
        displayName: _fallbackGroupCallParticipantName(normalized),
      ),
    );
  }
  return GroupCallUiState(
    status: state.status,
    callType: state.callType,
    roomId: state.roomId,
    roomName: state.roomName,
    callId: state.callId,
    createdByMxid: state.createdByMxid,
    initiator: initiator,
    invitedUserIds: state.invitedUserIds,
    invitedParticipants: invitedParticipants,
    isIncoming: state.isIncoming,
    participantCount: state.participantCount,
    participants: participants,
    joinedUserIds: state.joinedUserIds,
    mediaUserIds: state.mediaUserIds,
    videoStreams: state.videoStreams,
    isMuted: state.isMuted,
    isCameraMuted: state.isCameraMuted,
    isSpeakerOn: state.isSpeakerOn,
    connectedAt: state.connectedAt,
    error: state.error,
  );
}

GroupCallParticipantInfo _groupCallParticipantWithResolvedProfile(
  GroupCallParticipantInfo participant, {
  required AsSyncCacheState syncCache,
  Profile? currentUserProfile,
  String? localDisplayNameOverride,
  Client? client,
}) {
  final userId = participant.userId.trim();
  final localUserId = syncCache.bootstrap?.user.userId.trim();
  final isLocal = participant.isLocal ||
      (localUserId != null && localUserId.isNotEmpty && localUserId == userId);
  if (isLocal) {
    final localName = _firstNonEmpty([
      localDisplayNameOverride,
      currentUserProfile?.displayName,
      participant.displayName,
    ]);
    final localAvatar = _firstNonEmpty([
      _profileAvatarUrl(currentUserProfile, client),
      participant.avatarUrl,
    ]);
    return GroupCallParticipantInfo(
      userId: participant.userId,
      displayName: localName,
      avatarUrl: localAvatar,
      isLocal: true,
    );
  }

  final contact = syncCache.contactForUserId(userId);
  final displayName = _firstNonEmpty([
    contact?.displayName,
    participant.displayName,
  ]);
  final avatarUrl = _firstNonEmpty([
    _contactAvatarUrl(contact?.avatarUrl, client),
    participant.avatarUrl,
  ]);
  return GroupCallParticipantInfo(
    userId: participant.userId,
    displayName: displayName,
    avatarUrl: avatarUrl,
    isLocal: participant.isLocal,
  );
}

String _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

String _fallbackGroupCallParticipantName(String userId) {
  final normalized = userId.trim();
  if (normalized.isEmpty) return '';
  final localpart = normalized.startsWith('@')
      ? normalized.substring(1).split(':').first
      : normalized.split(':').first;
  return localpart.isEmpty ? normalized : localpart;
}

String? _profileAvatarUrl(Profile? profile, Client? client) {
  if (profile == null) return null;
  if (client != null) return profileAvatarHttpUrl(profile, client);
  final value = profile.avatarUrl?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

String? _contactAvatarUrl(String? avatarUrl, Client? client) {
  final value = avatarUrl?.trim();
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (client != null && uri != null && uri.scheme == 'mxc') {
    return matrixContentHttpUrl(client, uri);
  }
  return value;
}

class _GroupCallParticipants extends StatelessWidget {
  const _GroupCallParticipants({required this.state});

  final GroupCallUiState state;

  @override
  Widget build(BuildContext context) {
    final participants = _visibleParticipants();
    if (participants.isEmpty) {
      return const _GroupCallWaitingBadge();
    }
    final hasExpectedParticipants = state.invitedParticipants.isNotEmpty;
    final joinedUserIds = {
      ...state.joinedUserIds,
      ...state.mediaUserIds,
      if (!hasExpectedParticipants)
        for (final participant in state.participants) participant.userId,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final participant in participants.take(8))
            _GroupCallParticipantTile(
              participant: participant,
              isJoined: _isJoinedParticipant(
                participant,
                joinedUserIds,
                hasExpectedParticipants: hasExpectedParticipants,
              ),
            ),
        ],
      ),
    );
  }

  bool _isJoinedParticipant(
    GroupCallParticipantInfo participant,
    Set<String> joinedUserIds, {
    required bool hasExpectedParticipants,
  }) {
    if (!hasExpectedParticipants) return true;
    if (joinedUserIds.contains(participant.userId)) return true;
    if (state.status == GroupCallStatus.ringing &&
        participant.userId == state.initiator?.userId) {
      return true;
    }
    return false;
  }

  List<GroupCallParticipantInfo> _visibleParticipants() {
    if (state.invitedParticipants.isEmpty) return state.participants;
    final seen = <String>{};
    final participants = <GroupCallParticipantInfo>[];
    for (final participant in state.invitedParticipants) {
      if (seen.add(participant.userId)) participants.add(participant);
    }
    for (final participant in state.participants) {
      if (seen.add(participant.userId)) participants.add(participant);
    }
    for (final userId in state.joinedUserIds) {
      final normalized = userId.trim();
      if (normalized.isEmpty || !seen.add(normalized)) continue;
      participants.add(
        GroupCallParticipantInfo(
          userId: normalized,
          displayName: _fallbackGroupCallParticipantName(normalized),
        ),
      );
    }
    return participants;
  }
}

class _GroupCallWaitingBadge extends StatelessWidget {
  const _GroupCallWaitingBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _groupCallText.withValues(alpha: 0.14),
        border: Border.all(
          color: _groupCallText.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: SizedBox(
        width: 88,
        height: 88,
        child: Icon(
          Symbols.groups,
          size: 38,
          color: _groupCallText.withValues(alpha: 0.76),
        ),
      ),
    );
  }
}

class _GroupCallParticipantTile extends StatelessWidget {
  const _GroupCallParticipantTile({
    required this.participant,
    required this.isJoined,
  });

  final GroupCallParticipantInfo participant;
  final bool isJoined;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      key: ValueKey('group-call-participant-${participant.userId}'),
      opacity: isJoined ? 1 : 0.38,
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: participant.isLocal
                      ? const Color(0xFF6BFF8D).withValues(alpha: 0.62)
                      : _groupCallText.withValues(alpha: 0.22),
                  width: participant.isLocal ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _GroupCallParticipantAvatar(participant: participant),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              participant.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTheme.sans(
                size: 12,
                weight: FontWeight.w600,
                color: _groupCallText.withValues(alpha: 0.82),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCallParticipantAvatar extends StatelessWidget {
  const _GroupCallParticipantAvatar({required this.participant});

  final GroupCallParticipantInfo participant;

  @override
  Widget build(BuildContext context) {
    final seed = participant.displayName.trim().isNotEmpty
        ? participant.displayName.trim()
        : participant.userId;
    final effective = seed.startsWith('@') && seed.contains(':')
        ? seed.substring(1, seed.indexOf(':'))
        : seed;
    final letter =
        effective.isNotEmpty ? effective.characters.first.toUpperCase() : '?';
    final url = participant.avatarUrl?.trim();
    return ClipOval(
      child: SizedBox(
        width: 64,
        height: 64,
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(letter),
              )
            : _fallback(letter),
      ),
    );
  }

  Widget _fallback(String letter) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _groupCallText.withValues(alpha: 0.15),
      ),
      child: Center(
        child: Text(
          letter,
          style: AppTheme.sans(
            size: 26,
            weight: FontWeight.w700,
            color: _groupCallText,
          ),
        ),
      ),
    );
  }
}

class _GroupCallControls extends StatelessWidget {
  const _GroupCallControls({
    required this.state,
    required this.isVideo,
    required this.onAnswer,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onToggleSpeaker,
    required this.onLeave,
  });

  final GroupCallUiState state;
  final bool isVideo;
  final VoidCallback? onAnswer;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final hasLocalVideoTrack = state.videoStreams.any(
      (stream) => stream.isLocal && stream.hasVideo,
    );
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final canToggleCamera = !isVideo || hasLocalVideoTrack;
    final cameraLabel = !hasLocalVideoTrack
        ? l10n?.groupCallCameraUnavailable ?? '摄像头不可用'
        : state.isCameraMuted
            ? l10n?.callCameraOn ?? '开摄像头'
            : l10n?.callCameraOff ?? '关摄像头';
    if (onAnswer != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundCallButton(
            icon: Symbols.call_end,
            label: l10n?.callHangup ?? '挂断',
            backgroundColor: _groupCallDanger,
            onTap: onLeave,
          ),
          _RoundCallButton(
            icon: isVideo ? Symbols.video_call : Symbols.call,
            label: l10n?.groupCallJoin ?? '加入',
            backgroundColor: const Color(0xFF2E7D32),
            onTap: onAnswer!,
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundCallButton(
          icon: state.isMuted ? Symbols.mic_off : Symbols.mic,
          label: state.isMuted
              ? l10n?.callUnmute ?? '取消静音'
              : l10n?.callMute ?? '静音',
          onTap: onToggleMute,
        ),
        if (isVideo)
          _RoundCallButton(
            icon: state.isCameraMuted ? Symbols.videocam_off : Symbols.videocam,
            label: cameraLabel,
            onTap: onToggleCamera,
            enabled: canToggleCamera,
          ),
        _RoundCallButton(
          icon: state.isSpeakerOn ? Symbols.volume_up : Symbols.hearing,
          label: state.isSpeakerOn
              ? l10n?.callSpeaker ?? '扬声器'
              : l10n?.callEarpiece ?? '听筒',
          onTap: onToggleSpeaker,
        ),
        _RoundCallButton(
          key: const Key('group-call-leave-button'),
          icon: Symbols.call_end,
          label: l10n?.groupCallLeave ?? '离开',
          backgroundColor: _groupCallDanger,
          onTap: onLeave,
        ),
      ],
    );
  }
}

class _RoundCallButton extends StatelessWidget {
  const _RoundCallButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: backgroundColor ??
                        _groupCallText.withValues(alpha: 0.14),
                    border: Border.all(
                      color: backgroundColor == null
                          ? _groupCallText.withValues(alpha: 0.16)
                          : _groupCallDanger.withValues(alpha: 0.4),
                    ),
                  ),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(
                      icon,
                      color: _groupCallText,
                      size: 25,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: AppTheme.sans(
                    size: 12,
                    color: _groupCallText.withValues(alpha: 0.66),
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

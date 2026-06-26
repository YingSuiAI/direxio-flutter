import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../providers/voice_call_provider.dart';
import 'voice_call_controller.dart';

enum ActiveCallMiniWindowKind { direct, group }

class ActiveCallMiniWindow {
  const ActiveCallMiniWindow({
    required this.kind,
    required this.roomId,
    required this.isVideo,
    this.callId,
    this.peerUserId,
    this.title,
    this.avatarUrl,
    this.incoming = false,
  });

  final ActiveCallMiniWindowKind kind;
  final String roomId;
  final bool isVideo;
  final String? callId;
  final String? peerUserId;
  final String? title;
  final String? avatarUrl;
  final bool incoming;
}

final activeCallMiniWindowProvider =
    StateProvider<ActiveCallMiniWindow?>((ref) => null);

bool directCallMiniWindowShouldStayVisible(VoiceCallUiState state) {
  return state.isActive;
}

bool groupCallMiniWindowShouldStayVisible(GroupCallUiState state) {
  return state.isActive;
}

String activeCallMiniWindowRoute(ActiveCallMiniWindow call) {
  final roomPath = Uri.encodeComponent(call.roomId);
  final path = switch (call.kind) {
    ActiveCallMiniWindowKind.direct =>
      call.isVideo ? '/video-call/$roomPath' : '/call/$roomPath',
    ActiveCallMiniWindowKind.group =>
      call.isVideo ? '/group-video-call/$roomPath' : '/group-call/$roomPath',
  };
  final query = <String, String>{'restore': '1'};
  final callId = _filled(call.callId);
  final peer = _filled(call.peerUserId);
  final title = _filled(call.title);
  final avatar = _filled(call.avatarUrl);
  if (callId != null) query['call_id'] = callId;
  if (call.kind == ActiveCallMiniWindowKind.direct && peer != null) {
    query['peer'] = peer;
  }
  if (title != null) query['name'] = title;
  if (call.kind == ActiveCallMiniWindowKind.direct && avatar != null) {
    query['avatar'] = avatar;
  }
  if (call.incoming) query['incoming'] = '1';
  return Uri(path: path, queryParameters: query).toString();
}

String? _filled(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class ActiveCallMiniWindowOverlay extends ConsumerStatefulWidget {
  const ActiveCallMiniWindowOverlay({
    super.key,
    required this.child,
    this.onRestoreRoute,
  });

  final Widget child;
  final ValueChanged<String>? onRestoreRoute;

  @override
  ConsumerState<ActiveCallMiniWindowOverlay> createState() =>
      _ActiveCallMiniWindowOverlayState();
}

class _ActiveCallMiniWindowOverlayState
    extends ConsumerState<ActiveCallMiniWindowOverlay> {
  Offset? _offset;

  @override
  Widget build(BuildContext context) {
    final miniCall = ref.watch(activeCallMiniWindowProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (miniCall != null) _buildMiniWindow(context, miniCall),
      ],
    );
  }

  Widget _buildMiniWindow(BuildContext context, ActiveCallMiniWindow miniCall) {
    final controller = ref.watch(voiceCallControllerProvider);
    return switch (miniCall.kind) {
      ActiveCallMiniWindowKind.direct => StreamBuilder<VoiceCallUiState>(
          stream: controller.stateStream,
          initialData: controller.currentState,
          builder: (context, snapshot) {
            final state = snapshot.data ?? controller.currentState;
            if (!_matchesDirectCall(miniCall, state) ||
                !directCallMiniWindowShouldStayVisible(state)) {
              _clearAfterFrame();
              return const SizedBox.shrink();
            }
            final l10n = AppLocalizations.of(context);
            return _PositionedMiniWindow(
              offset: _offset,
              onOffsetChanged: (offset) => setState(() => _offset = offset),
              onTap: () => _restore(miniCall),
              child: _ActiveCallMiniWindowCard(
                isVideo: state.isVideo || miniCall.isVideo,
                title: _filled(miniCall.title) ??
                    _filled(state.peerName) ??
                    (state.isVideo || miniCall.isVideo
                        ? l10n.contactVideoCall
                        : l10n.groupChatVoiceCall),
                status: voiceCallStatusLabel(state, l10n: l10n),
              ),
            );
          },
        ),
      ActiveCallMiniWindowKind.group => StreamBuilder<GroupCallUiState>(
          stream: controller.groupStateStream,
          initialData: controller.currentGroupState,
          builder: (context, snapshot) {
            final state = snapshot.data ?? controller.currentGroupState;
            if (!_matchesGroupCall(miniCall, state) ||
                !groupCallMiniWindowShouldStayVisible(state)) {
              _clearAfterFrame();
              return const SizedBox.shrink();
            }
            final l10n = AppLocalizations.of(context);
            return _PositionedMiniWindow(
              offset: _offset,
              onOffsetChanged: (offset) => setState(() => _offset = offset),
              onTap: () => _restore(miniCall),
              child: _ActiveCallMiniWindowCard(
                isVideo: state.isVideo || miniCall.isVideo,
                title: _filled(state.roomName) ??
                    _filled(miniCall.title) ??
                    (state.isVideo || miniCall.isVideo
                        ? l10n.groupCallTitleVideo
                        : l10n.groupCallTitleVoice),
                status: groupCallStatusLabel(state, l10n: l10n),
              ),
            );
          },
        ),
    };
  }

  bool _matchesDirectCall(
    ActiveCallMiniWindow miniCall,
    VoiceCallUiState state,
  ) {
    final stateCallId = _filled(state.callId);
    final miniCallId = _filled(miniCall.callId);
    if (stateCallId != null && miniCallId != null) {
      return stateCallId == miniCallId;
    }
    return _filled(state.roomId) == miniCall.roomId;
  }

  bool _matchesGroupCall(
    ActiveCallMiniWindow miniCall,
    GroupCallUiState state,
  ) {
    final stateCallId = _filled(state.callId);
    final miniCallId = _filled(miniCall.callId);
    if (stateCallId != null && miniCallId != null) {
      return stateCallId == miniCallId;
    }
    return _filled(state.roomId) == miniCall.roomId;
  }

  void _clearAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(activeCallMiniWindowProvider.notifier).state = null;
    });
  }

  void _restore(ActiveCallMiniWindow miniCall) {
    final route = activeCallMiniWindowRoute(miniCall);
    ref.read(activeCallMiniWindowProvider.notifier).state = null;
    final restore = widget.onRestoreRoute;
    if (restore != null) {
      restore(route);
      return;
    }
    context.push(route);
  }
}

class _PositionedMiniWindow extends StatelessWidget {
  const _PositionedMiniWindow({
    required this.child,
    required this.offset,
    required this.onOffsetChanged,
    required this.onTap,
  });

  static const Size _size = Size(172, 76);
  static const double _margin = 16;

  final Widget child;
  final Offset? offset;
  final ValueChanged<Offset> onOffsetChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final defaultOffset = Offset(_margin, media.padding.top + 72);
    final current = _clamp(offset ?? defaultOffset, media.size, media.padding);
    return Positioned(
      left: current.dx,
      top: current.dy,
      child: GestureDetector(
        key: const Key('active_call_mini_window'),
        onTap: onTap,
        onPanUpdate: (details) {
          onOffsetChanged(
            _clamp(current + details.delta, media.size, media.padding),
          );
        },
        child: SizedBox.fromSize(size: _size, child: child),
      ),
    );
  }

  Offset _clamp(Offset value, Size screen, EdgeInsets padding) {
    final maxX = math.max(_margin, screen.width - _size.width - _margin);
    final maxY = math.max(
      padding.top + _margin,
      screen.height - _size.height - padding.bottom - _margin,
    );
    return Offset(
      value.dx.clamp(_margin, maxX).toDouble(),
      value.dy.clamp(padding.top + _margin, maxY).toDouble(),
    );
  }
}

class _ActiveCallMiniWindowCard extends StatelessWidget {
  const _ActiveCallMiniWindowCard({
    required this.isVideo,
    required this.title,
    required this.status,
  });

  final bool isVideo;
  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.callMiniRestore,
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.accent.withValues(alpha: 0.18),
                ),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    isVideo ? Symbols.videocam : Symbols.call,
                    size: 22,
                    color: t.accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 15,
                        weight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 12,
                        color: t.textMute,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

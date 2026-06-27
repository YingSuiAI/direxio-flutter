import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class UserActionDebounce extends StatefulWidget {
  const UserActionDebounce({
    super.key,
    required this.child,
    this.duration = defaultDuration,
  });

  static const defaultDuration = Duration(milliseconds: 200);

  final Widget child;
  final Duration duration;

  @override
  State<UserActionDebounce> createState() => _UserActionDebounceState();
}

class _UserActionDebounceState extends State<UserActionDebounce> {
  final Map<int, _PointerTapCandidate> _candidates = {};
  Timer? _timer;
  bool _absorbing = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_absorbing) return;
    _candidates[event.pointer] = _PointerTapCandidate(
      position: event.position,
      eligible: _isPrimaryPointer(event),
    );
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final candidate = _candidates[event.pointer];
    if (candidate == null) return;
    if ((event.position - candidate.position).distance > kTouchSlop) {
      candidate.moved = true;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final candidate = _candidates.remove(event.pointer);
    if (candidate == null || !candidate.eligible || candidate.moved) return;
    _startDebounce();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _candidates.remove(event.pointer);
  }

  bool _isPrimaryPointer(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      return event.buttons == kPrimaryButton;
    }
    return true;
  }

  void _startDebounce() {
    if (widget.duration <= Duration.zero) return;
    _timer?.cancel();
    if (!_absorbing) {
      setState(() => _absorbing = true);
    }
    _timer = Timer(widget.duration, () {
      if (!mounted) return;
      setState(() => _absorbing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_absorbing)
            const Positioned.fill(
              child: AbsorbPointer(
                child: SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}

class _PointerTapCandidate {
  _PointerTapCandidate({
    required this.position,
    required this.eligible,
  });

  final Offset position;
  final bool eligible;
  bool moved = false;
}

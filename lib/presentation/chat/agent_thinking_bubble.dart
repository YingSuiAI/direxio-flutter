import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

class AgentThinkingBubble extends StatefulWidget {
  const AgentThinkingBubble({super.key});

  @override
  State<AgentThinkingBubble> createState() => _AgentThinkingBubbleState();
}

class _AgentThinkingBubbleState extends State<AgentThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      label: 'Agent thinking',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            key: const ValueKey('agent_thinking_dots'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                _ThinkingDot(
                  progress: _dotProgress(_controller.value, i),
                  color: t.accent,
                ),
                if (i != 2) const SizedBox(width: 5),
              ],
            ],
          );
        },
      ),
    );
  }

  double _dotProgress(double value, int index) {
    final shifted = (value - index * 0.18) % 1.0;
    return (math.sin(shifted * math.pi * 2) + 1) / 2;
  }
}

class _ThinkingDot extends StatelessWidget {
  const _ThinkingDot({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scale = 0.72 + progress * 0.34;
    final opacity = 0.38 + progress * 0.62;
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: 8),
        ),
      ),
    );
  }
}

/// Agent 工具调用气泡：可折叠卡片，显示 tool name / args / result summary / latency
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

class ToolCallBubble extends StatefulWidget {
  const ToolCallBubble({
    super.key,
    required this.toolName,
    required this.args,
    required this.resultSummary,
    required this.latencyMs,
    this.warnings = const [],
    this.denied = false,
    this.deniedReason,
  });
  final String toolName;
  final Map<String, dynamic> args;
  final String resultSummary;
  final int latencyMs;
  final List<String> warnings;
  final bool denied;
  final String? deniedReason;

  @override
  State<ToolCallBubble> createState() => _ToolCallBubbleState();
}

class _ToolCallBubbleState extends State<ToolCallBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final color = widget.denied ? t.danger : t.accent;
    final argsJson = const JsonEncoder.withIndent('  ').convert(widget.args);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: t.border),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    Icon(
                      widget.denied
                          ? LucideIcons.circle_x
                          : LucideIcons.wrench,
                      size: 12,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Text(widget.toolName,
                        style: AppTheme.mono(
                            size: 12,
                            color: t.text,
                            weight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.denied
                            ? (widget.deniedReason ?? '被拒')
                            : widget.resultSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppTheme.sans(size: 11, color: t.textMute),
                      ),
                    ),
                    if (!widget.denied)
                      Text('${widget.latencyMs}ms',
                          style: AppTheme.mono(
                              size: 10, color: t.textMute)),
                    const SizedBox(width: 6),
                    Icon(
                      _expanded
                          ? LucideIcons.chevron_up
                          : LucideIcons.chevron_down,
                      size: 12,
                      color: t.textMute,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(height: 1, color: t.border),
                    const SizedBox(height: 6),
                    Text('参数',
                        style: AppTheme.mono(
                            size: 10,
                            color: t.textMute,
                            weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: t.bg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: t.border),
                      ),
                      child: SelectableText(
                        argsJson,
                        style: AppTheme.mono(size: 11, color: t.text),
                      ),
                    ),
                    if (widget.warnings.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('警告',
                          style: AppTheme.mono(
                              size: 10,
                              color: t.textMute,
                              weight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ...widget.warnings.map((w) => Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 1),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Icon(LucideIcons.triangle_alert,
                                    size: 11, color: Colors.amber),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(w,
                                      style: AppTheme.sans(
                                          size: 11, color: t.textMute)),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final phase = (_c.value + i * 0.2) % 1.0;
              final scale = 0.7 + 0.5 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: t.accentCool,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

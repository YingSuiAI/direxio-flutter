import 'dart:async';

// AI Bot / Agent 消息体：渲染 Markdown
// 用户自己的消息走纯文本，不进这个组件
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../chat/agent_message_content.dart';

class AgentMessageBody extends StatefulWidget {
  const AgentMessageBody(
    this.text, {
    super.key,
    this.selectable = true,
    this.cards = const [],
    this.isGenerating = false,
    this.animateUpdates = false,
  });

  final String text;
  final bool selectable;
  final List<AgentMessageCard> cards;
  final bool isGenerating;
  final bool animateUpdates;

  @override
  State<AgentMessageBody> createState() => _AgentMessageBodyState();
}

class _AgentMessageBodyState extends State<AgentMessageBody> {
  static const _typewriterTick = Duration(milliseconds: 16);
  static const _typewriterCharsPerTick = 6;

  Timer? _typewriterTimer;
  late String _visibleText;
  late String _targetText;

  @override
  void initState() {
    super.initState();
    _visibleText = widget.text;
    _targetText = widget.text;
  }

  @override
  void didUpdateWidget(covariant AgentMessageBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text == _targetText) return;
    if (!widget.animateUpdates ||
        !widget.text.startsWith(_visibleText) ||
        widget.text.length <= _visibleText.length) {
      _typewriterTimer?.cancel();
      _targetText = widget.text;
      _visibleText = widget.text;
      return;
    }
    _targetText = widget.text;
    _startTypewriter();
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    super.dispose();
  }

  void _startTypewriter() {
    _typewriterTimer?.cancel();
    _typewriterTimer = Timer.periodic(_typewriterTick, (_) {
      if (!mounted) return;
      if (_visibleText.length >= _targetText.length) {
        _typewriterTimer?.cancel();
        return;
      }
      setState(() {
        final nextLength =
            (_visibleText.length + _typewriterCharsPerTick).clamp(
          0,
          _targetText.length,
        );
        _visibleText = _targetText.substring(0, nextLength);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final text = _visibleText;
    final baseStyle = AppTheme.sans(
      size: 14,
      color: t.text,
    ).copyWith(height: 1.55);

    final md = GptMarkdown(
      text,
      style: baseStyle,
      followLinkColor: true,
      onLinkTap: (url, title) {
        // Links are rendered as text until the product defines navigation.
      },
      codeBuilder: (ctx, name, code, closed) =>
          _CodeBlock(language: name, code: code),
      highlightBuilder: (ctx, code, style) => _InlineCode(text: code),
      tableBuilder: (ctx, rows, textStyle, config) => _M3Table(rows: rows),
    );

    // 收敛标题字号——气泡内不需要 headlineLarge 那么夸张
    final mdTheme = GptMarkdownTheme.of(context).copyWith(
      h1: AppTheme.sans(size: 18, color: t.text, weight: FontWeight.w700),
      h2: AppTheme.sans(size: 16, color: t.text, weight: FontWeight.w700),
      h3: AppTheme.sans(size: 15, color: t.text, weight: FontWeight.w600),
      h4: AppTheme.sans(size: 14, color: t.text, weight: FontWeight.w600),
      h5: AppTheme.sans(size: 14, color: t.text, weight: FontWeight.w600),
      h6: AppTheme.sans(size: 14, color: t.text, weight: FontWeight.w600),
    );
    final themed = GptMarkdownTheme(gptThemeData: mdTheme, child: md);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (text.trim().isNotEmpty)
          widget.selectable ? SelectionArea(child: themed) : themed,
        for (final card in widget.cards) ...[
          if (text.trim().isNotEmpty || widget.cards.indexOf(card) > 0)
            const SizedBox(height: 8),
          _AgentStructuredCard(card: card),
        ],
        if (widget.isGenerating) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: t.accent,
                ),
              ),
              const SizedBox(width: 6),
              Text('生成中', style: AppTheme.sans(size: 11, color: t.textMute)),
            ],
          ),
        ],
      ],
    );

    return content;
  }
}

class _AgentStructuredCard extends StatelessWidget {
  const _AgentStructuredCard({required this.card});

  final AgentMessageCard card;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (card.title.trim().isNotEmpty) ...[
            Row(
              children: [
                Icon(Symbols.smart_toy, size: 15, color: t.accentCool),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    card.title.trim(),
                    style: AppTheme.sans(
                      size: 13,
                      color: t.text,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (card.blocks.isNotEmpty || card.actions.isNotEmpty)
              const SizedBox(height: 8),
          ],
          for (final block in card.blocks) ...[
            if (block.kind == 'divider')
              Divider(height: 14, color: t.border.withValues(alpha: 0.55))
            else
              AgentMessageBody(block.text, selectable: false),
            if (card.blocks.last != block) const SizedBox(height: 6),
          ],
          if (card.actions.isNotEmpty) ...[
            if (card.blocks.isNotEmpty) const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final action in card.actions)
                  _AgentCardActionChip(action: action),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AgentCardActionChip extends StatelessWidget {
  const _AgentCardActionChip({required this.action});

  final AgentMessageCardAction action;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final danger = action.kind.trim().toLowerCase() == 'danger';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: danger
            ? t.danger.withValues(alpha: 0.08)
            : t.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: danger
              ? t.danger.withValues(alpha: 0.35)
              : t.accent.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        action.label,
        style: AppTheme.sans(
          size: 12,
          color: danger ? t.danger : t.accentCool,
          weight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InlineCode extends StatelessWidget {
  const _InlineCode({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: t.surfaceHover,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: t.border),
      ),
      child: Text(text, style: AppTheme.mono(size: 12, color: t.accentCool)),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.language, required this.code});
  final String language;
  final String code;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: t.surfaceHover,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: t.bg.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
              border: Border(bottom: BorderSide(color: t.border)),
            ),
            child: Row(
              children: [
                Text(
                  language.isEmpty ? 'code' : language,
                  style: AppTheme.mono(
                    size: 10,
                    color: t.textMute,
                    weight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Clipboard.setData(ClipboardData(text: code)),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      '复制',
                      style: AppTheme.mono(size: 10, color: t.textMute),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: SelectableText(
              code,
              style: AppTheme.mono(
                size: 12,
                color: t.text,
              ).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

//// M3 风格表格 —— 替代 gpt_markdown 默认的浏览器黑框表格。
class _M3Table extends StatelessWidget {
  const _M3Table({required this.rows});
  final List<CustomTableRow> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder.symmetric(
          inside: BorderSide(color: t.border.withValues(alpha: 0.4)),
        ),
        children: [
          for (final row in rows)
            TableRow(
              decoration: BoxDecoration(
                color: row.isHeader ? t.surfaceHigh : null,
              ),
              children: [
                for (final field in row.fields)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      // cell 内的简单 md 标记（**粗体** 等）直接剥离
                      field.data.replaceAll(RegExp(r'[*_`]'), ''),
                      textAlign: field.alignment,
                      style: AppTheme.sans(
                        size: 13,
                        color: t.text,
                        weight:
                            row.isHeader ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

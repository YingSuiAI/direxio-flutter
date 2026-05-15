/// AI Bot / Agent 消息体：渲染 Markdown
/// 用户自己的消息走纯文本，不进这个组件
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

class AgentMessageBody extends StatelessWidget {
  const AgentMessageBody(this.text, {super.key, this.selectable = true});
  final String text;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final baseStyle =
        AppTheme.sans(size: 14, color: t.text).copyWith(height: 1.55);

    final md = GptMarkdown(
      text,
      style: baseStyle,
      followLinkColor: true,
      onLinkTap: (url, title) {
        // mock 阶段：什么都不做
      },
      codeBuilder: (ctx, name, code, closed) =>
          _CodeBlock(language: name, code: code),
      highlightBuilder: (ctx, code, style) => _InlineCode(text: code),
    );

    return selectable ? SelectionArea(child: md) : md;
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
      child: Text(
        text,
        style: AppTheme.mono(size: 12, color: t.accentCool),
      ),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: t.bg.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6)),
              border: Border(bottom: BorderSide(color: t.border)),
            ),
            child: Row(
              children: [
                Text(
                  language.isEmpty ? 'code' : language,
                  style: AppTheme.mono(
                      size: 10,
                      color: t.textMute,
                      weight: FontWeight.w600),
                ),
                const Spacer(),
                InkWell(
                  onTap: () =>
                      Clipboard.setData(ClipboardData(text: code)),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    child: Text('复制',
                        style: AppTheme.mono(
                            size: 10, color: t.textMute)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: SelectableText(
              code,
              style: AppTheme.mono(size: 12, color: t.text)
                  .copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

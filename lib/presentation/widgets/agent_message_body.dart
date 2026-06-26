// AI Bot / Agent 消息体：渲染 Markdown
// 用户自己的消息走纯文本，不进这个组件
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class AgentMessageBody extends StatelessWidget {
  const AgentMessageBody(this.text, {super.key, this.selectable = true});
  final String text;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
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

    return selectable ? SelectionArea(child: themed) : themed;
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
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
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
                      l10n?.groupChatCopy ?? '复制',
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

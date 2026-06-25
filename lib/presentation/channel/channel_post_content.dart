import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import 'channel_post_media.dart';

class ChannelPostContent extends StatelessWidget {
  const ChannelPostContent({
    super.key,
    required this.images,
    required this.body,
    required this.expanded,
    required this.onToggle,
    this.bodyColor,
  });

  final List<ChannelPostMediaImage> images;
  final String body;
  final bool expanded;
  final VoidCallback onToggle;
  final Color? bodyColor;

  static const _collapsedLines = 3;

  @override
  Widget build(BuildContext context) {
    final text = body.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty) ...[
          ChannelPostImageGrid(images: images),
          if (text.isNotEmpty) const SizedBox(height: 10),
        ],
        if (text.isNotEmpty)
          _ExpandablePostExcerpt(
            text,
            expanded: expanded,
            onToggle: onToggle,
            color: bodyColor,
          ),
      ],
    );
  }
}

String channelPostBodyText(AsChannelPost post) {
  final body = post.body.trim();
  final images = channelPostImagesFromPost(post);
  if (body.isEmpty) return '';
  if (images.isNotEmpty && _matchesPostImageName(body, images)) {
    return '';
  }
  return body;
}

bool _matchesPostImageName(
  String body,
  List<ChannelPostMediaImage> images,
) {
  final normalizedBody = body.trim();
  if (normalizedBody.isEmpty) return false;
  for (final image in images) {
    if (_sameNonEmptyText(normalizedBody, image.name)) return true;
    if (_sameNonEmptyText(normalizedBody, _basenameFromUrl(image.url))) {
      return true;
    }
  }
  return false;
}

bool _sameNonEmptyText(String left, String right) {
  final a = left.trim();
  final b = right.trim();
  return a.isNotEmpty && b.isNotEmpty && a == b;
}

String _basenameFromUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    return Uri.decodeComponent(uri.pathSegments.last);
  }
  final slash = trimmed.lastIndexOf('/');
  if (slash >= 0 && slash < trimmed.length - 1) {
    return trimmed.substring(slash + 1);
  }
  return '';
}

class _ExpandablePostExcerpt extends StatelessWidget {
  const _ExpandablePostExcerpt(
    this.text, {
    required this.expanded,
    required this.onToggle,
    this.color,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final style = AppTheme.sans(
      size: 13,
      weight: FontWeight.w500,
      color: color ?? t.text,
    ).copyWith(height: 18 / 13);
    return LayoutBuilder(
      builder: (context, constraints) {
        final canExpand = _exceedsCollapsedLines(
          context,
          style,
          constraints.maxWidth,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              maxLines: expanded ? null : ChannelPostContent._collapsedLines,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: style,
            ),
            if (canExpand) ...[
              const SizedBox(height: 10),
              _PostExpandControl(
                expanded: expanded,
                onTap: onToggle,
              ),
            ],
          ],
        );
      },
    );
  }

  bool _exceedsCollapsedLines(
    BuildContext context,
    TextStyle style,
    double maxWidth,
  ) {
    if (!maxWidth.isFinite || maxWidth <= 0) return false;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: ChannelPostContent._collapsedLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }
}

class _PostExpandControl extends StatelessWidget {
  const _PostExpandControl({
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!expanded) ...[
              Container(width: 24, height: 1, color: t.border),
              const SizedBox(width: 6),
            ],
            Text(
              expanded
                  ? l10n?.channelPostCollapse ?? '收起'
                  : l10n?.channelPostExpandMore ?? '展开更多',
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w500,
                color: t.textMute,
              ).copyWith(height: 20 / 13),
            ),
            const SizedBox(width: 2),
            Icon(
              expanded
                  ? Symbols.keyboard_arrow_up
                  : Symbols.keyboard_arrow_down,
              size: 16,
              color: t.textMute,
            ),
          ],
        ),
      ),
    );
  }
}

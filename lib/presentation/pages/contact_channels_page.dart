import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../mock/mock_data.dart';

class ContactChannelsPage extends StatelessWidget {
  const ContactChannelsPage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final channels = _channelsForUserId(userId);
    final t = context.tk;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            children: [
              _ContactChannelsHeader(onBack: () => context.pop()),
              Expanded(
                child: channels.isEmpty
                    ? Center(
                        child: Text(
                          '暂无频道',
                          style: AppTheme.sans(size: 15, color: t.textMute),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(0, 14, 0, 28),
                        children: [
                          for (var i = 0; i < channels.length; i++)
                            _ContactChannelListItem(
                              item: channels[i],
                              showDivider: i != channels.length - 1,
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

class _ContactChannelsHeader extends StatelessWidget {
  const _ContactChannelsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: t.text.withValues(alpha: 0.12),
                    blurRadius: 36,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: ClipOval(
                child: Material(
                  color: t.surface.withValues(alpha: 0.65),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onBack,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Symbols.arrow_back,
                        size: 24,
                        color: t.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            '他的频道',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(
              size: 20,
              weight: FontWeight.w600,
              color: t.text,
            ),
          ),
        ],
      ),
    );
  }
}

List<_ContactChannelItem> _channelsForUserId(String userId) {
  final home = MockData.contactHomeByMxid(userId);
  if (home == null || home.channels.isEmpty) return const [];
  return [
    for (final channel in home.channels)
      _ContactChannelItem(
        title: channel.name,
        subtitle: channel.description,
        tag: '帖子',
      ),
  ];
}

class _ContactChannelItem {
  const _ContactChannelItem({
    required this.title,
    required this.subtitle,
    required this.tag,
  });

  final String title;
  final String subtitle;
  final String tag;
}

class _ContactChannelListItem extends StatelessWidget {
  const _ContactChannelListItem({
    required this.item,
    required this.showDivider,
  });

  final _ContactChannelItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {},
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            _ChannelInitialBadge(title: item.title),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, right: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.sans(
                                  size: 14,
                                  weight: FontWeight.w600,
                                  color: t.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _ChannelTag(text: item.tag),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(size: 12, color: t.textMute),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Symbols.chevron_right,
                      size: 24,
                      color: t.text,
                    ),
                  ),
                  if (showDivider)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Divider(
                        height: 1,
                        thickness: 0.5,
                        color: t.surfaceHigh,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelInitialBadge extends StatelessWidget {
  const _ChannelInitialBadge({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final initial = title.trim().isEmpty ? '频' : title.trim().characters.first;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        initial,
        style: AppTheme.sans(
          size: 15,
          weight: FontWeight.w600,
          color: t.accent,
        ),
      ),
    );
  }
}

class _ChannelTag extends StatelessWidget {
  const _ChannelTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 14,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTheme.sans(
          size: 8,
          weight: FontWeight.w500,
          color: t.textMute,
        ),
      ),
    );
  }
}

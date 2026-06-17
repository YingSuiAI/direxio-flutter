import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../channel/channel_info_data.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/portal_avatar.dart';

class ChannelConversationPage extends ConsumerWidget {
  const ChannelConversationPage({super.key, required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channel = resolveChannelInfoData(ref, channelId);
    return Scaffold(
      backgroundColor: context.tk.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 76, 16, 96),
                children: [
                  Center(
                    child: Container(
                      width: 91,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.tk.surfaceHover,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '频道已创建',
                        style: AppTheme.sans(
                          size: 13,
                          weight: FontWeight.w500,
                          color: context.tk.textMute,
                        ).copyWith(height: 18 / 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 38),
                  _ChannelMessageRow(
                    name: 'Alice',
                    time: '10:55',
                    body: '我正在考虑接受它！！',
                    avatarSeed: '${channel.id}-alice-1',
                  ),
                  const SizedBox(height: 24),
                  _ChannelMessageRow(
                    name: 'Alice',
                    time: '10:56',
                    body: '我正在考虑接受它！！',
                    avatarSeed: '${channel.id}-alice-2',
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _ConversationTopBar(
                title: '#${channel.name}',
                onBack: () => context.pop(),
                onMore: () => context.push(
                  '/channel/${Uri.encodeComponent(channel.id)}/info',
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ConversationWriteBar(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTopBar extends StatelessWidget {
  const _ConversationTopBar({
    required this.title,
    required this.onBack,
    required this.onMore,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 16,
            top: 4,
            child: GlassHeaderButton(
              icon: Symbols.arrow_back,
              iconSize: 22,
              color: context.tk.text,
              onTap: onBack,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(
                  size: 20,
                  weight: FontWeight.w600,
                  color: context.tk.text,
                ).copyWith(height: 33 / 20),
              ),
            ],
          ),
          Positioned(
            right: 16,
            top: 4,
            child: GlassHeaderButton(
              icon: Symbols.more_vert,
              iconSize: 23,
              color: context.tk.text,
              onTap: onMore,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelMessageRow extends StatelessWidget {
  const _ChannelMessageRow({
    required this.name,
    required this.time,
    required this.body,
    required this.avatarSeed,
  });

  final String name;
  final String time;
  final String body;
  final String avatarSeed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalAvatar(
          seed: avatarSeed,
          size: 40,
          shape: AvatarShape.squircle,
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: AppTheme.sans(
                    size: 16,
                    weight: FontWeight.w600,
                    color: context.tk.text,
                  ).copyWith(height: 18 / 16),
                ),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: AppTheme.sans(size: 12, color: context.tk.textMute),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 42,
              constraints: const BoxConstraints(minWidth: 174),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.tk.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                body,
                style: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: context.tk.text,
                ).copyWith(height: 23 / 15),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConversationWriteBar extends StatelessWidget {
  const _ConversationWriteBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.tk.bg.withValues(alpha: 0),
            context.tk.bg.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _WriteCircleButton(icon: Symbols.keyboard_alt),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 40,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: context.tk.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _channelShadowColor(context),
                    blurRadius: 37,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Text(
                '按住 说话',
                style: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: context.tk.text,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const _WriteCircleButton(icon: Symbols.mood),
          const SizedBox(width: 8),
          const _WriteCircleButton(icon: Symbols.add),
        ],
      ),
    );
  }
}

class _WriteCircleButton extends StatelessWidget {
  const _WriteCircleButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: context.tk.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _channelShadowColor(context),
            blurRadius: 37,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Icon(icon, size: 24, color: context.tk.text),
    );
  }
}

Color _channelShadowColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.34)
      : Colors.black.withValues(alpha: 0.12);
}

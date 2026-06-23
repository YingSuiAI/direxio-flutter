import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_message_cards.dart';
import 'group_invite_content.dart';

const groupInviteCardMaxWidthFactor = chatMessageCardMaxWidthFactor;

class GroupInviteCard extends StatelessWidget {
  const GroupInviteCard({
    super.key,
    required this.invite,
    required this.joining,
    required this.onJoin,
    this.inviterDisplayName = '',
    this.alreadyJoined = false,
  });

  final GroupInviteContent invite;
  final bool joining;
  final VoidCallback onJoin;
  final String inviterDisplayName;
  final bool alreadyJoined;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final inviter = inviterDisplayName.trim().isNotEmpty
        ? inviterDisplayName.trim()
        : invite.inviterDisplayName.isEmpty
            ? invite.inviterMxid
            : invite.inviterDisplayName;
    final fallbackInviter = l10n?.groupInviteFallbackInviter ?? '对方';
    final displayInviter = inviter.trim().isEmpty ? fallbackInviter : inviter;
    final alreadyJoinedMessage = l10n?.groupInviteAlreadyJoined ?? '已在群里中';
    final titleColor = t.text;
    final bodyColor = t.textMute;
    final buttonColor = t.accent;
    final buttonTextColor = t.onAccent;
    final joinDisabled = joining || alreadyJoined;
    return ChatCardBubbleFrame(
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.groupInviteTitle ?? '邀请加入群聊',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(
                          size: 16,
                          weight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        joining
                            ? l10n?.groupInviteJoining(invite.groupName) ??
                                '正在加入“${invite.groupName}”'
                            : l10n?.groupInviteBody(
                                  displayInviter,
                                  invite.groupName,
                                ) ??
                                '$displayInviter 邀请你加入“${invite.groupName}”',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(
                          size: 13,
                          color: bodyColor,
                        ).copyWith(height: 1.22),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ChatGroupAvatarTile(seed: invite.groupName, size: 46),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: Material(
              color: joinDisabled
                  ? buttonColor.withValues(alpha: 0.48)
                  : buttonColor,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: joining
                    ? null
                    : alreadyJoined
                        ? null
                        : onJoin,
                borderRadius: BorderRadius.circular(8),
                child: Center(
                  child: Text(
                    joining
                        ? l10n?.groupInviteJoiningButton ?? '加入中…'
                        : alreadyJoined
                            ? alreadyJoinedMessage
                            : l10n?.groupInviteJoinButton ?? '加入群聊',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: buttonTextColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

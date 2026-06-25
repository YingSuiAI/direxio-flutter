import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../providers/personal_space_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/avatar_url.dart';
import '../widgets/center_toast.dart';
import '../widgets/portal_avatar.dart';

const _homeBg = Color(0xFFFAFAFA);
const _homeText = Color(0xFF262628);
const _homeMuted = Color(0xFFA3A3A4);
const _feedbackBackgroundAsset = 'assets/images/fankui.png';
const _feedbackEmail = 'liyananinsh@outlook.com';

class MePage extends ConsumerWidget {
  const MePage({super.key, required this.client});

  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final userId = client.userID ?? '';
    final displayId = userId.isEmpty ? '@me:portal.agent-p2p.io' : userId;
    final localpart = _localpartFromMxid(displayId);
    final profileName = profile?.displayName?.trim();
    final personalProfile = ref.watch(personalProfileProvider);
    final draftName = personalProfile.displayName?.trim();
    final displayName = draftName?.isNotEmpty == true
        ? draftName!
        : profileName?.isNotEmpty == true
            ? profileName!
            : localpart;
    final avatarUrl = profileAvatarHttpUrl(profile, client) ?? '';
    final uidUrl = _meUidUrl(client, displayId);
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );

    return ColoredBox(
      color: _homeBgColor(context),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
          children: [
            _MeTopBar(
              title: l10n?.tabMe ?? '我的',
              onSettingsTap: () => context.push('/settings'),
            ),
            const SizedBox(height: 12),
            _MeProfileTile(
              displayId: displayId,
              displayName: displayName,
              uid: uidUrl,
              avatarUrl: avatarUrl,
              onAvatarTap: () => context.push('/me/profile'),
              onProfileTap: () => context.push('/me/profile'),
              onUidTap: () => _copyUidUrl(context, uidUrl),
              onQrTap: () => context.push('/me/qr'),
            ),
            const SizedBox(height: 34),
            _MeActionRow(
              icon: Symbols.person_add,
              label: l10n?.channelManageMyChannels ?? '我的频道',
              onTap: () => context.push('/me/channels'),
            ),
            const SizedBox(height: 16),
            _MeActionRow(
              icon: Symbols.bookmark,
              label: l10n?.meFavoritesTitle ?? '收藏',
              onTap: () => context.push('/me/favorites'),
            ),
            const SizedBox(height: 16),
            _MeActionRow(
              icon: Symbols.favorite,
              label: l10n?.meLikesTitle ?? '赞',
              onTap: () => context.push('/me/likes'),
            ),
            const SizedBox(height: 16),
            _MeActionRow(
              icon: Symbols.error,
              label: l10n?.meCommentsTitle ?? '评论',
              onTap: () => context.push('/me/comments'),
            ),
            const SizedBox(height: 16),
            _MeActionRow(
              icon: Symbols.help,
              label: l10n?.meHelpFeedbackTitle ?? '帮助与反馈',
              onTap: () => _showHelpFeedback(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeTopBar extends StatelessWidget {
  const _MeTopBar({required this.title, required this.onSettingsTap});

  final String title;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 20,
                weight: FontWeight.w600,
                color: _homeTextColor(context),
              ),
            ),
          ),
          _MeIconButton(icon: Symbols.settings, onTap: onSettingsTap),
        ],
      ),
    );
  }
}

class _MeProfileTile extends StatelessWidget {
  const _MeProfileTile({
    required this.displayId,
    required this.displayName,
    required this.uid,
    required this.avatarUrl,
    required this.onAvatarTap,
    required this.onProfileTap,
    required this.onUidTap,
    required this.onQrTap,
  });

  final String displayId;
  final String displayName;
  final String uid;
  final String avatarUrl;
  final VoidCallback onAvatarTap;
  final VoidCallback onProfileTap;
  final VoidCallback onUidTap;
  final VoidCallback onQrTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('me_profile_avatar'),
            onTap: onAvatarTap,
            child: PortalAvatar(
              seed: displayId,
              size: 60,
              imageUrl: avatarUrl.isEmpty ? null : avatarUrl,
              shape: AvatarShape.squircle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: onProfileTap,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 20,
                        weight: FontWeight.w600,
                        color: _homeTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: onUidTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              uid,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(
                                size: 13,
                                color: _homeMutedColor(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Symbols.content_copy,
                            size: 14,
                            color: _homeMutedColor(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _MeIconButton(icon: Symbols.qr_code_2, onTap: onQrTap),
        ],
      ),
    );
  }
}

class _MeActionRow extends StatelessWidget {
  const _MeActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _homeSurfaceColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 24, color: _homeTextColor(context)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.sans(
                    size: 16,
                    weight: FontWeight.w500,
                    color: _homeTextColor(context),
                  ),
                ),
              ),
              Icon(
                Symbols.chevron_right,
                size: 22,
                color: _homeMutedColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeIconButton extends StatelessWidget {
  const _MeIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 40,
          child: Center(
            child: Icon(icon, size: 24, color: _homeTextColor(context)),
          ),
        ),
      ),
    );
  }
}

String _meUidUrl(Client client, String displayId) {
  final domain = _serverNameFromMxid(displayId) ?? _clientServerName(client);
  final normalized = domain.trim().replaceFirst(RegExp(r'^https?://'), '');
  if (normalized.isEmpty) return displayId;
  return 'https://$normalized';
}

Future<void> _copyUidUrl(BuildContext context, String uidUrl) async {
  await Clipboard.setData(ClipboardData(text: uidUrl));
  if (!context.mounted) return;
  final l10n = Localizations.of<AppLocalizations>(
    context,
    AppLocalizations,
  );
  showCenterToast(context, l10n?.meUidCopied ?? '已复制 UID');
}

Future<void> _showHelpFeedback(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      return _HelpFeedbackDialog(
        headline: l10n?.meHelpFeedbackHeadline ?? '一起打造更好的\nDirexio',
        prompt: l10n?.meHelpFeedbackPrompt ?? '发现问题或有好想法？',
        contactLine: l10n?.meHelpFeedbackContactLine(_feedbackEmail) ??
            '联系我们：$_feedbackEmail',
        note: l10n?.meHelpFeedbackNote ?? '我们会持续根据你的反馈优化产品。',
        okLabel: l10n?.meHelpFeedbackOk ?? '知道了',
      );
    },
  );
}

class _HelpFeedbackDialog extends StatelessWidget {
  const _HelpFeedbackDialog({
    required this.headline,
    required this.prompt,
    required this.contactLine,
    required this.note,
    required this.okLabel,
  });

  final String headline;
  final String prompt;
  final String contactLine;
  final String note;
  final String okLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: AspectRatio(
          aspectRatio: 1052 / 1161,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Image.asset(
                  _feedbackBackgroundAsset,
                  key: const ValueKey('help_feedback_background'),
                  fit: BoxFit.contain,
                  color: isDark ? t.surface : null,
                  colorBlendMode: isDark ? BlendMode.modulate : null,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: t.surface.withValues(alpha: 0.55),
                  shape: CircleBorder(
                    side: BorderSide(color: t.surface.withValues(alpha: 0.85)),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: SizedBox.square(
                      dimension: 28,
                      child: Icon(
                        Symbols.close,
                        size: 22,
                        color: t.textMute,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(46, 76, 44, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headline,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.sans(
                                  size: 26,
                                  weight: FontWeight.w800,
                                  color: t.text,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                prompt,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.sans(size: 15, color: t.text),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                contactLine,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.sans(size: 15, color: t.text),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                note,
                                style: AppTheme.sans(size: 15, color: t.text),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: SizedBox(
                          width: 148,
                          height: 45,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: FilledButton.styleFrom(
                              backgroundColor: t.accent,
                              foregroundColor: t.onAccent,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              okLabel,
                              style: AppTheme.sans(
                                size: 15,
                                weight: FontWeight.w700,
                                color: t.onAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _localpartFromMxid(String mxid) {
  final trimmed = mxid.trim();
  final colon = trimmed.indexOf(':');
  final body = colon > 0 ? trimmed.substring(0, colon) : trimmed;
  return body.startsWith('@') ? body.substring(1) : body;
}

String? _serverNameFromMxid(String mxid) {
  final index = mxid.indexOf(':');
  if (index < 0 || index == mxid.length - 1) return null;
  return mxid.substring(index + 1);
}

String _clientServerName(Client client) {
  final userId = client.userID ?? '';
  final fromMxid = _serverNameFromMxid(userId);
  if (fromMxid != null && fromMxid.isNotEmpty) return fromMxid;
  final homeserver = client.homeserver;
  if (homeserver != null && homeserver.host.isNotEmpty) return homeserver.host;
  return 'p2p-im.com';
}

Color _homeBgColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.bg
      : _homeBg;
}

Color _homeTextColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.text
      : _homeText;
}

Color _homeMutedColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.textMute
      : _homeMuted;
}

Color _homeSurfaceColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.surface
      : Colors.white;
}

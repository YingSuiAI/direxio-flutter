import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../providers/personal_space_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/avatar_url.dart';
import '../widgets/portal_avatar.dart';

const _homeBg = Color(0xFFFAFAFA);
const _homeText = Color(0xFF262628);
const _homeMuted = Color(0xFFA3A3A4);

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

    return ColoredBox(
      color: _homeBgColor(context),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
          children: [
            _MeTopBar(onSettingsTap: () => context.push('/settings')),
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
              label: '我的频道',
              onTap: () => context.push('/me/channels'),
            ),
            const SizedBox(height: 16),
            _MeActionRow(
              icon: Symbols.bookmark,
              label: '收藏',
              onTap: () => context.push('/me/favorites'),
            ),
            const SizedBox(height: 16),
            _MeActionRow(
              icon: Symbols.favorite,
              label: '赞',
              onTap: () => context.push('/me/likes'),
            ),
            const SizedBox(height: 16),
            _MeActionRow(
              icon: Symbols.error,
              label: '评论',
              onTap: () => context.push('/me/comments'),
            ),
            const SizedBox(height: 16),
            _MeActionRow(
              icon: Symbols.help,
              label: '帮助与反馈',
              onTap: () => _showHelpFeedback(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeTopBar extends StatelessWidget {
  const _MeTopBar({required this.onSettingsTap});

  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '我的',
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
                Icons.chevron_right,
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
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('已复制 UID')),
  );
}

Future<void> _showHelpFeedback(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('帮助与反馈'),
      content: const Text(
          '官方邮箱：support@direxio.ai\n\n温馨提示：请在反馈中描述问题发生的页面、操作步骤和设备型号。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../mock/mock_data.dart';
import '../providers/as_sync_cache_provider.dart';
import '../utils/contact_identity_label.dart';
import '../widgets/portal_avatar.dart';

class AddContactDetailPage extends ConsumerStatefulWidget {
  const AddContactDetailPage({
    super.key,
    required this.userId,
    this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String? displayName;
  final String? avatarUrl;

  @override
  ConsumerState<AddContactDetailPage> createState() =>
      _AddContactDetailPageState();
}

class _AddContactDetailPageState extends ConsumerState<AddContactDetailPage> {
  bool _muted = false;
  bool _blocked = false;

  void _openVerification() {
    final query = widget.displayName == null || widget.displayName!.isEmpty
        ? ''
        : '?name=${Uri.encodeQueryComponent(widget.displayName!)}';
    context.push(
      '/add-contact/verify/${Uri.encodeComponent(widget.userId)}$query',
    );
  }

  void _openAcceptedChat(String roomId) {
    final trimmed = roomId.trim();
    if (trimmed.isEmpty) {
      _toast(context, '打开聊天失败: 缺少会话信息');
      return;
    }
    context.go('/chat/${Uri.encodeComponent(trimmed)}');
  }

  @override
  Widget build(BuildContext context) {
    final acceptedContact =
        ref.watch(asSyncCacheProvider).acceptedContactForUserId(widget.userId);
    final isAcceptedContact = acceptedContact != null;
    final profile = _profileForAddContact(
      widget.userId,
      acceptedContact?.displayName ?? widget.displayName,
      avatarUrl: acceptedContact?.avatarUrl ?? widget.avatarUrl,
    );
    final t = context.tk;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: t.surfaceHover,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.paddingOf(context).top + 4,
                  16,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _DetailGlassBackButton(onTap: () => context.pop()),
                    ),
                    const SizedBox(height: 16),
                    _ProfileHeader(profile: profile),
                    const SizedBox(height: 24),
                    _DetailActionRow(
                      onMessage: isAcceptedContact
                          ? () => _openAcceptedChat(acceptedContact.roomId)
                          : _openVerification,
                      onVoice: () =>
                          _toast(context, l10n.addContactVoiceAfterAdding),
                      onVideo: () =>
                          _toast(context, l10n.addContactVideoAfterAdding),
                    ),
                    const SizedBox(height: 24),
                    _DetailSwitchRow(
                      label: l10n.contactMuteMessages,
                      value: _muted,
                      onChanged: (value) => setState(() => _muted = value),
                    ),
                    const SizedBox(height: 16),
                    _DetailSwitchRow(
                      label: l10n.contactBlockUser,
                      value: _blocked,
                      onChanged: (value) => setState(() => _blocked = value),
                    ),
                    const SizedBox(height: 16),
                    _DetailNavigationRow(
                      label: l10n.contactReportUser,
                      onTap: () => _toast(context, l10n.contactReportTodo),
                    ),
                  ],
                ),
              ),
            ),
            _ApplyFriendButton(
              label: !isAcceptedContact
                  ? l10n.contactApplyFriend
                  : l10n.contactSendMessage,
              onTap: !isAcceptedContact
                  ? _openVerification
                  : () => _openAcceptedChat(acceptedContact.roomId),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddContactProfile {
  const _AddContactProfile({
    required this.name,
    required this.uid,
    required this.domain,
    this.avatarUrl,
  });

  final String name;
  final String uid;
  final String domain;
  final String? avatarUrl;
}

_AddContactProfile _profileForAddContact(
  String userId,
  String? displayName, {
  String? avatarUrl,
}) {
  final home = MockData.contactHomeByMxid(userId);
  final domain = userId.contains(':') ? userId.split(':').last : '';
  final name = contactDisplayNameFromIdentity(
    mxid: userId,
    displayName: displayName ?? home?.displayName ?? '',
    domain: home?.domain ?? domain,
    fallback: displayName ?? userId,
  );
  return _AddContactProfile(
    name: name,
    uid: _uidFromUserId(userId),
    domain: home?.domain ?? domain,
    avatarUrl: avatarUrl?.trim().isNotEmpty == true
        ? avatarUrl!.trim()
        : home?.avatarUrl,
  );
}

String _uidFromUserId(String userId) {
  final digits =
      RegExp(r'\d+').allMatches(userId).map((match) => match.group(0)!).join();
  if (digits.length >= 6) return digits;
  final localpart = userId.startsWith('@') && userId.contains(':')
      ? userId.substring(1, userId.indexOf(':'))
      : userId;
  final hash = userId.codeUnits.fold<int>(0, (value, unit) => value + unit);
  return '${localpart.hashCode.abs()}$hash'
      .replaceAll('-', '')
      .padRight(10, '0')
      .substring(0, 10);
}

class _DetailGlassBackButton extends StatelessWidget {
  const _DetailGlassBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return DecoratedBox(
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
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(Symbols.arrow_back, size: 24, color: t.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final _AddContactProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      children: [
        PortalAvatar(
          seed: profile.uid,
          imageUrl: profile.avatarUrl,
          size: 60,
          shape: AvatarShape.squircle,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(
                  size: 16,
                  weight: FontWeight.w600,
                  color: t.text,
                ).copyWith(letterSpacing: -0.4),
              ),
              const SizedBox(height: 8),
              Text(
                'UID ${profile.uid}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(size: 14, color: t.textMute),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailActionRow extends StatelessWidget {
  const _DetailActionRow({
    required this.onMessage,
    required this.onVoice,
    required this.onVideo,
  });

  final VoidCallback onMessage;
  final VoidCallback onVoice;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DetailActionButton(
            icon: Symbols.chat_bubble,
            label: AppLocalizations.of(context).contactSendMessage,
            onTap: onMessage,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _DetailActionButton(
            icon: Symbols.call,
            label: AppLocalizations.of(context).contactVoiceCall,
            onTap: onVoice,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _DetailActionButton(
            icon: Symbols.videocam,
            label: AppLocalizations.of(context).contactVideoCall,
            onTap: onVideo,
          ),
        ),
      ],
    );
  }
}

class _DetailActionButton extends StatelessWidget {
  const _DetailActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: t.accent, fill: 1),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  color: t.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSwitchRow extends StatelessWidget {
  const _DetailSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 12, right: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTheme.sans(
                size: 14,
                weight: FontWeight.w500,
                color: t.text,
              ).copyWith(letterSpacing: -0.4),
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: t.surface,
              activeTrackColor: t.accent,
              inactiveThumbColor: t.surface,
              inactiveTrackColor: t.surfaceHigh,
              trackOutlineColor: WidgetStateProperty.all(
                t.surface.withValues(alpha: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailNavigationRow extends StatelessWidget {
  const _DetailNavigationRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTheme.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: t.text,
                    ).copyWith(letterSpacing: -0.4),
                  ),
                ),
                Icon(Symbols.chevron_right, size: 24, color: t.text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplyFriendButton extends StatelessWidget {
  const _ApplyFriendButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SizedBox(
          height: 44,
          width: double.infinity,
          child: FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: t.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              label,
              style: AppTheme.sans(
                size: 14,
                weight: FontWeight.w500,
                color: t.onAccent,
              ).copyWith(letterSpacing: -0.4),
            ),
          ),
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

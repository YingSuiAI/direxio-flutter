import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../channel/channel_confirm_dialog.dart';
import '../channel/channel_inbox_data.dart';
import '../channel/channel_leave_flow.dart';
import '../providers/as_sync_cache_provider.dart';
import '../widgets/center_toast.dart';

enum ChannelManagementSection {
  overview,
  profile,
  members,
  moderation;

  static ChannelManagementSection fromName(String? value) {
    return switch (value) {
      'profile' => profile,
      'members' => members,
      'moderation' => moderation,
      _ => overview,
    };
  }
}

class ChannelManagementPage extends ConsumerStatefulWidget {
  const ChannelManagementPage({
    super.key,
    this.initialSection = ChannelManagementSection.overview,
    this.channelId,
  });

  final ChannelManagementSection initialSection;
  final String? channelId;

  @override
  ConsumerState<ChannelManagementPage> createState() =>
      _ChannelManagementPageState();
}

class _ChannelManagementPageState extends ConsumerState<ChannelManagementPage> {
  late ChannelManagementSection _section = widget.initialSection;
  late String? _selectedChannelId = widget.channelId;

  @override
  void didUpdateWidget(covariant ChannelManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      _section = widget.initialSection;
    }
    if (oldWidget.channelId != widget.channelId) {
      _selectedChannelId = widget.channelId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final channels = _managementChannels(ref);
    final selected = _selectedChannel(channels, _selectedChannelId);
    if (_selectedChannelId == null && selected != null) {
      _selectedChannelId = selected.id;
    }
    final t = context.tk;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ChannelManageTopBar(
              title: _section.title(l10n),
              subtitle: selected?.name ?? '',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: selected == null
                  ? const _ChannelManageEmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                      children: [
                        _SectionTabs(
                          selected: _section,
                          onChanged: (section) =>
                              setState(() => _section = section),
                        ),
                        const SizedBox(height: 18),
                        switch (_section) {
                          ChannelManagementSection.overview => _OverviewSection(
                              channels: channels,
                              selectedId: selected.id,
                              onSelect: (channel) => setState(
                                () => _selectedChannelId = channel.id,
                              ),
                              onOpenProfile: (channel) => setState(() {
                                _selectedChannelId = channel.id;
                                _section = ChannelManagementSection.profile;
                              }),
                            ),
                          ChannelManagementSection.profile => _ProfileSection(
                              channel: selected,
                              onDissolve: () => _confirmDissolveChannel(
                                context,
                                ref,
                                selected.id,
                              ),
                            ),
                          ChannelManagementSection.members => _MembersSection(
                              channel: selected,
                            ),
                          ChannelManagementSection.moderation =>
                            _ModerationSection(
                              channel: selected,
                            ),
                        },
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on ChannelManagementSection {
  String title(AppLocalizations l10n) {
    return switch (this) {
      ChannelManagementSection.overview => l10n.channelManageTitle,
      ChannelManagementSection.profile => l10n.channelManageProfileTitle,
      ChannelManagementSection.members => l10n.channelManageMembersTitle,
      ChannelManagementSection.moderation => l10n.channelManageModerationTitle,
    };
  }

  String label(AppLocalizations l10n) {
    return switch (this) {
      ChannelManagementSection.overview => l10n.channelManageTabOverview,
      ChannelManagementSection.profile => l10n.channelManageTabProfile,
      ChannelManagementSection.members => l10n.channelManageTabMembers,
      ChannelManagementSection.moderation => l10n.channelManageTabModeration,
    };
  }
}

class _ManageChannel {
  const _ManageChannel({
    required this.id,
    required this.name,
    required this.domain,
    required this.description,
    required this.memberCount,
    required this.pendingCount,
    required this.color,
    required this.isOwned,
    required this.visibility,
    required this.speechPolicy,
    required this.invitePolicy,
    required this.encrypted,
  });

  final String id;
  final String name;
  final String domain;
  final String description;
  final int memberCount;
  final int pendingCount;
  final Color color;
  final bool isOwned;
  final String visibility;
  final String speechPolicy;
  final String invitePolicy;
  final bool encrypted;
}

List<_ManageChannel> _managementChannels(WidgetRef ref) {
  final bootstrap = ref.watch(asSyncCacheProvider).bootstrap;
  final real = bootstrap == null
      ? const <ChannelInboxItem>[]
      : ChannelInboxData.fromBootstrap(
          bootstrap,
          fallbackDomain: 'p2p-im.com',
        ).where((channel) => channel.isOwned).toList();
  if (real.isNotEmpty) {
    return [
      for (final channel in real)
        _ManageChannel(
          id: channel.id,
          name: channel.name,
          domain: channel.domain.isEmpty ? 'p2p-im.com' : channel.domain,
          description: channel.description.isEmpty
              ? channel.latestPreview
              : channel.description,
          memberCount: channel.memberCount,
          pendingCount: channel.pendingJoinCount,
          color: PortalTokens.brandPrimary,
          isOwned: true,
          visibility: channel.visibility == 'private' ? 'private' : 'public',
          speechPolicy:
              channel.joinPolicy == 'approval' ? 'owner_review' : 'members',
          invitePolicy: channel.role.isEmpty ? 'owner' : channel.role,
          encrypted: true,
        ),
    ];
  }

  return const [];
}

_ManageChannel? _selectedChannel(
  List<_ManageChannel> channels,
  String? id,
) {
  for (final channel in channels) {
    if (channel.id == id) return channel;
  }
  if (channels.isNotEmpty) return channels.first;
  return null;
}

class _ChannelManageTopBar extends StatelessWidget {
  const _ChannelManageTopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _CircleButton(
                icon: Symbols.arrow_back,
                iconSize: 24,
                onTap: onBack,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 17,
                    weight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 12,
                    color: t.textMute,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelManageEmptyState extends StatelessWidget {
  const _ChannelManageEmptyState();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.campaign, size: 34, color: t.textMute),
            const SizedBox(height: 10),
            Text(
              l10n?.channelManageEmptyTitle ?? '还没有可管理的频道',
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n?.channelManageEmptySubtitle ?? '创建频道后，可以在这里管理资料、成员和规则。',
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 13, color: t.textMute)
                  .copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface.withValues(alpha: 0.86),
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: t.text.withValues(alpha: 0.10),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: iconSize, color: t.text),
        ),
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.selected, required this.onChanged});

  final ChannelManagementSection selected;
  final ValueChanged<ChannelManagementSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surfaceHover,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (final section in ChannelManagementSection.values)
            Expanded(
              child: _SectionTab(
                label: section.label(AppLocalizations.of(context)),
                selected: section == selected,
                onTap: () => onChanged(section),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: selected ? t.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(
              size: 12,
              weight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? t.text : t.textMute,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.channels,
    required this.selectedId,
    required this.onSelect,
    required this.onOpenProfile,
  });

  final List<_ManageChannel> channels;
  final String selectedId;
  final ValueChanged<_ManageChannel> onSelect;
  final ValueChanged<_ManageChannel> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tk;
    final totalMembers = channels.fold<int>(
      0,
      (value, channel) => value + channel.memberCount,
    );
    final pending = channels.fold<int>(
      0,
      (value, channel) => value + channel.pendingCount,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: l10n.channelManageStatSubscribers,
                value: _compactCount(totalMembers),
                color: t.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: l10n.channelManageStatPending,
                value: '$pending',
                color: t.accentCool,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: l10n.channelManageMyChannels,
                value: '${channels.length}',
                color: t.primaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          l10n.channelManageMyChannels,
          style: AppTheme.sans(
            size: 17,
            weight: FontWeight.w600,
            color: t.text,
          ),
        ),
        const SizedBox(height: 10),
        for (final channel in channels) ...[
          _ChannelManageCard(
            channel: channel,
            selected: channel.id == selectedId,
            onTap: () => onSelect(channel),
            onOpen: () => onOpenProfile(channel),
          ),
          const SizedBox(height: 12),
        ],
        _ActionRow(
          icon: Symbols.add_circle,
          label: l10n.channelManageCreateChannel,
          value: l10n.channelManageCreateChannelValue,
          color: t.accent,
          onTap: () => _showComingSoon(
            context,
            l10n.channelManageCreateChannel,
          ),
        ),
        const SizedBox(height: 12),
        _ActionRow(
          icon: Symbols.link,
          label: l10n.channelManageInviteLinks,
          value: l10n.channelManageDisabled,
          color: t.accentCool,
          onTap: () => _showComingSoon(context, l10n.channelManageInviteLinks),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.channel,
    required this.onDissolve,
  });

  final _ManageChannel channel;
  final VoidCallback onDissolve;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileHero(channel: channel),
        const SizedBox(height: 24),
        Text(
          l10n.channelManagePermissions,
          style: AppTheme.sans(
            size: 17,
            weight: FontWeight.w600,
            color: t.text,
          ),
        ),
        const SizedBox(height: 10),
        _ActionRow(
          icon: Symbols.public,
          label: l10n.channelManageVisibility,
          value: _visibilityLabel(l10n, channel.visibility),
          color: t.accent,
          onTap: () => _showComingSoon(context, l10n.channelManageVisibility),
        ),
        const SizedBox(height: 10),
        _ActionRow(
          icon: Symbols.rate_review,
          label: l10n.channelManageSpeechPermission,
          value: _speechPolicyLabel(l10n, channel.speechPolicy),
          color: const Color(0xFFF59E0B),
          onTap: () => _showComingSoon(
            context,
            l10n.channelManageSpeechPermission,
          ),
        ),
        const SizedBox(height: 10),
        _ActionRow(
          icon: Symbols.person_add,
          label: l10n.channelManageInvitePermission,
          value: _invitePolicyLabel(l10n, channel.invitePolicy),
          color: const Color(0xFF1FAF71),
          onTap: () => _showComingSoon(
            context,
            l10n.channelManageInvitePermission,
          ),
        ),
        const SizedBox(height: 10),
        _ActionRow(
          icon: Symbols.encrypted,
          label: l10n.channelManageMessageEncryption,
          value: channel.encrypted
              ? l10n.channelManageEnabled
              : l10n.channelManageDisabled,
          color: const Color(0xFF6F4CE6),
          onTap: () => _showComingSoon(
            context,
            l10n.channelManageMessageEncryption,
          ),
        ),
        const SizedBox(height: 26),
        _DangerRow(
          label: l10n.channelManageDisableChannel,
          onTap: onDissolve,
        ),
      ],
    );
  }
}

class _MembersSection extends StatelessWidget {
  const _MembersSection({required this.channel});

  final _ManageChannel channel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tk;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: l10n.channelManageStatOwner,
                value: '1',
                color: t.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: l10n.channelManageStatSubscribers,
                value: _compactCount(channel.memberCount),
                color: t.accentCool,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: l10n.channelManageStatPending,
                value: '${channel.pendingCount}',
                color: t.primaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ActionRow(
          icon: Symbols.person_add,
          label: l10n.channelManageInviteMembers,
          value: l10n.channelManageInviteMembersValue,
          color: t.accent,
          onTap: () =>
              _showComingSoon(context, l10n.channelManageInviteMembers),
        ),
        const SizedBox(height: 12),
        _EmptyPanel(
          icon: Symbols.groups,
          title: l10n.channelManageMembersEmptyTitle,
        ),
      ],
    );
  }
}

class _ModerationSection extends StatelessWidget {
  const _ModerationSection({required this.channel});

  final _ManageChannel channel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tk;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: l10n.channelManageStatPending,
                value: '${channel.pendingCount}',
                color: t.accentCool,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _EmptyPanel(
          icon: Symbols.fact_check,
          title: l10n.channelManageModerationEmptyTitle,
        ),
        const SizedBox(height: 18),
        _ActionRow(
          icon: Symbols.rule,
          label: l10n.channelManageAutoRules,
          value: l10n.channelManageDisabled,
          color: t.primaryContainer,
          onTap: () => _showComingSoon(context, l10n.channelManageAutoRules),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return _Surface(
      height: 76,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 20,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
            const Spacer(),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 12,
                color: t.textMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelManageCard extends StatelessWidget {
  const _ChannelManageCard({
    required this.channel,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  final _ManageChannel channel;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tk;
    return _Surface(
      onTap: onTap,
      borderColor: selected ? t.accent : t.border,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _ChannelGlyph(color: channel.color, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 16,
                      weight: FontWeight.w600,
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.channelManageChannelSummary(
                      _visibilityLabel(l10n, channel.visibility),
                      _compactCount(channel.memberCount),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 12,
                      color: t.textMute,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onOpen,
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? t.accent : t.surfaceHover,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  selected
                      ? l10n.channelManageManaging
                      : l10n.channelManageManage,
                  style: AppTheme.sans(
                    size: 12,
                    weight: FontWeight.w600,
                    color: selected ? t.onAccent : t.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.channel});

  final _ManageChannel channel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.tk;
    return _Surface(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            _ChannelGlyph(color: channel.color, size: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 18,
                      weight: FontWeight.w600,
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    channel.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 13,
                      color: t.textMute,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 32,
                    child: FilledButton(
                      onPressed: () => _showComingSoon(
                        context,
                        l10n.channelManageEditProfile,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: t.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(
                        l10n.channelManageEditProfile,
                        style: AppTheme.sans(
                          size: 13,
                          weight: FontWeight.w600,
                          color: t.onAccent,
                        ),
                      ),
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return _Surface(
      height: 56,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, size: 17, color: t.onAccent, fill: 1),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w500,
                  color: t.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppTheme.sans(
                  size: 13,
                  color: t.textMute,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Symbols.chevron_right,
              size: 20,
              color: t.textMute,
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return _Surface(
      height: 56,
      onTap: onTap,
      borderColor: t.danger.withValues(alpha: 0.28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Text(
              label,
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: t.danger,
              ),
            ),
            const Spacer(),
            Icon(
              Symbols.chevron_right,
              size: 20,
              color: t.danger,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 92,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: t.textMute),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTheme.sans(size: 13, color: t.textMute),
          ),
        ],
      ),
    );
  }
}

class _ChannelGlyph extends StatelessWidget {
  const _ChannelGlyph({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.31),
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.48,
          height: size * 0.48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GlyphBar(width: size * 0.30),
              SizedBox(height: size * 0.08),
              _GlyphBar(width: size * 0.48, opacity: 0.74),
              SizedBox(height: size * 0.08),
              _GlyphBar(width: size * 0.36, opacity: 0.50),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlyphBar extends StatelessWidget {
  const _GlyphBar({required this.width, this.opacity = 1});

  final double width;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.height,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final double? height;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final content = Container(
      height: height,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor ?? t.border),
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

String _visibilityLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'private' => l10n.channelManageVisibilityPrivate,
    _ => l10n.channelManageVisibilityPublic,
  };
}

String _speechPolicyLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'members' => l10n.channelManageSpeechMembers,
    _ => l10n.channelManageSpeechOwnerReview,
  };
}

String _invitePolicyLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'owner' => l10n.channelManageInviteOwner,
    _ => value,
  };
}

String _compactCount(int value) {
  if (value >= 10000) {
    final count = value / 10000;
    return '${count.toStringAsFixed(count >= 10 ? 0 : 1)}w';
  }
  if (value >= 1000) {
    final count = value / 1000;
    return '${count.toStringAsFixed(count >= 10 ? 0 : 1)}k';
  }
  return '$value';
}

void _showComingSoon(BuildContext context, String label) {
  final l10n = AppLocalizations.of(context);
  showTopSnackBar(
    context,
    SnackBar(content: Text(l10n.channelManageComingSoon(label))),
  );
}

Future<void> _confirmDissolveChannel(
  BuildContext context,
  WidgetRef ref,
  String channelId,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showChannelConfirmDialog(
    context,
    title: l10n.channelInfoDissolveConfirm,
  );
  if (!context.mounted || !confirmed) return;
  try {
    await dissolveChannelThroughAs(ref, channelId);
    if (!context.mounted) return;
    showTopSnackBar(
      context,
      SnackBar(content: Text(l10n.channelInfoDissolved)),
    );
    _returnToChannelTab(context);
  } catch (err) {
    if (!context.mounted) return;
    showTopSnackBar(
      context,
      SnackBar(content: Text(l10n.channelInfoDissolveFailed('$err'))),
    );
  }
}

void _returnToChannelTab(BuildContext context) {
  try {
    context.go('/home?tab=channels');
    return;
  } catch (_) {
    // Tests may mount this page without GoRouter.
  }
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../channel/channel_inbox_data.dart';
import '../mock/mock_channels.dart';
import '../providers/as_sync_cache_provider.dart';

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
    final channels = _managementChannels(ref);
    final selected = _selectedChannel(channels, _selectedChannelId);
    _selectedChannelId ??= selected.id;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ChannelManageTopBar(
              title: _section.title,
              subtitle: selected.name,
              onBack: () => context.pop(),
              onCreate: () => _showComingSoon(context, '创建频道'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  _SectionTabs(
                    selected: _section,
                    onChanged: (section) => setState(() => _section = section),
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
                      ),
                    ChannelManagementSection.members => _MembersSection(
                        channel: selected,
                      ),
                    ChannelManagementSection.moderation => _ModerationSection(
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
  String get title {
    return switch (this) {
      ChannelManagementSection.overview => '频道管理',
      ChannelManagementSection.profile => '频道资料',
      ChannelManagementSection.members => '成员与角色',
      ChannelManagementSection.moderation => '内容审核',
    };
  }

  String get label {
    return switch (this) {
      ChannelManagementSection.overview => '我的频道',
      ChannelManagementSection.profile => '资料权限',
      ChannelManagementSection.members => '成员角色',
      ChannelManagementSection.moderation => '内容审核',
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
    required this.todayMessages,
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
  final int todayMessages;
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
          todayMessages: channel.unreadCount + 24,
          pendingCount: channel.pendingJoinCount,
          color: const Color(0xFF3097CB),
          isOwned: true,
          visibility: channel.visibility == 'private' ? '私密' : '公开',
          speechPolicy: channel.joinPolicy == 'approval' ? '管理员审核' : '成员可发言',
          invitePolicy: channel.role.isEmpty ? '管理员' : channel.role,
          encrypted: true,
        ),
    ];
  }

  return [
    for (final channel in MockChannels.items.where((channel) => channel.isOwned))
      _ManageChannel(
        id: channel.id,
        name: channel.name,
        domain: channel.domain,
        description: channel.latestMessage,
        memberCount: channel.posts.fold<int>(
              1200,
              (value, post) => value + post.views.replaceAll('k', '00').length,
            ) +
            4600,
        todayMessages: 96 + channel.unreadCount,
        pendingCount: channel.unreadCount,
        color: channel.color,
        isOwned: channel.isOwned,
        visibility: '公开',
        speechPolicy: '管理员审核',
        invitePolicy: '管理员',
        encrypted: true,
      ),
  ];
}

_ManageChannel _selectedChannel(List<_ManageChannel> channels, String? id) {
  for (final channel in channels) {
    if (channel.id == id) return channel;
  }
  if (channels.isNotEmpty) return channels.first;
  return const _ManageChannel(
    id: 'p2p-im',
    name: 'P2P Matrix 公告',
    domain: 'p2p-im.com',
    description: '项目公告、节点状态与版本发布',
    memberCount: 5824,
    todayMessages: 96,
    pendingCount: 3,
    color: Color(0xFF3097CB),
    isOwned: true,
    visibility: '公开',
    speechPolicy: '管理员审核',
    invitePolicy: '管理员',
    encrypted: true,
  );
}

class _ChannelManageTopBar extends StatelessWidget {
  const _ChannelManageTopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onCreate,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
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
                icon: Symbols.arrow_back_ios_new,
                iconSize: 20,
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
                    color: const Color(0xFF222325),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 12,
                    color: const Color(0xFF747B85),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _CircleButton(
                icon: Symbols.add,
                iconSize: 24,
                color: const Color(0xFF3097CB),
                onTap: onCreate,
              ),
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
    this.color = const Color(0xFF222325),
  });

  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.86),
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: iconSize, color: color),
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
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (final section in ChannelManagementSection.values)
            Expanded(
              child: _SectionTab(
                label: section.label,
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
    return Material(
      color: selected ? Colors.white : Colors.transparent,
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
              color: selected
                  ? const Color(0xFF222325)
                  : const Color(0xFF747B85),
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
    final totalMembers = channels.fold<int>(
      0,
      (value, channel) => value + channel.memberCount,
    );
    final totalMessages = channels.fold<int>(
      0,
      (value, channel) => value + channel.todayMessages,
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
                label: '订阅人数',
                value: _compactCount(totalMembers),
                color: const Color(0xFF3097CB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: '今日消息',
                value: '$totalMessages',
                color: const Color(0xFF1FAF71),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: '待审核',
                value: '$pending',
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          '我的频道',
          style: AppTheme.sans(
            size: 17,
            weight: FontWeight.w600,
            color: const Color(0xFF222325),
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
          label: '创建新频道',
          value: '名称、头像、简介',
          color: const Color(0xFF3097CB),
          onTap: () => _showComingSoon(context, '创建新频道'),
        ),
        const SizedBox(height: 12),
        _ActionRow(
          icon: Symbols.link,
          label: '频道邀请链接',
          value: '3 个有效',
          color: const Color(0xFF1FAF71),
          onTap: () => _showComingSoon(context, '频道邀请链接'),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.channel});

  final _ManageChannel channel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileHero(channel: channel),
        const SizedBox(height: 24),
        Text(
          '频道权限',
          style: AppTheme.sans(
            size: 17,
            weight: FontWeight.w600,
            color: const Color(0xFF222325),
          ),
        ),
        const SizedBox(height: 10),
        _ActionRow(
          icon: Symbols.public,
          label: '频道可见性',
          value: channel.visibility,
          color: const Color(0xFF3097CB),
          onTap: () => _showComingSoon(context, '频道可见性'),
        ),
        const SizedBox(height: 10),
        _ActionRow(
          icon: Symbols.rate_review,
          label: '发言权限',
          value: channel.speechPolicy,
          color: const Color(0xFFF59E0B),
          onTap: () => _showComingSoon(context, '发言权限'),
        ),
        const SizedBox(height: 10),
        _ActionRow(
          icon: Symbols.person_add,
          label: '邀请权限',
          value: channel.invitePolicy,
          color: const Color(0xFF1FAF71),
          onTap: () => _showComingSoon(context, '邀请权限'),
        ),
        const SizedBox(height: 10),
        _ActionRow(
          icon: Symbols.encrypted,
          label: '消息加密',
          value: channel.encrypted ? '已开启' : '未开启',
          color: const Color(0xFF6F4CE6),
          onTap: () => _showComingSoon(context, '消息加密'),
        ),
        const SizedBox(height: 26),
        _DangerRow(onTap: () => _showComingSoon(context, '停用频道')),
      ],
    );
  }
}

class _MembersSection extends StatelessWidget {
  const _MembersSection({required this.channel});

  final _ManageChannel channel;

  @override
  Widget build(BuildContext context) {
    final members = [
      _Member('Niki', '所有者 · 在线', channel.color),
      const _Member('Alex Chen', '管理员 · 内容审核', Color(0xFF1FAF71)),
      const _Member('Mina', '管理员 · 成员运营', Color(0xFF6F4CE6)),
      const _Member('Bot Monitor', '机器人 · 风控', Color(0xFFF59E0B)),
    ];
    return Column(
      children: [
        const Row(
          children: [
            Expanded(
              child: _StatCard(
                label: '管理员',
                value: '12',
                color: Color(0xFF3097CB),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: '今日新增',
                value: '58',
                color: Color(0xFF1FAF71),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: '禁言中',
                value: '7',
                color: Color(0xFFEB3B3B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ActionRow(
          icon: Symbols.admin_panel_settings,
          label: '邀请管理员',
          value: '通过 ID 或链接',
          color: const Color(0xFF3097CB),
          onTap: () => _showComingSoon(context, '邀请管理员'),
        ),
        const SizedBox(height: 12),
        for (final member in members) ...[
          _MemberRow(member: member),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ModerationSection extends StatelessWidget {
  const _ModerationSection({required this.channel});

  final _ManageChannel channel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: '待审核',
                value: '${channel.pendingCount + 20}',
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: _StatCard(
                label: '举报',
                value: '5',
                color: Color(0xFFEB3B3B),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: _StatCard(
                label: '自动通过',
                value: '91%',
                color: Color(0xFF1FAF71),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _ReviewCard(
          title: '新成员发言申请',
          body: '用户 @ray 申请在公告频道发布节点同步说明。',
          tag: '发言',
          color: Color(0xFF3097CB),
        ),
        const SizedBox(height: 12),
        const _ReviewCard(
          title: '链接风险提示',
          body: '检测到外部链接，需要管理员确认后展示。',
          tag: '链接',
          color: Color(0xFFF59E0B),
        ),
        const SizedBox(height: 12),
        const _ReviewCard(
          title: '举报消息',
          body: '2 位成员举报该消息包含重复广告内容。',
          tag: '举报',
          color: Color(0xFFEB3B3B),
        ),
        const SizedBox(height: 18),
        _ActionRow(
          icon: Symbols.rule,
          label: '自动审核规则',
          value: '关键词 / 链接 / 频率',
          color: const Color(0xFF6F4CE6),
          onTap: () => _showComingSoon(context, '自动审核规则'),
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
                color: const Color(0xFF747B85),
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
    return _Surface(
      onTap: onTap,
      borderColor: selected ? const Color(0xFF3097CB) : const Color(0xFFE5E9EF),
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
                      color: const Color(0xFF222325),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${channel.visibility}频道 · ${_compactCount(channel.memberCount)} 人 · 今日 ${channel.todayMessages} 条',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 12,
                      color: const Color(0xFF747B85),
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
                  color: selected
                      ? const Color(0xFF3097CB)
                      : const Color(0xFFF1F6F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  selected ? '管理中' : '管理',
                  style: AppTheme.sans(
                    size: 12,
                    weight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF3097CB),
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
                      color: const Color(0xFF222325),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    channel.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 13,
                      color: const Color(0xFF747B85),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 32,
                    child: FilledButton(
                      onPressed: () => _showComingSoon(context, '编辑资料'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3097CB),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(
                        '编辑资料',
                        style: AppTheme.sans(
                          size: 13,
                          weight: FontWeight.w600,
                          color: Colors.white,
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
              child: Icon(icon, size: 17, color: Colors.white, fill: 1),
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
                  color: const Color(0xFF222325),
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
                  color: const Color(0xFF747B85),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Symbols.chevron_right,
              size: 20,
              color: Color(0xFF9AA2AD),
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      height: 56,
      onTap: onTap,
      borderColor: const Color(0xFFFFDCDC),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Text(
              '停用频道',
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: const Color(0xFFEB3B3B),
              ),
            ),
            const Spacer(),
            const Icon(
              Symbols.chevron_right,
              size: 20,
              color: Color(0xFFEB3B3B),
            ),
          ],
        ),
      ),
    );
  }
}

class _Member {
  const _Member(this.name, this.role, this.color);

  final String name;
  final String role;
  final Color color;
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final _Member member;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: member.color.withValues(alpha: 0.16),
              child: Text(
                member.name.characters.first,
                style: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w700,
                  color: member.color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 15,
                      weight: FontWeight.w600,
                      color: const Color(0xFF222325),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member.role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 12,
                      color: const Color(0xFF747B85),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '管理',
                style: AppTheme.sans(
                  size: 12,
                  weight: FontWeight.w600,
                  color: const Color(0xFF3097CB),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.body,
    required this.tag,
    required this.color,
  });

  final String title;
  final String body;
  final String tag;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 15,
                      weight: FontWeight.w600,
                      color: const Color(0xFF222325),
                    ),
                  ),
                ),
                _TagPill(text: tag, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(size: 13, color: const Color(0xFF747B85)),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ReviewButton(
                  label: '通过',
                  color: Color(0xFF1FAF71),
                  background: Color(0xFFE9F8F0),
                ),
                SizedBox(width: 10),
                _ReviewButton(
                  label: '拒绝',
                  color: Color(0xFFEB3B3B),
                  background: Color(0xFFFFF0F0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewButton extends StatelessWidget {
  const _ReviewButton({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        label,
        style: AppTheme.sans(
          size: 12,
          weight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: AppTheme.sans(
          size: 11,
          weight: FontWeight.w600,
          color: color,
        ),
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
    this.borderColor = const Color(0xFFE5E9EF),
  });

  final Widget child;
  final double? height;
  final VoidCallback? onTap;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label 功能待接入')),
  );
}

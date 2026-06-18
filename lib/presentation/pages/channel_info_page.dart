import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../channel/channel_confirm_dialog.dart';
import '../channel/channel_info_data.dart';
import '../channel/channel_leave_flow.dart';
import '../channel/channel_share.dart';
import '../providers/as_client_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/p2p_api_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/direct_contact_status.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/report_reason_dialog.dart';

class ChannelInfoPage extends ConsumerStatefulWidget {
  const ChannelInfoPage({super.key, required this.channelId});

  final String channelId;

  @override
  ConsumerState<ChannelInfoPage> createState() => _ChannelInfoPageState();
}

class _ChannelInfoPageState extends ConsumerState<ChannelInfoPage>
    with WidgetsBindingObserver {
  bool _muted = false;
  Future<List<AsChannelMember>>? _membersFuture;
  List<AsChannelMember> _members = const [];
  bool _removingMember = false;
  bool _muteChanging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant ChannelInfoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) {
      _resetMembers();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resetMembers();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _resetMembers() {
    if (!mounted) return;
    setState(() {
      _membersFuture = null;
      _members = const [];
    });
  }

  Future<List<AsChannelMember>> _ensureMembersFuture() {
    return _membersFuture ??= _loadMembers();
  }

  Future<List<AsChannelMember>> _loadMembers() async {
    final client = ref.read(matrixClientProvider);
    if (!client.isLogged()) return const [];
    try {
      final members = await ref.read(asClientProvider).getChannelMembers(
            widget.channelId,
            status: asChannelMemberStatusJoined,
          );
      final visibleMembers = _visibleChannelMembers(members, client);
      if (mounted) {
        setState(() => _members = visibleMembers);
      }
      return visibleMembers;
    } catch (_) {
      if (mounted) {
        setState(() => _members = const []);
      }
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = resolveChannelInfoData(ref, widget.channelId);
    final titleMemberCount = _channelTitleMemberCount(channel);
    return Scaffold(
      backgroundColor: context.tk.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              children: [
                _InfoTopBar(
                  title: '频道信息($titleMemberCount)',
                  onBack: () => context.pop(),
                ),
                if (channel.isOwned)
                  ..._ownerContent(context, channel)
                else
                  ..._memberContent(context, channel),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _memberContent(BuildContext context, ChannelInfoData channel) {
    final avatarUrl = avatarHttpUrl(
      ref.watch(matrixClientProvider),
      channel.avatarUrl,
    );
    return [
      const SizedBox(height: 24),
      Center(
        child: PortalAvatar(
          seed: channel.name,
          size: 86,
          imageUrl: avatarUrl,
          shape: AvatarShape.squircle,
        ),
      ),
      const SizedBox(height: 15),
      Center(
        child: Text(
          '#${channel.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.sans(
            size: 15,
            weight: FontWeight.w600,
            color: context.tk.textMute,
          ).copyWith(height: 33 / 15),
        ),
      ),
      const SizedBox(height: 26),
      _InfoActionRow(
        label: '频道详情',
        onTap: () => context.push(
          '/channel/${Uri.encodeComponent(channel.id)}/detail',
        ),
      ),
      const SizedBox(height: 14),
      _InfoActionRow(
        label: '分享频道',
        onTap: () => _shareChannel(context, ref, channel),
      ),
      const SizedBox(height: 14),
      _InfoActionRow(
        label: '举报频道',
        onTap: () => _showReportDialog(context, channel),
      ),
      const SizedBox(height: 26),
      _DangerCenterRow(
        label: '退出频道',
        onTap: () => _confirmLeaveChannel(context, ref, channel),
      ),
    ];
  }

  List<Widget> _ownerContent(BuildContext context, ChannelInfoData channel) {
    final displayMembers =
        _members.where(_isJoinedChannelMember).toList(growable: false);
    final visibleTotalCount =
        displayMembers.isEmpty ? channel.memberCount : displayMembers.length;
    final visibleMemberCount = displayMembers.isEmpty
        ? channel.memberCount.clamp(0, 12)
        : displayMembers.length.clamp(0, 12);
    return [
      const SizedBox(height: 24),
      FutureBuilder<List<AsChannelMember>>(
        future: _ensureMembersFuture(),
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState != ConnectionState.done &&
              displayMembers.isEmpty;
          return _OwnerMemberGrid(
            channel: channel,
            members: displayMembers.take(visibleMemberCount).toList(),
            placeholderCount: displayMembers.isEmpty ? visibleMemberCount : 0,
            isLoading: isLoading,
            onRemove: _showRemoveMemberSheet,
          );
        },
      ),
      if (visibleTotalCount > visibleMemberCount) ...[
        const SizedBox(height: 14),
        const _ExpandMembersHint(),
      ],
      const SizedBox(height: 21),
      _InfoActionRow(
        label: '频道详情',
        onTap: () => context.push(
          '/channel/${Uri.encodeComponent(channel.id)}/detail',
        ),
      ),
      const SizedBox(height: 14),
      _InfoActionRow(
        label: '分享频道',
        onTap: () => _shareChannel(context, ref, channel),
      ),
      const SizedBox(height: 14),
      _MuteRow(
        value: _muted,
        busy: _muteChanging,
        onChanged: (value) => _setChannelMuted(channel, value),
      ),
      const SizedBox(height: 26),
      _DangerCenterRow(
        label: '解散频道',
        onTap: () => _confirmDissolveChannel(context, ref, channel),
      ),
    ];
  }

  int _channelTitleMemberCount(ChannelInfoData channel) {
    final joinedMembers =
        _members.where(_isJoinedChannelMember).toList(growable: false);
    if (joinedMembers.isNotEmpty) return joinedMembers.length;
    return channel.memberCount < 0 ? 0 : channel.memberCount;
  }

  Future<void> _showRemoveMemberSheet() async {
    final members = _members.isEmpty
        ? await _ensureMembersFuture()
            .catchError((_) => const <AsChannelMember>[])
        : _members;
    if (!mounted) return;
    final client = ref.read(matrixClientProvider);
    final currentUserId = client.userID?.trim() ?? '';
    final candidates = members.where((member) {
      final userMxid = member.userMxid.trim();
      if (userMxid.isEmpty || userMxid == currentUserId) return false;
      if (_isAgentChannelMember(member, client)) return false;
      if (!_isJoinedChannelMember(member)) return false;
      return member.role != asChannelRoleOwner;
    }).toList(growable: false);
    if (candidates.isEmpty) {
      _showSnack(context, '暂无可移除成员');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.tk.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '移除频道成员',
                  style: AppTheme.sans(
                    size: 18,
                    weight: FontWeight.w600,
                    color: sheetContext.tk.text,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final member = candidates[index];
                      final name = _memberName(member);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: PortalAvatar(
                          seed: member.userMxid,
                          size: 38,
                          shape: AvatarShape.squircle,
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(
                            size: 15,
                            weight: FontWeight.w600,
                            color: context.tk.text,
                          ),
                        ),
                        subtitle: Text(
                          member.userMxid,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(
                            size: 12,
                            weight: FontWeight.w400,
                            color: context.tk.textMute,
                          ),
                        ),
                        trailing: _removingMember
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.tk.accent,
                                ),
                              )
                            : Icon(
                                Symbols.remove_circle,
                                color: context.tk.danger,
                              ),
                        onTap: _removingMember
                            ? null
                            : () async {
                                Navigator.of(sheetContext).pop();
                                await _confirmRemoveMember(member, name);
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmRemoveMember(
    AsChannelMember member,
    String name,
  ) async {
    final confirmed = await showChannelConfirmDialog(
      context,
      title: '确认移除$name',
    );
    if (!confirmed || !mounted) return;
    setState(() => _removingMember = true);
    try {
      await ref
          .read(asClientProvider)
          .removeChannelMember(widget.channelId, member.userMxid);
      if (!mounted) return;
      setState(() {
        _members = _members
            .where((item) => item.userMxid.trim() != member.userMxid.trim())
            .toList(growable: false);
        _membersFuture = Future.value(_members);
      });
      _showSnack(context, '已移除成员');
    } catch (err) {
      if (!mounted) return;
      _showSnack(context, '移除失败：$err');
    } finally {
      if (mounted) {
        setState(() => _removingMember = false);
      }
    }
  }

  Future<void> _setChannelMuted(
    ChannelInfoData channel,
    bool muted,
  ) async {
    if (_muteChanging) return;
    final previous = _muted;
    setState(() {
      _muted = muted;
      _muteChanging = true;
    });
    try {
      final asClient = ref.read(asClientProvider);
      if (muted) {
        await asClient.muteChannel(channel.id);
      } else {
        await asClient.unmuteChannel(channel.id);
      }
      if (!mounted) return;
      _showSnack(context, muted ? '已开启全员禁言' : '已解除全员禁言');
    } catch (err) {
      if (!mounted) return;
      setState(() => _muted = previous);
      _showSnack(context, muted ? '开启全员禁言失败：$err' : '解除全员禁言失败：$err');
    } finally {
      if (mounted) setState(() => _muteChanging = false);
    }
  }

  Future<void> _showReportDialog(
    BuildContext context,
    ChannelInfoData channel,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      barrierColor: context.tk.text.withValues(alpha: 0.7),
      builder: (_) => const ReportReasonDialog(),
    );
    if (reason == null || reason.trim().isEmpty || !context.mounted) return;

    final reporterDomain = reportDomainForUserId(
      ref.read(matrixClientProvider).userID ?? '',
      null,
    );
    final reportedDomain = reportDomainForUserId(
      channel.roomId,
      channel.domain,
    );
    try {
      await ref.read(p2pApiClientProvider).submitReport(
            reporterDomain: reporterDomain,
            reportedDomain: reportedDomain,
            targetType: 1,
            reason: reason.trim(),
          );
      if (!context.mounted) return;
      _showSnack(context, '举报已提交');
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, '举报提交失败: $error');
    }
  }
}

class _InfoTopBar extends StatelessWidget {
  const _InfoTopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            top: 4,
            child: GlassHeaderButton(
              icon: Symbols.arrow_back,
              iconSize: 22,
              color: context.tk.text,
              onTap: onBack,
            ),
          ),
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
    );
  }
}

class _InfoActionRow extends StatelessWidget {
  const _InfoActionRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tk.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 16,
                      weight: FontWeight.w500,
                      color: context.tk.text,
                    ).copyWith(height: 33 / 16),
                  ),
                ),
                Icon(
                  Symbols.chevron_right,
                  size: 24,
                  color: context.tk.text,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DangerCenterRow extends StatelessWidget {
  const _DangerCenterRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tk.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Center(
            child: Text(
              label,
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w500,
                color: context.tk.danger,
              ).copyWith(height: 33 / 16),
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerMemberGrid extends StatelessWidget {
  const _OwnerMemberGrid({
    required this.channel,
    required this.members,
    required this.placeholderCount,
    required this.isLoading,
    required this.onRemove,
  });

  final ChannelInfoData channel;
  final List<AsChannelMember> members;
  final int placeholderCount;
  final bool isLoading;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final member in members)
          PortalAvatar(
            key: ValueKey('channel_member_avatar_${member.userMxid}'),
            seed: _memberName(member),
            size: 40,
            shape: AvatarShape.squircle,
          ),
        for (var index = 0; index < placeholderCount; index++)
          PortalAvatar(
            seed: '${channel.id}-member-$index',
            size: 40,
            shape: AvatarShape.squircle,
          ),
        _RemoveMemberTile(
          isLoading: isLoading,
          onTap: onRemove,
        ),
      ],
    );
  }
}

class _RemoveMemberTile extends StatelessWidget {
  const _RemoveMemberTile({
    required this.isLoading,
    required this.onTap,
  });

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.tk.border,
            style: BorderStyle.solid,
          ),
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Symbols.remove,
                size: 20,
                color: context.tk.textMute,
              ),
      ),
    );
  }
}

class _ExpandMembersHint extends StatelessWidget {
  const _ExpandMembersHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '展开更多成员',
          style: AppTheme.sans(
            size: 13,
            weight: FontWeight.w500,
            color: context.tk.textMute,
          ).copyWith(height: 20 / 13),
        ),
        const SizedBox(width: 2),
        Icon(
          Symbols.keyboard_arrow_down,
          size: 12,
          color: context.tk.textMute,
        ),
      ],
    );
  }
}

bool _isJoinedChannelMember(AsChannelMember member) {
  final status = member.status.trim().toLowerCase();
  if (status == asChannelMemberStatusPending ||
      status == asChannelMemberStatusRejected) {
    return false;
  }
  if (status == asChannelMemberStatusJoined || status == 'join') return true;
  return status.isEmpty && member.joinedAtMs > 0;
}

List<AsChannelMember> _visibleChannelMembers(
  List<AsChannelMember> members,
  Client client,
) {
  return members
      .where((member) => !_isAgentChannelMember(member, client))
      .toList(growable: false);
}

bool _isAgentChannelMember(AsChannelMember member, Client client) {
  final userMxid = member.userMxid.trim();
  if (userMxid.isEmpty) return false;
  final agentMxid = portalAgentMxidForClient(client);
  if (agentMxid != null && userMxid == agentMxid) return true;
  return userMxid.toLowerCase().startsWith('@agent:');
}

String _memberName(AsChannelMember member) {
  final displayName = member.displayName.trim();
  if (displayName.isNotEmpty) return displayName;
  final userMxid = member.userMxid.trim();
  if (userMxid.startsWith('@')) {
    final colon = userMxid.indexOf(':');
    if (colon > 1) return userMxid.substring(1, colon);
  }
  return userMxid.isEmpty ? '频道成员' : userMxid;
}

class _MuteRow extends StatelessWidget {
  const _MuteRow({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tk.surface,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '全员禁言',
                  style: AppTheme.sans(
                    size: 16,
                    weight: FontWeight.w500,
                    color: context.tk.text,
                  ).copyWith(height: 33 / 16),
                ),
              ),
              busy
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.tk.accent,
                      ),
                    )
                  : _OwnerSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerSwitch extends StatelessWidget {
  const _OwnerSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: 47,
        height: 26,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 47,
              height: 26,
              decoration: BoxDecoration(
                color: value ? context.tk.accent : context.tk.surfaceHover,
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 160),
              left: value ? 23 : 1,
              top: 1,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: context.tk.onAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _shareChannel(
  BuildContext context,
  WidgetRef ref,
  ChannelInfoData channel,
) async {
  try {
    final sent = await showAndShareChannel(
      context,
      ref,
      payload: channelSharePayloadFromChannel(
        channelId: channel.id,
        roomId: channel.roomId,
        homeDomain: channel.domain,
        name: channel.name,
        description: channel.description,
        avatarUrl: channel.avatarUrl,
        visibility: channel.visibility,
        joinPolicy: channel.joinPolicy,
        commentsEnabled: channel.commentsEnabled,
        channelType: channel.channelType,
        tags: channel.tags,
      ),
      currentRoomId: channel.roomId,
      currentRoomName: channel.name,
    );
    if (!context.mounted || !sent) return;
    _showSnack(context, '已分享频道');
  } catch (err) {
    if (!context.mounted) return;
    _showSnack(context, '分享频道失败：$err');
  }
}

void _showSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _confirmLeaveChannel(
  BuildContext context,
  WidgetRef ref,
  ChannelInfoData channel,
) async {
  final confirmed = await showChannelConfirmDialog(
    context,
    title: '确定退出？',
  );
  if (!context.mounted || !confirmed) return;
  try {
    await leaveChannelThroughAs(ref, channel.id);
    if (!context.mounted) return;
    _showSnack(context, '已退出频道');
    _returnToChannelTab(context);
  } catch (err) {
    if (!context.mounted) return;
    _showSnack(context, '退出频道失败：$err');
  }
}

Future<void> _confirmDissolveChannel(
  BuildContext context,
  WidgetRef ref,
  ChannelInfoData channel,
) async {
  final confirmed = await showChannelConfirmDialog(
    context,
    title: '确定解散？',
  );
  if (!context.mounted || !confirmed) return;
  try {
    await leaveChannelThroughAs(ref, channel.id);
    if (!context.mounted) return;
    _showSnack(context, '已解散频道');
    _returnToChannelTab(context);
  } catch (err) {
    if (!context.mounted) return;
    _showSnack(context, '解散频道失败：$err');
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

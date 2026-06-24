import 'dart:async';

import 'package:flutter/foundation.dart';
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
import '../channel/channel_member_avatar.dart';
import '../channel/channel_share.dart';
import '../providers/as_client_provider.dart';
import '../providers/app_warmup_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/im_public_client_provider.dart';
import '../providers/user_profile_directory_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/direct_contact_status.dart';
import '../utils/user_profile_directory.dart';
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
  final Set<String> _preloadedMemberAvatarUrls = {};
  final Map<String, String> _memberProfileAvatarUrls = {};
  final Set<String> _resolvingMemberProfileAvatars = {};

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
      _memberProfileAvatarUrls.clear();
      _resolvingMemberProfileAvatars.clear();
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
      var visibleMembers = _visibleChannelMembers(members, client);
      if (visibleMembers.isEmpty) {
        visibleMembers = await _matrixRoomChannelMembers(client);
      }
      _debugLogMemberAvatarState(
        client: client,
        stage: 'loaded',
        members: visibleMembers,
        rawCount: members.length,
      );
      _preloadMemberAvatars(client, visibleMembers);
      unawaited(_resolveMissingMemberProfileAvatars(client, visibleMembers));
      if (mounted) {
        setState(() => _members = visibleMembers);
      }
      return visibleMembers;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[channel.member.avatar] load failed channel=${widget.channelId} '
          'error=$error',
        );
        debugPrint('$stackTrace');
      }
      if (mounted) {
        setState(() => _members = const []);
      }
      return const [];
    }
  }

  Future<List<AsChannelMember>> _matrixRoomChannelMembers(Client client) async {
    final roomId = _currentChannelRoomId();
    final room = roomId.trim().isEmpty ? null : client.getRoomById(roomId);
    if (room == null) {
      if (kDebugMode) {
        debugPrint(
          '[channel.member.avatar] matrix fallback skipped '
          'channel=${widget.channelId} room=$roomId reason=room_not_found',
        );
      }
      return const [];
    }
    final memoryMembers = _matrixUsersToChannelMembers(
      room.getParticipants(const [Membership.join]),
      room,
      client,
    );
    if (memoryMembers.isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[channel.member.avatar] matrix memory fallback '
          'channel=${widget.channelId} room=${room.id} '
          'count=${memoryMembers.length}',
        );
      }
      return memoryMembers;
    }
    try {
      final users = await room.requestParticipants(
        const [Membership.join],
        true,
        true,
      );
      final members = _matrixUsersToChannelMembers(users, room, client);
      if (kDebugMode) {
        debugPrint(
          '[channel.member.avatar] matrix fallback channel=${widget.channelId} '
          'room=${room.id} count=${members.length}',
        );
      }
      return members;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[channel.member.avatar] matrix fallback failed '
          'channel=${widget.channelId} room=${room.id} error=$error',
        );
      }
      return const [];
    }
  }

  List<AsChannelMember> _matrixUsersToChannelMembers(
    Iterable<User> users,
    Room room,
    Client client,
  ) {
    return users
        .map(
          (user) => AsChannelMember(
            channelId: widget.channelId,
            roomId: room.id,
            userMxid: user.id,
            displayName: user.displayName ?? '',
            avatarUrl: user.avatarUrl?.toString() ?? '',
            domain: _domainFromMxid(user.id),
            role: user.id == client.userID
                ? asChannelRoleOwner
                : asChannelRoleMember,
            status: asChannelMemberStatusJoined,
          ),
        )
        .where((member) => !_isAgentChannelMember(member, client))
        .toList(growable: false);
  }

  void _preloadMemberAvatars(
    Client client,
    Iterable<AsChannelMember> members,
  ) {
    final roomId = _currentChannelRoomId();
    final directory = ref.read(userProfileDirectoryProvider);
    for (final member in members) {
      final url = channelMemberAvatarUrl(
        client,
        member,
        roomId: roomId,
        directory: directory,
        fallbackAvatarUrl: _memberProfileAvatarUrls[member.userMxid] ?? '',
      );
      if (url == null || !_preloadedMemberAvatarUrls.add(url)) continue;
      unawaited(ref.read(avatarPreloaderProvider).preload(url));
    }
  }

  void _debugLogMemberAvatarState({
    required Client client,
    required String stage,
    required Iterable<AsChannelMember> members,
    int? rawCount,
  }) {
    if (!kDebugMode) return;
    final list = members.toList(growable: false);
    final roomId = _currentChannelRoomId();
    final directory = ref.read(userProfileDirectoryProvider);
    debugPrint(
      '[channel.member.avatar] stage=$stage channel=${widget.channelId} '
      'room=$roomId raw_count=${rawCount ?? list.length} '
      'visible_count=${list.length} client_user=${client.userID ?? '<empty>'}',
    );
    for (final member in list) {
      final mxid = member.userMxid.trim();
      String? roomAvatar;
      for (final id in <String>{roomId.trim(), member.roomId.trim()}) {
        if (id.isEmpty) continue;
        final room = client.getRoomById(id);
        if (room == null) continue;
        roomAvatar = matrixContentHttpUrl(
          client,
          room.unsafeGetUserFromMemoryOrFallback(mxid).avatarUrl,
        );
        if (roomAvatar != null) break;
      }
      final directoryAvatar = directory.avatarUrlFor(
        mxid,
        fallbackAvatarUrl: member.avatarUrl,
      );
      final profileFallback = _memberProfileAvatarUrls[mxid] ?? '';
      final resolved = channelMemberAvatarUrl(
        client,
        member,
        roomId: roomId,
        directory: directory,
        fallbackAvatarUrl: profileFallback,
      );
      debugPrint(
        '[channel.member.avatar] member user=${mxid.isEmpty ? '<empty>' : mxid} '
        'name=${member.displayName.trim().isEmpty ? '<empty>' : member.displayName.trim()} '
        'status=${member.status} role=${member.role} '
        'member_room=${member.roomId.trim().isEmpty ? '<empty>' : member.roomId.trim()} '
        'as_avatar=${member.avatarUrl.trim().isEmpty ? '<empty>' : member.avatarUrl.trim()} '
        'room_avatar=${roomAvatar ?? '<empty>'} '
        'directory_avatar=${directoryAvatar ?? '<empty>'} '
        'profile_fallback=${profileFallback.isEmpty ? '<empty>' : profileFallback} '
        'resolved=${resolved ?? '<empty>'}',
      );
    }
  }

  Future<void> _resolveMissingMemberProfileAvatars(
    Client client,
    Iterable<AsChannelMember> members,
  ) async {
    final roomId = _currentChannelRoomId();
    final directory = ref.read(userProfileDirectoryProvider);
    for (final member in members) {
      final mxid = member.userMxid.trim();
      if (mxid.isEmpty ||
          _memberProfileAvatarUrls.containsKey(mxid) ||
          !_resolvingMemberProfileAvatars.add(mxid)) {
        continue;
      }
      final existing = channelMemberAvatarUrl(
        client,
        member,
        roomId: roomId,
        directory: directory,
      );
      if (existing != null) {
        _resolvingMemberProfileAvatars.remove(mxid);
        continue;
      }
      try {
        final profile = await client.getProfileFromUserId(
          mxid,
          cache: true,
          getFromRooms: true,
        );
        final avatarUrl = profileAvatarHttpUrl(profile, client);
        if (kDebugMode) {
          debugPrint(
            '[channel.member.avatar] profile user=$mxid '
            'display=${profile.displayName ?? '<empty>'} '
            'avatar=${avatarUrl ?? '<empty>'}',
          );
        }
        if (avatarUrl == null || !mounted) continue;
        setState(() => _memberProfileAvatarUrls[mxid] = avatarUrl);
        _debugLogMemberAvatarState(
          client: client,
          stage: 'profile-resolved',
          members: members,
        );
        if (_preloadedMemberAvatarUrls.add(avatarUrl)) {
          unawaited(ref.read(avatarPreloaderProvider).preload(avatarUrl));
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            '[channel.member.avatar] profile failed user=$mxid error=$error',
          );
        }
        // Profile lookup is a best-effort fallback for old member records.
      } finally {
        _resolvingMemberProfileAvatars.remove(mxid);
      }
    }
  }

  String _currentChannelRoomId() {
    final target = widget.channelId.trim();
    final bootstrap = ref.read(asSyncCacheProvider).bootstrap;
    if (bootstrap != null) {
      for (final channel in bootstrap.channels) {
        final channelId = channel.channelId.trim();
        final roomId = channel.roomId.trim();
        if ((channelId.isNotEmpty && channelId == target) ||
            (roomId.isNotEmpty && roomId == target)) {
          return roomId.isEmpty ? target : roomId;
        }
      }
    }
    return target;
  }

  @override
  Widget build(BuildContext context) {
    final channel = resolveChannelInfoData(ref, widget.channelId);
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
                  title: '频道信息',
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
    return [
      const SizedBox(height: 24),
      _ChannelInfoHeader(
        channel: channel,
        avatarUrl: _channelAvatarUrl(channel),
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
    final visibleMemberCount = displayMembers.isEmpty
        ? channel.memberCount.clamp(0, 8)
        : displayMembers.length;
    return [
      const SizedBox(height: 24),
      FutureBuilder<List<AsChannelMember>>(
        future: _ensureMembersFuture(),
        builder: (context, snapshot) {
          final loadedMembers = snapshot.data
                  ?.where(_isJoinedChannelMember)
                  .toList(growable: false) ??
              displayMembers;
          final isLoading = snapshot.connectionState != ConnectionState.done &&
              loadedMembers.isEmpty;
          return _OwnerMemberGrid(
            channel: channel,
            channelRoomId: _currentChannelRoomId(),
            members: loadedMembers,
            profileAvatarUrls: _memberProfileAvatarUrls,
            placeholderCount: loadedMembers.isEmpty ? visibleMemberCount : 0,
            isLoading: isLoading,
            client: ref.read(matrixClientProvider),
            profileDirectory: ref.watch(userProfileDirectoryProvider),
            currentUserId: ref.read(matrixClientProvider).userID ?? '',
            onOpenMember: _openMemberHome,
            onRemove: _showRemoveMemberSheet,
          );
        },
      ),
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
        value: _displayedChannelMuted(channel),
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

  String? _channelAvatarUrl(ChannelInfoData channel) {
    return avatarHttpUrl(
      ref.watch(matrixClientProvider),
      channel.avatarUrl,
    );
  }

  bool _displayedChannelMuted(ChannelInfoData channel) {
    if (_muteChanging) return _muted;
    return channel.muted;
  }

  Future<void> _showRemoveMemberSheet() async {
    final members = _members.isEmpty
        ? await _ensureMembersFuture()
            .catchError((_) => const <AsChannelMember>[])
        : _members;
    if (!mounted) return;
    final client = ref.read(matrixClientProvider);
    final channelRoomId = _currentChannelRoomId();
    final directory = ref.read(userProfileDirectoryProvider);
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
                          imageUrl: channelMemberAvatarUrl(
                            client,
                            member,
                            roomId: channelRoomId,
                            directory: directory,
                          ),
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

  void _openMemberHome(AsChannelMember member) {
    final userMxid = member.userMxid.trim();
    if (userMxid.isEmpty) return;
    context.push('/contact-home/${Uri.encodeComponent(userMxid)}');
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
    final previous = _displayedChannelMuted(channel);
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
      _updateCachedChannelMuted(channel, muted: muted);
      _showSnack(context, muted ? '已开启全员禁言' : '已解除全员禁言');
    } catch (err) {
      if (!mounted) return;
      setState(() => _muted = previous);
      _showSnack(context, muted ? '开启全员禁言失败：$err' : '解除全员禁言失败：$err');
    } finally {
      if (mounted) setState(() => _muteChanging = false);
    }
  }

  void _updateCachedChannelMuted(
    ChannelInfoData channel, {
    required bool muted,
  }) {
    final channelId = channel.id.trim();
    final roomId = channel.roomId.trim();
    ref.read(asSyncCacheProvider.notifier).update((state) {
      final next = state.withChannelMuted(
        channelId.isNotEmpty ? channelId : roomId,
        muted: muted,
      );
      if (!identical(next, state) || roomId.isEmpty || roomId == channelId) {
        return next;
      }
      return next.withChannelMuted(
        roomId,
        muted: muted,
      );
    });
  }

  Future<void> _showReportDialog(
    BuildContext context,
    ChannelInfoData channel,
  ) async {
    final result = await showDialog<ReportReasonResult>(
      context: context,
      barrierColor: context.tk.text.withValues(alpha: 0.7),
      builder: (_) => const ReportReasonDialog(),
    );
    if (result == null || result.reason.trim().isEmpty || !context.mounted) {
      return;
    }

    final reporterDomain = reportDomainForUserId(
      ref.read(matrixClientProvider).userID ?? '',
      null,
    );
    final reportedDomain = channel.roomId.trim();
    if (reportedDomain.isEmpty) {
      _showSnack(context, '举报提交失败: 缺少频道房间ID');
      return;
    }
    try {
      await ref.read(imPublicClientProvider).submitReport(
            reporterDomain: reporterDomain,
            reportedDomain: reportedDomain,
            targetType: 3,
            reason: result.reason.trim(),
            files: result.toImPublicFiles(),
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

class _ChannelInfoHeader extends StatelessWidget {
  const _ChannelInfoHeader({
    required this.channel,
    required this.avatarUrl,
  });

  final ChannelInfoData channel;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
            channelDisplayNameWithMemberCount(channel),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(
              size: 15,
              weight: FontWeight.w600,
              color: context.tk.textMute,
            ).copyWith(height: 33 / 15),
          ),
        ),
      ],
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
    required this.channelRoomId,
    required this.members,
    required this.profileAvatarUrls,
    required this.placeholderCount,
    required this.isLoading,
    required this.client,
    required this.profileDirectory,
    required this.currentUserId,
    required this.onOpenMember,
    required this.onRemove,
  });

  final ChannelInfoData channel;
  final String channelRoomId;
  final List<AsChannelMember> members;
  final Map<String, String> profileAvatarUrls;
  final int placeholderCount;
  final bool isLoading;
  final Client client;
  final UserProfileDirectory profileDirectory;
  final String currentUserId;
  final ValueChanged<AsChannelMember> onOpenMember;
  final VoidCallback onRemove;

  static const int _columns = 5;
  static const int _maxVisibleRows = 4;
  static const double _tileSize = 40;
  static const double _gap = 16;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (final member in members)
        InkWell(
          key: ValueKey('channel_member_avatar_${member.userMxid}'),
          borderRadius: BorderRadius.circular(8),
          onTap: member.userMxid.trim() == currentUserId.trim()
              ? null
              : () => onOpenMember(member),
          child: PortalAvatar(
            seed: _memberName(member),
            size: 40,
            imageUrl: channelMemberAvatarUrl(
              client,
              member,
              roomId:
                  channelRoomId.trim().isEmpty ? channel.roomId : channelRoomId,
              directory: profileDirectory,
              fallbackAvatarUrl: profileAvatarUrls[member.userMxid] ?? '',
            ),
            shape: AvatarShape.squircle,
          ),
        ),
      for (var index = 0; index < placeholderCount; index++)
        PortalAvatar(
          seed: '${channel.id}-member-$index',
          size: 40,
          shape: AvatarShape.squircle,
        ),
      _RemoveMemberTile(
        key: const ValueKey('channel_remove_member_tile'),
        isLoading: isLoading,
        onTap: onRemove,
      ),
    ];
    final rows = (children.length / _columns).ceil().clamp(1, _maxVisibleRows);
    final height = rows * _tileSize + (rows - 1) * _gap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        const preferredWidth = _columns * _tileSize + (_columns - 1) * _gap;
        final compactGap =
            (((availableWidth - _columns * _tileSize) / (_columns - 1))
                    .clamp(4.0, _gap))
                .toDouble();
        final gap = availableWidth < preferredWidth ? compactGap : _gap;
        final contentWidth = _columns * _tileSize + (_columns - 1) * gap;
        return SizedBox(
          key: const ValueKey('channel_owner_member_grid'),
          height: height,
          child: SingleChildScrollView(
            primary: false,
            padding: EdgeInsets.zero,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                key: const ValueKey('channel_owner_member_grid_content'),
                width: contentWidth,
                child: Wrap(
                  spacing: gap,
                  runSpacing: _gap,
                  children: children
                      .map(
                        (child) => SizedBox(
                          width: _tileSize,
                          height: _tileSize,
                          child: child,
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RemoveMemberTile extends StatelessWidget {
  const _RemoveMemberTile({
    super.key,
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

String _domainFromMxid(String mxid) {
  final value = mxid.trim();
  final colon = value.indexOf(':');
  if (colon < 0 || colon == value.length - 1) return '';
  return value.substring(colon + 1);
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
        memberCount: channel.memberCount,
      ),
      currentRoomId: channel.roomId,
      currentRoomName: channel.name,
      createInviteGrant: channel.isOwned,
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
    await dissolveChannelThroughAs(ref, channel.id);
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

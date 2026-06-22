import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/as_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../providers/home_hidden_conversations_provider.dart';
import '../providers/product_conversations_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_display_name.dart';
import '../utils/contact_identity_label.dart';
import '../utils/direct_contact_status.dart';
import '../utils/product_conversation_navigation.dart';
import '../utils/product_conversation_summary_writer.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/report_reason_dialog.dart';

class ContactDetailPage extends ConsumerStatefulWidget {
  const ContactDetailPage({
    super.key,
    required this.userId,
    this.fromChatAvatar = false,
    this.fromChatInfo = false,
  });

  final String userId;
  final bool fromChatAvatar;
  final bool fromChatInfo;

  @override
  ConsumerState<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends ConsumerState<ContactDetailPage> {
  bool _blocking = false;
  bool _friendActionBusy = false;
  StreamSubscription<SyncUpdate>? _syncSub;

  @override
  void initState() {
    super.initState();
    _syncSub = ref.read(matrixClientProvider).onSync.stream.listen((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final client = ref.read(matrixClientProvider);
    final syncCache = ref.watch(asSyncCacheProvider);
    final productConversations =
        ref.watch(productConversationsProvider).valueOrNull ??
            const <AsConversation>[];
    final currentUserProfile =
        ref.watch(currentUserProfileProvider).valueOrNull;
    final userId = widget.userId;
    final isSelf = userId == client.userID;
    final acceptedContactForUser = syncCache.acceptedContactForUserId(userId);
    final acceptedRoom = acceptedContactForUser == null
        ? null
        : client.getRoomById(acceptedContactForUser.roomId);
    final room = acceptedRoom ??
        client.rooms.where((r) {
          final acceptedContact = syncCache.acceptedContactForRoom(r.id);
          return r.directChatMatrixID == userId ||
              productDirectPeerMxid(r) == userId ||
              acceptedContact?.userId == userId;
        }).firstOrNull;
    final agentMxid = portalAgentMxidForClient(client);
    final acceptedRoomIds = syncCache.acceptedDirectRoomIds;
    final canUseRealRoom = room != null &&
        acceptedContactForUser != null &&
        room.id == acceptedContactForUser.roomId &&
        acceptedRoomIds.contains(room.id) &&
        canSendDirectChatMessage(
          room,
          agentMxid: agentMxid,
          acceptedRoomIds: acceptedRoomIds,
        );
    final directProductConversation = productDirectConversationForPeer(
      productConversations,
      peerMxid: userId,
      roomId: acceptedContactForUser?.roomId ?? room?.id ?? '',
    );
    final canOpenChat = canUseRealRoom && directProductConversation != null;
    final acceptedContact = acceptedContactForUser ??
        (room == null ? null : syncCache.acceptedContactForRoom(room.id));
    final domain = domainFromMxid(userId);
    final uidDomain = reportDomainForUserId(userId, acceptedContact?.domain);
    final currentProfileName = currentUserProfile?.displayName?.trim();
    final peerMember = room?.unsafeGetUserFromMemoryOrFallback(userId);
    final peerMemberName = directPeerMemberDisplayName(room, userId);
    final displayName = contactDisplayNameFromIdentity(
      mxid: userId,
      displayName: isSelf && currentProfileName?.isNotEmpty == true
          ? currentProfileName!
          : _firstNonEmpty([
              peerMemberName,
              acceptedContact?.displayName,
              room?.getLocalizedDisplayname(),
            ]),
      domain: acceptedContact?.domain ?? domain,
      fallback: userId,
    );
    final avatarUrl = isSelf
        ? profileAvatarHttpUrl(currentUserProfile, client)
        : (room == null
                ? null
                : matrixContentHttpUrl(client, peerMember?.avatarUrl)) ??
            avatarHttpUrl(client, acceptedContact?.avatarUrl);
    final roomId = room?.id;
    final preferenceKey = roomId ?? userId;
    final mutedConversationIds = ref.watch(mutedConversationIdsProvider);
    final muted = mutedConversationIds.contains(preferenceKey);
    final hideChatAvatarEntries = widget.fromChatAvatar;
    final hideRecommendFriend = widget.fromChatInfo;
    final existingContact = syncCache.contactForUserId(userId);

    if (widget.fromChatAvatar) {
      return _buildChatAvatarProfile(
        context,
        displayName: displayName,
        avatarUrl: avatarUrl,
        seed: userId,
        isSelf: isSelf,
        isFriend: canOpenChat,
        contactStatus: existingContact?.status,
        onMessage: canOpenChat && roomId != null
            ? () => context.go('/chat/${Uri.encodeComponent(roomId)}')
            : null,
        onVoice: room != null
            ? () => context.push(
                  _callRoute('call', room.id, userId, displayName, avatarUrl),
                )
            : null,
        onVideo: room != null
            ? () => context.push(
                  _callRoute(
                    'video-call',
                    room.id,
                    userId,
                    displayName,
                    avatarUrl,
                  ),
                )
            : null,
        onChannels: () => context.push(
          '/contact-channels/${Uri.encodeComponent(userId)}',
        ),
        onRecommend: isSelf ? null : () => _shareContact(displayName, userId),
        onAddFriend: isSelf || _isPendingContact(existingContact?.status)
            ? null
            : () => _sendFriendRequest(
                  context,
                  userId: userId,
                  displayName: displayName,
                  domain: acceptedContact?.domain ?? domain,
                ),
      );
    }

    return Scaffold(
      backgroundColor: t.surfaceHover,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _ContactBackButton(
                        onTap: () => context.pop(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _UserHeader(
                      name: displayName,
                      badge: _roleBadge(acceptedContact?.domain),
                      uid: uidDomain,
                      onUidTap: () => _copyUid(context, uidDomain),
                      avatarUrl: avatarUrl,
                      seed: userId,
                    ),
                    const SizedBox(height: 24),
                    _QuickActionGrid(
                      onMessage: canOpenChat && roomId != null
                          ? () {
                              _openProductChat(
                                directProductConversation,
                              );
                            }
                          : null,
                      showCallActions: true,
                      onVoice: room != null
                          ? () => context.push(
                                _callRoute(
                                  'call',
                                  room.id,
                                  userId,
                                  displayName,
                                  avatarUrl,
                                ),
                              )
                          : null,
                      onVideo: room != null
                          ? () => context.push(
                                _callRoute(
                                  'video-call',
                                  room.id,
                                  userId,
                                  displayName,
                                  avatarUrl,
                                ),
                              )
                          : null,
                      onSearch: hideChatAvatarEntries
                          ? null
                          : roomId == null
                              ? () => _toast(context, '缺少联系人房间信息，无法搜索聊天')
                              : () => context.push(
                                    '/room-search/${Uri.encodeComponent(roomId)}',
                                  ),
                    ),
                    if (!isSelf) ...[
                      const SizedBox(height: 26),
                      _ContactSettingRow(
                        label: '设置备注',
                        onTap: () => _showRemarkDialog(
                          context,
                          userId: userId,
                          roomId: acceptedContact?.roomId ?? roomId ?? '',
                          domain: acceptedContact?.domain ?? domain,
                          currentName: displayName,
                        ),
                      ),
                    ],
                    if (!hideRecommendFriend) ...[
                      SizedBox(height: isSelf ? 26 : 16),
                      _ContactSettingRow(
                        label: '推荐给朋友',
                        onTap: () => _shareContact(displayName, userId),
                      ),
                    ],
                    if (!hideChatAvatarEntries) ...[
                      const SizedBox(height: 16),
                      _ContactSwitchRow(
                        label: '消息免打扰',
                        value: muted,
                        onChanged: (value) => setConversationMuted(
                          ref,
                          preferenceKey,
                          value,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ContactSettingRow(
                        label: '拉黑用户',
                        onTap: room == null
                            ? () => _toast(context, '拉黑用户失败: 缺少联系人房间信息')
                            : () => _confirmBlockContact(context, room.id),
                      ),
                      const SizedBox(height: 16),
                      _ContactSettingRow(
                        label: '举报用户',
                        onTap: () => _showReportDialog(
                          context,
                          reportedDomain: uidDomain,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!isSelf)
              _DeleteFriendButton(
                onTap: room == null
                    ? () => _toast(context, '删除好友失败: 缺少联系人房间信息')
                    : () => _confirmDeleteContact(context, room.id),
              ),
          ],
        ),
      ),
    );
  }

  void _openProductChat(AsConversation conversation) {
    final roomId = conversation.roomId.trim();
    final route = productConversationRoute(conversation);
    if (roomId.isEmpty || route == null) return;
    showHomeConversation(ref, roomId);
    context.go(route);
  }

  Widget _buildChatAvatarProfile(
    BuildContext context, {
    required String displayName,
    required String? avatarUrl,
    required String seed,
    required bool isSelf,
    required bool isFriend,
    required String? contactStatus,
    required VoidCallback? onMessage,
    required VoidCallback? onVoice,
    required VoidCallback? onVideo,
    required VoidCallback onChannels,
    required VoidCallback? onRecommend,
    required VoidCallback? onAddFriend,
  }) {
    final t = context.tk;
    final pending = _isPendingContact(contactStatus);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _ContactBackButton(onTap: () => context.pop()),
              ),
              const SizedBox(height: 24),
              _AvatarProfileHeader(
                name: displayName,
                avatarUrl: avatarUrl,
                seed: seed,
              ),
              SizedBox(height: isFriend ? 22 : 24),
              if (isFriend) ...[
                _AvatarProfileActions(
                  onMessage: onMessage,
                  onVoice: onVoice,
                  onVideo: onVideo,
                ),
                const SizedBox(height: 24),
                _AvatarProfileMenuRow(
                  label: '他的频道',
                  onTap: onChannels,
                ),
                const SizedBox(height: 14),
                if (onRecommend != null)
                  _AvatarProfileMenuRow(
                    label: '把他推荐给朋友',
                    onTap: onRecommend,
                  ),
              ] else ...[
                _AvatarProfileMenuRow(
                  label: '他的频道',
                  onTap: onChannels,
                  previewSeeds: const ['channel-a', 'channel-b', 'channel-c'],
                ),
                if (!isSelf) ...[
                  const SizedBox(height: 14),
                  _AddFriendRow(
                    busy: _friendActionBusy,
                    text: pending ? '已申请' : '添加好友',
                    onTap: pending || _friendActionBusy ? null : onAddFriend,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendFriendRequest(
    BuildContext context, {
    required String userId,
    required String displayName,
    required String domain,
  }) async {
    if (_friendActionBusy) return;
    setState(() => _friendActionBusy = true);
    try {
      final contact = await ref.read(asClientProvider).createContactRequest(
            mxid: userId,
            displayName: displayName,
            domain: domain,
          );
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withContactEntry(contact),
          );
      await ref.read(matrixClientProvider).oneShotSync();
      unawaited(
        ref.read(asBootstrapRepositoryProvider).refresh().then((bootstrap) {
          ref.read(asSyncCacheProvider.notifier).update(
                (state) => state.copyWith(bootstrap: bootstrap),
              );
        }).catchError((Object e) {
          debugPrint('refresh bootstrap after contact request failed: $e');
        }),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            contact.status.trim() == 'accepted'
                ? '已恢复旧会话，可以继续聊天。'
                : '好友请求已发送，等待对方接受。',
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
          'send friend request from contact detail failed: $e\n$stackTrace');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送好友请求失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _friendActionBusy = false);
    }
  }

  Future<void> _confirmDeleteContact(
      BuildContext context, String roomId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '删除好友',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          '删除后将不再显示该联系人，会话关系也会同步更新。',
          style: AppTheme.sans(size: 15, color: context.tk.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '删除',
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: context.tk.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _removeContact(
      context,
      roomId,
      successMessage: '已删除好友',
      failurePrefix: '删除好友失败',
    );
  }

  Future<void> _confirmBlockContact(
    BuildContext context,
    String roomId,
  ) async {
    if (_blocking) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '拉黑用户',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          '拉黑后将移除该联系人和会话关系。',
          style: AppTheme.sans(size: 15, color: context.tk.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '拉黑',
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: context.tk.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _blocking = true);
    try {
      await _removeContact(
        context,
        roomId,
        successMessage: '已拉黑用户',
        failurePrefix: '拉黑用户失败',
      );
    } finally {
      if (mounted) setState(() => _blocking = false);
    }
  }

  Future<void> _showReportDialog(
    BuildContext context, {
    required String reportedDomain,
  }) async {
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
    try {
      await ref.read(asClientProvider).submitReport(
            reporterDomain: reporterDomain,
            reportedDomain: reportedDomain,
            targetType: 1,
            reason: reason.trim(),
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('举报已提交')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('举报提交失败: $error')),
      );
    }
  }

  Future<void> _showRemarkDialog(
    BuildContext context, {
    required String userId,
    required String roomId,
    required String domain,
    required String currentName,
  }) async {
    final next = await showDialog<String>(
      context: context,
      builder: (_) => _ContactRemarkDialog(initialValue: currentName),
    );
    if (!context.mounted || next == null) return;
    if (next.trim().isEmpty) {
      _toast(context, '备注不能为空');
      return;
    }
    final cleanRoomId = roomId.trim();
    if (cleanRoomId.isEmpty) {
      _toast(context, '缺少联系人房间信息，无法保存备注');
      return;
    }
    ContactEntry updated;
    try {
      updated = await ref.read(asClientProvider).updateContact(
            roomId: cleanRoomId,
            displayName: next,
            domain: domain,
          );
    } catch (error) {
      if (!context.mounted) return;
      _toast(context, '备注更新失败: $error');
      return;
    }
    if (!context.mounted) return;
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.withContactEntry(updated).withContactDisplayName(
                userId: userId,
                displayName: updated.displayName.trim().isEmpty
                    ? next
                    : updated.displayName,
              ),
        );
    final bootstrap = ref.read(asSyncCacheProvider).bootstrap;
    if (bootstrap != null) {
      unawaited(
        ref
            .read(asBootstrapStoreProvider.future)
            .then((store) => store.write(bootstrap))
            .catchError((error) {
          debugPrint('persist contact remark bootstrap failed: $error');
        }),
      );
    }
    _toast(context, '备注已更新');
  }

  Future<void> _shareContact(String displayName, String userId) async {
    final name = displayName.trim().isEmpty ? userId : displayName.trim();
    await Share.share('推荐联系人：$name\n$userId');
  }

  Future<void> _copyUid(BuildContext context, String uid) async {
    await Clipboard.setData(ClipboardData(text: uid));
    if (!context.mounted) return;
    _toast(context, '已复制 UID');
  }

  Future<void> _removeContact(
    BuildContext context,
    String roomId, {
    required String successMessage,
    required String failurePrefix,
  }) async {
    final client = ref.read(matrixClientProvider);
    try {
      final contact = await ref.read(asClientProvider).deleteContact(roomId);
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withContactEntry(contact),
          );
      await recordProductConversationMutation(
        ref,
        contact.productConversation,
      );
      unawaited(
        ref.read(asBootstrapRepositoryProvider).refresh().then((bootstrap) {
          ref.read(asSyncCacheProvider.notifier).update(
                (state) => state.copyWith(bootstrap: bootstrap),
              );
        }).catchError((Object e) {
          debugPrint('refresh bootstrap after contact delete failed: $e');
        }),
      );
      final room = client.getRoomById(roomId);
      if (room != null) client.rooms.remove(room);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      context.go('/home');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$failurePrefix: $e')),
      );
    }
  }
}

class _ContactBackButton extends StatelessWidget {
  const _ContactBackButton({required this.onTap});

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
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: t.surface.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
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
    );
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader({
    required this.name,
    required this.badge,
    required this.uid,
    required this.onUidTap,
    required this.seed,
    this.avatarUrl,
  });

  final String name;
  final String badge;
  final String uid;
  final VoidCallback onUidTap;
  final String seed;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      children: [
        PortalAvatar(
          seed: seed,
          size: 60,
          imageUrl: avatarUrl,
          shape: AvatarShape.squircle,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 16,
                        weight: FontWeight.w600,
                        color: t.text,
                      ).copyWith(letterSpacing: -0.4),
                    ),
                  ),
                  if (badge.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _RoleBadge(text: badge),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onUidTap,
                child: Text(
                  'UID $uid',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 14, color: t.textMute),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: t.accent),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTheme.sans(size: 10, color: t.accent).copyWith(
          letterSpacing: -0.4,
          height: 1.1,
        ),
      ),
    );
  }
}

class _AvatarProfileHeader extends StatelessWidget {
  const _AvatarProfileHeader({
    required this.name,
    required this.seed,
    this.avatarUrl,
  });

  final String name;
  final String seed;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      children: [
        PortalAvatar(
          seed: seed,
          size: 60,
          imageUrl: avatarUrl,
          shape: AvatarShape.squircle,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(
              size: 16,
              weight: FontWeight.w600,
              color: t.text,
            ).copyWith(letterSpacing: -0.4),
          ),
        ),
      ],
    );
  }
}

class _AvatarProfileActions extends StatelessWidget {
  const _AvatarProfileActions({
    required this.onMessage,
    required this.onVoice,
    required this.onVideo,
  });

  final VoidCallback? onMessage;
  final VoidCallback? onVoice;
  final VoidCallback? onVideo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AvatarProfileActionCard(
            icon: Symbols.chat_bubble,
            label: '发消息',
            onTap: onMessage,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AvatarProfileActionCard(
            icon: Symbols.call,
            label: '音频通话',
            onTap: onVoice,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AvatarProfileActionCard(
            icon: Symbols.videocam,
            label: '视频通话',
            onTap: onVideo,
          ),
        ),
      ],
    );
  }
}

class _AvatarProfileActionCard extends StatelessWidget {
  const _AvatarProfileActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final enabled = onTap != null;
    final color = enabled ? t.accent : t.accent.withValues(alpha: 0.35);
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: color, fill: 1),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(
                  size: 13,
                  weight: FontWeight.w500,
                  color: color,
                ).copyWith(letterSpacing: -0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarProfileMenuRow extends StatelessWidget {
  const _AvatarProfileMenuRow({
    required this.label,
    required this.onTap,
    this.previewSeeds = const [],
  });

  final String label;
  final VoidCallback onTap;
  final List<String> previewSeeds;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Row(
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 16,
                    weight: FontWeight.w500,
                    color: t.text,
                  ).copyWith(letterSpacing: -0.4),
                ),
                if (previewSeeds.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  for (final seed in previewSeeds.take(3)) ...[
                    PortalAvatar(
                      seed: seed,
                      size: 30,
                      shape: AvatarShape.squircle,
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
                const Spacer(),
                Icon(
                  Symbols.chevron_right,
                  size: 24,
                  color: t.text,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddFriendRow extends StatelessWidget {
  const _AddFriendRow({
    required this.text,
    required this.busy,
    required this.onTap,
  });

  final String text;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final enabled = onTap != null;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 50,
          child: Center(
            child: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.accent,
                    ),
                  )
                : Text(
                    text,
                    style: AppTheme.sans(
                      size: 16,
                      weight: FontWeight.w500,
                      color: enabled ? t.accent : t.textMute,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({
    required this.onMessage,
    required this.showCallActions,
    required this.onVoice,
    required this.onVideo,
    required this.onSearch,
  });

  final VoidCallback? onMessage;
  final bool showCallActions;
  final VoidCallback? onVoice;
  final VoidCallback? onVideo;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ContactQuickAction(
            icon: Symbols.chat_bubble,
            label: '发消息',
            onTap: onMessage,
          ),
        ),
        if (showCallActions) ...[
          const SizedBox(width: 16),
          Expanded(
            child: _ContactQuickAction(
              icon: Symbols.call,
              label: '语音通话',
              onTap: onVoice,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _ContactQuickAction(
              icon: Symbols.videocam,
              label: '视频通话',
              onTap: onVideo,
            ),
          ),
        ],
        if (onSearch != null) ...[
          const SizedBox(width: 16),
          Expanded(
            child: _ContactQuickAction(
              icon: Symbols.search,
              label: '搜索聊天',
              onTap: onSearch,
            ),
          ),
        ],
      ],
    );
  }
}

class _ContactQuickAction extends StatelessWidget {
  const _ContactQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final t = context.tk;
    final color = enabled ? t.accent : t.accent.withValues(alpha: 0.35);
    return Material(
      color: t.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color, fill: 1),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactSettingRow extends StatelessWidget {
  const _ContactSettingRow({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: t.text,
                    ).copyWith(letterSpacing: -0.4),
                  ),
                ),
                Icon(
                  Symbols.chevron_right,
                  size: 24,
                  color: t.textMute.withValues(alpha: 0.65),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactSwitchRow extends StatelessWidget {
  const _ContactSwitchRow({
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

class _DeleteFriendButton extends StatelessWidget {
  const _DeleteFriendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Material(
          color: t.surface.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.danger),
              ),
              child: Text(
                '删除好友',
                style: AppTheme.sans(
                  size: 14,
                  weight: FontWeight.w500,
                  color: t.danger,
                ).copyWith(letterSpacing: -0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactRemarkDialog extends StatefulWidget {
  const _ContactRemarkDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_ContactRemarkDialog> createState() => _ContactRemarkDialogState();
}

class _ContactRemarkDialogState extends State<_ContactRemarkDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AlertDialog(
      title: Text(
        '设置备注',
        style: AppTheme.sans(size: 17, weight: FontWeight.w600),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 32,
        decoration: InputDecoration(
          hintText: '输入备注名',
          hintStyle: AppTheme.sans(size: 15, color: t.textMute),
        ),
        style: AppTheme.sans(size: 15, color: t.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '取消',
            style: AppTheme.sans(size: 15, color: t.textMute),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(
            '保存',
            style: AppTheme.sans(
              size: 15,
              weight: FontWeight.w600,
              color: t.accent,
            ),
          ),
        ),
      ],
    );
  }
}

String _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

bool _isPendingContact(String? status) {
  final normalized = status?.trim();
  return normalized == 'pending_outbound' || normalized == 'pending_inbound';
}

String _roleBadge(String? domain) {
  final value = domain?.trim().toLowerCase() ?? '';
  if (value.contains('agent') || value.contains('support')) return '客服经理';
  return '';
}

String _callRoute(
  String path,
  String roomId,
  String peerUserId,
  String name,
  String? avatarUrl,
) {
  final room = Uri.encodeComponent(roomId);
  final peer = Uri.encodeQueryComponent(peerUserId);
  final displayName = Uri.encodeQueryComponent(name);
  final avatar = avatarUrl?.trim();
  final avatarQuery = avatar == null || avatar.isEmpty
      ? ''
      : '&avatar=${Uri.encodeQueryComponent(avatar)}';
  return '/$path/$room?peer=$peer&name=$displayName$avatarQuery';
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

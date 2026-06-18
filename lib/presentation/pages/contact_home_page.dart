import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../mock/mock_data.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/contact_identity_label.dart';
import '../widgets/glass_list_tile.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/portal_avatar.dart';

const _mockAuthEnabled = bool.fromEnvironment(
  'P2P_MATRIX_MOCK_AUTH',
  defaultValue: false,
);

enum _FriendButtonState { none, pending, accepted }

class ContactHomePage extends ConsumerStatefulWidget {
  const ContactHomePage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<ContactHomePage> createState() => _ContactHomePageState();
}

class _ContactHomePageState extends ConsumerState<ContactHomePage> {
  bool _following = false;
  bool _followBusy = false;
  bool _friendActionBusy = false;
  _FriendButtonState _friendState = _FriendButtonState.none;
  String? _acceptedContactRoomId;
  String? _relationshipLoadKey;
  List<AsChannel>? _publicChannels;

  String get _friendButtonText {
    switch (_friendState) {
      case _FriendButtonState.accepted:
        return '删除好友';
      case _FriendButtonState.pending:
        return '已申请';
      case _FriendButtonState.none:
        return '加好友';
    }
  }

  @override
  void didUpdateWidget(covariant ContactHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId == widget.userId) return;
    setState(() {
      _following = false;
      _friendState = _FriendButtonState.none;
      _acceptedContactRoomId = null;
      _relationshipLoadKey = null;
      _publicChannels = null;
    });
  }

  bool get _useMockRelationship {
    final isLoggedIn =
        ref.read(authStateNotifierProvider).valueOrNull?.isLoggedIn ?? false;
    return _mockAuthEnabled || !isLoggedIn;
  }

  Future<void> _loadRelationshipState(MockContactHome home) async {
    if (_useMockRelationship) return;
    try {
      final asClient = ref.read(asClientProvider);
      final bootstrap = ref.read(asSyncCacheProvider).bootstrap ??
          await ref.read(asBootstrapRepositoryProvider).refresh();
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
      final contact = _contactForHome(bootstrap.contacts, home);
      final results = await Future.wait<Object>([
        asClient.getFollows(),
        asClient.getUserPublicChannels(home.userId),
      ]);
      final follows = results[0] as List<FollowEntry>;
      final publicChannels = results[1] as List<AsChannel>;
      if (!mounted) return;
      setState(() {
        _following = _isFollowingHome(follows, home);
        _friendState = _friendStateFromContact(contact);
        _acceptedContactRoomId =
            contact?.status == 'accepted' ? contact?.roomId : null;
        _publicChannels = publicChannels;
      });
    } catch (e) {
      debugPrint('load contact home relationship failed: $e');
    }
  }

  Future<void> _toggleFollow(MockContactHome home) async {
    if (_followBusy) return;
    final next = !_following;

    setState(() {
      _following = next;
      _followBusy = true;
    });

    try {
      if (!_useMockRelationship) {
        final asClient = ref.read(asClientProvider);
        if (next) {
          await asClient.addFollow(home.domain);
        } else {
          await asClient.removeFollow(home.domain);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _following = !next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next ? '关注失败: $e' : '取消关注失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _onFriendAction(MockContactHome home) async {
    if (_friendActionBusy) return;
    switch (_friendState) {
      case _FriendButtonState.accepted:
        await _confirmAndDeleteFriend(home);
        return;
      case _FriendButtonState.pending:
        return;
      case _FriendButtonState.none:
        await _sendFriendRequest(home);
        return;
    }
  }

  Future<void> _sendFriendRequest(MockContactHome home) async {
    setState(() => _friendActionBusy = true);

    try {
      var restored = false;
      if (!_useMockRelationship) {
        final contact = await ref.read(asClientProvider).createContactRequest(
              mxid: home.userId,
              displayName: home.displayName,
              domain: home.domain,
            );
        restored = contact.status.trim() == 'accepted';
        ref.read(asSyncCacheProvider.notifier).update(
              (state) => state.withContactEntry(contact),
            );
        await ref.read(matrixClientProvider).oneShotSync();
        await _refreshBootstrapFromAs();
      }
      if (!mounted) return;
      setState(() {
        _friendState =
            restored ? _FriendButtonState.accepted : _FriendButtonState.pending;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(restored ? '已恢复旧会话，可以继续聊天。' : '好友请求已发送，等待对方接受。'),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('send friend request failed: $e\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送好友请求失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _friendActionBusy = false);
    }
  }

  Future<void> _confirmAndDeleteFriend(MockContactHome home) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除好友'),
          content: Text('删除 ${home.displayName} 后，双方的私聊关系会解除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _deleteFriend(home);
  }

  Future<void> _deleteFriend(MockContactHome home) async {
    final roomId = _acceptedContactRoomId?.trim();
    if (roomId == null || roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除好友失败: 缺少联系人房间信息')),
      );
      return;
    }

    setState(() => _friendActionBusy = true);
    try {
      final asClient = ref.read(asClientProvider);
      await asClient.deleteContact(roomId);
      await _refreshBootstrapFromAs();
      _removeLocalMatrixRoom(roomId);
      if (!mounted) return;
      setState(() {
        _friendState = _FriendButtonState.none;
        _acceptedContactRoomId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除 ${home.displayName}')),
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除好友失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _friendActionBusy = false);
    }
  }

  void _removeLocalMatrixRoom(String roomId) {
    final client = ref.read(matrixClientProvider);
    final room = client.getRoomById(roomId);
    if (room != null) client.rooms.remove(room);
  }

  Future<void> _refreshBootstrapFromAs() async {
    final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.copyWith(bootstrap: bootstrap),
        );
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(asSyncCacheProvider).bootstrap;
    final home = _visitorHomeForUserId(widget.userId, bootstrap);
    final visitorChannels =
        _publicChannels?.map(_contactChannelFromAs).toList(growable: false) ??
            home?.channels ??
            const <MockContactChannel>[];
    final auth = ref.watch(authStateNotifierProvider).valueOrNull;
    if (home != null &&
        !_mockAuthEnabled &&
        auth?.isLoggedIn == true &&
        _relationshipLoadKey != widget.userId) {
      _relationshipLoadKey = widget.userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadRelationshipState(home));
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(title: '主页'),
          Expanded(
            child: home == null
                ? const _ContactHomeEmpty()
                : ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      _VisitorCoverHeader(
                        home: home,
                        following: _following,
                        busy: _followBusy,
                        friendButtonText: _friendButtonText,
                        friendButtonActive:
                            _friendState != _FriendButtonState.none,
                        friendActionBusy: _friendActionBusy,
                        onFollowTap: () => _toggleFollow(home),
                        onFriendTap: () => _onFriendAction(home),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: glassListTileHorizontalMargin,
                        ),
                        child: _VisitorSection(
                          title: '她的频道',
                          child: visitorChannels.isEmpty
                              ? const _VisitorEmptyLine(text: '还没有公开频道')
                              : Column(
                                  children: [
                                    for (var i = 0;
                                        i < visitorChannels.length;
                                        i++) ...[
                                      _VisitorChannelTile(
                                        channel: visitorChannels[i],
                                      ),
                                      if (i != visitorChannels.length - 1)
                                        const SizedBox(height: 10),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: glassListTileHorizontalMargin,
                        ),
                        child: _VisitorSection(
                          title: '她的动态',
                          child: home.dynamics.isEmpty
                              ? const _VisitorEmptyLine(text: '还没有公开动态')
                              : _VisitorDynamicsTimeline(
                                  items: home.dynamics,
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

MockContactHome? _visitorHomeForUserId(
  String userId,
  AsSyncBootstrap? bootstrap,
) {
  final mock = MockData.contactHomeByMxid(userId);
  if (mock != null) return mock;

  final trimmed = userId.trim();
  if (trimmed.isEmpty) return null;

  final contact = _contactForIdentity(
    bootstrap?.contacts ?? const <AsSyncContact>[],
    trimmed,
  );
  final contactDomain = contact?.domain.trim() ?? '';
  final domain =
      contactDomain.isNotEmpty ? contactDomain : _domainFromMxid(trimmed);
  final displayName = contactDisplayNameFromIdentity(
    mxid: trimmed,
    displayName: contact?.displayName ?? '',
    domain: domain,
    fallback: _displayNameFromMxid(trimmed, fallbackDomain: domain),
  );
  final avatarUrl = contact?.avatarUrl.trim();

  return MockContactHome(
    userId: trimmed,
    displayName: displayName,
    domain: domain,
    bio: '',
    avatarUrl: avatarUrl == null || avatarUrl.isEmpty ? null : avatarUrl,
    channels: const [],
    dynamics: const [],
  );
}

MockContactChannel _contactChannelFromAs(AsChannel channel) {
  return MockContactChannel(
    name: channel.name.trim().isEmpty ? channel.roomId : channel.name.trim(),
    description: channel.roomId.trim(),
    memberCount: channel.memberCount,
    roomId: channel.roomId.trim(),
    channelId: channel.channelId.trim(),
    avatarUrl:
        channel.avatarUrl.trim().isEmpty ? null : channel.avatarUrl.trim(),
  );
}

AsSyncContact? _contactForIdentity(
  List<AsSyncContact> contacts,
  String identity,
) {
  for (final contact in contacts) {
    if (_sameIdentity(contact.userId, identity) ||
        _sameIdentity(contact.domain, identity)) {
      return contact;
    }
  }
  return null;
}

AsSyncContact? _contactForHome(
  List<AsSyncContact> contacts,
  MockContactHome home,
) {
  for (final contact in contacts) {
    if (_sameIdentity(contact.userId, home.userId) ||
        _sameIdentity(contact.domain, home.domain)) {
      return contact;
    }
  }
  return null;
}

String _domainFromMxid(String mxid) {
  final separator = mxid.indexOf(':');
  if (mxid.startsWith('@') && separator > 1 && separator < mxid.length - 1) {
    return mxid.substring(separator + 1);
  }
  return mxid;
}

String _displayNameFromMxid(String mxid, {required String fallbackDomain}) {
  final separator = mxid.indexOf(':');
  if (mxid.startsWith('@') && separator > 1) {
    return mxid.substring(1, separator);
  }
  if (fallbackDomain.isNotEmpty) return fallbackDomain;
  return mxid;
}

bool _isFollowingHome(List<FollowEntry> follows, MockContactHome home) {
  for (final follow in follows) {
    if (_sameIdentity(follow.domain, home.domain)) return true;
  }
  return false;
}

_FriendButtonState _friendStateFromContact(AsSyncContact? contact) {
  final status = contact?.status.trim().toLowerCase();
  if (status == 'accepted') return _FriendButtonState.accepted;
  if (status == 'pending_outbound' || status == 'pending_inbound') {
    return _FriendButtonState.pending;
  }
  return _FriendButtonState.none;
}

bool _sameIdentity(String left, String right) {
  return left.trim().toLowerCase() == right.trim().toLowerCase();
}

class _VisitorCoverHeader extends StatelessWidget {
  const _VisitorCoverHeader({
    required this.home,
    required this.following,
    required this.busy,
    required this.friendButtonText,
    required this.friendButtonActive,
    required this.friendActionBusy,
    required this.onFollowTap,
    required this.onFriendTap,
  });

  final MockContactHome home;
  final bool following;
  final bool busy;
  final String friendButtonText;
  final bool friendButtonActive;
  final bool friendActionBusy;
  final VoidCallback onFollowTap;
  final VoidCallback onFriendTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7894A8),
                  Color(0xFFE3B46E),
                  Color(0xFF34302D),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.04),
                  Colors.black.withValues(alpha: 0.36),
                ],
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _CoverActionButton(
                  key: const ValueKey('contact_home_follow_button'),
                  text: following ? '取关' : '关注',
                  busy: busy,
                  active: following,
                  onTap: onFollowTap,
                ),
                const SizedBox(height: 8),
                _CoverActionButton(
                  key: const ValueKey('contact_home_add_friend_button'),
                  text: friendButtonText,
                  busy: friendActionBusy,
                  active: friendButtonActive,
                  onTap: onFriendTap,
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                PortalAvatar(
                  seed: home.userId,
                  size: 104,
                  imageUrl: home.avatarUrl,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        home.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(
                          size: 24,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        home.domain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(size: 16, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        home.bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(size: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverActionButton extends StatelessWidget {
  const _CoverActionButton({
    super.key,
    required this.text,
    required this.busy,
    required this.active,
    required this.onTap,
  });

  final String text;
  final bool busy;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 34,
          constraints: const BoxConstraints(minWidth: 74),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: active ? 0.22 : 0.36),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          alignment: Alignment.center,
          child: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  text,
                  style: AppTheme.sans(
                    size: 14,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _VisitorSection extends StatelessWidget {
  const _VisitorSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 2, bottom: 8),
          child: Text(
            title,
            style: AppTheme.sans(
              size: 16,
              weight: FontWeight.w600,
              color: t.text,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _VisitorChannelTile extends StatelessWidget {
  const _VisitorChannelTile({required this.channel});

  final MockContactChannel channel;

  @override
  Widget build(BuildContext context) {
    final target = channel.roomId.trim().isNotEmpty
        ? channel.roomId.trim()
        : channel.channelId.trim();
    return GlassListTile(
      margin: const EdgeInsets.only(bottom: glassListTileGap),
      leading: channel.avatarUrl?.trim().isNotEmpty == true
          ? PortalAvatar(
              seed: target.isEmpty ? channel.name : target,
              size: 40,
              imageUrl: channel.avatarUrl,
              shape: AvatarShape.squircle,
            )
          : const GlassListIcon(icon: Symbols.campaign),
      title: channel.name,
      subtitle: [
        if (channel.roomId.trim().isNotEmpty) channel.roomId.trim(),
        if (channel.description.trim().isNotEmpty &&
            channel.description.trim() != channel.roomId.trim())
          channel.description.trim(),
        '${channel.memberCount} 人',
      ].join(' · '),
      onTap: target.isEmpty
          ? null
          : () => context.push('/channel/${Uri.encodeComponent(target)}'),
    );
  }
}

class _VisitorDynamicsTimeline extends StatelessWidget {
  const _VisitorDynamicsTimeline({required this.items});

  final List<MockContactDynamic> items;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          _VisitorDynamicRow(item: sorted[i]),
        ],
      ],
    );
  }
}

class _VisitorDynamicRow extends StatelessWidget {
  const _VisitorDynamicRow({required this.item});

  final MockContactDynamic item;

  @override
  Widget build(BuildContext context) {
    return GlassListPanel(
      margin: const EdgeInsets.only(bottom: glassListTileGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 78, child: _VisitorDynamicDate(item: item)),
          const SizedBox(width: 16),
          Expanded(child: _VisitorDynamicPreview(item: item)),
        ],
      ),
    );
  }
}

class _VisitorDynamicDate extends StatelessWidget {
  const _VisitorDynamicDate({required this.item});

  final MockContactDynamic item;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (item.day.isEmpty) {
      return Text(
        item.month,
        style: AppTheme.sans(
          size: 22,
          weight: FontWeight.w700,
          color: t.text,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.month, style: AppTheme.sans(size: 13, color: t.text)),
        Text(
          item.day,
          style: AppTheme.sans(
            size: 26,
            weight: FontWeight.w700,
            color: t.text,
          ),
        ),
      ],
    );
  }
}

class _VisitorDynamicPreview extends StatelessWidget {
  const _VisitorDynamicPreview({required this.item});

  final MockContactDynamic item;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.sans(
            size: 17,
            weight: FontWeight.w500,
            color: t.text,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Color(item.previewColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Symbols.image, color: t.textMute, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(size: 13, color: t.textMute).copyWith(
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VisitorEmptyLine extends StatelessWidget {
  const _VisitorEmptyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(text, style: AppTheme.sans(size: 13, color: t.textMute)),
      ),
    );
  }
}

class _ContactHomeEmpty extends StatelessWidget {
  const _ContactHomeEmpty();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Text(
        '联系人主页不存在',
        style: AppTheme.sans(size: 14, color: t.textMute),
      ),
    );
  }
}

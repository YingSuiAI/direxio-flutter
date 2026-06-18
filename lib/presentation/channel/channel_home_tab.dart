import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../providers/local_created_channels_provider.dart';
import '../utils/avatar_url.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/portal_avatar.dart';
import 'channel_inbox_data.dart';
import 'create_channel_sheet.dart';

const _mockAuthEnabled = bool.fromEnvironment(
  'P2P_MATRIX_MOCK_AUTH',
  defaultValue: false,
);
const _channelBg = Color(0xFFFAFAFA);
const _channelText = Color(0xFF262628);
const _channelMuted = Color(0xFFA3A3A4);
const _channelBorder = Color(0xFFE6E6E6);

final _channelListProvider = FutureProvider.autoDispose<List<AsChannel>>((ref) {
  return ref.read(asClientProvider).listChannels();
});

final _hiddenChannelListKeysProvider = StateProvider<Set<String>>(
  (ref) => const <String>{},
);

final _channelPendingReviewCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final channels = await ref.watch(_channelListProvider.future);
  var count = 0;
  for (final channel in channels.where(_canReviewChannel)) {
    final channelId = channel.channelId.trim().isEmpty
        ? channel.roomId.trim()
        : channel.channelId.trim();
    if (channelId.isEmpty) continue;
    final members = await ref.read(asClientProvider).getChannelMembers(
          channelId,
          status: asChannelMemberStatusPending,
        );
    count += members
        .where((member) => member.status == asChannelMemberStatusPending)
        .length;
  }
  return count;
});

class ChannelExplorePage extends ConsumerStatefulWidget {
  const ChannelExplorePage({super.key});

  @override
  ConsumerState<ChannelExplorePage> createState() => _ChannelExplorePageState();
}

class _ChannelExplorePageState extends ConsumerState<ChannelExplorePage> {
  @override
  Widget build(BuildContext context) {
    final client = ref.watch(matrixClientProvider);
    final isLoggedIn = client.isLogged();
    final auth = ref.watch(authStateNotifierProvider).valueOrNull;
    final syncCache = asSyncCacheForUser(
      ref.watch(asSyncCacheProvider),
      auth?.userId,
    );
    final bootstrap = syncCache.bootstrap;
    final useRealChannels = !_mockAuthEnabled && isLoggedIn;
    final listedChannels =
        useRealChannels ? ref.watch(_channelListProvider).valueOrNull : null;
    final localCreatedChannels = useRealChannels
        ? ref.watch(localCreatedChannelsProvider)
        : const <ChannelCreatedCacheEntry>[];
    final hiddenChannelKeys = ref.watch(_hiddenChannelListKeysProvider);
    final pinnedChannelKeys = ref.watch(pinnedConversationIdsProvider);
    final fallbackDomain = _clientServerName(client);
    final syncHiddenChannelKeys = _hiddenChannelKeys(syncCache);
    final sourceChannels = useRealChannels
        ? ChannelInboxData.mergeCreatedCache(
            listedChannels == null
                ? bootstrap == null
                    ? const <ChannelInboxItem>[]
                    : ChannelInboxData.fromBootstrap(
                        bootstrap,
                        fallbackDomain: fallbackDomain,
                        roomNameForRoomId: (roomId) =>
                            _matrixRoomName(client, roomId),
                        roomAvatarForRoomId: (roomId) =>
                            _matrixRoomAvatar(client, roomId),
                      )
                : ChannelInboxData.fromChannels(
                    listedChannels,
                    fallbackDomain: fallbackDomain,
                    bootstrap: bootstrap,
                    roomNameForRoomId: (roomId) =>
                        _matrixRoomName(client, roomId),
                    roomAvatarForRoomId: (roomId) =>
                        _matrixRoomAvatar(client, roomId),
                  ),
            localCreatedChannels,
            fallbackDomain: fallbackDomain,
            roomNameForRoomId: (roomId) => _matrixRoomName(client, roomId),
            roomAvatarForRoomId: (roomId) => _matrixRoomAvatar(client, roomId),
            hiddenChannelKeys: syncHiddenChannelKeys,
          )
        : _mockChannelItems();
    final visibleSourceChannels = _sortPinnedChannels(
      sourceChannels
          .where((channel) =>
              !_channelHiddenKeysContain(hiddenChannelKeys, channel))
          .toList(growable: false),
      pinnedChannelKeys,
    );
    final visibleChannels = visibleSourceChannels
        .where((channel) => !_channelIsDissolved(channel))
        .toList(growable: false);
    final activeChannelKeys = _activeChannelKeys(
      syncCache,
      localCreatedChannels,
    );
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final pendingReviewCount = useRealChannels
        ? ref.watch(_channelPendingReviewCountProvider).valueOrNull ??
            _channelPendingCount(sourceChannels)
        : _channelPendingCount(sourceChannels);

    if (useRealChannels && bootstrap == null && listedChannels == null) {
      return const _ChannelFrame(
        child: Center(
          child: _ChannelEmpty(
            icon: Symbols.sync,
            title: '正在同步频道',
            subtitle: '请稍候',
          ),
        ),
      );
    }

    final topInset = MediaQuery.of(context).padding.top;
    return _ChannelFrame(
      child: Stack(
        children: [
          Positioned(
            left: 24,
            top: topInset + 22,
            width: 140,
            height: 34,
            child: Text(
              key: const ValueKey('channel_tab_title'),
              l10n?.tabChannels ?? '频道',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 20,
                weight: FontWeight.w600,
                color: _channelTextColor(context),
              ).copyWith(height: 25 / 20),
            ),
          ),
          Positioned(
            right: 16,
            top: topInset + 20,
            child: Row(
              children: [
                _ChannelIconButton(
                  key: const ValueKey('channel_review_button'),
                  assetName: 'assets/images/channel_review_button.png',
                  badgeCount: pendingReviewCount,
                  onTap: () async {
                    await context.push('/channels/review');
                    if (!context.mounted) return;
                    ref.invalidate(_channelPendingReviewCountProvider);
                    ref.invalidate(_channelListProvider);
                  },
                ),
                const SizedBox(width: 8),
                _ChannelIconButton(
                  key: const ValueKey('channel_search_button'),
                  assetName: 'assets/images/search_icon.png',
                  iconSize: 20,
                  onTap: () => context.push('/channels/search'),
                ),
              ],
            ),
          ),
          Positioned.fill(
            top: topInset + 76,
            child: visibleChannels.isEmpty
                ? const _ChannelEmptyArea()
                : ChannelInboxList(
                    key: const ValueKey('channel_inbox_all'),
                    storageKey: const PageStorageKey(
                      'channel_inbox_scroll_all',
                    ),
                    channels: visibleChannels,
                    onTapChannel: (channel) => _openChannelInboxItem(
                      context,
                      channel,
                      validateExists: useRealChannels && bootstrap != null,
                      activeChannelKeys: activeChannelKeys,
                    ),
                    pinnedChannelKeys: pinnedChannelKeys,
                    onTogglePin: (channel) =>
                        _toggleChannelListPin(ref, channel),
                    onHide: (channel) => _hideChannelListItem(ref, channel),
                    onDelete: (channel) => _deleteChannelListItem(ref, channel),
                  ),
          ),
          Positioned(
            right: 24,
            bottom: 56,
            child: _ChannelCreateButton(
              key: const ValueKey('channel_post_button'),
              onTap: () => showCreateChannelDialog(
                context,
                ref,
                onCreated: () => ref.invalidate(_channelListProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChannelReviewPage extends ConsumerStatefulWidget {
  const ChannelReviewPage({super.key});

  @override
  ConsumerState<ChannelReviewPage> createState() => _ChannelReviewPageState();
}

class MeChannelsPage extends ConsumerStatefulWidget {
  const MeChannelsPage({super.key});

  @override
  ConsumerState<MeChannelsPage> createState() => _MeChannelsPageState();
}

class _MeChannelsPageState extends ConsumerState<MeChannelsPage> {
  String _section = '我创建';

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(matrixClientProvider);
    final auth = ref.watch(authStateNotifierProvider).valueOrNull;
    final syncCache = asSyncCacheForUser(
      ref.watch(asSyncCacheProvider),
      auth?.userId,
    );
    final bootstrap = syncCache.bootstrap;
    final localCreatedChannels = ref.watch(localCreatedChannelsProvider);
    final hiddenChannelKeys = ref.watch(_hiddenChannelListKeysProvider);
    final pinnedChannelKeys = ref.watch(pinnedConversationIdsProvider);
    final syncHiddenChannelKeys = _hiddenChannelKeys(syncCache);
    final channels = bootstrap == null
        ? ChannelInboxData.mergeCreatedCache(
            const <ChannelInboxItem>[],
            localCreatedChannels,
            fallbackDomain: _clientServerName(client),
            roomNameForRoomId: (roomId) => _matrixRoomName(client, roomId),
            roomAvatarForRoomId: (roomId) => _matrixRoomAvatar(client, roomId),
          )
        : ChannelInboxData.mergeCreatedCache(
            ChannelInboxData.fromBootstrap(
              bootstrap,
              fallbackDomain: _clientServerName(client),
              roomNameForRoomId: (roomId) => _matrixRoomName(client, roomId),
              roomAvatarForRoomId: (roomId) =>
                  _matrixRoomAvatar(client, roomId),
            ),
            localCreatedChannels,
            fallbackDomain: _clientServerName(client),
            roomNameForRoomId: (roomId) => _matrixRoomName(client, roomId),
            roomAvatarForRoomId: (roomId) => _matrixRoomAvatar(client, roomId),
            hiddenChannelKeys: syncHiddenChannelKeys,
          );
    final filteredChannels = channels.where((channel) {
      final hidden = _channelHiddenKeysContain(hiddenChannelKeys, channel);
      if (hidden) return false;
      return _section == '我创建' ? channel.isOwned : !channel.isOwned;
    }).toList(growable: false);
    final visibleChannels = _sortPinnedChannels(
      filteredChannels,
      pinnedChannelKeys,
    );

    return Scaffold(
      backgroundColor: _channelBgColor(context),
      body: Column(
        children: [
          GlassHeader.detail(title: '我的频道'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: _MeChannelSectionSwitch(
              value: _section,
              onChanged: (value) => setState(() => _section = value),
            ),
          ),
          Expanded(
            child: bootstrap == null
                ? const _ChannelEmpty(
                    icon: Symbols.sync,
                    title: '正在同步频道',
                    subtitle: '请稍候',
                  )
                : visibleChannels.isEmpty
                    ? _ChannelEmpty(
                        icon: Symbols.forum,
                        title: _section == '我创建' ? '暂无我创建的频道' : '暂无已加入频道',
                        subtitle:
                            _section == '我创建' ? '创建的频道会显示在这里' : '加入的频道会显示在这里',
                      )
                    : ChannelInboxList(
                        storageKey: const PageStorageKey('me_channels'),
                        channels: visibleChannels,
                        bottomPadding: 24,
                        showTime: false,
                        pinnedChannelKeys: pinnedChannelKeys,
                        onTogglePin: (channel) =>
                            _toggleChannelListPin(ref, channel),
                        onHide: (channel) => _hideChannelListItem(ref, channel),
                        onDelete: (channel) =>
                            _deleteChannelListItem(ref, channel),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ChannelReviewPageState extends ConsumerState<ChannelReviewPage> {
  late Future<List<_ReviewItem>> _future;
  List<_ReviewItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _future = _loadAndSetReviewItems();
  }

  Future<List<_ReviewItem>> _loadAndSetReviewItems() async {
    final items = await _loadReviewItems();
    if (mounted) {
      setState(() => _items = items);
    }
    return items;
  }

  Future<List<_ReviewItem>> _loadReviewItems() async {
    final listedChannels = await ref.read(asClientProvider).listChannels();
    final ownedChannels = listedChannels.where(_canReviewChannel).toList(
          growable: false,
        );
    final items = <_ReviewItem>[];
    for (final channel in ownedChannels) {
      final channelId = channel.channelId.trim().isEmpty
          ? channel.roomId.trim()
          : channel.channelId.trim();
      if (channelId.isEmpty) continue;
      final members = await ref
          .read(asClientProvider)
          .getChannelMembers(channelId, status: asChannelMemberStatusPending);
      for (final member in members) {
        if (member.status != asChannelMemberStatusPending) continue;
        items.add(
          _ReviewItem(
            channelId: channelId,
            channelName: channel.name.trim().isEmpty ? '未命名频道' : channel.name,
            userMxid: member.userMxid,
            name: member.displayName.trim().isEmpty
                ? _localpartFromMxid(member.userMxid)
                : member.displayName.trim(),
            time: _formatReviewTime(member.joinedAtMs),
            status: _ReviewStatus.pending,
          ),
        );
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _channelBgColor(context),
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _ReviewTopBar(
              topInset: topInset,
              pendingCount: _items
                  .where((item) => item.status == _ReviewStatus.pending)
                  .length,
              onBack: () => context.pop(),
            ),
          ),
          Positioned.fill(
            top: topInset + 83,
            child: FutureBuilder<List<_ReviewItem>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const _ChannelEmpty(
                    icon: Symbols.error,
                    title: '审核加载失败',
                    subtitle: '请稍后重试',
                  );
                }
                if (_items.isEmpty) {
                  return const _ChannelEmpty(
                    icon: Symbols.check_circle,
                    title: '暂无加入申请',
                    subtitle: '新的频道加入申请会显示在这里',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _ReviewCard(
                      item: item,
                      onApprove: () => _resolve(index, _ReviewStatus.approved),
                      onReject: () => _resolve(index, _ReviewStatus.rejected),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolve(int index, _ReviewStatus status) async {
    final item = _items[index];
    try {
      if (status == _ReviewStatus.approved) {
        await ref
            .read(asClientProvider)
            .approveChannelJoin(item.channelId, item.userMxid);
      } else if (status == _ReviewStatus.rejected) {
        await ref
            .read(asClientProvider)
            .rejectChannelJoin(item.channelId, item.userMxid);
      }
      setState(() {
        _items[index] = item.copyWith(status: status);
      });
      ref.invalidate(_channelPendingReviewCountProvider);
      ref.invalidate(_channelListProvider);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                status == _ReviewStatus.approved ? '同意失败：$err' : '拒绝失败：$err')),
      );
    }
  }
}

bool _canReviewChannel(AsChannel channel) {
  return channel.role == asChannelRoleOwner ||
      channel.role == asChannelRoleAdmin ||
      channel.pendingJoinCount > 0;
}

class _ReviewTopBar extends StatelessWidget {
  const _ReviewTopBar({
    required this.topInset,
    required this.pendingCount,
    required this.onBack,
  });

  final double topInset;
  final int pendingCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: topInset + 70,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 16,
              top: 6,
              child: _GlassRoundButton(
                icon: Symbols.arrow_back,
                onTap: onBack,
              ),
            ),
            Text(
              '频道审核',
              style: AppTheme.sans(
                size: 20,
                weight: FontWeight.w600,
                color: _channelTextColor(context),
              ).copyWith(height: 25 / 20),
            ),
            Positioned(
              right: 30,
              top: 12,
              child: _ReviewCounter(count: pendingCount),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  final _ReviewItem item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final pending = item.status == _ReviewStatus.pending;
    return Container(
      height: pending ? 118 : 64,
      decoration: BoxDecoration(
        color: _channelSurfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _channelCardShadowColor(context),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 14,
            top: 14,
            child: _ReviewAvatar(size: 44),
          ),
          Positioned(
            left: 64,
            top: 17,
            right: 96,
            child: Text(
              '#${item.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 14,
                weight: FontWeight.w500,
                color: _channelTextColor(context),
              ),
            ),
          ),
          Positioned(
            left: 64,
            top: 39,
            right: 96,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    item.channelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 12,
                      weight: FontWeight.w500,
                      color: _channelMutedColor(context),
                    ).copyWith(height: 16 / 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.time,
                  style: AppTheme.sans(
                    size: 12,
                    weight: FontWeight.w500,
                    color: pending
                        ? _channelPendingTimeColor(context)
                        : _channelMutedColor(context),
                  ).copyWith(height: 16 / 12),
                ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            top: 14,
            child: _ReviewStatusPill(status: item.status),
          ),
          if (pending) ...[
            Positioned(
              left: 18,
              right: 184,
              bottom: 14,
              height: 34,
              child: _ReviewActionButton(
                label: '通过',
                foreground: context.tk.onAccent,
                background: context.tk.accent,
                onTap: onApprove,
              ),
            ),
            Positioned(
              left: 184,
              right: 18,
              bottom: 14,
              height: 34,
              child: _ReviewActionButton(
                label: '拒绝',
                foreground: _channelMutedColor(context),
                background: _channelSoftFillColor(context),
                onTap: onReject,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChannelFrame extends StatelessWidget {
  const _ChannelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: _channelBgColor(context), child: child);
  }
}

class _MeChannelSectionSwitch extends StatelessWidget {
  const _MeChannelSectionSwitch({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: context.tk.surfaceHover,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          for (final label in _meChannelSections)
            Expanded(
              child: _MeChannelSectionSegment(
                label: label,
                selected: label == value,
                onTap: () {
                  if (label == value) return;
                  onChanged(label);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MeChannelSectionSegment extends StatelessWidget {
  const _MeChannelSectionSegment({
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
      color: selected ? context.tk.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: Center(
          child: Text(
            label,
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w500,
              color: selected ? context.tk.text : context.tk.textMute,
            ).copyWith(height: 16 / 13),
          ),
        ),
      ),
    );
  }
}

class _ChannelIconButton extends StatelessWidget {
  const _ChannelIconButton({
    super.key,
    required this.onTap,
    required this.assetName,
    this.badgeCount = 0,
    this.iconSize = 24,
  });

  final String assetName;
  final VoidCallback onTap;
  final int badgeCount;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Image.asset(
                  assetName,
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  color: _channelTextColor(context),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _ChannelActionBadge(count: badgeCount),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelActionBadge extends StatelessWidget {
  const _ChannelActionBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.tk.danger,
        shape: BoxShape.circle,
      ),
      child: Text(
        _formatBadgeCount(count),
        style: AppTheme.sans(
          size: 10,
          weight: FontWeight.w700,
          color: context.tk.onAccent,
        ),
      ),
    );
  }
}

class _ChannelCreateButton extends StatelessWidget {
  const _ChannelCreateButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tk.accent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 56,
          child: Icon(
            Symbols.add,
            size: 30,
            color: context.tk.onAccent,
            weight: 700,
          ),
        ),
      ),
    );
  }
}

class ChannelInboxList extends StatelessWidget {
  const ChannelInboxList({
    super.key,
    required this.storageKey,
    required this.channels,
    this.onTapChannel,
    this.pinnedChannelKeys = const <String>{},
    this.onTogglePin,
    this.onHide,
    this.onDelete,
    this.showTime = true,
    this.bottomPadding = 104,
  });

  final PageStorageKey<String> storageKey;
  final List<ChannelInboxItem> channels;
  final ValueChanged<ChannelInboxItem>? onTapChannel;
  final Set<String> pinnedChannelKeys;
  final ValueChanged<ChannelInboxItem>? onTogglePin;
  final ValueChanged<ChannelInboxItem>? onHide;
  final ValueChanged<ChannelInboxItem>? onDelete;
  final bool showTime;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: storageKey,
      padding: EdgeInsets.only(bottom: bottomPadding),
      itemCount: channels.length,
      itemBuilder: (context, index) => ChannelInboxTile(
        key: ValueKey('channel_inbox_tile_${channels[index].id}'),
        channel: channels[index],
        showDivider: index != channels.length - 1,
        onTap: onTapChannel,
        isPinned: _channelPinnedKeysContain(pinnedChannelKeys, channels[index]),
        onTogglePin: onTogglePin,
        onHide: onHide,
        onDelete: onDelete,
        showTime: showTime,
      ),
    );
  }
}

class ChannelInboxTile extends StatelessWidget {
  const ChannelInboxTile({
    super.key,
    required this.channel,
    required this.showDivider,
    this.onTap,
    this.isPinned = false,
    this.onTogglePin,
    this.onHide,
    this.onDelete,
    this.showTime = true,
  });

  final ChannelInboxItem channel;
  final bool showDivider;
  final ValueChanged<ChannelInboxItem>? onTap;
  final bool isPinned;
  final ValueChanged<ChannelInboxItem>? onTogglePin;
  final ValueChanged<ChannelInboxItem>? onHide;
  final ValueChanged<ChannelInboxItem>? onDelete;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final channelId = channel.id.trim();
    Offset menuPosition = Offset.zero;
    return GestureDetector(
      onSecondaryTapDown: (details) => menuPosition = details.globalPosition,
      onSecondaryTap: () => _showChannelInboxMenu(
        context,
        menuPosition,
        channel,
        isPinned: isPinned,
        onTogglePin: onTogglePin,
        onHide: onHide,
        onDelete: onDelete,
      ),
      onLongPressStart: (details) {
        menuPosition = details.globalPosition;
        _showChannelInboxMenu(
          context,
          menuPosition,
          channel,
          isPinned: isPinned,
          onTogglePin: onTogglePin,
          onHide: onHide,
          onDelete: onDelete,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: channelId.isEmpty
              ? null
              : () {
                  final handler = onTap;
                  if (handler == null) {
                    context.push(_channelRoute(channel));
                    return;
                  }
                  handler(channel);
                },
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 16),
                _ChannelAvatar(channel: channel, size: 42),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: showDivider
                          ? Border(
                              bottom: BorderSide(
                                color: _channelBorderColor(context),
                                width: 0.5,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 21),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    channel.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.sans(
                                      size: 14,
                                      weight: FontWeight.w500,
                                      color: _channelTextColor(context),
                                    ).copyWith(height: 18 / 14),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _ChannelKindBadge(
                                  label:
                                      _channelIsTextType(channel) ? '文字' : '帖子',
                                ),
                                if (isPinned) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Symbols.push_pin,
                                    size: 14,
                                    color: _channelMutedColor(context),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 50,
                          height: 64,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 11),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (showTime)
                                  Text(
                                    _formatChannelTime(channel.latestAt),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: AppTheme.sans(
                                      size: 12,
                                      weight: FontWeight.w500,
                                      color: _channelMutedColor(context),
                                    ).copyWith(height: 15 / 12),
                                  ),
                                const Spacer(),
                                if (_channelIsTextType(channel) &&
                                    channel.unreadCount > 0)
                                  _UnreadBadge(
                                    key: ValueKey(
                                      'channel_unread_count_${channel.id}',
                                    ),
                                    count: channel.unreadCount,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelKindBadge extends StatelessWidget {
  const _ChannelKindBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _channelKindBadgeBgColor(context),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTheme.sans(
          size: 8,
          weight: FontWeight.w500,
          color: _channelKindBadgeTextColor(context),
        ).copyWith(height: 10 / 8),
      ),
    );
  }
}

class _ChannelAvatar extends ConsumerWidget {
  const _ChannelAvatar({required this.channel, required this.size});

  final ChannelInboxItem channel;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = avatarHttpUrl(
      ref.watch(matrixClientProvider),
      channel.avatarUrl,
    );
    if (imageUrl != null) {
      return PortalAvatar(
        seed: channel.name,
        size: size,
        imageUrl: imageUrl,
        shape: AvatarShape.squircle,
      );
    }
    final label = _avatarLabel(channel.name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _channelAvatarColor(context, channel),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTheme.sans(
          size: 15,
          weight: FontWeight.w600,
          color: context.tk.accent,
        ).copyWith(height: 19 / 15),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = _formatBadgeCount(count);
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.tk.danger,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: AppTheme.sans(
          size: label.length > 2 ? 8 : 11,
          weight: FontWeight.w700,
          color: context.tk.onAccent,
        ).copyWith(height: 1),
      ),
    );
  }
}

class _ChannelEmptyArea extends StatelessWidget {
  const _ChannelEmptyArea();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: _ChannelEmpty(
        icon: Symbols.campaign,
        title: '还没有频道',
        subtitle: '加入或创建频道后会显示在这里',
      ),
    );
  }
}

class _ChannelEmpty extends StatelessWidget {
  const _ChannelEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: t.textMute),
        const SizedBox(height: 10),
        Text(title, style: AppTheme.sans(size: 15, color: t.text)),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTheme.sans(size: 12, color: t.textMute)),
      ],
    );
  }
}

class _ReviewAvatar extends StatelessWidget {
  const _ReviewAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  context.tk.secondaryContainer,
                  context.tk.accent.withValues(alpha: 0.72),
                ]
              : const [Color(0xFFE7F0FF), Color(0xFF76A7FF)],
        ),
      ),
      child: Icon(
        Symbols.person,
        color: dark ? context.tk.onPrimaryContainer : const Color(0xFF5C8CFF),
        size: 28,
        fill: 1,
      ),
    );
  }
}

class _ReviewStatusPill extends StatelessWidget {
  const _ReviewStatusPill({required this.status});

  final _ReviewStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      _ReviewStatus.pending => (
          '待审核',
          _channelStatusBgColor(context, _ReviewStatus.pending),
          _channelStatusTextColor(context, _ReviewStatus.pending),
        ),
      _ReviewStatus.approved => (
          '已通过',
          _channelStatusBgColor(context, _ReviewStatus.approved),
          _channelStatusTextColor(context, _ReviewStatus.approved),
        ),
      _ReviewStatus.rejected => (
          '已拒绝',
          _channelStatusBgColor(context, _ReviewStatus.rejected),
          _channelStatusTextColor(context, _ReviewStatus.rejected),
        ),
    };
    return Container(
      width: 56,
      height: 25,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(
        label,
        style: AppTheme.sans(size: 12, weight: FontWeight.w500, color: fg)
            .copyWith(height: 16 / 12),
      ),
    );
  }
}

class _ReviewActionButton extends StatelessWidget {
  const _ReviewActionButton({
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            style: AppTheme.sans(
              size: 15,
              weight: FontWeight.w500,
              color: foreground,
            ).copyWith(height: 20 / 15),
          ),
        ),
      ),
    );
  }
}

class _ReviewCounter extends StatelessWidget {
  const _ReviewCounter({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _channelSelectedFilterBgColor(context),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: AppTheme.sans(
          size: 15,
          weight: FontWeight.w600,
          color: context.tk.accent,
        ),
      ),
    );
  }
}

class _GlassRoundButton extends StatelessWidget {
  const _GlassRoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _channelGlassColor(context),
      shape: const CircleBorder(),
      elevation: 12,
      shadowColor: _channelGlassShadowColor(context),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 40,
          child: Icon(icon, size: 24, color: _channelTextColor(context)),
        ),
      ),
    );
  }
}

enum _ReviewStatus { pending, approved, rejected }

class _ReviewItem {
  const _ReviewItem({
    required this.channelId,
    required this.channelName,
    required this.userMxid,
    required this.name,
    required this.time,
    required this.status,
  });

  final String channelId;
  final String channelName;
  final String userMxid;
  final String name;
  final String time;
  final _ReviewStatus status;

  _ReviewItem copyWith({_ReviewStatus? status}) {
    return _ReviewItem(
      channelId: channelId,
      channelName: channelName,
      userMxid: userMxid,
      name: name,
      time: time,
      status: status ?? this.status,
    );
  }
}

const _meChannelSections = ['已加入', '我创建'];

bool _channelIsTextType(ChannelInboxItem channel) {
  return normalizeAsChannelType(channel.channelType) == asChannelTypeChat;
}

String _channelRoute(ChannelInboxItem channel) {
  final channelId = Uri.encodeComponent(channel.id.trim());
  if (!_channelIsTextType(channel)) return '/channel/$channelId';
  final name = channel.name.trim();
  final query = name.isEmpty ? '' : '?name=${Uri.encodeQueryComponent(name)}';
  return '/channel/$channelId/conversation$query';
}

void _showChannelInboxMenu(
  BuildContext context,
  Offset position,
  ChannelInboxItem channel, {
  required bool isPinned,
  ValueChanged<ChannelInboxItem>? onTogglePin,
  ValueChanged<ChannelInboxItem>? onHide,
  ValueChanged<ChannelInboxItem>? onDelete,
}) {
  if (onTogglePin == null && onHide == null && onDelete == null) return;
  final size = MediaQuery.of(context).size;
  const menuWidth = 176.0;
  const menuHeight = 148.0;
  var left = position.dx;
  var top = position.dy;
  if (left + menuWidth > size.width - 8) left = size.width - menuWidth - 8;
  if (top + menuHeight > size.height - 8) top = size.height - menuHeight - 8;
  if (left < 8) left = 8;
  if (top < 8) top = 8;

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'channel-inbox-menu',
    barrierColor: Colors.black.withValues(alpha: 0.15),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (dialogContext, _, __) => Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: menuWidth,
          child: _ChannelInboxMenuCard(
            channel: channel,
            isPinned: isPinned,
            onTogglePin: onTogglePin,
            onHide: onHide,
            onDelete: onDelete,
          ),
        ),
      ],
    ),
    transitionBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _ChannelInboxMenuCard extends StatelessWidget {
  const _ChannelInboxMenuCard({
    required this.channel,
    required this.isPinned,
    this.onTogglePin,
    this.onHide,
    this.onDelete,
  });

  final ChannelInboxItem channel;
  final bool isPinned;
  final ValueChanged<ChannelInboxItem>? onTogglePin;
  final ValueChanged<ChannelInboxItem>? onHide;
  final ValueChanged<ChannelInboxItem>? onDelete;

  static const _dark = Color(0xFF1E2026); // theme-fixed
  static const _divider = Color(0x1AFFFFFF); // theme-fixed
  static const _icon = Color(0xB3FFFFFF); // theme-fixed
  static const _label = Colors.white; // theme-fixed
  static const _danger = Color(0xFFFF6B6B); // theme-fixed

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: _dark,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(
              context,
              isPinned ? Symbols.keep_off : Symbols.push_pin,
              isPinned ? '取消置顶' : '置顶',
              () {
                Navigator.of(context).pop();
                onTogglePin?.call(channel);
                _toast(
                  context,
                  isPinned ? '已取消置顶「${channel.name}」' : '已置顶「${channel.name}」',
                );
              },
            ),
            const Divider(
              height: 1,
              color: _divider,
              indent: 16,
              endIndent: 16,
            ),
            _row(context, Symbols.visibility_off, '不显示', () {
              Navigator.of(context).pop();
              onHide?.call(channel);
              _toast(context, '已隐藏「${channel.name}」');
            }),
            const Divider(
              height: 1,
              color: _divider,
              indent: 16,
              endIndent: 16,
            ),
            _row(context, Symbols.delete, '删除频道', () {
              Navigator.of(context).pop();
              onDelete?.call(channel);
              _toast(context, '已删除「${channel.name}」');
            }, danger: true),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color = danger ? _danger : _label;
    final iconColor = danger ? _danger : _icon;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 12),
            Text(label, style: AppTheme.sans(size: 15, color: color)),
          ],
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
  );
}

void _openChannelInboxItem(
  BuildContext context,
  ChannelInboxItem channel, {
  required bool validateExists,
  required Set<String> activeChannelKeys,
}) {
  if (_channelIsDissolved(channel) ||
      (validateExists &&
          !_activeChannelKeysContain(activeChannelKeys, channel))) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('频道已经解散')));
    return;
  }
  context.push(_channelRoute(channel));
}

Set<String> _activeChannelKeys(
  AsSyncCacheState syncCache,
  List<ChannelCreatedCacheEntry> localCreatedChannels,
) {
  final keys = <String>{};
  for (final channel in syncCache.bootstrap?.channels ?? const []) {
    if (_channelStatusIsDissolved(channel.memberStatus)) continue;
    _addChannelKeys(keys, channel.channelId, channel.roomId);
  }
  for (final entry in localCreatedChannels) {
    _addChannelKeys(
      keys,
      entry.channel.channelId,
      entry.channel.roomId,
    );
  }
  return keys;
}

List<ChannelInboxItem> _sortPinnedChannels(
  List<ChannelInboxItem> channels,
  Set<String> pinnedChannelKeys,
) {
  final sorted = [...channels]..sort((a, b) {
      final aPinned = _channelPinnedKeysContain(pinnedChannelKeys, a);
      final bPinned = _channelPinnedKeysContain(pinnedChannelKeys, b);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      return 0;
    });
  return sorted;
}

void _toggleChannelListPin(WidgetRef ref, ChannelInboxItem channel) {
  final key = _channelPreferenceKey(channel);
  if (key.isEmpty) return;
  toggleConversationPin(ref, key);
}

void _hideChannelListItem(WidgetRef ref, ChannelInboxItem channel) {
  _updateHiddenChannelListKeys(ref, channel);
}

void _deleteChannelListItem(WidgetRef ref, ChannelInboxItem channel) {
  _updateHiddenChannelListKeys(ref, channel);
  final key = _channelPreferenceKey(channel);
  if (key.isNotEmpty) unpinConversation(ref, key);
}

void _updateHiddenChannelListKeys(WidgetRef ref, ChannelInboxItem channel) {
  final keys = _channelListKeys(channel);
  if (keys.isEmpty) return;
  ref.read(_hiddenChannelListKeysProvider.notifier).update(
        (current) => {...current, ...keys},
      );
}

bool _channelHiddenKeysContain(
  Set<String> hiddenChannelKeys,
  ChannelInboxItem channel,
) {
  return _channelListKeys(channel).any(hiddenChannelKeys.contains);
}

bool _channelPinnedKeysContain(
  Set<String> pinnedChannelKeys,
  ChannelInboxItem channel,
) {
  final key = _channelPreferenceKey(channel);
  return key.isNotEmpty && pinnedChannelKeys.contains(key);
}

String _channelPreferenceKey(ChannelInboxItem channel) {
  final roomId = channel.roomId.trim();
  if (roomId.isNotEmpty) return roomId;
  return channel.id.trim();
}

Set<String> _channelListKeys(ChannelInboxItem channel) {
  final keys = <String>{};
  final channelId = channel.id.trim();
  final roomId = channel.roomId.trim();
  if (channelId.isNotEmpty) keys.add(channelId);
  if (roomId.isNotEmpty) keys.add(roomId);
  return keys;
}

Set<String> _hiddenChannelKeys(AsSyncCacheState syncCache) {
  final keys = <String>{};
  for (final channel in syncCache.bootstrap?.channels ?? const []) {
    if (!_channelStatusIsDissolved(channel.memberStatus)) continue;
    _addChannelKeys(keys, channel.channelId, channel.roomId);
  }
  return keys;
}

bool _channelIsDissolved(ChannelInboxItem channel) {
  return _channelStatusIsDissolved(channel.memberStatus);
}

bool _channelStatusIsDissolved(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'removed' ||
      normalized == 'left' ||
      normalized == 'dissolved' ||
      normalized == 'deleted' ||
      normalized == 'closed';
}

bool _activeChannelKeysContain(
  Set<String> keys,
  ChannelInboxItem channel,
) {
  final id = channel.id.trim();
  final roomId = channel.roomId.trim();
  return keys.contains('channel:$id') ||
      keys.contains('room:$id') ||
      keys.contains('room:$roomId');
}

void _addChannelKeys(Set<String> keys, String channelId, String roomId) {
  final trimmedChannelId = channelId.trim();
  if (trimmedChannelId.isNotEmpty) keys.add('channel:$trimmedChannelId');
  final trimmedRoomId = roomId.trim();
  if (trimmedRoomId.isNotEmpty) keys.add('room:$trimmedRoomId');
}

int _channelPendingCount(List<ChannelInboxItem> channels) {
  return channels.fold<int>(
    0,
    (sum, channel) => sum + channel.pendingJoinCount,
  );
}

List<ChannelInboxItem> _mockChannelItems() {
  return [
    ChannelInboxItem(
      id: 'owner',
      roomId: 'owner',
      name: 'owner',
      domain: 'p2p-im.com',
      avatarUrl: '',
      latestPreview: '后端部署清单已更新：个人资料、二维码加好友...',
      latestAt: _todayAt(18, 40),
      unreadCount: 7,
      isOwned: true,
      channelType: asChannelTypeChat,
      tags: const ['文字'],
      pendingJoinCount: 1,
    ),
    ChannelInboxItem(
      id: 'p2p-im',
      roomId: 'p2p-im',
      name: 'P2P IM 官方',
      domain: 'p2p-im.com',
      avatarUrl: '',
      latestPreview: '后端部署清单已更新：个人资料、二维码加好友...',
      latestAt: _todayAt(18, 40),
      unreadCount: 3,
      isOwned: true,
      channelType: asChannelTypePost,
      tags: const ['帖子', '产品'],
    ),
    ChannelInboxItem(
      id: 'ai-studio',
      roomId: 'ai-studio',
      name: 'AI 创作实验室',
      domain: 'p2p-im.com',
      avatarUrl: '',
      latestPreview: '短视频脚本生成流程已整理',
      latestAt: _todayAt(13, 20),
      unreadCount: 1,
      isOwned: true,
      channelType: asChannelTypePost,
      tags: const ['帖子', 'AI'],
    ),
    ChannelInboxItem(
      id: 'agent-workflows',
      roomId: 'agent-workflows',
      name: 'Agent 工作流',
      domain: 'agent-workflows.p2p-im.com',
      avatarUrl: '',
      latestPreview: '有人分享了群聊总结模板',
      latestAt: _todayAt(18, 12),
      unreadCount: 8,
      isOwned: false,
      channelType: asChannelTypePost,
      tags: const ['帖子', 'AI'],
    ),
    ChannelInboxItem(
      id: 'drafts',
      roomId: 'drafts',
      name: '草稿箱',
      domain: 'p2p-im.com',
      avatarUrl: '',
      latestPreview: '2 条帖子待发布',
      latestAt: DateTime.now().subtract(const Duration(days: 5)),
      unreadCount: 0,
      isOwned: true,
      channelType: asChannelTypeChat,
      tags: const ['文字'],
    ),
    ChannelInboxItem(
      id: 'joined-general',
      roomId: 'joined-general',
      name: '综合讨论',
      domain: 'p2p-im.com',
      avatarUrl: '',
      latestPreview: '自由讨论、技术交流与闲聊',
      latestAt: _todayAt(9, 15),
      unreadCount: 0,
      isOwned: false,
      channelType: asChannelTypeChat,
      tags: const ['文字'],
    ),
  ];
}

String _avatarLabel(String name) {
  if (name.toLowerCase().contains('agent')) return 'AI';
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '频';
  return trimmed.characters.first;
}

Color _channelAvatarColor(BuildContext context, ChannelInboxItem channel) {
  if (Theme.of(context).brightness == Brightness.dark) {
    return context.tk.secondaryContainer;
  }
  final name = channel.name;
  if (name.contains('设计')) return const Color(0xFFF0EBFF);
  if (name.toLowerCase().contains('agent')) return const Color(0xFFE5F5FA);
  if (name.contains('草稿')) return const Color(0xFFF5F2E5);
  if (name.contains('产品')) return const Color(0xFFE5F0FF);
  return const Color(0xFFDDF0FA);
}

DateTime _todayAt(int hour, int minute) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

String _formatChannelTime(DateTime? value) {
  if (value == null) return '';
  final now = DateTime.now();
  final local = value.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  if (date == today) {
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
  if (date == today.subtract(const Duration(days: 1))) return '昨天';
  if (now.difference(local).inDays < 7) {
    return const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][local.weekday - 1];
  }
  return '${local.month}/${local.day}';
}

String _formatBadgeCount(int count) => count > 99 ? '99+' : '$count';

String _formatReviewTime(int millis) {
  if (millis <= 0) return '刚刚';
  final local = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  if (date == today) {
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
  if (date == today.subtract(const Duration(days: 1))) return '昨天';
  return '${local.month}/${local.day}';
}

String _localpartFromMxid(String mxid) {
  final trimmed = mxid.trim();
  final match = RegExp(r'^@([^:]+):').firstMatch(trimmed);
  return match?.group(1) ?? trimmed;
}

String _clientServerName(Client client) {
  final userId = client.userID ?? '';
  final mxidDomain = RegExp(r':([^:]+)$').firstMatch(userId)?.group(1);
  if (mxidDomain != null && mxidDomain.isNotEmpty) return mxidDomain;
  final homeserver = client.homeserver;
  if (homeserver != null && homeserver.host.isNotEmpty) return homeserver.host;
  return 'p2p-im.com';
}

String _matrixRoomName(Client client, String roomId) {
  final room = client.getRoomById(roomId.trim());
  if (room == null) return '';
  final name = room.getLocalizedDisplayname().trim();
  return _looksLikeMatrixRoomId(name) ? '' : name;
}

String _matrixRoomAvatar(Client client, String roomId) {
  return client.getRoomById(roomId.trim())?.avatar?.toString() ?? '';
}

bool _looksLikeMatrixRoomId(String text) {
  return text.startsWith('!') && text.contains(':');
}

Color _channelBgColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.bg
      : _channelBg;
}

Color _channelSurfaceColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.surface
      : Colors.white;
}

Color _channelTextColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.text
      : _channelText;
}

Color _channelMutedColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.textMute
      : _channelMuted;
}

Color _channelBorderColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.border
      : _channelBorder;
}

Color _channelCardShadowColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.28)
      : const Color(0xFFBFBFBF).withValues(alpha: 0.25);
}

Color _channelPendingTimeColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.textMute.withValues(alpha: 0.72)
      : const Color(0xFFCACACA);
}

Color _channelSoftFillColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.surfaceHigh
      : const Color(0xFFEEF1F6);
}

Color _channelSelectedFilterBgColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.secondaryContainer
      : const Color(0xFFDDF0FA);
}

Color _channelKindBadgeBgColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.secondaryContainer
      : const Color(0xFFE9F2FF);
}

Color _channelKindBadgeTextColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.onPrimaryContainer
      : const Color(0xFF66707F);
}

Color _channelStatusBgColor(BuildContext context, _ReviewStatus status) {
  if (Theme.of(context).brightness == Brightness.dark) {
    return switch (status) {
      _ReviewStatus.pending => context.tk.surfaceHigh,
      _ReviewStatus.approved => context.tk.secondaryContainer,
      _ReviewStatus.rejected => context.tk.danger.withValues(alpha: 0.18),
    };
  }
  return switch (status) {
    _ReviewStatus.pending => const Color(0xFFFFF2DF),
    _ReviewStatus.approved => const Color(0xFFE4F8ED),
    _ReviewStatus.rejected => const Color(0xFFFFE4E4),
  };
}

Color _channelStatusTextColor(BuildContext context, _ReviewStatus status) {
  if (Theme.of(context).brightness == Brightness.dark) {
    return switch (status) {
      _ReviewStatus.pending => context.tk.textMute,
      _ReviewStatus.approved => context.tk.tertiaryFixed,
      _ReviewStatus.rejected => context.tk.danger,
    };
  }
  return switch (status) {
    _ReviewStatus.pending => const Color(0xFFF69A18),
    _ReviewStatus.approved => const Color(0xFF00A954),
    _ReviewStatus.rejected => const Color(0xFFCF0404),
  };
}

Color _channelGlassColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.surface.withValues(alpha: 0.82)
      : Colors.white.withValues(alpha: 0.65);
}

Color _channelGlassShadowColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.34)
      : Colors.black.withValues(alpha: 0.12);
}

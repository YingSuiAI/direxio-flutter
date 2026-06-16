import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../chat/chat_record_detail_page.dart';
import '../chat/chat_record_forwarding.dart';
import '../providers/as_client_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/matrix_media_cache_provider.dart';
import '../widgets/glass_list_tile.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_search_field.dart';

const double _favoritePreviewSize = 62;
const _favoriteConversationFilter = 'conversation';

class MeMenuPage extends StatelessWidget {
  const MeMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(title: '菜单'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 32),
              children: [
                _MeMenuSection(
                  children: [
                    _MeMenuRow(
                      icon: Symbols.bookmarks,
                      title: '我的收藏',
                      onTap: () => context.push('/me/favorites'),
                    ),
                    const _MeMenuDivider(),
                    _MeMenuRow(
                      icon: Symbols.thumb_up,
                      title: '我的点赞',
                      onTap: () => context.push('/me/likes'),
                    ),
                    const _MeMenuDivider(),
                    _MeMenuRow(
                      icon: Symbols.comment,
                      title: '我的评论',
                      onTap: () => context.push('/me/comments'),
                    ),
                    const _MeMenuDivider(),
                    _MeMenuRow(
                      icon: Symbols.drafts,
                      title: '草稿箱',
                      onTap: () => context.push('/me/drafts'),
                    ),
                    const _MeMenuDivider(),
                    _MeMenuRow(
                      icon: Symbols.account_balance_wallet,
                      title: '我的钱包',
                      onTap: () => context.push('/me/wallet'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _MeMenuSection(
                  children: [
                    _MeMenuRow(
                      icon: Symbols.settings,
                      title: '通用设置',
                      onTap: () => context.push('/settings'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MeFavoritesPage extends ConsumerStatefulWidget {
  const MeFavoritesPage({super.key});

  @override
  ConsumerState<MeFavoritesPage> createState() => _MeFavoritesPageState();
}

class _MeFavoritesPageState extends ConsumerState<MeFavoritesPage> {
  String _messageType = '';
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _removedFavoriteIds = {};
  late Future<List<AsFavoriteMessage>> _future = _load();

  Future<List<AsFavoriteMessage>> _load() async {
    final remoteFilter =
        _messageType == _favoriteConversationFilter ? '' : _messageType;
    final favorites = await ref
        .read(asClientProvider)
        .getFavorites(messageType: remoteFilter);
    return _filterFavorites(favorites, _messageType);
  }

  void _setFilter(String messageType) {
    if (_messageType == messageType) return;
    setState(() {
      _messageType = messageType;
      _future = _load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleFavoriteTap(AsFavoriteMessage favorite) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatRecordDetailPage(
          pageTitle: '收藏详情',
          payload: _favoriteMessagePayload(favorite),
        ),
      ),
    );
  }

  Future<void> _handleFavoriteLongPress(AsFavoriteMessage favorite) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.tk.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        final t = context.tk;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: ListTile(
              leading: Icon(Symbols.delete, color: t.danger),
              title: Text(
                '删除收藏',
                style: AppTheme.sans(
                  size: 16,
                  weight: FontWeight.w600,
                  color: t.danger,
                ),
              ),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ),
        );
      },
    );
    if (action != 'delete') return;
    await _deleteFavorite(favorite);
  }

  Future<bool> _confirmDeleteFavorite(AsFavoriteMessage favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final t = context.tk;
        return AlertDialog(
          backgroundColor: t.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(
            '取消收藏',
            style: AppTheme.sans(
              size: 18,
              weight: FontWeight.w700,
              color: t.text,
            ),
          ),
          content: Text(
            '确认删除该收藏吗？',
            style: AppTheme.sans(size: 14, color: t.textMute),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '取消',
                style: AppTheme.sans(size: 14, color: t.textMute),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                '确认',
                style: AppTheme.sans(
                  size: 14,
                  weight: FontWeight.w700,
                  color: t.danger,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return false;
    return _deleteFavorite(favorite);
  }

  Future<bool> _deleteFavorite(AsFavoriteMessage favorite) async {
    try {
      await ref.read(asClientProvider).deleteFavorite(favorite.id);
      if (!mounted) return false;
      setState(() {
        _removedFavoriteIds.add(favorite.id);
        _future = _load();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除收藏')),
      );
      return true;
    } on Object catch (err) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除收藏失败：$err')),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      key: const ValueKey('me_favorites_scaffold'),
      backgroundColor: t.bg,
      body: Column(
        children: [
          GlassHeader.detail(title: '我的收藏'),
          _FavoriteSearchBar(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchText = value),
            onClear: () {
              _searchController.clear();
              setState(() => _searchText = '');
            },
          ),
          _FavoriteFilters(selected: _messageType, onSelected: _setFilter),
          Expanded(
            child: FutureBuilder<List<AsFavoriteMessage>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.accent,
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _MeEmptyUtilityContent(
                    icon: Symbols.error,
                    emptyTitle: '收藏加载失败',
                    emptySubtitle: '${snapshot.error}',
                  );
                }
                final favorites = _searchFavorites(
                  (snapshot.data ?? const [])
                      .where(
                        (favorite) =>
                            !_removedFavoriteIds.contains(favorite.id),
                      )
                      .toList(growable: false),
                  _searchText,
                );
                if (favorites.isEmpty) {
                  final searching = _searchText.trim().isNotEmpty;
                  return _MeEmptyUtilityContent(
                    icon: Symbols.bookmarks,
                    emptyTitle: searching ? '未找到相关收藏' : '暂无收藏',
                    emptySubtitle: searching ? '换个关键词试试' : '长按聊天消息收藏后会显示在这里',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
                  itemBuilder: (context, index) {
                    final favorite = favorites[index];
                    return _FavoriteTile(
                      favorite: favorite,
                      onTap: () => unawaited(_handleFavoriteTap(favorite)),
                      onLongPress: () =>
                          unawaited(_handleFavoriteLongPress(favorite)),
                      onDismissDelete: () => _confirmDeleteFavorite(favorite),
                    );
                  },
                  itemCount: favorites.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MeLikesPage extends ConsumerStatefulWidget {
  const MeLikesPage({super.key});

  @override
  ConsumerState<MeLikesPage> createState() => _MeLikesPageState();
}

class _MeLikesPageState extends ConsumerState<MeLikesPage> {
  late final Future<List<AsChannelReactionHistory>> _future = _load();

  Future<List<AsChannelReactionHistory>> _load() {
    return ref.read(asClientProvider).getMyChannelReactions();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(title: '我的点赞'),
          Expanded(
            child: FutureBuilder<List<AsChannelReactionHistory>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.accent,
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _MeEmptyUtilityContent(
                    icon: Symbols.error,
                    emptyTitle: '点赞加载失败',
                    emptySubtitle: '${snapshot.error}',
                  );
                }
                final reactions = snapshot.data ?? const [];
                if (reactions.isEmpty) {
                  return const _MeEmptyUtilityContent(
                    icon: Symbols.thumb_up,
                    emptyTitle: '暂无点赞',
                    emptySubtitle: '你点过赞的频道帖子会显示在这里',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
                  itemCount: reactions.length,
                  itemBuilder: (context, index) {
                    final item = reactions[index];
                    return _ChannelActivityTile(
                      key: ValueKey(
                        'my-like-${item.channelId}-${item.postId}',
                      ),
                      icon: Symbols.thumb_up,
                      channel: item.channel,
                      title: _channelActivityPostPreview(item.post),
                      subtitle: _channelActivityChannelLabel(item.channel),
                      meta: _channelActivityDateLabel(item.originServerTs),
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
}

class MeCommentsPage extends ConsumerStatefulWidget {
  const MeCommentsPage({super.key});

  @override
  ConsumerState<MeCommentsPage> createState() => _MeCommentsPageState();
}

class _MeCommentsPageState extends ConsumerState<MeCommentsPage> {
  late final Future<List<AsChannelCommentHistory>> _future = _load();

  Future<List<AsChannelCommentHistory>> _load() {
    return ref.read(asClientProvider).getMyChannelComments();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(title: '我的评论'),
          Expanded(
            child: FutureBuilder<List<AsChannelCommentHistory>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.accent,
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _MeEmptyUtilityContent(
                    icon: Symbols.error,
                    emptyTitle: '评论加载失败',
                    emptySubtitle: '${snapshot.error}',
                  );
                }
                final comments = snapshot.data ?? const [];
                if (comments.isEmpty) {
                  return const _MeEmptyUtilityContent(
                    icon: Symbols.comment,
                    emptyTitle: '暂无评论',
                    emptySubtitle: '你在频道帖子下发表过的评论会显示在这里',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final item = comments[index];
                    return _ChannelActivityTile(
                      key: ValueKey(
                        'my-comment-${item.comment.commentId}',
                      ),
                      icon: Symbols.comment,
                      channel: item.channel,
                      title: item.comment.body.trim().isEmpty
                          ? '评论'
                          : item.comment.body.trim(),
                      subtitle: '${_channelActivityChannelLabel(item.channel)}'
                          ' · 评论了 ${_channelActivityPostPreview(item.post)}',
                      meta: _channelActivityDateLabel(
                        item.comment.originServerTs,
                      ),
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
}

class _ChannelActivityTile extends StatelessWidget {
  const _ChannelActivityTile({
    super.key,
    required this.icon,
    required this.channel,
    required this.title,
    required this.subtitle,
    required this.meta,
  });

  final IconData icon;
  final AsChannel channel;
  final String title;
  final String subtitle;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final channelName =
        channel.name.trim().isEmpty ? '频道' : channel.name.trim();
    return GlassListTile(
      leading:
          GlassListIcon(icon: icon, fill: icon == Symbols.thumb_up ? 1 : 0),
      title: title.trim().isEmpty ? channelName : title.trim(),
      subtitle: subtitle.trim().isEmpty ? channelName : subtitle.trim(),
      trailingText: meta,
      onTap: channel.channelId.trim().isEmpty
          ? null
          : () => context.push(
                '/channel/${Uri.encodeComponent(channel.channelId.trim())}',
              ),
      titleStyle: AppTheme.sans(
        size: 17,
        weight: FontWeight.w600,
        color: t.text,
      ),
      subtitleStyle: AppTheme.sans(size: 13, color: t.textMute),
    );
  }
}

class MeDraftsPage extends StatelessWidget {
  const MeDraftsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MeEmptyUtilityPage(
      title: '草稿箱',
      icon: Symbols.drafts,
      emptyTitle: '暂无草稿',
      emptySubtitle: '未发布的动态和频道内容会保存在这里',
    );
  }
}

class MeHistoryPage extends StatelessWidget {
  const MeHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MeEmptyUtilityPage(
      title: '浏览记录',
      icon: Symbols.history,
      emptyTitle: '暂无浏览记录',
      emptySubtitle: '看过的主页、频道和动态会显示在这里',
    );
  }
}

class MeWalletPage extends StatelessWidget {
  const MeWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MeEmptyUtilityPage(
      title: '我的钱包',
      icon: Symbols.account_balance_wallet,
      emptyTitle: '钱包未开通',
      emptySubtitle: '资产、订阅和付费能力会从这里进入',
    );
  }
}

class _MeEmptyUtilityPage extends StatelessWidget {
  const _MeEmptyUtilityPage({
    required this.title,
    required this.icon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final String title;
  final IconData icon;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(title: title),
          Expanded(
            child: _MeEmptyUtilityContent(
              icon: icon,
              emptyTitle: emptyTitle,
              emptySubtitle: emptySubtitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeEmptyUtilityContent extends StatelessWidget {
  const _MeEmptyUtilityContent({
    required this.icon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final IconData icon;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: t.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: t.textMute),
            ),
            const SizedBox(height: 18),
            Text(
              emptyTitle,
              textAlign: TextAlign.center,
              style: AppTheme.sans(
                size: 18,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: AppTheme.sans(
                size: 14,
                color: t.textMute,
              ).copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteSearchBar extends StatelessWidget {
  const _FavoriteSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      color: t.bg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.trim().isNotEmpty;
          return M3SearchField(
            controller: controller,
            hint: '搜索收藏内容',
            onChanged: onChanged,
            trailing: hasText
                ? IconButton(
                    tooltip: '清除',
                    onPressed: onClear,
                    icon: Icon(
                      Symbols.cancel,
                      size: 18,
                      color: t.textMute,
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _FavoriteFilters extends StatelessWidget {
  const _FavoriteFilters({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  static const _filters = <(String value, String label)>[
    ('', '全部'),
    (_favoriteConversationFilter, '聊天记录'),
    ('image', '图片'),
    ('video', '视频'),
    ('file', '文件'),
    ('link', '链接'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: t.bg,
        border:
            Border(bottom: BorderSide(color: t.border.withValues(alpha: 0.35))),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final item = _filters[index];
          return _FavoriteFilterChip(
            label: item.$2,
            selected: selected == item.$1,
            onTap: () => onSelected(item.$1),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _filters.length,
      ),
    );
  }
}

class _FavoriteFilterChip extends StatelessWidget {
  const _FavoriteFilterChip({
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
      color: selected ? t.text : t.surfaceHigh,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: AppTheme.sans(
              size: 14,
              weight: FontWeight.w600,
              color: selected ? t.bg : t.textMute,
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.favorite,
    required this.onTap,
    required this.onLongPress,
    required this.onDismissDelete,
  });

  final AsFavoriteMessage favorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<bool> Function() onDismissDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Dismissible(
      key: ValueKey('favorite-dismiss-${favorite.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onDismissDelete(),
      background: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: t.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.danger.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Symbols.delete, color: t.danger, size: 22),
          ),
        ),
      ),
      child: GlassListPanel(
        key: ValueKey('favorite-card-${favorite.id}'),
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FavoritePreview(favorite: favorite),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _favoriteListTitle(favorite),
                    maxLines: favorite.messageType == 'file' ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                      size: 16,
                      weight: FontWeight.w600,
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _favoriteSourceLabel(favorite),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(size: 12, color: t.textMute),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _favoriteListMeta(favorite),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(size: 12, color: t.textMute),
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

List<AsFavoriteMessage> _searchFavorites(
  List<AsFavoriteMessage> favorites,
  String query,
) {
  final keyword = query.trim().toLowerCase();
  if (keyword.isEmpty) return favorites;
  return favorites
      .where((favorite) => _favoriteSearchText(favorite).contains(keyword))
      .toList(growable: false);
}

String _favoriteSearchText(AsFavoriteMessage favorite) {
  final values = <String>[
    _favoriteListTitle(favorite),
    _favoriteSourceLabel(favorite),
    _favoriteMessageBody(favorite),
    _favoriteTypeLabel(favorite.messageType),
    favorite.body,
    favorite.filename,
    favorite.url,
    favorite.mimeType,
    favorite.senderId,
    favorite.senderName,
    favorite.roomId,
    favorite.eventId,
    favorite.roomType,
  ];
  return values
      .where((value) => value.trim().isNotEmpty)
      .join('\n')
      .toLowerCase();
}

class _FavoritePreview extends ConsumerStatefulWidget {
  const _FavoritePreview({required this.favorite});

  final AsFavoriteMessage favorite;

  @override
  ConsumerState<_FavoritePreview> createState() => _FavoritePreviewState();
}

class _FavoritePreviewState extends ConsumerState<_FavoritePreview> {
  Future<Uint8List>? _previewFuture;

  @override
  void initState() {
    super.initState();
    final favorite = widget.favorite;
    final hasThumbnail = favorite.thumbnailUrl.trim().isNotEmpty;
    final shouldLoadPreview =
        (favorite.messageType == 'image' && favorite.url.trim().isNotEmpty) ||
            (favorite.messageType == 'video' && hasThumbnail);
    if (shouldLoadPreview) {
      _previewFuture = _downloadFavoriteMediaBytes(
        ref,
        favorite,
        thumbnail: favorite.messageType == 'video' || hasThumbnail,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorite = widget.favorite;
    final t = context.tk;
    final isMedia =
        favorite.messageType == 'image' || favorite.messageType == 'video';
    if (!isMedia) {
      return _FavoriteIconBox(
        key: ValueKey('favorite-preview-${favorite.id}'),
        type: favorite.messageType,
        size: _favoritePreviewSize,
      );
    }

    final placeholder = Container(
      color: t.surfaceHigh,
      alignment: Alignment.center,
      child: Icon(
        _favoriteIcon(favorite.messageType),
        color: t.textMute,
        size: 28,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        key: ValueKey('favorite-preview-${favorite.id}'),
        width: _favoritePreviewSize,
        height: _favoritePreviewSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_previewFuture == null)
              placeholder
            else
              FutureBuilder<Uint8List>(
                future: _previewFuture,
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null || bytes.isEmpty) return placeholder;
                  return Image.memory(bytes, fit: BoxFit.cover);
                },
              ),
            if (favorite.messageType == 'video')
              Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Symbols.play_arrow,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteIconBox extends StatelessWidget {
  const _FavoriteIconBox({
    super.key,
    required this.type,
    this.size = _favoritePreviewSize,
  });

  final String type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _favoriteIcon(type),
        size: size > 48 ? 30 : 22,
        color: t.textMute,
      ),
    );
  }
}

IconData _favoriteIcon(String type) {
  return switch (type) {
    'image' => Symbols.image,
    'video' => Symbols.play_circle,
    'file' => Symbols.description,
    'chat_record' => Symbols.forum,
    'audio' => Symbols.graphic_eq,
    'link' => Symbols.link,
    _ => Symbols.notes,
  };
}

String _favoriteTitle(AsFavoriteMessage favorite) {
  if (favorite.messageType == 'chat_record') {
    return _favoriteChatRecordDescription(favorite);
  }
  if (favorite.messageType == 'file' ||
      favorite.messageType == 'image' ||
      favorite.messageType == 'video' ||
      favorite.messageType == 'audio') {
    if (favorite.filename.isNotEmpty) return favorite.filename;
  }
  if (favorite.body.isNotEmpty) return favorite.body;
  if (favorite.url.isNotEmpty) return favorite.url;
  return '收藏消息';
}

List<AsFavoriteMessage> _filterFavorites(
  List<AsFavoriteMessage> favorites,
  String messageType,
) {
  final type = messageType.trim();
  if (type.isEmpty) return favorites;
  if (type == _favoriteConversationFilter) {
    return favorites
        .where((favorite) =>
            favorite.messageType == 'text' ||
            favorite.messageType == chatRecordMessageType)
        .toList(growable: false);
  }
  return favorites
      .where((favorite) => favorite.messageType == type)
      .toList(growable: false);
}

String _favoriteListTitle(AsFavoriteMessage favorite) {
  return switch (favorite.messageType) {
    'image' => '图片',
    'video' => '视频',
    'audio' => '语音',
    'chat_record' => '聊天记录',
    'file' => _favoriteTitle(favorite),
    'link' => favorite.body.trim().isNotEmpty ? favorite.body.trim() : '链接',
    _ => _favoriteTitle(favorite),
  };
}

String _favoriteListMeta(AsFavoriteMessage favorite) {
  final parts = <String>[
    _favoriteDateLabel(favorite),
    if (favorite.size > 0) _favoriteSize(favorite.size),
  ];
  return parts.where((part) => part.trim().isNotEmpty).join(' · ');
}

String _favoriteSourceLabel(AsFavoriteMessage favorite) {
  if (favorite.messageType == 'chat_record') {
    return _favoriteChatRecordDescription(favorite);
  }
  final sender = favorite.senderName.trim().isNotEmpty
      ? favorite.senderName.trim()
      : favorite.senderId.trim();
  return switch (favorite.roomType) {
    'direct' => sender.isEmpty ? '来自私聊' : '来自与 $sender 的私聊',
    'group' => sender.isEmpty ? '来自群聊' : '来自群聊 · $sender',
    'channel' => sender.isEmpty ? '来自频道' : '来自频道 · $sender',
    'agent' => '来自 Agent',
    _ => sender.isEmpty ? '来自聊天' : '来自聊天 · $sender',
  };
}

String _favoriteDateLabel(AsFavoriteMessage favorite) {
  final value = _favoriteTimestamp(favorite);
  if (value == null) return '';
  final local = value.toLocal();
  final prefix = '${local.year}年${local.month}月${local.day}日';
  return '$prefix ${_two(local.hour)}:${_two(local.minute)}';
}

DateTime? _favoriteTimestamp(AsFavoriteMessage favorite) {
  if (favorite.favoritedAt != null) return favorite.favoritedAt;
  final ts = favorite.originServerTs;
  if (ts <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
}

String _channelActivityPostPreview(AsChannelPost post) {
  final body = post.body.trim();
  if (body.isNotEmpty) return body;
  return switch (post.messageType.trim()) {
    'image' || 'm.image' => '图片',
    'video' || 'm.video' => '视频',
    'file' || 'm.file' => '文件',
    'audio' || 'm.audio' => '语音',
    _ => '频道帖子',
  };
}

String _channelActivityChannelLabel(AsChannel channel) {
  final name = channel.name.trim();
  if (name.isNotEmpty) return name;
  final domain = channel.homeDomain.trim();
  if (domain.isNotEmpty) return domain;
  return '频道';
}

String _channelActivityDateLabel(int originServerTs) {
  if (originServerTs <= 0) return '';
  final local = DateTime.fromMillisecondsSinceEpoch(
    originServerTs,
    isUtc: true,
  ).toLocal();
  return '${local.year}年${local.month}月${local.day}日 '
      '${_two(local.hour)}:${_two(local.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

String _favoriteTypeLabel(String type) {
  return switch (type) {
    'text' => '文字',
    'image' => '图片',
    'video' => '视频',
    'file' => '文件',
    'chat_record' => '聊天记录',
    'audio' => '语音',
    'link' => '链接',
    _ => '消息',
  };
}

String _favoriteSize(int bytes) {
  if (bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var index = 0;
  while (size >= 1024 && index < units.length - 1) {
    size /= 1024;
    index++;
  }
  final digits = index == 0 || size >= 10 ? 0 : 1;
  return '${size.toStringAsFixed(digits)} ${units[index]}';
}

String _favoriteChatRecordDescription(AsFavoriteMessage favorite) {
  final body = favorite.body.trim();
  if (body.isNotEmpty) return body;

  final name = favorite.senderName.trim().isNotEmpty
      ? favorite.senderName.trim()
      : favorite.senderId.trim();
  return switch (favorite.roomType) {
    'direct' => name.isEmpty ? '私聊聊天记录' : '与 $name 的聊天记录',
    'group' => name.isEmpty ? '群聊聊天记录' : '群聊「$name」的聊天记录',
    'channel' => name.isEmpty ? '频道聊天记录' : '频道「$name」的聊天记录',
    'agent' => '与 Agent 的聊天记录',
    _ => name.isEmpty ? '聊天记录' : '与 $name 的聊天记录',
  };
}

ChatRecordPayload _favoriteMessagePayload(AsFavoriteMessage favorite) {
  if (favorite.messageType == chatRecordMessageType &&
      favorite.chatRecord.isNotEmpty) {
    final payload = chatRecordPayloadFromContent({
      'msgtype': MessageTypes.Text,
      'body': favorite.body.trim().isEmpty
          ? _favoriteChatRecordDescription(favorite)
          : favorite.body.trim(),
      chatRecordMatrixMarkerKey: chatRecordMessageType,
      chatRecordMatrixPayloadKey: favorite.chatRecord,
    });
    if (payload != null) return payload;
  }
  final title = favorite.messageType == chatRecordMessageType
      ? _favoriteChatRecordDescription(favorite)
      : _favoriteSourceLabel(favorite);
  return ChatRecordPayload(
    sourceRoomId: favorite.roomId,
    sourceRoomType:
        favorite.roomType.trim().isEmpty ? 'direct' : favorite.roomType.trim(),
    title: title,
    body: '收藏详情\n$title\n共 1 条消息',
    itemCount: 1,
    items: [
      {
        'sender_id': favorite.senderId.trim(),
        'sender_name': favorite.senderName.trim(),
        'is_me': favorite.senderId.trim().isNotEmpty &&
            favorite.senderId.trim() == favorite.ownerUserId.trim(),
        'body': _favoriteMessageBody(favorite),
        'message_type': _favoriteMatrixMessageType(favorite.messageType),
        'origin_server_ts': favorite.originServerTs,
        'content': _favoriteMatrixContent(favorite),
      },
    ],
  );
}

String _favoriteMessageBody(AsFavoriteMessage favorite) {
  if (favorite.messageType == chatRecordMessageType) {
    return _favoriteChatRecordDescription(favorite);
  }
  if ((favorite.filename).trim().isNotEmpty &&
      (favorite.messageType == 'image' ||
          favorite.messageType == 'video' ||
          favorite.messageType == 'file' ||
          favorite.messageType == 'audio')) {
    return favorite.filename.trim();
  }
  if (favorite.body.trim().isNotEmpty) return favorite.body.trim();
  if (favorite.url.trim().isNotEmpty) return favorite.url.trim();
  return _favoriteTypeLabel(favorite.messageType);
}

String _favoriteMatrixMessageType(String type) {
  return switch (type) {
    'image' => MessageTypes.Image,
    'video' => MessageTypes.Video,
    'file' => MessageTypes.File,
    'audio' => MessageTypes.Audio,
    _ => MessageTypes.Text,
  };
}

Map<String, Object?> _favoriteMatrixContent(AsFavoriteMessage favorite) {
  final msgType = _favoriteMatrixMessageType(favorite.messageType);
  final body = _favoriteMessageBody(favorite);
  if (favorite.messageType == chatRecordMessageType) {
    return {
      'msgtype': MessageTypes.Text,
      'body': body,
    };
  }
  return {
    'msgtype': msgType,
    'body': body,
    if (favorite.filename.trim().isNotEmpty)
      'filename': favorite.filename.trim(),
    if (favorite.url.trim().isNotEmpty) 'url': favorite.url.trim(),
    'info': {
      if (favorite.mimeType.trim().isNotEmpty)
        'mimetype': favorite.mimeType.trim(),
      if (favorite.size > 0) 'size': favorite.size,
      if (favorite.thumbnailUrl.trim().isNotEmpty)
        'thumbnail_url': favorite.thumbnailUrl.trim(),
      if (favorite.thumbnailMimeType.trim().isNotEmpty)
        'thumbnail_info': {
          'mimetype': favorite.thumbnailMimeType.trim(),
          if (favorite.thumbnailSize > 0) 'size': favorite.thumbnailSize,
        },
      if (favorite.width > 0) 'w': favorite.width,
      if (favorite.height > 0) 'h': favorite.height,
      if (favorite.durationMs > 0) 'duration': favorite.durationMs,
    },
  };
}

Future<Uint8List> _downloadFavoriteMediaBytes(
  WidgetRef ref,
  AsFavoriteMessage favorite, {
  bool thumbnail = false,
}) async {
  final raw = (thumbnail ? favorite.thumbnailUrl : favorite.url).trim();
  final mxc = Uri.tryParse(raw);
  if (mxc == null || !mxc.isScheme('mxc')) {
    throw StateError('收藏媒体地址无效');
  }

  final client = ref.read(matrixClientProvider);
  return ref.read(matrixMediaBytesCacheProvider).read(client, mxc);
}

class _MeMenuSection extends StatelessWidget {
  const _MeMenuSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(children: children);
  }
}

class _MeMenuRow extends StatelessWidget {
  const _MeMenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassListTile(
      leading: GlassListIcon(icon: icon),
      title: title,
      onTap: onTap,
    );
  }
}

class _MeMenuDivider extends StatelessWidget {
  const _MeMenuDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

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
import '../chat/chat_voice_player.dart';
import '../providers/as_client_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/matrix_media_cache_provider.dart';
import '../widgets/glass_list_tile.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/portal_avatar.dart';

const double _favoriteMediaPreviewSize = 109;

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
  final Set<int> _removedFavoriteIds = {};
  late Future<List<AsFavoriteMessage>> _future = _load();

  Future<List<AsFavoriteMessage>> _load() async {
    return ref.read(asClientProvider).getFavorites();
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
          GlassHeader.detail(title: '收藏'),
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
                final favorites = (snapshot.data ?? const [])
                    .where(
                      (favorite) => !_removedFavoriteIds.contains(favorite.id),
                    )
                    .toList(growable: false);
                if (favorites.isEmpty) {
                  return const _MeEmptyUtilityContent(
                    icon: Symbols.bookmarks,
                    emptyTitle: '暂无收藏',
                    emptySubtitle: '长按聊天消息收藏后会显示在这里',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final favorite = favorites[index];
                    return _FavoriteCard(
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
    return ref.read(asClientProvider).getMyChannelReactions(limit: 50);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          GlassHeader.detail(title: '赞'),
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
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                  itemCount: reactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = reactions[index];
                    return _MeLikePostCard(
                      key: ValueKey(
                        'my-like-${item.channelId}-${item.postId}',
                      ),
                      item: item,
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

class _MeLikePostCard extends StatelessWidget {
  const _MeLikePostCard({
    super.key,
    required this.item,
  });

  final AsChannelReactionHistory item;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final post = item.post;
    final author = _postAuthorLabel(post, item.channel);
    final title = _channelActivityPostPreview(post);
    final body = post.body.trim().isEmpty ? title : post.body.trim();
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(20),
      shadowColor: t.border.withValues(alpha: 0.25),
      elevation: 10,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openReactionTarget(context, item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PortalAvatar(
                    seed: post.authorId.trim().isEmpty
                        ? author
                        : post.authorId.trim(),
                    size: 40,
                    shape: AvatarShape.squircle,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.sans(
                                  size: 17,
                                  weight: FontWeight.w600,
                                  color: t.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _PostTypeBadge(type: post.messageType),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _commentTimeLabel(post.originServerTs),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(size: 13, color: t.textMute),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(
                  size: 17,
                  weight: FontWeight.w600,
                  color: t.text,
                ).copyWith(height: 1.28),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(
                  size: 13,
                  weight: FontWeight.w500,
                  color: t.textMute,
                ).copyWith(height: 20 / 13),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    '收起',
                    style: AppTheme.sans(size: 13, color: t.textMute),
                  ),
                  Icon(Symbols.expand_less, size: 16, color: t.textMute),
                  const Spacer(),
                  _PostStat(
                    icon: Symbols.favorite,
                    count: post.reactionCount,
                    color: t.danger,
                    fill: 1,
                  ),
                  const SizedBox(width: 16),
                  _PostStat(
                    icon: Symbols.chat_bubble,
                    count: post.commentCount,
                    color: t.textMute,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostTypeBadge extends StatelessWidget {
  const _PostTypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _favoriteTypeLabel(type),
        style: AppTheme.sans(size: 11, color: t.textMute),
      ),
    );
  }
}

class _PostStat extends StatelessWidget {
  const _PostStat({
    required this.icon,
    required this.count,
    required this.color,
    this.fill = 0,
  });

  final IconData icon;
  final int count;
  final Color color;
  final double fill;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color, fill: fill),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: AppTheme.sans(size: 13, color: t.textMute),
        ),
      ],
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
      key: const ValueKey('me_comments_scaffold'),
      backgroundColor: t.bg,
      body: Column(
        children: [
          GlassHeader.detail(title: '评论'),
          Expanded(
            child: FutureBuilder<List<AsChannelCommentHistory>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _MeCommentsEmpty(
                    icon: Symbols.error,
                    title: '评论加载失败',
                    subtitle: '${snapshot.error}',
                  );
                }
                final comments = snapshot.data ?? const [];
                if (comments.isEmpty) {
                  return const _MeCommentsEmpty(
                    icon: Symbols.comment,
                    title: '暂无评论',
                    subtitle: '你在频道帖子下发表过的评论会显示在这里',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = comments[index];
                    return _MeCommentCard(
                      key: ValueKey('my-comment-${item.comment.commentId}'),
                      item: item,
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

class _MeCommentCard extends StatelessWidget {
  const _MeCommentCard({
    super.key,
    required this.item,
  });

  final AsChannelCommentHistory item;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final comment = item.comment;
    final author = _commentAuthorLabel(comment);
    final body = comment.body.trim().isEmpty ? '评论' : comment.body.trim();
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(20),
      shadowColor: t.border.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.25,
      ),
      elevation: 10,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openCommentTarget(context, item),
        child: SizedBox(
          height: 102,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 15, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PortalAvatar(
                  seed: comment.authorId.trim().isEmpty
                      ? author
                      : comment.authorId.trim(),
                  size: 40,
                  shape: AvatarShape.squircle,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 20,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sans(
                              size: 16,
                              weight: FontWeight.w600,
                              color: t.text,
                            ).copyWith(height: 33 / 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(
                          size: 13,
                          weight: FontWeight.w500,
                          color: t.text,
                        ).copyWith(height: 20 / 13),
                      ),
                      const Spacer(),
                      Text(
                        _commentTimeLabel(comment.originServerTs),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(
                          size: 10,
                          weight: FontWeight.w400,
                          color: t.textMute,
                        ),
                      ),
                    ],
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

class _MeCommentsEmpty extends StatelessWidget {
  const _MeCommentsEmpty({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: t.textMute),
            const SizedBox(height: 14),
            Text(
              title,
              style: AppTheme.sans(
                size: 17,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w400,
                color: t.textMute,
              ),
            ),
          ],
        ),
      ),
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

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
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
      child: Material(
        key: ValueKey('favorite-card-${favorite.id}'),
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        shadowColor: t.border.withValues(alpha: 0.25),
        elevation: 10,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: _FavoriteCardBody(favorite: favorite),
          ),
        ),
      ),
    );
  }
}

class _FavoriteCardBody extends StatelessWidget {
  const _FavoriteCardBody({required this.favorite});

  final AsFavoriteMessage favorite;

  @override
  Widget build(BuildContext context) {
    if (favorite.messageType == chatRecordMessageType) {
      return _FavoriteChatRecordBody(favorite: favorite);
    }
    if (favorite.messageType == 'file') {
      return _FavoriteFileBody(favorite: favorite);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FavoriteAuthorHeader(favorite: favorite),
        const SizedBox(height: 14),
        switch (favorite.messageType) {
          'audio' => _FavoriteAudioContent(favorite: favorite),
          'image' || 'video' => _FavoriteMediaContent(favorite: favorite),
          _ => _FavoriteTextContent(favorite: favorite),
        },
      ],
    );
  }
}

class _FavoriteAuthorHeader extends StatelessWidget {
  const _FavoriteAuthorHeader({required this.favorite});

  final AsFavoriteMessage favorite;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final author = _favoriteSenderLabel(favorite);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalAvatar(
          seed: favorite.senderId.trim().isEmpty
              ? author
              : favorite.senderId.trim(),
          size: 40,
          shape: AvatarShape.squircle,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 17,
                        weight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _PostTypeBadge(type: favorite.messageType),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                _favoriteTimeLabel(favorite),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(size: 13, color: t.textMute),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FavoriteTextContent extends StatelessWidget {
  const _FavoriteTextContent({required this.favorite});

  final AsFavoriteMessage favorite;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final title = _favoriteTitle(favorite);
    final body = favorite.body.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.sans(
            size: 17,
            weight: FontWeight.w600,
            color: t.text,
          ).copyWith(height: 1.28),
        ),
        if (body.isNotEmpty && body != title) ...[
          const SizedBox(height: 8),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w500,
              color: t.textMute,
            ).copyWith(height: 20 / 13),
          ),
        ],
      ],
    );
  }
}

class _FavoriteAudioContent extends ConsumerStatefulWidget {
  const _FavoriteAudioContent({required this.favorite});

  final AsFavoriteMessage favorite;

  @override
  ConsumerState<_FavoriteAudioContent> createState() =>
      _FavoriteAudioContentState();
}

class _FavoriteAudioContentState extends ConsumerState<_FavoriteAudioContent> {
  late final ChatVoicePlayer _player = ChatVoicePlayer();
  bool _loading = false;

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_loading) return;
    final favorite = widget.favorite;
    final url = favorite.url.trim();
    if (url.isEmpty) {
      _showAudioError('收藏语音地址为空，无法播放');
      return;
    }
    setState(() => _loading = true);
    try {
      final bytes = await _downloadFavoriteMediaBytes(ref, favorite);
      await _player.playBytes(
        bytes,
        mimeType: favorite.mimeType,
        messageId: _favoriteAudioMessageId(favorite),
      );
    } catch (err) {
      _showAudioError('语音播放失败：$err');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAudioError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorite = widget.favorite;
    final t = context.tk;
    return ValueListenableBuilder<ChatVoicePlaybackState>(
      valueListenable: _player.playback,
      builder: (context, playback, _) {
        final playing = playback.playing &&
            playback.messageId == _favoriteAudioMessageId(favorite);
        return Material(
          color: t.surfaceHigh,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
            bottomLeft: Radius.circular(2),
          ),
          child: InkWell(
            key: ValueKey('favorite-audio-${favorite.id}'),
            onTap: () => unawaited(_togglePlay()),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(24),
              bottomLeft: Radius.circular(2),
            ),
            child: Container(
              width: 128,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  if (_loading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.text,
                      ),
                    )
                  else
                    Icon(
                      playing ? Symbols.pause : Symbols.graphic_eq,
                      size: 22,
                      color: t.text,
                      fill: playing ? 1 : 0,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    _favoriteAudioDuration(favorite),
                    style: AppTheme.sans(
                      size: 15,
                      weight: FontWeight.w600,
                      color: t.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FavoriteMediaContent extends StatelessWidget {
  const _FavoriteMediaContent({required this.favorite});

  final AsFavoriteMessage favorite;

  @override
  Widget build(BuildContext context) {
    return _FavoritePreview(
      favorite: favorite,
      size: _favoriteMediaPreviewSize,
      borderRadius: 4,
    );
  }
}

class _FavoriteChatRecordBody extends StatelessWidget {
  const _FavoriteChatRecordBody({required this.favorite});

  final AsFavoriteMessage favorite;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final lines = _favoriteChatRecordPreviewLines(favorite);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _favoriteChatRecordDescription(favorite),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.sans(
            size: 17,
            weight: FontWeight.w600,
            color: t.text,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          _favoriteTimeLabel(favorite),
          style: AppTheme.sans(size: 13, color: t.textMute),
        ),
        const SizedBox(height: 12),
        for (final line in lines.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(size: 13, color: t.textMute),
            ),
          ),
      ],
    );
  }
}

class _FavoriteFileBody extends StatelessWidget {
  const _FavoriteFileBody({required this.favorite});

  final AsFavoriteMessage favorite;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _favoriteTitle(favorite),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(
                  size: 17,
                  weight: FontWeight.w600,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _favoriteTimeLabel(favorite),
                style: AppTheme.sans(size: 13, color: t.textMute),
              ),
              const SizedBox(height: 42),
              Text(
                _favoriteSenderLabel(favorite),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(size: 13, color: t.textMute),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _FavoriteIconBox(
          key: ValueKey('favorite-preview-${favorite.id}'),
          type: favorite.messageType,
          size: 70,
        ),
      ],
    );
  }
}

List<String> _favoriteChatRecordPreviewLines(AsFavoriteMessage favorite) {
  final items = favorite.chatRecord['items'];
  if (items is Iterable) {
    return items
        .whereType<Map>()
        .map((item) {
          final sender = (item['sender_name'] as String? ?? '').trim();
          final body = (item['body'] as String? ?? '').trim();
          if (body.isEmpty) return '';
          return sender.isEmpty ? body : '$sender：$body';
        })
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }
  final body = favorite.body.trim();
  return body.isEmpty ? const <String>[] : <String>[body];
}

String _favoriteAudioDuration(AsFavoriteMessage favorite) {
  final seconds = (favorite.durationMs / 1000).round();
  if (seconds > 0) return '${seconds}s';
  final body = favorite.body.trim();
  return body.isEmpty ? '60s' : body;
}

String _favoriteAudioMessageId(AsFavoriteMessage favorite) {
  final eventId = favorite.eventId.trim();
  if (eventId.isNotEmpty) return eventId;
  return 'favorite-audio-${favorite.id}';
}

String _favoriteSenderLabel(AsFavoriteMessage favorite) {
  final name = favorite.senderName.trim();
  if (name.isNotEmpty) return name;
  final senderId = favorite.senderId.trim();
  if (senderId.startsWith('@')) {
    final colon = senderId.indexOf(':');
    if (colon > 1) return senderId.substring(1, colon);
  }
  return senderId.isEmpty ? '未知' : senderId;
}

String _favoriteTimeLabel(AsFavoriteMessage favorite) {
  final value = _favoriteTimestamp(favorite);
  if (value == null) return '';
  final local = value.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

class _FavoritePreview extends ConsumerStatefulWidget {
  const _FavoritePreview({
    required this.favorite,
    required this.size,
    required this.borderRadius,
  });

  final AsFavoriteMessage favorite;
  final double size;
  final double borderRadius;

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
        size: widget.size,
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
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        key: ValueKey('favorite-preview-${favorite.id}'),
        width: widget.size,
        height: widget.size,
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
                    color: t.text.withValues(alpha: 0.42),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Symbols.play_arrow,
                    color: t.surface,
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
    required this.size,
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
    'file' => Symbols.folder,
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

String _commentTimeLabel(int originServerTs) {
  if (originServerTs <= 0) return '';
  final local = DateTime.fromMillisecondsSinceEpoch(
    originServerTs,
    isUtc: true,
  ).toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

String _commentAuthorLabel(AsChannelComment comment) {
  final authorName = comment.authorName.trim();
  if (authorName.isNotEmpty) return authorName;
  final authorId = comment.authorId.trim();
  if (authorId.startsWith('@')) {
    final colon = authorId.indexOf(':');
    if (colon > 1) return authorId.substring(1, colon);
  }
  return authorId.isEmpty ? '我' : authorId;
}

String _postAuthorLabel(AsChannelPost post, AsChannel channel) {
  final authorName = post.authorName.trim();
  if (authorName.isNotEmpty) return authorName;
  final authorId = post.authorId.trim();
  if (authorId.startsWith('@')) {
    final colon = authorId.indexOf(':');
    if (colon > 1) return authorId.substring(1, colon);
  }
  if (authorId.isNotEmpty) return authorId;
  return _channelActivityChannelLabel(channel);
}

void _openReactionTarget(
  BuildContext context,
  AsChannelReactionHistory item,
) {
  final channelId = item.channel.channelId.trim().isNotEmpty
      ? item.channel.channelId.trim()
      : item.channelId.trim();
  final postId = item.post.postId.trim().isNotEmpty
      ? item.post.postId.trim()
      : item.postId.trim();
  if (channelId.isEmpty || postId.isEmpty) return;
  context.push(
    '/channel/${Uri.encodeComponent(channelId)}/post/'
    '${Uri.encodeComponent(postId)}',
  );
}

void _openCommentTarget(
  BuildContext context,
  AsChannelCommentHistory item,
) {
  final channelId = item.channel.channelId.trim().isNotEmpty
      ? item.channel.channelId.trim()
      : item.comment.channelId.trim();
  final postId = item.post.postId.trim().isNotEmpty
      ? item.post.postId.trim()
      : item.comment.postId.trim();
  if (channelId.isEmpty || postId.isEmpty) return;
  context.push(
    '/channel/${Uri.encodeComponent(channelId)}/post/'
    '${Uri.encodeComponent(postId)}',
  );
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

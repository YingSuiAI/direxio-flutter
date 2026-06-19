import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../channel/channel_inbox_data.dart';
import '../mock/mock_channels.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';

const _detailBg = Color(0xFFFAFAFA);
const _detailText = Color(0xFF262628);
const _detailMuted = Color(0xFFA3A3A4);
const _detailBody = Color(0xFF666666);
const _detailMeta = Color(0xFF777777);
const _detailCommentMeta = Color(0xFF999999);
const _detailAction = Color(0xFF727176);

class ChannelPostDetailPage extends ConsumerStatefulWidget {
  const ChannelPostDetailPage({
    super.key,
    required this.channelId,
    required this.postId,
  });

  final String channelId;
  final String postId;

  @override
  ConsumerState<ChannelPostDetailPage> createState() =>
      _ChannelPostDetailPageState();
}

class _ChannelPostDetailPageState extends ConsumerState<ChannelPostDetailPage> {
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _submittedCommentBody;
  String? _submittedCommentTimeLabel;
  int? _submittedCommentTs;
  _PostDetailData? _activeDetail;
  bool _bodyExpanded = false;
  bool _commentsExpanded = false;
  bool _commentsLoading = false;
  bool _commentsLoadingMore = false;
  bool _commentsHasMore = true;
  int _commentsPage = 0;
  String _commentsError = '';
  String _commentsKey = '';
  List<_PostComment> _comments = const [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_commentsExpanded || _commentsLoading || _commentsLoadingMore) return;
    if (!_commentsHasMore || !_scrollCtrl.hasClients) return;
    final position = _scrollCtrl.position;
    if (position.extentAfter > 160) return;
    final detail = _activeDetail;
    if (detail == null) return;
    unawaited(_loadMoreComments(detail));
  }

  _PostDetailData _currentDetail() {
    return _resolvePostDetail(ref, widget.channelId, widget.postId);
  }

  void _ensureCommentsKey(_PostDetailData detail) {
    final key = _commentsKeyFor(detail);
    if (_commentsKey == key) return;
    _commentsKey = key;
    _commentsExpanded = false;
    _commentsLoading = false;
    _commentsLoadingMore = false;
    _commentsHasMore = true;
    _commentsPage = 0;
    _commentsError = '';
    _comments = const [];
  }

  String _commentsKeyFor(_PostDetailData detail) {
    return '${detail.channelId}:${detail.postId}:${detail.realPost != null}';
  }

  @override
  Widget build(BuildContext context) {
    final detail = _currentDetail();
    _activeDetail = detail;
    _ensureCommentsKey(detail);
    final optimisticComment = _submittedCommentBody == null
        ? null
        : _PostComment(
            authorName: '我',
            body: _submittedCommentBody!,
            timeLabel: _submittedCommentTimeLabel ?? '刚刚',
            originServerTs: _submittedCommentTs ?? 0,
          );
    final commentItems = _withOptimisticComments(_comments, optimisticComment);
    final showComments = _commentsExpanded;

    return Scaffold(
      backgroundColor: _detailBgColor(context),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 106, 16, 28),
                children: [
                  _PostIntroPill(channelName: detail.channelName),
                  const SizedBox(height: 20),
                  _PostDetailCard(
                    detail: detail,
                    comments: commentItems,
                    showComments: showComments,
                    bodyExpanded: _bodyExpanded,
                    commentsLoading: _commentsLoading,
                    commentsLoadingMore: _commentsLoadingMore,
                    commentsHasMore: _commentsHasMore,
                    commentsError: _commentsError,
                    onToggleBodyExpanded: () =>
                        setState(() => _bodyExpanded = !_bodyExpanded),
                    onToggleCommentsExpanded: () => _toggleComments(detail),
                    commentController: _commentCtrl,
                    sending: _sending,
                    onSend: () => _sendComment(detail),
                    onPostReaction: () => _togglePostReaction(detail),
                    onCommentReaction: _toggleCommentReaction,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _PostDetailTopBar(
                onBack: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleComments(_PostDetailData detail) async {
    if (_commentsExpanded) {
      setState(() => _commentsExpanded = false);
      return;
    }
    setState(() => _commentsExpanded = true);
    if (_comments.isEmpty && !_commentsLoading) {
      await _loadInitialComments(detail);
    }
  }

  Future<void> _loadInitialComments(_PostDetailData detail) async {
    final expectedKey = _commentsKeyFor(detail);
    setState(() {
      _commentsLoading = true;
      _commentsError = '';
    });
    try {
      final loaded = await _fetchComments(detail, page: 1, pageSize: 5);
      if (!mounted || expectedKey != _commentsKey) return;
      setState(() {
        _comments = loaded;
        _commentsHasMore = loaded.length >= 5;
        _commentsPage = 1;
        _commentsLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _comments = const [];
        _commentsHasMore = false;
        _commentsLoading = false;
        _commentsError = '评论加载失败';
      });
    }
  }

  Future<void> _loadMoreComments(_PostDetailData detail) async {
    if (!_commentsHasMore || _comments.isEmpty) return;
    final expectedKey = _commentsKeyFor(detail);
    final nextPage = _commentsPage + 1;
    setState(() => _commentsLoadingMore = true);
    try {
      final loaded = await _fetchComments(
        detail,
        page: nextPage,
        pageSize: 5,
      );
      if (!mounted || expectedKey != _commentsKey) return;
      setState(() {
        _comments = _dedupeComments([..._comments, ...loaded]);
        _commentsHasMore = loaded.length >= 5;
        if (loaded.isNotEmpty) _commentsPage = nextPage;
        _commentsLoadingMore = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _commentsLoadingMore = false);
    }
  }

  Future<List<_PostComment>> _fetchComments(
    _PostDetailData detail, {
    required int page,
    required int pageSize,
  }) async {
    if (detail.realPost == null) {
      final all = _mockComments(detail, true);
      final start = (page <= 1 ? 0 : page - 1) * pageSize;
      return all.skip(start).take(pageSize).toList(growable: false);
    }
    final items = await ref.read(asClientProvider).getChannelComments(
          detail.channelId,
          detail.postId,
          page: page,
          pageSize: pageSize,
        );
    return [
      for (final item in items) _commentFromAs(item),
    ];
  }

  Future<void> _sendComment(_PostDetailData detail) async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      if (detail.realPost != null) {
        await ref.read(asClientProvider).createChannelComment(
              detail.channelId,
              detail.postId,
              messageType: 'text',
              body: body,
            );
        ref.invalidate(
          channelCommentsProvider(
            ChannelCommentsKey(
              channelId: detail.channelId,
              postId: detail.postId,
            ),
          ),
        );
        unawaited(
          ref
              .read(channelPostsProvider(detail.channelId).notifier)
              .refresh(silent: true),
        );
      }
      _commentCtrl.clear();
      if (mounted) {
        setState(() {
          _submittedCommentBody = body;
          _submittedCommentTimeLabel = _formatTime(
            DateTime.now().millisecondsSinceEpoch,
          );
          _submittedCommentTs = DateTime.now().millisecondsSinceEpoch;
          _commentsExpanded = true;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleCommentReaction(_PostComment comment) async {
    final channelId = comment.channelId.trim();
    final postId = comment.postId.trim();
    final commentId = comment.commentId.trim();
    if (channelId.isEmpty || postId.isEmpty || commentId.isEmpty) return;
    final result =
        await ref.read(asClientProvider).toggleChannelCommentReaction(
              channelId,
              postId,
              commentId,
            );
    if (mounted) {
      setState(() {
        _comments = [
          for (final item in _comments)
            if (item.commentId.trim() == commentId)
              item.copyWith(
                likeCount: result.reactionCount,
                reactedByMe: result.active,
              )
            else
              item,
        ];
      });
    }
    ref.invalidate(
      channelCommentsProvider(
        ChannelCommentsKey(channelId: channelId, postId: postId),
      ),
    );
  }

  Future<void> _togglePostReaction(_PostDetailData detail) async {
    if (detail.realPost == null) return;
    final channelId = detail.channelId.trim();
    final postId = detail.postId.trim();
    if (channelId.isEmpty || postId.isEmpty) return;
    await ref.read(asClientProvider).toggleChannelPostReaction(
          channelId,
          postId,
        );
    unawaited(
      ref.read(channelPostsProvider(channelId).notifier).refresh(silent: true),
    );
  }
}

class _PostDetailTopBar extends StatelessWidget {
  const _PostDetailTopBar({
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _GlassCircleAction(
              icon: Symbols.arrow_back,
              onTap: onBack,
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '帖子详情',
                  style: AppTheme.sans(
                    size: 20,
                    weight: FontWeight.w600,
                    color: _detailTextColor(context),
                  ).copyWith(height: 26 / 20),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _GlassCircleAction(
              icon: Symbols.more_vert,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _PostIntroPill extends StatelessWidget {
  const _PostIntroPill({required this.channelName});

  final String channelName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 24,
        constraints: const BoxConstraints(maxWidth: 270),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _detailPillColor(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '频道主Diana发布帖子，成员可评论和恢复',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.sans(
            size: 13,
            weight: FontWeight.w500,
            color: _detailSubtleTextColor(context),
          ),
        ),
      ),
    );
  }
}

class _PostDetailCard extends StatelessWidget {
  const _PostDetailCard({
    required this.detail,
    required this.comments,
    required this.showComments,
    required this.bodyExpanded,
    required this.commentsLoading,
    required this.commentsLoadingMore,
    required this.commentsHasMore,
    required this.commentsError,
    required this.onToggleBodyExpanded,
    required this.onToggleCommentsExpanded,
    required this.commentController,
    required this.sending,
    required this.onSend,
    required this.onPostReaction,
    required this.onCommentReaction,
  });

  final _PostDetailData detail;
  final List<_PostComment> comments;
  final bool showComments;
  final bool bodyExpanded;
  final bool commentsLoading;
  final bool commentsLoadingMore;
  final bool commentsHasMore;
  final String commentsError;
  final VoidCallback onToggleBodyExpanded;
  final VoidCallback onToggleCommentsExpanded;
  final TextEditingController commentController;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPostReaction;
  final Future<void> Function(_PostComment comment) onCommentReaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: _detailSurfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _detailCardShadowColor(context),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostAuthorHeader(detail: detail),
          const SizedBox(height: 8),
          _PostIdRow(postId: detail.displayPostId),
          const SizedBox(height: 18),
          Text(
            detail.title,
            style: AppTheme.sans(
              size: 18,
              weight: FontWeight.w600,
              color: _detailTextColor(context),
            ).copyWith(height: 26 / 18),
          ),
          const SizedBox(height: 6),
          Text(
            detail.body,
            maxLines: bodyExpanded ? null : 4,
            overflow:
                bodyExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w500,
              color: bodyExpanded
                  ? _detailTextColor(context)
                  : _detailBodyColor(context),
            ).copyWith(height: 20 / 13),
          ),
          const SizedBox(height: 14),
          _PostStatsRow(
            likeCount: detail.reactionCount,
            reactedByMe: detail.reactedByMe,
            commentCount: detail.commentCount,
            alignEnd: true,
            onLike: detail.realPost == null ? null : onPostReaction,
          ),
          if (showComments) ...[
            const SizedBox(height: 18),
            if (commentsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (commentsError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  commentsError,
                  style: AppTheme.sans(
                    size: 13,
                    color: _detailMutedColor(context),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (final comment in comments)
                    _CommentThreadRow(
                      comment: comment,
                      onReaction: () => onCommentReaction(comment),
                    ),
                  if (commentsLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!commentsHasMore && comments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '没有更多评论',
                        style: AppTheme.sans(
                          size: 12,
                          color: _detailMutedColor(context),
                        ),
                      ),
                    ),
                ],
              ),
          ],
          const SizedBox(height: 10),
          if (!bodyExpanded) _PostBodyExpandRow(onTap: onToggleBodyExpanded),
          if (detail.commentCount > 0 || showComments) ...[
            if (!bodyExpanded) const SizedBox(height: 8),
            _PostCommentsToggleRow(
              expanded: showComments,
              count: detail.commentCount,
              onTap: onToggleCommentsExpanded,
            ),
          ],
          const SizedBox(height: 12),
          _CommentInputRow(
            controller: commentController,
            sending: sending,
            onSend: onSend,
          ),
        ],
      ),
    );
  }
}

class _PostIdRow extends StatelessWidget {
  const _PostIdRow({required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    final id = postId.trim();
    if (id.isEmpty) return const SizedBox.shrink();
    return InkWell(
      key: const ValueKey('channel_post_detail_id_row'),
      onTap: () => _copyPostId(context, id),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              'ID:$id',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(
                size: 13,
                color: context.tk.textMute,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Symbols.content_copy,
            size: 14,
            color: context.tk.textMute,
          ),
        ],
      ),
    );
  }
}

Future<void> _copyPostId(BuildContext context, String postId) async {
  unawaited(Clipboard.setData(ClipboardData(text: postId)));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('已复制帖子 ID')),
  );
}

class _PostAuthorHeader extends StatelessWidget {
  const _PostAuthorHeader({required this.detail});

  final _PostDetailData detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PostAvatar(name: detail.authorName, size: 40, radius: 8),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  detail.authorName,
                  style: AppTheme.sans(
                    size: 16,
                    weight: FontWeight.w600,
                    color: _detailTextColor(context),
                  ).copyWith(height: 18 / 16),
                ),
                const SizedBox(width: 6),
                const _KindBadge(),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              detail.timeLabel,
              style: AppTheme.sans(size: 12, color: _detailMutedColor(context)),
            ),
          ],
        ),
      ],
    );
  }
}

class _PostStatsRow extends StatelessWidget {
  const _PostStatsRow({
    required this.likeCount,
    required this.reactedByMe,
    required this.commentCount,
    this.alignEnd = false,
    this.onLike,
  });

  final int likeCount;
  final bool reactedByMe;
  final int commentCount;
  final bool alignEnd;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onLike,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            child: Icon(
              Symbols.favorite,
              size: 22,
              color:
                  reactedByMe ? context.tk.danger : _detailIconColor(context),
              fill: reactedByMe ? 1 : 0,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text('$likeCount', style: _statStyle(context)),
        const SizedBox(width: 18),
        Icon(Symbols.chat_bubble, size: 21, color: _detailIconColor(context)),
        const SizedBox(width: 6),
        Text('$commentCount', style: _statStyle(context)),
      ],
    );
    return alignEnd ? Align(alignment: Alignment.centerRight, child: row) : row;
  }

  TextStyle _statStyle(BuildContext context) {
    return AppTheme.sans(
      size: 13,
      weight: FontWeight.w500,
      color: _detailMetaColor(context),
    ).copyWith(height: 20 / 13);
  }
}

class _CommentThreadRow extends StatelessWidget {
  const _CommentThreadRow({
    required this.comment,
    required this.onReaction,
  });

  final _PostComment comment;
  final Future<void> Function() onReaction;

  @override
  Widget build(BuildContext context) {
    final indent = comment.replyToName == null ? 0.0 : 34.0;
    final avatarSize = comment.replyToName == null ? 28.0 : 20.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostAvatar(name: comment.authorName, size: avatarSize, radius: 4),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: AppTheme.sans(
                        size: comment.replyToName == null ? 14 : 12,
                        weight: FontWeight.w600,
                        color: _detailCommentMetaColor(context),
                      ),
                    ),
                    if (comment.replyToName != null) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Symbols.arrow_forward_ios,
                        size: 8,
                        color: _detailCommentMetaColor(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        comment.replyToName!,
                        style: AppTheme.sans(
                          size: 12,
                          weight: FontWeight.w600,
                          color: _detailCommentMetaColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.body,
                  style: AppTheme.sans(
                    size: 13,
                    weight: FontWeight.w500,
                    color: _detailTextColor(context),
                  ).copyWith(height: 20 / 13),
                ),
                Row(
                  children: [
                    Text(
                      comment.timeLabel,
                      style: AppTheme.sans(
                        size: 10,
                        color: _detailMutedColor(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '回复',
                      style: AppTheme.sans(
                        size: 13,
                        weight: FontWeight.w500,
                        color: _detailActionColor(context),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      key: comment.commentId.trim().isEmpty
                          ? null
                          : ValueKey(
                              'channel_comment_like_${comment.commentId.trim()}',
                            ),
                      borderRadius: BorderRadius.circular(16),
                      onTap: comment.commentId.trim().isEmpty
                          ? null
                          : () => onReaction(),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          comment.reactedByMe
                              ? Symbols.favorite
                              : Symbols.favorite,
                          size: 20,
                          color: comment.reactedByMe
                              ? context.tk.danger
                              : _detailIconColor(context),
                          fill: comment.reactedByMe ? 1 : 0,
                        ),
                      ),
                    ),
                    Text(
                      '${comment.likeCount}',
                      style: AppTheme.sans(
                        size: 13,
                        weight: FontWeight.w500,
                        color: _detailMetaColor(context),
                      ),
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

class _PostBodyExpandRow extends StatelessWidget {
  const _PostBodyExpandRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 24, height: 1, color: _detailDividerColor(context)),
        const SizedBox(width: 6),
        InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Text(
                '展开更多',
                style: _expandTextStyle(context),
              ),
              const SizedBox(width: 3),
              Icon(
                Symbols.keyboard_arrow_down,
                size: 12,
                color: _detailActionColor(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _expandTextStyle(BuildContext context) {
    return AppTheme.sans(
      size: 13,
      weight: FontWeight.w500,
      color: _detailActionColor(context),
    ).copyWith(height: 20 / 13);
  }
}

class _PostCommentsToggleRow extends StatelessWidget {
  const _PostCommentsToggleRow({
    required this.expanded,
    required this.count,
    required this.onTap,
  });

  final bool expanded;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 24, height: 1, color: _detailDividerColor(context)),
            const SizedBox(width: 6),
            Text(
              expanded ? '收起评论' : '查看评论${count > 0 ? '($count)' : ''}',
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w500,
                color: _detailActionColor(context),
              ).copyWith(height: 20 / 13),
            ),
            const SizedBox(width: 3),
            Icon(
              expanded
                  ? Symbols.keyboard_arrow_up
                  : Symbols.keyboard_arrow_down,
              size: 12,
              color: _detailActionColor(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentInputRow extends StatelessWidget {
  const _CommentInputRow({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      width: double.infinity,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final showSend = value.text.trim().isNotEmpty || sending;
          return TextField(
            controller: controller,
            textInputAction: TextInputAction.send,
            textAlignVertical: TextAlignVertical.center,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              isDense: true,
              hintText: '输入评论...',
              hintStyle: AppTheme.sans(
                size: 13,
                weight: FontWeight.w500,
                color: _detailCommentMetaColor(context),
              ),
              filled: true,
              fillColor: _detailInputFillColor(context),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              suffixIcon: Opacity(
                opacity: showSend ? 1 : 0,
                child: IconButton(
                  onPressed: sending ? null : onSend,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: sending
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Symbols.send,
                          size: 18,
                          color: context.tk.accent,
                        ),
                ),
              ),
              suffixIconConstraints: const BoxConstraints.tightFor(
                width: 32,
                height: 32,
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            style: AppTheme.sans(size: 13, color: _detailTextColor(context)),
          );
        },
      ),
    );
  }
}

class _PostAvatar extends StatelessWidget {
  const _PostAvatar({
    required this.name,
    required this.size,
    required this.radius,
  });

  final String name;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = _avatarColors(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        name.trim().isEmpty ? 'A' : name.trim().characters.first.toUpperCase(),
        style: AppTheme.sans(
          size: size * 0.38,
          weight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _detailBadgeBgColor(context),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '帖子',
        style: AppTheme.sans(
          size: 8,
          weight: FontWeight.w500,
          color: _detailBadgeTextColor(context),
        ).copyWith(height: 10 / 8),
      ),
    );
  }
}

class _GlassCircleAction extends StatelessWidget {
  const _GlassCircleAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _detailGlassColor(context),
      shape: const CircleBorder(),
      elevation: 12,
      shadowColor: _detailGlassShadowColor(context),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 40,
          child: Icon(icon, size: 24, color: _detailTextColor(context)),
        ),
      ),
    );
  }
}

class _PostDetailData {
  const _PostDetailData({
    required this.channelId,
    required this.channelName,
    required this.postId,
    required this.authorName,
    required this.timeLabel,
    required this.title,
    required this.body,
    required this.reactionCount,
    required this.reactedByMe,
    required this.commentCount,
    this.realPost,
  });

  final String channelId;
  final String channelName;
  final String postId;
  final String authorName;
  final String timeLabel;
  final String title;
  final String body;
  final int reactionCount;
  final bool reactedByMe;
  final int commentCount;
  final AsChannelPost? realPost;

  String get displayPostId {
    final realPostId = realPost?.postId.trim() ?? '';
    if (realPostId.isNotEmpty) return realPostId;
    final eventId = realPost?.eventId.trim() ?? '';
    if (eventId.isNotEmpty) return eventId;
    return postId.trim();
  }
}

class _PostComment {
  const _PostComment({
    required this.authorName,
    required this.body,
    required this.timeLabel,
    this.commentId = '',
    this.channelId = '',
    this.postId = '',
    this.replyToName,
    this.likeCount = 6,
    this.reactedByMe = false,
    this.originServerTs = 0,
  });

  final String commentId;
  final String channelId;
  final String postId;
  final String authorName;
  final String? replyToName;
  final String body;
  final String timeLabel;
  final int likeCount;
  final bool reactedByMe;
  final int originServerTs;

  _PostComment copyWith({
    int? likeCount,
    bool? reactedByMe,
  }) {
    return _PostComment(
      commentId: commentId,
      channelId: channelId,
      postId: postId,
      authorName: authorName,
      replyToName: replyToName,
      body: body,
      timeLabel: timeLabel,
      likeCount: likeCount ?? this.likeCount,
      reactedByMe: reactedByMe ?? this.reactedByMe,
      originServerTs: originServerTs,
    );
  }
}

_PostDetailData _resolvePostDetail(
  WidgetRef ref,
  String channelId,
  String postId,
) {
  final realChannel = _findRealChannel(ref, channelId);
  final realPost = ref
      .watch(channelPostsProvider(channelId))
      .valueOrNull
      ?.where((post) => _realPostKey(post) == postId)
      .firstOrNull;
  if (realChannel != null && realPost != null) {
    return _PostDetailData(
      channelId: channelId,
      channelName: realChannel.name,
      postId: postId,
      authorName: realPost.authorName.trim().isEmpty
          ? _localpartFromMxid(realPost.authorId)
          : realPost.authorName.trim(),
      timeLabel: _formatTime(realPost.originServerTs),
      title: _titleFromBody(realPost.body),
      body: realPost.body.trim().isEmpty
          ? '[${realPost.messageType}]'
          : realPost.body,
      reactionCount: realPost.reactionCount,
      reactedByMe: realPost.reactedByMe,
      commentCount: realPost.commentCount,
      realPost: realPost,
    );
  }

  final mock = MockChannels.byId(channelId);
  if (mock != null) {
    for (final post in mock.posts) {
      if (_mockPostKey(post) == postId) {
        return _PostDetailData(
          channelId: channelId,
          channelName: mock.name,
          postId: postId,
          authorName: post.author,
          timeLabel: post.timeLabel,
          title: '我发布的帖子',
          body: post.body,
          reactionCount: _countFromLabel(post.reactionLabel, fallback: 6),
          reactedByMe: false,
          commentCount: post.commentCount,
        );
      }
    }
  }

  return _PostDetailData(
    channelId: channelId,
    channelName: realChannel?.name ?? mock?.name ?? '综合讨论',
    postId: postId,
    authorName: 'Alice',
    timeLabel: '10:55',
    title: '我发布的帖子',
    body: '我发布的帖子我发布的帖子我发布的帖子我发布的帖子，我发布的帖子我发布的帖子我发布的帖子我发布的帖子。',
    reactionCount: 6,
    reactedByMe: false,
    commentCount: 8,
  );
}

String _realPostKey(AsChannelPost post) {
  final id = post.postId.trim();
  if (id.isNotEmpty) return id;
  final eventId = post.eventId.trim();
  if (eventId.isNotEmpty) return eventId;
  return '${post.authorId}|${post.originServerTs}|${post.body}';
}

List<_PostComment> _mockComments(_PostDetailData detail, bool submitted) {
  if (!submitted) return const [];
  return const [
    _PostComment(
      authorName: 'Alice',
      body: '我发布的帖子我发布的帖子我发布的帖子我发布的帖子。',
      timeLabel: '10:55',
      originServerTs: 4,
    ),
    _PostComment(
      authorName: 'Mrra',
      replyToName: 'Alice',
      body: '我发布的帖子我发布的帖子。',
      timeLabel: '10:55',
      originServerTs: 3,
    ),
    _PostComment(
      authorName: 'Dridder',
      body: '我发布的帖子我发布的帖子。',
      timeLabel: '10:55',
      originServerTs: 2,
    ),
    _PostComment(
      authorName: 'Dridder',
      body: '我发布的帖子我发布的帖子。',
      timeLabel: '10:55',
      originServerTs: 1,
    ),
  ];
}

_PostComment _commentFromAs(AsChannelComment item) {
  return _PostComment(
    commentId: item.commentId,
    channelId: item.channelId,
    postId: item.postId,
    authorName: item.authorName.trim().isEmpty
        ? _localpartFromMxid(item.authorId)
        : item.authorName.trim(),
    body: item.body.trim().isEmpty ? '[${item.messageType}]' : item.body,
    timeLabel: _formatTime(item.originServerTs),
    likeCount: item.reactionCount,
    reactedByMe: item.reactedByMe,
    originServerTs: item.originServerTs,
  );
}

List<_PostComment> _withOptimisticComments(
  List<_PostComment> comments,
  _PostComment? optimistic,
) {
  if (optimistic == null) return comments;
  if (comments.any((item) => item.body == optimistic.body)) return comments;
  return [optimistic, ...comments];
}

List<_PostComment> _dedupeComments(List<_PostComment> comments) {
  final seen = <String>{};
  final result = <_PostComment>[];
  for (final comment in comments) {
    final key = comment.commentId.trim().isNotEmpty
        ? comment.commentId.trim()
        : '${comment.authorName}|${comment.originServerTs}|${comment.body}';
    if (!seen.add(key)) continue;
    result.add(comment);
  }
  return result;
}

ChannelInboxItem? _findRealChannel(WidgetRef ref, String channelId) {
  final bootstrap = ref.watch(asSyncCacheProvider).bootstrap;
  if (bootstrap == null) return null;
  final client = ref.watch(matrixClientProvider);
  final channels = ChannelInboxData.fromBootstrap(
    bootstrap,
    fallbackDomain: _clientServerName(client),
    roomNameForRoomId: (roomId) => _matrixRoomName(client, roomId),
    roomAvatarForRoomId: (roomId) => _matrixRoomAvatar(client, roomId),
  );
  for (final channel in channels) {
    if (channel.id == channelId) return channel;
  }
  return null;
}

String _mockPostKey(MockChannelPost post) =>
    '${post.author}|${post.timeLabel}|${post.body}';

String _titleFromBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return '我发布的帖子';
  final firstLine = trimmed.split('\n').first.trim();
  if (firstLine.length <= 14) return firstLine;
  return '我发布的帖子';
}

int _countFromLabel(String label, {required int fallback}) {
  final match = RegExp(r'\d+').firstMatch(label);
  return int.tryParse(match?.group(0) ?? '') ?? fallback;
}

String _localpartFromMxid(String mxid) {
  if (!mxid.startsWith('@') || !mxid.contains(':')) return mxid;
  return mxid.substring(1, mxid.indexOf(':'));
}

String _formatTime(int milliseconds) {
  if (milliseconds <= 0) return '10:55';
  final dt = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  return '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

String _clientServerName(Client client) {
  final userId = client.userID ?? '';
  final fromMxid = _serverNameFromMxid(userId);
  if (fromMxid != null && fromMxid.isNotEmpty) return fromMxid;
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

String? _serverNameFromMxid(String mxid) {
  final index = mxid.indexOf(':');
  if (index < 0 || index == mxid.length - 1) return null;
  return mxid.substring(index + 1);
}

List<Color> _avatarColors(String name) {
  final hash = name.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return switch (hash % 4) {
    0 => const [Color(0xFFBFC7D8), Color(0xFF7B879D)],
    1 => const [Color(0xFFD9B29A), Color(0xFF8A5A45)],
    2 => const [Color(0xFF9FC7E8), Color(0xFF477AA8)],
    _ => const [Color(0xFFC8C1ED), Color(0xFF6F64B5)],
  };
}

Color _detailBgColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.bg
      : _detailBg;
}

Color _detailSurfaceColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.surface
      : Colors.white;
}

Color _detailTextColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.text
      : _detailText;
}

Color _detailBodyColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.text
      : _detailBody;
}

Color _detailMutedColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.textMute
      : _detailMuted;
}

Color _detailIconColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.textMute
      : _detailMeta;
}

Color _detailMetaColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.textMute
      : _detailMeta;
}

Color _detailCommentMetaColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.textMute
      : _detailCommentMeta;
}

Color _detailActionColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.textMute
      : _detailAction;
}

Color _detailSubtleTextColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.textMute
      : const Color(0xFFAFAFAF);
}

Color _detailPillColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.surfaceHover
      : const Color(0xFFEBF0F4);
}

Color _detailDividerColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.border
      : const Color(0xFFD9D9D9);
}

Color _detailInputFillColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.surfaceHigh
      : const Color(0xFFF7F7F7);
}

Color _detailBadgeBgColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.secondaryContainer
      : const Color(0xFFE9F2FF);
}

Color _detailBadgeTextColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.onPrimaryContainer
      : const Color(0xFF66707F);
}

Color _detailCardShadowColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.28)
      : const Color(0xFFBFBFBF).withValues(alpha: 0.25);
}

Color _detailGlassColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? context.tk.surface.withValues(alpha: 0.82)
      : Colors.white.withValues(alpha: 0.65);
}

Color _detailGlassShadowColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.34)
      : Colors.black.withValues(alpha: 0.12);
}

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}

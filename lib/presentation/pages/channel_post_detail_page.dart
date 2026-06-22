import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../channel/channel_inbox_data.dart';
import '../channel/channel_post_media.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/product_conversations_provider.dart';
import '../utils/avatar_url.dart';
import '../widgets/portal_avatar.dart';

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

AppLocalizations? _l10n(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
  bool _autoLoadScheduled = false;

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

  _PostDetailData? _currentDetail() {
    return _resolvePostDetail(ref, widget.channelId, widget.postId);
  }

  void _ensureCommentsKey(_PostDetailData detail) {
    final key = _commentsKeyFor(detail);
    if (_commentsKey == key) return;
    _commentsKey = key;
    _commentsExpanded = true;
    _commentsLoading = false;
    _commentsLoadingMore = false;
    _commentsHasMore = true;
    _commentsPage = 0;
    _commentsError = '';
    _comments = const [];
    _autoLoadScheduled = false;
  }

  String _commentsKeyFor(_PostDetailData detail) {
    return '${detail.channelId}:${detail.postId}:${detail.realPost != null}';
  }

  @override
  Widget build(BuildContext context) {
    final detail = _currentDetail();
    _activeDetail = detail;
    if (detail == null) {
      return Scaffold(
        backgroundColor: _detailBgColor(context),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              const Positioned.fill(
                child: _PostMissingState(),
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
    _ensureCommentsKey(detail);
    _scheduleInitialCommentsLoad(detail);
    final l10n = _l10n(context);
    final optimisticComment = _submittedCommentBody == null
        ? null
        : _PostComment(
            authorName: l10n?.commonMe ?? '我',
            body: _submittedCommentBody!,
            timeLabel:
                _submittedCommentTimeLabel ?? l10n?.commonJustNow ?? '刚刚',
            originServerTs: _submittedCommentTs ?? 0,
          );
    final commentItems = _withOptimisticComments(_comments, optimisticComment);
    return Scaffold(
      backgroundColor: _detailBgColor(context),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(31, 58, 23, 112),
                children: [
                  _PostDetailContent(
                    detail: detail,
                    comments: commentItems,
                    bodyExpanded: _bodyExpanded,
                    commentsLoading: _commentsLoading,
                    commentsLoadingMore: _commentsLoadingMore,
                    commentsHasMore: _commentsHasMore,
                    commentsError: _commentsError,
                    onToggleBodyExpanded: () =>
                        setState(() => _bodyExpanded = !_bodyExpanded),
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PostDetailBottomBar(
                detail: detail,
                controller: _commentCtrl,
                sending: _sending,
                onSend: () => _sendComment(detail),
                onPostReaction: () => _togglePostReaction(detail),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleInitialCommentsLoad(_PostDetailData detail) {
    if (_autoLoadScheduled || _commentsLoading || _comments.isNotEmpty) return;
    if (detail.commentCount <= 0) return;
    _autoLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _comments.isNotEmpty || _commentsLoading) return;
      unawaited(_loadInitialComments(detail));
    });
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
        _commentsError =
            _l10n(context)?.channelPostCommentLoadFailed ?? '评论加载失败';
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
    final items = await ref.read(asClientProvider).getChannelComments(
          detail.channelId,
          detail.postId,
          page: page,
          pageSize: pageSize,
        );
    return [
      for (final item in items) _commentFromAs(ref, item),
    ];
  }

  Future<void> _sendComment(_PostDetailData detail) async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _sending || !detail.canCreateComment) return;
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
    final detail = _activeDetail;
    if (detail?.canToggleReaction != true) return;
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
    if (detail.realPost == null || !detail.canToggleReaction) return;
    final channelId = detail.channelId.trim();
    final postId = detail.postId.trim();
    if (channelId.isEmpty || postId.isEmpty) return;
    final reaction = await ref.read(asClientProvider).toggleChannelPostReaction(
          channelId,
          postId,
        );
    await ref
        .read(channelPostsProvider(channelId).notifier)
        .applyReaction(postId, reaction);
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
      height: 48,
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: 4,
            child: _GlassCircleAction(
              icon: Symbols.arrow_back,
              onTap: onBack,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostDetailContent extends StatelessWidget {
  const _PostDetailContent({
    required this.detail,
    required this.comments,
    required this.bodyExpanded,
    required this.commentsLoading,
    required this.commentsLoadingMore,
    required this.commentsHasMore,
    required this.commentsError,
    required this.onToggleBodyExpanded,
    required this.onCommentReaction,
  });

  final _PostDetailData detail;
  final List<_PostComment> comments;
  final bool bodyExpanded;
  final bool commentsLoading;
  final bool commentsLoadingMore;
  final bool commentsHasMore;
  final String commentsError;
  final VoidCallback onToggleBodyExpanded;
  final Future<void> Function(_PostComment comment) onCommentReaction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          detail.body,
          maxLines: bodyExpanded ? null : 4,
          overflow: bodyExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: AppTheme.sans(
            size: 13,
            weight: FontWeight.w500,
            color: _detailBodyColor(context),
          ).copyWith(height: 18 / 13),
        ),
        if (detail.images.isNotEmpty) ...[
          const SizedBox(height: 12),
          ChannelPostImageGrid(images: detail.images),
        ],
        const SizedBox(height: 15),
        Row(
          children: [
            Text(
              _commentCountLabel(context, detail.commentCount),
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w500,
                color: _detailTextColor(context),
              ).copyWith(height: 16 / 13),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (commentsLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: context.tk.accent),
            ),
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
                  onReaction: detail.canToggleReaction
                      ? () => onCommentReaction(comment)
                      : null,
                ),
              if (commentsLoadingMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: CircularProgressIndicator(color: context.tk.accent),
                  ),
                )
              else if (!commentsHasMore && comments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _l10n(context)?.channelPostNoMoreComments ?? '没有更多评论',
                    style: AppTheme.sans(
                      size: 12,
                      color: _detailMutedColor(context),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 180),
        Divider(height: 1, color: _detailDividerColor(context)),
      ],
    );
  }
}

String _commentCountLabel(BuildContext context, int count) {
  return _l10n(context)?.channelPostCommentCount(count) ?? '共$count条评论';
}

class _PostDetailBottomBar extends StatelessWidget {
  const _PostDetailBottomBar({
    required this.detail,
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onPostReaction,
  });

  final _PostDetailData detail;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPostReaction;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      color: _detailSurfaceColor(context),
      padding: EdgeInsets.fromLTRB(
        31,
        12,
        31,
        37 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          if (detail.canCreateComment)
            SizedBox(
              width: 170,
              height: 32,
              child: _CommentInputRow(
                controller: controller,
                sending: sending,
                onSend: onSend,
              ),
            )
          else
            const SizedBox(width: 170, height: 32),
          const Spacer(),
          _BottomStatButton(
            key: ValueKey('channel_post_detail_like_${detail.postId}'),
            icon: Symbols.favorite,
            count: detail.reactionCount,
            color: detail.reactedByMe ? t.danger : t.danger,
            fill: detail.reactedByMe ? 1 : 1,
            active: detail.reactedByMe,
            onTap: detail.realPost == null || !detail.canToggleReaction
                ? null
                : onPostReaction,
          ),
          const SizedBox(width: 10),
          _BottomStatButton(
            icon: Symbols.star,
            count: 0,
            color: t.accent,
            fill: 1,
            onTap: null,
          ),
          const SizedBox(width: 10),
          _BottomStatButton(
            icon: Symbols.chat_bubble,
            count: detail.commentCount,
            color: _detailIconColor(context),
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _BottomStatButton extends StatelessWidget {
  const _BottomStatButton({
    super.key,
    required this.icon,
    required this.count,
    required this.color,
    this.active = false,
    this.fill = 0,
    this.onTap,
  });

  final IconData icon;
  final int count;
  final Color color;
  final bool active;
  final double fill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon == Symbols.favorite)
          Image.asset(
            active ? 'assets/images/like.png' : 'assets/images/no-like.png',
            width: 20,
            height: 20,
          )
        else
          Icon(icon, size: 20, color: color, fill: fill),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: AppTheme.sans(
            size: 13,
            weight: FontWeight.w500,
            color: _detailMetaColor(context),
          ).copyWith(height: 20 / 13),
        ),
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      ),
    );
  }
}

class _CommentThreadRow extends StatelessWidget {
  const _CommentThreadRow({
    required this.comment,
    required this.onReaction,
  });

  final _PostComment comment;
  final Future<void> Function()? onReaction;

  @override
  Widget build(BuildContext context) {
    final indent = comment.replyToName == null ? 0.0 : 34.0;
    final avatarSize = comment.replyToName == null ? 28.0 : 20.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalAvatar(
            seed: comment.authorName,
            size: avatarSize,
            imageUrl: comment.avatarUrl.trim().isEmpty
                ? null
                : comment.avatarUrl.trim(),
            shape: AvatarShape.squircle,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: AppTheme.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: _detailCommentMetaColor(context),
                      ).copyWith(height: 18 / 14),
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
                Text(
                  comment.body,
                  style: AppTheme.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: _detailTextColor(context),
                  ).copyWith(height: 20 / 13),
                ),
                if (comment.timeLabel.trim().isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    comment.timeLabel,
                    style: AppTheme.sans(
                      size: 10,
                      color: _detailMutedColor(context),
                    ).copyWith(height: 12 / 10),
                  ),
                ],
              ],
            ),
          ),
        ],
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
              hintText: _l10n(context)?.channelPostCommentHint ?? '输入评论...',
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

class _PostMissingState extends StatelessWidget {
  const _PostMissingState();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.search_off, size: 36, color: t.textMute),
            const SizedBox(height: 10),
            Text(
              _l10n(context)?.channelPostMissingTitle ?? '帖子不存在',
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _l10n(context)?.channelPostMissingSubtitle ??
                  '该帖子可能已删除，或尚未同步到本机。',
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
    required this.canCreateComment,
    required this.canToggleReaction,
    this.images = const [],
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
  final bool canCreateComment;
  final bool canToggleReaction;
  final List<ChannelPostMediaImage> images;
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
    this.avatarUrl = '',
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
  final String avatarUrl;
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
      avatarUrl: avatarUrl,
      replyToName: replyToName,
      body: body,
      timeLabel: timeLabel,
      likeCount: likeCount ?? this.likeCount,
      reactedByMe: reactedByMe ?? this.reactedByMe,
      originServerTs: originServerTs,
    );
  }
}

_PostDetailData? _resolvePostDetail(
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
      canCreateComment: realChannel.canCreateComment,
      canToggleReaction: realChannel.canToggleReaction,
      images: channelPostImagesFromPost(realPost),
      realPost: realPost,
    );
  }

  return null;
}

String _realPostKey(AsChannelPost post) {
  final id = post.postId.trim();
  if (id.isNotEmpty) return id;
  final eventId = post.eventId.trim();
  if (eventId.isNotEmpty) return eventId;
  return '${post.authorId}|${post.originServerTs}|${post.body}';
}

_PostComment _commentFromAs(WidgetRef ref, AsChannelComment item) {
  return _PostComment(
    commentId: item.commentId,
    channelId: item.channelId,
    postId: item.postId,
    authorName: item.authorName.trim().isEmpty
        ? _localpartFromMxid(item.authorId)
        : item.authorName.trim(),
    avatarUrl: _commentAvatarUrl(ref, item.authorAvatarUrl),
    body: item.body.trim().isEmpty ? '[${item.messageType}]' : item.body,
    timeLabel: _formatTime(item.originServerTs),
    likeCount: item.reactionCount,
    reactedByMe: item.reactedByMe,
    originServerTs: item.originServerTs,
  );
}

String _commentAvatarUrl(WidgetRef ref, String rawUrl) {
  return avatarHttpUrl(ref.read(matrixClientProvider), rawUrl) ?? '';
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
  final productConversations =
      ref.watch(productConversationsProvider).valueOrNull ?? const [];
  final channels = ChannelInboxData.fromBootstrap(
    bootstrap,
    fallbackDomain: _clientServerName(client),
    productConversations: productConversations,
    roomNameForRoomId: (roomId) => _matrixRoomName(client, roomId),
    roomAvatarForRoomId: (roomId) => _matrixRoomAvatar(client, roomId),
  );
  for (final channel in channels) {
    if (channel.id == channelId) return channel;
  }
  return null;
}

String _titleFromBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return '';
  final firstLine = trimmed.split('\n').first.trim();
  if (firstLine.length <= 14) return firstLine;
  return '';
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

Color _detailBgColor(BuildContext context) {
  return context.tk.bg;
}

Color _detailSurfaceColor(BuildContext context) {
  return context.tk.surface;
}

Color _detailTextColor(BuildContext context) {
  return context.tk.text;
}

Color _detailBodyColor(BuildContext context) {
  return context.tk.textMute;
}

Color _detailMutedColor(BuildContext context) {
  return context.tk.textMute.withValues(alpha: 0.64);
}

Color _detailIconColor(BuildContext context) {
  return context.tk.textMute;
}

Color _detailMetaColor(BuildContext context) {
  return context.tk.textMute;
}

Color _detailCommentMetaColor(BuildContext context) {
  return context.tk.textMute.withValues(alpha: 0.72);
}

Color _detailDividerColor(BuildContext context) {
  return context.tk.border.withValues(alpha: 0.48);
}

Color _detailInputFillColor(BuildContext context) {
  return context.tk.surfaceHover;
}

Color _detailGlassColor(BuildContext context) {
  return context.tk.surface.withValues(alpha: 0.82);
}

Color _detailGlassShadowColor(BuildContext context) {
  return context.tk.text.withValues(
    alpha: Theme.of(context).brightness == Brightness.dark ? 0.34 : 0.12,
  );
}

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}

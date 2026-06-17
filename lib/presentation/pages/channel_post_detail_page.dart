import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _submittedComment = false;
  String? _submittedCommentBody;
  String? _submittedCommentTimeLabel;
  bool _expanded = false;
  bool _sending = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _resolvePostDetail(ref, widget.channelId, widget.postId);
    final optimisticComment = _submittedCommentBody == null
        ? null
        : _PostComment(
            authorName: '我',
            body: _submittedCommentBody!,
            timeLabel: _submittedCommentTimeLabel ?? '刚刚',
          );
    final AsyncValue<List<_PostComment>> comments = detail.realPost == null
        ? AsyncValue.data(_mockComments(detail, _submittedComment))
        : _withOptimisticComment(
            ref
                .watch(
                  channelCommentsProvider(
                    ChannelCommentsKey(
                      channelId: detail.channelId,
                      postId: detail.postId,
                    ),
                  ),
                )
                .whenData(
                  (items) => [
                    for (final item in items)
                      _PostComment(
                        commentId: item.commentId,
                        channelId: item.channelId,
                        postId: item.postId,
                        authorName: item.authorName.trim().isEmpty
                            ? _localpartFromMxid(item.authorId)
                            : item.authorName.trim(),
                        body: item.body,
                        timeLabel: _formatTime(item.originServerTs),
                        likeCount: item.reactionCount,
                        reactedByMe: item.reactedByMe,
                      ),
                  ],
                ),
            optimisticComment,
          );
    final loadedComments = comments.valueOrNull ?? const <_PostComment>[];
    final showComments = _submittedComment || loadedComments.isNotEmpty;

    return Scaffold(
      backgroundColor: _detailBgColor(context),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 106, 16, 28),
                children: [
                  _PostIntroPill(channelName: detail.channelName),
                  const SizedBox(height: 20),
                  _PostDetailCard(
                    detail: detail,
                    comments: comments,
                    showComments: showComments,
                    expanded: _expanded,
                    onToggleExpanded: () =>
                        setState(() => _expanded = !_expanded),
                    commentController: _commentCtrl,
                    sending: _sending,
                    onSend: () => _sendComment(detail),
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
                title: detail.channelName,
                onBack: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
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
          _submittedComment = true;
          _submittedCommentBody = body;
          _submittedCommentTimeLabel = _formatTime(
            DateTime.now().millisecondsSinceEpoch,
          );
          _expanded = true;
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
    await ref.read(asClientProvider).toggleChannelCommentReaction(
          channelId,
          postId,
          commentId,
        );
    ref.invalidate(
      channelCommentsProvider(
        ChannelCommentsKey(channelId: channelId, postId: postId),
      ),
    );
  }
}

class _PostDetailTopBar extends StatelessWidget {
  const _PostDetailTopBar({
    required this.title,
    required this.onBack,
  });

  final String title;
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
                  title,
                  style: AppTheme.sans(
                    size: 20,
                    weight: FontWeight.w600,
                    color: _detailTextColor(context),
                  ).copyWith(height: 26 / 20),
                ),
                const SizedBox(width: 6),
                Icon(
                  Symbols.lock,
                  size: 15,
                  color: context.tk.accent,
                  fill: 1,
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
    required this.expanded,
    required this.onToggleExpanded,
    required this.commentController,
    required this.sending,
    required this.onSend,
    required this.onCommentReaction,
  });

  final _PostDetailData detail;
  final AsyncValue<List<_PostComment>> comments;
  final bool showComments;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final TextEditingController commentController;
  final bool sending;
  final VoidCallback onSend;
  final Future<void> Function(_PostComment comment) onCommentReaction;

  @override
  Widget build(BuildContext context) {
    final commentItems = comments.valueOrNull ?? const <_PostComment>[];
    final visibleComments = expanded ? commentItems : commentItems.take(1);
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
            maxLines: showComments ? null : 4,
            overflow:
                showComments ? TextOverflow.visible : TextOverflow.ellipsis,
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w500,
              color: showComments
                  ? _detailTextColor(context)
                  : _detailBodyColor(context),
            ).copyWith(height: 20 / 13),
          ),
          const SizedBox(height: 14),
          _PostStatsRow(
            likeCount: detail.reactionCount,
            commentCount: detail.commentCount,
            alignEnd: true,
          ),
          if (showComments) ...[
            const SizedBox(height: 18),
            comments.when(
              data: (_) => Column(
                children: [
                  for (final comment in visibleComments)
                    _CommentThreadRow(
                      comment: comment,
                      onReaction: () => onCommentReaction(comment),
                    ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '评论加载失败',
                  style: AppTheme.sans(
                    size: 13,
                    color: _detailMutedColor(context),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (!showComments || commentItems.length > 1)
            _PostExpandRow(
              expanded: expanded,
              canCollapse: showComments,
              onTap: onToggleExpanded,
            ),
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
    required this.commentCount,
    this.alignEnd = false,
  });

  final int likeCount;
  final int commentCount;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Symbols.favorite,
          size: 22,
          color: _detailIconColor(context),
          fill: 0,
        ),
        const SizedBox(width: 6),
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

class _PostExpandRow extends StatelessWidget {
  const _PostExpandRow({
    required this.expanded,
    required this.canCollapse,
    required this.onTap,
  });

  final bool expanded;
  final bool canCollapse;
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
                expanded ? '展开更多' : '展开更多',
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
        if (canCollapse) ...[
          const SizedBox(width: 34),
          InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Text('收起', style: _expandTextStyle(context)),
                const SizedBox(width: 3),
                Icon(
                  Symbols.keyboard_arrow_up,
                  size: 12,
                  color: _detailActionColor(context),
                ),
              ],
            ),
          ),
        ],
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
  final int commentCount;
  final AsChannelPost? realPost;
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
    ),
    _PostComment(
      authorName: 'Mrra',
      replyToName: 'Alice',
      body: '我发布的帖子我发布的帖子。',
      timeLabel: '10:55',
    ),
    _PostComment(
      authorName: 'Dridder',
      body: '我发布的帖子我发布的帖子。',
      timeLabel: '10:55',
    ),
    _PostComment(
      authorName: 'Dridder',
      body: '我发布的帖子我发布的帖子。',
      timeLabel: '10:55',
    ),
  ];
}

AsyncValue<List<_PostComment>> _withOptimisticComment(
  AsyncValue<List<_PostComment>> comments,
  _PostComment? optimistic,
) {
  if (optimistic == null) return comments;
  final items = comments.valueOrNull;
  if (items == null) return AsyncValue.data([optimistic]);
  if (items.any((item) => item.body == optimistic.body)) return comments;
  return AsyncValue.data([...items, optimistic]);
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

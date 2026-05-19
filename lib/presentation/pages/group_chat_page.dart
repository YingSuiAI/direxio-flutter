import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/m3/glass_header.dart';

class GroupChatPage extends ConsumerStatefulWidget {
  const GroupChatPage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends ConsumerState<GroupChatPage> {
  final _msgCtrl = TextEditingController();
  Timeline? _timeline;
  bool _loading = true;

  Room? get _room => ref.read(matrixClientProvider).getRoomById(widget.roomId);

  @override
  void initState() {
    super.initState();
    _initTimeline();
  }

  Future<void> _initTimeline() async {
    final room = _room;
    if (room == null) return;
    void rebuild() {
      if (mounted) setState(() {});
    }

    try {
      _timeline = await room.getTimeline(
        onUpdate: rebuild,
        onChange: (_) => rebuild(),
        onInsert: (_) => rebuild(),
        onRemove: (_) => rebuild(),
      );
    } on Object catch (e) {
      debugPrint('getTimeline failed: $e');
    }
    if (mounted) setState(() => _loading = false);
    final tl = _timeline;
    if (tl != null) {
      unawaited(() async {
        var attempts = 0;
        while (attempts < 5 &&
            tl.canRequestHistory &&
            tl.events.where((e) => e.type == EventTypes.Message).length < 50) {
          try {
            await tl.requestHistory(historyCount: 30);
          } on Object catch (e) {
            debugPrint('timeline.requestHistory failed: $e');
            break;
          }
          attempts++;
        }
        if (mounted) setState(() {});
      }());
    }
  }

  @override
  void dispose() {
    _timeline?.cancelSubscriptions();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    await _room?.sendTextEvent(text);
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    if (room == null) {
      return const Scaffold(body: Center(child: Text('群组不存在')));
    }
    final t = context.tk;
    final name = room.getLocalizedDisplayname();
    final memberCount = room.summary.mJoinedMemberCount ?? 0;
    final events =
        _timeline?.events.where((e) => e.type == EventTypes.Message).toList() ??
        [];
    final myId = ref.read(matrixClientProvider).userID;

    return Scaffold(
      body: Column(
        children: [
          GlassHeader.detail(
            title: name,
            subtitle: '$memberCount 名成员',
            centerLeading: _GroupAvatar(seed: name),
            actions: [
              GlassHeaderButton(
                icon: Symbols.videocam,
                color: t.accent,
                onTap: () =>
                    context.push('/call/${Uri.encodeComponent(widget.roomId)}'),
              ),
              GlassHeaderButton(
                icon: Symbols.more_vert,
                color: t.textMute,
                onTap: () => context.push(
                  '/group-detail/${Uri.encodeComponent(widget.roomId)}',
                ),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.accent,
                      ),
                    ),
                  )
                : events.isEmpty
                ? Center(
                    child: Text(
                      '还没有消息',
                      style: AppTheme.sans(size: 13, color: t.textMute),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: events.length,
                    itemBuilder: (context, i) {
                      final e = events[i];
                      return _GroupMessageBubble(
                        event: e,
                        isMe: e.senderId == myId,
                      );
                    },
                  ),
          ),
          _GroupChatInputBar(ctrl: _msgCtrl, onSend: _send),
        ],
      ),
    );
  }
}

/// 头部群头像：squircle, tertiary-container 底, 白色字。
class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.seed});
  final String seed;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final letter = seed.isNotEmpty ? seed.characters.first.toUpperCase() : '#';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: t.accentCool,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: AppTheme.sans(
          size: 15,
          weight: FontWeight.w600,
          color: t.onAccent,
        ),
      ),
    );
  }
}

/// 群消息气泡：他人 = 头像 + 姓名 + surface 气泡 + 左上小圆角;
/// 我方 = 右对齐 accent 气泡 + 右上小圆角，无头像无姓名。
class _GroupMessageBubble extends StatelessWidget {
  const _GroupMessageBubble({required this.event, required this.isMe});
  final Event event;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final body = event.body;

    final bubble = Container(
      decoration: BoxDecoration(
        color: isMe ? t.accent : t.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMe ? 16 : 4),
          topRight: Radius.circular(isMe ? 4 : 16),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        body,
        style: AppTheme.sans(size: 17, color: isMe ? t.onAccent : t.text),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _MemberAvatar(seed: event.senderId, name: senderName),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        senderName,
                        style: AppTheme.sans(size: 11, color: t.textMute),
                      ),
                    ),
                  bubble,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 成员色彩头像：32×32 圆形，按 seed 取色。
class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.seed, required this.name});
  final String seed;
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final palette = <(Color bg, Color fg)>[
      (t.accent, t.onAccent),
      (t.accentCool, t.onAccent),
      (t.primaryContainer, t.onPrimaryContainer),
      (t.danger, t.onAccent),
    ];
    final hash = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    final (bg, fg) = palette[hash % palette.length];
    final letter = (name.isNotEmpty ? name : seed).characters.first
        .toUpperCase();
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// 群聊输入栏：add_circle + 圆角输入框（含 mood）+ 发送箭头。
class _GroupChatInputBar extends StatelessWidget {
  const _GroupChatInputBar({required this.ctrl, required this.onSend});
  final TextEditingController ctrl;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: t.bg.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(color: t.border.withValues(alpha: 0.5)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Symbols.add_circle, size: 28, color: t.textMute),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.surfaceHover,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ctrl,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => onSend(),
                              minLines: 1,
                              maxLines: 5,
                              style: AppTheme.sans(size: 17, color: t.text),
                              decoration: InputDecoration(
                                hintText: '消息…',
                                hintStyle: AppTheme.sans(
                                  size: 17,
                                  color: t.textMute,
                                ),
                                isCollapsed: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {},
                            child: Icon(
                              Symbols.mood,
                              size: 20,
                              color: t.textMute,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: t.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onSend,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Symbols.arrow_upward,
                          size: 20,
                          color: t.onAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

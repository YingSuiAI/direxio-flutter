import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../widgets/portal_avatar.dart';
import '../mock/mock_data.dart';
import '../mock/mcp_policy.dart';
import '../mock/mock_mcp_client.dart';
import '../widgets/agent_message_body.dart';
import '../widgets/tool_call_bubble.dart';
import '../widgets/m3/glass_header.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CHAT PAGE — index.html `s-chat` 1:1 复刻
//
// 真实数据通路（Matrix）+ Mock 数据通路（_MockChatScaffold）并存，业务逻辑全部
// 保留；仅 widget 树/视觉按 `s-chat` (index.html 第 392-505 行) 与 `s-agent`
// (第 245-371 行) 重写：头部 / 气泡 / 输入栏 / +号面板 / 表情面板 / 长按上下文
// 菜单 / 多选栏 / 回复栏。
// ═══════════════════════════════════════════════════════════════════════════

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _msgCtrl = TextEditingController();
  Timeline? _timeline;
  bool _loading = true;

  // s-chat 视觉状态
  bool _showPlusPanel = false;
  bool _showEmojiPanel = false;
  bool _multiSelect = false;
  final Set<String> _selected = {};
  Event? _replyTo;

  Room? get _room => ref.read(matrixClientProvider).getRoomById(widget.roomId);

  /// 未登录且 roomId 命中 mock 数据时走 mock 渲染；
  /// 已登录则一律走真 Matrix timeline（真房间 id 不会以 mock_ 开头）。
  bool get _useMock {
    final isLoggedIn =
        ref.read(authStateNotifierProvider).valueOrNull?.isLoggedIn ?? false;
    return !isLoggedIn && MockData.byId(widget.roomId) != null;
  }

  @override
  void initState() {
    super.initState();
    if (_useMock) {
      _loading = false;
      return;
    }
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
      unawaited(_backfillHistory(tl));
    }
  }

  Future<void> _backfillHistory(Timeline timeline) async {
    var attempts = 0;
    while (attempts < 5 &&
        timeline.canRequestHistory &&
        timeline.events.where((e) => e.type == EventTypes.Message).length <
            50) {
      try {
        await timeline.requestHistory(historyCount: 30);
      } on Object catch (e) {
        debugPrint('timeline.requestHistory failed: $e');
        break;
      }
      attempts++;
    }
    if (mounted) setState(() {});
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
    setState(() => _replyTo = null);
    await _room?.sendTextEvent(text);
  }

  void _togglePlus() => setState(() {
    _showPlusPanel = !_showPlusPanel;
    if (_showPlusPanel) _showEmojiPanel = false;
  });

  void _toggleEmoji() => setState(() {
    _showEmojiPanel = !_showEmojiPanel;
    if (_showEmojiPanel) _showPlusPanel = false;
  });

  void _closePanels() => setState(() {
    _showPlusPanel = false;
    _showEmojiPanel = false;
  });

  Future<void> _onLongPressEvent(BuildContext ctx, Event e, Offset pos) async {
    final action = await _showMsgContextMenu(ctx, pos);
    if (!mounted || action == null) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: e.body));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已复制'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        break;
      case 'quote':
        setState(() => _replyTo = e);
        break;
      case 'multi':
        setState(() {
          _multiSelect = true;
          _selected.add(e.eventId);
        });
        break;
      case 'delete':
        try {
          await e.redactEvent();
        } on Object catch (err) {
          debugPrint('redact failed: $err');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useMock) {
      return _MockChatScaffold(conv: MockData.byId(widget.roomId)!);
    }

    final room = _room;
    final t = context.tk;
    if (room == null) {
      return const Scaffold(body: Center(child: Text('会话不存在')));
    }

    final events =
        _timeline?.events.where((e) => e.type == EventTypes.Message).toList() ??
        [];

    final mxid = room.directChatMatrixID ?? '';
    final name = room.getLocalizedDisplayname();

    return Scaffold(
      body: Column(
        children: [
          GlassHeader.detail(
            title: name,
            subtitle: mxid.isNotEmpty ? '在线' : '端对端加密',
            subtitleIcon: mxid.isEmpty ? Symbols.lock : null,
            centerLeading: SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                children: [
                  PortalAvatar(seed: name, size: 36),
                  const Positioned(
                    bottom: 0,
                    right: 0,
                    child: OnlineDot(size: 10),
                  ),
                ],
              ),
            ),
            actions: [
              GlassHeaderButton(
                icon: Symbols.call,
                color: t.accent,
                onTap: () =>
                    context.push('/call/${Uri.encodeComponent(widget.roomId)}'),
              ),
              GlassHeaderButton(
                icon: Symbols.videocam,
                color: t.accent,
                onTap: () =>
                    context.push('/call/${Uri.encodeComponent(widget.roomId)}'),
              ),
              GlassHeaderButton(
                icon: Symbols.more_vert,
                color: t.accent,
                onTap: () => context.push(
                  '/chat-info/${Uri.encodeComponent(widget.roomId)}',
                ),
              ),
            ],
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closePanels,
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
                        '开始你们的第一条消息',
                        style: AppTheme.sans(size: 13, color: t.textMute),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                      itemCount: events.length + 1,
                      itemBuilder: (context, i) {
                        if (i == events.length) {
                          return const _E2eFooter();
                        }
                        final e = events[i];
                        final isMe = e.senderId == e.room.client.userID;
                        final selected = _selected.contains(e.eventId);
                        return _SChatBubble(
                          isMe: isMe,
                          text: e.body,
                          time: DateFormat('HH:mm').format(e.originServerTs),
                          showRead: isMe,
                          avatarSeed: e.senderId,
                          selected: selected,
                          multiSelect: _multiSelect,
                          onTap: _multiSelect
                              ? () => setState(() {
                                  if (selected) {
                                    _selected.remove(e.eventId);
                                  } else {
                                    _selected.add(e.eventId);
                                  }
                                })
                              : null,
                          onLongPressAt: (pos) =>
                              _onLongPressEvent(context, e, pos),
                        );
                      },
                    ),
            ),
          ),
          if (_replyTo != null)
            _ReplyBar(
              text: _replyTo!.body,
              sender: _replyTo!.senderFromMemoryOrFallback.calcDisplayname(),
              onClose: () => setState(() => _replyTo = null),
            ),
          if (_multiSelect)
            _MultiSelectBar(
              count: _selected.length,
              onExit: () => setState(() {
                _multiSelect = false;
                _selected.clear();
              }),
              onForward: () {},
              onDelete: () async {
                for (final id in _selected.toList()) {
                  Event? ev;
                  for (final e in events) {
                    if (e.eventId == id) {
                      ev = e;
                      break;
                    }
                  }
                  if (ev == null) continue;
                  try {
                    await ev.redactEvent();
                  } on Object catch (err) {
                    debugPrint('redact failed: $err');
                  }
                }
                setState(() {
                  _multiSelect = false;
                  _selected.clear();
                });
              },
            )
          else
            _SChatInputBar(
              ctrl: _msgCtrl,
              onSend: _send,
              onPlus: _togglePlus,
              onEmoji: _toggleEmoji,
              plusActive: _showPlusPanel,
              emojiActive: _showEmojiPanel,
            ),
          if (_showPlusPanel) const _PlusPanel(),
          if (_showEmojiPanel)
            _EmojiPanel(
              onPick: (e) {
                final c = _msgCtrl;
                final base = c.text;
                c.text = base + e;
                c.selection = TextSelection.collapsed(offset: c.text.length);
              },
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Mock 聊天页：roomId 命中 MockData 时使用，无需 Matrix client。
// ═══════════════════════════════════════════════════════════════════════════

class _MockChatScaffold extends ConsumerStatefulWidget {
  const _MockChatScaffold({required this.conv});
  final MockConversation conv;

  @override
  ConsumerState<_MockChatScaffold> createState() => _MockChatScaffoldState();
}

class _PendingConfirm {
  _PendingConfirm({
    required this.tool,
    required this.args,
    required this.preview,
    required this.onConfirm,
  });
  final String tool;
  final Map<String, dynamic> args;
  final String preview;
  final VoidCallback onConfirm;
}

class _MockChatScaffoldState extends ConsumerState<_MockChatScaffold> {
  final _ctrl = TextEditingController();
  late List<MockMessage> _messages;
  bool _agentBusy = false;
  _PendingConfirm? _pendingConfirm;
  Timer? _streamTimer;
  static const _agentId = 'local-aibot';

  // s-chat 视觉状态
  bool _showPlusPanel = false;
  bool _showEmojiPanel = false;
  bool _multiSelect = false;
  final Set<int> _selected = {};
  MockMessage? _replyTo;

  bool get _isAiBot => widget.conv.id == 'mock_aibot';

  @override
  void initState() {
    super.initState();
    _messages = List.of(widget.conv.messages);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _streamTimer?.cancel();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(MockMessage(isMe: true, text: text, time: DateTime.now()));
      _ctrl.clear();
      _replyTo = null;
    });
    if (_isAiBot) {
      _streamAgentReply('收到："$text"。\n\n（这是 mock 回复，真接 LLM 后会基于上下文回答）');
    }
  }

  /// 流式输出：按字符 append，制造打字机感
  void _streamAgentReply(String full, {int charDelayMs = 12}) {
    _streamTimer?.cancel();
    setState(() {
      _agentBusy = true;
      _messages.add(MockMessage(isMe: false, text: '', time: DateTime.now()));
    });
    int i = 0;
    _streamTimer = Timer.periodic(Duration(milliseconds: charDelayMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (i >= full.length) {
        t.cancel();
        setState(() => _agentBusy = false);
        return;
      }
      i = (i + 2).clamp(0, full.length);
      setState(() {
        final last = _messages.last;
        _messages[_messages.length - 1] = MockMessage(
          isMe: last.isMe,
          text: full.substring(0, i),
          time: last.time,
        );
      });
    });
  }

  void _addToolBubble({
    required String tool,
    required Map<String, dynamic> args,
    required String summary,
    required int latencyMs,
    List<String> warnings = const [],
    bool denied = false,
    String? deniedReason,
  }) {
    setState(() {
      _messages.add(
        MockMessage(
          isMe: false,
          text: '',
          time: DateTime.now(),
          kind: MockMsgKind.toolCall,
          toolName: tool,
          toolArgs: args,
          toolResultSummary: denied ? (deniedReason ?? '被拒') : summary,
          toolLatencyMs: latencyMs,
          toolWarnings: [...warnings, if (denied) deniedReason ?? '权限不足'],
        ),
      );
    });
  }

  void _addUserAction(String text) {
    _messages.add(MockMessage(isMe: true, text: text, time: DateTime.now()));
  }

  Future<void> _onTokenUsage() async {
    setState(() => _addUserAction('/查询 token 用量'));
    try {
      final r = await _callToolWithBubble('token_usage', {});
      final d = r.data;
      _streamAgentReply(
        '## 📊 本月 Token 用量\n\n'
        '| 类别 | 数量 |\n'
        '| --- | ---: |\n'
        '| 输入 | `${d['input']}` |\n'
        '| 输出 | `${d['output']}` |\n'
        '| **总计** | **${d['total']} / ${d['limit']}** |\n'
        '| 占比 | ${(d['total'] / d['limit'] * 100).toStringAsFixed(1)}% |\n\n'
        '**当前模型**：`${d['model']}`  \n'
        '**本月预计支出**：¥${d['cost_cny']}\n\n'
        '> ⏰ 配额重置时间：**2026-06-01**',
      );
    } on McpDeniedException {
      /* 已写气泡 */
    }
  }

  Future<void> _onSummarizeRecent() async {
    setState(() => _addUserAction('/总结最近谁和我聊了什么'));
    try {
      final who = await _callToolWithBubble('list_conversations', {
        'query': 'jack',
      });
      final convs = who.data['conversations'] as List;
      if (convs.isEmpty) {
        _streamAgentReply('没有匹配到名为 Jack 的会话。');
        return;
      }
      final target = convs.first;
      final r = await _callToolWithBubble('get_recent_messages', {
        'room_id': target['id'],
        'limit': 50,
      });
      final msgs = (r.data['messages'] as List).cast<Map>();
      final preview = msgs
          .take(3)
          .map((m) => '> **${m['sender_name']}**：${m['text']}')
          .join('\n>\n');

      final policy = ref.read(mcpPolicyStoreProvider)[_agentId]!;
      final warnLines = <String>[
        if (r.warnings.isNotEmpty) ...r.warnings.map((w) => '> ⚠️ $w'),
        '> 当前窗口：**${policy.historyWindow.label}**；范围：**${policy.summary}**',
      ];

      _streamAgentReply(
        '## 📨 最近联系人活动\n\n'
        '### ${target['name']} `${target['mxid']}`\n\n'
        '共 **${msgs.length}** 条消息，未读 **${target['unread']}** 条。\n\n'
        '**关键内容**\n\n'
        '- 周一下午评审会改期至 **周二 10:00**，会议室 `A 区 3 楼`\n'
        '- 需带上次的 PRD 文档参会\n'
        '- 询问周末是否有空一起打球\n\n'
        '**消息预览**\n\n'
        '$preview\n\n'
        '---\n\n'
        '**建议行动**\n\n'
        '- ✅ 已在日历更新评审会时间\n'
        '- ⏰ 待办：整理 PRD 文档\n'
        '- 💬 待回复：周末是否打球（**提示**：点下方"代我回复"按钮，将经你确认后发送）\n\n'
        '${warnLines.join('\n')}',
      );
    } on McpDeniedException {
      /* 已写气泡 */
    }
  }

  void _onNewSession() {
    _streamTimer?.cancel();
    setState(() {
      _messages.clear();
      _agentBusy = false;
    });
    _streamAgentReply(
      '你好，我是 **AI Bot**，新会话已开始 👋\n\n'
      '你可以让我：\n\n'
      '- 总结某个联系人最近的聊天\n'
      '- 查询 Token 用量\n'
      '- 起草回复消息（写操作会经你确认）\n'
      '- 查找历史消息\n\n'
      '> 我的权限范围可在右上角 **管理** 中调整。',
    );
  }

  void _onAgentDraftReply() {
    setState(() {
      _pendingConfirm = _PendingConfirm(
        tool: 'send_message',
        args: {'room_id': 'mock_jack', 'text': '周日下午 3 点万体馆见，到时候打你电话。'},
        preview: '将发送给 **Jack**：\n\n> 周日下午 3 点万体馆见，到时候打你电话。',
        onConfirm: () async {
          final args = _pendingConfirm!.args;
          setState(() => _pendingConfirm = null);
          try {
            await _callToolWithBubble(
              'send_message',
              args,
              userConfirmed: true,
            );
            _streamAgentReply('✅ 已替你发送给 Jack。');
          } on McpDeniedException {
            /* 已写气泡 */
          }
        },
      );
    });
  }

  Future<void> _onLongPressMsg(MockMessage m, Offset pos) async {
    if (m.kind != MockMsgKind.text) return;
    final action = await _showMsgContextMenu(context, pos);
    if (!mounted || action == null) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已复制'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        break;
      case 'quote':
        setState(() => _replyTo = m);
        break;
      case 'forward':
        // 占位
        break;
      case 'fav':
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已收藏'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        break;
      case 'multi':
        setState(() {
          _multiSelect = true;
          _selected.add(_messages.indexOf(m));
        });
        break;
      case 'delete':
        setState(() => _messages.remove(m));
        break;
    }
  }

  /// 包装：先 precheck，需确认就弹 banner；否则直接调
  Future<ToolResult> _callToolWithBubble(
    String tool,
    Map<String, dynamic> args, {
    bool userConfirmed = false,
  }) async {
    final client = ref.read(mockMcpClientProvider);
    final pre = client.precheck(_agentId, tool);
    if (pre.needConfirm && !userConfirmed) {
      throw McpDeniedException('需用户二次确认');
    }
    try {
      final r = await client.call(
        _agentId,
        tool,
        args,
        userConfirmed: userConfirmed,
      );
      _addToolBubble(
        tool: tool,
        args: args,
        summary: r.summary,
        latencyMs: r.latencyMs,
        warnings: r.warnings,
      );
      return r;
    } on McpDeniedException catch (e) {
      _addToolBubble(
        tool: tool,
        args: args,
        summary: '',
        latencyMs: 0,
        denied: true,
        deniedReason: e.reason,
      );
      rethrow;
    }
  }

  void _togglePlus() => setState(() {
    _showPlusPanel = !_showPlusPanel;
    if (_showPlusPanel) _showEmojiPanel = false;
  });

  void _toggleEmoji() => setState(() {
    _showEmojiPanel = !_showEmojiPanel;
    if (_showEmojiPanel) _showPlusPanel = false;
  });

  void _closePanels() => setState(() {
    _showPlusPanel = false;
    _showEmojiPanel = false;
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = widget.conv;
    return Scaffold(
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────
          // AI 助手用 s-agent 头部（smart_toy + 端对端加密标签）；
          // 普通联系人用 s-chat 头部（头像 + 在线 + call/video/more）。
          GlassHeader.detail(
            title: c.name,
            subtitle: _isAiBot ? '端对端加密' : (c.isGroup ? '6 名成员' : '在线'),
            subtitleIcon: _isAiBot ? Symbols.lock : null,
            centerLeading: _isAiBot
                ? _AgentBadge(color: t.accent)
                : c.isGroup
                ? Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: t.surfaceHigh,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Symbols.groups,
                      size: 20,
                      color: t.textMute,
                      fill: 1,
                    ),
                  )
                : SizedBox(
                    width: 36,
                    height: 36,
                    child: Stack(
                      children: [
                        PortalAvatar(
                          seed: c.name,
                          size: 36,
                          imageUrl: c.avatarUrl,
                        ),
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: OnlineDot(size: 10),
                        ),
                      ],
                    ),
                  ),
            actions: _isAiBot
                ? [
                    GlassHeaderButton(
                      icon: Symbols.more_horiz,
                      color: t.accent,
                      onTap: () {},
                    ),
                  ]
                : [
                    GlassHeaderButton(
                      icon: Symbols.call,
                      color: t.accent,
                      onTap: () {},
                    ),
                    GlassHeaderButton(
                      icon: Symbols.videocam,
                      color: t.accent,
                      onTap: () {},
                    ),
                    GlassHeaderButton(
                      icon: Symbols.more_vert,
                      color: t.accent,
                      onTap: () => context.push(
                        '${c.isGroup ? '/group-detail' : '/chat-info'}/${Uri.encodeComponent(c.id)}',
                      ),
                    ),
                  ],
          ),

          // ── Messages ───────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closePanels,
              child: _messages.isEmpty
                  ? _EmptyState(isAiBot: _isAiBot)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                      itemCount: _messages.length + (_agentBusy ? 1 : 0) + 1,
                      itemBuilder: (context, i) {
                        if (_agentBusy && i == _messages.length) {
                          return const TypingIndicator();
                        }
                        if (i == _messages.length + (_agentBusy ? 1 : 0)) {
                          return const _E2eFooter();
                        }
                        final m = _messages[i];
                        if (m.kind == MockMsgKind.toolCall) {
                          return ToolCallBubble(
                            toolName: m.toolName ?? '',
                            args: m.toolArgs ?? const {},
                            resultSummary: m.toolResultSummary ?? '',
                            latencyMs: m.toolLatencyMs ?? 0,
                            warnings: m.toolWarnings ?? const [],
                            denied:
                                m.toolResultSummary?.isEmpty == true &&
                                (m.toolWarnings?.isNotEmpty ?? false),
                            deniedReason: m.toolResultSummary?.isEmpty == true
                                ? m.toolWarnings?.first
                                : null,
                          );
                        }
                        final selected = _selected.contains(i);
                        return _SChatBubble(
                          isMe: m.isMe,
                          text: m.text,
                          time: DateFormat('HH:mm').format(m.time),
                          showRead: m.isMe,
                          avatarSeed: m.isMe ? 'me' : c.name,
                          markdownChild: (_isAiBot && !m.isMe)
                              ? AgentMessageBody(m.text)
                              : null,
                          selected: selected,
                          multiSelect: _multiSelect,
                          onTap: _multiSelect
                              ? () => setState(() {
                                  if (selected) {
                                    _selected.remove(i);
                                  } else {
                                    _selected.add(i);
                                  }
                                })
                              : null,
                          onLongPressAt: (pos) => _onLongPressMsg(m, pos),
                        );
                      },
                    ),
            ),
          ),

          // ── Pending agent confirm banner ───────────────────────
          if (_pendingConfirm != null)
            _ConfirmBanner(
              pending: _pendingConfirm!,
              onCancel: () => setState(() => _pendingConfirm = null),
            ),

          // ── AI 快捷指令悬浮栏 ──────────────────────────────────
          if (_isAiBot)
            _AgentFloatingBar(
              onTokenUsage: _onTokenUsage,
              onSummarizeRecent: _onSummarizeRecent,
              onNewSession: _onNewSession,
              onDraftReply: _onAgentDraftReply,
            ),

          // ── Reply bar / Multi-select bar / Input bar ──────────
          if (_replyTo != null)
            _ReplyBar(
              text: _replyTo!.text,
              sender: _replyTo!.isMe ? '我' : c.name,
              onClose: () => setState(() => _replyTo = null),
            ),
          if (_multiSelect)
            _MultiSelectBar(
              count: _selected.length,
              onExit: () => setState(() {
                _multiSelect = false;
                _selected.clear();
              }),
              onForward: () {},
              onDelete: () {
                setState(() {
                  final idx = _selected.toList()..sort((a, b) => b - a);
                  for (final i in idx) {
                    if (i < _messages.length) _messages.removeAt(i);
                  }
                  _multiSelect = false;
                  _selected.clear();
                });
              },
            )
          else
            _SChatInputBar(
              ctrl: _ctrl,
              onSend: _send,
              onPlus: _togglePlus,
              onEmoji: _toggleEmoji,
              plusActive: _showPlusPanel,
              emojiActive: _showEmojiPanel,
              suggestions: _isAiBot
                  ? const []
                  : const ['周日下午有空', '周日要加班，下次', '几点？'],
              onPickSuggestion: (s) {
                _ctrl.text = s;
                _send();
              },
            ),

          // ── Plus / Emoji panel ────────────────────────────────
          if (_showPlusPanel) const _PlusPanel(),
          if (_showEmojiPanel)
            _EmojiPanel(
              onPick: (e) {
                final c = _ctrl;
                final base = c.text;
                c.text = base + e;
                c.selection = TextSelection.collapsed(offset: c.text.length);
              },
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 共享 widget：气泡 / 输入栏 / 面板 / 长按菜单 / 回复栏 / 多选栏
// ═══════════════════════════════════════════════════════════════════════════

/// s-chat 气泡：对方左侧 28px 头像 + `surfaceHigh` 气泡 + 时间戳；
/// 自己右对齐 + `accent` 气泡 + 时间戳行内 `done_all` 已读图标。
class _SChatBubble extends StatelessWidget {
  const _SChatBubble({
    required this.isMe,
    required this.text,
    required this.time,
    required this.showRead,
    required this.avatarSeed,
    this.markdownChild,
    this.selected = false,
    this.multiSelect = false,
    this.onTap,
    this.onLongPressAt,
  });

  final bool isMe;
  final String text;
  final String time;
  final bool showRead;
  final String avatarSeed;
  final Widget? markdownChild;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;
  final void Function(Offset globalPos)? onLongPressAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final bubbleColor = isMe ? t.accent : t.surfaceHigh;
    final textColor = isMe ? t.onAccent : t.text;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    Offset pos = Offset.zero;
    final bubble = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => pos = d.globalPosition,
      onTap: onTap,
      onLongPress: () => onLongPressAt?.call(pos),
      // 桌面端右键：记录位置 + 触发同一菜单。
      onSecondaryTapDown: (d) => pos = d.globalPosition,
      onSecondaryTap: () => onLongPressAt?.call(pos),
      child: Container(
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child:
            markdownChild ??
            Text(text, style: AppTheme.sans(size: 17, color: textColor)),
      ),
    );

    final timeRow = isMe && showRead
        ? Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: AppTheme.sans(size: 11, color: t.textMute)),
                const SizedBox(width: 4),
                Icon(Symbols.done_all, size: 14, color: t.accent),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              time,
              style: AppTheme.sans(size: 11, color: t.textMute),
            ),
          );

    final column = Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [bubble, timeRow],
    );

    return Container(
      color: selected ? t.accent.withValues(alpha: 0.10) : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (multiSelect) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 14),
              child: Icon(
                selected
                    ? Symbols.check_circle
                    : Symbols.radio_button_unchecked,
                size: 20,
                color: selected ? t.accent : t.textMute,
              ),
            ),
          ],
          if (!isMe) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: PortalAvatar(seed: avatarSeed, size: 28),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              child: column,
            ),
          ),
        ],
      ),
    );
  }
}

/// s-chat 头部 AI 标记：`smart_toy` 圆形 36 像素徽章。
class _AgentBadge extends StatelessWidget {
  const _AgentBadge({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: t.primaryContainer.withValues(alpha: 0.30),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(Symbols.smart_toy, size: 20, color: color, fill: 1),
    );
  }
}

/// s-chat 输入栏 + AI 建议回复 chips（毛玻璃底栏 + 圆角输入框）。
class _SChatInputBar extends StatelessWidget {
  const _SChatInputBar({
    required this.ctrl,
    required this.onSend,
    required this.onPlus,
    required this.onEmoji,
    this.plusActive = false,
    this.emojiActive = false,
    this.suggestions = const [],
    this.onPickSuggestion,
  });

  final TextEditingController ctrl;
  final VoidCallback onSend;
  final VoidCallback onPlus;
  final VoidCallback onEmoji;
  final bool plusActive;
  final bool emojiActive;
  final List<String> suggestions;
  final ValueChanged<String>? onPickSuggestion;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (suggestions.isNotEmpty)
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Row(
                            children: [
                              Icon(
                                Symbols.auto_awesome,
                                size: 14,
                                color: t.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'AI 建议',
                                style: AppTheme.sans(
                                  size: 12,
                                  color: t.textMute,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...suggestions.map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Material(
                              color: t.surfaceHigh,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => onPickSuggestion?.call(s),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    s,
                                    style: AppTheme.sans(
                                      size: 13,
                                      color: t.text,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(
                          Symbols.add_circle,
                          size: 28,
                          color: plusActive ? t.accent : t.textMute,
                        ),
                        onPressed: onPlus,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: t.surfaceHigh,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: ctrl,
                                  textInputAction: TextInputAction.newline,
                                  maxLines: 5,
                                  minLines: 1,
                                  style: AppTheme.sans(size: 17, color: t.text),
                                  decoration: InputDecoration(
                                    hintText: '消息…',
                                    hintStyle: AppTheme.sans(
                                      size: 17,
                                      color: t.textMute,
                                    ),
                                    isCollapsed: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 11,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Symbols.mood,
                                  size: 24,
                                  color: emojiActive ? t.accent : t.textMute,
                                ),
                                onPressed: onEmoji,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: ctrl,
                        builder: (_, v, __) {
                          final hasText = v.text.trim().isNotEmpty;
                          return Material(
                            color: t.accent,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: hasText ? onSend : null,
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Icon(
                                  hasText ? Symbols.arrow_upward : Symbols.mic,
                                  size: 20,
                                  color: t.onAccent,
                                ),
                              ),
                            ),
                          );
                        },
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

/// `chat-plus-panel` 1:1 复刻：4 列网格、6 个动作（相册/拍摄/视频通话/位置/名片/文件）。
class _PlusPanel extends StatelessWidget {
  const _PlusPanel();

  static const _items = <_PlusItem>[
    _PlusItem(Symbols.photo_library, '相册'),
    _PlusItem(Symbols.photo_camera, '拍摄'),
    _PlusItem(Symbols.videocam, '视频通话'),
    _PlusItem(Symbols.location_on, '位置'),
    _PlusItem(Symbols.contact_page, '个人名片'),
    _PlusItem(Symbols.folder_open, '文件'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      color: t.surfaceHover,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 20,
            crossAxisSpacing: 8,
            childAspectRatio: 0.82,
            children: _items
                .map((it) => _PlusButton(icon: it.icon, label: it.label))
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _PlusItem {
  const _PlusItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _PlusButton extends StatelessWidget {
  const _PlusButton({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {},
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(icon, size: 26, color: t.textMute),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTheme.sans(size: 11, color: t.textMute)),
        ],
      ),
    );
  }
}

/// `chat-emoji-panel` 1:1 复刻：8 列 emoji 网格。
class _EmojiPanel extends StatelessWidget {
  const _EmojiPanel({required this.onPick});
  final ValueChanged<String> onPick;

  static const _emojis = [
    '😀',
    '😂',
    '🥲',
    '😍',
    '🥰',
    '😘',
    '😭',
    '😤',
    '👍',
    '❤️',
    '🙏',
    '💪',
    '👏',
    '✌️',
    '🤝',
    '🫡',
    '🎉',
    '🔥',
    '💯',
    '✨',
    '😅',
    '😆',
    '🤣',
    '😋',
    '😎',
    '🤓',
    '🤗',
    '😏',
    '😢',
    '😡',
    '🥹',
    '🫶',
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      color: t.surfaceHover,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 8,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: _emojis
                .map(
                  (e) => Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onPick(e),
                      child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

/// 引用回复栏：消息上方一行预览 + 关闭按钮。
class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.text,
    required this.sender,
    required this.onClose,
  });
  final String text;
  final String sender;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceHover,
        border: Border(
          top: BorderSide(color: t.border.withValues(alpha: 0.5)),
          left: BorderSide(color: t.accent, width: 3),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Symbols.reply, size: 16, color: t.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '回复 $sender',
                  style: AppTheme.sans(
                    size: 11,
                    color: t.accent,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 13, color: t.textMute),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Symbols.close, size: 18, color: t.textMute),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// 多选栏：替代输入栏，显示选中数 + 转发/删除等操作。
class _MultiSelectBar extends StatelessWidget {
  const _MultiSelectBar({
    required this.count,
    required this.onExit,
    required this.onForward,
    required this.onDelete,
  });
  final int count;
  final VoidCallback onExit;
  final VoidCallback onForward;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: t.bg.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(color: t.border.withValues(alpha: 0.5)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: onExit,
                    icon: Icon(Symbols.close, size: 18, color: t.text),
                    label: Text(
                      '取消',
                      style: AppTheme.sans(size: 13, color: t.text),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '已选 $count 条',
                        style: AppTheme.sans(
                          size: 13,
                          color: t.textMute,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Symbols.forward, color: t.accent, size: 22),
                    onPressed: count > 0 ? onForward : null,
                  ),
                  IconButton(
                    icon: Icon(Symbols.delete, color: t.danger, size: 22),
                    onPressed: count > 0 ? onDelete : null,
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

/// `msg-ctx-menu`：深色 `#1E2026` 圆角浮层 / 2 行 × 3 列 — 复制/转发/收藏 + 删除/多选/引用。
Future<String?> _showMsgContextMenu(BuildContext context, Offset pos) {
  final size = MediaQuery.of(context).size;
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'msg-ctx',
    barrierColor: Colors.black.withValues(alpha: 0.15),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, a1, a2) {
      // 锚点：限制在屏内
      const menuW = 300.0;
      const menuH = 168.0;
      var left = pos.dx - menuW / 2;
      var top = pos.dy - menuH - 12;
      if (left < 12) left = 12;
      if (left + menuW > size.width - 12) left = size.width - menuW - 12;
      if (top < 60) top = pos.dy + 12;
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: menuW,
            child: const _MsgCtxMenuCard(),
          ),
        ],
      );
    },
    transitionBuilder: (ctx, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

class _MsgCtxMenuCard extends StatelessWidget {
  const _MsgCtxMenuCard();
  @override
  Widget build(BuildContext context) {
    // s-chat 长按菜单固定用深色背景（与 light/dark 主题无关）
    const dark = Color(0xFF1E2026);
    const divider = Color(0x1AFFFFFF);
    const labelColor = Color(0xB3FFFFFF);
    const iconColor = Color(0xCCFFFFFF);
    const danger = Color(0xFFFF6B6B);
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: dark,
          borderRadius: BorderRadius.circular(16),
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
            IntrinsicHeight(
              child: Row(
                children: [
                  _ctxBtn(
                    context,
                    Symbols.content_copy,
                    '复制',
                    'copy',
                    iconColor,
                    labelColor,
                  ),
                  const VerticalDivider(width: 1, color: divider),
                  _ctxBtn(
                    context,
                    Symbols.forward,
                    '转发',
                    'forward',
                    iconColor,
                    labelColor,
                  ),
                  const VerticalDivider(width: 1, color: divider),
                  _ctxBtn(
                    context,
                    Symbols.star,
                    '收藏',
                    'fav',
                    iconColor,
                    labelColor,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: divider),
            IntrinsicHeight(
              child: Row(
                children: [
                  _ctxBtn(
                    context,
                    Symbols.delete,
                    '删除',
                    'delete',
                    danger,
                    danger,
                  ),
                  const VerticalDivider(width: 1, color: divider),
                  _ctxBtn(
                    context,
                    Symbols.checklist,
                    '多选',
                    'multi',
                    iconColor,
                    labelColor,
                  ),
                  const VerticalDivider(width: 1, color: divider),
                  _ctxBtn(
                    context,
                    Symbols.format_quote,
                    '引用',
                    'quote',
                    iconColor,
                    labelColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctxBtn(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color iconColor,
    Color labelColor,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () => Navigator.of(context).pop(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(height: 6),
              Text(label, style: AppTheme.sans(size: 11, color: labelColor)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 消息流底部「端对端加密」标签
class _E2eFooter extends StatelessWidget {
  const _E2eFooter();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Opacity(
          opacity: 0.6,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.lock, size: 12, color: t.textMute),
              const SizedBox(width: 4),
              Text('端对端加密', style: AppTheme.sans(size: 11, color: t.textMute)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isAiBot});
  final bool isAiBot;
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAiBot ? Symbols.auto_awesome : Symbols.chat_bubble,
            size: 36,
            color: t.textMute,
          ),
          const SizedBox(height: 12),
          Text(
            isAiBot ? '问点什么 / 用上方快捷指令' : '开始你们的第一条消息',
            style: AppTheme.sans(size: 13, color: t.textMute),
          ),
        ],
      ),
    );
  }
}

class _ConfirmBanner extends StatelessWidget {
  const _ConfirmBanner({required this.pending, required this.onCancel});
  final _PendingConfirm pending;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.accent, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.security, size: 16, color: t.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Agent 想调用 ',
                      style: AppTheme.sans(size: 12, color: t.textMute),
                    ),
                    Text(
                      pending.tool,
                      style: AppTheme.mono(
                        size: 12,
                        color: t.accent,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      ' · 需你确认',
                      style: AppTheme.sans(size: 12, color: t.textMute),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AgentMessageBody(pending.preview, selectable: false),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  minimumSize: const Size(60, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  '取消',
                  style: AppTheme.sans(size: 12, color: t.textMute),
                ),
              ),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: pending.onConfirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(60, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  backgroundColor: t.accent,
                ),
                child: Text(
                  '确认发送',
                  style: AppTheme.sans(
                    size: 12,
                    color: t.onAccent,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// AI Bot 输入框上方悬浮的两个胶囊按钮 —— 飞书风格
class _AgentFloatingBar extends ConsumerWidget {
  const _AgentFloatingBar({
    required this.onTokenUsage,
    required this.onSummarizeRecent,
    required this.onNewSession,
    required this.onDraftReply,
  });

  final VoidCallback onTokenUsage;
  final VoidCallback onSummarizeRecent;
  final VoidCallback onNewSession;
  final VoidCallback onDraftReply;

  void _showShortcuts(BuildContext context, Offset anchor) {
    final t = context.tk;
    showMenu<void>(
      context: context,
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: t.border),
      ),
      position: RelativeRect.fromLTRB(
        anchor.dx,
        anchor.dy,
        anchor.dx + 1,
        anchor.dy + 1,
      ),
      items: [
        _shortcutItem(
          t,
          Symbols.speed,
          '查询 Token 用量',
          '查看本月消耗与配额',
          onTokenUsage,
        ),
        _shortcutItem(
          t,
          Symbols.format_list_bulleted,
          '总结最近的聊天',
          '汇总最近联系人聊了什么',
          onSummarizeRecent,
        ),
        _shortcutItem(
          t,
          Symbols.send,
          '代我回复 Jack',
          '让 Agent 起草并经你确认后发送',
          onDraftReply,
        ),
        _shortcutItem(
          t,
          Symbols.add_comment,
          '新建会话',
          '清空当前对话开始新一轮',
          onNewSession,
        ),
      ],
    );
  }

  PopupMenuItem<void> _shortcutItem(
    PortalTokens t,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return PopupMenuItem<void>(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: t.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTheme.sans(
                      size: 13,
                      color: t.text,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.sans(size: 11, color: t.textMute),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final policy = ref.watch(mcpPolicyStoreProvider)['local-aibot'];
    return Container(
      color: t.bg,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (policy != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 2),
              child: Row(
                children: [
                  Icon(
                    Symbols.verified_user,
                    size: 11,
                    color: policy.enabled ? t.accent : t.textMute,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    policy.enabled ? '权限：${policy.summary}' : '权限：已禁用',
                    style: AppTheme.mono(size: 10, color: t.textMute),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Builder(
                builder: (btnCtx) {
                  return _CapsuleButton(
                    icon: Symbols.keyboard_arrow_down,
                    iconLeading: false,
                    label: '快捷指令',
                    onTap: () {
                      final box = btnCtx.findRenderObject() as RenderBox?;
                      final offset =
                          box?.localToGlobal(Offset.zero) ?? Offset.zero;
                      _showShortcuts(btnCtx, offset);
                    },
                  );
                },
              ),
              const SizedBox(width: 8),
              _CapsuleButton(
                icon: Symbols.tune,
                iconLeading: true,
                label: '管理',
                onTap: () => context.push('/mcp-permission/local-aibot'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapsuleButton extends StatelessWidget {
  const _CapsuleButton({
    required this.icon,
    required this.iconLeading,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final bool iconLeading;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.primaryContainer.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: t.accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconLeading) ...[
                Icon(icon, size: 15, color: t.accent),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: AppTheme.sans(
                  size: 13,
                  color: t.accent,
                  weight: FontWeight.w600,
                ),
              ),
              if (!iconLeading) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 15, color: t.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

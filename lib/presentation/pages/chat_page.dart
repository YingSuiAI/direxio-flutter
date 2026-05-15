import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import '../providers/auth_provider.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/portal_avatar.dart';
import '../mock/mock_data.dart';
import '../mock/mcp_policy.dart';
import '../mock/mock_mcp_client.dart';
import '../widgets/agent_message_body.dart';
import '../widgets/tool_call_bubble.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

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

  Room? get _room =>
      ref.read(matrixClientProvider).getRoomById(widget.roomId);

  @override
  void initState() {
    super.initState();
    // MOCK: 命中 mock 就不走真 Matrix timeline
    if (MockData.byId(widget.roomId) != null) {
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
    // 灌历史进 Timeline（timeline 级，不是 room 级）
    final tl = _timeline;
    if (tl != null) {
      unawaited(_backfillHistory(tl));
    }
  }

  Future<void> _backfillHistory(Timeline timeline) async {
    // 拉够 50 条历史；matrix SDK 单次返回有限，需要循环
    var attempts = 0;
    while (attempts < 5 &&
        timeline.canRequestHistory &&
        timeline.events.where((e) => e.type == EventTypes.Message).length < 50) {
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
    await _room?.sendTextEvent(text);
  }

  @override
  Widget build(BuildContext context) {
    // MOCK: roomId 命中 mock → 走 mock 渲染
    final mock = MockData.byId(widget.roomId);
    if (mock != null) {
      return _MockChatScaffold(conv: mock);
    }

    final room = _room;
    final t = context.tk;
    if (room == null) {
      return const Scaffold(body: Center(child: Text('会话不存在')));
    }

    // Timeline.events is newest-first; ListView reverse:true puts index 0 at
    // bottom — so we keep newest-first to render newest at the bottom.
    final events = _timeline?.events
            .where((e) => e.type == EventTypes.Message)
            .toList() ??
        [];

    final mxid = room.directChatMatrixID ?? '';
    final name = room.getLocalizedDisplayname();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            PortalAvatar(seed: name, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                          size: 14,
                          weight: FontWeight.w600,
                          color: t.text)),
                  if (mxid.isNotEmpty)
                    Text(mxid,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppTheme.mono(size: 11, color: t.accentCool)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.phone, size: 18, color: t.text),
            onPressed: () => context.push(
                '/call/${Uri.encodeComponent(widget.roomId)}'),
          ),
          IconButton(
            icon: Icon(LucideIcons.video, size: 18, color: t.text),
            onPressed: () => context.push(
                '/call/${Uri.encodeComponent(widget.roomId)}'),
          ),
          IconButton(
            icon: Icon(LucideIcons.info, size: 18, color: t.text),
            onPressed: () => context.push(
                '/contact/${Uri.encodeComponent(mxid)}'),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: t.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: t.accent),
                    ),
                  )
                : events.isEmpty
                    ? Center(
                        child: Text('开始你们的第一条消息',
                            style: AppTheme.sans(
                                size: 13, color: t.textMute)))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: events.length,
                        itemBuilder: (context, i) =>
                            MessageBubble(event: events[i]),
                      ),
          ),
          MessageInputBar(ctrl: _msgCtrl, onSend: _send, room: room),
        ],
      ),
    );
  }
}

/// Mock 聊天页：roomId 命中 MockData 时使用,无需 Matrix client。
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
      _messages.add(
        MockMessage(isMe: true, text: text, time: DateTime.now()),
      );
      _ctrl.clear();
    });
    // AI Bot 自动 echo 一条流式回复（mock）
    if (_isAiBot) {
      _streamAgentReply(
          '收到："$text"。\n\n（这是 mock 回复，真接 LLM 后会基于上下文回答）');
    }
  }

  /// 流式输出：按字符 append，制造打字机感
  void _streamAgentReply(String full, {int charDelayMs = 12}) {
    _streamTimer?.cancel();
    setState(() {
      _agentBusy = true;
      _messages.add(MockMessage(
        isMe: false,
        text: '',
        time: DateTime.now(),
      ));
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

  /// 添加工具调用气泡消息
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
      _messages.add(MockMessage(
        isMe: false,
        text: '',
        time: DateTime.now(),
        kind: MockMsgKind.toolCall,
        toolName: tool,
        toolArgs: args,
        toolResultSummary: denied ? (deniedReason ?? '被拒') : summary,
        toolLatencyMs: latencyMs,
        toolWarnings: [
          ...warnings,
          if (denied) deniedReason ?? '权限不足',
        ],
      ));
    });
  }

  // ─── Agent 工具调用(mock) ─────────────────────────
  void _addUserAction(String text) {
    _messages.add(
      MockMessage(isMe: true, text: text, time: DateTime.now()),
    );
  }

  void _addAgentReply(String text) {
    _messages.add(
      MockMessage(
        isMe: false,
        text: text,
        time: DateTime.now().add(const Duration(seconds: 1)),
      ),
    );
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
    } on McpDeniedException {/* 已写气泡 */}
  }

  Future<void> _onSummarizeRecent() async {
    setState(() => _addUserAction('/总结最近谁和我聊了什么'));
    try {
      // Step 1: 解析 Jack
      final who = await _callToolWithBubble('list_conversations', {'query': 'jack'});
      final convs = who.data['conversations'] as List;
      if (convs.isEmpty) {
        _streamAgentReply('没有匹配到名为 Jack 的会话。');
        return;
      }
      final target = convs.first;
      // Step 2: 拉历史
      final r = await _callToolWithBubble(
          'get_recent_messages',
          {'room_id': target['id'], 'limit': 50});
      final msgs = (r.data['messages'] as List).cast<Map>();
      final preview = msgs.take(3).map((m) =>
          '> **${m['sender_name']}**：${m['text']}').join('\n>\n');

      final policy = ref.read(mcpPolicyStoreProvider)[_agentId]!;
      final warnLines = <String>[
        if (r.warnings.isNotEmpty)
          ...r.warnings.map((w) => '> ⚠️ $w'),
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
    } on McpDeniedException {/* 已写气泡 */}
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

  /// 演示二次确认：发消息工具
  void _onAgentDraftReply() {
    setState(() {
      _pendingConfirm = _PendingConfirm(
        tool: 'send_message',
        args: {
          'room_id': 'mock_jack',
          'text': '周日下午 3 点万体馆见，到时候打你电话。',
        },
        preview: '将发送给 **Jack**：\n\n> 周日下午 3 点万体馆见，到时候打你电话。',
        onConfirm: () async {
          final args = _pendingConfirm!.args;
          setState(() => _pendingConfirm = null);
          try {
            await _callToolWithBubble('send_message', args,
                userConfirmed: true);
            _streamAgentReply('✅ 已替你发送给 Jack。');
          } on McpDeniedException {/* 已写气泡 */}
        },
      );
    });
  }

  void _showMessageMenu(MockMessage m) async {
    if (m.kind != MockMsgKind.text) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final t = ctx.tk;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _menuTile(t, LucideIcons.copy, '复制', 'copy'),
              _menuTile(t, LucideIcons.quote, '引用', 'quote'),
              _menuTile(t, LucideIcons.forward, '转发', 'forward'),
              _menuTile(t, LucideIcons.sparkles, '让 AI Bot 解读', 'ai',
                  highlight: true),
              if (m.isMe)
                _menuTile(t, LucideIcons.trash_2, '删除', 'delete',
                    danger: true),
            ],
          ),
        );
      },
    );
    if (action == null) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.text));
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('已复制')));
        }
        break;
      case 'quote':
        _ctrl.text = '> ${m.text.split('\n').join('\n> ')}\n\n';
        break;
      case 'ai':
        if (mounted) {
          context.push('/chat/mock_aibot');
        }
        break;
      case 'delete':
        setState(() => _messages.remove(m));
        break;
    }
  }

  Widget _menuTile(PortalTokens t, IconData icon, String label, String value,
      {bool highlight = false, bool danger = false}) {
    final color = danger
        ? t.danger
        : highlight
            ? t.accentCool
            : t.text;
    return ListTile(
      leading: Icon(icon, size: 18, color: color),
      title: Text(label, style: AppTheme.sans(size: 14, color: color)),
      onTap: () => Navigator.pop(context, value),
    );
  }

  /// 包装：先 precheck，需确认就弹 banner；否则直接调
  Future<ToolResult> _callToolWithBubble(
      String tool, Map<String, dynamic> args,
      {bool userConfirmed = false}) async {
    final client = ref.read(mockMcpClientProvider);
    final pre = client.precheck(_agentId, tool);
    if (pre.needConfirm && !userConfirmed) {
      // 调用方应自己用 _pendingConfirm 处理；这里抛错
      throw McpDeniedException('需用户二次确认');
    }
    try {
      final r =
          await client.call(_agentId, tool, args, userConfirmed: userConfirmed);
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
  // ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = widget.conv;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            PortalAvatar(seed: c.name, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                          size: 14,
                          weight: FontWeight.w600,
                          color: t.text)),
                  Text(c.mxid,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.mono(size: 11, color: t.accentCool)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.phone, size: 18, color: t.text),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(LucideIcons.video, size: 18, color: t.text),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(LucideIcons.info, size: 18, color: t.text),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: t.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(isAiBot: _isAiBot)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _messages.length + (_agentBusy ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (_agentBusy && i == _messages.length) {
                        return const TypingIndicator();
                      }
                      final m = _messages[i];
                      if (m.kind == MockMsgKind.toolCall) {
                        return ToolCallBubble(
                          toolName: m.toolName ?? '',
                          args: m.toolArgs ?? const {},
                          resultSummary: m.toolResultSummary ?? '',
                          latencyMs: m.toolLatencyMs ?? 0,
                          warnings: m.toolWarnings ?? const [],
                          denied: m.toolResultSummary?.isEmpty == true &&
                              (m.toolWarnings?.isNotEmpty ?? false),
                          deniedReason:
                              m.toolResultSummary?.isEmpty == true
                                  ? m.toolWarnings?.first
                                  : null,
                        );
                      }
                      return _MockBubble(
                        msg: m,
                        isAgent: _isAiBot,
                        onLongPress: () => _showMessageMenu(m),
                      );
                    },
                  ),
          ),
          if (_pendingConfirm != null)
            _ConfirmBanner(
              pending: _pendingConfirm!,
              onCancel: () => setState(() => _pendingConfirm = null),
            ),
          if (_isAiBot)
            _AgentFloatingBar(
              onTokenUsage: _onTokenUsage,
              onSummarizeRecent: _onSummarizeRecent,
              onNewSession: _onNewSession,
              onDraftReply: _onAgentDraftReply,
            ),
          _MockInputBar(
            ctrl: _ctrl,
            onSend: _send,
            suggestions: _isAiBot
                ? const []
                : const [
                    '周日下午有空',
                    '周日要加班，下次',
                    '几点？',
                  ],
            onPickSuggestion: (s) {
              _ctrl.text = s;
              _send();
            },
          ),
        ],
      ),
    );
  }
}

class _MockBubble extends StatelessWidget {
  const _MockBubble({required this.msg, this.isAgent = false, this.onLongPress});
  final MockMessage msg;
  final bool isAgent;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isMe = msg.isMe;
    final time = DateFormat('HH:mm').format(msg.time);
    final sideColor = isMe ? t.accent : t.accentCool;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            Container(
              width: 2,
              constraints:
                  const BoxConstraints(minHeight: 24, maxHeight: 80),
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: sideColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
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
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: (isAgent && !isMe)
                        ? AgentMessageBody(msg.text)
                        : Text(
                            msg.text,
                            style: AppTheme.sans(
                                size: 14,
                                color: t.text,
                                weight: FontWeight.w400),
                          ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(time,
                        style: AppTheme.mono(size: 10, color: t.textMute)),
                  ),
                ],
              ),
            ),
          ),
          if (isMe)
            Container(
              width: 2,
              constraints:
                  const BoxConstraints(minHeight: 24, maxHeight: 80),
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: sideColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
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
            isAiBot ? LucideIcons.sparkles : LucideIcons.message_circle,
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
          Icon(LucideIcons.shield_alert, size: 16, color: t.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Agent 想调用 ',
                      style: AppTheme.sans(size: 12, color: t.textMute)),
                  Text(pending.tool,
                      style: AppTheme.mono(
                          size: 12,
                          color: t.accent,
                          weight: FontWeight.w600)),
                  Text(' · 需你确认',
                      style: AppTheme.sans(size: 12, color: t.textMute)),
                ]),
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
                child: Text('取消',
                    style: AppTheme.sans(size: 12, color: t.textMute)),
              ),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: pending.onConfirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(60, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  backgroundColor: t.accent,
                ),
                child: Text('确认发送',
                    style: AppTheme.sans(
                        size: 12,
                        color: Colors.black,
                        weight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockInputBar extends StatelessWidget {
  const _MockInputBar({
    required this.ctrl,
    required this.onSend,
    this.suggestions = const [],
    this.onPickSuggestion,
  });
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final List<String> suggestions;
  final ValueChanged<String>? onPickSuggestion;

  void _showCommonMenu(BuildContext context) {
    final t = context.tk;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: const [
                  _CommonAction(icon: LucideIcons.image, label: '相册'),
                  _CommonAction(icon: LucideIcons.camera, label: '拍摄'),
                  _CommonAction(icon: LucideIcons.file, label: '文件'),
                  _CommonAction(icon: LucideIcons.video, label: '视频通话'),
                  _CommonAction(icon: LucideIcons.phone, label: '语音通话'),
                  _CommonAction(icon: LucideIcons.map_pin, label: '位置'),
                  _CommonAction(icon: LucideIcons.user, label: '名片'),
                  _CommonAction(icon: LucideIcons.mic, label: '语音输入'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Row(children: [
                          Icon(LucideIcons.sparkles,
                              size: 11, color: t.accentCool),
                          const SizedBox(width: 4),
                          Text('AI 建议',
                              style: AppTheme.mono(
                                  size: 10,
                                  color: t.textMute,
                                  weight: FontWeight.w600)),
                          const SizedBox(width: 6),
                        ]),
                      ),
                      ...suggestions.map((s) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(s,
                                  style: AppTheme.sans(
                                      size: 12, color: t.text)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onPressed: () => onPickSuggestion?.call(s),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: '',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    fillColor: t.surface,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: t.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: t.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: t.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: t.surface,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showCommonMenu(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: t.border),
                    ),
                    child: Icon(LucideIcons.plus, size: 18, color: t.text),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: t.accent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onSend,
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Icon(LucideIcons.send_horizontal,
                        size: 16, color: Colors.black),
                  ),
                ),
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

class _CommonAction extends StatelessWidget {
  const _CommonAction({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {},
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.border),
            ),
            child: Icon(icon, size: 22, color: t.text),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: AppTheme.sans(size: 11, color: t.textMute)),
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
        anchor.dx, anchor.dy, anchor.dx + 1, anchor.dy + 1,
      ),
      items: [
        _shortcutItem(t, LucideIcons.gauge, '查询 Token 用量',
            '查看本月消耗与配额', onTokenUsage),
        _shortcutItem(t, LucideIcons.list_collapse, '总结最近的聊天',
            '汇总最近联系人聊了什么', onSummarizeRecent),
        _shortcutItem(t, LucideIcons.send, '代我回复 Jack',
            '让 Agent 起草并经你确认后发送', onDraftReply),
        _shortcutItem(t, LucideIcons.message_square_plus, '新建会话',
            '清空当前对话开始新一轮', onNewSession),
      ],
    );
  }

  PopupMenuItem<void> _shortcutItem(PortalTokens t, IconData icon,
      String title, String subtitle, VoidCallback onTap) {
    return PopupMenuItem<void>(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Container(
        width: 260,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: t.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: AppTheme.sans(
                          size: 13,
                          color: t.text,
                          weight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTheme.sans(size: 11, color: t.textMute)),
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
                  Icon(LucideIcons.shield_check,
                      size: 11,
                      color: policy.enabled ? t.accent : t.textMute),
                  const SizedBox(width: 4),
                  Text(
                    policy.enabled
                        ? '权限：${policy.summary}'
                        : '权限：已禁用',
                    style:
                        AppTheme.mono(size: 10, color: t.textMute),
                  ),
                ],
              ),
            ),
          Row(children: [
          Builder(builder: (btnCtx) {
            return _CapsuleButton(
              icon: LucideIcons.chevron_down,
              iconLeading: false,
              label: '快捷指令',
              onTap: () {
                final box = btnCtx.findRenderObject() as RenderBox?;
                final offset = box?.localToGlobal(Offset.zero) ??
                    Offset.zero;
                _showShortcuts(btnCtx, offset);
              },
            );
          }),
          const SizedBox(width: 8),
          _CapsuleButton(
            icon: LucideIcons.settings_2,
            iconLeading: true,
            label: '管理',
            onTap: () => context.push('/mcp-permission/local-aibot'),
          ),
        ]),
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
      color: t.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconLeading) ...[
                Icon(icon, size: 13, color: t.text),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: AppTheme.sans(
                      size: 12,
                      color: t.text,
                      weight: FontWeight.w500)),
              if (!iconLeading) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 13, color: t.textMute),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

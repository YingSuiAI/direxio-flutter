import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import '../providers/auth_provider.dart';
import '../widgets/chat_widgets.dart';

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
    if (room == null) return const Scaffold(body: Center(child: Text('群组不存在')));
    final events = _timeline?.events
        .where((e) => e.type == EventTypes.Message)
        .toList() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room.getLocalizedDisplayname(),
                style: const TextStyle(fontSize: 16)),
            Text('${room.summary.mJoinedMemberCount ?? 0} 位成员',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            onPressed: () => context.push('/group-detail/${Uri.encodeComponent(widget.roomId)}'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: events.length,
                    itemBuilder: (context, i) => MessageBubble(event: events[i]),
                  ),
          ),
          MessageInputBar(ctrl: _msgCtrl, onSend: _send, room: room),
        ],
      ),
    );
  }
}

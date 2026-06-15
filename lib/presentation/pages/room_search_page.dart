// 会话内搜索。优先走 AS 的 room_id 搜索，离线/失败时使用本地 Matrix 缓存。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../providers/as_client_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';
import '../widgets/m3/m3_search_field.dart';

class RoomSearchPage extends ConsumerStatefulWidget {
  const RoomSearchPage({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<RoomSearchPage> createState() => _RoomSearchPageState();
}

class _RoomSearchPageState extends ConsumerState<RoomSearchPage> {
  static const _limit = 50;
  static const _cachedPageSize = 80;
  static const _maxCachedEvents = 500;

  final _controller = TextEditingController();
  Timer? _debounce;
  List<_RoomSearchResult> _results = const [];
  bool _loading = false;
  String _lastQuery = '';
  int _serial = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _serial++;
      setState(() {
        _results = const [];
        _loading = false;
        _lastQuery = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 260), () => _search(query));
  }

  Future<void> _search(String query) async {
    final serial = ++_serial;
    setState(() => _loading = true);
    final client = ref.read(matrixClientProvider);
    final local = await _cachedResults(query, client);
    if (!mounted || serial != _serial) return;
    setState(() {
      _results = _dedupe(local);
      _lastQuery = query;
      _loading = false;
    });

    final remote = await _remoteResults(query);
    if (!mounted || serial != _serial) return;
    setState(() => _results = _dedupe([...local, ...remote]));
  }

  Future<List<_RoomSearchResult>> _remoteResults(String query) async {
    try {
      final results = await ref.read(asClientProvider).search(
            query,
            roomId: widget.roomId,
            limit: _limit,
          );
      return results.map(_RoomSearchResult.remote).toList(growable: false);
    } catch (error) {
      debugPrint('room remote search failed: $error');
      return const [];
    }
  }

  Future<List<_RoomSearchResult>> _cachedResults(
    String query,
    Client client,
  ) async {
    final room = client.getRoomById(widget.roomId);
    if (room == null) return const [];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final results = <_RoomSearchResult>[];
    final seen = <String>{};
    void maybeAdd(Event event) {
      if (results.length >= _limit) return;
      if (event.type != EventTypes.Message || event.redacted) return;
      if (!event.plaintextBody.toLowerCase().contains(q)) return;
      if (!seen.add(event.eventId)) return;
      results.add(_RoomSearchResult.cached(event));
    }

    final lastEvent = room.lastEvent;
    if (lastEvent != null) maybeAdd(lastEvent);

    final database = client.database;
    if (database == null) return results;

    var start = 0;
    while (results.length < _limit && start < _maxCachedEvents) {
      final pageLimit = start + _cachedPageSize > _maxCachedEvents
          ? _maxCachedEvents - start
          : _cachedPageSize;
      List<Event> events;
      try {
        events = await database.getEventList(
          room,
          start: start,
          limit: pageLimit,
        );
      } catch (error) {
        debugPrint('room cached search failed: $error');
        break;
      }
      if (events.isEmpty) break;
      for (final event in events) {
        maybeAdd(event);
        if (results.length >= _limit) break;
      }
      start += events.length;
      if (events.length < pageLimit) break;
    }
    return results;
  }

  List<_RoomSearchResult> _dedupe(List<_RoomSearchResult> results) {
    final seen = <String>{};
    return [
      for (final result in results)
        if (seen.add(result.eventId.isEmpty
            ? '${result.senderName}:${result.timestamp.millisecondsSinceEpoch}:${result.content}'
            : result.eventId))
          result,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(title: '查找聊天记录'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: M3SearchField(
              controller: _controller,
              hint: '搜索当前会话',
              autofocus: true,
              onChanged: _onChanged,
            ),
          ),
          Expanded(child: _buildBody(t)),
        ],
      ),
    );
  }

  Widget _buildBody(PortalTokens t) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_lastQuery.isEmpty) {
      return Center(
        child: Text(
          '输入关键词搜索当前会话',
          style: AppTheme.sans(size: 13, color: t.textMute),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          '没有找到包含「$_lastQuery」的消息',
          style: AppTheme.sans(size: 13, color: t.textMute),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final result = _results[index];
        return _RoomSearchTile(
          result: result,
          onTap: () => context.pop(result.eventId),
        );
      },
    );
  }
}

class _RoomSearchResult {
  const _RoomSearchResult({
    required this.eventId,
    required this.senderName,
    required this.content,
    required this.timestamp,
  });

  factory _RoomSearchResult.remote(AsSearchResult result) {
    return _RoomSearchResult(
      eventId: result.eventId,
      senderName: result.senderName.isEmpty ? '消息' : result.senderName,
      content: result.content,
      timestamp: result.timestamp,
    );
  }

  factory _RoomSearchResult.cached(Event event) {
    return _RoomSearchResult(
      eventId: event.eventId,
      senderName: _senderDisplayName(event),
      content: event.plaintextBody,
      timestamp: event.originServerTs,
    );
  }

  final String eventId;
  final String senderName;
  final String content;
  final DateTime timestamp;
}

class _RoomSearchTile extends StatelessWidget {
  const _RoomSearchTile({required this.result, required this.onTap});

  final _RoomSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return M3Card(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: t.surfaceHover,
          child: Icon(Symbols.chat_bubble, size: 18, color: t.textMute),
        ),
        title: Text(
          result.senderName,
          style: AppTheme.sans(
            size: 15,
            weight: FontWeight.w600,
            color: t.text,
          ),
        ),
        subtitle: Text(
          result.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.sans(size: 13, color: t.textMute),
        ),
        trailing: Text(
          DateFormat('MM-dd HH:mm').format(result.timestamp),
          style: AppTheme.sans(size: 11, color: t.textMute),
        ),
        onTap: onTap,
      ),
    );
  }
}

String _senderDisplayName(Event event) {
  final member = event.room.getState(EventTypes.RoomMember, event.senderId);
  final displayName = member?.content['displayname'];
  if (displayName is String && displayName.trim().isNotEmpty) {
    return displayName.trim();
  }
  final sender = event.senderId;
  if (sender.startsWith('@') && sender.contains(':')) {
    return sender.substring(1, sender.indexOf(':'));
  }
  return sender;
}

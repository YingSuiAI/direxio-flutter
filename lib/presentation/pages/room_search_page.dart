// 会话内搜索。优先使用本地 Matrix 缓存，随后追加 Matrix /search 结果。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/matrix_message_search_client.dart';
import '../../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/matrix_message_clients_provider.dart';
import '../widgets/m3/m3_search_field.dart';

const double _roomSearchToolbarHeight = 62;

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
    final l10n = AppLocalizations.of(context);
    final senderFallback = l10n.roomSearchMessageFallback;
    try {
      final results = await ref.read(matrixMessageSearchClientProvider).search(
            query,
            roomId: widget.roomId,
            limit: _limit,
          );
      final client = ref.read(matrixClientProvider);
      return results
          .map(
            (result) => _RoomSearchResult.remote(
              result,
              client,
              senderFallback: senderFallback,
            ),
          )
          .toList(growable: false);
    } catch (error) {
      debugPrint('room Matrix search failed: $error');
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          _RoomSearchToolbar(
            title: l10n.roomSearchTitle,
            onBack: () => context.pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: M3SearchField(
              controller: _controller,
              hint: l10n.roomSearchHint,
              autofocus: true,
              onChanged: _onChanged,
            ),
          ),
          Expanded(child: _buildBody(t, l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(PortalTokens t, AppLocalizations l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_lastQuery.isEmpty) {
      return Center(
        child: Text(
          l10n.roomSearchEmptyPrompt,
          style: AppTheme.sans(size: 13, color: t.textMute),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          l10n.roomSearchNoResults(_lastQuery),
          style: AppTheme.sans(size: 13, color: t.textMute),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox.shrink(),
      itemBuilder: (context, index) {
        final result = _results[index];
        return _RoomSearchTile(
          result: result,
          query: _lastQuery,
          onTap: () => _openResult(result),
        );
      },
    );
  }

  void _openResult(_RoomSearchResult result) {
    final route = _conversationRouteForResult(result);
    if (route == null) {
      context.pop(result.eventId);
      return;
    }
    context.go(route);
  }

  String? _conversationRouteForResult(_RoomSearchResult result) {
    final roomId = widget.roomId.trim();
    if (roomId.isEmpty) return null;
    final room = ref.read(matrixClientProvider).getRoomById(roomId);
    final base = room?.isDirectChat == false ? '/group' : '/chat';
    final eventId = result.eventId.trim();
    final encodedRoomId = Uri.encodeComponent(roomId);
    if (eventId.isEmpty) return '$base/$encodedRoomId';
    return '$base/$encodedRoomId?event=${Uri.encodeComponent(eventId)}';
  }
}

class _RoomSearchResult {
  const _RoomSearchResult({
    required this.eventId,
    required this.senderName,
    required this.content,
    required this.timestamp,
  });

  factory _RoomSearchResult.remote(
    MatrixMessageSearchResult result,
    Client client, {
    required String senderFallback,
  }) {
    final room = client.getRoomById(result.roomId);
    var senderName = result.senderId.trim();
    if (room != null && senderName.isNotEmpty) {
      final member = room.unsafeGetUserFromMemoryOrFallback(senderName);
      final displayName = member.calcDisplayname().trim();
      if (displayName.isNotEmpty) senderName = displayName;
    }
    return _RoomSearchResult(
      eventId: result.eventId,
      senderName: senderName.isEmpty ? senderFallback : senderName,
      content: result.body,
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
  const _RoomSearchTile({
    required this.result,
    required this.query,
    required this.onTap,
  });

  final _RoomSearchResult result;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: t.border, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const _RoomSearchThumbnail(),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RoomSearchHighlightedText(
                        text: result.senderName,
                        query: query,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(size: 12, color: t.textMute)
                            .copyWith(letterSpacing: 0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MM-dd HH:mm').format(result.timestamp),
                  style: AppTheme.sans(size: 11, color: t.textMute),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomSearchToolbar extends StatelessWidget {
  const _RoomSearchToolbar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: _roomSearchToolbarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _RoomSearchBackButton(onTap: onBack),
              ),
              Text(
                title,
                style: AppTheme.sans(
                  size: 16,
                  weight: FontWeight.w600,
                  color: t.text,
                ).copyWith(letterSpacing: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomSearchBackButton extends StatelessWidget {
  const _RoomSearchBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: 0.08),
            blurRadius: 36,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: Material(
          color: t.surface.withValues(alpha: 0.72),
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: 40,
              child: Icon(Symbols.arrow_back, size: 24, color: t.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomSearchThumbnail extends StatelessWidget {
  const _RoomSearchThumbnail();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: t.primaryContainer,
        borderRadius: BorderRadius.circular(5.6),
      ),
      alignment: Alignment.center,
      child: Icon(Symbols.chat_bubble, size: 17, color: t.onPrimaryContainer),
    );
  }
}

class _RoomSearchHighlightedText extends StatelessWidget {
  const _RoomSearchHighlightedText({
    required this.text,
    required this.query,
  });

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Text.rich(
      TextSpan(children: _roomSearchHighlightSpans(text, query, t.accent)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTheme.sans(
        size: 16,
        weight: FontWeight.w500,
        color: t.text,
      ).copyWith(letterSpacing: 0),
    );
  }
}

List<TextSpan> _roomSearchHighlightSpans(
  String text,
  String query,
  Color highlight,
) {
  final q = query.trim();
  if (q.isEmpty) return [TextSpan(text: text)];
  final lowerText = text.toLowerCase();
  final lowerQuery = q.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (start < text.length) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index < 0) {
      spans.add(TextSpan(text: text.substring(start)));
      break;
    }
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index)));
    }
    final end = index + q.length;
    spans.add(
      TextSpan(
        text: text.substring(index, end),
        style: TextStyle(color: highlight, fontWeight: FontWeight.w700),
      ),
    );
    start = end;
  }
  return spans;
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

/// 消息搜索 —— 对应 INTERFACE_SPEC.md §5.1
/// 走 AsClient（当前 MockAsClient）的 /_as/search，全文搜消息内容。
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../data/as_client.dart';
import '../../data/mock_as_client.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<AsSearchResult> _results = [];
  bool _loading = false;
  String _lastQuery = '';

  void _onChanged(String query) {
    _debounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _lastQuery = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final as = ref.read(asClientProvider);
      final results = await as.search(query, limit: 30);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _lastQuery = query;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
        _lastQuery = query;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      body: Column(
        children: [
          GlassHeader.detail(title: '搜索消息'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: M3InputField(
              controller: _ctrl,
              icon: Symbols.search,
              hint: '搜索消息内容…',
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lastQuery.isEmpty) {
      return Center(
        child: Text('输入关键词搜索聊天记录',
            style: AppTheme.sans(size: 13, color: t.textMute)),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text('没有找到包含「$_lastQuery」的消息',
            style: AppTheme.sans(size: 13, color: t.textMute)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: t.border, indent: 16),
      itemBuilder: (context, i) {
        final r = _results[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: t.accent.withValues(alpha: 0.15),
            child: Text(
              r.senderName.isEmpty
                  ? '?'
                  : r.senderName.characters.first.toUpperCase(),
              style: AppTheme.sans(size: 14, color: t.accent),
            ),
          ),
          title: Text(r.senderName,
              style: AppTheme.sans(
                  size: 14, weight: FontWeight.w600, color: t.text)),
          subtitle: Text(
            r.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(size: 12, color: t.textMute),
          ),
          trailing: Text(
            DateFormat('MM-dd HH:mm').format(r.timestamp),
            style: AppTheme.mono(size: 10, color: t.textMute),
          ),
          onTap: () =>
              context.push('/chat/${Uri.encodeComponent(r.roomId)}'),
        );
      },
    );
  }
}

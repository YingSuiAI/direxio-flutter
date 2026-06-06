import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';

class ChannelSearchPage extends ConsumerStatefulWidget {
  const ChannelSearchPage({super.key});

  @override
  ConsumerState<ChannelSearchPage> createState() => _ChannelSearchPageState();
}

class _ChannelSearchPageState extends ConsumerState<ChannelSearchPage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  int _serial = 0;
  bool _loading = false;
  String _lastQuery = '';
  String _error = '';
  List<AsChannel> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _loading = false;
        _lastQuery = '';
        _error = '';
        _results = const [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 320), () => _search(q));
  }

  Future<void> _search(String query) async {
    final serial = ++_serial;
    setState(() {
      _loading = true;
      _lastQuery = query;
      _error = '';
    });
    try {
      final target = _channelSearchTarget(query);
      final results = await ref.read(asClientProvider).searchPublicChannels(
            target.query,
            baseUri: target.baseUri,
            limit: 20,
          );
      if (!mounted || serial != _serial) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (err) {
      if (!mounted || serial != _serial) return;
      setState(() {
        _results = const [];
        _loading = false;
        _error = '搜索失败，请稍后重试';
      });
    }
  }

  Future<void> _join(AsChannel channel) async {
    final id = channel.channelId.trim();
    if (id.isEmpty) return;
    try {
      final joined = await ref.read(asClientProvider).joinChannel(id);
      setState(() {
        _results = [
          for (final item in _results)
            if (item.channelId == id) joined else item,
        ];
      });
      if (joined.memberStatus == asChannelMemberStatusJoined) {
        await _refreshBootstrap();
      }
      if (!mounted) return;
      final message = joined.memberStatus == asChannelMemberStatusPending
          ? '已提交加入申请'
          : '已加入频道';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入频道失败：$err')),
      );
    }
  }

  Future<void> _refreshBootstrap() async {
    final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.copyWith(bootstrap: bootstrap),
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      body: Column(
        children: [
          GlassHeader.detail(title: '搜索频道'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: M3InputField(
              controller: _ctrl,
              icon: Symbols.search,
              hint: '输入频道名、标签、域名或 Portal URL',
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
      return const _ChannelSearchEmpty(
        icon: Symbols.travel_explore,
        title: '搜索公开频道',
        subtitle: '搜索是加入频道的主路径，也可以通过别人分享的频道卡片加入',
      );
    }
    if (_error.isNotEmpty) {
      return _ChannelSearchEmpty(
        icon: Symbols.error,
        title: _error,
        subtitle: '请检查网络或目标节点地址',
      );
    }
    if (_results.isEmpty) {
      return const _ChannelSearchEmpty(
        icon: Symbols.search_off,
        title: '没有找到频道',
        subtitle: '私密频道不会出现在搜索结果中，需要通过邀请或分享卡片加入',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final channel = _results[index];
        return _ChannelSearchResultTile(
          channel: channel,
          onTap: () => context.push(
            '/channel/${Uri.encodeComponent(channel.channelId)}',
          ),
          onJoin: () => _join(channel),
        );
      },
    );
  }
}

class _ChannelSearchTarget {
  const _ChannelSearchTarget({required this.query, this.baseUri});

  final String query;
  final Uri? baseUri;
}

_ChannelSearchTarget _channelSearchTarget(String rawQuery) {
  final query = rawQuery.trim();
  final uri = Uri.tryParse(query);
  final host = uri == null || uri.host.isEmpty ? '' : uri.host.trim();
  if ((uri?.scheme == 'http' || uri?.scheme == 'https') && host.isNotEmpty) {
    return _ChannelSearchTarget(
      query: '',
      baseUri: Uri(scheme: uri!.scheme, host: host, path: '/_as'),
    );
  }
  final domainLike = RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  if (domainLike.hasMatch(query)) {
    return _ChannelSearchTarget(
      query: '',
      baseUri: Uri(scheme: 'https', host: query, path: '/_as'),
    );
  }
  return _ChannelSearchTarget(query: query);
}

class _ChannelSearchEmpty extends StatelessWidget {
  const _ChannelSearchEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 42),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: t.textMute),
            const SizedBox(height: 14),
            Text(
              title,
              style: AppTheme.sans(
                size: 18,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 13, color: t.textMute).copyWith(
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelSearchResultTile extends StatelessWidget {
  const _ChannelSearchResultTile({
    required this.channel,
    required this.onTap,
    required this.onJoin,
  });

  final AsChannel channel;
  final VoidCallback onTap;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final status = channel.memberStatus.trim();
    final joined = status == asChannelMemberStatusJoined;
    final pending = status == asChannelMemberStatusPending;
    final approval = channel.joinPolicy == asChannelJoinPolicyApproval;
    final buttonLabel = joined
        ? '已加入'
        : pending
            ? '待审核'
            : approval
                ? '申请加入'
                : '加入';
    return Material(
      color: t.surface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _SearchChannelAvatar(channel: channel),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name.trim().isEmpty ? '未命名频道' : channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 16,
                        weight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _channelSubtitle(channel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(size: 13, color: t.textMute),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 34,
                child: FilledButton.tonal(
                  onPressed: joined || pending ? null : onJoin,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                  ),
                  child: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _channelSubtitle(AsChannel channel) {
    final parts = <String>[];
    if (channel.homeDomain.trim().isNotEmpty) parts.add(channel.homeDomain);
    if (channel.description.trim().isNotEmpty) {
      parts.add(channel.description.trim());
    }
    if (parts.isEmpty) {
      parts.add(channel.joinPolicy == asChannelJoinPolicyApproval
          ? '公开频道 · 加入需审核'
          : '公开频道');
    }
    return parts.join(' · ');
  }
}

class _SearchChannelAvatar extends StatelessWidget {
  const _SearchChannelAvatar({required this.channel});

  final AsChannel channel;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(Symbols.campaign, color: t.accent, size: 25, fill: 1),
    );
  }
}

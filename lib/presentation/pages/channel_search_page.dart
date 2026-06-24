import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../channel/channel_join_flow.dart';
import '../channel/channel_join_debug_log.dart';
import '../channel/channel_share.dart';
import '../channel/public_channel_target.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../utils/product_conversation_navigation.dart';
import '../widgets/m3/m3_search_field.dart';

AppLocalizations? _channelSearchL10n(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations);
}

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
      if (looksLikeMatrixRoomId(query)) {
        final channel =
            await ref.read(asClientProvider).getPublicChannelByRoomId(
                  query.trim(),
                  remoteNodeBaseUri: publicBaseUriForMatrixRoomId(query),
                );
        if (!mounted || serial != _serial) return;
        setState(() {
          _results = [channel];
          _loading = false;
        });
        return;
      }
      final target = _channelSearchTarget(query);
      final results = await ref.read(asClientProvider).searchPublicChannels(
            target.keyword,
            baseUri: target.baseUri,
          );
      if (!mounted || serial != _serial) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } on AsClientException catch (err) {
      if (!mounted || serial != _serial) return;
      setState(() {
        _results = const [];
        _loading = false;
        _error = err.statusCode == 404
            ? ''
            : _channelSearchL10n(context)?.channelSearchFailed ?? '搜索失败，请稍后重试';
      });
    } catch (err) {
      if (!mounted || serial != _serial) return;
      setState(() {
        _results = const [];
        _loading = false;
        _error =
            _channelSearchL10n(context)?.channelSearchFailed ?? '搜索失败，请稍后重试';
      });
    }
  }

  Future<void> _join(AsChannel channel) async {
    final id = channel.channelId.trim();
    final roomId = channel.roomId.trim();
    if (roomId.isEmpty) return;
    try {
      final joined = await ref.read(asClientProvider).joinChannelByRoomId(
            roomId,
            discoveredChannel: channel,
            remoteNodeBaseUri: publicBaseUriForMatrixRoomId(roomId),
          );
      setState(() {
        _results = [
          for (final item in _results)
            if (item.channelId == id) joined else item,
        ];
      });
      if (!mounted) return;
      if (isAsChannelMemberAwaitingJoin(joined.memberStatus)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(_channelJoinWaitingText(context, joined.memberStatus)),
          ),
        );
        return;
      }
      if (isAsChannelMemberJoinFailed(joined.memberStatus)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(_channelJoinWaitingText(context, joined.memberStatus)),
          ),
        );
        return;
      }
      if (!isAsChannelMemberJoined(joined.memberStatus)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _channelSearchL10n(context)?.channelJoinProcessing ??
                  channelJoinInProgressText,
            ),
          ),
        );
        return;
      }
      await _refreshBootstrap();
      if (!mounted) return;
      _openJoinedChannel(joined, fallback: channel);
    } catch (err) {
      logChannelJoinForbidden(
        err,
        source: 'channel_search',
        channelId: channel.channelId,
        roomId: roomId,
        remoteNodeBaseUri: publicBaseUriForMatrixRoomId(roomId),
        discoveredChannel: channel,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _channelSearchL10n(context)?.channelJoinFailed('$err') ??
                '加入频道失败：$err',
          ),
        ),
      );
    }
  }

  Future<void> _refreshBootstrap() async {
    final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
    ref.read(asSyncCacheProvider.notifier).update(
          (state) => state.copyWith(bootstrap: bootstrap),
        );
  }

  void _openJoinedChannel(AsChannel joined, {required AsChannel fallback}) {
    final channelId = joined.channelId.trim().isEmpty
        ? fallback.channelId.trim()
        : joined.channelId.trim();
    if (channelId.isEmpty) return;
    final encodedChannelId = Uri.encodeComponent(channelId);
    if (normalizeAsChannelType(joined.channelType) == asChannelTypePost) {
      context.go('/channel/$encodedChannelId');
      return;
    }
    final route = productConversationRoute(
      joined.productConversation,
      channelId: channelId,
    );
    if (route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _channelSearchL10n(context)?.channelSearchSyncing ?? '频道正在同步，请稍后重试',
          ),
        ),
      );
      return;
    }
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: context.tk.bg,
      body: Stack(
        children: [
          Positioned(
            left: 22,
            top: topInset + 36,
            child: _ChannelSearchCircleButton(
              icon: Symbols.arrow_back,
              onTap: () => context.pop(),
            ),
          ),
          Positioned(
            left: 76,
            right: 24,
            top: topInset + 39,
            height: 40,
            child: _ChannelSearchInput(
              controller: _ctrl,
              onChanged: _onChanged,
              hint: _channelSearchL10n(context)?.channelSearchHint ?? '搜索频道...',
            ),
          ),
          Positioned.fill(
            top: topInset + 132,
            child: _buildBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = _channelSearchL10n(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lastQuery.isEmpty) {
      return _ChannelSearchEmpty(
        icon: Symbols.search,
        title: l10n?.channelSearchTitle ?? '搜索频道',
        subtitle: l10n?.channelSearchPrompt ?? '输入频道ID查找频道',
      );
    }
    if (_error.isNotEmpty) {
      return _ChannelSearchEmpty(
        icon: Symbols.error,
        title: _error,
        subtitle: l10n?.channelSearchNetworkHint ?? '请检查网络或目标节点地址',
      );
    }
    if (_results.isEmpty) {
      return _ChannelSearchEmpty(
        icon: Symbols.search_off,
        title: l10n?.channelSearchNoResults ?? '没有找到频道',
        subtitle:
            l10n?.channelSearchPrivateHint ?? '私密频道不会出现在搜索结果中，需要通过邀请或分享卡片加入',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final channel = _results[index];
        final detailId = channel.roomId.trim().isEmpty
            ? channel.channelId
            : channel.roomId.trim();
        return _ChannelSearchResultTile(
          channel: channel,
          onTap: () => context.push(
            '/channel/${Uri.encodeComponent(detailId)}/detail',
            extra: channelSharePayloadFromChannel(
              channelId: channel.channelId,
              roomId: channel.roomId,
              homeDomain: channel.homeDomain,
              name: channel.name,
              description: channel.description,
              avatarUrl: channel.avatarUrl,
              visibility: channel.visibility,
              joinPolicy: channel.joinPolicy,
              commentsEnabled: channel.commentsEnabled,
              channelType: channel.channelType,
              tags: channel.tags,
              memberCount: channel.memberCount,
            ),
          ),
          onJoin: () => _join(channel),
          l10n: l10n,
        );
      },
    );
  }
}

String _channelJoinWaitingText(BuildContext context, String status) {
  return _channelJoinLabel(
    _channelSearchL10n(context),
    status,
    approval: false,
  );
}

class _ChannelSearchTarget {
  const _ChannelSearchTarget({
    this.keyword = '',
    this.baseUri,
  });

  final String keyword;
  final Uri? baseUri;
}

_ChannelSearchTarget _channelSearchTarget(String rawQuery) {
  final query = rawQuery.trim();
  final uri = Uri.tryParse(query);
  final host = uri == null || uri.host.isEmpty ? '' : uri.host.trim();
  if ((uri?.scheme == 'http' || uri?.scheme == 'https') && host.isNotEmpty) {
    return _ChannelSearchTarget(baseUri: publicBaseUriForServerName(query));
  }
  final domainLike = RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  if (domainLike.hasMatch(query)) {
    return _ChannelSearchTarget(baseUri: publicBaseUriForServerName(query));
  }
  return _ChannelSearchTarget(keyword: query);
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 42),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: context.tk.textMute, weight: 500),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTheme.sans(
                size: 17,
                weight: FontWeight.w500,
                color: context.tk.textMute,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTheme.sans(
                size: 14,
                color: context.tk.textMute,
              ).copyWith(
                height: 20 / 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelSearchCircleButton extends StatelessWidget {
  const _ChannelSearchCircleButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tk.surface,
      shape: const CircleBorder(),
      elevation: 14,
      shadowColor: _channelSearchShadowColor(context),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 42,
          child: Center(
            child: Icon(
              icon,
              size: 28,
              weight: 700,
              color: context.tk.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelSearchInput extends StatelessWidget {
  const _ChannelSearchInput({
    required this.controller,
    required this.onChanged,
    required this.hint,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return M3SearchField(
      controller: controller,
      hint: hint,
      autofocus: true,
      onChanged: onChanged,
    );
  }
}

class _ChannelSearchResultTile extends StatelessWidget {
  const _ChannelSearchResultTile({
    required this.channel,
    required this.onTap,
    required this.onJoin,
    required this.l10n,
  });

  final AsChannel channel;
  final VoidCallback onTap;
  final VoidCallback onJoin;
  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final status = channel.memberStatus.trim();
    final joined = status == asChannelMemberStatusJoined;
    final pending = status == asChannelMemberStatusPending;
    final approved = status == asChannelMemberStatusApproved ||
        status == asChannelMemberStatusJoining;
    final approval = channel.joinPolicy == asChannelJoinPolicyApproval;
    final buttonLabel = _channelJoinLabel(
      l10n,
      status,
      approval: approval,
    );
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
                      channel.name.trim().isEmpty
                          ? l10n?.channelSearchUnnamed ?? '未命名频道'
                          : channel.name,
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
                      _channelSubtitle(channel, l10n),
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
                  onPressed: joined || pending || approved ? null : onJoin,
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

  static String _channelSubtitle(AsChannel channel, AppLocalizations? l10n) {
    final parts = <String>[];
    if (channel.homeDomain.trim().isNotEmpty) parts.add(channel.homeDomain);
    if (channel.description.trim().isNotEmpty) {
      parts.add(channel.description.trim());
    }
    if (parts.isEmpty) {
      parts.add(channel.joinPolicy == asChannelJoinPolicyApproval
          ? l10n?.channelSearchPublicApproval ?? '公开频道 · 加入需审核'
          : l10n?.channelSearchPublicChannel ?? '公开频道');
    }
    return parts.join(' · ');
  }
}

String _channelJoinLabel(
  AppLocalizations? l10n,
  String status, {
  required bool approval,
}) {
  if (status == asChannelMemberStatusJoined) {
    return l10n?.channelJoinJoined ?? '已加入';
  }
  if (status == asChannelMemberStatusPending) {
    return l10n?.channelJoinPending ?? '待审核';
  }
  if (status == asChannelMemberStatusApproved ||
      status == asChannelMemberStatusJoining) {
    return l10n?.channelJoinSyncing ?? '同步中';
  }
  if (status == asChannelMemberStatusJoinFailed) {
    return l10n?.channelJoinRetry ?? '重试';
  }
  if (approval) return l10n?.channelJoinApply ?? '申请加入';
  return l10n?.channelJoinAction ?? '加入';
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

Color _channelSearchShadowColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.34)
      : Colors.black.withValues(alpha: 0.08);
}

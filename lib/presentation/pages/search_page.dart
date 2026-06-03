// 全局搜索。
// 消息全文走 AsClient /_as/search；联系人、群聊、频道走本地缓存索引。
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../../data/as_client.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../channel/channel_inbox_data.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../mock/mock_channels.dart';
import '../mock/mock_data.dart';
import '../utils/contact_identity_label.dart';
import '../utils/direct_contact_status.dart';
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
  List<_GlobalSearchResult> _results = [];
  bool _loading = false;
  String _lastQuery = '';
  int _searchSerial = 0;

  static const _messageSearchLimit = 30;
  static const _cachedMessagePageSize = 60;
  static const _maxCachedEventsPerRoom = 300;

  void _onChanged(String query) {
    _debounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      _searchSerial++;
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
    final serial = ++_searchSerial;
    setState(() => _loading = true);
    final client = ref.read(matrixClientProvider);
    final directoryResults = _localDirectoryResults(query, client);
    final remoteMessageResultsFuture = _remoteMessageResults(query);
    final cachedMessageResults = await _cachedMessageResults(query, client);
    if (!mounted || serial != _searchSerial) return;
    final localResults = [
      ...directoryResults,
      ...cachedMessageResults,
    ];
    setState(() {
      _results = _dedupeResults(localResults);
      _loading = false;
      _lastQuery = query;
    });

    final remoteMessageResults = await remoteMessageResultsFuture;
    if (!mounted || serial != _searchSerial) return;
    setState(() {
      _results = _dedupeResults([
        ...localResults,
        ...remoteMessageResults.map(_GlobalSearchResult.remoteMessage),
      ]);
    });
  }

  Future<List<AsSearchResult>> _remoteMessageResults(String query) async {
    try {
      final as = ref.read(asClientProvider);
      return as.search(query, limit: _messageSearchLimit);
    } catch (_) {
      return const [];
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
          GlassHeader.detail(title: '搜索'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: M3InputField(
              controller: _ctrl,
              icon: Symbols.search,
              hint: '搜索消息、联系人、群聊、频道',
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
        child: Text(
          '输入关键词开始搜索',
          style: AppTheme.sans(size: 13, color: t.textMute),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          '没有找到包含「$_lastQuery」的内容',
          style: AppTheme.sans(size: 13, color: t.textMute),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: t.border, indent: 16),
      itemBuilder: (context, i) {
        final r = _results[i];
        return _SearchResultTile(result: r);
      },
    );
  }

  List<_GlobalSearchResult> _localDirectoryResults(
      String query, Client client) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final results = <_GlobalSearchResult>[];

    bool containsAny(Iterable<String?> values) => values.any((value) {
          final text = value?.trim().toLowerCase() ?? '';
          return text.isNotEmpty && text.contains(q);
        });

    if (client.rooms.isEmpty) {
      for (final c in MockData.conversations) {
        if (c.id == 'mock_aibot') continue;
        final isContact = c.mxid.startsWith('@');
        final isGroup = c.isGroup || c.mxid.startsWith('!');
        if (!containsAny([c.name, c.mxid, c.subtitle])) continue;
        results.add(
          _GlobalSearchResult.local(
            type: isGroup ? _SearchResultType.group : _SearchResultType.contact,
            title: c.name,
            subtitle: isContact ? c.mxid : c.subtitle,
            route: isGroup ? '/group/${c.id}' : '/chat/${c.id}',
          ),
        );
      }
    } else {
      final syncCache = ref.read(asSyncCacheProvider);
      final acceptedRoomIds = syncCache.acceptedDirectRoomIds;
      for (final room in client.rooms) {
        if (room.membership != Membership.join) continue;
        final acceptedContact = syncCache.acceptedContactForRoom(room.id);
        final peerMxid = productDirectPeerMxid(room) ?? acceptedContact?.userId;
        final name = contactDisplayNameFromIdentity(
          mxid: peerMxid ?? '',
          displayName: acceptedContact?.displayName ?? '',
          domain: acceptedContact?.domain ?? '',
          fallback: room.getLocalizedDisplayname(),
        );
        if (!containsAny([name, peerMxid, room.id])) continue;
        final isContact = isProductDirectContactRoom(
          room,
          acceptedRoomIds: acceptedRoomIds,
        );
        final encodedRoomId = Uri.encodeComponent(room.id);
        results.add(
          _GlobalSearchResult.local(
            type:
                isContact ? _SearchResultType.contact : _SearchResultType.group,
            title: name,
            subtitle: isContact ? (peerMxid ?? room.id) : '群聊',
            route: isContact ? '/chat/$encodedRoomId' : '/group/$encodedRoomId',
          ),
        );
      }
    }

    final bootstrap = ref.read(asSyncCacheProvider).bootstrap;
    final realChannels = bootstrap == null
        ? null
        : ChannelInboxData.fromBootstrap(
            bootstrap,
            fallbackDomain: _fallbackDomain(client),
          );
    if (realChannels != null) {
      for (final channel in realChannels) {
        if (!containsAny([
          channel.name,
          channel.domain,
          channel.latestPreview,
          ...channel.tags,
        ])) {
          continue;
        }
        results.add(
          _GlobalSearchResult.local(
            type: _SearchResultType.channel,
            title: channel.name,
            subtitle: '${channel.domain} · ${channel.latestPreview}',
            route: '/channel/${Uri.encodeComponent(channel.id)}',
          ),
        );
      }
      return results;
    }

    for (final channel in MockChannels.items) {
      if (!containsAny([
        channel.name,
        channel.handle,
        channel.latestMessage,
        ...channel.tags,
      ])) {
        continue;
      }
      results.add(
        _GlobalSearchResult.local(
          type: _SearchResultType.channel,
          title: channel.name,
          subtitle: '${channel.handle} · ${channel.latestMessage}',
          route: '/channel/${Uri.encodeComponent(channel.id)}',
        ),
      );
    }

    return results;
  }

  Future<List<_GlobalSearchResult>> _cachedMessageResults(
    String query,
    Client client,
  ) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final results = <_GlobalSearchResult>[];
    final seenEventIds = <String>{};

    void maybeAdd(Event event) {
      if (results.length >= _messageSearchLimit) return;
      if (!_isSearchableMessage(event)) return;
      if (!event.plaintextBody.toLowerCase().contains(q)) return;
      if (!seenEventIds.add(event.eventId)) return;
      results.add(_GlobalSearchResult.cachedMessage(event));
    }

    for (final room in client.rooms) {
      if (results.length >= _messageSearchLimit) break;
      if (room.membership != Membership.join) continue;

      final lastEvent = room.lastEvent;
      if (lastEvent != null) maybeAdd(lastEvent);

      final database = client.database;
      if (database == null) continue;

      var start = 0;
      while (results.length < _messageSearchLimit &&
          start < _maxCachedEventsPerRoom) {
        final pageLimit =
            start + _cachedMessagePageSize > _maxCachedEventsPerRoom
                ? _maxCachedEventsPerRoom - start
                : _cachedMessagePageSize;
        List<Event> events;
        try {
          events = await database.getEventList(
            room,
            start: start,
            limit: pageLimit,
          );
        } catch (e) {
          debugPrint('cached message search failed for ${room.id}: $e');
          break;
        }
        if (events.isEmpty) break;
        for (final event in events) {
          maybeAdd(event);
          if (results.length >= _messageSearchLimit) break;
        }
        start += events.length;
        if (events.length < pageLimit) break;
      }
    }

    return results;
  }

  List<_GlobalSearchResult> _dedupeResults(
    List<_GlobalSearchResult> results,
  ) {
    final seenMessageEvents = <String>{};
    final seenLocalKeys = <String>{};
    final deduped = <_GlobalSearchResult>[];
    for (final result in results) {
      final eventId = result.eventId;
      if (eventId != null && eventId.isNotEmpty) {
        if (!seenMessageEvents.add('${result.route}:$eventId')) continue;
      } else {
        final key = '${result.type}:${result.route}:${result.title}';
        if (!seenLocalKeys.add(key)) continue;
      }
      deduped.add(result);
    }
    return deduped;
  }
}

String _fallbackDomain(Client client) {
  final userId = client.userID ?? '';
  final idx = userId.lastIndexOf(':');
  if (idx >= 0 && idx < userId.length - 1) {
    return userId.substring(idx + 1);
  }
  final homeserver = client.homeserver;
  if (homeserver != null && homeserver.host.isNotEmpty) return homeserver.host;
  return 'p2p-im.com';
}

enum _SearchResultType { message, contact, group, channel }

class _GlobalSearchResult {
  const _GlobalSearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    this.route,
    this.eventId,
    this.timestamp,
  });

  factory _GlobalSearchResult.remoteMessage(AsSearchResult result) =>
      _GlobalSearchResult(
        type: _SearchResultType.message,
        title: result.senderName.isEmpty ? '消息' : result.senderName,
        subtitle: result.content,
        route: '/chat/${Uri.encodeComponent(result.roomId)}',
        eventId: result.eventId,
        timestamp: result.timestamp,
      );

  factory _GlobalSearchResult.cachedMessage(Event event) {
    final room = event.room;
    final encodedRoomId = Uri.encodeComponent(room.id);
    return _GlobalSearchResult(
      type: _SearchResultType.message,
      title: _senderDisplayName(event),
      subtitle: event.plaintextBody,
      route:
          room.isDirectChat ? '/chat/$encodedRoomId' : '/group/$encodedRoomId',
      eventId: event.eventId,
      timestamp: event.originServerTs,
    );
  }

  factory _GlobalSearchResult.local({
    required _SearchResultType type,
    required String title,
    required String subtitle,
    String? route,
  }) =>
      _GlobalSearchResult(
        type: type,
        title: title,
        subtitle: subtitle,
        route: route,
      );

  final _SearchResultType type;
  final String title;
  final String subtitle;
  final String? route;
  final String? eventId;
  final DateTime? timestamp;

  IconData get icon => switch (type) {
        _SearchResultType.message => Symbols.chat_bubble,
        _SearchResultType.contact => Symbols.person,
        _SearchResultType.group => Symbols.groups,
        _SearchResultType.channel => Symbols.campaign,
      };

  String get label => switch (type) {
        _SearchResultType.message => '消息',
        _SearchResultType.contact => '联系人',
        _SearchResultType.group => '群聊',
        _SearchResultType.channel => '频道',
      };
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result});

  final _GlobalSearchResult result;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: t.surfaceHover,
        child: Icon(result.icon, size: 18, color: t.textMute),
      ),
      title: Text(
        result.title,
        style: AppTheme.sans(
          size: 14,
          weight: FontWeight.w600,
          color: t.text,
        ),
      ),
      subtitle: Text(
        result.subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.sans(size: 12, color: t.textMute),
      ),
      trailing: result.timestamp == null
          ? Text(result.label,
              style: AppTheme.mono(size: 10, color: t.textMute))
          : Text(
              DateFormat('MM-dd HH:mm').format(result.timestamp!),
              style: AppTheme.mono(size: 10, color: t.textMute),
            ),
      onTap: result.route == null
          ? () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('频道详情功能待接入')),
              )
          : () => context.push(result.route!),
    );
  }
}

bool _isSearchableMessage(Event event) {
  if (event.type != EventTypes.Message) return false;
  if (event.redacted) return false;
  return event.plaintextBody.trim().isNotEmpty;
}

String _senderDisplayName(Event event) {
  final member = event.room.getState(EventTypes.RoomMember, event.senderId);
  final displayName = member?.content['displayname'];
  if (displayName is String && displayName.trim().isNotEmpty) {
    return displayName.trim();
  }
  return _compactMxid(event.senderId);
}

String _compactMxid(String mxid) {
  if (mxid.startsWith('@') && mxid.contains(':')) {
    return mxid.substring(1, mxid.indexOf(':'));
  }
  return mxid;
}

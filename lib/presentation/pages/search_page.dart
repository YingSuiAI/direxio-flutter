// 全局搜索。
// 消息全文走 Matrix /search；联系人、群聊、频道走本地缓存索引。
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../../data/as_client.dart';
import '../../data/matrix_message_search_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../channel/channel_inbox_data.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_preferences_provider.dart';
import '../providers/matrix_message_clients_provider.dart';
import '../providers/product_conversations_provider.dart';
import '../groups/group_invite_content.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_display_name.dart';
import '../utils/contact_identity_label.dart';
import '../utils/direct_contact_status.dart';
import '../utils/group_avatar_members.dart';
import '../utils/product_conversation_navigation.dart';
import '../widgets/group_composite_avatar.dart';
import '../widgets/m3/m3_search_field.dart';
import '../widgets/portal_avatar.dart';

AppLocalizations? _searchL10n(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations);
}

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
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
    final l10n = _searchL10n(context);
    setState(() => _loading = true);
    final client = ref.read(matrixClientProvider);
    final productConversations = await _productConversations();
    if (!mounted || serial != _searchSerial) return;
    final directoryResults =
        _localDirectoryResults(query, client, productConversations, l10n);
    final remoteMessageResultsFuture = _remoteMessageResults(query);
    final cachedMessageResults =
        await _cachedMessageResults(query, client, productConversations);
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
        ...remoteMessageResults
            .where((result) => !_isGroupInviteSearchContent(result.body))
            .map(
              (result) => _GlobalSearchResult.remoteMessage(
                result,
                client,
                productConversations,
                l10n,
              ),
            )
            .whereType<_GlobalSearchResult>(),
      ]);
    });
  }

  Future<List<AsConversation>> _productConversations() async {
    try {
      return await ref.read(productConversationsProvider.future);
    } catch (_) {
      return const [];
    }
  }

  Future<List<MatrixMessageSearchResult>> _remoteMessageResults(
    String query,
  ) async {
    try {
      return await ref
          .read(matrixMessageSearchClientProvider)
          .search(query, limit: _messageSearchLimit);
    } catch (_) {
      return const [];
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tk.bg,
      body: Column(
        children: [
          _SearchToolbar(onBack: () => context.pop()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _SearchInput(
              controller: _ctrl,
              focusNode: _focusNode,
              onChanged: _onChanged,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_lastQuery.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_results.isEmpty) {
      final l10n = _searchL10n(context);
      return Center(
        child: Text(
          l10n?.globalSearchNoResults(_lastQuery) ?? '没有找到包含「$_lastQuery」的内容',
          style: AppTheme.sans(size: 13, color: context.tk.textMute),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final r = _results[i];
        return _SearchResultTile(
          result: r,
          query: _lastQuery,
          l10n: _searchL10n(context),
        );
      },
    );
  }

  List<_GlobalSearchResult> _localDirectoryResults(
    String query,
    Client client,
    Iterable<AsConversation> productConversations,
    AppLocalizations? l10n,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final results = <_GlobalSearchResult>[];

    bool containsAny(Iterable<String?> values) => values.any((value) {
          final text = value?.trim().toLowerCase() ?? '';
          return text.isNotEmpty && text.contains(q);
        });

    final syncCache = ref.read(asSyncCacheProvider);
    final groupAvatarMemberOrders = ref.read(groupAvatarMemberOrdersProvider);
    final groupAvatarMemberAvatars = ref.read(groupAvatarMemberAvatarsProvider);
    for (final room in client.rooms) {
      if (room.membership != Membership.join) continue;
      final productConversation = productConversationForRoom(
        productConversations,
        room.id,
      );
      if (productConversation == null) continue;
      final route = productConversationRoute(productConversation);
      if (route == null) continue;

      final isContact = productConversation.isDirect;
      final acceptedContact =
          isContact ? syncCache.acceptedContactForRoom(room.id) : null;
      final peerMxid = isContact
          ? productDirectPeerMxid(room) ?? acceptedContact?.userId
          : null;
      final memberName =
          isContact ? directPeerMemberDisplayName(room, peerMxid) : '';
      final name = isContact
          ? contactDisplayNameFromIdentity(
              mxid: peerMxid ?? '',
              displayName: memberName.isNotEmpty
                  ? memberName
                  : acceptedContact?.displayName ?? '',
              domain: acceptedContact?.domain ?? '',
              fallback: productConversation.title.trim().isNotEmpty
                  ? productConversation.title
                  : safeRoomDisplayName(room),
            )
          : productConversation.title.trim().isNotEmpty
              ? productConversation.title.trim()
              : safeRoomDisplayName(room);
      if (!containsAny([name, peerMxid, room.id])) continue;
      final groupAvatarMembers = productConversation.isGroup
          ? stableGroupAvatarMembersForRoom(
              room: room,
              syncCache: syncCache,
              cachedMemberOrder:
                  groupAvatarMemberOrders[room.id] ?? const <String>[],
              cachedMemberAvatarUrls:
                  groupAvatarMemberAvatars[room.id] ?? const {},
            ).members
          : const <GroupCompositeAvatarMember>[];
      results.add(
        _GlobalSearchResult.local(
          type: isContact ? _SearchResultType.contact : _SearchResultType.group,
          title: name,
          subtitle: isContact
              ? (peerMxid ?? room.id)
              : l10n?.globalSearchGroupLabel ?? '群聊',
          route: route,
          avatarUrl: isContact
              ? avatarHttpUrl(client, productConversation.avatarUrl) ??
                  avatarHttpUrl(client, acceptedContact?.avatarUrl) ??
                  _memberAvatarHttpUrl(room, peerMxid)
              : avatarHttpUrl(client, productConversation.avatarUrl) ??
                  roomAvatarHttpUrl(room),
          avatarSeed: isContact ? peerMxid ?? name : room.id,
          groupAvatarMembers: groupAvatarMembers,
        ),
      );
    }

    final bootstrap = ref.read(asSyncCacheProvider).bootstrap;
    final realChannels = bootstrap == null
        ? null
        : ChannelInboxData.fromBootstrap(
            bootstrap,
            fallbackDomain: _fallbackDomain(client),
            roomNameForRoomId: (roomId) => _matrixRoomName(client, roomId),
            roomAvatarForRoomId: (roomId) => _matrixRoomAvatar(client, roomId),
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
            avatarUrl: avatarHttpUrl(client, channel.avatarUrl),
            avatarSeed: channel.id,
          ),
        );
      }
      return results;
    }
    return results;
  }

  Future<List<_GlobalSearchResult>> _cachedMessageResults(
    String query,
    Client client,
    Iterable<AsConversation> productConversations,
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
      final result =
          _GlobalSearchResult.cachedMessage(event, productConversations);
      if (result != null) results.add(result);
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
        if (!seenMessageEvents.add(eventId)) continue;
      } else {
        final key = '${result.type}:${result.route}:${result.title}';
        if (!seenLocalKeys.add(key)) continue;
      }
      deduped.add(result);
    }
    return deduped;
  }
}

const _searchToolbarHeight = 48.0;

String _fallbackDomain(Client client) {
  final userId = client.userID ?? '';
  final serverName = domainFromMxid(userId);
  if (serverName.isNotEmpty) return serverName;
  final homeserver = client.homeserver;
  if (homeserver != null && homeserver.host.isNotEmpty) return homeserver.host;
  return 'p2p-im.com';
}

String _matrixRoomName(Client client, String roomId) {
  final room = client.getRoomById(roomId.trim());
  if (room == null) return '';
  final name = safeRoomDisplayName(room).trim();
  return _looksLikeMatrixRoomId(name) ? '' : name;
}

String _matrixRoomAvatar(Client client, String roomId) {
  return client.getRoomById(roomId.trim())?.avatar?.toString() ?? '';
}

String? _memberAvatarHttpUrl(Room room, String? mxid) {
  final memberId = mxid?.trim() ?? '';
  if (memberId.isEmpty) return null;
  final member = room.getState(EventTypes.RoomMember, memberId)?.asUser(room);
  if (member == null) return null;
  return matrixContentHttpUrl(room.client, member.avatarUrl);
}

bool _looksLikeMatrixRoomId(String text) {
  return text.startsWith('!') && text.contains(':');
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
    this.avatarUrl,
    this.avatarSeed,
    this.groupAvatarMembers = const [],
  });

  static _GlobalSearchResult? remoteMessage(
    MatrixMessageSearchResult result,
    Client client,
    Iterable<AsConversation> productConversations,
    AppLocalizations? l10n,
  ) {
    final room = client.getRoomById(result.roomId);
    var senderName = result.senderId.trim();
    if (room != null && senderName.isNotEmpty) {
      final displayName = directPeerMemberDisplayName(room, senderName);
      if (displayName.isNotEmpty) senderName = displayName;
    }
    final productConversation = productConversationForRoom(
      productConversations,
      result.roomId,
    );
    final route = productConversationRoute(productConversation);
    if (route == null) return null;
    return _GlobalSearchResult(
      type: _SearchResultType.message,
      title: senderName.isEmpty
          ? l10n?.globalSearchMessageFallback ?? '消息'
          : senderName,
      subtitle: result.body,
      route: route,
      eventId: result.eventId,
      timestamp: result.timestamp,
    );
  }

  static _GlobalSearchResult? cachedMessage(
    Event event,
    Iterable<AsConversation> productConversations,
  ) {
    final room = event.room;
    final conversation =
        productConversationForRoom(productConversations, room.id);
    final route = productConversationRoute(conversation);
    if (route == null) return null;
    return _GlobalSearchResult(
      type: _SearchResultType.message,
      title: _senderDisplayName(event),
      subtitle: event.plaintextBody,
      route: route,
      eventId: event.eventId,
      timestamp: event.originServerTs,
    );
  }

  factory _GlobalSearchResult.local({
    required _SearchResultType type,
    required String title,
    required String subtitle,
    String? route,
    String? avatarUrl,
    String? avatarSeed,
    List<GroupCompositeAvatarMember> groupAvatarMembers = const [],
  }) =>
      _GlobalSearchResult(
        type: type,
        title: title,
        subtitle: subtitle,
        route: route,
        avatarUrl: avatarUrl,
        avatarSeed: avatarSeed,
        groupAvatarMembers: groupAvatarMembers,
      );

  final _SearchResultType type;
  final String title;
  final String subtitle;
  final String? route;
  final String? eventId;
  final DateTime? timestamp;
  final String? avatarUrl;
  final String? avatarSeed;
  final List<GroupCompositeAvatarMember> groupAvatarMembers;

  IconData get icon => switch (type) {
        _SearchResultType.message => Symbols.chat_bubble,
        _SearchResultType.contact => Symbols.person,
        _SearchResultType.group => Symbols.groups,
        _SearchResultType.channel => Symbols.campaign,
      };

  String label(AppLocalizations? l10n) => switch (type) {
        _SearchResultType.message => l10n?.globalSearchMessageLabel ?? '消息',
        _SearchResultType.contact => l10n?.globalSearchContactLabel ?? '联系人',
        _SearchResultType.group => l10n?.globalSearchGroupLabel ?? '群聊',
        _SearchResultType.channel => l10n?.globalSearchChannelLabel ?? '频道',
      };
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.query,
    required this.l10n,
  });

  final _GlobalSearchResult result;
  final String query;
  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final targetRoute = _targetRouteForResult(result);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: targetRoute == null
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n?.globalSearchChannelDetailPending ?? '频道详情功能待接入',
                    ),
                  ),
                )
            : () => context.push(targetRoute),
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
                _ResultThumbnail(result: result),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HighlightedResultTitle(
                        text: result.title,
                        query: query,
                      ),
                      if (result.subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          result.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(size: 12, color: t.textMute)
                              .copyWith(letterSpacing: 0),
                        ),
                      ],
                    ],
                  ),
                ),
                if (result.timestamp != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MM-dd HH:mm').format(result.timestamp!),
                    style: AppTheme.sans(size: 11, color: t.textMute),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _targetRouteForResult(_GlobalSearchResult result) {
  final route = result.route;
  if (route == null) return null;
  final eventId = result.eventId?.trim() ?? '';
  if (eventId.isEmpty) return route;
  return '$route?event=${Uri.encodeComponent(eventId)}';
}

class _SearchToolbar extends StatelessWidget {
  const _SearchToolbar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: _searchToolbarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _SearchBackButton(onTap: onBack),
              ),
              Text(
                _searchL10n(context)?.globalSearchTitle ?? '搜索',
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

class _SearchBackButton extends StatelessWidget {
  const _SearchBackButton({required this.onTap});

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

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return M3SearchField(
      controller: controller,
      focusNode: focusNode,
      hint: _searchL10n(context)?.globalSearchHint ?? '搜索',
      autofocus: true,
      onChanged: onChanged,
    );
  }
}

class _ResultThumbnail extends StatelessWidget {
  const _ResultThumbnail({required this.result});

  final _GlobalSearchResult result;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final avatarSeed = result.avatarSeed?.trim().isNotEmpty == true
        ? result.avatarSeed!.trim()
        : result.title;
    if (result.type == _SearchResultType.group &&
        (result.avatarUrl?.trim().isNotEmpty == true ||
            result.groupAvatarMembers.isNotEmpty)) {
      return GroupCompositeAvatar(
        seed: avatarSeed,
        size: 28,
        imageUrl: result.avatarUrl,
        members: result.groupAvatarMembers,
        minimumSlots: 4,
        radius: 5.6,
      );
    }
    if (result.avatarUrl?.trim().isNotEmpty == true) {
      return PortalAvatar(
        seed: avatarSeed,
        size: 28,
        imageUrl: result.avatarUrl!.trim(),
        shape: AvatarShape.squircle,
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _thumbnailColor(context, result.type),
        borderRadius: BorderRadius.circular(5.6),
      ),
      alignment: Alignment.center,
      child: Icon(result.icon, size: 17, color: t.onAccent),
    );
  }
}

Color _thumbnailColor(BuildContext context, _SearchResultType type) {
  final t = context.tk;
  return switch (type) {
    _SearchResultType.message => t.primaryContainer,
    _SearchResultType.contact => t.accent,
    _SearchResultType.group => t.secondaryContainer,
    _SearchResultType.channel => t.accentCool,
  };
}

class _HighlightedResultTitle extends StatelessWidget {
  const _HighlightedResultTitle({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final spans = _highlightSpans(text, query, t.accent);
    return Text.rich(
      TextSpan(children: spans),
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

List<TextSpan> _highlightSpans(String text, String query, Color highlight) {
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
        style: TextStyle(color: highlight),
      ),
    );
    start = end;
  }
  return spans.isEmpty ? [TextSpan(text: text)] : spans;
}

bool _isSearchableMessage(Event event) {
  if (event.type != EventTypes.Message) return false;
  if (event.redacted) return false;
  if (GroupInviteContent.tryParse(event.content, eventId: event.eventId) !=
      null) {
    return false;
  }
  if (_isGroupInviteSearchContent(event.plaintextBody)) return false;
  return event.plaintextBody.trim().isNotEmpty;
}

bool _isGroupInviteSearchContent(String content) {
  final text = content.trim();
  if (text.isEmpty) return false;
  final lower = text.toLowerCase();
  return lower.contains(GroupInviteContent.msgTypeV1) ||
      lower.contains(GroupInviteContent.legacyMsgType) ||
      text.contains('邀请加入群聊') ||
      text.contains('邀请进群') ||
      text.contains('群邀请');
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

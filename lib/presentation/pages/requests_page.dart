import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../providers/auth_provider.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/friend_request_read_provider.dart';
import '../groups/group_invite_join_flow.dart';
import '../widgets/portal_avatar.dart';
import '../utils/avatar_url.dart';
import '../utils/contact_identity_label.dart';
import '../utils/direct_contact_status.dart';
import '../utils/product_conversation_navigation.dart';
import '../../data/as_client.dart';
import '../../data/well_known_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/m3/m3_search_field.dart';

const _requestsToolbarHeight = 62.0;
const _requestsSearchGap = 12.0;

/// `s-new-friends` — 新朋友 (index.html L1494-1564)
class RequestsPage extends ConsumerStatefulWidget {
  const RequestsPage({super.key});

  @override
  ConsumerState<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends ConsumerState<RequestsPage> {
  StreamSubscription<SyncUpdate>? _syncSub;
  final _searchCtrl = TextEditingController();
  bool _busy = false;
  String? _notice;
  bool _noticeIsError = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final client = ref.read(matrixClientProvider);
    _syncSub = client.onSync.stream.listen((_) {
      if (!mounted) return;
      setState(() {});
      unawaited(_refreshBootstrap(silent: true));
    });
    _searchCtrl.addListener(() {
      final next = _searchCtrl.text;
      if (next == _query) return;
      setState(() {
        _query = next;
        _notice = null;
        _noticeIsError = false;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markCurrentFriendRequestsRead();
      unawaited(_refreshBootstrap(silent: true));
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _accept(Room room) async {
    setState(() => _busy = true);
    try {
      final peerMXID = _peerMxidForRoom(room);
      if (peerMXID == null || peerMXID.isEmpty) {
        throw const FormatException('无法识别请求来源');
      }
      final contact = await ref.read(asClientProvider).acceptContactRequest(
            roomId: room.id,
            peerMxid: peerMXID,
            domain: _domainFromMxid(peerMXID),
            displayName: contactDisplayNameFromIdentity(
              mxid: peerMXID,
              displayName: room.getLocalizedDisplayname(),
              domain: _domainFromMxid(peerMXID),
            ),
          );
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withContactEntry(contact),
          );
      await ref.read(matrixClientProvider).oneShotSync();
      await _refreshBootstrap();
      if (mounted) {
        setState(() {
          _notice = '已接受好友请求';
          _noticeIsError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notice = '接受失败：$e';
          _noticeIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(Room room) async {
    setState(() => _busy = true);
    try {
      final peerMXID = _peerMxidForRoom(room);
      if (peerMXID == null || peerMXID.isEmpty) {
        throw const FormatException('无法识别请求来源');
      }
      final contact = await ref.read(asClientProvider).rejectContactRequest(
            roomId: room.id,
            peerMxid: peerMXID,
            domain: _domainFromMxid(peerMXID),
            displayName: contactDisplayNameFromIdentity(
              mxid: peerMXID,
              displayName: room.getLocalizedDisplayname(),
              domain: _domainFromMxid(peerMXID),
            ),
          );
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withContactEntry(contact),
          );
      await ref.read(matrixClientProvider).oneShotSync();
      await _refreshBootstrap();
      if (mounted) {
        setState(() {
          _notice = '已拒绝好友请求';
          _noticeIsError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notice = '拒绝失败：$e';
          _noticeIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptContact(AsSyncContact pending) async {
    setState(() => _busy = true);
    try {
      final contact = await ref.read(asClientProvider).acceptContactRequest(
            roomId: pending.roomId,
            peerMxid: pending.userId,
            domain: pending.domain,
            displayName: contactDisplayNameFromIdentity(
              mxid: pending.userId,
              displayName: pending.displayName,
              domain: pending.domain,
            ),
          );
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withContactEntry(contact),
          );
      await ref.read(matrixClientProvider).oneShotSync();
      await _refreshBootstrap();
      if (mounted) {
        setState(() {
          _notice = '已接受好友请求';
          _noticeIsError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notice = '接受失败：$e';
          _noticeIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rejectContact(AsSyncContact pending) async {
    setState(() => _busy = true);
    try {
      final contact = await ref.read(asClientProvider).rejectContactRequest(
            roomId: pending.roomId,
            peerMxid: pending.userId,
            domain: pending.domain,
            displayName: contactDisplayNameFromIdentity(
              mxid: pending.userId,
              displayName: pending.displayName,
              domain: pending.domain,
            ),
          );
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withContactEntry(contact),
          );
      await ref.read(matrixClientProvider).oneShotSync();
      await _refreshBootstrap();
      if (mounted) {
        setState(() {
          _notice = '已拒绝好友请求';
          _noticeIsError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notice = '拒绝失败：$e';
          _noticeIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptGroupInviteNotice(AsSyncPendingItem invite) async {
    final roomId = invite.id.trim();
    if (roomId.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final group = await ref.read(asClientProvider).joinGroup(
            roomId: roomId,
            groupName: invite.title.trim(),
          );
      final joinedRoomId = group.roomId.trim().isEmpty ? roomId : group.roomId;
      await waitForJoinedGroupMatrixRoom(
        roomId: joinedRoomId,
        oneShotSync: ref.read(matrixClientProvider).oneShotSync,
        refreshBootstrap: _refreshBootstrap,
        hasJoinedMatrixRoom: (roomId) {
          return ref
                  .read(matrixClientProvider)
                  .getRoomById(roomId)
                  ?.membership ==
              Membership.join;
        },
      );
      if (!mounted) return;
      setState(() {
        _notice = '已加入群聊';
        _noticeIsError = false;
      });
      final route = productConversationRoute(group.productConversation);
      if (route == null) {
        setState(() {
          _notice = '群聊正在同步，请稍后重试';
          _noticeIsError = false;
        });
        return;
      }
      context.push(route);
    } catch (e) {
      if (mounted) {
        setState(() {
          _notice = '加入群聊失败：$e';
          _noticeIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendInviteFromSearch() async {
    final input = _searchCtrl.text.trim();
    if (input.isEmpty || _busy) return;

    setState(() {
      _busy = true;
      _notice = null;
      _noticeIsError = false;
    });

    try {
      final client = ref.read(matrixClientProvider);
      final target = await _resolveInviteTarget(client, input);
      if (target.mxid == client.userID) {
        throw const FormatException('不能添加自己');
      }
      await _refreshBootstrap(silent: true);
      final syncCache = ref.read(asSyncCacheProvider);
      final acceptedContact = syncCache.acceptedContactForUserId(target.mxid);
      final existingContact = syncCache.contactForUserId(target.mxid);

      if (acceptedContact != null || existingContact?.status == 'accepted') {
        setState(() {
          _notice = '${target.displayName} 已经是联系人';
          _noticeIsError = false;
        });
        return;
      }
      if (existingContact?.status == 'pending_outbound' ||
          existingContact?.status == 'pending_inbound') {
        setState(() {
          _notice = '已向 ${target.displayName} 发送过好友请求，等待对方接受';
          _noticeIsError = false;
        });
        return;
      }

      final contact = await ref.read(asClientProvider).createContactRequest(
            mxid: target.mxid,
            displayName: target.displayName,
            domain: _domainFromMxid(target.mxid),
          );
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.withContactEntry(contact),
          );
      await client.oneShotSync();
      await _refreshBootstrap(silent: true);
      if (!mounted) return;
      _searchCtrl.clear();
      final restored = contact.status.trim() == 'accepted';
      setState(() {
        _notice = restored
            ? '已恢复与 ${target.displayName} 的旧会话'
            : '已向 ${target.displayName} 发送好友请求';
        _noticeIsError = false;
      });
    } catch (e, stackTrace) {
      debugPrint(
          'send friend request from requests page failed: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _notice = _formatInviteError(e);
          _noticeIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshBootstrap({bool silent = false}) async {
    try {
      final before = ref.read(asSyncCacheProvider);
      final client = ref.read(matrixClientProvider);
      final bootstrap = await ref.read(asBootstrapRepositoryProvider).refresh();
      final rejectedOutgoing = _rejectedOutgoingRequestsAfterBootstrap(
        before: before,
        bootstrap: bootstrap,
        client: client,
      );
      ref.read(asSyncCacheProvider.notifier).update(
        (state) {
          var next = state.copyWith(bootstrap: bootstrap);
          for (final contact in rejectedOutgoing) {
            next = next.withContactEntry(contact);
          }
          return next;
        },
      );
      _markCurrentFriendRequestsRead();
    } catch (e) {
      if (!silent) rethrow;
    }
  }

  void _markCurrentFriendRequestsRead() {
    final client = ref.read(matrixClientProvider);
    final syncCache = ref.read(asSyncCacheProvider);
    final roomIds = {
      for (final room in _incomingDirectContactInvites(client)) room.id,
      for (final contact in syncCache.pendingInboundContacts) contact.roomId,
      for (final request in syncCache.bootstrap?.pending.friendRequests ??
          const <AsSyncPendingItem>[])
        request.id,
      for (final request in syncCache.bootstrap?.pending.groupInvites ??
          const <AsSyncPendingItem>[])
        request.id,
      for (final request in syncCache.bootstrap?.pending.channelNotices ??
          const <AsSyncPendingItem>[])
        request.id,
    };
    ref.read(friendRequestReadProvider.notifier).markRead(roomIds);
  }

  String? _peerMxidForRoom(Room room) {
    return productDirectPeerMxid(room) ??
        room.getState(EventTypes.RoomCreate)?.senderId;
  }

  String _domainFromMxid(String mxid) {
    return domainFromMxid(mxid);
  }

  Future<_InviteTarget> _resolveInviteTarget(
      Client client, String input) async {
    if (input.startsWith('@') && input.contains(':')) {
      return _InviteTarget(
        mxid: input,
        displayName: contactDisplayNameFromIdentity(mxid: input),
      );
    }

    final domain = _normalizeDomainInput(input);
    if (domain.isEmpty || domain.contains(' ')) {
      throw const FormatException('请输入有效的域名或 Matrix ID');
    }

    final wk = WellKnownService(httpClient: client.httpClient);
    final result = await wk.discoverOwner(domain);
    switch (result.availability) {
      case PortalAvailability.online:
        final owner = result.owner!;
        return _InviteTarget(
          mxid: owner.matrixUserId,
          displayName: contactDisplayNameFromIdentity(
            mxid: owner.matrixUserId,
            displayName: owner.displayName,
            domain: domain,
          ),
        );
      case PortalAvailability.notDeployed:
        throw const FormatException('该域名不是产品用户');
      case PortalAvailability.unreachable:
        throw const FormatException('该域名不是产品用户');
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(matrixClientProvider);
    final syncCache = ref.watch(asSyncCacheProvider);
    final pendingInboundContacts = syncCache.pendingInboundContacts;
    final pendingInboundRoomIds = pendingInboundContacts
        .map((contact) => contact.roomId.trim())
        .where((roomId) => roomId.isNotEmpty)
        .toSet();
    final invites = _incomingDirectContactInvites(client)
        .where((room) => !pendingInboundRoomIds.contains(room.id.trim()))
        .toList(growable: false);
    final inviteRoomIds = invites.map((room) => room.id.trim()).toSet();
    final pendingFriendRequestNotices = [
      for (final request in syncCache.bootstrap?.pending.friendRequests ??
          const <AsSyncPendingItem>[])
        if (request.id.trim().isNotEmpty &&
            !pendingInboundRoomIds.contains(request.id.trim()) &&
            !inviteRoomIds.contains(request.id.trim()))
          request,
    ];
    final pendingGroupInviteNotices = [
      for (final request in syncCache.bootstrap?.pending.groupInvites ??
          const <AsSyncPendingItem>[])
        if (request.id.trim().isNotEmpty) request,
    ];
    final pendingChannelNotices = [
      for (final request in syncCache.bootstrap?.pending.channelNotices ??
          const <AsSyncPendingItem>[])
        if (request.id.trim().isNotEmpty) request,
    ];
    final pendingOutboundContacts =
        _pendingOutboundContactsForDisplay(client, syncCache);
    final rejectedOutboundContacts =
        _rejectedOutboundContactsForDisplay(client, syncCache);
    final acceptedContacts = syncCache.acceptedContacts;
    final searchResults = _searchResultsForQuery(
      client: client,
      query: _query,
      invites: invites,
      pendingInboundContacts: pendingInboundContacts,
      pendingOutboundContacts: pendingOutboundContacts,
      rejectedOutboundContacts: rejectedOutboundContacts,
      acceptedContacts: acceptedContacts,
    );
    final isSearching = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: context.tk.bg,
      body: Column(
        children: [
          _RequestsHeader(title: isSearching ? '添加好友' : '新的好友'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                0,
                _requestsSearchGap,
                0,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SearchBox(
                      controller: _searchCtrl,
                      busy: _busy,
                      onSearch: _sendInviteFromSearch,
                    ),
                  ),
                  if (_notice != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _RequestNotice(
                        message: _notice!,
                        isError: _noticeIsError,
                      ),
                    ),
                  ],
                  if (isSearching) ...[
                    const SizedBox(height: _requestsSearchGap),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SearchResultList(
                        query: _query,
                        results: searchResults,
                        busy: _busy,
                        onTap: (result) {
                          _searchCtrl.text = result.mxid;
                          _searchCtrl.selection = TextSelection.collapsed(
                            offset: _searchCtrl.text.length,
                          );
                          _sendInviteFromSearch();
                        },
                      ),
                    ),
                  ] else ...[
                    const _HiddenText('待接受'),
                    _PendingSection(
                      client: client,
                      invites: invites,
                      contacts: pendingInboundContacts,
                      friendNotices: pendingFriendRequestNotices,
                      groupInvites: pendingGroupInviteNotices,
                      channelNotices: pendingChannelNotices,
                      busy: _busy,
                      onOpenProfile: _openAddContactProfile,
                      onAccept: _accept,
                      onReject: _reject,
                      onAcceptContact: _acceptContact,
                      onRejectContact: _rejectContact,
                      onAcceptGroupInvite: _acceptGroupInviteNotice,
                    ),
                    if (pendingOutboundContacts.isNotEmpty) ...[
                      const _HiddenText('等待对方接受'),
                      _OutgoingSection(
                        client: client,
                        contacts: pendingOutboundContacts,
                        onOpenProfile: _openAddContactProfile,
                      ),
                    ],
                    if (rejectedOutboundContacts.isNotEmpty) ...[
                      const _HiddenText('已拒绝'),
                      _OutgoingSection(
                        client: client,
                        contacts: rejectedOutboundContacts,
                        onOpenProfile: _openAddContactProfile,
                      ),
                    ],
                    const _HiddenText('已添加'),
                    if (acceptedContacts.isNotEmpty)
                      _AcceptedSection(
                        client: client,
                        contacts: acceptedContacts,
                        onOpenProfile: _openContactProfile,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAddContactProfile(String mxid, String displayName) {
    final id = mxid.trim();
    if (id.isEmpty) return;
    final query = displayName.trim().isEmpty
        ? ''
        : '?name=${Uri.encodeQueryComponent(displayName.trim())}';
    context.push('/add-contact/detail/${Uri.encodeComponent(id)}$query');
  }

  void _openContactProfile(String mxid) {
    final id = mxid.trim();
    if (id.isEmpty) return;
    context.push('/contact/${Uri.encodeComponent(id)}');
  }
}

List<Room> _incomingDirectContactInvites(Client client) {
  final agentMxid = portalAgentMxidForClient(client);
  final knownPendingRoomIds = <String>{};
  return client.rooms.where((room) {
    if (!isIncomingDirectContactInvite(room, agentMxid: agentMxid)) {
      return false;
    }
    return knownPendingRoomIds.add(room.id.trim());
  }).toList(growable: false);
}

class _RequestsHeader extends StatelessWidget {
  const _RequestsHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: _requestsToolbarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _HeaderGlassBackButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
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

class _HeaderGlassBackButton extends StatelessWidget {
  const _HeaderGlassBackButton({required this.onTap});

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
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(Symbols.arrow_back, size: 24, color: t.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _HiddenText extends StatelessWidget {
  const _HiddenText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox.shrink(
      child: Opacity(
        opacity: 0,
        child: Text(text),
      ),
    );
  }
}

List<ContactEntry> _rejectedOutgoingRequestsAfterBootstrap({
  required AsSyncCacheState before,
  required AsSyncBootstrap bootstrap,
  required Client client,
}) {
  final bootstrapStatusesByPeerId = <String, String>{};
  final candidates = <String, AsSyncContact>{};

  void addCandidate(AsSyncContact contact) {
    final roomId = contact.roomId.trim();
    final peerMxid = contact.userId.trim();
    if (roomId.isEmpty || peerMxid.isEmpty) return;
    candidates.putIfAbsent(peerMxid, () => contact);
  }

  for (final contact in bootstrap.contacts) {
    final peerMxid = contact.userId.trim();
    if (peerMxid.isEmpty) continue;
    bootstrapStatusesByPeerId[peerMxid] = contact.status.trim();
    if (contact.status.trim() == 'pending_outbound') {
      addCandidate(contact);
    }
  }

  final rejected = <ContactEntry>[];

  for (final contact in before.pendingOutboundContacts) {
    addCandidate(contact);
  }

  for (final contact in candidates.values) {
    final roomId = contact.roomId.trim();
    final peerMxid = contact.userId.trim();
    if (roomId.isEmpty || peerMxid.isEmpty) continue;
    final bootstrapStatus = bootstrapStatusesByPeerId[peerMxid];
    if (bootstrapStatus != null &&
        bootstrapStatus.isNotEmpty &&
        bootstrapStatus != 'pending_outbound' &&
        bootstrapStatus != 'rejected_outbound') {
      continue;
    }
    if (!_peerRejectedRequest(client, roomId, peerMxid)) continue;
    rejected.add(
      ContactEntry(
        peerMxid: peerMxid,
        displayName: contact.displayName,
        domain: contact.domain,
        roomId: roomId,
        status: 'rejected_outbound',
      ),
    );
  }
  return rejected;
}

List<AsSyncContact> _pendingOutboundContactsForDisplay(
  Client client,
  AsSyncCacheState syncCache,
) {
  return syncCache.pendingOutboundContacts.where((contact) {
    return !_peerRejectedRequest(
      client,
      contact.roomId.trim(),
      contact.userId.trim(),
    );
  }).toList(growable: false);
}

List<AsSyncContact> _rejectedOutboundContactsForDisplay(
  Client client,
  AsSyncCacheState syncCache,
) {
  final contactsByPeer = <String, AsSyncContact>{};
  for (final contact in syncCache.rejectedOutboundContacts) {
    final peerMxid = contact.userId.trim();
    if (peerMxid.isNotEmpty) {
      contactsByPeer[peerMxid] = contact;
    }
  }
  for (final contact in syncCache.pendingOutboundContacts) {
    final roomId = contact.roomId.trim();
    final peerMxid = contact.userId.trim();
    if (roomId.isEmpty || peerMxid.isEmpty) continue;
    if (!_peerRejectedRequest(client, roomId, peerMxid)) continue;
    contactsByPeer[peerMxid] = AsSyncContact(
      userId: contact.userId,
      displayName: contact.displayName,
      avatarUrl: contact.avatarUrl,
      roomId: contact.roomId,
      domain: contact.domain,
      status: 'rejected_outbound',
      visibleAfterTs: contact.visibleAfterTs,
      deletedEventIds: contact.deletedEventIds,
    );
  }
  return List.unmodifiable(contactsByPeer.values);
}

bool _peerRejectedRequest(Client client, String roomId, String peerMxid) {
  final room = client.getRoomById(roomId);
  final event = room?.getState(EventTypes.RoomMember, peerMxid);
  final membership = event?.content['membership']?.toString().trim();
  return membership == 'leave' || membership == 'ban';
}

class _InviteTarget {
  const _InviteTarget({required this.mxid, required this.displayName});
  final String mxid;
  final String displayName;
}

String _normalizeDomainInput(String input) {
  final trimmed = input.trim().replaceAll(RegExp(r'^https?://'), '');
  return trimmed.split('/').first.replaceAll(RegExp(r':$'), '').trim();
}

String _formatInviteError(Object error) {
  final msg = error.toString().replaceFirst('FormatException: ', '');
  return msg.startsWith('Exception: ') ? msg.substring(11) : msg;
}

List<_FriendSearchResult> _searchResultsForQuery({
  required Client client,
  required String query,
  required List<Room> invites,
  required List<AsSyncContact> pendingInboundContacts,
  required List<AsSyncContact> pendingOutboundContacts,
  required List<AsSyncContact> rejectedOutboundContacts,
  required List<AsSyncContact> acceptedContacts,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];

  final results = <_FriendSearchResult>[];
  final seen = <String>{};

  void add({
    required String mxid,
    required String displayName,
    required String seed,
    String? avatarUrl,
  }) {
    final cleanMxid = mxid.trim();
    final cleanName = displayName.trim();
    final cleanSeed = seed.trim().isEmpty ? cleanName : seed.trim();
    if (cleanName.isEmpty || cleanSeed.isEmpty) return;
    final haystack = '$cleanName $cleanMxid'.toLowerCase();
    if (!haystack.contains(needle)) return;
    final key = cleanMxid.isEmpty ? cleanSeed : cleanMxid;
    if (!seen.add(key)) return;
    results.add(
      _FriendSearchResult(
        mxid: cleanMxid,
        displayName: cleanName,
        seed: cleanSeed,
        avatarUrl: avatarUrl,
      ),
    );
  }

  for (final contact in [
    ...pendingInboundContacts,
    ...pendingOutboundContacts,
    ...rejectedOutboundContacts,
    ...acceptedContacts,
  ]) {
    final mxid = contact.userId.trim();
    add(
      mxid: mxid,
      displayName: contactDisplayNameFromIdentity(
        mxid: mxid,
        displayName: contact.displayName,
        domain: contact.domain,
      ),
      seed: mxid,
      avatarUrl: _avatarUrlForContact(client, contact),
    );
  }

  for (final room in invites) {
    final mxid = productDirectPeerMxid(room) ??
        room.getState(EventTypes.RoomCreate)?.senderId ??
        '';
    final profileName = productDirectPeerDisplayName(room);
    add(
      mxid: mxid,
      displayName: contactDisplayNameFromIdentity(
        mxid: mxid,
        displayName: profileName ?? room.getLocalizedDisplayname(),
        domain: productDirectPeerDomain(room) ?? domainFromMxid(mxid),
        fallback: room.getLocalizedDisplayname(),
      ),
      seed: mxid,
      avatarUrl: _avatarUrlForRoomPeer(room, mxid),
    );
  }

  return results.take(8).toList(growable: false);
}

class _FriendSearchResult {
  const _FriendSearchResult({
    required this.mxid,
    required this.displayName,
    required this.seed,
    this.avatarUrl,
  });

  final String mxid;
  final String displayName;
  final String seed;
  final String? avatarUrl;
}

String? _avatarUrlForContact(Client client, AsSyncContact contact) {
  return _avatarUrlForRoomPeer(
        client.getRoomById(contact.roomId.trim()),
        contact.userId,
      ) ??
      avatarHttpUrl(client, contact.avatarUrl);
}

String? _avatarUrlForRoomPeer(Room? room, String mxid) {
  final peerId = mxid.trim();
  if (room == null || peerId.isEmpty) return null;
  final nativeAvatarUrl = productDirectPeerMxid(room) == peerId
      ? productDirectPeerAvatarUrl(room)
      : null;
  final resolvedNativeAvatar = avatarHttpUrl(room.client, nativeAvatarUrl);
  if (resolvedNativeAvatar != null) return resolvedNativeAvatar;
  final member = room.unsafeGetUserFromMemoryOrFallback(peerId);
  return matrixContentHttpUrl(room.client, member.avatarUrl);
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.busy,
    required this.onSearch,
  });
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return M3SearchField(
      controller: controller,
      enabled: !busy,
      keyboardType: TextInputType.url,
      hint: '搜索',
      onSubmitted: (_) => onSearch(),
    );
  }
}

class _SearchResultList extends StatelessWidget {
  const _SearchResultList({
    required this.query,
    required this.results,
    required this.busy,
    required this.onTap,
  });

  final String query;
  final List<_FriendSearchResult> results;
  final bool busy;
  final ValueChanged<_FriendSearchResult> onTap;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final result in results)
          _SearchResultRow(
            result: result,
            query: query,
            onTap: busy ? null : () => onTap(result),
          ),
      ],
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.result,
    required this.query,
    required this.onTap,
  });

  final _FriendSearchResult result;
  final String query;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          key: const ValueKey('requests_search_result_row'),
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: t.border.withValues(alpha: 0.45),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                PortalAvatar(
                  seed: result.seed,
                  imageUrl: result.avatarUrl,
                  size: 28,
                  shape: AvatarShape.squircle,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: _highlightSearchNameSpan(
                      context,
                      result.displayName,
                      query,
                    ),
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

TextSpan _highlightSearchNameSpan(
  BuildContext context,
  String name,
  String query,
) {
  final t = context.tk;
  final base = AppTheme.sans(
    size: 16,
    weight: FontWeight.w500,
    color: t.text,
  ).copyWith(letterSpacing: 0);
  final accent = base.copyWith(color: t.accent);
  final needle = query.trim();
  final index =
      needle.isEmpty ? -1 : name.toLowerCase().indexOf(needle.toLowerCase());
  if (index < 0) return TextSpan(text: name, style: base);
  return TextSpan(
    children: [
      if (index > 0) TextSpan(text: name.substring(0, index), style: base),
      TextSpan(
        text: name.substring(index, index + needle.length),
        style: accent,
      ),
      if (index + needle.length < name.length)
        TextSpan(
          text: name.substring(index + needle.length),
          style: base,
        ),
    ],
  );
}

class _RequestNotice extends StatelessWidget {
  const _RequestNotice({required this.message, required this.isError});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final color = isError ? t.danger : t.accentCool;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Symbols.error : Symbols.check_circle,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTheme.sans(size: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingSection extends StatelessWidget {
  const _PendingSection({
    required this.client,
    required this.invites,
    required this.contacts,
    required this.friendNotices,
    required this.groupInvites,
    required this.channelNotices,
    required this.busy,
    required this.onOpenProfile,
    required this.onAccept,
    required this.onReject,
    required this.onAcceptContact,
    required this.onRejectContact,
    required this.onAcceptGroupInvite,
  });
  final Client client;
  final List<Room> invites;
  final List<AsSyncContact> contacts;
  final List<AsSyncPendingItem> friendNotices;
  final List<AsSyncPendingItem> groupInvites;
  final List<AsSyncPendingItem> channelNotices;
  final bool busy;
  final void Function(String mxid, String displayName) onOpenProfile;
  final void Function(Room) onAccept;
  final void Function(Room) onReject;
  final void Function(AsSyncContact) onAcceptContact;
  final void Function(AsSyncContact) onRejectContact;
  final void Function(AsSyncPendingItem) onAcceptGroupInvite;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;

    final rows = <Widget>[];
    for (var i = 0; i < contacts.length; i++) {
      final contact = contacts[i];
      final mxid = contact.userId.trim();
      final name = contactDisplayNameFromIdentity(
        mxid: mxid,
        displayName: contact.displayName,
        domain: contact.domain,
      );
      rows.add(
        _PendingRow(
          name: name,
          message: mxid.isEmpty ? '请求加为好友' : mxid,
          seed: mxid.isEmpty ? name : mxid,
          imageUrl: _avatarUrlForContact(client, contact),
          onTap: mxid.isEmpty ? null : () => onOpenProfile(mxid, name),
          onAccept: busy ? null : () => onAcceptContact(contact),
          onReject: busy ? null : () => onRejectContact(contact),
        ),
      );
    }
    for (var i = 0; i < invites.length; i++) {
      final room = invites[i];
      final inviterId = productDirectPeerMxid(room) ??
          room.getState(EventTypes.RoomCreate)?.senderId ??
          '';
      final profileName = productDirectPeerDisplayName(room);
      final name = contactDisplayNameFromIdentity(
        mxid: inviterId,
        displayName: profileName ?? room.getLocalizedDisplayname(),
        domain: productDirectPeerDomain(room) ?? domainFromMxid(inviterId),
        fallback: room.getLocalizedDisplayname(),
      );
      rows.add(
        _PendingRow(
          name: name,
          message: inviterId.isEmpty ? '请求加为好友' : inviterId,
          seed: inviterId.isEmpty ? name : inviterId,
          imageUrl: _avatarUrlForRoomPeer(room, inviterId),
          onTap:
              inviterId.isEmpty ? null : () => onOpenProfile(inviterId, name),
          onAccept: busy ? null : () => onAccept(room),
          onReject: busy ? null : () => onReject(room),
        ),
      );
    }
    for (final notice in friendNotices) {
      final title = notice.title.trim();
      final id = notice.id.trim();
      final name = title.isEmpty ? '好友申请' : title;
      rows.add(
        _PendingRow(
          name: name,
          message: id.isEmpty ? '好友申请通知' : id,
          seed: id.isEmpty ? name : id,
          imageUrl: null,
          onTap: null,
          onAccept: null,
          onReject: null,
        ),
      );
    }
    for (final notice in groupInvites) {
      final title = notice.title.trim();
      final id = notice.id.trim();
      final name = title.isEmpty ? '群聊邀请' : title;
      rows.add(
        _PendingRow(
          name: name,
          message: id.isEmpty ? '邀请加入群聊' : '邀请加入群聊 · $id',
          seed: id.isEmpty ? name : id,
          imageUrl: null,
          onTap: null,
          onAccept: busy ? null : () => onAcceptGroupInvite(notice),
          onReject: null,
        ),
      );
    }
    for (final notice in channelNotices) {
      final title = notice.title.trim();
      final id = notice.id.trim();
      final name = title.isEmpty ? '频道通知' : title;
      rows.add(
        _PendingRow(
          name: name,
          message: id.isEmpty ? '频道通知' : id,
          seed: id.isEmpty ? name : id,
          imageUrl: null,
          onTap: null,
          onAccept: null,
          onReject: null,
        ),
      );
    }

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child:
              Text('暂无好友请求', style: AppTheme.sans(size: 14, color: t.textMute)),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.name,
    required this.message,
    required this.seed,
    this.imageUrl,
    required this.onTap,
    required this.onAccept,
    required this.onReject,
  });
  final String name;
  final String message;
  final String seed;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return _FriendRequestRowShell(
      seed: seed,
      imageUrl: imageUrl,
      name: name,
      message: message,
      onTap: onTap,
      trailing: _ViewRequestButton(
        enabled: onAccept != null || onReject != null,
        onTap: () => _showRequestActions(context),
      ),
    );
  }

  void _showRequestActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.tk.surface,
      builder: (sheetContext) => _RequestActionSheet(
        name: name,
        message: message,
        onAccept: onAccept == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                onAccept!();
              },
        onReject: onReject == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                onReject!();
              },
      ),
    );
  }
}

class _ViewRequestButton extends StatelessWidget {
  const _ViewRequestButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: enabled ? t.text : t.textMute.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            '查看',
            style: AppTheme.sans(
              size: 12,
              color: t.onAccent,
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestActionSheet extends StatelessWidget {
  const _RequestActionSheet({
    required this.name,
    required this.message,
    required this.onAccept,
    required this.onReject,
  });

  final String name;
  final String message;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name,
              textAlign: TextAlign.center,
              style: AppTheme.sans(
                size: 17,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 13, color: t.textMute),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _RejectButton(onTap: onReject)),
                const SizedBox(width: 12),
                Expanded(child: _AcceptButton(onTap: onAccept)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectButton extends StatelessWidget {
  const _RejectButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surfaceHover,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            '拒绝',
            textAlign: TextAlign.center,
            style: AppTheme.sans(
              size: 15,
              color: t.textMute,
            ),
          ),
        ),
      ),
    );
  }
}

class _AcceptButton extends StatelessWidget {
  const _AcceptButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.text,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            '接受',
            textAlign: TextAlign.center,
            style: AppTheme.sans(
              size: 15,
              color: t.onAccent,
            ),
          ),
        ),
      ),
    );
  }
}

class _OutgoingSection extends StatelessWidget {
  const _OutgoingSection({
    required this.client,
    required this.contacts,
    required this.onOpenProfile,
  });
  final Client client;
  final List<AsSyncContact> contacts;
  final void Function(String mxid, String displayName) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final contact in contacts)
          _OutgoingRow(
            client: client,
            contact: contact,
            onOpenProfile: onOpenProfile,
          ),
      ],
    );
  }
}

class _OutgoingRow extends StatelessWidget {
  const _OutgoingRow({
    required this.client,
    required this.contact,
    required this.onOpenProfile,
  });
  final Client client;
  final AsSyncContact contact;
  final void Function(String mxid, String displayName) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final mxid = contact.userId.trim();
    final isRejected = contact.status.trim() == 'rejected_outbound';
    final name = contactDisplayNameFromIdentity(
      mxid: mxid,
      displayName: contact.displayName,
      domain: contact.domain,
    );
    return _FriendRequestRowShell(
      seed: mxid.isEmpty ? name : mxid,
      imageUrl: _avatarUrlForContact(client, contact),
      name: name,
      message: isRejected ? '我:请求添加你为朋友' : '请求添加你为朋友',
      onTap: mxid.isEmpty ? null : () => onOpenProfile(mxid, name),
      trailing: _RequestStatusText(
        text: isRejected ? '已过期' : '等待接受',
        hiddenText: isRejected ? '对方已拒绝' : null,
      ),
    );
  }
}

class _AcceptedSection extends StatelessWidget {
  const _AcceptedSection({
    required this.client,
    required this.contacts,
    required this.onOpenProfile,
  });
  final Client client;
  final List<AsSyncContact> contacts;
  final ValueChanged<String> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (contacts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '暂无已添加联系人',
            style: AppTheme.sans(size: 14, color: t.textMute),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final contact in contacts)
          _AcceptedRow(
            client: client,
            contact: contact,
            onOpenProfile: onOpenProfile,
          ),
      ],
    );
  }
}

class _AcceptedRow extends StatelessWidget {
  const _AcceptedRow({
    required this.client,
    required this.contact,
    required this.onOpenProfile,
  });
  final Client client;
  final AsSyncContact contact;
  final ValueChanged<String> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final mxid = contact.userId.trim();
    final name = contactDisplayNameFromIdentity(
      mxid: mxid,
      displayName: contact.displayName,
      domain: contact.domain,
    );
    return _FriendRequestRowShell(
      seed: mxid.isEmpty ? name : mxid,
      imageUrl: _avatarUrlForContact(client, contact),
      name: name,
      message: '请求添加你为朋友',
      onTap: mxid.isEmpty ? null : () => onOpenProfile(mxid),
      trailing: const _RequestStatusText(text: '已添加'),
    );
  }
}

class _RequestStatusText extends StatelessWidget {
  const _RequestStatusText({required this.text, this.hiddenText});

  final String text;
  final String? hiddenText;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final hidden = hiddenText;
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          style: AppTheme.sans(
            size: 10,
            color: t.textMute,
          ),
        ),
        if (hidden != null) _HiddenText(hidden),
      ],
    );
  }
}

class _FriendRequestRowShell extends StatelessWidget {
  const _FriendRequestRowShell({
    required this.seed,
    this.imageUrl,
    required this.name,
    required this.message,
    required this.trailing,
    this.onTap,
  });

  final String seed;
  final String? imageUrl;
  final String name;
  final String message;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final profileArea = Row(
      children: [
        PortalAvatar(
          seed: seed,
          imageUrl: imageUrl,
          size: 28,
          shape: AvatarShape.squircle,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: t.surfaceHigh,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 14,
                    weight: FontWeight.w500,
                    color: t.text,
                  ),
                ),
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 10, color: t.textMute),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    final tappableProfileArea = onTap == null
        ? profileArea
        : Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, child: profileArea),
          );
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(child: tappableProfileArea),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

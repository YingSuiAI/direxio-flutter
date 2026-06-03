import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../providers/auth_provider.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/friend_request_read_provider.dart';
import '../widgets/glass_list_tile.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/m3/glass_header.dart';
import '../utils/contact_identity_label.dart';
import '../utils/direct_contact_status.dart';
import '../../data/as_client.dart';
import '../../data/well_known_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    final client = ref.read(matrixClientProvider);
    _syncSub = client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
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
      await _refreshBootstrap();
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
      await _refreshBootstrap();
      if (!mounted) return;
      _searchCtrl.clear();
      final restored = contact.status.trim() == 'accepted';
      setState(() {
        _notice = restored
            ? '已恢复与 ${target.displayName} 的旧会话'
            : '已向 ${target.displayName} 发送好友请求';
        _noticeIsError = false;
      });
    } catch (e) {
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
    final roomIds = syncCache.bootstrap == null
        ? client.rooms
            .where((room) => isIncomingDirectContactInvite(
                  room,
                  agentMxid: portalAgentMxidForClient(client),
                ))
            .map((room) => room.id)
        : syncCache.pendingInboundContacts.map((contact) => contact.roomId);
    ref.read(friendRequestReadProvider.notifier).markRead(roomIds);
  }

  String? _peerMxidForRoom(Room room) {
    return productDirectPeerMxid(room) ??
        room.getState(EventTypes.RoomCreate)?.senderId;
  }

  String _domainFromMxid(String mxid) {
    final idx = mxid.lastIndexOf(':');
    if (idx < 0 || idx == mxid.length - 1) return '';
    return mxid.substring(idx + 1);
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
    final agentMxid = portalAgentMxidForClient(client);
    final syncCache = ref.watch(asSyncCacheProvider);
    final bootstrapLoaded = syncCache.bootstrap != null;
    final invites = bootstrapLoaded
        ? <Room>[]
        : client.rooms
            .where(
                (r) => isIncomingDirectContactInvite(r, agentMxid: agentMxid))
            .toList();
    final pendingInboundContacts = syncCache.pendingInboundContacts;
    final pendingOutboundContacts = syncCache.pendingOutboundContacts;
    final rejectedOutboundContacts = syncCache.rejectedOutboundContacts;
    final acceptedContacts = syncCache.acceptedContacts;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(title: '新朋友'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 添加朋友搜索框
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _SearchBox(
                      controller: _searchCtrl,
                      busy: _busy,
                      onSearch: _sendInviteFromSearch,
                    ),
                  ),
                  if (_notice != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _RequestNotice(
                        message: _notice!,
                        isError: _noticeIsError,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 待接受请求
                  const _SectionLabel(text: '待接受'),
                  const SizedBox(height: 8),
                  _PendingSection(
                    invites: invites,
                    contacts: pendingInboundContacts,
                    busy: _busy,
                    onAccept: _accept,
                    onReject: _reject,
                    onAcceptContact: _acceptContact,
                    onRejectContact: _rejectContact,
                  ),
                  if (pendingOutboundContacts.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _SectionLabel(text: '等待对方接受'),
                    const SizedBox(height: 8),
                    _OutgoingSection(
                      contacts: pendingOutboundContacts,
                    ),
                  ],
                  if (rejectedOutboundContacts.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _SectionLabel(text: '已拒绝'),
                    const SizedBox(height: 8),
                    _OutgoingSection(
                      contacts: rejectedOutboundContacts,
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 已添加
                  const _SectionLabel(text: '已添加'),
                  const SizedBox(height: 8),
                  _AcceptedSection(
                    contacts: acceptedContacts,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<ContactEntry> _rejectedOutgoingRequestsAfterBootstrap({
  required AsSyncCacheState before,
  required AsSyncBootstrap bootstrap,
  required Client client,
}) {
  final bootstrapRoomIds = bootstrap.contacts
      .map((contact) => contact.roomId.trim())
      .where((roomId) => roomId.isNotEmpty)
      .toSet();
  final bootstrapPeerIds = bootstrap.contacts
      .map((contact) => contact.userId.trim())
      .where((userId) => userId.isNotEmpty)
      .toSet();
  final rejected = <ContactEntry>[];

  for (final contact in before.pendingOutboundContacts) {
    final roomId = contact.roomId.trim();
    final peerMxid = contact.userId.trim();
    if (roomId.isEmpty || peerMxid.isEmpty) continue;
    if (bootstrapRoomIds.contains(roomId) ||
        bootstrapPeerIds.contains(peerMxid)) {
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
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Symbols.search, size: 20, color: t.textMute),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTheme.sans(size: 15, color: t.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: t.accent, width: 1.5),
                ),
                hintText: '域名 / Matrix ID / Node ID',
                hintStyle: AppTheme.sans(size: 15, color: t.textMute),
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onSubmitted: (_) => onSearch(),
            ),
          ),
          InkWell(
            key: const ValueKey('new_friends_search_send_button'),
            onTap: busy ? null : onSearch,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.accent,
                      ),
                    )
                  : Icon(Symbols.send, size: 18, color: t.accent),
            ),
          ),
        ],
      ),
    );
  }
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        text,
        style: AppTheme.sans(
          size: 13,
          weight: FontWeight.w500,
          color: t.textMute,
        ),
      ),
    );
  }
}

class _PendingSection extends StatelessWidget {
  const _PendingSection({
    required this.invites,
    required this.contacts,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    required this.onAcceptContact,
    required this.onRejectContact,
  });
  final List<Room> invites;
  final List<AsSyncContact> contacts;
  final bool busy;
  final void Function(Room) onAccept;
  final void Function(Room) onReject;
  final void Function(AsSyncContact) onAcceptContact;
  final void Function(AsSyncContact) onRejectContact;

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
          onAccept: busy ? null : () => onAcceptContact(contact),
          onReject: busy ? null : () => onRejectContact(contact),
        ),
      );
    }
    for (var i = 0; i < invites.length; i++) {
      final room = invites[i];
      final inviterId = room.directChatMatrixID ??
          room.getState(EventTypes.RoomCreate)?.senderId ??
          '';
      final name = contactDisplayNameFromIdentity(
        mxid: inviterId,
        displayName: room.getLocalizedDisplayname(),
        domain: domainFromMxid(inviterId),
        fallback: room.getLocalizedDisplayname(),
      );
      rows.add(
        _PendingRow(
          name: name,
          message: inviterId.isEmpty ? '请求加为好友' : inviterId,
          seed: inviterId.isEmpty ? name : inviterId,
          onAccept: busy ? null : () => onAccept(room),
          onReject: busy ? null : () => onReject(room),
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
    required this.onAccept,
    required this.onReject,
  });
  final String name;
  final String message;
  final String seed;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GlassListPanel(
      contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          PortalAvatar(seed: seed, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 20,
                    weight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(size: 15, color: t.textMute),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RejectButton(onTap: onReject),
          const SizedBox(width: 8),
          _AcceptButton(onTap: onAccept),
        ],
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
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            '拒绝',
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w500,
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
      color: t.accent,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            '接受',
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w500,
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
    required this.contacts,
  });
  final List<AsSyncContact> contacts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final contact in contacts) _OutgoingRow(contact: contact),
      ],
    );
  }
}

class _OutgoingRow extends StatelessWidget {
  const _OutgoingRow({required this.contact});
  final AsSyncContact contact;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final mxid = contact.userId.trim();
    final isRejected = contact.status.trim() == 'rejected_outbound';
    final name = contactDisplayNameFromIdentity(
      mxid: mxid,
      displayName: contact.displayName,
      domain: contact.domain,
    );
    return GlassListPanel(
      contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          PortalAvatar(seed: mxid.isEmpty ? name : mxid, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 20,
                    weight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                if (mxid.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    mxid,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(size: 15, color: t.textMute),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isRejected ? '对方已拒绝' : '等待接受',
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w500,
              color: isRejected ? t.danger : t.textMute,
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptedSection extends StatelessWidget {
  const _AcceptedSection({
    required this.contacts,
  });
  final List<AsSyncContact> contacts;

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
        for (final contact in contacts) _AcceptedRow(contact: contact),
      ],
    );
  }
}

class _AcceptedRow extends StatelessWidget {
  const _AcceptedRow({required this.contact});
  final AsSyncContact contact;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final mxid = contact.userId.trim();
    final name = contactDisplayNameFromIdentity(
      mxid: mxid,
      displayName: contact.displayName,
      domain: contact.domain,
    );
    return GlassListPanel(
      contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          PortalAvatar(seed: mxid.isEmpty ? name : mxid, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 20,
                    weight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                if (mxid.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    mxid,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(size: 15, color: t.textMute),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '已添加',
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w500,
              color: t.textMute,
            ),
          ),
        ],
      ),
    );
  }
}

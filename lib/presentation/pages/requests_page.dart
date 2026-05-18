import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import '../providers/auth_provider.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/m3/glass_header.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

class RequestsPage extends ConsumerStatefulWidget {
  const RequestsPage({super.key});

  @override
  ConsumerState<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends ConsumerState<RequestsPage> {
  StreamSubscription<SyncUpdate>? _syncSub;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final client = ref.read(matrixClientProvider);
    _syncSub = client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _accept(Room room) async {
    setState(() => _busy = true);
    try {
      await room.join();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(Room room) async {
    setState(() => _busy = true);
    try {
      await room.leave();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final client = ref.watch(matrixClientProvider);
    final invites = client.rooms
        .where((r) => r.membership == Membership.invite)
        .toList();

    return Scaffold(
      body: Column(
        children: [
          GlassHeader.detail(title: '好友申请'),
          Expanded(
            child: invites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Symbols.notifications_off,
                      size: 32, color: t.textMute),
                  const SizedBox(height: 12),
                  Text('暂无待处理申请',
                      style: AppTheme.sans(
                          size: 14,
                          color: t.text,
                          weight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('好友/群邀请会出现在这里',
                      style: AppTheme.sans(size: 12, color: t.textMute)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: invites.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final room = invites[i];
                final isDm = room.isDirectChat;
                final inviterId = room.directChatMatrixID ??
                    room
                        .getState(EventTypes.RoomCreate)
                        ?.senderId ??
                    '';
                final domain = inviterId.contains(':')
                    ? inviterId.split(':').last
                    : inviterId;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    children: [
                      PortalAvatar(seed: domain, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              room.getLocalizedDisplayname(),
                              style: AppTheme.sans(
                                  size: 14,
                                  weight: FontWeight.w600,
                                  color: t.text),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isDm ? '好友申请' : '群邀请',
                              style:
                                  AppTheme.sans(size: 11, color: t.textMute),
                            ),
                            if (inviterId.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                inviterId,
                                style: AppTheme.mono(
                                    size: 11, color: t.accentCool),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _IconBtn(
                        icon: Symbols.close,
                        color: t.danger,
                        onTap: _busy ? null : () => _reject(room),
                      ),
                      const SizedBox(width: 6),
                      _IconBtn(
                        icon: Symbols.check,
                        color: t.accent,
                        onTap: _busy ? null : () => _accept(room),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.color, this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';
import '../providers/auth_provider.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/m3/glass_header.dart';
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
    _searchCtrl.dispose();
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

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final client = ref.watch(matrixClientProvider);
    final invites = client.rooms
        .where((r) => r.membership == Membership.invite)
        .toList();

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          GlassHeader.detail(title: '新朋友'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 添加朋友搜索框
                  _SearchBox(controller: _searchCtrl, onSearch: () {}),
                  const SizedBox(height: 20),

                  // 待接受请求
                  _SectionLabel(text: '待接受'),
                  const SizedBox(height: 8),
                  _PendingSection(
                    invites: invites,
                    busy: _busy,
                    onAccept: _accept,
                  ),
                  const SizedBox(height: 20),

                  // 已添加
                  _SectionLabel(text: '已添加'),
                  const SizedBox(height: 8),
                  _AcceptedSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onSearch});
  final TextEditingController controller;
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
                hintText: '手机号 / 用户名 / Node ID',
                hintStyle: AppTheme.sans(size: 15, color: t.textMute),
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onSubmitted: (_) => onSearch(),
            ),
          ),
          InkWell(
            onTap: onSearch,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Symbols.send, size: 18, color: t.accent),
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
      padding: const EdgeInsets.only(left: 4),
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
    required this.busy,
    required this.onAccept,
  });
  final List<Room> invites;
  final bool busy;
  final void Function(Room) onAccept;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;

    // 真实 invites 优先；如无,展示设计稿 mock 内容。
    final List<Widget> rows;
    if (invites.isNotEmpty) {
      rows = [];
      for (var i = 0; i < invites.length; i++) {
        if (i > 0) rows.add(_RowDivider());
        final room = invites[i];
        final inviterId =
            room.directChatMatrixID ??
            room.getState(EventTypes.RoomCreate)?.senderId ??
            '';
        rows.add(
          _PendingRow(
            name: room.getLocalizedDisplayname(),
            message: inviterId.isEmpty ? '请求加为好友' : inviterId,
            seed: inviterId.isEmpty
                ? room.getLocalizedDisplayname()
                : inviterId,
            onAccept: busy ? null : () => onAccept(room),
          ),
        );
      }
    } else {
      rows = [];
    }

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('暂无好友请求', style: AppTheme.sans(size: 14, color: t.textMute)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.name,
    required this.message,
    required this.seed,
    required this.onAccept,
  });
  final String name;
  final String message;
  final String seed;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.all(16),
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
          _AcceptButton(onTap: onAccept),
        ],
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

class _AcceptedSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            PortalAvatar(seed: 'Alice', size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Alice Chen',
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
                    '3 天前接受了你的请求',
                    style: AppTheme.sans(size: 15, color: t.textMute),
                  ),
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
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(height: 1, color: t.border.withValues(alpha: 0.2));
  }
}

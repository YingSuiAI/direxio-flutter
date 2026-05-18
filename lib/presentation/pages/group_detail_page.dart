/// 群组详情 —— 对应 s-group-info。M3 风格。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';
import '../widgets/portal_avatar.dart';

class GroupDetailPage extends ConsumerWidget {
  const GroupDetailPage({super.key, required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final client = ref.read(matrixClientProvider);
    final room = client.getRoomById(roomId);
    if (room == null) {
      return const Scaffold(body: Center(child: Text('群组不存在')));
    }

    final members = room.getParticipants();
    final topic = room.topic;

    return Scaffold(
      body: Column(
        children: [
          GlassHeader.detail(title: room.getLocalizedDisplayname()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (topic != null && topic.isNotEmpty) ...[
                  M3Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('群公告',
                            style: AppTheme.sans(
                                size: 13,
                                weight: FontWeight.w600,
                                color: t.textMute)),
                        const SizedBox(height: 6),
                        Text(topic,
                            style: AppTheme.sans(
                                size: 15, color: t.text)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('成员 (${members.length})',
                      style: AppTheme.sans(
                          size: 13,
                          weight: FontWeight.w600,
                          color: t.textMute)),
                ),
                M3Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < members.length; i++) ...[
                        _MemberRow(
                          name: members[i].displayName ?? members[i].id,
                          mxid: members[i].id,
                        ),
                        if (i != members.length - 1)
                          Divider(
                              height: 1,
                              color: t.border,
                              indent: 60),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                M3Card(
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () async {
                      await room.leave();
                      if (context.mounted) {
                        Navigator.of(context).maybePop();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Symbols.logout,
                              size: 22, color: t.danger),
                          const SizedBox(width: 14),
                          Text('退出群组',
                              style: AppTheme.sans(
                                  size: 15, color: t.danger)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.name, required this.mxid});
  final String name;
  final String mxid;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final domain = mxid.contains(':') ? mxid.split(':').last : mxid;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          PortalAvatar(seed: name, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(size: 15, color: t.text)),
                Text(domain,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTheme.sans(size: 12, color: t.textMute)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

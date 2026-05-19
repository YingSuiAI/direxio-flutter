/// 群「群信息」—— 对齐原型 s-group-info。M3 风格，mock 数据。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../mock/mock_data.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/info_rows.dart';

class GroupInfoPage extends StatefulWidget {
  const GroupInfoPage({super.key, required this.roomId});
  final String roomId;

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  bool _mute = false;
  bool _pinned = false;
  bool _showMemberNick = true;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final conv = MockData.byId(widget.roomId);
    final members = conv?.members ?? const <String>[];

    return Scaffold(
      body: Column(
        children: [
          GlassHeader.detail(
            title: '聊天信息(${members.length})',
            actions: [
              GlassHeaderButton(
                icon: Symbols.search,
                color: t.accent,
                onTap: () {},
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                // 成员头像横滚 + 邀请
                M3Card(
                  child: SizedBox(
                    height: 72,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final m in members) _MemberChip(name: m),
                        _InviteChip(onTap: () {}),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 群公告 / 群管理 / 备注
                M3Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      InfoNavRow(label: '群公告', onTap: () {}),
                      const InfoDivider(),
                      InfoNavRow(label: '群管理', onTap: () {}),
                      const InfoDivider(),
                      InfoNavRow(label: '备注', onTap: () {}),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 查找聊天记录
                M3Card(
                  padding: EdgeInsets.zero,
                  child: InfoNavRow(label: '查找聊天记录', onTap: () {}),
                ),
                const SizedBox(height: 16),
                // 开关组
                M3Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      InfoSwitchRow(
                        label: '消息免打扰',
                        value: _mute,
                        onChanged: (v) => setState(() => _mute = v),
                      ),
                      const InfoDivider(),
                      InfoSwitchRow(
                        label: '置顶聊天',
                        value: _pinned,
                        onChanged: (v) => setState(() => _pinned = v),
                      ),
                      const InfoDivider(),
                      InfoNavRow(label: '我在群里的昵称', value: 'Alex', onTap: () {}),
                      const InfoDivider(),
                      InfoSwitchRow(
                        label: '显示群成员昵称',
                        value: _showMemberNick,
                        onChanged: (v) => setState(() => _showMemberNick = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 背景 / 清空
                M3Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      InfoNavRow(label: '设置当前聊天背景', onTap: () {}),
                      const InfoDivider(),
                      InfoNavRow(label: '清空聊天记录', onTap: () {}),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 退出群聊
                M3Card(
                  padding: EdgeInsets.zero,
                  child: InfoCenterRow(
                    label: '退出群聊',
                    danger: true,
                    onTap: () => _confirmLeave(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLeave(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出群聊'),
        content: const Text('确定要退出该群聊吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (context.mounted) context.go('/home');
            },
            child: Text('退出', style: TextStyle(color: context.tk.danger)),
          ),
        ],
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final short = name.split(' ').first;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PortalAvatar(seed: name, size: 48),
          const SizedBox(height: 4),
          SizedBox(
            width: 52,
            child: Text(
              short,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 10, color: t.textMute),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteChip extends StatelessWidget {
  const _InviteChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.border, width: 1.5),
              ),
              child: Icon(Symbols.add, size: 22, color: t.textMute),
            ),
          ),
          const SizedBox(height: 4),
          Text('邀请', style: AppTheme.sans(size: 10, color: t.textMute)),
        ],
      ),
    );
  }
}

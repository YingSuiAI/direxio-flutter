/// 单聊「聊天信息」—— 对齐原型 s-chat-info。M3 风格。
library;

import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../mock/mock_data.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';
import '../widgets/portal_avatar.dart';
import '../widgets/info_rows.dart';

class ChatInfoPage extends StatefulWidget {
  const ChatInfoPage({super.key, required this.roomId});
  final String roomId;

  @override
  State<ChatInfoPage> createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends State<ChatInfoPage> {
  bool _mute = false;
  bool _pinned = true;
  bool _remind = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final conv = MockData.byId(widget.roomId);
    final name = conv?.name ?? '联系人';

    return Scaffold(
      body: Column(
        children: [
          GlassHeader.detail(title: '聊天信息'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                // 头像 + 名字
                Row(
                  children: [
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: PortalAvatar(seed: name, size: 56),
                        ),
                        const SizedBox(height: 6),
                        Text(name,
                            style: AppTheme.sans(
                                size: 12, color: t.textMute)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 查找聊天记录
                M3Card(
                  padding: EdgeInsets.zero,
                  child: InfoNavRow(
                    label: '查找聊天记录',
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 16),
                // 三个开关
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
                      InfoSwitchRow(
                        label: '提醒',
                        value: _remind,
                        onChanged: (v) => setState(() => _remind = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 设置聊天背景
                M3Card(
                  padding: EdgeInsets.zero,
                  child: InfoNavRow(
                    label: '设置当前聊天背景',
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 16),
                // 清空聊天记录
                M3Card(
                  padding: EdgeInsets.zero,
                  child: InfoNavRow(
                    label: '清空聊天记录',
                    danger: true,
                    onTap: () => _confirmClear(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: const Text('确定要清空所有聊天记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('清空',
                style: TextStyle(color: context.tk.danger)),
          ),
        ],
      ),
    );
  }
}

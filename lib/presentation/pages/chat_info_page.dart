import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../mock/mock_data.dart';
import '../providers/auth_provider.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/portal_avatar.dart';

/// `s-chat-info` — 单聊聊天信息 (index.html L597-675)
///
/// 单聊点击右上角 more_vert 进入；区别于「好友个人详情」(contact_detail_page)。
/// 这里只放聊天本身的设置：免打扰 / 置顶 / 提醒 / 背景 / 清空记录。
class ChatInfoPage extends ConsumerStatefulWidget {
  const ChatInfoPage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<ChatInfoPage> createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends ConsumerState<ChatInfoPage> {
  bool _mute = false;
  bool _pinned = true;
  bool _alert = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final client = ref.read(matrixClientProvider);
    final room = client.getRoomById(widget.roomId);
    // 真房间走 Matrix；否则回退 mock 数据（id 以 mock_ 开头，例如 mock_jack）。
    final mock = room == null ? MockData.byId(widget.roomId) : null;
    final peerId = room?.directChatMatrixID ?? mock?.mxid;
    final name =
        room?.getLocalizedDisplayname() ??
        mock?.name ??
        peerId ??
        widget.roomId;

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          GlassHeader.detail(title: '聊天信息'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PeerHeader(
                    name: name,
                    avatarUrl: mock?.avatarUrl,
                    // 仅真 Matrix 房间允许进 contact-detail（mock 路径下 contact-detail
                    // 拿不到房间数据，跳过去是死页）。
                    onTap: room != null && peerId != null
                        ? () => context.push(
                            '/contact/${Uri.encodeComponent(peerId)}',
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _GroupedCard(
                          children: [
                            _RowChevron(label: '查找聊天记录', onTap: () {}),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _GroupedCard(
                          children: [
                            _RowSwitch(
                              label: '消息免打扰',
                              value: _mute,
                              onChanged: (v) => setState(() => _mute = v),
                            ),
                            _Divider(),
                            _RowSwitch(
                              label: '置顶聊天',
                              value: _pinned,
                              onChanged: (v) => setState(() => _pinned = v),
                            ),
                            _Divider(),
                            _RowSwitch(
                              label: '提醒',
                              value: _alert,
                              onChanged: (v) => setState(() => _alert = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _GroupedCard(
                          children: [
                            _RowChevron(label: '设置当前聊天背景', onTap: () {}),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _GroupedCard(
                          children: [
                            _RowDanger(
                              label: '清空聊天记录',
                              onTap: () => _confirmClear(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final t = context.tk;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          '清空聊天记录',
          style: AppTheme.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          '确定清空所有聊天记录？该操作不可恢复。',
          style: AppTheme.sans(size: 15, color: t.textMute),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(
              '取消',
              style: AppTheme.sans(size: 15, color: t.textMute),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(
              '清空',
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: t.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).maybePop();
  }
}

class _PeerHeader extends StatelessWidget {
  const _PeerHeader({required this.name, this.onTap, this.avatarUrl});
  final String name;
  final VoidCallback? onTap;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              PortalAvatar(
                seed: name,
                size: 56,
                shape: AvatarShape.squircle,
                imageUrl: avatarUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 17,
                    weight: FontWeight.w500,
                    color: t.text,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Symbols.chevron_right, size: 22, color: t.border),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupedCard extends StatelessWidget {
  const _GroupedCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: context.tk.border.withValues(alpha: 0.2));
}

class _RowChevron extends StatelessWidget {
  const _RowChevron({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.sans(size: 17, color: t.text),
                ),
              ),
              Icon(Symbols.chevron_right, size: 22, color: t.border),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowSwitch extends StatelessWidget {
  const _RowSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTheme.sans(size: 17, color: t.text)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: t.accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: t.secondaryContainer,
          ),
        ],
      ),
    );
  }
}

class _RowDanger extends StatelessWidget {
  const _RowDanger({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.sans(size: 17, color: t.danger),
                ),
              ),
              Icon(Symbols.chevron_right, size: 22, color: t.border),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../providers/agent_config_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/product_conversations_provider.dart';
import '../utils/avatar_url.dart';
import '../widgets/avatar_adjust_sheet.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/portal_avatar.dart';

typedef AgentAvatarPicker = Future<String?> Function(
  BuildContext context,
  WidgetRef ref,
);

class AgentSettingsPage extends ConsumerStatefulWidget {
  const AgentSettingsPage({super.key, this.pickAvatarUrl});

  final AgentAvatarPicker? pickAvatarUrl;

  @override
  ConsumerState<AgentSettingsPage> createState() => _AgentSettingsPageState();
}

class _AgentSettingsPageState extends ConsumerState<AgentSettingsPage> {
  bool _saving = false;
  bool _avatarBusy = false;

  Future<void> _save(AgentConfig config) async {
    setState(() => _saving = true);
    try {
      await ref.read(agentConfigProvider.notifier).update(config);
      if (!mounted) return;
      setState(() => _saving = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请稍后重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final configAsync = ref.watch(agentConfigProvider);
    final config = configAsync.valueOrNull;
    final matrixClient = ref.watch(matrixClientProvider);
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          GlassHeader.detail(title: 'Agent 设置'),
          Expanded(
            child: RefreshIndicator(
              color: t.accent,
              onRefresh: () => ref.read(agentConfigProvider.notifier).reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  if (config == null)
                    SizedBox(
                      height: 220,
                      child: Center(
                        child: configAsync.isLoading
                            ? CircularProgressIndicator(color: t.accent)
                            : _ErrorState(
                                onRetry: () => ref
                                    .read(agentConfigProvider.notifier)
                                    .reload(),
                              ),
                      ),
                    )
                  else ...[
                    _AgentProfileCard(
                      config: config,
                      avatarUrl: avatarHttpUrl(matrixClient, config.avatarUrl),
                      saving: _saving || _avatarBusy,
                      onAvatarTap: () => _pickAvatar(config),
                      onNameTap: () => _editDisplayName(config),
                    ),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      key: const ValueKey('agent_blocked_rooms_row'),
                      title: '禁读房间设置',
                      subtitle: '已屏蔽 ${config.mcpBlockedRoomIds.length} 个房间',
                      trailingIcon: Symbols.chevron_right,
                      onTap: () => _showBlockedRoomsSheet(config),
                    ),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      title: '活动记录',
                      trailingIcon: Symbols.keyboard_arrow_down,
                      onTap: () {},
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

  Future<void> _pickAvatar(AgentConfig config) async {
    if (_avatarBusy || _saving) return;
    setState(() => _avatarBusy = true);
    try {
      final picker = widget.pickAvatarUrl ?? _pickAndUploadAgentAvatar;
      final avatarUrl = await picker(context, ref);
      if (!mounted) return;
      final trimmed = avatarUrl?.trim() ?? '';
      if (trimmed.isEmpty) return;
      await _save(config.copyWith(avatarUrl: trimmed));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('头像上传失败，请稍后重试')),
      );
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _editDisplayName(AgentConfig config) async {
    final nameCtrl = TextEditingController(text: config.displayName);
    final result = await showDialog<AgentConfig>(
      context: context,
      builder: (context) {
        final t = context.tk;
        return AlertDialog(
          title: Text('编辑 Agent', style: AppTheme.sans(size: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: '昵称'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                Navigator.pop(
                  context,
                  config.copyWith(
                    displayName: name.isEmpty ? config.displayName : name,
                  ),
                );
              },
              child: Text('保存', style: TextStyle(color: t.accent)),
            ),
          ],
        );
      },
    );
    if (result != null) await _save(result);
  }

  Future<void> _showBlockedRoomsSheet(AgentConfig config) async {
    final conversations =
        await ref.read(productConversationsProvider.future).catchError(
              (_) => const <AsConversation>[],
            );
    if (!mounted) return;
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BlockedRoomsSheet(
        conversations: conversations
            .where((conversation) =>
                conversation.roomId.trim().isNotEmpty &&
                conversation.kind != asConversationKindAgent)
            .toList(growable: false),
        selectedRoomIds: config.mcpBlockedRoomIds,
      ),
    );
    if (picked == null) return;
    await _save(config.copyWith(mcpBlockedRoomIds: picked));
  }
}

Future<String?> _pickAndUploadAgentAvatar(
  BuildContext context,
  WidgetRef ref,
) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 92,
    maxWidth: 2048,
    maxHeight: 2048,
    requestFullMetadata: false,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return null;
  String? uploadedAvatarUrl;
  await showAvatarAdjustSheet(
    context,
    imageBytes: bytes,
    onConfirm: (adjustedBytes) async {
      final avatarMxc = await ref.read(matrixClientProvider).uploadContent(
            adjustedBytes,
            filename: 'agent-avatar.png',
            contentType: 'image/png',
          );
      uploadedAvatarUrl = avatarMxc.toString();
    },
  );
  return uploadedAvatarUrl;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('加载失败', style: AppTheme.sans(size: 14, color: t.textMute)),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    );
  }
}

class _AgentProfileCard extends StatelessWidget {
  const _AgentProfileCard({
    required this.config,
    required this.avatarUrl,
    required this.saving,
    required this.onAvatarTap,
    required this.onNameTap,
  });

  final AgentConfig config;
  final String? avatarUrl;
  final bool saving;
  final VoidCallback onAvatarTap;
  final VoidCallback onNameTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Row(
          children: [
            GestureDetector(
              key: const ValueKey('agent_profile_avatar'),
              behavior: HitTestBehavior.opaque,
              onTap: saving ? null : onAvatarTap,
              child: PortalAvatar(
                seed: config.displayName,
                imageUrl: avatarUrl,
                size: 64,
                shape: AvatarShape.squircle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                key: const ValueKey('agent_profile_name'),
                borderRadius: BorderRadius.circular(12),
                onTap: saving ? null : onNameTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              config.displayName.trim().isEmpty
                                  ? 'Agent'
                                  : config.displayName.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(
                                size: 22,
                                weight: FontWeight.w700,
                                color: t.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: t.textMute.withValues(alpha: 0.64),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '离线',
                            style: AppTheme.sans(size: 14, color: t.textMute),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '点击头像可更换，点击昵称可修改',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(size: 14, color: t.textMute),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Symbols.chevron_right, color: t.textMute, size: 24),
              onPressed: saving ? null : onNameTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.trailingIcon,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData trailingIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.sans(
                        size: 18,
                        weight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: AppTheme.sans(size: 14, color: t.textMute),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(trailingIcon, color: t.textMute, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedRoomsSheet extends StatefulWidget {
  const _BlockedRoomsSheet({
    required this.conversations,
    required this.selectedRoomIds,
  });

  final List<AsConversation> conversations;
  final List<String> selectedRoomIds;

  @override
  State<_BlockedRoomsSheet> createState() => _BlockedRoomsSheetState();
}

class _BlockedRoomsSheetState extends State<_BlockedRoomsSheet> {
  late final List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = _normalizeRoomIds(widget.selectedRoomIds);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.76,
        ),
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: t.textMute.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '选择需要屏蔽的房间',
                    style: AppTheme.sans(
                      size: 22,
                      weight: FontWeight.w700,
                      color: t.text,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Symbols.close, color: t.text, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Agent 将不能获取已屏蔽房间的信息',
                style: AppTheme.sans(size: 14, color: t.textMute),
              ),
            ),
            const SizedBox(height: 22),
            Flexible(
              child: widget.conversations.isEmpty
                  ? Center(
                      child: Text(
                        '暂无可屏蔽房间',
                        style: AppTheme.sans(size: 14, color: t.textMute),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final conversation = widget.conversations[index];
                        final roomId = conversation.roomId.trim();
                        final selected = _selected.contains(roomId);
                        return _RoomPickerTile(
                          conversation: conversation,
                          selected: selected,
                          onTap: () => setState(() {
                            if (selected) {
                              _selected.remove(roomId);
                            } else {
                              _selected.add(roomId);
                            }
                          }),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: const ValueKey('agent_room_picker_save'),
                onPressed: () =>
                    Navigator.pop(context, List<String>.of(_selected)),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomPickerTile extends StatelessWidget {
  const _RoomPickerTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final AsConversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final roomId = conversation.roomId.trim();
    final title =
        conversation.title.trim().isEmpty ? roomId : conversation.title.trim();
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              PortalAvatar(
                seed: title,
                imageUrl: conversation.avatarUrl.trim().isEmpty
                    ? null
                    : conversation.avatarUrl.trim(),
                size: 52,
                shape: AvatarShape.squircle,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 18,
                    weight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
              ),
              Checkbox(
                key: ValueKey('agent_room_picker_$roomId'),
                value: selected,
                onChanged: (_) => onTap(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<String> _normalizeRoomIds(Iterable<String> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) continue;
    normalized.add(trimmed);
  }
  return normalized;
}

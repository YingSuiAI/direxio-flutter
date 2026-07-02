import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../providers/agent_config_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/product_conversations_provider.dart';
import '../utils/avatar_url.dart';
import '../widgets/avatar_adjust_sheet.dart';
import '../widgets/center_toast.dart';
import '../widgets/portal_avatar.dart';

typedef AgentAvatarPicker = Future<String?> Function(
  BuildContext context,
  WidgetRef ref,
);

const _agentAvatarEditIconAsset = 'assets/images/ellipse.png';

class AgentSettingsPage extends ConsumerStatefulWidget {
  const AgentSettingsPage({super.key, this.pickAvatarUrl});

  final AgentAvatarPicker? pickAvatarUrl;

  @override
  ConsumerState<AgentSettingsPage> createState() => _AgentSettingsPageState();
}

class _AgentSettingsPageState extends ConsumerState<AgentSettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  bool _saving = false;
  bool _avatarBusy = false;
  bool _editingName = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save(AgentConfig config) async {
    setState(() => _saving = true);
    try {
      await ref.read(agentConfigProvider.notifier).update(config);
      if (!mounted) return;
      setState(() => _saving = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showTopSnackBar(
        context,
        SnackBar(
          content: Text(AppLocalizations.of(context).agentSettingsSaveFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final configAsync = ref.watch(agentConfigProvider);
    final config = configAsync.valueOrNull;
    final matrixClient = ref.watch(matrixClientProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: t.agentSettingsBackground,
      body: Column(
        children: [
          _AgentSettingsHeader(title: l10n.agentSettingsTitle),
          Expanded(
            child: RefreshIndicator(
              color: t.accent,
              onRefresh: () => ref.read(agentConfigProvider.notifier).reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
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
                      editingName: _editingName,
                      nameController: _nameController,
                      nameFocusNode: _nameFocusNode,
                      onAvatarTap: () => _pickAvatar(config),
                      onNameTap: () => _beginDisplayNameEdit(config),
                      onNameSubmitted: (value) =>
                          _submitDisplayName(config, value),
                    ),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      key: const ValueKey('agent_blocked_rooms_row'),
                      title: l10n.agentSettingsBlockedConversationsTitle,
                      subtitle: l10n.agentSettingsBlockedRoomsCount(
                        config.mcpBlockedRoomIds.length,
                      ),
                      trailingIcon: Symbols.chevron_right,
                      onTap: () => _showBlockedRoomsSheet(config),
                    ),
                    if (_editingName) ...[
                      const SizedBox(height: 12),
                      _SettingsCard(
                        title: l10n.agentSettingsActivityLog,
                        compact: true,
                        trailingIcon: Symbols.chevron_right,
                        onTap: () {},
                      ),
                    ],
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
      showTopSnackBar(
        context,
        SnackBar(
          content: Text(
            AppLocalizations.of(context).agentSettingsAvatarUploadFailed,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  void _beginDisplayNameEdit(AgentConfig config) {
    if (_saving || _avatarBusy) return;
    _nameController.text =
        config.displayName.trim().isEmpty ? 'Agent' : config.displayName.trim();
    setState(() => _editingName = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nameFocusNode.requestFocus();
      _nameController.selection = TextSelection.collapsed(
        offset: _nameController.text.length,
      );
    });
  }

  Future<void> _submitDisplayName(AgentConfig config, String value) async {
    final name = value.trim();
    setState(() => _editingName = false);
    _nameFocusNode.unfocus();
    if (name.isEmpty || name == config.displayName.trim()) return;
    await _save(config.copyWith(displayName: name));
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

class _AgentSettingsHeader extends StatelessWidget {
  const _AgentSettingsHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      height: topInset + 58,
      padding: EdgeInsets.only(top: topInset),
      color: t.surface,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 80,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: Icon(
                  Symbols.chevron_left,
                  size: 34,
                  color: t.agentHeaderText,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(
              size: 22,
              weight: FontWeight.w500,
              color: t.agentHeaderText,
            ),
          ),
        ],
      ),
    );
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
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.agentSettingsLoadFailed,
          style: AppTheme.sans(size: 14, color: t.textMute),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
      ],
    );
  }
}

class _AgentProfileCard extends StatelessWidget {
  const _AgentProfileCard({
    required this.config,
    required this.avatarUrl,
    required this.saving,
    required this.editingName,
    required this.nameController,
    required this.nameFocusNode,
    required this.onAvatarTap,
    required this.onNameTap,
    required this.onNameSubmitted,
  });

  final AgentConfig config;
  final String? avatarUrl;
  final bool saving;
  final bool editingName;
  final TextEditingController nameController;
  final FocusNode nameFocusNode;
  final VoidCallback onAvatarTap;
  final VoidCallback onNameTap;
  final ValueChanged<String> onNameSubmitted;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = AppLocalizations.of(context);
    final displayName =
        config.displayName.trim().isEmpty ? 'Agent' : config.displayName.trim();
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      shadowColor: t.agentHeaderText.withValues(alpha: 0.04),
      elevation: 4,
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
          child: Row(
            children: [
              GestureDetector(
                key: const ValueKey('agent_profile_avatar'),
                behavior: HitTestBehavior.opaque,
                onTap: saving ? null : onAvatarTap,
                child: _AgentEditableAvatar(
                  displayName: displayName,
                  avatarUrl: avatarUrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  key: const ValueKey('agent_profile_name'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: saving ? null : onNameTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: editingName
                                ? TextField(
                                    key: const ValueKey(
                                      'agent_profile_name_field',
                                    ),
                                    controller: nameController,
                                    focusNode: nameFocusNode,
                                    enabled: !saving,
                                    autofocus: true,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: onNameSubmitted,
                                    cursorColor: t.accent,
                                    style: AppTheme.sans(
                                      size: 18,
                                      color: t.agentContentText,
                                    ),
                                    decoration: const InputDecoration(
                                      isCollapsed: true,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  )
                                : Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.sans(
                                      size: 18,
                                      weight: FontWeight.w400,
                                      color: t.agentContentText,
                                    ),
                                  ),
                          ),
                          if (!editingName) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Symbols.edit_square,
                              size: 16,
                              color: t.agentContentText,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      _AgentStatusLabel(text: l10n.agentSettingsOfflineStatus),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentEditableAvatar extends StatelessWidget {
  const _AgentEditableAvatar({
    required this.displayName,
    required this.avatarUrl,
  });

  final String displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: avatarUrl == null
                ? const _AgentDefaultAvatar(size: 48)
                : PortalAvatar(
                    seed: displayName,
                    imageUrl: avatarUrl,
                    size: 48,
                    shape: AvatarShape.squircle,
                  ),
          ),
          Positioned(
            left: 38,
            top: 36,
            child: Image.asset(
              _agentAvatarEditIconAsset,
              width: 20,
              height: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentDefaultAvatar extends StatelessWidget {
  const _AgentDefaultAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(Symbols.robot_2, size: size * 0.58, color: t.onAccent),
    );
  }
}

class _AgentStatusLabel extends StatelessWidget {
  const _AgentStatusLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: t.agentStatusText,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: AppTheme.sans(size: 10, color: t.agentStatusText),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    super.key,
    required this.title,
    this.subtitle,
    this.compact = false,
    required this.trailingIcon,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool compact;
  final IconData trailingIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      shadowColor: t.agentHeaderText.withValues(alpha: 0.04),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: compact ? 46 : 68,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.sans(
                          size: 16,
                          weight: FontWeight.w400,
                          color: t.agentContentText,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: AppTheme.sans(
                            size: 12,
                            color: t.agentMutedText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(trailingIcon, color: t.agentMutedText, size: 24),
              ],
            ),
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
    final l10n = AppLocalizations.of(context);
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
                    l10n.agentSettingsBlockedRoomsSheetTitle,
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
                l10n.agentSettingsBlockedRoomsSheetSubtitle,
                style: AppTheme.sans(size: 14, color: t.textMute),
              ),
            ),
            const SizedBox(height: 22),
            Flexible(
              child: widget.conversations.isEmpty
                  ? Center(
                      child: Text(
                        l10n.agentSettingsBlockedRoomsEmpty,
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
                child: Text(l10n.commonSave),
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

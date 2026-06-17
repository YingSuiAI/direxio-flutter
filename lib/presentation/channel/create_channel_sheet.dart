import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/api_logger.dart';
import '../../data/as_client.dart';
import '../providers/as_bootstrap_store_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/as_sync_cache_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/local_created_channels_provider.dart';
import '../widgets/m3/glass_header.dart';

Future<void> showCreateChannelDialog(
  BuildContext context,
  WidgetRef ref, {
  FutureOr<void> Function()? onCreated,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'create-channel',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return _CreateChannelSheet(onCreated: onCreated);
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

String _channelTypeForDraft(String type) {
  return type.trim() == '帖子' ? 'post' : 'chat';
}

String createChannelJoinPolicyForVisibility(bool isPublic) {
  return isPublic ? asChannelJoinPolicyOpen : asChannelJoinPolicyApproval;
}

class _CreateChannelDraft {
  const _CreateChannelDraft({
    required this.name,
    required this.type,
    required this.description,
    this.avatarUrl = '',
    required this.isPublic,
  });

  final String name;
  final String type;
  final String description;
  final String avatarUrl;
  final bool isPublic;
}

class _CreateChannelSheet extends ConsumerStatefulWidget {
  const _CreateChannelSheet({this.onCreated});

  final FutureOr<void> Function()? onCreated;

  @override
  ConsumerState<_CreateChannelSheet> createState() =>
      _CreateChannelSheetState();
}

class _CreateChannelSheetState extends ConsumerState<_CreateChannelSheet> {
  final _nameCtrl = TextEditingController();
  final _introCtrl = TextEditingController();
  String _type = '文字';
  String _avatarUrl = '';
  Uint8List? _avatarPreviewBytes;
  bool _avatarUploading = false;
  bool _isPublic = false;
  bool _needsApproval = true;
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_avatarUploading) return;
    setState(() => _avatarUploading = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1024,
        maxHeight: 1024,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw StateError('empty channel avatar bytes');
      if (mounted) setState(() => _avatarPreviewBytes = bytes);
      final uploaded = await ref.read(matrixClientProvider).uploadContent(
            bytes,
            filename:
                file.name.trim().isEmpty ? 'channel-avatar.jpg' : file.name,
            contentType: file.mimeType ?? _imageMimeTypeForName(file.name),
          );
      if (!mounted) return;
      setState(() => _avatarUrl = uploaded.toString());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('频道头像上传失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _submit() async {
    if (_creating) return;
    if (_avatarUploading) {
      _showCenterWeakHint(context, '频道头像上传中，请稍候');
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showCenterWeakHint(context, '频道名称不能为空');
      return;
    }
    if (_avatarUrl.trim().isEmpty) {
      _showCenterWeakHint(context, '请上传频道头像');
      return;
    }
    if (_introCtrl.text.trim().isEmpty) {
      _showCenterWeakHint(context, '频道介绍不能为空');
      return;
    }

    setState(() => _creating = true);
    try {
      final draft = _CreateChannelDraft(
        name: name,
        type: _type,
        description: _introCtrl.text,
        avatarUrl: _avatarUrl,
        isPublic: _isPublic,
      );
      final channel = await ref.read(asClientProvider).createChannel(
        name: name,
        description: draft.description.trim(),
        avatarUrl: draft.avatarUrl,
        visibility: draft.isPublic
            ? asChannelVisibilityPublic
            : asChannelVisibilityPrivate,
        joinPolicy: createChannelJoinPolicyForVisibility(draft.isPublic),
        channelType: _channelTypeForDraft(draft.type),
        tags: [draft.type],
      );
      ApiLogger.info(
        '[AS admin] create channel result ${jsonEncode(channel.toJson())}',
      );
      final createdAt = DateTime.now().toUtc();
      await ref
          .read(localCreatedChannelsProvider.notifier)
          .cacheCreatedChannel(channel, createdAt);
      final bootstrap = _bootstrapWithCreatedChannel(
        await ref.read(asBootstrapRepositoryProvider).refresh(),
        channel,
        draft,
        createdAt,
      );
      ref.read(asSyncCacheProvider.notifier).update(
            (state) => state.copyWith(bootstrap: bootstrap),
          );
      await widget.onCreated?.call();
      if (!mounted) return;
      const duration = Duration(milliseconds: 700);
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('频道已创建'), duration: duration),
      );
      await Future<void>.delayed(duration);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建频道失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: context.tk.bg,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _CreateChannelTopBar(
                topInset: topInset,
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned.fill(
              top: topInset + 82,
              bottom: keyboardInset + 84,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _CreateChannelNameSection(
                    controller: _nameCtrl,
                  ),
                  const SizedBox(height: 15),
                  _CreateChannelAvatarRow(
                    previewBytes: _avatarPreviewBytes,
                    uploading: _avatarUploading,
                    onTap: _pickAvatar,
                  ),
                  const SizedBox(height: 24),
                  _CreateChannelSection(
                    title: '选择频道类型',
                    gap: 5,
                    child: Row(
                      children: [
                        Expanded(
                          child: _CreateChannelTypeTile(
                            assetName: 'assets/images/icon_edit.png',
                            title: '文字',
                            subtitle: '成员自由发言',
                            selected: _type == '文字',
                            onTap: () => setState(() => _type = '文字'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CreateChannelTypeTile(
                            assetName: 'assets/images/icon_pencil.png',
                            title: '帖子',
                            subtitle: '帖子与评论',
                            selected: _type == '帖子',
                            onTap: () => setState(() => _type = '帖子'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 23),
                  const _CreateChannelSectionHeader(title: '频道权限'),
                  const SizedBox(height: 10),
                  _CreateChannelSwitchRow(
                    title: '是否公开',
                    subtitle: '关闭后仅通过邀请加入',
                    value: _isPublic,
                    onChanged: (value) => setState(() => _isPublic = value),
                  ),
                  const SizedBox(height: 10),
                  _CreateChannelSwitchRow(
                    title: '加入是否需要审核',
                    subtitle: '开启后新成员加入前需要频道审核',
                    value: _needsApproval,
                    onChanged: (value) =>
                        setState(() => _needsApproval = value),
                  ),
                  const SizedBox(height: 24),
                  _CreateChannelSection(
                    title: '频道介绍',
                    meta: '',
                    gap: 5,
                    child: _CreateChannelIntroField(controller: _introCtrl),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboardInset + 25,
              child: SafeArea(
                top: false,
                child: Center(
                  child: SizedBox(
                    width: 156,
                    child: _CreateChannelSubmitButton(
                      creating: _creating,
                      onTap: _submit,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

AsSyncBootstrap _bootstrapWithCreatedChannel(
  AsSyncBootstrap bootstrap,
  AsChannel channel,
  _CreateChannelDraft draft,
  DateTime createdAt,
) {
  final roomId = channel.roomId.trim();
  final channelId = channel.channelId.trim();
  if (roomId.isEmpty && channelId.isEmpty) return bootstrap;
  final summary = AsSyncRoomSummary(
    channelId: channelId,
    roomId: roomId,
    homeDomain: channel.homeDomain.trim(),
    name: channel.name.trim().isEmpty ? draft.name.trim() : channel.name.trim(),
    avatarUrl:
        channel.avatarUrl.trim().isEmpty ? draft.avatarUrl : channel.avatarUrl,
    unreadCount: 0,
    lastActivityAt: channel.latestActivityAt ?? createdAt,
    description: channel.description.trim().isEmpty
        ? draft.description.trim()
        : channel.description.trim(),
    isOwned: true,
    tags: channel.tags.isEmpty ? [draft.type] : channel.tags,
    visibility: channel.visibility,
    joinPolicy: channel.joinPolicy,
    commentsEnabled: channel.commentsEnabled,
    channelType: normalizeAsChannelType(channel.channelType),
    role: channel.role.trim().isEmpty ? asChannelRoleOwner : channel.role,
    memberStatus: channel.memberStatus.trim().isEmpty
        ? asChannelMemberStatusJoined
        : channel.memberStatus,
    memberCount: channel.memberCount,
    pendingJoinCount: channel.pendingJoinCount,
  );
  final existing = bootstrap.channels.where((item) {
    final existingChannelId = item.channelId.trim();
    final existingRoomId = item.roomId.trim();
    if (channelId.isNotEmpty && existingChannelId == channelId) return false;
    if (roomId.isNotEmpty && existingRoomId == roomId) return false;
    return true;
  }).toList(growable: false);
  return AsSyncBootstrap(
    syncedAt: bootstrap.syncedAt,
    user: bootstrap.user,
    rooms: bootstrap.rooms,
    contacts: bootstrap.contacts,
    groups: bootstrap.groups,
    channels: [summary, ...existing],
    pending: bootstrap.pending,
    agentRoomId: bootstrap.agentRoomId,
  );
}

class _CreateChannelTopBar extends StatelessWidget {
  const _CreateChannelTopBar({
    required this.topInset,
    required this.onClose,
  });

  final double topInset;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: topInset + 70,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 16,
              top: 6,
              child: GlassHeaderButton(
                icon: Symbols.close,
                onTap: onClose,
                color: context.tk.text,
                iconSize: 24,
              ),
            ),
            Text(
              '创建频道',
              style: AppTheme.sans(
                size: 18,
                weight: FontWeight.w600,
                color: context.tk.text,
              ).copyWith(height: 33 / 26),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateChannelSection extends StatelessWidget {
  const _CreateChannelSection({
    required this.title,
    required this.child,
    this.meta,
    this.gap = 8,
  });

  final String title;
  final String? meta;
  final Widget child;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CreateChannelSectionHeader(title: title, meta: meta),
        SizedBox(height: gap),
        child,
      ],
    );
  }
}

class _CreateChannelNameSection extends StatelessWidget {
  const _CreateChannelNameSection({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CreateChannelSectionHeader(title: '频道名称', meta: ''),
        const SizedBox(height: 4),
        _CreateChannelNameField(controller: controller),
      ],
    );
  }
}

class _CreateChannelAvatarRow extends StatelessWidget {
  const _CreateChannelAvatarRow({
    required this.previewBytes,
    required this.uploading,
    required this.onTap,
  });

  final Uint8List? previewBytes;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CreateChannelSectionHeader(title: '上传频道头像'),
              const SizedBox(height: 8),
              Text(
                '支持图片上传，作为频道展示头像',
                style: AppTheme.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  color: context.tk.textMute,
                ).copyWith(height: 18 / 12),
              ),
            ],
          ),
        ),
        _CreateChannelAvatarPicker(
          previewBytes: previewBytes,
          uploading: uploading,
          onTap: onTap,
        ),
      ],
    );
  }
}

class _CreateChannelSectionHeader extends StatelessWidget {
  const _CreateChannelSectionHeader({required this.title, this.meta});

  final String title;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTheme.sans(
              size: 18,
              weight: FontWeight.w600,
              color: context.tk.text,
            ).copyWith(height: 26 / 18),
          ),
        ),
        if (meta != null)
          Text(
            meta!,
            style: AppTheme.sans(
              size: 12,
              weight: FontWeight.w500,
              color: context.tk.accent,
            ).copyWith(height: 14 / 12),
          ),
      ],
    );
  }
}

class _CreateChannelNameField extends StatelessWidget {
  const _CreateChannelNameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: context.tk.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        maxLines: 1,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          hintText: '请输入',
          hintStyle: AppTheme.sans(
            size: 12,
            weight: FontWeight.w500,
            color: context.tk.textMute,
          ).copyWith(height: 18 / 12),
        ),
        style: AppTheme.sans(
          size: 14,
          weight: FontWeight.w500,
          color: context.tk.text,
        ),
      ),
    );
  }
}

class _CreateChannelAvatarPicker extends StatelessWidget {
  const _CreateChannelAvatarPicker({
    required this.previewBytes,
    required this.uploading,
    required this.onTap,
  });

  final Uint8List? previewBytes;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: previewBytes == null
                    ? Image.asset(
                        'assets/images/icon_avatar.png',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : Image.memory(previewBytes!, fit: BoxFit.cover),
              ),
              if (uploading)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.32),
                  ),
                  child: const Center(
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
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

class _CreateChannelTypeTile extends StatelessWidget {
  const _CreateChannelTypeTile({
    required this.assetName,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String assetName;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 125,
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? t.accent : t.border.withValues(alpha: 0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _createShadowColor(context),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Image.asset(
                assetName,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: AppTheme.sans(
                  size: 16,
                  weight: FontWeight.w500,
                  color: t.text,
                ).copyWith(height: 19 / 16),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                style: AppTheme.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  color: t.textMute,
                ).copyWith(height: 18 / 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateChannelSwitchRow extends StatelessWidget {
  const _CreateChannelSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.sans(
                    size: 16,
                    weight: FontWeight.w500,
                    color: context.tk.text,
                  ).copyWith(height: 26 / 16),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.sans(
                    size: 12,
                    weight: FontWeight.w500,
                    color: context.tk.textMute,
                  ).copyWith(height: 18 / 12),
                ),
              ],
            ),
          ),
          _CreateChannelSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CreateChannelSwitch extends StatelessWidget {
  const _CreateChannelSwitch({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: 47,
        height: 26,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 47,
              height: 26,
              decoration: BoxDecoration(
                color: value ? context.tk.accent : context.tk.surfaceHover,
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              left: value ? 23 : 1,
              top: 1,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: context.tk.onAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateChannelIntroField extends StatelessWidget {
  const _CreateChannelIntroField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 89,
      decoration: BoxDecoration(
        color: context.tk.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        minLines: null,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          hintText: '输入频道介绍...',
          hintStyle: AppTheme.sans(
            size: 12,
            weight: FontWeight.w500,
            color: context.tk.textMute,
          ).copyWith(height: 18 / 12),
        ),
        style: AppTheme.sans(
          size: 14,
          weight: FontWeight.w500,
          color: context.tk.text,
        ),
      ),
    );
  }
}

class _CreateChannelSubmitButton extends StatelessWidget {
  const _CreateChannelSubmitButton({
    required this.creating,
    required this.onTap,
  });

  final bool creating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tk.accent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: creating ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 43,
          child: Center(
            child: creating
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.tk.onAccent,
                    ),
                  )
                : Text(
                    '创建频道',
                    style: AppTheme.sans(
                      size: 18,
                      weight: FontWeight.w600,
                      color: context.tk.onAccent,
                    ).copyWith(height: 26 / 18),
                  ),
          ),
        ),
      ),
    );
  }
}

void _showCenterWeakHint(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final t = context.tk;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: t.text.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.sans(
                size: 14,
                weight: FontWeight.w500,
                color: t.bg,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 1200), () {
    if (entry.mounted) entry.remove();
  });
}

String _imageMimeTypeForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  return 'image/jpeg';
}

Color _createShadowColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.34)
      : const Color(0xFFBFBFBF).withValues(alpha: 0.25);
}

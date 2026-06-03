import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../mock/mock_data.dart';
import '../providers/auth_provider.dart';
import '../providers/app_warmup_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/personal_space_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/avatar_url.dart';
import '../widgets/avatar_adjust_sheet.dart';
import '../widgets/glass_list_tile.dart';
import '../widgets/portal_avatar.dart';

class ProfileInfoPage extends ConsumerStatefulWidget {
  const ProfileInfoPage({super.key});

  @override
  ConsumerState<ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends ConsumerState<ProfileInfoPage> {
  bool _avatarBusy = false;
  bool _coverBusy = false;
  bool _profileBusy = false;

  Future<void> _pickCover() async {
    if (_coverBusy) return;
    setState(() => _coverBusy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 2400,
        maxHeight: 1600,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      ref.read(personalProfileProvider.notifier).state =
          ref.read(personalProfileProvider).copyWith(coverImageBytes: bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('背景更新失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _coverBusy = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (_avatarBusy) return;
    setState(() => _avatarBusy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2048,
        maxHeight: 2048,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await showAvatarAdjustSheet(
        context,
        imageBytes: bytes,
        onConfirm: (adjustedBytes) async {
          final matrixFile = MatrixFile(
            bytes: adjustedBytes,
            name: 'avatar.png',
            mimeType: 'image/png',
          );
          await ref.read(matrixClientProvider).setAvatar(matrixFile);
          ref.invalidate(currentUserProfileProvider);
          await ref.read(currentUserProfileProvider.future);
          ref.invalidate(appWarmupProvider);
          unawaited(ref.read(appWarmupProvider.future));
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像更新失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _editField({
    required String title,
    required String initialValue,
    required FutureOr<void> Function(String value) onSave,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改$title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: title == '简介' ? 3 : 1,
          decoration: InputDecoration(hintText: '请输入$title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value == null) return;
    await onSave(value.trim());
  }

  void _updateProfile(PersonalProfileData data) {
    ref.read(personalProfileProvider.notifier).state = data;
  }

  Future<void> _updateDisplayName(
    PersonalProfileData data,
    String userId,
    String value,
  ) async {
    if (_profileBusy) return;
    final displayName = value.trim();
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户名不能为空')),
      );
      return;
    }
    if (displayName.toLowerCase() == _localpartFromMxid(userId).toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请设置一个不同于系统账号的用户名')),
      );
      return;
    }

    setState(() => _profileBusy = true);
    try {
      final ownerProfile = await ref
          .read(asClientProvider)
          .updateOwnerProfile(displayName: displayName);
      final savedName = ownerProfile.displayName.trim().isNotEmpty
          ? ownerProfile.displayName.trim()
          : displayName;
      _updateProfile(data.copyWith(displayName: savedName));
      ref.invalidate(currentUserProfileProvider);
      await ref.read(currentUserProfileProvider.future);
      ref.invalidate(appWarmupProvider);
      unawaited(ref.read(appWarmupProvider.future));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('用户名已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('用户名更新失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _profileBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final client = ref.watch(matrixClientProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final data = ref.watch(personalProfileProvider);
    final userId = client.userID ?? '@me:portal.agent-p2p.io';
    final localpart = _localpartFromMxid(userId);
    final profileName = profile?.displayName?.trim();
    final displayName = data.displayName?.trim().isNotEmpty == true
        ? data.displayName!.trim()
        : profileName?.isNotEmpty == true
            ? profileName!
            : localpart;
    final domain = _domainFromMxid(userId);
    final avatarUrl = profileAvatarHttpUrl(profile, client) ?? MockAvatars.me;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _ProfileCover(
                coverImageBytes: data.coverImageBytes,
                coverBusy: _coverBusy,
                avatarBusy: _avatarBusy,
                avatarUrl: avatarUrl,
                displayId: userId,
                displayName: displayName,
                onCoverTap: _pickCover,
                onAvatarTap: _pickAvatar,
              ),
              Container(
                decoration: BoxDecoration(
                  color: t.bg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                padding: const EdgeInsets.fromLTRB(0, 18, 0, 32),
                child: Column(
                  children: [
                    const _ProfileCompletion(text: '资料完成度 100%'),
                    const SizedBox(height: 18),
                    _ProfileInfoRow(
                      label: '用户名',
                      value: displayName,
                      onTap: () => _editField(
                        title: '用户名',
                        initialValue: displayName,
                        onSave: (value) =>
                            _updateDisplayName(data, userId, value),
                      ),
                    ),
                    _ProfileInfoRow(
                      label: '简介',
                      value: data.bio,
                      onTap: () => _editField(
                        title: '简介',
                        initialValue: data.bio,
                        onSave: (value) =>
                            _updateProfile(data.copyWith(bio: value)),
                      ),
                    ),
                    _ProfileInfoRow(
                      label: '性别',
                      value: data.gender,
                      onTap: () => _editField(
                        title: '性别',
                        initialValue: data.gender,
                        onSave: (value) =>
                            _updateProfile(data.copyWith(gender: value)),
                      ),
                    ),
                    _ProfileInfoRow(
                      label: '生日',
                      value: data.birthday,
                      onTap: () => _editField(
                        title: '生日',
                        initialValue: data.birthday,
                        onSave: (value) =>
                            _updateProfile(data.copyWith(birthday: value)),
                      ),
                    ),
                    _ProfileInfoRow(
                      label: '所在地',
                      value: data.location,
                      onTap: () => _editField(
                        title: '所在地',
                        initialValue: data.location,
                        onSave: (value) =>
                            _updateProfile(data.copyWith(location: value)),
                      ),
                    ),
                    _ProfileInfoRow(
                      label: '域名',
                      value: domain,
                      onTap: null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Symbols.arrow_back_ios_new,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '个人信息',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 18,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _CoverButton(onTap: _pickCover, busy: _coverBusy),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCover extends StatelessWidget {
  const _ProfileCover({
    required this.coverImageBytes,
    required this.coverBusy,
    required this.avatarBusy,
    required this.avatarUrl,
    required this.displayId,
    required this.displayName,
    required this.onCoverTap,
    required this.onAvatarTap,
  });

  final Uint8List? coverImageBytes;
  final bool coverBusy;
  final bool avatarBusy;
  final String avatarUrl;
  final String displayId;
  final String displayName;
  final VoidCallback onCoverTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 392,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 330,
            child: GestureDetector(
              onTap: onCoverTap,
              child: coverImageBytes == null
                  ? const _DefaultCover()
                  : Image.memory(coverImageBytes!, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 330,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.38),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: ClipOval(
                          child: PortalAvatar(
                            seed: displayId,
                            size: 132,
                            imageUrl: avatarUrl,
                          ),
                        ),
                      ),
                      ClipOval(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.24),
                          child: SizedBox(
                            width: 132,
                            height: 132,
                            child: Center(
                              child: avatarBusy
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Symbols.photo_camera,
                                          size: 34,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '更换头像',
                                          style: AppTheme.sans(
                                            size: 16,
                                            weight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  displayName,
                  style: AppTheme.sans(
                    size: 20,
                    weight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
              ],
            ),
          ),
          if (coverBusy)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileCompletion extends StatelessWidget {
  const _ProfileCompletion({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: AppTheme.sans(size: 14, color: context.tk.textMute),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final displayValue = value.isEmpty ? '未设置' : value;
    return GlassListTile(
      onTap: onTap,
      title: label,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.46,
            ),
            child: Text(
              displayValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTheme.sans(size: 13, color: t.textMute),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Symbols.chevron_right, size: 22, color: t.textMute),
          ],
        ],
      ),
      showChevron: false,
    );
  }
}

class _CoverButton extends StatelessWidget {
  const _CoverButton({required this.onTap, required this.busy});

  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Symbols.add_a_photo,
                    size: 22,
                    color: Colors.white,
                  ),
            const SizedBox(width: 8),
            Text(
              '更换背景',
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

class _DefaultCover extends StatelessWidget {
  const _DefaultCover();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6D8EA6),
            Color(0xFFD6B06F),
            Color(0xFF3A342F),
          ],
        ),
      ),
    );
  }
}

String _domainFromMxid(String mxid) {
  final colon = mxid.indexOf(':');
  if (colon == -1 || colon == mxid.length - 1) return '未连接域名';
  return mxid.substring(colon + 1);
}

String _localpartFromMxid(String mxid) {
  if (!mxid.startsWith('@')) return mxid;
  final colon = mxid.indexOf(':');
  if (colon == -1) return mxid.substring(1);
  return mxid.substring(1, colon);
}

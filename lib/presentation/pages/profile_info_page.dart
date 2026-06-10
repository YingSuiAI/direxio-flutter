import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../mock/mock_data.dart';
import '../providers/app_warmup_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/personal_space_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/avatar_url.dart';
import '../widgets/avatar_adjust_sheet.dart';
import '../widgets/portal_avatar.dart';

class ProfileInfoPage extends ConsumerStatefulWidget {
  const ProfileInfoPage({super.key});

  @override
  ConsumerState<ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends ConsumerState<ProfileInfoPage> {
  bool _avatarBusy = false;
  bool _profileBusy = false;

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
    final avatarUrl = profileAvatarHttpUrl(profile, client) ?? MockAvatars.me;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: t.surfaceHover,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _ProfileHeader(topInset: topInset),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 25, 16, 28 + bottomInset),
                child: Column(
                  children: [
                    _AvatarEditor(
                      avatarBusy: _avatarBusy,
                      avatarUrl: avatarUrl,
                      seed: userId,
                      onTap: _pickAvatar,
                    ),
                    const SizedBox(height: 22),
                    _ProfileInfoCard(
                      label: '名字',
                      value: displayName,
                      busy: _profileBusy,
                      onTap: () => _editField(
                        title: '名字',
                        initialValue: displayName,
                        onSave: (value) =>
                            _updateDisplayName(data, userId, value),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileInfoCard(
                      label: '性别',
                      value: data.gender,
                      onTap: () => _editField(
                        title: '性别',
                        initialValue: _emptyIfUnset(data.gender),
                        onSave: (value) => _updateProfile(
                          data.copyWith(gender: value.isEmpty ? '未设置' : value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileInfoCard(
                      label: '生日',
                      value: data.birthday,
                      onTap: () => _editField(
                        title: '生日',
                        initialValue: _emptyIfUnset(data.birthday),
                        onSave: (value) => _updateProfile(
                          data.copyWith(
                            birthday: value.isEmpty ? '未设置' : value,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileInfoCard(
                      label: '手机号码',
                      value: data.phone,
                      onTap: () => _editField(
                        title: '手机号码',
                        initialValue: data.phone,
                        onSave: (value) =>
                            _updateProfile(data.copyWith(phone: value)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileInfoCard(
                      label: '邮箱',
                      value: data.email,
                      onTap: () => _editField(
                        title: '邮箱',
                        initialValue: data.email,
                        onSave: (value) =>
                            _updateProfile(data.copyWith(email: value)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _emptyIfUnset(String value) =>
    value == '未设置' || value == '不展示' ? '' : value;

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: topInset + 62,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topInset + 4, 16, 0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _GlassBackButton(onTap: () => context.pop()),
            ),
            Text(
              '我的信息',
              style: AppTheme.sans(
                size: 16,
                weight: FontWeight.w600,
                color: t.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: t.text.withValues(alpha: 0.12),
            blurRadius: 36,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: t.surface.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(Symbols.arrow_back, size: 24, color: t.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({
    required this.avatarBusy,
    required this.avatarUrl,
    required this.seed,
    required this.onTap,
  });

  final bool avatarBusy;
  final String avatarUrl;
  final String seed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GestureDetector(
      onTap: avatarBusy ? null : onTap,
      child: SizedBox(
        width: 98,
        height: 98,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PortalAvatar(
                seed: seed,
                size: 98,
                imageUrl: avatarUrl,
                shape: AvatarShape.squircle,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 20,
                child: ColoredBox(
                  color: t.text.withValues(alpha: 0.78),
                  child: Center(
                    child: avatarBusy
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              color: t.surface,
                              strokeWidth: 1.8,
                            ),
                          )
                        : Text(
                            '修改',
                            style: AppTheme.sans(size: 10, color: t.surface),
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

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.label,
    required this.value,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final displayValue = value.trim().isEmpty ? '未设置' : value.trim();
    final muted = displayValue == '未设置';
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : onTap,
        child: Container(
          width: double.infinity,
          height: 78,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 14,
                        weight: FontWeight.w500,
                        color: t.textMute,
                      ),
                    ),
                    Text(
                      displayValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 16,
                        weight: FontWeight.w600,
                        color: muted ? t.textMute : t.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.accent,
                      ),
                    )
                  : Icon(Symbols.chevron_right, size: 24, color: t.text),
            ],
          ),
        ),
      ),
    );
  }
}

String _localpartFromMxid(String mxid) {
  final trimmed = mxid.trim();
  if (trimmed.startsWith('@')) {
    final end = trimmed.indexOf(':');
    if (end > 1) return trimmed.substring(1, end);
    return trimmed.substring(1);
  }
  return trimmed;
}

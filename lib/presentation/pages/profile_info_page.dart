import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:matrix/matrix.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/as_client.dart';
import '../../l10n/app_localizations.dart';
import '../providers/app_warmup_provider.dart';
import '../providers/as_client_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/personal_space_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/avatar_url.dart';
import '../utils/direct_contact_status.dart';
import '../widgets/avatar_adjust_sheet.dart';
import '../widgets/center_toast.dart';
import '../widgets/portal_avatar.dart';

class ProfileInfoPage extends ConsumerStatefulWidget {
  const ProfileInfoPage({super.key});

  @override
  ConsumerState<ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends ConsumerState<ProfileInfoPage> {
  bool _avatarBusy = false;
  bool _profileBusy = false;

  Future<void> _pickAvatar(
    PersonalProfileData data,
    String userId,
    String displayName,
  ) async {
    final l10n = _profileInfoL10n(context);
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
          final client = ref.read(matrixClientProvider);
          final matrixUserId = client.userID;
          if (matrixUserId == null || matrixUserId.isEmpty) {
            throw StateError(
              l10n?.profileInfoMatrixSessionMissing ?? '当前 Matrix 登录态缺失',
            );
          }
          final avatarMxc = await client.uploadContent(
            adjustedBytes,
            filename: 'avatar.png',
            contentType: 'image/png',
          );
          await client.setAvatarUrl(matrixUserId, avatarMxc);
          await _saveOwnerProfile(
            data,
            userId: userId,
            displayName: displayName,
            avatarUrl: avatarMxc.toString(),
          );
          await cacheCurrentUserProfile(
            ref,
            userId: matrixUserId,
            displayName: displayName,
            avatarUrl: avatarMxc.toString(),
          );
          ref.invalidate(currentUserProfileProvider);
          await ref.read(currentUserProfileProvider.future);
          ref.invalidate(appWarmupProvider);
          unawaited(ref.read(appWarmupProvider.future));
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.profileInfoAvatarUpdateFailed('$e') ?? '头像更新失败: $e',
            ),
          ),
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
    TextInputType? keyboardType,
  }) async {
    final l10n = _profileInfoL10n(context);
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.profileInfoEditTitle(title) ?? '修改$title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: l10n?.profileInfoInputHint(title) ?? '请输入$title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n?.commonCancel ?? '取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l10n?.commonSave ?? '保存'),
          ),
        ],
      ),
    );
    if (value == null) return;
    await onSave(value.trim());
  }

  Future<void> _pickGender(PersonalProfileData data, String userId) async {
    final l10n = _profileInfoL10n(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => _GenderPickerSheet(
        value: _emptyIfUnset(data.gender),
      ),
    );
    if (selected == null) return;
    await _updateProfileField(
      data,
      userId: userId,
      gender: selected,
      successMessage: l10n?.profileInfoGenderUpdated ?? '性别已更新',
      failureLabel: l10n?.profileInfoGender ?? '性别',
    );
  }

  Future<void> _pickBirthday(PersonalProfileData data, String userId) async {
    final l10n = _profileInfoL10n(context);
    final initial = _parseBirthday(data.birthday) ?? DateTime(2000);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: l10n?.profileInfoBirthdayPickerTitle ?? '选择生日',
      cancelText: l10n?.commonCancel ?? '取消',
      confirmText: l10n?.commonSave ?? '保存',
    );
    if (picked == null) return;
    await _updateProfileField(
      data,
      userId: userId,
      birthday: _formatBirthday(picked),
      successMessage: l10n?.profileInfoBirthdayUpdated ?? '生日已更新',
      failureLabel: l10n?.profileInfoBirthday ?? '生日',
    );
  }

  void _updateProfile(PersonalProfileData data) {
    ref.read(personalProfileProvider.notifier).state = data;
  }

  Future<void> _syncMatrixDisplayName(String userId, String displayName) async {
    final client = ref.read(matrixClientProvider);
    final matrixUserId = client.userID?.trim().isNotEmpty == true
        ? client.userID!.trim()
        : userId;
    if (matrixUserId.trim().isEmpty) return;
    await client.setDisplayName(matrixUserId, displayName);

    final joinedRooms =
        client.rooms.where((room) => room.membership == Membership.join);
    for (final room in joinedRooms) {
      try {
        final currentContent =
            room.getState(EventTypes.RoomMember, matrixUserId)?.content;
        final nextContent = <String, Object?>{
          if (currentContent != null) ...currentContent,
          'membership': Membership.join.name,
          'displayname': displayName,
        };
        await client.setRoomStateWithKey(
          room.id,
          EventTypes.RoomMember,
          matrixUserId,
          nextContent,
        );
      } catch (e) {
        debugPrint('sync room member display name failed: ${room.id}: $e');
      }
    }
  }

  Future<OwnerProfile> _saveOwnerProfile(
    PersonalProfileData data, {
    required String userId,
    String? displayName,
    String? avatarUrl,
    String? gender,
    String? birthday,
    String? phone,
    String? email,
  }) {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final resolvedDisplayName = (displayName ??
            data.displayName ??
            profile?.displayName ??
            _localpartFromMxid(userId))
        .trim();
    final resolvedAvatarUrl =
        avatarUrl ?? profile?.avatarUrl?.toString().trim() ?? '';
    return ref.read(asClientProvider).updateOwnerProfile(
          displayName: resolvedDisplayName,
          avatarUrl: resolvedAvatarUrl,
          gender: _asProfileValue(gender ?? data.gender),
          birthday: _asProfileValue(birthday ?? data.birthday),
          phone: (phone ?? data.phone).trim(),
          email: (email ?? data.email).trim(),
        );
  }

  Future<void> _updateProfileField(
    PersonalProfileData data, {
    required String userId,
    required String successMessage,
    required String failureLabel,
    String? displayName,
    String? gender,
    String? birthday,
    String? phone,
    String? email,
  }) async {
    final l10n = _profileInfoL10n(context);
    if (_profileBusy) return;
    final cleanDisplayName = displayName?.trim();
    if (displayName != null && cleanDisplayName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.profileInfoDisplayNameEmpty ?? '用户名不能为空'),
        ),
      );
      return;
    }
    if (cleanDisplayName != null &&
        cleanDisplayName.toLowerCase() ==
            _localpartFromMxid(userId).toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.profileInfoDisplayNameSystemName ?? '请设置一个不同于系统账号的用户名',
          ),
        ),
      );
      return;
    }

    setState(() => _profileBusy = true);
    try {
      final ownerProfile = await _saveOwnerProfile(
        data,
        userId: userId,
        displayName: cleanDisplayName,
        gender: gender,
        birthday: birthday,
        phone: phone,
        email: email,
      );
      if (cleanDisplayName != null) {
        try {
          await _syncMatrixDisplayName(userId, cleanDisplayName);
        } catch (e) {
          debugPrint('sync Matrix display name failed: $e');
        }
      }
      _updateProfile(_personalProfileFromOwner(data, ownerProfile));
      await cacheCurrentUserProfile(
        ref,
        userId: userId,
        displayName: ownerProfile.displayName.trim().isNotEmpty
            ? ownerProfile.displayName.trim()
            : cleanDisplayName ?? data.displayName ?? '',
        avatarUrl: ownerProfile.avatarUrl.trim().isNotEmpty
            ? ownerProfile.avatarUrl.trim()
            : ref
                    .read(currentUserProfileProvider)
                    .valueOrNull
                    ?.avatarUrl
                    ?.toString() ??
                '',
      );
      ref.invalidate(currentUserProfileProvider);
      await ref.read(currentUserProfileProvider.future);
      ref.invalidate(appWarmupProvider);
      unawaited(ref.read(appWarmupProvider.future));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.profileInfoFieldUpdateFailed(failureLabel, '$e') ??
                  '$failureLabel更新失败: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _profileBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = _profileInfoL10n(context);
    final client = ref.watch(matrixClientProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final data = ref.watch(personalProfileProvider);
    final userId = client.userID ?? '@me:portal.agent-p2p.io';
    final localpart = _localpartFromMxid(userId);
    final uidUrl = _profileUidUrl(client, userId);
    final profileName = profile?.displayName?.trim();
    final displayName = data.displayName?.trim().isNotEmpty == true
        ? data.displayName!.trim()
        : profileName?.isNotEmpty == true
            ? profileName!
            : localpart;
    final avatarUrl = profileAvatarHttpUrl(profile, client);
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
                      editLabel: l10n?.profileInfoAvatarEdit ?? '修改',
                      seed: userId,
                      onTap: () => _pickAvatar(data, userId, displayName),
                    ),
                    const SizedBox(height: 22),
                    _ProfileInfoCard(
                      label: l10n?.profileInfoNickname ?? '昵称',
                      value: displayName,
                      unsetLabel: l10n?.profileInfoUnset ?? '未设置',
                      busy: _profileBusy,
                      onTap: () => _editField(
                        title: l10n?.profileInfoNickname ?? '昵称',
                        initialValue: displayName,
                        onSave: (value) => _updateProfileField(
                          data,
                          userId: userId,
                          displayName: value,
                          successMessage:
                              l10n?.profileInfoDisplayNameUpdated ?? '用户名已更新',
                          failureLabel: l10n?.profileInfoDisplayName ?? '用户名',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileUidCard(
                      uid: uidUrl,
                      onTap: () => _copyUidUrl(context, uidUrl),
                    ),
                    const SizedBox(height: 16),
                    _ProfileInfoCard(
                      label: l10n?.profileInfoGender ?? '性别',
                      value: _profileGenderDisplayValue(data.gender, l10n),
                      unsetLabel: l10n?.profileInfoUnset ?? '未设置',
                      onTap: () => _pickGender(data, userId),
                    ),
                    const SizedBox(height: 16),
                    _ProfileInfoCard(
                      label: l10n?.profileInfoBirthday ?? '生日',
                      value: data.birthday,
                      unsetLabel: l10n?.profileInfoUnset ?? '未设置',
                      onTap: () => _pickBirthday(data, userId),
                    ),
                    const SizedBox(height: 16),
                    _ProfileInfoCard(
                      label: l10n?.profileInfoEmail ?? '邮箱',
                      value: data.email,
                      unsetLabel: l10n?.profileInfoUnset ?? '未设置',
                      onTap: () => _editField(
                        title: l10n?.profileInfoEmail ?? '邮箱',
                        initialValue: data.email,
                        keyboardType: TextInputType.emailAddress,
                        onSave: (value) => _updateProfileField(
                          data,
                          userId: userId,
                          email: value,
                          successMessage:
                              l10n?.profileInfoEmailUpdated ?? '邮箱已更新',
                          failureLabel: l10n?.profileInfoEmail ?? '邮箱',
                        ),
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

AppLocalizations? _profileInfoL10n(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations);
}

String _emptyIfUnset(String value) =>
    value == '未设置' || value == '不展示' ? '' : value;

String _asProfileValue(String value) => _emptyIfUnset(value).trim();

DateTime? _parseBirthday(String value) {
  final clean = _emptyIfUnset(value).trim();
  if (clean.isEmpty) return null;
  final normalized = clean.replaceAll('/', '-').replaceAll('.', '-');
  return DateTime.tryParse(normalized);
}

String _formatBirthday(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _profileDisplayValue(String value) {
  final clean = value.trim();
  return clean.isEmpty ? '未设置' : clean;
}

String _profileGenderDisplayValue(String value, AppLocalizations? l10n) {
  final clean = _emptyIfUnset(value).trim();
  return switch (clean) {
    '男' => l10n?.profileInfoGenderMale ?? '男',
    '女' => l10n?.profileInfoGenderFemale ?? '女',
    _ => clean,
  };
}

PersonalProfileData _personalProfileFromOwner(
  PersonalProfileData current,
  OwnerProfile owner,
) {
  return current.copyWith(
    displayName: owner.displayName.trim().isEmpty
        ? current.displayName
        : owner.displayName.trim(),
    gender: _profileDisplayValue(owner.gender),
    birthday: _profileDisplayValue(owner.birthday),
    phone: owner.phone.trim(),
    email: owner.email.trim(),
  );
}

String _profileUidUrl(Client client, String userId) {
  final domain = serverNameFromMxid(userId) ?? _clientServerName(client);
  final normalized = domain.trim().replaceFirst(RegExp(r'^https?://'), '');
  if (normalized.isEmpty) return userId;
  return 'https://$normalized';
}

String _clientServerName(Client client) {
  final homeserver = client.homeserver;
  if (homeserver != null && homeserver.host.isNotEmpty) return homeserver.host;
  return 'p2p-im.com';
}

Future<void> _copyUidUrl(BuildContext context, String uidUrl) async {
  await Clipboard.setData(ClipboardData(text: uidUrl));
  if (!context.mounted) return;
  final l10n = _profileInfoL10n(context);
  showCenterToast(context, l10n?.profileInfoUidCopied ?? '已复制 UID');
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = _profileInfoL10n(context);
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
              l10n?.profileInfoTitle ?? '我的信息',
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
    required this.editLabel,
    required this.seed,
    required this.onTap,
  });

  final bool avatarBusy;
  final String? avatarUrl;
  final String editLabel;
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
                            editLabel,
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

class _GenderPickerSheet extends StatelessWidget {
  const _GenderPickerSheet({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = _profileInfoL10n(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _GenderOptionButton(
                    label: l10n?.profileInfoGenderMale ?? '男',
                    selected: value == '男',
                    onTap: () => Navigator.of(context).pop('男'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GenderOptionButton(
                    label: l10n?.profileInfoGenderFemale ?? '女',
                    selected: value == '女',
                    onTap: () => Navigator.of(context).pop('女'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: t.textMute,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  l10n?.commonCancel ?? '取消',
                  style: AppTheme.sans(size: 15, color: t.textMute),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderOptionButton extends StatelessWidget {
  const _GenderOptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: selected ? t.accent : t.surfaceHover,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              label,
              style: AppTheme.sans(
                size: 15,
                weight: FontWeight.w600,
                color: selected ? t.onAccent : t.text,
              ),
            ),
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
    required this.unsetLabel,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final String value;
  final String unsetLabel;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final cleanValue = _emptyIfUnset(value).trim();
    final displayValue = cleanValue.isEmpty ? unsetLabel : cleanValue;
    final muted = displayValue == unsetLabel;
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

class _ProfileUidCard extends StatelessWidget {
  const _ProfileUidCard({
    required this.uid,
    required this.onTap,
  });

  final String uid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                      'UID',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 14,
                        weight: FontWeight.w500,
                        color: t.textMute,
                      ),
                    ),
                    Text(
                      'UID: $uid',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        size: 16,
                        weight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Symbols.content_copy, size: 20, color: t.textMute),
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

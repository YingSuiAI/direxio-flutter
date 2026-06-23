// 创建账号页 —— 沿用 s-login 的 M3 视觉语言。
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/as_client_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/avatar_adjust_sheet.dart';

class InitPage extends ConsumerStatefulWidget {
  const InitPage({super.key});

  @override
  ConsumerState<InitPage> createState() => _InitPageState();
}

class _InitPageState extends ConsumerState<InitPage> {
  final _domainCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _portalTokenCtrl = TextEditingController();
  final _confirmPortalTokenCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _weakHint;
  Uint8List? _avatarBytes;

  @override
  void dispose() {
    _domainCtrl.dispose();
    _displayNameCtrl.dispose();
    _portalTokenCtrl.dispose();
    _confirmPortalTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
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
        setState(() {
          _avatarBytes = adjustedBytes;
          _weakHint = null;
        });
      },
    );
  }

  Future<String> _uploadSelectedAvatar() async {
    final bytes = _avatarBytes;
    if (bytes == null) return '';
    final client = ref.read(matrixClientProvider);
    final userId = client.userID?.trim() ?? '';
    if (userId.isEmpty) return '';
    final uploaded = await client.uploadContent(
      bytes,
      filename: 'avatar.png',
      contentType: 'image/png',
    );
    await client.setAvatarUrl(userId, uploaded);
    return uploaded.toString();
  }

  Future<void> _register() async {
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final auth = ref.read(authStateNotifierProvider).valueOrNull;
    final isLoggedIn = auth?.isLoggedIn == true;
    final domain = _domainCtrl.text.trim();
    final displayName = _displayNameCtrl.text.trim();
    final portalToken = _portalTokenCtrl.text.trim();
    final confirmPortalToken = _confirmPortalTokenCtrl.text.trim();
    if (_avatarBytes == null) {
      setState(() {
        _weakHint = null;
        _error = null;
      });
      _showCenterWeakHint(context, l10n?.initAvatarRequired ?? '请设置头像');
      return;
    }
    if (!isLoggedIn && domain.isEmpty) {
      setState(() {
        _weakHint = l10n?.initPortalDomainRequired ?? '请填写 Portal 域名';
        _error = null;
      });
      return;
    }
    if (displayName.isEmpty) {
      setState(() {
        _weakHint = l10n?.initDisplayNameRequired ?? '请填写用户昵称';
        _error = null;
      });
      return;
    }
    if (portalToken.isEmpty) {
      setState(() {
        _weakHint = l10n?.initOwnerTokenRequired ?? '请填写长期登录口令';
        _error = null;
      });
      return;
    }
    if (confirmPortalToken.isEmpty) {
      setState(() {
        _weakHint = l10n?.initConfirmOwnerTokenRequired ?? '请再次输入长期登录口令';
        _error = null;
      });
      return;
    }
    if (portalToken.length < 8) {
      setState(() {
        _weakHint = l10n?.initPasswordTooShort ?? '密码至少 8 位';
        _error = null;
      });
      return;
    }
    if (portalToken != confirmPortalToken) {
      setState(() {
        _weakHint = l10n?.initPasswordMismatch ?? '两次输入的密码不一致';
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _weakHint = null;
    });
    try {
      if (isLoggedIn) {
        final avatarUrl = await _uploadSelectedAvatar();
        await ref
            .read(authStateNotifierProvider.notifier)
            .completeOwnerProfileSetup(
              displayName: displayName,
              newPortalToken: portalToken,
              avatarUrl: avatarUrl,
            );
        final userId = ref.read(matrixClientProvider).userID ?? auth?.userId;
        if (userId != null && userId.trim().isNotEmpty) {
          await cacheCurrentUserProfile(
            ref,
            userId: userId,
            displayName: displayName,
            avatarUrl: avatarUrl,
          );
        }
        if (mounted) context.go('/home');
      } else {
        await ref.read(authStateNotifierProvider.notifier).register(
              domain,
              portalToken,
              displayName,
            );
        final avatarUrl = await _uploadSelectedAvatar();
        await ref.read(asClientProvider).updateOwnerProfile(
              displayName: displayName,
              avatarUrl: avatarUrl,
            );
        final userId = ref.read(matrixClientProvider).userID;
        if (userId != null && userId.trim().isNotEmpty) {
          await cacheCurrentUserProfile(
            ref,
            userId: userId,
            displayName: displayName,
            avatarUrl: avatarUrl,
          );
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const pageTokens = PortalTokens.dark;
    final auth = ref.watch(authStateNotifierProvider).valueOrNull;
    final isLoggedIn = auth?.isLoggedIn ?? false;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return Scaffold(
      backgroundColor: pageTokens.surface,
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                pageTokens.primaryContainer,
                pageTokens.surface,
                pageTokens.surface,
              ],
              stops: const [0, 0.28, 1],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(19, 62, 19, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 420,
                      minHeight: constraints.maxHeight - 92,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: _InitAvatarPicker(
                            imageBytes: _avatarBytes,
                            onTap: _loading ? null : _pickAvatar,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Direxio',
                          textAlign: TextAlign.center,
                          style: AppTheme.sans(
                            size: 24,
                            weight: FontWeight.w700,
                            color: pageTokens.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n?.loginSubtitle ?? '使用你的Portal域名和密码进入去中心化通讯空间',
                          textAlign: TextAlign.center,
                          style: AppTheme.sans(
                            size: 12,
                            color: pageTokens.accent,
                          ),
                        ),
                        const SizedBox(height: 44),
                        if (!isLoggedIn) ...[
                          _InitPillInputField(
                            controller: _domainCtrl,
                            icon: Symbols.link,
                            hint: l10n?.initPortalDomainHint ?? 'Portal 域名',
                            keyboardType: TextInputType.url,
                            tokens: pageTokens,
                          ),
                          const SizedBox(height: 15),
                        ],
                        _InitPillInputField(
                          controller: _displayNameCtrl,
                          icon: Symbols.person,
                          hint: l10n?.initDisplayNameHint ?? '用户昵称',
                          tokens: pageTokens,
                          onChanged: (_) => _clearWeakHint(),
                        ),
                        const SizedBox(height: 15),
                        _InitPillInputField(
                          controller: _portalTokenCtrl,
                          icon: Symbols.lock,
                          hint: isLoggedIn
                              ? l10n?.initOwnerTokenHint ?? '长期登录口令'
                              : l10n?.initPasswordHint ?? '登录密码',
                          obscure: _obscure,
                          onSubmitted: (_) => _register(),
                          onChanged: (_) => _clearWeakHint(),
                          tokens: pageTokens,
                          trailing: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Symbols.visibility
                                  : Symbols.visibility_off,
                              size: 22,
                              color: pageTokens.text,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        const SizedBox(height: 15),
                        _InitPillInputField(
                          controller: _confirmPortalTokenCtrl,
                          icon: Symbols.verified_user,
                          hint: isLoggedIn
                              ? l10n?.initConfirmOwnerTokenHint ?? '再次输入长期登录口令'
                              : l10n?.initConfirmPasswordHint ?? '再次输入登录密码',
                          obscure: _obscure,
                          onSubmitted: (_) => _register(),
                          onChanged: (_) => _clearWeakHint(),
                          tokens: pageTokens,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n?.initPasswordRule ?? '密码至少8位',
                          style: AppTheme.sans(
                            size: 12,
                            color: pageTokens.textMute,
                          ),
                        ),
                        if (_weakHint != null) ...[
                          const SizedBox(height: 8),
                          _WeakHint(message: _weakHint!),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _ErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 53,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: pageTokens.accent,
                              foregroundColor: pageTokens.onAccent,
                              disabledBackgroundColor:
                                  pageTokens.accent.withValues(alpha: 0.55),
                              disabledForegroundColor:
                                  pageTokens.onAccent.withValues(alpha: 0.75),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: AppTheme.sans(
                                size: 16,
                                weight: FontWeight.w600,
                                color: pageTokens.onAccent,
                              ),
                            ),
                            onPressed: _loading ? null : _register,
                            child: Text(
                              _loading
                                  ? l10n?.initButtonLoading ?? '初始化中…'
                                  : l10n?.initButton ?? '确认',
                            ),
                          ),
                        ),
                        const SizedBox(height: 166),
                        if (!isLoggedIn) ...[
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: Text(
                              l10n?.initExistingAccountLogin ?? '已有账号？登录',
                              style: AppTheme.sans(
                                size: 15,
                                color: pageTokens.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _clearWeakHint() {
    if (_weakHint == null) return;
    setState(() => _weakHint = null);
  }
}

class _InitAvatarPicker extends StatelessWidget {
  const _InitAvatarPicker({
    required this.imageBytes,
    required this.onTap,
  });

  final Uint8List? imageBytes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const pageTokens = PortalTokens.dark;
    if (imageBytes == null) {
      return GestureDetector(
        onTap: onTap,
        child: SizedBox(
          key: const ValueKey('init_avatar_placeholder_frame'),
          width: 96,
          height: 97,
          child: Image.asset(
            'assets/images/2d-logo.png',
            key: const ValueKey('init_avatar_placeholder_asset'),
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pageTokens.surface.withValues(alpha: 0.92),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(
                  imageBytes!,
                  key: const ValueKey('init_avatar_preview'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 8,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: pageTokens.textMute,
                  shape: BoxShape.circle,
                  border: Border.all(color: pageTokens.surface, width: 2),
                ),
                child: Icon(
                  Symbols.photo_camera,
                  size: 17,
                  fill: 1,
                  color: pageTokens.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitPillInputField extends StatelessWidget {
  const _InitPillInputField({
    required this.controller,
    required this.icon,
    required this.hint,
    required this.tokens,
    this.obscure = false,
    this.keyboardType,
    this.trailing,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final PortalTokens tokens;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 53,
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: tokens.accent),
        boxShadow: [
          BoxShadow(
            color: tokens.surface.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Icon(icon, size: 24, color: tokens.accent),
          Container(
            width: 1,
            height: 25,
            margin: const EdgeInsets.only(left: 17, right: 12),
            color: tokens.text,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              style: AppTheme.sans(size: 16, color: tokens.text),
              cursorColor: tokens.text,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTheme.sans(
                  size: 16,
                  color: tokens.text.withValues(alpha: 0.58),
                ),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          if (trailing != null) trailing!,
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _WeakHint extends StatelessWidget {
  const _WeakHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    const pageTokens = PortalTokens.dark;
    return Text(
      key: const ValueKey('init_inline_weak_hint'),
      message,
      style: AppTheme.sans(
        size: 12,
        color: pageTokens.accent.withValues(alpha: 0.9),
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
            key: const ValueKey('init_center_weak_hint'),
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: t.text.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: t.text.withValues(alpha: 0.18),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.error, size: 16, color: t.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTheme.sans(size: 13, color: t.danger),
            ),
          ),
        ],
      ),
    );
  }
}

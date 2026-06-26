import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/local_login_domain_hint.dart';
import '../../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

/// 登录页 —— 对齐 Agent P2P 设计稿 s-login。
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _domainCtrl = TextEditingController();
  final _portalTokenCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _agreed = false;
  bool _guideOpen = false;
  String? _error;
  String? _domainHint;

  @override
  void initState() {
    super.initState();
    _domainCtrl.addListener(_refreshDomainHint);
    _loadLastLogin();
  }

  void _refreshDomainHint() {
    final hint = localLoginDomainHintFor(_domainCtrl.text);
    final next = hint?.recommendedAuthority;
    if (_domainHint == next) return;
    setState(() => _domainHint = next);
  }

  Future<void> _loadLastLogin() async {
    // ?hs= URL param overrides storage (useful for testing)
    final hsParam = Uri.base.queryParameters['hs'];
    if (hsParam != null && hsParam.isNotEmpty) {
      if (mounted) _domainCtrl.text = _withoutScheme(hsParam);
      return;
    }
    const storage = FlutterSecureStorage();
    final hs =
        await storage.read(key: AuthStateNotifier.lastLoginHomeserverKey) ??
            await storage.read(key: 'matrix_homeserver');
    final portalToken =
        await storage.read(key: AuthStateNotifier.lastLoginPortalTokenKey);
    if (!mounted) return;
    if (hs != null) {
      final uri = Uri.tryParse(hs);
      final authority = uri?.hasAuthority == true ? uri!.authority : '';
      if (authority.isNotEmpty) {
        _domainCtrl.text = authority;
      }
    }
    if (portalToken != null && portalToken.trim().isNotEmpty) {
      _portalTokenCtrl.text = portalToken.trim();
    }
  }

  @override
  void dispose() {
    _domainCtrl.removeListener(_refreshDomainHint);
    _domainCtrl.dispose();
    _portalTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (_loading) return;
    if (_agreed) {
      await _login();
      return;
    }
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.loginAgreementRequiredTitle ?? '请先阅读并同意'),
        content: Text(
          l10n?.loginAgreementRequiredMessage ?? '登录前需要同意用户协议与隐私条款。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n?.commonCancel ?? '取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n?.loginAgreementConfirmAndLogin ?? '同意并登录'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _agreed = true);
    await _login();
  }

  Future<void> _login() async {
    final localDomainHint = localLoginDomainHintFor(_domainCtrl.text);
    if (localDomainHint != null) {
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      final recommendedAuthority = localDomainHint.recommendedAuthority;
      setState(() {
        _error = l10n?.loginLocalMatrixApiPortError(recommendedAuthority) ??
            '本地三节点测试请使用 $recommendedAuthority，'
                '不要填写 127.0.0.1 的 Matrix API 端口。';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authStateNotifierProvider.notifier)
          .login(_withHttpsPrefix(_domainCtrl.text), _portalTokenCtrl.text);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openLegalUrl(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!opened && mounted) {
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.loginTermsOpenFailed ?? '无法打开用户协议与隐私条款',
          ),
        ),
      );
    }
  }

  Future<void> _showGettingStartedGuide() async {
    if (_guideOpen) return;
    const loginTokens = PortalTokens.dark;
    setState(() => _guideOpen = true);
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).closeButtonLabel,
        barrierColor: loginTokens.surface.withValues(alpha: 0.7),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => const _GettingStartedGuideDialog(
          tokens: loginTokens,
        ),
        transitionBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _guideOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const loginTokens = PortalTokens.dark;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return Scaffold(
      backgroundColor: loginTokens.surface,
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                loginTokens.primaryContainer,
                loginTokens.surface,
                loginTokens.surface,
              ],
              stops: const [0, 0.28, 1],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(19, 62, 19, 80),
                child: Column(
                  children: [
                    const _DirexioLogoMark(),
                    const SizedBox(height: 12),
                    Text(
                      'Direxio',
                      style: AppTheme.sans(
                        size: 24,
                        weight: FontWeight.w700,
                        color: loginTokens.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n?.loginSubtitle ?? '使用你的Portal域名和密码进入去中心化通讯空间',
                      textAlign: TextAlign.center,
                      style: AppTheme.sans(size: 12, color: loginTokens.accent),
                    ),
                    const SizedBox(height: 44),
                    _LoginPillInputField(
                      controller: _domainCtrl,
                      icon: Symbols.link,
                      hint: l10n?.loginDomainHint ?? '你的域名',
                      keyboardType: TextInputType.url,
                      tokens: loginTokens,
                    ),
                    if (_domainHint != null) ...[
                      const SizedBox(height: 8),
                      _LocalDomainHintBanner(
                        message: l10n?.loginLocalMatrixApiPortHint(
                              _domainHint!,
                            ) ??
                            '本地三节点测试请填写 ${_domainHint!}',
                      ),
                    ],
                    const SizedBox(height: 15),
                    _LoginPillInputField(
                      controller: _portalTokenCtrl,
                      icon: Symbols.lock,
                      hint: l10n?.loginPasswordHint ?? '登录密码',
                      obscure: _obscure,
                      onSubmitted: (_) => _submitLogin(),
                      tokens: loginTokens,
                      trailing: IconButton(
                        icon: Icon(
                          _obscure
                              ? Symbols.visibility
                              : Symbols.visibility_off,
                          size: 22,
                          color: loginTokens.text,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 45),
                    SizedBox(
                      width: double.infinity,
                      height: 53,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: loginTokens.accent,
                          foregroundColor: loginTokens.onAccent,
                          disabledBackgroundColor:
                              loginTokens.accent.withValues(alpha: 0.55),
                          disabledForegroundColor:
                              loginTokens.onAccent.withValues(alpha: 0.75),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: AppTheme.sans(
                            size: 16,
                            weight: FontWeight.w600,
                            color: loginTokens.onAccent,
                          ),
                        ),
                        onPressed: _loading ? null : _submitLogin,
                        child: Text(
                          _loading
                              ? l10n?.loginButtonLoading ?? '登录中…'
                              : l10n?.loginButton ?? '登录',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: loginTokens.accent,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: AppTheme.sans(
                          size: 14,
                          weight: FontWeight.w600,
                          color: loginTokens.accent,
                        ),
                      ),
                      onPressed: _showGettingStartedGuide,
                      child: Text(
                        _guideOpen
                            ? l10n?.loginProductOverview ?? 'Product Overview'
                            : l10n?.loginGettingStartedGuide ??
                                'Getting Started Guide',
                      ),
                    ),
                    const SizedBox(height: 175),
                    _LoginAgreementLine(
                      agreed: _agreed,
                      tokens: loginTokens,
                      onToggle: () => setState(() => _agreed = !_agreed),
                      onTermsTap: () => _openLegalUrl(
                        'https://www.direxio.ai/legal/terms/',
                      ),
                      onPrivacyTap: () => _openLegalUrl(
                        'https://www.direxio.ai/legal/privacy-policy/',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GettingStartedGuideDialog extends StatelessWidget {
  const _GettingStartedGuideDialog({required this.tokens});

  final PortalTokens tokens;

  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final size = MediaQuery.sizeOf(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 315,
              maxHeight: size.height - 80,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      tokens.primaryContainer,
                      tokens.surface,
                    ],
                    stops: const [0, 0.78],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GuideIllustration(tokens: tokens),
                        const SizedBox(height: 16),
                        _GuideParagraph(
                          text: l10n?.loginGuideIntroPrimary ??
                              'Before your first use, prepare a functional AI Agent (such as Codex, OpenClaw, Hermes), along with cloud accounts and a domain name required for deployment.\nSend your Agent the repository address for the Direxio deployment skill:https://github.com/YingSuiAI/direxio-deployer',
                          tokens: tokens,
                        ),
                        const SizedBox(height: 8),
                        _GuideParagraph(
                          text: l10n?.loginGuideIntroSecondary ??
                              'so it can automatically complete installation, deployment, domain binding and plugin configuration following the standard workflow.\nOnce deployment succeeds, your Agent will return your IM access URL, initial account and password.\nAfter receiving these details, return to this App and enter the server address and password to sign in.\nOfficial Website: direxio.ai',
                          tokens: tokens,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideIllustration extends StatelessWidget {
  const _GuideIllustration({required this.tokens});

  final PortalTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 199,
      height: 169,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 169,
            height: 169,
            decoration: BoxDecoration(
              color: tokens.surface.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: tokens.onPrimaryContainer.withValues(alpha: 0.18),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Image.asset(
              'assets/images/2d-logo.png',
              width: 151,
              height: 151,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 11,
            right: 0,
            child: Container(
              height: 33,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: tokens.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: tokens.onPrimaryContainer.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.smart_toy,
                    size: 16,
                    color: tokens.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'AI',
                    style: AppTheme.sans(
                      size: 13,
                      weight: FontWeight.w700,
                      color: tokens.onPrimaryContainer,
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
}

class _GuideParagraph extends StatelessWidget {
  const _GuideParagraph({
    required this.text,
    required this.tokens,
  });

  final String text;
  final PortalTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.sans(
        size: 14,
        weight: FontWeight.w600,
        color: tokens.onPrimaryContainer,
      ).copyWith(height: 1.42),
    );
  }
}

class _LoginAgreementLine extends StatelessWidget {
  const _LoginAgreementLine({
    required this.agreed,
    required this.tokens,
    required this.onToggle,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  final bool agreed;
  final PortalTokens tokens;
  final VoidCallback onToggle;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: onToggle,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              agreed ? Symbols.check_circle : Symbols.radio_button_unchecked,
              size: 16,
              color: agreed ? tokens.accent : tokens.textMute,
              fill: agreed ? 1 : 0,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          l10n?.agreementPrefix ?? '阅读并同意',
          style: AppTheme.sans(size: 12, color: tokens.textMute),
        ),
        InkWell(
          onTap: onTermsTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n?.agreementTerms ?? '《用户协议》',
              style: AppTheme.sans(size: 12, color: tokens.text),
            ),
          ),
        ),
        InkWell(
          onTap: onPrivacyTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n?.agreementPrivacy ?? '《隐私条款》',
              style: AppTheme.sans(size: 12, color: tokens.text),
            ),
          ),
        ),
      ],
    );
  }
}

class _DirexioLogoMark extends StatelessWidget {
  const _DirexioLogoMark();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(27),
      child: Image.asset(
        'assets/images/logo.png',
        key: const ValueKey('login_logo_asset'),
        width: 96,
        height: 96,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _LoginPillInputField extends StatelessWidget {
  const _LoginPillInputField({
    required this.controller,
    required this.icon,
    required this.hint,
    required this.tokens,
    this.obscure = false,
    this.keyboardType,
    this.trailing,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final PortalTokens tokens;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final ValueChanged<String>? onSubmitted;

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

class _LocalDomainHintBanner extends StatelessWidget {
  const _LocalDomainHintBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.surfaceHigh.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.info, size: 16, color: t.accentCool),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTheme.sans(size: 13, color: t.text),
            ),
          ),
        ],
      ),
    );
  }
}

String _withHttpsPrefix(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(trimmed);
  return hasScheme ? trimmed : 'https://$trimmed';
}

String _withoutScheme(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasAuthority) return uri.authority;
  return trimmed.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://'), '');
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

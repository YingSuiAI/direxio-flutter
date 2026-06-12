import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/m3/m3_card.dart';

/// 登录页 —— 对齐 Agent P2P 设计稿 s-login。
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _domainCtrl = TextEditingController(text: 'https://');
  final _portalTokenCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLastLogin();
  }

  Future<void> _loadLastLogin() async {
    // ?hs= URL param overrides storage (useful for testing)
    final hsParam = Uri.base.queryParameters['hs'];
    if (hsParam != null && hsParam.isNotEmpty) {
      if (mounted) setState(() => _domainCtrl.text = _withHttpsPrefix(hsParam));
      return;
    }
    const storage = FlutterSecureStorage();
    final hs =
        await storage.read(key: AuthStateNotifier.lastLoginHomeserverKey) ??
            await storage.read(key: 'matrix_homeserver');
    final portalToken =
        await storage.read(key: AuthStateNotifier.lastLoginPortalTokenKey) ??
            await storage.read(key: 'portal_token');
    if (!mounted) return;
    if (hs != null) {
      final uri = Uri.tryParse(hs);
      final authority = uri?.hasAuthority == true ? uri!.authority : '';
      if (authority.isNotEmpty) {
        final scheme = uri!.scheme.isNotEmpty ? uri.scheme : 'https';
        setState(() => _domainCtrl.text = '$scheme://$authority');
      }
    }
    if (portalToken != null && portalToken.trim().isNotEmpty) {
      setState(() => _portalTokenCtrl.text = portalToken.trim());
    }
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    _portalTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authStateNotifierProvider.notifier)
          .login(_domainCtrl.text.trim(), _portalTokenCtrl.text);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              child: Column(
                children: [
                  // App icon — squircle 112
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: t.primaryContainer,
                      borderRadius: BorderRadius.circular(112 * 0.225),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Symbols.communication,
                      size: 56,
                      color: t.onPrimaryContainer,
                      fill: 1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n?.loginTitle ?? 'Portal IM',
                    style: AppTheme.sans(
                      size: 28,
                      weight: FontWeight.w700,
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.loginSubtitle ?? '使用你的 Portal 域名和密码进入去中心化通讯空间',
                    style: AppTheme.sans(size: 12, color: t.textMute),
                  ),
                  const SizedBox(height: 40),

                  // Portal 地址
                  M3InputField(
                    controller: _domainCtrl,
                    icon: Symbols.link,
                    hint: l10n?.loginDomainHint ?? 'https://你的域名',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  // Portal Token
                  M3InputField(
                    controller: _portalTokenCtrl,
                    icon: Symbols.key,
                    hint: l10n?.loginPasswordHint ?? '登录密码',
                    obscure: _obscure,
                    onSubmitted: (_) => _login(),
                    trailing: IconButton(
                      icon: Icon(
                        _obscure ? Symbols.visibility : Symbols.visibility_off,
                        size: 16,
                        color: t.textMute,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: _error!),
                  ],

                  const SizedBox(height: 40),
                  M3PrimaryButton(
                    label: _loading
                        ? l10n?.loginButtonLoading ?? '登录中…'
                        : l10n?.loginButton ?? '登录',
                    onPressed: _loading ? null : _login,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _withHttpsPrefix(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'https://';
  final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(trimmed);
  return hasScheme ? trimmed : 'https://$trimmed';
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

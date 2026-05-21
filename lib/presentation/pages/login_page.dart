import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
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
  final _domainCtrl = TextEditingController(
    text: 'https://liyananp2p.com',
  );
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLastDomain();
  }

  Future<void> _loadLastDomain() async {
    // ?hs= URL param overrides storage (useful for testing)
    final hsParam = Uri.base.queryParameters['hs'];
    if (hsParam != null && hsParam.isNotEmpty) {
      if (mounted) setState(() => _domainCtrl.text = hsParam);
      return;
    }
    const storage = FlutterSecureStorage();
    final hs = await storage.read(key: 'matrix_homeserver');
    if (hs != null && mounted) {
      final host = Uri.tryParse(hs)?.host ?? '';
      if (host.isNotEmpty) setState(() => _domainCtrl.text = host);
    }
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    _passwordCtrl.dispose();
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
          .login(_domainCtrl.text.trim(), _passwordCtrl.text);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
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
                    'Agent P2P',
                    style: AppTheme.sans(
                      size: 28,
                      weight: FontWeight.w700,
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '去中心化 · 端对端加密 · 安全通讯',
                    style: AppTheme.sans(size: 15, color: t.textMute),
                  ),
                  const SizedBox(height: 40),

                  // Portal 地址
                  M3InputField(
                    controller: _domainCtrl,
                    icon: Symbols.link,
                    hint: 'Portal 地址',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  // 密码
                  M3InputField(
                    controller: _passwordCtrl,
                    icon: Symbols.lock,
                    hint: '密码',
                    obscure: _obscure,
                    onSubmitted: (_) => _login(),
                    trailing: IconButton(
                      icon: Icon(
                        _obscure ? Symbols.visibility : Symbols.visibility_off,
                        size: 20,
                        color: t.textMute,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: _error!),
                  ],

                  const SizedBox(height: 12),
                  M3PrimaryButton(
                    label: _loading ? '登录中…' : '登录',
                    onPressed: _loading ? null : _login,
                  ),

                  const SizedBox(height: 24),
                  // 「或」分割线
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: t.border.withValues(alpha: 0.4)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '或',
                          style: AppTheme.sans(size: 15, color: t.textMute),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: t.border.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => context.go('/init'),
                    child: Text(
                      '注册新账号',
                      style: AppTheme.sans(size: 15, color: t.accent),
                    ),
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

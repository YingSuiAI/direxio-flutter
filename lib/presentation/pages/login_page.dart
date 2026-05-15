import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _domainCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLastDomain();
  }

  Future<void> _loadLastDomain() async {
    const storage = FlutterSecureStorage();
    final hs = await storage.read(key: 'matrix_homeserver');
    if (hs != null && mounted && _domainCtrl.text.isEmpty) {
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Wordmark
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: t.accent.withValues(alpha: 0.4),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(LucideIcons.message_square,
                            size: 16, color: t.accent),
                      ),
                      const SizedBox(width: 10),
                      Text('Portal IM', style: AppTheme.mono(
                          size: 17, weight: FontWeight.w700, color: t.text)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('去中心化 P2P 通讯',
                      style: AppTheme.sans(size: 13, color: t.textMute)),

                  const SizedBox(height: 48),

                  _Label(text: '域名'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _domainCtrl,
                    decoration: const InputDecoration(
                      hintText: 'liyananp2p.com',
                    ),
                    style: AppTheme.mono(size: 14, color: t.text),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                  ),

                  const SizedBox(height: 16),
                  _Label(text: '密码'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(hintText: '••••••••'),
                    style: AppTheme.sans(size: 14, color: t.text),
                    obscureText: true,
                    onSubmitted: (_) => _login(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: t.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: t.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.circle_alert,
                              size: 14, color: t.danger),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: AppTheme.mono(
                                    size: 12, color: t.danger)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(t.bg),
                            ),
                          )
                        : const Text('登录'),
                  ),

                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/init'),
                    child: const Text('首次使用？创建 Portal 账号 →'),
                  ),

                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: t.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.info,
                            size: 14, color: t.accentCool),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('域名即是你的身份',
                                  style: AppTheme.sans(
                                      size: 12,
                                      color: t.text,
                                      weight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                '每个 Portal 一台 server，登录用自己控制的域名。\n例：',
                                style: AppTheme.sans(
                                    size: 12, color: t.textMute),
                              ),
                              Text('liyananp2p.com',
                                  style: AppTheme.mono(
                                      size: 12, color: t.accentCool)),
                            ],
                          ),
                        ),
                      ],
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

class _Label extends StatelessWidget {
  const _Label({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.sans(
          size: 12, color: context.tk.textMute, weight: FontWeight.w500),
    );
  }
}

/// 创建账号页 —— 沿用 s-login 的 M3 视觉语言。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';

class InitPage extends ConsumerStatefulWidget {
  const InitPage({super.key});

  @override
  ConsumerState<InitPage> createState() => _InitPageState();
}

class _InitPageState extends ConsumerState<InitPage> {
  final _domainCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _domainCtrl.dispose();
    _displayNameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authStateNotifierProvider.notifier)
          .register(
            _domainCtrl.text.trim(),
            _passwordCtrl.text,
            _displayNameCtrl.text.trim(),
          );
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
      body: Column(
        children: [
          GlassHeader.detail(title: '创建账号', onBack: () => context.go('/login')),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: t.primaryContainer,
                          borderRadius: BorderRadius.circular(96 * 0.225),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Symbols.person_add,
                          size: 48,
                          color: t.onPrimaryContainer,
                          fill: 1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '创建你的 Portal 账号',
                        textAlign: TextAlign.center,
                        style: AppTheme.sans(
                          size: 20,
                          weight: FontWeight.w700,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '域名须是你控制、已部署 homeserver 的服务器',
                        textAlign: TextAlign.center,
                        style: AppTheme.sans(size: 13, color: t.textMute),
                      ),
                      const SizedBox(height: 28),
                      M3InputField(
                        controller: _domainCtrl,
                        icon: Symbols.link,
                        hint: 'Portal 域名',
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 12),
                      M3InputField(
                        controller: _displayNameCtrl,
                        icon: Symbols.person,
                        hint: '显示名称',
                      ),
                      const SizedBox(height: 12),
                      M3InputField(
                        controller: _passwordCtrl,
                        icon: Symbols.lock,
                        hint: '密码',
                        obscure: _obscure,
                        onSubmitted: (_) => _register(),
                        trailing: IconButton(
                          icon: Icon(
                            _obscure
                                ? Symbols.visibility
                                : Symbols.visibility_off,
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
                      const SizedBox(height: 20),
                      M3PrimaryButton(
                        label: _loading ? '创建中…' : '创建账号',
                        onPressed: _loading ? null : _register,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text(
                          '已有账号？登录',
                          style: AppTheme.sans(size: 15, color: t.accent),
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

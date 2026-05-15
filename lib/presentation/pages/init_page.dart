import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

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
  String? _error;

  @override
  void dispose() {
    _domainCtrl.dispose();
    _displayNameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authStateNotifierProvider.notifier).register(
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('创建账号')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('你的 Portal 域名',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('必须是你控制的服务器域名，已部署 continuwuity',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              TextField(
                controller: _domainCtrl,
                decoration: const InputDecoration(
                  labelText: '域名',
                  hintText: 'liyananp2p.com',
                  prefixIcon: Icon(Icons.language),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _displayNameCtrl,
                decoration: const InputDecoration(
                  labelText: '显示名称',
                  hintText: '施歌',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(
                  labelText: '密码',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: cs.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('创建账号'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('已有账号？登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

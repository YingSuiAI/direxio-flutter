import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_list_tile.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';

/// `s-me-account` — 账号与安全 (index.html L1167-1224)
class MeAccountPage extends StatefulWidget {
  const MeAccountPage({super.key});

  @override
  State<MeAccountPage> createState() => _MeAccountPageState();
}

class _MeAccountPageState extends State<MeAccountPage> {
  bool _biometric = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(title: '账号与安全'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 32),
              child: _GroupedCard(
                children: [
                  _IconChevronRow(
                    icon: Symbols.shield_person,
                    label: '账号安全',
                    onTap: () {},
                  ),
                  _Divider(),
                  _IconChevronRow(
                    icon: Symbols.key,
                    label: '修改密码',
                    onTap: () => context.push('/me/account/password'),
                  ),
                  _Divider(),
                  _IconSwitchRow(
                    icon: Symbols.fingerprint,
                    label: '生物识别解锁',
                    value: _biometric,
                    onChanged: (v) => setState(() => _biometric = v),
                  ),
                  _Divider(),
                  _IconChevronRow(
                    icon: Symbols.lock,
                    label: '隐私设置',
                    onTap: () {},
                  ),
                  _Divider(),
                  _IconChevronRow(
                    icon: Symbols.devices,
                    label: '已登录设备',
                    trailingText: '2 台',
                    onTap: () {},
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

class ChangePortalTokenPage extends ConsumerStatefulWidget {
  const ChangePortalTokenPage({super.key});

  @override
  ConsumerState<ChangePortalTokenPage> createState() =>
      _ChangePortalTokenPageState();
}

class _ChangePortalTokenPageState extends ConsumerState<ChangePortalTokenPage> {
  final _tokenCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final token = _tokenCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (token != confirm) {
        throw ArgumentError('两次输入不一致');
      }
      await ref.read(authStateNotifierProvider.notifier).changePortalToken(
            token,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录口令已更新')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = e.toString().replaceFirst('Invalid argument: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(title: '修改密码'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      M3InputField(
                        controller: _tokenCtrl,
                        icon: Symbols.key,
                        hint: '新登录口令',
                        obscure: _obscure,
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
                      const SizedBox(height: 12),
                      M3InputField(
                        controller: _confirmCtrl,
                        icon: Symbols.check,
                        hint: '确认新登录口令',
                        obscure: _obscure,
                        onSubmitted: (_) => _loading ? null : _save(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 16),
                      M3PrimaryButton(
                        label: _loading ? '保存中…' : '保存',
                        onPressed: _loading ? null : _save,
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
      child: Text(
        message,
        style: AppTheme.sans(size: 13, color: t.danger),
      ),
    );
  }
}

class _GroupedCard extends StatelessWidget {
  const _GroupedCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// 行：左侧 32 圆角图标方块（中性底 + 中性图标）+ 标签 + 右侧文本/箭头。
class _IconChevronRow extends StatelessWidget {
  const _IconChevronRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return GlassListTile(
      leading: GlassListIcon(icon: icon),
      title: label,
      trailingText: trailingText,
      onTap: onTap,
    );
  }
}

class _IconSwitchRow extends StatelessWidget {
  const _IconSwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return GlassListTile(
      leading: GlassListIcon(icon: icon),
      title: label,
      showChevron: false,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: t.accent,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: t.secondaryContainer,
      ),
    );
  }
}

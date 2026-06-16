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
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _oldObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _clearErrorOnEdit(String _) {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _save() async {
    if (_loading) return;
    final oldPassword = _oldCtrl.text.trim();
    final newPassword = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (oldPassword.length < 8) {
      setState(() => _error = '原密码至少 8 位');
      return;
    }
    if (newPassword.length < 8) {
      setState(() => _error = '新密码至少 8 位');
      return;
    }
    if (newPassword != confirm) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authStateNotifierProvider.notifier).changePortalPassword(
            oldPassword: oldPassword,
            newPassword: newPassword,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码已修改')),
      );
      context.go('/settings');
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
      backgroundColor: t.surfaceHover,
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
                        controller: _oldCtrl,
                        icon: Symbols.key,
                        hint: '原密码',
                        obscure: _oldObscure,
                        autofocus: true,
                        onChanged: _clearErrorOnEdit,
                        trailing: IconButton(
                          icon: Icon(
                            _oldObscure
                                ? Symbols.visibility
                                : Symbols.visibility_off,
                            size: 20,
                            color: t.textMute,
                          ),
                          onPressed: () =>
                              setState(() => _oldObscure = !_oldObscure),
                        ),
                      ),
                      const SizedBox(height: 12),
                      M3InputField(
                        controller: _newCtrl,
                        icon: Symbols.lock_reset,
                        hint: '新密码',
                        obscure: _newObscure,
                        onChanged: _clearErrorOnEdit,
                        trailing: IconButton(
                          icon: Icon(
                            _newObscure
                                ? Symbols.visibility
                                : Symbols.visibility_off,
                            size: 20,
                            color: t.textMute,
                          ),
                          onPressed: () =>
                              setState(() => _newObscure = !_newObscure),
                        ),
                      ),
                      const SizedBox(height: 12),
                      M3InputField(
                        controller: _confirmCtrl,
                        icon: Symbols.check,
                        hint: '再次输入新密码',
                        obscure: _confirmObscure,
                        onChanged: _clearErrorOnEdit,
                        onSubmitted: (_) => _loading ? null : _save(),
                        trailing: IconButton(
                          icon: Icon(
                            _confirmObscure
                                ? Symbols.visibility
                                : Symbols.visibility_off,
                            size: 20,
                            color: t.textMute,
                          ),
                          onPressed: () => setState(
                              () => _confirmObscure = !_confirmObscure),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '密码至少 8 位',
                        style: AppTheme.sans(size: 13, color: t.textMute),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 16),
                      M3PrimaryButton(
                        label: _loading ? '提交中…' : '提交修改',
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

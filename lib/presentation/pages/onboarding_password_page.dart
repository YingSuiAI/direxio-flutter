import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/setup_payload.dart';
import '../../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/m3/glass_header.dart';
import '../widgets/m3/m3_card.dart';

class OnboardingPasswordPage extends ConsumerStatefulWidget {
  const OnboardingPasswordPage({super.key, required this.payload});

  final SetupPayload payload;

  @override
  ConsumerState<OnboardingPasswordPage> createState() =>
      _OnboardingPasswordPageState();
}

class _OnboardingPasswordPageState
    extends ConsumerState<OnboardingPasswordPage> {
  final _setupCodeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _setupCodeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final setupCode =
        widget.payload.hasCode ? widget.payload.code : _setupCodeCtrl.text;
    final password = _passwordCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    setState(() => _error = null);
    if (!SetupPayload.isValidSetupCode(setupCode)) {
      setState(() => _error = l10n?.setupInvalidCode ?? '请输入 8 位设置码');
      return;
    }
    if (password != confirm) {
      setState(() => _error = l10n?.setupPasswordMismatch ?? '两次输入的口令不一致');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref
          .read(authStateNotifierProvider.notifier)
          .bootstrapAndChangePortalToken(
            widget.payload.server.toString(),
            setupCode.trim(),
            password,
          );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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
      body: Column(
        children: [
          GlassHeader.detail(
            title: l10n?.setupPasswordTitle ?? '设置登录口令',
            onBack: () => context.go('/login'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Symbols.encrypted,
                        size: 48,
                        color: t.accent,
                        fill: 1,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.payload.server.host,
                        textAlign: TextAlign.center,
                        style: AppTheme.sans(
                          size: 20,
                          weight: FontWeight.w700,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.payload.hasCode
                            ? l10n?.setupPasswordQrCodeWillExpire ??
                                '设置后，当前二维码设置码会失效'
                            : l10n?.setupPasswordEnterCodeAndPassword ??
                                '输入该 Portal 的设置码并设置登录口令',
                        textAlign: TextAlign.center,
                        style: AppTheme.sans(size: 13, color: t.textMute),
                      ),
                      const SizedBox(height: 28),
                      if (!widget.payload.hasCode) ...[
                        M3InputField(
                          controller: _setupCodeCtrl,
                          icon: Symbols.password,
                          hint: l10n?.setupCodeHint ?? '设置码',
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      M3InputField(
                        controller: _passwordCtrl,
                        icon: Symbols.key,
                        hint: l10n?.setupNewPasswordHint ?? '新登录口令',
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
                        icon: Symbols.verified_user,
                        hint: l10n?.setupConfirmNewPasswordHint ?? '再次输入登录口令',
                        obscure: _obscure,
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 20),
                      M3PrimaryButton(
                        label: _loading
                            ? l10n?.setupPasswordSaving ?? '设置中…'
                            : l10n?.setupPasswordDone ?? '完成设置',
                        onPressed: _loading ? null : _submit,
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/setup_payload.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/m3/glass_header.dart';

class SetupScanPage extends StatefulWidget {
  const SetupScanPage({super.key});

  @override
  State<SetupScanPage> createState() => _SetupScanPageState();
}

class _SetupScanPageState extends State<SetupScanPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final payload = SetupPayload.parse(raw);
        _handled = true;
        _controller.stop();
        if (mounted) {
          context.pushReplacement('/setup/password', extra: payload);
        }
        return;
      } on FormatException catch (e) {
        if (mounted) {
          setState(() => _error = '${e.message}: ${_rawPreview(raw)}');
        }
      }
    }
  }

  void _openPassword(SetupPayload payload) {
    if (_handled) return;
    _handled = true;
    _controller.stop();
    if (mounted) {
      context.pushReplacement('/setup/password', extra: payload);
    }
  }

  Future<void> _openManualEntry() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ManualSetupSheet(
          onSubmit: (payload) {
            Navigator.of(sheetContext).pop();
            _openPassword(payload);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GlassHeader.detail(
            title: l10n?.setupScanTitle ?? '扫码添加服务器',
            onBack: () => context.go('/login'),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleCapture,
                ),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Symbols.qr_code_scanner,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error ??
                                    l10n?.setupScanHint ??
                                    '扫描 Portal 设置页上的二维码',
                                style: AppTheme.sans(
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const ValueKey('manual_setup_entry_button'),
                            onPressed: _openManualEntry,
                            icon: const Icon(Symbols.keyboard, size: 18),
                            label: Text(
                              l10n?.setupManualEntry ?? '手动输入',
                              style: AppTheme.sans(
                                size: 15,
                                weight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                              minimumSize: const Size.fromHeight(44),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _rawPreview(String raw) {
  final compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 48) return compact;
  return '${compact.substring(0, 48)}...';
}

class _ManualSetupSheet extends StatefulWidget {
  const _ManualSetupSheet({required this.onSubmit});

  final ValueChanged<SetupPayload> onSubmit;

  @override
  State<_ManualSetupSheet> createState() => _ManualSetupSheetState();
}

class _ManualSetupSheetState extends State<_ManualSetupSheet> {
  final _portalCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _portalCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _error = null);
    try {
      final payload = SetupPayload.parseManual(
        portalOrDeepLink: _portalCtrl.text,
        code: _codeCtrl.text,
      );
      widget.onSubmit(payload);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n?.setupManualTitle ?? '手动添加 Portal',
                style: AppTheme.sans(
                  size: 18,
                  weight: FontWeight.w700,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('manual_setup_portal_field'),
                controller: _portalCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Symbols.link),
                  labelText:
                      l10n?.setupManualPortalLabel ?? 'Portal URL 或二维码链接',
                  hintText: l10n?.setupManualPortalHint ??
                      'p2p-im.com 或 p2pim://setup?...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('manual_setup_code_field'),
                controller: _codeCtrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Symbols.password),
                  labelText: l10n?.setupManualCodeLabel ?? '一次性设置码',
                  hintText: l10n?.setupManualCodeHint ?? '8 位小写字母或数字',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTheme.sans(size: 13, color: t.danger),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('manual_setup_continue_button'),
                onPressed: _submit,
                child: Text(l10n?.setupManualContinue ?? '继续'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

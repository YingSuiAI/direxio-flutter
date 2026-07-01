import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../qr/qr_scan_parser.dart';
import '../widgets/center_toast.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _logQrScan('scanner init');
  }

  @override
  void dispose() {
    _logQrScan('scanner dispose handled=$_handled');
    _controller.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_handled) return;
    _logQrScan('capture barcodes=${capture.barcodes.length}');
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      _logQrScan(
        'raw format=${barcode.format.name} value=${_rawPreview(raw)}',
      );
      _handled = true;
      _controller.stop();
      _handleScanResult(raw.trim());
      return;
    }
  }

  void _handleScanResult(String raw) {
    final target = parseQrScanTarget(raw);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (target == null) {
      _logQrScan('parse failed raw=${_rawPreview(raw)}');
      _showErrorAndResume('${l10n.qrInvalidFormat}: ${_rawPreview(raw)}');
      return;
    }
    _logQrScan(
      'parsed kind=${target.kind.name} user=${target.userId ?? ""} '
      'group=${target.groupId ?? ""} hasName=${target.displayName?.trim().isNotEmpty == true} '
      'hasAvatar=${target.avatarUrl?.trim().isNotEmpty == true}',
    );

    switch (target.kind) {
      case QrScanKind.user:
        final userId = target.userId?.trim();
        if (userId == null || userId.isEmpty) {
          _logQrScan('invalid user target');
          _showErrorAndResume(l10n.qrInvalidUser);
          return;
        }
        final route = addContactDetailRouteForQrTarget(target);
        _logQrScan('navigate user route=$route');
        context.pushReplacement(route);
      case QrScanKind.group:
        final groupId = target.groupId?.trim();
        if (groupId == null || groupId.isEmpty) {
          _logQrScan('invalid group target');
          _showErrorAndResume(l10n.qrInvalidGroup);
          return;
        }
        final route = groupDetailRouteForQrTarget(target);
        if (route == null) {
          _logQrScan('unsupported group target group=$groupId');
          _showErrorAndResume(l10n.qrUnsupportedGroup);
        } else {
          _logQrScan('navigate group route=$route');
          context.pushReplacement(route);
        }
    }
  }

  void _showErrorAndResume(String message) {
    _logQrScan('error message=$message');
    showTopSnackBar(
      context,
      SnackBar(content: Text(message)),
    );
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _handled = false;
      _controller.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    _logQrScan('scanner build handled=$_handled');
    final t = context.tk;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black, // theme-fixed scanner camera background
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleCapture,
          ),
          const _ScannerScrim(),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _ScannerBackButton(onTap: () => context.pop()),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.qrScannerInstruction,
                  textAlign: TextAlign.center,
                  style: AppTheme.sans(size: 14, color: t.onAccent),
                ),
                const SizedBox(height: 20),
                const _ScannerFrame(),
                const SizedBox(height: 20),
                Text(
                  l10n.qrScannerSupportUsers,
                  textAlign: TextAlign.center,
                  style: AppTheme.sans(
                    size: 12,
                    color: t.onAccent.withValues(alpha: 0.72),
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

@visibleForTesting
String addContactDetailRouteForQrTarget(QrScanTarget target) {
  final userId = target.userId?.trim() ?? '';
  final queryParameters = <String, String>{
    if (target.displayName?.trim().isNotEmpty == true)
      'name': target.displayName!.trim(),
    if (target.avatarUrl?.trim().isNotEmpty == true)
      'avatar': target.avatarUrl!.trim(),
  };
  final query = queryParameters.isEmpty
      ? ''
      : '?${Uri(queryParameters: queryParameters).query}';
  return '/add-contact/detail/${Uri.encodeComponent(userId)}$query';
}

@visibleForTesting
String? groupDetailRouteForQrTarget(QrScanTarget target) {
  final groupId = target.groupId?.trim() ?? '';
  if (groupId.isEmpty) return null;
  final queryParameters = <String, String>{
    'qr': '1',
    if (target.displayName?.trim().isNotEmpty == true)
      'name': target.displayName!.trim(),
    if (target.avatarUrl?.trim().isNotEmpty == true)
      'avatar': target.avatarUrl!.trim(),
  };
  final query = queryParameters.isEmpty
      ? ''
      : '?${Uri(queryParameters: queryParameters).query}';
  return '/group-detail/${Uri.encodeComponent(groupId)}$query';
}

void _logQrScan(String message) {
  debugPrint('qr-scan $message');
}

class _ScannerScrim extends StatelessWidget {
  const _ScannerScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28), // theme-fixed scanner
      ),
    );
  }
}

class _ScannerBackButton extends StatelessWidget {
  const _ScannerBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28), // theme-fixed scanner
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Symbols.arrow_back,
            size: 24,
            color: Colors.white, // theme-fixed scanner
          ),
        ),
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final frameSize = size.shortestSide < 400 ? 250.0 : 300.0;
    return Container(
      width: frameSize,
      height: frameSize,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white, // theme-fixed scanner
          width: 4,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

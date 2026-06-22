import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            children: [
              _AboutHeader(onBack: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 20),
              const _DirexioLogoMark(),
              const SizedBox(height: 12),
              Text(
                'Direxio',
                style: AppTheme.sans(
                  size: 24,
                  weight: FontWeight.w700,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 50),
              _AboutInfoRow(
                label: l10n?.aboutWebsite ?? '官网',
                value: 'https://im2.direxio.ai',
              ),
              const SizedBox(height: 12),
              _AboutInfoRow(
                label: l10n?.aboutEmail ?? '邮箱',
                value: 'lInnebdeb@imdire.enwxio',
              ),
              const SizedBox(height: 12),
              _AboutInfoRow(
                label: l10n?.aboutVersionUpdates ?? '版本更新',
                value: 'V1.0.0',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 48,
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: t.text.withValues(alpha: 0.12),
                blurRadius: 36,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: ClipOval(
            child: Material(
              color: t.surface.withValues(alpha: 0.65),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onBack,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Symbols.arrow_back,
                    size: 24,
                    color: t.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirexioLogoMark extends StatelessWidget {
  const _DirexioLogoMark();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [t.accent, t.primaryContainer, t.accent],
          stops: const [0, 0.62, 1],
        ),
        borderRadius: BorderRadius.circular(27),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Symbols.communication,
              size: 47,
              fill: 1,
              color: t.onAccent,
            ),
          ),
          Positioned(
            top: 16,
            right: 14,
            child: Icon(
              Symbols.star,
              size: 18,
              fill: 1,
              color: t.onAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppTheme.sans(
              size: 16,
              weight: FontWeight.w600,
              color: t.text,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTheme.sans(
                size: 12,
                weight: FontWeight.w500,
                color: t.textMute,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

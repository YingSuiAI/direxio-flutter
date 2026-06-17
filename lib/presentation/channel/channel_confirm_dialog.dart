import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

Future<bool> showChannelConfirmDialog(
  BuildContext context, {
  required String title,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.30),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 302,
            height: 144,
            decoration: BoxDecoration(
              color: ctx.tk.surface,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(
                    size: 20,
                    weight: FontWeight.w500,
                    color: ctx.tk.text,
                  ).copyWith(height: 33 / 20),
                ),
                const SizedBox(height: 9),
                _ConfirmPrimaryButton(
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
                const SizedBox(height: 2),
                _ConfirmCancelButton(
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}

class _ConfirmPrimaryButton extends StatelessWidget {
  const _ConfirmPrimaryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tk.accent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 202,
          height: 38,
          child: Center(
            child: Text(
              '确定',
              style: AppTheme.sans(
                size: 18,
                weight: FontWeight.w600,
                color: context.tk.onAccent,
              ).copyWith(height: 33 / 18),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmCancelButton extends StatelessWidget {
  const _ConfirmCancelButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: SizedBox(
        width: 80,
        height: 32,
        child: Center(
          child: Text(
            '取消',
            style: AppTheme.sans(
              size: 16,
              weight: FontWeight.w400,
              color: context.tk.textMute,
            ).copyWith(height: 33 / 16),
          ),
        ),
      ),
    );
  }
}

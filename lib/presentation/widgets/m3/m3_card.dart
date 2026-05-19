/// M3 通用组件 —— 对齐 Agent P2P 设计稿
import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/app_theme.dart';

/// M3 卡片：surface-container-lowest + 细边 + 12 圆角 + 轻阴影。
class M3Card extends StatelessWidget {
  const M3Card({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.clipContent = false,
  });
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool clipContent;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final deco = BoxDecoration(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: t.border.withValues(alpha: 0.3)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
    final inner = clipContent
        ? ClipRRect(borderRadius: BorderRadius.circular(12), child: child)
        : Padding(padding: padding, child: child);

    if (onTap == null) {
      return Container(decoration: deco, child: inner);
    }
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: deco,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: inner,
        ),
      ),
    );
  }
}

/// 主按钮 —— primary 实心，圆角 12，按压缩放。
class M3PrimaryButton extends StatelessWidget {
  const M3PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: t.onAccent),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: AppTheme.sans(
            size: 17,
            weight: FontWeight.w600,
            color: t.onAccent,
          ),
        ),
      ],
    );
    return Material(
      color: onPressed == null ? t.accent.withValues(alpha: 0.5) : t.accent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: child,
        ),
      ),
    );
  }
}

/// M3 输入框容器 —— surface 底 + 细边 + 12 圆角，内部放图标 + input。
class M3InputField extends StatelessWidget {
  const M3InputField({
    super.key,
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.trailing,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
  });
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(icon, size: 20, color: t.textMute),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              autofocus: autofocus,
              style: AppTheme.sans(size: 17, color: t.text),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTheme.sans(size: 17, color: t.textMute),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          if (trailing != null) trailing!,
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';

class M3SearchField extends StatelessWidget {
  const M3SearchField({
    super.key,
    required this.hint,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType,
    this.trailing,
  });

  final String hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final TextInputType? keyboardType;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final field = Row(
      children: [
        const SizedBox(width: 12),
        Icon(Symbols.search, size: 18, color: t.textMute),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            readOnly: readOnly,
            autofocus: autofocus,
            keyboardType: keyboardType,
            textInputAction: TextInputAction.search,
            onTap: onTap,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            cursorColor: t.accent,
            style: AppTheme.sans(size: 14, color: t.text),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: hint,
              hintStyle: AppTheme.sans(size: 14, color: t.textMute),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          trailing!,
        ],
        const SizedBox(width: 12),
      ],
    );
    return Material(
      color: t.surfaceHover,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: readOnly ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 40,
          child: field,
        ),
      ),
    );
  }
}

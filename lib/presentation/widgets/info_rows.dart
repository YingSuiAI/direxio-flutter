/// 信息页通用行组件 —— 聊天信息 / 群信息共用。对齐原型 s-chat-info / s-group-info。
library;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';

/// 卡片内分割线，左侧不缩进（贯穿）。
class InfoDivider extends StatelessWidget {
  const InfoDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
        height: 1, color: context.tk.border.withValues(alpha: 0.5));
  }
}

/// 导航行：标题 + 右侧 chevron。可选 value 文字、danger 红字。
class InfoNavRow extends StatelessWidget {
  const InfoNavRow({
    super.key,
    required this.label,
    this.value,
    this.danger = false,
    this.onTap,
  });
  final String label;
  final String? value;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppTheme.sans(
                      size: 15, color: danger ? t.danger : t.text)),
            ),
            if (value != null) ...[
              Text(value!,
                  style: AppTheme.sans(size: 13, color: t.textMute)),
              const SizedBox(width: 4),
            ],
            Icon(Symbols.chevron_right, size: 18, color: t.textMute),
          ],
        ),
      ),
    );
  }
}

/// 开关行：标题 + 右侧 Switch。
class InfoSwitchRow extends StatelessWidget {
  const InfoSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppTheme.sans(size: 15, color: t.text)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: t.onAccent,
            activeTrackColor: t.accent,
          ),
        ],
      ),
    );
  }
}

/// 纯展示/可点的文字行（无 chevron），如「退出群聊」居中红字。
class InfoCenterRow extends StatelessWidget {
  const InfoCenterRow({
    super.key,
    required this.label,
    this.danger = false,
    this.onTap,
  });
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Center(
          child: Text(label,
              style: AppTheme.sans(
                  size: 15,
                  weight: FontWeight.w500,
                  color: danger ? t.danger : t.text)),
        ),
      ),
    );
  }
}

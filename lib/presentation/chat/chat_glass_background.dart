import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

Color chatPageBackgroundColor(BuildContext context) => context.tk.bg;

class ChatGlassBackground extends StatelessWidget {
  const ChatGlassBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: chatPageBackgroundColor(context),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';

import '../widgets/app_glass_background.dart';

class ChatGlassBackground extends StatelessWidget {
  const ChatGlassBackground({
    super.key,
    required this.child,
  });

  static const assetName = AppGlassBackground.assetName;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppGlassBackground(child: child);
  }
}

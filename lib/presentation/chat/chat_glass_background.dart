import 'package:flutter/material.dart';

class ChatGlassBackground extends StatelessWidget {
  const ChatGlassBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFAFAFA),
      child: child,
    );
  }
}

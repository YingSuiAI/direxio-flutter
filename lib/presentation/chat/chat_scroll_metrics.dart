import 'package:flutter/widgets.dart';

ScrollPosition? chatScrollPositionWithDimensions(ScrollController controller) {
  if (!controller.hasClients) return null;
  final position = controller.position;
  if (!position.hasContentDimensions) return null;
  return position;
}

import 'package:flutter/widgets.dart';

const chatLatestInitialAutoScrollMaxAttempts = 8;
const chatLatestInitialAutoScrollRetryDelay = Duration(milliseconds: 16);
const chatLatestAutoScrollTolerance = 1.0;

ScrollPosition? chatScrollPositionWithDimensions(ScrollController controller) {
  if (!controller.hasClients) return null;
  final position = controller.position;
  if (!position.hasContentDimensions) return null;
  return position;
}

bool shouldRetryLatestInitialAutoScroll({
  required bool hasPosition,
  required bool isAtLatest,
  required int attempt,
  int maxAttempts = chatLatestInitialAutoScrollMaxAttempts,
}) {
  if (attempt >= maxAttempts) return false;
  if (!hasPosition) return true;
  return !isAtLatest;
}

import 'package:flutter/widgets.dart';

const chatLatestInitialAutoScrollMaxAttempts = 8;
const chatLatestInitialAutoScrollSettleAttempts = 3;
const chatLatestInitialAutoScrollRetryDelay = Duration(milliseconds: 16);
const chatLatestAutoScrollTolerance = 1.0;

ScrollController chatMessageScrollController({required bool openAtLatest}) {
  if (!openAtLatest) return ScrollController();
  return ChatInitialLatestScrollController();
}

class ChatInitialLatestScrollController extends ScrollController {
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _ChatInitialLatestScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _ChatInitialLatestScrollPosition extends ScrollPositionWithSingleContext {
  _ChatInitialLatestScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    super.debugLabel,
  });

  bool _pendingInitialLatest = true;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final wasAtLatest = hasContentDimensions &&
        (pixels - this.maxScrollExtent).abs() < chatLatestAutoScrollTolerance;
    final result = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    final shouldPinToLatest = _pendingInitialLatest || wasAtLatest;
    if (shouldPinToLatest && maxScrollExtent > minScrollExtent) {
      _pendingInitialLatest = false;
      if ((pixels - maxScrollExtent).abs() >= chatLatestAutoScrollTolerance) {
        correctPixels(maxScrollExtent);
        return false;
      }
    }
    return result;
  }
}

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
  if (!isAtLatest) return true;
  return attempt < chatLatestInitialAutoScrollSettleAttempts;
}

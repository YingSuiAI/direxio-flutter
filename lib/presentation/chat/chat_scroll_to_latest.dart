class ChatScrollToLatestCoordinator {
  Object? _lastScrolledItemKey;
  Object? _pendingItemKey;
  int _retryAttempts = 0;

  bool request(Object? itemKey, {required bool targetEventPending}) {
    if (targetEventPending) return false;
    if (itemKey == null) return false;
    if (_lastScrolledItemKey == itemKey || _pendingItemKey == itemKey) {
      return false;
    }
    _pendingItemKey = itemKey;
    _retryAttempts = 0;
    return true;
  }

  bool shouldRun(Object itemKey, {required bool targetEventPending}) {
    if (targetEventPending) {
      cancel();
      return false;
    }
    return _pendingItemKey == itemKey;
  }

  bool get shouldJump => _lastScrolledItemKey == null;

  bool retry(Object itemKey, {int maxAttempts = 8}) {
    if (_pendingItemKey != itemKey) return false;
    _retryAttempts++;
    if (_retryAttempts > maxAttempts) {
      cancel();
      return false;
    }
    return true;
  }

  void complete(Object itemKey) {
    if (_pendingItemKey == itemKey) {
      _pendingItemKey = null;
    }
    _lastScrolledItemKey = itemKey;
    _retryAttempts = 0;
  }

  void cancel() {
    _pendingItemKey = null;
    _retryAttempts = 0;
  }
}

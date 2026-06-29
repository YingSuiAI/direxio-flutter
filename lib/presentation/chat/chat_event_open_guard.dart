class ChatEventOpenGuard {
  final Set<String> _openingKeys = <String>{};

  Future<void> runOnce(String key, Future<void> Function() action) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await action();
      return;
    }
    if (!_openingKeys.add(trimmed)) return;
    try {
      await action();
    } finally {
      _openingKeys.remove(trimmed);
    }
  }
}

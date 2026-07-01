class InFlightActionGate {
  final Set<String> _keys = {};

  bool contains(String key) => _keys.contains(key.trim());

  bool begin(String key) {
    final normalized = key.trim();
    if (normalized.isEmpty || _keys.contains(normalized)) return false;
    _keys.add(normalized);
    return true;
  }

  void end(String key) {
    _keys.remove(key.trim());
  }

  Future<T?> run<T>(String key, Future<T> Function() action) async {
    final normalized = key.trim();
    if (!begin(normalized)) return null;
    try {
      return await action();
    } finally {
      end(normalized);
    }
  }
}

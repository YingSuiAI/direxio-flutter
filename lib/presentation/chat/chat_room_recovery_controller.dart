enum ChatRoomRecoveryAttemptResult {
  skipped,
  recovered,
  failed,
}

class ChatRoomRecoveryController {
  bool _inFlight = false;
  bool _attempted = false;
  bool _failed = false;

  bool get inFlight => _inFlight;
  bool get attempted => _attempted;
  bool get failed => _failed;

  bool begin({bool force = false}) {
    if (_inFlight) return false;
    if (_attempted && !force) return false;
    _inFlight = true;
    _attempted = true;
    _failed = false;
    return true;
  }

  void finish({required bool recovered}) {
    _inFlight = false;
    if (recovered) {
      _attempted = false;
      _failed = false;
      return;
    }
    _failed = true;
  }

  void retry() {
    reset();
  }

  Future<ChatRoomRecoveryAttemptResult> runAttempt({
    bool force = false,
    required Future<bool> Function() attempt,
  }) async {
    if (!begin(force: force)) return ChatRoomRecoveryAttemptResult.skipped;
    try {
      final recovered = await attempt();
      finish(recovered: recovered);
      return recovered
          ? ChatRoomRecoveryAttemptResult.recovered
          : ChatRoomRecoveryAttemptResult.failed;
    } on Object {
      finish(recovered: false);
      return ChatRoomRecoveryAttemptResult.failed;
    }
  }

  void reset() {
    _inFlight = false;
    _attempted = false;
    _failed = false;
  }
}

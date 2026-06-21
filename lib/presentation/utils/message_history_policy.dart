/// Triggers that may request historical message bodies.
enum MessageHistoryLoadTrigger {
  /// Opening a concrete chat screen. This may fetch the first visible page for
  /// that room after the user enters it.
  chatOpen,

  /// User explicitly asks for older messages.
  userLoadOlder,

  /// Backend-provided unread-only recovery for a new device.
  unreadRecovery,
}

/// Privacy-first policy for loading message bodies on this device.
///
/// Bootstrap remains metadata-only. Opening a concrete room may fetch the first
/// visible page so a restored client can refill its local Matrix timeline.
bool shouldRequestHistoricalMessages(MessageHistoryLoadTrigger trigger) {
  return switch (trigger) {
    MessageHistoryLoadTrigger.chatOpen => true,
    MessageHistoryLoadTrigger.userLoadOlder => true,
    MessageHistoryLoadTrigger.unreadRecovery => true,
  };
}

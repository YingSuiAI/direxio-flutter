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
/// Bootstrap remains metadata-only. Opening a room should render cached
/// timeline/local history only; explicit older-message loading is user driven.
bool shouldRequestHistoricalMessages(MessageHistoryLoadTrigger trigger) {
  return switch (trigger) {
    MessageHistoryLoadTrigger.chatOpen => false,
    MessageHistoryLoadTrigger.userLoadOlder => true,
    MessageHistoryLoadTrigger.unreadRecovery => true,
  };
}

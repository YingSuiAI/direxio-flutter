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
/// Bootstrap remains metadata-only. Once the user opens a concrete room, the
/// first visible page can be loaded so a new phone does not show an empty chat
/// until the user manually pulls down.
bool shouldRequestHistoricalMessages(MessageHistoryLoadTrigger trigger) {
  return switch (trigger) {
    MessageHistoryLoadTrigger.chatOpen => true,
    MessageHistoryLoadTrigger.userLoadOlder => true,
    MessageHistoryLoadTrigger.unreadRecovery => true,
  };
}

/// Triggers that may request historical message bodies.
enum MessageHistoryLoadTrigger {
  /// Opening a concrete chat screen.
  chatOpen,

  /// User explicitly asks for older messages.
  userLoadOlder,

  /// Backend-provided unread-only recovery for a new device.
  unreadRecovery,
}

/// Privacy-first policy for loading message bodies on this device.
///
/// Chat screens render cached Matrix events and only the normal sync stream may
/// add offline unread events. They must not fetch arbitrary historical message
/// bodies when a room is opened or when the user scrolls upward.
bool shouldRequestHistoricalMessages(MessageHistoryLoadTrigger trigger) {
  return switch (trigger) {
    MessageHistoryLoadTrigger.chatOpen => false,
    MessageHistoryLoadTrigger.userLoadOlder => false,
    MessageHistoryLoadTrigger.unreadRecovery => true,
  };
}

/// Triggers that may request historical message bodies.
enum MessageHistoryLoadTrigger {
  /// Opening a chat screen. This must not fetch read history on a new device.
  chatOpen,

  /// User explicitly asks for older messages.
  userLoadOlder,

  /// Backend-provided unread-only recovery for a new device.
  unreadRecovery,
}

/// Privacy-first policy for loading message bodies on this device.
///
/// Automatic chat-open backfill is blocked because it can pull read history
/// onto a new device. Explicit user action and unread-only recovery remain
/// allowed.
bool shouldRequestHistoricalMessages(MessageHistoryLoadTrigger trigger) {
  return switch (trigger) {
    MessageHistoryLoadTrigger.chatOpen => false,
    MessageHistoryLoadTrigger.userLoadOlder => true,
    MessageHistoryLoadTrigger.unreadRecovery => true,
  };
}

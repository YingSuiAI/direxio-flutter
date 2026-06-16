import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _doNotDisturbKey = 'message_notifications.do_not_disturb';
const _messageSoundKey = 'message_notifications.sound';
const _messageVibrationKey = 'message_notifications.vibration';

@immutable
class MessageNotificationPreferences {
  const MessageNotificationPreferences({
    this.doNotDisturb = false,
    this.messageSound = true,
    this.messageVibration = true,
  });

  final bool doNotDisturb;
  final bool messageSound;
  final bool messageVibration;

  MessageNotificationPreferences copyWith({
    bool? doNotDisturb,
    bool? messageSound,
    bool? messageVibration,
  }) {
    return MessageNotificationPreferences(
      doNotDisturb: doNotDisturb ?? this.doNotDisturb,
      messageSound: messageSound ?? this.messageSound,
      messageVibration: messageVibration ?? this.messageVibration,
    );
  }
}

final messageNotificationPreferencesProvider = StateNotifierProvider<
    MessageNotificationPreferencesNotifier, MessageNotificationPreferences>(
  (ref) => MessageNotificationPreferencesNotifier(),
);

class MessageNotificationPreferencesNotifier
    extends StateNotifier<MessageNotificationPreferences> {
  MessageNotificationPreferencesNotifier()
      : super(const MessageNotificationPreferences()) {
    _load();
  }

  Future<void> setDoNotDisturb(bool enabled) async {
    state = state.copyWith(doNotDisturb: enabled);
    await _save(_doNotDisturbKey, enabled);
  }

  Future<void> setMessageSound(bool enabled) async {
    state = state.copyWith(messageSound: enabled);
    await _save(_messageSoundKey, enabled);
  }

  Future<void> setMessageVibration(bool enabled) async {
    state = state.copyWith(messageVibration: enabled);
    await _save(_messageVibrationKey, enabled);
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      state = MessageNotificationPreferences(
        doNotDisturb: prefs.getBool(_doNotDisturbKey) ?? false,
        messageSound: prefs.getBool(_messageSoundKey) ?? true,
        messageVibration: prefs.getBool(_messageVibrationKey) ?? true,
      );
    } on Object catch (error) {
      debugPrint('message notification preferences load failed: $error');
    }
  }

  Future<void> _save(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } on Object catch (error) {
      debugPrint('message notification preference save failed: $error');
    }
  }
}

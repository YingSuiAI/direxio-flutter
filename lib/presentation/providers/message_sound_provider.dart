import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';
import 'package:vibration/vibration.dart';

import 'auth_provider.dart';
import 'conversation_preferences_provider.dart';
import 'message_notification_preferences_provider.dart';

const _messageSoundAsset = '0.m4a';
const _messageSoundThrottle = Duration(milliseconds: 900);

final messageSoundPlayerProvider = Provider<MessageSoundPlayer>((ref) {
  final player = MessageSoundPlayer();
  ref.onDispose(player.dispose);
  return player;
});

final messageVibrationPlayerProvider = Provider<MessageVibrationPlayer>((ref) {
  return const MessageVibrationPlayer();
});

final messageSoundControllerProvider = Provider<void>((ref) {
  final preferences = ref.watch(messageNotificationPreferencesProvider);
  final mutedConversationIds = ref.watch(mutedConversationIdsProvider);
  if (preferences.doNotDisturb ||
      (!preferences.messageSound && !preferences.messageVibration)) {
    return;
  }
  final auth = ref.watch(authStateNotifierProvider).valueOrNull;
  if (auth?.isLoggedIn != true) return;
  final client = ref.watch(matrixClientProvider);
  if (!client.isLogged()) return;

  DateTime? lastPlayedAt;
  final subscription = client.onEvent.stream.listen((update) {
    if (!shouldPlayMessageSound(
      update,
      currentUserId: client.userID,
      mutedConversationIds: mutedConversationIds,
    )) {
      return;
    }

    final now = DateTime.now();
    final previous = lastPlayedAt;
    if (previous != null && now.difference(previous) < _messageSoundThrottle) {
      return;
    }
    lastPlayedAt = now;
    if (preferences.messageSound) {
      unawaited(ref.read(messageSoundPlayerProvider).play());
    }
    if (preferences.messageVibration) {
      unawaited(ref.read(messageVibrationPlayerProvider).vibrate());
    }
  });

  ref.onDispose(subscription.cancel);
});

@visibleForTesting
bool shouldPlayMessageSound(
  EventUpdate update, {
  required String? currentUserId,
  Set<String> mutedConversationIds = const {},
}) {
  if (update.type != EventUpdateType.timeline &&
      update.type != EventUpdateType.decryptedTimelineQueue) {
    return false;
  }
  final roomId = update.roomID.trim();
  if (roomId.isNotEmpty && mutedConversationIds.contains(roomId)) {
    return false;
  }
  if (update.content['type'] != EventTypes.Message) return false;

  final sender = update.content['sender'];
  if (sender is! String || sender.trim().isEmpty) return false;
  if (currentUserId != null && sender == currentUserId) return false;

  final content = update.content['content'];
  if (content is! Map) return false;
  final msgType = content['msgtype'];
  return msgType is String && msgType.trim().isNotEmpty;
}

class MessageSoundPlayer {
  MessageSoundPlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool _playing = false;

  Future<void> play() async {
    if (_playing) return;
    _playing = true;
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1);
      await _player.play(
        AssetSource(_messageSoundAsset),
        mode: PlayerMode.lowLatency,
        ctx: _messageSoundAudioContext,
      );
    } on Object catch (error) {
      debugPrint('message sound play failed: $error');
    } finally {
      _playing = false;
    }
  }

  Future<void> dispose() => _player.dispose();
}

class MessageVibrationPlayer {
  const MessageVibrationPlayer({
    this.hasVibrator = Vibration.hasVibrator,
    this.vibrateDevice = Vibration.vibrate,
    this.hapticFallback = HapticFeedback.heavyImpact,
    this.defaultTargetPlatformProvider = _defaultTargetPlatform,
  });

  final Future<bool?> Function() hasVibrator;
  final Future<void> Function({List<int> pattern}) vibrateDevice;
  final Future<void> Function() hapticFallback;
  final TargetPlatform Function() defaultTargetPlatformProvider;

  Future<void> vibrate() async {
    try {
      final platform = defaultTargetPlatformProvider();
      if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
        await hapticFallback();
        return;
      }
      final supported = await hasVibrator();
      if (supported == true) {
        await vibrateDevice(pattern: const [0, 200, 100, 200]);
      }
    } on Object catch (error) {
      debugPrint('message vibration failed: $error');
      try {
        await hapticFallback();
      } on Object catch (fallbackError) {
        debugPrint('message haptic fallback failed: $fallbackError');
      }
    }
  }
}

TargetPlatform _defaultTargetPlatform() => defaultTargetPlatform;

final AudioContext _messageSoundAudioContext = AudioContext(
  android: const AudioContextAndroid(
    isSpeakerphoneOn: true,
    audioMode: AndroidAudioMode.normal,
    contentType: AndroidContentType.sonification,
    usageType: AndroidUsageType.notificationCommunicationInstant,
    audioFocus: AndroidAudioFocus.gainTransientMayDuck,
  ),
);

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

class ChatVoicePlaybackState {
  const ChatVoicePlaybackState({
    this.messageId,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playing = false,
  });

  final String? messageId;
  final Duration position;
  final Duration duration;
  final bool playing;

  ChatVoicePlaybackState copyWith({
    String? messageId,
    Duration? position,
    Duration? duration,
    bool? playing,
    bool clearMessageId = false,
  }) {
    return ChatVoicePlaybackState(
      messageId: clearMessageId ? null : messageId ?? this.messageId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playing: playing ?? this.playing,
    );
  }
}

class ChatVoicePlayer {
  ChatVoicePlayer() {
    _player.onLog.listen((message) {
      debugPrint('chat voice player log: $message');
    });
    _player.onPlayerStateChanged.listen((state) {
      debugPrint('chat voice player state: $state');
      final playing = state == PlayerState.playing;
      if (state == PlayerState.stopped || state == PlayerState.completed) {
        playback.value = const ChatVoicePlaybackState();
        return;
      }
      playback.value = playback.value.copyWith(playing: playing);
    });
    _player.onPlayerComplete.listen((_) {
      debugPrint('chat voice player complete');
      playback.value = const ChatVoicePlaybackState();
    });
    _player.onDurationChanged.listen((duration) {
      playback.value = playback.value.copyWith(duration: duration);
    });
    _player.onPositionChanged.listen((position) {
      playback.value = playback.value.copyWith(position: position);
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<ChatVoicePlaybackState> playback =
      ValueNotifier<ChatVoicePlaybackState>(const ChatVoicePlaybackState());
  Timer? _lowLatencyStopTimer;

  Future<void> play(
    File file, {
    String mimeType = '',
    String? messageId,
  }) async {
    final length = await file.length();
    if (length <= 0) {
      throw StateError('empty voice file');
    }
    debugPrint('chat voice play file=${file.path} bytes=$length');
    await _playSource(
      DeviceFileSource(file.path, mimeType: _mime(mimeType)),
      mode: PlayerMode.mediaPlayer,
      messageId: messageId,
    );
  }

  Future<void> _playSource(
    Source source, {
    required PlayerMode mode,
    String? messageId,
  }) async {
    if (messageId != null &&
        playback.value.messageId == messageId &&
        playback.value.playing) {
      await stop();
      return;
    }
    _lowLatencyStopTimer?.cancel();
    await _player.stop();
    playback.value = ChatVoicePlaybackState(messageId: messageId);
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(1);
    await _player.play(
      source,
      mode: mode,
      ctx: _voiceAudioContext,
    );
    try {
      final duration = await _player.getDuration();
      debugPrint('chat voice player duration: ${duration?.inMilliseconds}ms');
      if (duration != null) {
        playback.value = playback.value.copyWith(duration: duration);
      }
    } on Object catch (err) {
      debugPrint('chat voice duration unavailable: $err');
    }
  }

  Future<void> playBytes(
    List<int> bytes, {
    String mimeType = '',
    String? messageId,
  }) async {
    if (bytes.isEmpty) {
      throw StateError('empty voice data');
    }
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final normalizedMime = _mime(mimeType);
    debugPrint(
      'chat voice bytes=${data.length} mime=$normalizedMime head=${_hexHead(data)}',
    );
    final extension = _audioExtensionForData(data, normalizedMime);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/portal_voice_playback_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await file.writeAsBytes(data, flush: true);
    await play(file, mimeType: normalizedMime, messageId: messageId);
  }

  Future<void> seek(Duration position) async {
    final target = position < Duration.zero ? Duration.zero : position;
    await _player.seek(target);
    await _player.resume();
    playback.value = playback.value.copyWith(position: target, playing: true);
  }

  Future<void> stop() async {
    _lowLatencyStopTimer?.cancel();
    await _player.stop();
    playback.value = const ChatVoicePlaybackState();
  }

  Future<void> dispose() async {
    _lowLatencyStopTimer?.cancel();
    playback.dispose();
    await _player.dispose();
  }
}

final AudioContext _voiceAudioContext = AudioContext(
  android: const AudioContextAndroid(
    isSpeakerphoneOn: true,
    audioMode: AndroidAudioMode.normal,
    contentType: AndroidContentType.speech,
    usageType: AndroidUsageType.media,
    audioFocus: AndroidAudioFocus.gain,
  ),
);

String _audioExtensionForData(Uint8List bytes, String mimeType) {
  if (_looksLikeMp4(bytes)) return '.m4a';
  if (_looksLikeAacAdts(bytes)) return '.aac';
  return _audioExtensionForMime(mimeType);
}

bool _looksLikeMp4(Uint8List bytes) {
  if (bytes.length < 12) return false;
  return bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70;
}

bool _looksLikeAacAdts(Uint8List bytes) {
  if (bytes.length < 2) return false;
  return bytes[0] == 0xFF && (bytes[1] & 0xF0) == 0xF0;
}

String _hexHead(Uint8List bytes) {
  return bytes
      .take(16)
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join(' ');
}

String _audioExtensionForMime(String mimeType) {
  final mime = mimeType.toLowerCase();
  if (mime.contains('mpeg') || mime.contains('mp3')) return '.mp3';
  if (mime.contains('wav')) return '.wav';
  if (mime.contains('ogg')) return '.ogg';
  if (mime.contains('opus')) return '.opus';
  if (mime.contains('amr')) return '.amr';
  if (mime.contains('aac')) return '.aac';
  return '.m4a';
}

String _mime(String mimeType) {
  final mime = mimeType.toLowerCase().split(';').first.trim();
  if (mime == 'audio/m4a' || mime == 'audio/x-m4a') return 'audio/mp4';
  if (mime.isNotEmpty) return mime;
  return 'audio/mp4';
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class ChatVoiceRecording {
  const ChatVoiceRecording({
    required this.bytes,
    required this.filename,
    required this.mimeType,
    required this.durationMs,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
  final int durationMs;
}

class ChatVoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  DateTime? _startedAt;
  String? _path;
  StreamSubscription<Amplitude>? _amplitudeSub;
  double _maxAmplitude = -160;

  bool get isRecording => _startedAt != null;

  Future<void> start() async {
    if (isRecording) return;
    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      throw const ChatVoiceRecorderException('没有麦克风权限');
    }
    final dir = await getTemporaryDirectory();
    final now = DateTime.now().millisecondsSinceEpoch;
    final path = '${dir.path}/portal_voice_$now.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.mic,
          manageBluetooth: false,
        ),
      ),
      path: path,
    );
    _maxAmplitude = -160;
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .listen((amplitude) {
      if (amplitude.current > _maxAmplitude) {
        _maxAmplitude = amplitude.current;
      }
    });
    _startedAt = DateTime.now();
    _path = path;
  }

  Future<ChatVoiceRecording?> stop() async {
    final startedAt = _startedAt;
    _startedAt = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    final stoppedPath = await _recorder.stop();
    final path = stoppedPath ?? _path;
    _path = null;
    if (startedAt == null || path == null || path.isEmpty) return null;
    final durationMs = DateTime.now().difference(startedAt).inMilliseconds;
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    unawaitedDelete(file);
    if (bytes.isEmpty) return null;
    debugPrint(
      'chat voice recording bytes=${bytes.length} duration=${durationMs}ms maxAmplitude=${_maxAmplitude.toStringAsFixed(1)}dB',
    );
    return ChatVoiceRecording(
      bytes: bytes,
      filename: path.split('/').last,
      mimeType: 'audio/mp4',
      durationMs: durationMs,
    );
  }

  Future<void> cancel() async {
    _startedAt = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    final stoppedPath = await _recorder.stop();
    final path = stoppedPath ?? _path;
    _path = null;
    if (path == null || path.isEmpty) return;
    unawaitedDelete(File(path));
  }

  Future<void> dispose() async {
    await _amplitudeSub?.cancel();
    await _recorder.dispose();
  }
}

class ChatVoiceRecorderException implements Exception {
  const ChatVoiceRecorderException(this.message);

  final String message;

  @override
  String toString() => message;
}

void unawaitedDelete(File file) {
  file.delete().ignore();
}

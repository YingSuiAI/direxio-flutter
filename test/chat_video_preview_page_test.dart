import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:portal_app/presentation/chat/chat_video_preview_page.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  late _FakeVideoPlayerPlatform videoPlatform;

  setUp(() {
    videoPlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = videoPlatform;
  });

  testWidgets('shows save-to-album action when provided', (tester) async {
    var saves = 0;
    final file = File('${tester.testDescription}.mp4');

    await tester.pumpWidget(
      MaterialApp(
        home: ChatVideoPreviewPage(
          file: file,
          title: 'clip.mp4',
          onSaveToAlbum: () async => saves++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('保存到相册'), findsOneWidget);
    expect(find.byIcon(Symbols.download), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.download));
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(find.byIcon(Symbols.check), findsOneWidget);
  });
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final Map<int, StreamController<VideoEvent>> _streams =
      <int, StreamController<VideoEvent>>{};
  int _nextPlayerId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    return createWithOptions(
      VideoCreationOptions(
        dataSource: dataSource,
        viewType: VideoViewType.textureView,
      ),
    );
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = _nextPlayerId++;
    final stream = StreamController<VideoEvent>();
    _streams[playerId] = stream;
    stream.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        size: const Size(100, 100),
        duration: const Duration(seconds: 1),
      ),
    );
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _streams[playerId]!.stream;
  }

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> dispose(int playerId) async {
    await _streams.remove(playerId)?.close();
  }

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int playerId) {
    return kIsWeb ? const SizedBox.shrink() : Texture(textureId: playerId);
  }

  @override
  Future<List<VideoAudioTrack>> getAudioTracks(int playerId) async {
    return const <VideoAudioTrack>[];
  }

  @override
  Future<void> setAudioTrack(int playerId, String? trackId) async {}
}

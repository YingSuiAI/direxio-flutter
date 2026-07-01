import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_app/presentation/call/camera_switching.dart';
import 'package:webrtc_interface/webrtc_interface.dart';

void main() {
  test('switchFirstLocalVideoTrack treats false native result as success',
      () async {
    final track = _FakeMediaStreamTrack(
      id: 'video-track-1',
      kind: 'video',
    );
    final stream = _FakeMediaStream(videoTracks: [track]);
    var switchedTrackId = '';

    final switched = await switchFirstLocalVideoTrack(
      stream,
      switchCamera: (track) async {
        switchedTrackId = track.id ?? '';
        return false;
      },
    );

    expect(switched, isTrue);
    expect(switchedTrackId, 'video-track-1');
  });

  test('camera facing constraints target the opposite camera', () {
    expect(
      cameraFacingForTrack(
        _FakeMediaStreamTrack(
          id: 'front-track',
          kind: 'video',
          settings: const {'facingMode': 'user'},
        ),
        fallback: LocalCameraFacing.user,
      ),
      LocalCameraFacing.user,
    );
    expect(
      oppositeCameraFacing(LocalCameraFacing.user),
      LocalCameraFacing.environment,
    );
    expect(
      videoConstraintsForCameraFacing(LocalCameraFacing.environment),
      const {
        'audio': false,
        'video': {
          'width': 1280,
          'height': 720,
          'facingMode': 'environment',
        },
      },
    );
  });

  test('camera constraints prefer an explicit front camera device', () {
    final constraints = preferCameraDeviceForFacing(
      const {
        'audio': true,
        'video': {
          'width': 1280,
          'height': 720,
          'facingMode': 'user',
        },
      },
      [
        MediaDeviceInfo(
          deviceId: 'rear-device',
          label: '后置相机',
          kind: 'videoinput',
        ),
        MediaDeviceInfo(
          deviceId: 'front-device',
          label: '前置相机',
          kind: 'videoinput',
        ),
      ],
    );

    expect(
      constraints['video'],
      containsPair('deviceId', 'front-device'),
    );
    expect(
      constraints['video'],
      containsPair('facingMode', 'user'),
    );
  });

  test('camera constraints keep user facing fallback without front device', () {
    final constraints = preferCameraDeviceForFacing(
      const {
        'audio': true,
        'video': {
          'width': 1280,
          'height': 720,
          'facingMode': 'user',
        },
      },
      [
        MediaDeviceInfo(
          deviceId: 'rear-device',
          label: '后置相机',
          kind: 'videoinput',
        ),
      ],
    );

    expect(
      constraints['video'],
      isNot(containsPair('deviceId', 'rear-device')),
    );
    expect(
      constraints['video'],
      containsPair('facingMode', 'user'),
    );
  });

  test('camera stream binding token changes when video track changes',
      () async {
    final oldTrack = _FakeMediaStreamTrack(id: 'front-track', kind: 'video');
    final newTrack = _FakeMediaStreamTrack(id: 'rear-track', kind: 'video');
    final stream = _FakeMediaStream(videoTracks: [oldTrack]);

    final before = cameraStreamBindingToken(stream);
    await stream.removeTrack(oldTrack);
    await stream.addTrack(newTrack);

    expect(cameraStreamBindingToken(stream), isNot(before));
  });

  test('camera stream binding token changes when camera device changes', () {
    final settings = <String, dynamic>{
      'deviceId': 'front-device',
      'facingMode': 'user',
    };
    final track = _FakeMediaStreamTrack(
      id: 'video-track',
      kind: 'video',
      settings: settings,
    );
    final stream = _FakeMediaStream(videoTracks: [track]);

    final before = cameraStreamBindingToken(stream);
    settings['deviceId'] = 'rear-device';
    settings['facingMode'] = 'environment';

    expect(cameraStreamBindingToken(stream), isNot(before));
  });

  test('camera debug summary includes stream token and track settings', () {
    final stream = _FakeMediaStream(
      videoTracks: [
        _FakeMediaStreamTrack(
          id: 'front-track',
          kind: 'video',
          settings: const {'facingMode': 'user'},
        ),
      ],
    );

    final summary = cameraTrackDebugSummary(stream);

    expect(summary, contains('fake-stream'));
    expect(summary, contains('front-track'));
    expect(summary, contains('facingMode'));
    expect(summary, contains(cameraStreamBindingToken(stream)));
  });

  test('removeAndStopVideoTracks uses a stable track snapshot', () async {
    final track = _FakeMediaStreamTrack(id: 'front-track', kind: 'video');
    final stream = _FakeMediaStream(
      videoTracks: [track],
      returnsTrackListSnapshot: false,
    );

    await removeAndStopVideoTracks(stream);

    expect(stream.getVideoTracks(), isEmpty);
    expect(track.stopCount, 1);
  });
}

class _FakeMediaStream extends MediaStream {
  _FakeMediaStream({
    List<MediaStreamTrack> videoTracks = const [],
    this.returnsTrackListSnapshot = true,
  })  : _videoTracks = videoTracks,
        super('fake-stream', 'fake-owner');

  final List<MediaStreamTrack> _videoTracks;
  final bool returnsTrackListSnapshot;

  @override
  bool? get active => true;

  @override
  Future<void> addTrack(MediaStreamTrack track,
      {bool addToNative = true}) async {
    _videoTracks.add(track);
  }

  @override
  List<MediaStreamTrack> getAudioTracks() => const [];

  @override
  Future<void> getMediaTracks() async {}

  @override
  List<MediaStreamTrack> getTracks() {
    if (!returnsTrackListSnapshot) return _videoTracks;
    return List.of(_videoTracks);
  }

  @override
  List<MediaStreamTrack> getVideoTracks() {
    if (!returnsTrackListSnapshot) return _videoTracks;
    return List.of(_videoTracks);
  }

  @override
  Future<void> removeTrack(
    MediaStreamTrack track, {
    bool removeFromNative = true,
  }) async {
    _videoTracks.remove(track);
  }
}

class _FakeMediaStreamTrack extends MediaStreamTrack {
  _FakeMediaStreamTrack({
    required this.id,
    required this.kind,
    this.settings = const {},
  });

  @override
  final String id;

  @override
  final String kind;

  final Map<String, dynamic> settings;

  bool _enabled = true;
  int stopCount = 0;

  @override
  Future<ByteBuffer> captureFrame() {
    throw UnimplementedError();
  }

  @override
  Future<void> dispose() async {}

  @override
  bool get enabled => _enabled;

  @override
  set enabled(bool b) {
    _enabled = b;
  }

  @override
  Map<String, dynamic> getSettings() => settings;

  @override
  String get label => '';

  @override
  bool? get muted => false;

  @override
  Future<void> stop() async {
    stopCount += 1;
  }
}

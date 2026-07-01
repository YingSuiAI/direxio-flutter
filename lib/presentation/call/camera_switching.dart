import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

typedef CameraTrackSwitcher = Future<bool> Function(
  webrtc.MediaStreamTrack track,
);

enum LocalCameraFacing {
  user,
  environment,
}

Future<bool> switchFirstLocalVideoTrack(
  webrtc.MediaStream? stream, {
  CameraTrackSwitcher switchCamera = webrtc.Helper.switchCamera,
}) async {
  final tracks = stream?.getVideoTracks();
  if (tracks == null || tracks.isEmpty) return false;
  await switchCamera(tracks.first);
  return true;
}

Future<void> removeAndStopVideoTracks(webrtc.MediaStream stream) async {
  final tracks = stream.getVideoTracks().toList(growable: false);
  for (final track in tracks) {
    await stream.removeTrack(track);
    await track.stop();
  }
}

String cameraStreamBindingToken(webrtc.MediaStream? stream) {
  if (stream == null) return 'none';
  final videoTrackIds = stream
      .getVideoTracks()
      .map((track) => track.id ?? '')
      .where((id) => id.isNotEmpty)
      .join(',');
  return '${stream.id}:$videoTrackIds';
}

String cameraTrackDebugSummary(webrtc.MediaStream? stream) {
  if (stream == null) return 'stream=null token=none videos=[]';
  final videos = stream.getVideoTracks().map((track) {
    return 'id=${track.id ?? ""} kind=${track.kind} '
        'enabled=${track.enabled} muted=${track.muted} '
        'settings=${_settingsDebugSummary(track.getSettings())}';
  }).join(';');
  return 'stream=${stream.id} token=${cameraStreamBindingToken(stream)} '
      'videos=[$videos]';
}

String _settingsDebugSummary(Map<String, dynamic> settings) {
  if (settings.isEmpty) return '{}';
  final keys = settings.keys.map((key) => key.toString()).toList()..sort();
  return '{${keys.map((key) => '$key: ${settings[key]}').join(', ')}}';
}

LocalCameraFacing cameraFacingForTrack(
  webrtc.MediaStreamTrack track, {
  required LocalCameraFacing fallback,
}) {
  final facingMode = track.getSettings()['facingMode']?.toString();
  return switch (facingMode) {
    'environment' => LocalCameraFacing.environment,
    'user' => LocalCameraFacing.user,
    _ => fallback,
  };
}

LocalCameraFacing oppositeCameraFacing(LocalCameraFacing facing) {
  return switch (facing) {
    LocalCameraFacing.user => LocalCameraFacing.environment,
    LocalCameraFacing.environment => LocalCameraFacing.user,
  };
}

Map<String, Object> videoConstraintsForCameraFacing(LocalCameraFacing facing) {
  return {
    'audio': false,
    'video': {
      'width': 1280,
      'height': 720,
      'facingMode': switch (facing) {
        LocalCameraFacing.user => 'user',
        LocalCameraFacing.environment => 'environment',
      },
    },
  };
}

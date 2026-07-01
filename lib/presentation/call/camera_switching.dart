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
      .map(_videoTrackBindingToken)
      .where((id) => id.isNotEmpty)
      .join(',');
  return '${stream.id}:$videoTrackIds';
}

String? cameraPrimaryVideoTrackId(webrtc.MediaStream? stream) {
  final tracks = stream?.getVideoTracks();
  if (tracks == null || tracks.isEmpty) return null;
  final id = tracks.first.id?.trim();
  return id == null || id.isEmpty ? null : id;
}

String _videoTrackBindingToken(webrtc.MediaStreamTrack track) {
  final id = track.id?.trim();
  if (id == null || id.isEmpty) return '';
  final settings = track.getSettings();
  final deviceId = settings['deviceId']?.toString() ?? '';
  final facingMode = settings['facingMode']?.toString() ?? '';
  return '$id|device=$deviceId|facing=$facingMode';
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

Map<String, dynamic> preferCameraDeviceForFacing(
  Map<String, dynamic> constraints,
  Iterable<webrtc.MediaDeviceInfo> devices,
) {
  final video = constraints['video'];
  if (video == null || video == false) return constraints;
  final videoConstraints =
      video is Map ? Map<String, dynamic>.from(video) : <String, dynamic>{};
  final desiredFacing =
      _cameraFacingFromConstraint(videoConstraints['facingMode']);
  if (desiredFacing == null) return constraints;

  final selectedDevice = _cameraDeviceForFacing(devices, desiredFacing);
  if (selectedDevice == null) return constraints;

  return {
    ...constraints,
    'video': {
      ...videoConstraints,
      'facingMode': switch (desiredFacing) {
        LocalCameraFacing.user => 'user',
        LocalCameraFacing.environment => 'environment',
      },
      'deviceId': selectedDevice.deviceId,
    },
  };
}

LocalCameraFacing? _cameraFacingFromConstraint(Object? value) {
  if (value is Map) {
    return _cameraFacingFromConstraint(value['exact'] ?? value['ideal']);
  }
  final normalized = value?.toString().trim().toLowerCase();
  return switch (normalized) {
    'user' => LocalCameraFacing.user,
    'environment' => LocalCameraFacing.environment,
    _ => null,
  };
}

webrtc.MediaDeviceInfo? _cameraDeviceForFacing(
  Iterable<webrtc.MediaDeviceInfo> devices,
  LocalCameraFacing facing,
) {
  for (final device in devices) {
    if (device.kind?.toLowerCase() != 'videoinput') continue;
    final label = device.label.trim().toLowerCase();
    if (_cameraLabelMatchesFacing(label, facing)) return device;
  }
  return null;
}

bool _cameraLabelMatchesFacing(String label, LocalCameraFacing facing) {
  if (label.isEmpty) return false;
  return switch (facing) {
    LocalCameraFacing.user => label.contains('front') ||
        label.contains('user') ||
        label.contains('face') ||
        label.contains('前置') ||
        label.contains('前摄') ||
        label.contains('前置相机'),
    LocalCameraFacing.environment => label.contains('back') ||
        label.contains('rear') ||
        label.contains('environment') ||
        label.contains('后置') ||
        label.contains('后摄') ||
        label.contains('后置相机'),
  };
}

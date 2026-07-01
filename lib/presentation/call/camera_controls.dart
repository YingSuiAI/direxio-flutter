import '../../l10n/app_localizations.dart';

bool cameraSwitchControlVisible({required bool isVideoCall}) => isVideoCall;

bool cameraSwitchControlCanToggle({
  required bool isVideoCall,
  required bool hasLocalVideoTrack,
  required bool isCameraMuted,
}) {
  return isVideoCall && hasLocalVideoTrack && !isCameraMuted;
}

String cameraSwitchControlLabel({AppLocalizations? l10n}) {
  return '翻转';
}

#!/bin/sh
set -eu

if [ "${PLATFORM_NAME:-}" != "iphoneos" ]; then
  exit 0
fi

if [ "${CONFIGURATION:-}" = "Debug" ]; then
  exit 0
fi

if [ -z "${DWARF_DSYM_FOLDER_PATH:-}" ]; then
  echo "warning: DWARF_DSYM_FOLDER_PATH is not set; skipping WebRTC dSYM generation"
  exit 0
fi

PODS_DIR="${PODS_ROOT:-${SRCROOT}/Pods}"
WEBRTC_BINARY=""

for candidate in \
  "${PODS_DIR}/WebRTC-SDK/WebRTC.xcframework/ios-arm64/WebRTC.framework/WebRTC" \
  "${PODS_XCFRAMEWORKS_BUILD_DIR:-}/WebRTC-SDK/WebRTC.framework/WebRTC"
do
  if [ -f "${candidate}" ]; then
    WEBRTC_BINARY="${candidate}"
    break
  fi
done

if [ -z "${WEBRTC_BINARY}" ]; then
  echo "warning: WebRTC.framework binary was not found; skipping WebRTC dSYM generation"
  exit 0
fi

DSYM_OUTPUT="${DWARF_DSYM_FOLDER_PATH}/WebRTC.framework.dSYM"
mkdir -p "${DWARF_DSYM_FOLDER_PATH}"
rm -rf "${DSYM_OUTPUT}"

xcrun dsymutil "${WEBRTC_BINARY}" -o "${DSYM_OUTPUT}"

binary_uuid="$(xcrun dwarfdump --uuid "${WEBRTC_BINARY}" | awk '/arm64/ { print $2; exit }')"
dsym_uuid="$(xcrun dwarfdump --uuid "${DSYM_OUTPUT}" | awk '/arm64/ { print $2; exit }')"

if [ -z "${binary_uuid}" ] || [ "${binary_uuid}" != "${dsym_uuid}" ]; then
  echo "error: Generated WebRTC.framework.dSYM UUID (${dsym_uuid:-missing}) does not match WebRTC.framework UUID (${binary_uuid:-missing})." >&2
  exit 1
fi

echo "Generated ${DSYM_OUTPUT} for WebRTC.framework UUID ${dsym_uuid}"

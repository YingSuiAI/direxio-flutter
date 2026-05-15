#!/usr/bin/env bash
# Vercel build script for Flutter Web
# 下载 Flutter SDK → pub get → build_runner → build web
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.9}"
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
FLUTTER_SDK_DIR="${PWD}/.flutter-sdk"
FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/${FLUTTER_ARCHIVE}"

echo "==> Vercel Flutter build"
echo "    Flutter ${FLUTTER_VERSION} (${FLUTTER_CHANNEL})"

# 1) Install Flutter SDK (cached across builds via .flutter-sdk/)
if [ ! -x "${FLUTTER_SDK_DIR}/bin/flutter" ]; then
  echo "==> Downloading Flutter SDK"
  curl -fsSL -o "/tmp/${FLUTTER_ARCHIVE}" "${FLUTTER_URL}"
  mkdir -p "${FLUTTER_SDK_DIR}"
  tar -xf "/tmp/${FLUTTER_ARCHIVE}" -C "${FLUTTER_SDK_DIR}" --strip-components=1
  rm -f "/tmp/${FLUTTER_ARCHIVE}"
else
  echo "==> Reusing cached Flutter SDK at ${FLUTTER_SDK_DIR}"
fi

export PATH="${FLUTTER_SDK_DIR}/bin:${PATH}"
# Tell git the SDK dir is safe (Vercel runs as different uid)
git config --global --add safe.directory "${FLUTTER_SDK_DIR}" || true

flutter --version

# 2) Disable analytics + telemetry in CI
flutter config --no-analytics > /dev/null
dart --disable-analytics > /dev/null

# 3) Fetch deps
echo "==> flutter pub get"
flutter pub get

# 4) Run code generation (freezed / riverpod / json_serializable)
echo "==> dart run build_runner build"
dart run build_runner build --delete-conflicting-outputs

# 5) Build web (release, HTML renderer to keep payload small; switch to canvaskit if you need fidelity)
echo "==> flutter build web"
flutter build web --release --no-tree-shake-icons

echo "==> Build complete: build/web/"
ls -lh build/web/ | head -10

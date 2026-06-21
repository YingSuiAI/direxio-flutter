#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUNDLE_ID="${BUNDLE_ID:-com.direxio.app}"
APP_PATH="${APP_PATH:-build/ios/iphonesimulator/Runner.app}"

export DIREXIO_LOCAL_ENDPOINTS="${DIREXIO_LOCAL_ENDPOINTS:-host.docker.internal:18448=127.0.0.1:18008,host.docker.internal:28448=127.0.0.1:28008,host.docker.internal:38448=127.0.0.1:38008}"

BOOTED_DEVICES=()
while IFS= read -r udid; do
  BOOTED_DEVICES+=("$udid")
done < <(xcrun simctl list devices booted | grep -Eo '[0-9A-Fa-f-]{36}' || true)

if [[ "${#BOOTED_DEVICES[@]}" -eq 0 ]]; then
  echo "No booted iOS simulators found." >&2
  exit 1
fi

echo "Building local three-node simulator app..."
flutter build ios --simulator --debug \
  --dart-define="DIREXIO_LOCAL_ENDPOINTS=$DIREXIO_LOCAL_ENDPOINTS"

echo "Installing ${APP_PATH} to ${#BOOTED_DEVICES[@]} booted simulator(s)..."
for udid in "${BOOTED_DEVICES[@]}"; do
  echo "Installing $udid"
  xcrun simctl install "$udid" "$APP_PATH"
  xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
done

echo "Done."

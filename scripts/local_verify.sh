#!/usr/bin/env bash
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root" || exit 1

usage() {
  cat <<'USAGE'
Usage:
  scripts/local_verify.sh [options] [-- <flutter test args>]

Runs local validation in a serial, low-noise order.

Options:
  --skip-tests            Run analysis and generated-file checks only.
  --flutter-analyze       Run flutter analyze --no-pub after dart analyze lib.
  --ios-simulator-build   Run flutter build ios --simulator --debug --no-pub.
  --restore-ios-noise     Restore iOS project files only if they were clean before the build.
  -h, --help              Show this help.

When no flutter test args are supplied, the default focused smoke tests run:
  flutter test --no-pub test/channel_inbox_data_test.dart test/http_as_client_test.dart
  flutter test --no-pub test/widget_test.dart --plain-name channel
USAGE
}

skip_tests=0
run_flutter_analyze=0
run_ios_build=0
restore_ios_noise=0
test_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-tests)
      skip_tests=1
      shift
      ;;
    --flutter-analyze)
      run_flutter_analyze=1
      shift
      ;;
    --ios-simulator-build)
      run_ios_build=1
      shift
      ;;
    --restore-ios-noise)
      restore_ios_noise=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      test_args=("$@")
      break
      ;;
    *)
      test_args=("$@")
      break
      ;;
  esac
done

status=0

run_step() {
  printf '\n==> %s\n' "$*"
  "$@"
  local step_status=$?
  if [[ $step_status -ne 0 && $status -eq 0 ]]; then
    status=$step_status
  fi
}

check_generated_files() {
  local missing=()
  local generated_files=(
    "lib/core/router/app_router.g.dart"
    "lib/presentation/providers/auth_provider.g.dart"
  )

  for file in "${generated_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      missing+=("$file")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    printf '\nMissing generated files:\n' >&2
    printf '  %s\n' "${missing[@]}" >&2
    printf '\nRegenerate them with:\n  dart run build_runner build --delete-conflicting-outputs\n' >&2
    status=1
  fi
}

cleanup_flutter_logs() {
  find "$repo_root" -maxdepth 1 -name 'flutter_*.log' -print -delete
}

ios_noise_files=(
  "ios/Podfile.lock"
  "ios/Runner.xcodeproj/project.pbxproj"
)

initial_ios_noise="$(git status --short -- "${ios_noise_files[@]}")"

check_generated_files
cleanup_flutter_logs

run_step dart analyze lib

if [[ $run_flutter_analyze -eq 1 ]]; then
  run_step flutter analyze --no-pub
fi

if [[ $skip_tests -eq 0 ]]; then
  if [[ ${#test_args[@]} -gt 0 ]]; then
    run_step flutter test --no-pub "${test_args[@]}"
  else
    run_step flutter test --no-pub test/channel_inbox_data_test.dart test/http_as_client_test.dart
    run_step flutter test --no-pub test/widget_test.dart --plain-name channel
  fi
fi

if [[ $run_ios_build -eq 1 ]]; then
  run_step flutter build ios --simulator --debug --no-pub
fi

cleanup_flutter_logs

final_ios_noise="$(git status --short -- "${ios_noise_files[@]}")"
if [[ -n "$final_ios_noise" ]]; then
  if [[ -z "$initial_ios_noise" && $restore_ios_noise -eq 1 ]]; then
    printf '\n==> Restoring iOS build-tool noise\n'
    git restore -- "${ios_noise_files[@]}"
  else
    printf '\n==> iOS project files changed during local validation:\n%s\n' "$final_ios_noise"
    if [[ -n "$initial_ios_noise" ]]; then
      printf 'These files were already dirty before validation, so the script left them untouched.\n'
    else
      printf 'Review them, or rerun with --restore-ios-noise if they are only local build-tool updates.\n'
    fi
  fi
fi

exit "$status"

#!/bin/bash
set -euo pipefail
# Pass the UDID of a booted, disposable iOS 18+ simulator.
if [[ $# -lt 1 ]]; then
  echo 'Usage: preview-companion-3d.sh <simulator-udid> [debug-preview-flags...]' >&2
  exit 2
fi
prototype_device="$1"
shift
prototype_root="$(cd "$(dirname "$0")/../.." && pwd)"
prototype_build="${TMPDIR:-/tmp}/clockin-3d-preview-build"
xcodebuild -project "$prototype_root/iOS/Clockin.xcodeproj" -scheme Clockin \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$prototype_build" build CODE_SIGNING_ALLOWED=NO \
  > "${TMPDIR:-/tmp}/clockin-3d-preview-build.log" 2>&1
xcrun simctl install "$prototype_device" "$prototype_build/Build/Products/Debug-iphonesimulator/Clockin.app"
xcrun simctl launch --terminate-running-process "$prototype_device" com.erdmncdr.clockin \
  --companion-3d-preview --3d-checks "$@"

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null; then
  echo 'Xcode is required. Run this on your Mac after installing Xcode and an iOS simulator runtime.' >&2
  exit 1
fi
if [ -z "${IOS_SIMULATOR_ID:-}" ]; then
  xcrun simctl list devices available
  echo 'Set IOS_SIMULATOR_ID to the UUID of an available iPhone simulator, then rerun.' >&2
  exit 1
fi
results="${LIFTLOG_RESULTS:-/tmp/LiftLog-$(date +%Y%m%d-%H%M%S).xcresult}"
xcodebuild -project LiftLog.xcodeproj -scheme LiftLog -configuration Debug \
  -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" \
  -resultBundlePath "$results" CODE_SIGNING_ALLOWED=NO test

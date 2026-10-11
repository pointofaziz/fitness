#!/bin/bash
# Runs the app already built by GitHub Actions; no local compilation or signing.
set -euo pipefail
cd "$(dirname "$0")"
if [ "$(uname -s)" != Darwin ]; then
  echo 'This launcher requires a Mac with Xcode and an iOS simulator runtime.' >&2
  exit 1
fi
if [ -d /Applications/Xcode.app/Contents/Developer ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
if [ ! -d LiftLog.app ]; then
  echo 'Download and extract the LiftLog-Simulator artifact from the successful GitHub Actions run. This launcher must be beside LiftLog.app.' >&2
  exit 1
fi
liftlog_temp="$(mktemp -d "${TMPDIR:-/tmp}/LiftLog-launch.XXXXXX")"
trap 'rm -rf "$liftlog_temp"' EXIT
xcrun simctl list devices available --json > "$liftlog_temp/devices.json"
liftlog_device="$(python3 select-simulator.py "$liftlog_temp/devices.json")"
echo 'Starting the iPhone simulator…'
xcrun simctl bootstatus "$liftlog_device" -b
open -a Simulator --args -CurrentDeviceUDID "$liftlog_device"
xcrun simctl install "$liftlog_device" LiftLog.app
liftlog_bundle="$(/usr/libexec/PlistBuddy -c 'Print:CFBundleIdentifier' LiftLog.app/Info.plist)"
xcrun simctl launch "$liftlog_device" "$liftlog_bundle"
echo 'Lift Log is running in the iPhone simulator.'

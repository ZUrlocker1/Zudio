#!/bin/bash
# Reports whether an iPhone Duo simulator is available. Read-only; changes nothing.
# Run with:  bash ~/Downloads/Zudio/check-duo.sh

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

echo "== Xcode =="
echo "xcode-select in this shell: $(xcode-select -p 2>&1)"
if [ ! -d "$DEVELOPER_DIR" ]; then
  echo "No Xcode at /Applications/Xcode.app. Find yours with: ls -d /Applications/Xcode*"
  exit 1
fi
/usr/bin/xcodebuild -version 2>&1 | head -2

echo
echo "== Duo device types =="
/usr/bin/xcrun simctl list devicetypes 2>&1 | grep -i -E "duo|fold" || echo "none found"

echo
echo "== Duo simulator devices =="
/usr/bin/xcrun simctl list devices 2>&1 | grep -i -E "duo|fold" || echo "none found"

echo
echo "== Runtimes =="
/usr/bin/xcrun simctl list runtimes 2>&1 | grep -i ios || echo "none found"

echo
echo "== Raw device type count (0 or 1 line means simctl itself failed) =="
/usr/bin/xcrun simctl list devicetypes 2>&1 | wc -l

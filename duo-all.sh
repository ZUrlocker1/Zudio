#!/bin/bash
# Captures the full iPhone Duo App Store set: closed and open, portrait and landscape.
# Run from your own Terminal (needs Accessibility permission for it):
#   bash ~/Downloads/Zudio/duo-all.sh
# Writes ~/Downloads/AppStoreScreenshots/Duo/Zudio-Duo-<pose>-<scene>.png
# Sizes: closed 1398x2034 / 2034x1398, open 2007x2853 / 2853x2007.
# Assumes the Duo simulator is booted with Zudio running, folded and upright.
# Fold and Rotate are found by menu-item name in Device Hub (Xcode 27); if one is
# not found the script prints every menu item so the name can be fixed below.

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
ID=76E19B9A-7011-48B9-A751-5621A1E7837C
OUT=~/Downloads/AppStoreScreenshots/Duo
HUB=/Applications/Xcode.app/Contents/Applications/DeviceHub.app
mkdir -p "$OUT"

BUNDLE=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$HUB/Contents/Info.plist")
open -b "$BUNDLE"; sleep 2

# menu_click "<exact item name>"  -- clicks the first menu item with that name, any menu
menu_click() {
  osascript - "$BUNDLE" "$1" <<'EOF'
on run argv
  set bid to item 1 of argv
  set target to item 2 of argv
  tell application "System Events"
    set p to first process whose bundle identifier is bid
    set frontmost of p to true
    repeat with m in menu bar items of menu bar 1 of p
      try
        repeat with mi in menu items of menu 1 of m
          if name of mi is target then
            click mi
            return "clicked " & target
          end if
        end repeat
      end try
    end repeat
    set found to ""
    repeat with m in menu bar items of menu bar 1 of p
      try
        repeat with mi in menu items of menu 1 of m
          set found to found & (name of m) & " > " & (name of mi) & linefeed
        end repeat
      end try
    end repeat
    return "NOT FOUND: " & target & linefeed & found
  end tell
end run
EOF
}

step() {  # step "<menu item>"
  R=$(menu_click "$1")
  case "$R" in NOT\ FOUND*) echo "$R"; exit 1 ;; esac
  sleep 3
}

shot() {  # shot <display> <W> <H> <pose> <scene>
  F="$OUT/Zudio-Duo-$4-$5.png"
  xcrun simctl io $ID screenshot --display=$1 "$F" >/dev/null 2>&1
  GW=$(sips -g pixelWidth "$F" | awk '/pixelWidth/{print $2}')
  GH=$(sips -g pixelHeight "$F" | awk '/pixelHeight/{print $2}')
  if [ "$GW" = "$2" ] && [ "$GH" = "$3" ]; then echo "OK   $(basename "$F")  ${GW}x${GH}"
  else echo "BAD  $(basename "$F")  got ${GW}x${GH}, need $2x$3"; fi
}

echo "In the Duo window (folded, upright): tap Generate so a song plays, and pick the style you want shown."
read -r -p "Press Return when a song is playing... "

echo "== Closed =="
shot 1 1398 2034 closed-portrait visuals
step "Rotate Left"
shot 1 2034 1398 closed-landscape visuals
step "Rotate Right"

echo "== Open =="
step "Unfold"
shot 3 2007 2853 open-portrait visuals
step "Rotate Left"
shot 3 2853 2007 open-landscape visuals
step "Rotate Right"

echo
echo "Tap the Tracks tab on the open display (upright)."
read -r -p "Press Return when Tracks is showing... "
shot 3 2007 2853 open-portrait tracks
step "Rotate Left"
shot 3 2853 2007 open-landscape tracks
step "Rotate Right"
step "Fold"

echo
echo "Done. Files are in $OUT"
open "$OUT"

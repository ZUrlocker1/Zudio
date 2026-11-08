#!/bin/bash
# Captures the iPhone Duo simulator's active display for the App Store.
# Usage:  bash ~/Downloads/Zudio/duo-shot.sh <pose> <name>
#   pose = closed-portrait | closed-landscape | open-portrait | open-landscape
#   name = a short word for the scene, e.g. visuals, tracks, songs
# Writes ~/Downloads/AppStoreScreenshots/Duo/Zudio-Duo-<pose>-<name>.png
# Required sizes: closed (outer) 1398x2034 or 2034x1398, open (inner) 2007x2853 or 2853x2007.

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
ID=76E19B9A-7011-48B9-A751-5621A1E7837C
POSE="$1"; NAME="$2"
OUT=~/Downloads/AppStoreScreenshots/Duo
mkdir -p "$OUT"

case "$POSE" in
  closed-portrait)  DISPLAY_ID=1; W=1398; H=2034 ;;
  closed-landscape) DISPLAY_ID=1; W=2034; H=1398 ;;
  open-portrait)    DISPLAY_ID=3; W=2007; H=2853 ;;
  open-landscape)   DISPLAY_ID=3; W=2853; H=2007 ;;
  *) echo "pose must be closed-portrait, closed-landscape, open-portrait or open-landscape"; exit 1 ;;
esac
[ -z "$NAME" ] && { echo "give a scene name, e.g. visuals"; exit 1; }

FILE="$OUT/Zudio-Duo-$POSE-$NAME.png"
xcrun simctl io $ID screenshot --display=$DISPLAY_ID "$FILE" 2>&1 | tail -1
GOT_W=$(sips -g pixelWidth "$FILE" | awk '/pixelWidth/{print $2}')
GOT_H=$(sips -g pixelHeight "$FILE" | awk '/pixelHeight/{print $2}')
if [ "$GOT_W" = "$W" ] && [ "$GOT_H" = "$H" ]; then
  echo "OK  $FILE  ${GOT_W}x${GOT_H}"
else
  echo "SIZE MISMATCH: got ${GOT_W}x${GOT_H}, need ${W}x${H}. Wrong pose or display; delete $FILE"
fi

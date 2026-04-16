#!/usr/bin/env bash
# release-dmg.sh — Package a pre-signed Zudio.app into a drag-to-install DMG.
# Usage: ./release-dmg.sh [path-to-Zudio.app]
# Defaults to ~/Downloads/Zudio.app if no argument given.

set -euo pipefail

VERSION="1.0"
APP_VER="${VERSION//./}"   # "1.0" → "10"
APP_SRC="${1:-${HOME}/Downloads/Zudio ${APP_VER}.app}"
TEAM_ID="K66MA9TR8Z"
SIGNING_IDENTITY="Developer ID Application: Zack Urlocker (${TEAM_ID})"
OUTPUT_DMG="${HOME}/Downloads/Zudio-${VERSION}.dmg"

DMG_WORK="/tmp/ZudioDMG"
DMG_STAGING="${DMG_WORK}/staging"
DMG_BACKGROUND="${DMG_WORK}/background.png"

WINDOW_W=560
WINDOW_H=340
ICON_SIZE=100

if [ ! -d "${APP_SRC}" ]; then
    echo "ERROR: App not found at: ${APP_SRC}"
    exit 1
fi

echo ""
echo "==> Source app: ${APP_SRC}"
echo "==> Output DMG: ${OUTPUT_DMG}"

# ---------------------------------------------------------------------------
# Step 1: Verify create-dmg is available
# ---------------------------------------------------------------------------
if ! command -v create-dmg &>/dev/null; then
    echo ""
    echo "ERROR: create-dmg not found. Install it with:"
    echo "  brew install create-dmg"
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 2: Generate background PNG (dark gradient + arrow)
# ---------------------------------------------------------------------------
echo ""
echo "==> [1/4] Generating DMG background..."
rm -rf "${DMG_WORK}"
mkdir -p "${DMG_STAGING}"

DMG_BACKGROUND="${DMG_BACKGROUND}" python3 - <<'PYEOF'
import struct, zlib, os

# Canvas: 560 x 340 (matches --window-size)
# Icons:  Zudio.app at x=130,y=160  |  Applications at x=430,y=160
# Arrow:  solid filled, shaft + arrowhead, pointing LEFT → RIGHT between icons

W, H = 560, 340

# --- Light grey background so Finder's black icon labels are readable ---
BG = (210, 210, 215)          # light grey
ARROW = (90, 90, 95)          # dark grey arrow

# Arrow geometry (all in pixel coords)
SHAFT_X1, SHAFT_X2 = 195, 355   # horizontal span of shaft
SHAFT_Y1, SHAFT_Y2 = 162, 178   # vertical span of shaft (16px tall)
HEAD_X1,  HEAD_X2  = 340, 395   # arrowhead x span (overlaps shaft end)
HEAD_TIP_Y         = 170         # vertical centre of arrowhead tip
HEAD_HALF          = 28          # half-height of arrowhead base (56px total)

def in_arrow(x, y):
    # Shaft rectangle
    if SHAFT_X1 <= x <= SHAFT_X2 and SHAFT_Y1 <= y <= SHAFT_Y2:
        return True
    # Arrowhead triangle: right-pointing, tip at (HEAD_X2, HEAD_TIP_Y)
    # Left edge of triangle is HEAD_X1; at any x the triangle spans
    # ± HEAD_HALF * (HEAD_X2 - x) / (HEAD_X2 - HEAD_X1) around HEAD_TIP_Y
    if HEAD_X1 <= x <= HEAD_X2:
        frac = (HEAD_X2 - x) / (HEAD_X2 - HEAD_X1)
        half = HEAD_HALF * frac
        if abs(y - HEAD_TIP_Y) <= half:
            return True
    return False

def write_png(path, pixels):
    def chunk(tag, data):
        c = zlib.crc32(tag + data) & 0xffffffff
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', c)
    raw = b''
    for row in pixels:
        raw += b'\x00' + bytes(row)
    compressed = zlib.compress(raw, 9)
    ihdr = struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', ihdr))
        f.write(chunk(b'IDAT', compressed))
        f.write(chunk(b'IEND', b''))

pixels = []
for y in range(H):
    row = []
    for x in range(W):
        if in_arrow(x, y):
            row.extend(ARROW)
        else:
            row.extend(BG)
    pixels.append(row)

out = os.environ.get('DMG_BACKGROUND', '/tmp/ZudioDMG/background.png')
write_png(out, pixels)
print(f'    Background written: {out}')
PYEOF

# ---------------------------------------------------------------------------
# Step 3: Stage the app and build the DMG
# ---------------------------------------------------------------------------
echo ""
echo "==> [2/4] Staging app..."
cp -R "${APP_SRC}" "${DMG_STAGING}/Zudio.app"

echo ""
echo "==> [3/4] Building drag-to-install DMG..."
create-dmg \
    --volname "Zudio ${VERSION}" \
    --background "${DMG_BACKGROUND}" \
    --window-pos 200 120 \
    --window-size ${WINDOW_W} ${WINDOW_H} \
    --icon-size ${ICON_SIZE} \
    --icon "Zudio.app" 130 160 \
    --app-drop-link 430 160 \
    --hide-extension "Zudio.app" \
    --no-internet-enable \
    "${OUTPUT_DMG}" \
    "${DMG_STAGING}/"

# ---------------------------------------------------------------------------
# Step 4: Sign the DMG
# ---------------------------------------------------------------------------
echo ""
echo "==> [4/4] Signing DMG..."
codesign --force --sign "${SIGNING_IDENTITY}" "${OUTPUT_DMG}"
codesign --verify "${OUTPUT_DMG}"
echo "    DMG signature verified OK."

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Done!  ${OUTPUT_DMG}"
echo ""
echo " Verify checklist:"
echo "   1. Open the DMG — Zudio.app on left, Applications on right, arrow visible"
echo "   2. Drag Zudio.app to Applications and launch"
echo "   3. About dialog shows version 1.0"
echo "   4. spctl --assess --verbose=4 --type exec \"${APP_SRC}\""
echo "============================================================"
echo ""

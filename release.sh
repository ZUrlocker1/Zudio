#!/usr/bin/env bash
# release.sh — Build, sign, notarize, and package Zudio as a drag-to-install DMG.
#
# Usage:
#   ./release.sh
#
# Prerequisites:
#   - Xcode command-line tools installed
#   - Developer ID Application certificate in your keychain
#   - App-specific password stored in keychain under the label "AC_PASSWORD"
#     (create one at appleid.apple.com → App-Specific Passwords, then:
#      xcrun notarytool store-credentials "AC_PASSWORD" \
#        --apple-id YOUR_APPLE_ID --team-id K66MA9TR8Z --password THE_APP_PASSWORD)
#   - create-dmg installed: brew install create-dmg
#
# What it does:
#   1. Clean + build universal binary (arm64 + x86_64) with Release config
#   2. Fix the icon path inside the bundle (CFBundleIconFile quirk)
#   3. Sign with Developer ID + hardened runtime + entitlements
#   4. Submit to Apple notarization and wait for approval
#   5. Staple the notarization ticket to the .app
#   6. Create a drag-to-install DMG (app + Applications alias + arrow background)
#   7. Sign the DMG itself
#   8. Print the output path — verify it before pushing to GitHub/sharing

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCHEME="Zudio"
BUNDLE_ID="com.zudio.app"
TEAM_ID="K66MA9TR8Z"
VERSION="0.95"
SIGNING_IDENTITY="Developer ID Application: Zack Urlocker (${TEAM_ID})"
NOTARYTOOL_PROFILE="AC_PASSWORD"          # keychain profile name set up with xcrun notarytool store-credentials
ENTITLEMENTS="$(pwd)/Zudio.entitlements"

DERIVED_DATA_PATH="/tmp/ZudioBuild"
BUILD_DIR="${DERIVED_DATA_PATH}/Build/Products/Release"
APP_NAME="Zudio.app"
APP_SRC="${BUILD_DIR}/${APP_NAME}"

DMG_DIR="/tmp/ZudioDMG"
DMG_STAGING="${DMG_DIR}/staging"
DMG_BACKGROUND="${DMG_DIR}/background.png"
OUTPUT_DMG="${HOME}/Downloads/Zudio-${VERSION}.dmg"

WINDOW_W=560
WINDOW_H=340
ICON_SIZE=100

# ---------------------------------------------------------------------------
# Step 1: Build universal binary
# ---------------------------------------------------------------------------
echo ""
echo "==> [1/7] Building universal binary..."
xcodebuild \
    -scheme "${SCHEME}" \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -destination "platform=macOS" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    clean build

# ---------------------------------------------------------------------------
# Step 2: Fix icon path (CFBundleIconFile looks in Resources/, not Resources/assets/)
# ---------------------------------------------------------------------------
echo ""
echo "==> [2/7] Fixing icon path in bundle..."
ICON_SRC="${APP_SRC}/Contents/Resources/assets/zudio-icon.icns"
ICON_DST="${APP_SRC}/Contents/Resources/zudio-icon.icns"
if [ -f "${ICON_SRC}" ] && [ ! -f "${ICON_DST}" ]; then
    cp "${ICON_SRC}" "${ICON_DST}"
fi

DOC_ICON_SRC="${APP_SRC}/Contents/Resources/assets/zudio-doc.icns"
DOC_ICON_DST="${APP_SRC}/Contents/Resources/zudio-doc.icns"
if [ -f "${DOC_ICON_SRC}" ] && [ ! -f "${DOC_ICON_DST}" ]; then
    cp "${DOC_ICON_SRC}" "${DOC_ICON_DST}"
fi

# ---------------------------------------------------------------------------
# Step 3: Sign with Developer ID + hardened runtime
# ---------------------------------------------------------------------------
echo ""
echo "==> [3/7] Signing with Developer ID..."
codesign \
    --force \
    --deep \
    --options runtime \
    --entitlements "${ENTITLEMENTS}" \
    --sign "${SIGNING_IDENTITY}" \
    "${APP_SRC}"

codesign --verify --deep --strict "${APP_SRC}"
echo "    Signature verified OK."

# ---------------------------------------------------------------------------
# Step 4: Notarize
# ---------------------------------------------------------------------------
echo ""
echo "==> [4/7] Submitting for notarization (this takes 1-5 minutes)..."
NOTARIZE_ZIP="/tmp/Zudio-notarize.zip"
ditto -c -k --keepParent "${APP_SRC}" "${NOTARIZE_ZIP}"

xcrun notarytool submit "${NOTARIZE_ZIP}" \
    --keychain-profile "${NOTARYTOOL_PROFILE}" \
    --wait

rm -f "${NOTARIZE_ZIP}"
echo "    Notarization approved."

# ---------------------------------------------------------------------------
# Step 5: Staple
# ---------------------------------------------------------------------------
echo ""
echo "==> [5/7] Stapling notarization ticket..."
xcrun stapler staple "${APP_SRC}"
xcrun stapler validate "${APP_SRC}"
echo "    Staple verified OK."

# ---------------------------------------------------------------------------
# Step 6: Build drag-to-install DMG
# ---------------------------------------------------------------------------
echo ""
echo "==> [6/7] Creating drag-to-install DMG..."

# Require create-dmg
if ! command -v create-dmg &>/dev/null; then
    echo ""
    echo "ERROR: create-dmg not found. Install it with:"
    echo "  brew install create-dmg"
    exit 1
fi

rm -rf "${DMG_DIR}"
mkdir -p "${DMG_STAGING}"

# Generate a simple gradient background with an arrow using sips + Python
# (no external image editor required)
python3 - <<'PYEOF'
import struct, zlib, os

# 560x340 PNG with a dark gradient and a white arrow pointing right
W, H = 560, 340

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
    # light grey background
    r = g = b = 230
    for x in range(W):
        # right-pointing chevron centred between icons at x=280, y=H//2
        ax, ay = 280, H // 2
        dx, dy = x - ax, y - ay
        # upper arm: rises left-to-right (dy = -dx * 0.7, dx > 0)
        # lower arm: falls left-to-right (dy = +dx * 0.7, dx > 0)
        on_arrow = (
            (abs(dy + dx * 0.7) < 5 and 0 <= dx <= 28 and dy <= 0) or
            (abs(dy - dx * 0.7) < 5 and 0 <= dx <= 28 and dy >= 0)
        )
        if on_arrow:
            row.extend([100, 100, 100])  # dark grey arrow, readable on light bg
        else:
            row.extend([r, g, b])
    pixels.append(row)

out = os.environ.get('DMG_BACKGROUND', '/tmp/ZudioDMG/background.png')
write_png(out, pixels)
print(f'Background written to {out}')
PYEOF

# Copy app into staging
cp -R "${APP_SRC}" "${DMG_STAGING}/${APP_NAME}"

# create-dmg handles the Applications symlink and layout automatically
create-dmg \
    --volname "Zudio ${VERSION}" \
    --background "${DMG_BACKGROUND}" \
    --window-pos 200 120 \
    --window-size ${WINDOW_W} ${WINDOW_H} \
    --icon-size ${ICON_SIZE} \
    --icon "${APP_NAME}" 130 160 \
    --app-drop-link 430 160 \
    --hide-extension "${APP_NAME}" \
    --no-internet-enable \
    "${OUTPUT_DMG}" \
    "${DMG_STAGING}/"

echo "    DMG created at: ${OUTPUT_DMG}"

# ---------------------------------------------------------------------------
# Step 7: Sign the DMG
# ---------------------------------------------------------------------------
echo ""
echo "==> [7/7] Signing DMG..."
codesign \
    --force \
    --sign "${SIGNING_IDENTITY}" \
    "${OUTPUT_DMG}"

codesign --verify "${OUTPUT_DMG}"
echo "    DMG signature verified OK."

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Build complete!"
echo " Output: ${OUTPUT_DMG}"
echo ""
echo " Verify before releasing:"
echo "   1. Open the DMG — confirm Zudio.app + Applications arrow"
echo "   2. Drag Zudio.app to Applications and launch it"
echo "   3. Check About dialog shows version ${VERSION}"
echo "   4. spctl --assess --type exec -v '${OUTPUT_DMG}'"
echo "============================================================"
echo ""

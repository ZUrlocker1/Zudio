#!/usr/bin/env bash
# build zudio script.sh — Build Zudio (Debug, macOS) and install it to a fixed
# local path so Finder/Messages file-association testing always launches
# today's build, never a stale copy left over from an old DerivedData hash
# or an old Downloads/.app copy.
#
# Usage: ./"build zudio script.sh"

set -euo pipefail

SCHEME="Zudio"
CONFIG="Debug"
DEST_APP="$HOME/Applications/Zudio-Dev.app"
# Also mirrored here — this is the path already registered as the "Open With"
# handler for .zudio files, so keeping it in sync means Finder/Messages always
# launch today's build with no "Get Info -> Open With" step required.
DOWNLOADS_APP="$HOME/Downloads/Zudio.app"

cd "$(dirname "$0")"

echo ""
echo "==> Building ${SCHEME} (${CONFIG})..."
xcodebuild -project Zudio.xcodeproj -scheme "${SCHEME}" -configuration "${CONFIG}" build

BUILT_PRODUCTS_DIR=$(xcodebuild -project Zudio.xcodeproj -scheme "${SCHEME}" -configuration "${CONFIG}" -showBuildSettings 2>/dev/null \
    | awk -F'= ' '/ BUILT_PRODUCTS_DIR =/ { print $2; exit }')
SRC_APP="${BUILT_PRODUCTS_DIR}/${SCHEME}.app"

if [ ! -d "${SRC_APP}" ]; then
    echo "ERROR: Build succeeded but app not found at: ${SRC_APP}"
    exit 1
fi

echo ""
echo "==> Installing to ${DEST_APP}..."
mkdir -p "$(dirname "${DEST_APP}")"
rm -rf "${DEST_APP}"
cp -R "${SRC_APP}" "${DEST_APP}"

echo ""
echo "==> Mirroring to ${DOWNLOADS_APP} (the registered .zudio file handler)..."
rm -rf "${DOWNLOADS_APP}"
cp -R "${DEST_APP}" "${DOWNLOADS_APP}"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${DEST_APP}/Contents/Info.plist" 2>/dev/null || echo "?")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${DEST_APP}/Contents/Info.plist" 2>/dev/null || echo "?")

echo ""
echo "============================================================"
echo " Done! Installed Zudio ${VERSION} (build ${BUILD}) to:"
echo "   ${DEST_APP}"
echo "   ${DOWNLOADS_APP}"
echo ""
echo " First time only: right-click a .zudio file -> Get Info ->"
echo " Open With -> select ${DOWNLOADS_APP} -> Change All..."
echo "============================================================"
echo ""

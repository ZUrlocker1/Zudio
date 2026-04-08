#!/usr/bin/env bash
# tools/run_loop.sh — Zudio automated quality loop
#
# Usage:
#   cd ~/Downloads/Zudio && bash tools/run_loop.sh [style]
#
#   style: motorik | kosmic | chill | ambient (default: kosmic)
#
# What it does:
#   1. Builds and runs the batch test for the given style
#   2. Runs the style-specific analyzer on the output
#   3. Prints the report
#
# NOTE: Must be run from a regular Terminal (not from Claude Code).
#       xcodebuild test needs a GUI session / LaunchServices context.

set -euo pipefail

STYLE="${1:-kosmic}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Map style → test suite name and analyzer script
case "$STYLE" in
  motorik)
    TEST_SUITE="ZudioTests/MotorikBatchTests"
    BATCH_DIR="$SCRIPT_DIR/batch-output/motorik"
    ANALYZER="$SCRIPT_DIR/analyze_zudio.py"
    ;;
  kosmic)
    TEST_SUITE="ZudioTests/KosmicBatchTests"
    BATCH_DIR="$SCRIPT_DIR/batch-output/kosmic"
    ANALYZER="$SCRIPT_DIR/kosmic_analyze.py"
    ;;
  chill)
    TEST_SUITE="ZudioTests/ChillBatchTests"
    BATCH_DIR="$SCRIPT_DIR/batch-output/chill"
    ANALYZER="$SCRIPT_DIR/chill_analyze.py"
    ;;
  ambient)
    TEST_SUITE="ZudioTests/AmbientBatchTests"
    BATCH_DIR="$SCRIPT_DIR/batch-output/ambient"
    ANALYZER="$SCRIPT_DIR/analyze_zudio.py"
    ;;
  *)
    echo "Unknown style: $STYLE"
    echo "Usage: $0 [motorik|kosmic|chill|ambient]"
    exit 1
    ;;
esac

echo ""
echo "=== Zudio Quality Loop — $STYLE ==="
echo "Test suite : $TEST_SUITE"
echo "Output dir : $BATCH_DIR"
echo ""

# Step 1 — Run the batch test (build + test)
echo "--- Step 1: Generating batch ---"
xcodebuild test \
  -scheme Zudio \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY="Apple Development" \
  -only-testing:"$TEST_SUITE" \
  2>&1 | grep -E "=== Gen|${STYLE}_| [0-9]+\.|BPM|passed|FAILED|error:" || true

# Check output was produced
MID_COUNT=$(find "$BATCH_DIR" -name "*.MID" 2>/dev/null | wc -l | tr -d ' ')
if [ "$MID_COUNT" -eq 0 ]; then
  echo ""
  echo "ERROR: No .MID files found in $BATCH_DIR"
  echo "The batch test may have failed to run."
  exit 1
fi
echo ""
echo "Generated $MID_COUNT songs in $BATCH_DIR"

# Step 2 — Analyze
if [ -f "$ANALYZER" ]; then
  echo ""
  echo "--- Step 2: Analyzing ---"
  cd "$BATCH_DIR" && python3 "$ANALYZER" *.MID
else
  echo ""
  echo "Analyzer not found: $ANALYZER"
  echo "Skipping analysis. MID files are in: $BATCH_DIR"
fi

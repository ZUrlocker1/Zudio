#!/usr/bin/env bash
# Downloads arcade/NES/Genesis MIDI files from vgmusic.com for Motorik Arcade research
set -euo pipefail

OUT=~/Downloads/Arcade-MIDIs
mkdir -p "$OUT"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

fetch_midis() {
    local base_url="$1"
    local pattern="$2"
    local label="$3"
    echo ""
    echo "==> Fetching $label index..."
    local index
    index=$(curl -s -A "$UA" "$base_url")
    local files
    files=$(echo "$index" | grep -oi 'href="[^"]*\.mid"' | sed 's/href="//;s/"//' | grep -i "$pattern" || true)
    local count=0
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        local fname
        fname=$(basename "$f")
        if [ ! -f "$OUT/$fname" ]; then
            echo "    Downloading: $fname"
            curl -s -A "$UA" "${base_url}${f}" -o "$OUT/$fname" || echo "    FAILED: $fname"
        else
            echo "    Already have: $fname"
        fi
        count=$((count + 1))
    done <<< "$files"
    echo "    $label: $count files found"
}

# NES games
NES="https://www.vgmusic.com/music/console/nintendo/nes/"
fetch_midis "$NES" "mega.man\|megaman\|mega_man" "Mega Man (NES)"
fetch_midis "$NES" "castlevania" "Castlevania (NES)"
fetch_midis "$NES" "contra" "Contra (NES)"
fetch_midis "$NES" "gradius" "Gradius (NES)"

# Genesis games
GEN="https://www.vgmusic.com/music/console/sega/genesis/"
fetch_midis "$GEN" "outrun\|out_run\|out-run" "OutRun (Genesis)"
fetch_midis "$GEN" "sonic" "Sonic (Genesis)"

# Arcade games
ARC="https://www.vgmusic.com/music/other/miscellaneous/arcade/"
fetch_midis "$ARC" "street.fighter\|sf2\|sf_2" "Street Fighter II (Arcade)"
fetch_midis "$ARC" "gradius" "Gradius (Arcade)"
fetch_midis "$ARC" "arkanoid" "Arkanoid (Arcade)"
fetch_midis "$ARC" "galaga" "Galaga (Arcade)"
fetch_midis "$ARC" "contra" "Contra (Arcade)"

echo ""
echo "============================================================"
echo " Done! Files saved to: $OUT"
ls "$OUT" | wc -l | xargs echo " Total files:"
ls "$OUT"
echo "============================================================"

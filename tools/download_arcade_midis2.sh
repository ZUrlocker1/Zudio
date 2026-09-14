#!/usr/bin/env bash
# Downloads MIDI files from reference artists cited in motorik-arcade-plan.md:
#   - Tempest 2000 (KHInsider)
#   - Carpenter Brut fan transcriptions (Nonstop2k, Doomworld)
#   - Additional VGMusic arcade games (Bubble Bobble, Double Dragon, Final Fight,
#     Golden Axe, Arkanoid, Gyruss, R-Type, Raiden, Pac-Man, Donkey Kong, Asteroids)
#
# Run from any directory. Files land in ~/Downloads/Arcade-MIDIs/
# Sources that block hotlinking will print BLOCKED — those require manual download.

set -euo pipefail

OUT=~/Downloads/Arcade-MIDIs
mkdir -p "$OUT"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
BLOCKED=()

# ---------------------------------------------------------------------------
# Helper: download all .mid links from a vgmusic index page matching a pattern
# ---------------------------------------------------------------------------
vgmusic_fetch() {
    local base_url="$1"
    local pattern="$2"
    local label="$3"
    echo ""
    echo "==> VGMusic: $label..."
    local index
    index=$(curl -sL -A "$UA" "$base_url")
    local files
    files=$(echo "$index" | grep -oi 'href="[^"]*\.mid"' | sed 's/href="//;s/"//' | grep -i "$pattern" || true)
    local count=0
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        local fname
        fname=$(basename "$f")
        if [ ! -f "$OUT/$fname" ]; then
            echo "    Downloading: $fname"
            curl -sL -A "$UA" "${base_url}${f}" -o "$OUT/$fname" || echo "    FAILED: $fname"
        else
            echo "    Already have: $fname"
        fi
        count=$((count + 1))
    done <<< "$files"
    echo "    Found: $count files"
}

# ---------------------------------------------------------------------------
# Helper: fetch a page and download all absolute .mid links found on it
# ---------------------------------------------------------------------------
page_fetch_midis() {
    local page_url="$1"
    local referer="$2"
    local label="$3"
    local subfolder="${4:-}"
    local dest="$OUT"
    [ -n "$subfolder" ] && dest="$OUT/$subfolder" && mkdir -p "$dest"
    echo ""
    echo "==> $label..."
    local html
    html=$(curl -sL -A "$UA" -H "Referer: $referer" "$page_url" 2>/dev/null || true)
    if [ -z "$html" ]; then
        echo "    BLOCKED or unreachable — add to manual list"
        BLOCKED+=("$label ($page_url)")
        return
    fi
    # Extract absolute .mid URLs
    local urls
    urls=$(echo "$html" | grep -oi 'https\?://[^"'\''<> ]*\.mid' | sort -u || true)
    local count=0
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        local fname
        fname=$(basename "$url" | sed 's/?.*//') # strip query strings
        [ -z "$fname" ] && fname="file_${count}.mid"
        if [ ! -f "$dest/$fname" ]; then
            echo "    Downloading: $fname"
            curl -sL -A "$UA" -H "Referer: $page_url" "$url" -o "$dest/$fname" || echo "    FAILED: $fname"
        else
            echo "    Already have: $fname"
        fi
        count=$((count + 1))
    done <<< "$urls"
    if [ "$count" -eq 0 ]; then
        echo "    No .mid links found on page (may require login or JS rendering)"
        BLOCKED+=("$label — no links parsed ($page_url)")
    else
        echo "    Downloaded: $count files → $dest"
    fi
}

# ---------------------------------------------------------------------------
# 1. KHInsider — Tempest 2000 (Atari Jaguar)
#    MIDI index page lists individual song links; each links to a detail page
#    from which the actual .mid is fetched. KHInsider uses a two-step pattern.
# ---------------------------------------------------------------------------
echo ""
echo "==> KHInsider: Tempest 2000 (Atari Jaguar)..."
KHINS_INDEX="https://www.khinsider.com/midi/jaguar/tempest-2000"
KHINS_BASE="https://www.khinsider.com"
KHINS_DEST="$OUT/Tempest2000"
mkdir -p "$KHINS_DEST"

# KHInsider index pages 403-block curl, but direct files.khinsider.com URLs work
# with no auth. Hardcoding confirmed URL + slug guesses from VGMPF track listing.
KHINS_FILE_BASE="https://files.khinsider.com/midifiles/jaguar/tempest-2000"
count=0
for slug in \
    "ingame" \
    "title" "title-screen" \
    "minds-eye" "mind-s-eye" \
    "digital-terror" \
    "constructive-demolition" \
    "ultra-yak" \
    "glide-control" \
    "2000-dub" \
; do
    url="${KHINS_FILE_BASE}/${slug}.mid"
    fname="tempest2000_${slug}.mid"
    if [ ! -f "$KHINS_DEST/$fname" ]; then
        http_code=$(curl -sL -o "$KHINS_DEST/$fname" -w "%{http_code}" \
            -A "$UA" -H "Referer: $KHINS_INDEX" "$url")
        if [ "$http_code" = "200" ]; then
            echo "    Downloaded: $fname"
            count=$((count + 1))
        else
            rm -f "$KHINS_DEST/$fname"
        fi
    else
        echo "    Already have: $fname"
        count=$((count + 1))
    fi
done
if [ "$count" -eq 0 ]; then
    echo "    No tracks downloaded — open $KHINS_INDEX in a browser to get exact filenames"
    BLOCKED+=("KHInsider Tempest 2000 — slug guesses failed, check page manually ($KHINS_INDEX)")
else
    echo "    Tempest 2000: $count files → $KHINS_DEST"
fi

# ---------------------------------------------------------------------------
# 2. Nonstop2k — BLOCKED: Cloudflare + subscription-gated, not scriptable
# ---------------------------------------------------------------------------
echo ""
echo "==> Nonstop2k: Carpenter Brut — SKIPPED (Cloudflare + paid subscription)"
BLOCKED+=("Nonstop2k Carpenter Brut — subscription service, not scriptable (https://www.nonstop2k.com/midi-files/archive.php?key=carpenter-brut)")

# ---------------------------------------------------------------------------
# 3. Doomworld — BLOCKED: Cloudflare, no usable archive snapshot
# ---------------------------------------------------------------------------
echo "==> Doomworld: Carpenter Brut thread — SKIPPED (Cloudflare-blocked, no archive)"
BLOCKED+=("Doomworld Carpenter Brut thread — Cloudflare-blocked (https://www.doomworld.com/forum/topic/152862-my-carpenter-brut-midis/)")

# ---------------------------------------------------------------------------
# 4. Online Sequencer — Carpenter Brut fan transcriptions
#    Direct download: https://onlinesequencer.net/midi/{id}  (no login required)
#    Multiple transcriptions per song — downloading all variants
# ---------------------------------------------------------------------------
echo ""
echo "==> OnlineSequencer: Carpenter Brut fan MIDIs..."
CB_DEST="$OUT/CarpenterBrut"
mkdir -p "$CB_DEST"

os_download() {
    local id="$1"
    local label="$2"
    local fname="CB_${label// /_}_${id}.mid"
    if [ ! -f "$CB_DEST/$fname" ]; then
        http_code=$(curl -sL -o "$CB_DEST/$fname" -w "%{http_code}" \
            -A "$UA" -H "Referer: https://onlinesequencer.net/${id}" \
            "https://onlinesequencer.net/midi/${id}")
        if [ "$http_code" = "200" ]; then
            echo "    Downloaded: $fname"
        else
            rm -f "$CB_DEST/$fname"
            echo "    FAILED ($http_code): $fname"
        fi
    else
        echo "    Already have: $fname"
    fi
}

os_download 1989888 "Turbo_Killer"
os_download 1445277 "Turbo_Killer_v2"
os_download 3401360 "Turbo_Killer_WIP"
os_download 1450145 "Maniac"
os_download 1453480 "Maniac_v2"
os_download 1484666 "Escape_From_Midwich_Valley"
os_download 1866913 "Roller_Mobster"
os_download 2819396 "Roller_Mobster_v2"
os_download 3064709 "Youre_Mine"
os_download 3751290 "Le_Perv"
echo "    → $CB_DEST"

# ---------------------------------------------------------------------------
# 4. Perturbator — Technoir (Steam Community Workshop item)
#    Steam Workshop items are not directly downloadable without the Steam client.
#    Noting as manual.
# ---------------------------------------------------------------------------
echo ""
echo "==> Perturbator: Technoir MIDI"
echo "    Steam Workshop items require the Steam client to download."
echo "    Manual: https://steamcommunity.com/sharedfiles/filedetails/?id=492259707"
BLOCKED+=("Perturbator Technoir — Steam Workshop, requires Steam client (manual download)")

# ---------------------------------------------------------------------------
# 5. Additional VGMusic arcade games not in the first script
# ---------------------------------------------------------------------------
ARC="https://www.vgmusic.com/music/other/miscellaneous/arcade/"
vgmusic_fetch "$ARC" "bubble.bobble\|bubbobble\|bubble_bobble" "Bubble Bobble (Arcade)"
vgmusic_fetch "$ARC" "double.dragon\|dbldragon\|double_dragon" "Double Dragon (Arcade)"
vgmusic_fetch "$ARC" "final.fight\|finalfight\|final_fight" "Final Fight (Arcade)"
vgmusic_fetch "$ARC" "golden.axe\|goldenaxe\|golden_axe" "Golden Axe (Arcade)"
vgmusic_fetch "$ARC" "gyruss" "Gyruss (Arcade)"
vgmusic_fetch "$ARC" "r.type\|rtype\|r_type" "R-Type (Arcade)"
vgmusic_fetch "$ARC" "raiden" "Raiden (Arcade)"
vgmusic_fetch "$ARC" "pac.man\|pacman\|pac_man" "Pac-Man (Arcade)"
vgmusic_fetch "$ARC" "donkey.kong\|dkong\|donkey_kong" "Donkey Kong (Arcade)"
vgmusic_fetch "$ARC" "asteroids" "Asteroids (Arcade)"
vgmusic_fetch "$ARC" "tempest" "Tempest (Arcade)"
vgmusic_fetch "$ARC" "defender" "Defender (Arcade)"
vgmusic_fetch "$ARC" "centipede" "Centipede (Arcade)"
vgmusic_fetch "$ARC" "space.invaders\|spaceinvaders\|space_invaders" "Space Invaders (Arcade)"
vgmusic_fetch "$ARC" "outrun\|out.run\|out_run" "OutRun (Arcade)"
vgmusic_fetch "$ARC" "afterburner\|after.burner\|after_burner" "After Burner (Arcade)"
vgmusic_fetch "$ARC" "thunder.blade\|thunderblade" "Thunder Blade (Arcade)"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Done! Files saved to: $OUT"
ls "$OUT" | wc -l | xargs echo " Subfolders/files at top level:"
echo ""
echo " Manual downloads needed:"
if [ ${#BLOCKED[@]} -eq 0 ]; then
    echo "   (none)"
else
    for b in "${BLOCKED[@]}"; do
        echo "   • $b"
    done
fi
echo "============================================================"

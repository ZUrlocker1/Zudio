#!/bin/bash
# Render a directory of MIDI files to .m4a using tools/render_midi.swift.
#
# Usage:
#     tools/render_midi_batch.sh [in-dir] [out-dir]
#
# Defaults to ~/Downloads/soho-midi -> ~/Downloads/soho-midi/audio.
#
# Renders to WAV via Apple's built-in GM synth, then transcodes to .m4a and deletes the WAV —
# a 4-minute render is ~86 MB as float WAV and ~6 MB as AAC, which matters when the disk is
# tight. Skips anything already rendered, so it is safe to re-run after adding files.
#
# NOTE: this needs CoreAudio's component registry, which is unavailable inside a sandbox —
# `auval -a` listing nothing is the tell. Run it from a normal shell.
set -uo pipefail

IN="${1:-$HOME/Downloads/soho-midi}"
OUT="${2:-$IN/audio}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[ -d "$IN" ] || { echo "no such input directory: $IN" >&2; exit 1; }
mkdir -p "$OUT" || exit 1
cd "$REPO" || exit 1

# swift-frontend writes a module cache; point it somewhere writable.
CACHE="${TMPDIR:-/tmp}/zudio-modcache"
mkdir -p "$CACHE"

shopt -s nullglob
count=0; failed=0
for f in "$IN"/*.mid "$IN"/*.MID; do
    base="$(basename "$f")"; base="${base%.*}"
    m4a="$OUT/$base.m4a"
    wav="$OUT/$base.wav"
    if [ -f "$m4a" ]; then echo "have: $base"; continue; fi

    swift -module-cache-path "$CACHE" tools/render_midi.swift "$f" "$wav" 2>/dev/null | tail -1
    if [ -s "$wav" ]; then
        if ffmpeg -hide_banner -loglevel error -y -i "$wav" -c:a aac -b:a 192k "$m4a" 2>/dev/null; then
            rm -f "$wav"; count=$((count+1))
        else
            echo "  transcode FAILED (WAV kept): $base"; failed=$((failed+1))
        fi
    else
        echo "  render FAILED: $base"; rm -f "$wav"; failed=$((failed+1))
    fi
done

echo "---"
echo "$count rendered, $failed failed -> $OUT"
du -sh "$OUT" 2>/dev/null

#!/usr/bin/env python3
"""Fetch fan-transcribed MIDI for the Solo improvement plan (docs/Solo-improvement-plan.md).

Usage:
    python3 tools/fetch_solo_midi.py              # -> ~/Downloads/solo-improvement-midi/{motorik,kosmic}
    python3 tools/fetch_solo_midi.py <out-dir>
    python3 tools/fetch_solo_midi.py --list       # show matches, download nothing

Searches BitMidi only and reuses the helpers in fetch_kraftwerk_midi.py. MidiShow files need
a login, so fetch those by hand (links in the plan).

These are transcriptions of copyrighted compositions, held locally for listening and
analysis. The default output is outside the repo on purpose: do not commit them.
"""
import os, re, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fetch_kraftwerk_midi import search, get, safe_name, REJECT

# (style, label, [queries], [regexes the result name must match], keep)
# Motorik Europe already uses Autobahn, The Robots, Computer Love and Numbers.
TARGETS = [
    ("motorik", "Neon Lights",         ["kraftwerk neon lights", "neon lights"],      [r"neon\s*light"], 2),
    ("motorik", "The Model",           ["kraftwerk the model", "das model"],           [r"kraftwerk.*model", r"^the model", r"das model"], 2),
    ("motorik", "Trans-Europe Express", ["trans europe express", "trans-europa express"], [r"trans\W*europ"], 2),
    ("motorik", "Tour de France",      ["kraftwerk tour de france", "tour de france"], [r"tour\W*de\W*france"], 2),
    ("motorik", "Hallogallo",          ["neu hallogallo", "hallogallo"],               [r"hallo\W*gallo"], 2),
    ("motorik", "La Dusseldorf",       ["la dusseldorf", "silver cloud", "la dusseldorf viva"], [r"d[uü]sseldorf", r"silver\s*cloud"], 2),
    ("motorik", "Harmonia",            ["harmonia deluxe", "harmonia monza", "harmonia"], [r"harmonia"], 2),
    ("motorik", "Michael Rother",      ["michael rother", "flammende herzen"],         [r"michael\W*rother", r"flammende"], 2),
    ("kosmic",  "Pulstar",             ["vangelis pulstar", "pulstar"],                [r"pulstar"], 2),
    ("kosmic",  "Alpha",               ["vangelis alpha", "albedo alpha"],             [r"vangelis.*alpha|alpha.*vangelis"], 2),
    ("kosmic",  "Blade Runner",        ["blade runner vangelis", "blade runner love theme", "blade runner end titles"], [r"blade\s*runner"], 3),
    ("kosmic",  "Chariots of Fire",    ["vangelis chariots of fire", "chariots of fire"], [r"chariots"], 1),
    ("kosmic",  "Love on a Real Train", ["love on a real train", "tangerine dream"],   [r"real\s*train"], 2),
    ("kosmic",  "Tangerine Dream",     ["tangerine dream", "tangerine dream thief", "song of the whale"], [r"tangerine\W*dream", r"song of the whale"], 3),
]


def main():
    args = sys.argv[1:]
    list_only = "--list" in args
    args = [a for a in args if not a.startswith("--")]
    root = os.path.expanduser(args[0] if args else "~/Downloads/solo-improvement-midi")
    print("Listing only, nothing downloaded.\n" if list_only else f"Output: {root}\n")

    grabbed = 0
    for style, label, queries, require, keep in TARGETS:
        print(f"  [{style}] {label}")
        pool, seen = [], set()
        for q in queries:
            for name, url in search(q):
                low = name.lower()
                if url in seen or any(re.search(rx, low) for rx in REJECT):
                    continue
                if not any(re.search(rx, low) for rx in require):
                    continue
                seen.add(url)
                pool.append((name, url))
            if len(pool) >= keep:
                break
            time.sleep(0.4)
        if not pool:
            print("      no confirmed matches")
            continue
        out_dir = os.path.join(root, style)
        for name, url in pool[:keep]:
            if list_only:
                print(f"      {name}")
                continue
            os.makedirs(out_dir, exist_ok=True)
            dest = os.path.join(out_dir, safe_name(label, name))
            if os.path.exists(dest):
                print(f"      have: {os.path.basename(dest)}")
                continue
            try:
                blob = get(url, binary=True)
            except Exception as e:
                print(f"      FAILED {name}: {e}")
                continue
            if not blob.startswith(b"MThd"):
                print(f"      skipped {name}: not a MIDI file")
                continue
            with open(dest, "wb") as f:
                f.write(blob)
            grabbed += 1
            print(f"      saved: {os.path.basename(dest)} ({len(blob) / 1024:.0f} KB)")
            time.sleep(1.0)
    if not list_only:
        print(f"\n{grabbed} file(s) saved under {root}")


if __name__ == "__main__":
    main()

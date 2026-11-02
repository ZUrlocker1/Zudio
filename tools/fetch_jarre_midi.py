#!/usr/bin/env python3
"""Fetch fan-transcribed Jarre MIDI files for local analysis.

Usage:
    python3 tools/fetch_jarre_midi.py                 # -> ~/Downloads/jarre-midi
    python3 tools/fetch_jarre_midi.py <out-dir>
    python3 tools/fetch_jarre_midi.py --list          # show matches, download nothing

Then:
    python3 tools/jarre_analyze.py ~/Downloads/jarre-midi

WHAT THESE FILES ARE
These are fan transcriptions, not official releases — someone's ear, quantised.
They are useful for measuring structure (intervals, durations, cell lengths,
harmonic rhythm) and useless as ground truth for anything else. A measurement is
only worth turning into a Kosmic Space rule if it holds across several files.

The default output directory is OUTSIDE the repo on purpose. These are
transcriptions of copyrighted compositions, downloaded here for private
analysis; do not commit them, ship them, or copy them into assets/.
"""
import json, os, re, sys, time, urllib.parse, urllib.request

# The Kosmic Space corpus.
# Each entry: (label, [query variants], [regexes the RESULT NAME must match], keep)
#
# The "require" patterns exist because the search is fuzzy: querying "oxygene part 4"
# happily returns parts 2 and 3, which is how the first run produced duplicates of the
# wrong tracks. A result is only accepted if its own name confirms the part number.
#
# Names on bitmidi come in two spellings, "J.M.JARRE.Oxygene part 4.mid" and
# "Oxygene-(Part-4)-1.mid", so the part pattern allows punctuation and an optional
# "part" between title and number. Versions of the same part by different
# transcribers are all kept: they disagree, and agreement between them is evidence.
def _part(title, n):
    return rf"{title}\W*(part\W*)?{n}\b"

# Results whose name matches any of these are never taken: remixes and covers by
# other artists, which would measure someone else's arrangement.
EXCLUDE = [r"remix", r"shane 54", r"gubellini", r"sash", r"medley"]

TARGETS = [
    ("Oxygene 1", ["oxygene"], [_part("oxyg[eè]ne", 1)], 3),
    ("Oxygene 2", ["oxygene"], [_part("oxyg[eè]ne", 2)], 3),
    ("Oxygene 3", ["oxygene"], [_part("oxyg[eè]ne", 3)], 3),
    ("Oxygene 4", ["oxygene"], [_part("oxyg[eè]ne", 4)], 4),
    ("Oxygene 6", ["oxygene"], [_part("oxyg[eè]ne", 6)], 3),
    ("Oxygene 8", ["oxygene"], [_part("oxyg[eè]ne", 8)], 2),
    ("Oxygene", ["oxygene", "jean michel jarre"], [r"^(j\.m\.jarre\.)?ox[iy]g[eè]ne\.mid$"], 3),
    ("Equinoxe", ["equinoxe", "jean michel jarre"], [r"^(j\.m\.jarre\.)?equinoxe\.mid$"], 3),
    ("Magnetic Fields 1", ["magnetic fields"], [_part(r"magnetic\W*fields?", 1)], 3),
    ("Magnetic Fields 2", ["magnetic fields"], [_part(r"magnetic\W*fields?", 2)], 3),
    ("Magnetic Fields 4", ["magnetic fields"], [_part(r"magnetic\W*fields?", 4)], 3),
    ("Magnetic Fields 5", ["magnetic fields"], [_part(r"magnetic\W*fields?", 5)], 3),
    ("Chronologie 2", ["chronologie"], [_part("chronologie", 2)], 3),
    ("Chronologie 3", ["chronologie"], [_part("chronologie", 3)], 3),
    ("Chronologie 4", ["chronologie"], [_part("chronologie", 4)], 3),
    ("Chronologie 5", ["chronologie"], [_part("chronologie", 5)], 3),
    ("Chronologie 8", ["chronologie"], [_part("chronologie", 8)], 3),
    ("Rendez-Vous 2", ["rendez-vous"], [_part(r"rendez\W*vous", 2)], 2),
    ("Arpegiator", ["jean michel jarre"], [r"arpegiator"], 1),
]

API  = "https://bitmidi.com/api/midi/search?q={}&pageSize=50"
BASE = "https://bitmidi.com"
UA   = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Zudio-research/1.0"


def get(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read() if binary else json.loads(r.read().decode("utf-8", "replace"))


def search(query):
    """Returns [(name, absolute_download_url)] for one query string."""
    data = None
    for attempt in range(3):                      # the API sometimes drops the connection
        try:
            data = get(API.format(urllib.parse.quote(query)))
            break
        except Exception as e:
            if attempt == 2:
                print(f"      search failed: {e}")
                return []
            time.sleep(1.5)
    results = (data.get("result") or {}).get("results") or []
    out = []
    for r in results:
        dl = r.get("downloadUrl") or ""
        if not dl:
            continue
        out.append((r.get("name") or "untitled", dl if dl.startswith("http") else BASE + dl))
    return out


def safe_name(label, name):
    stem = "".join(c if c.isalnum() or c in " -_" else "_" for c in name)[:60].strip()
    return f"{label.replace(' ', '_')}__{stem or 'file'}.mid"


def main():
    args = [a for a in sys.argv[1:]]
    list_only = "--list" in args
    args = [a for a in args if not a.startswith("--")]
    out_dir = os.path.expanduser(args[0] if args else "~/Downloads/jarre-midi")

    if not list_only:
        os.makedirs(out_dir, exist_ok=True)
        print(f"Output: {out_dir}\n")
    else:
        print("Listing only — nothing will be downloaded.\n")

    grabbed = 0
    for label, queries, require, keep in TARGETS:
        print(f"  {label}")
        pool, seen_urls = [], set()
        for q in queries:
            for name, url in search(q):
                if url in seen_urls:
                    continue
                low = name.lower()
                if require and not any(re.search(rx, low) for rx in require):
                    continue                      # name does not confirm the part number
                if any(re.search(rx, low) for rx in EXCLUDE):
                    continue
                seen_urls.add(url)
                pool.append((name, url))
            if len(pool) >= keep:
                break
            time.sleep(0.4)
        if not pool:
            print("      no confirmed matches (searched: " + ", ".join(repr(q) for q in queries) + ")")
            continue
        for name, url in pool[:keep]:
            if list_only:
                print(f"      {name}")
                continue
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
            print(f"      saved: {os.path.basename(dest)}  ({len(blob)/1024:.0f} KB)")
            time.sleep(1.0)
        time.sleep(0.5)

    if not list_only:
        print(f"\n  {grabbed} file(s) downloaded to {out_dir}")
        print(f"  Next:  python3 tools/jarre_analyze.py {out_dir}")


if __name__ == "__main__":
    main()

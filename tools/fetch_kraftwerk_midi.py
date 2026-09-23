#!/usr/bin/env python3
"""Fetch fan-transcribed Kraftwerk MIDI files for local analysis.

Usage:
    python3 tools/fetch_kraftwerk_midi.py                 # -> ~/Downloads/kraftwerk-midi
    python3 tools/fetch_kraftwerk_midi.py <out-dir>
    python3 tools/fetch_kraftwerk_midi.py --list          # show matches, download nothing

Then:
    python3 tools/jarre_analyze.py ~/Downloads/kraftwerk-midi

(The analyser is corpus-agnostic despite the name — it takes any directory of MIDI.)

WHAT THESE FILES ARE
Fan transcriptions, not official releases. Useful for measuring structure — note density,
rest ratio, cell length, register separation, interval distribution — and useless as ground
truth for anything else. A measurement is only worth turning into a rule if it holds across
several files.

The default output directory is OUTSIDE the repo on purpose. These are transcriptions of
copyrighted compositions, held locally for private analysis; do not commit them, ship them,
or copy them into assets/.
"""
import json, os, re, sys, time, urllib.parse, urllib.request

# Six targets is plenty — the aim is a few strong rules per track, not exhaustive coverage.
# Each entry: (label, [query variants], [regexes the RESULT NAME must match], keep)
#
# The "require" patterns matter because these searches are fuzzy: a bare "kraftwerk" query
# returns remixes, tributes and covers, and a corpus polluted with those would describe the
# wrong decade.
TARGETS = [
    ("Autobahn",        ["kraftwerk autobahn", "autobahn"],
     [r"autobahn"], 2),
    ("The Robots",      ["kraftwerk the robots", "die roboter", "the robots"],
     [r"robot", r"roboter"], 2),
    ("Radioactivity",   ["kraftwerk radioactivity", "radioaktivitat", "radioactivity"],
     [r"radioactiv", r"radioaktiv"], 2),
    ("Computer Love",   ["kraftwerk computer love", "computer love"],
     [r"computer\s*love", r"computerliebe"], 2),
    ("Numbers",         ["kraftwerk numbers", "nummern"],
     [r"\bnumbers?\b", r"nummern"], 2),
    ("Spacelab",        ["kraftwerk spacelab", "spacelab"],
     [r"space\s*lab"], 2),
    # Also worth trying by hand if the above come up thin:
    #   Computer World / Computerwelt, Trans-Europe Express, Tour de France, Aero Dynamik
]

API  = "https://bitmidi.com/api/midi/search?q={}"
BASE = "https://bitmidi.com"
UA   = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Zudio-research/1.0"

# Names containing these are almost never the original studio arrangement.
REJECT = (r"remix", r"cover", r"tribute", r"karaoke", r"live", r"medley", r"megamix")


def get(url, binary=False):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read() if binary else json.loads(r.read().decode("utf-8", "replace"))


def search(query):
    """Returns [(name, absolute_download_url)] for one query string."""
    try:
        data = get(API.format(urllib.parse.quote(query)))
    except Exception as e:
        print(f"      search failed: {e}")
        return []
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
    out_dir = os.path.expanduser(args[0] if args else "~/Downloads/kraftwerk-midi")

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
                if any(re.search(rx, low) for rx in REJECT):
                    continue                       # remix / cover / live
                if require and not any(re.search(rx, low) for rx in require):
                    continue                       # name does not confirm the track
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
        print("  Note: Type 0 files merge all parts into one track — the analyser reports")
        print("  one stream for those. Split by MIDI channel to recover the parts.")


if __name__ == "__main__":
    main()

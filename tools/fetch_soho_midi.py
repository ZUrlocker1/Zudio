#!/usr/bin/env python3
"""Fetch fan-transcribed MIDI for the Chill Soho reference set.

Usage:
    python3 tools/fetch_soho_midi.py                  # -> ~/Downloads/soho-midi
    python3 tools/fetch_soho_midi.py <out-dir>
    python3 tools/fetch_soho_midi.py --list           # show matches, download nothing
    python3 tools/fetch_soho_midi.py --latin          # only the Latin half
    python3 tools/fetch_soho_midi.py --soul           # only the non-Latin half

Then:
    python3 tools/jarre_analyze.py ~/Downloads/soho-midi

(The analyser is corpus-agnostic despite the name — it takes any directory of MIDI.)

WHAT THESE FILES ARE
Fan transcriptions, not official releases. Useful for measuring structure — note density,
rest ratio, harmonic rhythm, register separation, interval distribution — and useless as
ground truth for anything else. A measurement is only worth turning into a rule if it holds
across several files. See tools/fetch_kraftwerk_midi.py, which this follows.

The default output directory is OUTSIDE the repo on purpose. These are transcriptions of
copyrighted compositions, held locally for private analysis; do not commit them, ship them,
or copy them into assets/.

WHAT WE ARE TRYING TO MEASURE
docs/chill-soho-plan.md lists four open questions this corpus should answer:
  1. Do the five drum rules hold up, or is Latin Sway too close to Bossa Clave to justify
     a separate rule?
  2. Is the tempo band really 88-108?
  3. Harmonic rhythm — does the "2-4 chord vamp that does not modulate" claim hold?
  4. Density — notes per bar per track, to set the space correctly rather than guessing.
The corpus is therefore split into a LATIN half and a SOUL half, matching the two
ChillBeatStyle cases, so each pool can be measured on its own rather than averaged together.
"""
import json, os, re, sys, time, urllib.parse, urllib.request

# Each entry: (half, label, [query variants], [regexes — ALL must match the RESULT NAME], keep)
#
# Note ALL, not any: this corpus is full of common English phrases, and an any-match filter
# let through Everything but the Girl's "Missing" for Night and Day, D-Ream and Gladys Knight
# for "the best thing", and Roxy Music's "More Than This" for Avalon. Requiring artist AND
# title together is what makes the filter reliable. Alternation inside one pattern covers
# naming variants, e.g. the Style Council also being filed under Weller or The Jam.
TARGETS = [
    # ---- Latin half: bossa, sway, samba ----
    ("latin", "Sade - Smooth Operator",
     ["sade smooth operator", "smooth operator"],
     [r"sade", r"smooth\s*operator"], 2),
    ("latin", "Sade - The Sweetest Taboo",
     ["sade sweetest taboo", "sweetest taboo", "sade"],
     [r"sade", r"sweetest\s*taboo"], 2),
    ("latin", "Steely Dan - Do It Again",
     ["steely dan do it again", "steely dan"],
     [r"steely", r"do\s*it\s*again"], 2),
    ("latin", "EBTG - Night and Day",
     ["everything but the girl night and day", "ebtg night and day",
      "everything but the girl"],
     [r"everything\s*but|ebtg", r"night\s*and\s*day"], 2),
    ("latin", "Matt Bianco - Half a Minute",
     ["matt bianco half a minute", "half a minute"],
     [r"bianco", r"half\s*a\s*minute"], 1),
    ("latin", "Basia - Time and Tide",
     ["basia time and tide", "basia"],
     [r"basia", r"time\s*and\s*tide"], 1),

    # ---- Soul half: backbeat and ballad ----
    ("soul", "Roxy Music - More Than This",
     ["roxy music more than this", "more than this"],
     [r"roxy", r"more\s*than\s*this"], 2),
    ("soul", "Roxy Music - Avalon",
     ["roxy music avalon", "avalon"],
     [r"roxy", r"avalon"], 2),
    ("soul", "Sade - No Ordinary Love",
     ["sade no ordinary love", "no ordinary love", "sade"],
     [r"sade", r"no\s*ordinary\s*love"], 2),
    ("soul", "Sade - Your Love Is King",
     ["sade your love is king", "your love is king"],
     [r"sade", r"your\s*love\s*is\s*king"], 2),
    ("soul", "Simply Red - Holding Back the Years",
     ["simply red holding back the years", "holding back the years"],
     [r"simply\s*red", r"holding\s*back"], 2),
    ("soul", "Style Council - You're the Best Thing",
     ["style council youre the best thing", "style council", "paul weller"],
     [r"style\s*council|weller", r"best\s*thing"], 2),
    ("soul", "Style Council - Long Hot Summer",
     ["style council long hot summer", "style council"],
     [r"style\s*council|weller", r"long\s*hot\s*summer"], 1),
    ("soul", "Steely Dan - Black Cow",
     ["steely dan black cow", "black cow"],
     [r"steely", r"black\s*cow"], 2),
    # Supplementary, not in docs/chill-soho-plan.md's named reference list. Sade is the anchor
    # artist for both halves and bitmidi carries a deep catalogue, so these widen the sample
    # for the density and harmonic-rhythm measurements without changing what the style is
    # modelled on. Drop them if the corpus is already big enough.
    ("soul", "Sade - Cherish the Day",
     ["sade cherish the day", "sade"], [r"sade", r"cherish\s*the\s*day"], 1),
    ("latin", "Sade - Kiss of Life",
     ["sade kiss of life", "sade"], [r"sade", r"kiss\s*of\s*life"], 1),
    # Worth trying by hand if the above come up thin:
    #   EBTG "Each and Every One", Style Council "The Paris Match"
    # CONFIRMED ABSENT from bitmidi as of 2026-10-10: the Style Council / Paul Weller catalogue
    # entirely, Basia entirely, and EBTG apart from "Missing" (a 90s drum-and-bass track, not
    # relevant here). Those three references need a different source or must be measured by ear.
]

API  = "https://bitmidi.com/api/midi/search?q={}"
BASE = "https://bitmidi.com"
UA   = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Zudio-research/1.0"

# Names containing these are almost never the original studio arrangement.
# "smooth jazz" is here because this corpus attracts lounge re-recordings in a way the
# Kraftwerk one did not — they flatten exactly the rhythmic detail we are trying to measure.
REJECT = (r"remix", r"cover", r"tribute", r"karaoke", r"live", r"medley", r"megamix",
          r"smooth\s*jazz", r"panflute", r"pan\s*flute", r"8\s*bit", r"ringtone")


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


def norm(name):
    """Lowercase and flatten separators before matching.

    bitmidi mixes naming conventions in the same corpus: "SADE.Your love is king.mid" but
    "sade-no_ordinary_love.mid". A pattern written with \\s* between words silently misses the
    underscore form, which is how "No Ordinary Love" was reported absent when it is in fact
    there. Treat _ - . and + as spaces so one pattern covers every convention.
    """
    return re.sub(r"[_\-.+]+", " ", name.lower())


def safe_name(half, label, name):
    stem = "".join(c if c.isalnum() or c in " -_" else "_" for c in name)[:60].strip()
    lab = label.replace(" ", "_").replace("/", "_")
    return f"{half}__{lab}__{stem or 'file'}.mid"


def main():
    args = sys.argv[1:]
    list_only = "--list" in args
    halves = {h for h in ("latin", "soul") if f"--{h}" in args} or {"latin", "soul"}
    args = [a for a in args if not a.startswith("--")]
    out_dir = os.path.expanduser(args[0] if args else "~/Downloads/soho-midi")

    if not list_only:
        os.makedirs(out_dir, exist_ok=True)
        print(f"Output: {out_dir}\n")
    else:
        print("Listing only — nothing will be downloaded.\n")

    grabbed, missing = 0, []
    for half, label, queries, require, keep in TARGETS:
        if half not in halves:
            continue
        print(f"  [{half}] {label}")
        pool, seen_urls = [], set()
        for q in queries:
            for name, url in search(q):
                if url in seen_urls:
                    continue
                low = norm(name)
                if any(re.search(rx, low) for rx in REJECT):
                    continue                       # remix / cover / live / lounge
                if require and not all(re.search(rx, low) for rx in require):
                    continue                       # artist AND title must both confirm
                seen_urls.add(url)
                pool.append((name, url))
            if len(pool) >= keep:
                break
            time.sleep(0.4)
        if not pool:
            print("      no confirmed matches (searched: "
                  + ", ".join(repr(q) for q in queries) + ")")
            missing.append(label)
            continue
        for name, url in pool[:keep]:
            if list_only:
                print(f"      {name}")
                continue
            dest = os.path.join(out_dir, safe_name(half, label, name))
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

    if missing:
        print("\n  No match: " + ", ".join(missing))
        print("  These are the less-transcribed acts; try bitmidi/freemidi by hand,")
        print("  or drop the target if the half already has three or more files.")

    if not list_only:
        print(f"\n  {grabbed} file(s) downloaded to {out_dir}")
        print(f"  Next:  python3 tools/jarre_analyze.py {out_dir}")
        print("  Filenames are prefixed latin__ / soul__ so the two pools can be measured")
        print("  separately — averaging them together would hide the distinction the")
        print("  substyle is built on.")
        print("  Note: Type 0 files merge all parts into one track — the analyser reports")
        print("  one stream for those. Split by MIDI channel to recover the parts.")


if __name__ == "__main__":
    main()

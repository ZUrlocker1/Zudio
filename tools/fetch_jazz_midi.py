#!/usr/bin/env python3
"""Fetch jazz horn MIDI for new Chill / Chill Blues Lead 1 rules.

Usage:
    python3 tools/fetch_jazz_midi.py                  # -> ~/Downloads/jazz-midi
    python3 tools/fetch_jazz_midi.py <out-dir>
    python3 tools/fetch_jazz_midi.py --list           # show matches, download nothing

Then:
    python3 tools/jazz_survey.py ~/Downloads/jazz-midi

TWO SOURCES
1. bitmidi.com fan arrangements (head, comping and sometimes a solo; quality varies). Files go
   in <out>/fan/. They are for listening, and for the head melodies and riffs.
2. The Weimar Jazz Database (Jazzomat, HfM Weimar): 456 hand-transcribed solos, solo line
   only, unquantized, released under the Open Database License (ODbL). The whole MIDI zip is
   fetched and the blues and ballad solos that fit Chill are copied to <out>/weimar/.
   Credit: Pfleiderer et al., "Inside the Jazzomat" (2017).

The output directory is OUTSIDE the repo on purpose: the fan files are transcriptions of
copyrighted compositions, held locally for private analysis. Do not commit them, ship them or
copy them into assets/. Rules built from them are homage transformations, never copies.
"""
import io, json, os, re, sys, time, urllib.parse, urllib.request, zipfile

# (label, [queries], [regexes, ALL must match the result name], keep)
FAN = [
    ("Miles Davis - All Blues",        ["m.davis", "all blues", "miles"],  [r"all.?blues"], 3),
    ("Miles Davis - So What",          ["m.davis"],                        [r"davis", r"so.?what"], 1),
    ("Miles Davis - Blue in Green",    ["m.davis", "blue in green"],       [r"blue.?in.?green"], 2),
    ("Miles Davis - Milestones",       ["m.davis"],                        [r"davis", r"milestones"], 1),
    ("Miles Davis - My Funny Valentine", ["m.davis"],                      [r"davis", r"funny"], 1),
    ("Miles Davis - Seven Steps",      ["m.davis"],                        [r"davis", r"7.?steps"], 1),
    ("Dizzy Gillespie - Night in Tunisia", ["gillespie"],                  [r"tunisia"], 1),
    ("Kenny Dorham - Blue Bossa",      ["dorham", "blue bossa", "kenny burrell"], [r"blue.?bossa", r"dorham"], 2),
    ("Sonny Rollins - St. Thomas",     ["rollins"],                        [r"thomas"], 1),
    ("Charlie Parker - Parker's Mood", ["parker"],                         [r"parker.?s.?mood"], 1),
    ("Charlie Parker - Now's the Time", ["now's the time"],                [r"now.?s.?the.?time"], 1),
    ("Thelonious Monk - Blue Monk",    ["blue monk"],                      [r"blue.?monk"], 1),
    ("Bobby Timmons - Moanin'",        ["moanin"],                         [r"moanin"], 2),
    ("Oliver Nelson - Stolen Moments", ["stolen moments"],                 [r"stolen.?moments"], 1),
    ("Horace Silver - Song for My Father", ["horace"],                     [r"song.?for.?my.?father"], 1),
    ("Herbie Hancock - Cantaloupe Island", ["hancock"],                    [r"cantal"], 1),
    ("Paul Desmond - Take Five",       ["desmond"],                        [r"desmond", r"take.?five"], 1),
]

# Weimar solos to copy out, matched against the zip's file names (Performer_Title_...).
# Blues and slow tunes first; the fast bebop is left in the full zip.
WEIMAR_PICKS = [
    r"MilesDavis_(VierdBlues|TranesBlues|BluesByFive|Walkin|KCBlues|SoWhat)",
    r"ChetBaker_(TwosBlues|LetsGetLost|IFallInLoveTooEasily|JustFriends)",
    r"DizzyGillespie_(BlueNBoogie|CognacBlues)",
    r"(Cannonball|JulianAdderley|CannonballAdderley).*_(WorkSong|ThisHere|SoWhat)",
    r"KennyDorham_(Doodlin|BluesInBe-?Bop)",
    r"LeeMorgan_(TheSidewinder|Sidewinder|BlueTrain)",
    r"J\.?J\.?Johnson_(Walkin|BlueMode)",
    r"SonnyRollins_(BlueSeven|TenorMadness)",
    r"CharlieParker_(BilliesBounce|BluesForAlice|KCBlues)",
]
WEIMAR_ZIP = "https://jazzomat.hfm-weimar.de/download/downloads/RELEASE2.0_mid_unquant.zip"

API  = "https://bitmidi.com/api/midi/search?q={}&pageSize=100"
BASE = "https://bitmidi.com"
UA   = {"User-Agent": "Mozilla/5.0 (Zudio corpus fetch)"}


def get(url, binary=False, tries=6):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                data = r.read()
            if not data:
                raise IOError("empty response")
            return data if binary else data.decode("utf-8", "replace")
        except Exception as e:
            if i == tries - 1:
                raise
            time.sleep(2)


def search(query):
    try:
        return json.loads(get(API.format(urllib.parse.quote(query)))).get("result", {}).get("results", [])
    except Exception as e:
        print(f"  search failed: {query}: {e}")
        return []


def safe(s):
    return re.sub(r"[^A-Za-z0-9._ '-]+", "_", s).strip()


def fetch_fan(out, list_only):
    os.makedirs(out, exist_ok=True)
    for label, queries, pats, keep in FAN:
        hits, seen = [], set()
        for q in queries:
            for r in search(q):
                n = r["name"]
                if n in seen or not all(re.search(p, n, re.I) for p in pats):
                    continue
                seen.add(n); hits.append(r)
            time.sleep(0.5)
        hits = hits[:keep]
        print(f"{label}: " + (" | ".join(h["name"] for h in hits) or "NOT FOUND"))
        if list_only:
            continue
        for i, h in enumerate(hits):
            url = BASE + h["downloadUrl"]
            dest = os.path.join(out, safe(f"{label} [{i+1}] {h['name']}"))
            if not dest.lower().endswith(".mid"):
                dest += ".mid"
            if os.path.exists(dest):
                continue
            try:
                open(dest, "wb").write(get(url, binary=True))
            except Exception as e:
                print(f"  download failed: {h['name']}: {e}")
            time.sleep(0.5)


def fetch_weimar(out, list_only):
    os.makedirs(out, exist_ok=True)
    zpath = os.path.join(out, "RELEASE2.0_mid_unquant.zip")
    if os.path.exists(zpath) and not zipfile.is_zipfile(zpath):
        os.remove(zpath)   # a truncated earlier download
    if not os.path.exists(zpath):
        if list_only:
            print("Weimar: zip not downloaded yet (run without --list)"); return
        print("Weimar: downloading zip ...")
        open(zpath, "wb").write(get(WEIMAR_ZIP, binary=True))
    with zipfile.ZipFile(zpath) as z:
        names = [n for n in z.namelist() if n.lower().endswith(".mid")]
        # File names keep apostrophes and dots (Trane'sBlues, K.C.); match with them removed.
        bare = lambda n: re.sub(r"['.]", "", os.path.basename(n)).replace("JJJohnson", "J.J.Johnson")
        picked = [n for n in names if any(re.search(p, bare(n), re.I) for p in WEIMAR_PICKS)]
        print(f"Weimar: {len(names)} solos in zip, {len(picked)} picked")
        for n in picked:
            print("  " + os.path.basename(n))
            if not list_only:
                open(os.path.join(out, os.path.basename(n)), "wb").write(z.read(n))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    list_only = "--list" in sys.argv
    root = os.path.expanduser(args[0] if args else "~/Downloads/jazz-midi")
    fetch_fan(os.path.join(root, "fan"), list_only)
    fetch_weimar(os.path.join(root, "weimar"), list_only)


if __name__ == "__main__":
    main()

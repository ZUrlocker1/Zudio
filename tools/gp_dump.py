#!/usr/bin/env python3
# Copyright (c) 2026 Zack Urlocker
"""gp_dump.py — survey or dump Guitar Pro 7 (.gp) tabs, which are zipped XML (Content/score.gpif).
Used for the Motorik Noir leads (docs/motorik-noir-plan.md, 2026-11-14). Run with python3 -I.

Usage:
  gp_dump.py FILE                 -> list tracks with note counts, pitch range, distinct pitches
  gp_dump.py FILE TRACK A-B       -> dump bars A..B of track index TRACK as note names on a 16th grid
"""
import sys, zipfile, xml.etree.ElementTree as ET, collections

NV = {"Whole": 64, "Half": 32, "Quarter": 16, "Eighth": 8, "16th": 4, "32nd": 2, "64th": 1}
NAMES = "C C# D Eb E F F# G Ab A Bb B".split()
STEP = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

def nn(m): return f"{NAMES[m % 12]}{m // 12 - 1}"

def load(path):
    z = zipfile.ZipFile(path)
    root = ET.fromstring(z.read("Content/score.gpif"))
    idx = lambda tag, sub: {e.get("id"): e for e in root.find(tag).findall(sub)}
    tracks = root.find("Tracks").findall("Track")
    bars, voices, beats, notes, rhythms = idx("Bars", "Bar"), idx("Voices", "Voice"), idx("Beats", "Beat"), idx("Notes", "Note"), idx("Rhythms", "Rhythm")
    masters = root.find("MasterBars").findall("MasterBar")
    tunings = []
    for t in tracks:
        tun = None
        for p in t.iter("Property"):
            if p.get("name") == "Tuning":
                tun = [int(x) for x in p.find("Pitches").text.split()]
                break
        tunings.append(tun)
    return tracks, masters, bars, voices, beats, notes, rhythms, tunings

def rdur(r):
    d = NV.get(r.find("NoteValue").text, 16)  # in 64ths
    a = r.find("AugmentationDot")
    if a is not None:
        c = int(a.get("count", "1")); d = d * (2 - 0.5 ** c)
    t = r.find("PrimaryTuplet")
    if t is not None: d = d * int(t.get("den")) / int(t.get("num"))
    return d / 4  # in 16ths

def pitch(n, tun):
    props = {p.get("name"): p for p in n.iter("Property")}
    if "Midi" in props: return int(props["Midi"].find("Number").text)
    if "String" in props and "Fret" in props and tun:
        return tun[int(props["String"].find("String").text)] + int(props["Fret"].find("Fret").text)
    if "ConcertPitch" in props:
        pe = props["ConcertPitch"].find("Pitch")
        s = STEP[pe.find("Step").text]; acc = pe.find("Accidental").text or ""
        s += acc.count("#") - acc.count("b")
        return 12 * (int(pe.find("Octave").text) + 1) + s
    return None

def events(path, ti):
    tracks, masters, bars, voices, beats, notes, rhythms, tunings = load(path)
    out = []  # (bar, pos16, midi, dur16, tied)
    for bi, mb in enumerate(masters):
        bid = mb.find("Bars").text.split()[ti]
        vids = bars[bid].find("Voices").text.split()
        for vid in vids[:1]:
            if vid == "-1": continue
            pos = 0.0
            for b in voices[vid].find("Beats").text.split():
                be = beats[b]; d = rdur(rhythms[be.find("Rhythm").get("ref")])
                ne = be.find("Notes")
                if ne is not None:
                    for nid in ne.text.split():
                        n = notes[nid]; tie = n.find("Tie")
                        tied = tie is not None and tie.get("destination") == "true"
                        p = pitch(n, tunings[ti])
                        if p is not None: out.append((bi, pos, p, d, tied))
                pos += d
    return tracks, masters, out

def survey(path):
    tracks, masters, *_ = load(path)
    print(f"{path.split('/')[-1]}  bars={len(masters)}")
    for ti, t in enumerate(tracks):
        _, _, ev = events(path, ti)
        ev = [e for e in ev if not e[4]]
        if not ev: print(f"  {ti} {t.findtext('Name')!r}: empty"); continue
        ps = [e[2] for e in ev]; barsw = len({e[0] for e in ev})
        chordy = sum(1 for k, v in collections.Counter((e[0], e[1]) for e in ev).items() if v > 1)
        print(f"  {ti} {t.findtext('Name')!r}: notes={len(ev)} bars={barsw} range={nn(min(ps))}-{nn(max(ps))} distinct={len(set(ps))} chordOnsets={chordy}")

def dump(path, ti, a, b):
    _, _, ev = events(path, ti)
    cur = None
    for bar, pos, p, d, tied in ev:
        if not (a <= bar <= b): continue
        if bar != cur: print(f"\nbar {bar}:", end=""); cur = bar
        print(f" {'~' if tied else ''}{nn(p)}@{pos:g}/{d:g}", end="")
    print()

if __name__ == "__main__":
    if len(sys.argv) == 2: survey(sys.argv[1])
    else:
        a, b = map(int, sys.argv[3].split("-")); dump(sys.argv[1], int(sys.argv[2]), a, b)

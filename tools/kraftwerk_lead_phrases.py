#!/usr/bin/env python3
"""kraftwerk_lead_phrases.py — what the melodic lines in the Kraftwerk corpus actually do.

Reads the source transcriptions and reports, per melodic track:
  - pitch-class vocabulary and compass
  - the interval histogram in SEMITONES (not scale steps)
  - the most repeated pitch figures, as intervals, with how often each recurs

The point is to find real starting phrases rather than invent them, and to measure how wide
the intervals in a Kraftwerk lead actually are.
"""
import sys, os
from collections import Counter, defaultdict
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kraftwerk_analyze import parse_midi

SOURCES = [
    ("The Robots",    os.path.expanduser("~/Downloads/kraftwerk - the robots.mid")),
    ("Autobahn",      os.path.expanduser("~/Downloads/kraftwerk - autobahn.mid")),
    ("Computer Love", os.path.expanduser("~/Downloads/kraftwerk - computer love.mid")),
]
NAMES = "C C# D D# E F F# G G# A A# B".split()


def melodic(name, notes):
    """A melodic line: enough notes, more than 3 distinct pitches, sitting above the bass."""
    if len(notes) < 24:
        return False
    pitches = [n[1] for n in notes]
    if len(set(pitches)) < 4:
        return False
    if sum(pitches) / len(pitches) < 52:      # bass register — not a lead
        return False
    lowered = name.lower()
    return not any(k in lowered for k in
                   ("drum", "kick", "snare", "hat", "tom", "perc", "brush", "bass"))


def figures(iv, lo=3, hi=6):
    """Most repeated interval n-grams, longest first, keeping only genuinely recurring ones."""
    out = []
    for n in range(hi, lo - 1, -1):
        c = Counter(tuple(iv[i:i+n]) for i in range(len(iv) - n + 1))
        for fig, count in c.most_common(3):
            if count >= 3 and any(x != 0 for x in fig):
                out.append((n, fig, count))
    return out[:6]


for title, path in SOURCES:
    if not os.path.exists(path):
        print(f"\n{title}: NOT FOUND at {path}")
        continue
    tracks, tpq = parse_midi(path)
    print(f"\n{'=' * 78}\n{title}  ({len(tracks)} tracks)\n{'=' * 78}")
    for name, notes in tracks:
        if not melodic(name, notes):
            continue
        pitches = [n[1] for n in notes]
        pcs = sorted({p % 12 for p in pitches})
        iv = [b - a for a, b in zip(pitches, pitches[1:])]
        if not iv:
            continue
        absiv = [abs(x) for x in iv if x != 0]
        steps = sum(1 for x in absiv if x <= 2)
        leaps = sum(1 for x in absiv if x >= 5)
        print(f"\n  --- {name.strip() or '(unnamed)'} --- {len(notes)} notes")
        print(f"      compass {min(pitches)}-{max(pitches)} ({max(pitches)-min(pitches)} semitones), "
              f"{len(pcs)} pitch classes: {' '.join(NAMES[p] for p in pcs)}")
        if absiv:
            print(f"      motion: {100*steps/len(absiv):.0f}% stepwise (<=2st), "
                  f"{100*leaps/len(absiv):.0f}% leaps (>=5st), "
                  f"median |interval| {sorted(absiv)[len(absiv)//2]}st, max {max(absiv)}st")
        rep = sum(1 for x in iv if x == 0)
        print(f"      repeated-note moves: {100*rep/len(iv):.0f}%")
        h = Counter(iv)
        top = ", ".join(f"{k:+d}:{100*v/len(iv):.0f}%" for k, v in h.most_common(8))
        print(f"      interval histogram: {top}")
        figs = figures(iv)
        if figs:
            print("      recurring figures (as intervals):")
            for n, fig, count in figs:
                print(f"        {n}-note  [{' '.join(f'{x:+d}' for x in fig)}]  x{count}")

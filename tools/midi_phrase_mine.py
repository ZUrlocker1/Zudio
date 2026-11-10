#!/usr/bin/env python3
"""Mine recurring short phrases from one track/channel of a MIDI file.

usage: python3 tools/midi_phrase_mine.py FILE TRACK CHANNEL [--gap BEATS] [--top N] [--dump BARS]
  TRACK  : track index (type-0 files: 0)
  CHANNEL: channel number, or -1 for all
Monophonic reduction: highest note per onset. Grid: 16ths. Phrases split at rests >= gap.
Signature = (interval sequence, onset-delta sequence) so transposed restatements match.
"""
import sys, collections, mido

NAMES = "C C# D D# E F F# G G# A A# B".split()
def nm(n): return f"{NAMES[n % 12]}{n // 12 - 1}"

args = sys.argv[1:]
f, ti, ch = args[0], int(args[1]), int(args[2])
gap = float(args[args.index("--gap") + 1]) if "--gap" in args else 1.0
top = int(args[args.index("--top") + 1]) if "--top" in args else 8
dump = args[args.index("--dump") + 1] if "--dump" in args else None

m = mido.MidiFile(f); tpb = m.ticks_per_beat; q = tpb // 4
now, on, notes = 0, {}, []
for e in m.tracks[ti]:
    now += e.time
    if e.type not in ("note_on", "note_off") or (ch >= 0 and e.channel != ch) or e.channel == 9:
        continue
    if e.type == "note_on" and e.velocity > 0:
        on[(e.channel, e.note)] = (now, e.velocity)
    elif (e.channel, e.note) in on:
        s, v = on.pop((e.channel, e.note))
        notes.append((round(s / q), e.note, max(1, round((now - s) / q)), v))
# monophonic: top note per onset
by = {}
for s, n, d, v in notes:
    if s not in by or n > by[s][1]: by[s] = (s, n, d, v)
mono = [by[k] for k in sorted(by)]
print(f"{len(notes)} notes, {len(mono)} onsets")

if dump:
    a, b = map(int, dump.split("-"))
    for bar in range(a, b + 1):
        row = [f"{s % 16}:{nm(n)}/{d}" for s, n, d, v in mono if s // 16 + 1 == bar]
        if row: print(f"bar {bar:3}  " + "  ".join(row))
    sys.exit()

phrases, cur = [], []
for x in mono:
    if cur and x[0] - (cur[-1][0] + cur[-1][2]) >= gap * 4:
        phrases.append(cur); cur = []
    cur.append(x)
if cur: phrases.append(cur)

sig = collections.defaultdict(list)
for p in phrases:
    if not 3 <= len(p) <= 16: continue
    iv = tuple(p[i + 1][1] - p[i][1] for i in range(len(p) - 1))
    rh = tuple(p[i + 1][0] - p[i][0] for i in range(len(p) - 1))
    sig[(iv, rh)].append(p)
ranked = sorted(sig.items(), key=lambda kv: (-len(kv[1]), -len(kv[0][0])))
print(f"{len(phrases)} phrases; recurring shapes:")
for (iv, rh), ps in ranked[:top]:
    p = ps[0]
    bars = sorted({x[0][0] // 16 + 1 for x in ps})
    print(f"\n x{len(ps)}  bars {bars[:12]}")
    print("   " + "  ".join(f"{x[0] - p[0][0]}:{nm(x[1])}/{x[2]}" for x in p))
    print(f"   intervals {list(iv)}  start step-in-bar {p[0][0] % 16}")

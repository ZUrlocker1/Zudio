#!/usr/bin/env python3
"""Analyse fan Eno MIDI (from tools/fetch_eno_midi.py) for the Ambient Zen plan.

Usage:
    python3 tools/eno_analyze.py docs/midi-analysis/eno/*.mid

Per file, overall and per track:
  key and mode (Krumhansl profile + scale fit), pitch-class use
  register (range, median), note lengths in beats, velocity
  polyphony: share of time with 0, 1, 2, 3+ notes sounding (silence / overlap)
  chord changes: per-bar dominant pitch-class set, how long each lasts
  repetition: the smallest bar period at which a track's bars repeat exactly
Times are in beats (quarter notes). Fan transcriptions: trust shapes, not details.
"""
import sys, collections, mido

NAMES = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B']
MAJ = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
MIN = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
MODES = {'Ionian': [0, 2, 4, 5, 7, 9, 11], 'Dorian': [0, 2, 3, 5, 7, 9, 10],
         'Phrygian': [0, 1, 3, 5, 7, 8, 10], 'Lydian': [0, 2, 4, 6, 7, 9, 11],
         'Mixolydian': [0, 2, 4, 5, 7, 9, 10], 'Aeolian': [0, 2, 3, 5, 7, 8, 10],
         'MajPent': [0, 2, 4, 7, 9], 'MinPent': [0, 3, 5, 7, 10]}


def nm(n): return f"{NAMES[n % 12]}{n // 12 - 1}"


def load(path):
    mid = mido.MidiFile(path)
    tpb, tempo = mid.ticks_per_beat, 500000
    tracks = []
    for t in mid.tracks:
        tick, on, notes, name = 0, {}, [], t.name or ''
        for m in t:
            tick += m.time
            if m.type == 'set_tempo': tempo = m.tempo
            if m.type == 'note_on' and m.velocity > 0:
                on.setdefault((m.channel, m.note), []).append((tick, m.velocity))
            elif m.type in ('note_off', 'note_on'):
                st = on.get((m.channel, m.note))
                if st:
                    s, v = st.pop(0)
                    notes.append((s / tpb, (tick - s) / tpb, m.note, v))
        if notes: tracks.append((name, sorted(notes)))
    return round(60_000_000 / tempo, 1), tracks


def corr(a, b):
    ma, mb = sum(a) / 12, sum(b) / 12
    num = sum((x - ma) * (y - mb) for x, y in zip(a, b))
    den = (sum((x - ma) ** 2 for x in a) * sum((y - mb) ** 2 for y in b)) ** 0.5
    return num / den if den else 0


def key_of(notes):
    w = [0.0] * 12
    for s, d, p, v in notes: w[p % 12] += d
    best = max([(corr(w, MAJ[-k:] + MAJ[:-k]), k, 'maj') for k in range(12)] +
               [(corr(w, MIN[-k:] + MIN[:-k]), k, 'min') for k in range(12)])
    tot = sum(w) or 1
    fits = []
    for r in range(12):
        for mname, iv in MODES.items():
            inside = sum(w[(r + i) % 12] for i in iv) / tot
            fits.append((round(inside, 3), -len(iv), NAMES[r], mname))
    fits.sort(reverse=True)
    pcs = sorted(range(12), key=lambda i: -w[i])
    return best, fits[:3], [(NAMES[i], round(w[i] / tot * 100)) for i in pcs if w[i] > 0]


def pct(xs, q):
    xs = sorted(xs); return xs[min(len(xs) - 1, int(q * len(xs)))]


def poly(notes, end):
    grid = collections.Counter()
    step = 0.25
    cover = [0] * (int(end / step) + 1)
    for s, d, p, v in notes:
        for i in range(int(s / step), min(len(cover), int((s + d) / step))):
            cover[i] += 1
    for c in cover: grid[min(c, 3)] += 1
    n = len(cover) or 1
    return {k: round(grid[k] / n * 100) for k in range(4)}


def bar_sets(notes, end, bpb=4):
    bars = int(end // bpb) + 1
    sets = [collections.Counter() for _ in range(bars)]
    for s, d, p, v in notes:
        b0, b1 = int(s // bpb), int((s + d - 1e-6) // bpb)
        for b in range(b0, min(bars, b1 + 1)):
            ov = min(s + d, (b + 1) * bpb) - max(s, b * bpb)
            sets[b][p % 12] += ov
    return sets


def chord_runs(notes, end):
    out = []
    for c in bar_sets(notes, end):
        tot = sum(c.values())
        top = frozenset(pc for pc, w in c.items() if tot and w / tot >= 0.12)
        out.append(top)
    runs = []
    for i, s in enumerate(out):
        if runs and runs[-1][0] == s: runs[-1][2] += 1
        else: runs.append([s, i, 1])
    return runs


def period(notes, end, bpb=4):
    bars = int(end // bpb) + 1
    sig = [tuple() for _ in range(bars)]
    tmp = collections.defaultdict(list)
    for s, d, p, v in notes:
        tmp[int(s // bpb)].append((round(s % bpb, 2), p, round(d, 2)))
    sig = [tuple(sorted(tmp[b])) for b in range(bars)]
    active = [i for i, x in enumerate(sig) if x]
    if len(active) < 4: return None
    for P in (1, 2, 3, 4, 5, 6, 7, 8, 12, 16):
        same = sum(1 for i in active if i + P < bars and sig[i + P] == sig[i])
        tot = sum(1 for i in active if i + P < bars)
        if tot and same / tot >= 0.6: return (P, round(same / tot * 100))
    return None


def report(path):
    bpm, tracks = load(path)
    allnotes = sorted(n for _, ns in tracks for n in ns)
    end = max(s + d for s, d, p, v in allnotes)
    print(f"\n=== {path.split('/')[-1]}  {bpm} bpm  {end / 4:.0f} bars  "
          f"{end * 60 / bpm:.0f} s  {len(allnotes)} notes  {len(tracks)} tracks")
    best, fits, pcs = key_of(allnotes)
    print(f"  key {NAMES[best[1]]} {best[2]} (r={best[0]:.2f}); mode fit "
          + ", ".join(f"{r} {m} {f * 100:.0f}%" for f, _, r, m in fits))
    print(f"  pitch classes by duration %: {pcs}")
    pl = poly(allnotes, end)
    print(f"  all-track sounding: silent {pl[0]}%  1 note {pl[1]}%  2 {pl[2]}%  3+ {pl[3]}%")
    for name, ns in tracks:
        ps = [p for _, _, p, _ in ns]; ds = [d for _, d, _, _ in ns]; vs = [v for *_, v in ns]
        first = ns[0][0]; last = max(s + d for s, d, _, _ in ns)
        pl = poly(ns, end)
        per = period(ns, end)
        print(f"  [{name}] {len(ns)} notes, bars {first / 4:.0f}-{last / 4:.0f}, "
              f"range {nm(min(ps))}-{nm(max(ps))} median {nm(pct(ps, .5))}, "
              f"len beats p10 {pct(ds, .1):.2f} med {pct(ds, .5):.2f} p90 {pct(ds, .9):.2f}, "
              f"vel {min(vs)}-{max(vs)}, silent {pl[0]}% 1:{pl[1]}% 2:{pl[2]}% 3+:{pl[3]}%, "
              f"repeat period {per[0]} bars ({per[1]}%)" if per else
              f"  [{name}] {len(ns)} notes, bars {first / 4:.0f}-{last / 4:.0f}, "
              f"range {nm(min(ps))}-{nm(max(ps))} median {nm(pct(ps, .5))}, "
              f"len beats p10 {pct(ds, .1):.2f} med {pct(ds, .5):.2f} p90 {pct(ds, .9):.2f}, "
              f"vel {min(vs)}-{max(vs)}, silent {pl[0]}% 1:{pl[1]}% 2:{pl[2]}% 3+:{pl[3]}%, no bar repeat")
        # simultaneous chord sizes on this track
        onsets = collections.Counter(round(s, 2) for s, *_ in ns)
        sizes = collections.Counter(min(c, 5) for c in onsets.values())
        print(f"      notes per onset: {dict(sorted(sizes.items()))}")
    runs = chord_runs(allnotes, end)
    print(f"  harmony runs (bar-level pitch-class sets, {len(runs)} runs):")
    line = []
    for s, b, n in runs:
        line.append(f"b{b}:{'-'.join(NAMES[x] for x in sorted(s)) or 'rest'}x{n}")
    for i in range(0, len(line), 6): print("    " + "  ".join(line[i:i + 6]))
    lens = [n for s, b, n in runs if s]
    if lens:
        print(f"  harmonic rhythm: median {pct(lens, .5)} bars, max {max(lens)}, "
              f"distinct sets {len({s for s, _, _ in runs if s})}")


if __name__ == '__main__':
    for p in sys.argv[1:]:
        try: report(p)
        except Exception as e: print(f"\n=== {p}: ERROR {e}")

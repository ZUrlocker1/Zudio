#!/usr/bin/env python3
"""soho_lead_phrases.py — what the sax/lead lines in the Chill Soho corpus actually play.

Usage:
    python3 tools/soho_lead_phrases.py [dir] [--role bass|lead] [--cells N]

The Motorik Europe lesson: prose descriptions of a lead ("phrases of 3-5 notes, resolving onto
a chord tone") did not produce usable melodies. What worked was a bank of CONCRETE cells
extracted from the source corpus, then varied — see `kraftwerkCells` in LeadGenerator.swift and
tools/kraftwerk_lead_phrases.py, which this follows.

Reports per melodic channel:
  - phrase lengths and the rests between them (the plan claims 3-5 notes, 2-4 bars silence)
  - note durations in 16th steps
  - the semitone interval histogram
  - CLOSURE: how often a phrase returns to its starting pitch. Kraftwerk cells are closed;
    whether sophisti-pop sax lines are is an open question this answers.
  - the most repeated interval figures, as candidate cells

Cells are printed as interval lists ready to paste into a Swift array, with the rhythm that
went with them, because a melodic cell without its rhythm is only half a phrase.
"""
import sys, os, glob, collections, statistics

try:
    import mido
except ImportError:
    sys.exit("mido not installed. Try: python3 -m pip install mido")

REED = range(64, 72)        # sax, oboe, clarinet
BRASS = range(56, 64)
PIPE = range(72, 80)        # flute, recorder
SYNTHLEAD = range(80, 88)
LEADISH = set(REED) | set(BRASS) | set(PIPE) | set(SYNTHLEAD)
BASSISH = set(range(32, 40))

NAMES = "C C# D D# E F F# G G# A A# B".split()


def load(path):
    mid = mido.MidiFile(path)
    tpb = mid.ticks_per_beat
    numer = 4
    progs, notes, open_n = {}, [], collections.defaultdict(list)
    for tr in mid.tracks:
        t = 0
        for msg in tr:
            t += msg.time
            if msg.type == "time_signature":
                numer = msg.numerator * 4 / msg.denominator
            elif msg.type == "program_change":
                progs.setdefault(msg.channel, msg.program)
            elif msg.type == "note_on" and msg.velocity > 0:
                n = [t, msg.note, msg.velocity, msg.channel, 0]
                notes.append(n)
                open_n[(msg.channel, msg.note)].append(n)
            elif msg.type == "note_off" or (msg.type == "note_on" and msg.velocity == 0):
                st = open_n.get((msg.channel, msg.note))
                if st:
                    n = st.pop(0)
                    n[4] = max(1, t - n[0])
    return notes, tpb, numer, progs


def phrases(seq, tpb, gap_beats=1.0):
    """Split a monophonic-ish line into phrases wherever the rest exceeds gap_beats."""
    out, cur = [], []
    gap = tpb * gap_beats
    for i, n in enumerate(seq):
        if cur:
            prev = cur[-1]
            rest = n[0] - (prev[0] + prev[4])
            if rest > gap:
                out.append((cur, rest))
                cur = []
        cur.append(n)
    if cur:
        out.append((cur, 0))
    return out


def analyse_channel(name, song, seq, tpb, numer):
    seq = sorted(seq, key=lambda n: n[0])
    # Collapse simultaneous notes to the top one — a sax line transcribed with harmony
    # doubling would otherwise read as a cluster of zero intervals.
    dedup, last_t = [], None
    for n in seq:
        if last_t is not None and n[0] - last_t < tpb / 16:
            if n[1] > dedup[-1][1]:
                dedup[-1] = n
            continue
        dedup.append(n)
        last_t = n[0]
    seq = dedup
    if len(seq) < 12:
        return None

    ph = phrases(seq, tpb)
    step = tpb / 4.0
    lens = [len(p) for p, _ in ph]
    rests = [r / (tpb * numer) for _, r in ph if r > 0]
    durs = [n[4] / step for n in seq]
    ivals = [seq[i + 1][1] - seq[i][1] for i in range(len(seq) - 1)]
    closed = sum(1 for p, _ in ph if len(p) > 2 and p[0][1] == p[-1][1])

    print(f"\n  {song} — ch{seq[0][3]}  ({len(seq)} notes, {len(ph)} phrases)")
    print(f"     phrase length : median {statistics.median(lens):.0f} notes  "
          f"range {min(lens)}-{max(lens)}")
    if rests:
        print(f"     rest between  : median {statistics.median(rests):.1f} bars  "
              f"max {max(rests):.1f}")
    print(f"     note duration : median {statistics.median(durs):.1f} steps  "
          f"range {min(durs):.0f}-{max(durs):.0f}")
    print(f"     compass       : {max(n[1] for n in seq) - min(n[1] for n in seq)} semitones")
    print(f"     closed phrases: {closed}/{len([1 for p,_ in ph if len(p)>2])}")
    ih = collections.Counter(abs(i) for i in ivals)
    top = ", ".join(f"{k}st x{v}" for k, v in ih.most_common(6))
    print(f"     intervals     : {top}")
    steps_leap = sum(v for k, v in ih.items() if k >= 5)
    print(f"     leaps >=5st   : {steps_leap}/{len(ivals)} ({100*steps_leap/max(1,len(ivals)):.0f}%)")
    return [tuple(seq[i + 1][1] - seq[i][1] for i in range(a, b))
            for a, b in _windows(len(seq))], ph, step


def _windows(n, lo=3, hi=6):
    for size in range(lo, hi + 1):
        for a in range(0, n - size):
            yield a, a + size


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    want_bass = "--role" in sys.argv and "bass" in sys.argv
    ncells = 12
    if "--cells" in sys.argv:
        try:
            ncells = int(sys.argv[sys.argv.index("--cells") + 1])
        except (IndexError, ValueError):
            pass
    d = os.path.expanduser(args[0] if args else "~/Downloads/soho-midi")
    files = sorted(glob.glob(os.path.join(d, "*.mid")) + glob.glob(os.path.join(d, "*.MID")))

    want = BASSISH if want_bass else LEADISH
    label = "BASS" if want_bass else "LEAD / SAX"
    print(f"{'='*78}\n{label} LINES — Chill Soho corpus\n{'='*78}")

    figures = collections.Counter()
    for f in files:
        notes, tpb, numer, progs = load(f)
        song = os.path.basename(f).replace("_mid.mid", "").replace(".mid", "")[:40]
        by = collections.defaultdict(list)
        for n in notes:
            if n[3] != 9 and progs.get(n[3]) in want:
                by[n[3]].append(n)
        for ch, seq in sorted(by.items()):
            r = analyse_channel(label, song, seq, tpb, numer)
            if r:
                figs, _, _ = r
                for fg in figs:
                    if any(abs(x) > 14 for x in fg) or all(x == 0 for x in fg):
                        continue
                    figures[fg] += 1

    print(f"\n{'='*78}\nMOST REPEATED INTERVAL FIGURES (candidate cells)\n{'='*78}")
    print("  intervals in semitones; sum=0 means the figure closes back on its start pitch\n")
    shown = 0
    seen = set()
    for fig, count in figures.most_common(400):
        if count < 3 or fig in seen:
            continue
        seen.add(fig)
        closes = "CLOSED" if sum(fig) == 0 else f"ends {sum(fig):+d}"
        print(f"   x{count:<3} [{', '.join(f'{i:+d}' for i in fig)}]   {closes}")
        shown += 1
        if shown >= ncells:
            break
    if not shown:
        print("   (no figure recurs 3+ times — the corpus leads are through-composed)")


if __name__ == "__main__":
    main()

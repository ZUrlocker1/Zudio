#!/usr/bin/env python3
"""soho_harmony.py — extract the actual chord cycles from the Chill Soho corpus.

Usage:
    python3 tools/soho_harmony.py [dir]

docs/chill-soho-plan.md measures that these songs use 4-7 bass roots changing every 1-1.5 bars
and never modulate, but it has no actual progressions. Chill Blues specifies its 16-bar
sequence explicitly (Im7x8, IVm7x2, Im7x2, V7x1, IVm7x1, Im7x2) and Soho needs the equivalent
before Rhythm, Pads or Lead can be coded.

Method, per bar:
  - ROOT from the bass channels (most common pitch class in that bar)
  - QUALITY from the pitch classes sounding in the chordal channels, measured as intervals
    above that root
  - KEY as the most frequent root across the song, then degrees expressed relative to it

Melody is excluded deliberately: a sung 9th or 13th over a triad would otherwise read as a
chord tone and turn every bar into an extended chord.
"""
import sys, os, glob, collections

try:
    import mido
except ImportError:
    sys.exit("mido not installed. Try: python3 -m pip install mido")

NAMES = "C Db D Eb E F Gb G Ab A Bb B".split()
DEGREE = ["I", "bII", "II", "bIII", "III", "IV", "bV", "V", "bVI", "VI", "bVII", "VII"]

BASS_PROG = set(range(32, 40))
CHORD_PROG = set(range(0, 8)) | set(range(16, 32)) | set(range(48, 56)) | set(range(88, 96))

# Interval sets above the root, longest match first so m7 beats m.
QUALITIES = [
    (frozenset({0, 3, 7, 10, 2}), "m9"),
    (frozenset({0, 4, 7, 11, 2}), "maj9"),
    (frozenset({0, 3, 7, 10}), "m7"),
    (frozenset({0, 4, 7, 11}), "maj7"),
    (frozenset({0, 4, 7, 10}), "7"),
    (frozenset({0, 3, 6, 10}), "m7b5"),
    (frozenset({0, 3, 7, 9}), "m6"),
    (frozenset({0, 4, 7, 9}), "6"),
    (frozenset({0, 3, 7}), "m"),
    (frozenset({0, 4, 7}), "M"),
    (frozenset({0, 7}), "5"),
]


def quality(pcs_rel):
    best, score = "?", -1
    for iv, name in QUALITIES:
        if not iv <= pcs_rel:
            continue
        s = len(iv)
        if s > score:
            best, score = name, s
    if best == "?":
        if 3 in pcs_rel:
            return "m"
        if 4 in pcs_rel:
            return "M"
    return best


def analyse(path):
    """Group by PART, where a part is a track when the file names its tracks and a channel
    otherwise.

    Guitar Pro exports put every pitched track on channel 0, so a channel-based reading merges
    bass, guitar and vocals. Measured against the real Fretless Bass track of "You're the Best
    Thing", the merged reading got the root wrong in 60% of bars — the guitar has ~15x more
    notes than the bass, so the most common pitch class is usually a chord tone. Group by track
    and that disappears.
    """
    mid = mido.MidiFile(path)
    tpb, numer = mid.ticks_per_beat, 4
    parts = []            # (key, program, name, [(tick, note)])
    chan_prog = {}
    for idx, tr in enumerate(mid.tracks):
        name, prog, notes, t = "", None, [], 0
        chans = set()
        for msg in tr:
            t += msg.time
            if msg.type == "track_name":
                name = msg.name
            elif msg.type == "time_signature":
                numer = msg.numerator * 4 / msg.denominator
            elif msg.type == "program_change":
                if prog is None:
                    prog = msg.program
                chan_prog.setdefault(msg.channel, msg.program)
            elif msg.type == "note_on" and msg.velocity > 0:
                notes.append((t, msg.note))
                chans.add(msg.channel)
        if notes and 9 not in chans:
            parts.append((idx, prog, name, notes))

    # If tracks carry no programs of their own, fall back to grouping by channel.
    if not any(p for _, p, _, _ in parts):
        by_chan = collections.defaultdict(list)
        for _, _, _, notes in parts:
            pass
        parts = []
        for tr in mid.tracks:
            t = 0
            for msg in tr:
                t += msg.time
                if msg.type == "note_on" and msg.velocity > 0 and msg.channel != 9:
                    by_chan[msg.channel].append((t, msg.note))
        parts = [(c, chan_prog.get(c), "", ns) for c, ns in by_chan.items()]

    if not parts:
        return None
    bar = tpb * numer

    def is_bass(prog, name, notes):
        if "bass" in (name or "").lower():
            return True
        if prog is not None and prog in BASS_PROG:
            return True
        return False

    bass_parts = [p for p in parts if is_bass(p[1], p[2], p[3])]
    if not bass_parts:
        # Lowest median register wins.
        bass_parts = [min(parts, key=lambda p: sorted(n for _, n in p[3])[len(p[3]) // 2])]
    bass_keys = {p[0] for p in bass_parts}
    # Chords: everything else that is not obviously the melody.
    chord_parts = [p for p in parts
                   if p[0] not in bass_keys and "vocal" not in (p[2] or "").lower()]
    if not chord_parts:
        chord_parts = [p for p in parts if p[0] not in bass_keys]

    bbass = collections.defaultdict(collections.Counter)
    bchord = collections.defaultdict(set)
    for _, _, _, notes in bass_parts:
        for t, n in notes:
            bbass[t // bar][n % 12] += 1
    for _, _, _, notes in chord_parts:
        for t, n in notes:
            bchord[t // bar].add(n % 12)

    roots, qual = {}, {}
    for b in sorted(bbass):
        if not bbass[b]:
            continue
        r = bbass[b].most_common(1)[0][0]
        roots[b] = r
        qual[b] = quality(frozenset((p - r) % 12 for p in bchord.get(b, set())))
    return roots, qual


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    d = os.path.expanduser(args[0] if args else "~/Downloads/soho-midi")
    for f in sorted(glob.glob(os.path.join(d, "*.mid")) + glob.glob(os.path.join(d, "*.MID"))):
        r = analyse(f)
        if not r:
            continue
        roots, qual = r
        if len(roots) < 12:
            continue
        tonic = collections.Counter(roots.values()).most_common(1)[0][0]
        seq = []
        for b in sorted(roots):
            deg = DEGREE[(roots[b] - tonic) % 12] + qual.get(b, "")
            if not seq or seq[-1][0] != deg:
                seq.append([deg, 1])
            else:
                seq[-1][1] += 1
        print(f"\n=== {os.path.basename(f)[:54]} ===")
        print(f"  tonic {NAMES[tonic]}   {len(set(roots.values()))} distinct roots   "
              f"{len(seq)} chord events over {len(roots)} bars")
        line = "  " + "  ".join(f"{d}x{n}" if n > 1 else d for d, n in seq[:28])
        print(line[:200])
        # Look for the repeating cycle.
        degs = [d for d, _ in seq]
        for size in range(2, 9):
            if len(degs) < size * 3:
                continue
            if all(degs[i] == degs[i % size] for i in range(size * 3)):
                print(f"  >> repeating {size}-chord cycle: {' | '.join(degs[:size])}")
                break


if __name__ == "__main__":
    main()

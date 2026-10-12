#!/usr/bin/env python3
"""Measure the Chill Soho reference corpus against docs/chill-soho-plan.md.

NOTE ON SEPARATION: this groups by MIDI CHANNEL. That is right for the bitmidi files, but
WRONG for Guitar Pro exports, which are Type 1 with properly named tracks ("Fretless Bass",
"Vocals") that all share channel 0. Keying on channel collapses them into one 35-note/bar
blob. Use tools/soho_tracks.py for those — it groups by track and reports the track name.

Usage:
    python3 tools/soho_analyze.py [dir]            # summary for every file
    python3 tools/soho_analyze.py [dir] --detail   # + per-channel breakdown
    python3 tools/soho_analyze.py [dir] --steps    # + 16th-step histograms

Defaults to ~/Downloads/soho-midi.

Works per MIDI CHANNEL rather than per track, so Type 0 (everything merged into one track)
and Type 1 files are measured the same way. Seven of the bitmidi files are Type 0, so a
track-based reading would report most of this corpus as "one instrument".

What it answers, in the order the plan asks:
  - tempo band (plan claims 88-108, peak 98)
  - harmonic rhythm (plan claims a 2-4 chord vamp that does not modulate)
  - per-role density, to set the space rather than guess it
  - drum step placement, to check CHL-DRUM-009..013 against what the records do
  - how many roles each song really needs, against Zudio's seven tracks
"""
import sys, os, glob, collections, statistics

try:
    import mido
except ImportError:
    sys.exit("mido not installed. Try: python3 -m pip install mido")

# ---------------------------------------------------------------- GM drum map

DRUM = {
    35: "kick", 36: "kick",
    37: "rim", 38: "snare", 40: "snare",
    39: "clap",
    42: "hatC", 44: "hatP", 46: "hatO",
    51: "ride", 59: "ride", 53: "ridebell",
    49: "crash", 57: "crash", 55: "splash", 52: "china",
    54: "tamb", 56: "cowbell", 58: "vibraslap",
    60: "bongo", 61: "bongo", 62: "conga", 63: "conga", 64: "conga",
    65: "timbale", 66: "timbale", 67: "agogo", 68: "agogo",
    69: "cabasa", 70: "maracas", 75: "claves",
    82: "shaker", 76: "woodblock", 77: "woodblock",
    41: "tom", 43: "tom", 45: "tom", 47: "tom", 48: "tom", 50: "tom",
}
LATIN_VOICES = {"conga", "bongo", "claves", "cabasa", "maracas", "shaker", "agogo", "timbale"}

GM_FAMILY = [
    (0, 7, "piano"), (8, 15, "chrom"), (16, 23, "organ"), (24, 31, "guitar"),
    (32, 39, "bass"), (40, 47, "strings"), (48, 55, "ensemble"), (56, 63, "brass"),
    (64, 71, "reed"), (72, 79, "pipe"), (80, 87, "synthlead"), (88, 95, "synthpad"),
    (96, 103, "synthfx"), (104, 111, "ethnic"), (112, 119, "perc"), (120, 127, "fx"),
]


def family(prog):
    for lo, hi, name in GM_FAMILY:
        if lo <= prog <= hi:
            return name
    return "?"


# ---------------------------------------------------------------- note extraction

class Note:
    __slots__ = ("start", "dur", "pitch", "vel", "chan")
    def __init__(self, start, pitch, vel, chan):
        self.start, self.pitch, self.vel, self.chan = start, pitch, vel, chan
        self.dur = 0


def load(path):
    """Return (notes, ticks_per_beat, tempo_bpm, tempo_changes, numerator)."""
    mid = mido.MidiFile(path)
    tpb = mid.ticks_per_beat
    notes, open_notes = [], collections.defaultdict(list)
    tempos, numer = [], 4
    progs = {}
    prog_at = collections.defaultdict(list)

    for track in mid.tracks:
        t = 0
        for msg in track:
            t += msg.time
            if msg.type == "set_tempo":
                tempos.append((t, mido.tempo2bpm(msg.tempo)))
            elif msg.type == "time_signature":
                # Quarter-notes per bar, honouring the denominator. Reading the numerator alone
                # mis-barred "The Paris Match" (6/8) as 6/4 — twice its real length.
                numer = msg.numerator * 4 / msg.denominator
            elif msg.type == "program_change":
                progs.setdefault(msg.channel, msg.program)
                prog_at[msg.channel].append(msg.program)
            elif msg.type == "note_on" and msg.velocity > 0:
                n = Note(t, msg.note, msg.velocity, msg.channel)
                notes.append(n)
                open_notes[(msg.channel, msg.note)].append(n)
            elif msg.type == "note_off" or (msg.type == "note_on" and msg.velocity == 0):
                stack = open_notes.get((msg.channel, msg.note))
                if stack:
                    n = stack.pop(0)
                    n.dur = max(1, t - n.start)

    # Take the tempo that is in force for the LONGEST TIME, not the first event. Several of
    # these files open with a stray 120 bpm at tick 0 before the real tempo lands, and reading
    # tempos[0] reported Black Cow as 120 when it actually sits around 98.
    if tempos:
        end = max((n.start for n in notes), default=0)
        spans = collections.Counter()
        for i, (tick, b) in enumerate(tempos):
            nxt = tempos[i + 1][0] if i + 1 < len(tempos) else end
            spans[round(b)] += max(0, nxt - tick)
        bpm = float(spans.most_common(1)[0][0]) if spans else tempos[0][1]
    else:
        bpm = 120.0
    distinct = sorted({round(b) for _, b in tempos})
    return notes, tpb, bpm, distinct, float(numer), progs, prog_at


# ---------------------------------------------------------------- role inference

def classify(chan, notes, prog):
    """Infer the musical role of one channel. Zudio has seven tracks, so the point is to see
    how many DISTINCT roles a record needs, not to name every overdub."""
    if chan == 9:
        return "drums"
    pitches = [n.pitch for n in notes]
    med = statistics.median(pitches)
    fam = family(prog) if prog is not None else "?"

    # Polyphony: mean simultaneous notes at each onset.
    onsets = collections.Counter(n.start for n in notes)
    poly = statistics.mean(onsets.values()) if onsets else 1.0

    if fam == "bass" or med < 48:
        return "bass"
    if poly >= 2.0:
        return "pad" if fam in ("synthpad", "strings", "ensemble", "organ") else "rhythm"
    if med >= 72 or fam in ("reed", "brass", "synthlead", "pipe"):
        return "lead"
    return "rhythm"


# ---------------------------------------------------------------- measurement

def step16(tick, tpb, numer):
    """Position within the bar, in 16ths. Assumes the bar is numer quarter-notes long."""
    bar_ticks = tpb * numer
    if bar_ticks <= 0:
        return 0
    steps = int(round(numer * 4))
    return int(((tick % bar_ticks) / bar_ticks) * steps) % steps


def harmonic_rhythm(notes, tpb, numer, bass_chans):
    """Mean bars per chord change, read from the BASS ROOT per bar.

    An earlier version compared the full pitch-class set of every chordal channel per bar. That
    reported ~1.1 bars/change across the corpus, which is an artefact: any passing note or
    melodic inflection changes the set, so it measures surface activity rather than harmony.
    The bass root is the robust signal for "has the chord changed", which is what the plan's
    "2-4 chord vamp that does not modulate" claim is actually about.
    """
    bar_ticks = tpb * numer
    if bar_ticks <= 0 or not bass_chans:
        return None, None
    bars = collections.defaultdict(collections.Counter)
    for n in notes:
        if n.chan in bass_chans:
            bars[n.start // bar_ticks][n.pitch % 12] += 1
    keys = sorted(bars)
    if len(keys) < 8:
        return None, None
    roots = []
    for k in keys:
        if bars[k]:
            roots.append((k, bars[k].most_common(1)[0][0]))
    changes = sum(1 for i in range(1, len(roots)) if roots[i][1] != roots[i - 1][1])
    span = roots[-1][0] - roots[0][0] + 1
    return (span / changes if changes else float(span)), len({r for _, r in roots})


def analyse(path, detail=False, steps=False):
    notes, tpb, bpm, tempo_list, numer, progs, prog_at = load(path)
    if not notes:
        print(f"  {os.path.basename(path)}: no notes")
        return None
    bar_ticks = tpb * numer
    total_bars = max(1, (max(n.start for n in notes) // bar_ticks) + 1)

    by_chan = collections.defaultdict(list)
    for n in notes:
        by_chan[n.chan].append(n)

    roles = {}
    for c, ns in by_chan.items():
        roles[c] = classify(c, ns, progs.get(c))

    name = os.path.basename(path)
    name = name.replace("_mid.mid", "").replace(".mid", "").replace(".MID", "")
    print(f"\n{'='*78}\n{name[:76]}")
    tempo_note = f"{bpm:.0f} bpm" + (f"  (changes: {tempo_list})" if len(tempo_list) > 1 else "")
    print(f"  {tempo_note}   {numer:g}/4   {total_bars} bars   {len(by_chan)} channels   {len(notes)} notes")

    # ---- roles present
    role_count = collections.Counter(roles.values())
    role_chans = collections.defaultdict(list)
    for c, r in roles.items():
        role_chans[r].append(c)
    print("  roles: " + ", ".join(f"{r}x{n}" for r, n in sorted(role_count.items())))

    # ---- harmonic rhythm
    bchans = {c for c, r in roles.items() if r == "bass"}
    hr, distinct = harmonic_rhythm(notes, tpb, numer, bchans)
    if hr:
        print(f"  harmonic rhythm: ~{hr:.1f} bars/chord change, {distinct} distinct bass roots")

    # ---- per-role density
    print("  density (notes/bar):")
    for r in ("drums", "bass", "rhythm", "pad", "lead"):
        chans = role_chans.get(r, [])
        if not chans:
            continue
        for c in sorted(chans):
            ns = by_chan[c]
            dens = len(ns) / total_bars
            prog = progs.get(c)
            pname = f"p{prog:<3}{family(prog)}" if prog is not None else "p?  "
            med = statistics.median([n.pitch for n in ns])
            dur = statistics.median([n.dur for n in ns]) / tpb
            star = "" if detail else ""
            print(f"     ch{c:<3} {r:<7} {pname:<12} {dens:6.1f}/bar  med.pitch {med:3.0f}  "
                  f"med.dur {dur:4.2f} beats  n={len(ns)}{star}")

    # ---- drums
    if 9 in by_chan:
        voices = collections.Counter(DRUM.get(n.pitch, f"?{n.pitch}") for n in by_chan[9])
        latin = sum(v for k, v in voices.items() if k in LATIN_VOICES)
        total = sum(voices.values())
        print(f"  drum voices: " + ", ".join(f"{k}={v}" for k, v in voices.most_common(9)))
        print(f"  latin percussion: {latin}/{total} hits ({100*latin/total:.0f}%)")
        if steps:
            for voice in ("kick", "snare", "rim", "hatC", "ride", "conga", "shaker"):
                hits = [step16(n.start, tpb, numer) for n in by_chan[9]
                        if DRUM.get(n.pitch) == voice]
                if not hits:
                    continue
                h = collections.Counter(hits)
                row = " ".join(f"{h.get(s,0):>3}" for s in range(int(round(numer * 4))))
                print(f"     {voice:<7} {row}")

    # ---- bass placement
    bass_chans = role_chans.get("bass", [])
    if bass_chans and steps:
        for c in bass_chans:
            h = collections.Counter(step16(n.start, tpb, numer) for n in by_chan[c])
            row = " ".join(f"{h.get(s,0):>3}" for s in range(int(round(numer * 4))))
            print(f"     bass ch{c:<2} {row}")

    return {
        "name": name, "bpm": bpm, "bars": total_bars, "roles": role_count,
        "hr": hr, "channels": len(by_chan),
        "latin_pct": (100 * sum(v for k, v in
                      collections.Counter(DRUM.get(n.pitch, "") for n in by_chan[9]).items()
                      if k in LATIN_VOICES) / max(1, len(by_chan[9]))) if 9 in by_chan else None,
    }


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    detail = "--detail" in sys.argv
    steps = "--steps" in sys.argv
    d = os.path.expanduser(args[0] if args else "~/Downloads/soho-midi")
    files = sorted(glob.glob(os.path.join(d, "*.mid")) + glob.glob(os.path.join(d, "*.MID")))
    if not files:
        sys.exit(f"no MIDI in {d}")

    rows = [r for r in (analyse(f, detail, steps) for f in files) if r]

    print(f"\n{'='*78}\nSUMMARY ({len(rows)} files)")
    tempos = sorted(r["bpm"] for r in rows)
    print(f"  tempo: min {tempos[0]:.0f}  median {statistics.median(tempos):.0f}  max {tempos[-1]:.0f}")
    print(f"  plan claims 88-108 peak 98")
    hrs = [r["hr"] for r in rows if r["hr"]]
    if hrs:
        print(f"  harmonic rhythm: median {statistics.median(hrs):.1f} bars/change")
    chans = sorted(r["channels"] for r in rows)
    print(f"  channels used: min {chans[0]}  median {statistics.median(chans):.0f}  max {chans[-1]}  (Zudio has 7)")


if __name__ == "__main__":
    main()

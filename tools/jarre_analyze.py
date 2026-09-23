#!/usr/bin/env python3
"""Jarre corpus analysis — derives Kosmic Space rule candidates from MIDI.

Usage:
    python3 tools/jarre_analyze.py <dir-of-midi-files>
    python3 tools/jarre_analyze.py ~/Downloads/jarre-midi

Reads every .mid/.MID in the directory and reports, per source track, the
measurements the Kosmic Space rule design actually needs (see
docs/kosmic-space-plan.md). Nothing is written; this only prints.

Tracks are classified heuristically into Zudio roles by register and density,
because fan transcriptions rarely name tracks usefully. The classification is
printed so it can be sanity-checked and overridden by eye.

WHAT IT MEASURES AND WHY
  register + spread    -> which Zudio track the part maps to
  note duration        -> sustained pad vs staccato sequencer
  interval histogram   -> kosmic-plan §2 claims JMJ avoids large leaps and
                          favours 2nds/3rds/4ths/octaves. This tests that.
  onset grid deviation -> how mechanical the sequencer is (0 = quantised)
  cell period          -> repeating arpeggio cell length in steps; kosmic-plan
                          claims 4-8 note patterns
  velocity spread      -> whether dynamics are programmed or flat
  pitch-class turnover -> harmonic rhythm proxy; JMJ holds chords 8-16 bars

CAVEAT: fan transcriptions are interpretations, not ground truth. A feature is
only worth turning into a rule if it holds across several independent files.
"""
import sys, os, glob, statistics
from collections import Counter, defaultdict

try:
    import mido
except ImportError:
    sys.exit("mido not installed:  pip3 install mido")


def load_tracks(path):
    """Returns [(track_name, [(tick, pitch, vel, dur_ticks), ...])], plus tpb."""
    mid = mido.MidiFile(path)
    tpb = mid.ticks_per_beat or 480
    out = []
    for tr in mid.tracks:
        t, pending, notes = 0, {}, []
        for msg in tr:
            t += msg.time
            if msg.type == 'note_on' and msg.velocity > 0:
                pending.setdefault(msg.note, []).append((t, msg.velocity))
            elif msg.type in ('note_off',) or (msg.type == 'note_on' and msg.velocity == 0):
                if msg.note in pending and pending[msg.note]:
                    st, v = pending[msg.note].pop(0)
                    notes.append((st, msg.note, v, max(1, t - st)))
        if notes:
            notes.sort()
            out.append((tr.name.strip() or f"track{len(out)}", notes))
    return out, tpb


def classify(notes, tpb):
    """Map a track to a Zudio role by register, density and sustain."""
    pitches = [n[1] for n in notes]
    med = statistics.median(pitches)
    durs = [n[3] / tpb for n in notes]          # in beats
    med_dur = statistics.median(durs)
    span = (max(n[0] for n in notes) - min(n[0] for n in notes)) / tpb or 1
    density = len(notes) / span                  # notes per beat
    if med < 48 and med_dur < 4:      return "BASS"
    if med_dur >= 3.0:                return "PADS"
    if density >= 1.6:                return "RHYTHM (arp/sequencer)"
    if med >= 72:                     return "LEAD"
    return "TEXTURE/other"


def cell_period(notes, tpb, max_steps=32):
    """Smallest repeating pitch-cell length, in notes. 0 if none found."""
    seq = [n[1] for n in notes][:200]
    if len(seq) < 8: return 0
    for p in range(2, min(max_steps, len(seq) // 3)):
        if all(seq[i] == seq[i + p] for i in range(len(seq) - p)):
            return p
    # tolerant match: 90% agreement
    best = 0
    for p in range(2, min(max_steps, len(seq) // 3)):
        agree = sum(1 for i in range(len(seq) - p) if seq[i] == seq[i + p])
        if agree / (len(seq) - p) >= 0.90:
            best = p; break
    return best


def arrangement(notes, tpb):
    """Entry/exit, dropout gaps and rest ratio for one track.

    Answers the arrangement questions the rule design needs: when does this part
    come in, does it ever leave, for how long, and how much of its active span is
    silence. Kraftwerk in particular uses absence structurally — a part that stops
    for sixteen bars is making a statement, not resting.
    """
    bar = tpb * 4
    first_bar = notes[0][0] // bar
    last_bar  = (notes[-1][0] + notes[-1][3]) // bar
    span = max(1, last_bar - first_bar + 1)

    # Which bars inside the active span contain at least one note-on
    occupied = set(n[0] // bar for n in notes)
    gaps, run = [], 0
    for b in range(first_bar, last_bar + 1):
        if b in occupied:
            if run >= 2:
                gaps.append((b - run, run))     # (start bar, length in bars)
            run = 0
        else:
            run += 1
    if run >= 2:
        gaps.append((last_bar + 1 - run, run))

    # Rest ratio: sixteenth-steps with no note-on, across the active span
    steps_total = span * 16
    step_len = tpb // 4 or 1
    onsets = set(n[0] // step_len for n in notes)
    rest_ratio = 1.0 - (len(onsets) / steps_total) if steps_total else 0.0
    return first_bar, last_bar, span, gaps, rest_ratio


def phrases(notes, tpb):
    """Group notes into statements separated by silence.

    Rest ratio alone is misleading: one note every ten steps and an eight-note
    phrase followed by forty steps of silence both read as ~90% rest, but only the
    second is a musical statement. This finds the statements.

    The phrase-boundary threshold adapts to the track's own density — three times
    its median inter-onset gap, floored at one beat — so a dense sequencer and a
    sparse lead are each judged on their own terms rather than a fixed grid.
    """
    step_len = tpb // 4 or 1
    onsets = sorted(set(n[0] // step_len for n in notes))
    if len(onsets) < 4:
        return None
    gaps = [onsets[i+1] - onsets[i] for i in range(len(onsets)-1)]
    med_gap = statistics.median(gaps)
    threshold = max(4, med_gap * 3)

    runs, cur = [], [onsets[0]]
    for i in range(1, len(onsets)):
        if onsets[i] - onsets[i-1] > threshold:
            runs.append(cur); cur = [onsets[i]]
        else:
            cur.append(onsets[i])
    runs.append(cur)

    lens_notes = [len(r) for r in runs]
    lens_steps = [r[-1] - r[0] + 1 for r in runs]
    silences   = [runs[i+1][0] - (runs[i][-1] + 1) for i in range(len(runs)-1)]
    return {
        "count":       len(runs),
        "notes_med":   statistics.median(lens_notes),
        "steps_med":   statistics.median(lens_steps),
        "silence_med": statistics.median(silences) if silences else 0,
        "ratio":       (statistics.median(silences) / statistics.median(lens_steps))
                       if silences and statistics.median(lens_steps) else 0.0,
        "uniform":     statistics.pstdev(lens_notes) < 1.0 if len(lens_notes) > 2 else True,
    }


def analyse(path):
    name = os.path.basename(path)
    print(f"\n{'='*74}\n{name}\n{'='*74}")
    try:
        tracks, tpb = load_tracks(path)
    except Exception as e:
        print(f"  UNREADABLE: {e}"); return
    print(f"  ticks/beat {tpb}   tracks with notes: {len(tracks)}")

    # Entry order across the song — shows how the arrangement is built up
    entries = sorted(((notes[0][0] // (tpb*4), tname) for tname, notes in tracks
                      if len(notes) >= 8), key=lambda x: x[0])
    if entries:
        print("  entry order: " + " -> ".join(f"{n[:12]}@{b}" for b, n in entries))

    for tname, notes in tracks:
        if len(notes) < 8: continue
        pitches = [n[1] for n in notes]
        vels    = [n[2] for n in notes]
        durs    = [n[3] / tpb for n in notes]
        role    = classify(notes, tpb)

        # melodic intervals between consecutive notes
        iv = [abs(pitches[i+1] - pitches[i]) for i in range(len(pitches)-1)]
        ivc = Counter(iv)
        small = sum(c for i, c in ivc.items() if i <= 5)        # 2nds-4ths
        leaps = sum(c for i, c in ivc.items() if i > 7)
        # onset deviation from a 16th grid
        step = tpb / 4
        dev = [min(n[0] % step, step - (n[0] % step)) / step for n in notes]

        print(f"\n  ── {tname[:40]:<40} [{role}]")
        print(f"     notes {len(notes):<5} register {min(pitches)}–{max(pitches)} (med {int(statistics.median(pitches))})")
        print(f"     duration beats: med {statistics.median(durs):.2f}  "
              f"p90 {sorted(durs)[int(len(durs)*0.9)]:.2f}")
        print(f"     velocity: med {int(statistics.median(vels))}  "
              f"range {min(vels)}–{max(vels)}  stdev {statistics.pstdev(vels):.1f}")
        print(f"     intervals: <=4th {100*small/max(1,len(iv)):.0f}%   "
              f">5th leaps {100*leaps/max(1,len(iv)):.0f}%   "
              f"top {[f'{i}st:{c}' for i, c in ivc.most_common(4)]}")
        print(f"     grid deviation: mean {100*statistics.mean(dev):.1f}% of a 16th "
              f"({'quantised' if statistics.mean(dev) < 0.04 else 'played/loose'})")
        cp = cell_period(notes, tpb)
        print(f"     repeating cell: {cp if cp else 'none detected'} notes")
        first, last, span, gaps, rest = arrangement(notes, tpb)
        gap_txt = ", ".join(f"{L}bar@{b}" for b, L in sorted(gaps, key=lambda g: -g[1])[:4]) or "none"
        print(f"     arrangement: bars {first}-{last} ({span} bars)  "
              f"rest {100*rest:.0f}%  dropouts: {gap_txt}")
        ph = phrases(notes, tpb)
        if ph:
            shape = "uniform" if ph["uniform"] else "varied"
            print(f"     phrasing: {ph['count']} statements, median {ph['notes_med']:.0f} notes "
                  f"/ {ph['steps_med']:.0f} steps, then {ph['silence_med']:.0f} steps silence "
                  f"(silence:statement {ph['ratio']:.1f}:1, {shape} lengths)")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    root = os.path.expanduser(sys.argv[1])
    files = sorted(glob.glob(os.path.join(root, '*.mid')) +
                   glob.glob(os.path.join(root, '*.MID')))
    if not files:
        sys.exit(f"no .mid files in {root}")
    print(f"Analysing {len(files)} file(s) from {root}")
    for f in files:
        analyse(f)
    print(f"\n{'='*74}")
    print("Reminder: only promote a feature to a rule if it holds across several files.")


if __name__ == '__main__':
    main()

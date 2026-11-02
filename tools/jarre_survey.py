#!/usr/bin/env python3
"""jarre_survey.py — per-file overview of the Kosmic Space corpus.

Usage:
    python3 tools/jarre_survey.py [dir]          # default ~/Downloads/jarre-midi

For each file: length in bars and minutes, tempo map, meter, and every part (track x
channel, so Type 0 files split correctly) with its GM program, register, density, median
duration and the bars it is active. This is the map the deeper passes
(jarre_sections.py, jarre_harmony.py, jarre_lead_phrases.py) are read against.
"""
import sys, os, glob, statistics, collections

try:
    import mido
except ImportError:
    sys.exit("mido not installed. Try: python3 -m pip install mido")


def load_parts(path):
    """Returns (parts, tpb, tempos, meters, end_tick).

    parts: {(track_name, channel): {"notes": [(tick, pitch, vel, dur)], "program": int}}
    tempos: [(tick, bpm)]   meters: [(tick, num, den)]
    """
    mid = mido.MidiFile(path)
    tpb = mid.ticks_per_beat or 480
    parts, tempos, meters, end = {}, [], [], 0
    for ti, tr in enumerate(mid.tracks):
        t, pending, name = 0, {}, (tr.name or "").strip() or f"track{ti}"
        prog = {}
        for msg in tr:
            t += msg.time
            if msg.type == "set_tempo":
                tempos.append((t, round(mido.tempo2bpm(msg.tempo), 1)))
            elif msg.type == "time_signature":
                meters.append((t, msg.numerator, msg.denominator))
            elif msg.type == "program_change":
                prog[msg.channel] = msg.program
            elif msg.type == "note_on" and msg.velocity > 0:
                pending.setdefault((msg.channel, msg.note), []).append((t, msg.velocity))
            elif msg.type == "note_off" or (msg.type == "note_on" and msg.velocity == 0):
                k = (msg.channel, msg.note)
                if pending.get(k):
                    st, v = pending[k].pop(0)
                    key = (name, msg.channel)
                    p = parts.setdefault(key, {"notes": [], "program": None})
                    p["notes"].append((st, msg.note, v, max(1, t - st)))
        for (ch, _), _ in list(pending.items()):
            pass
        for key, p in parts.items():
            if key[0] == name and p["program"] is None and key[1] in prog:
                p["program"] = prog[key[1]]
        end = max(end, t)
    for p in parts.values():
        p["notes"].sort()
    tempos.sort(); meters.sort()
    return parts, tpb, tempos, meters, end


def seconds_at(tick, tempos, tpb):
    """Wall-clock seconds at a tick, honouring tempo changes."""
    secs, last_t, bpm = 0.0, 0, (tempos[0][1] if tempos and tempos[0][0] == 0 else 120.0)
    for tt, b in tempos:
        if tt >= tick:
            break
        secs += (tt - last_t) / tpb * 60.0 / bpm
        last_t, bpm = tt, b
    return secs + (tick - last_t) / tpb * 60.0 / bpm


def bar_len(meters, tpb):
    num, den = (meters[0][1], meters[0][2]) if meters else (4, 4)
    return int(tpb * num * 4 / den), num, den


def active_bars(notes, bar_ticks):
    bars = sorted({n[0] // bar_ticks for n in notes})
    # compress to ranges
    out, start, prev = [], None, None
    for b in bars:
        if start is None:
            start = prev = b
        elif b <= prev + 2:             # a one-bar gap is not a dropout
            prev = b
        else:
            out.append((start, prev)); start = prev = b
    if start is not None:
        out.append((start, prev))
    return out


def main():
    root = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Downloads/jarre-midi")
    files = sorted(glob.glob(os.path.join(root, "*.mid")) + glob.glob(os.path.join(root, "*.MID")))
    for path in files:
        parts, tpb, tempos, meters, end = load_parts(path)
        bt, num, den = bar_len(meters, tpb)
        last_note = max(n[0] + n[3] for p in parts.values() for n in p["notes"])
        nbars = last_note // bt + 1
        mins = seconds_at(last_note, tempos, tpb) / 60
        print("=" * 78)
        print(os.path.basename(path))
        tmap = []
        for tt, b in tempos:
            if not tmap or abs(tmap[-1][1] - b) >= 1:
                tmap.append((tt // bt + 1, b))
        print(f"  {nbars} bars  {mins:.1f} min  meter {num}/{den}"
              + ("" if len(meters) <= 1 else f" (+{len(meters) - 1} meter changes: "
                 + ", ".join(f"bar {t // bt + 1} {n}/{d}" for t, n, d in meters[1:6]) + ")"))
        print("  tempo: " + ", ".join(f"bar {b} = {bpm:g}" for b, bpm in tmap[:12])
              + (" ..." if len(tmap) > 12 else ""))
        rows = []
        for (name, ch), p in parts.items():
            ns = p["notes"]
            if len(ns) < 4:
                continue
            pitches = [n[1] for n in ns]
            span_beats = max(1, (ns[-1][0] - ns[0][0]) / tpb)
            dens = len(ns) / span_beats
            md = statistics.median(n[3] / tpb for n in ns)
            ranges = active_bars(ns, bt)
            act = " ".join(f"{a + 1}-{b + 1}" for a, b in ranges[:8]) + (" ..." if len(ranges) > 8 else "")
            prog = "drums" if ch == 9 else (p["program"] if p["program"] is not None else "?")
            rows.append((ns[0][0], f"  {name[:22]:22} ch{ch:<2} prg {str(prog):5} "
                         f"n{len(ns):5}  reg {min(pitches)}-{max(pitches)} (med {int(statistics.median(pitches))})  "
                         f"dens {dens:4.2f}/beat  dur {md:5.2f}b  bars {act}"))
        for _, r in sorted(rows):
            print(r)


if __name__ == "__main__":
    main()

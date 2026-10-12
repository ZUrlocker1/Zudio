#!/usr/bin/env python3
"""soho_tracks.py — measure a MIDI corpus by TRACK rather than by channel.

Usage:
    python3 tools/soho_tracks.py [dir]

Companion to soho_analyze.py, which groups by MIDI channel. That is correct for the bitmidi
transcriptions, where each part has its own channel, but wrong for Guitar Pro exports: those
are Type 1 files with properly named tracks — "Fretless Bass", "Vocals", "Rhythm Guitar" —
that all share channel 0. Grouping them by channel merges four real parts into one 35-note/bar
blob and makes a simple arrangement look like a dense one.

The track NAME is also the most reliable role label in the whole corpus. It beats inferring
role from GM program or pitch range, which is what soho_analyze.py has to do.
"""
import sys, os, glob, collections, statistics

try:
    import mido
except ImportError:
    sys.exit("mido not installed. Try: python3 -m pip install mido")


def parts(path):
    mid = mido.MidiFile(path)
    tpb, numer, out = mid.ticks_per_beat, 4, []
    for tr in mid.tracks:
        name, prog, notes, t = "", None, [], 0
        open_n = collections.defaultdict(list)
        for msg in tr:
            t += msg.time
            if msg.type == "track_name":
                name = msg.name
            elif msg.type == "time_signature":
                numer = msg.numerator * 4 / msg.denominator
            elif msg.type == "program_change" and prog is None:
                prog = msg.program
            elif msg.type == "note_on" and msg.velocity > 0:
                n = [t, msg.note, 0]
                notes.append(n)
                open_n[msg.note].append(n)
            elif msg.type == "note_off" or (msg.type == "note_on" and msg.velocity == 0):
                st = open_n.get(msg.note)
                if st:
                    nn = st.pop(0)
                    nn[2] = max(1, t - nn[0])
        if notes:
            out.append((name or "(unnamed)", prog, notes))
    return out, tpb, numer


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    d = os.path.expanduser(args[0] if args else "~/Downloads/soho-midi")
    files = sorted(glob.glob(os.path.join(d, "*.mid")) + glob.glob(os.path.join(d, "*.MID")))
    if not files:
        sys.exit(f"no MIDI in {d}")

    for f in files:
        ps, tpb, numer = parts(f)
        named = [p for p in ps if not p[0].startswith("(")]
        if len(named) < 2:
            continue                      # no useful track names — use soho_analyze.py instead
        bar = tpb * numer
        bars = max(max(n[0] for n in p[2]) for p in ps) // bar + 1
        steps = int(round(numer * 4))
        print(f"\n=== {os.path.basename(f)[:56]}  ({bars} bars, {numer:g}/4) ===")
        for name, prog, notes in ps:
            h = collections.Counter(int(((n[0] % bar) / bar) * steps) for n in notes)
            row = " ".join(f"{h.get(i, 0):>3}" for i in range(steps))
            dur = statistics.median(n[2] for n in notes) / (tpb / 4)
            onsets = collections.Counter(n[0] for n in notes)
            poly = statistics.mean(onsets.values())
            print(f"  {name[:24]:<24} p{str(prog):<4} {len(notes)/bars:5.1f}/bar "
                  f"poly{poly:4.1f} dur{dur:5.1f} steps  n={len(notes)}")
            print(f"      {row}")


if __name__ == "__main__":
    main()

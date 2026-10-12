#!/usr/bin/env python3
"""Strip volume automation (CC7) and expression (CC11) from MIDI files.

Usage:
    python3 tools/strip_midi_volume.py [in-dir] [out-dir]

Defaults to ~/Downloads/soho-midi -> ~/Downloads/soho-midi/clean.
Originals are never modified; cleaned copies are written to out-dir.

WHY
Fan transcriptions often carry a full mix: channel volume rides and a fade-out at the end.
Two files in the Chill Soho corpus (Matt Bianco "Half a Minute", Simply Red "Holding Back the
Years") fade CC7 all the way to 0.

That causes a confusing failure in a DAW. Logic does not chase control changes by default, so
unless playback starts at the very top, the channel faders sit wherever the last CC7 event left
them — at zero — and the file appears silent even though the note data is intact. The same file
renders fine offline, because an offline render always starts at tick 0.

For measuring density, harmonic rhythm and groove, the mix is irrelevant and the fade is
actively harmful: it makes late bars look quiet when the parts are still playing. Stripping CC7
and CC11 leaves note timing and velocity untouched, which is all the analysis depends on.
"""
import os, sys, glob

try:
    import mido
except ImportError:
    sys.exit("mido not installed. Try: python3 -m pip install mido")

STRIP = {7, 11}   # 7 = channel volume, 11 = expression


def clean(path, out_dir):
    mid = mido.MidiFile(path)
    removed = 0
    for track in mid.tracks:
        kept, carry = [], 0
        for msg in track:
            if msg.type == "control_change" and msg.control in STRIP:
                # Fold the dropped event's delta into the next kept message. Without this the
                # track shifts earlier by the sum of every removed delta, which would corrupt
                # exactly the note timing the analysis depends on.
                carry += msg.time
                removed += 1
                continue
            kept.append(msg.copy(time=msg.time + carry))
            carry = 0
        track[:] = kept
    dest = os.path.join(out_dir, os.path.basename(path))
    mid.save(dest)
    return removed, dest


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    in_dir = os.path.expanduser(args[0] if args else "~/Downloads/soho-midi")
    out_dir = os.path.expanduser(args[1] if len(args) > 1 else os.path.join(in_dir, "clean"))
    os.makedirs(out_dir, exist_ok=True)

    files = sorted(glob.glob(os.path.join(in_dir, "*.mid")) +
                   glob.glob(os.path.join(in_dir, "*.MID")))
    if not files:
        sys.exit(f"no MIDI files in {in_dir}")

    for f in files:
        removed, dest = clean(f, out_dir)
        print(f"  {os.path.basename(f)[:46]:<48} stripped {removed:4} CC events")
    print(f"\n  {len(files)} file(s) -> {out_dir}")
    print("  Import these into Logic instead; the originals keep their mix automation.")


if __name__ == "__main__":
    main()

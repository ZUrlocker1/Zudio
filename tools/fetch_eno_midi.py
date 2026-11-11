#!/usr/bin/env python3
"""Fetch fan-made Brian Eno sequences from Online Sequencer and save them as MIDI.

Usage:
    python3 tools/fetch_eno_midi.py                 # -> docs/midi-analysis/eno/
    python3 tools/fetch_eno_midi.py <out-dir>
    python3 tools/fetch_eno_midi.py --convert <file.bin> <out.mid>   # offline, no network

WHY THIS AND NOT BITMIDI
BitMidi, MIDIWorld, FreeMIDI, Midis101 and MIDI DB have no Eno (checked 2026-11-09).
Online Sequencer is the only source. Its old midi.php export URL is a 404; the site
now builds MIDI in the browser from a protobuf served by app/api/get_proto.php.
This script fetches that protobuf and writes a standard MIDI file itself, with no
dependencies.

PROTOBUF LAYOUT (read from the bytes; the site publishes no schema)
    Sequence { 1: Settings, 2: repeated Note }
    Settings { 1: bpm (varint), 3: repeated InstrumentSettings }
    Note     { 1: type (varint, pitch index), 2: time (float, sixteenths),
               3: length (float, sixteenths), 4: instrument (varint),
               5: volume (float, 0..1) }
Missing fields take protobuf defaults (time 0, instrument 0, volume 1).
Pitch: type is an index from C0, so MIDI note = type + 12. Not verified against the
site; an octave error would shift register, not intervals.
Each Online Sequencer instrument becomes its own MIDI track, so layering survives.

These are fan transcriptions of copyrighted works, for private analysis only.
Do not commit them or ship them.
"""
import os, struct, sys, time, urllib.request

SEQUENCES = [
    (983336,  "The Big Ship (Another Green World)"),
    (3958553, "The Big Ship remix (DJ gMn)"),
    (5003459, "A Stream With Bright Fish (The Pearl)"),
    (5439286, "Among Fields Of Crystal (The Pearl) WIP a"),
    (5181117, "Among Fields Of Crystal (The Pearl) WIP b"),
    (4808484, "Among Fields Of Crystal (The Pearl) WIP c"),
    (3084268, "Against The Sky (The Pearl)"),
    (3056055, "Not Yet Remembered (The Plateaux Of Mirror)"),
    (126162,  "Prophecy Theme (Dune, with Toto)"),
    (890687,  "Music For Airports excerpt a"),
    (841635,  "Music For Airports excerpt b"),
    (1309750, "Brian Eno untitled (unverified)"),
]
URL = "https://onlinesequencer.net/app/api/get_proto.php?id={}"
PPQ = 480                     # ticks per quarter; one sixteenth = 120 ticks


# ---- minimal protobuf reader ----
def _varint(b, i):
    v = s = 0
    while True:
        c = b[i]; i += 1
        v |= (c & 0x7F) << s; s += 7
        if c < 0x80:
            return v, i

def _fields(b):
    i = 0
    while i < len(b):
        key, i = _varint(b, i)
        f, wt = key >> 3, key & 7
        if wt == 0:
            v, i = _varint(b, i)
        elif wt == 1:
            v = struct.unpack_from("<d", b, i)[0]; i += 8
        elif wt == 2:
            n, i = _varint(b, i); v = b[i:i + n]; i += n
        elif wt == 5:
            v = struct.unpack_from("<f", b, i)[0]; i += 4
        else:
            raise ValueError(f"wire type {wt} at byte {i}")
        yield f, v

def parse(data):
    bpm, notes = 110, []
    for f, v in _fields(data):
        if f == 1:
            for sf, sv in _fields(v):
                if sf == 1: bpm = sv
        elif f == 2:
            n = {1: 0, 2: 0.0, 3: 1.0, 4: 0, 5: 1.0}
            for nf, nv in _fields(v):
                n[nf] = nv
            notes.append(n)
    return bpm, notes


# ---- minimal MIDI writer ----
def _vlq(n):
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.insert(0, (n & 0x7F) | 0x80); n >>= 7
    return bytes(out)

def _track(events):
    events.sort(key=lambda e: (e[0], e[1]))   # note-offs (0) before note-ons (1) at a tick
    body, last = bytearray(), 0
    for tick, _, msg in events:
        body += _vlq(tick - last) + msg; last = tick
    body += b"\x00\xff\x2f\x00"
    return b"MTrk" + struct.pack(">I", len(body)) + bytes(body)

def to_midi(bpm, notes):
    tempo = round(60_000_000 / bpm)
    tracks = [_track([(0, 0, b"\xff\x51\x03" + tempo.to_bytes(3, "big"))])]
    by_inst = {}
    for n in notes:
        by_inst.setdefault(n[4], []).append(n)
    for k, inst in enumerate(sorted(by_inst)):          # sorted: stable track order
        ch = k if k < 9 else k + 1                      # skip channel 10 (drums)
        ch &= 0x0F
        name = f"OS instrument {inst}".encode()
        ev = [(0, 0, b"\xff\x03" + _vlq(len(name)) + name)]
        for n in by_inst[inst]:
            pitch = int(n[1]) + 12
            if not 0 <= pitch <= 127:
                continue
            on = round(n[2] * PPQ / 4)
            off = max(on + 1, round((n[2] + n[3]) * PPQ / 4))
            vel = max(1, min(127, round(n[5] * 100)))
            ev.append((on, 1, bytes([0x90 | ch, pitch, vel])))
            ev.append((off, 0, bytes([0x80 | ch, pitch, 0])))
        tracks.append(_track(ev))
    head = b"MThd" + struct.pack(">IHHH", 6, 1, len(tracks), PPQ)
    return head + b"".join(tracks)


def convert(data, dest):
    bpm, notes = parse(data)
    if not notes:
        raise ValueError("no notes in sequence")
    with open(dest, "wb") as fh:
        fh.write(to_midi(bpm, notes))
    insts = len({n[4] for n in notes})
    return f"{len(notes)} notes, {insts} instruments, {bpm} bpm"


def main(argv):
    if argv[:1] == ["--convert"]:
        src, dest = argv[1], argv[2]
        with open(src, "rb") as fh:
            print("ok   ", dest, "-", convert(fh.read(), dest))
        return
    out = argv[0] if argv else "docs/midi-analysis/eno"
    os.makedirs(out, exist_ok=True)
    for sid, title in SEQUENCES:
        dest = os.path.join(out, f"{title}.mid")
        if os.path.getsize(dest) if os.path.exists(dest) else 0:
            print("have ", title); continue
        try:
            req = urllib.request.Request(URL.format(sid), headers={"User-Agent": "Mozilla/5.0"})
            data = urllib.request.urlopen(req, timeout=30).read()
            print("ok   ", title, "-", convert(data, dest))
        except Exception as e:
            print("FAIL ", title, f"(id {sid}): {e}")
        time.sleep(1)


if __name__ == "__main__":
    main(sys.argv[1:])

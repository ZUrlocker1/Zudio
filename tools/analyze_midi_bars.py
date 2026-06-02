#!/usr/bin/env python3
import struct, sys

def read_vlq(data, pos):
    val = 0
    while True:
        b = data[pos]; pos += 1
        val = (val << 7) | (b & 0x7F)
        if not (b & 0x80): return val, pos

def parse_midi(path):
    with open(path, 'rb') as f: data = f.read()
    assert data[0:4] == b'MThd'
    hlen = struct.unpack('>I', data[4:8])[0]
    fmt, ntracks, tpq = struct.unpack('>HHH', data[8:14])
    pos = 8 + hlen
    tracks = []
    for _ in range(ntracks):
        assert data[pos:pos+4] == b'MTrk'
        tlen = struct.unpack('>I', data[pos+4:pos+8])[0]
        tdata = data[pos+8:pos+8+tlen]; pos += 8 + tlen
        events = []; tick = 0; p = 0; last_status = 0
        while p < len(tdata):
            dt, p = read_vlq(tdata, p); tick += dt
            b = tdata[p]
            if b & 0x80: last_status = b; p += 1
            else: b = last_status
            cmd = b & 0xF0; ch = b & 0x0F
            if cmd in (0x80, 0x90):
                note = tdata[p]; vel = tdata[p+1]; p += 2
                events.append((tick, cmd, ch, note, vel))
            elif cmd in (0xA0, 0xB0, 0xE0): p += 2
            elif cmd in (0xC0, 0xD0): p += 1
            elif b == 0xFF:
                mtype = tdata[p]; p += 1
                mlen, p = read_vlq(tdata, p); p += mlen
            elif b in (0xF0, 0xF7):
                mlen, p = read_vlq(tdata, p); p += mlen
            else: p += 1
        tracks.append(events)
    return tracks, tpq, ntracks

NOTE_NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']

for path in sys.argv[1:]:
    print(f"\n{'='*60}")
    print(f"FILE: {path.split('/')[-1]}")
    tracks, tpq, ntracks = parse_midi(path)
    print(f"TPQ={tpq}, tracks={ntracks}")

    for ti, track in enumerate(tracks):
        note_ons = [(tick, note, vel) for tick, cmd, ch, note, vel in track
                    if cmd == 0x90 and vel > 0 and ch != 9]
        if not note_ons: continue
        max_tick = max(t for t,_,_ in note_ons)
        total_bars = max_tick // (tpq * 4) + 2

        bar_notes = {}
        for tick, note, vel in note_ons:
            bar = tick // (tpq * 4)
            bar_notes.setdefault(bar, []).append((note, vel))

        print(f"\nTrack {ti}: {len(note_ons)} note-ons over ~{total_bars} bars")
        print("Active bars:")
        for bar in range(total_bars):
            notes = bar_notes.get(bar, [])
            if notes:
                desc = " ".join(f"{NOTE_NAMES[n%12]}{n//12-1}:v{v}" for n,v in sorted(notes))
                print(f"  bar{bar+1:3d}: [{len(notes):2d}] {desc}")

        print("Silence runs (>=2 bars with no new note-ons):")
        in_silence = False; sstart = 0
        for bar in range(total_bars + 1):
            has = bar in bar_notes
            if not has and not in_silence: sstart = bar; in_silence = True
            elif has and in_silence:
                slen = bar - sstart
                if slen >= 2: print(f"  bars {sstart+1}-{bar} ({slen} empty)")
                in_silence = False
        if in_silence and total_bars - sstart >= 2:
            print(f"  bars {sstart+1}-{total_bars+1} ({total_bars-sstart} empty, end)")

#!/usr/bin/env python3
import struct
from pathlib import Path

ROOT = Path('/Users/urlocker/Downloads/Zudio')
OUT = ROOT / 'assets/midi/references/hallogallo-tab/hallogallo-tab-translation.mid'
PPQ = 480
BPM = 124
BAR = PPQ * 4
EIGHTH = PPQ // 2


def vlq(n):
    b = [n & 0x7F]
    n >>= 7
    while n:
        b.append((n & 0x7F) | 0x80)
        n >>= 7
    return bytes(reversed(b))


class Track:
    def __init__(self):
        self.events = []

    def add(self, t, data):
        self.events.append((t, data))

    def note(self, ch, note, vel, start, dur):
        self.add(start, bytes([0x90 | ch, note & 0x7F, vel & 0x7F]))
        self.add(start + dur, bytes([0x80 | ch, note & 0x7F, 0]))

    def prog(self, ch, program, t=0):
        self.add(t, bytes([0xC0 | ch, program & 0x7F]))

    def name(self, name, t=0):
        b = name.encode('utf-8')
        self.add(t, b'\xFF\x03' + vlq(len(b)) + b)

    def bytes(self):
        out = b''
        cur = 0
        for t, msg in sorted(self.events, key=lambda x: (x[0], x[1])):
            out += vlq(t - cur) + msg
            cur = t
        out += b'\x00\xFF\x2F\x00'
        return b'MTrk' + struct.pack('>I', len(out)) + out


# A-string fret to MIDI note (A2 is 45)
def a_fret(f):
    return 45 + f

# D-string fret to MIDI note (D3 is 50)
def d_fret(f):
    return 50 + f

# G-string fret to MIDI note (G3 is 55)
def g_fret(f):
    return 55 + f


def main():
    tempo = Track(); tempo.name('Tempo')
    mpqn = int(60_000_000 / BPM)
    tempo.add(0, b'\xFF\x51\x03' + struct.pack('>I', mpqn)[1:])
    tempo.add(0, b'\xFF\x58\x04\x04\x02\x18\x08')

    bass = Track(); bass.name('Bass (Hallogallo Tab)')
    g1 = Track(); g1.name('Guitar 1 Power Chords')
    g2 = Track(); g2.name('Guitar 2 Motif')

    # GM: 34 finger bass, 30 overdriven guitar, 28 clean guitar
    bass.prog(0, 33)
    g1.prog(1, 29)
    g2.prog(2, 27)

    base_pattern = [7, 7, 7, None, 7, 7, 7, None, 7, 7, 7, 7, 7, 7, 7, None]
    var_pattern = [5, 7, 7, None, 5, 7, 7, None, 5, 7, 7, 7, 7, 7, 7, None]

    total_bars = 32
    for bar in range(total_bars):
        start = bar * BAR
        pat = var_pattern if (bar % 8 == 7) else base_pattern
        for i, fret in enumerate(pat):
            if fret is None:
                continue
            t = start + i * EIGHTH // 2  # 16th grid drive
            dur = EIGHTH // 2
            n = a_fret(fret)
            bass.note(0, n, 100 if i in (0, 8, 12) else 88, t, dur)

            # Guitar 1 doubles with power chord (root + fifth)
            g1.note(1, n + 12, 84, t, dur)
            g1.note(1, n + 19, 76, t, dur)

    # Guitar 2 motif from tab (played a few times)
    # D string: 7,9 ... 7,9 ; G string: 11,11 ... 9,9
    motif = [
        (0, d_fret(7), 84), (2, d_fret(9), 86),
        (4, g_fret(11), 82), (6, g_fret(11), 82),
        (10, d_fret(7), 84), (12, d_fret(9), 86),
        (14, g_fret(9), 80), (15, g_fret(9), 80),
    ]
    for bar in (8, 16, 24, 28):
        start = bar * BAR
        for step, note, vel in motif:
            g2.note(2, note, vel, start + step * (BAR // 16), BAR // 16)

    tracks = [tempo, bass, g1, g2]
    header = b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), PPQ)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(header + b''.join(t.bytes() for t in tracks))
    print(OUT)


if __name__ == '__main__':
    main()

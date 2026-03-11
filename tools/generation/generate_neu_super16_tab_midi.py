#!/usr/bin/env python3
import struct
from pathlib import Path

ROOT = Path('/Users/urlocker/Downloads/Zudio')
OUT = ROOT / 'assets/midi/references/neu-super16-tab/neu-super16-tab-translation.mid'
PPQ = 480
BPM = 160
BAR = PPQ * 4
STEP = BAR // 16


def vlq(n):
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.append((n & 0x7F) | 0x80)
        n >>= 7
    return bytes(reversed(out))


class Track:
    def __init__(self):
        self.e = []

    def add(self, t, m):
        self.e.append((t, m))

    def name(self, s, t=0):
        b = s.encode('utf-8')
        self.add(t, b'\xFF\x03' + vlq(len(b)) + b)

    def prog(self, ch, p, t=0):
        self.add(t, bytes([0xC0 | ch, p & 0x7F]))

    def note(self, ch, n, v, s, d):
        self.add(s, bytes([0x90 | ch, n & 0x7F, v & 0x7F]))
        self.add(s + d, bytes([0x80 | ch, n & 0x7F, 0]))

    def bytes(self):
        out = b''
        cur = 0
        for t, m in sorted(self.e, key=lambda x: (x[0], x[1])):
            out += vlq(t - cur) + m
            cur = t
        out += b'\x00\xFF\x2F\x00'
        return b'MTrk' + struct.pack('>I', len(out)) + out


ROOTS = {
    'G': 55,
    'C': 48,
    'A': 57,
    'D': 50,
}


def add_chug(clean, fuzz, chord, bar_idx, with_fill):
    if chord == 'NC':
        return
    root = ROOTS[chord]
    fifth = root + 7
    top = root + 12
    base = bar_idx * BAR

    # Eighth-note motorik-adjacent chug.
    for st in (0, 2, 4, 6, 8, 10, 12, 14):
        t = base + st * STEP
        v = 92 if st in (0, 8, 12) else 82
        clean.note(0, top, v, t, STEP)
        clean.note(0, fifth, v - 6, t, STEP)
        fuzz.note(1, root, min(110, v + 8), t, STEP)

    # Tab-inspired end-bar upper movement (2, b3, 1 feel).
    if with_fill:
        for st, semis, vel in ((10, 2, 86), (12, 3, 90), (14, 0, 84)):
            t = base + st * STEP
            clean.note(0, top + semis, vel, t, STEP)


def main():
    tempo = Track(); tempo.name('Tempo')
    mpqn = int(60_000_000 / BPM)
    tempo.add(0, b'\xFF\x51\x03' + struct.pack('>I', mpqn)[1:])
    tempo.add(0, b'\xFF\x58\x04\x04\x02\x18\x08')

    clean = Track(); clean.name('Rhythm Guitar (Super16 tab)')
    fuzz = Track(); fuzz.name('Fuzz Riff')
    clean.prog(0, 28)  # GM29 electric clean
    fuzz.prog(1, 30)   # GM31 distortion guitar

    sections = [
        ('Verse 1', [('G', 16, True), ('C', 4, False), ('C', 4, True), ('G', 8, True)]),
        ('Bridge 1', [('G', 4, False), ('NC', 4, False)]),
        ('Verse 2', [('G', 16, True), ('C', 4, False), ('C', 4, True), ('G', 16, True)]),
        ('Bridge 2', [('G', 4, False), ('NC', 2, False)]),
        ('Verse 3', [('A', 16, True), ('D', 4, False), ('D', 4, True), ('A', 16, True)]),
    ]

    bar = 0
    markers = Track(); markers.name('Section Markers')
    for sec_name, seq in sections:
        b = sec_name.encode('utf-8')
        markers.add(bar * BAR, b'\xFF\x06' + vlq(len(b)) + b)
        for chord, bars, fill in seq:
            for i in range(bars):
                add_chug(clean, fuzz, chord, bar, fill and (i % 2 == 1))
                bar += 1

    tracks = [tempo, clean, fuzz, markers]
    header = b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), PPQ)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(header + b''.join(t.bytes() for t in tracks))
    print(OUT)


if __name__ == '__main__':
    main()

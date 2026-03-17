#!/usr/bin/env python3
"""
analyze_midi_drums.py

Analyzes a MIDI file for drum pattern content and outputs:
  - File summary (format, tempo, bar count)
  - All GM drum notes used with hit counts and velocity ranges
  - Per-2-bar-block fingerprint grid (kick/snare/hat/cymbal overview)
  - Detailed event dump for any specified blocks

Usage:
    python3 analyze_midi_drums.py <midi_file> [--blocks 0 7 16 ...]

Examples:
    python3 analyze_midi_drums.py ../../assets/midi/motorik/drums/Drumscribe\ -\ Motorik\ -\ MIDI.mid
    python3 analyze_midi_drums.py some.mid --blocks 0 1 15 31 63
"""

import struct
import sys
import argparse

# ---------------------------------------------------------------------------
# GM drum note names (channel 10, notes 35-81)
# ---------------------------------------------------------------------------
GM_DRUMS = {
    35: 'Kick2',        36: 'Kick',          37: 'Sidestick',
    38: 'Snare',        39: 'Clap',          40: 'Snare2',
    41: 'LowFloorTom',  42: 'ClosedHat',     43: 'HighFloorTom',
    44: 'PedalHat',     45: 'LowMidTom',     46: 'OpenHat',
    47: 'HiMidTom',     48: 'HiTom',         49: 'Crash1',
    50: 'HiTom2',       51: 'Ride',          52: 'China',
    53: 'RideBell',     54: 'Tambourine',    55: 'Splash',
    56: 'Cowbell',      57: 'Crash2',        58: 'Vibraslap',
    59: 'Ride2',
}


def drum_name(note):
    return GM_DRUMS.get(note, f'Note{note}')


# ---------------------------------------------------------------------------
# MIDI parser
# ---------------------------------------------------------------------------

def read_var_len(data, pos):
    val = 0
    while True:
        b = data[pos]; pos += 1
        val = (val << 7) | (b & 0x7F)
        if not (b & 0x80):
            break
    return val, pos


def parse_midi(path):
    with open(path, 'rb') as f:
        data = f.read()

    magic = data[0:4]
    assert magic == b'MThd', f"Not a MIDI file: {path}"
    hlen = struct.unpack('>I', data[4:8])[0]
    fmt, ntracks, tpq = struct.unpack('>HHH', data[8:14])

    pos = 8 + hlen
    all_tracks = []

    for t in range(ntracks):
        assert data[pos:pos+4] == b'MTrk', f"Expected MTrk at byte {pos}"
        tlen = struct.unpack('>I', data[pos+4:pos+8])[0]
        track_end = pos + 8 + tlen
        pos += 8

        tick = 0
        running_status = 0
        events = []

        while pos < track_end:
            delta, pos = read_var_len(data, pos)
            tick += delta
            b = data[pos]

            if b == 0xFF:                       # meta event
                pos += 1
                mtype = data[pos]; pos += 1
                mlen, pos = read_var_len(data, pos)
                mdata = data[pos:pos+mlen]; pos += mlen
                if mtype == 0x51:
                    us = struct.unpack('>I', b'\x00' + mdata)[0]
                    events.append({'tick': tick, 'type': 'tempo', 'us': us,
                                   'bpm': round(60_000_000 / us, 2)})
                elif mtype == 0x2F:
                    events.append({'tick': tick, 'type': 'end'})

            elif b in (0xF0, 0xF7):             # sysex
                pos += 1
                slen, pos = read_var_len(data, pos)
                pos += slen

            else:                               # channel event
                if b & 0x80:
                    running_status = b
                    pos += 1
                status = running_status
                ch = status & 0x0F
                msg = (status >> 4) & 0x0F

                if msg in (0x8, 0x9, 0xA):      # note off / on / aftertouch
                    note = data[pos]; vel = data[pos+1]; pos += 2
                    if msg == 0x9 and vel > 0:
                        events.append({'tick': tick, 'type': 'note_on',
                                       'note': note, 'vel': vel, 'ch': ch})
                    else:
                        events.append({'tick': tick, 'type': 'note_off',
                                       'note': note, 'ch': ch})
                elif msg in (0xB, 0xE):
                    pos += 2
                elif msg in (0xC, 0xD):
                    pos += 1
                else:
                    pos += 1

        all_tracks.append(events)

    return fmt, ntracks, tpq, all_tracks


# ---------------------------------------------------------------------------
# Analysis helpers
# ---------------------------------------------------------------------------

def collect_note_ons(tracks):
    events = []
    for track in tracks:
        events.extend(e for e in track if e['type'] == 'note_on')
    return sorted(events, key=lambda e: e['tick'])


def collect_tempos(tracks):
    events = []
    for track in tracks:
        events.extend(e for e in track if e['type'] == 'tempo')
    return sorted(events, key=lambda e: e['tick'])


def quantize_step(tick, ticks_per_step):
    return round(tick / ticks_per_step)


def block_fingerprint(note_ons, block_idx, steps_per_block, ticks_per_step):
    """Return a compact string showing kick/snare/hat/cymbal per step."""
    start = block_idx * steps_per_block * ticks_per_step
    end   = start + steps_per_block * ticks_per_step

    step_notes = {}
    for e in note_ons:
        if start <= e['tick'] < end:
            step = quantize_step(e['tick'] - start, ticks_per_step)
            if step < steps_per_block:
                step_notes.setdefault(step, []).append(e['note'])

    chars = []
    for step in range(steps_per_block):
        notes = step_notes.get(step, [])
        # Priority: kick > snare > hat > open > crash/ride > other
        if   36 in notes or 35 in notes: c = 'K'
        elif 38 in notes or 40 in notes: c = 'S'
        elif 42 in notes or 44 in notes: c = 'H'
        elif 46 in notes:                c = 'O'
        elif 49 in notes or 57 in notes: c = 'C'
        elif 51 in notes or 53 in notes: c = 'R'
        elif any(n in notes for n in (41,43,45,47,48,50)): c = 'T'
        elif notes:                      c = 'X'
        else:                            c = '.'
        chars.append(c)
    return ''.join(chars)


def show_block_detail(note_ons, block_idx, steps_per_block, ticks_per_step):
    start = block_idx * steps_per_block * ticks_per_step
    end   = start + steps_per_block * ticks_per_step
    blk   = [e for e in note_ons if start <= e['tick'] < end]

    print(f"\n--- Block {block_idx} (bars {block_idx*2+1}-{block_idx*2+2}) detail ---")
    for e in sorted(blk, key=lambda x: x['tick']):
        step      = quantize_step(e['tick'] - start, ticks_per_step)
        bar_local = step // 16 + 1
        step_local = step % 16
        print(f"  Bar{bar_local} step{step_local:2d}  {drum_name(e['note']):<14s} vel={e['vel']}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description='Analyse MIDI drum patterns')
    parser.add_argument('midi_file', help='Path to MIDI file')
    parser.add_argument('--blocks', nargs='*', type=int, default=[],
                        help='Block indices to show in full detail (0-based, 2-bar blocks)')
    parser.add_argument('--steps-per-block', type=int, default=32,
                        help='Steps per analysis block (default: 32 = 2 bars at 16 steps/bar)')
    args = parser.parse_args()

    fmt, ntracks, tpq, tracks = parse_midi(args.midi_file)
    note_ons = collect_note_ons(tracks)
    tempos   = collect_tempos(tracks)
    ticks_per_step = tpq // 4   # 16th-note grid

    # --- File summary ---
    max_tick = max(e['tick'] for t in tracks for e in t)
    total_steps = round(max_tick / ticks_per_step)
    total_bars  = total_steps / 16
    num_blocks  = int(total_bars) // 2

    print("=" * 60)
    print(f"File: {args.midi_file}")
    print(f"Format: {fmt}  Tracks: {ntracks}  TPQ: {tpq}")
    print(f"Ticks per 16th note: {ticks_per_step}")
    if tempos:
        t0 = tempos[0]
        print(f"Tempo: {t0['bpm']} BPM ({t0['us']} µs/beat)")
    print(f"Total bars (4/4): {total_bars:.0f}")
    print(f"Analysis blocks (2-bar): {num_blocks}")

    # --- Notes used ---
    notes_used = sorted(set(e['note'] for e in note_ons))
    print(f"\nGM notes used ({len(notes_used)}):")
    for n in notes_used:
        hits = [e for e in note_ons if e['note'] == n]
        vels = [e['vel'] for e in hits]
        print(f"  {n:3d}  {drum_name(n):<14s}  {len(hits):4d} hits  "
              f"vel {min(vels)}-{max(vels)}")

    # --- Block fingerprints ---
    print(f"\nBlock fingerprints (32 steps = 2 bars per row):")
    print(f"  Legend: K=kick  S=snare  H=closed-hat  O=open-hat  C=crash  R=ride  T=tom  X=other  .=silent")
    print()
    for blk in range(num_blocks):
        fp = block_fingerprint(note_ons, blk, args.steps_per_block, ticks_per_step)
        bar_a = blk * 2 + 1
        bar_b = bar_a + 1
        print(f"  [{blk:3d}] bars {bar_a:3d}-{bar_b:3d}: {fp}")

    # --- Detailed block dumps ---
    for blk in args.blocks:
        if 0 <= blk < num_blocks:
            show_block_detail(note_ons, blk, args.steps_per_block, ticks_per_step)
        else:
            print(f"\nWarning: block {blk} out of range (0-{num_blocks-1})")


if __name__ == '__main__':
    main()

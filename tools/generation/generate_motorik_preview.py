#!/usr/bin/env python3
import json, struct
from pathlib import Path

ROOT = Path('/Users/urlocker/Downloads/Zudio')
STARTERS = ROOT / 'assets/midi/motorik/starters'
OUT_MID = ROOT / 'renders/previews/zudio-preview-motorik-drum-bass-pads.mid'

PPQ = 480
BPM = 138
TOTAL_BARS = 16
BAR_TICKS = PPQ * 4
STEPS_PER_BAR = 16
STEP_TICKS = BAR_TICKS // STEPS_PER_BAR

# E natural minor
TONIC_MIDI_BASS = 52  # E3 as center before oct offsets
DEGREE_OFFSETS = {
    '1':0,'2':2,'b3':3,'3':4,'4':5,'5':7,'b6':8,'6':9,'b7':10,'7':11,'9':14
}

def vlq(n:int)->bytes:
    b=[n & 0x7F]
    n >>= 7
    while n:
        b.append((n & 0x7F) | 0x80)
        n >>= 7
    return bytes(reversed(b))

class Track:
    def __init__(self):
        self.events=[]  # (tick, bytes)
    def add(self,tick,msg):
        self.events.append((tick,msg))
    def note(self,ch,note,vel,start,dur):
        self.add(start, bytes([0x90|ch, note & 0x7F, vel & 0x7F]))
        self.add(start+dur, bytes([0x80|ch, note & 0x7F, 0]))
    def program(self,ch,prog,tick=0):
        self.add(tick, bytes([0xC0|ch, prog & 0x7F]))
    def meta_name(self,name,tick=0):
        data=name.encode('utf-8')
        self.add(tick, b'\xFF\x03' + vlq(len(data)) + data)
    def bytes(self):
        out=b''
        cur=0
        # stable ordering for same tick
        for t,msg in sorted(self.events, key=lambda x:(x[0], x[1])):
            dt=t-cur
            out += vlq(dt) + msg
            cur=t
        out += b'\x00\xFF\x2F\x00'
        return b'MTrk' + struct.pack('>I', len(out)) + out

def degree_to_midi(deg, octv):
    off = DEGREE_OFFSETS.get(deg, 0)
    return TONIC_MIDI_BASS + off + (octv * 12)

def chord_for_bar(bar_idx):
    # i-bVII alternation in E minor: Em, D
    if bar_idx % 2 == 0:
        return {'R':52, '3':55, '5':59, '7':62, '2':54, '9':66}  # Em around E3
    return {'R':50, '3':54, '5':57, '7':60, '2':52, '9':64}      # D around D3

def main():
    bass = json.loads((STARTERS/'bass-starters-v1.json').read_text())
    pads = json.loads((STARTERS/'pads-starters-v1.json').read_text())
    bass_pat = next(p for p in bass['patterns'] if p['id']=='bass_anchor_01')
    pad_tpl = next(t for t in pads['templates'] if t['id']=='pad_hold_triad_01')

    # tempo track
    tempo = Track()
    tempo.meta_name('Tempo')
    mpqn = int(60_000_000 / BPM)
    tempo.add(0, b'\xFF\x51\x03' + struct.pack('>I', mpqn)[1:])
    tempo.add(0, b'\xFF\x58\x04\x04\x02\x18\x08')  # 4/4

    drums = Track(); bass_tr = Track(); pads_tr = Track()
    drums.meta_name('Drums'); bass_tr.meta_name('Bass'); pads_tr.meta_name('Pads')

    # Programs (GM numbers 1-based -> MIDI program 0-based)
    bass_tr.program(0, 38)  # Synth Bass 1 (GM39)
    pads_tr.program(1, 89)  # Warm Pad (GM90)

    # Drums on ch 9
    for bar in range(TOTAL_BARS):
        base = bar * BAR_TICKS
        # 8th hats
        for s in range(0,16,2):
            vel = 84 if s in (0,8) else 72
            drums.note(9, 42, vel, base + s*STEP_TICKS, STEP_TICKS)
        # kick 4-on-floor
        for s in (0,4,8,12):
            drums.note(9, 36, 110 if s in (0,8) else 100, base + s*STEP_TICKS, STEP_TICKS)
        # snare 2/4
        for s in (4,12):
            drums.note(9, 38, 102, base + s*STEP_TICKS, STEP_TICKS)
        # section accent
        if bar in (0,8):
            drums.note(9, 49, 96, base, STEP_TICKS*2)
        # final bar fill
        if bar == TOTAL_BARS - 1:
            for s,n in ((12,45),(13,47),(14,48),(15,50)):
                drums.note(9, n, 92, base + s*STEP_TICKS, STEP_TICKS)

    # Bass enters at bar 2 (after 2-bar drum intro)
    bass_start_bar = 2
    bass_pat_ticks = bass_pat['bars'] * BAR_TICKS
    for bar in range(bass_start_bar, TOTAL_BARS):
        loop_base = bar * BAR_TICKS
        pattern_base = ((bar - bass_start_bar) // bass_pat['bars']) * bass_pat_ticks
        local_bar_offset = ((bar - bass_start_bar) % bass_pat['bars']) * BAR_TICKS
        for ev in bass_pat['events']:
            step_tick = ev['step'] * STEP_TICKS
            if local_bar_offset <= step_tick < local_bar_offset + BAR_TICKS:
                t = loop_base + (step_tick - local_bar_offset)
                dur = ev['len'] * STEP_TICKS
                note = degree_to_midi(ev['degree'], ev['oct'])
                bass_tr.note(0, note, ev['vel'], t, dur)

    # Pads enter at bar 4 (after drums+bass lock)
    pads_start_bar = 4
    pad_tpl_ticks = pad_tpl['bars'] * BAR_TICKS
    for bar in range(pads_start_bar, TOTAL_BARS):
        local_bar_in_tpl = (bar - pads_start_bar) % pad_tpl['bars']
        bar_window_start = local_bar_in_tpl * BAR_TICKS
        bar_base = bar * BAR_TICKS
        chord = chord_for_bar(bar)
        for ev in pad_tpl['events']:
            ev_start = ev['step'] * STEP_TICKS
            if bar_window_start <= ev_start < bar_window_start + BAR_TICKS:
                t = bar_base + (ev_start - bar_window_start)
                dur = ev['len'] * STEP_TICKS
                base_note = chord.get(ev['role'], chord['R'])
                note = base_note + (ev.get('oct',0) * 12)
                pads_tr.note(1, note, ev['vel'], t, dur)

    tracks = [tempo, drums, bass_tr, pads_tr]
    header = b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), PPQ)
    data = header + b''.join(t.bytes() for t in tracks)
    OUT_MID.write_bytes(data)
    print(str(OUT_MID))

if __name__ == '__main__':
    main()

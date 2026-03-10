#!/usr/bin/env python3
import json, struct
from pathlib import Path

ROOT = Path('/Users/urlocker/Downloads/Zudio')
STARTERS = ROOT / 'assets/midi/motorik/starters'
OUT_MID = ROOT / 'renders/previews/zudio-preview-motorik-drum-bass-pads-lead1-texture.mid'

PPQ = 480
BPM = 138
TOTAL_BARS = 24
BAR_TICKS = PPQ * 4
STEPS_PER_BAR = 16
STEP_TICKS = BAR_TICKS // STEPS_PER_BAR

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
        self.events=[]
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
        for t,msg in sorted(self.events, key=lambda x:(x[0], x[1])):
            out += vlq(t-cur) + msg
            cur=t
        out += b'\x00\xFF\x2F\x00'
        return b'MTrk' + struct.pack('>I', len(out)) + out

def degree_to_midi(deg, octv, tonic_center):
    return tonic_center + DEGREE_OFFSETS.get(deg,0) + (octv*12)

def chord_for_bar(bar_idx):
    # i-bVII alternation in E minor: Em, D
    if bar_idx % 2 == 0:
        return {'R':52, '3':55, '5':59, '7':62, '2':54, '9':66}  # Em around E3
    return {'R':50, '3':54, '5':57, '7':60, '2':52, '9':64}      # D around D3

def main():
    bass_data = json.loads((STARTERS/'bass-starters-v1.json').read_text())
    pads_data = json.loads((STARTERS/'pads-starters-v1.json').read_text())
    lead_data = json.loads((STARTERS/'lead1-starters-v1.json').read_text())
    tex_data = json.loads((STARTERS/'texture-starters-v1.json').read_text())

    bass_pat = next(p for p in bass_data['patterns'] if p['id']=='bass_anchor_01')
    pad_tpl = next(t for t in pads_data['templates'] if t['id']=='pad_hold_triad_01')
    lead_a = next(m for m in lead_data['motifs'] if m['id']=='lead1_motif_01')
    lead_b = next(m for m in lead_data['motifs'] if m['id']=='lead1_motif_06')
    tex_events = [
        next(e for e in tex_data['events'] if e['id']=='texture_swell_01'),
        next(e for e in tex_data['events'] if e['id']=='texture_glass_06'),
        next(e for e in tex_data['events'] if e['id']=='texture_tail_05')
    ]

    tempo = Track(); tempo.meta_name('Tempo')
    mpqn = int(60_000_000 / BPM)
    tempo.add(0, b'\xFF\x51\x03' + struct.pack('>I', mpqn)[1:])
    tempo.add(0, b'\xFF\x58\x04\x04\x02\x18\x08')

    drums = Track(); drums.meta_name('Drums')
    bass = Track(); bass.meta_name('Bass')
    pads = Track(); pads.meta_name('Pads')
    lead = Track(); lead.meta_name('Lead 1')
    texture = Track(); texture.meta_name('Texture')

    # Programs (GM 1-based -> program 0-based)
    bass.program(0, 38)      # GM39 Synth Bass 1
    pads.program(1, 89)      # GM90 Warm Pad
    lead.program(2, 81)      # GM82 Saw Wave
    texture.program(3, 93)   # GM94 Metallic Pad

    # Drums (motorik core)
    for bar in range(TOTAL_BARS):
        base = bar * BAR_TICKS
        # hats 8ths; slight lift in middle section
        for s in range(0,16,2):
            vel = 84 if s in (0,8) else 72
            if 8 <= bar < 16:
                vel += 4
            drums.note(9, 42, vel, base + s*STEP_TICKS, STEP_TICKS)

        # kick 4-on-floor + slight accent
        for s in (0,4,8,12):
            kv = 112 if s in (0,8) else 102
            if bar in (0,8,16):
                kv += 4
            drums.note(9, 36, kv, base + s*STEP_TICKS, STEP_TICKS)

        # snare on 2/4
        for s in (4,12):
            sv = 104 if 8 <= bar < 16 else 100
            drums.note(9, 38, sv, base + s*STEP_TICKS, STEP_TICKS)

        if bar in (0,8,16):
            drums.note(9, 49, 98, base, STEP_TICKS*2)

        # occasional one-beat pickup fill at phrase ends
        if bar in (7,15,23):
            for i,n in enumerate((45,47,48,50)):
                drums.note(9, n, 90, base + (12+i)*STEP_TICKS, STEP_TICKS)

    # Bass enters at bar 2
    bass_start = 2
    pat_bars = bass_pat['bars']
    for bar in range(bass_start, TOTAL_BARS):
        local_bar = (bar - bass_start) % pat_bars
        local_start = local_bar * BAR_TICKS
        abs_bar = bar * BAR_TICKS
        for ev in bass_pat['events']:
            st = ev['step'] * STEP_TICKS
            if local_start <= st < local_start + BAR_TICKS:
                t = abs_bar + (st - local_start)
                note = degree_to_midi(ev['degree'], ev['oct'], tonic_center=52)
                bass.note(0, note, ev['vel'], t, ev['len'] * STEP_TICKS)

    # Pads enter at bar 4
    pads_start = 4
    tpl_bars = pad_tpl['bars']
    for bar in range(pads_start, TOTAL_BARS):
        local_bar = (bar - pads_start) % tpl_bars
        local_start = local_bar * BAR_TICKS
        abs_bar = bar * BAR_TICKS
        chord = chord_for_bar(bar)
        for ev in pad_tpl['events']:
            st = ev['step'] * STEP_TICKS
            if local_start <= st < local_start + BAR_TICKS:
                t = abs_bar + (st - local_start)
                base_note = chord.get(ev['role'], chord['R'])
                note = base_note + (ev.get('oct',0)*12)
                pads.note(1, note, ev['vel'], t, ev['len'] * STEP_TICKS)

    # Lead 1 enters at bar 8, alternates motifs every 4 bars
    lead_start = 8
    for block_start in range(lead_start, TOTAL_BARS, 4):
        motif = lead_a if ((block_start // 4) % 2 == 0) else lead_b
        m_bars = motif['bars']
        for bar in range(block_start, min(block_start + 4, TOTAL_BARS)):
            local_bar = (bar - block_start) % m_bars
            local_start = local_bar * BAR_TICKS
            abs_bar = bar * BAR_TICKS
            for ev in motif['events']:
                st = ev['step'] * STEP_TICKS
                if local_start <= st < local_start + BAR_TICKS:
                    t = abs_bar + (st - local_start)
                    note = degree_to_midi(ev['degree'], ev['oct'], tonic_center=64)
                    # keep lead under control in dense sections
                    vel = max(68, min(100, ev['vel']))
                    lead.note(2, note, vel, t, ev['len'] * STEP_TICKS)

    # Texture: sparse events around section boundaries + tail
    texture_plan = [(7, tex_events[0]), (15, tex_events[1]), (22, tex_events[2])]
    for bar, evset in texture_plan:
        base = bar * BAR_TICKS
        for n in evset['notes']:
            t = base + n['step'] * STEP_TICKS
            note = degree_to_midi(n['degree'], n.get('oct', 0), tonic_center=64)
            texture.note(3, note, n['vel'], t, n['len'] * STEP_TICKS)

    tracks = [tempo, drums, bass, pads, lead, texture]
    header = b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), PPQ)
    data = header + b''.join(t.bytes() for t in tracks)
    OUT_MID.parent.mkdir(parents=True, exist_ok=True)
    OUT_MID.write_bytes(data)
    print(OUT_MID)

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
import json, struct
from pathlib import Path

ROOT = Path('/Users/urlocker/Downloads/Zudio')
STARTERS = ROOT / 'assets/midi/motorik/starters'
OUT_MID = ROOT / 'renders/previews/zudio-preview-motorik-drum-bass-pads-lead1-texture-variation.mid'

PPQ = 480
BPM = 142
TOTAL_BARS = 32
BAR_TICKS = PPQ * 4
STEPS_PER_BAR = 16
STEP_TICKS = BAR_TICKS // STEPS_PER_BAR

DEG = {'1':0,'2':2,'b3':3,'3':4,'4':5,'5':7,'b6':8,'6':9,'b7':10,'7':11,'9':14}

def vlq(n):
    b=[n & 0x7F]; n >>= 7
    while n: b.append((n & 0x7F)|0x80); n >>= 7
    return bytes(reversed(b))

class Track:
    def __init__(self): self.events=[]
    def add(self,t,m): self.events.append((t,m))
    def note(self,ch,n,v,s,d):
        self.add(s, bytes([0x90|ch, n & 0x7F, v & 0x7F]))
        self.add(s+d, bytes([0x80|ch, n & 0x7F, 0]))
    def prog(self,ch,p,t=0): self.add(t, bytes([0xC0|ch,p & 0x7F]))
    def name(self,n,t=0):
        d=n.encode(); self.add(t, b'\xFF\x03'+vlq(len(d))+d)
    def bytes(self):
        out=b''; cur=0
        for t,m in sorted(self.events, key=lambda x:(x[0],x[1])):
            out += vlq(t-cur)+m; cur=t
        out += b'\x00\xFF\x2F\x00'
        return b'MTrk'+struct.pack('>I',len(out))+out

def chord_for_bar(b):
    # A section (bars 0-15): Em-D ; B section (16-31): Em-C-D-C
    if b < 16:
        return ('Em' if b%2==0 else 'D')
    cyc = ['Em','C','D','C']
    return cyc[(b-16)%4]

CH = {
    'Em': {'R':52,'3':55,'5':59,'7':62,'2':54,'9':66},
    'D':  {'R':50,'3':54,'5':57,'7':60,'2':52,'9':64},
    'C':  {'R':48,'3':52,'5':55,'7':59,'2':50,'9':62},
}

def d2m(d,octv,center): return center + DEG.get(d,0) + 12*octv


def main():
    bass_data=json.loads((STARTERS/'bass-starters-v1.json').read_text())
    pads_data=json.loads((STARTERS/'pads-starters-v1.json').read_text())
    lead_data=json.loads((STARTERS/'lead1-starters-v1.json').read_text())
    tex_data=json.loads((STARTERS/'texture-starters-v1.json').read_text())

    bass_patterns={p['id']:p for p in bass_data['patterns']}
    pad_templates={t['id']:t for t in pads_data['templates']}
    lead_motifs={m['id']:m for m in lead_data['motifs']}
    tex_events={e['id']:e for e in tex_data['events']}

    tempo=Track(); tempo.name('Tempo')
    mpqn=int(60_000_000/BPM)
    tempo.add(0,b'\xFF\x51\x03'+struct.pack('>I',mpqn)[1:])
    tempo.add(0,b'\xFF\x58\x04\x04\x02\x18\x08')

    drums=Track(); drums.name('Drums')
    bass=Track(); bass.name('Bass')
    pads=Track(); pads.name('Pads')
    lead=Track(); lead.name('Lead 1')
    texture=Track(); texture.name('Texture')

    bass.prog(0,39)    # GM40 Synth Bass 2 (more bite)
    pads.prog(1,90)    # GM91 Polysynth
    lead.prog(2,87)    # GM88 Bass & Lead
    texture.prog(3,94) # GM95 Halo Pad

    # DRUMS: dynamic hats/ride/open, ghost notes, frequent micro-fills
    for b in range(TOTAL_BARS):
        base=b*BAR_TICKS
        a_section=(b<16)
        # lane choice
        use_ride = (not a_section and b%4 in (2,3))
        cym_note = 51 if use_ride else 42

        # 8th grid, with 16th spurts
        for s in range(0,16,2):
            v=74 + (6 if s in (0,8) else 0) + (4 if b%8 in (4,5) else 0)
            drums.note(9,cym_note,v,base+s*STEP_TICKS,STEP_TICKS)
            if b%4==3 and s in (6,14):
                drums.note(9,46,82,base+(s+1)*STEP_TICKS,STEP_TICKS)  # open hat lift

        # kick backbone + alternates
        for s in (0,4,8,12):
            kv = 108 if s in (0,8) else 98
            if b in (0,8,16,24): kv += 6
            drums.note(9,36,kv,base+s*STEP_TICKS,STEP_TICKS)
        if b%4 in (1,3):
            drums.note(9,36,90,base+10*STEP_TICKS,STEP_TICKS)

        # snare + ghosts
        for s in (4,12): drums.note(9,38,102 if b%8<4 else 108,base+s*STEP_TICKS,STEP_TICKS)
        if b%2==1:
            drums.note(9,40,70,base+3*STEP_TICKS,STEP_TICKS)
            drums.note(9,40,68,base+11*STEP_TICKS,STEP_TICKS)

        # crashes
        if b in (0,8,16,24): drums.note(9,49,102,base,2*STEP_TICKS)

        # fills at phrase ends
        if b in (7,11,15,19,23,27,31):
            seq=[45,47,48,50] if b%8!=3 else [38,45,47,38]
            for i,n in enumerate(seq):
                drums.note(9,n,92+i*2,base+(12+i)*STEP_TICKS,STEP_TICKS)

    # BASS: alternate patterns by phrase and section, with bar-end approaches
    bass_start=2
    for b in range(bass_start,TOTAL_BARS):
        base=b*BAR_TICKS
        p = bass_patterns['bass_anchor_01'] if b<16 else bass_patterns['bass_anchor_06']
        # local 1-bar render from pattern events
        pbar = p['bars']
        lb = (b-bass_start)%pbar
        win0=lb*BAR_TICKS
        for e in p['events']:
            st=e['step']*STEP_TICKS
            if win0 <= st < win0+BAR_TICKS:
                t=base+(st-win0)
                n=d2m(e['degree'],e['oct'],52)
                v=min(115,e['vel']+(4 if b%8 in (0,4) else 0))
                bass.note(0,n,v,t,e['len']*STEP_TICKS)
        # extra approach into next bar root on phrase turns
        if b%4==3:
            bass.note(0,d2m('2',-2,52),82,base+14*STEP_TICKS,STEP_TICKS)
            bass.note(0,d2m('b3',-2,52),84,base+15*STEP_TICKS,STEP_TICKS)

    # PADS: A section long holds, B section more re-voicing/sus/add9
    for b in range(4,TOTAL_BARS):
        base=b*BAR_TICKS
        chord=CH[chord_for_bar(b)]
        if b < 16:
            tpl = pad_templates['pad_hold_triad_01']
        elif b%4 in (0,2):
            tpl = pad_templates['pad_halfbar_revoice_02']
        else:
            tpl = pad_templates['pad_sus2_04'] if b%8 in (3,7) else pad_templates['pad_add9_sparse_03']
        tb=tpl['bars']; lb=(b-4)%tb; win0=lb*BAR_TICKS
        for e in tpl['events']:
            st=e['step']*STEP_TICKS
            if win0 <= st < win0+BAR_TICKS:
                t=base+(st-win0)
                note=chord.get(e['role'],chord['R']) + 12*e.get('oct',0)
                dur=min(BAR_TICKS-(st-win0), e['len']*STEP_TICKS)
                pads.note(1,note,e['vel'],t,dur)

    # LEAD1: enters bar 8, phrase swapping + selective rests for space
    lead_plan=[
        ('lead1_motif_01',8,12),
        ('lead1_motif_06',12,16),
        ('lead1_motif_03',16,20),
        ('lead1_motif_08',20,24),
        ('lead1_motif_07',24,28),
        ('lead1_motif_02',28,32),
    ]
    for mid,s,e in lead_plan:
        m=lead_motifs[mid]; mb=m['bars']
        for b in range(s,e):
            if b%8==7:  # breath bar before section turn
                continue
            base=b*BAR_TICKS; lb=(b-s)%mb; win0=lb*BAR_TICKS
            for ev in m['events']:
                st=ev['step']*STEP_TICKS
                if win0 <= st < win0+BAR_TICKS:
                    t=base+(st-win0)
                    n=d2m(ev['degree'],ev['oct'],64)
                    v=max(72,min(104,ev['vel']+(6 if b%4==0 else 0)))
                    d=max(STEP_TICKS, ev['len']*STEP_TICKS)
                    lead.note(2,n,v,t,d)

    # TEXTURE: boundary swells + mid-section events + long tail
    tex_plan=[
        (6,'texture_swell_01'),(10,'texture_glass_06'),(14,'texture_rise_04'),
        (18,'texture_ping_03'),(22,'texture_air_02'),(26,'texture_swell_01'),
        (30,'texture_tail_05')
    ]
    for b,tid in tex_plan:
        e=tex_events[tid]; base=b*BAR_TICKS
        for n in e['notes']:
            t=base+n['step']*STEP_TICKS
            nn=d2m(n['degree'],n.get('oct',0),64)
            texture.note(3,nn,n['vel'],t,n['len']*STEP_TICKS)

    tracks=[tempo,drums,bass,pads,lead,texture]
    header=b'MThd'+struct.pack('>IHHH',6,1,len(tracks),PPQ)
    data=header+b''.join(t.bytes() for t in tracks)
    OUT_MID.parent.mkdir(parents=True, exist_ok=True)
    OUT_MID.write_bytes(data)
    print(OUT_MID)

if __name__=='__main__':
    main()

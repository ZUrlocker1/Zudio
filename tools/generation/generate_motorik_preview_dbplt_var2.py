#!/usr/bin/env python3
import json, struct
from pathlib import Path

ROOT = Path('/Users/urlocker/Downloads/Zudio')
STARTERS = ROOT / 'assets/midi/motorik/starters'
OUT_MID = ROOT / 'renders/previews/zudio-preview-motorik-drum-bass-pads-lead1-texture-variation-2.mid'

PPQ = 480
BPM = 140
TOTAL_BARS = 32
BAR_TICKS = PPQ * 4
STEP_TICKS = BAR_TICKS // 16
DEG = {'1':0,'2':2,'b3':3,'3':4,'4':5,'5':7,'b6':8,'6':9,'b7':10,'7':11,'9':14}


def vlq(n):
    b=[n & 0x7F]; n >>= 7
    while n:
        b.append((n & 0x7F) | 0x80); n >>= 7
    return bytes(reversed(b))

class T:
    def __init__(self): self.e=[]
    def add(self,t,m): self.e.append((t,m))
    def note(self,ch,n,v,s,d):
        self.add(s, bytes([0x90|ch, n & 0x7F, v & 0x7F]))
        self.add(s+d, bytes([0x80|ch, n & 0x7F, 0]))
    def prog(self,ch,p,t=0): self.add(t, bytes([0xC0|ch,p & 0x7F]))
    def name(self,n,t=0):
        d=n.encode(); self.add(t, b'\xFF\x03'+vlq(len(d))+d)
    def bytes(self):
        out=b''; cur=0
        for t,m in sorted(self.e, key=lambda x:(x[0],x[1])):
            out += vlq(t-cur)+m; cur=t
        out += b'\x00\xFF\x2F\x00'
        return b'MTrk'+struct.pack('>I',len(out))+out


def d2m(d,octv,center): return center + DEG.get(d,0) + 12*octv

def chord_name(bar):
    # A: Em-D ; B: Em-C-D-C
    if bar < 16:
        return 'Em' if bar%2==0 else 'D'
    return ['Em','C','D','C'][(bar-16)%4]

CH={
    'Em': {'R':52,'3':55,'5':59,'7':62,'2':54,'9':66},
    'D':  {'R':50,'3':54,'5':57,'7':60,'2':52,'9':64},
    'C':  {'R':48,'3':52,'5':55,'7':59,'2':50,'9':62},
}


def main():
    bass_data=json.loads((STARTERS/'bass-starters-v1.json').read_text())
    pads_data=json.loads((STARTERS/'pads-starters-v1.json').read_text())
    lead_data=json.loads((STARTERS/'lead1-starters-v1.json').read_text())
    tex_data=json.loads((STARTERS/'texture-starters-v1.json').read_text())

    bassP={p['id']:p for p in bass_data['patterns']}
    padsT={t['id']:t for t in pads_data['templates']}
    leadM={m['id']:m for m in lead_data['motifs']}
    texE={e['id']:e for e in tex_data['events']}

    tempo=T(); tempo.name('Tempo')
    mpqn=int(60_000_000/BPM)
    tempo.add(0,b'\xFF\x51\x03'+struct.pack('>I',mpqn)[1:])
    tempo.add(0,b'\xFF\x58\x04\x04\x02\x18\x08')

    drums=T(); drums.name('Drums')
    bass=T(); bass.name('Bass')
    pads=T(); pads.name('Pads')
    lead=T(); lead.name('Lead 1')
    tex=T(); tex.name('Texture')

    bass.prog(0,38)   # Synth Bass 1
    pads.prog(1,89)   # Warm Pad
    lead.prog(2,81)   # Saw Wave
    tex.prog(3,94)    # Halo Pad

    # drums
    for b in range(TOTAL_BARS):
        base=b*BAR_TICKS
        use_ride=(b>=16 and b%4 in (2,3))
        cym=51 if use_ride else 42
        for s in range(0,16,2):
            v=72 + (8 if s in (0,8) else 0)
            if b%8 in (4,5): v += 4
            drums.note(9,cym,v,base+s*STEP_TICKS,STEP_TICKS)
            if b%8 in (7,) and s in (6,14):
                drums.note(9,46,80,base+(s+1)*STEP_TICKS,STEP_TICKS)
        for s in (0,4,8,12):
            drums.note(9,36,110 if s in (0,8) else 100,base+s*STEP_TICKS,STEP_TICKS)
        for s in (4,12):
            drums.note(9,38,104 if b>=16 else 100,base+s*STEP_TICKS,STEP_TICKS)
        if b in (0,8,16,24): drums.note(9,49,100,base,2*STEP_TICKS)
        if b in (7,15,23,31):
            for i,n in enumerate((45,47,48,50)):
                drums.note(9,n,90+i*2,base+(12+i)*STEP_TICKS,STEP_TICKS)

    # bass
    bass_start=2
    for b in range(bass_start,TOTAL_BARS):
        p = bassP['bass_anchor_01'] if b<16 else bassP['bass_anchor_04']
        pb=p['bars']; lb=(b-bass_start)%pb; win0=lb*BAR_TICKS; base=b*BAR_TICKS
        for e in p['events']:
            st=e['step']*STEP_TICKS
            if win0 <= st < win0+BAR_TICKS:
                t=base+(st-win0)
                bass.note(0,d2m(e['degree'],e['oct'],52),e['vel'],t,e['len']*STEP_TICKS)
        if b%4==3:
            bass.note(0,d2m('2',-2,52),80,base+15*STEP_TICKS,STEP_TICKS)

    # pads
    for b in range(4,TOTAL_BARS):
        c=CH[chord_name(b)]
        tpl = padsT['pad_hold_triad_01'] if b<16 else (padsT['pad_halfbar_revoice_02'] if b%2==0 else padsT['pad_add9_sparse_03'])
        tb=tpl['bars']; lb=(b-4)%tb; win0=lb*BAR_TICKS; base=b*BAR_TICKS
        for e in tpl['events']:
            st=e['step']*STEP_TICKS
            if win0 <= st < win0+BAR_TICKS:
                t=base+(st-win0)
                note=c.get(e['role'],c['R'])+12*e.get('oct',0)
                dur=min(BAR_TICKS-(st-win0), e['len']*STEP_TICKS)
                pads.note(1,note,e['vel'],t,dur)

    # lead 1 - explicitly sparse early section
    early_ids=['lead1_motif_01','lead1_motif_05','lead1_motif_04']
    late_ids=['lead1_motif_06','lead1_motif_03','lead1_motif_08','lead1_motif_02']

    # bars 8-15: play only on even bars, and thin motif events to ~50%
    for b in range(8,16):
        if b % 2 == 1:
            continue  # full rest bars for breathing room
        m=leadM[early_ids[(b-8)//2 % len(early_ids)]]
        mb=m['bars']; lb=(b-8)%mb; win0=lb*BAR_TICKS; base=b*BAR_TICKS
        for idx,e in enumerate(m['events']):
            if idx % 2 == 1:
                continue
            st=e['step']*STEP_TICKS
            if win0 <= st < win0+BAR_TICKS:
                t=base+(st-win0)
                d=max(STEP_TICKS, min(e['len']*STEP_TICKS, 3*STEP_TICKS))
                v=max(70, min(92, e['vel']-4))
                lead.note(2,d2m(e['degree'],e['oct'],64),v,t,d)

    # bars 16-31: fuller but still phrase-breath rests every 4 bars
    for b in range(16,32):
        if b % 4 == 3:
            continue
        m=leadM[late_ids[(b-16) % len(late_ids)]]
        mb=m['bars']; lb=(b-16)%mb; win0=lb*BAR_TICKS; base=b*BAR_TICKS
        for idx,e in enumerate(m['events']):
            st=e['step']*STEP_TICKS
            if win0 <= st < win0+BAR_TICKS:
                # mild mutation for anti-repetition
                shift = STEP_TICKS if (idx==0 and b%4==1) else 0
                t=base+(st-win0)+shift
                d=max(STEP_TICKS, e['len']*STEP_TICKS)
                v=max(72, min(102, e['vel'] + (4 if b%4==0 else 0)))
                lead.note(2,d2m(e['degree'],e['oct'],64),v,t,d)

    # texture
    plan=[(6,'texture_swell_01'),(11,'texture_glass_06'),(15,'texture_rise_04'),(19,'texture_ping_03'),(24,'texture_air_02'),(30,'texture_tail_05')]
    for b,tid in plan:
        base=b*BAR_TICKS
        for n in texE[tid]['notes']:
            t=base+n['step']*STEP_TICKS
            tex.note(3,d2m(n['degree'],n.get('oct',0),64),n['vel'],t,n['len']*STEP_TICKS)

    tracks=[tempo,drums,bass,pads,lead,tex]
    head=b'MThd'+struct.pack('>IHHH',6,1,len(tracks),PPQ)
    OUT_MID.parent.mkdir(parents=True, exist_ok=True)
    OUT_MID.write_bytes(head + b''.join(t.bytes() for t in tracks))
    print(OUT_MID)

if __name__=='__main__':
    main()

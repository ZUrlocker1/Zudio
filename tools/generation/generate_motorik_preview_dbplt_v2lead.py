#!/usr/bin/env python3
import json, struct
from pathlib import Path

ROOT = Path('/Users/urlocker/Downloads/Zudio')
STARTERS = ROOT / 'assets/midi/motorik/starters'
OUT_MID = ROOT / 'renders/previews/zudio-preview-motorik-dbplt-lead1-v2.mid'

PPQ = 480
BPM = 140
TOTAL_BARS = 32
BAR = PPQ * 4
STEP = BAR // 16
DEG = {'1':0,'2':2,'b3':3,'3':4,'4':5,'5':7,'b6':8,'6':9,'b7':10,'7':11,'9':14}


def vlq(n):
    b=[n & 0x7F]; n >>= 7
    while n:
        b.append((n & 0x7F) | 0x80); n >>= 7
    return bytes(reversed(b))

class Track:
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
            out += vlq(t-cur) + m; cur=t
        out += b'\x00\xFF\x2F\x00'
        return b'MTrk' + struct.pack('>I', len(out)) + out


def d2m(deg, octv, center):
    return center + DEG.get(deg,0) + 12*octv


def chord_name(bar):
    if bar < 16:
        return 'Em' if bar % 2 == 0 else 'D'
    return ['Em','C','D','C'][(bar-16) % 4]

CH = {
    'Em': {'R':52,'3':55,'5':59,'7':62,'2':54,'9':66},
    'D':  {'R':50,'3':54,'5':57,'7':60,'2':52,'9':64},
    'C':  {'R':48,'3':52,'5':55,'7':59,'2':50,'9':62},
}


def main():
    bass = json.loads((STARTERS/'bass-starters-v1.json').read_text())
    pads = json.loads((STARTERS/'pads-starters-v1.json').read_text())
    lead = json.loads((STARTERS/'lead1-solo-starters-v2.json').read_text())
    tex = json.loads((STARTERS/'texture-starters-v1.json').read_text())

    bassP = {p['id']: p for p in bass['patterns']}
    padsT = {p['id']: p for p in pads['templates']}
    leadP = {p['id']: p for p in lead['phrases']}
    texE = {e['id']: e for e in tex['events']}

    tempo=Track(); tempo.name('Tempo')
    mpqn=int(60_000_000/BPM)
    tempo.add(0, b'\xFF\x51\x03'+struct.pack('>I', mpqn)[1:])
    tempo.add(0, b'\xFF\x58\x04\x04\x02\x18\x08')

    drums=Track(); drums.name('Drums')
    bassT=Track(); bassT.name('Bass')
    padsTt=Track(); padsTt.name('Pads')
    leadT=Track(); leadT.name('Lead 1')
    texT=Track(); texT.name('Texture')

    bassT.prog(0,38)  # GM39 Synth Bass1
    padsTt.prog(1,89) # GM90 Warm Pad
    leadT.prog(2,81)  # GM82 Saw
    texT.prog(3,94)   # GM95 Halo

    # drums
    for b in range(TOTAL_BARS):
        base=b*BAR
        ride = (b>=16 and b%4 in (2,3))
        cym = 51 if ride else 42
        for s in range(0,16,2):
            v=72 + (8 if s in (0,8) else 0) + (4 if b%8 in (4,5) else 0)
            drums.note(9,cym,v,base+s*STEP,STEP)
            if b%8 in (7,) and s in (6,14):
                drums.note(9,46,82,base+(s+1)*STEP,STEP)
        for s in (0,4,8,12):
            drums.note(9,36,112 if s in (0,8) else 100,base+s*STEP,STEP)
        for s in (4,12):
            drums.note(9,38,104 if b>=16 else 100,base+s*STEP,STEP)
        if b in (0,8,16,24):
            drums.note(9,49,100,base,2*STEP)
        if b in (7,15,23,31):
            for i,n in enumerate((45,47,48,50)):
                drums.note(9,n,92+i*2,base+(12+i)*STEP,STEP)

    # bass
    for b in range(2,TOTAL_BARS):
        p = bassP['bass_anchor_01'] if b < 16 else bassP['bass_anchor_06']
        pb = p['bars']; lb = (b-2) % pb; win0=lb*BAR; base=b*BAR
        for e in p['events']:
            st=e['step']*STEP
            if win0 <= st < win0+BAR:
                t = base + (st-win0)
                bassT.note(0,d2m(e['degree'],e['oct'],52),e['vel'],t,e['len']*STEP)
        if b%4==3:
            bassT.note(0,d2m('2',-2,52),80,base+15*STEP,STEP)

    # pads
    for b in range(4,TOTAL_BARS):
        c = CH[chord_name(b)]
        tpl = padsT['pad_hold_triad_01'] if b<16 else (padsT['pad_halfbar_revoice_02'] if b%2==0 else padsT['pad_add9_sparse_03'])
        tb=tpl['bars']; lb=(b-4)%tb; win0=lb*BAR; base=b*BAR
        for e in tpl['events']:
            st=e['step']*STEP
            if win0 <= st < win0+BAR:
                t=base+(st-win0)
                n=c.get(e['role'],c['R']) + 12*e.get('oct',0)
                d=min(BAR-(st-win0), e['len']*STEP)
                padsTt.note(1,n,e['vel'],t,d)

    # Lead1 with v2 phrase blocks and rest policy
    phrase_ids = [
        'lead1_phrase_01_statement_answer',
        'lead1_phrase_04_syncopated_space',
        'lead1_phrase_02_sequence_develop',
        'lead1_phrase_08_peak_and_resolve',
        'lead1_phrase_06_dorian_color',
        'lead1_phrase_07_sequence_then_break'
    ]

    # 8-bar sections using two 4-bar phrases, with explicit breath bars
    section_starts = [8, 16, 24]
    for si, sbar in enumerate(section_starts):
        p1 = leadP[phrase_ids[(si*2) % len(phrase_ids)]]
        p2 = leadP[phrase_ids[(si*2+1) % len(phrase_ids)]]
        for pi, phrase in enumerate((p1,p2)):
            base_bar = sbar + pi*4
            # skip out-of-range
            if base_bar >= TOTAL_BARS:
                continue
            # one breath bar per 4-bar phrase (bar 2 in phrase)
            breath_bar = base_bar + 2
            for b in range(base_bar, min(base_bar+4, TOTAL_BARS)):
                if b == breath_bar:
                    continue
                local_bar = b - base_bar
                bar0 = local_bar * BAR
                abs0 = b * BAR
                for idx,e in enumerate(phrase['events']):
                    st=e['step']*STEP
                    if bar0 <= st < bar0+BAR:
                        # anti-fragment: ignore ultra-short punctuation in opening section except pickups
                        if sbar == 8 and e['len'] <= 1 and (st-bar0) > 4*STEP:
                            continue
                        # variation: rhythmic displacement on answer bars
                        shift = STEP if (b % 4 == 1 and idx % 3 == 0) else 0
                        t = abs0 + (st-bar0) + shift
                        d = max(STEP, min(4*STEP, e['len']*STEP))
                        v = max(72, min(102, e['vel'] + (4 if b % 4 == 0 else 0)))
                        leadT.note(2, d2m(e['degree'], e['oct'], 64), v, t, d)

    # texture
    tplan=[(6,'texture_swell_01'),(11,'texture_glass_06'),(15,'texture_rise_04'),(19,'texture_ping_03'),(23,'texture_air_02'),(30,'texture_tail_05')]
    for b,tid in tplan:
        if b >= TOTAL_BARS: continue
        base=b*BAR
        for n in texE[tid]['notes']:
            texT.note(3,d2m(n['degree'],n.get('oct',0),64),n['vel'],base+n['step']*STEP,n['len']*STEP)

    tracks=[tempo,drums,bassT,padsTt,leadT,texT]
    header=b'MThd'+struct.pack('>IHHH',6,1,len(tracks),PPQ)
    OUT_MID.parent.mkdir(parents=True, exist_ok=True)
    OUT_MID.write_bytes(header + b''.join(t.bytes() for t in tracks))
    print(OUT_MID)

if __name__ == '__main__':
    main()

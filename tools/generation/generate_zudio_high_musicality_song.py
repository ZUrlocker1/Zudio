#!/usr/bin/env python3
import json
import struct
from pathlib import Path

ROOT = Path('/Users/urlocker/Downloads/Zudio')
START = ROOT / 'assets/midi/motorik/starters'
OUT = ROOT / 'renders/previews/zudio-preview-high-musicality-01.mid'

PPQ = 480
BPM = 132
BAR = PPQ * 4
STEP = BAR // 16
TOTAL_BARS = 40

DEG = {'1':0,'2':2,'b3':3,'3':4,'4':5,'5':7,'b6':8,'6':9,'b7':10,'7':11,'9':14,'R':0}


def vlq(n):
    b = [n & 0x7F]
    n >>= 7
    while n:
        b.append((n & 0x7F) | 0x80)
        n >>= 7
    return bytes(reversed(b))


class Track:
    def __init__(self):
        self.e = []

    def add(self, t, m):
        self.e.append((int(t), m))

    def name(self, s, t=0):
        b = s.encode('utf-8')
        self.add(t, b'\xFF\x03' + vlq(len(b)) + b)

    def prog(self, ch, p, t=0):
        self.add(t, bytes([0xC0 | ch, p & 0x7F]))

    def note(self, ch, n, v, s, d):
        n = max(0, min(127, int(n)))
        v = max(1, min(127, int(v)))
        s = int(s)
        d = max(1, int(d))
        self.add(s, bytes([0x90 | ch, n, v]))
        self.add(s + d, bytes([0x80 | ch, n, 0]))

    def bytes(self):
        out = b''
        cur = 0
        for t, m in sorted(self.e, key=lambda x: (x[0], x[1])):
            out += vlq(t - cur) + m
            cur = t
        out += b'\x00\xFF\x2F\x00'
        return b'MTrk' + struct.pack('>I', len(out)) + out


# Chord plan by bar
CHORDS = []
CHORDS += ['C'] * 4
CHORDS += ['C', 'Em', 'Fmaj7', 'C'] * 2
CHORDS += ['G', 'C', 'C', 'G'] * 2
CHORDS += ['Em', 'Fmaj7', 'G', 'D'] * 2
CHORDS += ['A', 'D', 'D', 'A'] * 2
CHORDS += ['C', 'Em', 'Fmaj7', 'C']
assert len(CHORDS) == TOTAL_BARS

CH = {
    'C': {'R':48,'3':52,'5':55,'7':59,'2':50,'9':62,'4':53,'6':57,'b3':51,'b7':58,'1':48},
    'Em': {'R':52,'3':55,'5':59,'7':62,'2':54,'9':66,'4':57,'6':61,'b3':55,'b7':62,'1':52},
    'Fmaj7': {'R':53,'3':57,'5':60,'7':64,'2':55,'9':67,'4':58,'6':62,'b3':56,'b7':63,'1':53},
    'G': {'R':55,'3':59,'5':62,'7':65,'2':57,'9':69,'4':60,'6':64,'b3':58,'b7':65,'1':55},
    'D': {'R':50,'3':54,'5':57,'7':61,'2':52,'9':64,'4':55,'6':59,'b3':53,'b7':60,'1':50},
    'A': {'R':57,'3':61,'5':64,'7':68,'2':59,'9':71,'4':62,'6':66,'b3':60,'b7':67,'1':57},
}


def chord_for_tick(t):
    bar = min(TOTAL_BARS - 1, max(0, t // BAR))
    return CH[CHORDS[bar]]


def note_from_degree(deg, octv, center, chord):
    semi = DEG.get(deg, 0)
    if deg in chord:
        base = chord[deg]
    elif deg in ('R', '1'):
        base = chord['R']
    else:
        base = chord['R'] + semi
    return base + 12 * octv + (center - chord['R'])


def load_json(name):
    return json.loads((START / name).read_text())


def place_abs_pattern(track, ch, events, base_tick, bars, src_bars, transpose=0, vel_mul=1.0, step_offset=0):
    max_steps = bars * 16
    src_max = src_bars * 16
    for ev in events:
        st = ev['step'] + step_offset
        if st >= src_max:
            continue
        if st >= max_steps:
            continue
        ln = max(1, min(ev['len'], max_steps - st))
        t = base_tick + st * STEP
        track.note(ch, ev['note'] + transpose, int(ev['vel'] * vel_mul), t, ln * STEP)


def place_deg_pattern(track, ch, events, base_tick, bars, src_bars, center, vel_mul=1.0, swing=0):
    max_steps = bars * 16
    src_max = src_bars * 16
    for ev in events:
        st = ev['step']
        if st >= src_max or st >= max_steps:
            continue
        ln = max(1, min(ev['len'], max_steps - st))
        t = base_tick + st * STEP
        if swing and (st % 2 == 1):
            t += int(STEP * swing)
        chord = chord_for_tick(t)
        n = note_from_degree(ev.get('degree', ev.get('role', 'R')), ev.get('oct', 0), center, chord)
        track.note(ch, n, int(ev['vel'] * vel_mul), t, ln * STEP)


def main():
    silly = load_json('silly-love-songs-derived-v1.json')['tracks']
    bh = load_json('bass-starters-hallogallo-v1.json')['patterns']
    rs = load_json('rhythm-starters-super16-v1.json')['patterns']
    pads = load_json('pads-starters-v1.json')['templates']
    l1 = load_json('lead1-solo-starters-v2.json')['phrases']
    l2 = load_json('lead2-starters-hallogallo-v1.json')['counter_motifs'][0]
    tex = load_json('texture-starters-v1.json')['events']

    silly_dr = {x['id']: x for x in silly['Drums']}
    silly_ba = {x['id']: x for x in silly['Bass']}
    silly_tx = {x['id']: x for x in silly['Texture']}
    bh = {x['id']: x for x in bh}
    rs = {x['id']: x for x in rs}
    pads = {x['id']: x for x in pads}
    l1 = {x['id']: x for x in l1}
    tex = {x['id']: x for x in tex}

    tempo = Track(); tempo.name('Tempo')
    tempo.add(0, b'\xFF\x51\x03' + struct.pack('>I', int(60_000_000 / BPM))[1:])
    tempo.add(0, b'\xFF\x58\x04\x04\x02\x18\x08')

    drums = Track(); drums.name('Drums')
    bass = Track(); bass.name('Bass')
    rhythm = Track(); rhythm.name('Rhythm')
    pads_t = Track(); pads_t.name('Pads')
    lead1 = Track(); lead1.name('Lead 1')
    lead2 = Track(); lead2.name('Lead 2')
    texture = Track(); texture.name('Texture')

    bass.prog(0, 38)     # Synth Bass 1
    rhythm.prog(1, 5)    # EP2
    pads_t.prog(2, 89)   # Warm Pad
    lead1.prog(3, 81)    # Saw lead
    lead2.prog(4, 63)    # Synth Brass 1
    texture.prog(5, 94)  # Halo pad

    # Drums (sample-derived arrangement)
    place_abs_pattern(drums, 9, silly_dr['drums_intro_sparse_8bar']['events'], 0 * BAR, 4, 8, vel_mul=0.88)
    place_abs_pattern(drums, 9, silly_dr['drums_preverse_groove_4bar']['events'], 4 * BAR, 4, 4, vel_mul=0.96)
    place_abs_pattern(drums, 9, silly_dr['drums_verse_drive_a_4bar']['events'], 8 * BAR, 4, 4, vel_mul=0.98)
    place_abs_pattern(drums, 9, silly_dr['drums_verse_drive_b_4bar']['events'], 12 * BAR, 4, 4, vel_mul=1.0)
    place_abs_pattern(drums, 9, silly_dr['drums_chorus_lift_a_4bar']['events'], 16 * BAR, 4, 4, vel_mul=1.02)
    place_abs_pattern(drums, 9, silly_dr['drums_chorus_lift_b_4bar']['events'], 20 * BAR, 4, 4, vel_mul=1.03)
    place_abs_pattern(drums, 9, silly_dr['drums_bridge_sparse_8bar']['events'], 24 * BAR, 8, 8, vel_mul=0.9)
    place_abs_pattern(drums, 9, silly_dr['drums_chorus_lift_b_4bar']['events'], 32 * BAR, 4, 4, vel_mul=1.05)
    place_abs_pattern(drums, 9, silly_dr['drums_verse_drive_a_4bar']['events'], 36 * BAR, 4, 4, vel_mul=0.98)
    # end fill
    base = 39 * BAR
    for i,n in enumerate((45,47,48,50,47,45,42,49)):
        drums.note(9, n, 90 + i * 3, base + (8 + i) * STEP // 2, STEP // 2)

    # Bass (sample-derived + hallogallo-derived)
    place_abs_pattern(bass, 0, silly_ba['bass_preverse_groove_4bar']['events'], 4 * BAR, 4, 4, transpose=12, vel_mul=0.98)
    place_abs_pattern(bass, 0, silly_ba['bass_verse_drive_a_4bar']['events'], 8 * BAR, 4, 4, transpose=12, vel_mul=1.0)
    place_abs_pattern(bass, 0, silly_ba['bass_verse_drive_b_4bar']['events'], 12 * BAR, 4, 4, transpose=12, vel_mul=1.0)
    # Hallogallo pulse center section
    for b in range(16, 24):
        pat = bh['bass_hallogallo_variation_02'] if b in (19, 23) else bh['bass_hallogallo_core_01']
        place_deg_pattern(bass, 0, pat['events'], b * BAR, 1, 1, center=57, vel_mul=1.0)
    # Bridge + outro from silly
    place_abs_pattern(bass, 0, silly_ba['bass_bridge_sparse_8bar']['events'], 24 * BAR, 8, 8, transpose=12, vel_mul=0.92)
    place_abs_pattern(bass, 0, silly_ba['bass_chorus_lift_a_4bar']['events'], 32 * BAR, 4, 4, transpose=12, vel_mul=1.03)
    place_abs_pattern(bass, 0, silly_ba['bass_chorus_lift_b_4bar']['events'], 36 * BAR, 4, 4, transpose=12, vel_mul=1.01)

    # Rhythm (Super16 chug mapped to chord flow)
    # intro sparse from super16 break
    for b in range(0, 4):
        place_deg_pattern(rhythm, 1, rs['rhythm_super16_break_nc_03']['events'], b * BAR, 1, 1, center=64)
    # body
    for b in range(4, TOTAL_BARS):
        pat = rs['rhythm_super16_chug_fill_02'] if (b % 4 == 3) else rs['rhythm_super16_chug_plain_01']
        vel = 0.84 if b < 8 else (0.92 if b < 24 else 0.86)
        if 24 <= b < 32 and b % 2 == 1:
            # Bridge breath bars
            continue
        place_deg_pattern(rhythm, 1, pat['events'], b * BAR, 1, 1, center=64, vel_mul=vel, swing=0.05)

    # Pads (harmonic glue)
    pad_plan = [
        (0,4,'pad_octave_shell_05',0.78),
        (4,12,'pad_hold_triad_01',0.95),
        (12,20,'pad_halfbar_revoice_02',0.92),
        (20,24,'pad_add9_sparse_03',0.94),
        (24,32,'pad_octave_shell_05',0.80),
        (32,36,'pad_halfbar_revoice_02',0.95),
        (36,40,'pad_add9_sparse_03',0.90),
    ]
    for s,e,pid,v in pad_plan:
        tpl = pads[pid]
        for b in range(s,e):
            place_deg_pattern(pads_t, 2, tpl['events'], b * BAR, 1, tpl['bars'], center=57, vel_mul=v)

    # Lead 1 high-musicality arc (v2 phrases + breath)
    phrases = [
        'lead1_phrase_01_statement_answer',
        'lead1_phrase_04_syncopated_space',
        'lead1_phrase_02_sequence_develop',
        'lead1_phrase_08_peak_and_resolve',
        'lead1_phrase_06_dorian_color',
        'lead1_phrase_07_sequence_then_break',
    ]
    starts = [8, 16, 24, 32]
    for si, sb in enumerate(starts):
        p = l1[phrases[(si*2) % len(phrases)]]
        q = l1[phrases[(si*2+1) % len(phrases)]]
        for pi, ph in enumerate((p, q)):
            b0 = sb + pi * 4
            breath = b0 + 2
            for b in range(b0, min(TOTAL_BARS, b0 + 4)):
                if b == breath:
                    continue
                bar0 = (b - b0) * BAR
                abs0 = b * BAR
                for idx, ev in enumerate(ph['events']):
                    st = ev['step'] * STEP
                    if not (bar0 <= st < bar0 + BAR):
                        continue
                    if b < 12 and ev['len'] <= 1 and st > 6 * STEP:
                        continue
                    shift = STEP if (b % 4 == 1 and idx % 3 == 0) else 0
                    t = abs0 + (st - bar0) + shift
                    d = max(STEP, min(4 * STEP, ev['len'] * STEP))
                    vv = ev['vel'] + (5 if b % 4 == 0 else 0)
                    place_deg_pattern(lead1, 3, [{'step':0,'len':d//STEP,'degree':ev['degree'],'oct':ev.get('oct',0),'vel':vv}], t, 1, 1, center=66, vel_mul=1.0)

    # Lead 2 (Hallogallo motif response after bar 16)
    for b in range(16, TOTAL_BARS, 2):
        if b in (24, 26, 28):
            continue
        place_deg_pattern(lead2, 4, l2['events'], b * BAR, 1, 1, center=62, vel_mul=0.78)

    # Texture (sample-derived intro and controlled transitions)
    place_abs_pattern(texture, 5, silly_tx['texture_intro_sparse_8bar']['events'], 0 * BAR, 4, 8, vel_mul=0.85)
    tplan = [(15,'texture_swell_01'), (23,'texture_glass_06'), (31,'texture_air_02'), (38,'texture_tail_05')]
    for b, tid in tplan:
        e = tex[tid]
        for n in e['notes']:
            texture.note(5, note_from_degree(n['degree'], n.get('oct',0), 64, chord_for_tick(b*BAR)), n['vel'], b*BAR + n['step']*STEP, n['len']*STEP)

    tracks = [tempo, drums, bass, rhythm, pads_t, lead1, lead2, texture]
    head = b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), PPQ)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(head + b''.join(t.bytes() for t in tracks))
    print(OUT)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
import json
import struct
from pathlib import Path

ROOT = Path('/Users/urlocker/Downloads/Zudio')
START = ROOT / 'assets/midi/motorik/starters'
OUT = ROOT / 'renders/previews/zudio-preview-high-musicality-03-strict-tonal.mid'

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
        self.notes = []

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
        self.notes.append({"ch": ch, "note": n, "start": s, "dur": d})
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

def chord_name_for_tick(t):
    bar = min(TOTAL_BARS - 1, max(0, t // BAR))
    return CHORDS[bar]

def is_strong_beat(tick):
    step = int((tick % BAR) // STEP)
    return step in (0, 8)

def scale_pcs_for_chord_name(chname):
    root = CH[chname]['R'] % 12
    if 'm' in chname and 'maj' not in chname:
        # natural minor family
        ints = (0, 2, 3, 5, 7, 8, 10)
    else:
        # major/maj7 family
        ints = (0, 2, 4, 5, 7, 9, 11)
    return {(root + i) % 12 for i in ints}

def chord_pcs_for_tick(tick):
    ch = chord_for_tick(tick)
    pcs = {ch['R'] % 12, ch['3'] % 12, ch['5'] % 12}
    if '7' in ch:
        pcs.add(ch['7'] % 12)
    return pcs

def tonal_pool(track_role, tick):
    strong = is_strong_beat(tick)
    chord_pcs = chord_pcs_for_tick(tick)
    scale_pcs = scale_pcs_for_chord_name(chord_name_for_tick(tick))

    if track_role in ('Bass', 'Pads', 'Rhythm'):
        return chord_pcs if strong else (chord_pcs | scale_pcs)
    if track_role == 'Lead2':
        return chord_pcs if strong else (chord_pcs | scale_pcs)
    if track_role == 'Lead1':
        return chord_pcs | scale_pcs
    return set(range(12))

def remap_to_pool(note, allowed_pcs, preferred_pcs=None, max_shift=6):
    if (note % 12) in allowed_pcs:
        return note
    candidates = []
    for d in range(-max_shift, max_shift + 1):
        cand = note + d
        if (cand % 12) in allowed_pcs:
            pref = 0 if (preferred_pcs and (cand % 12) in preferred_pcs) else 1
            candidates.append((abs(d), pref, cand))
    if not candidates:
        return note
    candidates.sort(key=lambda x: (x[0], x[1], x[2]))
    return candidates[0][2]

def remap_note(track_role, note, tick):
    allowed = tonal_pool(track_role, tick)
    preferred = chord_pcs_for_tick(tick)
    return remap_to_pool(note, allowed, preferred_pcs=preferred, max_shift=6)

def bass_note_at_tick(bass_track, tick):
    # nearest active bass note at this tick
    active = [n for n in bass_track.notes if n['start'] <= tick < (n['start'] + n['dur'])]
    if not active:
        return None
    # choose lowest active bass note
    active.sort(key=lambda n: n['note'])
    return active[0]['note']

def repair_lead2_against_bass(lead_note, tick, bass_track):
    if not is_strong_beat(tick):
        return lead_note
    bn = bass_note_at_tick(bass_track, tick)
    if bn is None:
        return lead_note
    interval = (lead_note - bn) % 12
    dissonant = {1, 2, 6, 10, 11}
    if interval not in dissonant:
        return lead_note
    target_intervals = {0, 3, 4, 7, 8, 9}
    allowed = tonal_pool('Lead2', tick)
    for d in range(0, 7):
        for sgn in (-1, 1):
            cand = lead_note + sgn * d
            if (cand % 12) in allowed and ((cand - bn) % 12) in target_intervals:
                return cand
    # no clean resolution close-by: suppress this event
    return None


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


def place_abs_pattern(track, ch, events, base_tick, bars, src_bars, transpose=0, vel_mul=1.0, step_offset=0, role=None):
    max_steps = bars * 16
    src_max = src_bars * 16
    for ev in events:
        st = ev['step'] + step_offset
        if st >= src_max or st >= max_steps:
            continue
        ln = max(1, min(ev['len'], max_steps - st))
        t = base_tick + st * STEP
        note = ev['note'] + transpose
        if role:
            note = remap_note(role, note, t)
        track.note(ch, note, int(ev['vel'] * vel_mul), t, ln * STEP)


def place_deg_pattern(track, ch, events, base_tick, bars, src_bars, center, vel_mul=1.0, swing=0.0, role=None, post_map=None):
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
        if role:
            n = remap_note(role, n, t)
        if post_map:
            n = post_map(n, t)
            if n is None:
                continue
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

    bass.prog(0, 38)
    rhythm.prog(1, 5)
    pads_t.prog(2, 89)
    lead1.prog(3, 81)
    lead2.prog(4, 63)
    texture.prog(5, 94)

    # Drums
    place_abs_pattern(drums, 9, silly_dr['drums_intro_sparse_8bar']['events'], 0 * BAR, 4, 8, vel_mul=0.88)
    place_abs_pattern(drums, 9, silly_dr['drums_preverse_groove_4bar']['events'], 4 * BAR, 4, 4, vel_mul=0.96)
    place_abs_pattern(drums, 9, silly_dr['drums_verse_drive_a_4bar']['events'], 8 * BAR, 4, 4, vel_mul=0.98)
    place_abs_pattern(drums, 9, silly_dr['drums_verse_drive_b_4bar']['events'], 12 * BAR, 4, 4, vel_mul=1.0)
    place_abs_pattern(drums, 9, silly_dr['drums_chorus_lift_a_4bar']['events'], 16 * BAR, 4, 4, vel_mul=1.02)
    place_abs_pattern(drums, 9, silly_dr['drums_chorus_lift_b_4bar']['events'], 20 * BAR, 4, 4, vel_mul=1.03)
    place_abs_pattern(drums, 9, silly_dr['drums_bridge_sparse_8bar']['events'], 24 * BAR, 8, 8, vel_mul=0.9)
    place_abs_pattern(drums, 9, silly_dr['drums_chorus_lift_b_4bar']['events'], 32 * BAR, 4, 4, vel_mul=1.05)
    place_abs_pattern(drums, 9, silly_dr['drums_verse_drive_a_4bar']['events'], 36 * BAR, 4, 4, vel_mul=0.98)

    # Bass
    place_abs_pattern(bass, 0, silly_ba['bass_preverse_groove_4bar']['events'], 4 * BAR, 4, 4, transpose=12, vel_mul=0.98, role='Bass')
    place_abs_pattern(bass, 0, silly_ba['bass_verse_drive_a_4bar']['events'], 8 * BAR, 4, 4, transpose=12, vel_mul=1.0, role='Bass')
    place_abs_pattern(bass, 0, silly_ba['bass_verse_drive_b_4bar']['events'], 12 * BAR, 4, 4, transpose=12, vel_mul=1.0, role='Bass')
    for b in range(16, 24):
        pat = bh['bass_hallogallo_variation_02'] if b in (19, 23) else bh['bass_hallogallo_core_01']
        place_deg_pattern(bass, 0, pat['events'], b * BAR, 1, 1, center=57, vel_mul=1.0, role='Bass')
    place_abs_pattern(bass, 0, silly_ba['bass_bridge_sparse_8bar']['events'], 24 * BAR, 8, 8, transpose=12, vel_mul=0.92, role='Bass')
    place_abs_pattern(bass, 0, silly_ba['bass_chorus_lift_a_4bar']['events'], 32 * BAR, 4, 4, transpose=12, vel_mul=1.03, role='Bass')
    place_abs_pattern(bass, 0, silly_ba['bass_chorus_lift_b_4bar']['events'], 36 * BAR, 4, 4, transpose=12, vel_mul=1.01, role='Bass')

    # Rhythm: sparse varied behavior (not nonstop)
    for b in range(TOTAL_BARS):
        # silent intro first 2 bars
        if b < 2:
            continue
        # bridge sparsity
        if 24 <= b < 32 and b % 2 == 1:
            continue
        # every 4th bar mostly rest except short fill at 8.5-style placement
        if b % 4 == 0:
            if b == 8:
                pat = rs['rhythm_super16_chug_fill_02']
                place_deg_pattern(rhythm, 1, pat['events'], b * BAR + 8 * STEP, 1, 1, center=64, vel_mul=0.72, role='Rhythm')
            continue

        # choose density by section
        if b < 12:
            pat = rs['rhythm_super16_chug_plain_01']
            keep = {0, 2, 8, 10, 14}  # sparse 8th accents
            vel = 0.70
        elif b < 24:
            pat = rs['rhythm_super16_chug_fill_02'] if b % 3 == 0 else rs['rhythm_super16_chug_plain_01']
            keep = {0, 4, 8, 12, 14}
            vel = 0.76
        else:
            pat = rs['rhythm_super16_chug_plain_01']
            keep = {0, 6, 8, 14}
            vel = 0.68

        events = [e for e in pat['events'] if e['step'] in keep]
        place_deg_pattern(rhythm, 1, events, b * BAR, 1, 1, center=64, vel_mul=vel, swing=0.04, role='Rhythm')

    # Pads: force rhythmic variation every 2-4 bars, cap long whole-note spans
    pad_modes = [
        ('pad_octave_shell_05', 2, 0.78),
        ('pad_halfbar_revoice_02', 2, 0.88),
        ('pad_hold_triad_01', 2, 0.86),
        ('pad_sus2_04', 2, 0.84),
        ('pad_add9_sparse_03', 2, 0.86),
    ]
    cursor = 0
    mode_ix = 0
    while cursor < TOTAL_BARS:
        pid, length, vm = pad_modes[mode_ix % len(pad_modes)]
        tpl = pads[pid]
        for b in range(cursor, min(TOTAL_BARS, cursor + length)):
            # allow occasional silence to breathe
            if b in (2, 14, 26, 34):
                continue
            place_deg_pattern(pads_t, 2, tpl['events'], b * BAR, 1, tpl['bars'], center=57, vel_mul=vm, role='Pads')
        cursor += length
        mode_ix += 1

    # Lead 1: fewer notes, stronger journey
    phrases = [
        'lead1_phrase_01_statement_answer',
        'lead1_phrase_04_syncopated_space',
        'lead1_phrase_02_sequence_develop',
        'lead1_phrase_08_peak_and_resolve',
        'lead1_phrase_06_dorian_color',
    ]
    starts = [10, 18, 30]
    for si, sb in enumerate(starts):
        ph = l1[phrases[si % len(phrases)]]
        # 6-bar window: 2 bars statement, 2 bars development, 2 bars resolve with more rest
        for b in range(sb, min(TOTAL_BARS, sb + 6)):
            if b in (sb + 2, sb + 5):
                continue  # breath bars
            bar0 = (b - sb) * BAR
            abs0 = b * BAR
            for idx, ev in enumerate(ph['events']):
                st = ev['step'] * STEP
                if not (bar0 <= st < bar0 + BAR):
                    continue
                local_step = (st - bar0) // STEP
                # density thinning
                if b < sb + 3:
                    if local_step not in (0, 3, 6, 10, 14):
                        continue
                elif b < sb + 5:
                    if local_step not in (1, 4, 8, 11, 14):
                        continue
                else:
                    if local_step not in (0, 6, 12):
                        continue
                t = abs0 + (st - bar0)
                d = max(STEP, min(3 * STEP, ev['len'] * STEP))
                vv = ev['vel'] + (4 if b == sb + 3 else 0)
                place_deg_pattern(lead1, 3, [{'step':0,'len':d//STEP,'degree':ev['degree'],'oct':ev.get('oct',0),'vel':vv}], t, 1, 1, center=66, vel_mul=0.96, role='Lead1')

    # Lead 2: keep strong
    for b in range(16, TOTAL_BARS, 2):
        if b in (24, 26, 28):
            continue
        place_deg_pattern(
            lead2,
            4,
            l2['events'],
            b * BAR,
            1,
            1,
            center=62,
            vel_mul=0.78,
            role='Lead2',
            post_map=lambda n, t: repair_lead2_against_bass(n, t, bass),
        )

    # Texture: reuse the good texture more often but not constant
    place_abs_pattern(texture, 5, silly_tx['texture_intro_sparse_8bar']['events'], 0 * BAR, 4, 8, vel_mul=0.88)
    tplan = [
        (7,'texture_swell_01'),
        (11,'texture_glass_06'),
        (15,'texture_rise_04'),
        (19,'texture_ping_03'),
        (23,'texture_air_02'),
        (27,'texture_glass_06'),
        (31,'texture_swell_01'),
        (35,'texture_ping_03'),
        (38,'texture_tail_05'),
    ]
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

#!/usr/bin/env python3
"""
chill_blues_analyze.py — Chill Blues-specific quality analyzer for Zudio.

Usage:
    python3 tools/chill_blues_analyze.py [directory]

Reads all .MID/.zudio pairs in the given directory, applies checks specific
to the 16-bar I–IV–I–V/I blues form, and prints a ranked report.

Form positions within each 16-bar cycle:
    I   chord: bars 0–7   (posInForm 0–7)
    IV  chord: bars 8–11  (posInForm 8–11)
    I   chord: bars 12–13 (posInForm 12–13)
    V/I chord: bars 14–15 (posInForm 14–15, turnaround)

Flags:
    !! CRITICAL  — structural correctness violation
    !!           — metric outside acceptable range
    ok           — within target
"""

import struct, os, sys, re, math
from collections import defaultdict

# ── Constants ─────────────────────────────────────────────────────────────────

TPQ             = 480
TICKS_PER_STEP  = 120
TICKS_PER_BAR   = 1920
BLUES_FORM_LEN  = 16   # bars per complete blues cycle

NOTE_NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']

KEY_ST = {'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,
          'F#':6,'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}

SCALE_INTERVALS = {
    'Ionian':     [0,2,4,5,7,9,11],
    'Dorian':     [0,2,3,5,7,9,10],
    'Mixolydian': [0,2,4,5,7,9,10],
    'Aeolian':    [0,2,3,5,7,8,10],
}

# Blues scale = minor pentatonic + b5 passing tone
BLUES_SCALE_INTERVALS = [0, 3, 5, 6, 7, 10]

# For Dorian (Chill Blues default): avoid tones per chord zone
# (pitch class offsets from key root)
AVOID_BY_ZONE = {
    'I':   [],         # I chord: no avoidance in Dorian
    'IV':  [2, 9],     # IVm7 in D Dorian (G): avoid B, F# (maj 6th/maj 7th of IV)
    'V':   [3, 8],     # V7 in D Dorian (A7): avoid Bb, Eb
}

# Blues density targets (notes/bar)
DENSITY_TARGETS = {
    'Lead 1': {'groove': (0.8, 3.5)},
    'Lead 2': {'groove': (0.3, 2.5)},
    'Bass':   {'groove': (1.5, 5.0)},
}

# ── MIDI parser ───────────────────────────────────────────────────────────────

def read_vlq(data, pos):
    val = 0
    while True:
        b = data[pos]; pos += 1
        val = (val << 7) | (b & 0x7F)
        if not (b & 0x80): break
    return val, pos

def parse_midi(path):
    with open(path, 'rb') as f:
        data = f.read()
    assert data[0:4] == b'MThd', "not a MIDI file"
    _, _, ntracks, tpq = struct.unpack('>IHHH', data[4:14])
    pos = 14
    tracks = []
    for _ in range(ntracks):
        assert data[pos:pos+4] == b'MTrk', f"bad MTrk at {pos}"
        tlen = struct.unpack('>I', data[pos+4:pos+8])[0]
        tend = pos + 8 + tlen
        tpos = pos + 8
        tick = 0; name = f"Track{len(tracks)}"; notes = []; active = {}; running = 0
        while tpos < tend:
            dt, tpos = read_vlq(data, tpos)
            tick += dt
            if tpos >= tend: break
            b = data[tpos]
            if b & 0x80:
                running = b; tpos += 1
            cmd = running & 0xF0
            if running == 0xFF:
                mt = data[tpos]; tpos += 1
                ml, tpos = read_vlq(data, tpos)
                if mt == 0x03:
                    name = data[tpos:tpos+ml].decode('latin1', 'replace')
                tpos += ml
            elif running in (0xF0, 0xF7):
                ml, tpos = read_vlq(data, tpos)
                tpos += ml
            elif cmd in (0x90, 0x80):
                note = data[tpos]; vel = data[tpos+1]; tpos += 2
                if cmd == 0x90 and vel > 0:
                    active[(running & 0x0F, note)] = (tick, vel)
                else:
                    key = (running & 0x0F, note)
                    if key in active:
                        st, sv = active.pop(key)
                        notes.append((st, note, sv, tick - st))
            elif cmd in (0xA0, 0xB0, 0xE0): tpos += 2
            elif cmd in (0xC0, 0xD0):       tpos += 1
        for (ch, note2), (st, sv) in active.items():
            notes.append((st, note2, sv, max(tpq, tick - st)))
        tracks.append({'name': name, 'notes': notes})
        pos = tend
    return tracks, tpq

# ── .zudio log parser ─────────────────────────────────────────────────────────

def parse_zudio(path):
    info = {
        'key': None, 'mode': None, 'tempo': None, 'bars': None, 'mood': None,
        'sections': [], 'chords': [], 'rules': {},
        'beat_style': None, 'lead_inst': None,
    }
    if not os.path.exists(path): return info
    with open(path) as f:
        lines = f.readlines()

    in_struct = in_chords = in_log = False
    for line in lines:
        s = line.strip()
        if s.startswith('Key:'):
            parts = s.split(None, 2)
            if len(parts) >= 3: info['key'] = parts[1]; info['mode'] = parts[2]
        elif s.startswith('Tempo:'):
            m = re.search(r'(\d+)', s)
            if m: info['tempo'] = int(m.group(1))
        elif s.startswith('Bars:'):
            m = re.search(r'(\d+)', s)
            if m: info['bars'] = int(m.group(1))
        elif s.startswith('Mood:'):
            info['mood'] = s.split(None, 1)[1].strip()
        elif '--- Structure ---' in s:  in_struct = True;  in_chords = in_log = False; continue
        elif '--- Chord Plan ---' in s: in_chords = True;  in_struct = in_log = False; continue
        elif '--- Generation Log ---' in s: in_log = True; in_struct = in_chords = False; continue
        elif s.startswith('---'): in_struct = in_chords = in_log = False; continue

        if in_struct:
            m = re.match(r'(\w+)\s+Bars\s+(\d+)[–-]\s*(\d+)', s)
            if m:
                name  = m.group(1).lower()
                start = int(m.group(2)) - 1
                end   = int(m.group(3))
                info['sections'].append({'name': name, 'start': start, 'end': end})

        elif in_chords:
            m = re.match(r'Bars\s+(\d+)[–-]\s*(\d+)\s+root=(\S+)\s+type=(\S+)', s)
            if m:
                info['chords'].append({
                    'start': int(m.group(1)) - 1,
                    'end':   int(m.group(2)),
                    'root':  m.group(3),
                    'ctype': m.group(4),
                })

        elif in_log:
            m = re.match(r'(CHL-\S+)\s+(.*)', s)
            if m: info['rules'][m.group(1)] = m.group(2).strip()
            # Beat style and lead instrument logged as non-rule entries
            mb = re.match(r'ChillBeatStyle\s+(.*)', s)
            if mb: info['beat_style'] = mb.group(1).strip()
            ml = re.match(r'ChillLeadInstrument\s+(.*)', s)
            if ml: info['lead_inst'] = ml.group(1).strip()

    return info

# ── Helpers ───────────────────────────────────────────────────────────────────

def tick_to_bar(tick):
    return tick // TICKS_PER_BAR

def tick_to_step(tick):
    return tick // TICKS_PER_STEP

def step_in_bar(tick):
    return (tick // TICKS_PER_STEP) % 16

def notes_in_section(notes, section):
    s_tick = section['start'] * TICKS_PER_BAR
    e_tick = section['end']   * TICKS_PER_BAR
    return [n for n in notes if s_tick <= n[0] < e_tick]

def section_by_name(sections, name):
    for s in sections:
        if s['name'] == name:
            return s
    return None

def section_bars(section):
    return max(1, section['end'] - section['start'])

def pos_in_form(bar, section_start):
    return (bar - section_start) % BLUES_FORM_LEN

def zone_for_pos(pos):
    if pos < 8:  return 'I'
    if pos < 12: return 'IV'
    return 'V'

DEGREE_ST = {'1':0,'2':2,'b3':3,'3':4,'4':5,'5':7,'b6':8,'6':9,'b7':10,'7':11}

def degree_to_pc(degree, key_st, mode):
    if degree in DEGREE_ST:
        return (key_st + DEGREE_ST[degree]) % 12
    try:
        d = int(degree) - 1
    except (ValueError, TypeError):
        return key_st % 12
    intervals = SCALE_INTERVALS.get(mode, [0,2,4,5,7,9,11])
    if 0 <= d < len(intervals):
        return (key_st + intervals[d]) % 12
    return key_st % 12

def chord_at_bar(chords, bar):
    for c in chords:
        if c['start'] <= bar < c['end']:
            return c
    return None

def chord_tones(chord, key_st, mode):
    root_pc = degree_to_pc(chord['root'], key_st, mode)
    ctype = chord.get('ctype', '')
    if ctype in ('major', 'dom7'):
        return {root_pc % 12, (root_pc+4) % 12, (root_pc+7) % 12}
    return {root_pc % 12, (root_pc+3) % 12, (root_pc+7) % 12}

# ── Per-song analysis ─────────────────────────────────────────────────────────

def analyze_song(midi_path, zudio_path):
    info = parse_zudio(zudio_path)
    tracks_raw, tpq = parse_midi(midi_path)

    key_st  = KEY_ST.get(info['key'] or '', 0)
    mode    = info['mode'] or 'Dorian'
    sections = info['sections']
    chords   = info['chords']
    rules    = info['rules']

    scale_pc = set((key_st + i) % 12 for i in SCALE_INTERVALS.get(mode, SCALE_INTERVALS['Dorian']))
    blues_pc = set((key_st + i) % 12 for i in BLUES_SCALE_INTERVALS)

    track_notes = {}
    for t in tracks_raw:
        nm = t['name']
        if nm in ('Lead 1', 'Lead 2', 'Bass', 'Pads', 'Rhythm', 'Drums'):
            track_notes[nm] = t['notes']

    sec_a  = section_by_name(sections, 'a')
    sec_b  = section_by_name(sections, 'b')
    groove_sections = [s for s in sections if s['name'] in ('a', 'b')]
    groove_bars_set = set()
    for s in groove_sections:
        groove_bars_set.update(range(s['start'], s['end']))

    flags = []
    stats = {}

    # ── 1. Blues chord root coverage (IV and V zones) ────────────────────────
    # Bass first-note of each bar should match chord root.
    # CHL-BASS-011 (ascending riff) starts bars on a pickup/approach note by design — skip.
    has_ascending_riff = 'CHL-BASS-011' in rules
    bass_notes = track_notes.get('Bass', [])
    if bass_notes and chords and not has_ascending_riff:
        bar_first = {}
        for tick, pitch, vel, dur in bass_notes:
            bar = tick_to_bar(tick)
            if bar in groove_bars_set and bar not in bar_first:
                bar_first[bar] = pitch % 12

        iv_correct = iv_total = 0
        v_correct  = v_total  = 0
        i_correct  = i_total  = 0

        for bar, pc in bar_first.items():
            sec = next((s for s in groove_sections if s['start'] <= bar < s['end']), None)
            if not sec: continue
            pos = pos_in_form(bar, sec['start'])
            zone = zone_for_pos(pos)
            chord = chord_at_bar(chords, bar)
            if not chord: continue
            root_pc = degree_to_pc(chord['root'], key_st, mode)
            correct = (pc == root_pc % 12)
            if zone == 'I':
                i_total += 1; i_correct += int(correct)
            elif zone == 'IV':
                iv_total += 1; iv_correct += int(correct)
            else:
                v_total += 1; v_correct += int(correct)

        if i_total > 0:
            i_cov = 100 * i_correct / i_total
            stats['bass_root_I'] = i_cov
            if i_cov < 60:
                flags.append(f'!! BASS-ROOT-I: {i_cov:.0f}% bar-1 root coverage on I chord (target ≥60%)')

        if iv_total > 0:
            iv_cov = 100 * iv_correct / iv_total
            stats['bass_root_IV'] = iv_cov
            if iv_cov < 55:
                flags.append(f'!! BASS-ROOT-IV: {iv_cov:.0f}% bar-1 root coverage on IV chord (target ≥55%)')

        if v_total > 0:
            v_cov = 100 * v_correct / v_total
            stats['bass_root_V'] = v_cov
            if v_cov < 40:
                flags.append(f'!! BASS-ROOT-V: {v_cov:.0f}% bar-1 root coverage on V/turnaround chord (target ≥40%)')

    # ── 2. Lead clash by blues form zone ────────────────────────────────────
    # Notes played on strong beats (steps 0,4,8,12) should avoid the chord's avoid tones
    for track_name in ('Lead 1', 'Lead 2'):
        lead_notes = track_notes.get(track_name, [])
        if not lead_notes or not chords: continue

        zone_clashes = {'I': (0,0), 'IV': (0,0), 'V': (0,0)}
        for tick, pitch, vel, dur in lead_notes:
            bar = tick_to_bar(tick)
            sec = next((s for s in groove_sections if s['start'] <= bar < s['end']), None)
            if not sec: continue
            # Only check strong beats (steps 0, 4, 8, 12 within bar)
            sib = step_in_bar(tick)
            if sib not in (0, 4, 8, 12): continue

            pos   = pos_in_form(bar, sec['start'])
            zone  = zone_for_pos(pos)
            chord = chord_at_bar(chords, bar)
            if not chord: continue

            # Avoid tones: pitch classes that clash strongly against this chord.
            # For dom7 (V7): avoid the b3 and b6 (minor colour against dominant).
            # For min7 (I, IV): avoid the major 3rd (natural 3rd clashes with minor chord).
            # The major 6th (Dorian characteristic note) is NOT an avoid tone over Im7.
            root_pc = degree_to_pc(chord['root'], key_st, mode)
            ctype   = chord.get('ctype', '')
            if ctype in ('major', 'dom7'):
                # Avoid b3 (minor 3rd) against a dominant/major chord
                avoid = {(root_pc + 3) % 12}
            else:
                # Avoid the major 3rd of a minor chord (e.g. B over Gm7 clashes with Bb)
                avoid = {(root_pc + 4) % 12}

            clash_count, total_count = zone_clashes[zone]
            total_count += 1
            if pitch % 12 in avoid:
                clash_count += 1
            zone_clashes[zone] = (clash_count, total_count)

        for zone, (clashes, total) in zone_clashes.items():
            if total < 3: continue
            pct = 100 * clashes / total
            stats[f'{track_name}_clash_{zone}'] = pct
            threshold = 20 if zone == 'I' else 25
            if pct > threshold:
                flags.append(f'!! CLASH-{zone} {track_name}: {pct:.0f}% strong-beat avoid-tones over {zone} chord (target ≤{threshold}%)')

    # ── 3. Lead activity by zone — turnaround silence ────────────────────────
    for track_name in ('Lead 1', 'Lead 2'):
        lead_notes = track_notes.get(track_name, [])
        if not lead_notes: continue

        zone_bars = {'I': set(), 'IV': set(), 'V': set()}
        zone_active = {'I': set(), 'IV': set(), 'V': set()}

        for s in groove_sections:
            for bar in range(s['start'], s['end']):
                pos  = pos_in_form(bar, s['start'])
                zone = zone_for_pos(pos)
                zone_bars[zone].add(bar)

        for tick, pitch, vel, dur in lead_notes:
            bar = tick_to_bar(tick)
            sec = next((s for s in groove_sections if s['start'] <= bar < s['end']), None)
            if not sec: continue
            pos  = pos_in_form(bar, sec['start'])
            zone = zone_for_pos(pos)
            zone_active[zone].add(bar)

        for zone, bars in zone_bars.items():
            if not bars: continue
            activity = 100 * len(zone_active[zone]) / len(bars)
            stats[f'{track_name}_activity_{zone}'] = activity
            # Lead should REST at least some of the V/turnaround zone
            if zone == 'V' and activity > 85:
                flags.append(f'!! LEAD-NO-TURNAROUND-REST {track_name}: {activity:.0f}% of V/turnaround bars active (target ≤85% — allow some rest)')

    # ── 4. Phrase seam crossing ──────────────────────────────────────────────
    # A phrase that starts in the I zone and runs into the IV zone (bar 8) is a seam cross
    for track_name in ('Lead 1', 'Lead 2'):
        lead_notes = track_notes.get(track_name, [])
        if not lead_notes: continue

        seam_crosses = 0
        total_phrases = 0
        phrase_notes = split_into_phrases(sorted(lead_notes, key=lambda n: n[0]))
        for phrase in phrase_notes:
            if len(phrase) < 2: continue
            first_bar = tick_to_bar(phrase[0][0])
            last_bar  = tick_to_bar(phrase[-1][0])
            sec = next((s for s in groove_sections if s['start'] <= first_bar < s['end']), None)
            if not sec: continue
            first_pos = pos_in_form(first_bar, sec['start'])
            last_pos  = pos_in_form(last_bar,  sec['start'])
            total_phrases += 1
            # Crosses a seam if it starts before 8 and ends at 8+, or starts before 12 and ends at 12+
            seams = [8, 12]
            for seam in seams:
                if first_pos < seam and last_pos >= seam:
                    seam_crosses += 1
                    break

        if total_phrases > 0:
            cross_pct = 100 * seam_crosses / total_phrases
            stats[f'{track_name}_seam_cross_pct'] = cross_pct
            if cross_pct > 20:
                flags.append(f'!! SEAM-CROSS {track_name}: {cross_pct:.0f}% of phrases cross a blues chord seam (target ≤20%)')

    # ── 5. Blues scale conformance (lead notes vs blues scale) ──────────────
    for track_name in ('Lead 1', 'Lead 2'):
        lead_notes = track_notes.get(track_name, [])
        if not lead_notes: continue
        groove_lead = [n for n in lead_notes if tick_to_bar(n[0]) in groove_bars_set]
        if not groove_lead: continue
        oos = sum(1 for _, p, _, _ in groove_lead if p % 12 not in blues_pc and p % 12 not in scale_pc)
        pct = 100 * oos / len(groove_lead)
        stats[f'{track_name}_blues_conformance'] = 100 - pct
        if pct > 15:
            flags.append(f'!! BLUES-OOS {track_name}: {pct:.0f}% notes outside blues+scale pool (target ≤15%)')

    # ── 6. Phrase repetition across cycles (monotony) ───────────────────────
    # Compare Lead 1 note patterns across successive 16-bar forms
    l1_notes = track_notes.get('Lead 1', [])
    if l1_notes and sec_a and sec_b:
        # Get all groove bars sorted by position-in-form
        form_patterns = defaultdict(list)  # pos_in_form → list of pitch classes per cycle
        cycle_index = 0
        last_cycle_start = -1
        for s in groove_sections:
            for bar_offset in range(section_bars(s)):
                bar = s['start'] + bar_offset
                pos = (bar - s['start']) % BLUES_FORM_LEN
                if pos == 0:
                    cycle_index += 1
                bar_notes = [n for n in l1_notes
                             if tick_to_bar(n[0]) == bar]
                pcs = frozenset(n[1] % 12 for n in bar_notes)
                form_patterns[pos].append((cycle_index, pcs))

        # Count how often every cycle uses the exact same pitch set at pos 0–7 (I zone)
        i_zone_repeats = 0
        i_zone_total   = 0
        for pos in range(8):
            cycles = form_patterns.get(pos, [])
            if len(cycles) < 2: continue
            # Count pairs that use identical non-empty pitch sets
            for i in range(len(cycles)):
                for j in range(i+1, len(cycles)):
                    pcs_i = cycles[i][1]
                    pcs_j = cycles[j][1]
                    if pcs_i and pcs_j:
                        i_zone_total += 1
                        if pcs_i == pcs_j:
                            i_zone_repeats += 1

        if i_zone_total > 0:
            rep_pct = 100 * i_zone_repeats / i_zone_total
            stats['lead1_cycle_repeat_pct'] = rep_pct
            if rep_pct > 60:
                flags.append(f'!! CYCLE-REPEAT Lead 1: {rep_pct:.0f}% of I-zone bar pairs repeat identical pitch sets (target ≤60%)')

    # ── 7. Bass melodic interest (groove sections) ───────────────────────────
    groove_bass = []
    for s in groove_sections:
        groove_bass += notes_in_section(bass_notes, s)
    groove_bass.sort(key=lambda n: n[0])

    if len(groove_bass) > 1:
        b_pitches = [p for _, p, _, _ in groove_bass]
        b_ivs = [abs(b_pitches[i+1] - b_pitches[i]) for i in range(len(b_pitches)-1)]
        repeat_pct = 100 * sum(1 for iv in b_ivs if iv == 0) / len(b_ivs)
        mean_iv    = sum(b_ivs) / len(b_ivs)
        stats['bass_repeat_pct']  = repeat_pct
        stats['bass_mean_iv']     = mean_iv

        if repeat_pct > 55:
            flags.append(f'!! BASS-MONOTONE: {repeat_pct:.0f}% consecutive same-pitch (target ≤55%)')
        if mean_iv < 1.5:
            flags.append(f'!! BASS-FLAT: mean interval {mean_iv:.1f} semitones (target ≥1.5)')

    # ── 8. Overall density checks ────────────────────────────────────────────
    if groove_bars_set:
        groove_bar_count = len(groove_bars_set)
        for track_name, targets in DENSITY_TARGETS.items():
            notes = []
            for s in groove_sections:
                notes += notes_in_section(track_notes.get(track_name, []), s)
            npb = len(notes) / groove_bar_count
            lo, hi = targets['groove']
            stats[f'density_{track_name}'] = npb
            if npb < lo:
                flags.append(f'!! SPARSE {track_name}: {npb:.2f}/bar (target {lo}–{hi})')
            elif npb > hi:
                flags.append(f'!! DENSE  {track_name}: {npb:.2f}/bar (target {lo}–{hi})')

    # ── 9. Drum appropriateness for blues ────────────────────────────────────
    drum_rule = next((r for r in rules if r.startswith('CHL-DRUM-')), None)
    beat_style = info.get('beat_style') or ''
    # Blues should NOT use stGermain or hipHopJazz
    if 'stGermain' in beat_style or 'hipHopJazz' in beat_style.lower().replace('-','').replace('_',''):
        flags.append(f'!! BLUES-WRONG-BEAT: beat_style={beat_style} (blues should use brushKit, neoSoul, or electronic)')

    # ── 10. Pads: should be sparse (blues is about space) ───────────────────
    pads_notes = track_notes.get('Pads', [])
    if pads_notes and groove_bars_set:
        groove_pads = [n for n in pads_notes if tick_to_bar(n[0]) in groove_bars_set]
        pads_npb = len(groove_pads) / len(groove_bars_set)
        stats['pads_npb'] = pads_npb
        if pads_npb > 3.0:
            flags.append(f'!! PADS-DENSE: {pads_npb:.1f} notes/bar (blues target ≤3.0 — keep it spacious)')

    # ── 11. Lead 1 phrase quality ────────────────────────────────────────────
    groove_l1 = []
    for s in groove_sections:
        groove_l1 += notes_in_section(track_notes.get('Lead 1', []), s)
    groove_l1.sort(key=lambda n: n[0])

    if groove_l1:
        phrases, rests = detect_phrases(groove_l1)
        avg_phrase = sum(phrases) / len(phrases) if phrases else 0
        avg_rest   = sum(rests)   / len(rests)   if rests   else 0
        stats['lead1_phrase_bars'] = avg_phrase
        stats['lead1_rest_bars']   = avg_rest

        if avg_phrase > 6:
            flags.append(f'!! DENSE-LEAD: Lead 1 avg phrase {avg_phrase:.1f} bars (target ≤6)')
        if avg_rest < 0.3 and len(phrases) > 2:
            flags.append(f'!! NO-REST: Lead 1 avg rest {avg_rest:.2f} bars (target ≥0.3 — blues needs breathing room)')

        pitches = [p for _, p, _, _ in groove_l1]
        if len(pitches) > 1:
            ivs = [abs(pitches[i+1] - pitches[i]) for i in range(len(pitches)-1)]
            step_pct = 100 * sum(1 for i in ivs if i <= 2) / len(ivs)
            stats['lead1_step_pct'] = step_pct
            if step_pct < 50:
                flags.append(f'!! LEAP-HEAVY Lead 1: step ratio {step_pct:.0f}% (target ≥50%)')

        # Strong landings on chord tones
        phrase_groups = split_into_phrases(groove_l1)
        strong = 0
        for phrase in phrase_groups:
            lt, lp, _, _ = phrase[-1]
            lb = tick_to_bar(lt)
            chord = chord_at_bar(chords, lb)
            if chord:
                ct = chord_tones(chord, key_st, mode)
                if lp % 12 in ct:
                    strong += 1
        if phrase_groups:
            sl_pct = 100 * strong / len(phrase_groups)
            stats['lead1_strong_landing'] = sl_pct
            if sl_pct < 50:
                flags.append(f'!! PHRASE-END Lead 1: {sl_pct:.0f}% land on chord tone (target ≥50%)')

    return flags, stats, rules, info

# ── Phrase detection ──────────────────────────────────────────────────────────

GAP_TICKS = TICKS_PER_BAR

def detect_phrases(notes):
    if not notes: return [], []
    phrases = []; rests = []
    ps = notes[0][0]; pe = notes[0][0] + notes[0][3]
    for tick, pitch, vel, dur in notes[1:]:
        if tick - pe >= GAP_TICKS:
            phrases.append((pe - ps) / TICKS_PER_BAR)
            rests.append((tick - pe) / TICKS_PER_BAR)
            ps = tick
        pe = max(pe, tick + dur)
    phrases.append((pe - ps) / TICKS_PER_BAR)
    return phrases, rests

def split_into_phrases(notes):
    if not notes: return []
    phrases = [[notes[0]]]
    prev_end = notes[0][0] + notes[0][3]
    for n in notes[1:]:
        if n[0] - prev_end >= GAP_TICKS:
            phrases.append([])
        phrases[-1].append(n)
        prev_end = max(prev_end, n[0] + n[3])
    return phrases

# ── Batch summary ─────────────────────────────────────────────────────────────

def main():
    target_dir = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    target_dir = os.path.expanduser(target_dir)

    pairs = []
    for fname in sorted(os.listdir(target_dir)):
        if not fname.lower().endswith('.mid'): continue
        base    = os.path.splitext(fname)[0]
        midi_p  = os.path.join(target_dir, fname)
        zudio_p = os.path.join(target_dir, base + '.zudio')
        if os.path.exists(zudio_p):
            pairs.append((midi_p, zudio_p))

    if not pairs:
        print(f"No .MID/.zudio pairs found in: {target_dir}")
        sys.exit(1)

    print(f"\n{'='*72}")
    print(f"  CHILL BLUES QUALITY REPORT — {len(pairs)} songs")
    print(f"  Directory: {target_dir}")
    print(f"{'='*72}\n")

    all_flags   = []
    all_stats   = defaultdict(list)
    beat_styles = defaultdict(int)
    lead_insts  = defaultdict(int)
    bass_rules  = defaultdict(int)
    song_flags  = []

    for midi_p, zudio_p in pairs:
        try:
            flags, stats, rules, info = analyze_song(midi_p, zudio_p)
        except Exception as e:
            import traceback
            flags, stats, rules, info = [f'ERROR: {e}\n{traceback.format_exc()}'], {}, {}, {}
        fname = os.path.basename(midi_p)
        song_flags.append((fname, flags, info))
        all_flags.extend(flags)
        for k, v in stats.items():
            all_stats[k].append(v)
        bs = info.get('beat_style') or '?'
        li = info.get('lead_inst')  or '?'
        beat_styles[bs] += 1
        lead_insts[li]  += 1
        for r in rules:
            if r.startswith('CHL-BASS-'):
                bass_rules[r] += 1

    # ── Per-song flag listing ────────────────────────────────────────────────
    for fname, flags, info in song_flags:
        key   = info.get('key')   or '?'
        mode  = info.get('mode')  or '?'
        tempo = info.get('tempo') or '?'
        bs    = info.get('beat_style') or '?'
        li    = info.get('lead_inst')  or '?'
        header = f"  {fname}  [{key} {mode} {tempo}bpm  beat={bs}  lead={li}]"
        if flags:
            print(header)
            for f in flags:
                print(f"    {f}")
            print()
        else:
            print(f"{header}  ✓ clean")

    # ── Batch averages ───────────────────────────────────────────────────────
    n = len(pairs)

    def avg(key):
        vals = all_stats.get(key, [])
        return sum(vals) / len(vals) if vals else None

    def fmt(val):
        return f'{val:.1f}' if val is not None else 'n/a'

    print(f"\n{'─'*72}")
    print(f"  BATCH AVERAGES  (n={n})")
    print(f"{'─'*72}")

    print(f"\n  [BASS ROOT COVERAGE by zone]")
    for zone in ('I', 'IV', 'V'):
        v = avg(f'bass_root_{zone}')
        tgt = {'I': 60, 'IV': 55, 'V': 40}[zone]
        ok = '!!' if (v is not None and v < tgt) else 'ok'
        print(f"    {ok:2s}  {zone:4s}  root_cov={fmt(v)}%  (target ≥{tgt}%)")

    print(f"\n  [LEAD STRONG-BEAT CLASHES by zone]")
    for track in ('Lead 1', 'Lead 2'):
        for zone in ('I', 'IV', 'V'):
            v = avg(f'{track}_clash_{zone}')
            tgt = 20 if zone == 'I' else 25
            ok = '!!' if (v is not None and v > tgt) else 'ok'
            print(f"    {ok:2s}  {track} {zone:4s}  clash={fmt(v)}%  (target ≤{tgt}%)")

    print(f"\n  [PHRASE SEAM CROSSING]")
    for track in ('Lead 1', 'Lead 2'):
        v = avg(f'{track}_seam_cross_pct')
        ok = '!!' if (v is not None and v > 20) else 'ok'
        print(f"    {ok:2s}  {track}  seam_cross={fmt(v)}%  (target ≤20%)")

    print(f"\n  [BLUES SCALE CONFORMANCE]")
    for track in ('Lead 1', 'Lead 2'):
        v = avg(f'{track}_blues_conformance')
        ok = '!!' if (v is not None and v < 85) else 'ok'
        print(f"    {ok:2s}  {track}  blues_conform={fmt(v)}%  (target ≥85%)")

    print(f"\n  [CYCLE REPETITION]")
    v = avg('lead1_cycle_repeat_pct')
    ok = '!!' if (v is not None and v > 60) else 'ok'
    print(f"    {ok:2s}  Lead 1 cycle repeat={fmt(v)}%  (target ≤60% — blues repeats but not robotically)")

    print(f"\n  [LEAD ACTIVITY by zone]")
    for track in ('Lead 1', 'Lead 2'):
        for zone in ('I', 'IV', 'V'):
            v = avg(f'{track}_activity_{zone}')
            if v is not None:
                ok = '!!' if (zone == 'V' and v > 85) else 'ok'
                print(f"    {ok:2s}  {track} {zone:4s}  active={fmt(v)}%  {'(target ≤85% — allow turnaround rest)' if zone=='V' else ''}")

    print(f"\n  [LEAD PHRASING]")
    v = avg('lead1_phrase_bars')
    ok = '!!' if (v is not None and v > 6) else 'ok'
    print(f"    {ok:2s}  avg phrase:      {fmt(v)} bars  (target ≤6)")
    v = avg('lead1_rest_bars')
    ok = '!!' if (v is not None and v < 0.3) else 'ok'
    print(f"    {ok:2s}  avg rest:        {fmt(v)} bars  (target ≥0.3)")
    v = avg('lead1_step_pct')
    ok = '!!' if (v is not None and v < 50) else 'ok'
    print(f"    {ok:2s}  step ratio:      {fmt(v)}%  (target ≥50%)")
    v = avg('lead1_strong_landing')
    ok = '!!' if (v is not None and v < 50) else 'ok'
    print(f"    {ok:2s}  strong landings: {fmt(v)}%  (target ≥50%)")

    print(f"\n  [BASS]")
    v = avg('bass_repeat_pct')
    ok = '!!' if (v is not None and v > 55) else 'ok'
    print(f"    {ok:2s}  same-note ratio: {fmt(v)}%  (target ≤55%)")
    v = avg('bass_mean_iv')
    ok = '!!' if (v is not None and v < 1.5) else 'ok'
    print(f"    {ok:2s}  mean interval:   {fmt(v)} semitones  (target ≥1.5)")
    v = avg('density_Bass')
    ok = '!!' if (v is not None and (v < 1.5 or v > 5.0)) else 'ok'
    print(f"    {ok:2s}  density:         {fmt(v)}/bar  (target 1.5–5.0)")

    print(f"\n  [BASS RULES — diversity]")
    BASS_DESC = {
        'CHL-BASS-001': 'Root sustain',
        'CHL-BASS-009': 'Blues pickup riff',
        'CHL-BASS-010': 'Syncopated vamp',
        'CHL-BASS-011': 'Ascending riff',
    }
    for rule in sorted(bass_rules):
        desc = BASS_DESC.get(rule, rule)
        print(f"    ok  {rule}: {bass_rules[rule]}/{n}  ({desc})")

    print(f"\n  [INSTRUMENTATION — diversity]")
    print(f"  Beat styles (n={n}):")
    for bs, cnt in sorted(beat_styles.items(), key=lambda x: -x[1]):
        print(f"    {cnt:3d}  {bs}")
    print(f"  Lead instruments (n={n}):")
    for li, cnt in sorted(lead_insts.items(), key=lambda x: -x[1]):
        print(f"    {cnt:3d}  {li}")

    print(f"\n{'─'*72}")
    critical = [f for f in all_flags if 'CRITICAL' in f]
    issues   = [f for f in all_flags if f.startswith('!!') and 'CRITICAL' not in f]
    print(f"  SUMMARY: {len(critical)} CRITICAL  {len(issues)} flags across {n} songs")
    if not all_flags:
        print("  ✓ No issues detected.")
    print()

if __name__ == '__main__':
    import io
    buf = io.StringIO()
    orig = sys.stdout
    sys.stdout = buf
    main()
    sys.stdout = orig
    output = buf.getvalue()
    print(output, end='')

    target_dir = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    target_dir = os.path.expanduser(target_dir)
    n = 1
    while os.path.exists(os.path.join(target_dir, f'blues_report_{n:02d}.txt')):
        n += 1
    report_path = os.path.join(target_dir, f'blues_report_{n:02d}.txt')
    with open(report_path, 'w') as f:
        f.write(output)
    print(f"  Report saved → {report_path}")

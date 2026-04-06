#!/usr/bin/env python3
"""
chill_analyze.py — Chill-specific quality analyzer for Zudio.

Usage:
    python3 tools/chill_analyze.py [directory]

Reads all .MID/.zudio pairs in the given directory (default: current dir),
applies Chill-specific quality checks, and prints a ranked report.
Regen variation files in the regen/ subdirectory are analyzed separately.

Flags:
    !! CRITICAL  — structural correctness violation (e.g. lead in breakdown)
    !!           — metric outside acceptable range
    ok           — within target
"""

import struct, os, sys, re, math
from collections import defaultdict

# ── Constants ─────────────────────────────────────────────────────────────────

TPQ             = 480
TICKS_PER_STEP  = 120   # TPQ / 4 (16th note)
TICKS_PER_BAR   = 1920  # 16 × 120

GM_KICK   = 36
GM_SNARE  = 38
GM_RIDE   = 51

NOTE_NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']

KEY_ST = {'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,
          'F#':6,'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}

SCALE_INTERVALS = {
    'Ionian':          [0,2,4,5,7,9,11],
    'Dorian':          [0,2,3,5,7,9,10],
    'Mixolydian':      [0,2,4,5,7,9,10],
    'Aeolian':         [0,2,3,5,7,8,10],
    'MinorPentatonic': [0,3,5,7,10],
    'MajorPentatonic': [0,2,4,7,9],
}

# Per-track clash thresholds (max % out-of-scale before flagging)
CLASH_THRESHOLDS = {
    'Bass':   5.0,
    'Pads':  10.0,
    'Rhythm':15.0,
    'Lead 1':20.0,
    'Lead 2':20.0,
}

# Chill density targets per section (notes/bar)  [min, max]
DENSITY_TARGETS = {
    'Lead 1': {'A': (1.0, 3.0), 'B': (1.0, 3.0), 'intro': (0.0, 0.8), 'outro': (0.0, 1.5)},
    'Lead 2': {'A': (0.5, 2.5), 'B': (0.5, 2.5)},
    'Bass':   {'A': (1.5, 4.0), 'B': (1.5, 4.0)},
    'Rhythm': {'A': (1.5, 10.0), 'B': (1.5, 10.0)},
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
    """Returns list of tracks [{name, notes: [(tick, pitch, vel, dur_ticks)]}] and TPQ."""
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
    """Returns dict with keys: key, mode, style, tempo, bars, sections, chords, rules, mood,
    breakdown_style ('stop-time' | 'bass-ostinato' | 'harmonic-drone' | None)."""
    info = {
        'key': None, 'mode': None, 'style': None, 'tempo': None,
        'bars': None, 'mood': None,
        'breakdown_style': None,   # parsed from Form line
        'sections': [],   # list of {name, start_bar, end_bar} (0-indexed, end exclusive)
        'chords':   [],   # list of {start_bar, end_bar, root, ctype} (0-indexed)
        'rules': {},
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
        elif s.startswith('Style:'): info['style'] = s.split(None,1)[1].strip()
        elif s.startswith('Mood:'):  info['mood']  = s.split(None,1)[1].strip()
        elif s.startswith('Tempo:'):
            m = re.search(r'(\d+)', s)
            if m: info['tempo'] = int(m.group(1))
        elif s.startswith('Bars:'):
            m = re.search(r'(\d+)', s)
            if m: info['bars'] = int(m.group(1))
        elif '--- Structure ---' in s: in_struct = True; in_chords = in_log = False; continue
        elif '--- Chord Plan ---' in s: in_chords = True; in_struct = in_log = False; continue
        elif '--- Generation Log ---' in s: in_log = True; in_struct = in_chords = False; continue
        elif s.startswith('---'): in_struct = in_chords = in_log = False; continue

        if in_struct:
            # e.g. "intro      Bars   1–  8         (8 bars)"
            m = re.match(r'(\w+)\s+Bars\s+(\d+)[–-]\s*(\d+)', s)
            if m:
                name = m.group(1).lower()
                start = int(m.group(2)) - 1   # 0-indexed
                end   = int(m.group(3))        # exclusive (1-indexed end → exclusive 0-indexed)
                info['sections'].append({'name': name, 'start': start, 'end': end})

        elif in_chords:
            # e.g. "Bars   1–  6         root=1  type=major"
            m = re.match(r'Bars\s+(\d+)[–-]\s*(\d+)\s+root=(\S+)\s+type=(\S+)', s)
            if m:
                info['chords'].append({
                    'start': int(m.group(1)) - 1,
                    'end':   int(m.group(2)),
                    'root':  m.group(3),
                    'ctype': m.group(4),
                })

        elif in_log:
            # e.g. "CHL-DRUM-002     Ghost note groove"
            m = re.match(r'(CHL-\S+)\s+(.*)', s)
            if m: info['rules'][m.group(1)] = m.group(2).strip()
            # e.g. "Form             Groove · breakdown (stop-time)"
            mf = re.match(r'Form\s+Groove.*breakdown\s+\(([^)]+)\)', s)
            if mf:
                raw = mf.group(1).strip().lower()
                if 'stop' in raw:
                    info['breakdown_style'] = 'stop-time'
                elif 'ostinato' in raw:
                    info['breakdown_style'] = 'bass-ostinato'
                elif 'drone' in raw or 'harmonic' in raw:
                    info['breakdown_style'] = 'harmonic-drone'

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

def degree_to_pc(degree, key_st, mode):
    """Convert chord root degree string ('1','4','b7' etc.) to pitch class.

    Supports plain numeric degrees ('1'–'7') and flat-prefixed degrees ('b3','b6','b7').
    Uses absolute semitone offsets so it works regardless of mode.
    """
    # Absolute semitone offsets for common chord root degree labels
    DEGREE_ST = {
        '1': 0, '2': 2, 'b3': 3, '3': 4, '4': 5,
        '5': 7, 'b6': 8, '6': 9, 'b7': 10, '7': 11,
    }
    if degree in DEGREE_ST:
        return (key_st + DEGREE_ST[degree]) % 12
    # Fallback: try numeric index into scale intervals
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

def strong_pcs(chord, key_st, mode):
    """Root, 3rd, 5th of a chord as pitch classes."""
    root_pc = degree_to_pc(chord['root'], key_st, mode)
    intervals = SCALE_INTERVALS.get(mode, [0,2,4,5,7,9,11])
    # 3rd = 2nd scale degree from root; 5th = 4th scale degree from root
    # Approximate: major/dominant = [4,7], minor/sus = [3,7]
    ctype = chord.get('ctype', '')
    if ctype in ('major', 'dom7'):
        third, fifth = 4, 7
    else:  # minor, sus4, etc.
        third, fifth = 3, 7
    return {root_pc % 12, (root_pc + third) % 12, (root_pc + fifth) % 12}

# ── Per-song analysis ─────────────────────────────────────────────────────────

def analyze_song(midi_path, zudio_path):
    """Returns a list of flag strings for this song."""
    info   = parse_zudio(zudio_path)
    tracks_raw, tpq = parse_midi(midi_path)

    scale_pc = set()
    key_st   = KEY_ST.get(info['key'] or '', 0)
    if info['mode'] and info['mode'] in SCALE_INTERVALS:
        scale_pc = set((key_st + i) % 12 for i in SCALE_INTERVALS[info['mode']])

    # Map track names to note lists
    track_notes = {}
    for t in tracks_raw:
        name = t['name']
        if name in ('Lead 1', 'Lead 2', 'Pads', 'Rhythm', 'Bass', 'Drums'):
            track_notes[name] = t['notes']

    sections  = info['sections']
    chords    = info['chords']
    rules     = info['rules']
    drum_rule = next((r for r in rules if r.startswith('CHL-DRUM-')), None)

    flags = []
    stats = {}   # metric label → value (for summary)

    # ── 1. Tonal clash per track ─────────────────────────────────────────────
    if scale_pc:
        for tname, threshold in CLASH_THRESHOLDS.items():
            notes = track_notes.get(tname, [])
            if not notes: continue
            oos = sum(1 for _, p, _, _ in notes if p % 12 not in scale_pc)
            pct = 100 * oos / len(notes)
            stats[f'clash_{tname}'] = pct
            if pct > threshold:
                flags.append(f'!! CLASH  {tname}: {pct:.1f}% out-of-scale (target ≤{threshold:.0f}%)')

    # ── 2. Breakdown checks ──────────────────────────────────────────────────
    bridge = section_by_name(sections, 'bridge')
    bds = info.get('breakdown_style')  # 'stop-time' | 'bass-ostinato' | 'harmonic-drone' | None
    if bridge:
        bridge_bars = section_bars(bridge)

        # Lead 1 silence: required for stop-time (even bars) and bass-ostinato; NOT for harmonic-drone
        l1_in_bridge = notes_in_section(track_notes.get('Lead 1', []), bridge)
        if bds == 'harmonic-drone':
            # Lead SHOULD play — no check
            pass
        elif bds == 'stop-time':
            # Lead plays only on odd bars; flag only if it plays on EVEN bars (stab bars)
            if bridge:
                even_bar_notes = []
                for note in l1_in_bridge:
                    note_bar = (note[0] // TICKS_PER_BAR) - bridge['start']
                    if note_bar % 2 == 0:
                        even_bar_notes.append(note)
                if even_bar_notes:
                    flags.append(f'!! LEAD-IN-STAB-BAR: {len(even_bar_notes)} Lead 1 notes in stop-time stab bars (must be silent on even bars)')
        else:
            # bass-ostinato or unknown: lead must be completely silent
            if l1_in_bridge:
                flags.append(f'!! CRITICAL  LEAD-IN-BREAKDOWN: {len(l1_in_bridge)} Lead 1 notes in bridge (must be 0 for {bds or "unknown"} breakdown)')

        # Rhythm (Rhodes comping): must be silent in all breakdown types
        rhy_bridge = notes_in_section(track_notes.get('Rhythm', []), bridge)
        if rhy_bridge:
            flags.append(f'!! BREAKDOWN-RHYTHM-ACTIVE: Rhythm has {len(rhy_bridge)} notes in bridge (must be silent)')

        # Pads checks — style-specific
        pads_bridge = notes_in_section(track_notes.get('Pads', []), bridge)
        pads_npb = len(pads_bridge) / bridge_bars
        stats['pads_bridge_npb'] = pads_npb
        if bds == 'bass-ostinato':
            # Pads are intentionally silent — flag if they have notes
            if pads_bridge:
                flags.append(f'!! PADS-IN-BASSOSTINATO: Pads have {len(pads_bridge)} notes in bass-ostinato breakdown (must be silent)')
        elif bds == 'stop-time':
            # Staccato stabs every other bar: 0.5–2.0 notes/bar is fine
            if pads_npb > 3.0:
                flags.append(f'!! BREAKDOWN-PADS-DENSE: Pads {pads_npb:.1f} notes/bar in bridge (target ≤3.0 for stop-time)')
        elif bds == 'harmonic-drone':
            # Whisper sustain, should be very sparse: ≤0.5/bar
            if pads_npb > 1.0:
                flags.append(f'!! BREAKDOWN-PADS-DENSE: Pads {pads_npb:.1f} notes/bar in bridge (target ≤1.0 for harmonic-drone)')
        else:
            # Unknown/no breakdown style — use conservative default
            if not pads_bridge:
                flags.append(f'!! BREAKDOWN-EMPTY-PADS: Pads completely silent in bridge (target ≥1 chord per 4 bars)')
            elif pads_npb > 1.5:
                flags.append(f'!! BREAKDOWN-PADS-DENSE: Pads {pads_npb:.1f} notes/bar in bridge (target ≤1.5)')

        # Bass density — style-specific targets
        bass_bridge = notes_in_section(track_notes.get('Bass', []), bridge)
        bass_npb = len(bass_bridge) / bridge_bars
        stats['bass_bridge_npb'] = bass_npb
        if bds == 'bass-ostinato':
            # Syncopated riff: expect 3–5 notes/bar
            if bass_npb < 2.0:
                flags.append(f'!! BASSOSTINATO-SPARSE: {bass_npb:.1f} notes/bar in bridge (target 3–5 for bass-ostinato)')
            elif bass_npb > 6.0:
                flags.append(f'!! BASSOSTINATO-DENSE: {bass_npb:.1f} notes/bar in bridge (target 3–5 for bass-ostinato)')
        elif bds == 'stop-time':
            # Staccato hit every other bar: expect 0.3–1.5/bar
            if bass_npb > 2.0:
                flags.append(f'!! BASS-BREAKDOWN: {bass_npb:.1f} notes/bar in stop-time bridge (target ≤2.0)')
        elif bds == 'harmonic-drone':
            # Quarter-note root pulse: expect 3–5/bar
            if bass_npb < 2.0:
                flags.append(f'!! BASS-DRONE-SPARSE: {bass_npb:.1f} notes/bar in harmonic-drone bridge (target 3–5)')
            elif bass_npb > 6.0:
                flags.append(f'!! BASS-DRONE-DENSE: {bass_npb:.1f} notes/bar in harmonic-drone bridge (target 3–5)')
        else:
            if bass_npb > 1.5:
                flags.append(f'!! BASS-BREAKDOWN: {bass_npb:.1f} notes/bar in bridge (target ≤1.5)')

        # Bass velocity — only check for stop-time where bass should punch through
        if bass_bridge and bds == 'stop-time':
            bass_bridge_vel = sum(v for _, _, v, _ in bass_bridge) / len(bass_bridge)
            stats['bass_bridge_vel'] = bass_bridge_vel
            if bass_bridge_vel > 95:
                flags.append(f'!! BREAKDOWN-BASS-LOUD: bass mean vel={bass_bridge_vel:.0f} in stop-time bridge (target ≤95)')
        elif bass_bridge and bds not in ('bass-ostinato', 'harmonic-drone'):
            bass_bridge_vel = sum(v for _, _, v, _ in bass_bridge) / len(bass_bridge)
            stats['bass_bridge_vel'] = bass_bridge_vel
            if bass_bridge_vel > 75:
                flags.append(f'!! BREAKDOWN-BASS-LOUD: bass mean vel={bass_bridge_vel:.0f} in bridge (target ≤75)')

        # Drums density — style-specific
        drum_bridge = notes_in_section(track_notes.get('Drums', []), bridge)
        drum_npb = len(drum_bridge) / bridge_bars
        stats['drum_bridge_npb'] = drum_npb
        if bds == 'bass-ostinato':
            # Minimal timekeeping (≤4 events/bar) is intentional; flag only if full groove density snuck in
            if drum_npb > 4.0:
                flags.append(f'!! DRUMS-IN-BASSOSTINATO: {drum_npb:.1f} drum events/bar in bass-ostinato bridge (target ≤4 for minimal timekeeping)')
        elif bds == 'harmonic-drone':
            # Beat continues at full density — no upper limit; just sanity check
            pass
        elif bds == 'stop-time':
            # Kick+snare hit every other bar: expect 0.5–2.0/bar
            if drum_npb > 3.0:
                flags.append(f'!! BREAKDOWN-DRUM-DENSE: {drum_npb:.1f} drum events/bar in stop-time bridge (target ≤3.0)')
        else:
            if drum_npb > 2.0:
                flags.append(f'!! BREAKDOWN-DRUM-DENSE: {drum_npb:.1f} drum events/bar in bridge (target ≤2.0)')

        # First-4-bar drum density check — only for stop-time and bass-ostinato
        if bridge_bars >= 4 and bds in ('stop-time', None):
            bridge_start_tick = bridge['start'] * TICKS_PER_BAR
            first4_end_tick   = bridge_start_tick + 4 * TICKS_PER_BAR
            drum_first4 = [n for n in track_notes.get('Drums', [])
                           if bridge_start_tick <= n[0] < first4_end_tick]
            drum_first4_npb = len(drum_first4) / 4
            stats['drum_bridge_first4_npb'] = drum_first4_npb
            if drum_first4_npb > 1.5:
                flags.append(f'!! BREAKDOWN-DRUM-EARLY-DENSE: {drum_first4_npb:.1f} drum events/bar in bridge bars 1–4 (target ≤1.5)')

    # ── 3. Groove B Lead 1 density ≥ Groove A (rebuild check) ───────────────
    sec_a = section_by_name(sections, 'a')
    sec_b = section_by_name(sections, 'b')
    l1_notes = track_notes.get('Lead 1', [])
    if sec_a and sec_b and l1_notes:
        a_npb = len(notes_in_section(l1_notes, sec_a)) / section_bars(sec_a)
        b_npb = len(notes_in_section(l1_notes, sec_b)) / section_bars(sec_b)
        stats['lead1_a_npb'] = a_npb
        stats['lead1_b_npb'] = b_npb
        if b_npb < a_npb * 0.9:
            flags.append(f'!! REBUILD-FLAT: Lead 1 Groove B={b_npb:.2f}/bar < Groove A={a_npb:.2f}/bar')

    # ── 4. Density checks ────────────────────────────────────────────────────
    # CHL-BASS-007 (St Germain 8th-note ostinato) generates ~6-10 notes/bar by design — skip bass density check
    has_stgermain_bass = 'CHL-BASS-007' in rules
    sec_map = {'a': 'A', 'b': 'B', 'intro': 'intro', 'outro': 'outro', 'bridge': 'bridge'}
    for sec in sections:
        sname = sec['name']
        target_key = sec_map.get(sname)
        if not target_key: continue
        for tname, sec_targets in DENSITY_TARGETS.items():
            if target_key not in sec_targets: continue
            # Skip bass density check for St Germain ostinato (dense by design)
            if tname == 'Bass' and has_stgermain_bass: continue
            lo, hi = sec_targets[target_key]
            notes = notes_in_section(track_notes.get(tname, []), sec)
            npb   = len(notes) / section_bars(sec)
            stats[f'density_{tname}_{target_key}'] = npb
            if npb < lo and lo > 0:
                flags.append(f'!! SPARSE  {tname} {target_key}: {npb:.2f}/bar (target {lo}–{hi})')
            elif npb > hi:
                flags.append(f'!! DENSE   {tname} {target_key}: {npb:.2f}/bar (target {lo}–{hi})')

    # ── 5. Beat style checks (drum pattern) ──────────────────────────────────
    drum_notes = track_notes.get('Drums', [])
    groove_sections = [s for s in sections if s['name'] in ('a', 'b')]
    groove_bars_set = set()
    for s in groove_sections:
        groove_bars_set.update(range(s['start'], s['end']))

    if drum_rule == 'CHL-DRUM-001':  # Minimal syncopated: kick on beat 1 ≥ 90%
        kick_bars = set(tick_to_bar(t) for t, p, v, d in drum_notes if p == GM_KICK)
        coverage  = len(kick_bars & groove_bars_set) / max(1, len(groove_bars_set))
        stats['drum_kick_coverage'] = coverage
        if coverage < 0.90:
            flags.append(f'!! CHILL-KICK-MISSING: kick on beat 1 in {coverage*100:.0f}% of groove bars (target ≥90%)')
        total_per_bar = len([n for n in drum_notes if tick_to_bar(n[0]) in groove_bars_set]) / max(1, len(groove_bars_set))
        if total_per_bar > 5.5:   # 0.5 headroom — minor variance at boundary
            flags.append(f'!! CHILL-DRUM-DENSE: {total_per_bar:.1f} events/bar (CHL-DRUM-001 target ≤5)')

    elif drum_rule == 'CHL-DRUM-002':  # Ghost note groove: low-vel snare ≤ 50
        ghost_notes = [n for n in drum_notes if n[1] == GM_SNARE and n[2] <= 50
                       and tick_to_bar(n[0]) in groove_bars_set]
        if not ghost_notes:
            flags.append('!! CHILL-NO-GHOST: no low-velocity snare (ghost notes) in groove (CHL-DRUM-002)')

    elif drum_rule == 'CHL-DRUM-003':  # Jazz pulse: ride on beats 1 and 3
        ride_on_beat1 = set()
        ride_on_beat3 = set()
        for t, p, v, d in drum_notes:
            if p == GM_RIDE:
                bar = tick_to_bar(t)
                sib = step_in_bar(t)
                if bar in groove_bars_set:
                    if sib == 0:  ride_on_beat1.add(bar)
                    if sib == 8:  ride_on_beat3.add(bar)
        b1_cov = len(ride_on_beat1) / max(1, len(groove_bars_set))
        b3_cov = len(ride_on_beat3) / max(1, len(groove_bars_set))
        stats['ride_beat1'] = b1_cov
        stats['ride_beat3'] = b3_cov
        if b1_cov < 0.85 or b3_cov < 0.85:
            flags.append(f'!! CHILL-JAZZ-PULSE: ride beat1={b1_cov*100:.0f}% beat3={b3_cov*100:.0f}% (target ≥85%)')

    # ── 6. Lead 1 phrase structure ───────────────────────────────────────────
    groove_l1 = []
    for s in groove_sections:
        groove_l1 += notes_in_section(l1_notes, s)
    groove_l1.sort(key=lambda n: n[0])

    if groove_l1:
        phrases, rests = detect_phrases(groove_l1)
        avg_phrase = sum(phrases) / len(phrases) if phrases else 0
        avg_rest   = sum(rests)   / len(rests)   if rests   else 0
        stats['lead1_phrase_bars'] = avg_phrase
        stats['lead1_rest_bars']   = avg_rest

        if avg_phrase > 6:
            flags.append(f'!! CHILL-DENSE-LEAD: Lead 1 avg phrase={avg_phrase:.1f} bars (target ≤6)')
        if avg_rest < 0.5 and len(phrases) > 2:
            flags.append(f'!! CHILL-NO-REST: Lead 1 avg rest={avg_rest:.2f} bars (target ≥0.5)')

        # ── 7. Melodic quality ───────────────────────────────────────────────
        pitches = [p for _, p, _, _ in groove_l1]
        if len(pitches) > 1:
            intervals_abs = [abs(pitches[i+1] - pitches[i]) for i in range(len(pitches)-1)]
            steps_pct = 100 * sum(1 for i in intervals_abs if i <= 2) / len(intervals_abs)
            stats['lead1_step_pct'] = steps_pct
            if steps_pct < 53:   # 2% headroom — 55% is the target, flag only clear failures
                flags.append(f'!! CHILL-LEAP: Lead 1 step ratio={steps_pct:.0f}% (target ≥55%)')

        # Phrase resolution (last note of each phrase vs chord root/3rd/5th)
        if scale_pc and chords and phrases:
            phrase_notes_grouped = split_into_phrases(groove_l1)
            strong_landings = 0
            for phrase in phrase_notes_grouped:
                last_tick, last_pitch, _, _ = phrase[-1]
                last_bar = tick_to_bar(last_tick)
                chord = chord_at_bar(chords, last_bar)
                if chord:
                    spcs = strong_pcs(chord, key_st, info['mode'] or '')
                    if last_pitch % 12 in spcs:
                        strong_landings += 1
            if phrase_notes_grouped:
                strong_pct = 100 * strong_landings / len(phrase_notes_grouped)
                stats['lead1_strong_landing_pct'] = strong_pct
                if strong_pct < 55:   # 5% headroom — batch avg drives the real check
                    flags.append(f'!! CHILL-PHRASE-END: Lead 1 strong landings={strong_pct:.0f}% (target ≥60%)')

        # Pitch variety per phrase
        phrase_notes_grouped = split_into_phrases(groove_l1)
        if phrase_notes_grouped:
            mono_phrases = sum(1 for p in phrase_notes_grouped
                               if len(set(n[1] % 12 for n in p)) <= 2)
            mono_pct = 100 * mono_phrases / len(phrase_notes_grouped)
            stats['lead1_mono_phrase_pct'] = mono_pct
            if mono_pct > 30:
                flags.append(f'!! CHILL-MONOTONE-PHRASE: {mono_pct:.0f}% of Lead 1 phrases use ≤2 pitch classes')

    # ── 8. Lead voice overlap ────────────────────────────────────────────────
    l2_notes = track_notes.get('Lead 2', [])
    if l1_notes and l2_notes:
        l1_steps = set(tick_to_step(t) for t, _, _, _ in
                       [n for n in l1_notes if tick_to_bar(n[0]) in groove_bars_set])
        l2_steps = set(tick_to_step(t) for t, _, _, _ in
                       [n for n in l2_notes if tick_to_bar(n[0]) in groove_bars_set])
        total_steps = len(groove_bars_set) * 16
        overlap = len(l1_steps & l2_steps) / max(1, total_steps)
        stats['lead_overlap_pct'] = overlap * 100
        if overlap > 0.20:
            flags.append(f'!! CHILL-OVERLAP: Lead 1+2 overlap {overlap*100:.0f}% of groove steps (target ≤20%)')

    # ── 9. Register separation ───────────────────────────────────────────────
    if l1_notes and l2_notes:
        l1_groove = [n for n in l1_notes if tick_to_bar(n[0]) in groove_bars_set]
        l2_groove = [n for n in l2_notes if tick_to_bar(n[0]) in groove_bars_set]
        if l1_groove and l2_groove:
            l1_median = sorted(n[1] for n in l1_groove)[len(l1_groove)//2]
            l2_median = sorted(n[1] for n in l2_groove)[len(l2_groove)//2]
            sep = l1_median - l2_median
            stats['lead_register_sep'] = sep
            if sep < 5:
                flags.append(f'!! CHILL-REGISTER: Lead 1 median={l1_median} Lead 2 median={l2_median} sep={sep} (target ≥5)')

    # ── 10. Bass root coverage ───────────────────────────────────────────────
    # CHL-BASS-007 (St Germain ostinato) uses all scale degrees — root coverage check N/A
    bass_notes = track_notes.get('Bass', [])
    if bass_notes and chords and scale_pc and not has_stgermain_bass:
        bar_first_bass = {}
        for tick, pitch, vel, dur in bass_notes:
            bar = tick_to_bar(tick)
            if bar in groove_bars_set:
                if bar not in bar_first_bass:
                    bar_first_bass[bar] = pitch % 12
        root_hits = sum(1 for bar, pc in bar_first_bass.items()
                        if (chord := chord_at_bar(chords, bar)) and
                        pc == degree_to_pc(chord['root'], key_st, info['mode'] or ''))
        if bar_first_bass:
            root_cov = 100 * root_hits / len(bar_first_bass)
            stats['bass_root_cov'] = root_cov
            if root_cov < 75:
                flags.append(f'!! CHILL-BASS-ROOT: {root_cov:.0f}% bar-1 bass notes are chord root (target ≥75%)')

    # ── 11. Chord window length ───────────────────────────────────────────────
    if chords:
        groove_chords = [c for c in chords
                         if any(c['start'] <= bar < c['end'] for bar in groove_bars_set)]
        if groove_chords:
            lengths = [c['end'] - c['start'] for c in groove_chords]
            avg_len = sum(lengths) / len(lengths)
            stats['chord_window_bars'] = avg_len
            # Minor blues 12-bar patterns legitimately produce ~2-bar averages (turnaround
            # chords are 1–2 bars); only flag below 2.0 to catch genuinely broken progressions.
            if avg_len < 2.0:
                flags.append(f'!! CHORD-FAST: avg chord window={avg_len:.1f} bars (target ≥2; 4–8 in static/pendulum)')
            elif avg_len > 12:
                flags.append(f'!! CHORD-SLOW: avg chord window={avg_len:.1f} bars (target 4–8)')

    # ── 12. Voicing check (Pads: any chord strikes with ≥4 simultaneous notes) ──
    pads_notes = track_notes.get('Pads', [])
    if pads_notes:
        # Group notes by start tick (within 1 step tolerance)
        clusters = defaultdict(list)
        for tick, pitch, vel, dur in pads_notes:
            step = tick_to_step(tick)
            clusters[step].append(pitch)
        rich_clusters = sum(1 for pitches in clusters.values() if len(pitches) >= 4)
        total_clusters = len(clusters)
        if total_clusters > 0:
            rich_pct = 100 * rich_clusters / total_clusters
            stats['pads_7th_pct'] = rich_pct
            if rich_pct < 10:
                flags.append(f'!! CHILL-NO-7THS: only {rich_pct:.0f}% of Pads chord events have ≥4 notes (target ≥10%)')

    # ── 13. Bass melodic quality (groove sections only) ──────────────────────
    groove_bass = []
    for s in groove_sections:
        groove_bass += notes_in_section(bass_notes, s)
    groove_bass.sort(key=lambda n: n[0])

    if len(groove_bass) > 1:
        b_pitches = [p for _, p, _, _ in groove_bass]
        b_intervals = [abs(b_pitches[i+1] - b_pitches[i]) for i in range(len(b_pitches)-1)]

        # Repeated-note ratio: consecutive same-pitch hits (sign of root-only monotony)
        repeat_count = sum(1 for iv in b_intervals if iv == 0)
        repeat_pct = 100 * repeat_count / len(b_intervals)
        stats['bass_repeat_pct'] = repeat_pct
        if repeat_pct > 50:
            flags.append(f'!! BASS-MONOTONE: {repeat_pct:.0f}% of consecutive bass moves are same-pitch (target ≤50%)')

        # Mean interval size: near 0 means nothing but octave-repeated roots
        mean_iv = sum(b_intervals) / len(b_intervals)
        stats['bass_mean_interval'] = mean_iv
        if mean_iv < 1.5:
            flags.append(f'!! BASS-FLAT: mean bass interval={mean_iv:.1f} semitones (target ≥1.5 — root+5th minimum)')

        # Distinct pitches per 4-bar groove window
        if groove_bars_set:
            all_groove_bars = sorted(groove_bars_set)
            varieties = []
            for i in range(0, len(all_groove_bars), 4):
                window_bars = all_groove_bars[i:i+4]
                w_start = window_bars[0] * TICKS_PER_BAR
                w_end   = (window_bars[-1] + 1) * TICKS_PER_BAR
                w_notes = [n for n in groove_bass if w_start <= n[0] < w_end]
                if w_notes:
                    varieties.append(len(set(n[1] for n in w_notes)))
            if varieties:
                avg_variety = sum(varieties) / len(varieties)
                stats['bass_pitch_variety_4bar'] = avg_variety
                if avg_variety < 2.5:
                    flags.append(f'!! BASS-BORING: avg {avg_variety:.1f} distinct pitches per 4-bar groove window (target ≥2.5)')

    return flags, stats, rules

# ── Phrase detection ──────────────────────────────────────────────────────────

GAP_TICKS = TICKS_PER_BAR   # ≥ 1 bar gap = new phrase

def detect_phrases(notes):
    """Returns (phrase_lengths_bars, rest_lengths_bars) from sorted note list."""
    if not notes: return [], []
    phrases = []
    rests   = []
    phrase_start = notes[0][0]
    phrase_end   = notes[0][0] + notes[0][3]
    for tick, pitch, vel, dur in notes[1:]:
        if tick - phrase_end >= GAP_TICKS:
            phrases.append((phrase_end - phrase_start) / TICKS_PER_BAR)
            rests.append((tick - phrase_end) / TICKS_PER_BAR)
            phrase_start = tick
        phrase_end = max(phrase_end, tick + dur)
    phrases.append((phrase_end - phrase_start) / TICKS_PER_BAR)
    return phrases, rests

def split_into_phrases(notes):
    """Returns list of phrase note lists."""
    if not notes: return []
    phrases = [[notes[0]]]
    prev_end = notes[0][0] + notes[0][3]
    for n in notes[1:]:
        tick = n[0]
        if tick - prev_end >= GAP_TICKS:
            phrases.append([])
        phrases[-1].append(n)
        prev_end = max(prev_end, tick + n[3])
    return phrases

# ── Regen variation analysis ──────────────────────────────────────────────────

def analyze_regen_dir(regen_dir):
    """Analyze regen variation files and print a sub-report."""
    if not os.path.isdir(regen_dir): return

    # Group files by seed + track
    groups = defaultdict(list)
    for fname in sorted(os.listdir(regen_dir)):
        if not fname.lower().endswith('.mid'): continue
        # Expected: chill_SEEDHEX_drums_regenN.MID or chill_SEEDHEX_lead1_regenN.MID
        m = re.match(r'chill_([0-9a-f]+)_(drums|lead1)_regen(\d+)', fname, re.IGNORECASE)
        if m:
            key = (m.group(1), m.group(2).lower())
            groups[key].append(os.path.join(regen_dir, fname))

    if not groups:
        print("\n[REGEN VARIATION]\n  No regen files found in regen/ subdirectory.")
        return

    print("\n[REGEN VARIATION]")
    all_ok = True
    for (seed, track), files in sorted(groups.items()):
        step_sets = []
        for fpath in sorted(files):
            try:
                tracks_raw, _ = parse_midi(fpath)
                # Find the relevant track
                target_name = 'Drums' if track == 'drums' else 'Lead 1'
                for t in tracks_raw:
                    if t['name'] == target_name:
                        steps = set(tick_to_step(n[0]) for n in t['notes'])
                        step_sets.append(steps)
                        break
            except Exception as e:
                print(f"  ERROR reading {fpath}: {e}")

        if len(step_sets) < 2: continue

        diffs = []
        for i in range(len(step_sets)):
            for j in range(i+1, len(step_sets)):
                union = step_sets[i] | step_sets[j]
                if not union: diffs.append(0.0); continue
                shared = step_sets[i] & step_sets[j]
                diffs.append((len(union) - len(shared)) / len(union))

        avg_diff = sum(diffs) / len(diffs)
        min_diff = min(diffs)
        threshold_avg = 0.30 if track == 'drums' else 0.40
        flag = '!! REGEN-MONOTONE' if min_diff < 0.15 else ('ok' if avg_diff >= threshold_avg else '~~ LOW-VAR')
        all_ok = all_ok and flag == 'ok'
        print(f"  {flag:<20}  {track:6s}  seed={seed[:8]}  avg={avg_diff*100:.1f}%  min={min_diff*100:.1f}%")

    if all_ok:
        print("  All regen tracks show sufficient structural variation.")

# ── Batch summary report ──────────────────────────────────────────────────────

def main():
    target_dir = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    target_dir = os.path.expanduser(target_dir)

    # Gather .MID/.zudio pairs
    pairs = []
    for fname in sorted(os.listdir(target_dir)):
        if not fname.lower().endswith('.mid'): continue
        base     = os.path.splitext(fname)[0]
        midi_p   = os.path.join(target_dir, fname)
        zudio_p  = os.path.join(target_dir, base + '.zudio')
        if os.path.exists(zudio_p):
            pairs.append((midi_p, zudio_p))

    if not pairs:
        print(f"No .MID/.zudio pairs found in: {target_dir}")
        sys.exit(1)

    print(f"\n{'='*72}")
    print(f"  CHILL QUALITY REPORT — {len(pairs)} songs")
    print(f"  Directory: {target_dir}")
    print(f"{'='*72}\n")

    all_flags  = []
    all_stats  = defaultdict(list)
    drum_rules = defaultdict(int)
    bass_rules = defaultdict(int)
    song_flags = []

    for midi_p, zudio_p in pairs:
        try:
            flags, stats, rules = analyze_song(midi_p, zudio_p)
        except Exception as e:
            flags, stats, rules = [f'ERROR: {e}'], {}, {}
        fname = os.path.basename(midi_p)
        song_flags.append((fname, flags))
        all_flags.extend(flags)
        for k, v in stats.items():
            all_stats[k].append(v)
        for r in rules:
            if r.startswith('CHL-DRUM-'):
                drum_rules[r] += 1
            if r.startswith('CHL-BASS-'):
                bass_rules[r] += 1

    # ── Per-song flag listing ────────────────────────────────────────────────
    for fname, flags in song_flags:
        if flags:
            print(f"  {fname}")
            for f in flags:
                print(f"    {f}")
            print()

    # ── Batch summary ────────────────────────────────────────────────────────
    def avg(key):
        vals = all_stats.get(key, [])
        return sum(vals) / len(vals) if vals else None

    def fmt(val, fmt_str=':.1f'):
        return ('{' + fmt_str + '}').format(val) if val is not None else 'n/a'

    n = len(pairs)
    print(f"{'─'*72}")
    print(f"  BATCH AVERAGES  (n={n})")
    print(f"{'─'*72}")

    print(f"\n  [TONAL CLASH]")
    for tname in ('Bass', 'Pads', 'Rhythm', 'Lead 1', 'Lead 2'):
        v = avg(f'clash_{tname}')
        threshold = CLASH_THRESHOLDS.get(tname, 20)
        ok = '!!' if (v is not None and v > threshold) else 'ok'
        print(f"    {ok:2s}  {tname:<10}  clash={fmt(v)}%  (target ≤{threshold:.0f}%)")

    print(f"\n  [DENSITY — Groove sections]")
    for tname in ('Lead 1', 'Lead 2', 'Bass', 'Rhythm'):
        for sec in ('A', 'B'):
            v = avg(f'density_{tname}_{sec}')
            lo_hi = DENSITY_TARGETS.get(tname, {}).get(sec)
            if lo_hi and v is not None:
                lo, hi = lo_hi
                ok = '!!' if (v < lo and lo > 0) or v > hi else 'ok'
                print(f"    {ok:2s}  {tname:<10} Groove {sec}: {fmt(v)}/bar  (target {lo}–{hi})")

    print(f"\n  [LEAD PHRASING]")
    v = avg('lead1_phrase_bars')
    ok = '!!' if v is not None and v > 6 else 'ok'
    print(f"    {ok:2s}  Lead 1 avg phrase:     {fmt(v)} bars  (target 2–6)")
    v = avg('lead1_rest_bars')
    ok = '!!' if v is not None and v < 0.5 else 'ok'
    print(f"    {ok:2s}  Lead 1 avg rest:       {fmt(v)} bars  (target ≥0.5)")
    v = avg('lead1_step_pct')
    ok = '!!' if v is not None and v < 55 else 'ok'
    print(f"    {ok:2s}  Lead 1 step ratio:     {fmt(v)}%    (target ≥55%)")
    v = avg('lead1_strong_landing_pct')
    ok = '!!' if v is not None and v < 60 else 'ok'
    print(f"    {ok:2s}  Lead 1 strong landing: {fmt(v)}%    (target ≥60%)")
    v = avg('lead1_mono_phrase_pct')
    ok = '!!' if v is not None and v > 30 else 'ok'
    print(f"    {ok:2s}  Monotone phrases:      {fmt(v)}%    (target ≤30%)")

    print(f"\n  [LEAD BALANCE]")
    v = avg('lead_overlap_pct')
    ok = '!!' if v is not None and v > 20 else 'ok'
    print(f"    {ok:2s}  Lead 1+2 overlap:      {fmt(v)}%    (target ≤20%)")
    v = avg('lead_register_sep')
    ok = '!!' if v is not None and v < 5 else 'ok'
    print(f"    {ok:2s}  Register separation:   {fmt(v)} semitones  (target ≥5)")

    print(f"\n  [BREAKDOWN]  (mixed styles — per-song checks are style-aware)")
    v = avg('pads_bridge_npb')
    if v is not None:
        print(f"    --  Pads bridge density:   {fmt(v)}/bar  (style-dependent — see per-song flags)")
    v = avg('bass_bridge_npb')
    if v is not None:
        print(f"    --  Bass bridge density:   {fmt(v)}/bar  (style-dependent: ostinato/drone≈3-5; stop-time≈0.5)")
    v = avg('drum_bridge_npb')
    ok = '!!' if v is not None and v > 3.0 else 'ok'
    print(f"    {ok:2s}  Drum bridge density:   {fmt(v)}/bar  (target ≤3.0 avg — style-dependent)")
    v = avg('drum_bridge_first4_npb')
    ok = '!!' if v is not None and v > 1.5 else 'ok'
    print(f"    {ok:2s}  Drum bridge bars 1–4:  {fmt(v)}/bar  (target ≤1.5 — stop-time/unknown only)")

    print(f"\n  [BASS]")
    v = avg('bass_root_cov')
    ok = '!!' if v is not None and v < 75 else 'ok'
    print(f"    {ok:2s}  Root coverage:         {fmt(v)}%    (target ≥75%)")
    v = avg('bass_repeat_pct')
    ok = '!!' if v is not None and v > 50 else 'ok'
    print(f"    {ok:2s}  Same-note ratio:       {fmt(v)}%    (target ≤50% — high = monotone root-only)")
    v = avg('bass_mean_interval')
    ok = '!!' if v is not None and v < 1.5 else 'ok'
    print(f"    {ok:2s}  Mean interval:         {fmt(v)} semitones  (target ≥1.5)")
    v = avg('bass_pitch_variety_4bar')
    ok = '!!' if v is not None and v < 2.5 else 'ok'
    print(f"    {ok:2s}  Pitch variety 4-bar:   {fmt(v)} distinct pitches  (target ≥2.5)")
    print(f"\n  [BASS RULES — pattern diversity]")
    BASS_DESC = {
        'CHL-BASS-001': 'Root sustain',
        'CHL-BASS-002': 'Syncopated',
        'CHL-BASS-003': 'Walking line',
        'CHL-BASS-004': 'Ostinato',
        'CHL-BASS-005': 'Breakdown whole-note',
        'CHL-BASS-006': 'Bass statement',
    }
    for rule in sorted(bass_rules):
        count = bass_rules[rule]
        desc = BASS_DESC.get(rule, rule)
        print(f"    ok  {rule}: {count}/{n} songs  ({desc})")

    print(f"\n  [HARMONY]")
    v = avg('chord_window_bars')
    ok = '!!' if v is not None and (v < 2.0 or v > 12) else 'ok'
    print(f"    {ok:2s}  Chord window:          {fmt(v)} bars  (target ≥2; 4–8 in static/pendulum)")
    v = avg('pads_7th_pct')
    ok = '!!' if v is not None and v < 10 else 'ok'
    print(f"    {ok:2s}  Pads 7th-chord events: {fmt(v)}%    (target ≥10%)")

    print(f"\n  [DRUMS — style diversity across {n} songs]")
    for rule, count in sorted(drum_rules.items()):
        desc = {'CHL-DRUM-001': 'Minimal syncopated',
                'CHL-DRUM-002': 'Ghost note groove',
                'CHL-DRUM-003': 'Jazz pulse'}.get(rule, rule)
        ok = '!! CHILL-DRUM-DOMINANT' if count >= 8 else 'ok'
        print(f"    {ok:2s}  {rule}: {count}/{n} songs  ({desc})")
    if len(drum_rules) < 2:
        print(f"    !! CHILL-DRUM-DOMINANT: only {len(drum_rules)} drum style(s) seen across batch")

    # ── Flag summary ─────────────────────────────────────────────────────────
    print(f"\n{'─'*72}")
    critical = [f for f in all_flags if 'CRITICAL' in f]
    issues   = [f for f in all_flags if f.startswith('!!') and 'CRITICAL' not in f]
    print(f"  SUMMARY: {len(critical)} CRITICAL  {len(issues)} flags across {n} songs")
    if not all_flags:
        print("  ✓ No issues detected.")
    print()

    # ── Regen variation ───────────────────────────────────────────────────────
    regen_dir = os.path.join(target_dir, 'regen')
    analyze_regen_dir(regen_dir)
    print()

if __name__ == '__main__':
    import io, sys as _sys
    _buf = io.StringIO()
    _orig_stdout = _sys.stdout
    _sys.stdout = _buf
    main()
    _sys.stdout = _orig_stdout
    output = _buf.getvalue()
    print(output, end='')
    # Save report with auto-incrementing number so past runs are preserved
    target_dir = _sys.argv[1] if len(_sys.argv) > 1 else os.getcwd()
    target_dir = os.path.expanduser(target_dir)
    n = 1
    while os.path.exists(os.path.join(target_dir, f'chill_report_{n:02d}.txt')):
        n += 1
    report_path = os.path.join(target_dir, f'chill_report_{n:02d}.txt')
    with open(report_path, 'w') as _f:
        _f.write(output)
    print(f"  Report saved → {report_path}")

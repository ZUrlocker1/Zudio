#!/usr/bin/env python3
"""
ambient_piano_analyze.py — Ambient Piano melodic quality analyzer.

Focuses on the three AMB-PNO rules:
  AMB-PNO-001  Floating Tones  (Harold Budd)
  AMB-PNO-002  Pensive Melody  (Satie / Arnalds)
  AMB-PNO-003  Dramatic Arc    (Winston / Jarrett)

Metrics (Lead 1 only, since that carries the piano):
  1. Note density and register balance (LH vs RH split at MIDI 60)
  2. Melodic lyricism: stepwise ratio, interval distribution, phrase length
  3. Chord quality: simultaneity, chord sizes, consonance of intervals
  4. Motif repetition: recurring 3-4 note pitch-class sequences
  5. Phrase spacing: gap distribution (longest, mean, histogram)
  6. Dynamic arc (AMB-PNO-003): does velocity rise toward climax?
  7. Rule-specific pass/fail flags

Usage:
  cd tools/batch-output/ambient && python3 ../../ambient_piano_analyze.py *.MID
"""

import struct, os, sys, re, collections, math

NOTE_NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
def note_name(n): return NOTE_NAMES[n % 12] + str(n // 12 - 1)

KEY_ST = {'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,
          'F#':6,'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}

SCALE_INTERVALS = {
    'Ionian':          [0,2,4,5,7,9,11],
    'Dorian':          [0,2,3,5,7,9,10],
    'Mixolydian':      [0,2,4,5,7,9,10],
    'Aeolian':         [0,2,3,5,7,8,10],
    'MinorPentatonic': [0,3,5,7,10],
    'MajorPentatonic': [0,2,4,7,9],
    'Dream':           [0,2,3,5,7,9,10],  # alias Dorian
    'Deep':            [0,2,3,5,7,8,10],  # alias Aeolian
}

# Consonant intervals (semitones) — ring beautifully on piano
CONSONANT = {0, 3, 4, 5, 7, 8, 9, 12}   # unison, m3, M3, P4, P5, m6, M6, oct
DISSONANT = {1, 2, 6, 10, 11}             # m2, M2, TT, m7, M7

# ── MIDI parser (same as ambient_analyze.py) ──────────────────────────────────

def read_vlq(data, pos):
    val = 0
    while True:
        b = data[pos]; pos += 1
        val = (val << 7) | (b & 0x7F)
        if not (b & 0x80): break
    return val, pos

def parse_midi(path):
    with open(path, 'rb') as f: data = f.read()
    assert data[0:4] == b'MThd'
    _, _, ntracks, tpq = struct.unpack('>IHHH', data[4:14])
    pos = 14; tracks = []
    for _ in range(ntracks):
        assert data[pos:pos+4] == b'MTrk'
        tlen = struct.unpack('>I', data[pos+4:pos+8])[0]
        tend = pos + 8 + tlen; tpos = pos + 8
        tick = 0; name = f"Track{len(tracks)}"; notes = []; active = {}; running = 0
        while tpos < tend:
            dt, tpos = read_vlq(data, tpos); tick += dt
            if tpos >= tend: break
            b = data[tpos]
            if b & 0x80: running = b; tpos += 1
            cmd = running & 0xF0
            if running == 0xFF:
                mt = data[tpos]; tpos += 1
                ml, tpos = read_vlq(data, tpos)
                if mt == 0x03: name = data[tpos:tpos+ml].decode('latin1','replace')
                tpos += ml
            elif running in (0xF0, 0xF7):
                ml, tpos = read_vlq(data, tpos); tpos += ml
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
            elif cmd == 0xC0: tpos += 1
        for (ch, note), (st, sv) in active.items():
            notes.append((st, note, sv, tick - st))
        tracks.append({'name': name, 'notes': notes}); pos = tend
    return tracks, tpq

def parse_log(path):
    info = {'key': None, 'mode': None, 'tempo': None, 'bars': None,
            'piano_rule': None, 'piano_submode': None,
            'is_ambient_piano': False, 'title': '?'}
    try:
        lines = open(path).readlines()
    except FileNotFoundError:
        return info
    for line in lines:
        s = line.rstrip()
        m = re.match(r'Title:\s+(.+)', s)
        if m: info['title'] = m.group(1).strip()
        m = re.match(r'Key:\s+(\S+)\s+(\S+)', s)
        if m: info['key'] = m.group(1); info['mode'] = m.group(2)
        m = re.match(r'Tempo:\s+(\d+)', s)
        if m: info['tempo'] = int(m.group(1))
        m = re.match(r'Bars:\s+(\d+)', s)
        if m: info['bars'] = int(m.group(1))
        m = re.search(r'(AMB-PNO-\d+)', s)
        if m:
            info['piano_rule'] = m.group(1)
            info['is_ambient_piano'] = True
            # Detect AMB-PNO-001 sub-mode from the generation log label
            if 'Pendulum' in s:   info['piano_submode'] = 'pendulum'
            elif 'Chord Wash' in s: info['piano_submode'] = 'chord_wash'
            elif 'Sparse' in s:   info['piano_submode'] = 'sparse'
        if 'Ambient Piano' in s:
            info['is_ambient_piano'] = True
    return info

# ── Music analysis helpers ────────────────────────────────────────────────────

def tonal_clash_pct(notes, key_st, mode_str):
    if not notes: return 0.0
    intervals = SCALE_INTERVALS.get(mode_str, SCALE_INTERVALS['Dorian'])
    scale = set((key_st + i) % 12 for i in intervals)
    clashes = sum(1 for (_, n, _, _) in notes if (n % 12) not in scale)
    return clashes / len(notes) * 100

def split_lh_rh(notes, split=60):
    """Split notes into left-hand (bass, <split) and right-hand (melody, >=split)."""
    lh = [(st, n, v, d) for (st, n, v, d) in notes if n < split]
    rh = [(st, n, v, d) for (st, n, v, d) in notes if n >= split]
    return lh, rh

def melodic_intervals(notes):
    """Compute intervals between consecutive notes sorted by start time."""
    if len(notes) < 2: return []
    sorted_notes = sorted(notes, key=lambda x: x[0])
    return [abs(sorted_notes[i+1][1] - sorted_notes[i][1])
            for i in range(len(sorted_notes)-1)]

def stepwise_ratio(intervals):
    """Fraction of intervals <= 2 semitones (whole step or less)."""
    if not intervals: return 0.0
    return sum(1 for i in intervals if i <= 2) / len(intervals)

def interval_histogram(intervals):
    """Bucket intervals: unison, step(1-2), skip(3-4), leap(5-7), wide(8+)."""
    h = {'unison': 0, 'step': 0, 'skip': 0, 'leap': 0, 'wide': 0}
    for i in intervals:
        if i == 0:    h['unison'] += 1
        elif i <= 2:  h['step']   += 1
        elif i <= 4:  h['skip']   += 1
        elif i <= 7:  h['leap']   += 1
        else:         h['wide']   += 1
    total = sum(h.values()) or 1
    return {k: v/total*100 for k, v in h.items()}

def find_phrases(notes, tpq, gap_beats=2.0):
    """Group notes into phrases separated by gaps >= gap_beats beats."""
    if not notes: return []
    tpb = tpq * 4
    gap_ticks = gap_beats * tpb
    sorted_n = sorted(notes, key=lambda x: x[0])
    phrases = []
    current = [sorted_n[0]]
    for note in sorted_n[1:]:
        prev_end = current[-1][0] + current[-1][3]
        if note[0] - prev_end >= gap_ticks:
            phrases.append(current)
            current = [note]
        else:
            current.append(note)
    phrases.append(current)
    return phrases

def phrase_gaps_bars(phrases, tpq):
    """Return list of gaps between consecutive phrases in bars."""
    tpb = tpq * 4
    gaps = []
    for i in range(len(phrases)-1):
        end_of_phrase  = phrases[i][-1][0] + phrases[i][-1][3]
        start_of_next  = phrases[i+1][0][0]
        gap_bars = (start_of_next - end_of_phrase) / tpb
        if gap_bars > 0:
            gaps.append(gap_bars)
    return gaps

def detect_motifs(notes, min_len=3, max_len=4, min_recur=3):
    """Find recurring pitch-class sequences of length min_len..max_len."""
    sorted_n = sorted(notes, key=lambda x: x[0])
    pcs = [n % 12 for (_, n, _, _) in sorted_n]
    motif_counts = collections.Counter()
    for length in range(min_len, max_len+1):
        for i in range(len(pcs) - length + 1):
            motif = tuple(pcs[i:i+length])
            motif_counts[motif] += 1
    return [(m, c) for m, c in motif_counts.most_common(10) if c >= min_recur]

def chord_analysis(notes, tpq, window_ms=60):
    """Find simultaneous note groups; measure chord size and interval consonance."""
    if not notes: return {'chord_pct': 0, 'size_dist': {}, 'consonance': 0, 'top_intervals': []}
    # Use tick window = window_ms / (60000 / tempo / tpq)
    # We approximate: window in ticks = window_ms/1000 * tpq * 4 * tempo/60
    # Since we don't have tempo here, use a relative window of tpq/8 ticks (~1/32 note at 120bpm)
    window_ticks = max(1, tpq // 8)
    sorted_n = sorted(notes, key=lambda x: x[0])
    groups = []
    i = 0
    while i < len(sorted_n):
        group = [sorted_n[i]]
        j = i + 1
        while j < len(sorted_n) and sorted_n[j][0] - sorted_n[i][0] <= window_ticks:
            group.append(sorted_n[j]); j += 1
        groups.append(group); i = j

    chord_groups = [g for g in groups if len(g) >= 2]
    chord_pct = len(chord_groups) / len(groups) * 100 if groups else 0

    size_dist = collections.Counter(len(g) for g in chord_groups)

    # Interval consonance
    all_ivls = []
    for g in chord_groups:
        pitches = sorted(n for (_, n, _, _) in g)
        for a in range(len(pitches)):
            for b in range(a+1, len(pitches)):
                ivl = (pitches[b] - pitches[a]) % 12
                all_ivls.append(ivl)
    consonance = sum(1 for i in all_ivls if i in CONSONANT) / len(all_ivls) * 100 if all_ivls else 0
    top_ivls = collections.Counter(all_ivls).most_common(5)

    return {
        'chord_pct': chord_pct,
        'size_dist': dict(size_dist),
        'consonance': consonance,
        'top_intervals': top_ivls,
    }

def velocity_arc(notes, tpq, total_bars):
    """Divide song into thirds; return mean velocity per third to check dynamic arc."""
    if not notes or not total_bars: return [], 0
    tpb = tpq * 4
    third = total_bars / 3
    thirds = [[], [], []]
    for (st, n, v, d) in notes:
        bar = st / tpb
        t = min(2, int(bar / third))
        thirds[t].append(v)
    means = [sum(t)/len(t) if t else 0 for t in thirds]
    # Arc score: does vel rise from 1st→2nd then fall 2nd→3rd?
    arc_score = 0
    if means[0] and means[1] and means[2]:
        if means[1] > means[0]: arc_score += 1
        if means[2] < means[1]: arc_score += 1
    return means, arc_score

def score_lyricism(ivl_hist, stepwise, n_phrases, mean_phrase_notes, motifs):
    """Return a 0-10 lyricism score."""
    score = 0.0
    # Stepwise motion (0-3 pts)
    score += min(3.0, stepwise / 0.40 * 3.0)
    # Skip/leap variety (0-2 pts) — pure stepwise is boring, some skips needed
    skip_leap = ivl_hist.get('skip', 0) + ivl_hist.get('leap', 0)
    score += min(2.0, skip_leap / 40.0 * 2.0)
    # Phrase count (0-2 pts)
    score += min(2.0, n_phrases / 6.0 * 2.0)
    # Phrase density (0-2 pts) — 4-12 notes per phrase is ideal
    ideal = min(1.0, max(0, mean_phrase_notes - 2) / 10.0)
    score += min(2.0, ideal * 2.0)
    # Motif repetition (0-1 pt)
    score += min(1.0, len(motifs) / 3.0)
    return round(min(10.0, score), 1)

def score_chord_quality(chord_info, lh_pct):
    """Return a 0-10 chord quality score."""
    score = 0.0
    # Chord presence (0-3 pts) — some chords needed, not all melody
    score += min(3.0, chord_info['chord_pct'] / 40.0 * 3.0)
    # Consonance (0-3 pts)
    score += min(3.0, chord_info['consonance'] / 90.0 * 3.0)
    # LH/RH balance (0-2 pts) — 20-45% in bass register is ideal
    ideal_lh = 1.0 - abs(lh_pct - 32) / 32.0
    score += max(0, min(2.0, ideal_lh * 2.0))
    # Chord variety (0-2 pts) — mix of dyads and triads
    sizes = chord_info['size_dist']
    has_dyad  = sizes.get(2, 0) > 0
    has_triad = sizes.get(3, 0) > 0
    score += (1.0 if has_dyad else 0) + (1.0 if has_triad else 0)
    return round(min(10.0, score), 1)

# ── Per-rule thresholds ────────────────────────────────────────────────────────

RULE_THRESHOLDS = {
    'AMB-PNO-001': {
        'density_min': 0.5,  'density_max': 5.0,   # Budd: sparse but some LH now
        'stepwise_min': 0.20,                        # some stepwise in figures
        'max_gap_bars':  18,                         # Budd: long gaps OK
        'min_gap_bars':   3,                         # but should have SOME silence
        'chord_pct_min': 10,                         # dyads expected
        'lh_pct_min': 0,    'lh_pct_max': 25,       # mostly high register
        'lyricism_min': 3.0,
        'chord_q_min':  4.0,
    },
    'AMB-PNO-002': {
        'density_min': 2.5,  'density_max': 10.0,   # Satie: LH adds lots of notes
        'stepwise_min': 0.25,                        # melody should step
        'max_gap_bars':  15,                         # no 15-bar silences
        'min_gap_bars':   0,
        'chord_pct_min': 20,                         # LH generates chords
        'lh_pct_min': 15,   'lh_pct_max': 60,       # LH bass present
        'lyricism_min': 4.0,
        'chord_q_min':  5.0,
    },
    'AMB-PNO-003': {
        'density_min': 2.5,  'density_max': 12.0,   # Winston: LH + melody
        'stepwise_min': 0.25,
        'max_gap_bars':  12,
        'min_gap_bars':   0,
        'chord_pct_min': 15,
        'lh_pct_min': 15,   'lh_pct_max': 60,       # Winston LH present
        'lyricism_min': 4.0,
        'chord_q_min':  5.0,
    },
}

RULE_LABEL = {
    'AMB-PNO-001': 'Floating Tones (Budd)',
    'AMB-PNO-002': 'Pensive Melody  (Satie/Arnalds)',
    'AMB-PNO-003': 'Dramatic Arc    (Winston/Jarrett)',
}

# ── Main analysis ─────────────────────────────────────────────────────────────

def analyze_file(midi_path):
    base     = os.path.splitext(midi_path)[0]
    log_path = base + '.zudio'
    fname    = os.path.basename(midi_path)

    tracks, tpq = parse_midi(midi_path)
    log = parse_log(log_path)
    has_log = log['key'] is not None

    key_st   = KEY_ST.get(log['key'], 0) if has_log else 0
    mode_str = log['mode'] or 'Dorian'
    tempo    = log['tempo'] or 72
    total_bars = log['bars'] or 88
    piano_rule  = log.get('piano_rule') or 'AMB-PNO-002'
    is_pendulum = log.get('piano_submode') == 'pendulum'
    tpb = tpq * 4

    track_map = {t['name']: t['notes'] for t in tracks}
    lead1 = track_map.get('Lead 1', [])

    rule_label = RULE_LABEL.get(piano_rule, piano_rule)
    thresh     = RULE_THRESHOLDS.get(piano_rule, RULE_THRESHOLDS['AMB-PNO-002'])

    print(f"\n{'═'*68}")
    print(f"  {fname}")
    if has_log:
        print(f"  \"{log['title']}\"")
        print(f"  Rule: {rule_label}")
        print(f"  {log['key']} {mode_str}  {tempo} BPM  {total_bars} bars")
    print()

    flags   = []
    metrics = {}

    # ── 1. Note density & register ─────────────────────────────────────────
    n_total = len(lead1)
    npb = n_total / total_bars if total_bars else 0
    lh, rh = split_lh_rh(lead1, split=55)   # <55 = true bass register; 55-59 are mid-register melody
    lh_pct = len(lh) / n_total * 100 if n_total else 0
    pitch_range = (min(n for (_,n,_,_) in lead1), max(n for (_,n,_,_) in lead1)) if lead1 else (0,0)
    pitch_span  = pitch_range[1] - pitch_range[0]
    vel_vals = [v for (_,_,v,_) in lead1]
    vel_mean = sum(vel_vals)/len(vel_vals) if vel_vals else 0
    vel_std  = math.sqrt(sum((v-vel_mean)**2 for v in vel_vals)/len(vel_vals)) if vel_vals else 0

    print(f"  [DENSITY & REGISTER]")
    dens_warn = ''
    if npb < thresh['density_min']:   dens_warn = f'  !!SPARSE (<{thresh["density_min"]})'
    elif npb > thresh['density_max']: dens_warn = f'  !!DENSE (>{thresh["density_max"]})'
    print(f"    Lead 1 notes: {n_total}   {npb:.1f} n/bar{dens_warn}")
    lh_warn = ''
    if lh_pct > thresh['lh_pct_max']: lh_warn = '  !!TOO-MUCH-BASS'
    elif lh_pct < thresh['lh_pct_min'] and n_total > 10 and not is_pendulum: lh_warn = '  !!NO-BASS-LH'
    print(f"    LH (bass <55): {len(lh)} ({lh_pct:.0f}%)   RH (melody ≥55): {len(rh)}{lh_warn}")
    print(f"    Pitch range: {note_name(pitch_range[0])}–{note_name(pitch_range[1])} ({pitch_span} semitones)")
    print(f"    Velocity: mean={vel_mean:.0f} std={vel_std:.0f}")
    if dens_warn: flags.append(f'DENSITY{dens_warn.strip()}')
    if lh_warn:   flags.append(f'REGISTER {lh_warn.strip()}')
    if pitch_span < 20 and n_total > 15: flags.append(f'NARROW-RANGE: only {pitch_span} semitones')

    metrics['npb']    = npb
    metrics['lh_pct'] = lh_pct

    # ── 2. Tonal clash ─────────────────────────────────────────────────────
    clash_pct = tonal_clash_pct(lead1, key_st, mode_str)
    clash_warn = '  !!CLASH' if clash_pct > 15 else ''
    print(f"\n  [TONAL CLASH]")
    print(f"    Lead 1: {clash_pct:.1f}% off-scale{clash_warn}")
    if clash_warn: flags.append(f'TONAL-CLASH: {clash_pct:.1f}%')

    # ── 3. Melodic lyricism (RH melody notes only) ─────────────────────────
    print(f"\n  [MELODIC LYRICISM]")
    rh_sorted = sorted(rh, key=lambda x: x[0]) if rh else []
    ivls       = melodic_intervals(rh_sorted)
    sw_ratio   = stepwise_ratio(ivls)
    ivl_hist   = interval_histogram(ivls)

    print(f"    Stepwise (≤2st): {sw_ratio*100:.0f}%")
    print(f"    Interval mix: " +
          f"unison={ivl_hist['unison']:.0f}%  step={ivl_hist['step']:.0f}%  "
          f"skip={ivl_hist['skip']:.0f}%  leap={ivl_hist['leap']:.0f}%  wide={ivl_hist['wide']:.0f}%")

    # Pentatonic modes have no semitones, so consecutive scale steps are already 2-3 st apart;
    # lower the stepwise floor so they aren't unfairly penalised.
    penta_modes = {'MajorPentatonic', 'MinorPentatonic'}
    sw_min = 0.18 if mode_str in penta_modes else thresh['stepwise_min']
    if sw_ratio < sw_min and len(rh) > 10:
        flags.append(f'NOT-LYRICAL: only {sw_ratio*100:.0f}% stepwise (min {sw_min*100:.0f}%)')

    # Phrases from ALL lead1 notes (LH+RH together reflect phrase structure)
    phrases    = find_phrases(lead1, tpq, gap_beats=1.5)
    phrase_counts = [len(p) for p in phrases]
    mean_phrase_notes = sum(phrase_counts)/len(phrase_counts) if phrase_counts else 0
    n_phrases  = len(phrases)

    # Phrase gaps
    gaps       = phrase_gaps_bars(phrases, tpq)
    max_gap    = max(gaps) if gaps else 0
    mean_gap   = sum(gaps)/len(gaps) if gaps else 0

    print(f"    Phrases: {n_phrases}  avg {mean_phrase_notes:.1f} notes/phrase")
    print(f"    Phrase gaps: max={max_gap:.1f} bars  mean={mean_gap:.1f} bars")

    gap_warn = ''
    if max_gap > thresh['max_gap_bars']:
        gap_warn = f'  !!LONG-SILENCE ({max_gap:.0f} bars)'
        flags.append(f'LONG-SILENCE: {max_gap:.0f}-bar gap')
    print(f"    Lead 1 longest silence: {max_gap:.1f} bars{gap_warn}")

    # Motifs
    motifs = detect_motifs(rh_sorted, min_recur=3)
    if motifs:
        top3 = ', '.join(f"{' '.join(NOTE_NAMES[p] for p in m)}×{c}" for m,c in motifs[:3])
        print(f"    Recurring motifs (3-4 notes, ≥3×): {top3}")
    else:
        print(f"    Recurring motifs: none detected")

    lyricism_score = score_lyricism(ivl_hist, sw_ratio, n_phrases, mean_phrase_notes, motifs)
    if lyricism_score < thresh['lyricism_min']:
        flags.append(f'LOW-LYRICISM: {lyricism_score}/10 (min {thresh["lyricism_min"]})')

    metrics['stepwise'] = sw_ratio
    metrics['motifs']   = motifs
    metrics['lyricism'] = lyricism_score

    # ── 4. Chord quality ───────────────────────────────────────────────────
    print(f"\n  [CHORD QUALITY]")
    chord_info = chord_analysis(lead1, tpq)
    chord_pct  = chord_info['chord_pct']
    consonance = chord_info['consonance']
    sizes      = chord_info['size_dist']
    ivl_names  = {0:'P1', 1:'m2', 2:'M2', 3:'m3', 4:'M3', 5:'P4',
                  6:'TT', 7:'P5', 8:'m6', 9:'M6', 10:'m7', 11:'M7', 12:'Oct'}
    top_ivl_str = ', '.join(f"{ivl_names.get(i%12,'?')}×{c}"
                             for i,c in chord_info['top_intervals'])
    size_str   = ', '.join(f"{k}-note×{v}" for k,v in sorted(sizes.items()))

    # Pendulum sub-mode is intentionally monophonic — skip chord checks for it
    chord_warn = '  !!FEW-CHORDS' if chord_pct < thresh['chord_pct_min'] and not is_pendulum else ''
    pend_note  = '  (monophonic by design)' if is_pendulum else ''
    cons_warn  = '  !!DISSONANT'  if consonance < 60 else ''
    print(f"    Chord groups: {chord_pct:.0f}%{chord_warn}{pend_note}")
    print(f"    Chord sizes: {size_str if size_str else 'none'}")
    print(f"    Consonance: {consonance:.0f}%{cons_warn}")
    print(f"    Top intervals: {top_ivl_str}")

    chord_q = score_chord_quality(chord_info, lh_pct)
    if chord_pct < thresh['chord_pct_min'] and not is_pendulum: flags.append(f'FEW-CHORDS: {chord_pct:.0f}%')
    if consonance < 60 and chord_pct > 10:  flags.append(f'DISSONANT: {consonance:.0f}% consonant')

    metrics['chord_q']  = chord_q
    metrics['chord_pct']= chord_pct

    # ── 5. Dynamic arc (especially AMB-PNO-003) ────────────────────────────
    print(f"\n  [DYNAMIC ARC]")
    vel_thirds, arc_score = velocity_arc(lead1, tpq, total_bars)
    if vel_thirds:
        t1, t2, t3 = vel_thirds
        arc_str = f"{t1:.0f} → {t2:.0f} → {t3:.0f}"
        arc_shape = ('▲' if t2 > t1 else '▼') + ('▼' if t3 < t2 else '▲')
        print(f"    Velocity by third: {arc_str}  shape={arc_shape}  arc_score={arc_score}/2")
        if piano_rule == 'AMB-PNO-003' and arc_score < 1:
            flags.append('FLAT-ARC: velocity does not rise and fall (AMB-PNO-003)')
    else:
        print(f"    (no notes)")

    # ── Summary scores ────────────────────────────────────────────────────
    print(f"\n  [SCORES]")
    print(f"    Lyricism:     {lyricism_score:4.1f}/10")
    print(f"    Chord quality:{chord_q:4.1f}/10")
    overall = round((lyricism_score + chord_q) / 2, 1)
    print(f"    Overall:      {overall:4.1f}/10")
    metrics['overall'] = overall

    if flags:
        print(f"\n  *** ISSUES ***")
        for f in flags:
            print(f"    !! {f}")
    else:
        print(f"\n  ✓ No issues")

    return flags, metrics, piano_rule

# ── Summary ───────────────────────────────────────────────────────────────────

def main():
    files = sys.argv[1:] or sorted(f for f in os.listdir('.') if f.endswith('.MID'))
    if not files:
        print("No .MID files found."); sys.exit(1)

    print(f"\nAmbient Piano Quality Analysis — {len(files)} songs")

    all_flags  = []
    all_metrics = []
    by_rule = collections.defaultdict(list)

    for path in sorted(files):
        flags, metrics, rule = analyze_file(path)
        all_flags.extend(flags)
        all_metrics.append(metrics)
        by_rule[rule].append(metrics)

    # ── Cross-song summary ────────────────────────────────────────────────
    print(f"\n{'═'*68}")
    print(f"CROSS-SONG SUMMARY  ({len(files)} songs)")
    print()

    if all_metrics:
        avg = lambda key: sum(m.get(key, 0) for m in all_metrics) / len(all_metrics)
        print(f"  Overall score:   {avg('overall'):.1f}/10  (target ≥6.0)")
        print(f"  Lyricism:        {avg('lyricism'):.1f}/10  (target ≥5.0)")
        print(f"  Chord quality:   {avg('chord_q'):.1f}/10  (target ≥5.0)")
        print(f"  Density:         {avg('npb'):.1f} n/bar")
        print(f"  LH bass share:   {avg('lh_pct'):.0f}%   (target 15-50%)")
        print(f"  Stepwise ratio:  {avg('stepwise')*100:.0f}%  (target ≥25%)")
        print()

    # Per-rule breakdown
    for rule in ['AMB-PNO-001', 'AMB-PNO-002', 'AMB-PNO-003']:
        ms = by_rule.get(rule, [])
        if not ms: continue
        label = RULE_LABEL.get(rule, rule)
        avg_r = lambda key: sum(m.get(key,0) for m in ms)/len(ms)
        print(f"  {label}  ({len(ms)} songs)")
        print(f"    Overall={avg_r('overall'):.1f}  Lyricism={avg_r('lyricism'):.1f}  "
              f"Chords={avg_r('chord_q'):.1f}  n/bar={avg_r('npb'):.1f}  "
              f"LH={avg_r('lh_pct'):.0f}%  Step={avg_r('stepwise')*100:.0f}%")
        print()

    # Issue counts
    print(f"  Issues across all songs:")
    if all_flags:
        counts = collections.Counter(f.split(':')[0] for f in all_flags)
        for issue, count in counts.most_common():
            print(f"    {issue:<35} {count} occurrence(s)")
    else:
        print(f"    ✓ All songs passed")

if __name__ == '__main__':
    main()

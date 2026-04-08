#!/usr/bin/env python3
"""
ambient_analyze.py — Ambient MIDI quality analyzer.

Usage:
    cd tools/batch-output/ambient
    python3 ../../ambient_analyze.py *.MID

For each .MID file it looks for a matching .zudio log (same base name).
Reports per song:
  1. Tonal clash (Ambient-specific thresholds)
  2. Note density (Ambient-specific low ceilings)
  3. Silence distribution (HOLLOW, LEAD-DEADZONE)
  4. Register ranges and collision (REGISTER-CLASH, TEXTURE-CLASH)
  5. Loop length health (LOOP-DUPLICATE, LOOP-UNDERCYCLE)
  6. 4-bar density crowding (CROWDED, RELENTLESS)
  7. Monotone / single-pitch detection (MONOTONE, SINGLE-PITCH)
"""

import struct, os, sys, re, collections

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
}

TRACK_ORDER = ['Lead 1', 'Lead Solo Vox', 'Pads', 'Rhythm', 'Texture', 'Bass', 'Drums']
PITCHED_TRACKS = [t for t in TRACK_ORDER if t != 'Drums']

# Ambient tonal clash thresholds
CLASH_THRESHOLDS = {
    'Bass':          5,
    'Pads':         10,
    'Rhythm':       20,
    'Lead 1':       20,
    'Lead Solo Vox':20,
    'Texture':      35,
    'Drums':        None,
}

# Ambient density ceilings (notes/bar) — much lower than Motorik
DENSITY_CEILINGS = {
    'Lead 1':        3.0,
    'Lead Solo Vox': 3.0,
    'Pads':          4.0,
    'Rhythm':        2.0,
    'Bass':          2.0,
    'Texture':       2.0,
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
            elif cmd in (0xA0, 0xB0, 0xE0):
                tpos += 2
            elif cmd == 0xC0:
                tpos += 1
        for (ch, note), (st, sv) in active.items():
            notes.append((st, note, sv, tick - st))
        tracks.append({'name': name, 'notes': notes})
        pos = tend
    return tracks, tpq

# ── .zudio log parser ─────────────────────────────────────────────────────────

def parse_log(path):
    info = {'key': None, 'mode': None, 'tempo': None, 'bars': None,
            'sections': [], 'rules': [], 'loop_lengths': {}}
    try:
        lines = open(path).readlines()
    except FileNotFoundError:
        return info

    in_structure = False
    in_loop      = False
    for line in lines:
        s = line.rstrip()
        m = re.match(r'Key:\s+(\S+)\s+(\S+)', s)
        if m: info['key'] = m.group(1); info['mode'] = m.group(2)
        m = re.match(r'Tempo:\s+(\d+)', s)
        if m: info['tempo'] = int(m.group(1))
        m = re.match(r'Bars:\s+(\d+)', s)
        if m: info['bars'] = int(m.group(1))
        if '--- Structure ---' in s:
            in_structure = True; in_loop = False; continue
        if in_structure:
            if '--- ' in s and 'Structure' not in s:
                in_structure = False
            elif 'Loop lengths' in s:
                in_loop = True
            elif in_loop:
                m = re.match(r'\s+(Lead 1|Lead 2|Lead Solo Vox|Pads|Bass|Rhythm|Texture):\s+(\d+)', s)
                if m:
                    info['loop_lengths'][m.group(1)] = int(m.group(2))
                elif s.strip() == '':
                    in_loop = False
            elif s.startswith('  ') and s.strip():
                m = re.match(r'\s+(\w+)\s+Bars\s+(\d+)[–\-]\s*(\d+)', s)
                if m:
                    info['sections'].append({
                        'label': m.group(1).lower(),
                        'start': int(m.group(2)),
                        'end':   int(m.group(3)),
                    })
        m = re.match(r'\s+(AMB-\S+)\s', s)
        if m: info['rules'].append(m.group(1))
    return info

# ── Analysis helpers ──────────────────────────────────────────────────────────

def tonal_clash(notes, key_st, mode_str):
    if not notes or mode_str not in SCALE_INTERVALS:
        return 0.0, []
    scale = set((key_st + i) % 12 for i in SCALE_INTERVALS[mode_str])
    clashes = [n for (_, n, _, _) in notes if (n % 12) not in scale]
    pct = len(clashes) / len(notes)
    names = collections.Counter(note_name(n) for n in clashes)
    return pct, [f"{k}×{v}" for k, v in names.most_common(3)]

def actual_range(notes):
    if not notes: return None, None
    pitches = [n for (_, n, _, _) in notes]
    return min(pitches), max(pitches)

def notes_per_bar(notes, total_bars, tpq):
    if not notes or not total_bars: return 0.0
    return len(notes) / total_bars

def body_bars_list(sections, total_bars):
    """Returns sorted list of 1-based body bar numbers."""
    body = [s for s in sections if s['label'] not in ('intro', 'outro')]
    if not body:
        return list(range(1, total_bars + 1))
    bars = []
    for s in body:
        bars.extend(range(s['start'], s['end'] + 1))
    return sorted(set(bars))

# ── Section 1+2: Clash and Density ───────────────────────────────────────────

def check_clash_density(track_map, tpq, key_st, mode_str, total_bars, flags):
    print("  [TONAL CLASH & DENSITY]")
    tpb = tpq * 4
    for tname in TRACK_ORDER:
        notes = track_map.get(tname, [])
        if not notes: continue
        thresh = CLASH_THRESHOLDS.get(tname)
        if thresh is None:
            print(f"    {tname:<16} drums — skip")
            continue
        pct, top = tonal_clash(notes, key_st, mode_str)
        pct100 = pct * 100
        clash_flag = ''
        if pct100 > thresh:
            clash_flag = f'  !!CLASH (>{thresh}%)'
            flags.append(f'CLASH {tname}: {pct100:.1f}%')
        npb = notes_per_bar(notes, total_bars, tpq)
        ceil = DENSITY_CEILINGS.get(tname)
        dense_flag = ''
        if ceil and npb > ceil:
            dense_flag = f'  !!DENSE (>{ceil})'
            flags.append(f'DENSE {tname}: {npb:.1f} n/bar')
        top_str = ', '.join(top) if top else ''
        print(f"    {tname:<16} clash={pct100:4.1f}%  {npb:4.1f} n/bar  {top_str}{clash_flag}{dense_flag}")

# ── Section 3: Silence distribution ──────────────────────────────────────────

def check_silence(track_map, tpq, sections, total_bars, flags, rules=None):
    print()
    print("  [SILENCE DISTRIBUTION]")
    tpb = tpq * 4
    body = body_bars_list(sections, total_bars)
    if not body:
        print("    (no body bars found)")
        return

    # Fully silent bars across all pitched tracks
    bar_has_any = set()
    for tname in PITCHED_TRACKS:
        for (st, _, _, _) in track_map.get(tname, []):
            bar_has_any.add(st // tpb + 1)
    silent_all = sum(1 for b in body if b not in bar_has_any)
    pct_all = silent_all / len(body) * 100
    hollow_flag = '  !!HOLLOW' if pct_all > 40 else ''
    print(f"    Body bars: {len(body)}   Fully silent (all pitched): {silent_all} ({pct_all:.0f}%){hollow_flag}")
    if hollow_flag:
        flags.append(f'HOLLOW: {pct_all:.0f}% body bars fully silent')

    # Total silence — any track (pitched OR drums) with a run > 1 bar
    all_bar_has_any = set()
    for tname in TRACK_ORDER:
        for (st, _, _, _) in track_map.get(tname, []):
            all_bar_has_any.add(st // tpb + 1)
    # Find runs of body bars where nothing plays on any track
    run = 0; run_start = 0; worst_run = 0; worst_start = 0
    for b in body:
        if b not in all_bar_has_any:
            if run == 0: run_start = b
            run += 1
            if run > worst_run:
                worst_run = run; worst_start = run_start
        else:
            run = 0
    if worst_run > 1:
        ts_flag = f'  !!TOTAL-SILENCE'
        print(f"    Total silence (all tracks): longest run = {worst_run} bars (bars {worst_start}–{worst_start+worst_run-1}){ts_flag}")
        flags.append(f'TOTAL-SILENCE: {worst_run}-bar run from bar {worst_start}')
    else:
        status = f"longest run = {worst_run} bar" if worst_run == 1 else "none"
        print(f"    Total silence (all tracks): {status}   ok")

    # Lead 1 longest gap
    lead_notes = track_map.get('Lead 1', [])
    if lead_notes:
        lead_bars = set(st // tpb + 1 for (st, _, _, _) in lead_notes)
        max_gap = 0; gap = 0; gap_start = 0; best_start = 0
        for b in body:
            if b not in lead_bars:
                if gap == 0: gap_start = b
                gap += 1
                if gap > max_gap:
                    max_gap = gap; best_start = gap_start
            else:
                gap = 0
        is_section_solo = rules and ('AMB-LEAD-009' in rules or 'AMB-LEAD-010' in rules)
        dz_flag = '  !!LEAD-DEADZONE' if max_gap > 20 and not is_section_solo else ''
        solo_note = '  (section solo — expected)' if max_gap > 20 and is_section_solo else ''
        print(f"    Lead 1 longest gap: {max_gap} bars (from bar {best_start}){dz_flag}{solo_note}")
        if dz_flag:
            flags.append(f'LEAD-DEADZONE: {max_gap}-bar gap from bar {best_start}')

# ── Section 4: Register collision ─────────────────────────────────────────────

def check_register(track_map, flags):
    print()
    print("  [REGISTER]")
    ranges = {}
    for tname in TRACK_ORDER:
        notes = track_map.get(tname, [])
        if not notes: continue
        lo, hi = actual_range(notes)
        ranges[tname] = (lo, hi)
        print(f"    {tname:<16} MIDI {lo}–{hi}  ({note_name(lo)}–{note_name(hi)})")

    def overlap(r1, r2):
        if not r1 or not r2: return 0, 0, 0
        lo = max(r1[0], r2[0]); hi = min(r1[1], r2[1])
        if hi < lo: return 0, 0, 0
        span = hi - lo
        span1 = max(1, r1[1] - r1[0]); span2 = max(1, r2[1] - r2[0])
        return span, span / span1 * 100, span / span2 * 100

    print()
    bass_r  = ranges.get('Bass')
    lead1_r = ranges.get('Lead 1')
    if bass_r and lead1_r:
        span, pct1, _ = overlap(bass_r, lead1_r)
        flag = '  !!REGISTER-CLASH' if bass_r[1] >= lead1_r[0] else ''
        print(f"    Bass ∩ Lead 1:      {span} semitone overlap{flag}")
        if flag: flags.append('REGISTER-CLASH Bass/Lead1')

    tex_r = ranges.get('Texture')
    for other in ['Lead 1', 'Pads', 'Rhythm']:
        other_r = ranges.get(other)
        if tex_r and other_r:
            span, pct_tex, pct_other = overlap(tex_r, other_r)
            # Flag if overlap covers >75% of the smaller track's range
            smaller_pct = min(pct_tex, pct_other)
            flag = '  !!TEXTURE-CLASH' if smaller_pct > 75 else ''
            print(f"    Texture ∩ {other:<10} {span} semitones ({smaller_pct:.0f}% of smaller range){flag}")
            if flag: flags.append(f'TEXTURE-CLASH Texture/{other}')

# ── Section 5: Loop length health ─────────────────────────────────────────────

def check_loops(loop_lengths, total_bars, flags):
    print()
    print("  [LOOP LENGTHS]")
    if not loop_lengths:
        print("    (not present — non-Ambient or all tracks silent)")
        return

    for tname, length in sorted(loop_lengths.items()):
        cycles = total_bars / length if length else 0
        print(f"    {tname:<16} {length} bars  →  {cycles:.1f} cycles")

    # Duplicate check
    counts = collections.Counter(loop_lengths.values())
    dups = {length: [t for t, l in loop_lengths.items() if l == length]
            for length, cnt in counts.items() if cnt > 1}
    if dups:
        for length, tracks in dups.items():
            msg = f'LOOP-DUPLICATE: {" and ".join(tracks)} both = {length} bars'
            print(f"    !!{msg}")
            flags.append(msg)
    else:
        print(f"    Duplicates: none   ok")

    # Undercycle check
    for tname, length in loop_lengths.items():
        if total_bars and length > total_bars / 3:
            msg = f'LOOP-UNDERCYCLE: {tname} = {length} bars, only {total_bars/length:.1f} cycles'
            print(f"    !!{msg}")
            flags.append(msg)

# ── Section 6: 4-bar density crowding ─────────────────────────────────────────

def check_4bar_crowding(track_map, tpq, sections, total_bars, flags):
    print()
    print("  [4-BAR DENSITY]")
    tpb = tpq * 4
    body = body_bars_list(sections, total_bars)
    if not body:
        print("    (no body bars)")
        return

    # Build 4-bar windows from body bars
    min_bar = body[0]; max_bar = body[-1]
    windows = list(range(min_bar, max_bar + 1, 4))

    # Active non-drum tracks
    active_tracks = [t for t in PITCHED_TRACKS if track_map.get(t)]
    n_active = len(active_tracks)

    if n_active == 0:
        print("    (no active pitched tracks)")
        return

    # Per-window active track count
    crowded_windows = []
    per_track_counts = {t: 0 for t in active_tracks}

    for w in windows:
        w_end = w + 4
        w_lo = (w - 1) * tpb
        w_hi = (w_end - 1) * tpb
        firing = []
        for tname in active_tracks:
            has_note = any(w_lo <= st < w_hi for (st, _, _, _) in track_map[tname])
            if has_note:
                per_track_counts[tname] += 1
                firing.append(tname)
        if len(firing) == n_active:
            crowded_windows.append(w)

    n_windows = len(windows)
    crowded_pct = len(crowded_windows) / n_windows * 100 if n_windows else 0
    crowded_flag = '  !!CROWDED' if crowded_windows else ''
    print(f"    Active pitched tracks: {n_active}   Windows: {n_windows}")
    print(f"    All-tracks-firing windows: {len(crowded_windows)} / {n_windows}  ({crowded_pct:.0f}%){crowded_flag}")
    if crowded_windows:
        print(f"    Example: bars {crowded_windows[0]}–{crowded_windows[0]+3}")
        flags.append(f'CROWDED: {len(crowded_windows)} windows with all {n_active} tracks firing')

    # Relentless check
    print()
    for tname in active_tracks:
        cnt = per_track_counts[tname]
        pct = cnt / n_windows * 100 if n_windows else 0
        relentless_flag = '  !!RELENTLESS' if cnt == n_windows else ''
        print(f"    {tname:<16} {cnt}/{n_windows} windows active ({pct:.0f}%){relentless_flag}")
        if relentless_flag:
            flags.append(f'RELENTLESS: {tname} active in every 4-bar window')

# ── Section 7: Monotone / single-pitch ────────────────────────────────────────

def check_monotone(track_map, tpq, total_bars, flags):
    print()
    print("  [MONOTONE / SINGLE-PITCH]")
    tpb = tpq * 4

    for tname in PITCHED_TRACKS:
        notes = track_map.get(tname, [])
        if not notes: continue

        # Bar fingerprints: frozenset of (step_in_bar, pitch, duration_bucket)
        bar_fp = collections.defaultdict(list)
        for (st, note, vel, dur) in notes:
            bar  = st // tpb
            step = (st % tpb) * 16 // tpb   # 0–15
            dur_bucket = min(dur // (tpb // 4), 7)  # coarse duration bucket
            bar_fp[bar].append((step, note, dur_bucket))

        fingerprints = {b: frozenset(v) for b, v in bar_fp.items()}
        distinct_fps  = len(set(fingerprints.values()))
        distinct_pitches = len(set(n for (_, n, _, _) in notes))

        mono_flag   = '  !!MONOTONE'    if distinct_fps    == 1 else ''
        pitch_flag  = '  !!SINGLE-PITCH' if distinct_pitches == 1 else ''

        print(f"    {tname:<16} {distinct_fps} distinct bar patterns   {distinct_pitches} distinct pitches{mono_flag}{pitch_flag}")
        if mono_flag:
            flags.append(f'MONOTONE: {tname} has only 1 bar pattern')
        if pitch_flag:
            flags.append(f'SINGLE-PITCH: {tname} uses only 1 pitch')

# ── Main ──────────────────────────────────────────────────────────────────────

def analyze_file(midi_path):
    base     = os.path.splitext(midi_path)[0]
    log_path = base + '.zudio'
    fname    = os.path.basename(midi_path)

    tracks, tpq = parse_midi(midi_path)
    log = parse_log(log_path)
    has_log = log['key'] is not None

    key_st   = KEY_ST.get(log['key'], 0) if has_log else 0
    mode_str = log['mode'] if has_log else 'Dorian'
    tempo    = log['tempo'] or 80

    track_map  = {t['name']: t['notes'] for t in tracks}
    total_bars = log['bars'] or max(
        (st // (tpq * 4) + 1 for notes in track_map.values() for (st, _, _, _) in notes),
        default=1
    )

    print(f"\n{'═'*64}")
    print(f"  {fname}")
    if has_log:
        rules_str = ', '.join(log['rules'][:6])
        print(f"  {log['key']} {mode_str}  {tempo} BPM  {total_bars} bars")
        print(f"  Rules: {rules_str}")
    print()

    flags = []

    check_clash_density(track_map, tpq, key_st, mode_str, total_bars, flags)
    check_silence(track_map, tpq, log['sections'], total_bars, flags, rules=log['rules'])
    check_register(track_map, flags)
    check_loops(log['loop_lengths'], total_bars, flags)
    check_4bar_crowding(track_map, tpq, log['sections'], total_bars, flags)
    check_monotone(track_map, tpq, total_bars, flags)

    if flags:
        print()
        print("  *** ISSUES ***")
        for f in flags:
            print(f"    !! {f}")
    else:
        print()
        print("  ✓ No issues")

    return flags

def main():
    files = sys.argv[1:] or sorted(f for f in os.listdir('.') if f.endswith('.MID'))
    if not files:
        print("No .MID files found.")
        sys.exit(1)

    print(f"\nAmbient Quality Analysis — {len(files)} songs")

    all_flags = []
    for path in sorted(files):
        f = analyze_file(path)
        all_flags.extend(f)

    print(f"\n{'═'*64}")
    print(f"SUMMARY: {len(files)} songs analyzed")
    if all_flags:
        counts = collections.Counter(f.split(':')[0] for f in all_flags)
        for issue, count in counts.most_common():
            print(f"  {issue:<30} {count} occurrence(s)")
    else:
        print("  ✓ All songs passed")

if __name__ == '__main__':
    main()

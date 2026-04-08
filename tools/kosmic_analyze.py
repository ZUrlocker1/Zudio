#!/usr/bin/env python3
"""
kosmic_analyze.py — Kosmic MIDI register overlap, simultaneous density, and tonal clash analyzer.

Usage:
    cd tools/batch-output/kosmic
    python3 ../../kosmic_analyze.py *.MID

For each .MID file it looks for a matching .zudio log (same base name).
Reports:
  - Tonal clash per track (Kosmic-specific thresholds)
  - Register overlap between track pairs
  - Simultaneous note density (polyphony peaks)
  - Per-section density (A vs B arc)
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

# Kosmic-specific tonal clash thresholds (tighter than generic 20%)
CLASH_THRESHOLDS = {
    'Bass':      5,
    'Pads':      8,
    'Rhythm':   12,   # Arpeggio — some passing tones OK
    'Lead 1':   15,
    'Lead 2':   15,
    'Texture':  25,   # Intentional chromatic content
    'Drums':    None, # Skip
    'Lead Synth': 15,
}

# Expected MIDI note ranges per track (from code analysis)
EXPECTED_RANGES = {
    'Bass':     (40, 55),
    'Texture':  (33, 59),
    'Rhythm':   (55, 72),
    'Pads':     (36, 72),
    'Lead 2':   (55, 80),
    'Lead 1':   (60, 96),
    'Lead Synth': (60, 96),
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
        # Close any hanging notes
        for (ch, note), (st, sv) in active.items():
            notes.append((st, note, sv, tick - st))
        tracks.append({'name': name, 'notes': notes})
        pos = tend
    return tracks, tpq

# ── .zudio log parser ─────────────────────────────────────────────────────────

def parse_log(path):
    info = {'key': None, 'mode': None, 'tempo': None, 'sections': [], 'rules': []}
    try:
        with open(path) as f:
            lines = f.readlines()
    except FileNotFoundError:
        return info

    in_structure = False
    for line in lines:
        line = line.rstrip()
        m = re.match(r'Key:\s+(\S+)\s+(\S+)', line)
        if m: info['key'] = m.group(1); info['mode'] = m.group(2)
        m = re.match(r'Tempo:\s+(\d+)', line)
        if m: info['tempo'] = int(m.group(1))
        if '--- Structure ---' in line:
            in_structure = True; continue
        if in_structure:
            if line.startswith('  ') and line.strip():
                m = re.match(r'\s+(\w+)\s+Bars\s+(\d+)[–-]\s*(\d+)', line)
                if m:
                    info['sections'].append({
                        'label': m.group(1),
                        'start': int(m.group(2)),
                        'end':   int(m.group(3)),
                    })
            else:
                in_structure = False
        # Rules
        m = re.match(r'\s+(KOS-\S+)\s', line)
        if m: info['rules'].append(m.group(1))
    return info

# ── Analysis functions ────────────────────────────────────────────────────────

def tonal_clash(notes, key_st, mode_str):
    """Returns clash fraction (0.0–1.0) and list of clashing note names."""
    if not notes or mode_str not in SCALE_INTERVALS:
        return 0.0, []
    scale = set((key_st + i) % 12 for i in SCALE_INTERVALS[mode_str])
    clashes = [n for (_, n, _, _) in notes if (n % 12) not in scale]
    pct = len(clashes) / len(notes)
    clash_names = collections.Counter(note_name(n) for n in clashes)
    top = [f"{k}×{v}" for k, v in clash_names.most_common(3)]
    return pct, top

def actual_range(notes):
    """Returns (min_note, max_note) actually used."""
    if not notes: return None, None
    pitches = [n for (_, n, _, _) in notes]
    return min(pitches), max(pitches)

def range_overlap_pct(r1, r2):
    """Fraction of r1's range that overlaps with r2. Returns 0.0–1.0."""
    if r1[0] is None or r2[0] is None: return 0.0
    lo = max(r1[0], r2[0])
    hi = min(r1[1], r2[1])
    if hi < lo: return 0.0
    span1 = r1[1] - r1[0]
    if span1 == 0: return 0.0
    return (hi - lo) / span1

def simultaneous_density(tracks_notes, tpq):
    """
    Returns:
      - max simultaneous tracks active at any tick
      - max simultaneous notes at any tick
      - average simultaneous notes per beat
      - list of (tick, count) for peaks > 4 tracks
    """
    # Build event list: (tick, +1 or -1, track_idx)
    events = []
    for ti, notes in enumerate(tracks_notes):
        for (start, note, vel, dur) in notes:
            events.append((start,    +1, ti))
            events.append((start+dur, -1, ti))
    events.sort()

    active_tracks = set()
    active_notes  = 0
    max_tracks    = 0
    max_notes     = 0
    peaks = []  # (tick, n_tracks) where n_tracks > 4

    i = 0
    while i < len(events):
        tick = events[i][0]
        # Process all events at this tick
        while i < len(events) and events[i][0] == tick:
            _, delta, ti = events[i]
            if delta == +1:
                active_tracks.add(ti)
                active_notes += 1
            else:
                active_tracks.discard(ti)
                active_notes = max(0, active_notes - 1)
            i += 1
        n = len(active_tracks)
        if n > max_tracks: max_tracks = n
        if active_notes > max_notes: max_notes = active_notes
        if n > 4:
            peaks.append((tick, n))

    return max_tracks, max_notes, peaks

def bar_from_tick(tick, tpq):
    """1-based bar number from tick (assuming 4/4, tpq = ticks per quarter)."""
    ticks_per_bar = tpq * 4
    return tick // ticks_per_bar + 1

def section_density(notes, sections, tpq, total_bars):
    """Returns dict of label → notes_per_bar."""
    ticks_per_bar = tpq * 4
    result = {}
    for sec in sections:
        lo = (sec['start'] - 1) * ticks_per_bar
        hi = sec['end'] * ticks_per_bar
        count = sum(1 for (st, _, _, _) in notes if lo <= st < hi)
        bars = sec['end'] - sec['start'] + 1
        result[sec['label']] = count / max(1, bars)
    return result

# ── New analysis functions ────────────────────────────────────────────────────

def repetition_runs(track_map, tpq):
    """
    For each pitched track, compute a per-bar fingerprint = frozenset of
    (step_position % 16, pitch_class) tuples. Find the longest run of
    consecutive bars with identical fingerprints.
    Returns list of (track_name, longest_run, run_start_bar, all_fingerprints).
    """
    ticks_per_bar  = tpq * 4
    ticks_per_step = tpq // 4  # 16th-note resolution

    results = []
    for tname in TRACK_ORDER:
        if tname == 'Drums': continue
        notes = track_map.get(tname, [])
        if not notes: continue

        # Group notes by bar
        bar_fp = collections.defaultdict(list)
        for (start, note, vel, dur) in notes:
            bar = start // ticks_per_bar  # 0-based
            step = (start % ticks_per_bar) // max(1, ticks_per_step)
            bar_fp[bar].append((step % 16, note % 12))

        if not bar_fp: continue
        bars = sorted(bar_fp.keys())
        fingerprints = {b: frozenset(bar_fp[b]) for b in bars}

        # Find longest run of consecutive identical fingerprints
        best_run = 1; best_start = bars[0]
        cur_run  = 1; cur_start  = bars[0]
        for i in range(1, len(bars)):
            if bars[i] == bars[i-1] + 1 and fingerprints[bars[i]] == fingerprints[bars[i-1]]:
                cur_run += 1
                if cur_run > best_run:
                    best_run = cur_run; best_start = cur_start
            else:
                cur_run  = 1; cur_start = bars[i]

        distinct = len(set(fingerprints.values()))
        results.append((tname, best_run, best_start + 1, distinct, len(bars)))

    return results

# Thresholds for REP-LONG flag
REP_LONG_THRESH = {
    'Rhythm': 4,
    'Lead 1': 5,
    'Lead 2': 3,
    'Lead Solo Vox': 3,
    'Bass':   8,
    'Pads':   8,
    'Texture':8,
    'Lead Synth': 3,
}

def activity_timeline(track_map, tpq, total_bars):
    """
    Compute which 8-bar windows contain at least one note per track.
    Returns (grid dict, flags list).
    grid: track_name → list of chars ('▓','▒','·') per window.
    """
    ticks_per_bar = tpq * 4
    windows = list(range(0, total_bars, 8))  # 0-based bar starts
    grid = {}

    for tname in TRACK_ORDER:
        if tname == 'Drums': continue
        notes = track_map.get(tname, [])
        row = []
        for w in windows:
            lo = w * ticks_per_bar
            hi = (w + 8) * ticks_per_bar
            active = [n for n in notes if lo <= n[0] < hi]
            if not active:
                row.append('·')
            elif len(active) >= 3:
                row.append('▓')
            else:
                row.append('▒')
        if notes:
            grid[tname] = row

    flags = []
    # NO-STAGGER: all pitched tracks with notes active from window 0 simultaneously
    active_at_0 = [t for t, row in grid.items() if row and row[0] == '▓']
    if len(active_at_0) >= 5:
        flags.append(f'NO-STAGGER: {len(active_at_0)} tracks all active from bar 1')

    # NO-GAPS: any lead/rhythm track active in every window
    for tname, row in grid.items():
        if tname in ('Bass', 'Pads', 'Lead Synth'): continue  # drones expected
        if row and all(c != '·' for c in row):
            flags.append(f'NO-GAPS {tname}: never silent in any 8-bar window')

    return grid, windows, flags

def silence_ratio(track_map, sections, tpq):
    """
    For each track, count body (non-intro/outro) bars with zero notes.
    Returns list of (track_name, silent_bars, total_body_bars, silent_pct).
    """
    ticks_per_bar = tpq * 4
    body_secs = [s for s in sections if s['label'] not in ('intro', 'outro')]
    if not body_secs:
        # Fallback: use all sections
        body_secs = sections

    body_bars = []
    for s in body_secs:
        for b in range(s['start'], s['end'] + 1):
            body_bars.append(b)  # 1-based

    results = []
    for tname in TRACK_ORDER:
        if tname == 'Drums': continue
        notes = track_map.get(tname, [])
        if not notes: continue

        note_bars = set()
        for (start, note, vel, dur) in notes:
            b = start // ticks_per_bar + 1  # 1-based
            note_bars.add(b)

        silent = sum(1 for b in body_bars if b not in note_bars)
        total  = len(body_bars)
        pct    = (silent / total * 100) if total else 0
        results.append((tname, silent, total, pct))

    return results

BREATHLESS_THRESH = {
    'Rhythm':       5,
    'Lead 1':      10,
    'Lead 2':       5,
    'Lead Solo Vox':5,
    'Lead Synth':  10,
}

# ── Main ──────────────────────────────────────────────────────────────────────

TRACK_ORDER = ['Lead 1', 'Lead 2', 'Pads', 'Rhythm', 'Texture', 'Bass', 'Drums', 'Lead Synth']

def analyze_file(midi_path):
    base   = os.path.splitext(midi_path)[0]
    log_path = base + '.zudio'
    fname  = os.path.basename(midi_path)

    tracks, tpq = parse_midi(midi_path)
    log = parse_log(log_path)
    has_log = log['key'] is not None

    key_st   = KEY_ST.get(log['key'], 0) if has_log else 0
    mode_str = log['mode'] if has_log else 'Dorian'
    tempo    = log['tempo'] or 100

    # Map tracks by name
    track_map = {t['name']: t['notes'] for t in tracks}

    print(f"\n{'─'*60}")
    print(f"  {fname}")
    if has_log:
        print(f"  Key: {log['key']} {mode_str}  Tempo: {tempo} BPM  Rules: {', '.join(log['rules'][:4])}")
    print()

    flags = []

    # ── 1. Tonal clash ────────────────────────────────────────────────────────
    print("  [TONAL CLASH]")
    for tname in TRACK_ORDER:
        notes = track_map.get(tname, [])
        if not notes: continue
        thresh = CLASH_THRESHOLDS.get(tname)
        if thresh is None:
            print(f"    {tname:<14} skip (drums)")
            continue
        if not has_log:
            print(f"    {tname:<14} no log")
            continue
        pct, top = tonal_clash(notes, key_st, mode_str)
        pct100 = pct * 100
        flag = ''
        if pct100 > thresh:
            flag = f'  !! CLASH (threshold ≤{thresh}%)'
            flags.append(f'CLASH {tname}: {pct100:.1f}%')
        top_str = ', '.join(top) if top else ''
        print(f"    {tname:<14} {pct100:5.1f}%  {top_str}{flag}")

    # ── 2. Register overlap ───────────────────────────────────────────────────
    print()
    print("  [REGISTER RANGES & OVERLAP]")
    ranges = {}
    for tname in TRACK_ORDER:
        notes = track_map.get(tname, [])
        if not notes: continue
        lo, hi = actual_range(notes)
        ranges[tname] = (lo, hi)
        exp = EXPECTED_RANGES.get(tname)
        exp_str = f"expected {exp[0]}–{exp[1]}" if exp else ""
        print(f"    {tname:<14} actual {lo}–{hi}  ({note_name(lo)}–{note_name(hi)})  {exp_str}")

    # Check key pairs for overlap
    print()
    print("  [OVERLAP BETWEEN TRACK PAIRS]")
    pairs = [
        ('Rhythm', 'Pads',    70, "arpeggio/pads mid-range collision"),
        ('Rhythm', 'Texture', 60, "arpeggio/texture collision"),
        ('Pads',   'Bass',    50, "pads reaching into bass territory"),
        ('Texture','Bass',    60, "texture/bass collision"),
        ('Lead 2', 'Lead 1',  60, "leads competing in same register"),
    ]
    for t1, t2, thresh, desc in pairs:
        r1 = ranges.get(t1)
        r2 = ranges.get(t2)
        if not r1 or not r2: continue
        ov = range_overlap_pct(r1, r2) * 100
        flag = ''
        if ov > thresh:
            flag = f'  !! REGISTER-CLASH ({desc})'
            flags.append(f'REGISTER-CLASH {t1}/{t2}: {ov:.0f}%')
        print(f"    {t1:<14} ∩ {t2:<14} {ov:5.1f}% overlap{flag}")

    # ── 3. Simultaneous density ───────────────────────────────────────────────
    print()
    print("  [SIMULTANEOUS DENSITY]")
    pitched_tracks = [track_map.get(t, []) for t in TRACK_ORDER if t != 'Drums']
    max_tracks, max_notes, peaks = simultaneous_density(pitched_tracks, tpq)

    flag_tracks = '  !! DENSE-TRACKS' if max_tracks > 5 else ''
    flag_notes  = '  !! DENSE-PEAK'   if max_notes  > 12 else ''
    print(f"    Max simultaneous tracks: {max_tracks}{flag_tracks}")
    print(f"    Max simultaneous notes:  {max_notes}{flag_notes}")
    if peaks:
        # Group into bars and report worst bars
        bar_peaks = collections.Counter()
        for (tick, n) in peaks:
            bar_peaks[bar_from_tick(tick, tpq)] = max(bar_peaks[bar_from_tick(tick, tpq)], n)
        worst = bar_peaks.most_common(5)
        print(f"    Bars with >4 simultaneous tracks: {[f'bar {b}={n}' for b,n in worst]}")
        if max_tracks > 5:
            flags.append(f'DENSE-TRACKS peak={max_tracks}')
    if max_notes > 12:
        flags.append(f'DENSE-PEAK notes={max_notes}')

    # ── 4. Section arc (A vs B density) ──────────────────────────────────────
    print()
    print("  [SECTION ARC — notes/bar]")
    if log['sections']:
        a_sections = [s for s in log['sections'] if s['label'] == 'A']
        b_sections = [s for s in log['sections'] if s['label'] == 'B']

        total_notes = []
        for tname in TRACK_ORDER:
            if tname == 'Drums': continue
            total_notes += track_map.get(tname, [])

        def section_npb(secs, all_notes, tpq):
            if not secs: return 0
            tpb = tpq * 4
            total_bars = sum(s['end'] - s['start'] + 1 for s in secs)
            count = 0
            for s in secs:
                lo = (s['start'] - 1) * tpb
                hi = s['end'] * tpb
                count += sum(1 for (st,_,_,_) in all_notes if lo <= st < hi)
            return count / max(1, total_bars)

        a_npb = section_npb(a_sections, total_notes, tpq)
        b_npb = section_npb(b_sections, total_notes, tpq)

        flag = ''
        if b_npb <= a_npb:
            flag = '  !! NO-BUILDUP'
            flags.append(f'NO-BUILDUP A={a_npb:.1f} B={b_npb:.1f}')
        print(f"    A sections: {a_npb:.1f} notes/bar (all pitched tracks combined)")
        print(f"    B sections: {b_npb:.1f} notes/bar{flag}")

        # Per-track breakdown
        print(f"    {'Track':<14}  {'A npb':>6}  {'B npb':>6}")
        for tname in TRACK_ORDER:
            if tname == 'Drums': continue
            notes = track_map.get(tname, [])
            if not notes: continue
            a = section_npb(a_sections, notes, tpq)
            b = section_npb(b_sections, notes, tpq)
            marker = ' <' if b > a * 1.2 else ''
            print(f"    {tname:<14}  {a:6.1f}  {b:6.1f}{marker}")
    else:
        print("    (no section data in log)")

    # ── 5. Repetition detection ───────────────────────────────────────────────
    print()
    print("  [REPETITION — longest identical bar run]")
    rep_results = repetition_runs(track_map, tpq)
    for (tname, best_run, run_start, distinct, total_track_bars) in rep_results:
        thresh = REP_LONG_THRESH.get(tname, 4)
        flag = ''
        if distinct == 1 and total_track_bars > 2:
            flag = '  !! REP-MONOTONE'
            flags.append(f'REP-MONOTONE {tname}')
        elif best_run > thresh:
            flag = '  !! REP-LONG'
            flags.append(f'REP-LONG {tname}: run={best_run}')
        status = 'ok' if not flag else ''
        print(f"    {tname:<18} run={best_run:3d} bars  (from bar {run_start:3d})  distinct={distinct}  {status}{flag}")

    # ── 6. Track activity timeline ────────────────────────────────────────────
    print()
    print("  [LAYERING — active tracks per 8-bar window]")
    total_bars_song = max(s['end'] for s in log['sections']) if log['sections'] else 100
    grid, windows, tl_flags = activity_timeline(track_map, tpq, total_bars_song)

    # Header
    header_bars = ''.join(f"{w+1:>4}" for w in windows)
    print(f"    {'':18} {header_bars}")
    for tname in TRACK_ORDER:
        if tname == 'Drums': continue
        row = grid.get(tname)
        if not row: continue
        cells = ''.join(f"  {c} " for c in row)
        print(f"    {tname:<18} {cells}")
    print("    (▓=active  ▒=partial  ·=silent)")

    for tf in tl_flags:
        flags.append(tf)
        print(f"    !! {tf}")

    # ── 7. Breathing room (silence ratio) ────────────────────────────────────
    print()
    print("  [BREATHING ROOM — % body bars with no notes]")
    sr_results = silence_ratio(track_map, log['sections'], tpq)
    for (tname, silent, total, pct) in sr_results:
        thresh = BREATHLESS_THRESH.get(tname)
        flag = ''
        if thresh is not None and (100 - pct) >= (100 - thresh):
            # silent pct < thresh → track is breathless
            if pct < thresh:
                flag = '  !! BREATHLESS'
                flags.append(f'BREATHLESS {tname}: {pct:.0f}% silent')
        drone_note = ' (drone — expected)' if tname in ('Bass', 'Pads') else ''
        status = 'ok' if not flag else ''
        print(f"    {tname:<18} {silent:4d} / {total:3d} bars silent  ({pct:5.1f}%)  {status}{flag}{drone_note}")

    # ── Summary ───────────────────────────────────────────────────────────────
    if flags:
        print()
        print(f"  FLAGS ({len(flags)}):")
        for f in flags:
            print(f"    !! {f}")
    else:
        print()
        print("  ok — no flags")

    return flags

def main():
    paths = sys.argv[1:] or sorted(f for f in os.listdir('.') if f.upper().endswith('.MID'))
    if not paths:
        print("No .MID files found."); return

    print(f"\n=== KOSMIC QUALITY REPORT ===")
    print(f"{len(paths)} songs\n")

    all_flags = []
    for p in sorted(paths):
        flags = analyze_file(p)
        all_flags.extend(flags)

    print(f"\n{'='*60}")
    print(f"SUMMARY: {len(paths)} songs, {len(all_flags)} total flags")
    if all_flags:
        counts = collections.Counter(f.split(':')[0].split()[0] + ' ' + f.split(':')[0].split()[1]
                                     if len(f.split(':')[0].split()) > 1 else f.split(':')[0]
                                     for f in all_flags)
        for issue, n in counts.most_common():
            print(f"  {n}× {issue}")

if __name__ == '__main__':
    main()

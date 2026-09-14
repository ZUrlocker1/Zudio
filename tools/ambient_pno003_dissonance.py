#!/usr/bin/env python3
"""
ambient_pno003_dissonance.py — Bass-melody dissonance analyzer for Ambient Piano songs.

For each song, merges ALL tracks and checks every bar for:
  - Bass-melody clashes: simultaneous bass (MIDI < 60) + melody (MIDI >= 60) notes
    that form a dissonant interval (minor 2nd = 1 st, tritone = 6 st, major 7th = 11 st)
  - Intra-bass clashes: two bass notes forming a minor 2nd (adjacent semitones),
    e.g. the B2+C3 problem

Also annotates whether each clashing note is in-scale or out-of-scale, so you can
distinguish "in-scale dissonance" (e.g. B+C in G major) from chromatic accidents.

Usage:
  python3 tools/ambient_pno003_dissonance.py tools/batch-output/ambient-pno003/*.MID
  python3 tools/ambient_pno003_dissonance.py tools/batch-output/ambient/*.MID
  python3 tools/ambient_pno003_dissonance.py tools/batch-output/ambient/ambient_16*.MID
"""

import struct, os, sys, re, collections

# ── Note / scale helpers ───────────────────────────────────────────────────────

NOTE_NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']

def note_name(n):
    return NOTE_NAMES[n % 12] + str(n // 12 - 1)

KEY_ST = {
    'C':0, 'C#':1, 'Db':1, 'D':2, 'D#':3, 'Eb':3, 'E':4, 'F':5,
    'F#':6, 'Gb':6, 'G':7, 'G#':8, 'Ab':8, 'A':9, 'A#':10, 'Bb':10, 'B':11,
}

SCALE_INTERVALS = {
    'Ionian':          [0,2,4,5,7,9,11],
    'Dorian':          [0,2,3,5,7,9,10],
    'Mixolydian':      [0,2,4,5,7,9,10],
    'Aeolian':         [0,2,3,5,7,8,10],
    'MinorPentatonic': [0,3,5,7,10],
    'MajorPentatonic': [0,2,4,7,9],
    'Dream':           [0,2,3,5,7,9,10],   # alias Dorian
    'Deep':            [0,2,3,5,7,8,10],   # alias Aeolian
}

# Dissonant intervals (semitones mod 12) that we flag:
#   1  = minor 2nd  (half step — the B+C type clash)
#   6  = tritone    (augmented 4th / diminished 5th)
#   11 = major 7th  (leading-tone clash at the octave boundary)
DISSONANT_IVLS = {1, 6, 11}

IVL_NAME = {
    0:'P1', 1:'m2', 2:'M2', 3:'m3', 4:'M3', 5:'P4',
    6:'TT', 7:'P5', 8:'m6', 9:'M6', 10:'m7', 11:'M7', 12:'Oct',
}

# ── MIDI parser ────────────────────────────────────────────────────────────────

def read_vlq(data, pos):
    val = 0
    while True:
        b = data[pos]; pos += 1
        val = (val << 7) | (b & 0x7F)
        if not (b & 0x80):
            break
    return val, pos

def parse_midi(path):
    with open(path, 'rb') as f:
        data = f.read()
    assert data[0:4] == b'MThd', f"Not a MIDI file: {path}"
    _, _, ntracks, tpq = struct.unpack('>IHHH', data[4:14])
    pos = 14
    tracks = []
    for _ in range(ntracks):
        assert data[pos:pos+4] == b'MTrk'
        tlen = struct.unpack('>I', data[pos+4:pos+8])[0]
        tend = pos + 8 + tlen
        tpos = pos + 8
        tick = 0
        name = f"Track{len(tracks)}"
        notes = []
        active = {}
        running = 0
        while tpos < tend:
            dt, tpos = read_vlq(data, tpos)
            tick += dt
            if tpos >= tend:
                break
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
            elif cmd in (0xA0, 0xB0, 0xE0):
                tpos += 2
            elif cmd == 0xC0:
                tpos += 1
        for (ch, note), (st, sv) in active.items():
            notes.append((st, note, sv, tick - st))
        tracks.append({'name': name, 'notes': notes})
        pos = tend
    return tracks, tpq

# ── Log parser ─────────────────────────────────────────────────────────────────

def parse_log(path):
    info = {'key': None, 'mode': None, 'tempo': None, 'bars': None, 'title': '?'}
    try:
        lines = open(path).readlines()
    except FileNotFoundError:
        return info
    for line in lines:
        s = line.rstrip()
        m = re.match(r'Title:\s+(.+)', s)
        if m:
            info['title'] = m.group(1).strip()
        m = re.match(r'Key:\s+(\S+)\s+(\S+)', s)
        if m:
            info['key'] = m.group(1); info['mode'] = m.group(2)
        m = re.match(r'Tempo:\s+(\d+)', s)
        if m:
            info['tempo'] = int(m.group(1))
        m = re.match(r'Bars:\s+(\d+)', s)
        if m:
            info['bars'] = int(m.group(1))
    return info

# ── Scale membership ───────────────────────────────────────────────────────────

def build_scale_set(key, mode):
    """Return the set of pitch-class ints (0–11) in the given key+mode."""
    key_st = KEY_ST.get(key, 0)
    intervals = SCALE_INTERVALS.get(mode, SCALE_INTERVALS['Dorian'])
    return set((key_st + i) % 12 for i in intervals)

def in_scale(pitch, scale_set):
    return (pitch % 12) in scale_set

# ── Core dissonance analysis ───────────────────────────────────────────────────

def overlap_ticks(a_start, a_dur, b_start, b_dur):
    """Return the number of ticks two notes overlap. 0 if they don't."""
    a_end = a_start + a_dur
    b_end = b_start + b_dur
    return max(0, min(a_end, b_end) - max(a_start, b_start))

def analyze_dissonance(midi_path):
    """
    Parse MIDI + log, then return a dict with per-bar clash records.

    Returns:
        {
          'fname': str,
          'title': str,
          'key': str,
          'mode': str,
          'tempo': int,
          'bars': int,
          'tpq': int,
          'clashes': list of clash dicts,
          'scale_set': set,
        }
    """
    base     = os.path.splitext(midi_path)[0]
    log_path = base + '.zudio'

    tracks, tpq = parse_midi(midi_path)
    log = parse_log(log_path)

    key   = log['key']  or 'C'
    mode  = log['mode'] or 'Dorian'
    tempo = log['tempo'] or 72
    total_bars = log['bars'] or 88
    scale_set  = build_scale_set(key, mode)

    tpb = tpq * 4   # ticks per bar (4/4)

    # Merge ALL tracks into a single note list, excluding MIDI < 24 (parser artifacts)
    all_notes = []
    for t in tracks:
        for (st, pitch, vel, dur) in t['notes']:
            if pitch >= 24:
                all_notes.append((st, pitch, vel, dur))

    clashes = []

    for bar in range(total_bars):
        bar_start = bar * tpb
        bar_end   = (bar + 1) * tpb

        # Notes active during this bar: start < bar_end AND start + dur > bar_start
        bar_notes = [
            (st, pitch, vel, dur)
            for (st, pitch, vel, dur) in all_notes
            if st < bar_end and (st + dur) > bar_start
        ]

        bass   = [(st, p, v, d) for (st, p, v, d) in bar_notes if p < 60]
        melody = [(st, p, v, d) for (st, p, v, d) in bar_notes if p >= 60]

        # ── Bass-melody dissonance ──────────────────────────────────────────
        for (bst, bp, bv, bd) in bass:
            for (mst, mp, mv, md) in melody:
                ov = overlap_ticks(bst, bd, mst, md)
                if ov <= 0:
                    continue
                ivl = (mp - bp) % 12
                if ivl in DISSONANT_IVLS:
                    ov_beats = ov / tpb
                    clashes.append({
                        'bar':       bar + 1,
                        'kind':      'bass-melody',
                        'ivl':       ivl,
                        'ivl_name':  IVL_NAME.get(ivl, f'{ivl}st'),
                        'bass_pitch':   bp,
                        'melody_pitch': mp,
                        'bass_name':    note_name(bp),
                        'melody_name':  note_name(mp),
                        'bass_vel':     bv,
                        'melody_vel':   mv,
                        'overlap_beats': ov_beats,
                        'bass_in_scale':   in_scale(bp, scale_set),
                        'melody_in_scale': in_scale(mp, scale_set),
                    })

        # ── Intra-bass dissonance (minor 2nd between two bass notes) ───────
        for i in range(len(bass)):
            for j in range(i + 1, len(bass)):
                bst1, bp1, bv1, bd1 = bass[i]
                bst2, bp2, bv2, bd2 = bass[j]
                ov = overlap_ticks(bst1, bd1, bst2, bd2)
                if ov <= 0:
                    continue
                ivl = abs(bp1 - bp2) % 12
                if ivl == 1:   # minor 2nd only for intra-bass
                    ov_beats = ov / tpb
                    lo, hi = (bp1, bp2) if bp1 < bp2 else (bp2, bp1)
                    lo_v, hi_v = (bv1, bv2) if bp1 < bp2 else (bv2, bv1)
                    clashes.append({
                        'bar':       bar + 1,
                        'kind':      'intra-bass',
                        'ivl':       1,
                        'ivl_name':  'm2',
                        'bass_pitch':   lo,
                        'melody_pitch': hi,
                        'bass_name':    note_name(lo),
                        'melody_name':  note_name(hi),
                        'bass_vel':     lo_v,
                        'melody_vel':   hi_v,
                        'overlap_beats': ov_beats,
                        'bass_in_scale':   in_scale(lo, scale_set),
                        'melody_in_scale': in_scale(hi, scale_set),
                    })

    return {
        'fname':    os.path.basename(midi_path),
        'title':    log['title'],
        'key':      key,
        'mode':     mode,
        'tempo':    tempo,
        'bars':     total_bars,
        'tpq':      tpq,
        'clashes':  clashes,
        'scale_set': scale_set,
    }

# ── Scale context label ────────────────────────────────────────────────────────

def scale_context(clash):
    """
    Return a short label like 'in-scale', 'chromatic bass', 'chromatic melody',
    or 'chromatic both'.
    """
    bi = clash['bass_in_scale']
    mi = clash['melody_in_scale']
    if bi and mi:
        return 'in-scale'
    elif not bi and not mi:
        return 'chromatic-both'
    elif not bi:
        return 'chromatic-bass'
    else:
        return 'chromatic-melody'

# ── Report formatter ──────────────────────────────────────────────────────────

def print_song_report(result):
    fname  = result['fname']
    title  = result['title']
    key    = result['key']
    mode   = result['mode']
    tempo  = result['tempo']
    bars   = result['bars']
    clashes = result['clashes']

    print(f"\n{'='*70}")
    print(f"  {fname}")
    print(f"  \"{title}\"")
    print(f"  {key} {mode}  {tempo} BPM  {bars} bars")
    print()

    if not clashes:
        print("  No dissonant clashes detected.")
        return

    # Deduplicate: same bar+kind+bass+melody can appear multiple times from the
    # cross-product if several overlapping note instances match. Group by
    # (bar, kind, bass_pitch, melody_pitch) and keep the longest overlap.
    dedup = {}
    for c in clashes:
        key_tuple = (c['bar'], c['kind'], c['bass_pitch'], c['melody_pitch'])
        if key_tuple not in dedup or c['overlap_beats'] > dedup[key_tuple]['overlap_beats']:
            dedup[key_tuple] = c
    deduped = sorted(dedup.values(), key=lambda c: (c['bar'], c['kind'], c['bass_pitch']))

    # Group by bar for output
    by_bar = collections.defaultdict(list)
    for c in deduped:
        by_bar[c['bar']].append(c)

    print(f"  Dissonant clashes ({len(deduped)} unique pairs across {len(by_bar)} bars):")
    print()

    notable_bars = []

    for bar_num in sorted(by_bar):
        bar_clashes = by_bar[bar_num]
        total_overlap = sum(c['overlap_beats'] for c in bar_clashes)
        notable = total_overlap > 0.5
        if notable:
            notable_bars.append(bar_num)
        flag = "  *** NOTABLE ***" if notable else ""

        print(f"  Bar {bar_num:3d}  ({len(bar_clashes)} clash{'es' if len(bar_clashes)>1 else ''},"
              f" {total_overlap:.2f} beats overlap total){flag}")

        for c in bar_clashes:
            ctx = scale_context(c)
            kind_label = 'BM' if c['kind'] == 'bass-melody' else 'BB'
            print(f"    [{kind_label}] {c['bass_name']:4s} + {c['melody_name']:4s}"
                  f"  {c['ivl_name']:3s}  {c['overlap_beats']:.2f} beats"
                  f"  vel=({c['bass_vel']},{c['melody_vel']})"
                  f"  [{ctx}]")

    if notable_bars:
        print(f"\n  Notable bars (>0.5 beats overlap): {notable_bars}")

    return deduped

# ── Cross-song summary ─────────────────────────────────────────────────────────

def print_summary(all_results):
    print(f"\n{'='*70}")
    print(f"CROSS-SONG DISSONANCE SUMMARY  ({len(all_results)} songs)")
    print()

    total_clashes = 0
    songs_with_clashes = 0
    clash_by_type   = collections.Counter()   # ivl_name
    clash_by_kind   = collections.Counter()   # bass-melody vs intra-bass
    clash_by_ctx    = collections.Counter()   # in-scale, chromatic-*
    bar_clash_counts = collections.Counter()  # bar number -> count (across songs)
    worst_songs = []   # (clash_count, fname, title)

    for result in all_results:
        clashes = result.get('_deduped', [])
        n = len(clashes)
        total_clashes += n
        if n > 0:
            songs_with_clashes += 1
        worst_songs.append((n, result['fname'], result['title']))
        for c in clashes:
            clash_by_type[c['ivl_name']] += 1
            clash_by_kind[c['kind']] += 1
            clash_by_ctx[scale_context(c)] += 1
            bar_clash_counts[c['bar']] += 1

    worst_songs.sort(reverse=True)

    print(f"  Total unique clashes:   {total_clashes}")
    print(f"  Songs with any clash:   {songs_with_clashes} / {len(all_results)}")
    if total_clashes:
        avg = total_clashes / len(all_results)
        print(f"  Average clashes/song:   {avg:.1f}")
    print()

    if total_clashes:
        print("  Clash kinds:")
        for kind, count in clash_by_kind.most_common():
            label = 'bass+melody' if kind == 'bass-melody' else 'intra-bass (BB)'
            print(f"    {label:<28}  {count}")
        print()

        print("  Most common interval types:")
        for ivl_name, count in clash_by_type.most_common():
            pct = count / total_clashes * 100
            print(f"    {ivl_name:<6}  {count:4d}  ({pct:.0f}%)")
        print()

        print("  Scale context breakdown:")
        for ctx, count in clash_by_ctx.most_common():
            pct = count / total_clashes * 100
            print(f"    {ctx:<22}  {count:4d}  ({pct:.0f}%)")
        print()

        print("  Most problematic bars (across all songs):")
        for bar_num, count in bar_clash_counts.most_common(10):
            print(f"    Bar {bar_num:3d}  {count} clash{'es' if count>1 else ''}")
        print()

        print("  Worst songs (by unique clash count):")
        for n, fname, title in worst_songs[:10]:
            if n == 0:
                continue
            print(f"    {n:4d}  {fname}")
            print(f"          \"{title}\"")
        print()

        print("  Clean songs (zero clashes):")
        clean = [(fname, title) for (n, fname, title) in worst_songs if n == 0]
        if clean:
            for fname, title in clean:
                print(f"    {fname}")
                print(f"      \"{title}\"")
        else:
            print("    (none)")
    else:
        print("  No dissonant clashes found across any song.")

# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    files = sys.argv[1:]
    if not files:
        # Fallback: look for .MID files in cwd
        files = sorted(f for f in os.listdir('.') if f.upper().endswith('.MID'))
    if not files:
        print("Usage: python3 ambient_pno003_dissonance.py <path/to/*.MID>")
        sys.exit(1)

    # Expand glob-like patterns that the shell may not have expanded (e.g. on Windows)
    import glob
    expanded = []
    for f in files:
        g = glob.glob(f)
        expanded.extend(g if g else [f])
    files = sorted(set(expanded))

    print(f"\nAmbient Piano — Bass-Melody Dissonance Analysis")
    print(f"{len(files)} file(s)")

    all_results = []

    for path in files:
        if not os.path.exists(path):
            print(f"\n  [SKIP] File not found: {path}")
            continue
        try:
            result = analyze_dissonance(path)
            deduped = print_song_report(result)
            result['_deduped'] = deduped if deduped else []
            all_results.append(result)
        except Exception as e:
            print(f"\n  [ERROR] {path}: {e}")

    if len(all_results) > 1:
        print_summary(all_results)
    elif len(all_results) == 1:
        # Single-file: still print a mini-summary
        result = all_results[0]
        n = len(result.get('_deduped', []))
        print(f"\n  Summary: {n} unique dissonant clash pair(s) in \"{result['title']}\"")

if __name__ == '__main__':
    main()

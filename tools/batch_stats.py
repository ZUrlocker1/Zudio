#!/usr/bin/env python3
"""
batch_stats.py — Statistical analysis of Zudio batch-generated .zudio log files.

Usage:
    python3 tools/batch_stats.py tools/batch-output/all/
    python3 tools/batch_stats.py *.zudio

Reports:
  - Style distribution
  - Substyle % per style
  - Mode and Mood distributions
  - Key distribution
  - BPM histogram
  - Song length (bars) histogram
  - Form distribution
  - Rule frequency (flags high-bias rules)
  - Instrument repeat analysis (consecutive same-instrument)
  - Track absence rates
  - Bridge frequency
"""

import os, sys, re, collections, glob
from pathlib import Path

# ── Parser ─────────────────────────────────────────────────────────────────────

def parse_zudio(path):
    d = {
        'file': Path(path).name,
        'title': None, 'style': None, 'substyle': None,
        'key': None, 'mode': None, 'tempo': None, 'bars': None, 'mood': None,
        'form': None, 'chords': None,
        'rules': {},          # tag → description
        'instruments': {},    # L1/L2/Pd/Ry/Tx/Bs/Dr → program number
        'loop_lengths': {},   # Pd/L1/L2/Ry/Tx/Bs → bars
        'has_bridge': False,
        'absent_tracks': [],  # tracks with "No X" rule
        'raw_log': [],
    }
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"  [WARN] Could not read {path}: {e}")
        return d

    in_gen_log = False
    for line in lines:
        s = line.strip()
        if not s: continue

        if s.startswith('Title:'):
            d['title'] = s.split(None, 1)[1].strip() if len(s.split(None,1)) > 1 else ''
        elif s.startswith('Style:'):
            d['style'] = s.split(None, 1)[1].strip()
        elif s.startswith('Key:'):
            parts = s.split()
            if len(parts) >= 3:
                d['key'] = parts[1]
                d['mode'] = parts[2]
        elif s.startswith('Tempo:'):
            m = re.search(r'(\d+)', s)
            if m: d['tempo'] = int(m.group(1))
        elif s.startswith('Bars:'):
            m = re.search(r'(\d+)', s)
            if m: d['bars'] = int(m.group(1))
        elif s.startswith('Mood:'):
            d['mood'] = s.split(None, 1)[1].strip() if len(s.split(None,1)) > 1 else ''
        elif '--- Generation Log ---' in s:
            in_gen_log = True
        elif s.startswith('---') and in_gen_log:
            in_gen_log = False
        elif in_gen_log:
            # Format: "  TAG             description"
            parts = s.split(None, 1)
            if len(parts) == 2:
                tag, desc = parts[0], parts[1].strip()
                d['rules'][tag] = desc
                d['raw_log'].append((tag, desc))
                if tag == 'Style':
                    d['substyle'] = desc
                elif tag == 'Form':
                    d['form'] = desc
                elif tag == 'Chords':
                    d['chords'] = desc
                elif tag == 'Instruments':
                    # Parse "L1:76 L2:100 Pd:95 Ry:39 Tx:86 Bs:87 Dr:24"
                    for token in desc.split():
                        if ':' in token:
                            k, v = token.split(':', 1)
                            try: d['instruments'][k] = int(v)
                            except: d['instruments'][k] = v
                elif tag == 'Loops':
                    # Parse "Pd:11 L1:19 L2:17 Ry:23 Tx:29 Bs:13"
                    for token in desc.split():
                        if ':' in token:
                            k, v = token.split(':', 1)
                            try: d['loop_lengths'][k] = int(v)
                            except: pass
                # Detect bridge presence
                if 'bridge' in desc.lower() or 'Bridge' in tag:
                    d['has_bridge'] = True
                # Detect absent tracks
                if desc.startswith('No ') or desc.endswith('absent') or desc.endswith('silent'):
                    d['absent_tracks'].append(tag)

    return d

# ── Formatting helpers ─────────────────────────────────────────────────────────

def pct(n, total): return f"{100*n/total:.1f}%" if total else "n/a"

def bar_chart(counts, total, width=30):
    lines = []
    for k, v in sorted(counts.items(), key=lambda x: -x[1]):
        bar = '█' * int(width * v / max(counts.values(), default=1))
        lines.append(f"    {str(k):<24}  {v:3d}  {pct(v,total):>6}  {bar}")
    return '\n'.join(lines)

def histogram(values, bins=8):
    if not values: return "    (none)"
    lo, hi = min(values), max(values)
    if lo == hi: return f"    all = {lo}"
    step = (hi - lo) / bins
    counts = collections.Counter()
    for v in values:
        b = int((v - lo) / step)
        b = min(b, bins - 1)
        counts[b] += 1
    lines = []
    for b in range(bins):
        lo_b = lo + b * step
        hi_b = lo_b + step
        n = counts[b]
        bar = '█' * int(20 * n / len(values))
        lines.append(f"    {lo_b:6.0f}–{hi_b:<6.0f}  {n:3d}  {bar}")
    return '\n'.join(lines)

# ── Analysis ───────────────────────────────────────────────────────────────────

def analyze(songs):
    N = len(songs)
    print(f"\n{'='*70}")
    print(f"  ZUDIO BATCH STATISTICS — {N} songs")
    print(f"{'='*70}")

    # ── Style distribution ────────────────────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  STYLE DISTRIBUTION")
    print(f"{'─'*50}")
    by_style = collections.Counter(s['style'] for s in songs if s['style'])
    for style, n in sorted(by_style.items(), key=lambda x: -x[1]):
        print(f"    {style:<12}  {n:3d}  {pct(n,N):>6}")

    # ── Substyle distribution per style ──────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  SUBSTYLE DISTRIBUTION")
    print(f"{'─'*50}")
    for style in sorted(by_style):
        style_songs = [s for s in songs if s['style'] == style]
        ns = len(style_songs)
        substyles = collections.Counter()
        for s in style_songs:
            sub = s.get('substyle')
            if sub and sub != style.capitalize() and sub != style:
                substyles[sub] += 1
            else:
                substyles['(base)'] += 1
        print(f"\n  {style.capitalize()} ({ns} songs):")
        for sub, n in sorted(substyles.items(), key=lambda x: -x[1]):
            print(f"    {sub:<30}  {n:3d}  {pct(n,ns):>6}")

    # ── Style run-length analysis ─────────────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  STYLE RUN-LENGTH (consecutive same style — flag runs > 4)")
    print(f"{'─'*50}")
    styles_seq = [s['style'] for s in songs if s['style']]
    runs = []
    if styles_seq:
        cur_style, run = styles_seq[0], 1
        for st in styles_seq[1:]:
            if st == cur_style:
                run += 1
            else:
                runs.append((cur_style, run))
                cur_style, run = st, 1
        runs.append((cur_style, run))
    max_run = max((r for _, r in runs), default=0)
    long_runs = [(s, r) for s, r in runs if r >= 4]
    print(f"    Longest run: {max_run} consecutive same style")
    if long_runs:
        print(f"    Runs of 4+:  {len(long_runs)}")
        for s, r in sorted(long_runs, key=lambda x: -x[1])[:10]:
            flag = '  ⚠ STUCK?' if r >= 6 else ''
            print(f"      {s:<12}  {r} in a row{flag}")
    else:
        print("    No runs of 4+ — good randomness ✓")

    # ── Mode distribution ─────────────────────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  MODE DISTRIBUTION")
    print(f"{'─'*50}")
    modes = collections.Counter(s['mode'] for s in songs if s['mode'])
    print(bar_chart(modes, N))

    # ── Mood distribution ─────────────────────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  MOOD DISTRIBUTION")
    print(f"{'─'*50}")
    moods = collections.Counter(s['mood'] for s in songs if s['mood'])
    print(bar_chart(moods, N))

    # ── Key distribution ──────────────────────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  KEY DISTRIBUTION")
    print(f"{'─'*50}")
    keys = collections.Counter(s['key'] for s in songs if s['key'])
    print(bar_chart(keys, N))

    # ── BPM distribution ──────────────────────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  BPM DISTRIBUTION (by style)")
    print(f"{'─'*50}")
    for style in sorted(by_style):
        tempos = [s['tempo'] for s in songs if s['style'] == style and s['tempo']]
        if tempos:
            print(f"\n  {style.capitalize()}: min={min(tempos)} max={max(tempos)} mean={sum(tempos)//len(tempos)}")
            print(histogram(tempos, bins=6))

    # ── Song length distribution ──────────────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  SONG LENGTH (bars, by style)")
    print(f"{'─'*50}")
    for style in sorted(by_style):
        lengths = [s['bars'] for s in songs if s['style'] == style and s['bars']]
        if lengths:
            print(f"\n  {style.capitalize()}: min={min(lengths)} max={max(lengths)} mean={sum(lengths)//len(lengths)}")
            print(histogram(lengths, bins=6))

    # ── Form distribution ─────────────────────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  FORM DISTRIBUTION")
    print(f"{'─'*50}")
    forms = collections.Counter(s['form'] for s in songs if s['form'])
    print(bar_chart(forms, N))

    # ── Bridge frequency ──────────────────────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  BRIDGE PRESENCE (by style)")
    print(f"{'─'*50}")
    for style in sorted(by_style):
        style_songs = [s for s in songs if s['style'] == style]
        ns = len(style_songs)
        with_bridge = sum(1 for s in style_songs if s['has_bridge'])
        print(f"    {style:<12}  {with_bridge}/{ns}  {pct(with_bridge,ns):>6}")

    # ── Rule frequency ────────────────────────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  RULE FREQUENCY — top 20 most frequent (flag if >60%)")
    print(f"{'─'*50}")
    rule_counts = collections.Counter()
    for s in songs:
        for tag in s['rules']:
            if tag not in ('SONG','Style','Form','Chords','Instruments','Loops','FILE'):
                rule_counts[tag] += 1
    print(f"\n  {'Rule':<24}  {'Count':>5}  {'%':>6}  Flag?")
    for tag, n in rule_counts.most_common(30):
        flag = '  ⚠ HIGH BIAS' if n/N > 0.60 else ''
        print(f"    {tag:<24}  {n:5d}  {pct(n,N):>6}{flag}")

    # ── Rule frequency per style ──────────────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  RULE FREQUENCY PER STYLE — top 10 each")
    print(f"{'─'*50}")
    for style in sorted(by_style):
        style_songs = [s for s in songs if s['style'] == style]
        ns = len(style_songs)
        rc = collections.Counter()
        for s in style_songs:
            for tag in s['rules']:
                if tag not in ('SONG','Style','Form','Chords','Instruments','Loops','FILE'):
                    rc[tag] += 1
        print(f"\n  {style.capitalize()} (n={ns}):")
        for tag, n in rc.most_common(12):
            flag = '  ⚠' if n/ns > 0.65 else ''
            print(f"    {tag:<28}  {n:3d}  {pct(n,ns):>6}{flag}")

    # ── Track absence rates ───────────────────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  TRACK ABSENCE RATES")
    print(f"{'─'*50}")
    absence_counts = collections.Counter()
    for s in songs:
        for tag in s['absent_tracks']:
            absence_counts[tag] += 1
    if absence_counts:
        print(bar_chart(absence_counts, N))
    else:
        print("    (none detected — check rule descriptions for 'No X' or 'absent')")

    # ── Instrument repeat analysis ────────────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  INSTRUMENT REPEAT ANALYSIS (consecutive same program)")
    print(f"{'─'*50}")
    track_keys = ['L1','L2','Pd','Ry','Tx','Bs','Dr']
    for style in sorted(by_style):
        style_songs = [s for s in songs if s['style'] == style]
        ns = len(style_songs)
        repeat_counts = collections.defaultdict(int)
        for i in range(1, ns):
            prev = style_songs[i-1]['instruments']
            curr = style_songs[i]['instruments']
            for tk in track_keys:
                if prev.get(tk) is not None and prev.get(tk) == curr.get(tk):
                    repeat_counts[tk] += 1
        print(f"\n  {style.capitalize()} ({ns} songs) — consecutive same-instrument rate:")
        for tk in track_keys:
            n = repeat_counts[tk]
            flag = '  ⚠ HIGH' if n/(ns-1) > 0.70 else ''
            print(f"    {tk}:  {n}/{ns-1}  {pct(n,ns-1):>6}{flag}")

    # ── Instrument diversity per track per style ──────────────────────────────
    print(f"\n{'─'*50}")
    print("  INSTRUMENT DIVERSITY (unique programs per track per style)")
    print(f"{'─'*50}")
    for style in sorted(by_style):
        style_songs = [s for s in songs if s['style'] == style]
        ns = len(style_songs)
        print(f"\n  {style.capitalize()} ({ns} songs):")
        for tk in track_keys:
            progs = collections.Counter(
                str(s['instruments'].get(tk,'–')) for s in style_songs
                if s['instruments'].get(tk) is not None
            )
            if not progs: continue
            top = progs.most_common(3)
            top_str = '  '.join(f"prog{p}={n}({pct(n,ns)})" for p,n in top)
            flag = '  ⚠' if top[0][1]/ns > 0.65 else ''
            print(f"    {tk}: {len(progs)} unique — {top_str}{flag}")

    # ── Chord family distribution ─────────────────────────────────────────────
    print(f"\n{'─'*50}")
    print("  CHORD FAMILY / HARMONY DESCRIPTION")
    print(f"{'─'*50}")
    chords = collections.Counter(s['chords'] for s in songs if s['chords'])
    for desc, n in chords.most_common(15):
        print(f"    {desc:<40}  {n:3d}  {pct(n,N):>6}")

    print(f"\n{'='*70}")
    print(f"  Analysis complete — {N} songs")
    print(f"{'='*70}\n")

# ── Entry point ────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    paths = []
    if len(sys.argv) > 1:
        for arg in sys.argv[1:]:
            if os.path.isdir(arg):
                paths.extend(sorted(glob.glob(os.path.join(arg, '*.zudio'))))
            else:
                paths.extend(sorted(glob.glob(arg)))
    else:
        paths = sorted(glob.glob('*.zudio'))

    if not paths:
        print("No .zudio files found. Pass a directory or glob pattern.")
        sys.exit(1)

    print(f"Loading {len(paths)} .zudio files...")
    songs = [parse_zudio(p) for p in paths]
    songs = [s for s in songs if s['style']]  # drop unparseable
    print(f"  Parsed {len(songs)} valid songs.")

    analyze(songs)

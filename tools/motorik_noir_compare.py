#!/usr/bin/env python3
"""
motorik_noir_compare.py — Compares Motorik Noir vs Regular batch outputs.

Usage:
    cd tools/batch-output/motorik
    python3 ../../motorik_noir_compare.py

Reads noir_*.zudio and regular_*.zudio files in the current directory.
"""

import os, re, sys
from collections import Counter, defaultdict

def parse_zudio(path):
    d = {}
    with open(path) as f:
        text = f.read()

    def field(label):
        m = re.search(rf'^{label}:\s+(.+)$', text, re.MULTILINE)
        return m.group(1).strip() if m else None

    d['title']  = field('Title')
    d['key']    = field('Key')
    d['tempo']  = int(field('Tempo').replace(' BPM','')) if field('Tempo') else 0
    d['bars']   = int(field('Bars')) if field('Bars') else 0
    d['mood']   = field('Mood')
    d['style']  = field('Style')  # "Motorik Noir" or "Motorik"

    # Mode from Key line e.g. "E  HarmonicMinor"
    key_line = field('Key') or ''
    parts = key_line.split()
    d['mode'] = parts[1] if len(parts) > 1 else '?'

    # Rules from generation log section
    gen_section = re.search(r'--- Generation Log ---(.+?)(?=---|$)', text, re.DOTALL)
    gen_text = gen_section.group(1) if gen_section else ''

    def rule(prefix):
        m = re.search(rf'({prefix}-\S+)', gen_text)
        return m.group(1) if m else None

    d['drum_rule']   = rule('MOT-DRUM')
    d['bass_rule']   = rule('MOT-BASS')
    d['pads_rule']   = rule('MOT-PADS')
    d['ld1_rule']    = rule('MOT-LD1')
    d['ld2_rule']    = rule('MOT-LD2')
    d['rthm_rule']   = rule('MOT-RTHM')
    d['tex_rules']   = re.findall(r'MOT-TEXT-\S+', gen_text)

    # Instruments line: "L1:81 L2:90 Pd:94 Ry:8081 Tx:86 Bs:39 Dr:8 LS:90"
    inst_m = re.search(r'Instruments\s+(.+)', gen_text)
    d['instruments'] = inst_m.group(1).strip() if inst_m else ''

    # Note counts
    nc_section = re.search(r'--- Note Counts Per Track ---(.+?)(?=---|$)', text, re.DOTALL)
    nc_text = nc_section.group(1) if nc_section else ''
    def note_count(track):
        m = re.search(rf'{track}\s+(\d+)', nc_text)
        return int(m.group(1)) if m else 0

    d['notes_lead1']   = note_count('Lead 1')
    d['notes_pads']    = note_count('Pads')
    d['notes_rhythm']  = note_count('Rhythm')
    d['notes_texture'] = note_count('Texture')
    d['notes_bass']    = note_count('Bass')
    d['notes_drums']   = note_count('Drums')
    d['notes_lead2']   = note_count('Lead 2')

    # Form from Generation Log
    form_m = re.search(r'Form\s+(.+)', gen_text)
    d['form'] = form_m.group(1).strip() if form_m else '?'

    # Has pads / lead2 / texture
    d['has_pads']    = d['notes_pads'] > 0
    d['has_lead2']   = d['notes_lead2'] > 0
    d['has_texture'] = d['notes_texture'] > 0

    return d


def summarise(songs, label):
    n = len(songs)
    if n == 0:
        print(f"  No {label} songs found.")
        return

    tempos  = [s['tempo'] for s in songs]
    bars    = [s['bars']  for s in songs]
    modes   = Counter(s['mode'] for s in songs)
    moods   = Counter(s['mood'] for s in songs)
    drums   = Counter(s['drum_rule']  for s in songs)
    bass    = Counter(s['bass_rule']  for s in songs)
    pads    = Counter(s['pads_rule']  for s in songs)
    ld1     = Counter(s['ld1_rule']   for s in songs)
    ld2     = Counter(s['ld2_rule']   for s in songs)
    rthm    = Counter(s['rthm_rule']  for s in songs)
    forms   = Counter(s['form']       for s in songs)

    pads_pct    = 100 * sum(1 for s in songs if s['has_pads'])    // n
    lead2_pct   = 100 * sum(1 for s in songs if s['has_lead2'])   // n
    texture_pct = 100 * sum(1 for s in songs if s['has_texture']) // n

    avg_lead1_notes = sum(s['notes_lead1'] for s in songs) // n
    avg_bass_notes  = sum(s['notes_bass']  for s in songs) // n
    avg_drum_notes  = sum(s['notes_drums'] for s in songs) // n

    def fmt_counter(c):
        return ', '.join(f'{k}×{v}' for k,v in c.most_common())

    print(f"  Tempo:     {min(tempos)}–{max(tempos)} BPM  (avg {sum(tempos)//n})")
    print(f"  Bars:      {min(bars)}–{max(bars)}  (avg {sum(bars)//n})")
    print(f"  Modes:     {fmt_counter(modes)}")
    print(f"  Moods:     {fmt_counter(moods)}")
    print(f"  Form:      {fmt_counter(forms)}")
    print(f"  Drums:     {fmt_counter(drums)}")
    print(f"  Bass:      {fmt_counter(bass)}")
    print(f"  Pads:      {fmt_counter(pads)}  ({pads_pct}% have pads)")
    print(f"  Lead 1:    {fmt_counter(ld1)}  (avg {avg_lead1_notes} notes)")
    print(f"  Lead 2:    {fmt_counter(ld2)}  ({lead2_pct}% active)")
    print(f"  Rhythm:    {fmt_counter(rthm)}")
    print(f"  Texture:   {texture_pct}% have texture")
    print(f"  Bass avg:  {avg_bass_notes} notes   Drums avg: {avg_drum_notes} notes")


def compare(noir, regular):
    print("\n══════════════════════════════════════════════")
    print("  DISTINCTIVENESS ANALYSIS")
    print("══════════════════════════════════════════════\n")

    checks = []

    # Tempo
    noir_avg   = sum(s['tempo'] for s in noir)   // len(noir)
    reg_avg    = sum(s['tempo'] for s in regular) // len(regular)
    diff = reg_avg - noir_avg
    checks.append(('Tempo', diff >= 8,
        f"Noir avg {noir_avg} BPM vs Regular avg {reg_avg} BPM  (Δ{diff:+d})"))

    # Minor mode enforcement
    noir_minor   = sum(1 for s in noir    if s['mode'] not in ('Ionian','MajorPentatonic','Mixolydian','major')) / len(noir)
    reg_minor    = sum(1 for s in regular if s['mode'] not in ('Ionian','MajorPentatonic','Mixolydian','major')) / len(regular)
    checks.append(('Minor keys', noir_minor > reg_minor,
        f"Noir {noir_minor:.0%} minor  vs Regular {reg_minor:.0%} minor"))

    # Lead 2 suppression in Noir
    noir_ld2   = sum(1 for s in noir    if s['has_lead2']) / len(noir)
    reg_ld2    = sum(1 for s in regular if s['has_lead2']) / len(regular)
    checks.append(('Lead 2 suppressed in Noir', noir_ld2 < reg_ld2 - 0.3,
        f"Noir {noir_ld2:.0%} active Lead 2  vs Regular {reg_ld2:.0%}"))

    # Pads presence difference
    noir_pads  = sum(1 for s in noir    if s['has_pads']) / len(noir)
    reg_pads   = sum(1 for s in regular if s['has_pads']) / len(regular)
    checks.append(('Pads sparser in Noir', noir_pads <= reg_pads,
        f"Noir {noir_pads:.0%} have pads  vs Regular {reg_pads:.0%}"))

    # Drum rule variety
    noir_drums   = set(s['drum_rule'] for s in noir)
    reg_drums    = set(s['drum_rule'] for s in regular)
    overlap      = noir_drums & reg_drums
    checks.append(('Drum rule separation', len(overlap) <= 1,
        f"Noir drums: {sorted(noir_drums)}  ∩ Regular: {sorted(overlap)} shared"))

    # Bass rule variety
    noir_bass    = set(s['bass_rule'] for s in noir)
    reg_bass     = set(s['bass_rule'] for s in regular)
    bass_overlap = noir_bass & reg_bass
    checks.append(('Bass rule separation', len(bass_overlap) <= 2,
        f"Noir bass: {sorted(noir_bass)}  ∩ overlap: {sorted(bass_overlap)}"))

    # Rhythm rule variety
    noir_rthm  = set(s['rthm_rule'] for s in noir)
    reg_rthm   = set(s['rthm_rule'] for s in regular)
    rthm_overlap = noir_rthm & reg_rthm
    checks.append(('Rhythm rule separation', len(rthm_overlap) <= 1,
        f"Noir rthm: {sorted(noir_rthm)}  ∩ overlap: {sorted(rthm_overlap)}"))

    passed = sum(1 for _, ok, _ in checks if ok)
    for label, ok, detail in checks:
        mark = '✓' if ok else '✗'
        print(f"  {mark} {label}")
        print(f"      {detail}")

    print(f"\n  Score: {passed}/{len(checks)} checks passed")

    print("\n── Suggestions ─────────────────────────────\n")
    for label, ok, detail in checks:
        if not ok:
            if 'Tempo' in label:
                print(f"  • Tempo gap is small ({detail}). Consider widening the Noir tempo ceiling or")
                print(f"    raising the Regular floor to create more separation.")
            if 'Minor' in label:
                print(f"  • Noir is not enforcing minor keys as strongly as expected ({detail}).")
                print(f"    Check MusicalFrameGenerator — motorikNoir should force minor modes only.")
            if 'Lead 2' in label:
                print(f"  • Lead 2 suppression gap is narrow ({detail}).")
                print(f"    Noir should always suppress Lead 2.")
            if 'Pads' in label:
                print(f"  • Pads presence not clearly sparser in Noir ({detail}).")
                print(f"    The Pads suppression gate may not be firing reliably.")
            if 'Drum' in label:
                print(f"  • Drum rules overlap too much ({detail}).")
                print(f"    More drum rules should be exclusive to one mode.")
            if 'Bass' in label:
                print(f"  • Bass rules share too many rules ({detail}).")
                print(f"    Noir PiL-inspired bass rules should be Noir-only.")
            if 'Rhythm' in label:
                print(f"  • Rhythm rules overlap too much ({detail}).")
                print(f"    Consider making Void Stab and similar Noir-exclusive.")


def main():
    cwd = os.getcwd()
    noir_files    = sorted(f for f in os.listdir(cwd) if f.startswith('noir_')    and f.endswith('.zudio'))
    regular_files = sorted(f for f in os.listdir(cwd) if f.startswith('regular_') and f.endswith('.zudio'))

    if not noir_files or not regular_files:
        print("No noir_*.zudio or regular_*.zudio files found in current directory.")
        print("Run the MotorikNoirCompareTests Swift test first.")
        sys.exit(1)

    noir    = [parse_zudio(f) for f in noir_files]
    regular = [parse_zudio(f) for f in regular_files]

    print(f"\n{'='*54}")
    print(f"  MOTORIK NOIR  ({len(noir)} songs)")
    print(f"{'='*54}")
    summarise(noir, 'Noir')

    print(f"\n{'='*54}")
    print(f"  MOTORIK REGULAR  ({len(regular)} songs)")
    print(f"{'='*54}")
    summarise(regular, 'Regular')

    compare(noir, regular)


if __name__ == '__main__':
    main()

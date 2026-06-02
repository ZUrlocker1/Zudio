#!/usr/bin/env python3
"""MIDI analysis for Diffuse-Light-Pooling-the-Beige-Ceiling-Tiles.MID"""

import mido
import collections

MIDI_FILE = '/Users/urlocker/Downloads/Diffuse-Light-Pooling-the-Beige-Ceiling-Tiles.MID'
TICKS_PER_BEAT = 480
STEP_TICKS = 120   # 1 sixteenth note
BAR_TICKS = 1920   # 16 steps

NOTE_NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']

def note_name(midi_num):
    return f"{NOTE_NAMES[midi_num % 12]}{midi_num // 12 - 1}"

def bar_of(tick):
    return tick // BAR_TICKS + 1  # 1-indexed

def step_in_bar(tick):
    return (tick % BAR_TICKS) // STEP_TICKS  # 0-indexed

def load_notes(path):
    mid = mido.MidiFile(path)
    print(f"Type: {mid.type}, Ticks/beat: {mid.ticks_per_beat}, Tracks: {len(mid.tracks)}")
    for i, t in enumerate(mid.tracks):
        print(f"  Track {i}: '{t.name}', msgs: {len(t)}")

    # Collect all note_on/off events across all tracks with absolute tick time
    events = []
    for track in mid.tracks:
        abs_tick = 0
        for msg in track:
            abs_tick += msg.time
            if msg.type in ('note_on', 'note_off'):
                events.append((abs_tick, msg.type, msg.note, msg.velocity))

    # Sort by tick
    events.sort(key=lambda x: x[0])

    # Build note list: (start_tick, end_tick, note)
    pending = {}  # note -> list of start ticks
    notes = []
    for tick, mtype, note, vel in events:
        if mtype == 'note_on' and vel > 0:
            pending.setdefault(note, []).append(tick)
        else:
            if note in pending and pending[note]:
                start = pending[note].pop(0)
                notes.append((start, tick, note))

    notes.sort()
    return notes

def notes_in_bars(notes, bar_start, bar_end):
    """Return notes that start in [bar_start, bar_end] (1-indexed)."""
    tick_start = (bar_start - 1) * BAR_TICKS
    tick_end = bar_end * BAR_TICKS
    return [(s, e, n) for s, e, n in notes if tick_start <= s < tick_end]

def notes_sounding_in_bar(notes, bar_num):
    """Return notes that are sounding at any point during bar_num."""
    tick_start = (bar_num - 1) * BAR_TICKS
    tick_end = bar_num * BAR_TICKS
    return [(s, e, n) for s, e, n in notes if s < tick_end and e > tick_start]

# ─── Load ────────────────────────────────────────────────────────────────────
notes = load_notes(MIDI_FILE)
print(f"\nTotal notes: {len(notes)}")
print(f"Bar range: {bar_of(notes[0][0])} – {bar_of(notes[-1][0])}")
print()

# ─── ISSUE 1: Bars 3–9 ───────────────────────────────────────────────────────
print("=" * 60)
print("ISSUE 1: Bars 3–9 (two songs going on)")
print("=" * 60)

issue1 = notes_in_bars(notes, 3, 9)
print(f"Notes starting in bars 3-9: {len(issue1)}")
print()

# Find max simultaneous voices
def max_polyphony(note_list):
    events = []
    for s, e, n in note_list:
        events.append((s, +1, n))
        events.append((e, -1, n))
    events.sort()
    cur = 0
    mx = 0
    for tick, delta, _ in events:
        cur += delta
        mx = max(mx, cur)
    return mx

print(f"Max simultaneous voices in bars 3-9: {max_polyphony(issue1)}")
print()

# Print each note with bar, step, duration
print(f"{'Tick':>8} {'Bar':>4} {'Step':>5} {'Note':>6} {'MIDI':>5} {'Dur(steps)':>10}")
print("-" * 50)
for s, e, n in sorted(issue1):
    dur_steps = (e - s) / STEP_TICKS
    print(f"{s:8d} {bar_of(s):4d} {step_in_bar(s):5d} {note_name(n):>6} {n:5d} {dur_steps:10.2f}")

# Register split analysis
low = [(s,e,n) for s,e,n in issue1 if n < 60]
high = [(s,e,n) for s,e,n in issue1 if n >= 60]
print(f"\nLow register (<60): {len(low)} notes, range {min(n for _,_,n in low) if low else 'N/A'}–{max(n for _,_,n in low) if low else 'N/A'}")
print(f"High register (>=60): {len(high)} notes, range {min(n for _,_,n in high) if high else 'N/A'}–{max(n for _,_,n in high) if high else 'N/A'}")

# Simultaneous voice check per step
print("\nSimultaneous voices per step (bars 3-9):")
all_sounding = {}
for s, e, n in notes_in_bars(notes, 3, 9):
    step_start = s // STEP_TICKS
    step_end = (e - 1) // STEP_TICKS
    for st in range(step_start, step_end + 1):
        b = st * STEP_TICKS // BAR_TICKS + 1
        if 3 <= b <= 9:
            all_sounding.setdefault(st, []).append(n)

multi_voice_steps = {st: ns for st, ns in all_sounding.items() if len(ns) >= 2}
print(f"Steps with 2+ simultaneous notes: {len(multi_voice_steps)}")
for st in sorted(list(multi_voice_steps.keys()))[:30]:
    b = st * STEP_TICKS // BAR_TICKS + 1
    sib = st % (BAR_TICKS // STEP_TICKS)
    ns = sorted(multi_voice_steps[st])
    names = [note_name(n) for n in ns]
    print(f"  Bar {b} step {sib:2d}: {names} ({ns})")

print()
# ─── ISSUE 2: Bars 34–46 and 65–73 ──────────────────────────────────────────
print("=" * 60)
print("ISSUE 2: Bars 34–46 and 65–73 (repeated high notes)")
print("=" * 60)

for bar_range, label in [((34, 46), "Bars 34-46"), ((65, 73), "Bars 65-73")]:
    print(f"\n--- {label} ---")
    range_notes = notes_in_bars(notes, *bar_range)
    high_notes = [(s, e, n) for s, e, n in range_notes if n > 70]
    print(f"Notes above MIDI 70: {len(high_notes)}")

    # Count consecutive attacks on same note
    # Sort by start tick
    high_notes_sorted = sorted(high_notes)
    if not high_notes_sorted:
        print("  None found.")
        continue

    # Build runs of same note
    runs = []
    cur_note = None
    cur_run = []
    for s, e, n in high_notes_sorted:
        if n == cur_note:
            cur_run.append((s, e, n))
        else:
            if cur_run:
                runs.append(cur_run)
            cur_note = n
            cur_run = [(s, e, n)]
    if cur_run:
        runs.append(cur_run)

    print(f"Consecutive same-note runs (sorted high notes):")
    for run in runs:
        if len(run) >= 2:
            note_val = run[0][2]
            bars = sorted({bar_of(s) for s,e,n in run})
            print(f"  {note_name(note_val)} (MIDI {note_val}): {len(run)}x consecutive, bars {bars[0]}-{bars[-1]}")
            for s,e,n in run:
                print(f"    bar {bar_of(s)} step {step_in_bar(s)}: {note_name(n)}")

    # Also find any single pitch with 4+ attacks in range
    pitch_attacks = collections.Counter(n for s,e,n in high_notes)
    print(f"Pitch attack counts (above 70): {dict(sorted(pitch_attacks.items()))}")
    for pitch, count in sorted(pitch_attacks.items(), key=lambda x: -x[1]):
        print(f"  {note_name(pitch)} (MIDI {pitch}): {count} attacks")

print()
# ─── ISSUE 3: Bar 68 ──────────────────────────────────────────────────────────
print("=" * 60)
print("ISSUE 3: Bar 68 (dissonant bass)")
print("=" * 60)

bar68 = notes_sounding_in_bar(notes, 68)
print(f"Notes sounding in bar 68: {len(bar68)}")
for s, e, n in sorted(bar68):
    print(f"  {note_name(n):>6} (MIDI {n:3d})  start_bar={bar_of(s)} step={step_in_bar(s)}  dur={((e-s)/STEP_TICKS):.1f}steps")

# Check intervals
DISSONANT = {1, 2, 6, 10, 11}
print(f"\nDissonant interval check (semitone mod 12 in {DISSONANT}):")
bar68_list = sorted(bar68)
found_any = False
for i in range(len(bar68_list)):
    for j in range(i+1, len(bar68_list)):
        s1, e1, n1 = bar68_list[i]
        s2, e2, n2 = bar68_list[j]
        # Check if they overlap in time
        overlap = min(e1, e2) - max(s1, s2)
        interval = abs(n1 - n2) % 12
        if interval in DISSONANT:
            overlap_str = f"overlap={overlap/STEP_TICKS:.1f}steps" if overlap > 0 else "no_overlap"
            print(f"  {note_name(n1)}-{note_name(n2)}: interval={interval} semitones  {overlap_str}")
            found_any = True
if not found_any:
    print("  No dissonant intervals found among sounding notes.")

print()
# ─── ISSUE 4: Bars 96–120 ────────────────────────────────────────────────────
print("=" * 60)
print("ISSUE 4: Bars 96–120 (only bass, no melody?)")
print("=" * 60)

outro = notes_in_bars(notes, 96, 120)
bass = [(s,e,n) for s,e,n in outro if n < 55]
mid_ = [(s,e,n) for s,e,n in outro if 55 <= n <= 70]
high = [(s,e,n) for s,e,n in outro if n > 70]

print(f"Total notes in bars 96-120: {len(outro)}")
print(f"  Bass (<55):    {len(bass)}")
print(f"  Mid (55-70):   {len(mid_)}")
print(f"  High (>70):    {len(high)}")

if mid_:
    print(f"\nMid-range notes (55-70):")
    for s,e,n in sorted(mid_):
        print(f"  Bar {bar_of(s):3d} step {step_in_bar(s):2d}: {note_name(n):>6} (MIDI {n})  dur={((e-s)/STEP_TICKS):.1f}steps")

if high:
    print(f"\nHigh notes (>70):")
    for s,e,n in sorted(high):
        print(f"  Bar {bar_of(s):3d} step {step_in_bar(s):2d}: {note_name(n):>6} (MIDI {n})  dur={((e-s)/STEP_TICKS):.1f}steps")

if bass:
    print(f"\nBass notes sample (first 20):")
    for s,e,n in sorted(bass)[:20]:
        print(f"  Bar {bar_of(s):3d} step {step_in_bar(s):2d}: {note_name(n):>6} (MIDI {n})  dur={((e-s)/STEP_TICKS):.1f}steps")

# Bar-by-bar breakdown
print(f"\nBar-by-bar note counts (96-120):")
for bar_num in range(96, 121):
    bar_notes = notes_in_bars(notes, bar_num, bar_num)
    b = [(s,e,n) for s,e,n in bar_notes if n < 55]
    m = [(s,e,n) for s,e,n in bar_notes if 55 <= n <= 70]
    h = [(s,e,n) for s,e,n in bar_notes if n > 70]
    note_list = ", ".join(f"{note_name(n)}({n})" for _,__,n in sorted(bar_notes))
    print(f"  Bar {bar_num:3d}: bass={len(b)} mid={len(m)} high={len(h)}  {note_list}")

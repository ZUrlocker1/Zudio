#!/usr/bin/env python3
"""Analyze ambient MIDI files for chord grouping and bass note issues."""

import mido
import sys
from collections import defaultdict

NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']

def midi_note_name(n):
    octave = (n // 12) - 1
    return f"{NOTE_NAMES[n % 12]}{octave}"

def get_notes_with_timing(mid):
    """Extract all note-on events with absolute ticks, returning list of (tick, note, velocity, channel)."""
    notes = []
    abs_tick = 0
    for track in mid.tracks:
        abs_tick = 0
        for msg in track:
            abs_tick += msg.time
            if msg.type == 'note_on' and msg.velocity > 0:
                notes.append((abs_tick, msg.note, msg.velocity, msg.channel))
    return sorted(notes, key=lambda x: x[0])

def get_notes_with_duration(mid):
    """Extract note-on/off pairs with absolute ticks."""
    # Track note_on events, then match with note_off
    active = {}  # (channel, note) -> (start_tick, velocity)
    completed = []

    for track in mid.tracks:
        abs_tick = 0
        for msg in track:
            abs_tick += msg.time
            key = (msg.channel, msg.note) if hasattr(msg, 'note') else None
            if msg.type == 'note_on' and msg.velocity > 0:
                active[key] = (abs_tick, msg.velocity)
            elif msg.type == 'note_off' or (msg.type == 'note_on' and msg.velocity == 0):
                if key in active:
                    start, vel = active.pop(key)
                    duration = abs_tick - start
                    completed.append((start, msg.note, vel, msg.channel, duration))

    return sorted(completed, key=lambda x: x[0])

def group_by_window(notes, window=60):
    """Group notes that start within `window` ticks of each other."""
    if not notes:
        return []
    groups = []
    current_group = [notes[0]]
    group_start = notes[0][0]

    for note in notes[1:]:
        tick = note[0]
        if tick - group_start <= window:
            current_group.append(note)
        else:
            groups.append(current_group)
            current_group = [note]
            group_start = tick

    groups.append(current_group)
    return groups


# ============================================================
# TASK 1: Songs 07 and 08 — why 0 chord groups?
# ============================================================

files_task1 = [
    ("/Users/urlocker/Downloads/Zudio/tools/batch-output/ambient/ambient_07_AMB-PNO-001_1ff1ff62f5b60ee1.MID", "Song 07 (G MajorPentatonic 67 BPM 56 bars)"),
    ("/Users/urlocker/Downloads/Zudio/tools/batch-output/ambient/ambient_08_AMB-PNO-001_40b0700c2d928f63.MID", "Song 08 (G MajorPentatonic 66 BPM 56 bars)"),
]

for path, label in files_task1:
    print(f"\n{'='*70}")
    print(f"TASK 1: {label}")
    print(f"File: {path.split('/')[-1]}")
    print(f"{'='*70}")

    mid = mido.MidiFile(path)
    tpq = mid.ticks_per_beat
    print(f"Ticks per beat (TPQ): {tpq}")
    print(f"Tracks: {len(mid.tracks)}")
    for i, t in enumerate(mid.tracks):
        print(f"  Track {i}: name='{t.name}' msgs={len(t)}")

    notes = get_notes_with_timing(mid)
    print(f"\nTotal note-on events: {len(notes)}")

    bass_notes = [(t, n, v, c) for t, n, v, c in notes if n < 60]
    print(f"Notes below MIDI 60 (bass): {len(bass_notes)}")

    # Check for simultaneous (exact same tick)
    tick_to_notes = defaultdict(list)
    for t, n, v, c in notes:
        tick_to_notes[t].append(n)
    simultaneous_ticks = {t: ns for t, ns in tick_to_notes.items() if len(ns) > 1}
    print(f"Ticks with 2+ simultaneous notes: {len(simultaneous_ticks)}")
    if simultaneous_ticks:
        for t, ns in sorted(simultaneous_ticks.items())[:5]:
            print(f"  tick {t}: notes {[midi_note_name(n) for n in ns]}")

    # Group by 60-tick window
    groups = group_by_window(notes, window=60)
    chord_groups = [g for g in groups if len(g) > 1]
    print(f"\nGroups total (60-tick window): {len(groups)}")
    print(f"Chord groups (2+ notes): {len(chord_groups)}")

    if chord_groups:
        print("First few chord groups:")
        for g in chord_groups[:5]:
            print(f"  tick {g[0][0]}: {[(midi_note_name(n), t) for t, n, v, c in g]}")

    # Show first 30 notes with tick, pitch
    print(f"\nFirst 30 notes (tick, MIDI#, name, vel, ch):")
    for i, (t, n, v, c) in enumerate(notes[:30]):
        bar = t // (tpq * 4) + 1
        beat = (t % (tpq * 4)) // tpq + 1
        print(f"  [{i+1:2d}] tick={t:6d}  bar={bar:2d} beat={beat}  note={n:3d} ({midi_note_name(n):4s})  vel={v:3d}  ch={c}")

    # Show inter-note tick gaps for first 30 notes
    print(f"\nInter-note gaps (ticks between consecutive note-ons), first 30:")
    for i in range(1, min(30, len(notes))):
        gap = notes[i][0] - notes[i-1][0]
        print(f"  [{i-1}->{i}] gap={gap}")

    # Bass note detail
    if bass_notes:
        print(f"\nAll bass notes (MIDI < 60):")
        for t, n, v, c in bass_notes:
            bar = t // (tpq * 4) + 1
            print(f"  tick={t:6d} bar={bar:2d}  note={n:3d} ({midi_note_name(n):4s})  vel={v}  ch={c}")


# ============================================================
# TASK 2: Song 05 — list all bass notes below MIDI 60
# ============================================================

print(f"\n{'='*70}")
print(f"TASK 2: Song 05 (F# Dorian 62 BPM 48 bars, 150 notes, 29% bass)")
path05 = "/Users/urlocker/Downloads/Zudio/tools/batch-output/ambient/ambient_05_AMB-PNO-001_dd0e4f43add838f7.MID"
print(f"File: {path05.split('/')[-1]}")
print(f"{'='*70}")

mid = mido.MidiFile(path05)
tpq = mid.ticks_per_beat
print(f"TPQ: {tpq}")

# Get notes with duration
notes_dur = get_notes_with_duration(mid)
bass = [(t, n, v, c, d) for t, n, v, c, d in notes_dur if n < 60]
total = len(notes_dur)
print(f"Total notes: {total}")
print(f"Bass notes (< MIDI 60): {len(bass)} ({100*len(bass)//total}%)")
print()

TICKS_PER_BAR = tpq * 4  # 4/4 assumed; with tpq=480 that's 1920

print(f"{'Tick':>7}  {'Bar':>4}  {'MIDI':>4}  {'Name':>5}  {'Vel':>3}  {'Dur(ticks)':>10}  {'Dur(beats)':>10}")
print(f"{'-'*7}  {'-'*4}  {'-'*4}  {'-'*5}  {'-'*3}  {'-'*10}  {'-'*10}")
for t, n, v, c, d in sorted(bass, key=lambda x: x[0]):
    bar = t // TICKS_PER_BAR + 1
    beat_within_bar = (t % TICKS_PER_BAR) / tpq + 1
    dur_beats = d / tpq
    print(f"{t:7d}  {bar:4d}  {n:4d}  {midi_note_name(n):>5}  {v:3d}  {d:10d}  {dur_beats:10.2f}")

# Summarize which bars have bass
bar_counts = defaultdict(int)
for t, n, v, c, d in bass:
    bar = t // TICKS_PER_BAR + 1
    bar_counts[bar] += 1

print(f"\nBass notes per bar:")
for bar in sorted(bar_counts.keys()):
    print(f"  Bar {bar:2d}: {bar_counts[bar]} notes")

# Show pitch distribution
pitch_counts = defaultdict(int)
for t, n, v, c, d in bass:
    pitch_counts[midi_note_name(n)] += 1
print(f"\nBass pitch distribution:")
for name, count in sorted(pitch_counts.items(), key=lambda x: -x[1]):
    print(f"  {name}: {count}")

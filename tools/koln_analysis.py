#!/usr/bin/env python3
"""Detailed musical phrase analysis of Keith Jarrett - Köln Concert Part 1 MIDI"""

import mido
import sys
from collections import Counter, defaultdict
import statistics

MIDI_PATH = "/Users/urlocker/Downloads/Zudio/Keith Jarrett - Koln concert part 1.mid"

# ─── Load MIDI ────────────────────────────────────────────────────────────────
mid = mido.MidiFile(MIDI_PATH)
ticks_per_beat = mid.ticks_per_beat
print(f"Ticks per beat: {ticks_per_beat}")
print(f"Tracks: {len(mid.tracks)}")
for i, t in enumerate(mid.tracks):
    print(f"  Track {i}: '{t.name}' — {len(t)} messages")

# ─── Collect tempo map ────────────────────────────────────────────────────────
tempo_map = []  # list of (abs_tick, tempo_us)
abs_tick = 0
default_tempo = 500000  # 120 BPM

# Gather tempo from all tracks
raw_tempo_events = []
for track in mid.tracks:
    abs_tick = 0
    for msg in track:
        abs_tick += msg.time
        if msg.type == 'set_tempo':
            raw_tempo_events.append((abs_tick, msg.tempo))

raw_tempo_events.sort(key=lambda x: x[0])
if not raw_tempo_events or raw_tempo_events[0][0] > 0:
    tempo_map = [(0, default_tempo)] + raw_tempo_events
else:
    tempo_map = raw_tempo_events

print(f"\nTempo events: {len(tempo_map)}")
for tick, us in tempo_map[:10]:
    bpm = 60_000_000 / us
    print(f"  tick={tick:8d}  {us} µs/beat  = {bpm:.1f} BPM")
if len(tempo_map) > 10:
    print(f"  ... ({len(tempo_map)-10} more)")

def ticks_to_seconds(abs_tick_target):
    """Convert absolute tick to seconds using tempo map."""
    if not tempo_map:
        return abs_tick_target * default_tempo / (ticks_per_beat * 1_000_000)

    t = 0.0
    prev_tick = 0
    prev_tempo = default_tempo

    for ev_tick, ev_tempo in tempo_map:
        if ev_tick >= abs_tick_target:
            break
        t += (ev_tick - prev_tick) * prev_tempo / (ticks_per_beat * 1_000_000)
        prev_tick = ev_tick
        prev_tempo = ev_tempo

    t += (abs_tick_target - prev_tick) * prev_tempo / (ticks_per_beat * 1_000_000)
    return t

# ─── Collect all note events ──────────────────────────────────────────────────
# Merge all tracks into a single timeline of (abs_tick, msg)
all_events = []
for track in mid.tracks:
    abs_tick = 0
    for msg in track:
        abs_tick += msg.time
        if msg.type in ('note_on', 'note_off'):
            all_events.append((abs_tick, msg))

all_events.sort(key=lambda x: x[0])

# Build note list: (onset_tick, pitch, velocity, duration_tick, channel)
active_notes = {}  # (channel, pitch) -> onset_tick, velocity
notes = []

for abs_tick, msg in all_events:
    key = (msg.channel, msg.note)
    if msg.type == 'note_on' and msg.velocity > 0:
        active_notes[key] = (abs_tick, msg.velocity)
    elif msg.type == 'note_off' or (msg.type == 'note_on' and msg.velocity == 0):
        if key in active_notes:
            onset_tick, vel = active_notes.pop(key)
            dur_tick = abs_tick - onset_tick
            notes.append({
                'pitch': msg.note,
                'channel': msg.channel,
                'onset_tick': onset_tick,
                'offset_tick': abs_tick,
                'dur_tick': dur_tick,
                'velocity': vel,
            })

# Sort by onset
notes.sort(key=lambda n: (n['onset_tick'], n['pitch']))

# Add time in seconds
for n in notes:
    n['onset_s'] = ticks_to_seconds(n['onset_tick'])
    n['offset_s'] = ticks_to_seconds(n['offset_tick'])
    n['dur_s'] = n['offset_s'] - n['onset_s']

total_notes = len(notes)
total_duration_s = notes[-1]['offset_s'] if notes else 0
print(f"\nTotal notes: {total_notes}")
print(f"Total duration: {total_duration_s:.1f}s ({total_duration_s/60:.1f} min)")

PITCH_NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
def pitch_name(p):
    return f"{PITCH_NAMES[p%12]}{p//12 - 1}"

# ─── SECTION 1: First 80 Notes ───────────────────────────────────────────────
print("\n" + "="*80)
print("SECTION 1: FIRST 80 NOTES (note-by-note)")
print("="*80)
print(f"{'#':>4} {'Pitch':>6} {'MIDI':>5} {'Vel':>4} {'Onset(s)':>9} {'Dur(s)':>7} {'Dur(tk)':>8} {'IOI(s)':>7}")
print("-"*65)

opening_120s = [n for n in notes if n['onset_s'] < 120.0]
print(f"Notes in first 120s: {len(opening_120s)}")
print()

for i, n in enumerate(notes[:80]):
    if i + 1 < len(notes):
        ioi = notes[i+1]['onset_s'] - n['onset_s']
        ioi_str = f"{ioi:7.3f}"
    else:
        ioi_str = "    ---"
    pname = pitch_name(n['pitch'])
    print(f"{i+1:4d} {pname:>6} {n['pitch']:>5} {n['velocity']:>4} {n['onset_s']:>9.3f} {n['dur_s']:>7.3f} {n['dur_tick']:>8d} {ioi_str}")

# ─── SECTION 2: Velocity Profile ─────────────────────────────────────────────
print("\n" + "="*80)
print("SECTION 2: VELOCITY PROFILE")
print("="*80)

def velocity_stats(note_list, label):
    vels = [n['velocity'] for n in note_list]
    if not vels:
        return
    print(f"\n--- {label} (n={len(vels)}) ---")
    vels_sorted = sorted(vels)
    median = statistics.median(vels)
    p25 = vels_sorted[len(vels)//4]
    p75 = vels_sorted[3*len(vels)//4]
    print(f"  Min: {min(vels)}  Max: {max(vels)}  Mean: {statistics.mean(vels):.1f}")
    print(f"  Median: {median}  P25: {p25}  P75: {p75}")
    print(f"  StdDev: {statistics.stdev(vels):.1f}")
    print(f"  Below 30: {sum(1 for v in vels if v < 30)} ({100*sum(1 for v in vels if v < 30)/len(vels):.1f}%)")
    print(f"  Below 40: {sum(1 for v in vels if v < 40)} ({100*sum(1 for v in vels if v < 40)/len(vels):.1f}%)")
    print(f"  Below 50: {sum(1 for v in vels if v < 50)} ({100*sum(1 for v in vels if v < 50)/len(vels):.1f}%)")
    print(f"  Below 64: {sum(1 for v in vels if v < 64)} ({100*sum(1 for v in vels if v < 64)/len(vels):.1f}%)")
    print(f"  80-127:   {sum(1 for v in vels if v >= 80)} ({100*sum(1 for v in vels if v >= 80)/len(vels):.1f}%)")

    # Histogram in buckets of 10
    print("  Histogram (buckets of 10):")
    for lo in range(0, 128, 10):
        hi = lo + 10
        count = sum(1 for v in vels if lo <= v < hi)
        bar = '#' * (count * 50 // max(1, len(vels)))
        print(f"    {lo:3d}-{hi-1:3d}: {count:5d} {bar}")

velocity_stats(opening_120s, "Opening 120s")
velocity_stats(notes, "Full piece")

# ─── SECTION 3: Phrase Segmentation ──────────────────────────────────────────
print("\n" + "="*80)
print("SECTION 3: PHRASE SEGMENTATION (silence threshold = 1.5s)")
print("="*80)

SILENCE_THRESHOLD = 1.5  # seconds

phrases = []
current_phrase = []

for i, n in enumerate(notes):
    if not current_phrase:
        current_phrase = [n]
    else:
        # IOI from previous note onset to this note onset
        gap = n['onset_s'] - notes[i-1]['onset_s']
        # Also check if previous note has ended and there's silence
        prev_offset = notes[i-1]['offset_s']
        silence = n['onset_s'] - prev_offset
        if silence >= SILENCE_THRESHOLD:
            phrases.append(current_phrase)
            current_phrase = [n]
        else:
            current_phrase.append(n)

if current_phrase:
    phrases.append(current_phrase)

print(f"Total phrases found: {len(phrases)}")
print(f"Showing first 20 phrases:\n")

for pi, phrase in enumerate(phrases[:20]):
    start = phrase[0]['onset_s']
    end = phrase[-1]['offset_s']
    dur = end - start
    vels = [n['velocity'] for n in phrase]
    pitches = [n['pitch'] for n in phrase]

    if len(pitches) > 1:
        ascending = sum(1 for a, b in zip(pitches, pitches[1:]) if b > a)
        descending = sum(1 for a, b in zip(pitches, pitches[1:]) if b < a)
        if ascending > descending * 1.5:
            direction = "ascending"
        elif descending > ascending * 1.5:
            direction = "descending"
        else:
            direction = "mixed"
    else:
        direction = "single"

    pitch_names = [pitch_name(p) for p in pitches]
    print(f"Phrase {pi+1:2d}: t={start:6.1f}s  notes={len(phrase):3d}  dur={dur:5.1f}s  "
          f"vel={min(vels)}-{max(vels)}  dir={direction}")
    print(f"          pitches: {' '.join(pitch_names[:20])}" + (" ..." if len(pitch_names) > 20 else ""))

    # Gap before next phrase
    if pi + 1 < len(phrases):
        next_start = phrases[pi+1][0]['onset_s']
        gap_s = next_start - phrase[-1]['offset_s']
        print(f"          -> gap to next phrase: {gap_s:.2f}s")
    print()

# ─── SECTION 4: IOI Distribution ─────────────────────────────────────────────
print("\n" + "="*80)
print("SECTION 4: IOI DISTRIBUTION (opening 120s)")
print("="*80)

ioi_values = []
op_notes = [n for n in notes if n['onset_s'] < 120.0]
for i in range(len(op_notes) - 1):
    ioi = op_notes[i+1]['onset_s'] - op_notes[i]['onset_s']
    ioi_values.append(ioi)

if ioi_values:
    print(f"IOI count: {len(ioi_values)}")
    print(f"Min IOI: {min(ioi_values):.3f}s  Max IOI: {max(ioi_values):.3f}s")
    print(f"Mean IOI: {statistics.mean(ioi_values):.3f}s  Median: {statistics.median(ioi_values):.3f}s")
    print(f"Gaps > 1.0s: {sum(1 for v in ioi_values if v > 1.0)} ({100*sum(1 for v in ioi_values if v > 1.0)/len(ioi_values):.1f}%)")
    print(f"Gaps > 2.0s: {sum(1 for v in ioi_values if v > 2.0)} ({100*sum(1 for v in ioi_values if v > 2.0)/len(ioi_values):.1f}%)")
    print(f"Gaps > 4.0s: {sum(1 for v in ioi_values if v > 4.0)} ({100*sum(1 for v in ioi_values if v > 4.0)/len(ioi_values):.1f}%)")

    print("\nIOI Histogram (seconds):")
    buckets = [
        (0.0, 0.1), (0.1, 0.2), (0.2, 0.3), (0.3, 0.5), (0.5, 0.75),
        (0.75, 1.0), (1.0, 1.5), (1.5, 2.0), (2.0, 3.0), (3.0, 5.0), (5.0, 999)
    ]
    for lo, hi in buckets:
        count = sum(1 for v in ioi_values if lo <= v < hi)
        bar = '#' * (count * 60 // max(1, len(ioi_values)))
        label = f"{lo:.2f}-{hi:.2f}s" if hi < 999 else f"{lo:.2f}s+"
        print(f"  {label:12s}: {count:5d} {bar}")

    # Most common IOI values (rounded to 50ms)
    print("\nMost common IOI values (rounded to 50ms):")
    rounded = [round(v * 20) / 20 for v in ioi_values]
    ctr = Counter(rounded)
    for val, cnt in ctr.most_common(15):
        print(f"  {val:.3f}s: {cnt} occurrences ({100*cnt/len(ioi_values):.1f}%)")

# ─── SECTION 5: Note Duration Distribution ───────────────────────────────────
print("\n" + "="*80)
print("SECTION 5: NOTE DURATION DISTRIBUTION (opening 120s)")
print("="*80)

dur_values = [n['dur_s'] for n in opening_120s]
if dur_values:
    print(f"Note count: {len(dur_values)}")
    print(f"Min dur: {min(dur_values):.3f}s  Max dur: {max(dur_values):.3f}s")
    print(f"Mean dur: {statistics.mean(dur_values):.3f}s  Median: {statistics.median(dur_values):.3f}s")
    print(f"StdDev: {statistics.stdev(dur_values):.3f}s")

    print("\nDuration Histogram (seconds):")
    buckets = [
        (0.0, 0.1), (0.1, 0.2), (0.2, 0.3), (0.3, 0.5), (0.5, 0.75),
        (0.75, 1.0), (1.0, 1.5), (1.5, 2.0), (2.0, 3.0), (3.0, 5.0), (5.0, 999)
    ]
    for lo, hi in buckets:
        count = sum(1 for v in dur_values if lo <= v < hi)
        bar = '#' * (count * 60 // max(1, len(dur_values)))
        label = f"{lo:.2f}-{hi:.2f}s" if hi < 999 else f"{lo:.2f}s+"
        print(f"  {label:12s}: {count:5d} {bar}")

    print("\nMost common durations (rounded to 50ms):")
    rounded = [round(v * 20) / 20 for v in dur_values]
    ctr = Counter(rounded)
    for val, cnt in ctr.most_common(15):
        print(f"  {val:.3f}s: {cnt} occurrences ({100*cnt/len(dur_values):.1f}%)")

# ─── SECTION 6: Melodic Intervals ────────────────────────────────────────────
print("\n" + "="*80)
print("SECTION 6: MELODIC INTERVALS (opening 120s, within phrases)")
print("="*80)

# Build phrase list from opening 120s only
op_phrases = []
op_current = []
op_notes_sorted = [n for n in notes if n['onset_s'] < 120.0]

for i, n in enumerate(op_notes_sorted):
    if not op_current:
        op_current = [n]
    else:
        prev_offset = op_notes_sorted[i-1]['offset_s']
        silence = n['onset_s'] - prev_offset
        if silence >= SILENCE_THRESHOLD:
            op_phrases.append(op_current)
            op_current = [n]
        else:
            op_current.append(n)

if op_current:
    op_phrases.append(op_current)

# Collect intervals within phrases
interval_counts = Counter()
all_intervals = []
for phrase in op_phrases:
    pitches = [n['pitch'] for n in phrase]
    for a, b in zip(pitches, pitches[1:]):
        interval = b - a
        interval_counts[interval] += 1
        all_intervals.append(interval)

total_intervals = len(all_intervals)
print(f"Total within-phrase intervals: {total_intervals}")

if total_intervals > 0:
    steps = sum(v for k, v in interval_counts.items() if abs(k) in (1, 2))
    skips = sum(v for k, v in interval_counts.items() if abs(k) in (3, 4))
    leaps = sum(v for k, v in interval_counts.items() if 5 <= abs(k) <= 7)
    wide  = sum(v for k, v in interval_counts.items() if abs(k) >= 8)
    unison = interval_counts.get(0, 0)
    print(f"\nInterval categories:")
    print(f"  Unison (0st):      {unison:5d} ({100*unison/total_intervals:.1f}%)")
    print(f"  Step (1-2st):      {steps:5d} ({100*steps/total_intervals:.1f}%)")
    print(f"  Skip (3-4st):      {skips:5d} ({100*skips/total_intervals:.1f}%)")
    print(f"  Leap (5-7st):      {leaps:5d} ({100*leaps/total_intervals:.1f}%)")
    print(f"  Wide (8+st):       {wide:5d} ({100*wide/total_intervals:.1f}%)")

    print("\nAll interval sizes (most common, raw semitones):")
    for interval, cnt in sorted(interval_counts.items(), key=lambda x: -x[1])[:30]:
        sign = '+' if interval > 0 else ''
        bar = '#' * (cnt * 40 // max(1, total_intervals))
        print(f"  {sign}{interval:3d}st: {cnt:5d} ({100*cnt/total_intervals:.1f}%) {bar}")

# ─── SECTION 7: First 10 Phrase Interval Sequences ───────────────────────────
print("\n" + "="*80)
print("SECTION 7: FIRST 10 PHRASE SHAPES (exact interval sequences)")
print("="*80)

for pi, phrase in enumerate(phrases[:10]):
    pitches = [n['pitch'] for n in phrase]
    durations = [n['dur_s'] for n in phrase]
    onsets = [n['onset_s'] for n in phrase]
    vels = [n['velocity'] for n in phrase]

    print(f"\nPhrase {pi+1}: {len(phrase)} notes, starts at t={onsets[0]:.2f}s")
    print(f"  Root pitch: {pitch_name(pitches[0])} (MIDI {pitches[0]}), vel={vels[0]}")

    # IOIs within phrase
    iois_within = []
    for i in range(len(onsets)-1):
        iois_within.append(onsets[i+1] - onsets[i])

    # Build sequence string
    seq_parts = []
    for i, p in enumerate(pitches):
        dur = durations[i]
        vel = vels[i]
        pn = pitch_name(p)
        if i == 0:
            seq_parts.append(f"{pn}(v{vel},d{dur:.2f}s)")
        else:
            interval = pitches[i] - pitches[i-1]
            sign = '+' if interval >= 0 else ''
            ioi = iois_within[i-1]
            seq_parts.append(f"-ioi{ioi:.2f}s-> {sign}{interval}st={pn}(v{vel},d{dur:.2f}s)")

    # Print in chunks
    print(f"  Sequence:")
    line = "    "
    for part in seq_parts:
        if len(line) + len(part) > 100:
            print(line)
            line = "    " + part
        else:
            line += part + " "
    if line.strip():
        print(line)

    # Summary stats for phrase
    intervals = [pitches[i+1] - pitches[i] for i in range(len(pitches)-1)]
    if intervals:
        print(f"  Interval summary: min={min(intervals)}, max={max(intervals)}, "
              f"mean={statistics.mean(intervals):.1f}")
        print(f"  Dur summary: min={min(durations):.2f}s, max={max(durations):.2f}s, "
              f"mean={statistics.mean(durations):.2f}s")

    # Gap to next phrase
    if pi + 1 < len(phrases):
        gap = phrases[pi+1][0]['onset_s'] - phrase[-1]['offset_s']
        print(f"  Silence before next phrase: {gap:.2f}s")

# ─── BONUS: Register Analysis ────────────────────────────────────────────────
print("\n" + "="*80)
print("BONUS: REGISTER & PITCH DISTRIBUTION (opening 120s)")
print("="*80)

pitches_120 = [n['pitch'] for n in opening_120s]
if pitches_120:
    print(f"Pitch range: {min(pitches_120)} ({pitch_name(min(pitches_120))}) to {max(pitches_120)} ({pitch_name(max(pitches_120))})")
    print(f"Median pitch: {statistics.median(pitches_120):.0f} ({pitch_name(int(statistics.median(pitches_120)))})")

    print("\nRegister distribution (opening 120s):")
    registers = [
        ("Sub-bass (0-35, C-2 to B1)", 0, 35),
        ("Bass (36-47, C2-B2)",        36, 47),
        ("Low mid (48-59, C3-B3)",     48, 59),
        ("Mid (60-71, C4-B4)",         60, 71),
        ("Upper mid (72-83, C5-B5)",   72, 83),
        ("High (84-95, C6-B6)",        84, 95),
        ("Very high (96+)",            96, 127),
    ]
    for label, lo, hi in registers:
        count = sum(1 for p in pitches_120 if lo <= p <= hi)
        bar = '#' * (count * 40 // max(1, len(pitches_120)))
        print(f"  {label:35s}: {count:5d} ({100*count/len(pitches_120):.1f}%) {bar}")

# ─── BONUS: Channel usage ─────────────────────────────────────────────────────
print("\n" + "="*80)
print("BONUS: CHANNEL USAGE")
print("="*80)
chan_counts = Counter(n['channel'] for n in notes)
for ch, cnt in sorted(chan_counts.items()):
    print(f"  Channel {ch}: {cnt} notes")

print("\n=== ANALYSIS COMPLETE ===")

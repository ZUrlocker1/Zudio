#!/usr/bin/env python3
"""
Analyse Joy Division and PIL MIDI files for rhythm and lead patterns.
Focus: note density, rhythmic grid positions, durations, melodic contour,
silence blocks — to ground new Motorik Noir rules in real songs.
"""
import struct, sys, os, collections

FILES = [
    "Joy Division - Dead Souls.mid",
    "Joy Division - Love Will Tear Us Apart.mid",
    "Joy Division-Disorder.mid",
    "Joy Division-Shadowplay.mid",
    "Joy Division-She's Lost Control.mid",
    "Public Image Ltd - Albatross.mid",
    "Public Image Ltd - Annalisa.mid",
    "Public Image Ltd - Fodderstompf.mid",
    "Public Image Ltd - No Birds.mid",
    "Public Image Ltd - Religion.mid",
    "Public Image Ltd - Theme.mid",
    "Public Image Ltd - This is not a love song.mid",
]

BASE = "/Users/urlocker/Downloads/Zudio"
NOTE_NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']

def note_name(n):
    return f"{NOTE_NAMES[n%12]}{n//12-1}"

def read_vlq(data, pos):
    val = 0
    while True:
        b = data[pos]; pos += 1
        val = (val << 7) | (b & 0x7F)
        if not (b & 0x80): return val, pos

def parse_midi(path):
    with open(path, 'rb') as f: data = f.read()
    assert data[0:4] == b'MThd'
    hlen = struct.unpack('>I', data[4:8])[0]
    fmt, ntracks, tpq = struct.unpack('>HHH', data[8:14])
    pos = 8 + hlen
    tracks = []
    track_names = []
    for _ in range(ntracks):
        assert data[pos:pos+4] == b'MTrk'
        tlen = struct.unpack('>I', data[pos+4:pos+8])[0]
        tdata = data[pos+8:pos+8+tlen]; pos += 8 + tlen
        events = []; tick = 0; p = 0; last_status = 0
        name = ""
        while p < len(tdata):
            dt, p = read_vlq(tdata, p); tick += dt
            b = tdata[p]
            if b & 0x80: last_status = b; p += 1
            else: b = last_status
            cmd = b & 0xF0; ch = b & 0x0F
            if cmd in (0x80, 0x90):
                note = tdata[p]; vel = tdata[p+1]; p += 2
                events.append((tick, cmd, ch, note, vel))
            elif cmd in (0xA0, 0xB0, 0xE0): p += 2
            elif cmd in (0xC0, 0xD0): p += 1
            elif b == 0xFF:
                mtype = tdata[p]; p += 1
                mlen, p = read_vlq(tdata, p)
                if mtype == 0x03:
                    try: name = tdata[p:p+mlen].decode('latin-1')
                    except: pass
                p += mlen
            elif b in (0xF0, 0xF7):
                mlen, p = read_vlq(tdata, p); p += mlen
            else: p += 1
        tracks.append(events)
        track_names.append(name)
    return tracks, tpq, ntracks, track_names

def build_notes(events):
    """Return list of (start_tick, end_tick, note, vel, channel)."""
    pending = {}
    notes = []
    for tick, cmd, ch, note, vel in events:
        key = (ch, note)
        if cmd == 0x90 and vel > 0:
            pending[key] = (tick, vel)
        else:
            if key in pending:
                start, v = pending.pop(key)
                notes.append((start, tick if tick > start else start+1, note, v, ch))
    return sorted(notes)

def analyse_track(notes, tpq, label):
    if not notes: return
    bar_ticks = tpq * 4
    step_ticks = tpq // 4  # 16th note

    # Pitch range
    pitches = [n for _,_,n,_,_ in notes]
    lo, hi = min(pitches), max(pitches)

    # Compute note-on positions as 16th-step within bar
    step_positions = collections.Counter()
    durations_steps = []
    intervals = []
    prev_pitch = None

    bar_notes = collections.defaultdict(list)
    for start, end, note, vel, ch in notes:
        bar = start // bar_ticks
        step_in_bar = (start % bar_ticks) // step_ticks
        step_positions[step_in_bar] += 1
        dur = max(1, round((end - start) / step_ticks))
        durations_steps.append(dur)
        bar_notes[bar].append((step_in_bar, note, vel, dur))
        if prev_pitch is not None:
            intervals.append(note - prev_pitch)
        prev_pitch = note

    total_bars = max(bar_notes.keys()) + 1 if bar_notes else 0
    active_bars = len(bar_notes)
    silence_bars = total_bars - active_bars

    avg_notes_per_active_bar = len(notes) / max(1, active_bars)
    avg_dur = sum(durations_steps) / len(durations_steps)

    print(f"\n  [{label}]  pitch {note_name(lo)}-{note_name(hi)}  total_notes={len(notes)}  bars={total_bars}  active={active_bars}  silence={silence_bars}")
    print(f"    avg notes/active-bar={avg_notes_per_active_bar:.1f}  avg_dur={avg_dur:.1f} steps")

    # Top rhythmic positions
    top_steps = step_positions.most_common(8)
    step_desc = "  ".join(f"s{s}:{c}" for s,c in sorted(top_steps))
    print(f"    top step positions (0=beat1 4=beat2 8=beat3 12=beat4): {step_desc}")

    # Beat-vs-offbeat
    on_beat  = sum(c for s,c in step_positions.items() if s % 4 == 0)
    on_8th   = sum(c for s,c in step_positions.items() if s % 2 == 0 and s % 4 != 0)
    on_16th  = sum(c for s,c in step_positions.items() if s % 2 != 0)
    total_n  = len(notes)
    print(f"    beat positions: on-beat={on_beat}({100*on_beat//total_n}%)  8th-offbeat={on_8th}({100*on_8th//total_n}%)  16th={on_16th}({100*on_16th//total_n}%)")

    # Duration profile
    short = sum(1 for d in durations_steps if d <= 2)
    medium = sum(1 for d in durations_steps if 3 <= d <= 6)
    long_ = sum(1 for d in durations_steps if d >= 7)
    print(f"    dur profile: staccato(<=2)={short}({100*short//len(durations_steps)}%)  medium(3-6)={medium}({100*medium//len(durations_steps)}%)  long(>=7)={long_}({100*long_//len(durations_steps)}%)")

    # Interval profile
    if intervals:
        unison   = sum(1 for i in intervals if i == 0)
        semitone = sum(1 for i in intervals if abs(i) == 1)
        step2    = sum(1 for i in intervals if 2 <= abs(i) <= 3)
        leap     = sum(1 for i in intervals if abs(i) >= 4)
        descend  = sum(1 for i in intervals if i < 0)
        ascend   = sum(1 for i in intervals if i > 0)
        ti = len(intervals)
        print(f"    intervals: unison={unison}({100*unison//ti}%)  semitone={semitone}({100*semitone//ti}%)  step={step2}({100*step2//ti}%)  leap={leap}({100*leap//ti}%)")
        print(f"    direction: ascending={ascend}({100*ascend//ti}%)  descending={descend}({100*descend//ti}%)")

    # Silence blocks
    silent_runs = []
    in_sil = False; ss = 0
    for bar in range(total_bars + 1):
        has = bar in bar_notes
        if not has and not in_sil: ss = bar; in_sil = True
        elif has and in_sil:
            if bar - ss >= 2: silent_runs.append(bar - ss)
            in_sil = False
    if in_sil and total_bars - ss >= 2: silent_runs.append(total_bars - ss)
    if silent_runs:
        print(f"    silence runs (>=2 bars): {sorted(silent_runs, reverse=True)[:8]}")

    # Sample a few bars to show actual patterns
    sample_bars = sorted(bar_notes.keys())[:3]
    for bar in sample_bars:
        hits = bar_notes[bar]
        desc = "  ".join(f"s{s}:{note_name(n)}(d{d})" for s,n,v,d in sorted(hits))
        print(f"    bar{bar+1:3d}: {desc}")

    # Repeat-note detection (ostinato character)
    pitch_counts = collections.Counter(n for _,_,n,_,_ in notes)
    top_pitch, top_count = pitch_counts.most_common(1)[0]
    if top_count > len(notes) * 0.30:
        print(f"    *** OSTINATO: {note_name(top_pitch)} appears {top_count}x ({100*top_count//len(notes)}% of notes) — strong repeating pitch ***")

    # Detect held/drone notes (dur >= 8 steps)
    drone_notes = [(start, note, round((end-start)/step_ticks)) for start,end,note,vel,ch in notes
                   if round((end-start)/step_ticks) >= 8]
    if drone_notes:
        print(f"    *** DRONE: {len(drone_notes)} notes held >=8 steps — sample: " +
              ", ".join(f"{note_name(n)}({d}steps)" for _,n,d in drone_notes[:5]) + " ***")

for fname in FILES:
    path = os.path.join(BASE, fname)
    if not os.path.exists(path):
        print(f"MISSING: {fname}"); continue

    tracks, tpq, ntracks, track_names = parse_midi(path)
    print(f"\n{'='*70}")
    print(f"  {fname}  (tpq={tpq}, tracks={ntracks})")

    for ti, (events, tname) in enumerate(zip(tracks, track_names)):
        notes = build_notes(events)
        if not notes: continue
        channels = set(ch for _,_,_,_,ch in notes)
        is_drum = 9 in channels
        if is_drum: continue  # skip drums

        pitches_all = [n for _,_,n,_,_ in notes]
        register = "bass" if max(pitches_all) < 55 else ("mid" if max(pitches_all) < 72 else "upper")
        label = f"T{ti} '{tname}' ch={sorted(channels)} {register}"
        analyse_track(notes, tpq, label)

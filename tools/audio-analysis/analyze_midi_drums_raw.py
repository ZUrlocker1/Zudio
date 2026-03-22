import struct

def read_variable_length(data, pos):
    value = 0
    while True:
        byte = data[pos]; pos += 1
        value = (value << 7) | (byte & 0x7F)
        if not (byte & 0x80): break
    return value, pos

def parse_midi(filepath):
    with open(filepath, 'rb') as f:
        data = f.read()
    pos = 0
    assert data[pos:pos+4] == b'MThd'
    pos += 4 + 4
    fmt = struct.unpack('>H', data[pos:pos+2])[0]; pos += 2
    num_tracks = struct.unpack('>H', data[pos:pos+2])[0]; pos += 2
    ppq = struct.unpack('>H', data[pos:pos+2])[0]; pos += 2
    tracks = []
    for track_idx in range(num_tracks):
        assert data[pos:pos+4] == b'MTrk'
        pos += 4
        track_length = struct.unpack('>I', data[pos:pos+4])[0]; pos += 4
        track_end = pos + track_length
        events = []; current_tick = 0; running_status = None
        while pos < track_end:
            delta, pos = read_variable_length(data, pos)
            current_tick += delta
            if data[pos] == 0xFF:
                pos += 1; meta_type = data[pos]; pos += 1
                meta_len, pos = read_variable_length(data, pos)
                meta_data = data[pos:pos+meta_len]; pos += meta_len
                if meta_type == 0x51:
                    tempo = struct.unpack('>I', b'\x00' + meta_data)[0]
                    events.append({'type': 'tempo', 'tick': current_tick, 'tempo': tempo})
                elif meta_type == 0x03:
                    events.append({'type': 'track_name', 'tick': current_tick, 'name': meta_data.decode('latin-1', errors='replace')})
                elif meta_type == 0x2F:
                    events.append({'type': 'end_of_track', 'tick': current_tick})
                running_status = None
            elif data[pos] in (0xF0, 0xF7):
                pos += 1
                sysex_len, pos = read_variable_length(data, pos)
                pos += sysex_len; running_status = None
            else:
                if data[pos] & 0x80:
                    status = data[pos]; pos += 1; running_status = status
                else:
                    status = running_status
                msg_type = (status & 0xF0) >> 4; channel = status & 0x0F
                if msg_type in (0x8, 0x9):
                    note = data[pos]; pos += 1; velocity = data[pos]; pos += 1
                    etype = 'note_on' if (msg_type == 0x9 and velocity > 0) else 'note_off'
                    events.append({'type': etype, 'tick': current_tick, 'channel': channel, 'note': note, 'velocity': velocity})
                elif msg_type == 0xA: pos += 2
                elif msg_type == 0xB: pos += 2
                elif msg_type == 0xC: pos += 1
                elif msg_type == 0xD: pos += 1
                elif msg_type == 0xE: pos += 2
                else: break
        tracks.append(events); pos = track_end
    return fmt, num_tracks, ppq, tracks

fmt, num_tracks, ppq, tracks = parse_midi('/Users/urlocker/Downloads/Zudio/Aptos Storm Warning drums.mid')

ppq = 480
ticks_per_bar = ppq * 4
ticks_per_step = ppq // 4  # 120 ticks = 1/16th note

print("=== UNDERSTANDING THE ABSOLUTE TIMELINE ===")
print(f"Total duration: tick 0 to 153600")
print(f"Ticks per bar: {ticks_per_bar}")
print(f"Total bars: {153600 // ticks_per_bar} = {153600 // ticks_per_bar}")
print()

# Track 0 (tempo/meter track) runs to bar 81 (tick 153600)
# But drum tracks only go to:
#   Track 1: bar 5-6 (ticks 8640-11520)
#   Track 2: bar 6-10 (ticks 11175-19200)
#   Track 3: bar 10-18 (ticks 18720-34560)

# Wait -- tick 153600 / 1920 = 80. So the tempo track covers 80 bars.
# But drum events only go to bar 18 (tick ~34560). The rest is silence.

print("=== TRACK TIMELINE (absolute) ===")
# All drum events combined
all_drum_events = []
for track_idx in [1, 2, 3]:
    events = tracks[track_idx]
    drum_events = [e for e in events if e['type'] == 'note_on' and e['note'] != 60]
    for e in drum_events:
        all_drum_events.append({'track': track_idx, **e})

all_drum_events.sort(key=lambda x: x['tick'])

print(f"All drum events: {len(all_drum_events)}")
print(f"First event tick: {all_drum_events[0]['tick']} = bar {all_drum_events[0]['tick']//ticks_per_bar + 1}")
print(f"Last event tick:  {all_drum_events[-1]['tick']} = bar {all_drum_events[-1]['tick']//ticks_per_bar + 1}")
print()

# Unique drum notes
all_notes = sorted(set(e['note'] for e in all_drum_events))
GM_DRUMS = {
    35: "AcousticKick2", 36: "Kick", 37: "SideStick", 38: "Snare",
    39: "HandClap", 40: "Snare2", 41: "LowFloorTom",
    42: "ClosedHat", 43: "HiFloorTom", 44: "PedalHat",
    45: "LowMidTom", 46: "OpenHat", 47: "LowTom",
    48: "HiMidTom", 49: "Crash", 50: "HiTom",
    51: "Ride", 52: "Chinese", 53: "RideBell",
    54: "Tambourine", 55: "Splash", 56: "Cowbell",
    57: "Crash2", 58: "Vibraslap", 59: "Ride2",
    60: "HiBongo(marker)",
}
print("All drum notes used across all tracks:")
for n in all_notes:
    print(f"  {n}: {GM_DRUMS.get(n, f'note{n}')}")
print()

# Per-track velocity ranges
print("=== PER-TRACK VELOCITY RANGES ===")
for track_idx in [1, 2, 3]:
    events = tracks[track_idx]
    drum_events = [e for e in events if e['type'] == 'note_on' and e['note'] != 60]
    print(f"\nTrack {track_idx}:")
    note_set = sorted(set(e['note'] for e in drum_events))
    for n in note_set:
        hits = [e for e in drum_events if e['note'] == n]
        vels = [e['velocity'] for e in hits]
        print(f"  {n:3d} {GM_DRUMS.get(n,'?'):<16s}: vel {min(vels)}-{max(vels)}, avg {sum(vels)/len(vels):.1f}")

# Let's study step 11 pedal hat - it's at non-standard position
print("\n=== PEDAL HAT TIMING DETAILS (non-step positions) ===")
for track_idx in [1, 2, 3]:
    events = tracks[track_idx]
    pedal_events = [e for e in events if e['type'] == 'note_on' and e['note'] == 44]
    if pedal_events:
        print(f"\nTrack {track_idx} PedalHat ticks and steps:")
        for e in pedal_events:
            bar = e['tick'] // ticks_per_bar
            tick_in_bar = e['tick'] % ticks_per_bar
            step_float = tick_in_bar / ticks_per_step
            print(f"  tick={e['tick']:6d} bar={bar+1} tick_in_bar={tick_in_bar} step={step_float:.3f} vel={e['velocity']}")

# RideBell timing in track 3
print("\n=== RIDE BELL TIMING DETAILS ===")
for track_idx in [3]:
    events = tracks[track_idx]
    rb_events = [e for e in events if e['type'] == 'note_on' and e['note'] == 53]
    print(f"\nTrack {track_idx} RideBell:")
    for e in rb_events:
        bar = e['tick'] // ticks_per_bar
        tick_in_bar = e['tick'] % ticks_per_bar
        step_float = tick_in_bar / ticks_per_step
        print(f"  tick={e['tick']:6d} bar={bar+1} step={step_float:.3f} vel={e['velocity']}")

# Count deduplicated hits per note across all tracks
print("\n=== TOTAL UNIQUE HITS PER NOTE (all tracks combined, deduped by tick) ===")
from collections import defaultdict
note_ticks = defaultdict(set)
for e in all_drum_events:
    note_ticks[e['note']].add(e['tick'])
for n in sorted(note_ticks.keys()):
    print(f"  {n:3d} {GM_DRUMS.get(n,'?'):<16s}: {len(note_ticks[n])} unique hits")

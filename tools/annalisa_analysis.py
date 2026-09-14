import struct

def read_var_len(data, pos):
    value = 0
    while True:
        byte = data[pos]
        pos += 1
        value = (value << 7) | (byte & 0x7F)
        if not (byte & 0x80):
            break
    return value, pos

def note_name(n):
    names = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
    return names[n%12] + str(n//12 - 1)

def parse_midi(path):
    with open(path, 'rb') as f:
        data = f.read()
    pos = 0
    assert data[pos:pos+4] == b'MThd'
    pos += 4
    hlen = struct.unpack('>I', data[pos:pos+4])[0]; pos += 4
    fmt = struct.unpack('>H', data[pos:pos+2])[0]; pos += 2
    ntrk = struct.unpack('>H', data[pos:pos+2])[0]; pos += 2
    tpqn = struct.unpack('>H', data[pos:pos+2])[0]; pos += 2
    tracks = []
    for t in range(ntrk):
        assert data[pos:pos+4] == b'MTrk'
        pos += 4
        tlen = struct.unpack('>I', data[pos:pos+4])[0]; pos += 4
        track_end = pos + tlen
        events = []
        tick = 0
        running_status = None
        while pos < track_end:
            delta, pos = read_var_len(data, pos)
            tick += delta
            status_byte = data[pos]
            if status_byte == 0xFF:
                pos += 1
                meta_type = data[pos]; pos += 1
                meta_len, pos = read_var_len(data, pos)
                meta_data = data[pos:pos+meta_len]; pos += meta_len
                if meta_type == 0x51:
                    tempo = struct.unpack('>I', b'\x00' + meta_data)[0]
                    events.append(('tempo', tick, tempo))
                elif meta_type == 0x58:
                    events.append(('timesig', tick, meta_data))
                elif meta_type == 0x03:
                    events.append(('name', tick, meta_data.decode('latin-1', errors='replace')))
                elif meta_type == 0x2F:
                    events.append(('end', tick))
                running_status = None
            elif status_byte == 0xF0 or status_byte == 0xF7:
                pos += 1
                slen, pos = read_var_len(data, pos)
                pos += slen
                running_status = None
            elif status_byte & 0x80:
                running_status = status_byte
                pos += 1
                cmd = (status_byte >> 4) & 0xF
                ch = status_byte & 0xF
                if cmd in (8, 9, 0xA, 0xB, 0xE):
                    b1 = data[pos]; pos += 1
                    b2 = data[pos]; pos += 1
                    events.append(('msg', tick, cmd, ch, b1, b2))
                elif cmd in (0xC, 0xD):
                    b1 = data[pos]; pos += 1
                    events.append(('msg', tick, cmd, ch, b1, 0))
            else:
                if running_status is not None:
                    cmd = (running_status >> 4) & 0xF
                    ch = running_status & 0xF
                    if cmd in (8, 9, 0xA, 0xB, 0xE):
                        b1 = data[pos]; pos += 1
                        b2 = data[pos]; pos += 1
                        events.append(('msg', tick, cmd, ch, b1, b2))
                    elif cmd in (0xC, 0xD):
                        b1 = data[pos]; pos += 1
                        events.append(('msg', tick, cmd, ch, b1, 0))
                else:
                    pos += 1
        tracks.append(events)
    return fmt, ntrk, tpqn, tracks

def build_note_events(track_events):
    note_events = []
    active = {}
    for e in track_events:
        if e[0] != 'msg':
            continue
        cmd = e[2]; ch = e[3]; b1 = e[4]; b2 = e[5]
        tick = e[1]
        if cmd == 9 and b2 > 0:
            active[b1] = (tick, b2)
        elif cmd == 8 or (cmd == 9 and b2 == 0):
            if b1 in active:
                on_tick, vel = active.pop(b1)
                dur = tick - on_tick
                note_events.append((on_tick, b1, vel, dur))
    note_events.sort()
    return note_events

def show_track(name, events, bar_len, TPQN, max_bars=16):
    print(name + " first " + str(max_bars) + " bars:")
    for on_tick, note, vel, dur in events:
        bar = on_tick // bar_len
        if bar >= max_bars:
            break
        beat = (on_tick % bar_len) / float(TPQN)
        step16 = int((on_tick % bar_len) / (TPQN / 4))
        dur_16ths = dur / float(TPQN / 4)
        print("  bar=" + str(bar+1) + " step=" + str(step16+1) + " beat=" + str(round(beat,3)) + "  note=" + str(note) + " (" + note_name(note) + ") vel=" + str(vel) + " dur=" + str(round(dur_16ths,1)) + "x16")
    print()
    all_notes = sorted(set(n for _,n,_,_ in events))
    print("  Unique notes: " + str([(n, note_name(n)) for n in all_notes]))
    print()

path = "/Users/urlocker/Downloads/Zudio/Public Image Ltd - Annalisa.mid"
fmt, ntrk, tpqn, tracks = parse_midi(path)
TPQN = tpqn
bar_len = TPQN * 4

print("===== BASS TRACK (Track 3) =====")
bass = build_note_events(tracks[3])
show_track("Bass", bass, bar_len, TPQN, 16)

print("===== GUITAR 1 (Track 1) =====")
gtr1 = build_note_events(tracks[1])
show_track("Guitar1", gtr1, bar_len, TPQN, 16)

print("===== GUITAR 2 (Track 2) =====")
gtr2 = build_note_events(tracks[2])
show_track("Guitar2", gtr2, bar_len, TPQN, 16)

# Song-level structure: look for where tracks start/stop by identifying first/last note per section
print("===== SECTION ANALYSIS =====")
print("Total bars (main tempo section): 212")
print("Tail bars (120 BPM): 2 bars (bars 213-214)")

# Find where each instrument enters
for tname, tevents in [("Bass", bass), ("Guitar1", gtr1), ("Guitar2", gtr2)]:
    if tevents:
        first_bar = tevents[0][0] // bar_len
        last_bar = tevents[-1][0] // bar_len
        print(tname + ": first note bar=" + str(first_bar+1) + "  last note bar=" + str(last_bar+1))

# Drum entry
drum_on = [(e[1], e[4], e[5]) for e in tracks[4] if e[0]=='msg' and e[2]==9 and e[5]>0]
if drum_on:
    first_drum_bar = drum_on[0][0] // bar_len
    last_drum_bar = drum_on[-1][0] // bar_len
    print("Drums: first note bar=" + str(first_drum_bar+1) + "  last note bar=" + str(last_drum_bar+1))

# Look for sections by scanning drum variation changes over the full song
print()
print("===== DRUM VARIATION OVERVIEW (every 8 bars) =====")
drum_map = {
    35: 'K2', 36: 'KK', 37: 'Rim', 38: 'SN', 39: 'Clap',
    40: 'SN2', 42: 'HH_C', 44: 'HH_P', 46: 'HH_O',
    49: 'Crs1', 51: 'Ride', 57: 'Crs2'
}
bar_patterns = {}
for tick, note, vel in drum_on:
    bar = tick // bar_len
    step16 = int((tick % bar_len) / (TPQN / 4))
    nm = drum_map.get(note, str(note))
    if bar not in bar_patterns:
        bar_patterns[bar] = []
    bar_patterns[bar].append((step16+1, nm))

total_bars = max(bar_patterns.keys()) + 1
for start in range(0, total_bars, 8):
    end = min(start+8, total_bars)
    chunk_bars = [bar_patterns.get(b, []) for b in range(start, end)]
    nonempty = [b for b in chunk_bars if b]
    if nonempty:
        sample = sorted(bar_patterns.get(start, bar_patterns.get(start+1, [])))
        print("  Bars " + str(start+1) + "-" + str(end) + ": " + str(sample[:8]))

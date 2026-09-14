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
                if cmd in (8, 9, 10, 11, 14):
                    b1 = data[pos]; pos += 1
                    b2 = data[pos]; pos += 1
                    events.append(('msg', tick, cmd, ch, b1, b2))
                elif cmd in (12, 13):
                    b1 = data[pos]; pos += 1
                    events.append(('msg', tick, cmd, ch, b1, 0))
            else:
                if running_status is not None:
                    cmd = (running_status >> 4) & 0xF
                    ch = running_status & 0xF
                    if cmd in (8, 9, 10, 11, 14):
                        b1 = data[pos]; pos += 1
                        b2 = data[pos]; pos += 1
                        events.append(('msg', tick, cmd, ch, b1, b2))
                    elif cmd in (12, 13):
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

path = "/Users/urlocker/Downloads/Zudio/Public Image Ltd - Annalisa.mid"
fmt, ntrk, tpqn, tracks = parse_midi(path)
TPQN = tpqn
bar_len = TPQN * 4

bass = build_note_events(tracks[3])
gtr1 = build_note_events(tracks[1])
gtr2 = build_note_events(tracks[2])
drum_on = [(e[1], e[4], e[5]) for e in tracks[4] if e[0]=='msg' and e[2]==9 and e[5]>0]

print("=== BASS: bars 197-214 (outro) ===")
for on_tick, note, vel, dur in bass:
    bar = on_tick // bar_len
    if bar < 196:
        continue
    step16 = int((on_tick % bar_len) / (TPQN / 4))
    beat = (on_tick % bar_len) / float(TPQN)
    dur_16ths = dur / float(TPQN / 4)
    print("  bar=" + str(bar+1) + " step=" + str(step16+1) + " beat=" + str(round(beat,3)) + "  note=" + str(note) + " (" + note_name(note) + ") vel=" + str(vel) + " dur=" + str(round(dur_16ths,1)) + "x16")

print()
print("=== GTR2: bars 197-214 ===")
for on_tick, note, vel, dur in gtr2:
    bar = on_tick // bar_len
    if bar < 196:
        continue
    step16 = int((on_tick % bar_len) / (TPQN / 4))
    beat = (on_tick % bar_len) / float(TPQN)
    dur_16ths = dur / float(TPQN / 4)
    print("  bar=" + str(bar+1) + " step=" + str(step16+1) + " beat=" + str(round(beat,3)) + "  note=" + str(note) + " (" + note_name(note) + ") vel=" + str(vel) + " dur=" + str(round(dur_16ths,1)) + "x16")

# Now identify 2-bar repeating bass pattern
print()
print("=== BASS 2-BAR PATTERN (bars 1-2 = the template) ===")
bar1_2 = [(on_tick, n, v, d) for on_tick, n, v, d in bass if on_tick // bar_len < 2]
for on_tick, note, vel, dur in bar1_2:
    bar = on_tick // bar_len
    step16 = int((on_tick % bar_len) / (TPQN / 4))
    beat = (on_tick % bar_len) / float(TPQN)
    dur_16ths = dur / float(TPQN / 4)
    print("  bar=" + str(bar+1) + " step=" + str(step16+1) + "  note=" + str(note) + " (" + note_name(note) + ") vel=" + str(vel) + " dur=" + str(round(dur_16ths,1)) + "x16")

# Check how many total bass events there are and detect section changes
print()
print("=== BASS PITCH CHANGES OVER SONG (detect new sections) ===")
# Group bars by root note of first hit
bar_roots = {}
for on_tick, note, vel, dur in bass:
    bar = on_tick // bar_len
    if bar not in bar_roots:
        bar_roots[bar] = note

# Print where root changes
prev_root = None
for bar in sorted(bar_roots.keys()):
    root = bar_roots[bar]
    if root != prev_root:
        print("  Bar " + str(bar+1) + ": root = " + str(root) + " (" + note_name(root) + ")")
        prev_root = root

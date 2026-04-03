#!/usr/bin/env python3
"""
analyze_zudio.py — Zudio MIDI + log clash/density analyzer.

Usage:
    python3 tools/analyze_zudio.py                    # scan current dir for .MID files
    python3 tools/analyze_zudio.py Zudio-Foo.MID ...  # explicit files

For each .MID file it looks for a matching .zudio log (same base name) to read
key, mode, style, and track-rule info. Reports per-track clash %, density, and
out-of-scale note names.
"""

import struct, os, sys, re, collections

NOTE_NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
def note_name(n): return NOTE_NAMES[n % 12] + str(n // 12 - 1)

KEY_ST = {'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,
          'F#':6,'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}

SCALE_INTERVALS = {
    'Ionian':          [0,2,4,5,7,9,11],
    'Dorian':          [0,2,3,5,7,9,10],
    'Mixolydian':      [0,2,4,5,7,9,10],
    'Aeolian':         [0,2,3,5,7,8,10],
    'MinorPentatonic': [0,3,5,7,10],
    'MajorPentatonic': [0,2,4,7,9],
}

# ── MIDI parser ───────────────────────────────────────────────────────────────

def read_vlq(data, pos):
    val = 0
    while True:
        b = data[pos]; pos += 1
        val = (val << 7) | (b & 0x7F)
        if not (b & 0x80): break
    return val, pos

def parse_midi(path):
    with open(path, 'rb') as f:
        data = f.read()
    assert data[0:4] == b'MThd', "not a MIDI file"
    _, _, ntracks, tpq = struct.unpack('>IHHH', data[4:14])
    pos = 14
    tracks = []
    for _ in range(ntracks):
        assert data[pos:pos+4] == b'MTrk', f"bad MTrk at {pos}"
        tlen = struct.unpack('>I', data[pos+4:pos+8])[0]
        tend = pos + 8 + tlen
        tpos = pos + 8
        tick = 0; name = f"Track{len(tracks)}"; notes = []; active = {}; running = 0
        while tpos < tend:
            dt, tpos = read_vlq(data, tpos)
            tick += dt
            if tpos >= tend: break
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
                ml, tpos = read_vlq(data, tpos)
                tpos += ml
            elif cmd in (0x90, 0x80):
                note = data[tpos]; vel = data[tpos+1]; tpos += 2
                if cmd == 0x90 and vel > 0:
                    active[(running & 0x0F, note)] = (tick, vel)
                else:
                    key = (running & 0x0F, note)
                    if key in active:
                        st, sv = active.pop(key)
                        notes.append((st, note, sv, tick - st))
            elif cmd in (0xA0, 0xB0, 0xE0): tpos += 2
            elif cmd in (0xC0, 0xD0):       tpos += 1
        for (ch, note), (st, sv) in active.items():
            notes.append((st, note, sv, max(tpq, tick - st)))
        tracks.append({'name': name, 'notes': notes})
        pos = tend
    return tracks, tpq

# ── Zudio log parser ──────────────────────────────────────────────────────────

def parse_zudio_log(log_path):
    info = {'key': None, 'mode': None, 'style': None, 'tempo': None,
            'bars': None, 'rules': {}}
    if not os.path.exists(log_path):
        return info
    with open(log_path, 'r') as f:
        lines = f.readlines()
    in_log = False
    for line in lines:
        line = line.rstrip()
        s = line.strip()
        if s.startswith('Key:'):
            parts = s.split(None, 2)  # ['Key:', 'Bb', 'Dorian']
            if len(parts) >= 3:
                info['key']  = parts[1]
                info['mode'] = parts[2]
        elif s.startswith('Style:'):
            info['style'] = s.split(None, 1)[1].strip() if len(s.split(None,1)) > 1 else None
        elif s.startswith('Tempo:'):
            m = re.search(r'(\d+)', s)
            if m: info['tempo'] = int(m.group(1))
        elif s.startswith('Bars:'):
            m = re.search(r'(\d+)', s)
            if m: info['bars'] = int(m.group(1))
        elif s.startswith('--- Generation Log ---'):
            in_log = True
        elif in_log:
            # Lines like:  AMB-LEAD-003     Harold Budd pentatonic shimmer
            m = re.match(r'\s+(AMB-\S+|MOT-\S+|KOS-\S+)\s+(.*)', s)
            if m:
                info['rules'][m.group(1)] = m.group(2).strip()
    return info

# ── Analysis ──────────────────────────────────────────────────────────────────

def analyze(midi_path):
    log_path = os.path.splitext(midi_path)[0] + '.zudio'
    log  = parse_zudio_log(log_path)
    key  = log['key']
    mode = log['mode']

    has_log = key is not None and mode is not None
    scale = set()
    scale_names = []
    if has_log:
        root = KEY_ST.get(key, 0)
        intervals = SCALE_INTERVALS.get(mode, [])
        scale = set((root + i) % 12 for i in intervals)
        scale_names = [NOTE_NAMES[(root + i) % 12] for i in intervals]

    tracks, tpq = parse_midi(midi_path)
    total_notes = sum(len(t['notes']) for t in tracks)

    title = os.path.basename(midi_path)
    header = f"{title}"
    if has_log:
        header += f"  [{key} {mode}]"
    if log['style']:
        header += f"  {log['style']}"
    if log['tempo']:
        header += f"  {log['tempo']} BPM"
    if log['bars']:
        header += f"  {log['bars']} bars"

    print(f"\n{'='*72}")
    print(header)
    if has_log and scale_names:
        print(f"  Scale: {scale_names}")
    print(f"  TPQ={tpq}  Total notes={total_notes}")
    if log['rules']:
        rule_str = '  '.join(f"{k}={v[:20]}" for k, v in log['rules'].items())
        print(f"  Rules: {rule_str}")

    print()
    issues = []
    for t in tracks:
        notes = t['notes']
        if not notes:
            continue
        pitches = [n[1] for n in notes]
        vels    = [n[2] for n in notes]
        durs    = [n[3] for n in notes]

        if len(notes) > 1:
            first_tick = min(n[0] for n in notes)
            last_tick  = max(n[0] + n[3] for n in notes)
            approx_bars = (last_tick - first_tick) / (tpq * 4) if tpq else 1
        else:
            approx_bars = 1
        npb = len(notes) / max(1.0, approx_bars)

        avg_dur_b = (sum(durs) / len(durs)) / tpq / 4
        max_dur_b = max(durs) / tpq / 4

        if has_log and scale:
            oos = [p for p in pitches if p % 12 not in scale]
            pct = 100 * len(oos) / len(pitches)
            oos_names = sorted(set(note_name(p) for p in oos))[:8]
        else:
            pct = 0.0
            oos_names = []

        flag = ''
        if has_log and pct >= 20:
            flag = ' !!CLASH'
            issues.append(f"{t['name']}: {pct:.0f}% out-of-scale")
        elif has_log and pct >= 5:
            flag = ' !clash'
        if npb > 5:
            flag += ' !!DENSE'
            issues.append(f"{t['name']}: {npb:.1f} notes/bar")

        clash_str = f"clash={pct:5.1f}%" if has_log else ""
        oos_str   = f"oos={oos_names}" if oos_names else ""
        print(f"  [{t['name'][:26]:26s}] n={len(notes):4d}  n/bar={npb:4.1f}"
              f"  vel={min(vels):3d}-{max(vels):3d}"
              f"  dur avg={avg_dur_b:.2f}b"
              f"  {clash_str}  {oos_str}{flag}")

    if issues:
        print(f"\n  *** ISSUES: {'; '.join(issues)}")

# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    paths = sys.argv[1:]
    if not paths:
        # Default: scan current directory for .MID / .mid files
        cwd = os.getcwd()
        paths = sorted(
            f for f in os.listdir(cwd)
            if f.lower().endswith('.mid') and not f.startswith('.')
        )
        if not paths:
            print("No .MID files found in current directory.")
            print("Usage: python3 tools/analyze_zudio.py [file1.MID ...]")
            return
        print(f"Scanning {len(paths)} .MID files in {cwd}")
        paths = [os.path.join(cwd, p) for p in paths]

    for path in paths:
        if not os.path.exists(path):
            print(f"\nMISSING: {path}")
            continue
        try:
            analyze(path)
        except Exception as e:
            print(f"\nERROR analyzing {path}: {e}")
    print()

if __name__ == '__main__':
    main()

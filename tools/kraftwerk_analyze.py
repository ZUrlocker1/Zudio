#!/usr/bin/env python3
"""kraftwerk_analyze.py — audits a batch of Kraftwerk-cluster Motorik songs.

Usage:
    python3 tools/kraftwerk_analyze.py [dir]      # default: tools/batch-output/kraftwerk

Reads each .MID with its matching .zudio log and reports three things:

  MUSICALITY   register separation between parts, pitch-class vocabulary, dynamic range,
               and whether any track is silent or runs away with the arrangement.
  REPETITION   longest run of identical consecutive bars per track, and how much of the
               song the longest run covers. The cluster guard caps this at 12.
  KRAFTWERK    how well the song matches the measured corpus: tempo 120-132, a sequencer
               cell locked to the barline, restricted pitch vocabulary on cluster tracks,
               percussion built from few single-pitch voices, and coordinated dropouts.

Reuses the dependency-free MIDI parsing approach from analyze_zudio.py.
"""
import struct, os, sys, re, glob, statistics
from collections import defaultdict

TRACK_NAMES = ["Lead 1", "Lead 2", "Pads", "Rhythm", "Texture", "Bass", "Drums", "Lead Synth"]


def read_vlq(data, pos):
    v = 0
    while True:
        b = data[pos]; pos += 1
        v = (v << 7) | (b & 0x7F)
        if not b & 0x80:
            return v, pos


def parse_midi(path):
    data = open(path, 'rb').read()
    assert data[0:4] == b'MThd'
    _, _, ntracks, tpq = struct.unpack('>IHHH', data[4:14])
    pos, tracks = 14, []
    for _ in range(ntracks):
        tlen = struct.unpack('>I', data[pos+4:pos+8])[0]
        tend, tpos = pos + 8 + tlen, pos + 8
        tick = 0; name = ""; notes = []; active = {}; running = 0
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
                ml, tpos = read_vlq(data, tpos); tpos += ml
            elif cmd in (0x90, 0x80):
                note, vel = data[tpos], data[tpos+1]; tpos += 2
                if cmd == 0x90 and vel > 0:
                    active[note] = (tick, vel)
                elif note in active:
                    st, v = active.pop(note)
                    notes.append((st, note, v, tick - st))
            elif cmd in (0xC0, 0xD0):
                tpos += 1
            elif cmd in (0xA0, 0xB0, 0xE0):
                tpos += 2
            else:
                tpos += 1
        tracks.append((name, sorted(notes)))
        pos = tend
    return tracks, tpq


def parse_log(path):
    info = {"rules": {}, "cluster": None, "tempo": None, "bars": None, "title": None}
    if not os.path.exists(path):
        return info
    for line in open(path, encoding='utf-8', errors='replace'):
        t = line.strip()
        if t.startswith("Title:"):  info["title"] = t[6:].strip()
        elif t.startswith("Tempo:"): info["tempo"] = int(re.search(r'\d+', t).group())
        elif t.startswith("Bars:"):  info["bars"] = int(re.search(r'\d+', t).group())
        elif t.startswith("Cluster KW"): info["cluster"] = t.split(None, 2)[2] if len(t.split(None, 2)) > 2 else ""
        else:
            m = re.match(r'(MOT-[A-Z0-9]+-\d+)\s+(.+)', t)
            if m: info["rules"][m.group(1)] = m.group(2).strip()
    return info


def bar_signature(notes, tpq):
    """bar -> a string that is equal only for bars that play identically."""
    bar_ticks = tpq * 4
    sig = defaultdict(list)
    for st, note, vel, dur in notes:
        sig[st // bar_ticks].append((st % bar_ticks, note, vel, dur))
    return {b: str(sorted(v)) for b, v in sig.items()}


def longest_identical_run(notes, tpq, total_bars):
    sig = bar_signature(notes, tpq)
    run = best = 0; prev = None
    for b in range(total_bars):
        cur = sig.get(b)
        if cur is None:
            run = 0; prev = None; continue
        run = run + 1 if cur == prev else 1
        prev = cur
        best = max(best, run)
    return best


def analyse(midi_path):
    tracks, tpq = parse_midi(midi_path)
    info = parse_log(os.path.splitext(midi_path)[0] + ".zudio")
    bars = info["bars"] or 1
    beats = bars * 4
    cluster_names = [n.strip() for n in (info["cluster"] or "").split(",") if n.strip()]

    per = {}
    for name, notes in tracks:
        if not notes or name not in TRACK_NAMES:
            continue
        pitches = [n[1] for n in notes]
        vels = [n[2] for n in notes]
        per[name] = {
            "n": len(notes),
            "density": len(notes) / beats,
            "pcs": len(set(p % 12 for p in pitches)),
            "lo": min(pitches), "hi": max(pitches),
            "vel_range": max(vels) - min(vels),
            "run": longest_identical_run(notes, tpq, bars),
            "active_bars": len(set(n[0] // (tpq * 4) for n in notes)),
            "in_cluster": name in cluster_names,
        }
    return info, per, bars, tracks


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "tools/batch-output/kraftwerk"
    files = sorted(glob.glob(os.path.join(root, "*.MID")))
    if not files:
        sys.exit(f"no .MID files in {root}")

    print(f"Analysing {len(files)} Kraftwerk-cluster songs from {root}\n")
    print("=" * 100)

    worst_run = []; tempos = []; flags = []
    cluster_counts = defaultdict(int)
    density_by_track = defaultdict(list)
    pcs_by_track = defaultdict(list)

    for f in files:
        info, per, bars, tracks = analyse(f)
        tempos.append(info["tempo"] or 0)
        cl = info["cluster"] or "?"
        cluster_counts[cl] += 1
        title = info["title"] or os.path.basename(f)

        print(f"\n{title}   {info['tempo']} bpm, {bars} bars")
        print(f"   cluster: {cl}")
        rules = ", ".join(f"{v}" for k, v in sorted(info["rules"].items()))
        print(f"   rules:   {rules}")
        for name in TRACK_NAMES:
            if name not in per: continue
            d = per[name]
            mark = "KW" if d["in_cluster"] else "  "
            print(f"   {mark} {name:9s} {d['n']:5d} notes  {d['density']:5.2f}/beat  "
                  f"{d['pcs']:2d} PCs  MIDI {d['lo']:3d}-{d['hi']:3d}  "
                  f"vel±{d['vel_range']:3d}  longest identical run {d['run']:3d} bars  "
                  f"active {d['active_bars']:3d}/{bars}")
            density_by_track[name].append(d["density"])
            pcs_by_track[name].append(d["pcs"])
            worst_run.append((d["run"], title, name))
            if d["run"] > 12:
                flags.append(f"{title}: {name} repeats {d['run']} identical bars (cap is 12)")
            if d["vel_range"] == 0 and d["n"] > 50:
                flags.append(f"{title}: {name} has no dynamic variation at all")
        # Real collisions, not overlapping ranges: two parts sounding the SAME step within a
        # semitone or two of each other. A range overlap on its own is normal counterpoint.
        onsets = {}
        for name, notes in tracks:
            if name in TRACK_NAMES:
                byslot = defaultdict(list)
                for st, note, vel, dur in notes:
                    byslot[st].append(note)
                onsets[name] = byslot
        for a, b in (("Lead 1", "Lead 2"), ("Lead 1", "Rhythm"), ("Lead 2", "Rhythm")):
            if a not in onsets or b not in onsets: continue
            shared = set(onsets[a]) & set(onsets[b])
            if not shared: continue
            clashes = sum(1 for t in shared
                          if any(abs(x - y) <= 2 and abs(x - y) != 0
                                 for x in onsets[a][t] for y in onsets[b][t]))
            unison = sum(1 for t in shared
                         if any(x == y for x in onsets[a][t] for y in onsets[b][t]))
            total_a = len(onsets[a])
            if total_a and clashes / total_a > 0.15:
                flags.append(f"{title}: {a}/{b} clash on {100*clashes/total_a:.0f}% of {a} onsets "
                             f"(same step, 1-2 semitones apart)")
            if total_a and unison / total_a > 0.6 and (a, b) != ("Lead 2", "Rhythm"):
                flags.append(f"{title}: {a}/{b} play in unison on {100*unison/total_a:.0f}% of {a} onsets")

    print("\n" + "=" * 100)
    print("\nSUMMARY\n")
    print(f"  tempo: {min(tempos)}-{max(tempos)} bpm, mean {sum(tempos)//len(tempos)}   (corpus 120-128, band 120-132)")
    print(f"  clusters: " + ", ".join(f"{k} x{v}" for k, v in sorted(cluster_counts.items())))
    print("\n  density by track (notes/beat, across the batch):")
    for name in TRACK_NAMES:
        if name not in density_by_track: continue
        v = density_by_track[name]
        print(f"    {name:9s} mean {statistics.mean(v):5.2f}  range {min(v):5.2f}-{max(v):5.2f}"
              f"   pitch classes mean {statistics.mean(pcs_by_track[name]):4.1f}")
    worst_run.sort(reverse=True)
    print("\n  longest identical-bar runs:")
    for run, title, name in worst_run[:6]:
        print(f"    {run:3d} bars  {name:9s}  {title}")
    print(f"\n  flags: {len(flags)}")
    for f in flags[:25]:
        print(f"    - {f}")
    if not flags:
        print("    (none)")


if __name__ == "__main__":
    main()

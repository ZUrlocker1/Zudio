#!/usr/bin/env python3
"""
Zudio Motorik Study 01 — MIDI + Log Analysis
Analyzes 10 songs for: note density, lead overlap, consonance, density arc,
drum fill rate, bass density, and Motorik style issues.

Usage: python3 analyze_motorik_study01.py
Output: motorik_study01_findings.txt  (same directory as this script)
"""

import os, re, math
from collections import defaultdict

try:
    import mido
except ImportError:
    print("pip3 install mido"); exit(1)

# ── Constants ──────────────────────────────────────────────────────────────────

TRACKS = ["Lead1", "Lead2", "Pads", "Rhythm", "Texture", "Bass", "Drums"]
TRACK_IDX = {n: i for i, n in enumerate(TRACKS)}

STEPS_PER_BAR = 16   # 16th-note grid

# Mode → scale intervals (semitones above root, 0-based)
SCALE_INTERVALS = {
    "Dorian":     {0,2,3,5,7,9,10},
    "Aeolian":    {0,2,3,5,7,8,10},
    "Mixolydian": {0,2,4,5,7,9,10},
    "Ionian":     {0,2,4,5,7,9,11},
    "Phrygian":   {0,1,3,5,7,8,10},
    "Lydian":     {0,2,4,6,7,9,11},
}

KEY_SEMITONES = {"C":0,"C#":1,"Db":1,"D":2,"D#":3,"Eb":3,"E":4,"F":5,
                 "F#":6,"Gb":6,"G":7,"G#":8,"Ab":8,"A":9,"A#":10,"Bb":10,"B":11}

MIDI_DIR   = "/Users/urlocker/Downloads/Zudio"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# ── Log file parser ────────────────────────────────────────────────────────────

def parse_log(path):
    """Returns dict with key/mode/tempo/bars/mood/structure/rules/annotations."""
    d = {"rules": [], "structure": [], "chord_plan": [], "annotations": []}
    section = None
    for line in open(path):
        line = line.rstrip()
        if line.startswith("Key:"):
            parts = line.split()[1:]
            d["key"]  = parts[0]
            d["mode"] = parts[1] if len(parts) > 1 else "Dorian"
        elif line.startswith("Tempo:"):
            d["tempo"] = int(line.split()[1])
        elif line.startswith("Bars:"):
            d["bars"] = int(line.split()[1])
        elif line.startswith("Mood:"):
            d["mood"] = line.split()[1]
        elif line.startswith("--- Structure"):
            section = "structure"
        elif line.startswith("--- Chord Plan"):
            section = "chord_plan"
        elif line.startswith("--- Generation Log"):
            section = "gen_log"
        elif line.startswith("--- Playback Annotations"):
            section = "annotations"
        elif line.startswith("---"):
            section = None
        elif section == "structure" and "Bars" in line:
            m = re.match(r'\s+(\S+)\s+Bars\s+(\d+).*\((\d+) bars\)', line)
            if m:
                d["structure"].append({"label": m.group(1),
                                        "start": int(m.group(2)) - 1,
                                        "bars":  int(m.group(3))})
        elif section == "chord_plan" and "Bars" in line:
            m = re.match(r'\s+Bars\s+(\d+).*?(\d+)\s+root=(\S+)\s+type=(\S+)', line)
            if m:
                d["chord_plan"].append({"start": int(m.group(1)) - 1,
                                         "end":   int(m.group(2)) - 1,
                                         "root":  m.group(3),
                                         "type":  m.group(4)})
        elif section == "gen_log":
            m = re.match(r'\s+(MOT-\S+)\s+(.*)', line)
            if m:
                d["rules"].append(m.group(1))
        elif section == "annotations":
            # e.g. "  Bar 042    DRUM-FILL   fill type: crash..."
            m = re.match(r'\s+Bar\s+(\d+)\s+(\S+)\s+(.*)', line)
            if m:
                d["annotations"].append({
                    "bar": int(m.group(1)),
                    "tag": m.group(2),
                    "desc": m.group(3)
                })
    return d

# ── MIDI parser ────────────────────────────────────────────────────────────────

def midi_to_notes(path):
    """
    Returns list of {track, pitch, vel, start, end, start_bar, end_bar}
    Track 0-based: 0=Lead1 ... 6=Drums.
    """
    mid = mido.MidiFile(path)
    tpb = mid.ticks_per_beat
    ticks_per_bar = tpb * 4  # 4/4

    notes = []
    for t_idx, track in enumerate(mid.tracks):
        if t_idx == 0:
            continue  # tempo track
        abs_tick = 0
        open_notes = {}
        for msg in track:
            abs_tick += msg.time
            if msg.type == "note_on" and msg.velocity > 0:
                open_notes[msg.note] = (abs_tick, msg.velocity)
            elif msg.type == "note_off" or (msg.type == "note_on" and msg.velocity == 0):
                if msg.note in open_notes:
                    st, vel = open_notes.pop(msg.note)
                    notes.append({
                        "track":     t_idx - 1,
                        "pitch":     msg.note,
                        "vel":       vel,
                        "start":     st,
                        "end":       abs_tick,
                        "start_bar": st / ticks_per_bar,
                        "end_bar":   abs_tick / ticks_per_bar,
                    })
    return notes, tpb, ticks_per_bar

# ── Analysis helpers ───────────────────────────────────────────────────────────

def section_label_for_bar(bar, structure):
    for s in structure:
        if s["bars"] > 0 and s["start"] <= bar < s["start"] + s["bars"]:
            return s["label"]
    return "body"

def consonance_rate(notes, key, mode, track_idx):
    root  = KEY_SEMITONES.get(key, 0)
    scale = SCALE_INTERVALS.get(mode, SCALE_INTERVALS["Dorian"])
    track_notes = [n for n in notes if n["track"] == track_idx]
    if not track_notes:
        return None
    in_scale = sum(1 for n in track_notes if (n["pitch"] - root) % 12 in scale)
    return in_scale / len(track_notes)

def density_per_section(notes, structure, track_idx):
    section_counts = defaultdict(lambda: [0, 0])
    for s in structure:
        if s["bars"] > 0:
            section_counts[s["label"]][1] += s["bars"]
    track_notes = [n for n in notes if n["track"] == track_idx]
    for n in track_notes:
        bar   = int(n["start_bar"])
        label = section_label_for_bar(bar, structure)
        section_counts[label][0] += 1
    return {label: cnt / bars if bars > 0 else 0
            for label, (cnt, bars) in section_counts.items()}

def lead_overlap_rate(notes, structure):
    body_bars = {s["start"] + b for s in structure
                 if s["label"] not in ("intro", "outro") and s["bars"] > 0
                 for b in range(s["bars"])}
    if not body_bars:
        return 0
    step_tracks = defaultdict(set)
    for n in notes:
        if n["track"] not in (0, 1):
            continue
        if int(n["start_bar"]) not in body_bars:
            continue
        start_step = int(n["start_bar"] * 16)
        end_step   = int(n["end_bar"]   * 16)
        for step in range(start_step, end_step):
            step_tracks[step].add(n["track"])
    body_steps    = len(body_bars) * 16
    overlap_steps = sum(1 for s, ts in step_tracks.items() if 0 in ts and 1 in ts)
    return overlap_steps / body_steps if body_steps > 0 else 0

def density_arc(notes, track_idx, total_bars):
    slice_size = max(1, total_bars // 10)
    slices = []
    for i in range(10):
        bar_lo = i * slice_size
        bar_hi = (i + 1) * slice_size if i < 9 else total_bars
        count  = sum(1 for n in notes
                     if n["track"] == track_idx and bar_lo <= n["start_bar"] < bar_hi)
        bars   = bar_hi - bar_lo
        slices.append(count / bars if bars > 0 else 0)
    return slices

def drum_fill_rate(annotations, total_bars):
    """Returns count of drum fill events and fills/bar."""
    fills = [a for a in annotations if "DRUM" in a["tag"].upper() or "fill" in a["desc"].lower()]
    return len(fills), len(fills) / total_bars if total_bars > 0 else 0

def chord_window_lengths(chord_plan):
    lengths = []
    for cp in chord_plan:
        length = cp["end"] - cp["start"] + 1
        lengths.append(length)
    return lengths

def notes_per_bar_overall(notes, track_idx, total_bars):
    count = sum(1 for n in notes if n["track"] == track_idx)
    return count / total_bars if total_bars > 0 else 0

def pitch_range_per_track(notes, track_idx):
    pitches = [n["pitch"] for n in notes if n["track"] == track_idx]
    if not pitches:
        return None
    return {"min": min(pitches), "max": max(pitches),
            "range": max(pitches) - min(pitches), "n": len(pitches)}

def velocity_stats(notes, track_idx):
    vels = [n["vel"] for n in notes if n["track"] == track_idx]
    if not vels:
        return None
    mean = sum(vels) / len(vels)
    std  = math.sqrt(sum((v - mean) ** 2 for v in vels) / len(vels))
    return {"mean": round(mean, 1), "std": round(std, 1),
            "min": min(vels), "max": max(vels), "n": len(vels)}

# ── Per-song analysis ─────────────────────────────────────────────────────────

def analyze_song(name, midi_path, log_path):
    log   = parse_log(log_path)
    notes, tpb, ticks_per_bar = midi_to_notes(midi_path)
    total_bars = log.get("bars", 64)
    key        = log.get("key", "C")
    mode       = log.get("mode", "Dorian")
    structure  = log.get("structure", [])

    result = {
        "name":        name,
        "key":         key,
        "mode":        mode,
        "tempo":       log.get("tempo"),
        "bars":        total_bars,
        "mood":        log.get("mood"),
        "rules":       log.get("rules", []),
        "structure":   structure,
        "chord_plan":  log.get("chord_plan", []),
        "annotations": log.get("annotations", []),
    }

    # Note counts
    result["note_counts"] = {t: sum(1 for n in notes if n["track"] == i)
                              for i, t in enumerate(TRACKS)}

    # Notes/bar overall per track
    result["npb_overall"] = {t: notes_per_bar_overall(notes, i, total_bars)
                              for i, t in enumerate(TRACKS)}

    # Consonance per track (skip drums)
    result["consonance"] = {}
    for i, t in enumerate(TRACKS[:6]):
        result["consonance"][t] = consonance_rate(notes, key, mode, i)

    # Density by section
    result["density"] = {}
    for i, t in enumerate(TRACKS):
        result["density"][t] = density_per_section(notes, structure, i)

    # Lead overlap
    result["lead_overlap"] = lead_overlap_rate(notes, structure)

    # Density arc Lead1
    result["lead1_arc"] = density_arc(notes, 0, total_bars)

    # Density arc Drums
    result["drum_arc"] = density_arc(notes, 6, total_bars)

    # Drum fill rate from annotations
    fill_count, fill_per_bar = drum_fill_rate(log.get("annotations", []), total_bars)
    result["drum_fill_count"]   = fill_count
    result["drum_fill_per_bar"] = fill_per_bar

    # Chord window lengths
    result["chord_window_lengths"] = chord_window_lengths(log.get("chord_plan", []))

    # Pitch ranges
    result["lead1_range"] = pitch_range_per_track(notes, 0)
    result["lead2_range"] = pitch_range_per_track(notes, 1)
    result["bass_range"]  = pitch_range_per_track(notes, 5)

    # Velocity stats
    for i, t in enumerate(["Lead1", "Lead2", "Bass", "Drums"]):
        idx = [0, 1, 5, 6][i]
        result.setdefault("velocity", {})[t] = velocity_stats(notes, idx)

    return result

# ── Report helpers ─────────────────────────────────────────────────────────────

def fmt(v, decimals=2):
    if v is None: return "—"
    if isinstance(v, float): return f"{v:.{decimals}f}"
    return str(v)

def pct(v):
    if v is None: return "—"
    return f"{v*100:.1f}%"

# ── Report writer ──────────────────────────────────────────────────────────────

def write_report(songs):
    lines = []
    w = lines.append

    w("=" * 72)
    w("ZUDIO MOTORIK — STUDY 01 MIDI ANALYSIS")
    w(f"Songs: {len(songs)}   (generated 2026-03-23)")
    w("=" * 72)
    w("")

    # ── 1. Overview ───────────────────────────────────────────────────────────
    w("── 1. SONG OVERVIEW ──────────────────────────────────────────────────")
    w("")
    for s in songs:
        structure_str = " → ".join(
            f"{x['label']}({x['bars']})" for x in s["structure"] if x["bars"] > 0
        )
        w(f"  {s['name']:<22}  {s['key']:<3} {s['mode']:<11}  {s['tempo']} BPM  {s['bars']} bars  {s['mood']}")
        w(f"    {structure_str}")
    w("")

    # ── 2. Rule frequency ─────────────────────────────────────────────────────
    w("── 2. RULE FREQUENCY ─────────────────────────────────────────────────")
    w("")
    rule_counts = defaultdict(int)
    for s in songs:
        for r in s["rules"]:
            rule_counts[r] += 1
    for rule, count in sorted(rule_counts.items(), key=lambda x: -x[1]):
        bar_v = "█" * count
        flag  = "  ← ALL SONGS (unconditional?)" if count == len(songs) else ""
        w(f"  {rule:<26}  {bar_v:<12}  {count}/{len(songs)}{flag}")
    w("")

    # ── 3. Note counts ────────────────────────────────────────────────────────
    w("── 3. NOTE COUNTS PER TRACK ──────────────────────────────────────────")
    w("")
    w(f"  {'Song':<22}  {'Lead1':>6}  {'Lead2':>6}  {'Pads':>6}  {'Rhythm':>6}  {'Texture':>6}  {'Bass':>6}  {'Drums':>6}")
    w("  " + "-" * 68)
    for s in songs:
        nc = s["note_counts"]
        l1_flag = " ←sparse" if nc.get("Lead1", 0) < 30 else ""
        w(f"  {s['name']:<22}  {nc.get('Lead1',0):>6}  {nc.get('Lead2',0):>6}  {nc.get('Pads',0):>6}  {nc.get('Rhythm',0):>6}  {nc.get('Texture',0):>6}  {nc.get('Bass',0):>6}  {nc.get('Drums',0):>6}{l1_flag}")
    w("")

    # ── 4. Notes/bar overall ──────────────────────────────────────────────────
    w("── 4. NOTES/BAR OVERALL ─────────────────────────────────────────────")
    w("")
    w(f"  {'Song':<22}  {'Lead1':>6}  {'Lead2':>6}  {'Pads':>6}  {'Rhythm':>6}  {'Bass':>6}  {'Drums':>6}")
    w("  " + "-" * 62)
    for s in songs:
        nb = s["npb_overall"]
        w(f"  {s['name']:<22}  {fmt(nb.get('Lead1'),1):>6}  {fmt(nb.get('Lead2'),1):>6}  {fmt(nb.get('Pads'),1):>6}  {fmt(nb.get('Rhythm'),1):>6}  {fmt(nb.get('Bass'),1):>6}  {fmt(nb.get('Drums'),1):>6}")
    w("")
    w("  Motorik target: Drums 4-8/bar (steady Apache),  Bass 2-4/bar,  Lead1 1-4/bar")
    w("  Pads/Texture high density may create clutter against the Apache beat")
    w("")

    # ── 5. Consonance rates ───────────────────────────────────────────────────
    w("── 5. CONSONANCE RATES (fraction of notes in active mode's scale) ────")
    w("")
    w(f"  {'Song':<22}  {'Lead1':>7}  {'Lead2':>7}  {'Pads':>7}  {'Bass':>7}  {'Rhythm':>7}  {'Texture':>7}")
    w("  " + "-" * 68)
    for s in songs:
        c = s.get("consonance", {})
        flags = ""
        if c.get("Bass") is not None and c["Bass"] < 0.90:
            flags += " ←bass"
        if c.get("Lead1") is not None and c["Lead1"] < 0.72:
            flags += " ←lead1"
        w(f"  {s['name']:<22}  {pct(c.get('Lead1')):>7}  {pct(c.get('Lead2')):>7}  {pct(c.get('Pads')):>7}  {pct(c.get('Bass')):>7}  {pct(c.get('Rhythm')):>7}  {pct(c.get('Texture')):>7}{flags}")
    w("")
    w("  Target: Bass > 92%,  Leads > 72%")
    w("")

    # ── 6. Lead overlap ───────────────────────────────────────────────────────
    w("── 6. LEAD OVERLAP IN BODY SECTIONS ──────────────────────────────────")
    w("")
    for s in songs:
        bar_vis = "█" * int(s["lead_overlap"] * 40)
        flag    = "  ← HIGH" if s["lead_overlap"] > 0.30 else ""
        w(f"  {s['name']:<22}  {pct(s['lead_overlap']):>6}  {bar_vis}{flag}")
    w("")
    w("  Target: < 30% of body steps")
    w("")

    # ── 7. Lead 1 density by section ─────────────────────────────────────────
    w("── 7. LEAD 1 DENSITY BY SECTION (notes/bar) ──────────────────────────")
    w("")
    w(f"  {'Song':<22}  {'intro':>7}  {'bodyA':>7}  {'bodyB':>7}  {'bridge':>7}  {'outro':>7}")
    w("  " + "-" * 60)
    for s in songs:
        d = s.get("density", {}).get("Lead1", {})
        intro_d  = d.get("intro", 0)
        outro_d  = d.get("outro", 0)
        body_a   = d.get("bodyA", d.get("body", 0))
        body_b   = d.get("bodyB", 0)
        bridge_d = d.get("bridge", 0)
        w(f"  {s['name']:<22}  {fmt(intro_d,1):>7}  {fmt(body_a,1):>7}  {fmt(body_b,1):>7}  {fmt(bridge_d,1):>7}  {fmt(outro_d,1):>7}")
    w("")
    w("  Target: intro < 1.5,  bodyA 1-4,  bodyB 2-5,  outro < 2")
    w("")

    # ── 8. Lead 2 vs Lead 1 comparison ───────────────────────────────────────
    w("── 8. LEAD 1 vs LEAD 2 NOTE COUNT COMPARISON ─────────────────────────")
    w("")
    for s in songs:
        nc    = s["note_counts"]
        l1    = nc.get("Lead1", 0)
        l2    = nc.get("Lead2", 0)
        total = l1 + l2
        if total > 0:
            l1_pct = l1 / total * 100
            l2_pct = l2 / total * 100
            flag   = "  ← Lead2 dominant" if l2 > l1 else ""
            w(f"  {s['name']:<22}  L1={l1:>4} ({l1_pct:.0f}%)  L2={l2:>4} ({l2_pct:.0f}%){flag}")
        else:
            w(f"  {s['name']:<22}  no lead notes")
    w("")

    # ── 9. Drums density + fill rate ─────────────────────────────────────────
    w("── 9. DRUMS DENSITY + FILL RATE ──────────────────────────────────────")
    w("")
    w(f"  {'Song':<22}  {'notes':>7}  {'n/bar':>7}  {'fills':>7}  {'fills/bar':>10}  {'fills/16b':>10}")
    w("  " + "-" * 70)
    for s in songs:
        nc        = s["note_counts"]
        drum_n    = nc.get("Drums", 0)
        drum_npb  = s["npb_overall"].get("Drums", 0)
        fills     = s["drum_fill_count"]
        fpb       = s["drum_fill_per_bar"]
        f16       = fills / (s["bars"] / 16) if s["bars"] > 0 else 0
        flag      = "  ← high fills" if fills > 12 else ""
        w(f"  {s['name']:<22}  {drum_n:>7}  {fmt(drum_npb,1):>7}  {fills:>7}  {fmt(fpb,3):>10}  {fmt(f16,2):>10}{flag}")
    w("")
    w("  Motorik target: ~1 fill per 16-32 bars (0.03-0.06/bar).  Apache beat = relentless 4/4, fills break tension sparingly.")
    w("")

    # ── 10. Pads + Texture density ────────────────────────────────────────────
    w("── 10. PADS + TEXTURE DENSITY ────────────────────────────────────────")
    w("")
    w(f"  {'Song':<22}  {'pads_n':>7}  {'pads/bar':>9}  {'tex_n':>7}  {'tex/bar':>9}")
    w("  " + "-" * 56)
    for s in songs:
        nc     = s["note_counts"]
        pads_n = nc.get("Pads", 0)
        tex_n  = nc.get("Texture", 0)
        pnpb   = s["npb_overall"].get("Pads", 0)
        tnpb   = s["npb_overall"].get("Texture", 0)
        p_flag = " ←high" if pnpb > 5 else ""
        t_flag = " ←high" if tnpb > 3 else ""
        w(f"  {s['name']:<22}  {pads_n:>7}  {fmt(pnpb,1):>9}{p_flag}  {tex_n:>7}  {fmt(tnpb,1):>9}{t_flag}")
    w("")
    w("  High pads/texture density clashes with the Apache beat's open space aesthetic")
    w("")

    # ── 11. Bass density + register ───────────────────────────────────────────
    w("── 11. BASS DENSITY + REGISTER ───────────────────────────────────────")
    w("")
    w(f"  {'Song':<22}  {'n/bar':>6}  {'min_p':>6}  {'max_p':>6}  {'med_p':>6}")
    w("  " + "-" * 44)
    for s in songs:
        r    = s.get("bass_range")
        nb   = s["npb_overall"].get("Bass", 0)
        flag = "  ← overdense" if nb > 5 else ""
        if r:
            w(f"  {s['name']:<22}  {fmt(nb,1):>6}  {r['min']:>6}  {r['max']:>6}  {(r['min']+r['max'])//2:>6}{flag}")
        else:
            w(f"  {s['name']:<22}  {fmt(nb,1):>6}  —{flag}")
    w("")

    # ── 12. Chord plan window lengths ─────────────────────────────────────────
    w("── 12. CHORD PLAN — WINDOW LENGTHS ───────────────────────────────────")
    w("")
    for s in songs:
        cwl = s["chord_window_lengths"]
        if cwl:
            avg = sum(cwl) / len(cwl)
            mn  = min(cwl)
            mx  = max(cwl)
            flag = "  ← fast changes" if avg < 4 else ""
            w(f"  {s['name']:<22}  avg={fmt(avg,1)} bars  min={mn}  max={mx}  windows={len(cwl)}{flag}")
        else:
            w(f"  {s['name']:<22}  —")
    w("")

    # ── 13. Lead 1 density arc ────────────────────────────────────────────────
    w("── 13. LEAD 1 DENSITY ARC (notes/bar, 10 equal slices) ──────────────")
    w("")
    for s in songs:
        arc  = s.get("lead1_arc", [])
        mx   = max(arc) if arc else 1
        vis  = "".join(str(min(9, int(v / mx * 9))) if mx > 0 else "0" for v in arc)
        w(f"  {s['name']:<22}  [{vis}]  peak={fmt(max(arc) if arc else 0,1)} n/bar")
    w("")

    # ── 14. Drum arc ──────────────────────────────────────────────────────────
    w("── 14. DRUM DENSITY ARC (notes/bar, 10 equal slices) ────────────────")
    w("")
    for s in songs:
        arc = s.get("drum_arc", [])
        mx  = max(arc) if arc else 1
        vis = "".join(str(min(9, int(v / mx * 9))) if mx > 0 else "0" for v in arc)
        w(f"  {s['name']:<22}  [{vis}]  peak={fmt(max(arc) if arc else 0,1)} n/bar")
    w("")

    # ── 15. Issues summary ────────────────────────────────────────────────────
    w("── 15. ISSUES FLAGGED PER SONG ───────────────────────────────────────")
    w("")
    for s in songs:
        issues = []
        nc  = s["note_counts"]
        npb = s["npb_overall"]
        c   = s["consonance"]

        if nc.get("Lead1", 0) < 30 and s["bars"] > 60:
            issues.append(f"Lead1 very sparse: {nc['Lead1']} notes / {s['bars']} bars ({npb.get('Lead1',0):.2f}/bar)")
        if nc.get("Lead2", 0) > nc.get("Lead1", 1):
            issues.append(f"Lead2 ({nc['Lead2']}) > Lead1 ({nc['Lead1']}) — role inversion")
        if s["lead_overlap"] > 0.30:
            issues.append(f"Lead overlap high: {pct(s['lead_overlap'])}")
        if npb.get("Bass", 0) > 5.5:
            issues.append(f"Bass overdense: {npb['Bass']:.1f} n/bar")
        if npb.get("Pads", 0) > 5.5:
            issues.append(f"Pads overdense: {npb['Pads']:.1f} n/bar (clutter risk)")
        if npb.get("Texture", 0) > 3.5:
            issues.append(f"Texture overdense: {npb['Texture']:.1f} n/bar (clutter risk)")
        if s["drum_fill_per_bar"] > 0.08:
            issues.append(f"Drum fills too frequent: {s['drum_fill_count']} fills in {s['bars']} bars ({s['drum_fill_per_bar']:.3f}/bar)")
        if c.get("Bass") is not None and c["Bass"] < 0.90:
            issues.append(f"Bass consonance low: {pct(c['Bass'])}")
        if c.get("Lead1") is not None and c["Lead1"] < 0.72:
            issues.append(f"Lead1 consonance low: {pct(c['Lead1'])}")
        for t in ["Rhythm", "Texture", "Pads"]:
            if c.get(t) is not None and c[t] < 0.80:
                issues.append(f"{t} consonance low: {pct(c[t])}")
        # Non-tonic chord roots with dom7 — potential Modal Drift consonance issue
        non_tonic_dom7 = [cp for cp in s.get("chord_plan", [])
                          if cp["root"] not in ("1", "I", "root") and "7" in cp["type"]]
        if non_tonic_dom7:
            issues.append(f"Non-tonic dom7 chord roots: {len(non_tonic_dom7)} windows — check consonance")

        if issues:
            w(f"  {s['name']}:")
            for iss in issues:
                w(f"    • {iss}")
        else:
            w(f"  {s['name']}: no issues flagged")
    w("")

    # ── 16. Aggregate summary ─────────────────────────────────────────────────
    w("── 16. AGGREGATE SUMMARY ─────────────────────────────────────────────")
    w("")
    avg_overlap  = sum(s["lead_overlap"] for s in songs) / len(songs)
    sparse_lead1 = sum(1 for s in songs if s["npb_overall"].get("Lead1", 0) < 0.8)
    l2_dominant  = sum(1 for s in songs if s["note_counts"].get("Lead2", 0) > s["note_counts"].get("Lead1", 0))

    l1_cons_vals = [s["consonance"].get("Lead1") for s in songs if s["consonance"].get("Lead1") is not None]
    bass_cons_vals = [s["consonance"].get("Bass") for s in songs if s["consonance"].get("Bass") is not None]

    avg_fills  = sum(s["drum_fill_per_bar"] for s in songs) / len(songs)
    high_fills = sum(1 for s in songs if s["drum_fill_per_bar"] > 0.08)

    rule_counts = defaultdict(int)
    for s in songs:
        for r in s["rules"]:
            rule_counts[r] += 1
    universal_rules = [r for r, c in rule_counts.items() if c == len(songs)]

    w(f"  Average lead overlap:            {pct(avg_overlap)}  (target < 30%)")
    w(f"  Lead1 very sparse (<0.8/bar):    {sparse_lead1}/{len(songs)}")
    w(f"  Songs where Lead2 > Lead1:       {l2_dominant}/{len(songs)}")
    if l1_cons_vals:
        w(f"  Average Lead1 consonance:        {pct(sum(l1_cons_vals)/len(l1_cons_vals))}  (target > 72%)")
    if bass_cons_vals:
        w(f"  Average Bass consonance:         {pct(sum(bass_cons_vals)/len(bass_cons_vals))}  (target > 90%)")
    w(f"  Average drum fill rate:          {avg_fills:.4f}/bar")
    w(f"  Songs with high fill rate (>8%): {high_fills}/{len(songs)}")
    if universal_rules:
        w(f"  Rules in ALL {len(songs)} songs (unconditional?): {', '.join(sorted(universal_rules))}")
    w("")

    return "\n".join(lines)

# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    song_names = [
        "B-Loop", "E-Space", "Fahrt-Maschine", "Fahrt-Punkt", "Frei-Licht",
        "Gross-Lauf", "Leuchtet-Zeit", "Space-5", "TagNacht", "ZeitLicht"
    ]

    songs = []
    for name in song_names:
        midi_path = os.path.join(MIDI_DIR, f"Zudio-{name}.MID")
        log_path  = os.path.join(MIDI_DIR, f"Zudio-{name}.txt")
        if not os.path.exists(midi_path) or not os.path.exists(log_path):
            print(f"  MISSING: {name}  (midi={os.path.exists(midi_path)}, log={os.path.exists(log_path)})")
            continue
        print(f"  Analyzing {name}…")
        songs.append(analyze_song(name, midi_path, log_path))

    if not songs:
        print("No songs found.")
        return

    report   = write_report(songs)
    out_path = os.path.join(SCRIPT_DIR, "motorik_study01_findings.txt")
    with open(out_path, "w") as f:
        f.write(report)

    print(f"\nReport written → {out_path}")
    print(report)

if __name__ == "__main__":
    main()

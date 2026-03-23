#!/usr/bin/env python3
"""
Zudio Kosmic Study 02 — MIDI + Log Analysis
Analyzes 11 songs for: note density, lead overlap, consonance, density arc,
bass-chord agreement, register distribution, and velocity dynamics.

Usage: python3 analyze_study02.py
Output: study02_findings.txt  (same directory as this script)
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
TICKS_STEP    = None  # computed per file

# Mode → scale intervals (semitones above root, 0-based)
SCALE_INTERVALS = {
    "Dorian":     {0,2,3,5,7,9,10},
    "Aeolian":    {0,2,3,5,7,8,10},
    "Mixolydian": {0,2,4,5,7,9,10},
    "Ionian":     {0,2,4,5,7,9,11},
    "Phrygian":   {0,1,3,5,7,8,10},
}

KEY_SEMITONES = {"C":0,"C#":1,"Db":1,"D":2,"D#":3,"Eb":3,"E":4,"F":5,
                 "F#":6,"Gb":6,"G":7,"G#":8,"Ab":8,"A":9,"A#":10,"Bb":10,"B":11}

MIDI_DIR = "/Users/urlocker/Downloads/Zudio"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# ── Log file parser ────────────────────────────────────────────────────────────

def parse_log(path):
    """Returns dict with key/mode/tempo/bars/mood/structure/rules."""
    d = {"rules": [], "structure": [], "chord_plan": []}
    section = None
    for line in open(path):
        line = line.rstrip()
        if line.startswith("Key:"):
            parts = line.split()[1:]   # e.g. ["E", "Dorian"]
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
            m = re.match(r'\s+(KOS-\S+)\s+(.*)', line)
            if m:
                d["rules"].append(m.group(1))
    return d

# ── MIDI parser ───────────────────────────────────────────────────────────────

def midi_to_notes(path, ticks_per_bar_target=None):
    """
    Returns list of {track, pitch, vel, start_tick, end_tick} for note-on/off pairs.
    Track 0 = tempo track, tracks 1-7 = Lead1..Drums (Zudio format).
    """
    mid = mido.MidiFile(path)
    tpb = mid.ticks_per_beat   # ticks per quarter note
    ticks_per_bar = tpb * 4    # 4/4

    notes = []
    for t_idx, track in enumerate(mid.tracks):
        if t_idx == 0:
            continue   # tempo track
        abs_tick = 0
        open_notes = {}  # pitch → start_tick
        for msg in track:
            abs_tick += msg.time
            if msg.type == "note_on" and msg.velocity > 0:
                open_notes[msg.note] = (abs_tick, msg.velocity)
            elif msg.type == "note_off" or (msg.type == "note_on" and msg.velocity == 0):
                if msg.note in open_notes:
                    st, vel = open_notes.pop(msg.note)
                    notes.append({
                        "track": t_idx - 1,   # 0-based track index
                        "pitch": msg.note,
                        "vel":   vel,
                        "start": st,
                        "end":   abs_tick,
                        "start_bar": st / ticks_per_bar,
                        "end_bar":   abs_tick / ticks_per_bar,
                    })
    return notes, ticks_per_bar

# ── Analysis helpers ──────────────────────────────────────────────────────────

def section_label_for_bar(bar, structure):
    """Returns section label for a given 0-based bar index."""
    for s in structure:
        if s["bars"] > 0 and s["start"] <= bar < s["start"] + s["bars"]:
            return s["label"]
    return "body"

def consonance_rate(notes, key, mode, track_idx):
    """Fraction of notes whose pitch class is in the scale."""
    root = KEY_SEMITONES.get(key, 0)
    scale = SCALE_INTERVALS.get(mode, SCALE_INTERVALS["Dorian"])
    track_notes = [n for n in notes if n["track"] == track_idx]
    if not track_notes:
        return None
    in_scale = sum(1 for n in track_notes if (n["pitch"] - root) % 12 in scale)
    return in_scale / len(track_notes)

def density_per_section(notes, structure, track_idx):
    """Returns {section_label: notes_per_bar}."""
    section_counts = defaultdict(lambda: [0, 0])  # label → [note_count, bar_count]
    for s in structure:
        if s["bars"] > 0:
            section_counts[s["label"]][1] += s["bars"]

    track_notes = [n for n in notes if n["track"] == track_idx]
    for n in track_notes:
        bar = int(n["start_bar"])
        label = section_label_for_bar(bar, structure)
        section_counts[label][0] += 1

    result = {}
    for label, (cnt, bars) in section_counts.items():
        result[label] = cnt / bars if bars > 0 else 0
    return result

def lead_overlap_rate(notes, structure):
    """
    Fraction of 16th-step slots where BOTH lead1 and lead2 are sounding simultaneously.
    Only counts body bars (not intro/outro).
    """
    body_bars = {s["start"] + b for s in structure
                 if s["label"] not in ("intro", "outro") and s["bars"] > 0
                 for b in range(s["bars"])}
    if not body_bars:
        return 0

    # Build per-step active sets from all notes in body
    # Use a simple approach: for each note, mark every 16th step it covers
    step_tracks = defaultdict(set)
    # ticks_per_bar is baked into start_bar — reconstruct step index
    for n in notes:
        if n["track"] not in (0, 1):  # lead1=0, lead2=1
            continue
        bar_f = n["start_bar"]
        bar_i = int(bar_f)
        if bar_i not in body_bars:
            continue
        # Convert to 16th-step index
        start_step = int(n["start_bar"] * 16)
        end_step   = int(n["end_bar"]   * 16)
        for step in range(start_step, end_step):
            step_tracks[step].add(n["track"])

    body_steps = len(body_bars) * 16
    overlap_steps = sum(1 for s, ts in step_tracks.items()
                        if 0 in ts and 1 in ts)
    return overlap_steps / body_steps if body_steps > 0 else 0

def bass_register_analysis(notes):
    """Returns (min_pitch, max_pitch, median_pitch, fraction_below_48) for bass track."""
    bass = [n["pitch"] for n in notes if n["track"] == 5]
    if not bass:
        return None
    bass.sort()
    n = len(bass)
    return {
        "min":    bass[0],
        "max":    bass[-1],
        "median": bass[n // 2],
        "pct_below_48": sum(1 for p in bass if p < 48) / n,
        "pct_above_60": sum(1 for p in bass if p > 60) / n,
    }

def velocity_stats(notes, track_idx):
    """Returns (mean, std, min, max) velocity for a track."""
    vels = [n["vel"] for n in notes if n["track"] == track_idx]
    if not vels:
        return None
    mean = sum(vels) / len(vels)
    std  = math.sqrt(sum((v - mean) ** 2 for v in vels) / len(vels))
    return {"mean": round(mean, 1), "std": round(std, 1),
            "min": min(vels), "max": max(vels), "n": len(vels)}

def long_note_rate(notes, track_idx, ticks_per_bar, min_bars=0.5):
    """Fraction of notes that last >= min_bars."""
    track = [n for n in notes if n["track"] == track_idx]
    if not track:
        return None
    min_ticks = min_bars * ticks_per_bar
    return sum(1 for n in track if (n["end"] - n["start"]) >= min_ticks) / len(track)

def pitch_range_per_track(notes, track_idx):
    pitches = [n["pitch"] for n in notes if n["track"] == track_idx]
    if not pitches:
        return None
    return {"min": min(pitches), "max": max(pitches),
            "range": max(pitches) - min(pitches),
            "n": len(pitches)}

def density_arc(notes, track_idx, total_bars):
    """Split song into 10% slices, return notes/bar for each slice."""
    slice_size = max(1, total_bars // 10)
    slices = []
    for i in range(10):
        bar_lo = i * slice_size
        bar_hi = (i + 1) * slice_size if i < 9 else total_bars
        count = sum(1 for n in notes
                    if n["track"] == track_idx and bar_lo <= n["start_bar"] < bar_hi)
        bars = bar_hi - bar_lo
        slices.append(count / bars if bars > 0 else 0)
    return slices

# ── Per-song analysis ─────────────────────────────────────────────────────────

def analyze_song(name, midi_path, log_path):
    log  = parse_log(log_path)
    notes, tpb = midi_to_notes(midi_path)
    total_bars = log.get("bars", 64)
    key  = log.get("key", "C")
    mode = log.get("mode", "Dorian")
    structure = log.get("structure", [])

    result = {
        "name":      name,
        "key":       key,
        "mode":      mode,
        "tempo":     log.get("tempo"),
        "bars":      total_bars,
        "mood":      log.get("mood"),
        "rules":     log.get("rules", []),
        "structure": structure,
    }

    # Note counts
    result["note_counts"] = {t: sum(1 for n in notes if n["track"] == i)
                              for i, t in enumerate(TRACKS)}

    # Consonance per track
    for i, t in enumerate(TRACKS[:6]):  # skip drums
        r = consonance_rate(notes, key, mode, i)
        result.setdefault("consonance", {})[t] = r

    # Density by section per track
    for i, t in enumerate(TRACKS[:6]):
        result.setdefault("density", {})[t] = density_per_section(notes, structure, i)

    # Lead overlap
    result["lead_overlap"] = lead_overlap_rate(notes, structure)

    # Bass register
    result["bass_register"] = bass_register_analysis(notes)

    # Velocity stats for leads and bass
    for i, t in enumerate(["Lead1", "Lead2", "Bass"]):
        idx = [0, 1, 5][i]
        result.setdefault("velocity", {})[t] = velocity_stats(notes, idx)

    # Long note fraction for pads and bass (>= 1 bar)
    result["pads_long_note_rate"] = long_note_rate(notes, 2, tpb * 4)
    result["bass_long_note_rate"] = long_note_rate(notes, 5, tpb * 4)

    # Lead pitch range
    result["lead1_range"] = pitch_range_per_track(notes, 0)
    result["lead2_range"] = pitch_range_per_track(notes, 1)

    # Density arc for Lead1
    result["lead1_arc"] = density_arc(notes, 0, total_bars)

    return result

# ── Report writer ─────────────────────────────────────────────────────────────

def fmt(v, decimals=2):
    if v is None: return "—"
    if isinstance(v, float): return f"{v:.{decimals}f}"
    return str(v)

def pct(v):
    if v is None: return "—"
    return f"{v*100:.1f}%"

def write_report(songs, out_path):
    lines = []
    w = lines.append

    w("=" * 72)
    w("ZUDIO KOSMIC — STUDY 02 MIDI ANALYSIS")
    w(f"Songs: {len(songs)}   (generated 2026-03-23)")
    w("=" * 72)
    w("")

    # ── 1. Overview table ─────────────────────────────────────────────────────
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
        bar = "█" * count
        w(f"  {rule:<22}  {bar:<12}  {count}/{len(songs)}")
    w("")

    # ── 3. Note counts ────────────────────────────────────────────────────────
    w("── 3. NOTE COUNTS PER TRACK ──────────────────────────────────────────")
    w("")
    header = f"  {'Song':<22}  {'Lead1':>6}  {'Lead2':>6}  {'Pads':>6}  {'Rhythm':>6}  {'Texture':>6}  {'Bass':>6}  {'Drums':>6}"
    w(header)
    w("  " + "-" * 68)
    for s in songs:
        nc = s["note_counts"]
        w(f"  {s['name']:<22}  {nc.get('Lead1',0):>6}  {nc.get('Lead2',0):>6}  {nc.get('Pads',0):>6}  {nc.get('Rhythm',0):>6}  {nc.get('Texture',0):>6}  {nc.get('Bass',0):>6}  {nc.get('Drums',0):>6}")
    w("")

    # ── 4. Consonance rates ───────────────────────────────────────────────────
    w("── 4. CONSONANCE RATES (fraction of notes in active mode's scale) ────")
    w("")
    w(f"  {'Song':<22}  {'Lead1':>7}  {'Lead2':>7}  {'Pads':>7}  {'Bass':>7}  {'Rhythm':>7}")
    w("  " + "-" * 58)
    for s in songs:
        c = s.get("consonance", {})
        w(f"  {s['name']:<22}  {pct(c.get('Lead1')):>7}  {pct(c.get('Lead2')):>7}  {pct(c.get('Pads')):>7}  {pct(c.get('Bass')):>7}  {pct(c.get('Rhythm')):>7}")
    w("")
    w("  Target: Bass/Pads > 92%,  Leads > 72%")
    w("")

    # ── 5. Lead overlap ───────────────────────────────────────────────────────
    w("── 5. LEAD OVERLAP IN BODY SECTIONS ──────────────────────────────────")
    w("")
    for s in songs:
        bar_vis = "█" * int(s["lead_overlap"] * 40)
        flag = "  ← HIGH" if s["lead_overlap"] > 0.30 else ""
        w(f"  {s['name']:<22}  {pct(s['lead_overlap']):>6}  {bar_vis}{flag}")
    w("")
    w("  Target: < 30% of body steps")
    w("")

    # ── 6. Density by section ─────────────────────────────────────────────────
    w("── 6. LEAD 1 DENSITY BY SECTION (notes/bar) ──────────────────────────")
    w("")
    w(f"  {'Song':<22}  {'intro':>7}  {'body':>7}  {'outro':>7}")
    w("  " + "-" * 45)
    for s in songs:
        d = s.get("density", {}).get("Lead1", {})
        intro_d  = d.get("intro", 0)
        outro_d  = d.get("outro", 0)
        # Aggregate non-intro/outro sections as body
        body_sections = [k for k in d if k not in ("intro","outro")]
        if body_sections:
            body_notes = sum(s["note_counts"].get("Lead1", 0)
                             * (d[k] / sum(d[k2] for k2 in body_sections if d[k2] > 0 or True))
                             for k in body_sections)
            # Simpler: average across body section labels
            body_vals = [v for k, v in d.items() if k not in ("intro","outro") and v > 0]
            body_d = sum(body_vals) / len(body_vals) if body_vals else 0
        else:
            body_d = 0
        w(f"  {s['name']:<22}  {fmt(intro_d, 1):>7}  {fmt(body_d, 1):>7}  {fmt(outro_d, 1):>7}")
    w("")
    w("  Target: intro < 1.5,  body 2-5,  outro < 2")
    w("")

    # ── 7. Bass register ─────────────────────────────────────────────────────
    w("── 7. BASS REGISTER ANALYSIS ─────────────────────────────────────────")
    w("")
    w(f"  {'Song':<22}  {'min':>5}  {'max':>5}  {'med':>5}  {'>60':>7}  {'<48':>7}")
    w("  " + "-" * 55)
    for s in songs:
        r = s.get("bass_register")
        if r:
            w(f"  {s['name']:<22}  {r['min']:>5}  {r['max']:>5}  {r['median']:>5}  {pct(r['pct_above_60']):>7}  {pct(r['pct_below_48']):>7}")
        else:
            w(f"  {s['name']:<22}  —")
    w("")
    w("  KOS-RULE-06 target: MIDI 40–55 (C2–G3).  >60 = too high, invades lead space.")
    w("")

    # ── 8. Lead velocity stats ────────────────────────────────────────────────
    w("── 8. LEAD 1 VELOCITY STATS ──────────────────────────────────────────")
    w("")
    w(f"  {'Song':<22}  {'mean':>6}  {'std':>6}  {'min':>5}  {'max':>5}")
    w("  " + "-" * 47)
    for s in songs:
        v = s.get("velocity", {}).get("Lead1")
        if v:
            w(f"  {s['name']:<22}  {v['mean']:>6}  {v['std']:>6}  {v['min']:>5}  {v['max']:>5}")
        else:
            w(f"  {s['name']:<22}  —")
    w("")

    # ── 9. Density arcs (Lead 1) ──────────────────────────────────────────────
    w("── 9. LEAD 1 DENSITY ARC (notes/bar, 10 equal slices across song) ───")
    w("")
    for s in songs:
        arc = s.get("lead1_arc", [])
        # Normalise to 0-8 chars per slice
        mx = max(arc) if arc else 1
        bar_vis = "".join(
            str(min(9, int(v / mx * 9))) if mx > 0 else "0"
            for v in arc
        )
        w(f"  {s['name']:<22}  [{bar_vis}]  peak={fmt(max(arc) if arc else 0,1)} n/bar")
    w("")

    # ── 10. Structural anomalies ──────────────────────────────────────────────
    w("── 10. STRUCTURAL / CHORD ANOMALIES ──────────────────────────────────")
    w("")
    for s in songs:
        issues = []
        # Check for zero-bar sections (preRamp/postRamp with 0 bars still logged)
        zero_sec = [x["label"] for x in s["structure"] if x["bars"] == 0]
        if zero_sec:
            issues.append(f"zero-bar sections in log: {zero_sec}")
        # Check chord plan for root-1-only songs (no harmonic movement)
        roots = set()
        for cp in s.get("structure", []):
            pass
        cp_roots = set()
        # Re-parse from log (already in result)
        # Single-chord songs: check note variety
        nc = s["note_counts"]
        if nc.get("Lead1", 0) < 20 and s["bars"] > 60:
            issues.append(f"Lead1 very sparse: {nc['Lead1']} notes over {s['bars']} bars ({nc['Lead1']/s['bars']:.2f}/bar)")
        if nc.get("Rhythm", 0) > 1500:
            issues.append(f"Rhythm very dense: {nc['Rhythm']} notes")
        if nc.get("Bass", 0) > 800:
            issues.append(f"Bass very dense: {nc['Bass']} notes")
        # Bass above 60
        r = s.get("bass_register")
        if r and r["pct_above_60"] > 0.10:
            issues.append(f"Bass above MIDI 60: {pct(r['pct_above_60'])} of notes (invades lead register)")
        # Low consonance
        c = s.get("consonance", {})
        for t in ["Lead1", "Lead2", "Bass"]:
            if c.get(t) is not None and c[t] < 0.72:
                issues.append(f"{t} consonance low: {pct(c[t])}")
        # High lead overlap
        if s["lead_overlap"] > 0.30:
            issues.append(f"Lead overlap high: {pct(s['lead_overlap'])}")

        if issues:
            w(f"  {s['name']}:")
            for iss in issues:
                w(f"    • {iss}")
        else:
            w(f"  {s['name']}: no issues flagged")
    w("")

    # ── 11. Aggregate findings ────────────────────────────────────────────────
    w("── 11. AGGREGATE FINDINGS ────────────────────────────────────────────")
    w("")

    avg_overlap = sum(s["lead_overlap"] for s in songs) / len(songs)
    w(f"  Average lead overlap:    {pct(avg_overlap)}  (target < 30%)")

    avg_l1_cons = [s["consonance"].get("Lead1") for s in songs if s["consonance"].get("Lead1")]
    if avg_l1_cons:
        w(f"  Average Lead1 consonance: {pct(sum(avg_l1_cons)/len(avg_l1_cons))}  (target > 72%)")

    avg_bass_cons = [s["consonance"].get("Bass") for s in songs if s["consonance"].get("Bass")]
    if avg_bass_cons:
        w(f"  Average Bass consonance:  {pct(sum(avg_bass_cons)/len(avg_bass_cons))}  (target > 92%)")

    no_drums = sum(1 for s in songs if s["note_counts"].get("Drums", 0) == 0)
    w(f"  No-drums songs:          {no_drums}/{len(songs)}")

    sparse_lead1 = sum(1 for s in songs
                       if s["note_counts"].get("Lead1", 0) / s["bars"] < 0.8)
    w(f"  Lead1 very sparse (<0.8/bar): {sparse_lead1}/{len(songs)}")

    bass_above_rule = sum(1 for s in songs
                          if s.get("bass_register") and s["bass_register"]["pct_above_60"] > 0.05)
    w(f"  Bass above MIDI 60 (>5%): {bass_above_rule}/{len(songs)}")

    w("")

    return "\n".join(lines)

# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    song_names = [
        "Auxese", "Deep-Solstice", "Ewig-Leere", "Flexure", "Fluxion",
        "Galaxie-VIII", "Polar-Horizon", "Proxima-III", "Solaxe",
        "Void-Ether", "Vortexe-VI"
    ]

    songs = []
    for name in song_names:
        midi_path = os.path.join(MIDI_DIR, f"Zudio-{name}.MID")
        log_path  = os.path.join(MIDI_DIR, f"Zudio-{name}.txt")
        if not os.path.exists(midi_path) or not os.path.exists(log_path):
            print(f"  MISSING: {name}")
            continue
        print(f"  Analyzing {name}…")
        songs.append(analyze_song(name, midi_path, log_path))

    report = write_report(songs, SCRIPT_DIR)

    out_path = os.path.join(SCRIPT_DIR, "study02_findings.txt")
    with open(out_path, "w") as f:
        f.write(report)

    print(f"\nReport written → {out_path}")
    print(report)

if __name__ == "__main__":
    main()

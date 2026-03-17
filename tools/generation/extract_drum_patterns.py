#!/usr/bin/env python3
"""
extract_drum_patterns.py

Extracts and derives motorik drum patterns from the analysed Drumscribe MIDI file
and writes them to assets/midi/motorik/drums/drum-patterns-v1.json.

This script encodes the musical decisions made during the MIDI analysis session:
  - Core A groove  (bars 1-32 of source: medium intensity, 5-kick pattern)
  - Core B groove  (bars 33-128 of source: high intensity, 6-kick pattern)
  - Sparse, intro, outro variants (derived/reduced)
  - Accent variants: section-start crash, ride, open-hat lift
  - Fill patterns extracted from section-boundary fill bars in the source

Source file facts (from analyze_midi_drums.py):
  - Drumscribe - Motorik - MIDI.mid
  - Format 0, 1 track, TPQ=480, 130 BPM
  - 139 bars total, 68 analysed 2-bar blocks
  - Two main groove families (A: blocks 0-15, B: blocks 16-63)
  - Fill bars occur at the second bar of every 8th block

Kick pattern detail:
  Core A: steps 0, 2, 6, 8, 14  (beat 1, 1-and, 2-and, beat 3, 4-and)
  Core B: steps 0, 2, 6, 8, 10, 14  (adds 3-and)

Hat pattern (both cores): steps 2, 4, 6, 8, 10, 12, 14
  Note: hat is absent on step 0 (kick alone on beat 1) — characteristic motorik spacing.

Usage:
    python3 extract_drum_patterns.py
    python3 extract_drum_patterns.py --out /path/to/output.json
"""

import json
import argparse
from pathlib import Path

# ---------------------------------------------------------------------------
# GM drum note constants
# ---------------------------------------------------------------------------
KICK      = 36
SNARE     = 38
SNARE2    = 40   # electric snare, used in fills
CHATHAT   = 42   # closed hi-hat
OHAT      = 46   # open hi-hat
FTOM_LO   = 41   # low floor tom
FTOM_HI   = 43   # high floor tom
HI_TOM    = 48   # hi-mid tom
LO_TOM    = 47   # low-mid tom
CRASH1    = 49
CRASH2    = 57
RIDE      = 51
CHINA     = 52   # china cymbal (section-start accent in source file)


def E(step, note, vel, len_=1):
    """Helper: create a drum event dict."""
    return {"step": step, "note": note, "vel": vel, "len": len_}


def build_patterns():
    return [

        # ===================================================================
        # CORE PATTERNS  —  repeating groove bars
        # ===================================================================

        {
            "id": "drum_core_a",
            "label": "Core motorik A — medium intensity",
            "family": "core",
            "bars": 1,
            "intensity": "medium",
            "description": (
                "Standard motorik pulse. Kick on steps 0,2,6,8,14 (beat-1, 1-and, 2-and, beat-3, 4-and). "
                "Snare on steps 4 and 12 (beats 2 and 4). Closed hat on all 8th offbeat positions "
                "(steps 2,4,6,8,10,12,14 — hat absent on beat 1 giving the characteristic motorik spacing). "
                "Closely matches bars 1-32 of source file. Use for intro build and low-energy sections."
            ),
            "events": [
                E(0,  KICK,    80),
                E(2,  KICK,    78), E(2,  CHATHAT, 80),
                E(4,  SNARE,   80), E(4,  CHATHAT, 91),
                E(6,  KICK,    76), E(6,  CHATHAT, 91),
                E(8,  KICK,    80), E(8,  CHATHAT, 91),
                E(10, CHATHAT, 91),
                E(12, SNARE,   80), E(12, CHATHAT, 91),
                E(14, KICK,    76), E(14, CHATHAT, 91),
            ]
        },

        {
            "id": "drum_core_b",
            "label": "Core motorik B — high intensity, extra kick",
            "family": "core",
            "bars": 1,
            "intensity": "high",
            "description": (
                "Higher velocity version with extra kick at step 10 (beat 3-and), "
                "pushing the groove harder and denser. Matches bars 33-128 of source file. "
                "Use for main body and climactic sections."
            ),
            "events": [
                E(0,  KICK,    93),
                E(2,  KICK,    91), E(2,  CHATHAT, 91),
                E(4,  SNARE,   93), E(4,  CHATHAT, 91),
                E(6,  KICK,    91), E(6,  CHATHAT, 91),
                E(8,  KICK,    93), E(8,  CHATHAT, 91),
                E(10, KICK,    89), E(10, CHATHAT, 91),
                E(12, SNARE,   93), E(12, CHATHAT, 91),
                E(14, KICK,    89), E(14, CHATHAT, 91),
            ]
        },

        # ===================================================================
        # SPARSE / INTRO / OUTRO  —  low-density variants
        # ===================================================================

        {
            "id": "drum_sparse",
            "label": "Sparse motorik — low intensity",
            "family": "sparse",
            "bars": 1,
            "intensity": "low",
            "description": (
                "Stripped-down groove. Kick on beats 1 and 3 only (steps 0 and 8). "
                "Snare on beats 2 and 4 (steps 4 and 12). Closed hat on quarter note positions only. "
                "Use for intro builds, bridge passages, or low-energy sections."
            ),
            "events": [
                E(0,  KICK,    72),
                E(4,  SNARE,   68), E(4,  CHATHAT, 72),
                E(8,  KICK,    72), E(8,  CHATHAT, 68),
                E(12, SNARE,   68), E(12, CHATHAT, 72),
            ]
        },

        {
            "id": "drum_intro_kickhat",
            "label": "Intro start — kick and hat only, no snare",
            "family": "sparse",
            "bars": 1,
            "intensity": "low",
            "description": (
                "Intro bar per spec: kick and closed hat present, snare deliberately absent. "
                "Use for the first 1-2 bars of a drums-only or drums+bass intro type. "
                "Switch to drum_sparse or drum_core_a once snare enters at bar 2 or 3."
            ),
            "events": [
                E(0,  KICK,    70),
                E(2,  KICK,    68), E(2,  CHATHAT, 72),
                E(4,  CHATHAT, 80),
                E(6,  KICK,    66), E(6,  CHATHAT, 80),
                E(8,  KICK,    70), E(8,  CHATHAT, 72),
                E(10, CHATHAT, 80),
                E(12, CHATHAT, 80),
                E(14, KICK,    66), E(14, CHATHAT, 80),
            ]
        },

        {
            "id": "drum_outro_reduce",
            "label": "Outro — reduced density, cymbal thinning",
            "family": "sparse",
            "bars": 1,
            "intensity": "low",
            "description": (
                "Outro step-down pattern per spec. Hat density reduced; only kick and snare backbone "
                "remain prominent. Ghost snare accents removed. Use for last 2-4 bars of a "
                "drums-only outro tail before final stop."
            ),
            "events": [
                E(0,  KICK,    80),
                E(4,  SNARE,   72),
                E(8,  KICK,    76), E(8,  CHATHAT, 62),
                E(12, SNARE,   72),
            ]
        },

        {
            "id": "drum_outro_kickonly",
            "label": "Outro tail — kick only pulse",
            "family": "sparse",
            "bars": 1,
            "intensity": "low",
            "description": (
                "Final outro bar. Kick on beats 1 and 3 only; no snare, no hat. "
                "Per spec: last bar may end with kick-only pulse (40% probability). "
                "Use as the final bar before a hard stop."
            ),
            "events": [
                E(0,  KICK,    70),
                E(8,  KICK,    65),
            ]
        },

        # ===================================================================
        # ACCENT VARIANTS  —  groove with cymbal or velocity decoration
        # ===================================================================

        {
            "id": "drum_section_start",
            "label": "Section start bar — crash accent on beat 1",
            "family": "accent",
            "bars": 1,
            "intensity": "high",
            "description": (
                "Core B groove with China/Crash cymbal on beat 1 (step 0). "
                "Use as the first bar of a new major section or structural transition. "
                "Matches the section-start decoration found in bar 1 of each major block in the source file."
            ),
            "events": [
                E(0,  KICK,    93), E(0,  CHINA,   80),
                E(2,  KICK,    91), E(2,  CHATHAT, 91),
                E(4,  SNARE,   93), E(4,  CHATHAT, 91),
                E(6,  KICK,    91), E(6,  CHATHAT, 91),
                E(8,  KICK,    93), E(8,  CHATHAT, 91),
                E(10, KICK,    89), E(10, CHATHAT, 91),
                E(12, SNARE,   93), E(12, CHATHAT, 91),
                E(14, KICK,    89), E(14, CHATHAT, 91),
            ]
        },

        {
            "id": "drum_ride",
            "label": "Ride cymbal variant — sustained glide feel",
            "family": "accent",
            "bars": 1,
            "intensity": "high",
            "description": (
                "Core B kick/snare pattern with ride cymbal replacing closed hat on all 8th positions. "
                "Creates a sustained, gliding cymbal texture. Use for extended build sections or "
                "as a contrasting texture mid-song. Derived from blocks 51-63 of source file."
            ),
            "events": [
                E(0,  KICK,    101),
                E(2,  KICK,    101), E(2,  RIDE,    91),
                E(4,  SNARE,   101), E(4,  RIDE,    91),
                E(6,  KICK,    101), E(6,  RIDE,    91),
                E(8,  KICK,    101), E(8,  RIDE,    91),
                E(10, KICK,    97),  E(10, RIDE,    91),
                E(12, SNARE,   101), E(12, RIDE,    91),
                E(14, KICK,    97),  E(14, RIDE,    91),
            ]
        },

        {
            "id": "drum_open_hat_lift",
            "label": "Open hat lift — driving 8th-note open hat",
            "family": "accent",
            "bars": 1,
            "intensity": "high",
            "description": (
                "Core B kick/snare with open hi-hat replacing closed hat on all 8th positions. "
                "Creates an open, airy, forward-driving feel. "
                "Use at phrase or section transitions for 1-2 bars before returning to closed hat."
            ),
            "events": [
                E(0,  KICK,    93),
                E(2,  KICK,    91), E(2,  OHAT,    85),
                E(4,  SNARE,   93), E(4,  OHAT,    85),
                E(6,  KICK,    91), E(6,  OHAT,    85),
                E(8,  KICK,    93), E(8,  OHAT,    85),
                E(10, KICK,    89), E(10, OHAT,    85),
                E(12, SNARE,   93), E(12, OHAT,    85),
                E(14, KICK,    89), E(14, OHAT,    85),
            ]
        },

        # ===================================================================
        # FILL PATTERNS  —  substitute one bar at a section/phrase boundary
        # Each fill bar starts normally then breaks into fill activity
        # ===================================================================

        {
            "id": "drum_fill_short_tom",
            "label": "Short fill — snare2 + floor tom, last 2 beats",
            "family": "fill",
            "bars": 1,
            "intensity": "medium",
            "description": (
                "Most common fill type in the source file. "
                "First half (beats 1-2) is normal Core A groove; "
                "steps 10-14 replace hat/kick with snare2+floortom hits leading into the next section. "
                "1-2 beat fill. Use at 8-bar phrase boundaries (30% probability slot per spec). "
                "Derived from blocks 3 and 7 of source file."
            ),
            "events": [
                E(0,  KICK,    80),
                E(2,  KICK,    78), E(2,  CHATHAT, 80),
                E(4,  SNARE,   80), E(4,  CHATHAT, 91),
                E(6,  KICK,    76), E(6,  CHATHAT, 91),
                E(8,  KICK,    80), E(8,  CHATHAT, 91),
                # fill starts at step 10
                E(10, SNARE2,  88), E(10, FTOM_LO, 88),
                E(12, KICK,    80), E(12, SNARE2,  92), E(12, FTOM_LO, 92),
                E(14, KICK,    80), E(14, SNARE2,  92), E(14, FTOM_LO, 92),
            ]
        },

        {
            "id": "drum_fill_snare_run",
            "label": "Short fill — snare accent run, last 2 beats",
            "family": "fill",
            "bars": 1,
            "intensity": "medium",
            "description": (
                "First half is normal Core B groove; steps 10, 12, 14 become additional snare hits "
                "(alongside hat), creating a triplet-accent drive into the next section. "
                "Derived from block 23 of source file."
            ),
            "events": [
                E(0,  KICK,    93),
                E(2,  KICK,    91), E(2,  CHATHAT, 91),
                E(4,  SNARE,   93), E(4,  CHATHAT, 91),
                E(6,  KICK,    91), E(6,  CHATHAT, 91),
                E(8,  KICK,    93), E(8,  CHATHAT, 91),
                # fill starts at step 10
                E(10, SNARE,   93), E(10, CHATHAT, 91),
                E(12, SNARE,   93), E(12, CHATHAT, 91),
                E(14, SNARE,   93), E(14, CHATHAT, 91),
            ]
        },

        {
            "id": "drum_fill_snare_roll",
            "label": "Snare roll fill — dense 16th-note run from beat 3",
            "family": "fill",
            "bars": 1,
            "intensity": "high",
            "description": (
                "First half normal Core B; from beat 3 (step 8) a dense 16th-note snare roll builds "
                "to the bar end. Very energetic; use sparingly at major section boundaries. "
                "Derived from block 31 of source file."
            ),
            "events": [
                E(0,  KICK,    93),
                E(2,  KICK,    91), E(2,  CHATHAT, 91),
                E(4,  SNARE,   93), E(4,  CHATHAT, 91),
                E(6,  KICK,    91), E(6,  CHATHAT, 91),
                # roll from beat 3
                E(8,  KICK,    92), E(8,  SNARE,   92),
                E(9,  SNARE,   88),
                E(10, SNARE,   90),
                E(11, SNARE,   86),
                E(12, KICK,    92), E(12, SNARE,   92),
                E(13, SNARE,   88),
                E(14, SNARE,   90),
                E(15, SNARE,   86),
            ]
        },

        {
            "id": "drum_fill_tom_run",
            "label": "Tom run fill — kick + floor tom pattern, second half bar",
            "family": "fill",
            "bars": 1,
            "intensity": "high",
            "description": (
                "First half normal Core B; second half (from beat 3) becomes a prominent "
                "kick+floor-tom descend with snare accents. Use at 16-bar section boundaries. "
                "Derived from block 35 of source file."
            ),
            "events": [
                E(0,  KICK,    93),
                E(2,  KICK,    91), E(2,  CHATHAT, 91),
                E(4,  SNARE,   93), E(4,  CHATHAT, 91),
                E(6,  KICK,    91), E(6,  CHATHAT, 91),
                # tom fill from beat 3
                E(8,  KICK,    93), E(8,  FTOM_LO, 93),
                E(10, KICK,    91), E(10, FTOM_LO, 91),
                E(12, KICK,    93), E(12, SNARE,   93),
                E(13, SNARE,   89),
                E(14, KICK,    91), E(14, FTOM_LO, 91),
            ]
        },

        {
            "id": "drum_fill_crash_climax",
            "label": "Crash climax fill — crash on every 8th note position",
            "family": "fill",
            "bars": 1,
            "intensity": "high",
            "description": (
                "Every 8th-note position has a crash cymbal hit alongside kick/snare. "
                "Maximum intensity marker. Reserve for the end of the song or a single major "
                "structural peak only. Derived from block 63 bar 1 of source file."
            ),
            "events": [
                E(0,  KICK,    101), E(0,  CRASH1,  70),
                E(2,  KICK,    101), E(2,  CRASH1,  70),
                E(4,  SNARE,   101), E(4,  CRASH1,  70),
                E(6,  KICK,    101), E(6,  CRASH1,  70),
                E(8,  KICK,    101), E(8,  CRASH1,  70),
                E(10, KICK,    101), E(10, CRASH1,  70),
                E(12, SNARE,   101), E(12, CRASH1,  70),
                E(14, KICK,    101), E(14, CRASH1,  70),
            ]
        },
    ]


def main():
    parser = argparse.ArgumentParser(description='Generate drum-patterns-v1.json')
    default_out = Path(__file__).parent.parent.parent / \
        'assets' / 'midi' / 'motorik' / 'drums' / 'drum-patterns-v1.json'
    parser.add_argument('--out', default=str(default_out),
                        help=f'Output path (default: {default_out})')
    args = parser.parse_args()

    patterns = {
        "track": "Drums",
        "version": "v1",
        "step_resolution": 16,
        "source": (
            "Derived from Drumscribe - Motorik - MIDI.mid "
            "(TPQ=480, 130 BPM, 139 bars). "
            "Run tools/audio-analysis/analyze_midi_drums.py to inspect the source file."
        ),
        "note_mapping": {
            "36": "Kick (bass drum)",
            "38": "Acoustic snare",
            "40": "Electric snare (fills/accents)",
            "41": "Low floor tom (fills)",
            "42": "Closed hi-hat",
            "43": "High floor tom (fills)",
            "46": "Open hi-hat",
            "47": "Low-mid tom (fills)",
            "48": "Hi-mid tom (fills)",
            "49": "Crash cymbal 1",
            "51": "Ride cymbal",
            "52": "China cymbal (section start accent)"
        },
        "patterns": build_patterns()
    }

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, 'w') as f:
        json.dump(patterns, f, indent=2)

    print(f"Written: {out_path}")
    print(f"Patterns: {len(patterns['patterns'])}")
    for p in patterns['patterns']:
        print(f"  {p['id']:<32s}  family={p['family']:<8s}  intensity={p['intensity']:<8s}"
              f"  events={len(p['events'])}")


if __name__ == '__main__':
    main()

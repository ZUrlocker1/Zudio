# Automated Musical Quality Loop — Plan

A repeating human-in-the-loop feedback cycle: generate a batch of songs, analyze them across
multiple musical quality dimensions, rank the worst offenders, a human makes targeted fixes,
rebuild, and repeat. The loop never edits code autonomously. It converges when no metric
exceeds its threshold across a statistically meaningful sample.

---

## The Cycle

```
Generate → Analyze → Compare to baseline → Report → Human reviews → Fix → Rebuild → repeat
```

Each iteration runs on its own git branch. Nothing merges to main until the report shows
improvement and the golden corpus does not regress.

---

## Component 1 — Headless Song Generator

**Problem:** Song generation currently requires the macOS GUI app to be running.

**Solution:** An XCTest target (`GenerateBatchTests`) added to the Xcode project. It imports
the existing generation code directly and calls `SongGenerator.generate()` in a loop — no
new generation logic, no GUI required.

**What it does:**
- Accepts a configurable count (default 10) and style list (Ambient, Motorik, Kosmic)
- For each song: picks a random UInt64 seed, calls `SongGenerator.generate()`, writes two
  files to an output directory — the MIDI data (`.mid`) and the .zudio log (`.zudio`)
- Also runs the fixed golden corpus seeds (same seeds every iteration)
- Filenames encode style and seed: `ambient_0xDEADBEEF.mid`, `ambient_0xDEADBEEF.zudio`
- Runs headlessly: `xcodebuild test -scheme Zudio -only-testing:GenerateBatchTests`
- Output directory: `tools/batch-output/round-N/`

**Configuration baked into the test:**
- Song count per style
- Whether to use `testMode` (shorter songs, faster) or full-length (more accurate arc analysis)
- A seed override list for the golden corpus
- Output directory path

---

## Component 2 — Batch Analyzer

**File:** `tools/batch_analyze.py`

Accepts a directory of `.mid`/`.zudio` pairs, runs analysis on each, and aggregates results
into a ranked report.

**For each song it reads:**
- The `.zudio` log for: style, key, mode, tempo, total bars, section boundaries, chord plan,
  forced rule IDs per track (Bass, Drums, Lead, Rhythm, Pads, Tex, Arp)
- The `.mid` file for: all note events with pitch, timing, duration, track, channel

**It then computes all metrics described in the Quality Metrics section below.**

**The ranked report contains:**
- Per-style aggregate for each metric (average across all songs in that style)
- Per-track breakdown within each style
- Per-rule-ID breakdown — clashes and density violations correlated to the specific rule
  ID that was active (visible in the .zudio log)
- Sample count `n` alongside every figure — results with n < 10 shown but marked
  as low-confidence
- Flagged items sorted by severity (worst first)

**Flag labels:**
- `!! CLASH` — pitch clash rate ≥ 20% with n ≥ 10
- `!! DENSE` — notes/bar > style ceiling with n ≥ 10
- `!! SPARSE` — notes/bar < style floor in body sections with n ≥ 10
- `!! ARC` — density arc missing or inverted (body not denser than intro/outro)
- `!! OVERLAP` — lead voice overlap > threshold with n ≥ 10
- `!! LEAP` — melodic leap rate > threshold with n ≥ 10
- `~~ LOW-N` — flagged condition but fewer than 10 samples; noted but not acted on
- `ok` — within acceptable range

**Output:** plain text report saved to `tools/batch-output/round-N/report.txt` and
printed to stdout.

---

## Component 3 — Regression Guard and Comparison

**File:** `tools/compare_rounds.py`

- Accepts two round directories: `round-N` and `round-N+1`
- Re-runs all metrics on the golden corpus songs in both rounds (same fixed seeds,
  so any change is caused by code changes, not randomness)
- Produces a diff: which metrics improved, which got worse, which are unchanged
- If any golden corpus metric is more than 2 percentage points worse in round N+1,
  prints `!! REGRESSION` and exits non-zero — the fix is rejected

The orchestration script checks the exit code and stops before advancing the round counter
if regression is detected.

---

## Component 4 — Golden Corpus

**File:** `tools/golden_corpus.txt`

A plain text file of fixed seeds with the style they should generate, selected from songs
that were manually listened to and confirmed to sound good.

**Selection criteria:**
- One seed per style per "problem area" (e.g. one Aeolian, one Dorian, one Mixolydian
  per style) so that a regression to any mode-specific fix is caught
- Aim for 5 seeds per style (15 total) — enough statistical weight, fast enough to run

**Rules:**
- Seeds are never changed or removed; only new ones can be added
- The golden corpus is run every iteration — its metric values form the per-round baseline
- A fix is only accepted if golden corpus results are equal to or better than the prior round

---

## Component 5 — Orchestration Script

**File:** `tools/run_loop.sh`

Steps:
1. Check `git status` — abort if working tree is dirty (no uncommitted changes allowed)
2. Read current round number from `tools/batch-output/current_round.txt`
3. Create `tools/batch-output/round-N/` directory
4. Run XCTest generator — 10 songs × 3 styles + golden corpus seeds
5. Run `batch_analyze.py` → produces `report.txt`
6. If round > 1, run `compare_rounds.py` against round N-1 → produces `diff.txt`;
   if exit code non-zero, print warning, do NOT increment round, stop
7. Print the report to the terminal
8. Increment `current_round.txt`
9. Stop — wait for human to read the report, make code changes, rebuild, re-run

**The script never:**
- Edits any Swift source file
- Commits to git
- Runs if the working tree is dirty

---

## Quality Metrics

### Tonal Clash (existing, extended)

Measures what fraction of notes have a pitch class not in the active key+mode scale AND
not in the active chord tones. Both conditions must be true — passing tones on chord
changes are not counted as clashes.

Per-track targets (applies to all styles unless noted):
- Bass: ≥ 95% consonance (≤ 5% clash)
- Pads: ≥ 90% consonance
- Rhythm: ≥ 85% consonance
- Lead 1 / Lead 2: ≥ 80% consonance
- Texture: ≥ 80% consonance
- Drums: excluded entirely (GM drum kit uses fixed note numbers, not pitched content)

Hardcoded exclusions:
- Drum tracks (MIDI channel 10 or GM drum note range)
- The X-Files whistle phrase (identified by bar range from .zudio log) — intentionally
  chromatic by design

---

### Note Density (existing, extended)

Notes per bar per track. Measured separately for intro, body, and outro sections using
section boundaries from the .zudio log.

Per-style density targets:

Motorik:
- Lead 1 body: 1.5 – 4.0 notes/bar
- Lead 2 body: 1.0 – 5.0 notes/bar
- Rhythm body: 2.0 – 8.0 notes/bar
- Bass body: 1.0 – 4.0 notes/bar
- Drums body: 4.0 – 16.0 notes/bar (kick + hihat + snare pattern)

Kosmic:
- Lead 1 body: 1.5 – 5.0 notes/bar
- Lead 2 body: 0.5 – 4.0 notes/bar
- Rhythm body: 1.0 – 6.0 notes/bar
- Bass body: 0.5 – 3.0 notes/bar

Ambient:
- Lead body: 0.5 – 3.0 notes/bar
- Rhythm body: ≤ 3.0 notes/bar
- Hand percussion: ≤ 1.5 notes/bar

---

### Density Arc Shape

Measures whether the note density curve has the correct shape across song sections.
Compute the average notes/bar for intro, body, and outro separately, then check:
- Body density > intro density (song builds into the main section)
- Body density > outro density (song winds down at the end)
- Intro and outro densities are within 50% of each other (symmetry)

A density arc violation (`!! ARC`) is flagged when body is NOT the densest section, or
when intro is denser than outro by more than 2× (lopsided).

Applies to: Lead 1, Rhythm, Bass. Not drums (kick pattern is constant by design).

---

### Melodic Contour Quality

Measures the shape and movement character of Lead 1 and Lead 2 in body sections.

**Step/leap ratio:**
- A "step" is a melodic interval of 0, 1, or 2 semitones
- A "leap" is 3 or more semitones
- Target: ≥ 55% steps, ≤ 45% leaps for all styles
- Flag `!! LEAP` if leaps exceed 50% of all intervals

**Consecutive leap detection:**
- Two or more leaps in the same direction without a step or rest between them is a
  melodic lurch — scored as a contour fault
- Target: ≤ 15% of phrase transitions are consecutive same-direction leaps
- This catches random-walk melodies that sound like arpeggiators, not phrases

**Melodic range:**
- Measure the interval between the highest and lowest note in body sections
- Target: 7 – 19 semitones (roughly a 5th to an octave and a half)
- Too narrow (< 7): monotone, sounds like a drone
- Too wide (> 24): unfocused, no sense of register

**Phrase resolution:**
- The last note of each detected phrase (a note followed by a rest ≥ 1 beat) is checked
  for its pitch class relative to the tonic
- "Strong landing": root, 3rd (mode-appropriate), or 5th
- "Weak landing": any other scale degree
- "Clash landing": a chromatic note not in the scale
- Target: ≥ 60% strong landings, ≤ 5% clash landings
- Flag `!! PHRASE` if clash landings exceed 10%

---

### Lead Voice Overlap

What fraction of time steps have both Lead 1 and Lead 2 playing simultaneously.
Measured in body sections only.

Targets:
- Kosmic: ≤ 30%
- Motorik: ≤ 25%
- Ambient: ≤ 20%

Lead 1 audibility — separately, measure whether Lead 1 is audible at all. Flag `!! SPARSE`
if Lead 1 averages below 0.5 notes/bar in body sections (effectively inaudible).

Register separation — measure the median MIDI pitch of Lead 1 vs Lead 2 in body sections.
Target: Lead 1 median pitch is at least 5 semitones above Lead 2 median. If Lead 2 sits
higher than Lead 1, flag `!! REGISTER`.

---

### Bass Root Coverage

Measures whether the bass lands on the active chord root at bar boundaries.

Method: for each bar, check whether the first bass note's pitch class matches the active
chord root's pitch class (from the chord plan in the .zudio log).

Targets:
- Motorik: ≥ 70% of bar-1 bass notes are chord roots
- Kosmic: ≥ 60% (Kosmic bass is more melodic)
- Ambient: ≥ 50% (ambient bass often drones, not always root-aligned)

Bass leap size — measure intervals between consecutive bass notes. Flag `!! BASS-LEAP` if
more than 20% of bass intervals exceed a 10th (16 semitones). Large leaps in the bass
sound unmusical except in walking bass contexts.

---

### Style-Specific Rhythmic Checks

These checks use the drum/rhythm MIDI directly and check structural expectations per style.

**Motorik:**
- Kick presence: in body sections, the kick drum (MIDI note 36 / C2) should land on beats
  1, 2, 3, and 4 of every bar. Measure fraction of beats covered. Target: ≥ 90%.
- Hihat consistency: closed hihat (MIDI note 42) should be present on 8th-note grid
  positions throughout the body. Target: ≥ 70% of 8th-note positions covered.
- Flag `!! MOTORIK-KICK` or `!! MOTORIK-HAT` if below threshold.

**Ambient:**
- Note duration: ambient songs should have sustained notes. Measure the average note
  duration (in beats) for Lead and Pad tracks in body sections. Target: ≥ 2 beats average.
- Silence ratio: what fraction of body bars have zero notes in the Lead track? Some silence
  is fine in ambient (up to 30%); above 60% the lead is effectively absent.
- Tempo check: verify generated tempo is within the ambient range (62–110 BPM) using
  the tempo field from the .zudio log. Flag if outside range (catches BPM override bugs).

**Kosmic:**
- Arpeggio density: if the arp track is present, verify it is active in body sections
  at ≥ 1.0 notes/bar. Below that the arpeggio adds no movement.
- Bridge differentiation: if a bridge is present (visible in .zudio log), measure whether
  its average notes/bar in the lead track differs from the A-section body by ≥ 20%. If
  the bridge is indistinguishable from the body, flag `!! BRIDGE-FLAT`.

---

### Rule and Key Diversity

Measures whether the generator is producing variety across a batch.

**Rule diversity:**
- For each generator track (Bass, Lead, Rhythm, etc.), count how many distinct rule IDs
  appear across a 10-song batch
- Target: ≥ 3 distinct rules per track per batch. A single rule dominating ≥ 70% of songs
  is flagged `!! RULE-DOMINANT`
- This catches weight imbalances where one rule crowds out all others

**Key distribution:**
- Across a 10-song batch, no single key should appear in more than 3 of 10 songs
- Flag `!! KEY-CLUSTER` if any key appears ≥ 4 times (statistically unlikely; suggests
  a key override not being cleared, or seed clustering)

**Mode distribution:**
- Check that mode frequencies roughly match the intended weights per style
- Acceptable tolerance: ±15 percentage points from intended weight across ≥ 20 songs
- Not flagged per-round (needs larger n); included in summary after 3+ rounds

---

### Chord Window Quality

**Window length:**
- Measure average bars per chord window from the chord plan in the .zudio log
- Targets: Motorik ≥ 15 bars, Kosmic ≥ 4 bars, Ambient ≥ 8 bars
- Flag `!! CHORD-FAST` if average window is shorter than half the target

**Diatonic root check:**
- For each chord window, verify that the chord root degree is diatonic to the active mode
- Any non-diatonic root (e.g. b6 in Dorian, b3 in Ionian) is a structural clash source
- Flag `!! BORROWED-ROOT` with the specific degree and mode — this is a high-priority flag
  as it was the root cause of the catastrophic clashes found in multiple studies

---

## Safeguards

**Against false positives:**
- Drums excluded from all pitch clash analysis unconditionally
- Clash threshold at ≥ 20% before flagging — minor passing tone clashes are expected
- Minimum n = 10 per rule before any rule is flagged — low-n results noted but not acted on
- X-Files whistle excluded by bar range annotation in the .zudio log
- Intentional chromaticism can be manually added to a per-style exclusion list in the
  analyzer config; initially empty; added only after human confirmation

**Against breaking working rules:**
- Golden corpus regression guard: any metric worsening by > 2 percentage points on fixed
  seeds blocks the fix from advancing
- One fix per iteration: only the top-ranked offender is addressed each round, keeping
  causality clear
- Git branch isolation: each round on its own branch; a bad fix is one `git branch -D`
  away from being gone
- The orchestration script verifies a clean working tree before running

**Against the loop running forever:**
- Done condition: zero `!!` flags with n ≥ 10 across all three styles
- Maximum 10 iterations — if not converged, the plan itself needs revisiting
- Each round produces a permanent record (`tools/batch-output/round-N/`) so progress
  is always visible and auditable

---

## Git Workflow Per Iteration

- Create branch before running: `git checkout -b analysis/round-N`
- Run the orchestration script
- Read the report; make ONE targeted fix on this branch
- Commit the fix, rebuild (XCTest picks up the new build)
- Re-run the orchestration script — it runs the new round and compares to round N-1
- If regression guard passes and at least one `!!` flag is resolved: merge to main
- If regression detected: `git checkout main && git branch -D analysis/round-N`, try
  a different approach on a new branch

---

## What Requires Human Ears

No automated metric can fully substitute for listening. After each iteration, before merging:
- Listen to at least 3 generated songs from the new build across different styles
- Confirm that the metric improvement is audible, not just numerical
- Check for "technically clean but musically boring" — a melody can pass all metrics
  while still being dull

Specific things to listen for that metrics cannot catch:
- Whether phrase endings feel resolved or hanging
- Whether the density arc creates genuine tension and release, not just numerical change
- Whether style identity is preserved (Motorik still sounds Motorik, Ambient still breathes)
- Whether any fix has made the music feel mechanical or over-corrected

---

## Estimated Cycle Time

- Generate 33 songs (30 batch + 3 golden per style): 3–5 min in testMode, ~15 min full-length
- Analyze and compare: < 1 minute
- Human listening review: 10–20 minutes
- Fix and rebuild: varies

Realistic end-to-end per iteration excluding fix time: 20–30 minutes.

---

## Chill Style Extension

Chill is a separate, Chill-only quality loop implemented as:
- `Tests/ZudioTests/ChillBatchTests.swift` — Swift Testing batch generator
- `tools/chill_analyze.py` — Chill-specific Python analyzer

Run with:
```
xcodebuild test -scheme Zudio -only-testing:ZudioTests/ChillBatchTests
python3 tools/chill_analyze.py ~/Downloads/Zudio/tools/batch-output/chill/
```

Output directory: `~/Downloads/Zudio/tools/batch-output/chill/`
- `chill_NN_SEED.MID` + `.zudio` — 10 generated songs
- `regen/chill_SEED_drums_regenN.MID` — 5 drum regens per fixed seed
- `regen/chill_SEED_lead1_regenN.MID` — 5 Lead 1 regens per fixed seed

### Chill Data Sources

The `.zudio` file already contains everything the analyzer needs:
- `--- Structure ---` block: section names with exact bar ranges (e.g. `bridge  Bars 41– 48`)
- `--- Chord Plan ---`: chord windows with root degree and type
- `--- Generation Log ---`: rule IDs (CHL-DRUM-001/002/003, CHL-BASS-*, CHL-LD1-*, etc.)

No changes to the `.zudio` format are required.

### Chill Density Targets (notes/bar)

- Lead 1 intro: 0–0.8; Groove A+B: 1.0–3.0; outro: 0–1.5
- Lead 2 Groove A+B: 0.5–2.5
- Bass Groove A+B: 1.5–4.0; bridge: 0–1.5
- Rhythm Groove A+B: 1.5–10.0 (wide — mobyBackbeat ≈ 2, arpeggiated ≈ 10; both valid)
- Drums: see beat style checks below

### Chill-Specific Structural Checks

**Breakdown (bridge section):**
- `!! CRITICAL LEAD-IN-BREAKDOWN` — any Lead 1 notes in bridge section (must be zero)
- `!! BASS-BREAKDOWN` — bass > 1.5 notes/bar in bridge

**Groove B rebuild:**
- `!! REBUILD-FLAT` — Lead 1 density in Groove B < 90% of Groove A (lead should be most active in B)

**Beat style verification (from CHL-DRUM rule ID):**
- CHL-DRUM-001 (Minimal syncopated): kick (note 36) on step 0 of ≥ 90% of groove bars; events/bar ≤ 5. Flag `!! CHILL-KICK-MISSING` or `!! CHILL-DRUM-DENSE`.
- CHL-DRUM-002 (Ghost note groove): at least one low-velocity (≤ 50) snare per groove section. Flag `!! CHILL-NO-GHOST`.
- CHL-DRUM-003 (Jazz pulse): ride (note 51) on steps 0 and 8 of ≥ 85% of groove bars. Flag `!! CHILL-JAZZ-PULSE`.
- **Diversity**: ≥ 2 of 3 drum rules must appear across a 10-song batch. Flag `!! CHILL-DRUM-DOMINANT` if one rule in ≥ 8/10 songs.

### Chill Lead Phrase Checks

Group Lead 1 notes into phrases where gap ≥ 1 bar = new phrase.

- `!! CHILL-DENSE-LEAD` — average phrase length > 6 bars (lead never breathes)
- `!! CHILL-NO-REST` — average inter-phrase rest < 0.5 bars (phrases run together)
- `!! CHILL-LEAP` — step/leap ratio < 55% steps (≤ 2 semitones = step; ≥ 3 = leap)
- `!! CHILL-PHRASE-END` — strong landings (root/3rd/5th) < 60% of phrase endings
- `!! CHILL-MONOTONE-PHRASE` — > 30% of phrases use ≤ 2 distinct pitch classes

### Chill Thresholds for Shared Metrics

These rows apply specifically to Chill in the existing metric tables:
- Tonal clash: Bass ≤ 5%, Pads ≤ 10%, Rhythm ≤ 15%, Lead 1/2 ≤ 20%
- Lead voice overlap: ≤ 20% of groove steps (call-and-response; less overlap than other styles)
- Register separation: Lead 1 median pitch ≥ Lead 2 median + 5 semitones
- Bass root coverage: ≥ 75% of groove bar-1 bass notes match chord root
- Chord window length: 4–8 bars average in groove sections
- Pads voicing: ≥ 10% of chord-strike events have ≥ 4 simultaneous notes (7th chord presence). Flag `!! CHILL-NO-7THS`.

### Regen Variation Test

Regenerate Drums and Lead 1 five times from each of 3 fixed seeds. Compare step-level structural difference (Jaccard distance on occupied step sets) between all regen pairs.

- `!! REGEN-MONOTONE` — any pair of regens differs in < 15% of steps
- `~~ LOW-VAR` — average difference < 30% for Drums or < 40% for Lead 1
- `ok` — average diff ≥ 30% (Drums) or ≥ 40% (Lead 1) and no pair < 15%

### Golden Corpus (Chill)

Deferred until after round 1 listening review. Target: 4–5 seeds covering Deep, Dream, Free, and Bright moods, with at least one "breakdown present" song. Seeds are added to `tools/golden_corpus.txt` after human confirmation that they sound good.

### Done Condition (Chill)

Zero `!!` flags across a 10-song batch with the regen variation test passing for all 3 seeds.

---

## Motorik Style QA Loop

Motorik is the original Zudio style and the most structurally constrained. Its identity depends
on the four-on-the-floor kick, metronomic hihat, and a long, slowly evolving melodic arc. The
QA loop targets three areas unique to Motorik: rhythmic integrity, melodic arc shape, and
instrument diversity.

### Running the Motorik Loop

Motorik uses the same infrastructure as the main loop (Component 1–5), restricted to `.motorik`
style only:

```
xcodebuild test -scheme Zudio -only-testing:GenerateBatchTests
python3 tools/batch_analyze.py tools/batch-output/round-N/ --style motorik
```

Generate at least 20 songs per round (Motorik is fast). The golden corpus should include 5
fixed seeds covering different lead rule IDs and at least one song with an X-Files whistle
phrase and one with a bridge.

### Motorik-Specific Checks

**Rhythmic Integrity**

The Neu!/Hallogallo beat is the non-negotiable core of Motorik. Any drift from the four-on-
the-floor + steady hihat pattern breaks style identity immediately.

- `!! MOT-KICK` — kick (note 36) not present on all four beats of ≥ 90% of body bars
- `!! MOT-HAT` — closed hihat (note 42) not on ≥ 70% of 8th-note grid positions in body
- `!! MOT-SNARE` — snare (note 38) absent from beats 2 and 4 in ≥ 80% of body bars
- `!! MOT-DRUM-DENSE` — drum events/bar > 20 in body sections (fills crowding the pocket)
- `~~ MOT-CRASH` — crash cymbal (note 49) fires more than once every 8 bars (distracting)

**Melodic Arc**

Motorik melodies are slow-burning. The lead should enter sparsely, build through the body,
and have a clear sense of register and direction rather than random wandering.

- `!! MOT-ARC-FLAT` — Lead 1 density difference between intro and peak body section < 0.5
  notes/bar (lead never really arrives)
- `!! MOT-DRONE` — Lead 1 uses ≤ 3 distinct pitch classes in any 8-bar window of the body
  (trapped on one note)
- `!! MOT-REGISTER` — Lead 1 median pitch outside 60–84 MIDI (below middle C or too shrill)
- `!! MOT-PHRASE-GAP` — Lead 1 has no rest ≥ 2 bars anywhere in the body (never breathes;
  phrases run together into a wall of sound)
- `~~ MOT-OCTAVE-JUMP` — more than 20% of consecutive Lead 1 intervals are exactly 12
  semitones (octave jumping as a crutch)

**Bass Character**

Motorik bass is an ostinato drone, not a walking line. It should mostly sit on the root with
occasional movement rather than leaping around.

- `!! MOT-BASS-ROOT` — fewer than 70% of body bar-1 bass notes match the active chord root
- `!! MOT-BASS-LEAP` — more than 15% of consecutive bass intervals exceed a 5th (7 semitones)
- `!! MOT-BASS-DENSE` — bass > 4.0 notes/bar in body (too busy for the style)

**Rhythm Track (Arp)**

The Motorik rhythm track is a hypnotic repeating figure — not a melody, not random. It should
be dense, locked to the beat, and harmonically consonant.

- `!! MOT-RTHM-SPARSE` — rhythm track < 2.0 notes/bar in body (inaudible contribution)
- `!! MOT-RTHM-CLASH` — rhythm pitch clash > 15% (arpeggio notes outside scale + chord)
- `!! MOT-RTHM-STOP` — rhythm track absent for > 4 consecutive body bars (unexplained gap)

**Song Length and Structure**

Motorik songs should be long. A 3-minute song doesn't have time to hypnotize.

- `!! MOT-SHORT` — total bars < 40 (< ~3 min at 125 BPM)
- `~~ MOT-NO-BRIDGE` — no bridge/breakdown present (not mandatory but worth noting for
  variety across a batch; flag only if absent in > 80% of a 20-song batch)

**Tonal Clashes**

Uses the same pitch-clash metric as the main loop (note pitch class not in active scale AND
not in active chord tones), with Motorik-specific thresholds. The long chord windows and
ostinato nature of Motorik mean clashes are more audible and more persistent than in other
styles.

- `!! MOT-CLASH-BASS` — bass consonance < 95% in body sections
- `!! MOT-CLASH-RHYTHM` — rhythm track consonance < 85% in body sections
- `!! MOT-CLASH-LEAD1` — Lead 1 consonance < 80% in body sections
- `!! MOT-CLASH-LEAD2` — Lead 2 consonance < 80% in body sections
- `!! MOT-CLASH-PADS` — pads consonance < 90% in body sections
- X-Files whistle phrase excluded by bar range (annotated in .zudio log)

**Instrument Diversity**

With 7 lead instruments and 7 rhythm instruments available, no single instrument should dominate.

- `!! MOT-LEAD-DOMINANT` — any single Lead 1 instrument in > 50% of a 20-song batch
- `!! MOT-RTHM-DOMINANT` — any single Rhythm instrument in > 50% of a 20-song batch

### Motorik Density Targets (reference)

These are already defined in the main Quality Metrics section and apply unchanged:
- Lead 1 body: 1.5–4.0 notes/bar
- Lead 2 body: 1.0–5.0 notes/bar
- Rhythm body: 2.0–8.0 notes/bar
- Bass body: 1.0–4.0 notes/bar
- Drums body: 4.0–16.0 notes/bar

### Motorik Golden Corpus Seeds

Target 5 seeds selected after listening review, covering:
- One song with X-Files whistle phrase (confirming it isn't flagged as a tonal clash)
- One song with a bridge present
- At least two different lead rule IDs (e.g. MOT-LD1-007 and MOT-LD1-008)
- At least two different modes (e.g. one Dorian, one Mixolydian)

### Done Condition (Motorik)

Zero `!!` flags across a 20-song batch, with the golden corpus showing no regressions from
the prior round. The `~~ MOT-NO-BRIDGE` warning is acceptable if variety is present in
other dimensions.

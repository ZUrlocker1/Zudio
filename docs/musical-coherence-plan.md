# Musical Coherence Analysis Plan

Goal: examine generated songs systematically to identify and improve harmonic coherence and authentic cosmic character. Starting with the Kosmic style.

## Overview

Each time a song is saved as MIDI, Zudio writes a companion `.txt` log file with the same base name. These log files, combined with the MIDI files themselves, form the raw material for analysis — either manual inspection or automated scripting.

## What the Log File Contains

- Song header: title, seed, style, key, mode, tempo, total bars, mood
- Section structure: label, bar range, length for each section
- Chord plan: root degree and chord type per window
- Note counts per track
- Full generation log: every rule ID, instrument, and decision made at generation time
- Playback annotations: bar-numbered list of all dynamic events (fills, bridges, X-Files, etc.) sorted by position

## How to Build a Sample Set

1. Generate songs normally (no test mode required — test mode biases toward bridge/percussion rules)
2. Save MIDI for each one you want to analyze (Cmd-D)
3. Companion `.txt` log is written automatically alongside the MIDI file
4. Aim for 8–12 songs before drawing conclusions

## What to Analyze

### From the log files

- Rule frequency: which rules dominate? Are 2–3 rules appearing in every song?
- Mode distribution: is Dorian appearing often enough? (Berlin School / cosmic favors Dorian, Phrygian, Lydian over plain minor/major)
- Section length distribution: are intro/outro long enough to breathe?
- Chord plan rhythm: how often does the root change per song? Cosmic should be slow — ideally 4–8 bars per chord window
- Annotation density: how many playback events fire per song? Sparseness is a feature, not a bug

### From the MIDI files

- Note density per bar per track (notes/bar): leads should be sparser in intro/outro than body
- Lead overlap: what fraction of steps have both Lead 1 and Lead 2 playing simultaneously? Lower is better
- Phrase landing: what MIDI pitch do lead phrases end on relative to the tonic? Root/third/fifth = intentional; random degrees = wandering
- Harmonic consonance rate per track: fraction of notes whose pitch class is in the active mode's scale. Bass/pads should be 95%+; leads 75–85% is acceptable
- Density arc shape: plot notes-per-bar across the song — should rise from intro, peak in body, fall in outro

### Cross-track checks

- Do bass notes agree with chord plan roots at bar boundaries?
- Do pad chord tones match the tonal map for their section?
- Are lead phrases avoiding the same register simultaneously?

## Key Metrics to Watch (Motorik)

- Modal consonance (bass): target > 90% (was 79.4% pre-fix)
- Modal consonance (leads): target > 80%
- Drum fill rate: target < 1 fill per 12 bars (was ~1 per 7–11 bars pre-fix)
- Lead 2 note share: target < 60% of total lead notes (was 70% pre-fix)
- Lead 1 body density: target 1.5–4 notes/bar
- Chord window length: confirm average remains 15+ bars
- MOT-TEXT rules: confirm 2+ distinct supplementary rules appearing across a batch; no single rule dominating all songs

## Key Metrics to Watch (Kosmic)

- Lead overlap rate: target < 30% of steps
- Modal consonance (bass): target > 92%
- Modal consonance (leads): target > 72%
- Chord window length: target average >= 4 bars
- Intro note density (Lead 1): target < 1.5 notes/bar
- Body note density (Lead 1): target 2–5 notes/bar
- Outro note density (Lead 1): target < 2 notes/bar

## What I (Claude) Can Analyze Autonomously

Given a set of log + MIDI files:
- Parse all log files and produce rule frequency table, mode distribution, section length stats
- Write a Swift or Python script to parse MIDI and compute note density curves, consonance rates, lead overlap
- Produce a findings report with specific rule IDs or generation parameters to investigate
- Suggest targeted tweaks (e.g. "KOS-LEAD-002 produces 4.8 notes/bar in body — consider thinning")

## What Requires Human Ears

- Whether it actually sounds cosmic
- Whether phrase endings feel resolved or hanging
- Whether the overall arc has tension and release
- Whether the mix of instruments feels right for the style

## Findings: Kosmic Study 01 (11 songs, March 2026)

Analysis of 11 generated Kosmic songs identified several structural and rule issues:

**Outro length mismatch** — Outros were 50/50 between 8 and 16 bars (average ~12 bars), far longer than intros (average 3.5 bars). The long drone notes in intros and outros don't translate well to MIDI, so long outros hurt more than help. Fixed to mirror the intro distribution.

**Shimmer (KOS-PADS-006) always logged** — The shimmer layer was unconditionally added to the generation log regardless of whether it actually fired. Fixed to only log when shimmer plays.

**Unnamed Wurlitzer rule** — A bIII chord voicing layer (internally KOS-RULE-07) predated the KOS-PADS-xxx naming convention and never appeared in generation logs. Renamed to KOS-PADS-008 "bIII Colour Chord" and added to logging.

**Mode weight bug** — Aeolian appeared twice in the mode picker array, giving it 45% effective weight instead of the intended 30%. Dorian was effectively 40%, not the dominant mode it should be. Fixed to make Dorian clearly primary.

**Berlin School Drone overweight** — KOS-BASS-001 fired too often relative to more interesting bass patterns. Reduced in favour of Loscil Pulse and Loscil Drift which suit the MIDI format better. Moroder Pulse and Autobahn Walk also increased slightly.

**Dual bass layer too frequent** — KOS-BASS-006 (staccato dual layer) fired at 55% probability when eligible, making the layered bass texture the norm rather than a special feature. Reduced significantly.

**Primary pad rule concentration** — KOS-PADS-001 (Eno Long Drone) dominated at 26%. Reduced and redistributed to Swell Chord and Gated Chord Pulse for more variety.

## Findings: Kosmic Study 02 (11 songs, March 2026) — MIDI + Log Analysis

Full machine analysis in `docs/midi-analysis/study02_findings.txt`. Script: `docs/midi-analysis/analyze_study02.py`.

**Lead 1 is far too sparse — the most urgent issue** — 8 of 11 songs produced under 0.8 notes/bar in body sections. Only Auxese (2.1), Fluxion (1.6), and Vortexe-VI (1.7) approached the 2–5 target. Songs like Deep-Solstice, Flexure, and Solaxe averaged 0.3 notes/bar — the lead is essentially inaudible. The Berlin School slow arc (KOS-LEAD-001) and Eno floating tones (KOS-LEAD-002) rules are the primary contributors and appear in 7 and 8 of 11 songs respectively. These rules are naturally sparse by design but may need a minimum density floor or be paired with denser rules more often.

**Lead overlap elevated in 5 of 11 songs** — Galaxie-VIII 50%, Flexure 39%, Deep-Solstice 39%, Polar-Horizon 37%, Void-Ether 30%. Average was 25.8% across all songs, just under the 30% target. When Lead1 is sparse, Lead2 tends to fill the same time-space, inflating overlap. Reducing overlap requires either register separation between leads or time-interleaving logic.

**Lead density arc is erratic or absent** — The intended shape (low intro → rising body → falling outro) rarely appears. Ewig-Leere shows Lead1 dropping to zero for ~30 bars in the middle of the body. Fluxion has no Lead1 at all in the final 40% of the song (entire B section). The "stepping back" mechanism is too aggressive — leads can go completely silent for extended stretches with no guarantee of return.

**Modal Drift consonance fault (Galaxie-VIII)** — When a section uses a non-tonic chord root (e.g., root=b7 producing Dm in an E Dorian song), some generators produce notes diatonic to that chord's own scale rather than staying in the key. Rhythm track consonance fell to 62%, bass to 79%, pads to 78%. This only manifests with Modal Drift and non-tonic roots — needs investigation.

**Rhythm over-density in KOS-RTHM-004** — Flexure's Rhythm track contained 1723 notes (13.9/bar) — far more than any other song and far above anything musically useful. KOS-RTHM-004 (Electric Buddha pentatonic groove) appears to have no density ceiling.

**Zero-bar sections logged** — preRamp(0) and postRamp(0) appear in the structure log for songs with a melodic bridge. These sections exist in the song structure but contain no bars, creating confusing log entries. SongLogExporter should suppress zero-bar sections.

**Key variety too low** — 5 of 11 songs were E Dorian; 3 were G Aeolian. Only 3 other keys appeared. With Dorian at 45% and E at 18% of key picks, the joint probability is ~8% per song — getting 5/11 E Dorian is statistically unlikely and may indicate a key-override persistence bug or seed clustering.

**Consonance is healthy overall** — Average Lead1 93.8%, Bass 97.1%, both well above targets. The Galaxie-VIII outlier aside, harmonic coherence across all tracks is strong.

## Fixes Applied: Kosmic Study 02 (March 2026)

All five phases from the roadmap below were implemented in the same session as the Study 02 analysis.

**Lead 1 / Lead 2 role differentiation (Phase 1)** — Lead 1 weights shifted strongly toward KOS-LEAD-006 JMJ Phrase Loop (25% → 40%) and KOS-LEAD-004 Echo Melody (12% → 20%), making Lead 1 the primary melodic voice with identifiable phrases rather than ambient texture. Lead 2 now excludes KOS-LEAD-006 entirely, preventing it from ever competing for the main melodic role. Lead 2 weights redistributed to favour sparse ambient rules: Eno Floating Tones 30%, Echo Melody 25%, Pentatonic Drift 20%. Lead 2 register shifted down from 60–88 to 55–80 so it sits in a darker register below Lead 1.

**Simultaneous silence fix (Phase 2)** — After Lead 2 generation, a post-processing pass scans body sections in 4-bar windows. Any window where both Lead 1 and Lead 2 are completely silent gets a single held note injected into Lead 2. This uses the `lead1Events` parameter that was passed into `generateLead2` but never previously used.

**Modal Drift consonance fix (Phase 3)** — `pentatonicNotes` and `dualRateNotes` in CosmicArpeggioGenerator (used by KOS-RTHM-004 and KOS-RTHM-005) now use `keySemitone(frame.key)` as the note-pool root instead of the chord-root-shifted value. When Modal Drift selects a non-tonic chord root (b7, b6), the pentatonic pool now stays anchored to the song tonic rather than shifting to the chord's local scale, eliminating the out-of-key notes that caused Galaxie-VIII's 62% Rhythm consonance.

**KOS-RTHM-004 density cap (Phase 4)** — Electric Buddha groove loop now exits via a labeled break once 6 notes have been added to a bar (anchor + 5 groove notes maximum). Caps the Flexure-style 13.9 notes/bar extreme to ≤ 6 with no change to the rule's musical character.

**Zero-bar section suppression (Phase 5)** — SongLogExporter now skips any section whose `lengthBars == 0` before writing to the structure log. preRamp(0) and postRamp(0) no longer appear in saved analysis logs for songs with a melodic bridge.

**Key clustering / lock-in fix** — The keyOverride / moodOverride / tempoOverride values were incorrectly written back to app state after each generation, locking all subsequent songs to the first-generated key and mood. Fixed to set these to nil after generation. This was the root cause of the 5/11 E Dorian clustering in Study 02 (a 0.1% random-chance occurrence; ~60% probability given the bug).

---

## Findings: Kosmic Study 03 (11 songs, March 2026)

8 songs generated in project root + 3 from Downloads root. One song (Auxese-test-bridge) generated in test mode with a forced melodic bridge for targeted analysis.

**Study 02 lead changes confirmed effective for 006-primary songs** — Songs where Lead 1 picked KOS-LEAD-006 (Auxese-test-bridge 112 notes, Sanft-Nebel 237 notes) showed clearly improved melody density. The JMJ phrase loop is now doing its job as the primary melodic voice.

**Songs with sparse Lead 1 rules remain nearly inaudible** — Songs where Lead 1 picked 001/002/003 still produced only 33–58 notes across 108–128 bars (0.3–0.5/bar). The weight shift to 006 helped the songs that pick it, but the ambient rules are structurally sparse by design and the problem persists in ~60% of generations. Technique D (B-section rule swap) was firing at only 60% probability and when it did fire could still pick another sparse rule.

**Bridge melody is a self-contained arch generator** — Analysis confirmed that `generateBridgeMelodySection` has its own dedicated rhythm skeleton and melodic arch logic and does not use any of the six standard lead rules. The `bridgeRule` parameter passed to it was dead code (never read). The bridge always sounds more melodic than the main sections because of this dedicated system, not because of which rule was rolled. This was always the case; our changes did not cause or worsen it.

**KOS-BASS-002 Root-Fifth Walk sounds mechanical** — The rule produced an identical sustained pattern every song (no rng, velocity always 100, duration always 30 steps). Articulation, timing, and pitch had zero variation.

## Fixes Applied: Kosmic Study 03 (March 2026)

**B-section escalation for sparse Lead 1 rules** — When Lead 1 picks an ambient sparse rule (KOS-LEAD-001, 002, or 003), Technique D now always fires and is constrained to pick either KOS-LEAD-004 Echo Melody or KOS-LEAD-006 JMJ Phrase Loop (60/40 split). Songs with drone or slow-arc A sections now always open into an actively melodic B section, creating a genuine ambient → melodic arc rather than 100+ bars of the same sparse texture throughout.

**Bridge rhythm variant wired to Lead 1 rule** — The bridge melody generator previously picked its rhythm skeleton at random from four options. Now the skeleton is biased (60%) toward the character of the song's Lead 1 rule: JMJ songs get the syncopated off-beat skeleton; echo melody songs get the driving 8th-note sequencer; sparse ambient songs (001/003/005) get the restrained 3-note motif with breath; floating tones songs get the steady quarter-note pulse. The bridge now feels like it belongs to the song's character rather than being a random texture shift.

**KOS-BASS-002 Root-Fifth Walk revitalised** — Rule weight reduced from 11% to 7%. The function now accepts rng and applies: probabilistic hold lengths (staccato 12 steps / medium 22 / full hold 30); velocity randomised 88–105; 30% chance of a one-16th syncopated attack push; 20% chance the fifth phase uses the b7 instead (more modal, suits Dorian); 25% chance of a 2-step approach tone just before the main note; 40% chance of a soft ghost echo on beat 3 for medium/long holds.

---

## Findings: Motorik Study 01 (10 songs, March 2026)

Full machine analysis in `docs/midi-analysis/motorik_study01_findings.txt`. Script: `docs/midi-analysis/analyze_motorik_study01.py`.

**MOT-PADS-004 phantom log entry** — `PadsGenerator.swift` unconditionally inserts `MOT-PADS-004` into `usedRuleIDs` for every song with the comment "sparse intro/outro always applies." There is no `case "MOT-PADS-004":` in the switch statement and no notes are ever generated for it. The intro/outro sparseness is implemented inline in the section check above the loop. Same class of misleading log as the Kosmic shimmer Study 01 fix, though here no notes are involved at all — it is a pure phantom rule ID.

**MOT-TEXT-001 in all 10 songs — by design, not a bug** — TEXT-001 (sparse boundary-weighted notes) is correctly always active; it is the intentional backbone rule. The unconditional log entry is accurate.

**Lead 2 dominates Lead 1 in 8/10 songs** — Same role inversion as Kosmic pre-Study 02. Lead 1 rule LD1-003 Long Breath fires at only 22% probability per bar (structurally producing ~22 notes in 100 bars — inaudible). Lead 1 is additionally hard-silent for the first 8–16 bars of the A section. Lead 2 with LD2-004 Hallogallo Counter fires on ALL body bars at 75% probability across 8 steps (~6 notes/bar). With no B-section escalation mechanism, songs with a sparse A-rule stay sparse throughout. Average Lead 2 note share: 70% of total lead notes.

**Consonance degraded by Modal Drift — same root cause as Kosmic Galaxie-VIII** — Average Bass consonance 79.4% vs target >92%. Two catastrophic outliers: Leuchtet-Zeit (32.9%, A Mixolydian, 68 of 112 bars on chord root b6/F — F's perfect fifth C is not in A Mixolydian), Space-5 (42.5%, B Dorian, multiple non-tonic chord roots). Primary sources: (a) RhythmGenerator computes flat7PC as chromatic `rootPC + 10` regardless of mode — produces out-of-scale notes when chord root is non-tonic; (b) LeadGenerator LD2-004 Hallogallo Counter and LD2-005 derive noteOffsets from the chord root PC, producing out-of-scale notes when offsets land on chromatic semitones not in the song key. Bass flat-7 patterns already had major-context guards covering the common cases.

**Drum fills too frequent — periodic trigger fires every 4 bars** — `DrumVariationEngine` inserts a fill on bar-3-of-4 in every body section (every 4 bars). Combined with section-transition fills and instrument-entrance fills, songs accumulate 11–22 fills. Fahrt-Punkt: 22 fills in 160 bars (1 per 7.3 bars); ZeitLicht: 15 fills in 148 bars; E-Space: 14 fills in 120 bars. Motorik can tolerate more fills than textbook NEU! but this rate is excessive.

**Lead overlap healthy** — Average 7.1% body overlap across all 10 songs. No overlap issues.

**Chord window lengths appropriate** — Average 18–49 bars per window. Harmonic movement is slow and Motorik-correct.

## Fixes Applied: Motorik Study 01 (March 2026)

**MOT-PADS-004 phantom log removed** — Removed unconditional `usedRuleIDs.insert("MOT-PADS-004")` from PadsGenerator. No behavior change; intro/outro sparseness was already handled inline.

**Drum fill rate halved; 3-beat fills reduced** — Periodic body fill trigger changed from every 4 bars (`(barInSection + 1) % 4 == 0`) to every 8 bars. Fill length weights adjusted from 60/30/10 (1-beat/2-beat/3-beat) to 70/25/5 — 3-beat fills more than halved as they are more disruptive to the Apache groove.

**Lead role differentiation — Motorik Technique D** — LD1-003 Long Breath weight reduced (0.15 → 0.08), redistributed to LD1-001 (+0.04) and LD1-004 (+0.03). When Lead 1 picks LD1-003 for the A section, the B section is forced to escalate to LD1-001 Phrase-first (60%) or LD1-004 Stepwise Sequence (40%), matching the Kosmic Technique D pattern. LD2-004 Hallogallo Counter step probability reduced from 75% to 55% per step (~4 notes/bar instead of ~6) to prevent it from overwhelming a sparse Lead 1.

**Modal Drift consonance fix — rhythm and leads** — The bass flat-7 patterns already had major-context guards; the main offenders were elsewhere. RhythmGenerator `chordPitches`: flat7PC is now snapped to the nearest in-scale pitch class using `frame.mode.intervals` + `keySemitone(frame.key)` rather than always using the chromatic b7 (`rootPC + 10`). LeadGenerator LD2-004 Hallogallo Counter and LD2-005 Descending Line: `rootPC` changed from chord-root-based to song-tonic-based — these counter-melody patterns are intended as fixed tonic-anchored motifs (NEU! style) and must not shift when chord roots change. LD1-004 and LD1-005 were left chord-tracking (their offsets are always diatonic in the common modes).

**Motorik texture overhaul — TEX → TEXT, new rules, retired rules** — Naming fixed throughout: all `TEX-` references in TextureGenerator.swift renamed to `TEXT-`. MOT-TEXT-003 (Drone Anchor) and MOT-TEXT-004 (Shimmer Pair) retired as redundant with the new rules. Four new supplementary rules added: TEXT-007 Pedal Drone (tonic held very quietly ~once per 32 body bars), TEXT-008 Phase Slip (adjacent semitone crunch ~once per 20 bars, Cluster reference), TEXT-003 Spatial Sweep (chromatic passing pair between chord tones, adapted from KOS-TEXT-003), TEXT-004 Shimmer Hold (scale tension held 4+ bars very quietly, adapted from KOS-TEXT-002). Supplementary pool expanded from 5 to 7 rules; weights rebalanced for equal representation. Test pool updated: old KOS-RTHM-009/010 and KOS-BASS-013 retired; new MOT-TEXT-003/004/007/008 and KOS-TEXT-004 marked as recent.

**Rule catalog renumbering** — All MOT-PADS and MOT-TEXT rule IDs renumbered to eliminate gaps left by retired rules. MOT-PADS: 006→004 (Stabs), 007→005 (Charleston), 010→006 (Half-bar Breathe), 011→007 (Backbeat Stabs). MOT-TEXT: 009→004 (Shimmer Hold), 010→003 (Spatial Sweep); old 003 and 004 removed. All other Motorik and Kosmic rule families (BASS, LD1, LD2, RTHM, DRUM, KOS-PADS, KOS-BASS, KOS-RTHM, KOS-TEXT, KOS-DRUM) are sequential with no gaps.

---

## Findings: Motorik Study 02 (10 songs, March 2026)

Full machine analysis in `docs/midi-analysis/` (scripts: `analyze_aflow.py`, `analyze_batch2.py`). Songs: A-Flow, A-Tone, Alt-Strom, Cycle-2, E-Layer, Field-4, GeistBahn, GeistStrom, Langsam-Bahn, Langsam-Maschine.

**Borrowed chord roots in major modes — the dominant structural problem** — `StructureGenerator.pickChordRoot` used a hardcoded Aeolian degree list `["1","2","b3","4","5","b6","b7"]` for ALL modes, ignoring the `mode` parameter. In Ionian: b3=C natural (A major has C#), b6=F natural (has F#), b7=G natural (has G#). In Mixolydian: b3 and b6 are similarly wrong. Three songs were severely affected: A-Flow (A Ionian, borrowed b3/b3 throughout — Pads 28% scale consonance, Rhythm 35%, Bass 40%), Alt-Strom (E Mixolydian, borrowed b6/b3 — same range), Cycle-2 (B Mixolydian, borrowed b3 in B section). Every bar in the borrowed-root sections had 4–7 simultaneous semitone clashes and tritones across tracks. This is the cause of the specific clashes heard in A-Flow bars 11 and 80–89.

**NotePoolBuilder using section.mode (hardcoded Dorian) instead of frame.mode** — `buildChordWindows` passed `section.mode` to both `pickChordRoot` and `NotePoolBuilder.build`. All A sections have `section.mode` hardcoded to `.Dorian` regardless of `frame.mode`. Consequence: scale tension pools baked into every chord window reflected a Dorian scale, not the actual key. Generators using `entry.chordWindow.scaleTensions` (TextureGenerator, BassGenerator) drew from a Dorian pool even in Ionian songs.

**Chord type adds chromatic tones even with diatonic roots** — PadsGenerator voiced chords using fixed interval offsets (e.g. dom7=[0,7,10,16], min7=[0,7,10,15]) without checking whether the resulting pitch classes are in the key scale. Example: F#m7 in E Aeolian adds C# (E Aeolian has C natural). Affected songs with otherwise-clean chord roots: GeistBahn Pads 74%, GeistStrom Pads 78%/Rhythm 71%, Langsam-Bahn Pads 77%/Rhythm 74%, Langsam-Maschine Pads 68%/Bass 51%.

**Lead 2 dominance persists in Long Breath songs** — Alt-Strom and Langsam-Maschine (both LD1-003) showed Lead 2 at 69% of total lead notes — same level as pre-Study-01. Technique D should escalate the B section, but both songs have very long B sections where the effect appears insufficient.

**Songs with fully diatonic chord plans are clean** — A-Tone, Field-4: Pads/Rhythm/Bass all above 87%. The fixes from Study 01 (flat7 snap, tonic-anchored LD2-004/005) are working correctly where chord roots are diatonic.

## Fixes Applied: Motorik Study 02 (March 2026)

**Chord root selection made mode-aware** — `pickChordRoot` in StructureGenerator now uses a mode-specific degree list. Ionian uses `["1","2","3","4","5","6","7"]`; Mixolydian uses `["1","2","3","4","5","6","b7"]`; Dorian uses `["1","2","b3","4","5","6","b7"]` (raised 6th, no b6); Aeolian keeps `["1","2","b3","4","5","b6","b7"]`. `buildChordWindows` now passes `frame.mode` (not `section.mode`) to both `pickChordRoot` and `NotePoolBuilder.build`, so chord roots and scale tension pools are always diatonic to the actual key.

**Pad voicing snapped to scale** — `PadsGenerator.buildVoicing` now snaps each voiced note's pitch class to the nearest in-scale PC after applying chord type offsets. If an interval (e.g. minor 7th in a dom7 chord) lands on a chromatic pitch class, it is shifted by the shortest semitone path to the nearest diatonic PC. This eliminates the residual chord-type chromatic tone problem (F#m7 adding C# in E Aeolian, etc.) without removing notes from the voicing.

---

## Findings: Kosmic Study 03 (cross-track tonal clash analysis, March 2026)

Second pass through the Study 03 batch — same 19 Kosmic songs — using the same MIDI pitch-class consonance scripts written for Motorik Study 02.

**Two songs with catastrophic borrowed-root clashes** — Auxese-test-bidge (C Dorian, 28 bars on root=b6): normal bars 99% consonant, borrowed bars 40.8% consonant, 118 simultaneous semitone clashes. Vortexe-VI (E Dorian, 14 bars on root=b6): normal 99%, borrowed 38.0%, 20 clashes. Root cause identical to Motorik Study 02: `pickKosmicChordRoot` returned "b6" 40% of the time for `two_chord_pendulum` regardless of the song's mode. b6 is diatonic only in Aeolian — in Dorian it is a borrowed degree whose chord tones (e.g. Cm in C Dorian = C Eb G, none in the key) clash directly with every other generator using the real scale.

**Mode mismatch causing Mixolydian dissonance (Maxima)** — Maxima (A Mixolydian) scored only 70.9% overall consonance despite no borrowed roots. `buildChordWindows` passed `section.mode` (hardcoded Dorian for all A sections) to `NotePoolBuilder.build`, so the scale tension pool reflected A Dorian (includes C natural) rather than A Mixolydian (needs C#). Compounded by the quartal chord on root=4 (D): quartal offsets [0,5,10,15] from D produce D,G,C,F where C and F are not in A Mixolydian.

**Chord-type chromatic tones in modal drift (Galaxie-VIII)** — Galaxie-VIII (E Dorian, root=b7 type=minor throughout) scored 75% overall. b7+minor = Dm in E Dorian context; Dm's minor third is F natural, not in E Dorian (has F#). The note pool's chord tones included F, which propagated through rhythm/texture generators. No mode mismatch here (frame.mode IS Dorian) — this is the chord-type chromatic tone issue, same tertiary cause as Motorik Study 02. Not fixed in this pass; scale-snap on Kosmic generators is a follow-up item.

**All other songs clean** — The 16 remaining Kosmic songs scored 84–100% consonance. Songs using `suspended_resolution` (Hexalon, Auxese, Solaxe, Fluxion) and `static_drone` (Astral-Current, Void-Ether) are consistently 93–99%. No borrowed-root clashes in any Aeolian song using `two_chord_pendulum` (Deep-Solstice, Polar-Horizon) — bVI is correctly diatonic in Aeolian.

## Fixes Applied: Kosmic Study 03 tonal clash fixes (March 2026)

**Chord root selection made mode-aware** — `pickKosmicChordRoot` signature changed from `section: SongSection` to `mode: Mode`. Call site now passes `effectiveMode` (= `frame.mode` for A/intro/outro sections, `section.mode` for B sections which carry meaningful Aeolian/Mixolydian modes). For `two_chord_pendulum`: "b6" used only when mode is Aeolian or MinorPentatonic (b6 diatonic); otherwise replaced with "4" (subdominant — always diatonic, equally atmospheric for the i→IV pendulum). For `modal_drift`: same — the degree list ["1","b7","b6","b7"] replaces b6 with "4" in non-Aeolian modes, giving i→bVII→IV drift instead of i→bVII→bVI.

**NotePoolBuilder + chord type picker use frame.mode for A sections** — `buildChordWindows` now computes `effectiveMode` at the top of the loop: A sections and all non-body sections use `frame.mode`; B sections keep `section.mode`. Both `pickKosmicChordType` and `NotePoolBuilder.build` receive `effectiveMode`, so scale tension pools are always diatonic to the actual song key. `anchorIntroToBody` also fixed to pass `frame.mode` instead of `introSection.mode` (which was always Dorian).

---

## Implementation Notes

- Log files land in the same Downloads folder as MIDI files: `~/Downloads/Zudio-SongName.txt`
- Bar numbers in the log are 1-based for readability
- Playback annotations in the log are sorted by bar position, not emission order

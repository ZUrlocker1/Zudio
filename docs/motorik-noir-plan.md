# Motorik Noir — Design & Implementation Plan
Copyright (c) 2026 Zack Urlocker

## Naming

The working name is **Motorik Noir**. "Noir" is widely understood (film noir, crime fiction) as meaning dark, nocturnal, claustrophobic — it communicates the mood without requiring genre knowledge.

---

## Musical Identity

Base Motorik is open-road and exhilarating — the Autobahn at speed, forward motion, bright. Motorik Noir keeps the hypnotic pulse but flips the emotional register entirely: nocturnal, claustrophobic, inward. The engine is the same but the mood is Joy Division's relationship to Neu! — the motorik mechanism deployed in service of darkness rather than propulsion.

### Reference artists

**Joy Division — *Unknown Pleasures* (1979), *Closer* (1980)**
The core reference. Peter Hook's bass is high-register and melodic — the actual lead voice of the band, not a rhythm instrument. The guitar is texture, not melody. The motorik pulse underneath is stiff and cold. "She's Lost Control" is the direct model for the Hook Ascent bass rule. "Decades" anchors the lower end of the BPM range.

**Public Image Ltd — *Metal Box* (1979)**
Jah Wobble's bass on "Albatross" is the extreme form of bass-as-only-voice: ten minutes, bass melody, dissonant guitar texture, stiff motorik groove, no lead melody. "Careering" is the clearest example of cold, angular guitar texture. "Poptones" shows how a repeating figure functions as a drone rather than a riff. "Theme" is the sparsest: two pitches per bar, half-note pulse, entire song driven by that minimalism.

**Wire — *Chairs Missing* (1978)**
"Map Ref. 41°N 93°W" demonstrates the tension arc in a compact form. "I Am the Fly" shows angular, rhythmic guitar-as-texture.

**Early Stereolab**
Motorik pulse plus minor-mode drone. The synthi washes and organ pads are closer to what Zudio can produce than Joy Division's guitar textures.

---

## PiL MIDI Analysis Findings

Seven PiL *Metal Box*-era songs were analyzed in detail (Albatross, Annalisa, Theme, Poptones, Careering, Swan Lake, Bad Baby). Key findings that revised or confirmed the design:

**Bass register is deep, not high.** The original plan called for "High Hook" bass in MIDI 52–68 (Peter Hook territory). PiL analysis revealed Wobble plays in the E1 zone (MIDI 28–40), one full octave below standard Motorik bass. All three new Noir bass rules use this deep register. The "high melodic bass" concept from Joy Division lives in MOT-BASS-007 Hook Ascent, which was already in the pool.

**Zero pads across all seven songs.** No song in the corpus has any pad, organ, or synth texture track. This directly drove the 85% pad-silence gate in Noir mode.

**Universal PiL song structure.** All songs open with bass + drums alone for 4–8 bars. The full band enters when the crash lands on beat 1 — no gradual layering, no instrument-entrance fills. This confirmed that Noir should suppress instrument-entrance fills and periodic body fills, keeping only section-transition cues.

**Annalisa drums are unlike any standard Motorik pattern.** Snare on all four beats (not just 2+4), open hi-hat on all eight 8th positions (no closed hat during groove), kick on offbeats only (steps 2, 6, 10). This is the inverse of standard rock drumming and creates the distinctive PiL claustrophobia.

**Theme bass is the sparsest pattern in the corpus.** Bar A: root half-note + P5 half-note. Bar B: five-note chromatic riff, beat 1 silent. The entire song is driven by two pitches per bar. Simplicity as power.

**Guitar-as-texture confirmed.** No PiL song in the corpus uses the guitar as a melodic lead instrument. All guitar parts are angular, rhythmic, held on one or two pitches. This validated the Cold Chord lead concept and the Chord Chug rhythm rule.

**Velocity is flat in the source material.** All seven MIDI files have velocity 89 uniformly (sequencer artifact). Zudio maintains human-feel gradients rather than mirroring this — it was a deliberate decision to keep the Zudio expressiveness while still referencing the mechanical feel through pattern, not velocity.

**Albatross open hat on step 14 is structurally significant.** The standard Motorik hat grid plays closed hats on every 8th and a closed hat on step 14. Albatross permanently opens step 14, creating a "hat breathe" just before the downbeat. This one change transforms the entire feel of the pattern without touching anything else.

---

## Joy Division MIDI Analysis Findings

Three Joy Division songs were analyzed (Disorder, Shadowplay, She's Lost Control). Key findings that drove the second-wave Noir rules:

**BPM is faster than originally assumed.** All three songs run 140–174 BPM. The original Noir ceiling of 128 BPM was too slow — it missed the nervous, claustrophobic urgency of the actual source material. The ceiling was raised to 140 (peak 130). Slower Noir tracks still fit the "Decades / Atmosphere" register; the new upper range fits Disorder-era speed.

**Shadowplay is a direct Motorik template.** Tempo 174, pure Apache beat (kick 1+3, snare 2+4), 16th hats. No structural invention — just the motorik mechanism played straight at high tempo. Confirmed that Classic Motorik (DRM-001) and Albatross Grid (DRM-005) are valid Noir drums; the darkness comes from the bass and modal context, not an unusual drum pattern.

**Disorder uses an inverted backbeat.** Snare on beats 1+3 (steps 0, 8), kick on beats 2+4 (steps 4, 12) — the exact opposite of the Apache convention. The hi-hat stays on 8th notes. At higher intensity, extra kick hits appear on the "and of 2" and "and of 4." The effect is unsettled forward-lurch — the beat feels like it's about to fall over but never does. Became DRM-007 "Inverted Beat."

**She's Lost Control has zero hi-hat.** The entire groove is built from snare and kick only — no hat of any kind. Kick pattern: steps 2, 4, 12, 14 (syncopated, never on the downbeat). Snare: beats 1+3. Every 4–8 bars the drums switch to a mechanical descending tom cascade: hi-mid tom triplet → low-mid tom triplet → floor tom roll, launched by kick+snare on step 0. The cascade is not a "fill" in the rock sense — it is metronomic, mechanical, and utterly cold. Became DRM-008 "Tribal."

**Peter Hook's bass is the actual lead voice.** On Disorder and She's Lost Control the bass is high-register, melodic, and moving constantly. The guitar provides rhythm/texture. This is the mirror image of standard rock arrangement. In Zudio terms: MOT-BASS-007 Hook Ascent (originally the melodic lead bass rule) was restored to its full high-register range (MIDI 48–72) in Noir context specifically for this reason.

**Repetition is the compositional logic.** All three songs are close to through-composed at the pattern level — the groove machine does not vary structurally between sections. Fills are rare and quiet. This reinforced the existing Noir decision to suppress body fills and instrument-entrance cues.

**Shadowplay bass is a root ostinato with one structural skip.** The pattern hits root 8th-notes on steps 0, 4, 6, 8, 10, 12, 14 — step 2 is always silent. The skip is the entire identity of the pattern; without it, it is just a root pulse. Bar B adds density (steps 0, 2, 4, 6, 8, 10) plus a M2 lean on the final quarter. 61 of 131 bars (47%) match the bar A template. Became MOT-BASS-020 "Shadowplay Pulse."

**Disorder guitar is a two-note quarter alternation.** Root on beats 1–4, a lower note (P5 or P4 below) filling the gaps — strict quarter-note rhythm, no 8ths, no syncopation. The result reads as a held texture rather than a melody. This is the "pendulum" quality of Disorder: two pitches rocking back and forth at a metronomic pace for the full song. Became MOT-LD1-010 "Pendulum."

---

## Second-Wave PiL MIDI Analysis Findings

Three additional PiL songs were analyzed after the first-wave findings (Religion, No Birds, This Is Not A Love Song). Key findings:

**Religion bass is front-loaded aggression.** Steps 0, 2, 4 are three consecutive root 8th-notes in descending velocity (88→84→80) — a cluster of impacts at the top of the bar. Step 6 lands on the m3 above for 4 steps, then steps 10 and 12 drop to the m3 below as a dark resolution. This front-loading pattern creates an aggressive attack that dissipates across the bar — the opposite of the building-toward-resolution approach in most bass lines. 121 of 149 bars (81%) match this template. Became MOT-BASS-019 "Religion Groove."

**No Birds uses the P4 as its primary tonal color.** Bar A: root 8th pickup on step 0, immediate move to P4 on step 2, P4 suspended through the bar. Bar B: two root quarter notes (steps 0, 4), then a chromatic ascent — P4 → tritone → P5 — landing on P5 on step 12. The tritone passing note is the sharpest moment of harmonic tension in the corpus; the P5 arrival on the final quarter resolves it just before the cycle repeats. Became MOT-BASS-021 "No Birds Walk" (2-bar cycle) and the beat-anchor lead texture in MOT-LD1-011.

**Not A Love Song guitar is a pure interleave.** Root hits on all four beats (steps 0, 4, 8, 12); a lower pitch hits on all four ands (steps 2, 6, 10, 14). The two voices never sound simultaneously — the rhythm alternates perfectly between them. 102 of 103 bars (99%) match this pattern. The lower voice is a P4 below (40%) or P5 below (60%) the root. Became MOT-RTHM-009 "Interleave."

**No Birds lead is a beat melody over a sustained lower drone.** The guitar plays scale tones on each beat (quarter-note melody, moving by step across the bar), while a lower fixed pitch sustains on each "and" between beats. The melody moves; the drone does not. The effect is a cantus firmus inversion — the moving voice is on top, the pedal is below. Became MOT-LD1-011 "Beat Anchor."

---

## How It Differs from Base Motorik

### Frame and structure

- **BPM** — 110–140 (peak 130) vs base 126–154 (peak 138). Slower Noir tracks feel heavy and oppressive; faster ones (around 140) hit the Disorder-era urgency.
- **Mode** — 80% Aeolian (natural minor), 20% Dorian. Bright modes (Ionian, Mixolydian) excluded.
- **Progression family** — biased to minor_loop_i_VII (38%), minor_loop_i_VI (30%), modal_cadence (22%), static_tonic (10%). The two_chord_I_bVII (classic Neu! open-road) is excluded.
- **Song length** — capped at 220s, peak 190s (≈ 3–3.5 min), vs base 270s peak 210s.

### Drum fill behavior

- Periodic body fills and instrument-entrance fills are suppressed (section-transition fills only).
- Fill length distribution: 95% 1-beat, 5% 2-beat, 0% 3-beat.
- Bonham Descent (2-beat v1) excluded — too dramatic for the locked-grid aesthetic.
- New 1-beat fill variant v6 (Floor Tom Double) available in Noir only.

### Lead 2

Always suppressed in Noir — generation is skipped entirely. The track logs "MOT-LD2-000". This reflects the PiL/Joy Division aesthetic where there is a single lead voice (or none), never a secondary melody running alongside.

### Texture

50% of Noir songs suppress the texture track entirely (logs "MOT-TEX-000"). When texture does fire, the Noir pool replaces the Regular pool:
- **Noir pool**: TEXT-003 (Spatial Sweep), TEXT-004 (Shimmer Hold), TEXT-006 (High Tension Touch), TEXT-007 (Pedal Drone), TEXT-008 (Phase Slip)
- **Regular pool**: TEXT-002, TEXT-003, TEXT-004, TEXT-005, TEXT-007
- **TEXT-006 "High Tension Touch"** — single scale-tension note, off-beat, fires ~once per 20 body bars. Noir only.
- **TEXT-008 "Phase Slip"** — two adjacent semitone notes at the same step (vel 25–35), ~once per 20 body bars. Noir only.

### Pads

- 50% of Noir songs have no pads at all (song-level gate).
- When pads fire, an additional per-bar gate skips 70% of individual bars (except PAD-008 which manages its own on/off cycle).
- Noir-only pad rules: PAD-002, PAD-007, PAD-008. PAD-005 (Charleston) is excluded.
- Break rule after 4 consecutive sustained bars: PAD-006 (Half-bar Breathe) in Noir; PAD-005 (Charleston) in Regular.

**MOT-PADS-002 "Power Drone"**
Root + fifth + octave whole-bar voicing. Heavier and more industrial than PAD-001's open chord. The octave doubling on the root creates a power-chord texture without a third. Noir only.

**MOT-PADS-007 "Backbeat Stabs"**
Chord hits on beats 2 and 4 only (steps 4, 12, duration 3). The displaced accent creates a nervous, unsettled feel — the pads are where the snare would be in a standard groove. Noir only.

**MOT-PADS-008 "Transmission Block"**
Open-5th triad (root + fifth + octave, no third) held 4–8 bars, then 5–8 bars of silence, beat 1 only. Does not follow chord changes — locks to the tonic throughout. Reference: Joy Division "Transmission" (1979), single D–A–D chord, 8 bars on / 7 bars off for the entire song. Noir only.

### Pad pool weights (Noir, when pads fire)

- MOT-PADS-003 Pulsed: 20%
- MOT-PADS-006 Half-bar Breathe: 20%
- MOT-PADS-002 Power Drone: 17%
- MOT-PADS-007 Backbeat Stabs: 15%
- MOT-PADS-008 Transmission Block: 15%
- MOT-PADS-004 Chord Stabs: 8%
- MOT-PADS-001 Sustained: 5%
- MOT-PADS-005 Charleston: 0% (excluded)

---

## Noir Rule Catalog

All rules below are Motorik Noir only. They do not appear in the base Motorik pool.

### Drum rules

**MOT-DRUM-005 "Albatross Grid"**
Classic Motorik 16th-hat pattern with one permanent change: closed hat on step 14 is replaced by an open hat held through the downbeat. Everything else is identical to DRM-001 (Classic Apache). The open step-14 is the Albatross signature — it breathes just before beat 1 restarts. Low intensity routes to a sparse variant.

**MOT-DRUM-006 "Annalisa March"**
Inverted Motorik groove inspired by PiL "Annalisa." Snare on all four beats (steps 0, 4, 8, 12), open hi-hat on all eight 8th positions, kick on the three offbeats (steps 2, 6, 10) only. No closed hat during the groove at all. At high intensity, 25% chance of a double snare at steps 14–15. The most rhythmically aggressive Noir drum rule.

**MOT-DRUM-007 "Inverted Beat"**
Snare on beats 1+3 (steps 0, 8), kick on beats 2+4 (steps 4, 12) — the Apache convention reversed. 8th-note closed hat. At high intensity on odd bars: extra syncopated kick on "and of 2" (step 6) and "and of 4" (step 14), adding forward-lurching pressure without breaking the grid. Based on Joy Division "Disorder" (1979). Low intensity routes to the standard sparse bar. Noir drum pool weight: 18%.

**MOT-DRUM-008 "Tribal"**
No hi-hat at all — the groove is entirely kick and snare. Snare on beats 1+3 (steps 0, 8). Kick syncopated: steps 2, 4, 12, 14 (never on beat 1). At high intensity, every 6th bar is replaced by a mechanical descending tom cascade: kick+snare launch on step 0, hi-mid tom triplet (steps 4–6), low-mid tom triplet (steps 8–10), floor tom roll (steps 12–15). The cascade is not a fill — it is metronomic and cold, a structural repetition unit. Based on Joy Division "She's Lost Control" (1980). Noir drum pool weight: 12%.

### Drum pool weights (Noir)

- MOT-DRUM-001 Classic Motorik: 16%
- MOT-DRUM-002 Open Pocket: 6%
- MOT-DRUM-003 Ride Groove: 16%
- MOT-DRUM-005 Albatross Grid: 18%
- MOT-DRUM-006 Annalisa March: 14%
- MOT-DRUM-007 Inverted Beat: 18%
- MOT-DRUM-008 Tribal: 12%

### Bass rules

**MOT-BASS-016 "Albatross Pulse"**
Deep E1-register (MIDI 28–40) 8th-note ostinato. Pattern: root–root–P5–root–root–root–P5–m6 per bar. The m6 is mode-snapped, giving a dark lean on the last 8th before the cycle restarts. ~5% breathe variant: first P5 extends to a held quarter note, opening the pulse briefly. Reference: "Albatross" (PiL, 1979). Noir pool weight: 22%.

**MOT-BASS-017 "Annalisa Riff"**
4-bar cycling deep bass (MIDI 28–40). Bar A (bars 0 and 2): root anchor 4 steps, then mode-6th repeated with escalating durations. Bar B (bar 1): beat 1 silent; two 3-note chromatic descent waves (P5→b5→P4, root+oct→maj7→b7). Bar C (bar 3): beat 1 silent; mirror ascent waves (b7→maj7→oct, P4→b5→P5). Reference: "Annalisa" (PiL, 1979). Noir pool weight: 25%.

**MOT-BASS-018 "Wobble Theme"**
2-bar half-note cycle (MIDI 28–40). Bar A: root half-note (steps 0–7), P5 half-note (steps 8–15). Two notes per bar only. Bar B: beat 1 silent; five-note b7-based riff — b7(d4), b7(d2), maj2(d2), root(d2), b7(d4) — starting at step 2. The sparsest bass pattern in the Noir pool, modeled on Jah Wobble's "Theme" approach. Noir pool weight: 10%.

**MOT-BASS-019 "Religion Groove"**
1-bar pattern (MIDI 28–40). Steps 0, 2, 4: three root 8th-notes in descending velocity (88→84→80) — a front-loaded cluster that attacks the top of the bar. Step 6: m3 above held for 4 steps (quarter note). Steps 10, 12: m3 below as dark resolution. The front-loading is the defining character: aggression at the downbeat, decay across the bar. 81% modal consistency across 149 analyzed bars. Reference: "Religion" (PiL, 1979). Noir pool weight: 8%.

**MOT-BASS-020 "Shadowplay Pulse"**
2-bar alternating ostinato (MIDI 28–40). Bar A: root 8th-notes on steps 0, 4, 6, 8, 10, 12, 14 — step 2 permanently silent (the structural skip). Bar B: denser root pulse on steps 0, 2, 4, 6, 8, 10 plus a M2 lean on the final quarter. The skip on step 2 of bar A is the entire identity of the pattern — without it, it collapses into a plain 8th-note ostinato. Reference: "Shadowplay" (Joy Division, 1979). Noir pool weight: 8%.

**MOT-BASS-021 "No Birds Walk"**
2-bar cycle (MIDI 28–40). Bar A: root 8th pickup (step 0), immediate P4 move (step 2), P4 suspension held through the bar. Bar B: two root quarter notes (steps 0, 4), then chromatic ascent — P4 → tritone → P5 — landing on P5 at step 12. The tritone passing note is the sharpest dissonance in the Noir bass pool; the P5 arrival resolves it one quarter before the cycle restarts. Reference: "No Birds" (PiL, 1979). Noir pool weight: 6%.

### Bass pool weights (Noir)

- MOT-BASS-017 Annalisa Riff: 17%
- MOT-BASS-018 Wobble Theme: 16%
- MOT-BASS-019 Religion Groove: 16%
- MOT-BASS-021 No Birds Walk: 16%
- MOT-BASS-016 Albatross Pulse: 10%
- MOT-BASS-020 Shadowplay Pulse: 10%
- MOT-BASS-007 Hook Ascent: 5%
- MOT-BASS-008 Moroder Pulse: 5%
- MOT-BASS-006 LA Woman Sustain: 5%

### Lead rules

**MOT-LD1-009 "Cold Chord"**
Single-pitch texture hold. Picks root or P5 (75%/25%) at the start of each 4–8 bar window and holds that pitch throughout, velocity 38–52. 30% chance to add P5 as a 2-note cluster. 25% chance of a quiet re-attack at beat 3 (the "guitar chug" cue). No melodic movement between notes. Register MIDI 60–72. Noir lead pool weight: 10%.

**MOT-LD1-010 "Pendulum"**
Two-note quarter alternation across a 4–8 bar window. Root on beats 1–4, lower note (P5 below, or P4 below on 30% of windows) on the off-beats — strict quarter-note rhythm, no 8ths, no syncopation. The window length is seed-determined and consistent within a section. 20% chance of a soft root echo on the "and" of beat 1 or 2. The effect is a textural rocking rather than melody. Register MIDI 52–79. Reference: "Disorder" guitar texture (Joy Division, 1979). Noir lead pool weight: 14%.

**MOT-LD1-011 "Melodic Spiral"**
Scale tones on each beat (quarter-note melody, stepping through the scale starting from a bar-offset position), with a fixed lower pitch sustaining on each "and" between beats. The melody moves; the anchor drone does not. The bar-offset advances by 1 scale step every 4 bars, so the melody slowly rotates without repeating identically. Register MIDI 52–79. Reference: "No Birds" guitar texture (PiL, 1979). Log: "Melodic Spiral". Noir lead pool weight: 16%.

**MOT-LD1-012 "Chromatic Descent"**
Slow descending chromatic line — steps downward by semitone or diatonic step across a 4–8 bar window. Notes are long (half-note or quarter-note duration), velocity 42–58. Silence gates are generous: ~40% of bars rest. The effect is a cold, slow melodic fade — a line disappearing rather than arriving. Noir only. Log: "Chromatic Descent". Noir lead pool weight: 10%.

**MOT-LD1-013 "Slow arc"**
Wide-range melodic phrase built by the shared phrase-builder engine (slow, step-wise movement, long note durations). Phrases are 4–8 bars long with generous silence between them. The arc spans a wide register (up to 2 octaves) and resolves downward at phrase end. Noir only. Log: "Slow arc". Noir lead pool weight: 13%.

**MOT-LD1-014 "Rising phrase"**
High-register melodic phrase with offbeat entry — the phrase starts on the "and" of beat 1 rather than the downbeat, giving an unsettled, arriving quality. Faster note movement than LD1-013, higher register (MIDI 65–79). Silence blends shorter as the song progresses so the line becomes more present in the second half. Uses the same phrase-builder engine as LD1-013. Noir only. Log: "Rising phrase". Noir lead pool weight: 14%.

### Lead pool weights (Noir)

- MOT-LD1-010 Pendulum: 17%
- MOT-LD1-011 Melodic Spiral: 17%
- MOT-LD1-014 Rising phrase: 15%
- MOT-LD1-013 Slow arc: 14%
- MOT-LD1-009 Cold Chord: 11%
- MOT-LD1-012 Chromatic Descent: 10%
- MOT-LD1-006 Long Arc Solo: 4%
- MOT-LD1-008 Visiting Solo: 4%
- MOT-LD1-001 Neu! Motif First: 4%
- MOT-LD1-005 Call and Answer: 4%
- ~~MOT-LD1-007 Vanishing Solo~~ — excluded from Noir. Its melodic arc was written for a major-key context; minor-scale adjustment corrects the notes but not the optimistic resolved character of the phrase, which clashes with the Noir aesthetic. 

### Rhythm rules

**MOT-RTHM-007 "Chord Chug"**
Root + fifth (60%) or root + fourth (40%) two-note stabs on all 8th-note positions. Velocity 72–80, slight beat accent (+6 on beats 1 and 3). No melodic movement — pure rhythmic mass, the guitar-power-chord texture of PiL and Wire. Noir rhythm weight: 36%. Noir only.

**MOT-RTHM-008 "Sparse Stab"**
Same root+fifth (or root+P4) dyad as Chord Chug but quarter-note spacing (stride by 4) with 65% hit probability per beat. More open and spacious than Chord Chug — the silence between hits is as important as the hits. Fits naturally alongside the Tribal drum pattern or in lower-intensity sections where Chord Chug would feel too dense. Noir rhythm weight: 22%. Noir only.

**MOT-RTHM-009 "Interleave"**
Root hits on all four beats (steps 0, 4, 8, 10, 12), lower pitch (P4 below 40%, P5 below 60%) on all four ands (steps 2, 6, 10, 14). Two voices, never simultaneous — the rhythm alternates perfectly between them at 65% beat probability. Velocity: beats at 74–84, ands at 62–70. The effect is angular two-voice texture with no harmonic overlap, the exact inverse of a chord stab. 99% modal consistency across 103 analyzed bars. Reference: "This Is Not A Love Song" guitar (PiL, 1983). Log: "Interleave". Noir rhythm weight: 12%. Noir only.

**MOT-RTHM-010 "Single-Note Pulse"**
Single root pitch on every 8th-note position, 50–82% density (intensity-scaled), accent (+8 velocity) on beats 1 and 3. No dyad — the mechanical one-pitch throb of Joy Division bass lines. 30% of 4-bar groups go completely silent. Pitch: 80% root, 15% P5 below, 5% flat-7, chosen once per bar. Log: "Single-Note Pulse". Noir rhythm weight: 14%. Noir only.

**MOT-RTHM-011 "Three-One Stab"**
Three quick root+fifth dyad hits at s0, s2, s4 (d2 each), then a shifted chord tone (flat-7 60%, third 40%) at s6 (d4), then root return at s10 (d5). The 3+1+1 rhythmic grouping creates a front-heavy, angular feel. Density gate on each hit. Reference: Keith Levene's Religion guitar (PiL): the 3+1+1 grouping in bars 6/8/10. Log: "Three-One Stab". Noir rhythm weight: 14%. Noir only.

**MOT-RTHM-012 "Void Stab"**
Root+fifth (or root+P4) sustained d8 on beat 1, optional beat-3 re-hit (50% chance), optional pickup note at s14 (40% chance). Maximum 3 notes per bar — creates an ambient chord wash rather than a rhythmic pattern. From PiL Albatross T3 guitar: full-bar sustains with sparse melodic fragments. Log: "Void Stab". Noir rhythm weight: 12%. Noir only.

**MOT-RTHM-013 "Levene Drop"**
Staccato single notes on "and" positions only (steps 2, 6, 10, 14), 45% hit probability per step, 30% of bars completely silent. Root (55%) / flat-7 (30%) / fifth (15%) chosen once per bar — no dyad. The effect is isolated guitar drops that arrive on off-beats and never stack. Reference: Keith Levene's isolated guitar figures in early PiL (Theme, Annalisa). Log: "Levene Drop". Noir rhythm weight: 12%. Noir only.

### Rhythm pool weights (Noir)

- MOT-RTHM-001 8th-note Stride: 4%
- MOT-RTHM-002 Quarter Stride: 10%
- MOT-RTHM-003 Syncopated Motorik: 0%
- MOT-RTHM-004 2-bar Melodic Riff: 0%
- MOT-RTHM-005 Chord Stab: 0%
- MOT-RTHM-006 Arpeggio: 0%
- MOT-RTHM-007 Chord Chug: 10%
- MOT-RTHM-008 Sparse Stab: 14%
- MOT-RTHM-009 Interleave: 12%
- MOT-RTHM-010 Single-Note Pulse: 14%
- MOT-RTHM-011 Three-One Stab: 14%
- MOT-RTHM-012 Void Stab: 12%
- MOT-RTHM-013 Levene Drop: 12%

### Drum fill variant

**1-Beat Fill v6 "Floor Tom Double"**
Strips hats on steps 14–15, places two high floor tom hits (velocity 72, 88). No crash. PiL-style minimal cue: no snare, no drama, just two floor tom strikes landing into the downbeat. Available only in Noir 1-beat fill selection (7-variant pool: v0–v6).

---

## What Is Still Missing

### Drop section (bass + kick only)

An 8-bar section where all instruments except bass and kick drop out — maximum tension, minimalist. This is the structural climax of Motorik Noir. Not yet implemented.

The ArrangementFilter approach is lower risk (no new SectionLabel plumbing):
- Placed at 40–55% of total bars
- Length: 8 bars
- All tracks except kTrackBass and kTrackDrums: events in this range filtered out
- Drums during drop: kick only (snare removed)

---

## Title generation

Single-word Motorik Noir titles get a suffix phrase appended: "After Dark", "Apocalypse", "Midnight", or "Noir" (equal weight). Multi-word titles are left unchanged. Example: "Schmutz" → "Schmutz After Dark".

---

## Testing Notes

Current activation probability is **50%** of Motorik songs. Target release probability is **~30%**.

Listen for:
- Tempo: lower-range Noir (110–120) is heavy and oppressive; upper-range (130–140) is anxious and driving — both are valid
- Mode: always minor — no Mixolydian or Ionian songs
- Bass: watch the generation log for which bass rule fired; Wobble Theme (018) should sound extremely sparse; Hook Ascent (007) should be heard in the higher register, melodic and prominent
- Drums (DRM-005): Albatross Grid — standard motorik with the open hat breathe on step 14; subtle difference from DRM-001
- Drums (DRM-006): Annalisa March — snare on all 4 beats sounds like a march, very different feel
- Drums (DRM-007): Inverted Beat — kick on 2+4 instead of 1+3 creates a lurching, off-balance quality; should be clearly distinguishable from standard Apache
- Drums (DRM-008): Tribal — no hat at all, purely kick and snare; tom cascade every ~6 bars should be metronomic and cold, not dramatic
- Fills: fills should be rare and subtle — no Bonham descents
- Pads: most songs should have no pads at all
- Rhythm (RTHM-007): Chord Chug — dense 8th-note power dyads, guitar-texture feel; should sound like Wire or PiL not like a melodic instrument
- Rhythm (RTHM-008): Sparse Stab — same dyad as Chord Chug but quarter-note with gaps; more open, less insistent
- Rhythm (RTHM-009): Interleave — two voices strictly alternating, root on beats and lower pitch on ands; should feel like two separate instruments never playing at the same time
- Rhythm (RTHM-010): Single-Note Pulse — one pitch, 8th-note grid, accent on beats 1+3; mechanical throb with silent 4-bar gaps; sounds like a Joy Division bass translated to a guitar register
- Rhythm (RTHM-011): Three-One Stab — three quick hits at the top of the bar, then a shifted chord at step 6, then root return at step 10; the front-heavy 3+1+1 grouping should feel angular and PiL-like
- Rhythm (RTHM-012): Void Stab — sparse chord wash: sustained dyad on beat 1, optional beat-3 hit, optional pickup; should feel like held guitar chords drifting rather than a rhythmic pattern
- Rhythm (RTHM-013): Levene Drop — isolated staccato notes on off-beats only (steps 2,6,10,14), 30% of bars silent; should sound like guitar figures dropping in from nowhere and disappearing
- Lead (LD1-009): Cold Chord — should feel like a held tone with occasional re-attacks, not a melodic line
- Lead (LD1-010): Pendulum — root and lower note rocking back and forth on quarter notes for 4–8 bars; texturally similar to Cold Chord but with two-pitch motion rather than static hold; no 8th-note activity
- Lead (LD1-011): Melodic Spiral — melody moves on the beats, lower drone sustains on the ands; the moving and fixed voices should be clearly audible as distinct layers
- Lead (LD1-012): Chromatic Descent — slow downward chromatic line with long notes and generous silence; should feel like a fading line rather than an active melody
- Lead (LD1-013): Slow arc — wide-range slow phrase with step-wise movement and long notes; resolves downward at phrase end
- Lead (LD1-014): Rising phrase — high-register phrase with offbeat entry on "and of 1"; faster and brighter than Slow arc, becomes more present in the second half of the song
- Bass (019): Religion Groove — three root hits cluster hard at the top of the bar, then the m3 steps in and the bar opens up; the front-loading is the character
- Bass (020): Shadowplay Pulse — root ostinato with a consistent gap at step 2; bar A and bar B should sound clearly different in density
- Bass (021): No Birds Walk — P4 suspension dominates bar A; bar B's tritone passing note on the ascent to P5 should be the most dissonant moment in the bar

---

## Reference: Chill Blues as the Model

Chill Blues (V1.4) is the precedent for sub-style implementation. It follows the same pattern:
- One probabilistic flag at song generation time
- Separate musical constraints (mode, BPM, instrument pool, song length)
- All generators receive the flag as a parameter
- Stored in SongState so per-track regen stays consistent
- `displayStyleName` returns the sub-style name in the UI

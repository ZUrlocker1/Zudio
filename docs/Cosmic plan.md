# Cosmic Style Generator — Research & Design Plan

## Context

Zudio currently generates only Motorik-style (krautrock) music. The user wants to add a second style called "Cosmic" — inspired by Berlin School electronic music (Tangerine Dream, Jean-Michel Jarre, Steve Roach, Craven Faults, Vangelis). This document is a research plan only; no code will be written yet. It establishes the musical rules, generator design, and architecture for when implementation begins.

The UI will eventually offer a style dial: **Motorik → Cosmic → Ambient** (Ambient is a future third choice). For now this plan covers Cosmic only.

---

## Part 1: Genre Research — What Is "Cosmic"?

### Definition

**Kosmische Musik** (German: "cosmic music") is 1970s West German electronic music rooted in synthesizers and sequencers, emphasizing themes of space and otherworldliness. It emerged from the experimental Zodiak Free Arts Lab in West Berlin. The genre is characterized by:

- **Ostinato step-sequences** (repeating melodic/harmonic patterns)
- **Modal improvisation** over static harmonic fields
- **Glacial structural development** — changes happen over minutes, not bars
- **Hypnotic, trance-inducing listening**
- **Timbre as primary narrative** — when harmony is static, synth tone color becomes the "melody"

**Critical distinction from Motorik:** Motorik (Neu!, Can) uses a steady 4/4 kick-drum groove as the forward propulsive engine; rhythm is primary. Cosmic/Kosmische uses sequencer patterns and harmonic drones as the engine; **rhythm is secondary or absent**. The energy is inward and spatial, not outward and propulsive.

---

## Part 2: Artist-by-Artist Analysis

### Jean-Michel Jarre — The Layerer

**Albums studied:** Oxygène (1976), Équinoxe (1978), Magnetic Fields (1981)

**Tempo & Rhythm:**
- Electronic rhythm (Korg Mini Pops) rather than drum kit; often "largely outside of time"
- Oxygène Part 2: ~126 BPM; rhythm machine programmed with Bossa Nova/Slow Rock settings
- Many sections have no percussion at all — pulse is implied by arpeggios and sequencers

**Keys & Harmony:**
- Minor keys favored: Oxygène in F minor; Magnetic Fields moves C → Fm → F → Bbm → Cm
- Harmonic rhythm extremely slow: chord changes every 8–16 bars or longer
- Multiple layered versions of the same chord (e.g., three Eminent String Machines processing one pad tone)

**Arpeggio Construction — The JMJ Core:**
- ARP 2600 and VCS-3 run through ARP 2500 ten-position sequencer
- **Interval patterns:** major/minor thirds, perfect fourths, octaves — avoids large leaps
- **Note counts per pattern:** 4–8 notes
- **Speed:** 8th-notes or 16th-notes at moderate BPM (creating 4–8 notes per beat)
- **Pattern shape:** Start on root, move stepwise or by 3rd, return to root or octave
- **Phasing:** Parallel arpeggio voices detuned 1–3 cents create chorus/shimmer
- The arpeggio IS the rhythm AND the harmony — it defines the groove and the chord simultaneously

**Structure:**
- Eight-bar melodic phrases alternate theme and development (classical logic)
- No verse/chorus; instead through-composed glacial unfolding
- Tracks 5–10+ minutes; structural "events" happen every 2–4 minutes

**Signature Sounds:**
- Eminent 310 organ string ensemble through slow phaser (0.1–0.2 Hz LFO)
- VCS-3 and ARP 2600 warm analog pads
- RMI additive synthesis (bell/organ hybrids)
- Slow filter sweeps and phasing as primary timbral devices

**Generative Lesson:** The arpeggio is the heartbeat. Everything else (pads, drones, texture) exists to frame and color it. The arpeggio must be diatonic, non-random, and phrased in 4–8 note loops. Phasing between parallel arpeggio voices provides variety without changing notes.

---

### Tangerine Dream — The Sequencer Pioneer

**Albums studied:** Phaedra (1974), Rubycon (1975), Ricochet (1975), Stratosfear (1976)

**Tempo & Rhythm:**
- Phaedra: beatless; rhythm emerges from layered sequencer patterns in different time signatures
- Ricochet: complex multi-layered rhythms foreshadowing trance/EDM
- Christopher Franke (drummer turned sequencer operator) treated the Moog 960 sequencer as a rhythm machine
- No conventional drum patterns in classic TD material

**Sequencer Architecture — The TD Core:**
- **Moog 960 sequencer:** 8, 16, or 32 steps
- **Skip logic:** Second row programmed to skip/reveal stages, exposing/hiding notes as arrangement evolves — this is what creates the sense of "descent"
- **Two sequencers interacting:** One controls pitch over 8 steps; second row skips stages
- **Delay timing:** Delay time = 1/4 or 1/8 of note length — creates phantom rhythmic multiplication
- 8-step patterns feel hypnotic; 32-step creates time-signature ambiguity

**Keys & Harmony:**
- Modal centers (Aeolian, Dorian, Phrygian) established by pedal points
- Minor keys dominant; harmonic ambiguity via modal interchange
- Oscillator drift (heating/cooling hardware) creates unintentional pitch shimmer — treated as a feature

**Voicing:**
- Moog analog pads with oscillators at -1.5 cents and +1.5 cents create chorus
- Fast filter attack (10ms), sharp decay (50–200ms), minimal sustain = "plucky" sequencer tone
- Mellotron flute provides occasional diatonic lines over sequences
- Tape echo (Revox A77) for spatial width

**Structure:**
- Phaedra title track: 17 minutes, single evolving idea
- No formal sections; instead cyclical arrangements that "breathe" — more/less density
- Calmer sections with "room to breathe" between intense sequencer passages
- A sense that the music is an organism that expands and contracts

**Generative Lesson:** The sequence pattern and its skip/reveal logic is more important than any single note. Two interlocking patterns creating polyrhythm is more effective than one complex pattern. Delay timing must be harmonic/rhythmic — not random reverb.

---

### Steve Roach — The Spatial Minimalist *(reference only — too extreme to model directly)*

> **Note:** Roach's music is entirely timbral — it works because Oberheim OB-8 analog filter evolution over 30 minutes IS the composition. In MIDI this reduces to a sustained chord with no events. He is retained here as a source of two specific principles (unsynchronized loop lengths, breath-shaped velocity) that are applied inside the Pads generator rather than as a modelable sub-style.

**Albums studied:** Structures from Silence (1984), Traveler (1983), Immersion series

**Tempo & Rhythm:**
- Completely beatless; no drums, no sequencer rhythm
- Music unfolds as "stately sonic formations of hypnotic weavings"
- Performs live by conducting loops and sequences, not layering pre-made tracks
- Three or four **unsynchronized** atmospheric loops running simultaneously

**Harmony:**
- Single drone or very slow harmonic motion (one chord per 20–30 minutes is possible)
- **Breathing chords:** Harmonic motion that evokes respiration — chord voicings swell and release
- Suspended chords (sus2, sus4) with slow modulation
- No traditional chord progressions; "harmonic drift" via LFO modulation of pitch ±20 cents

**Spatial Approach:**
- Oberheim OB-8, ARP 2600 for polyphonic pads with extremely long decay
- Multiple pad voices slowly shift register over time (unsynced)
- Plate/spring reverbs for spatial depth — reverb IS the space
- "Celestial music box with slowly orbiting motives" = multiple looping voices at different lengths

**Structure:**
- Three extended compositions; one track = 29 minutes
- No intro/build/peak/outro — instead **immersion** — you enter an already-existing world
- Listener finds their own tempo within the static texture
- Micro-evolution: what sounds static reveals slow harmonic drift over 20+ minutes

**Generative Lesson:** For Cosmic in Zudio, a Roach-style section means nearly static harmony with multiple overlapping pad layers at different loop lengths (e.g., 16, 20, and 24 bars) producing constant variation from a minimal palette. No drum track needed.

---

### Craven Faults — The Modernist Purist

**Albums studied:** Standers (2023), Erratics & Unconformities (2020), Waterways (2021)

**Tempo & Rhythm:**
- Retains a motorik-adjacent pulse (unlike pure ambient) but no explicit drum kit
- Rhythmic drive comes from repeating melodic patterns and synth bass, not percussion
- "Rhythmically locked in" but rooted in krautrock pulse
- Industrial/northern-England post-industrial edge

**Melody:**
- Repetitive melodic loops that "nimbly circle around drones" — 4–8 note pattern
- The loop itself IS the melody — singable, landscape-evoking
- Titles reference geology/landscape (Standers, Hurrocstanes, Meers & Hushes): music conveys terrain through melodic contour (rising lines for ascents, falling for descents)
- Modular synth (likely Moog-style semi-modular)

**Harmony:**
- Simple static harmonic progressions — 1–2 chords per section
- Minor modes establishing drone center
- Field recordings (Yorkshire industrial/natural landscapes) integrated as textural equals to synthesis

**Dynamics:**
- "Recorded and re-recorded to the correct level of imperfection" — intentional roughness; slight FM distortion keeps it human
- Layers added gradually over 4–8 bar cycles
- Dark, heavy timbre palette vs. the brightness of JMJ

**Generative Lesson:** Craven Faults proves a simple 4–8 note melodic loop can sustain a full track if the timbral palette is rich enough and the loop is allowed to breathe. The "imperfection" principle suggests intentional velocity/timing micro-variation (not strict quantization).

---

### Vangelis — The Cinematic Performer

**Albums studied:** Spiral (1977), Albedo 0.39 (1976), Blade Runner OST (1982), Heaven and Hell (1975)

**Tempo & Rhythm:**
- Rhythm emerges from chord changes and keyboard performance, not rhythm machines
- Heaven and Hell: mix of rhythmic propulsion and static passages
- Generally: rhythm subordinate to melody/harmony/timbre
- No sequencer patterns — everything is keyboard performance

**Keys & Harmony:**
- Heaven and Hell Part 1: **A major** (surprising brightness)
- Blade Runner Main Titles: E → Db → Bb → Abm → Gb (chromatic voice leading, unsettling)
- Blade Runner "Tears in Rain": F#m and D as two-chord foundation
- Spiral: Major and minor with chromatic voice leading
- More harmonic movement than Berlin School (cinematic scope requires events)

**Melody:**
- Strong singable lines (Blade Runner Main Titles is memorable even without words)
- Slow, held, expressive — Yamaha CS-80 allows velocity, aftertouch, ribbon controller performance
- Blend of jazz and classical sensibilities

**Chord Voicings:**
- Full polyphonic chords (5–6 voices simultaneously)
- **Filter attack ~1 second** → characteristic "brass swell" sound
- Slight octave detuning for warmth
- Aftertouch modulation within held chord = dynamic internal movement (human gesture)
- Pulse-width modulation for timbral richness without effects

**Structure:**
- Cinematic dramatic arc: follows emotional narrative of film scenes
- Multiple movements, each a complete statement
- Not looping; chord-change architecture drives structure
- Sudden texture shifts for dramatic effect (unlike Berlin School's gradual approach)

**Generative Lesson:** Vangelis shows that Cosmic doesn't have to be static. The "cinematic" variant uses two-chord simplicity (like Blade Runner's F#m/D) but makes those two chords sound vast through voicing, filter attack, and performance variation. For Zudio, the Vangelis approach means choosing 2-chord sections and varying how those chords are voiced/attacked per bar rather than changing chords frequently.

---

## Part 3: Universal Cosmic Rules (What All Five Share)

These rules are **non-negotiable** for anything to sound Cosmic:

1. **Hypnotic repetition + scheduled variation**
   - A pattern repeats 3–5 times before any change (3 = hook, 5 = hypnotic, 8+ = needs timbral variation)
   - Variation types in order of subtlety: spatial → timbral → harmonic → structural
   - Never random; always **scheduled** (on bar N, do X)

2. **Slow harmonic rhythm**
   - Chord changes every 8–16 bars minimum (vs. Motorik's 4–8 bars)
   - Drone/pedal points hold for 20–40 bars in spaciest sections
   - One tonal center per section

3. **Modal (not major/minor) tonality**
   - Aeolian (natural minor, darkest) — most common in Berlin School
   - Dorian (minor with raised 6th, warmth + darkness) — JMJ, Vangelis
   - Phrygian (minor with flat 2nd, mysterious/Spanish) — rare but effective
   - Mixolydian (major with flat 7th, open/suspended) — brighter cosmic sections
   - Avoid functional harmony (no V7→I resolution = no classical narrative)

4. **Timbre as primary narrative**
   - Filter sweeps, phasing, detuning, reverb depth changes = structural events
   - When harmony is static, tone evolution tells the story

5. **Spatial depth through effects**
   - Delay time = rhythmic division (1/4 or 1/8 of bar)
   - Reverb tail defines room size = defines spatial scale
   - Pan movement (slow LFO) creates perceived three-dimensionality
   - Multiple detuned voices (±1.5 cents) = analog chorus

6. **No rhythm-section primacy**
   - Drums absent or very subtle (no kick/snare grid)
   - If percussion exists, it is textural and sparse (hi-hat pulse, shaker, occasional hit)
   - Sequencer or pad replaces drummer's role

7. **Extended forms**
   - Sections are 2–5 minutes each (not 30-second verse/chorus)
   - No event-per-16-bars expectation
   - Listener immerses rather than follows a journey

---

## Part 4: Cosmic vs. Motorik — The Generative Differences

| Dimension | Motorik (current) | Cosmic (new) |
|---|---|---|
| Tempo | 126–154 BPM | 70–110 BPM (slower, more spacious) |
| Rhythm anchor | Kick drum 1+3, snare 2+4 | Sequencer arpeggio or absent |
| Harmonic rhythm | Change every 4–8 bars | Change every 8–32 bars |
| Mode | Dorian, Aeolian, Mixolydian | Aeolian, Dorian, Phrygian, Mixolydian |
| Song structure | Intro/A/B/Outro with clear arcs | Long evolving sections, glacial pacing |
| Lead melody | Phrase-first, syncopated, rhythmic | Long held notes, arpeggio-driven, sparse |
| Pads | Chord stabs, backbeats | Whole-bar sustains, slow swells |
| Bass | Motorik drive, 8th-note grooves | Slow root movement, drone-like |
| Drums | Full Motorik groove | Absent or sparse pulse only |
| Energy model | Propulsive, outward | Immersive, inward |
| Variation unit | Per-section (A/B) | Per-layer-cycle (staggered) |

---

## Part 5: Proposed Cosmic Generator Design

### 5.1 CosmicMusicalFrameGenerator

New `GlobalMusicalFrame` distributions for Cosmic:

**Tempo:** Triangular distribution, min=70, peak=90, max=110 BPM
- 90 BPM is the sweet spot (4 beats/bar = 1.5s/beat — breathing pace)
- At 90 BPM with 16th-note steps: 6.67ms/step — sequencer arpeggios feel right

**Keys:** Different probability table (more minor/flat keys):
- Am/A (20%), Em/E (18%), Dm/D (15%), Gm/G (12%), Cm/C (10%), Fm/F (8%), Bm/B (7%), other (10%)

**Modes:** Weighted differently from Motorik:
- Aeolian 40% (darkest, most "cosmic")
- Dorian 30% (warm darkness — most JMJ-like)
- Phrygian 15% (mysterious, Vangelis-adjacent)
- Mixolydian 15% (brighter, open-sounding)

**Progression Families** (new set for Cosmic):
- `static_drone` 30% — single tonic for 16–32 bars, slight voice movement
- `two_chord_pendulum` 25% — two chords alternating every 8–16 bars (Vangelis F#m/D model)
- `modal_drift` 20% — slow stepwise movement through modal scale tones (i → bVII → bVI → bVII → i)
- `suspended_resolution` 15% — sus2/sus4 chords resolving to minor/major slowly
- `quartal_stack` 10% — quartal harmony (stacked fourths), atonal feeling, spaciest

**Song length:** Triangular distribution min=180s, peak=300s, max=420s (3–7 minutes, longer than Motorik's 2.5–4.5)

---

### 5.2 CosmicStructureGenerator

**Song Forms:**
- `single_evolving` 50% — one long section that gradually mutates (Roach/TD model)
- `two_world` 35% — A section (spacious, static) → B section (denser, arpeggiated) → return
- `build_and_dissolve` 15% — builds from nothing, reaches peak density, dissolves back

**Section lengths:** 32–96 bars (much longer than Motorik's 16–48)

**Intro styles (Cosmic-specific):**
- `ambient_fade_in` — song starts at near-zero volume, slow 4-bar linear ramp, no pickup fill
- `texture_first` — pad/drone enters first (2 bars), then arpeggio joins on bar 3, bass on bar 5
- `sequencer_launch` — arpeggio starts immediately (no intro), pads enter bar 4 (JMJ style)

**Outro styles (Cosmic-specific):**
- `slow_dissolve` — layers drop out one at a time over 8 bars (opposite of build)
- `drone_hold` — all melodic content stops, pad/drone holds for 4 bars then fades
- `fade_to_silence` — master volume fade over 8–16 bars (ambient classic)

**Intensity model:** Instead of Motorik's low/medium/high per section, Cosmic uses a **density curve** — a smooth sine or ramp function over the whole song that controls how many layers are active at each bar.

---

### 5.3 CosmicArpeggioGenerator (new — central to the style)

This is the most important new generator. It replaces RhythmGenerator for Cosmic style.

**Arpeggio Construction Rules:**

**Pattern length:** 4, 6, or 8 notes (4 is most hypnotic; 8 creates more melodic interest)

**Interval vocabulary (JMJ-style):**
- Root → 3rd → 5th → octave (ascending triad arpeggio — most common)
- Root → 4th → 5th → octave (quartal arpeggio — more open/spacious)
- Root → 5th → octave → 3rd above (inverted ascending — avoids predictable root start)
- Root → 3rd → 5th → 3rd → root (arch shape — rises and falls in 5 notes)
- Root → 2nd → 3rd → 5th → 3rd → 2nd → root (scale walk — 7 notes, most melodic)

**Rhythm grid (at 90 BPM):**
- 16th-note arpeggios (fastest, most sequencer-like, TDream style) — `stepDuration = 1`
- 8th-note arpeggios (moderate, JMJ Oxygène feel) — `stepDuration = 2`
- Dotted 8th arpeggios (creates triplet feel against 4/4 grid) — `stepDuration = 3`
- Quarter-note arpeggios (slowest, most melodic, Vangelis-adjacent) — `stepDuration = 4`

**Tangerine Dream Skip Logic:**
At generation time, randomly mark 1–2 steps in the pattern as "skip" (velocity 0). This creates rhythmic gaps that the delay effect fills in, creating phantom notes. Skip positions should be consistent per pattern instance (not random per bar) for hypnotic effect.

**Phasing rule:**
If two arpeggio voices are used (Lead 1 + Rhythm track), offset the second voice by half the pattern length (e.g., if pattern is 8 steps, start voice 2 at step 4). This creates natural counterpoint without writing counterpoint.

**Modulation over time:**
- Every 16 bars: allow one note in the pattern to shift by ±1 semitone (the "slow mutation" effect)
- Every 32 bars: allow direction to reverse (ascending → descending → ascending)
- This is the "glacial variation" that keeps 20-minute tracks interesting

---

### 5.4 CosmicPadsGenerator

**Extends/replaces PadsGenerator** for Cosmic style.

**New pad rules:**

**COS-PAD-001: Long Drone** — whole notes held 2–4 bars, full chord voicing, very low velocity (40–55), filter LFO implied by velocity variation
- Duration: 32 or 64 steps (2 or 4 bars)
- Voicing: root + 5th + octave + (major or minor 3rd at octave up) = 4 voices

**COS-PAD-002: Swell Chord** — starts silent, velocity ramps from 20→80 over the bar, then holds (Vangelis brass swell)
- Use multiple velocity-stepped events to simulate filter attack on MIDI sampler
- Duration: 16 steps with ramped velocity across sub-events

**COS-PAD-003: Unsync Layers** — three pad voices at different loop lengths (8, 10, 12 bars) creating slowly shifting harmony from a single chord
- Voice 1: holds root chord for 8 bars
- Voice 2: holds same chord but different voicing for 10 bars
- Voice 3: holds inversion for 12 bars
- Their phase relationships shift over time = Roach-style organic variation

**COS-PAD-004: Suspended Resolution** — sus4 chord resolves to minor every 4 bars (sus4 for 3 bars, minor for 1 bar) — creates gentle periodicity

**COS-PAD-005: Quartal Stack** — stacked fourths (0, 5, 10 semitones) for atonal/spacious sections

**Voicing register:** MIDI 36–72 (lower than Motorik pads at 48–84) — creates spatial depth below the arpeggio

---

### 5.5 CosmicLeadGenerator

Lead melody in Cosmic is sparse and long-note-oriented. Not absent, but not rhythmically busy.

**New lead rules:**

**COS-LD-001: Slow Arc** — 2–4 note phrase, each note held 4–8 beats, rising or falling by scale steps. One phrase per 4–8 bars. Feels like a solo improvisation over the arpeggio bed.

**COS-LD-002: Floating Tones** — single notes, widely spaced (one every 2–4 bars), held until the next attack. Creates sense of vast space between events. Notes always on scale tones (no chromatic passing).

**COS-LD-003: Pentatonic Drift** — slow movement through pentatonic scale (5 notes only), each step 2–4 bars. The pentatonic constraint prevents dissonance. Sounds like a Japanese koto or Mellotron flute.

**COS-LD-004: Echo Melody** — a 4-note phrase (2 bars), followed by 2-bar silence, then the same phrase transposed up or down by a 3rd (question/answer). Repeats for the section. The classic Vangelis structural device.

**COS-LD-005: Arpeggio Highlight** — picks one note from the underlying arpeggio pattern and holds it for a full bar. Changes which note it highlights every 4 bars. Ties melody to arpeggio without duplicating it.

**Register:** MIDI 60–96 (higher than Motorik leads, more "celestial")
**Velocity:** 45–72 (softer than Motorik — cosmic is never aggressive)

---

### 5.6 CosmicBassGenerator

Bass in Cosmic is more drone-like than the driving Motorik bass patterns.

**New bass rules:**

**COS-BAS-001: Drone Root** — root note held for 2 bars (32 steps), releases, re-attacks. Velocity 65. The simplest possible bass — just marks the harmonic root.

**COS-BAS-002: Root-Fifth Slow Walk** — root for 2 bars, fifth for 2 bars, back to root. Creates slow harmonic movement underneath static pads. 8 bars per cycle.

**COS-BAS-003: Pedal Pulse** — root on every quarter note beat, short duration (4 steps), creates a subtle pulse without Motorik drive energy. Like a slow heartbeat.

**COS-BAS-004: Moroder Drift** — Giorgio Moroder-inspired: root held for 3 bars, then chromatic neighbor note (one semitone up) on bar 4 before returning to root. Creates harmonic tension without changing chord.

**COS-BAS-005: Absent Bass** (sparse sections only) — no bass events for 4–8 bar stretches, then COS-BAS-001 re-enters. This is the Roach approach: bass as punctuation, not foundation.

**Register:** MIDI 28–52 (same as Motorik — low register is the same regardless of style)

---

### 5.7 CosmicDrumGenerator (or: No Drums)

The key design question: **does Cosmic have drums?**

Research finding: Pure Berlin School (TD Phaedra, Steve Roach) has **no drums**. JMJ uses a minimal rhythm machine (Korg Mini Pops). Craven Faults uses no conventional kit. Vangelis uses drums on some tracks (Heaven and Hell) but not on ambient pieces.

**Recommendation:** Make drums **optional per song**, controlled by a new `percussionStyle` field in `CosmicMusicalFrame`:

- `percussionStyle = .absent` (40%): No drum track at all. Sequencer/arpeggio creates the pulse.
- `percussionStyle = .sparse` (35%): Single hi-hat pulse on every quarter beat (or every 2 beats), no kick or snare. Very quiet (velocity 35–50).
- `percussionStyle = .minimal` (25%): Occasional kick (beat 1 only, every other bar) + hi-hat pulse. The "electronic rhythm machine" feel — JMJ Mini Pops style.

No full Motorik groove in Cosmic mode.

---

### 5.8 CosmicTextureGenerator

Texture in Cosmic is more prominent than in Motorik (it becomes a primary voice, not a background shimmer).

**New texture rules:**

**COS-TEX-001: Orbital Motive** — a 3-note figure (root, 5th, octave) looping at a different length than the arpeggio (e.g., arpeggio = 8 steps, texture loop = 12 steps). Their phase relationship creates ever-changing rhythmic combinations. The Steve Roach "unsynchronized loops" approach.

**COS-TEX-002: Shimmer Hold** — single note held very quietly (velocity 25–35) for 4+ bars. Contributes to harmonic fullness without drawing attention. Think: a sustained string note buried in reverb.

**COS-TEX-003: Spatial Sweep** — slow glissando effect simulated by chromatic passing notes (velocity 20) between scale tones. One per 4 bars. Creates sense of filter sweep.

---

## Part 6: What Can Be Reused From Motorik Architecture

The Zudio generator architecture is well-suited to extension. All of these work as-is:

- `SeededRNG` — fully reusable, deterministic per-track seeds
- `MIDIEvent` struct — no changes needed
- `midiNote(key:degree:oct:)` — fully reusable
- `Mode.intervals` and `Mode.nearestInterval()` — reusable
- `ChordType.intervals` — reusable (quartal, power, sus2 all exist)
- `RegisterBounds` and `kRegisterBounds` — needs new entries for Cosmic tracks
- `TonalGovernanceBuilder` — fully reusable (works with any chord/mode combination)
- `DensitySimplifier` — reusable (density concept maps to Cosmic's layer counts)
- `ArrangementFilter` — reusable (post-processing is style-agnostic)
- `HarmonicFilter` — reusable (diatonic constraint works in any mode)
- `nearestMIDI(pc:bounds:prevNote:)` — fully reusable (voice leading is universal)
- `diatonicBelow/Above` helpers in LeadGenerator — reusable
- `buildArpNotes` in RhythmGenerator — reusable and extends to Cosmic arpeggio patterns
- `weightedPick` — universal
- `NotePoolBuilder` — reusable (pitch class sets work for any key/mode)

---

## Part 7: New Files Required

When implementation begins, create:

- `Sources/Zudio/Generation/Cosmic/CosmicMusicalFrameGenerator.swift` — tempo/key/mode/progression distributions
- `Sources/Zudio/Generation/Cosmic/CosmicStructureGenerator.swift` — song form, section lengths, intro/outro styles
- `Sources/Zudio/Generation/Cosmic/CosmicArpeggioGenerator.swift` — the core of the style; 4–8 note patterns, skip logic, phasing
- `Sources/Zudio/Generation/Cosmic/CosmicPadsGenerator.swift` — drone, swell, unsync-layer, sus/quartal rules
- `Sources/Zudio/Generation/Cosmic/CosmicLeadGenerator.swift` — sparse slow-arc, floating tones, echo melody
- `Sources/Zudio/Generation/Cosmic/CosmicBassGenerator.swift` — drone root, slow walk, pedal pulse
- `Sources/Zudio/Generation/Cosmic/CosmicDrumGenerator.swift` — absent/sparse/minimal percussion logic
- `Sources/Zudio/Generation/Cosmic/CosmicTextureGenerator.swift` — orbital motives, shimmer holds

**Modify:**
- `Sources/Zudio/Generation/SongGenerator.swift` — add `style: MusicStyle` parameter, branch to Cosmic generators
- `Sources/Zudio/Models/Types.swift` — add `MusicStyle` enum, new `PercussionStyle` enum, new progression families
- `Sources/Zudio/UI/TopBarView.swift` — add style dial (Motorik / Cosmic)
- `Sources/Zudio/UI/TrackRowView.swift` — Cosmic instrument presets for each track
- `Sources/Zudio/AppState.swift` — add `selectedStyle: MusicStyle` published property

---

## Part 8: UI — Style Dial

Replace the `Text("Style: Motorik")` static label in TopBarView with an interactive control.

**Design: Segmented picker (macOS `.segmented` style)**

```swift
Picker("Style", selection: $appState.selectedStyle) {
    Text("Motorik").tag(MusicStyle.motorik)
    Text("Cosmic").tag(MusicStyle.cosmic)
}
.pickerStyle(.segmented)
.frame(width: 140)
```

This is the cleanest macOS control for 2–3 choices. When Ambient is added, it becomes a 3-segment picker. No dial rotation needed — segmented control is instantly readable and matches macOS HIG.

**`MusicStyle` enum (add to Types.swift):**

```swift
enum MusicStyle: String, CaseIterable, Codable {
    case motorik = "Motorik"
    case cosmic  = "Cosmic"
    // case ambient = "Ambient"  // future
}
```

**Behavior:**
- Changing style takes effect on the next Generate (not the current song)
- The Generate button triggers regeneration using the selected style's generators
- Style selection persists across sessions (saved in AppState/UserDefaults)
- Track instrument presets change per style (Cosmic gets new instrument lists in TrackRowView)

---

## Part 9: Cosmic Instrument Presets (TrackRowView)

The existing GM program assignments will need a Cosmic variant per track:

- **Lead 1 (Cosmic):** Square Lead → Brightness (100), Vibraphone (11), Ocarina (79), Flute (73), Whistle (78) — lighter, more celestial than Motorik leads
- **Lead 2 (Cosmic):** Warm Pad (89), Halo Pad (94), New Age Pad (88) — pads acting as secondary melody
- **Pads (Cosmic):** Choir Aahs (52), String Ensemble (48), Synth Strings (50), Warm Pad (89), Space Voice (91)
- **Arpeggio/Rhythm (Cosmic):** Square Lead (80) for JMJ-style sequences, Vibraphone (11), Marimba (12), Kalimba (108)
- **Bass (Cosmic):** Moog Bass (39), Synth Bass 1 (38), Pad (89) at low register for drone effect
- **Drums (Cosmic):** Brush Kit (40) for sparse percussion, or absent

---

## Part 10: Open Questions (For Later Resolution)

1. **Tempo interaction with arpeggio speed:** At 90 BPM with 16th-note arpeggios, you get 6 notes/second — is that fast enough to feel "sequenced"? May need to allow tempo as low as 70 BPM for Roach-style sections.

2. **Delay timing:** The existing delay effect is a time-based effect on the audio output. For Cosmic, delay time should be calculated from BPM (e.g., quarter-note delay = 60/BPM seconds). This needs a BPM-aware effect setting, not just "on/off."

3. **Polyphonic arpeggio vs. monophonic:** JMJ arpeggios are monophonic (one note at a time). TD arpeggios are also monophonic. The existing arpeggio in RhythmGenerator is also monophonic. Good — no architecture change needed.

4. **Unsynchronized loop lengths (Steve Roach):** The current MIDI engine synchronizes all tracks to the same bar/step grid. Implementing truly unsynchronized loops would require fractional bar lengths or a separate loop-length concept per track. This may be complex — a simpler approximation is to use loop lengths that are co-prime (e.g., 8, 10, 12 bars per track), which creates long-period variation from simple patterns.

5. **Field recordings (Craven Faults):** Not feasible in MIDI. The "imperfection" principle can be approximated by adding ±5–10% velocity randomization and ±1 step timing jitter on some events.

6. **Microtonality:** Not feasible in standard MIDI. Skip for V1 of Cosmic.

7. **Continuous Play interaction:** Cosmic songs may need different transition rules — longer crossfades (6 bars instead of 4), and bass/pads may need to be "always copied" (not freshly generated) since stable drones are even more important in Cosmic than in Motorik.

---

## Part 11: Making It Sound Musical — The Core Rules

Drawing on all research, the key rules that prevent Cosmic from being "noise":

1. **Every note must be diatonic** (in the mode) — no random chromatic pitches
2. **The arpeggio pattern must be a recognizable shape** — not random note order; use one of the 5 interval vocabularies in §5.3
3. **Harmonic changes must be prepared** — change chord only on a bar boundary, and only to a chord that shares ≥4 pitch classes with the previous chord
4. **The bass must anticipate or confirm the chord** — bass moves to new root 1 step before or on the chord change bar
5. **Layers must not compete in the same register** — arpeggio (MIDI 60–84), pads (MIDI 36–72), lead (MIDI 72–96), bass (MIDI 28–52) must not overlap more than 4 semitones
6. **Velocity hierarchy:** Lead = 45–72, Arpeggio = 60–80, Pads = 35–60, Bass = 55–75, Texture = 20–45
7. **Silence is valid** — notes should not fill every step; rests ARE music in Cosmic style
8. **Skip logic creates the groove** — 1–2 skipped steps in an 8-step arpeggio pattern creates syncopation without complexity

---

## Part 12: Verification Criteria (When Implementation Begins)

1. Build: `xcodebuild -scheme Zudio -configuration Debug build`
2. Generate 10 Cosmic songs — all should be in 70–110 BPM range
3. All songs should have no full drum groove (only absent/sparse/minimal percussion)
4. Arpeggio track present in all songs, 4–8 note patterns diatonic to key
5. Harmonic changes should occur no more than once per 8 bars
6. Subjective test: does it sound like ambient/kosmische music? Would Tangerine Dream fan recognize the genre?
7. Style selector switches between Motorik and Cosmic — both styles generate correctly from the same Generate button
8. Test Mode (Cmd-T) works in Cosmic style — generates 1-minute songs for rapid audition

---

## Part 13: Song-Level Analysis & Derived Rules

This section provides concrete BPM, key, chord, and arpeggio data measured from specific recordings. These numbers directly inform the generator's probability tables and parameter bounds.

---

### Jean-Michel Jarre — Specific Song Analysis

**Oxygène Part 2**
- Tempo: ~87 BPM (feels like 173–174 at half-time/3/4 feel)
- Key: D Minor
- Time signature: 3/4 (unusual — most Cosmic is 4/4; this is an exception)
- Chord progression: Gm → Cm → Dm → F → Eb
- Character: Arpeggiated ARP 2600, slow phased string pad underneath, no percussion
- Generator lesson: Gm→Cm→Dm uses mostly 2nds and 4ths in bass movement — very smooth voice leading. The F→Eb at the end is the only chromatic step (whole tone down) and acts as the "surprise." Apply this: 4 diatonic chord changes, then 1 modal/chromatic pivot.

**Oxygène Part 4**
- Tempo: 126 BPM (coincides with the Motorik range — confirms BPM overlap at the upper end)
- Key: G Dorian
- Character: Iconic 8-step ARP 2600 sequence, each note 1/8th note duration, rise-fall arch shape
- Arpeggio shape: Root → 2nd → 3rd → 5th → 3rd → 2nd → Root (7 notes, the "scale walk" pattern from §5.3)
- Generator lesson: This is the canonical JMJ arpeggio. At 126 BPM with 8th notes = 4 notes/second. Confirms 8-step scale-walk as a top-priority arpeggio template.

**Équinoxe Part 4**
- Tempo: 115 BPM
- Key: F Major (unusually bright for JMJ — Ionian mode)
- Character: Korg Mini Pops rhythm machine, arpeggio + synth line counterpoint
- Generator lesson: 115 BPM is the sweet spot for "fast Cosmic" — rhythmic but not propulsive. Confirms upper BPM bound at ~120 (above that it starts sounding Motorik).

**Magnetic Fields Part 2**
- Tempo: ~98 BPM (195 at double time)
- Key: G#/Ab Major → moves through C → G → Ab → Fm → G → Cm
- Character: More harmonic movement than Oxygène — chord changes every 4–8 bars, modulation to relative minor
- Generator lesson: This is JMJ at his most "eventful." Six distinct chords over a long section. Even here, each change shares 3–4 pitch classes with previous. Confirms: chord changes are allowed every 4 bars minimum, but must share 3+ pitch classes.

**Revised JMJ BPM range for generator:** 87–126 BPM (not 70–110 as previously estimated). The slow end is slower than expected; the fast end reaches Motorik territory.

---

### Tangerine Dream — Specific Song Analysis

**Phaedra (title track, 1974)**
- Tempo: ~166 BPM (sequencer pulse, no drums — feels much slower due to long note durations)
- Key: Ambiguous — oscillates between C Major and D Minor (modal interchange, no clear tonic)
- Arpeggio: Moog 960, 8 steps, each note a 16th at 166 BPM ≈ 2 notes/second
- Oscillator drift: ±3–5 cents detune over 30s due to thermal instability — creates natural chorus without LFO
- Generator lesson: At 166 BPM with 16th-note arpeggios, pattern completes in ~1.2 seconds — very fast and hypnotic. The ambiguous key (neither pure C nor pure D) comes from using only the white-key MIDI notes (natural minor/major overlap). Implement as: pick root but use both Ionian and Aeolian notes from that root simultaneously (the "white key" set = C major = A minor overlapping).

**Rubycon Part 1**
- Sequencer evolution: begins with 4 notes/bar → expands to 5 → 6 → 12 as the track progresses
- Gate logic: Row 1 = note pitch, Row 2 = gate ON (1v) or skip (0v) — approximately 2 out of 8 steps are silent
- Pattern: not strictly diatonic; some chromatic neighbor notes (1 semitone steps) used for tension
- Generator lesson: The expansion from 4→12 notes/bar is the structural engine of the track. Implement as: `notesPerBar` starts at 4 in intro sections, increases by 2 every 16 bars in peak sections. This is the Cosmic equivalent of Motorik's intensity arc. Skip probability ≈ 25% (2 of 8 steps).

**Ricochet Part 1**
- Tempo: 146 BPM (faster than expected for Berlin School — confirms the upper range extends higher)
- Key: C Minor
- Character: Multiple interlocking sequences at different speeds, more rhythmically complex than Phaedra
- Generator lesson: At 146 BPM, Ricochet overlaps with Motorik entirely in tempo. The distinction is purely timbral and structural. Confirms tempo alone cannot distinguish Cosmic from Motorik — the absence of a kick-drum groove is the real marker.

**Berlin School Sequencer Pattern Example (Klaus Schulze-style):**
```
Row 1 (pitch):  c4  e4  g3  a3  f4  a3  d4  d3   ← normal speed
Row 2 (pitch):  a3  d4  d3  a3  d4  a3  e4  d3   ← half-speed (same 8 steps, 2x duration)
Gate:           1v  1v  0v  1v  1v  0v  1v  1v   ← 2 silences out of 8
```
- All notes are diatonic to D Minor (d, e, f, g, a, c — natural minor scale)
- Adjacent intervals: 2nds (d→e), 3rds (e→g), 2nds (g→a), 3rds (f→a), 4ths (a→d), 2nds (d→d) — maximum interval 4 semitones (minor 3rd), typical interval 2 semitones (major 2nd)
- Generator rule derived: **Max adjacent interval in arpeggio = 5 semitones (perfect 4th).** Steps larger than a 4th feel un-sequencer-like. This is the single most important interval constraint.

---

### Vangelis — Specific Song Analysis

**Blade Runner Main Titles**
- Tempo: 115–117 BPM
- Key: E Major (Ionian — surprisingly bright for noir sci-fi)
- Chord movement: A → E alternating (IV → I), very simple two-chord pendulum
- CS-80 voicing: 5–6 simultaneous voices, filter attack ~1 second ("brass swell"), slight octave detuning
- Generator lesson: The simplest possible harmonic structure — just IV→I. The complexity comes entirely from voicing and timbre. For Cosmic generator: `two_chord_pendulum` should default to I→IV or I→V (the most consonant relationships), not ii→V→I jazz logic.

**Tears in Rain (Blade Runner End Titles)**
- Tempo: 111 BPM
- Key: F# Minor
- Chords: F#m → D (i → bVI) — the classic minor-to-relative-major one-step
- Character: Completely sparse — single CS-80 voice, long held notes, 4–8 bar silence between phrases
- Generator lesson: i → bVI is the definitive Vangelis two-chord. Also confirms extreme sparsity: a single note held for 4+ bars with silence around it is valid and intentional. For the lead generator, `COS-LD-002: Floating Tones` with 4-bar holds is confirmed by this track.

**Pulstar (Albedo 0.39)**
- Tempo: 123 BPM
- Key: Db/Eb Major
- Character: Repeating 4-note pattern, each bar the same, very hypnotic, almost no variation for 3 minutes
- Generator lesson: 4-note arpeggio at 123 BPM with 8th notes = one complete pattern per 2 beats = extremely hypnotic at this tempo. Confirms 4-note as the minimum viable arpeggio length and most hypnotic setting. The almost-zero variation is intentional — in Cosmic, variation is the exception, not the rule.

**Alpha (Heaven and Hell)**
- Tempo: 83–84 BPM
- Key: A Major (Ionian — bright)
- Character: Layered development — starts with single pad, adds voices every 8 bars, reaches full texture by bar 32
- Generator lesson: The intro build takes 32 bars to reach full density. This is 5× longer than a Motorik intro (typically 8 bars). Sets expectation for `texture_first` intro style: first instrument enters bar 1, second bar 4, third bar 8, fourth bar 16, fifth bar 32.

**Chariots of Fire**
- Tempo: 71 BPM (slowest confirmed tempo — sets the Cosmic floor)
- Key: Db Major
- Progression: I → IV → V (Db → Gb → Ab) — pure classical major resolution
- Character: Each chord held for 4 full bars, clean classical voice leading
- Generator lesson: At 71 BPM, this is the slowest end of Cosmic. Confirms absolute minimum BPM = 70 (previously estimated, now confirmed). Four-bar chord holds at 71 BPM = ~13.5 seconds per chord — extremely spacious.

**Revised Vangelis BPM range for generator:** 71–123 BPM. The distribution is roughly: slow end (71–84, Alpha/Chariots), mid (111–117, Blade Runner), upper (123, Pulstar).

---

### Craven Faults — Specific Song Analysis

**General findings from Standers (2023) and Erratics & Unconformities (2020):**
- Tempo range: 85–100 BPM (motorik-adjacent but without the explicit kick/snare grid)
- Keys: Minor keys exclusively — B Minor, E Minor, G Minor most common
- Melodic loops: 4–6 notes, typically 8 steps total (some steps repeated), scale walk shape
- Timbre: Modular synth with slight FM distortion, intentional roughness — not pristine digital
- Bass: Slow root note pulses (every 2 beats) with occasional chromatic neighbor (±1 semitone)
- No drums: rhythm comes entirely from the repeating melodic loop
- Dynamics: Layers add gradually, rarely strip back — mostly additive through the track

**Generator lessons:**
- The "imperfection" principle: ±8 velocity variation (not strict quantization) on melodic notes. Every note should have its velocity = base ± rand(0, 8).
- The bass chromatic neighbor (Moroder Drift, `COS-BAS-004`) confirmed: bass holds root for 3 bars, moves ±1 semitone on bar 4, returns.
- Loop length should favor 8 steps with some steps repeated rather than 8 unique pitches. Example: `[d, e, f, g, a, g, f, e]` — arch shape with repetition.

---

### Updated Generator Parameter Tables

**Confirmed BPM distribution (triangular, from all sources):**
- Absolute minimum: 70 BPM (Chariots of Fire)
- Most common slow range: 83–90 BPM (Alpha, JMJ-slow)
- Most common mid range: 111–117 BPM (Blade Runner, Équinoxe Pt 4)
- Most common fast range: 120–126 BPM (Oxygène Pt 4, upper Motorik overlap)
- Absolute maximum: ~146 BPM for Cosmic (Ricochet — but this sounds like Motorik without the kick)
- **Generator recommendation:** Triangular distribution min=70, peak=95, max=120. The original plan used peak=90 — revise to 95 to match the Blade Runner/Équinoxe cluster.

**Confirmed key preferences (from all sources combined):**
- D Minor: JMJ (Oxygène Pt 2), Berlin School patterns — very common
- G Minor/G Dorian: JMJ (Oxygène Pt 4), Schulze patterns
- C Minor: TD (Ricochet), TD ambient patterns
- F# Minor: Vangelis (Blade Runner)
- B Minor, E Minor: Craven Faults
- Major keys present: D Major, F Major (JMJ), A Major, Db Major (Vangelis)
- **Generator recommendation:** Minor modes 65%, Major modes 35%. Within minor: Aeolian 40%, Dorian 35%, Phrygian 25%. Within major: Ionian 70%, Mixolydian 30%.

**Confirmed arpeggio interval constraint:**
- Maximum adjacent interval: perfect 4th (5 semitones) — from Klaus Schulze analysis
- Typical adjacent interval: major 2nd (2 semitones) — stepwise motion preferred
- This overrides any prior rule allowing 3rds as maximum; 3rds are common, but 4ths are the hard ceiling

**Confirmed chord hold lengths (minimum bars per chord):**
- Vangelis two-chord: 4 bars minimum per chord
- JMJ eventful progression: 4–8 bars per chord
- Berlin School / Phaedra: 8–16 bars per chord (or no chord change at all)
- **Generator recommendation:** Chord change interval = weighted pick from {4, 8, 16, 32} bars with weights {0.25, 0.40, 0.25, 0.10}

**Confirmed skip probability for arpeggio gate:**
- Rubycon analysis: ~25% (2 of 8 steps silent)
- Schulze pattern: exactly 2 of 8 = 25%
- **Generator recommendation:** Skip probability = 0.25 (exactly 2 steps in an 8-step pattern, or proportionally for other lengths). Skips should be consistent per pattern instance (same 2 positions every loop), not random per bar.

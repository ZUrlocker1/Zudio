# Kosmic Style Generator — Research & Design Plan

## Context

Kosmic is Zudio's second generative style — inspired by Berlin School electronic music (Tangerine
Dream, Jean-Michel Jarre, Steve Roach, Craven Faults, Vangelis). This document covers the research,
generator design, and the implemented specification.

The style dial offers: **Motorik → Kosmic → Ambient**. The Ambient style is documented separately
in `docs/ambient-plan.md`.

---

## Part 1: Genre Research — What Is "Kosmic"?

### Definition

**Kosmische Musik** (German: "kosmic music") is 1970s West German electronic music rooted in synthesizers and sequencers, emphasizing themes of space and otherworldliness. It emerged from the experimental Zodiak Free Arts Lab in West Berlin. The genre is characterized by:

- **Ostinato step-sequences** (repeating melodic/harmonic patterns)
- **Modal improvisation** over static harmonic fields
- **Glacial structural development** — changes happen over minutes, not bars
- **Hypnotic, trance-inducing listening**
- **Timbre as primary narrative** — when harmony is static, synth tone color becomes the "melody"

**Critical distinction from Motorik:** Motorik (Neu!, Can) uses a steady 4/4 kick-drum groove as the forward propulsive engine; rhythm is primary. Kosmic/Kosmische uses sequencer patterns and harmonic drones as the engine; **rhythm is secondary or absent**. The energy is inward and spatial, not outward and propulsive.

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

**Generative Lesson:** For Kosmic in Zudio, a Roach-style section means nearly static harmony with multiple overlapping pad layers at different loop lengths (e.g., 16, 20, and 24 bars) producing constant variation from a minimal palette. No drum track needed.

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

**Generative Lesson:** Vangelis shows that Kosmic doesn't have to be static. The "cinematic" variant uses two-chord simplicity (like Blade Runner's F#m/D) but makes those two chords sound vast through voicing, filter attack, and performance variation. For Zudio, the Vangelis approach means choosing 2-chord sections and varying how those chords are voiced/attacked per bar rather than changing chords frequently.

---

## Part 3: Universal Kosmic Rules (What All Five Share)

These rules are **non-negotiable** for anything to sound Kosmic:

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
   - Mixolydian (major with flat 7th, open/suspended) — brighter kosmic sections
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

## Part 4: Kosmic vs. Motorik — The Generative Differences

- **Tempo:** Motorik = 126–154 BPM / Kosmic = 95–126 BPM
- **Rhythm anchor:** Motorik = kick drum 1+3, snare 2+4 / Kosmic = sequencer arpeggio or absent
- **Harmonic rhythm:** Motorik = change every 4–8 bars / Kosmic = change every 8–32 bars
- **Mode:** Motorik = Dorian, Aeolian, Mixolydian / Kosmic = Aeolian, Dorian, Phrygian, Mixolydian
- **Song structure:** Motorik = Intro/A/B/Outro with clear arcs / Kosmic = long evolving sections, glacial pacing
- **Lead melody:** Motorik = phrase-first, syncopated, rhythmic / Kosmic = long held notes, arpeggio-driven, sparse
- **Pads:** Motorik = chord stabs, backbeats / Kosmic = whole-bar sustains, slow swells
- **Bass:** Motorik = Motorik drive, 8th-note grooves / Kosmic = slow root movement, drone-like
- **Drums:** Motorik = full Motorik groove / Kosmic = absent or sparse pulse only
- **Energy model:** Motorik = propulsive, outward / Kosmic = immersive, inward
- **Variation unit:** Motorik = per-section (A/B) / Kosmic = per-layer-cycle (staggered)

---

## Part 5: Proposed Kosmic Generator Design

### 5.1 CosmicMusicalFrameGenerator

New `GlobalMusicalFrame` distributions for Kosmic:

**Tempo:** Triangular distribution, min=95, peak=120, max=126 BPM
- 120 BPM is the empirically confirmed peak (all four Electric Buddha Band reference songs run at 120). With 30% probability, apply a mid-song tempo lift of +4–8 BPM at a random bar in the range [totalBars × 0.45, totalBars × 0.65].

**Keys:** Different probability table (more minor/flat keys):
- Am/A (20%), Em/E (18%), Dm/D (15%), Gm/G (12%), Cm/C (10%), Fm/F (8%), Bm/B (7%), other (10%)

**Modes:** Weighted differently from Motorik:
- Aeolian 40% (darkest, most "kosmic")
- Dorian 30% (warm darkness — most JMJ-like)
- Phrygian 15% (mysterious, Vangelis-adjacent)
- Mixolydian 15% (brighter, open-sounding)

**Progression Families** (new set for Kosmic):
- `static_drone` 30% — single tonic for 16–32 bars, slight voice movement
- `two_chord_pendulum` 25% — two chords alternating every 8–16 bars (Vangelis F#m/D model)
- `modal_drift` 20% — slow stepwise movement through modal scale tones (i → bVII → bVI → bVII → i)
- `suspended_resolution` 15% — sus2/sus4 chords resolving to minor/major slowly
- `quartal_stack` 10% — quartal harmony (stacked fourths), atonal feeling, spaciest

**Song length:** Triangular distribution min=180s, peak=300s, max=420s

**PercussionStyle enum (canonical, for Types.swift):** `.absent` / `.sparse` / `.minimal`

---

### 5.2 CosmicStructureGenerator

**Song Forms:**
- `single_evolving` 50% — one long section that gradually mutates (Roach/TD model)
- `two_world` 35% — A section (spacious, static) → B section (denser, arpeggiated) → return
- `build_and_dissolve` 15% — builds from nothing, reaches peak density, dissolves back

**Section lengths:** 32–96 bars (much longer than Motorik's 16–48)

**Intro styles (Kosmic-specific):**
- `ambient_fade_in` — song starts at near-zero volume, slow 4-bar linear ramp, no pickup fill
- `texture_first` — pad/drone enters first (2 bars), then arpeggio joins on bar 3, bass on bar 5
- `sequencer_launch` — arpeggio starts immediately (no intro), pads enter bar 4 (JMJ style)

**Outro styles (Kosmic-specific):**
- `slow_dissolve` — layers drop out one at a time over 8 bars (opposite of build)
- `drone_hold` — all melodic content stops, pad/drone holds for 4 bars then fades
- `fade_to_silence` — master volume fade over 8–16 bars (ambient classic)

**Intensity model:** Instead of Motorik's low/medium/high per section, Kosmic uses a **density curve** — a smooth sine or ramp function over the whole song that controls how many layers are active at each bar.

---

### 5.3 CosmicArpeggioGenerator (new — central to the style)

This is the most important new generator. It replaces RhythmGenerator for Kosmic style.

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

**Extends/replaces PadsGenerator** for Kosmic style.

**New pad rules:**

**KOS-PAD-001: Long Drone** — whole notes held 2–4 bars, full chord voicing, very low velocity (40–55), filter LFO implied by velocity variation
- Duration: 32 or 64 steps (2 or 4 bars)
- Voicing: root + 5th + octave + (major or minor 3rd at octave up) = 4 voices

**KOS-PAD-002: Swell Chord** — starts silent, velocity ramps from 20→80 over the bar, then holds (Vangelis brass swell)
- Use multiple velocity-stepped events to simulate filter attack on MIDI sampler
- Duration: 16 steps with ramped velocity across sub-events

**KOS-PAD-003: Unsync Layers** — three pad voices at different loop lengths (8, 10, 12 bars) creating slowly shifting harmony from a single chord
- Voice 1: holds root chord for 8 bars
- Voice 2: holds same chord but different voicing for 10 bars
- Voice 3: holds inversion for 12 bars
- Their phase relationships shift over time = Roach-style organic variation

**KOS-PAD-004: Suspended Resolution** — sus4 chord resolves to minor every 4 bars (sus4 for 3 bars, minor for 1 bar) — creates gentle periodicity

**KOS-PAD-005: Quartal Stack** — stacked fourths (0, 5, 10 semitones) for atonal/spacious sections

**Voicing register:** MIDI 36–72 (lower than Motorik pads at 48–84) — creates spatial depth below the arpeggio

---

### 5.5 CosmicLeadGenerator

Lead melody in Kosmic is sparse and long-note-oriented. Not absent, but not rhythmically busy.

**New lead rules:**

**KOS-LD-001: Slow Arc** — 2–4 note phrase, each note held 4–8 beats, rising or falling by scale steps. One phrase per 4–8 bars. Feels like a solo improvisation over the arpeggio bed.

**KOS-LD-002: Floating Tones** — single notes, widely spaced (one every 2–4 bars), held until the next attack. Creates sense of vast space between events. Notes always on scale tones (no chromatic passing).

**KOS-LD-003: Pentatonic Drift** — slow movement through pentatonic scale (5 notes only), each step 2–4 bars. The pentatonic constraint prevents dissonance. Sounds like a Japanese koto or Mellotron flute.

**KOS-LD-004: Echo Melody** — a 4-note phrase (2 bars), followed by 2-bar silence, then the same phrase transposed up or down by a 3rd (question/answer). Repeats for the section. The classic Vangelis structural device.

**KOS-LD-005: Arpeggio Highlight** — picks one note from the underlying arpeggio pattern and holds it for a full bar. Changes which note it highlights every 4 bars. Ties melody to arpeggio without duplicating it.

**Register:** MIDI 60–96 (higher than Motorik leads, more "celestial")
**Velocity:** 45–72 (softer than Motorik — kosmic is never aggressive)

---

### 5.6 CosmicBassGenerator

Bass in Kosmic is more drone-like than the driving Motorik bass patterns.

**New bass rules:**

**KOS-BAS-001: Drone Root** — root note held for 2 bars (32 steps), releases, re-attacks. Velocity 65. The simplest possible bass — just marks the harmonic root.

**KOS-BAS-002: Root-Fifth Slow Walk** — root for 2 bars, fifth for 2 bars, back to root. Creates slow harmonic movement underneath static pads. 8 bars per cycle.

**KOS-BAS-003: Pedal Pulse** — root on every quarter note beat, short duration (4 steps), creates a subtle pulse without Motorik drive energy. Like a slow heartbeat.

**KOS-BAS-004: Moroder Drift** — Giorgio Moroder-inspired: root held for 3 bars, then chromatic neighbor note (one semitone up) on bar 4 before returning to root. Creates harmonic tension without changing chord.

**KOS-BAS-005: Absent Bass** (sparse sections only) — no bass events for 4–8 bar stretches, then KOS-BAS-001 re-enters. This is the Roach approach: bass as punctuation, not foundation.

**Register:** MIDI 28–52 (same as Motorik — low register is the same regardless of style)

---

### 5.7 CosmicDrumGenerator (or: No Drums)

The key design question: **does Kosmic have drums?**

Research finding: Pure Berlin School (TD Phaedra, Steve Roach) has **no drums**. JMJ uses a minimal rhythm machine (Korg Mini Pops). Craven Faults uses no conventional kit. Vangelis uses drums on some tracks (Heaven and Hell) but not on ambient pieces.

**Recommendation:** Make drums **optional per song**, controlled by a new `percussionStyle` field in `CosmicMusicalFrame`:

- `percussionStyle = .absent` (40%): No drum track at all. Sequencer/arpeggio creates the pulse.
- `percussionStyle = .sparse` (35%): Single hi-hat pulse on every quarter beat (or every 2 beats), no kick or snare. Very quiet (velocity 35–50).
- `percussionStyle = .minimal` (25%): Occasional kick (beat 1 only, every other bar) + hi-hat pulse. The "electronic rhythm machine" feel — JMJ Mini Pops style.

No full Motorik groove in Kosmic mode.

---

### 5.8 CosmicTextureGenerator

Texture in Kosmic is more prominent than in Motorik (it becomes a primary voice, not a background shimmer).

**New texture rules:**

**KOS-TEX-001: Orbital Motive** — a 3-note figure (root, 5th, octave) looping at a different length than the arpeggio (e.g., arpeggio = 8 steps, texture loop = 12 steps). Their phase relationship creates ever-changing rhythmic combinations. The Steve Roach "unsynchronized loops" approach.

**KOS-TEX-002: Shimmer Hold** — single note held very quietly (velocity 25–35) for 4+ bars. Contributes to harmonic fullness without drawing attention. Think: a sustained string note buried in reverb.

**KOS-TEX-003: Spatial Sweep** — slow glissando effect simulated by chromatic passing notes (velocity 20) between scale tones. One per 4 bars. Creates sense of filter sweep.

---

## Part 6: What Can Be Reused From Motorik Architecture

The Zudio generator architecture is well-suited to extension. All of these work as-is:

- `SeededRNG` — fully reusable, deterministic per-track seeds
- `MIDIEvent` struct — no changes needed
- `midiNote(key:degree:oct:)` — fully reusable
- `Mode.intervals` and `Mode.nearestInterval()` — reusable
- `ChordType.intervals` — reusable (quartal, power, sus2 all exist)
- `RegisterBounds` and `kRegisterBounds` — needs new entries for Kosmic tracks
- `TonalGovernanceBuilder` — fully reusable (works with any chord/mode combination)
- `DensitySimplifier` — reusable (density concept maps to Kosmic's layer counts)
- `ArrangementFilter` — reusable (post-processing is style-agnostic)
- `HarmonicFilter` — reusable (diatonic constraint works in any mode)
- `nearestMIDI(pc:bounds:prevNote:)` — fully reusable (voice leading is universal)
- `diatonicBelow/Above` helpers in LeadGenerator — reusable
- `buildArpNotes` in RhythmGenerator — reusable and extends to Kosmic arpeggio patterns
- `weightedPick` — universal
- `NotePoolBuilder` — reusable (pitch class sets work for any key/mode)

---

## Part 7: New Files Required

When implementation begins, create:

- `Sources/Zudio/Generation/Kosmic/CosmicMusicalFrameGenerator.swift` — tempo/key/mode/progression distributions
- `Sources/Zudio/Generation/Kosmic/CosmicStructureGenerator.swift` — song form, section lengths, intro/outro styles
- `Sources/Zudio/Generation/Kosmic/CosmicArpeggioGenerator.swift` — the core of the style; 4–8 note patterns, skip logic, phasing
- `Sources/Zudio/Generation/Kosmic/CosmicPadsGenerator.swift` — drone, swell, unsync-layer, sus/quartal rules
- `Sources/Zudio/Generation/Kosmic/CosmicLeadGenerator.swift` — sparse slow-arc, floating tones, echo melody
- `Sources/Zudio/Generation/Kosmic/CosmicBassGenerator.swift` — drone root, slow walk, pedal pulse
- `Sources/Zudio/Generation/Kosmic/CosmicDrumGenerator.swift` — absent/sparse/minimal percussion logic
- `Sources/Zudio/Generation/Kosmic/CosmicTextureGenerator.swift` — orbital motives, shimmer holds

**Modify:**
- `Sources/Zudio/Generation/SongGenerator.swift` — add `style: MusicStyle` parameter, branch to Kosmic generators
- `Sources/Zudio/Models/Types.swift` — add `MusicStyle` enum, new `PercussionStyle` enum, new progression families
- `Sources/Zudio/UI/TopBarView.swift` — add style dial (Motorik / Kosmic)
- `Sources/Zudio/UI/TrackRowView.swift` — Kosmic instrument presets for each track
- `Sources/Zudio/AppState.swift` — add `selectedStyle: MusicStyle` published property

---

## Part 8: UI — Style Dial

Replace the `Text("Style: Motorik")` static label in TopBarView with an interactive control.

**Design: Segmented picker (macOS `.segmented` style)**

```swift
Picker("Style", selection: $appState.selectedStyle) {
    Text("Motorik").tag(MusicStyle.motorik)
    Text("Kosmic").tag(MusicStyle.kosmic)
}
.pickerStyle(.segmented)
.frame(width: 140)
```

This is the cleanest macOS control for 2–3 choices. When Ambient is added, it becomes a 3-segment picker. No dial rotation needed — segmented control is instantly readable and matches macOS HIG.

**`MusicStyle` enum (add to Types.swift):**

```swift
enum MusicStyle: String, CaseIterable, Codable {
    case motorik = "Motorik"
    case kosmic  = "Kosmic"
    // case ambient = "Ambient"  // future
}
```

**Behavior:**
- Changing style takes effect on the next Generate (not the current song)
- The Generate button triggers regeneration using the selected style's generators
- Style selection persists across sessions (saved in AppState/UserDefaults)
- Track instrument presets change per style (Kosmic gets new instrument lists in TrackRowView)

---

## Part 9: Kosmic Instrument Presets (TrackRowView)

The existing GM program assignments will need a Kosmic variant per track:

- **Lead 1 (Kosmic):** Square Lead → Brightness (100), Vibraphone (11), Ocarina (79), Flute (73), Whistle (78) — lighter, more celestial than Motorik leads
- **Lead 2 (Kosmic):** Warm Pad (89), Halo Pad (94), New Age Pad (88) — pads acting as secondary melody
- **Pads (Kosmic):** Choir Aahs (52), String Ensemble (48), Synth Strings (50), Warm Pad (89), Space Voice (91)
- **Arpeggio/Rhythm (Kosmic):** Square Lead (80) for JMJ-style sequences, Vibraphone (11), Marimba (12), Kalimba (108)
- **Bass (Kosmic):** Moog Bass (39), Synth Bass 1 (38), Pad (89) at low register for drone effect
- **Drums (Kosmic):** Brush Kit (40) for sparse percussion, or absent

---

## Part 10: Open Questions (For Later Resolution)

1. **Tempo interaction with arpeggio speed:** At 90 BPM with 16th-note arpeggios, you get 6 notes/second — is that fast enough to feel "sequenced"? May need to allow tempo as low as 70 BPM for Roach-style sections.

2. **Delay timing:** The existing delay effect is a time-based effect on the audio output. For Kosmic, delay time should be calculated from BPM (e.g., quarter-note delay = 60/BPM seconds). This needs a BPM-aware effect setting, not just "on/off."

3. **Polyphonic arpeggio vs. monophonic:** JMJ arpeggios are monophonic (one note at a time). TD arpeggios are also monophonic. The existing arpeggio in RhythmGenerator is also monophonic. Good — no architecture change needed.

4. **Unsynchronized loop lengths (Steve Roach):** The current MIDI engine synchronizes all tracks to the same bar/step grid. Implementing truly unsynchronized loops would require fractional bar lengths or a separate loop-length concept per track. This may be complex — a simpler approximation is to use loop lengths that are co-prime (e.g., 8, 10, 12 bars per track), which creates long-period variation from simple patterns.

5. **Field recordings (Craven Faults):** Not feasible in MIDI. The "imperfection" principle can be approximated by adding ±5–10% velocity randomization and ±1 step timing jitter on some events.

6. **Microtonality:** Not feasible in standard MIDI. Skip for V1 of Kosmic.

7. **Continuous Play interaction:** Kosmic songs may need different transition rules — longer crossfades (6 bars instead of 4), and bass/pads may need to be "always copied" (not freshly generated) since stable drones are even more important in Kosmic than in Motorik.

---

## Part 11: Making It Sound Musical — The Core Rules

Drawing on all research, the key rules that prevent Kosmic from being "noise":

1. **Every note must be diatonic** (in the mode) — no random chromatic pitches
2. **The arpeggio pattern must be a recognizable shape** — not random note order; use one of the 5 interval vocabularies in §5.3
3. **Harmonic changes must be prepared** — change chord only on a bar boundary, and only to a chord that shares ≥4 pitch classes with the previous chord
4. **The bass must anticipate or confirm the chord** — bass moves to new root 1 step before or on the chord change bar
5. **Layers must not compete in the same register** — arpeggio (MIDI 60–84), pads (MIDI 36–72), lead (MIDI 72–96), bass (MIDI 28–52) must not overlap more than 4 semitones
6. **Velocity hierarchy:** Lead = 45–72, Arpeggio = 60–80, Pads = 35–60, Bass = 55–75, Texture = 20–45
7. **Silence is valid** — notes should not fill every step; rests ARE music in Kosmic style
8. **Skip logic creates the groove** — 1–2 skipped steps in an 8-step arpeggio pattern creates syncopation without complexity

---

## Part 12: Verification Criteria (When Implementation Begins)

1. Build: `xcodebuild -scheme Zudio -configuration Debug build`
2. Generate 10 Kosmic songs — all should be in 95–126 BPM range
3. All songs should have no full drum groove (only absent/sparse/minimal percussion)
4. Arpeggio track present in all songs, 4–8 note patterns diatonic to key
5. Harmonic changes should occur no more than once per 8 bars
6. Subjective test: does it sound like ambient/kosmische music? Would Tangerine Dream fan recognize the genre?
7. Style selector switches between Motorik and Kosmic — both styles generate correctly from the same Generate button
8. Test Mode (Cmd-T) works in Kosmic style — generates 1-minute songs for rapid audition

---

## Part 13: Song-Level Analysis & Derived Rules

This section provides concrete BPM, key, chord, and arpeggio data measured from specific recordings. These numbers directly inform the generator's probability tables and parameter bounds.

---

### Jean-Michel Jarre — Specific Song Analysis

**Oxygène Part 2**
- Tempo: ~87 BPM (feels like 173–174 at half-time/3/4 feel)
- Key: D Minor
- Time signature: 3/4 (unusual — most Kosmic is 4/4; this is an exception)
- Chord progression: Gm → Cm → Dm → F → Eb
- Generator lesson: Gm→Cm→Dm uses mostly 2nds and 4ths in bass movement — very smooth voice leading. The F→Eb at the end is the only chromatic step (whole tone down) and acts as the "surprise." Apply this: 4 diatonic chord changes, then 1 modal/chromatic pivot.

**Oxygène Part 4**
- Tempo: 126 BPM (coincides with the Motorik range — confirms BPM overlap at the upper end)
- Key: G Dorian
- Arpeggio shape: Root → 2nd → 3rd → 5th → 3rd → 2nd → Root (7 notes, the "scale walk" pattern from §5.3)
- Generator lesson: This is the canonical JMJ arpeggio. At 126 BPM with 8th notes = 4 notes/second. Confirms 8-step scale-walk as a top-priority arpeggio template.

**Équinoxe Part 4**
- Tempo: 115 BPM
- Key: F Major (unusually bright for JMJ — Ionian mode)
- Generator lesson: 115 BPM is the sweet spot for "fast Kosmic" — rhythmic but not propulsive. Confirms upper BPM bound at ~120 (above that it starts sounding Motorik).

**Magnetic Fields Part 2**
- Tempo: ~98 BPM (195 at double time)
- Key: G#/Ab Major → moves through C → G → Ab → Fm → G → Cm
- Generator lesson: This is JMJ at his most "eventful." Six distinct chords over a long section. Even here, each change shares 3–4 pitch classes with previous. Confirms: chord changes are allowed every 4 bars minimum, but must share 3+ pitch classes.

**Revised JMJ BPM range for generator:** 87–126 BPM (not 70–110 as previously estimated). The slow end is slower than expected; the fast end reaches Motorik territory.

---

### Tangerine Dream — Specific Song Analysis

**Phaedra (title track, 1974)**
- Tempo: ~166 BPM (sequencer pulse, no drums — feels much slower due to long note durations)
- Key: Ambiguous — oscillates between C Major and D Minor (modal interchange, no clear tonic)
- Arpeggio: Moog 960, 8 steps, each note a 16th at 166 BPM ≈ 2 notes/second
- Generator lesson: At 166 BPM with 16th-note arpeggios, pattern completes in ~1.2 seconds — very fast and hypnotic. The ambiguous key (neither pure C nor pure D) comes from using only the white-key MIDI notes (natural minor/major overlap). Implement as: pick root but use both Ionian and Aeolian notes from that root simultaneously (the "white key" set = C major = A minor overlapping).

**Rubycon Part 1**
- Tempo: (beatless — sequencer-driven)
- Key: Modal ambiguity; chromatic neighbor notes used for tension
- Generator lesson: The expansion from 4→12 notes/bar is the structural engine of the track. Implement as: `notesPerBar` starts at 4 in intro sections, increases by 2 every 16 bars in peak sections. This is the Kosmic equivalent of Motorik's intensity arc. Skip probability ≈ 25% (2 of 8 steps).

**Ricochet Part 1**
- Tempo: 146 BPM (faster than expected for Berlin School — confirms the upper range extends higher)
- Key: C Minor
- Generator lesson: At 146 BPM, Ricochet overlaps with Motorik entirely in tempo. The distinction is purely timbral and structural. Confirms tempo alone cannot distinguish Kosmic from Motorik — the absence of a kick-drum groove is the real marker.

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
- Generator lesson: The simplest possible harmonic structure — just IV→I. The complexity comes entirely from voicing and timbre. For Kosmic generator: `two_chord_pendulum` should default to I→IV or I→V (the most consonant relationships), not ii→V→I jazz logic.

**Tears in Rain (Blade Runner End Titles)**
- Tempo: 111 BPM
- Key: F# Minor
- Chords: F#m → D (i → bVI)
- Generator lesson: i → bVI is the definitive Vangelis two-chord. Also confirms extreme sparsity: a single note held for 4+ bars with silence around it is valid and intentional. For the lead generator, `KOS-LD-002: Floating Tones` with 4-bar holds is confirmed by this track.

**Pulstar (Albedo 0.39)**
- Tempo: 123 BPM
- Key: Db/Eb Major
- Generator lesson: 4-note arpeggio at 123 BPM with 8th notes = one complete pattern per 2 beats = extremely hypnotic at this tempo. Confirms 4-note as the minimum viable arpeggio length and most hypnotic setting. The almost-zero variation is intentional — in Kosmic, variation is the exception, not the rule.

**Alpha (Heaven and Hell)**
- Tempo: 83–84 BPM
- Key: A Major (Ionian — bright)
- Generator lesson: The intro build takes 32 bars to reach full density. This is 5× longer than a Motorik intro (typically 8 bars). Sets expectation for `texture_first` intro style: first instrument enters bar 1, second bar 4, third bar 8, fourth bar 16, fifth bar 32.

**Chariots of Fire**
- Tempo: 71 BPM (slowest confirmed tempo — sets the Kosmic floor)
- Key: Db Major
- Progression: I → IV → V (Db → Gb → Ab)
- Generator lesson: At 71 BPM, this is the slowest end of Kosmic. Confirms absolute minimum BPM = 70 (previously estimated, now confirmed). Four-bar chord holds at 71 BPM = ~13.5 seconds per chord — extremely spacious.

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
- The bass chromatic neighbor (Moroder Drift, `KOS-BAS-004`) confirmed: bass holds root for 3 bars, moves ±1 semitone on bar 4, returns.
- Loop length should favor 8 steps with some steps repeated rather than 8 unique pitches. Example: `[d, e, f, g, a, g, f, e]` — arch shape with repetition.

---

### Updated Generator Parameter Tables

**Confirmed BPM distribution (triangular, from all sources):**
- Absolute minimum: 70 BPM (Chariots of Fire)
- Most common slow range: 83–90 BPM (Alpha, JMJ-slow)
- Most common mid range: 111–117 BPM (Blade Runner, Équinoxe Pt 4)
- Most common fast range: 120–126 BPM (Oxygène Pt 4, upper Motorik overlap)
- Absolute maximum: ~146 BPM for Kosmic (Ricochet — but this sounds like Motorik without the kick)
- **Generator recommendation:** Triangular distribution min=95, peak=120, max=126. The corpus is clearly centred on 120.

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

---

## Part 14: Mister Mosca MIDI Analysis — Electric Buddha Band

**Source file:** `docs/Mister Mosca MIDI.mid`
**Format:** Type 1 MIDI, 48 tracks, 480 ticks/beat

### Song Parameters (Confirmed)

- **BPM: 120** — higher than the 70–110 range estimated from Berlin School research. Confirms that Kosmic can and does run at 120 BPM. Kosmic BPM ceiling revised from 120 → 126.
- **Key: G Dorian** — confirmed by B natural appearing in the bass line (B natural = major 6th of G = the defining Dorian characteristic). Core scale tones: G, A, Bb, C, D, F.
- **Song length: ~105 bars at 4/4**

### Track Roles (summary)

- **Lead / Sequencer (Tracks 1–14):** G3–A4, 16th-note grid, G Dorian. Multiple tracks = timbre-swap technique across sections (same MIDI data, different instrument programs).
- **Synth Drums (Tracks 3, 13, 23):** Pitched synth on channel 0, not GM channel 9. Two pitches only: D3 (fifth) and G2 (root). ~27 note events across 224 beats — one note every ~8 beats.
- **Bass — Electric (Tracks 19, 21):** G2–D3, G Dorian tones only. Velocity 95–100. Duration avg ~270 ticks (between 8th and quarter note).
- **Bass — Synth (Tracks 22, 24):** Identical pitch content to Liverpool Bass. Velocity 100 flat on every note — zero variation. Timbre-swap of bass track between sections.
- **Wurlitzer / Chords (Tracks 15, 17):** C4–A#5. Long held chord tones avg 1563 ticks (3.26 beats). Velocity 7–71, starts nearly inaudible, swells to moderate. Bb major voicing (bIII of G Dorian).
- **Bluebird arpeggiator (Tracks 25–47):** A1–B3, quarter-note durations, velocity 7–103 with many ghost notes. Secondary arpeggio layer in lower register — maps to Texture track.

---

**KOS-RULE-01: BPM ceiling raised to 126**
Mister Mosca runs at exactly 120 BPM and sounds definitively Kosmic, not Motorik. The Kosmic BPM upper bound should be raised from 110 to 126 BPM. This overlaps with the slowest Motorik tempos (Motorik min = 126), confirming the boundary is stylistic (presence/absence of kick groove), not purely tempo-based.

**KOS-RULE-02: G Dorian confirmed as primary key center**
The song is G Dorian. The bass line uses B natural (not Bb), confirming Dorian mode specifically over Aeolian. For the generator, Dorian should be the highest-weight mode: Dorian 40%, Aeolian 30%, Mixolydian 20%, Ionian 10% (revised upward for Dorian).

**KOS-RULE-03: Lead sequencer note durations**
Average note duration = 108 ticks at 480 tpb = **exactly 16th note** (120 ticks) with some shorter. Maximum = 240 ticks = 8th note. The lead arpeggio fires at 16th note speed with occasional 8th note holds — confirming the Berlin School 16th-note sequencer model from Part 2. No notes shorter than a 32nd note (32 ticks).

**KOS-RULE-04: Low anchor note in sequencer**
The lead sequencer mixes a very low D2 (MIDI 38 — the fifth degree, 2+ octaves below the melodic range of G3–A4) as a punctuation note between melodic phrases. This appears roughly every 3–5 melodic notes. It acts like a bass guitar accent within the lead part — grounding the sequence without being the bass track. Generator rule: with 20% probability per 4-step window in the arpeggio, insert one note at `root - 5th - 2 octaves` at velocity ≤ 55.

**KOS-RULE-05: Squelchy bass uses velocity = 100 flat**
The synth bass has zero velocity variation — every note is exactly 100. This contrasts with the electric bass (95–100, slightly variable). For KOS-BAS rules: when `bassStyle == .droneRoot` or any synth bass, set velocity = 100 ± 0 (no random variation). This is intentional, not a MIDI default.

**KOS-RULE-06: Bass pitch set is narrow — 5 notes over one octave**
Bass uses only: G2, A2, B2, C3, D3 — a perfect one-octave Dorian scale fragment from root to fifth, plus the Dorian 6th (B natural) and minor 7th (F is absent from bass). Register is MIDI 43–50 — compressed into one octave. No octave jumps. Generator rule: Kosmic bass stays within a 7-semitone range (root to fifth only, plus scale tones within that span). No bass notes below MIDI 40 or above MIDI 55.

**KOS-RULE-07: Chord track uses bIII voicing held 3+ beats**
Wurlitzer plays Bb major chord (bIII of G Dorian) sustained for 3.26 beats average. Voicing: C4–G4–A#4–F5 ascending spread (root of bIII → 5th → 3rd+octave → 5th+octave). Velocity starts at 7 (nearly inaudible) and rises through the chord's duration. Generator rule for KOS-PAD / Wurlitzer chord track: hold bIII or bVII chord for 2–4 beats; use velocity ramp 15→65 over the duration; spread voicing across 2 octaves.

**KOS-RULE-08: Synth drums on root and fifth — not GM pitches**
The drum pattern uses only two pitches: G (root) and D (fifth). These are on channel 0, not channel 9. This means Kosmic drums are better implemented as a **pitched percussion instrument** (marimba, vibraphone, or synth pluck) playing the tonic and dominant, not as a traditional GM drum kit. Generator rule: `CosmicDrumGenerator` should emit notes at `keySemitone + 0` (root) and `keySemitone + 7` (fifth) in octave 3, velocity 60–100, at sparse intervals (one event every 4–8 beats).

**KOS-RULE-09: Timbre variation via duplicate MIDI data, not note variation**
Liverpool Bass and Squelchy Bass carry identical pitch and rhythm data — only the instrument program differs. Same for the multiple "Smooth Lead Synth" tracks. This is the Electric Buddha approach to section variation: swap the instrument, keep the notes. In Zudio, this is already achievable by assigning the same `trackEvents` to two tracks with different GM programs. For Kosmic, when generating section structure, consider designating one section as "bass timbre A" and another as "bass timbre B" with identical note data.

**KOS-RULE-10: Melodic range G3–A4 = 14 semitones**
The lead sequencer's melodic content spans exactly G3 (MIDI 55) to A4 (MIDI 69) — one octave plus a major second. This is the **canonical Kosmic lead register**. Notes do not go below G3 (except the D2 anchor, which is a punctuation device, not part of the melodic stream). Generator rule: Kosmic lead register = MIDI 55–72 (G3–C5), which is tighter than the previously estimated 60–84.

**KOS-RULE-11: Bluebird arpeggiator — secondary layer in lower register**
A second arpeggiated voice runs in A1–B3 (MIDI 33–59), well below the lead sequencer. Quarter-note durations (not 16th notes), moderate velocity. This is the `CosmicTextureGenerator`'s orbital motive at work in practice: a lower-register arpeggio with a different rhythm than the main lead, creating the polyrhythmic phase effect. Register separation is critical — the texture arpeggio must stay below the lead arpeggio with no pitch overlap.

**KOS-RULE-12: Velocity hierarchy confirmed**
- Synth bass: 100 (highest — bass is the anchor)
- Electric bass: 95–100
- Lead/sequencer: 48–100, avg 59 (moderate)
- Wurlitzer chords: 7–71, avg 44 (soft — pads/chords are background)
- Bluebird texture: 7–103, avg ~52 (ghost notes at very low velocity mix with moderate notes)
- Synth drums: very sparse, velocity 17–100

Final hierarchy for generator: **Bass (100) > Lead (55–75) > Texture arpeggio (35–60) > Chord pads (20–55) > Synth drums (40–70)**

---

## Part 15: MIDI Analysis — Time Loops & Dark Sun (Electric Buddha Band)

Two additional Kosmic-style songs analyzed. Combined with Part 14, these three songs form a solid empirical foundation for the generator rules.

### Time Loops

- **BPM:** 120, stable throughout
- **Length:** ~61 bars, ~122 seconds
- **Key / Harmony:** Bimodal — C and F# are nearly equal in note count. Tritone pairing creating "suspended kosmic" tension. D is the third most common pitch, suggesting D Dorian with both C (♭VII) and F# (major 3rd) as simultaneous poles.

Key musical findings:
- 7 parallel "Luminous Tines" arpeggio layers all playing the same 5-note pitch set (D5/A5/A#5/C6/D6) at fixed velocity 100 with slightly different timing per layer — shimmering pad texture from 5 pitches
- Mid-bass (24 tracks): D3–A#3, velocity avg 92–94, duration 1.16–1.33 beats (sustained harmonic glue)
- Sub-bass: C2–C3, velocity 42–100, duration 0.27–1.0 beats (staccato anchor hits every 2–3 bars)
- Drums: full Motorik pattern — 532 notes, 16th-note grid, C2–E3, velocity avg 85

### Dark Sun

- **BPM:** 120 at start → **128 BPM mid-song** (tempo lift at bar ~64 of 126)
- **Length:** ~126 bars, ~253 seconds
- **Key / Harmony:** D major with F#–C tritone (same tritone pairing as Time Loops transposed). Heavy C presence suggests ♭VII Mixolydian coloration.

Key musical findings:
- Lead ("70s Analog Synth Lead"): 91 notes over 253 seconds (0.36 notes/second), pitch range C#3–B4, velocity 10–87 avg 57 — extremely sparse, widest dynamic range
- Dual bass: sustained drone (D3–G3, 4.5+ beats, vel 60–67) + rhythmic "Eighties Bass" (C3–G#3, 0.6–1.6 beats, vel 92–93)
- "Cloud Shimmer" pads: D3–D4, duration avg 7+ beats, velocity 21–69 — fade-in envelopes (minimum vel=1 rising)
- Same 532-note Motorik drum structure as Time Loops

---

**KOS-RULE-13: 120 BPM is the Kosmic baseline; optional mid-song tempo lift**
All three songs are at 120 BPM. Dark Sun demonstrates a 120→128 BPM lift (~6.7% increase) at approximately the halfway point. This lift energises the second half without disrupting the hypnotic feel. Generator rule: Kosmic BPM distribution should peak at 120 (triangular min=95, peak=120, max=126). With 30% probability, apply a tempo lift of 4–8 BPM at a random bar in the range [totalBars * 0.45, totalBars * 0.65]. The prior ceiling of 126 from Mister Mosca analysis stands.

**KOS-RULE-14: Tritone bimodal harmonic center**
Both Time Loops (C + F#) and Dark Sun (D + F# + C, F#-C being a tritone) show two pitch classes a tritone apart as the most common notes. Mister Mosca is G Dorian where the bVII (F) and III (B) create similar tension. This tritone pairing is the Kosmic harmonic signature — it creates suspended, unresolved tension. Generator rule: after picking the key root, designate a "shadow root" at `root + 6 semitones` (tritone). Both the root and its tritone should each account for ~20–25% of all notes across all tracks. This creates the characteristic "kosmic float" with no strong tonal resolution.

**KOS-RULE-15: Parallel arpeggio layers with identical pitch set**
Time Loops uses 7 parallel "Luminous Tines" tracks all playing the same 5-note pitch set (D5/A5/A#5/C6/D6) at fixed velocity 100 with slightly different timing per layer. Dark Sun uses 10 "Classic Funk Boogie Bass Arp" tracks on the same pitch set. This parallel layering from a single constrained pitch set is the primary texture generation strategy. Generator rule: the `CosmicArpeggioGenerator` should output 3–7 parallel voices from the same 5-note modal subset of the key (root, 3rd, 5th, ♭7th, octave or equivalent pentatonic subset). Each voice gets a small timing offset (0–48 ticks = 0–1/10th of a beat jitter) and an independently randomised note ordering within the set. Fixed velocity 95–100 (no expression in arpeggio layers — expression lives in the lead only).

**KOS-RULE-16: Cloud shimmer — high-register sustained pad with fade-in envelope**
Dark Sun's "Cloud Shimmer" tracks hold notes for 7+ beats at velocity 21–69 in D3–D4 range. Time Loops has a similar upper-register sustained layer at D5–D6. The minimum velocity as low as 1 (Dark Sun synth chords) and 21 (shimmer) indicates these notes fade in via MIDI velocity ramp rather than having a full-on attack. Generator rule: `CosmicPadsGenerator` should include a shimmer layer — 1–3 notes from the key's upper register (root octave + 2 or +3), held for 4–8 beats, velocity ramped from 15 to 55 over the note's duration (simulate with a velocity curve: first few ticks at 15, later events at 55, or simply set note velocity to a mid-range value and mark it as a "shimmer note" for the playback engine to envelope). Duration avg target: 6 beats.

**KOS-RULE-17: Dual bass — drone sustain layer + rhythmic punch layer**
Confirmed across all three songs:
- Sustained harmonic bass: D3–G3 range, 4–5 beat duration, velocity 60–67 (Dark Sun); D3–A#3, 1.3 beats, vel 92 (Time Loops); G2–D3, 1.2 beats, vel 100 (Mister Mosca)
- Rhythmic staccato bass: C3–G#3, 0.6–1.6 beats, vel 92–93 (Dark Sun); C2–C3 sub-bass hits, 0.27–1.0 beats (Time Loops)

Generator rule: `CosmicBassGenerator` outputs two sub-layers. Sub-layer A: long harmonic anchor notes on root and ♭VII, held 2–4 beats, velocity 60–70, note changes every 4 bars aligned to harmonic progression. Sub-layer B: staccato rhythmic movement within a one-octave span above the root, velocity 90–95, notes at 0.5–1.5 beat durations, providing rhythmic energy without leaving the root area.

**KOS-RULE-18: Two valid drum approaches — dense Motorik grid OR sparse pitched percussion**
Time Loops and Dark Sun both use a full Motorik drum track (532 notes, 0.25-beat 16th-note grid, C2–E3 range, velocity avg 85). Mister Mosca uses sparse pitched percussion on root+fifth only (KOS-RULE-08). Both are legitimate Kosmic drum strategies. Generator rule: `CosmicDrumGenerator` should randomly choose between two modes:
- **Motorik mode** (60% probability): emit a full 16th-note grid drum pattern similar to the Motorik generator, but lighter — use primarily hi-hat, a kick on beats 1 and 3, a snare on 2 and 4, velocity avg 85 ± 8. This gives the track rhythmic energy.
- **Sparse pitched mode** (40% probability): emit root and fifth pitched hits at sparse intervals (one every 4–8 beats) as in Mister Mosca. This gives more open, drifting feel.
The mood can guide which: Dream/Deep moods favour sparse pitched mode; Bright/Free moods favour Motorik mode.

**KOS-RULE-19: Velocity zone stratification — three tiers**
Confirmed across all three songs, a consistent three-tier velocity structure:

- **Rhythmic tier** (drums, staccato bass, electric piano hits): velocity 80–100, narrow range. These are the forward-driving elements; they must cut through.
- **Harmonic tier** (arpeggios, active bass lines, lead melody): velocity 50–80, moderate expression. The arpeggio layers are fixed near top of this range (95–100); the lead uses the full range expressively.
- **Atmospheric tier** (pads, shimmer, drone bass, ghost percussion): velocity 1–65, wide range with fade-in envelopes. These are background wash; they must never compete with the rhythmic or harmonic tiers.

Generator rule: when assigning velocities, check which tier each note belongs to and clamp accordingly. Never let a pad note exceed 70. Never let a drum hit fall below 70. Lead notes use the full 20–87 range with intentional phrasing (higher velocity on phrase peaks).

These findings have been incorporated into the Part 5.1 parameter tables above.

---

## Part 16: MIDI Analysis — Cagliari Drop (Electric Buddha Band)

Fourth Kosmic-style song analyzed. BPM: 93 (constant), Key: D Mixolydian, ~68 bars (~175 seconds).

### Hi-Hat Velocity Swing Pattern

Track 39's 16th-note hi-hat grid with alternating ghost/accent pattern (the key finding for drum realism):

- Beat 0.0: C2 kick — velocity 100
- Beat 0.25: F#2 hat — velocity 48
- Beat 0.5: F#2 hat — velocity 82
- Beat 0.75: F#2 hat — velocity 48
- Beat 1.0: D2 snare — velocity 96
- Beat 1.25: F#2 hat — velocity 87
- Beat 1.5: F#2 hat — velocity 19
- Beat 1.75: F#2 hat — velocity 47

Pattern: ghost hits (velocity 19–48) alternate with accented hits (velocity 82–96) on the 16th grid — standard jazz/funk hi-hat technique applied to an electronic context. Not the robotic equal-velocity grid of Time Loops/Dark Sun.

### Pulsating Tremolo Technique

Track 11 ("Pulsating Pad bass"): 445 notes at velocity range 7–127, avg 87, duration avg 0.32 beats (rapid staccato). Velocities alternate between near-silent (7–20) and full (80–127) on rapid notes — a MIDI tremolo simulation encoding the LFO amplitude effect of a synthesizer tremolo as velocity changes. This is a classic Kosmic technique captured in MIDI.

---

**KOS-RULE-20: BPM distribution revised — 93 BPM is valid Kosmic territory**
With Cagliari Drop at 93 BPM alongside three songs at 120 BPM, the distribution must be bimodal or use a wider triangular spread. Revised generator rule: use two possible BPM modes selected randomly at generation time:
- **Mode A (70% weight):** triangular min=115, peak=120, max=126 — the "driving" Kosmic feel (Time Loops, Dark Sun, Mister Mosca)
- **Mode B (30% weight):** triangular min=88, peak=95, max=105 — the "contemplative" Kosmic feel (Cagliari Drop style)

Optional mid-song tempo lift (KOS-RULE-13, +4–8 BPM) applies only to Mode A; Mode B stays constant.

**KOS-RULE-21: Decomposed drum tracks — separate voice streams**
Cagliari Drop demonstrates that drums can be decomposed into independent streams, each with its own velocity and density profile, rather than merged into one track. This is architecturally important for the generator: `CosmicDrumGenerator` should produce separate note streams per voice:
- **Kick stream:** beat positions on 1 and 3 (with occasional syncopated early hit on "and-of-4"), velocity 95–105
- **Hi-hat stream:** 16th-note grid, velocity alternating ghost (20–50) / accent (75–95) in pattern: ghost, accent, ghost, ghost repeating with ±15 velocity variation per hit
- **Snare stream:** primarily on beat 2 and 4, but with 25% probability shifted one 16th early or late for syncopation, velocity 85–100
- **Crash stream:** placed at section start points (bar 1, major section boundary bars), velocity 65–80 for texture; velocity 100–120 for dramatic emphasis at climax

These four streams can be merged into one track in the MIDI output or kept as separate tracks (Zudio currently uses 7 tracks — assign one to drums and pack all four streams into it).

**KOS-RULE-22: Hi-hat velocity swing — ghost/accent alternation**
The hi-hat runs a 16th-note grid but every other hit is a ghost note. Concrete pattern: `[accent, ghost, accent, ghost]` per beat, where accent = velocity 75–95 and ghost = velocity 20–50. Vary each value by ±8 randomly. This creates the subtle human feel of a hi-hat played with alternating wrist/finger strokes. Do not use equal velocity across all hi-hat hits — equal velocity sounds robotic in a way that other equal-velocity parts (arpeggios, bass) do not, because the ear is acutely sensitive to hi-hat patterns.

**KOS-RULE-23: Pulsating bass tremolo — extreme velocity oscillation on rapid notes**
For a "pulsating" bass effect, generate staccato notes at 0.25–0.35 beat intervals and oscillate velocity between a low value (10–30) and a high value (80–120) on alternating notes. This MIDI-encodes the synthesizer tremolo/AM effect without requiring actual synthesis. The overall effect is a shimmering, rhythmically trembling bass. Apply this to one designated bass sub-layer in the Kosmic generator (the other sub-layers use normal dynamics per KOS-RULE-17). Probability of including this pulsating layer: 50%.

**KOS-RULE-24: Dual lead interval style — wide-impressionistic vs tight-melodic**
Each generated Kosmic song should commit to one of two lead interval profiles at generation time:
- **Wide / impressionistic** (40% probability): avg interval 10–14 semitones; pitch range spans 2–3 octaves; duration avg 0.8–1.2 beats; feels like a landscape painting — big shapes, few notes. Use with Dream or Deep mood.
- **Tight / melodic** (60% probability): avg interval 2–5 semitones; pitch range 1–1.5 octaves; duration avg 0.5–0.8 beats; feels like a sung phrase. Use with Bright or Free mood.

These map loosely to the interval profiles from Mister Mosca (16th-note tight sequencer = tight/melodic) and Cagliari Drop Track 1 (wide/impressionistic).

**KOS-RULE-25: Restraint principle — sparse high-velocity stabs at section boundaries**
Cagliari Drop's bridge tracks (Tracks 47–57) use only 2–8 notes each over the entire song, placed at section transition points, with high velocity (70–100) and long duration (1–3 beats). These are **impact markers**: a single stab that signals a new section without any melodic content. Generator rule: at each major section boundary (defined as the chord progression reset point), 40% probability of emitting one impact stab note on the tonic or ♭VII, velocity 90–110, duration 1.5–2.5 beats, in the mid-low register (MIDI 40–55). This gives the song a sense of structural punctuation without adding a dedicated "stab" instrument.

---

### Updated Summary Across All Four Songs

Four Electric Buddha Band Kosmic songs now analyzed. Combined picture:

**BPM:** 93 (Cagliari Drop), 120 (Mister Mosca, Time Loops, Dark Sun, + Dark Sun lift to 128). Two BPM territories confirmed.

**Keys used:** G Dorian (Mister Mosca), C + F# bimodal (Time Loops), D Mixolydian (Dark Sun, Cagliari Drop). The F#–C tritone pairing appears in three of four songs.

**Drum styles:** Sparse pitched root+fifth (Mister Mosca) / Full Motorik 532-note unified track (Time Loops, Dark Sun) / Decomposed multi-track with velocity swing (Cagliari Drop). All three are valid. KOS-RULE-18 updated: add "Decomposed" as a third mode (equal weight with Motorik and Sparse).

**Bass approaches:** Single-register squelchy flat velocity (Mister Mosca) / Dual mid+sub-bass (Time Loops) / Sustained drone + rhythmic Eighties Bass (Dark Sun) / Pulsating tremolo + layered disco bass (Cagliari Drop). Consistent theme: always at least two simultaneous bass layers with different density/velocity profiles.

**Lead approach:** 16th-note tight sequencer (Mister Mosca) / None identified as distinct (Time Loops) / "70s Analog" sparse expressive (Dark Sun) / Dual "Freely" tracks wide and tight (Cagliari Drop). Consistent: sparse note count relative to other tracks, moderate velocity, phrasing varies by style.

---

## Detailed Implementation

Reference artists: Jean-Michel Jarre, Tangerine Dream, Vangelis, Klaus Schulze, Loscil, Craven
Faults, Electric Buddha Band.

### Style philosophy

Berlin School / TD / JMJ aesthetic. Long-form, slowly evolving, atmospheric. Minimal or absent
percussion. Bass drones build from near-silence. Sequencer arpeggios spin up gradually. Pad swells
fill harmonic space. Songs feel like they are arriving from a great distance and receding back.

### Track roles

- Bass — holds root or fifth as drone; may have additive layer for movement or pulse
- Pads — slow-moving 2-bar held chord voicings; primary harmonic atmosphere
- Texture — atmospheric shimmer; present but nearly subliminal
- Arpeggio (Rhythm track) — sequencer pattern; the kinetic element; enters late in intro, exits early in outro
- Lead — sparse melodic line over the arpeggio pulse
- Drums — sparse or absent; never a driving backbeat

### Song forms

- `single_evolving` (30%) — A section only; no B section; evolution driven by bar-count thresholds
- `ab` (20%) — A section followed by B section
- `aba` (25%) — A section, B section, return to A
- `abab` (15%) — two full A/B cycles
- `abba` (10%) — A, double B in the middle, return to A (B2 uses same mode as B1)

A sections always use song's primary mode (Dorian). B sections shift: Aeolian 45%, Mixolydian 35%,
Aeolian again 20%.

Section proportions of total body bars:
- `ab`: A=60%, B=40%
- `aba`: A1=35%, B=30%, A2=35%
- `abab` / `abba`: each segment 25%
- Minimum: each B ≥16 bars, each A ≥24 bars

Bridge eligible in `ab` and `aba` forms only (35% of eligible songs). `abab` and `abba` ineligible.

Chord changes every 8–32 bars via five progression families:
- `static_drone` — one chord held for entire song
- `two_chord_pendulum` — two alternating chords every 8–16 bars
- `modal_drift` — slow stepwise movement through mode degrees
- `suspended_resolution` — sus chords slowly resolving
- `quartal_stack` — stacked fourths

### Global profile

- Tempo: 95–126 BPM (triangular distribution, peak 120); two BPM modes:
  - Mode A (70%): min=115, peak=120, max=126 — driving Kosmic feel
  - Mode B (30%): min=88, peak=95, max=105 — contemplative Kosmic feel
- Mid-song tempo lift of +4–8 BPM applies to Mode A only (30% chance)
- Mood: Deep/Dream favour sparse pitched drums; Bright/Free favour Motorik-mode drums
- Primary mode: Dorian 40%, Aeolian 30%, Mixolydian 20%, Ionian 10%

### Intro and outro behavior

**Intro (4–8 bars) builds from near-silence:**
- Bass enters first as barely audible drone, growing gradually louder
- Pads swell across 2-bar held notes, velocity climbing from dim to present
- Texture shimmer appears only in second half of intro
- Arpeggio spins up only in final 2 bars of intro, at reduced velocity

**Outro mirrors the arc:**
- Arpeggio winds down after first 2 bars of outro
- Pads decay across 2-bar holds, fading to near-silence
- Bass drone decays gradually to end
- Texture shimmer present only in first half of outro

**Cold start drum fill (3 variants, selected randomly):**
- No kick in fill; no notes on step 15 (leaves clean gap for bar 1 downbeat)
- v0 Hat Crescendo: 16th closed hats steps 4–13 building velocity, single snare step 14
- v1 Bonham Launch: hat prefix beat 2 (steps 4–7), tom cascade beat 3 (steps 8–13), snare step 14
- v2 Crescendo Roll: ghost snare roll steps 4–14 with exponential velocity curve (18→105)
- drumsOnly variant starts pickup at step 8 (2-beat); bass+drums starts at step 4 (3-beat)

### B section behavior

**Section-driven evolution rules:**
- KOS-RTHM-006 (Kraftwerk Locked Pulse): octave-displaced arpeggio active throughout entire B
  section; base pattern in A sections. In `single_evolving`, octave version fires at bar 32+ on
  32-bar windows.
- KOS-TEXT-001 (Orbital Motive): shimmer lift active throughout B section; inactive in A sections.
  In `single_evolving`, fires at bar 24+ on 24-bar windows.
- KOS-BASS-003 (Pedal Pulse): harmonic enrichment active in B section; bar-count fallback in
  `single_evolving`.

**B section entry techniques:**
- Technique C — Extended pad hold (50% chance): pads sustain a chord 8–12 bars at slightly
  elevated velocity (Dark Sun-style swell beneath other instruments)
- Technique D — New lead rule (60% chance): lead picks rule not used in A section (creates
  "instrument arriving" effect)

Arpeggio pitch arch: each A and B section has its own independent rise-and-fall, scoped to that
section's bar range.

Drum transition fills fire on bar immediately before every body section label change. Three
variants: hat strip, snare build, or tom cascade.

### Bridge archetypes

A bridge is inserted between the last A section and first B section in eligible forms (35% of ab
and aba songs). Two archetypes chosen with equal probability.

**Bridge density rule:** bridges must be less dense than the surrounding A section. Short bridges
(A-1 and A-2): max 3 instruments active. Melody bridge: max 4. Rhythm/Arpeggio, Texture, and Lead
2 are silent in all bridge sections.

**Archetype A — Drum Bridge** (4 or 8 bars; 4 bars 70%, 8 bars 30%): two sub-variants equal probability.

- A-1 Escalating Drum Bridge (Mister Mosca style): drums are the primary voice. Bass doubles kick
  on beat 1 with root note only (staccato). Pads hold a single chord at low velocity for full
  bridge. Drums escalate bar by bar: kick only → kick+snare+floor tom → kick+snare+tom cascade →
  full 5-drum climax hit (kick+snare+floor+rack+crash) launching into the B section.

- A-2 Sparse Hit + Call-and-Response Bridge (Caligari Drop style): synchronized drum+bass+pad hit
  fires on beat 1 of every 2nd bar; between hits, bass plays a 2–3 note walking figure while
  everything else is silent. The contrast between the 3-instrument hit and the 1-instrument
  response IS the bridge. Silence between hits is essential.

**Archetype B — Melody Bridge** (16 or 24 bars; 16 bars 60%, 24 bars 40%): lead melody drives
the section. Bass doubles the lead melody's pitch class one octave lower (not root-only — it
follows the lead's pitches). Pads hold a single tonic chord quietly for full bridge. Drums: kick
beat 1 + snare beats 2 and 4 only. Lead phrase stated and then repeated exactly.

Optional ramp sections flanking Archetype B:
- preRamp (6–8 bars before bridge): KOS-TEXT-002 shimmer hold applies; drums add transition fill
  on final ramp bar; all other generators continue normal A section behavior
- postRamp (6–8 bars after bridge, before A returns): KOS-TEXT-003 spatial sweep applies; drums
  add fills on final two ramp bars (consecutive fills signal urgency); others return to A patterns

### Drum rules (KOS-DRUM)

- KOS-DRUM-001 — Minimal: kick beat 1 every other bar; quarter-note hi-hat with ghost/accent
  alternation (JMJ Mini Pops style)
- KOS-DRUM-002 — Basic Channel minimal dub: pitched floor tom hits every 4–8 beats on root and
  fifth pitch classes
- KOS-DRUM-003 — Absent: no percussion (Berlin School orchestral mode)
- KOS-DRUM-004 — Electric Buddha Groove: 8th-note hi-hat (not 16th), 5 kick/snare pattern
  variants rotating every 4 bars. Cold start (drums-only pickup) 60% of time. Tempo ≥100 BPM only.
- KOS-DRUM-005 — Electric Buddha Pulse: quarter-note hi-hat; kick beat 1 + beat 3 added 45%;
  snare half-time (beat 3 only) 65%, full rock (beats 2+4) 35%. Tempo ≥100 BPM only.
- KOS-DRUM-006 — Electric Buddha Restrained: lower-velocity hi-hat with occasional omissions;
  kick beat 1 only; snare half-time with ghost touches. Bridges gap between Sparse and Groove.
  Tempo ≥100 BPM only.
- KOS-DRUM-FILL — Transition fill: fires on bar before every body section label change. Three
  variants: hat strip, snare build, tom cascade.

Kits (GM program on channel 10): Brush Kit 40 (default), 808 Kit 25, Machine Kit 24, Standard Kit 0.

### Arpeggio/rhythm patterns (KOS-RTHM)

One base pattern selected per song; evolves in B sections.

- KOS-RTHM-001 — TD Sequencer: repeating 8-step pattern over one octave (Tangerine Dream style)
- KOS-RTHM-002 — JMJ Hook: distinctive 6-step melodic hook (Jean-Michel Jarre style)
- KOS-RTHM-003 — Oxygène: three-voice layered ascending/descending figures
- KOS-RTHM-004 — Electric Buddha: syncopated 16-step pattern with rhythmic displacement
- KOS-RTHM-006 — Kraftwerk Locked Pulse: staccato pulse; octave-displaced version in B sections
  or bar 32+ in `single_evolving`
- KOS-RTHM-007 — Tangerine Dream pitch drift: pitch arch scoped per section; each A and B section
  gets its own independent rise-and-fall
- KOS-RTHM-008 — JMJ Oxygen 8-bar arc: slow stepwise melody unfolding over 8 bars; evolves
  pitch direction mid-arc; inspired by Jean-Michel Jarre
- KOS-RTHM-009 — Craven Faults phase drift: 5-note cell (root, 2nd, 3rd, 5th, 3rd) at 3-step
  intervals; 15-step cycle is coprime to bar length causing natural drift; startNote advances +1
  per bar over 5-bar cycle; MIDI 58–75; vel 52–68; 80% gate
- KOS-RTHM-010 — Craven Faults modular grit: 7-note arch cell at 2-step intervals; phase advances
  2 notes per bar over 7-bar cycle; 65% gate + 25% ghost notes; staccato; MIDI 58–76 normal /
  46–64 low octave (50% chance); vel 44–60 main / 22–38 ghost

### Bass patterns (KOS-BASS)

**Primary (one selected per song):**
- KOS-BASS-001 — Berlin School drone: single sustained root per bar
- KOS-BASS-002 — Octave pulse: alternating root / root+octave
- KOS-BASS-003 — Tangerine Dream pulse: alternates root and perfect fifth
- KOS-BASS-004 — Moroder Drift: slow chromatic drift between adjacent tones
- KOS-BASS-005 — Absent: no bass layer
- KOS-BASS-008 — Hallogallo Lock: root beat 1 (7 steps), fifth beat 3 (6 steps); requires
  KOS-BASS-006 dual layer
- KOS-BASS-009 — Crawling Walk: 2-bar root/fifth/approach pattern at lower velocities; MIDI 40–55
- KOS-BASS-010 — Moroder Pulse: 8th-note ostinato root–root–fifth–fifth–b7–b7–root–root. Blocks
  dual-layer and pulsating-layer.
- KOS-BASS-011 — Kraftwerk Autobahn: three rotating patterns (D=sparse anchor, E=Autobahn hook,
  C=trill) cycling at sections and every 16 bars. Always emits BASS-EVOL.
- KOS-BASS-012 — McCartney melodic drive: 8-note Mixolydian riff cycling each bar; b7 gives
  blues/Mixolydian quality; falls back to fifth in pure major. Blocks dual-layer. Always BASS-EVOL.
- KOS-BASS-013 — Loscil sub-bass pulse: sub-bass doublet beat 1 (primary + quiet repeat 2 steps
  later); optional beat-3 note (50%); MIDI 28–43; octave-up variant in variation windows. Blocks
  dual-layer and pulsating-layer.

**Additive (at most one per song, layered on top of primary):**
- KOS-BASS-006 — Additive dual bass: anchor + staccato off-beat hits. Blocked with KOS-BASS-004/
  010/012/013. Required for KOS-BASS-008.
- KOS-BASS-007 — Berlin school tremolo: rapid root pulsing. Blocked with KOS-BASS-004/010/012/013.

### Pad voicings (KOS-PADS)

- KOS-PADS-001 — Eno long drone: whole notes held 2–4 bars; root, fifth, octave, upper third
- KOS-PADS-002 — Vangelis swell: velocity ramp 20→80 via cascading sub-events; root and fifth
- KOS-PADS-003 — Steve Roach unsync layers: three independent voices at 8, 10, 12 bar loop lengths
- KOS-PADS-004 — Suspended Resolution: sus4 for 3 bars, minor resolution on bar 4
- KOS-PADS-005 — Stacked fourths: quartal voicing root, fourth, flat-seventh
- KOS-PADS-006 — Electric Buddha cloud shimmer: high-register shimmer layer above pad voicing
- KOS-PADS-007 — Probabilistic gated chord pulse: chord hits fire with variable probability each
  beat, creating rhythmic breathing texture rather than a sustained hold

### Texture patterns (KOS-TEXT)

- KOS-TEXT-001 — Orbital looping motif: shimmer lift; active throughout B sections; bar-count
  fallback in `single_evolving`
- KOS-TEXT-002 — Shimmer Hold: long sustained note in upper register; used in preRamp before
  melody bridges
- KOS-TEXT-003 — Spatial Sweep: slow rising figure across 4 bars; used in postRamp after melody
  bridges
- KOS-TEXT-004 — Loscil aquatic shimmer: 3 closely-voiced scale tones (root, 2nd, 3rd) with
  staggered 1-step attacks; sub-bass register MIDI 21–47; fires every 4 bars; volume cycles
  40%→100%→40% over 16 bars continuously; long hold (62 steps); dissolving underwater texture

### Lead behavior (KOS-LEAD)

One rule selected for A sections. In B sections, Technique D (60% chance) picks a different rule —
creating the "instrument arriving" effect heard in Dark Sun and Mister Mosca.

In melody bridges (Archetype B): bridge lead picks rule not used in A or B; plays upper register
(MIDI 72–84); generated phrase repeats once to fill the bridge duration.

- KOS-LEAD-006 — JMJ evolving phrase loop: 4–6 note melodic phrase generated once per body section
  and looped throughout; phrase mutates slightly at section boundaries (Jean-Michel Jarre style)

---

## Title Generator

Draws from space and cosmos vocabulary in English, French, and faux-German. Four patterns:
- Single JMJ-X word: 3-syllable word containing X (real French/Latin or invented JMJ style)
- JMJ-X word + Roman numeral (e.g. "Galaxie IV")
- Two-word English kosmic: adjective + kosmic noun
- Faux-German adjective + kosmic noun (Tangerine Dream tradition)

**Examples:** Vortexe, Proxima III, Dark Nebula, Silent Void, Ewig Kosmos, Tief Nebel, Dunkel Stern

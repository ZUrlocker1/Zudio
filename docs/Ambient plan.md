# Ambient Style Generator — Research & Design Plan

## Context

Zudio currently has Motorik (krautrock) implemented and Cosmic (Berlin School) fully designed. This is the third style: **Ambient** — rooted in Brian Eno's tape-loop generative philosophy and Loscil's electronic drone aesthetic. The plan covers musical research, generator design, and architecture. No code is written here.

The UI style dial will become: **Motorik → Cosmic → Ambient**.

The target is **electronic ambient** — slow, spacious, loop-phasing, modal. Not new-age piano. Available timbres: e-piano, Wurlitzer, organ, synth leads, pads, bass, drums (sparse/absent). No acoustic piano primacy.

---

## Part 1: What Is "Ambient"? — Genre Definition

**Brian Eno's definition (1978):** "Ambient music must be able to accommodate many levels of listening attention without enforcing one in particular; it must be as ignorable as it is interesting."

**Key characteristics distinguishing Ambient from Cosmic:**
- **Ambient:** No tempo anchor; loop phasing creates all variation; no rhythm; pure stasis with microscopic evolution
- **Cosmic:** Has a sequencer pulse (arpeggios, rhythmic patterns); tempo is felt; Berlin School energy
- **Motorik:** Driving kick/snare groove; forward propulsion; rhythm is primary

Ambient is the most static of the three styles. Changes happen over minutes, not bars. The listener cannot predict when anything will change — because nothing is scheduled to change; variation emerges from mathematical phase relationships between loops of incommensurable lengths.

---

## Part 2: Artist-by-Artist Analysis

### Brian Eno — The Inventor of the Genre

**Albums studied:** Discreet Music (1975), Music for Airports (1978), The Plateaux of Mirror (1980), On Land (1982), Apollo (1983), Thursday Afternoon (1985)

---

#### Discreet Music (1975) — The Foundation

The first true ambient record. A-side: single 30-minute piece using two tape delay loops.

**Loop architecture:**
- Loop 1: 63 seconds
- Loop 2: 68 seconds
- LCM(63, 68) = 4284 seconds = ~71 minutes before the two loops return to exact phase alignment
- In practice: never repeats in any meaningful listening session

**Source material:** Short fragments of Pachelbel's Canon (2–4 bar snippets) fed in live; the tape loops transform them into continuous evolving texture

**Derived rule:** Loop lengths with no common factors create infinite variation from finite material. A ratio of ~1.08 between two loop lengths (63/68 ≈ 0.926) is ideal — close enough to feel related, far enough to never sync.

---

#### Music for Airports (1978) — The Blueprint

**Track 2/1:**
- 7 independent tape loops, each containing ONE sustained pitch (held for ~1 bar, then silence ≥ 2× the note duration)
- 4 voices per pitch (non-vibrato singers)
- All 7 loops: incommensurable lengths (no common factors)
- Result: a shifting harmonic cloud; moments of consonance when loops coincidentally align, then drift apart
- **Eno's rule:** Silence must be at least 2× the duration of the sound

**Track 1/2:**
- 8 short piano snippets (single notes + 3–4 note phrases) converted to loops
- Each loop a different length
- Creates illusion of new melodies via recombination of the same 8 snippets

**Track 1/1 (Robert Wyatt piano):**
- BPM: ~82 (felt as free-time; no metronomic pulse)
- Key: D Major / D Mixolydian
- 2 piano layers in asynchronous phase
- 6-note descending opening phrase; echoes of 3 and 4 notes

**Generator rules derived:**
- 3–7 loops per song
- Each loop: 1–4 notes, then silence ≥ 2× note duration
- Loop lengths: prime-adjacent numbers with LCM > 20 minutes
- No percussion, no pulse, no metronomic grid

---

#### Apollo: Atmospheres & Soundtracks (1983)

Concrete BPM data from specific tracks:
- "An Ending (Ascent)": **67 BPM** (Adagio)
- "Under Stars": **66 BPM** (Adagio)
- "Deep Blue Day": **144 BPM** (Allegro — anomalously fast for ambient; treated as atmospheric, not driving)

**Production technique (backward-attack pads):**
- Notes recorded with soft attacks, then reversed; played with multiple echoes/reverbs applied in both directions
- Overlapping reversed-attack notes merge into one continuous flowing texture
- This is the origin of the "shimmer" pad sound — attack before the note, decay underneath it

**Generator rule:** Simulate reversed attack by using very long MIDI note attack (2–4 seconds, via velocity ramp from 0→peak) and very long release. The note "blooms" into existence rather than striking.

---

#### On Land (1982)

- 8 "landscape sound paintings" — no traditional song structure
- Instrumentation: synths emulating environmental sounds + field recordings + recycled earlier album sounds
- Harmonic approach: minimal; long sustained tones
- **Key technique:** 2 slightly detuned sine waves creating a slow beating drone (rate 0.1–0.5 Hz)
- Heavy reverb creates "underground rumbling" effect
- Structure: microscopic transformation while appearing static from afar

**Generator rule:** Two pad voices detuned by ±3–8 cents create a natural beating/chorus effect that evolves without any LFO parameter — the physics of interference patterns does the work.

---

#### Thursday Afternoon (1985)

- Single 61-minute continuous track
- Asynchronous loops; "holographic" — any brief excerpt represents the whole at lower resolution
- Irregular loop lengths recorded in full (not mechanical looping)
- Each event recurs at a different cyclic frequency; relationships constantly changing
- Emphasis on drones more than earlier works

**Generator rule:** For long Ambient songs, prefer drones (sustained whole-note chords) over melodic loops. The harmonic content IS the structure; no melody needed.

---

### Loscil (Scott Morgan) — Electronic Drone Ambient

**Albums studied:** Stases (2002), Submers (2002), Grundgestalt (2003), Plume (2006), Endless Falls (2010), Sketches from New Brighton (2012), Monument Builders (2016)

**Name origin:** "Loscil" = looping oscillator — the defining compositional technique

**BPM data (BPM tools report double-time; corrected values halved):**
- BPM detectors lock onto the 16th-note subdivision in Loscil's stuttery processed drums, not the felt quarter-note pulse — so all reported values should be halved
- "Sous-Marin": reported 172 → actual felt **~86 BPM**
- "Resurgence": reported 137 → actual felt **~68 BPM**
- "Micro Hydro": reported 183 → actual felt **~92 BPM**
- Corrected range: **68–92 BPM** — fully consistent with slow ambient feel

**Critical insight:** Loscil's tempo is fast but the music feels slow because:
- Individual events are sparse (one event per 2–4 bars, not every beat)
- Heavy reverb makes attack transients inaudible
- Drum loops are so processed (stuttered, granulated) they register as texture, not rhythm

**Drum approach:** Not traditional drums. Processed, micro-fragmented drum loops — stuttering hi-hats, granulated snares that sound more like rain or static than a kit.

**Harmonic approach:** Starts with "harmonic roots" (a tonal center), then sounds are processed loosely around that foundation. Minor/modal emphasis. Very slow harmonic rhythm (entire sections on one chord).

**Generator rules derived from Loscil:**
- "Loscil drums" = a drum track with very short note durations (2–4 steps), low velocity (30–50), probability-based triggering (50% chance per 16th note on hi-hat positions), heavy reverb effect tag
- Bass: sub-presence only; root note held for 4–8 bars at a time; no bass runs
- Texture: multiple pad layers with ±5–15 cent detune between voices

---

### Stars of the Lid

**Specific data:**
- "Articulate Silences, Pt. 1": 141 BPM, D Major
- "Gasfarming": 128 BPM

**Character:** Long-form drone; single chords sustained for entire compositions; no percussion; emphasis on timbre and warmth via string-section layering (real strings processed through reverb)

**Generator rule:** In Ambient, "no drums" is not a missing feature — it's a compositional choice that should generate silence on the drums track rather than a sparse pattern.

---

### Gas (Wolfgang Voigt) — Ambient Techno Crossover

- BPM: ~109 BPM
- **Unique in this survey:** Keeps a four-on-the-floor kick drum BUT surrounds it with ephemeral texture — barely-audible horn and string fragments, haze and drone
- The kick provides pulse without groove; it's a heartbeat, not a dance floor driver

**Generator rule:** Gas-style = Loscil-style drums but with kick on every quarter beat (beat 1/2/3/4). Still processed/quiet. This is the "with beat" variant of Ambient.

---

### Tim Hecker

- Albums: Ravedeath, 1972; Virgins
- **Harmonic approach:** Chromatic chords and dissonant layering (unusual for ambient — most ambient is consonant)
- Texture is primary; rhythm absent or minimal
- Pipe organ as primary instrument (maps well to organ patches in GM)
- Processed with laptop, tape, heavy effects

**Generator rule:** Hecker-style = allow dissonant intervals (minor 2nds, tritones) in pad voicings, unlike Eno-style which stays strictly diatonic. This creates a "dark ambient" sub-flavor.

---

## Part 2.5: Numbered Ambient Rules Catalog

These rules are extracted from the artist analysis above and numbered for reference during implementation. Each rule maps directly to a generator behavior or a Types.swift constraint.

**AMB-RULE-01: Incommensurable loop lengths**
Loop lengths must have no common factors (co-prime). A ratio of ~1.08–1.15 between any two loop lengths is ideal. This prevents the loops from returning to phase alignment during any listening session.
**Source:** Eno, Discreet Music (63s/68s loop ratio)

**AMB-RULE-02: Silence ≥ 2× note duration**
After any note event, generate at least 2× that note's duration as rest before the next event on the same track. This is Eno's foundational rule from Music for Airports.
**Source:** Eno, Music for Airports

**AMB-RULE-03: 3–7 loops per song, each with 1–4 notes**
Each loop layer contains 1–4 notes followed by silence. The minimal content per layer is intentional — variation emerges from phase relationships, not from complex individual patterns.
**Source:** Eno, Music for Airports

**AMB-RULE-04: Tonic always anchored**
At least one pad layer must hold the tonic note at all times. This is the harmonic anchor that prevents the piece from feeling atonal or random.

**AMB-RULE-05: Reversed-attack bloom via velocity ramp**
Simulate the reversed-attack effect by starting a note at near-zero velocity (0–15) and ramping to peak over the first 8–16 steps. The note "blooms" into existence rather than striking.
**Source:** Eno, Apollo (backward-attack pads)

**AMB-RULE-06: Beating drone via detuned voices**
Two pad voices detuned by ±3–8 cents create a natural beating/chorus effect at 0.1–0.5 Hz — one gentle pulse every 2–10 seconds. This is achieved through pitch: no LFO needed.
**Source:** Eno, On Land

**AMB-RULE-07: Drone preferred over melody in long songs**
For songs with `progressionFamily == .drone_single`, prefer whole-note chord drones over melodic loops. The harmonic content IS the structure.
**Source:** Eno, Thursday Afternoon

**AMB-RULE-08: Loscil drums = sparse stochastic texture**
"Drums" in Loscil-style ambient: very short note durations (2–4 steps), low velocity (30–50), ~25% trigger probability per 16th-note step. Heavy reverb. Feels like texture, not rhythm.
**Source:** Loscil, Stases/Submers/Plume

**AMB-RULE-09: Bass as sub-presence only**
Bass holds root note for 4–8 bars at a time. No bass runs. Velocity 55–65. Register MIDI 28–48.
**Source:** Loscil

**AMB-RULE-10: No drums = compositional silence, not a missing track**
When `percussionStyle == .absent`, the drums track exists but generates zero MIDI events. The track appears blank in the UI. This preserves UI consistency and allows mute/solo.
**Source:** Stars of the Lid, Eno beatless tracks

**AMB-RULE-11: Gas-style = textural drums + quarter-note kick**
A heartbeat-without-groove feel: kick on every quarter beat (steps 0, 4, 8, 12), hi-hat at 25% probability on 16th grid, velocity 15–30. No snare.
**Source:** Gas (Wolfgang Voigt)

**AMB-RULE-12: Dark ambient = allow dissonant intervals**
When `progressionFamily == .dissonant_haze`, allow minor 2nds and tritones in pad voicings. This requires a flag `allowsDissonance: Bool` to gate — the HarmonicFilter normally rejects these.
**Source:** Tim Hecker

---

## Part 3: Universal Ambient Rules (What All Sources Share)

These rules are non-negotiable for anything to sound Ambient:

- **Stasis over development** — no verse/chorus/bridge; no structural arc; the piece exists, it does not travel
- **Asynchronous loops** — if loops are used, their lengths must be incommensurable (no common factors)
- **Silence is structural** — rests are as important as notes; minimum rest ≥ 2× note duration (Eno's rule)
- **Harmonic changes are rare** — chord changes every 8–32 bars at minimum; drones OK for entire song
- **No metronomic pulse** — even when tempo exists (Loscil at 170 BPM), the feel is not "in time"
- **Consonant harmony** (Eno/Loscil style) OR controlled dissonance (Hecker style), but not jazz function
- **Reverb is compositional** — not an effect; it defines the spatial scale of the piece
- **Velocity hierarchy:**
  - Pads: 40–70 (background; never prominent)
  - Lead: 30–60 (even softer than pads — lead is background, not foreground)
  - Bass: 55–65 (sub-presence only)
  - Texture: 15–35 (barely audible; harmonic mass contributor)
  - Drums (when present): 20–55 textural / 50–65 soft-pulse
  - No track should exceed velocity 70; absence of dynamic peaks is genre-defining

---

## Part 4: Ambient vs. Cosmic vs. Motorik — The Full Comparison

- **Tempo feel:** Ambient = no felt pulse / Cosmic = sequencer pulse / Motorik = driving groove
- **Harmonic rhythm:** Ambient = drone (8–∞ bars) / Cosmic = slow (8–16 bars) / Motorik = moderate (4–8 bars)
- **Drums:** Ambient = absent or textural-only / Cosmic = absent or sparse hi-hat / Motorik = full groove
- **Leading element:** Ambient = pad/drone cloud / Cosmic = arpeggio sequence / Motorik = kick pattern
- **Variation source:** Ambient = loop phase math / Cosmic = skip logic + layer mutation / Motorik = section arcs
- **Listener experience:** Ambient = immersion (time dissolves) / Cosmic = trance (time slows) / Motorik = propulsion (time drives)

---

## Part 5: Proposed Ambient Generator Design

### 5.1 AmbientMusicalFrameGenerator

**Tempo:** Three operating modes:
- **Beatless** (50% probability): Tempo stored as 60–80 BPM but used only as step clock — no perceived pulse
- **Slow pulse** (35%): 70–95 BPM, soft kick-like events, Loscil/Gas feel (corrected from initial double-time estimate)
- **Mid pulse** (15%): 95–110 BPM — still feels slow due to sparse events; Gas-style heartbeat kick

**Cosmic/Ambient boundary at overlapping tempos:** At 95–110 BPM, the distinction from Cosmic is not tempo — it is the absence of the arpeggio generator. Ambient at these tempos has no sequencer pulse; Cosmic at the same tempo has a CosmicArpeggioGenerator as its primary voice.

**PercussionStyle enum (canonical, for Types.swift):** `.absent` / `.textural` / `.softPulse`

**Keys:** Weighted toward flat/minor keys:
- A minor (18%), E minor (15%), D minor (15%), G minor (12%), F minor (10%), B minor (10%), C minor (8%), other (12%)

**Modes:**
- Aeolian (natural minor): 40% — darkest, most ambient
- Dorian: 25% — minor with raised 6th, warmer
- Mixolydian: 15% — major with flat 7th, open/suspenseful
- Ionian (major): 15% — bright ambient (Eno's "An Ending (Ascent)" is major)
- Phrygian: 5% — mysterious, dark

**Progression families (new Ambient-specific set):**
- `drone_single` 35% — one tonic chord for entire song (or section); no harmonic movement
- `drone_two` 25% — two chords alternating every 16–32 bars (i → bVII or I → IV)
- `modal_drift` 20% — slow movement through 3–4 scale tones (i → bVII → bVI → bVII → i), each held 8–16 bars
- `suspended_drone` 15% — sus2 or sus4 chord held indefinitely; never resolves
- `dissonant_haze` 5% — chromatic cluster (Hecker-style), adjacent semitones as padding

**Song length:** Triangular min=180s, peak=300s, max=480s (3–8 minutes; can feel much longer due to stasis)

---

### 5.2 AmbientLoopEngine — The Core Architecture

This is what makes Ambient different from Cosmic at an engine level.

**Loop concept:** Rather than a single song-length MIDI sequence, Ambient uses 3–7 independent loop layers, each with its own bar count (loop length), that play simultaneously and never resync.

**Loop lengths (in bars):** Choose from prime-adjacent values that have large LCMs:
- Pair example: 11 + 13 bars → LCM = 143 bars = ~13 minutes at 90 BPM
- Trio example: 11 + 13 + 17 bars → LCM = 2431 bars = ~3.7 hours at 90 BPM
- This is why Eno's system "never repeats" — the math prevents it

**Implementation approach:** Rather than truly independent loop lengths (complex to implement in the current MIDI step engine), approximate using co-prime bar counts for each track. Each track's event pattern repeats at its own loop length. The master song length (totalBars) is set to LCM/4 so the song captures one full phase cycle at reduced resolution.

**Practical values for implementation:**
- 3-loop system: loop lengths 11, 13, 15 bars (LCM = 2145; use 48-bar song = first portion of the phase)
- 4-loop system: loop lengths 7, 11, 13, 17 bars (LCM = 17017; use 64-bar song)
- Loop lengths should be multiples of 2 for simpler MIDI alignment: 10, 14, 16, 22 bars (all even co-primes)

**Track→loop assignment (Zudio 7-track model):**
- Pads track: loop length A (longest prime, e.g. 17 bars)
- Lead 1: loop length B (e.g. 13 bars)
- Lead 2: loop length C (e.g. 11 bars)
- Texture track: loop length D (e.g. 7 bars — shortest for most frequent texture cycling)
- Bass track: loop length A or B (share with pads for harmonic consistency)
- Rhythm/Arpeggio: loop length E (e.g. 5 bars if used; absent in 60% of songs)
- Drums: no loop length (stochastic per-step probability; not a repeating loop)

In a 3-loop system (Pads + Lead 1 + Texture), assign the remaining tracks (Lead 2, Bass, Rhythm) to the nearest matching loop length or generate their content from the same loop pattern with minor variation.

---

### 5.3 AmbientPadsGenerator

Pads are the primary voice in Ambient. They carry all the harmonic content.

**AMB-PAD-001: Drone Sustain** — root chord held for entire loop length, velocity 45–60
- Voicing: root + 5th + octave (power chord structure) + optional major/minor 3rd at +1 octave
- Duration: entire loop length (e.g., 11 bars = 176 steps at 16 steps/bar)
- Attack: slow velocity ramp over first 8 steps (simulating reversed-attack bloom)
- Register: MIDI 36–72 (wide range; pads should fill space)

**AMB-PAD-002: Shimmer Layer** — two slightly detuned pad voices on same chord
- Voice 1: nominal pitch
- Voice 2: same chord, all notes +7 cents (1/14 semitone sharp)
- The 7-cent detune creates a ~0.3 Hz beating rate at A4=440 — one gentle pulse per ~3 seconds
- This is the "analog chorus without a chorus pedal" technique from On Land

**AMB-PAD-003: Swell Chord** — velocity ramps 20→75 over 16 steps, then holds for remainder of loop
- Simulates the Vangelis/Apollo "backward attack" effect via velocity
- Best for major/sus chords; sounds like strings entering from silence

**AMB-PAD-004: Suspended Drone** — sus2 or sus4 voicing held for entire section
- sus2 = root + 2nd + 5th (open, unresolved, spacious)
- sus4 = root + 4th + 5th (tense but not dissonant)
- Never resolves to major/minor; the suspension IS the harmonic statement

**AMB-PAD-005: Dissonant Cluster** (Hecker mode, 5% probability) — two chords a semitone apart played simultaneously
- Example: A minor triad + Bb major triad overlapping
- Creates dark, uneasy texture — "dark ambient" flavor
- Only generated when `progressionFamily == .dissonant_haze`

---

### 5.4 AmbientLeadGenerator

Lead in Ambient is sparse to the point of near-absence. It marks time rather than carrying melody.

**AMB-LD-001: Floating Tone** — single notes, each held 4–8 bars, widely spaced (one note per 8–16 bars)
- Notes always diatonic (no chromatic passing)
- Register: MIDI 72–96 (high, celestial register)
- Velocity: 30–50 (very soft; barely above threshold)
- This is the primary lead mode for pure ambient

**AMB-LD-002: Pentatonic Shimmer** — 2–3 note pentatonic figure, each note held 2 bars, played once per loop
- Notes: root, 4th, octave (open fifths and fourths only)
- No stepwise motion; only leaps
- One phrase per loop, then silence for the rest of the loop

**AMB-LD-003: Absent** — no lead notes at all (40% probability for pure ambient songs)
- Pads carry all harmonic content; no lead needed
- Most authentic to Eno's beatless tracks (Music for Airports 2/1 has no melody)

**AMB-LD-004: Echo Phrase** (Eno Music for Films style) — 3–4 note descending phrase, held long, then 8+ bars silence
- Descending direction only (ascending feels more expectant/active; descending settles)
- Notes: 5th → 3rd → root (or: octave → 5th → 3rd → root)
- Same phrase repeated once per loop cycle (identical notes, not varied)

---

### 5.5 AmbientBassGenerator

Bass in Ambient is minimal — a sub-presence that confirms the harmonic root, not a melodic voice.

**AMB-BAS-001: Root Drone** — root note held for entire loop length
- Velocity: 55–65
- Duration: 32–64 steps (2–4 bars per note event, then re-attack)
- Register: MIDI 28–48 (sub-bass range)
- This is the most common Ambient bass pattern

**AMB-BAS-002: Absent** (30% probability) — no bass at all in sparse sections
- Pads carry the low-end harmonic content
- Most appropriate when `progressionFamily == .drone_single` and pads include root voicing

**AMB-BAS-003: Slow Pulse** (Loscil/Gas style) — root note on every 2 beats (half-note pulse)
- Very short duration (2 steps), soft velocity (45)
- Creates heartbeat feel without a drum groove
- Only generated when `tempoStyle == .slowPulse` or `.midPulse`

---

### 5.6 AmbientDrumGenerator

The most constrained generator. Three settings:

**`percussionStyle = .absent` (50%)** — Track is empty. No MIDI events generated.
- Default for Eno-style pure ambient

**`percussionStyle = .textural` (35%)** — Loscil-style: sparse, processed, felt as texture
- Hi-hat: 16th-note grid, 25% trigger probability per step, velocity 20–35
- Occasional kick: beat 1 only, every 4th bar, velocity 40–55
- No snare
- All events tagged as "heavy reverb" and "compression" effects (if effects system supports it)

**`percussionStyle = .softPulse` (15%)** — Gas-style: quarter-note kick pulse + textural hi-hat
- Kick: every quarter beat (steps 0, 4, 8, 12 per bar), velocity 50–65
- Hi-hat: 25% probability on 16th-note grid, velocity 15–30
- No snare

---

### 5.7 AmbientRhythmGenerator (Arpeggio Track)

In Cosmic, the rhythm/arpeggio track is the primary voice. In Ambient, it is nearly silent or absent.

**AMB-RHY-001: Absent** (60% probability) — Track empty; pad drones carry everything

**AMB-RHY-002: Single Tone Pulse** — one note, repeated very softly every 2 bars
- Same pitch for entire loop
- Velocity: 25–40
- Duration: 2 steps (very short, percussive like a distant bell)
- Creates sense of slow pulse without rhythmic groove

**AMB-RHY-003: Sparse Arpeggio** — 4-note ascending pattern, played once per 4 bars, then silence for 4 bars
- Uses AMB-RHY-001-style silence between occurrences
- Velocity: 35–55; soft entry, not prominent
- Pattern: root → 3rd → 5th → octave (ascending tonic arpeggio, not Berlin School sequencer)

---

### 5.8 AmbientTextureGenerator

Texture is a primary layer in Ambient — often equal to or exceeding pads in importance.

**AMB-TEX-001: Orbital Shimmer** — a 3-note figure (root + 5th + octave) at prime loop length (different from all other tracks)
- Loop length: largest prime not shared with other tracks
- Velocity: 20–35 (barely audible; contributes to harmonic mass)
- Duration: whole notes (held 16 steps)

**AMB-TEX-002: Ghost Tone** — single note held for very long duration (64–128 steps = 4–8 bars)
- Pitch: scale degree 5 (the fifth, most consonant harmonic addition)
- Velocity: 15–25 (extremely soft; subliminal)
- One event per loop; rest of loop is silence

**AMB-TEX-003: Absent** (40% probability) — empty track; pad shimmer layer provides texture instead

---

## Part 6: Instrument Presets for Ambient Style (TrackRowView)

Available GM programs that work well for electronic Ambient:

- **Lead 1 (Ambient):** Brightness (100), Halo Pad (94), New Age Pad (88), Ocarina (79), Choir Aahs (52)
- **Lead 2 (Ambient):** Warm Pad (89), Space Voice (91), FX Atmosphere (99), Vibraphone (11)
- **Pads (Ambient):** Warm Pad (89), Halo Pad (94), String Ensemble (48), Synth Strings (50), Choir Aahs (52), Bowed Glass (92)
- **Rhythm/Arpeggio (Ambient):** New Age Pad (88), Vibraphone (11), Marimba (12), FX Echoes (102) — sparse/soft
- **Texture (Ambient):** Space Voice (91), FX Atmosphere (99), Sweep Pad (95), Bowed Glass (92)
- **Bass (Ambient):** Moog Bass (39), Synth Bass 1 (38), Warm Pad (89) at low register
- **Drums (Ambient):** Brush Kit (40) for textural percussion; absent otherwise

---

## Part 7: Ambient vs. "New Age" — Key Distinctions

The user explicitly does not want new-age piano style. The boundary:

- **New age:** Acoustic piano melody with tonal resolution; clear harmonic arcs; emotional narrative; ARP synthesizers mimicking orchestral swell
- **Electronic ambient (what we want):** No piano primacy; synth pads and drones; no melodic resolution; no emotional narrative arc; mathematical loop structure

Enforced in generator:
- Lead track defaults to absent or floating-tone (not melodic piano-style phrases)
- No waltz time, no 3/4
- No V7→I resolution (dominant seventh leading to tonic)
- Velocity flat (no dynamic crescendo/diminuendo arc per phrase)

---

## Part 8: Open Questions

- **Truly asynchronous loops:** Current MIDI engine locks all tracks to the same bar grid. True asynchrony (Eno's actual technique) requires per-track loop lengths. The approximation (co-prime bar counts within a shared song length) captures ~80% of the effect. Full implementation would need a per-track event scheduler with independent bar counters.

- **Tempo vs. beatless:** In pure ambient (50% of songs), tempo is cosmetic only. The scheduler still needs a BPM to compute step duration. A stored BPM of 70 BPM is fine — it just sets the metronome that no one hears.

- **Continuous Play interaction:** Ambient songs need different crossfade rules. A 6–8 bar crossfade (longer than Motorik's 4-bar) is appropriate. Bass and pads should always be "copied" (not regenerated fresh) across transitions — stable drones are even more critical in Ambient.

- **All 7 tracks always generated:** Both Cosmic and Ambient use all 7 tracks (Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums). Tracks that are "absent" for a given style simply generate no MIDI events — their MIDI lane appears blank in the UI. This preserves UI consistency, allows users to mute/solo any track, and lets users swap instruments on sparse tracks. Drums being "absent" means the drums track exists but has zero events.

- **Dark ambient sub-style (Hecker):** The `dissonant_haze` progression family introduces chromatic clusters. This might conflict with the HarmonicFilter pass. A flag `allowsDissonance: Bool` would gate this.

- **Loscil BPM correction:** Reported BPMs (137–183) were double-time artifacts of the BPM detection tool latching onto 16th-note subdivisions. Actual felt tempos are 68–92 BPM — consistent with the ambient range. The generator should use 65–95 BPM for Loscil-style ambient; no special fast-tempo exception needed.

---

## Part 9: Files to Create/Modify (When Implementation Begins)

**New files:**
- `Sources/Zudio/Generation/Ambient/AmbientMusicalFrameGenerator.swift`
- `Sources/Zudio/Generation/Ambient/AmbientStructureGenerator.swift`
- `Sources/Zudio/Generation/Ambient/AmbientPadsGenerator.swift`
- `Sources/Zudio/Generation/Ambient/AmbientLeadGenerator.swift`
- `Sources/Zudio/Generation/Ambient/AmbientBassGenerator.swift`
- `Sources/Zudio/Generation/Ambient/AmbientDrumGenerator.swift`
- `Sources/Zudio/Generation/Ambient/AmbientRhythmGenerator.swift`
- `Sources/Zudio/Generation/Ambient/AmbientTextureGenerator.swift`

**Modify:**
- `Sources/Zudio/Generation/SongGenerator.swift` — branch to Ambient generators when `style == .ambient`
- `Sources/Zudio/Models/Types.swift` — add `.ambient` to `MusicStyle`, add `PercussionStyle` enum, add Ambient progression families
- `Sources/Zudio/UI/TopBarView.swift` — style picker gains third segment
- `Sources/Zudio/UI/TrackRowView.swift` — Ambient instrument presets
- `Sources/Zudio/AppState.swift` — `selectedStyle` already planned for Cosmic; Ambient slots in automatically

---

## Part 10: Key Rules That Prevent Ambient from Sounding Like Noise

- Every note must be diatonic (strictly — no chromatic passing except in `dissonant_haze` mode)
- At least one pad layer must hold the tonic note at all times (harmonic anchor)
- Bass (when present) must match the pad's root note
- No two tracks should have identical loop lengths
- Lead track velocity must always be lower than pad track velocity (lead is background, not foreground)
- Silence is enforced: after any note event, generate at least 2× that note's duration as rest before the next event on the same track (Eno's rule)
- All loops must be ≥ 4 bars long (shorter feels like a riff, not ambient)

---

## Part 11: Verification Criteria (When Implementation Begins)

1. Build: `xcodebuild -scheme Zudio -configuration Debug build`
2. Generate 10 Ambient songs — none should feel rhythmically driven
3. Drums absent in 50% of generated songs; sparse/textural in 35%; soft-pulse in 15%
4. All songs: at least 2 pad layers with co-prime loop lengths (verify via status log)
5. Lead track absent or single floating tone in ≥ 70% of songs
6. No V7→I resolutions in any generated harmonic sequence
7. Subjective test: does it sound like background music that can be ignored? (Eno's "as ignorable as it is interesting" criterion)
8. Continuous Play crossfade: Ambient songs use 6-bar fade, not 4-bar
9. Style picker shows Motorik | Cosmic | Ambient — all three generate correctly
10. Test Mode (Cmd-T): 1-minute Ambient songs generated for rapid audition

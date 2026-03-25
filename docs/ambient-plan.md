# Ambient Style Generator — Research & Design Plan

## Context

Zudio currently has Motorik (krautrock) implemented and Kosmic (Berlin School) fully designed. This is the third style: **Ambient** — rooted in Brian Eno's tape-loop generative philosophy and Loscil's electronic drone aesthetic. The plan covers musical research, generator design, and architecture. No code is written here.

The UI style dial will become: **Motorik → Kosmic → Ambient**.

The target is **electronic ambient** — slow, spacious, loop-phasing, modal. Not new-age piano. Available timbres: e-piano, Wurlitzer, organ, synth leads, pads, bass, drums (sparse/absent). No acoustic piano primacy.

---

## Part 1: What Is "Ambient"? — Genre Definition

**Brian Eno's definition (1978):** "Ambient music must be able to accommodate many levels of listening attention without enforcing one in particular; it must be as ignorable as it is interesting."

**Key characteristics distinguishing Ambient from Kosmic:**
- **Ambient:** No tempo anchor; loop phasing creates all variation; no rhythm; pure stasis with microscopic evolution
- **Kosmic:** Has a sequencer pulse (arpeggios, rhythmic patterns); tempo is felt; Berlin School energy
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

**AMB-RULE-13: Dual-velocity pad architecture (primary + secondary layer)**
Pads are always generated in two layers: a primary layer (velocity 85–100, re-attacking every 4–5 beats) and a secondary shimmer layer (velocity 25–55, same pitches, offset by 2–4 steps). The two layers together create the characteristic "floating-but-present" pad texture. A single-velocity flat pad at 40–70 does NOT produce this sound.
**Source:** Zingaro Snow, Oxygenerator, Bosa Moon, Magnetik, Mobyesque MIDI analysis

**AMB-RULE-14: Pad re-attack overlap (not sustained single notes)**
Ambient pad notes are held 4–5 beats and re-attack before the previous note releases (1 beat overlap). The "eternal sustain" sensation is produced by overlapping re-attacks, not by single notes held for entire sections. Sound ratio 300–584% (note duration ÷ bar length) confirms consistent overlap.
**Source:** Zingaro Snow, Oxygenerator, Bosa Moon MIDI analysis

**AMB-RULE-15: Bell accent layer — staccato high-register highlights**
An optional bell/percussive-texture layer fires single very short notes (0.3 beat duration) at sparse density (~0.07 notes/bar) in the upper register (MIDI 84–108). Velocity 35–65. These are chord tones (root, 3rd, 5th) dropped in very quietly like single raindrops. The layer creates depth without rhythm. A sound ratio of ~27% (much shorter than the pad layer) distinguishes these as punctuation, not held tones.
**Source:** Zingaro Snow MIDI analysis

**AMB-RULE-16: Broken chord rhythm — scattered chord tones over 2–4 bars**
Instead of strumming or arpeggiating, individual chord tones are placed loosely across 2–4 bars with irregular spacing. Not a repeating pattern — each chord occurrence is unique in timing. Creates a "falling leaves" feel: related notes, no sequence.
**Source:** Bosa Moon MIDI analysis

**AMB-RULE-17: Major key preference**
Electric Buddha Ambient songs strongly favor major keys (D major, G major, C major, Ab major). Minor keys (D minor, A minor) appear but are not dominant. The genre-theory assumption of "ambient = minor/dark" is incorrect for this specific aesthetic. Weight major keys at ~55% vs minor at ~35%.
**Source:** Zingaro Snow (D major), Oxygenerator (G major), Bosa Moon (C major), Discreet Theseus (Ab major) MIDI analysis

**AMB-RULE-18: Co-prime loop length architecture (confirmed)**
Loop lengths with incommensurable ratios prevent repetition across any realistic listening session. Discreet Theseus: Left loop 13 bars, Right loop ~12.5 bars, LCM ≈ 325 bars (~18.8 minutes at 69 BPM). This confirms the Eno-derived AMB-RULE-01 architecture applies to the Electric Buddha style as well.
**Source:** Discreet Theseus MIDI analysis, Eno Discreet Music

**AMB-RULE-19: Stochastic note-firing as an alternative loop variation technique**
Rather than (or in addition to) co-prime loop lengths, Ambient variation can be generated by assigning independent fire probabilities to each note in a repeating phrase. A phrase of 6 notes where each has a 55% fire probability produces 2^6 = 64 possible "shapes" — the listener never hears exactly the same phrase twice. This is perceptually equivalent to the Eno loop-phasing effect but requires no special loop-length math. The two techniques are complementary: co-prime loops produce variation over very long timescales (minutes); stochastic firing produces variation bar-to-bar.
**Implementation:** For each note slot in the phrase, `if rng.nextDouble() < fireProb { generate note } else { skip (silence) }`. Fire probabilities should vary per note position — first and last notes of a phrase can have higher probability (0.75+) to preserve phrase boundaries; middle notes can be lower (0.40–0.60).

**AMB-RULE-20: Reverb is structural, not decorative**
In Ambient, reverb is the primary spatial tool — not an effect applied on top of a "dry" mix. It defines the perceived physical scale of the piece (intimate room vs. cathedral vs. infinite space). The generator should tag all Ambient tracks with maximum available reverb and minimum dry signal. Where the effects system supports room-size parameters: target reverb tail 3–8 seconds (much longer than Motorik's 0.5–1.5 seconds).
**Why it matters:** A pad note held for 3 beats in a 4-second reverb tail persists for ~5 more seconds after the note ends — this is how the "sustained" feeling is achieved at the playback level even when MIDI note durations are moderate (4–5 beats).

**AMB-RULE-22: Doubled parts with instrument crossfade**
Play the same melodic/pad pattern on two different instruments simultaneously, then gradually shift the relative volume from the first instrument toward the second over the course of a section (16–64 bars). The listener hears the timbre morph without any pitch change. The melody is identical; only the instrument character shifts.
- Implementation: generate identical MIDI event sequences on two tracks (same notes, same timing, same velocities). Apply a velocity envelope to each: Track A starts at 100% velocity and ramps down linearly to 30% over the crossfade window; Track B starts at 30% and ramps up to 100% over the same window.
- Crossfade window: 16–64 bars (full section is typical; a subtle effect when applied to a 32-bar section)
- Pair suggestions that produce interesting morphs: Flute → Warm Pad, String Ensemble → Synth Strings, Vibraphone → New Age Pad, Grand Piano → Halo Pad
- This directly simulates the volume automation technique used in Electric Buddha ambient recordings where two instrument tracks blend through the song

**AMB-RULE-23: Layered instrument presets (Microkorg-style dual timbre)**
Some synthesizer presets combine two distinct timbres into a single voice — e.g., a synth pad layer underneath a bright plucked attack layer. In MIDI, simulate this by generating two tracks playing the same pattern: one with a "body" instrument (sustained pad, string) and one with a "transient" instrument (short-duration bell, marimba, piano) at lower velocity. The transient layer provides the attack clarity the pad lacks; the pad provides the sustain body the transient lacks. Together they feel like one richer instrument.
- Transient layer velocity: 40–65 (noticeably softer than the body layer)
- Transient note duration: 1–3 beats (much shorter than the pad's 4–6 beat sustain)
- Transient instrument pairs with: Vibraphone (11) or Marimba (12) or Glockenspiel (9) or Music Box (10)
- Body instrument: any pad preset

**AMB-RULE-24: Chimes and embellishments as event markers**
Chimes (Tubular Bells GM 14, or Wind Chimes percussion), glockenspiel, and similar bright transient instruments serve as event markers in ambient — not melodic elements. They fire at points of harmonic change, section boundaries, or simply as sparse decoration every 8–16 bars.
- Velocity: 30–55 (soft enough to feel incidental, not assertive)
- Duration: 0.25–0.5 beats (very short; chimes are attack-only)
- Pitches: chord tones only (root or 5th preferred)
- Density: 1 event every 8–16 bars maximum — overuse destroys the "event marker" function
- Chimes work best at phrase boundaries (bar 8, bar 16, bar 32) and just before a chord change
- Also valid as wind chimes (unpitched): generate random hits from a narrow pitch range (MIDI 80–90) at low velocity (20–35) with 15% trigger probability per bar — continuous soft chime texture

**AMB-RULE-21: Tempo-synced delay with high feedback**
Delay in Ambient is not a subtle doubling effect — it is a primary compositional element that turns a single note into a repeating rhythmic pattern without any additional MIDI notes. Key parameters:
- **Delay time:** Synced to song tempo at a musically interesting subdivision. Preferred values:
  - Dotted half note (1.5 beats) — creates a gentle 3-against-2 feel at most tempos
  - Dotted quarter note (0.75 beats) — slightly faster, creates a lilting cascade
  - Whole note (4 beats) — slow echo, one repeat per bar
  - The dotted half note is the most characteristic Ambient delay setting (Brian Eno's primary delay time in Discreet Music)
- **Feedback:** 50–85% — high enough that each echo fires 4–8 times before fading below audibility. This turns one MIDI note into a self-generating phrase.
- **Dry/Wet:** 30–50% dry, 50–70% wet — the echoes are nearly as loud as the original
- **Implementation note:** Zudio's current playback engine uses `AVAudioUnitDelay`. Setting `delayTime` (in seconds) = `(60.0 / bpm) * 1.5` gives dotted-half-note sync. `feedback` = 0.65 is a good starting point. Tag Ambient lead and rhythm tracks with this delay profile by default.

---

## Part 3: Universal Ambient Rules (What All Sources Share)

These rules are non-negotiable for anything to sound Ambient:

- **Stasis over development** — no verse/chorus/bridge; no structural arc; the piece exists, it does not travel
- **Asynchronous loops** — if loops are used, their lengths must be incommensurable (no common factors)
- **Silence is structural** — rests are as important as notes; minimum rest ≥ 2× note duration (Eno's rule)
- **Harmonic changes are rare** — chord changes every 8–32 bars at minimum; drones OK for entire song
- **No metronomic pulse** — even when tempo exists (Loscil at 170 BPM), the feel is not "in time"
- **Consonant harmony** (Eno/Loscil style) OR controlled dissonance (Hecker style), but not jazz function
- **Reverb is compositional and should be extreme** — not an effect; it defines the spatial scale of the piece. Default to maximum available reverb. "When in doubt, add more reverb" is the correct instinct for Ambient. A sound that feels over-reverbed in isolation usually feels correct in the context of a full ambient mix.
- **Velocity hierarchy (corrected from MIDI analysis of 5 Electric Buddha Ambient songs):**
  - Pads primary layer: 85–100 (prominent — pads are the foreground voice in Ambient, not background)
  - Pads secondary layer: 25–55 (the quiet shimmer/texture layer underneath the primary)
  - Lead: 45–75 (softer than primary pads but not inaudible; a voice, not a whisper)
  - Bass: 55–65 (sub-presence only; consistent across all analyzed songs)
  - Texture: 20–45 (very soft; harmonic mass contributor)
  - Drums (when present): 20–55 textural / 50–65 soft-pulse
  - The dual-layer pad architecture (loud primary + quiet secondary) is the defining feature; flat dynamics across ALL tracks is incorrect — the primary pad must be heard clearly

---

## Part 4: Ambient vs. Kosmic vs. Motorik — The Full Comparison

- **Tempo feel:** Ambient = no felt pulse / Kosmic = sequencer pulse / Motorik = driving groove
- **Harmonic rhythm:** Ambient = drone (8–∞ bars) / Kosmic = slow (8–16 bars) / Motorik = moderate (4–8 bars)
- **Drums:** Ambient = absent or textural-only / Kosmic = absent or sparse hi-hat / Motorik = full groove
- **Leading element:** Ambient = pad/drone cloud / Kosmic = arpeggio sequence / Motorik = kick pattern
- **Variation source:** Ambient = loop phase math / Kosmic = skip logic + layer mutation / Motorik = section arcs
- **Listener experience:** Ambient = immersion (time dissolves) / Kosmic = trance (time slows) / Motorik = propulsion (time drives)

---

## Part 5: Proposed Ambient Generator Design

### 5.1 AmbientMusicalFrameGenerator

**Tempo:** Three operating modes:
- **Beatless** (50% probability): Tempo stored as 60–80 BPM but used only as step clock — no perceived pulse
- **Slow pulse** (35%): 70–95 BPM, soft kick-like events, Loscil/Gas feel (corrected from initial double-time estimate)
- **Mid pulse** (15%): 95–110 BPM — still feels slow due to sparse events; Gas-style heartbeat kick

**Kosmic/Ambient boundary at overlapping tempos:** At 95–110 BPM, the distinction from Kosmic is not tempo — it is the absence of the arpeggio generator. Ambient at these tempos has no sequencer pulse; Kosmic at the same tempo has a CosmicArpeggioGenerator as its primary voice.

**PercussionStyle enum (canonical, for Types.swift):** `.absent` / `.textural` / `.softPulse`

Distribution (corrected from MIDI analysis — all 7 reference songs used absent or textural only):
`.absent` 60% / `.textural` 35% / `.softPulse` 5%

**Keys:** Corrected weighting based on MIDI analysis of Electric Buddha Ambient songs (Zingaro Snow D major, Oxygenerator G major, Bosa Moon C major, Discreet Theseus Ab major, Magnetik D minor, Mobyesque A minor). Major keys dominate — the earlier minor-skewed table was wrong:
- D major (15%), G major (12%), C major (12%), Ab major (8%), F major (8%) — major subtotal ~55%
- D minor (10%), A minor (10%), E minor (8%), G minor (7%) — minor subtotal ~35%
- Other (10%)

The earlier plan (A minor 18%, E minor 15%, D minor 15%, minor-dominant) was derived from genre theory without MIDI evidence. Real Electric Buddha ambient songs strongly favor major and modal-major tonalities.

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

This is what makes Ambient different from Kosmic at an engine level.

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

**AMB-PAD-001: Drone Sustain** — root chord with re-attack every 4–5 beats, NOT held for entire loop length
- Corrected from MIDI analysis: Zingaro Snow, Oxygenerator, and Bosa Moon all show pad notes held ~4–5 beats with ~1 beat overlap into the next attack. Sound ratios 300–584% confirm heavy note overlap — the "sustained" feeling comes from overlapping re-attacks, not from single extremely long notes.
- Primary layer velocity: 85–100 (prominent, clearly audible)
- Secondary shimmer layer velocity: 25–55 (underneath the primary)
- Voicing: root + 5th + octave (power chord) + optional major/minor 3rd at +1 octave
- Re-attack interval: 4–5 beats (64–80 steps at 16 steps/bar)
- Note duration: 5–6 beats (1 beat overlap with next attack)
- Register: MIDI 36–72 (wide range; pads should fill space)
- Dual-layer architecture: generate one primary note event + one softer secondary note event at the same pitch, offset by 2–4 steps, lower velocity — this is the hallmark texture of all analyzed EB ambient songs

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

**AMB-PAD-006: Bell Accent Layer** — sparse staccato notes in high register, dropped in like raindrops
- Duration: 0.3 beats (very short, percussive quality)
- Density: ~0.07 notes/bar (roughly one bell tone every 14 bars)
- Register: MIDI 84–108 (above the pad chord voicing)
- Velocity: 35–65 (audible but not assertive)
- Pitches: chord tones only (root, 3rd, or 5th of current chord)
- Sound ratio ~27% — clearly shorter than pad notes (300–584%); distinguishes accent from held tone
- Generated as a secondary voice within the Pads track or as Texture track
- Source: Zingaro Snow analysis; user confirmed bell instrument use in Discreet Theseus

**AMB-PAD-007: Broken Chord Rhythm** — chord tones scattered loosely across 2–4 bars
- Not an arpeggio (no fixed interval between notes)
- Not a strum (not simultaneous)
- Placement: random within 2–4 bar window; each chord occurrence unique in timing
- Duration per note: 1–3 beats (varies)
- Velocity: 55–80 (secondary to primary pad layer but present)
- Creates "organic" harmonic movement; felt as calm motion, not as rhythm
- Source: Bosa Moon analysis

---

### 5.4 AmbientLeadGenerator

Lead in Ambient is sparse to the point of near-absence. It marks time rather than carrying melody.

**AMB-LD-001: Floating Tone** — single notes, each held 0.8–2.0 beats (not 4–8 bars), one note every 1.5–2 bars on average
- Corrected from MIDI analysis of Magnetik: "Freely" lead track shows avg 0.8–2.0 beat durations at 0.5–0.7 notes/bar — much shorter and denser than originally planned
- Notes always diatonic (no chromatic passing)
- Register: MIDI 60–84 (mid-to-high register; not exclusively celestial)
- Velocity: 45–75 (present but softer than primary pads)
- One phrase active, then silence for several bars, then next phrase — the "on/off" cycle is what creates the floating quality, not individual note length

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

**`percussionStyle = .absent` (60%)** — Track is empty. No MIDI events generated.
- Default for Eno-style pure ambient; confirmed dominant across all 7 analyzed songs

**`percussionStyle = .textural` (35%)** — Loscil-style: sparse, processed, felt as texture
- Hi-hat: 16th-note grid, 25% trigger probability per step, velocity 20–35
- Occasional kick: beat 1 only, every 4th bar, velocity 40–55
- No snare
- All events tagged as "heavy reverb" and "compression" effects (if effects system supports it)

**`percussionStyle = .softPulse` (5%)** — Gas-style: quarter-note kick pulse + textural hi-hat
- Kick: every quarter beat (steps 0, 4, 8, 12 per bar), velocity 50–65
- Hi-hat: 25% probability on 16th-note grid, velocity 15–30
- No snare

---

### 5.7 AmbientRhythmGenerator (Arpeggio Track)

In Kosmic, the rhythm/arpeggio track is the primary voice. In Ambient, it is nearly silent or absent.

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

**AMB-RHY-004: Stochastic Phrase** — a fixed melodic sequence where each note fires probabilistically rather than always
- Define a repeating phrase of 4–8 diatonic notes (loop-length determines phrase length)
- Each note in the sequence has an independent fire probability: 40–75% per occurrence
- Result: the phrase is never identical twice — some notes are present, some are silence gaps, gaps vary each cycle
- This produces the "loop phasing" sensation without requiring truly different loop lengths: the same 8-slot sequence sounds different each repeat because different notes drop out each time
- Velocity on fired notes: 30–60 (soft, not assertive)
- Gaps between fired notes create breathing room; the listener hears fragments and mentally completes the phrase
- This is the probabilistic alternative to the co-prime loop architecture — simpler to implement, same perceptual effect

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

**AMB-TEX-004: Chime Scatter** — sparse unpitched or pitched chime events, one per 8–16 bars
- Instrument: Tubular Bells (14), Glockenspiel (9), or Vibraphone (11)
- Velocity: 30–50 (incidental, not melodic)
- Duration: 0.25–0.5 beats
- Pitches: root or 5th of current chord only
- Function: marks time gently; gives the listener an occasional "anchor event" without creating rhythm

**AMB-TEX-005: Instrument Crossfade Double** — same note sequence as another track, crossfading in velocity
- Generates identical events to the Lead or Pads track (same pitch, same timing)
- Starts at 20% velocity, ramps to 80% over the section length while the source track ramps from 80% to 20%
- Net effect: a timbre morph over the section; no pitch change; listener hears the sound gradually shift character
- Pairs: Pad track doubles with Texture = String Ensemble → morph toward Synth Strings; or Warm Pad → Halo Pad

---

## Part 6: Instrument Presets for Ambient Style (TrackRowView)

### 6.1 Acoustic–Electronic Blending Philosophy

Ambient routinely combines acoustic timbres (strings, piano, bells, woodwinds, bowed instruments) with electronic timbres (synthesizers, pads, sweeps). The blend is a core part of the aesthetic — not a contrast but a fusion where the boundary between the two becomes unclear under heavy reverb.

**Design principle:** Each Ambient song should draw from both pools. A song with only synth pads feels sterile; a song with only acoustic instruments feels like classical or new-age. The target is the space between them.

Acoustic timbres that work in Ambient:
- **Strings** (slow-bowed) — Violin (40), Viola (41), Cello (42), String Ensemble 1 (48), String Ensemble 2 (49), Synth Strings 1 (50)
- **Woodwinds** — Flute (73), Recorder (74), Pan Flute (75), Ocarina (79)
- **Bells / metallic** — Glockenspiel (9), Vibraphone (11), Marimba (12), Tubular Bells (14), Music Box (10)
- **Bowed / tonal** — Bowed Glass (92) — straddles the acoustic/electronic boundary intentionally
- **Grand Piano** (1) — used very sparingly as a bell/accent layer only (individual notes, not chords); heavy reverb blurs it into the pad texture

Electronic timbres that work in Ambient:
- **Warm Pad** (89), **New Age Pad** (88), **Halo Pad** (94), **Sweep Pad** (95) — the core pad voices
- **Space Voice** (91), **Choir Aahs** (52) — vocalized texture, blurs acoustic/electronic
- **FX Atmosphere** (99), **FX Echoes** (102) — pure electronic texture
- **Brightness** (100) — shimmer/high-frequency presence
- **Synth Bass 1** (38), **Moog Bass** (39) — sub-bass presence

**Generator instrument pairing strategy:** When assigning instruments to an Ambient song's 7 tracks, pair at least one acoustic-family instrument with at least one electronic-family instrument per song. Avoid assigning all 7 tracks from the same family.

Example pairing (valid): Pads=Warm Pad (electronic) + Texture=String Ensemble (acoustic) + Lead=Flute (acoustic) + Rhythm=FX Echoes (electronic)
Example pairing (too uniform): Pads=Warm Pad + Texture=Halo Pad + Lead=Space Voice + Rhythm=Sweep Pad — all four are electronic pads

### 6.2 Instrument Preset Lists Per Track

Each track lists instruments in two families. At song generation time, AMB-SYNC-007 (see Part 13) requires at least one acoustic and one electronic instrument across the 7-track assignment. Instruments marked (A) are acoustic family; (E) are electronic.

**Lead 1 — primary floating melody**
- Acoustic: Flute (73) (A), Ocarina (79) (A), Pan Flute (75) (A), Whistle (78) (A), Recorder (74) (A)
- Electronic: Brightness (100) (E), Halo Pad (94) (E), New Age Pad (88) (E), Calliope Lead (82) (E)
- Design note: Lead 1 is the primary melody voice. Woodwind and breath timbres give it an organic, slightly imperfect quality that contrasts with the electronic pad sustain underneath.

**Lead 2 — shimmer / echo response**
- Acoustic: Vibraphone (11) (A), Celesta (8) (A), Glockenspiel (9) (A), Grand Piano (0) (A)
- Electronic: Warm Pad (89) (E), Space Voice (91) (E), FX Atmosphere (99) (E)
- Design note: Lead 2 never exceeds Lead 1 in note count. Metallic-bell and keyboard timbres make a natural acoustic foil to the electronic pad choices. Grand Piano is valid here provided it is used as Lead 2 requires: single sparse notes at velocity 40–65, never chords, never melodic runs. Under heavy reverb a soft single piano note becomes a tuned-percussion event rather than a piano performance — this is exactly Eno's technique in Music for Airports 1/2 (8 individual piano notes looped with reverb) and Harold Budd's approach on The Plateaux of Mirror. The "no new age piano" constraint is about usage pattern, not the instrument. Bright Acoustic Piano (1) is a valid alternative — marginally more percussive attack, integrates cleanly at low velocity. If Lead 1 is acoustic (flute, ocarina), Lead 2 should favour electronic (warm pad), and vice versa.

**Pads — harmonic foundation**
- Acoustic: String Ensemble 1 (48) (A), Choir Aahs (52) (A), Synth Strings 1 (50) (A/E), Bowed Glass (92) (A/E)
- Electronic: Warm Pad (89) (E), Halo Pad (94) (E), New Age Pad (88) (E), Sweep Pad (95) (E)
- Design note: Pads are the foreground voice in Ambient (primary layer velocity 85–100). String Ensemble with heavy reverb becomes nearly indistinguishable from a synth pad — this blurring of the acoustic/electronic boundary is the target texture.

**Rhythm — sparse accent / arpeggio when used**
- Acoustic: Vibraphone (11) (A), Marimba (12) (A), Tubular Bells (14) (A), Glockenspiel (9) (A)
- Electronic: FX Crystal (98) (E), FX Echoes (102) (E), Church Organ (19) (E)
- Design note: Rhythm track is absent in 60% of Ambient songs. When present, metallic-percussive timbres (vibraphone, tubular bells) pair well with the drone foundation — they mark time without creating a groove. FX Echoes provides a purely electronic counterpart.

**Texture — sustain / shimmer mass**
- Acoustic: String Ensemble 2 (49) (A), Bowed Glass (92) (A/E), Choir Aahs (52) (A)
- Electronic: Space Voice (91) (E), FX Atmosphere (99) (E), Sweep Pad (95) (E), Pad 3 Poly (90) (E)
- Design note: Texture is at very low velocity (20–45) — it adds harmonic mass, not melody. Bowed Glass sits at the acoustic/electronic boundary intentionally: it sounds like a wine glass or glass harmonica under heavy reverb, bridging both families.

**Bass — sub-presence**
- Acoustic: Cello (42) (A) — low register only (MIDI 28–48), Contrabass (43) (A)
- Electronic: Moog Bass (39) (E), Synth Bass 1 (38) (E), Fretless Bass (35) (E)
- Design note: Bass is sub-presence only (velocity 55–65, root held 4–8 bars). Cello or Contrabass in the low register with reverb creates an organic low-end that contrasts strongly with Moog Bass's synthetic character — this is one of the most effective acoustic/electronic pairings in the entire style.

**Drums — textural or absent**
- Brush Kit (40) (A) — only kit used; absent in 60% of songs
- Design note: Brush Kit is the most acoustic-feeling kit available in GM and suits the intimate, non-mechanical quality of ambient percussion. If present, all hits should be at velocity 20–50 and tagged with heavy reverb.

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

- **All 7 tracks always generated:** Both Kosmic and Ambient use all 7 tracks (Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums). Tracks that are "absent" for a given style simply generate no MIDI events — their MIDI lane appears blank in the UI. This preserves UI consistency, allows users to mute/solo any track, and lets users swap instruments on sparse tracks. Drums being "absent" means the drums track exists but has zero events.

- **Tempo-synced delay setup (AVAudioUnitDelay):** The PlaybackEngine already uses `AVAudioUnitDelay`. For Ambient style, when the playback engine initializes a song, it should configure the delay node with `delayTime = (60.0 / bpm) * 1.5` (dotted half note), `feedback = 0.65`, `wetDryMix = 60`. This would require either: (a) passing style info to PlaybackEngine so it can set delay parameters per-style, or (b) exporting delay parameters alongside MIDI events in the generated song data structure. Option (a) is simpler for the initial implementation.

- **Stochastic firing vs. loop phasing:** Both AMB-RULE-19 (stochastic) and AMB-RULE-01 (co-prime loops) solve the same problem — preventing repetition. Stochastic is simpler to implement within the current per-track event-array model. Co-prime loops require per-track loop length tracking. A practical first implementation: use stochastic firing for the lead/rhythm tracks, co-prime loop lengths (via the loop-length approach in 5.2) for the pads tracks.

- **Dark ambient sub-style (Hecker):** The `dissonant_haze` progression family introduces chromatic clusters. This might conflict with the HarmonicFilter pass. A flag `allowsDissonance: Bool` would gate this.

- **Loscil BPM correction:** Reported BPMs (137–183) were double-time artifacts of the BPM detection tool latching onto 16th-note subdivisions. Actual felt tempos are 68–92 BPM — consistent with the ambient range. The generator should use 65–95 BPM for Loscil-style ambient; no special fast-tempo exception needed.

- **Extreme effects investigation (to research before implementation):** Zudio's current `AVAudioUnitReverb` and `AVAudioUnitDelay` nodes offer moderate ranges. For Ambient, it's worth testing their limits and researching whether additional Audio Units are available on macOS/iOS that provide more extreme effects:
  - **Extended reverb:** `AVAudioUnitReverb` presets go up to "Large Hall 2" (~5s tail). Consider: is there a way to chain two reverb units? Or use a convolution reverb AU (AUNBandEQ / AUMatrixReverb)? A 15–30 second reverb tail is legitimate for ambient.
  - **Filter sweeps:** `AVAudioUnitEQ` can implement a low-pass filter. A slow automated cutoff sweep from 200 Hz → 8000 Hz over 32 bars produces the classic ambient "opening up" effect. This would require parameter automation tied to the step scheduler — an LFO applied to the EQ cutoff frequency, very slow period (16–64 bars).
  - **Chorus/ensemble width:** `AVAudioUnitEffect` with AU effect type kAudioUnitSubType_Chorus adds width. Stacking two slightly-detuned instances simulates the Microkorg's ensemble effect. Worth testing if CPU budget allows.
  - **Convolution reverb with impulse responses:** macOS provides `AUMatrixReverb` and third-party AUs accessible via `AVAudioUnit`. Loading a 10-second church IR would transform the spatial scale dramatically. Requires bundling an IR file (~2 MB for a stereo 10s IR at 44.1 kHz).
  - Decision point: evaluate what's achievable within `AVAudioEngine`'s built-in AU set before considering custom DSP.

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
- `Sources/Zudio/AppState.swift` — `selectedStyle` already planned for Kosmic; Ambient slots in automatically

---

## Part 10: Key Rules That Prevent Ambient from Sounding Like Noise

- Every note must be diatonic (strictly — no chromatic passing except in `dissonant_haze` mode)
- At least one pad layer must hold the tonic note at all times (harmonic anchor)
- Bass (when present) must match the pad's root note
- No two tracks should have identical loop lengths
- Lead track velocity must always be lower than primary pad track velocity (lead is secondary voice; primary pads are the foreground)
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
9. Style picker shows Motorik | Kosmic | Ambient — all three generate correctly
10. Test Mode (Cmd-T): 1-minute Ambient songs generated for rapid audition

---

## Part 12: MIDI Analysis Findings — Seven Reference Songs

This section records the concrete data extracted from MIDI analysis of reference songs. All measurements were taken with the `mido` Python library. These findings directly correct or extend the theoretical rules in Parts 1–11.

---

### Magnetik (Electric Buddha Band — Ambient-leaning)

- BPM: ~72 (slow ambient territory)
- Key: D minor / D Dorian
- Lead track ("Freely" designation): 0.5–0.7 notes/bar; avg note duration 0.8–2.0 beats — much shorter and denser than the original AMB-LD-001 plan of "4–8 bars per note"
- Pads: dual-velocity architecture confirmed (primary ~90, secondary ~35)
- Structure: long single-section form with textural variation only; no verse/chorus

**Rule corrections:** AMB-LD-001 note duration corrected to 0.8–2.0 beats; on/off cycles (phrase active then silent for several bars) replaced "individual long notes."

---

### Mobyesque (Electric Buddha Band — Ambient-leaning)

- BPM: ~80
- Key: A minor
- Pads: dual-velocity architecture confirmed; primary layer prominent
- Texture: stochastic hi-hat-like events; no structured drum pattern
- No melodic lead; pads are sole harmonic voice

**Rule confirmed:** AMB-RULE-13 (dual-velocity pads); AMB-RULE-10 (drums as texture only)

---

### Zingaro Snow (Electric Buddha Band — Ambient)

- BPM: ~75
- Key: D major — this was the first indication that the minor-key bias in the original plan was wrong
- Pads: primary layer 85–100 velocity; re-attack every 4–5 beats; ~5-beat note duration (1-beat overlap)
- Bell accent layer: staccato notes 0.3 beat duration, ~0.07 notes/bar density, velocity 35–55, MIDI 84–100 range, sound ratio ~27%
- Secondary shimmer layer: same pitches, velocity 25–45

**New rules:** AMB-RULE-14 (pad re-attack overlap), AMB-RULE-15 (bell accent layer), AMB-RULE-17 (major key preference)

---

### Oxygenerator (Electric Buddha Band — Ambient)

- BPM: ~82
- Key: G major
- Pads: dual-velocity architecture; primary 88–100; secondary 28–50
- No drum pattern; no lead melody
- Sound ratio ~400% (notes held ~4× bar length = 4-beat notes in 1-bar sections, heavily overlapping)
- One chord for entire song duration; no harmonic movement

**Rule confirmed:** AMB-RULE-13 (dual-velocity), AMB-RULE-14 (overlap re-attack), AMB-RULE-07 (drone preferred), AMB-RULE-17 (major key)

---

### Bosa Moon (Electric Buddha Band — Ambient)

- BPM: ~76
- Key: C major
- Pads: dual-velocity architecture; primary 90–100; secondary 30–55
- Broken chord pattern: individual chord tones scattered loosely across 2–4 bars with irregular timing; not an arpeggio, not a strum — organic "falling leaves" placement
- Sparse bass: root held 4–8 beats at a time; velocity ~60
- No drums; no lead

**New rule:** AMB-RULE-16 (broken chord rhythm); confirmed AMB-RULE-09 (bass as sub-presence)

---

### Discreet Theseus (Electric Buddha Band — Classic Eno-style Ambient)

- BPM: 69
- Duration: ~270 bars / 15.7 minutes / 89 tracks (multitrack tiling of two loop types)
- Key: Ab major (pitch classes C, C#/Db, D#/Eb, F, G#/Ab — all five fit Ab major; Bb and G absent)
  - Note: C# is the enharmonic equivalent of Db, which is the 3rd of Ab major; this is not C# Mixolydian
  - Ab major scale: Ab Bb C Db Eb F G — the analyzed pitches (excluding Bb and G, present but rare) center on Ab major
- Structure: two independent loops per the co-prime architecture (AMB-RULE-18):
  - Left loop: 13 bars; 6 notes per cycle (D#4→F4→C4→G#3→D#3→G#3); avg velocity 53; sound ratio ~40%
  - Right loop: ~12.5 bars; 4 notes per cycle (C#4→D#4→F3→G#3); avg velocity 82; sound ratio ~38%
  - LCM ≈ 325 bars = ~18.8 minutes before phase alignment — never repeats in one listening session
- Left loop note durations: 2.30b / 3.00b / 1.22b / 5.00b / 5.50b / 3.26b — wide variation; some very short (1.22 beats) mixed with long holds (5.50 beats)
- Right loop note durations: 1.25b / 3.25b / 4.50b / 4.00b — more uniform; ~3 beats average
- The song was performed by layering 89 tracks in a DAW (repeating the two loops across the full song length), not as true independent loops — but the mathematical effect is identical

**Additional production techniques (from user):**
- Volume automation across duplicate tracks to blend two different instrument sounds together — not captured in MIDI but produces "instrument morphing" effect over time
- A melody from "Hey Jude" (descending motif: G-F#-E-D-C-B...) was embedded as a separate melodic overlay, demonstrating that a structured melody can be floated on top of a pure drone ambient layer without destroying the ambient character
- Heavy reverb throughout (spatial scale: concert hall or larger)
- Bell instrument used as accent layer (confirms AMB-RULE-15)
- Blending of acoustic and electronic instrument timbres (string + synth, piano + pad)
- Lush sweeps: slow filter sweeps or volume swells across pad layers — the "shimmer" effect

**Generator implications:**
- The "Hey Jude" technique suggests the Ambient generator could optionally overlay a simple well-known diatonic melody fragment (3–6 notes, descending, very soft) as an Easter egg / structural high-point; or more practically, the lead track can quote a simple descending scale fragment without this feeling "wrong" in an ambient context
- Instrument morphing (via volume automation) = in Zudio's MIDI model, simulate by generating two simultaneous pad tracks with complementary velocity arcs: primary fades from 90→50 over 16 bars while secondary rises from 20→70 over the same span; net volume is constant but timbre shifts

---

### Harmonic Summary Across All 7 Songs

All pitches across the 7 analyzed songs fit major-key or modal-major (Dorian, Mixolydian) frameworks. Not one song used a purely minor (Aeolian) or dissonant (Phrygian, Locrian) harmonic center as its primary color. The original plan's minor-key bias (derived from genre theory, not measurement) was incorrect for the Electric Buddha Ambient aesthetic.

Key inventory:
- D major — Zingaro Snow, Magnetik (D Dorian variant)
- G major — Oxygenerator
- C major — Bosa Moon
- Ab major — Discreet Theseus
- A minor — Mobyesque (the one clearly minor-key entry)

**Updated key weights for AmbientMusicalFrameGenerator:** D major 15%, G major 12%, C major 12%, Ab major 8%, F major 7%, Eb major 6%, A minor 10%, D minor 8%, E minor 7%, other 15%

---

### Tempo and Percussion Summary

All 7 songs: 69–82 BPM. Percussion: absent or textural-only in all 7. Not one song used a soft-pulse (Gas-style) quarter-note kick. This suggests the percussion distribution should be revised:
- `.absent` 60% (raised from 50%)
- `.textural` 35% (unchanged)
- `.softPulse` 5% (lowered from 15% — rare in practice)

The 95–110 BPM "mid pulse" operating mode may be more characteristic of Kosmic-leaning ambient crossover than pure Ambient.

---

## Part 13: Effects Architecture for Ambient

### 13.1 What Is Already in the Signal Chain

Every track already has the following nodes wired in series:

`sampler → boost (gain/pan LFO) → sweepFilter (LFO low-pass) → delay (AVAudioUnitDelay) → comp → lowEQ → reverb (AVAudioUnitReverb) → master mixer`

The existing `TrackEffect` buttons the user sees (Boost, Delay, Reverb, Trem, Comp, Low, Sweep, Pan, Space) are all implemented by enabling/bypassing nodes already in this chain. No new hardware is needed for most Ambient improvements — the work is in setting different **parameter values** when `style == .ambient`.

---

### 13.2 The Two Effects That Matter Most for Ambient

**1. Delay — high feedback, long time, high wet**

The current delay defaults are configured for Motorik/Kosmic use: 16th-note delay time (0.125s at 120 BPM), feedback 40%, wet 40%. These produce a crisp tight echo suitable for rhythmic music. For Ambient this is wrong in every parameter.

Ambient delay target:
- **Delay time:** `(60.0 / bpm) * 1.5` — dotted half note. At 75 BPM this is 1.2 seconds. This is Brian Eno's primary delay time in Discreet Music. One echo every 1–2 seconds transforms a single note into a slowly decaying phrase without any additional MIDI.
- **Feedback:** 65–80%. At 75%, a single note produces approximately 6–8 audible repeats before falling below perception. This is the generative delay — the repeats become the texture, not the original note.
- **Low-pass cutoff:** 3500–4500 Hz (lower than the current 6000 Hz). Each repeat rolls off slightly more high end than the last, giving the echos a natural decay into warmth rather than staying bright.
- **Wet/dry mix:** 55–70% wet. The echos are nearly as loud as the original. This is aggressive by Motorik/Kosmic standards; it is correct for Ambient. The dry signal can feel almost buried in the echo field.

`AVAudioUnitDelay` supports these values natively: `delayTime` (0–2 seconds), `feedback` (–100 to 100), `lowPassCutoff` (10–22050 Hz), `wetDryMix` (0–100). No new nodes required.

A clean implementation: when `PlaybackEngine.ambientStyle` is true, configure delay nodes at song load time with the ambient parameters before playback begins. The user's per-track Delay button still toggles on/off, but when it's on in Ambient mode, it uses the ambient parameters rather than the default ones.

**2. Reverb — deep wet, cathedral for all atmospheric tracks**

Current behaviour: atmospheric tracks (Lead 1, Lead 2, Pads, Texture) load Cathedral preset; rhythmic tracks (Rhythm, Bass, Drums) load Large Chamber. Space effect = cathedral at 70% wet. Regular reverb = large chamber at 50% wet.

For Ambient, every track benefits from more reverb depth:
- Lead 1, Lead 2: cathedral, 80–85% wet. Single notes need to bloom and sustain well past their MIDI duration. A 3-second reverb tail on a 1-beat note at 75 BPM means the sound continues for ~4× its played duration. This is the "eternal sustain" sensation from pads, applied to lead notes.
- Pads: cathedral, 85–90% wet. Pads are already long sustain; reverb at this depth merges the attack into a continuous wash.
- Texture: cathedral, 85–90% wet. At this level texture is essentially pure reverb — the original dry signal is almost inaudible.
- Bass: large hall, 60–65% wet. Bass with too much reverb loses its root-anchoring function; it becomes mush. 60% is the Ambient limit before the pitch center blurs unacceptably.
- Rhythm (when present): large chamber, 65% wet. The goal is "distant bell, not dry click."
- Drums (textural): plate preset, 70% wet. Loscil-style drums are almost entirely reverb tail; the original hit is just a trigger.

The `AVAudioUnitReverb` presets available (`smallRoom`, `mediumRoom`, `largeChamber`, `mediumHall`, `largeHall`, `cathedral`, `plate`) span a range from ~0.3s tail to ~4–5s tail for cathedral. Cathedral at 90% wet is approximately the maximum achievable tail length with the built-in presets. For now this is sufficient; longer tails would require a third-party convolution reverb AU (see Section 14.4).

---

### 13.3 Per-Track Ambient Effect Defaults

These replace the Motorik/Kosmic defaults in `applyDefaultEffects()` when style is Ambient. The user can still toggle effects manually; these are the starting state.

**Lead 1:**
- Delay ON — dotted half note (1.5 beats), feedback 72%, lowpass 4000 Hz, wet 60%
- Reverb (Space) ON — cathedral, wet 82%
- Sweep OFF by default (can enable for a slow filter-open effect on sparse melodic phrases)

**Lead 2:**
- Delay ON — dotted quarter (0.75 beats), feedback 65%, lowpass 4500 Hz, wet 55%
  (shorter delay time than Lead 1 creates the echo counterpoint between the two leads)
- Reverb (Space) ON — cathedral, wet 78%

**Pads:**
- Delay OFF — delay on sustained pad chords causes frequency beating against themselves; creates muddiness rather than depth
- Reverb (Space) ON — cathedral, wet 88%
- Sweep optional — a very slow LFO sweep (32-bar period) on pads creates a long opening/closing filter breath effect; off by default but worth enabling manually

**Rhythm:**
- Delay ON — dotted half note, feedback 55%, lowpass 3500 Hz, wet 48%
  (distant bell character; sparse rhythm events should feel like they come from far away)
- Reverb ON — large chamber, wet 65%

**Texture:**
- Delay OFF — texture notes are already subliminal; delay would only thicken mush
- Reverb (Space) ON — cathedral, wet 90%
- Sweep ON — very slow LFO (16–32 bar period); texture is the ideal track for a barely-perceptible filter breath because its low volume means the sweep is subtle

**Bass:**
- Delay OFF — bass delay causes low-frequency smearing that muddies the harmonic root
- Reverb ON — large chamber, wet 62%
- Low Shelf ON — +5 dB at 80 Hz; sub-presence reinforcement

**Drums (when present, textural style):**
- Delay ON — 1-beat, feedback 40%, lowpass 3000 Hz, wet 45%
  (textural drums with short delay become more like processed noise texture)
- Reverb ON — plate, wet 70%
- Compression ON — flattens velocity variation in the sparse hits; makes the texture more consistent

---

### 13.4 Possible Additions Not Currently in the System

**High-pass filter (easy — recommend adding)**
A high-pass filter on Lead and Texture tracks in Ambient removes low-frequency muddiness that collides with the bass and pad root notes. With heavy reverb on all tracks, low-end build-up is a real risk. `AVAudioUnitEQ(numberOfBands: 1)` with `filterType = .highPass`, `frequency = 200–350 Hz` on Lead 1, Lead 2, and Texture would clean this up significantly. The existing `lowEQ` node (currently a low shelf boost) could be reconfigured for this, or a separate HPF node added to the chain. Implementation cost: low — same node class, different parameters.

**Ping-pong delay (medium — consider for v2)**
True ping-pong delay alternates each echo between left and right channels. `AVAudioUnitDelay` does not support ping-pong natively. Simulation approach: two delay nodes with complementary pan settings on their boost mixers (boost A panned left, boost B panned right), each at half the target delay time, feeding into each other — complex to wire but achievable within `AVAudioEngine`. For Ambient, ping-pong delay on Lead 1 creates a wide spatial sensation that reinforces the "music coming from the space around you" feel. Worth adding in a post-launch iteration.

**Chorus / ensemble width (hard — skip for now)**
macOS Core Audio has no standard public chorus effect AU. The `kAudioUnitSubType_Distortion` type with specific preset modes can produce vaguely chorus-like artifacts, but it is not clean. The detuned-voice approach (AMB-RULE-06, AMB-PAD-002) achieves the same beating-chorus sensation directly in MIDI by scheduling two notes a few cents apart. This is the better implementation path than trying to wire an effects-based chorus.

**Extended reverb tail beyond 5 seconds (hard — future consideration)**
`AVAudioUnitReverb` cathedral preset produces approximately 4–5 seconds of tail. Eno's reference spaces (real airport terminals, large halls) have reverb tails of 8–15 seconds. Achieving this would require either chaining two reverb nodes (doubles CPU cost, some phasing artifacts) or loading a convolution reverb AU with a long impulse response. macOS provides `AUMatrixReverb` as a private AU; `AVAudioUnit` with the corresponding AudioComponentDescription can load it. A 10-second stereo IR file at 44.1 kHz adds ~3.5 MB to the bundle. Worth investigating when Ambient is implemented — the difference between 5s and 10s reverb tail is not subtle in a fully ambient mix.

**Tremolo on ambient pads (note — already exists)**
The existing `.tremolo` TrackEffect drives a volume LFO on the boost node. At a very slow LFO rate (0.3–0.6 Hz), this produces a slow swell rather than the faster vibrato-like effect used in Motorik. For Ambient pads this could simulate the slow volume automation used in reference recordings. The LFO rate would need to be settable per-style, or a second LFO rate parameter added. Currently the tremolo rate is fixed — check the PlaybackEngine LFO implementation before deciding whether to expose this.

---

## Part 14: Implementation Roadmap — Staged Coding Plan

This section is the build plan. It follows the same foundation-first discipline used for Motorik (drums → bass → pads → leads) and Kosmic, but Ambient has a different core architecture — the loop tiling engine — that must be built before any generator produces meaningful output. The stages are ordered by dependency, not by importance.

Each stage has a test gate: a specific audible or measurable check that must pass before proceeding to the next stage.

---

### Stage 0 — Type System and UI Scaffolding

**Goal:** Style selector shows Motorik | Kosmic | Ambient. Selecting Ambient generates a valid (but silent) song without crashing.

**Files to modify:**
- `Sources/Zudio/Models/Types.swift`
  - Add `.ambient` to `MusicStyle` enum
  - Add `PercussionStyle` enum: `.absent`, `.textural`, `.softPulse`
  - Add `AmbientProgressionFamily` enum: `.droneSingle`, `.droneTwo`, `.modalDrift`, `.suspendedDrone`, `.dissonantHaze`
  - Add `AmbientTempoStyle` enum: `.beatless`, `.slowPulse`, `.midPulse`
  - Add `AmbientLoopLengths` struct: 7 `Int` values (one loop length in bars per track), a `songBars: Int` total, and a `stepsPerLoop: [Int]` computed property
- `Sources/Zudio/Generation/SongGenerator.swift`
  - Add `case .ambient:` branch in `generate()` that calls a new stub `generateAmbient()` returning an empty 64-bar silent SongState
- `Sources/Zudio/UI/TopBarView.swift`
  - Add third segment to the style picker: Motorik | Kosmic | Ambient
- `Sources/Zudio/AppState.swift`
  - Add `.ambient` case to `selectedStyle` handling
  - Add stub Ambient instrument pool names to `instrumentPoolNames()`
- `Sources/Zudio/UI/TrackRowView.swift`
  - Add `isAmbient` branch returning stub instrument lists for all 7 tracks

**Test gate:** Build succeeds. UI shows three-way picker. Selecting Ambient generates a silent song. All other styles continue working.

---

### Stage 1 — AmbientMusicalFrameGenerator

**Goal:** The frame generator produces a valid, varied musical context for every song.

**Files to create:**
- `Sources/Zudio/Generation/Ambient/AmbientMusicalFrameGenerator.swift`
  - Generates `AmbientMusicalFrame`: BPM, key (chromatic note), mode, progressionFamily, percussionStyle, tempoStyle
  - BPM: beatless 62–78 / slowPulse 72–92 / midPulse 95–110; distribution 60% / 35% / 5%
  - Key weights: D major 15%, G major 12%, C major 12%, Ab major 8%, F major 7%, Eb major 6%, A minor 10%, D minor 8%, E minor 7%, other 15% (AMB-RULE-17)
  - Mode weights: Aeolian 40%, Dorian 25%, Mixolydian 15%, Ionian 15%, Phrygian 5%
  - Progression family weights: droneSingle 35%, droneTwo 25%, modalDrift 20%, suspendedDrone 15%, dissonantHaze 5%
  - Enforces AMB-SYNC-005: keyOverride / moodOverride / tempoOverride set to nil after read; never written back to AppState after generation
  - Generates `AmbientLoopLengths`: assigns a co-prime bar count to each of the 7 tracks from the set {5, 7, 11, 13, 17, 19, 23}; longer primes for slower-cycling tracks (Pads gets the largest; Drums is stochastic so gets no loop length, assigned 0). Bass shares the Pads loop length for harmonic consistency (AMB-RULE-01, AMB-RULE-18).
  - Song total bars = LCM of the three largest loop lengths capped at 96 bars maximum (prevents excessively long songs while keeping the phase-relationship effect meaningful within one listening session)
  - Song length target: triangular distribution min=180s, peak=300s, max=480s; back-calculate totalBars from BPM and target duration

**Files to modify:**
- `Sources/Zudio/Generation/SongGenerator.swift` — `generateAmbient()` calls `AmbientMusicalFrameGenerator.generate()` and logs the result

**Test gate:** Generate 10 songs via logs only. Verify: key distribution is not clustering, BPM varies across the three tempo styles, progression families include at least droneSingle and droneTwo across the set. Confirm no key persistence across back-to-back generations.

---

### Stage 2 — AmbientStructureGenerator

**Goal:** Songs have a valid section structure. The loop tiling architecture is established.

**Files to create:**
- `Sources/Zudio/Generation/Ambient/AmbientStructureGenerator.swift`
  - Generates `SongStructure` compatible with the existing structure type
  - Ambient section shapes:
    - Pure drone (40%): body only, no intro/outro; the loop architecture provides all variation
    - Minimal arc (45%): 4-bar intro, body, 4-bar outro — intro/outro for the volume fade; body is the loop engine
    - Breathing arc (15%): 6-bar intro, body, 6-bar outro — slightly more formal fade
  - Intro/outro are marked for the PlaybackEngine's mainMixerNode volume fade (same approach as Motorik)
  - No bridge sections, no fills, no transitions — Ambient structure is the simplest of the three styles
- `Sources/Zudio/Generation/Ambient/AmbientLoopTiler.swift`
  - The architectural core unique to Ambient
  - `static func tile(events: [MIDIEvent], loopBars: Int, totalBars: Int, stepsPerBar: Int) -> [MIDIEvent]`
  - Takes a pattern of `loopBars` length and repeats it to fill `totalBars` via modulo step arithmetic: for each tiling pass, add `loopBars * stepsPerBar` to each event's stepIndex
  - Handles the case where the final tile is partial (totalBars % loopBars != 0): only include events whose tiled stepIndex < totalBars * stepsPerBar
  - This is what produces the Eno phase-shifting effect: Pads looping every 17 bars, Lead1 every 13 bars, Lead2 every 11 bars will never produce the same alignment twice within a 96-bar song

**Test gate:** Stub out one generator (e.g. a 4-note Pads pattern of 13 bars). Tile it to 64 bars. Verify in the MIDI lane view that the pattern repeats at the correct interval and never overruns totalBars. Verify two patterns of different loop lengths (11 and 13 bars) produce visibly offset starting points after the first loop.

---

### Stage 3 — AmbientPadsGenerator

**Goal:** The primary harmonic voice is audible and sounds like ambient music. This is the most important generator — everything else is built against it.

**Files to create:**
- `Sources/Zudio/Generation/Ambient/AmbientPadsGenerator.swift`
  - Generates one loop of `loopLengths.pads` bars, then tiled by AmbientLoopTiler
  - Implements all AMB-PAD rules:
    - AMB-PAD-001: primary layer — re-attack every 4–5 beats, 5–6 beat duration (1-beat overlap), velocity 85–100
    - AMB-PAD-001 secondary layer: same chord, offset by 2–4 steps, velocity 25–55
    - AMB-PAD-002: shimmer — second voice at +7 cents (two separate notes same pitch, small detune creates beating; in MIDI this is approximated by slight velocity variation between the two notes)
    - AMB-PAD-003: swell chord variant — velocity ramp 20→75 over 16 steps
    - AMB-PAD-004: suspended drone variant — sus2 or sus4 voicing for `suspendedDrone` progression family
    - AMB-PAD-006: bell accent layer (sparse, short-duration chord tones in high register, ~0.07 notes/bar)
    - AMB-PAD-007: broken chord — chord tones scattered across 2–4 bars with irregular timing
  - Voicing: root + 5th + octave + optional 3rd; root register MIDI 36–60, 5th above, octave doubling
  - Chord from progressionFamily: droneSingle = same chord all song; droneTwo = alternates every 16–32 bars; modalDrift = slow 3–4 chord movement, each chord 8–16 bars
  - AMB-SYNC-001: scale pool always `keySemitone(frame.key)` — never chord-root shifted
  - AMB-SYNC-009: lowest pad note pitch class must match bass root (verified post-generation)

**Test gate:** Generate 5 Ambient songs with only Pads active (mute all other tracks). Listen: should sound like a slowly evolving pad drone. Re-attacks should be audible (not a single infinitely held note). Dual-layer should create a subtle shimmer. Consonance rate target: >92%.

---

### Stage 4 — AmbientBassGenerator

**Goal:** Bass confirms the harmonic root without becoming melodic.

**Files to create:**
- `Sources/Zudio/Generation/Ambient/AmbientBassGenerator.swift`
  - Generates one loop of `loopLengths.bass` bars (same as Pads loop length — shares harmonic cycle), tiled
  - AMB-BAS-001: root note held 32–64 steps (2–4 bars), re-attack, velocity 55–65, register MIDI 28–48
  - AMB-BAS-002: absent (30% of songs — returns empty events)
  - AMB-BAS-003: slow pulse — root on every 2 beats at velocity 45, short duration (2 steps)
  - AMB-SYNC-002: bass root at bar boundaries must equal chord plan root for that bar
  - AMB-SYNC-009: pitch class of bass note must match lowest pad note pitch class

**Test gate:** With Pads + Bass active, verify bass root agrees with pad chord root in every bar of the log. Bass should be felt more than heard — a sub-presence.

---

### Stage 5 — AmbientDrumGenerator

**Goal:** Drums are absent, textural noise, or a heartbeat — never a groove.

**Files to create:**
- `Sources/Zudio/Generation/Ambient/AmbientDrumGenerator.swift`
  - Routes to three modes based on `frame.percussionStyle`:
  - `.absent` (60%): returns `[]`
  - `.textural` (35%): 16th-note grid, 25% trigger probability per step, velocity 20–35, duration 2 steps; occasional kick on beat 1 every 4th bar at velocity 40–55; no snare; all events tagged for heavy reverb and compression
  - `.softPulse` (5%): kick on steps 0/4/8/12, hi-hat 25% probability, velocity 15–30
  - Drums are stochastic — no loop length / no tiling; generate freshly across all totalBars

**Test gate:** With Pads + Bass + Drums, confirm drums are absent 60% of the time; when textural, they are quiet and feel more like rain than a drum pattern; they never drive the music.

---

### Stage 6 — AmbientLeadGenerator (Lead 1)

**Goal:** A sparse, on/off floating melody appears — audible, but does not dominate.

**Files to create:**
- `Sources/Zudio/Generation/Ambient/AmbientLeadGenerator.swift`
  - Generates one loop of `loopLengths.lead1` bars, tiled
  - Routes to rule by weighted pick:
    - AMB-LD-003 Absent: 40% — returns empty for the section; silence is correct
    - AMB-LD-001 Floating Tone: 30% — 0.5–0.7 notes/bar, 0.8–2.0 beat duration, velocity 45–75, diatonic only, register MIDI 60–84; stochastic firing (AMB-RULE-19) — phrase of 4–8 notes where each has 55% fire probability
    - AMB-LD-004 Echo Phrase: 20% — 3–4 note descending phrase (5th→3rd→root), held long, then silence for ≥4 bars before next phrase
    - AMB-LD-002 Pentatonic Shimmer: 10% — 2–3 note figure, each held 2 bars, root/4th/octave only
  - AMB-RULE-02: after each note, rest ≥ 2× note duration before next event (Eno's rule)
  - AMB-SYNC-001: all notes diatonic to `frame.key` + `frame.mode`; no chromatic passing
  - AMB-SYNC-006: hard density cap — if note count exceeds 2.0 notes/bar for any bar, truncate
  - Stores generated events in a return value that SongGenerator passes to Lead 2

**Test gate:** Lead 1 should be absent in roughly 40% of songs. When present, note density 0.5–2.0 notes/bar. Consonance target: >80%. Should feel like occasional phrases drifting in and out.

---

### Stage 7 — AmbientLead2Generator (Lead 2)

**Goal:** A quieter secondary voice that responds to Lead 1 rather than competing.

**Files to create:**
- `Sources/Zudio/Generation/Ambient/AmbientLead2Generator.swift`
  - Receives `lead1Events: [MIDIEvent]` — this parameter must be used, not ignored (AMB-SYNC-004)
  - Generates one loop of `loopLengths.lead2` bars (different prime from Lead 1), tiled
  - Determines Lead 1 activity windows: any 4-bar window where Lead 1 has ≥ 1 event is "Lead 1 active"
  - In Lead 1 active windows: Lead 2 generates at most 0.4 notes/bar (steps back)
  - In Lead 1 silent windows: Lead 2 may generate at 0.6–1.2 notes/bar (fills the space)
  - Register: MIDI 55–78 — consistently below Lead 1's 60–84 range
  - Rule mix (different weights from Lead 1):
    - AMB-LD-003 Absent: 30% (still often silent)
    - AMB-LD-001 Floating Tone: 35% — same sparse rules as Lead 1 but quieter (velocity 35–60)
    - AMB-LD-004 Echo Phrase: 25% — responds to Lead 1's last phrase by playing a shorter version 2–4 bars later
    - AMB-LD-002 Pentatonic Shimmer: 10%
  - AMB-SYNC-003: total Lead 2 note count must not exceed Lead 1 note count for any 8-bar section
  - AMB-SYNC-006: hard cap — 1.2 notes/bar maximum

**Test gate:** Lead overlap (bars where both leads are playing simultaneously) should be < 25% of total bars. Lead 2 note count should be less than Lead 1 in ≥ 70% of songs.

---

### Stage 8 — AmbientRhythmGenerator

**Goal:** An accent voice that marks occasional moments without creating a pattern.

**Files to create:**
- `Sources/Zudio/Generation/Ambient/AmbientRhythmGenerator.swift`
  - Routes by weighted pick:
    - AMB-RHY-001 Absent: 60% — returns `[]`
    - AMB-RHY-002 Single Tone Pulse: 20% — one pitch, repeated every 2 bars at velocity 25–40, duration 2 steps
    - AMB-RHY-003 Sparse Arpeggio: 10% — 4 notes ascending (root→3rd→5th→octave), once per 4 bars, then 4 bars silence; velocity 35–55
    - AMB-RHY-004 Stochastic Phrase: 10% — 4–8 diatonic notes with 40–75% fire probability per slot (AMB-RULE-19); phrase fills one loop, then stochastic variation makes each repeat sound different
  - Loop length: `loopLengths.rhythm` (shortest prime — 5 or 7 bars — so it cycles most frequently)
  - AMB-SYNC-001: all notes from song-tonic scale
  - AMB-SYNC-006: hard cap — 3.0 notes/bar

**Test gate:** Rhythm absent in ~60% of songs. When present, should be nearly inaudible as a supporting texture — noticeable only when listening for it.

---

### Stage 9 — AmbientTextureGenerator

**Goal:** A subliminal harmonic mass that adds depth without drawing attention.

**Files to create:**
- `Sources/Zudio/Generation/Ambient/AmbientTextureGenerator.swift`
  - Routes by weighted pick:
    - AMB-TEX-003 Absent: 40% — returns `[]`
    - AMB-TEX-001 Orbital Shimmer: 30% — root + 5th + octave at velocity 20–35, whole notes (held 16 steps), loop length is the largest prime not used by any other track
    - AMB-TEX-002 Ghost Tone: 20% — scale degree 5 held 64–128 steps at velocity 15–25; one event per loop, rest is silence
    - AMB-TEX-004 Chime Scatter: 10% — one chord-tone chime event every 8–16 bars at velocity 30–50, duration 0.25–0.5 beats (AMB-RULE-24)
  - Loop length: `loopLengths.texture` (medium prime — 7 or 11 bars)
  - AMB-SYNC-006: hard cap — 1.5 notes/bar

**Test gate:** Texture should be inaudible in isolation at normal listening volume. Its contribution should only be noticed as added warmth when it is muted.

---

### Stage 10 — SongGenerator Wiring and HarmonicFilter Pass

**Goal:** All 7 generators are wired together and a complete song generates correctly end to end.

**Files to modify:**
- `Sources/Zudio/Generation/SongGenerator.swift`
  - Implement full `generateAmbient()` replacing the Stage 0 stub:

```
generateAmbient() order:
1. AmbientMusicalFrameGenerator → frame + loopLengths
2. AmbientStructureGenerator → structure
3. AmbientPadsGenerator → raw loop → AmbientLoopTiler → trackEvents[kTrackPads]
4. AmbientBassGenerator → raw loop → AmbientLoopTiler → trackEvents[kTrackBass]
5. AmbientDrumGenerator → trackEvents[kTrackDrums] (stochastic, no tiling)
6. AmbientLeadGenerator → raw loop → AmbientLoopTiler → lead1Events
7. AmbientLead2Generator(lead1Events:) → raw loop → AmbientLoopTiler → trackEvents[kTrackLead2]
8. AmbientRhythmGenerator → raw loop → AmbientLoopTiler → trackEvents[kTrackRhythm]
9. AmbientTextureGenerator → raw loop → AmbientLoopTiler → trackEvents[kTrackTexture]
10. HarmonicFilter.apply() — enforce diatonic constraint; no DensitySimplifier, ArrangementFilter, PatternEvolver, or DrumVariationEngine for Ambient
11. Build SongState and return
```

  - No `DensitySimplifier` — Ambient notes are already sparse; thinning them would destroy the texture
  - No `ArrangementFilter` — no structural events (fills, bridges, X-Files) in Ambient
  - No `PatternEvolver` — loop phasing via AmbientLoopTiler provides variation; PatternEvolver would corrupt the loop integrity
  - No `DrumVariationEngine` — Ambient drums are stochastic from the start
  - Add `regenerateTrack()` Ambient branch (mirrors Kosmic branch) — regenerates the track's raw loop and re-tiles

**Test gate:** Generate 10 complete Ambient songs. All 7 tracks populated. HarmonicFilter passes without rejecting large numbers of notes. Status log shows varied keys, modes, and progression families. Build succeeds, no crashes.

---

### Stage 11 — PlaybackEngine: Ambient Effects Configuration

**Goal:** When Ambient is selected, delay and reverb parameters match the Ambient targets defined in Part 14.

**Files to modify:**
- `Sources/Zudio/Playback/PlaybackEngine.swift`
  - Add `var ambientStyle: Bool = false` property (alongside existing `kosmicStyle` and `motorikStyle`)
  - Add `configureAmbientEffects(bpm: Double)` — called at song load when `ambientStyle` is true:
    - For each atmospheric track (Lead1, Lead2, Pads, Texture): `delay.delayTime = (60.0 / bpm) * 1.5`, `delay.feedback = 72`, `delay.lowPassCutoff = 4000`, `delay.wetDryMix = 0` (actual wet mix applied when user enables Delay)
    - For Bass/Rhythm/Drums: `delay.delayTime = (60.0 / bpm) * 1.0`, `delay.feedback = 40`, `delay.lowPassCutoff = 3500`
    - Configure reverb presets per Part 14.2 (cathedral for Lead/Pads/Texture, largeChamber for Bass/Rhythm, plate for Drums) — preset loaded at song start, not at play time
  - Add ambient intro/outro fade via `mainMixerNode.outputVolume` ramp (same approach as Motorik — all tracks fade together; 4–6 bar ramp)
- `Sources/Zudio/AppState.swift`
  - Add `playback.ambientStyle = selectedStyle == .ambient` in both generation trigger points (alongside existing kosmicStyle and motorikStyle assignments)
- `Sources/Zudio/UI/TrackRowView.swift`
  - Add `isAmbient` branch in `applyDefaultEffects()`:
    - Lead 1: Space ON, Delay ON
    - Lead 2: Space ON, Delay ON
    - Pads: Space ON (delay OFF — sustain + delay causes beating muddiness)
    - Rhythm: Reverb ON, Delay ON
    - Texture: Space ON, Sweep ON
    - Bass: Reverb ON, Low Shelf ON
    - Drums: Reverb ON, Compression ON

**Test gate:** Switch style to Ambient. Generate a song. Play back. Delay on Lead 1 should be clearly audible as a long echo (not a tight 16th-note effect). Reverb on Pads should feel deep and spatial. Pan automations from Motorik should not apply.

---

### Stage 12 — Instrument Pools and TrackRowView

**Goal:** Ambient instrument picker shows the correct acoustic/electronic per-track lists defined in Part 6.2.

**Files to modify:**
- `Sources/Zudio/AppState.swift` — `instrumentPoolNames()` Ambient branch: all 7 tracks with the lists from Part 6.2
- `Sources/Zudio/UI/TrackRowView.swift` — `instruments` property Ambient branch: matching lists with GM program numbers

**Acoustic / electronic pairing validation (AMB-SYNC-007):** After random instrument assignment at generation time, verify at least one acoustic-family instrument is present. If all electronic, override Lead 2 to Vibraphone (11). Log the override as `AMB-SYNC-007 acoustic/electronic balance enforced`.

**Test gate:** Ambient instrument pickers show correct lists. Cycling through Lead 1 presets shows woodwinds and pads mixed together. Acoustic/electronic mix rule fires at least occasionally in a set of 10 songs.

---

### Stage 13 — Status Log and Generation Logging

**Goal:** Generation log entries for Ambient songs follo
w the same format as Motorik/Kosmic so the coherence analysis tools work correctly.

**Files to modify or create:**
- Log entries needed per song: style, key, mode, BPM, totalBars, percussionStyle, progressionFamily, loop lengths per track, instrument assignments, per-rule firing log for each generator
- Confirm `SongLogExporter` handles Ambient correctly — particularly AMB-SYNC-005 (key persistence cleared) and zero-bar section suppression (already fixed for Kosmic, should carry over)
- Add Ambient-specific log entries: `AMB-SYNC-007 acoustic/electronic balance enforced` (when fired), loop length assignments per track

**Test gate:** Export MIDI + log for 3 songs. Open logs. Verify loop lengths are logged, percussion style is logged, progression family is visible.

---

### Stage 14 — Coherence Analysis Pass

**Goal:** Confirm the generated output meets the musical quality targets before release.

Same methodology as Kosmic Studies 01–03. Generate 12 songs, export MIDI + logs, run consonance analysis script.

**Targets to verify (from AMB-SYNC-008 and Part 11):**
- Bass consonance > 92%
- Lead 1 consonance > 80%
- Lead overlap (both leads active simultaneously) < 25% of bars
- Lead 2 note count ≤ Lead 1 note count in ≥ 70% of songs
- Drums absent in ~60%, textural in ~35%
- No key/mode clustering across a batch of 12 (confirms AMB-SYNC-005 fix is working)
- All songs: at least 2 tracks with different loop lengths visible in the MIDI lane
- Progression family distribution: at least droneSingle, droneTwo, and modalDrift appear across 12 songs

If findings require generator changes, fix and re-run a smaller study (6–8 songs) to confirm. Do not proceed to Stage 15 until the coherence pass is clean.

---

### Stage 15 — Ambient Name Generator ✓ DONE

See `Sources/Zudio/Generation/AmbientTitleGenerator.swift`. See also the Title Generator section at the end of this document.

---

### Stage 16 — Test Mode Support

**Goal:** Cmd-T generates a short 1-minute Ambient song for rapid audition.

**Files to modify:**
- `Sources/Zudio/Generation/Ambient/AmbientMusicalFrameGenerator.swift` — when `testMode == true`, cap `totalBars` at the equivalent of ~60 seconds at the generated BPM
- Verify status log emits test mode indicators as per existing test mode convention

**Test gate:** Cmd-T in Ambient mode generates a ~1-minute song. Status log shows test mode flag. Full-length songs still generate correctly without test mode.

---

### Implementation Notes

**Do not apply to Ambient:** `DensitySimplifier`, `ArrangementFilter`, `PatternEvolver`, `DrumVariationEngine`. These four post-processing passes are Motorik/Kosmic-specific and would corrupt the loop-tiling architecture.

**Do apply to Ambient:** `HarmonicFilter`. The diatonic constraint is universal — it enforces AMB-SYNC-001.

**Loop tiling is the core architectural difference.** Each generator produces a short loop (5–19 bars), not a full-length song. `AmbientLoopTiler` repeats it. The phase relationship between different-length loops is what produces variation. If any generator bypasses the tiler and writes directly to the full song length, the phase effect is lost.

---

## Part 15: Harmonic Variety & Melodic Interest — Analysis and Plan (2026-03-24)

### 15.1 Observations from 10-Song Listening Analysis

Analysis of 15 Ambient songs (log files + MIDI) identified two structural weaknesses:

**Bass monotony:**
- `AmbientBassGenerator` plays only the root note, repeated for the entire song as a tiled loop.
- Bass note counts are very low (6–22 notes for full-length songs), which is correct for the style,
  but every note is identical in pitch — no harmonic movement whatsoever.
- More critically: the generator only reads `tonalMap.entry(atBar: 0)`, so for songs with
  multi-chord plans (root=b7, root=b6 sections — present in 5 of the 10 songs analysed), the
  bass continues to play the opening chord's root even when the harmony has shifted. This is
  harmonically wrong, not just aesthetically dull.

**Absence of a "melodic moment":**
- All Lead 1 rules (floatingTone, echoPhrase, pentaShimmer) generate notes chosen at random from
  the scale pool. None has an intentional melodic shape — a contour that rises to a peak and
  resolves, or a clear interval identity. The result is pleasant but featureless.
- There is no equivalent of the Kosmic Bridge Melody: a single, shaped, memorable gesture that
  appears once per song and gives the listener something to hold onto.

**Secondary observations:**
- Drums (Percussion Kit, Brush Kit) are now audible following the volume fix — hand percussion
  in particular sounds good. This makes the bass monotony more noticeable by contrast.
- Lead 2 ghost-echo (AMB-SYNC-004) works well and should be preserved.
- Songs with sus2 chord type sound notably brighter and more interesting than minor drone songs
  — harmonic variety at the macro level is already working.

---

### 15.2 Plan A — Bass Root/Fifth Variation (AMB-BASS-003) ✓ DONE

**What:** New bass rule where holds alternate between the chord root (even holds) and the perfect
fifth (root+7 semitones, odd holds). 10% chance any fifth hold becomes a major third instead.
Both intervals stay in the same bass register (MIDI 40–64) as the root. The bass still uses
long holds (32–64 steps) with silences (16–32 steps) between — the character remains drone-like.

**Why the alternating hold approach (vs. the original midpoint plan):** Alternating by hold index
means every chord window gets both the root and fifth visited in proportion to the window length,
regardless of how long the window is. The original plan (place 5th at loop midpoint) could leave
a very long chord window with only root for most of its duration.

**Rarely:** 10% chance on fifth holds of using the major third instead. This is the most affecting
interval in a drone context — brief and harmonically warm.

**Probability distribution (when bass present, i.e. 70% of songs):**
- AMB-BASS-001 (root only): 50%
- AMB-BASS-003 (alternating root + fifth): 50%
- AMB-BASS-002 already gates the 30% absent case before this split

**Files modified:**
- `Sources/Zudio/Generation/Ambient/AmbientBassGenerator.swift` — `useRootFifth` flag, odd-hold fifth logic
- `Sources/Zudio/Generation/SongGenerator.swift` — `AMB-BASS-003` log description added

---

### 15.3 Plan B — Bass Chord-Following Fix ✓ DONE

**What:** `AmbientBassGenerator` now iterates every `TonalGovernanceEntry` in the `tonalMap`
directly. For each chord window it computes the root pitch class from that window's `chordRoot`
degree, generates holds within `[window.startBar * 16, window.endBar * 16)`, then moves on to the
next window. The bass is no longer loop-tiled at all — it produces a single full-song event array.

**Why this approach (vs. the post-tiling re-pitch alternative):** Cleaner and correct by
construction. The loop-tile approach would have required detecting which tiled events fall in which
chord window and re-pitching them — fragile and harder to reason about. Generating per window and
concatenating is straightforward and requires no post-processing.

**Effect:** In a `modalDrift` (i–♭VII–♭VI) song the bass now correctly plays the tonic root
during the i section, drops a whole tone (♭VII) for the second section, and drops again (♭VI) for
the third. Previously it played the tonic root throughout.

**Signature change:** `loopBars` parameter removed. `SongGenerator` assigns the result directly
without calling `AmbientLoopTiler.tile`. Regen path (kTrackBass case) updated to match.

**Files modified:**
- `Sources/Zudio/Generation/Ambient/AmbientBassGenerator.swift` — full rewrite, chord-window iteration
- `Sources/Zudio/Generation/SongGenerator.swift` — removed tile call, updated regen path

---

### 15.4 Plan C — Celestial Phrase (AMB-RTHM-005) ✓ DONE

**What:** A 4–5 note ascending phrase on the Rhythm track using the major pentatonic of the song
key — regardless of the modal context. Deliberately "major feel": ♭7 and minor 3rd of
Dorian/Aeolian are excluded. Pentatonic intervals: root, +2, +4, +7, +9 (1–2–M3–5–6).

**Placement on Rhythm (not Lead 2 as originally planned):** The Rhythm track already generates
melodic content (arpeggios, stochastic phrases); an ascending gesture fits naturally there and
inherits the track's reverb and instrument (Vibraphone, Marimba, Tubular Bells). Named
AMB-RTHM-005 per track-based convention.

**How it sounds:** Picks 4 or 5 ascending consecutive pentatonic notes starting in the lower 55%
of the Rhythm register (MIDI 45–76). Each note held 8–12 steps; 2–4 step gap between notes.
Total phrase ~50–80 steps. Placed at a random offset within the loop — so the phrase returns each
tile cycle at a different position relative to the pads and bass, creating the phase-drift effect
characteristic of the Eno tape-loop aesthetic.

**Velocity:** 33–52, gentle. Emerges softly from the texture; does not dominate.

**Probability:** 5% of Rhythm selections (reduced AMB-RTHM-003 stochastic phrase from 10% to 5%
to make room; silent at 60% unchanged).

**Files modified:**
- `Sources/Zudio/Generation/Ambient/AmbientRhythmGenerator.swift` — `celestialPhrase()` added, `forceRuleID` support, switch-based dispatch
- `Sources/Zudio/Generation/SongGenerator.swift` — log description added

---

### 15.5 Plan D — AMB-LEAD-007: Lyric Fragment (Lead 1 rule, ~5%) ✓ DONE

**What:** A new Lead 1 rule with an intentional melodic arc: low → mid → peak → step-down.
4 notes with a clear contour (not random scale walking). Uses scale tones biased toward the
brighter intervals — degrees 1, 3, 5, 6 (or 1, 2, 4, 5 for sus2 contexts). The peak note sits
a 6th or 7th above the opening note; the final note steps down a 2nd from the peak.

**Timing:** 10–14 steps per note (held, not staccato), 6-step gaps. Total phrase ~72 steps.
One occurrence per loop tile.

**Why:** The existing echo phrase (AMB-LEAD-002) descends with diminishing velocity — it fades
away. The Lyric Fragment ascends toward a peak and has a brief resolution, giving the listener a
moment of arrival rather than pure evaporation. This is the "pretty melody" quality without
imposing a tune — it's more of a contour than a recognisable theme.

**Probability:** 5% of Lead 1 selections (added to pool, reducing floatingTone from 30% to 26%
and echoPhrase from 20% to 19%).

**Files to modify:**
- `Sources/Zudio/Generation/Ambient/AmbientLeadGenerator.swift` — add `lyricalFragment()` function as AMB-LEAD-007, add to roll table

---

### 15.6 Plan E — AMB-RTHM-006: Bell Cell ✓ DONE

**What:** A new Rhythm track rule: a 3-note repeating cell — root → fifth → octave — each note
4 steps long, with long silences (8+ bars) between repetitions. The cell repeats 1–2 times per
loop. With the long reverb on the rhythm track, these three bell-tones bloom into each other and
create a gentle harmonic pillar beneath the texture.

**Note:** AMB-RTHM-003 (stochastic phrase) is already in use; this becomes AMB-RTHM-006.

**Character:** Inspired by the bell gestures in Eno's "Thursday Afternoon" and Craven Faults' use
of sparse melodic elements to punctuate otherwise static textures.

**Files to modify:**
- `Sources/Zudio/Generation/Ambient/AmbientRhythmGenerator.swift` — add `bellCell()` function as AMB-RTHM-006
- `Sources/Zudio/Generation/SongGenerator.swift` — add log description

---

### 15.7 Implementation Order

- Plan B (chord-following bass fix) — ✓ DONE — full-song chord-window iteration, no tiling
- Plan A (AMB-BASS-003 root+fifth drone) — ✓ DONE — alternating holds, 50% probability
- Plan C (AMB-RTHM-005 celestial phrase) — ✓ DONE — ascending pentatonic, 5% on Rhythm track
- Plan D (AMB-LEAD-007 lyric fragment) — ✓ DONE — 4-note arc, 5% on Lead 1
- Plan E (AMB-RTHM-006 bell cell) — ✓ DONE — root→fifth→octave, 4% on Rhythm track

**Build order matters.** Pads must sound right before anything is added. The test gate at Stage 3 is the most important checkpoint — if the pad generator produces monotonous or clashing output, all subsequent stages will sound wrong on top of it.

---

## Part 16: Musical Depth Plans (F–L)

Seven plans to move Ambient from generative texture toward something that feels composed. Each is independent and can be implemented in any order. Simpler plans are listed first.

---

### 16.1 Plan F — Arpeggiated Chord Onsets (Pads)

**Rule:** AMB-PADS-001 enhancement (no new rule ID — modifies existing behaviour)

**What:** When the primary pad chord fires (3–4 notes), stagger note-on times by 1–2 steps per note rather than triggering all simultaneously. The lowest note fires first, then mid, then high — like a slow harp roll. Net duration per note is unchanged.

**Why:** A hard block chord sounds like a keyboard. A rolled chord sounds like breath. The difference is subtle at slow tempos but immediately perceptible to a listener — it removes the "MIDI" quality from pad attacks.

**Parameters:**
- Roll gap: 1–2 steps per note (randomly chosen per reattack)
- Order: always low→mid→high (ascending roll; descending would sound like a fall)
- Probability: apply on 60% of reattacks (40% stay as hard block for variety)

**Files to modify:**
- `Sources/Zudio/Generation/Ambient/AmbientPadsGenerator.swift` — in primary loop, offset `stepIndex` of each note by `rollGap * notePosition` with 60% probability

---

### 16.2 Plan G — Dynamic Arc (Pads + Lead)

**Rule:** AMB-PADS-001 and AMB-LEAD-xxx enhancement

**What:** Apply a song-wide velocity arc: notes in the intro region are softer (−15 velocity), body notes are at full velocity, outro notes taper back down (−15). This replaces the current flat-random velocity with a shaped envelope across the song's duration.

**Why:** Every piece of music has a dynamic shape. Flat dynamics across 20+ bars is the main reason AI-generated ambient sounds mechanical — there's no arc, no arrival, no release. Even a gentle 15-point swell across the body makes the music feel like it's going somewhere.

**Implementation approach:**
- In `AmbientLoopTiler.tile()`, after tiling events, apply a velocity multiplier based on the event's `stepIndex` relative to total song steps
- Or in the post-processing step in `generateAmbient()`, walk `trackEvents[kTrackPads]` and `trackEvents[kTrackLead1]` and scale velocity
- Curve: `factor = introFade(step) * outroFade(step)` where each fade covers the intro/outro bar count
- Clamp final velocity to 20–110

**Files to modify:**
- `Sources/Zudio/Generation/SongGenerator.swift` — post-processing loop after tiling, before harmonic filter
- Or `Sources/Zudio/Generation/Ambient/AmbientLoopTiler.swift` — add optional `dynamicArc` parameter

---

### 16.3 Plan H — Structural Silence (Breath Moment)

**Rule:** No new rule ID — structural post-processing

**What:** Once per song, in the body section, introduce a deliberate 2–4 bar gap in Pads and Lead 1 simultaneously. This is not the existing 30% random skip — it's a coordinated silence chosen at a musically meaningful point (e.g., bar 8–12 of the body). Bass and texture continue through it.

**Why:** Random skips produce occasional short gaps. A coordinated 2–4 bar silence is qualitatively different — it creates a "breath" moment, a point of stillness that makes the listener lean in. When the pads return, they feel like an arrival. Eno's "Discreet Music" and Stars of the Lid both use this technique deliberately.

**Implementation approach:**
- In `generateAmbient()`, after tiling, select a random 2–4 bar window in the body (not in the first or last 4 bars of body)
- Clear all `trackEvents[kTrackPads]` and `trackEvents[kTrackLead1]` events whose `stepIndex` falls in that window (truncating bleed-overs as the X-Files block-clear already does)
- 40% chance the silence occurs (not every song needs it)
- Log the silence bar range in the playback annotations

**Files to modify:**
- `Sources/Zudio/Generation/SongGenerator.swift` — post-processing step after tiling, before harmonic filter; reuse the `clearBlock()` pattern from X-Files injection

---

### 16.4 Plan I — Chord Movement (Mid-Song Shift)

**Rule:** AMB-HARM-001 (new rule category: Harmonic)

**What:** Currently `AmbientStructureGenerator` produces a single chord window for the entire song (or occasionally two). Plan I forces at least one chord change mid-body — a move to a closely related chord (relative major/minor, or a mode-appropriate ii or IV chord). The bass, pads, and lead all follow via the existing `TonalGovernanceMap` architecture.

**Why:** A single sustained chord is the most common weakness in generative ambient. The TonalGovernanceMap and chord-following generators are already built to handle multiple windows — this plan simply ensures they're used. Even a single chord change (e.g., Gm → Bb for 4 bars, then back) creates enormous harmonic interest.

**Parameters:**
- Probability: 50% of songs get a chord shift
- Timing: shift occurs at the halfway point of the body (±2 bars random)
- Duration of shift: 4–8 bars
- Chord options per mode (examples):
  - Dorian: i → IV or i → VII
  - Phrygian: i → II (the characteristic flat-II)
  - Lydian: I → II (the Lydian pivot)
  - Minor: i → III or i → VI
- After the shift, return to the original chord for the final bars + outro

**Files to modify:**
- `Sources/Zudio/Generation/Ambient/AmbientStructureGenerator.swift` — extend chord plan generation to optionally produce 3 windows (tonic → shift → tonic)
- No changes needed in generators — they already follow `TonalGovernanceMap` per window

---

### 16.5 Plan J — Intro/Outro Density Gate

**Rule:** Structural post-processing (no new rule ID)

**What:** Suppress Rhythm and Texture track events that fall within the intro and outro bar ranges. Pads, Bass, Lead 1 remain. This creates a natural thinning at the edges of the song — sparse at the start, full in the body, sparse at the end — mirroring how ambient records are typically structured.

**Why:** Currently all tracks start simultaneously (subject to random rule probabilities). Occasionally Rhythm fires from bar 1, which removes the sense of gradual emergence. The intro/outro fade-in/out on volume is already implemented; this is the complementary arrangement-level version.

**Implementation approach:**
- In `generateAmbient()`, after tiling all tracks:
  - Remove events in `trackEvents[kTrackRhythm]` whose `stepIndex < introEndStep`
  - Remove events in `trackEvents[kTrackTexture]` whose `stepIndex < introEndStep`
  - Remove events in `trackEvents[kTrackRhythm]` whose `stepIndex >= outroStartStep`
  - Remove events in `trackEvents[kTrackTexture]` whose `stepIndex >= outroStartStep`
- This is a simple filter — no generation changes needed

**Files to modify:**
- `Sources/Zudio/Generation/SongGenerator.swift` — 4 filter lines after tiling, before harmonic filter

---

### 16.6 Plan K — Lead 1 Phrase Memory (Returning Motif)

**Rule:** AMB-LEAD-008 (new rule)

**What:** A new Lead 1 rule that selects a short 2–3 note motif (from scale notes) and returns to it at intervals across the loop — approximately every 8–12 bars. Between returns, the track is silent. The motif is always the same pitches but can vary slightly in timing (±2 steps) to avoid mechanical repetition.

**Why:** The existing floating tone and echo phrase rules select notes independently each loop tile. There's no sense that the music "remembers" itself. A returning motif — even just two notes — gives the listener something to hold onto. This is the technique Eno uses in "1/1" (Music for Airports) where the same melodic fragment recurs at irregular intervals.

**Parameters:**
- Motif length: 2–3 notes drawn from lower-middle of scale register
- Note duration: 8–12 steps each
- Return interval: every 8–14 bars (not every loop tile; the motif spans a long loop or is placed directly)
- Timing jitter: ±2 steps per recurrence
- Velocity: consistent per motif (45–60), slightly varying per note
- Probability: 8% of Lead 1 selections

**Files to modify:**
- `Sources/Zudio/Generation/Ambient/AmbientLeadGenerator.swift` — add `returningMotif()` function, add AMB-LEAD-008 to roll table

---

### 16.7 Plan L — Bass Melodic Neighbour Tones (AMB-BASS-001 enhancement)

**Rule:** AMB-BASS-001 enhancement (no new rule ID)

**What:** The existing Loscil drone root holds the root note for 32–64 steps. Plan L gives the bass a small amount of melodic motion: on approximately 20% of holds, after holding the root for half the hold duration, the bass steps to the scale note immediately above or below (±1 scale step), then returns to root for the final portion. The effect is a barely-perceptible melodic inflection — not a melody, just a breath.

**Why:** A completely static bass drone has no character. The Loscil aesthetic uses very slow glides and subtle pitch movement to animate otherwise static tones. A single note a semitone or scale-step away, appearing once every 4–6 minutes, is enough to make the bass feel alive rather than programmed.

**Parameters:**
- Probability: 20% of individual holds in AMB-BASS-001
- Neighbour: ±1 scale step from root (prefers scale tones, avoids chromatic neighbours unless mode requires)
- Split: hold root for first 60% of hold duration, neighbour for next 25%, root again for final 15%
- Velocity: neighbour note is 10 points softer than root note

**Files to modify:**
- `Sources/Zudio/Generation/Ambient/AmbientBassGenerator.swift` — in the AMB-BASS-001 hold loop, add neighbour-tone split with 20% probability

---

### 16.8 Implementation Order

Recommended sequencing based on musical impact vs implementation complexity:

- Plan J (Intro/Outro Density Gate) — highest impact, simplest implementation (4 filter lines)
- Plan H (Structural Silence / Breath Moment) — high impact, uses existing clearBlock pattern
- Plan G (Dynamic Arc) — high impact, post-processing velocity pass
- Plan F (Arpeggiated Chord Onsets) — medium impact, clean change isolated to PadsGenerator
- Plan I (Chord Movement) — highest musical impact, touches StructureGenerator
- Plan K (Lead 1 Returning Motif) — medium impact, new rule in LeadGenerator
- Plan L (Bass Neighbour Tones) — subtle but character-defining, isolated to BassGenerator

Plans J, H, and G together address the most common complaint (flat, undifferentiated texture) and can be done in a single session. Plans I and K require more care but are the most musically transformative.

---

## Title Generator

Deliberately humorous — satirising the pomposity of generative ambient music naming conventions. Where Motorik titles sound industrial and Germanic and Kosmic titles sound astronomical and pretentious, Ambient titles undercut the genre's self-seriousness with mundane British bathos.

Patterns include: *Music for [mundane place]* (parodies Eno's *Music for Airports*), *An Ending ([bureaucratic parenthetical])*, weather + drab UK geography, fake philosophical observations, faux-French neologisms, and Loscil-style corrupted words applied to entirely undramatic subjects.

**Examples:** Music for Dentist Waiting Rooms, An Ending (Awaiting Confirmation), Damp Pavement at Slough, A Meaningful Meeting About Quarterly Targets, Stochastic Patterns for a Slow Elevator, Ambient 4: The One Where Nothing Resolves, Blandeur, Drizzlement

---

## Tonal Consistency Rules (AMB-SYNC)

These rules were derived from the Kosmic coherence analysis (musical-coherence-plan.md, Studies 01–03) and must be applied to Ambient from the start to prevent the class of bugs that required three rounds of post-generation debugging in Kosmic.

**These are not probabilistic firing rules.** AMB-SYNC rules are structural invariants — preconditions and postconditions baked into the generator architecture that hold for every song, every section, every note. They do not appear in the generation log as "fired" events. They are either upheld (invisible) or violated (audible clashes).

---

### AMB-SYNC-001: All scale pools anchor to song tonic — never to chord root

All note-pool derivations (pentatonic, diatonic, modal scale degrees) must use `keySemitone(frame.key)` as the root. When a progression family like `modal_drift` or `drone_two` selects a non-tonic chord root (e.g., a bVII chord in a D major song), generators must still produce notes from D major — not from the bVII chord's local scale. The chord root sets the lowest voice; the upper voices remain in the global key.

Ambient is at higher risk of this bug because `modal_drift` and `drone_two` are common (45% combined), both involving non-tonic chord roots.

---

### AMB-SYNC-002: Bass root must match chord plan at bar boundaries

The bass generator does not independently select root pitches. It receives the chord plan and at each bar boundary must output the chord plan's current root as the bass note. Non-root bass notes are only permitted in the middle of a chord window (as passing color), not at the boundary. In Ambient, where bass drones for 4–8 bars at a time, a wrong root is extremely audible against the pad layer.

---

### AMB-SYNC-003: Lead 1 is the statement — Lead 2 is the response

Lead 1 is the primary floating melody. Lead 2 receives the Lead 1 event array before generating. Lead 2 must never exceed Lead 1 in total note count, must prefer different bar windows, and must sit in a lower register when both play simultaneously. The `lead1Events` parameter must demonstrably affect note placement — not silently ignored as it was initially in Kosmic.

---

### AMB-SYNC-004: No silent parameter discarding

Every generator function that accepts `frame`, `mode`, `key`, or `section` parameters must use them. Every function that receives `frame.mode` must branch on its value; every function that receives a section parameter must produce different output for intro vs. body vs. outro.

---

### AMB-SYNC-005: Key and mode state cleared after generation

`keyOverride`, `moodOverride`, and `tempoOverride` must be set to `nil` after song generation completes. In Ambient this is especially damaging because the pool of musically interesting keys is narrow — any accidental lock-in makes all songs sound identical.

---

### AMB-SYNC-006: Per-track density caps

Hard ceilings enforced via labeled `break` or early return — not probabilistic thinning:
- Lead 1: 2.0 notes/bar maximum in body sections
- Lead 2: 1.2 notes/bar maximum
- Rhythm (when present): 3.0 notes/bar maximum
- Pads primary layer: 4 re-attacks per bar maximum
- Texture: 1.5 notes/bar maximum

---

### AMB-SYNC-007: Acoustic/electronic instrument pairing per song

After instrument selection, verify the 7-track assignment includes at least one acoustic instrument (strings, woodwinds, bells, Cello, Brush Kit) and one electronic (pad presets, FX class, Moog Bass, Synth Bass). If all fall into the same family, override Lead 2: all-electronic → Vibraphone (11); all-acoustic → Warm Pad (89).

---

### AMB-SYNC-008: Harmonic consonance floor per track

Bass and pads target >92% harmonic consonance. Leads can run 75–85% but should not fall below 70% except in `dissonant_haze` mode. Verify via MIDI batch analysis before deployment — coherence bugs are invisible in code and only surface in generated output.

---

### AMB-SYNC-009: Pads and bass use the same chord root within any bar

At every bar boundary, the lowest note of the pad voicing must match the bass note (same pitch class, any octave). Bass generator receives the chord plan directly and derives its root from the same object the pad generator reads — no independent root selection.

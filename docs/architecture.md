# Zudio Architecture
Copyright (c) 2026 Zack Urlocker

Zudio is a native macOS application that generates original music in three styles — Motorik,
Kosmic, and Ambient — using a rule-based generation engine. Every song is built from a set of
human-curated musical rules derived from analyzing real artists. There is no AI or machine
learning involved: the system applies probabilistic rule selection within a tightly controlled
harmonic framework.

One click generates a complete song. Songs can be played back immediately, exported as a
multi-track MIDI file for editing in any DAW, or exported as an M4A audio file. Individual
tracks can be regenerated independently without touching the rest of the song.

This document describes the oveall architecture. There is a separate detailed implementation.md plan and detailed plans on each of the musical styles: Motorik, Kosmic, Ambient.

---

## Technology Foundation

- **Language**: Swift, targeting macOS 13+
- **UI**: SwiftUI
- **Audio**: AVAudioEngine + AVAudioUnitSampler (Apple's built-in audio graph). No third-party
  audio libraries. This keeps the dependency footprint minimal and makes the codebase portable
  to iOS without changes to the audio layer.
- **Soundbank**: GS MIDI (bundled open-source soundbank). This replaces Apple's default DLS
  soundbank and provides significantly better instrument quality across the full GM2 range.
- **MIDI**: All notes are internally represented as MIDI events and fired directly to samplers
  at playback time. There is no live MIDI input or output to external hardware.

The native Apple stack was chosen over alternatives like AudioKit or JUCE because it has no
external dependencies, is App Store compatible, and the SwiftUI/AVAudioEngine combination
will port directly to an iPad/iPhone version with minimal rework.

---

## Core Generation Pipeline

Song generation runs as a deterministic 10-step pipeline. Given the same seed and overrides,
the pipeline always produces the same song.

```
1. Musical Frame     — key, mode, tempo, mood, total bars, loop lengths
2. Song Structure    — sections (intro / A / B / bridge / outro), chord plan
3. Tonal Map         — per-bar chord windows with note pools for each track role
4. Per-track loops   — each generator produces a short loop (e.g. 7 bars)
5. Loop tiling       — loops tiled to full song length (Ambient); or full-song
                       generation (Kosmic/Motorik)
6. Post-processing   — dynamic arc, density gating, harmonic filtering
7. Step annotations  — bar markers for status log playback feed
8. Generation log    — human-readable list of rules applied (written to status box
                       and to the MIDI log file on export)
9. SongState         — all of the above packaged into a single immutable struct
10. Playback load    — SongState handed to PlaybackEngine; pre-computes note-off map
```

**Seeded RNG**: Generation uses SplitMix64, a fast deterministic pseudo-random number generator.
The global seed is a random UInt64 chosen at generation time; per-track seeds can differ when
individual tracks are regenerated. Both the global seed and any per-track override seeds are
written to the companion `.txt` log file saved alongside each MIDI export. **Load Song**
(File menu, ⌘L) reads the seed from a log file and replays it through the same deterministic
generator, reproducing the song exactly.

**SongState** is the single source of truth for a loaded song. It is an immutable Swift struct
containing the musical frame, structure, tonal map, all track events, the generation log, and
live step annotations. Playback, export, and UI all read from SongState; nothing mutates it
during playback.

**Key data types**:
- `GlobalMusicalFrame` — key, mode, tempo, total bars, mood
- `SongStructure` — array of `SongSection` (startBar, length, label, intensity) + chord plan
- `ChordWindow` — a time range with a root chord, chord type, and three note pools
  (chord tones, scale tensions, avoid tones)
- `TonalGovernanceMap` — maps every bar to its active `ChordWindow`
- `MIDIEvent` — note number, velocity, step index, duration in steps

---

## Playback Engine

The playback engine is a step sequencer running at the song's tempo. One "step" equals one
sixteenth note. The timer fires at the correct interval for the current BPM and processes all
events scheduled for that step.

**Per-track signal chain**:
```
AVAudioUnitSampler → boost (volume/pan) → reverb → delay → master mixer
```

Additional per-track effects available:
- **Tremolo**: LFO modulates the boost node's volume at 0.1–4 Hz
- **Sweep filter**: LFO modulates a low-pass filter cutoff frequency
- **Space echo**: tap-tempo delay with moderate feedback
- **Static pan**: fixed left/right placement set once at style load time (used for
  Kosmic and Motorik to widen the stereo image across tracks)

**Note-off scheduling**: At song load time, a `noteOffMap` is pre-computed: a dictionary keyed
by step index containing all note-offs due at that step. This avoids creating a new
`DispatchWorkItem` for every note-on during playback — a significant CPU saving at 9 steps/second
across 7 tracks.

**LFO consolidation**: All tremolo and sweep LFOs share a single 16ms timer rather than
separate `DispatchSourceTimer` instances per effect. The consolidated timer processes all
active LFO channels in one dispatch.

**Transport**: Play, stop, and seek-by-bar are supported. The DAW scroll view auto-advances
during playback, keeping the playhead visible. Live bar annotations are emitted to the status
log as playback reaches each annotated step.

---

## UI Architecture

```
TopBarView
  ├── Logo + version + TEST badge
  ├── Transport controls (⏮ ◀ ▶ ■ ▶ ⏭)
  ├── Generate / Save MIDI / Export Audio buttons
  ├── Style selector (Ambient / Kosmic / Motorik)
  ├── Mood, Key, BPM overrides
  └── Help / About

ContentView
  └── 7 × TrackRowView
        ├── Track icon + label
        ├── ◀ Instrument name ▶  (cycles GM program)
        ├── M / S / ⚡ buttons   (mute / solo / regenerate)
        ├── Effects chips        (reverb, delay, tremolo, sweep, pan, space…)
        └── MIDILaneView         (piano-roll visualization)

StatusBoxView
  └── Scrolling status log (generation rules + live bar annotations)
```

**MIDILaneView** is split into two layers for performance:
- `NoteLayerView` (Equatable): draws all note rectangles and bar lines. SwiftUI compares
  its inputs before re-rendering; when only the playhead position changes (every tick), this
  layer is skipped entirely. It only redraws on song load, track regen, or DAW scroll.
- Playhead Canvas: a tiny Canvas view that redraws every tick — just one rectangle and an
  optional triangle handle.

**Drum lane display**: Drum tracks use a pitch-to-row mapping instead of a chromatic piano roll.
Standard GM kit sounds (kick, snare, hats, toms, cymbals) and hand percussion instruments
(congas, bongos, shaker, maracas, claves, triangle) each have a fixed vertical position in
the lane so the visual rhythm pattern is readable.

---

## Musical Foundation (shared across styles)

All three styles share the same harmonic framework.

**Modes**: Ionian (major), Dorian, Mixolydian, Aeolian (natural minor), Minor Pentatonic,
Major Pentatonic. Each song is assigned one mode at generation time. The mode determines which
scale degrees are "safe" (chord tones), "colorful" (scale tensions), and "avoid" (chromatic tones).

**Tonal Governance Map**: Every bar is mapped to a `ChordWindow` — a chord root, chord type,
and three note pools. Each track generator draws from the pool appropriate to its musical role:
- Bass and Rhythm: chord tones only (highest consonance)
- Pads: chord tones + some scale tensions
- Leads and Texture: full scale tensions allowed

**Note pool selection** respects register bounds per track (e.g. bass stays below middle C,
leads stay in the upper two octaves) and avoids chromatic tones entirely except for deliberate
color notes in the Ambient style's dissonant-haze family.

**Mood** (dark, bright, melancholic, hypnotic, neutral) biases mode selection and tempo range
at generation time. **Key** and **tempo** can be locked by the user from the UI.

---

## Audio Effects

Each track has an independent signal chain with per-track controls for the following effects.
All processing uses Apple's built-in AVAudio effect nodes — no third-party DSP libraries.

- **Boost**: Per-track gain and pan adjustment. Static pan values are also set here at song load
  time to widen the stereo image across tracks.
- **Reverb**: Convolution reverb that adds space and depth. Short pre-delay keeps it clean for
  rhythmic tracks; longer settings blur Ambient pads into a continuous wash.
- **Delay**: Tempo-synced single echo with adjustable feedback. Used on melodic tracks to extend
  phrases without adding density.
- **Space Echo**: A longer multi-tap delay with moderate feedback. Creates a wash of echoing
  repeats that fills the background without adding new pitches. Used on Pads and Texture tracks.
- **Sweep**: An LFO-driven low-pass filter whose cutoff slowly opens and closes, creating a
  cycling timbral shift (the "filter sweep" sound common in electronic music). Rate and depth are
  set per track.
- **Tremolo**: An LFO that modulates the track's volume at 0.1–4 Hz, creating rhythmic pulsing
  at fast rates or slow, breath-like undulation at slow rates.
- **Auto-Pan** (also known as ping pong): A fixed left/right stereo placement applied once at
  song load time. Used to spread tracks across the field rather than as a moving effect.

All three styles use the same effect nodes, but parameter settings differ significantly.
Ambient uses longer reverb tails, higher delay feedback, and more extreme space echo settings
to create the characteristic suspended, dissolving quality of the style.

Effect chips are shown on each track row in the UI as small labeled buttons; active effects are
highlighted. The user can toggle effects on and off per track at any time during playback.

---

## Motorik Style

Inspired by: Neu!, Kraftwerk, Harmonia, Can, Deluxe

**Character**: Propulsive, driving, outward energy. The kick drum is the anchor. Everything
else locks to the groove.

**Tempo**: 126–154 BPM

**Song structure**: Three forms — *single A* (45%, one continuous groove section), *subtle A/B*
(40%, a second section with a mode shift and higher intensity), *moderate A/B* (15%, A + B
with an optional A' reprise at the end). No bridge — that is Kosmic-only. Drum fills occur
approximately every 8 bars and are locked to the bass/kick pattern to avoid clashes.

**Motorik rules** — 50 rules were created by analyzing real-world Motorik songs. Some example rules are:
- `Drums  DRUM-001 classic Motorik beat` — kick on beats 1 and 3, snare on 2 and 4, closed hat on every 8th note
- `Drums  DRUM-004 open groove` — kick on beat 1 only, open hi-hat on offbeats, snare on 3
- `Bass   BASS-004 Berlin school pulse` — root note on beat 1, fifth on beat 3, 8th-note feel
- `Bass   BASS-007 syncopated walk` — root with off-beat approach notes, occasional octave jump
- `Lead1  LD1-003 sparse arc` — 2–4 notes per bar, melodic arc rises toward body section peak then falls in outro
- `Pads   PADS-002 chord stab` — short chord stabs on beats 2 and 4, emphasizing backbeat

**Instrument palette**:
- Lead 1: Square Lead, Mono Synth, Synth Brass, Fifths Lead, Moog Lead, Overdrive Gtr
- Lead 2: Brightness, Vibraphone, Bell/Pluck
- Pads: Warm Pad, Halo Pad, New Age Pad, Sweep Pad, Bowed Glass, Synth Strings, Organ Drone
- Rhythm: Guitar Pulse, Wurlitzer, Rock Organ, Clavinet, Electric Piano, Muted Guitar
- Texture: Halo Pad, Warm Pad, Space Voice, Swell, FX Atmosphere, FX Echoes
- Bass: Moog Bass, Lead Bass, Analog Bass, Electric Bass
- Drums: Rock Kit, 808 Kit, Brush Kit

**Static pans**: Lead 1 −0.07, Lead 2 +0.07, Pads −0.20, Rhythm +0.20 to widen the mix.

**Default effects**: Lead 1 — delay; Rhythm — delay; Pads — space echo; Texture — auto-pan.
Lead 2, Bass, and Drums have no effects on by default, keeping the low end dry and the rhythm
tight.

---

## Kosmic Style

Inspired by: Jean-Michel Jarre, Tangerine Dream, Vangelis, Klaus Schulze, Electric Buddha Band

**Character**: Immersive, inward, spacious. The arpeggio sequencer replaces the drum kit as the
primary pulse. Drums are optional. Chords change slowly — sometimes not at all for 32 bars.

**Tempo**: 95–126 BPM

**Song structure**: Three forms — *single evolving* (50%, one long section with gradual textural
change), *two-world* (35%, two contrasting sections A and B), *build-and-dissolve* (15%, rises
to a peak then collapses). A/B songs have a 35% chance of including a bridge between the A and B
sections. Three bridge archetypes:
- *A-1 escalating drum bridge* (4–8 bars): intensity builds through a drum-driven crescendo
  before dropping into the B section (Mister Mosca style)
- *A-2 call-and-response bridge* (4–8 bars): sparse hits create space for a call-and-response
  exchange between instruments (Caligari Drop style)
- *Melody bridge* (8–24 bars): a longer lyrical melodic statement, with pre-ramp and post-ramp
  transition sections on either side (Dark Sun style)

Chord changes happen every 8–32 bars via one of five **progression families**:
- `static_drone` — single chord held for the entire song
- `two_chord_pendulum` — two chords alternating every 8–16 bars
- `modal_drift` — slow stepwise movement through the mode's degrees
- `suspended_resolution` — sus chords that slowly resolve
- `quartal_stack` — stacked fourths for an open, spacious feel

A detailed specification of the Kosmic style — including progression families, bridge designs,
instrument choices, and rule rationale — is documented in `docs/kosmic-plan.md`.

**Kosmic rules** — 44 rules were created by analyzing real-world Kosmic songs. Some example rules are:
- `Arp    KOS-ARP-001 JMJ ascending 4-note` — four chord tones in ascending order on a 16th-note grid, looping every 1–2 bars
- `Arp    KOS-ARP-003 skip pattern` — chord tones with occasional skipped steps and velocity accent on beat 1
- `Pads   KOS-PADS-003 swell hold` — whole-bar sustains with slow velocity ramp up, reverb tail carries between bars
- `Bass   KOS-BASS-002 Moroder drift` — root held 2–4 bars with occasional step movement to fifth or subtonic
- `Drums  KOS-DRUM-001 absent` — no percussion; arpeggio carries all rhythmic content

**Instrument palette**:
- Lead 1: Ocarina, Flute, Whistle, Calliope Lead, Soft Brass
- Lead 2: Brightness, Warm Pad, Halo Pad, New Age Pad, Ocarina
- Pads: Choir Aahs, String Ensemble, Synth Strings, Warm Pad, Space Voice
- Rhythm: FX Crystal, Vibraphone, Elec Piano 2, Church Organ, Tremolo Strings
- Texture: FX Atmosphere, Pad 3 Poly, Sweep Pad
- Bass: Moog Bass, Synth Bass 1, Fretless Bass
- Drums: Brush Kit, 808 Kit, Machine Kit, Standard Kit

**Static pans**: Lead 1 −0.15, Lead 2 +0.15, Rhythm +0.22, Texture −0.22.

**Default effects**: Lead 1 — delay + space echo; Lead 2 — space echo; Pads — space echo +
delay; Rhythm — delay; Texture — delay + space echo; Bass — reverb. The heavy use of space
echo on melodic tracks reflects the style's emphasis on sustain and depth over attack.

---

## Ambient Style

Inspired by: Brian Eno, Loscil, Craven Faults, Stars of the Lid, Electric Buddha Band

**Character**: Stasis with microscopic evolution. No felt pulse. Texture and space are the
primary musical elements. Changes happen over minutes, not bars.

**Tempo**: 66–92 BPM (though tempo is rarely felt as a beat)

**Co-prime loop architecture**: Each track generates a short loop of a different length
(e.g. Pads = 7 bars, Bass = 11 bars, Lead = 9 bars). Because these lengths share no common
factors, the combination cycle is extremely long — the full pattern never repeats within a
normal song. This creates continuous subtle variation from a small amount of generated material,
directly inspired by Brian Eno's tape-loop phase technique.

**Song forms**:
- `pureDrone` (40%) — no intro or outro; body occupies the full song
- `minimalArc` (45%) — 4-bar fade-in intro and fade-out outro
- `breathingArc` (15%) — 6-bar intro and outro for a more pronounced envelope

**Post-processing passes** applied after track generation:
- *Dynamic arc*: Pads and Lead 1 velocities are scaled down in intro and outro (72% of body
  level), creating a natural volume envelope across the song
- *Breath silence*: 40% chance of a coordinated 2–4 bar silence in both Pads and Lead 1
  simultaneously, in the body section — gives the song room to breathe
- *Intro/outro density gate*: Rhythm and Texture tracks are stripped from intro and outro
  steps, keeping the edges sparse
- *Mid-song chord shift*: For single-chord song families, a 50% chance of injecting a 4–8 bar
  harmonic excursion (e.g. bVII) in the middle third of the song, then returning to tonic

A detailed specification of the Ambient style — including co-prime loop design, post-processing
passes, song form rationale, and rule development — is documented in `docs/ambient-plan.md`.

**Ambient rules** — 32 rules were created by analyzing real-world Ambient songs. Some example rules are:
- `Pads   AMB-PADS-003 inversion rotation` — chord voiced in rotating inversions each loop pass; notes arpeggiating on entry rather than attacking simultaneously
- `Pads   AMB-PADS-006 bell accent` — sparse single-note bell accents on strong chord tones, avoiding steps near primary chord attacks
- `Bass   AMB-BASS-001 root drone neighbour` — root note held 4–8 bars; 20% chance of a scale-step neighbour-tone inflection on long notes
- `Lead1  AMB-LEAD-008 returning motif` — a 2–3 note motif established in bar 1–8, then recurring every 8–14 bars with slight timing jitter (±2 steps)
- `Drums  AMB-DRUM-004 hand percussion` — congas and bongos on syncopated 16th-note positions; shaker or maracas 8th-note pulse; sparse claves or triangle accents

**Drum kit options**: Percussion Kit (standard GM hand percussion sounds) and Brush Kit
(substitutes maracas for shaker pulse, open triangle for claves). Switching kits during
playback remaps the relevant MIDI note numbers in the existing events without regenerating
the track.

**Instrument palette**:
- Lead 1: Flute, Ocarina, Pan Flute, Whistle, Recorder, Brightness, Halo Pad, New Age Pad, Calliope Lead
- Lead 2: Vibraphone, Celesta, Glockenspiel, Grand Piano, Warm Pad, Space Voice, FX Atmosphere
- Pads: String Ensemble, Choir Aahs, Synth Strings, Bowed Glass, Warm Pad, Halo Pad, New Age Pad, Sweep Pad
- Rhythm: Vibraphone, Marimba, Tubular Bells, Glockenspiel, FX Crystal, FX Echoes, Church Organ
- Texture: String Ensemble 2, Bowed Glass, Choir Aahs, Space Voice, FX Atmosphere, Sweep Pad, Pad 3 Poly
- Bass: Cello, Contrabass, Moog Bass, Synth Bass 1, Fretless Bass
- Drums: Percussion Kit, Brush Kit

**Default effects**: Lead 1 — delay + space echo; Lead 2 — delay + space echo; Pads — space
echo + tremolo; Rhythm — delay + reverb; Texture — space echo + auto-pan; Bass — reverb +
sweep; Drums — delay + reverb. Almost every track carries reverb or space echo, and the
parameter settings use longer tails and higher feedback than the other styles — the goal is
a sound that never fully decays.

---

## Rules System and Quality Assurance

**Rule IDs**: Every significant generation decision is tagged with a unique rule ID (e.g.
`KOS-BASS-002`, `AMB-LEAD-008`, `DRUM-001`). These IDs are written to the in-app status log
during playback and to a text log file alongside every MIDI export. Rule IDs make it possible
to identify exactly which rules produced a given song and to trace problems back to specific
generator code.

**Test mode**: A short-song mode that cycles through a fixed 12-slot rotation. Recently added
or changed rules are placed in the high-rotation slots, ensuring they are heard on every few
generations rather than only when their probability is selected at random. Test mode is
toggled with ⌘T.

**Song analysis loop**: The primary quality assurance method is:
1. Generate a batch of 10–15 songs
2. Export MIDI files and log files for each
3. Analyze with Claude: check modal consonance, lead density, rhythm balance, clashes
4. Identify bugs and musical problems
5. Update rules, fix generators, re-run

The methodology, metrics, and findings from completed analysis rounds are documented in
`docs/musical-coherence-plan.md`.

**Metrics tracked**:
- *Modal consonance*: percentage of note events whose pitch class belongs to the active mode's
  scale. Targets: Bass >92%, Leads >72–80%, Pads >85%
- *Lead overlap rate*: percentage of steps where both Lead 1 and Lead 2 are playing
  simultaneously. Target <30%
- *Chord window length*: minimum bars held per chord. Target: Kosmic ≥4 bars
- *Lead density arc*: notes-per-bar should be lower in intro and outro than in the body section

**Example findings from coherence studies**:
- *Kosmic Study 02*: `pickChordRoot` was hardcoded to use Aeolian degree weights for all modes,
  causing 28–40% consonance scores in Ionian and Dorian songs. Fixed by making root selection
  mode-aware.
- *Motorik Study 01*: Drum fills were firing every 4 bars (11–22 fills per song). Halved the
  rate to every 8 bars and reduced the proportion of three-beat fills.
- *Ambient pads*: A bell accent cluster was landing at the same step as the primary chord
  attack on certain bars due to loop tiling alignment. Fixed with a ±8 step exclusion zone
  around primary chord onset steps.

---

## Performance

Three specific optimizations were introduced to reduce CPU load during sustained playback
(which otherwise reached 50%+ for Ambient/Kosmic songs with many active effects):

- **NoteLayerView equatable optimization**: The SwiftUI piano-roll is split into a note-drawing
  layer (`NoteLayerView`, conforms to `Equatable`) and a playhead canvas. SwiftUI compares
  `NoteLayerView`'s inputs before re-running its body. Since the playhead position (`currentStep`)
  is not an input to `NoteLayerView`, the O(N) note drawing is skipped on every tick — it only
  runs on song load, track regeneration, or DAW scroll.

- **Pre-computed note-off map**: At song load time, all note-off events are pre-computed into a
  dictionary keyed by step index. During playback, the engine looks up `noteOffMap[step]` rather
  than scheduling a new `DispatchWorkItem` for every note-on. This eliminates 150–250 async
  closures per second at typical song densities.

- **Consolidated LFO timer**: All active tremolo and sweep LFOs share a single 16ms
  `DispatchSourceTimer` instead of one timer per active effect. This reduces the number of
  concurrent timers from up to 12 to exactly 1, and cuts main-queue dispatches from 240+/second
  to 60/second.

---

## Future Development

- **iPad / iPhone port**: The entire SwiftUI + AVAudioEngine stack is iOS-compatible. The main
  work required is a touch-optimized layout (larger tap targets, scrollable track area, adapted
  transport controls) and handling the iOS audio session lifecycle. No changes to the generation
  engine or playback engine are anticipated. A detailed plan including layout proposals is
  documented in `docs/ios-ipad-plan.md`.

- **Fluid soundbank upgrade**: Replacing the GS MIDI soundbank with Fluid R3 (or a comparable
  high-quality open-source soundbank) would significantly improve instrument quality, particularly
  for strings, woodwinds, and pitched percussion. The sampler loading code is isolated to a single
  function and the swap would be straightforward.

- **Additional rules**: Planned areas include more harmonic sophistication (secondary dominants,
  modal interchange, chord substitutions), additional lead melodic shapes for Kosmic and Ambient,
  more Motorik rhythm variations, and expanded hand percussion patterns for Ambient.

- **Continuous play / evolution mode**: A mode where the song evolves in real time without
  stopping — parameters drift gradually, new loops phase in, sections transition seamlessly.
  This was designed in `docs/continuous-play.md` but is not yet implemented.

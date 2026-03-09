# Zudio Prototype Direction

## Core musical model

Zudio should be oriented around visible, editable song parts instead of a purely passive ambient generator.

- Track parts
  - Lead 1
  - Lead 2
  - Pads
  - Rhythm
  - Texture
  - Bass
  - Drums
- Global musical controls
  - Pace (simple tempo preset, with optional BPM fine tuning)
  - Key
  - Mood (instead of scale)
  - Style (ambient / motorik variants)

## Product intent

- Keep the ambient-first aesthetic, but allow more direct composition and arrangement control.
- Make the structure of the piece legible on screen at all times.
- Let users shape each part independently while preserving coherent overall output.

## Interaction concept (v1)

- A multi-lane timeline or pattern grid with one lane per part: Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums.
- Per-track controls for activity, density, variation, and mute/solo.
- Global controls always visible: Style, Mood, Pace, Key.
- Primary action: `Generate` creates a full song state across all tracks using current global controls.
- Global transport includes a `Play` control shown as a green arrow.
- One-click regenerate options:
  - Regenerate single track
  - Regenerate all tracks while preserving style/mood/pace/key

## Design (v1 layout and UX structure)

- Screen layout is organized into three vertical zones below a global top bar:
  - Left: track rows with track-level controls
  - Middle: DAW-like grid/piano-roll visualization and note editing surface
  - Right: per-track effect controls and quick effect actions
- Top global bar contains:
  - Primary action: `Generate`
  - Global selectors: `Style`, `Mood`, `Pace`, `Key`
  - Secondary actions: `Regenerate Track`, `Regenerate All`, `Seed/Recall`
  - Global display/readouts: current seed, song length, master transport state
- Left track-control column (one row per track: Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums):
  - Track name and color
  - Instrument selector (`Auto` or manual)
  - Activity/Density/Variation controls
  - Mute/Solo and track regenerate button
- Middle composition surface:
  - Horizontal timeline for loop/song progression
  - Piano-roll/grid notes per track lane (drums may use lane-per-hit view)
  - Visual cues for motif repeats and variation points
  - Lightweight edit operations: drag note, lengthen/shorten, velocity accent, erase/add note
- Right effects column:
  - Per-track effect character controls (`Space`, `Echo`, `Width`, `Grit`, `Tone`) with context-aware subsets
  - Quick presets per track (for example `Dry`, `Wide`, `Hazy`, `Punchy`)
  - Simple on/off and depth controls, avoiding full plugin parameter surfaces in v1
- Interaction principles:
  - One-click generation always produces a complete song state.
  - UI should make structure visible first, detail second.
  - Advanced controls stay collapsible so first use remains simple.

## Track instrument options (v1)

- Each track should have an `Instrument` selector with a small curated set.
- Instrument choices should be style-aware and mood-aware, so only compatible options are emphasized.
- Suggested instrument pools:
  - Lead 1
    - Synth lead
    - Electric guitar-like lead
    - Brass-synth lead
    - Piano
    - Rhodes-style electric piano
  - Lead 2
    - Secondary synth lead
    - Guitar-like counter line
    - Bell/pluck tone
    - Soft brass counter voice
  - Pads
    - Warm analog pad
    - Glass/digital pad
    - String ensemble pad
    - Choir/air pad
    - Organ-like drone pad
  - Rhythm
    - Muted electric guitar pulse
    - Sequenced mono synth pulse
    - Arpeggiated poly synth
    - Processed electric piano pulse
  - Texture
    - Noise/swell bed
    - Field-noise layer
    - Metallic/percussive FX layer
    - Tape/air texture layer
  - Bass
    - Analog synth bass
    - FM/digital synth bass
    - Electric bass guitar
    - Upright bass
    - Cello-like low bowed voice
  - Drums
    - Vintage electronic kit
    - Modern electronic kit
    - Jazz kit
    - Rock kit
- UX simplification:
  - Show one default instrument per track when `Generate` is pressed.
  - Allow optional manual override per track.
  - Keep an `Auto` mode that reselects instruments during regeneration.

## Track effects approach (v1)

- Avoid full effect-chain editing in v1.
- Use per-track `Effect Character` presets with 1-2 depth knobs, so users get musical results without technical setup.
- Keep a small shared effect vocabulary across tracks:
  - Space (reverb/room)
  - Echo (delay)
  - Width (stereo spread/chorus-like motion)
  - Grit (saturation/distortion tone)
  - Tone (dark/bright filtering)
- Suggested defaults by track:
  - Lead 1: Echo, Space, Grit/Width (style-dependent)
  - Lead 2: Echo, Width, Tone (lower density than Lead 1)
  - Pads: Space, Width, Echo
  - Rhythm: Tone, Width, Echo (tempo-locked)
  - Texture: Space, Width, Tone (very low rhythmic density)
  - Bass: Tone, Grit, Space (subtle)
  - Drums: Tone, Space, Grit
- Advanced mode later can expose true effect modules (reverb, delay, chorus, distortion) per track.

## One-button generate rules (musical coherence)

- Goal: pressing `Generate` should output a full, stylistically coherent song state in one pass.
- Use a fixed generation order so dependencies are stable:
  - 1. Global plan (style, mood, pace, key, seed, loop/song length)
  - 2. Lead 1 motif plan
  - 3. Lead 2 counter-motif plan
  - 4. Pads harmonic-bed plan
  - 5. Rhythm ostinato plan
  - 6. Texture-event plan
  - 7. Bass anchor plan
  - 8. Drums groove plan
  - Internal dependency build still starts from drums+bass+rhythm, then applies pads/lead layers.
- All tracks inherit one shared harmonic map and timeline length:
  - Chord movement complexity depends on style (ambient = slower changes, motorik = tighter loop)
- Rhythm rules:
  - Drums define primary grid and density target.
  - Bass can syncopate but must anchor key downbeats or phrase boundaries.
  - Rhythm track repeats short 1-2 bar motifs with small per-section variation.
  - Lead 1 rhythmic density is capped relative to pads/bass to avoid crowding.
  - Lead 2 uses lower density and avoids simultaneous accents with Lead 1 on most strong beats.
  - Texture remains sparse and is weighted toward section boundaries.
- Harmonic rules:
  - Bass mostly uses chord tones and permitted passing tones for selected mood.
  - Rhythm pattern favors chord tones or single-note ostinato tied to tonal center.
  - Pads own chord identity; Lead 1 prefers chord tones on strong beats.
  - Lead 2 should emphasize complementary intervals (third/sixth/octave or contrary motion) against Lead 1.
  - Texture should be mostly non-harmonic or drone-compatible to avoid tonal clutter.
  - If mood is `Free`, constrain interval leaps and avoid strong tonal cadences.
- Register and space rules:
  - Lead 1 sits above pads unless intentionally swapped by preset.
  - Lead 2 sits either just below or just above Lead 1 with automatic spacing offsets.
  - Pads occupy mid/high sustained range.
  - Rhythm sits low-mid or mid range and avoids masking lead formants.
  - Texture occupies spectral edges and avoids dominant midrange masking.
  - Bass stays in low register lane.
  - Drums remain mostly broadband transient content with controlled cymbal highs.
  - Auto-EQ spacing targets reduce masking across Lead 1/Lead 2/Pads/Rhythm/Texture/Bass/Drums.
- Instrument/effect compatibility rules:
  - Style selects preferred instrument families per track.
  - Effect defaults are style-weighted (for example more space in ambient, tighter drums in motorik).
  - If user manually selects an instrument, keep it and adapt pattern/effects around it.
- Variation rules:
  - Per section, only change 1-2 dimensions per track (rhythm, note choice, articulation, effect depth).
  - Keep motif memory so Lead 1/Lead 2/Pads/Rhythm/Texture/Bass/Drums feel related across sections.
  - Prevent abrupt jumps by smoothing parameter deltas at section boundaries.
- Safety rules:
  - Density ceiling per track and global ceiling to avoid over-busy results.
  - Collision checks: if Lead 1 and pads conflict heavily, simplify Lead 1 first; if Lead 1 and Lead 2 conflict, thin Lead 2 first.
  - Deterministic replay: same seed + same controls => same output.

## Motorik most of it’s shot in Baie d’uffe but there are a few scenes downtownation Spec (Consolidated v1.0)

This is the implementation source of truth for Motorik. It consolidates prior Motorik sections in this document.

- Target references used for rule design
  - Neu!: `Hallogallo`, `Fur Immer`, `Neuschnee`
  - Harmonia: `Deluxe`, `Walky-Talky`, `Monza`
  - Kraftwerk calibration: `Autobahn` (instrumental behavior), `Aero Dynamik`, `Endless Endless`
- Canonical track order
  - Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums

### Global profile

- Tempo
  - Default: 138 BPM
  - Allowed: 126-154 BPM
  - Meter: fixed 4/4
- Tonality
  - Mood default: `Deep` (primary), `Dream` (secondary)
  - Key-center probabilities (Motorik default pool):
    - E: 30%
    - A: 20%
    - D: 15%
    - G: 10%
    - C: 10%
    - B: 8%
    - F#: 7%
  - Mood probabilities (Motorik):
    - Deep: 55%
    - Dream: 30%
    - Bright: 15%
  - Harmonic mode probabilities:
    - Static center: 65%
    - Slow shift: 30%
    - Free drift: 5%
  - Motorik progression family probabilities:
    - Static tonic hold (I or i): 35%
    - Two-chord alternation (I-bVII): 30%
    - Minor loop (i-VII or i-VI): 20%
    - Modal rock cadence (bVI-bVII-I): 15%
- Song duration and form
  - Length target: 3:30-6:30 (center near 4:45)
  - Form probabilities:
    - Single-A continuity: 45%
    - Subtle A/B: 40%
    - Moderate A/B: 15%

### Core musical behavior

- Drums
  - Pattern family probabilities:
    - Core motorik pulse: 55%
    - Accent variation: 30%
    - Sparse variant: 15%
  - Structural rules:
    - Kick: 4-on-floor default
    - Snare: 2/4 default
    - Hat/cymbal: steady subdivision
    - Fill limit: maximum 1 short fill per 16 bars
- Bass
  - Pattern family probabilities:
    - Root/fifth anchor: 50%
    - Anchor + sparse passing tone: 35%
    - More syncopated anchor: 15%
  - Writing rules:
    - Phrase length: 1-2 bars
    - Repetition target: 70-90% repeated cells per 16 bars
    - Passing tones: max 1-2 per bar
    - Register: low lane, minimal octave jumping
- Rhythm
  - Writing rules:
    - 1-2 bar ostinato, repeat-first behavior
    - 8th/16th pulse bias, minimal syncopation
    - Single-note or dyad-centric voicing
    - No riff-like fills; only accent/timbre shifts
- Lead 1
  - Writing rules:
    - Motif-first behavior, 2-6 note motifs
    - Phrase length 1-2 bars
    - Mostly stepwise/small intervals
    - One changed note/rhythm event every 4-8 bars
    - No high-density run longer than 2 bars
- Lead 2
  - Entry timing probabilities:
    - Enter at bar 8: 60%
    - Enter at bar 16: 40%
  - Writing rules:
    - 30-60% of Lead 1 event density
    - Secondary response role, not co-lead
    - Response-mode probabilities:
      - Off-beat echo response: 50%
      - Interval complement (3rd/6th/octave): 35%
      - Sparse unison punctuation: 15%
- Pads
  - Writing rules:
    - Sustained harmonic bed with slower motion than Lead 1/Lead 2/Rhythm
    - Chord-change ceiling: 1-2 functional changes per 16 bars
    - Progression shape: loop-first, linear/modal movement, avoid circle-of-fifths behavior
- Texture
  - Event probabilities:
    - Event chance per 8 bars: 35%
    - Event chance at boundary: 70%
  - Writing rules:
    - Sparse transitions only (swell/noise/tail)
    - Mostly non-harmonic to avoid tonal clutter

### Instrument probabilities (Auto mode)

- Lead 1: synth lead 50%, guitar-like lead 20%, brass-synth 15%, piano/Rhodes 15%
- Lead 2: bell/pluck 40%, secondary synth 40%, guitar-like counter 20%
- Pads: warm analog 40%, glass/digital 30%, synth-strings/choir 30%
- Rhythm: muted guitar pulse 45%, mono synth sequence 45%, arpeggiated poly 10%
- Texture: noise bed 45%, tape/air 35%, metallic/percussive FX 20%
- Bass: analog synth bass 45%, FM/digital synth bass 30%, electric/upright style bass 25%
- Drums: vintage electronic kit 45%, modern electronic kit 45%, acoustic/rock kit 10%

### Specific sound options (Motorik v1)

These are concrete sound targets derived from the Neu!/Harmonia/Kraftwerk reference set and your notes.

- Lead 1
  - Smooth Analog Lead (bright but controlled top, medium decay)
  - Saturated Mono Synth Lead (slight tape-like saturation character)
  - Guitar-Like Mono Lead (processed electric-guitar tone with synth-like sustain)
- Lead 2
  - Bell/Pluck Lead (short attack, thin body, echo-friendly)
  - Soft Synth Brass (muted attack, mid-band presence)
  - Narrow Pulse Lead (narrow pulse timbre, low density)
- Pads
  - Smooth Synth Pad (Neu/Harmonia-style sustained synth bed)
  - Analog Warm Pad (slow attack, low-mid warmth)
  - Synth Strings Pad (vintage ensemble style, gentle movement)
- Rhythm
  - Muted Motorik Guitar Pulse (8th/16th chug, minimal harmonic movement)
  - Sequenced Mono Synth Pulse (tight ostinato driver)
  - Processed Electric Piano Pulse (percussive transient, short gate)
- Texture
  - Tape Air Layer (hiss/air bed with slow filter motion)
  - Noise Swell Layer (transition-focused rise/fall events)
  - Metallic Percussive FX Layer (sparse mechanical accents)
- Bass
  - Analog Motor Bass (root/fifth anchor, rounded low-mid)
  - Digital/FM Pulse Bass (tighter transient, less low bloom)
  - Electric Pick Bass (steady ostinato with controlled attack)
- Drums (v1 limited set)
  - Vintage Electronic Kit
  - Rock Kit

### Effects probabilities (character presets)

- Drums: tight 60%, roomy 25%, gritty 15%
- Bass: focused 65%, warm 25%, saturated 10%
- Rhythm: dry pulse 35%, echo pulse 50%, wide pulse 15%
- Pads/Texture: deep space 55%, wide haze 35%, filtered air 10%
- Leads: echo-forward 50%, dry-forward 30%, saturated echo 20%

### Randomization guardrails

- Seeded determinism
  - Same seed + same controls => same result.
- Density balancing
  - If one track chooses a high-density option, lower high-density probabilities for adjacent tracks.
- Conflict prevention
  - Never allow high-fill drums and high-density Lead 1 in the same 8-bar window.
  - If Lead 1 conflicts with pads: thin Lead 1 first.
  - If Lead 1 conflicts with Lead 2: thin Lead 2 first.
- Continuity behavior
  - Only 1-2 parameter dimensions may change per track per boundary window.
  - Add/remove one layer at a time; avoid abrupt full-stop transitions.
  - Chord changes should align with strong pulse boundaries (bar starts, usually with kick anchors).
  - Key changes are rare in-base generation; if an evolution event shifts key, prefer step/fifth movement.

### V1 missing spec (now defined)

- Groove/swing microtiming (Motorik)
  - Swing amount target: 50-52% (nearly straight).
  - Per-event timing drift:
    - Drums: +/-6 ms
    - Bass: +/-8 ms
    - Rhythm: +/-7 ms
    - Lead 1/Lead 2: +/-10 ms
- Velocity/accent profiles (0-127 MIDI scale)
  - Drums:
    - Kick: 104-122
    - Snare: 96-118
    - Hat/cymbal: 72-104
    - Accent pulse every 2 or 4 bars, +6 to +10 velocity.
  - Bass: 78-108, phrase-start accents +5 to +8.
  - Rhythm: 70-100 with light up/down alternation.
  - Lead 1: 76-108 with motif peak note +8 max.
  - Lead 2: 64-96 (lower foreground than Lead 1).
- Note length/articulation defaults
  - Drums: one-shot/staccato.
  - Bass: mostly 8th-note gate, occasional held note at phrase boundary.
  - Rhythm: short gate (35-60% of step length).
  - Pads: long sustain (70-100% of harmonic window).
  - Lead 1: mixed short/medium notes, avoid continuous legato runs.
  - Lead 2: shorter than Lead 1 by default.
  - Texture: long tails/sparse one-shots.
- Register boundaries (guide ranges)
  - Lead 1: MIDI 60-88
  - Lead 2: MIDI 55-81
  - Pads: MIDI 48-84
  - Rhythm: MIDI 45-76
  - Texture: broad/noise bed, avoid dominant 1-3 kHz masking
  - Bass: MIDI 28-52
  - Drums: kit-mapped lanes (non-pitched)
- Transition/fill vocabulary (approved v1)
  - Drum micro-fill: 1-beat snare/tom pickup.
  - Drum cymbal lift: 1-bar hat-open crescendo.
  - Bass pickup: 1-2 note chromatic/diatonic approach into bar start.
  - Rhythm transition: one-bar accent-density lift.
  - Texture transition: noise swell in/out over 1-2 bars.
- Mix balance targets (starting points)
  - Relative level priority: Drums ~= Bass > Rhythm ~= Pads > Lead 1 > Lead 2 > Texture.
  - Low-end ownership: Bass and kick only.
  - Lead brightness cap: avoid harsh band build-up above ~6 kHz.
- Effects parameter ranges (normalized 0-100)
  - Drums: Space 8-28, Grit 12-36, Tone 40-62.
  - Bass: Space 0-14, Grit 8-28, Tone 34-58.
  - Rhythm: Echo 10-34, Width 12-32, Tone 42-66.
  - Pads: Space 36-72, Width 28-60, Echo 10-28.
  - Lead 1: Echo 18-46, Space 14-34, Grit 0-24.
  - Lead 2: Echo 24-54, Width 20-46, Tone 46-70.
  - Texture: Space 48-86, Width 32-70, Tone 30-60.
- Polyphony/event caps
  - Lead 1: max 2 simultaneous notes.
  - Lead 2: max 1 simultaneous note.
  - Pads: max 4-note voicings.
  - Rhythm: max 2-note dyad.
  - Bass: monophonic.
  - Texture: max 2 concurrent events.
  - Drums: no cap beyond kit-lane concurrency.
- Pattern library minimum sizes (v1)
  - Drums: 8 core patterns.
  - Bass: 6 patterns.
  - Rhythm: 6 patterns.
  - Pads: 5 harmonic templates.
  - Lead 1: 8 motif seeds.
  - Lead 2: 6 counter-motif templates.
  - Texture: 8 transition events.
- Mood-to-scale mapping (implementation defaults)
  - Bright: Ionian (major).
  - Deep: Aeolian (natural minor).
  - Dream: Dorian.
  - Free: hybrid note-pool with weak tonal gravity (avoid strong V-I cadence behavior).

## Constraints for v1

- Prioritize musical coherence over infinite flexibility.
- Keep controls shallow and meaningful; avoid DAW-level complexity in first prototype.
- Support repeatable results via seed/session recall.
- Effect controls should read as musical character, not studio engineering parameters.

## V1 Feature Lock

- Included:
  - `Generate New` button
  - Global `Play` button (green arrow)
  - Per-track `Mute` and `Solo` buttons
  - Per-track `Regenerate` button
  - Track set/order: Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums
- Excluded from v1:
  - Effect editing controls
  - Evolution mode (continuous morphing playback)

## Post-1.0 Evolution Mode (continuous play)

- Intent
  - `Generate` creates a completely new song state.
  - `Play` can run in an evolution mode where the current song morphs into new related states over time without hard resets.
- Playback behavior
  - Near the end of the current timeline, the engine prepares a successor state in the background.
  - Transition is seamless (crossfade/overlap boundary), preserving tempo continuity unless intentionally changed by rule.
  - Result should feel like an endless evolving stream rather than loop restart.
- Evolution probabilities per transition window
  - Keep most of current song, mutate a few dimensions:
    - mutate Lead 1 motif: 55%
    - mutate Lead 2 motif/entry behavior: 50%
    - mutate bass pattern: 45%
    - mutate drum pattern variant: 40%
    - swap one main instrument sound (non-drum): 35%
    - swap drum kit: 15%
    - harmonic-mode shift (static/slow shift/free): 25%
    - tempo shift small (+/-2 to 4 BPM): 20%
  - Large-change guardrail:
    - maximum 2 major mutations per evolution event.
- Continuity guardrails
  - Preserve key/mood by default (80%); controlled change allowed (20%).
  - Preserve at least 4 of 7 track identities at each transition.
  - Never mutate drums+bass+rhythm all at once in a single transition.
  - Keep deterministic evolution when seed and settings are unchanged.
- UX controls (post-1.0)
  - `Generate New`: hard new song.
  - `Evolve`: toggle continuous evolution during playback.
  - `Evolution Rate`: Slow / Medium / Fast (controls mutation frequency/intensity).
  - `Lock Track`: prevent selected track from mutation across evolution events.

## Open questions

- Should style be a single selector (Ambient, Motorik, Hybrid) or a blend slider?
- Should lead generation be optional by default for more sparse ambient output?
- Should each track permit independent length/polymeter, or all parts share one loop length in v1?

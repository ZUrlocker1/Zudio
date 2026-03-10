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
- Global transport includes:
  - `Previous` (left arrow)
  - `Play` (green arrow)
  - `Stop` (red square)
  - `Next` (right arrow)
- One-click regenerate options:
  - Regenerate single track
  - Regenerate all tracks while preserving style/mood/pace/key

## Design (v1 layout and UX structure)

- Screen layout is organized into three vertical zones below a global top bar:
  - Left: track rows with track-level controls
  - Middle: DAW-like grid/piano-roll visualization and note editing surface
  - Right: per-track effect controls and quick effect actions
  - Bottom: full-width text status box below all track rows
- Top global bar contains:
  - Upper-left logo lockup: stylized `Zudio` wordmark with small lightning bolt mark
  - Transport: `Previous` (left arrow), `Play` (green arrow), `Stop` (red square), `Next` (right arrow)
  - Primary action: `Generate`
  - Title section (top-center):
    - Generated song title
    - Tempo
    - Key
    - Mood
    - Style
  - Global selectors: `Style`, `Mood`, `Pace`, `Key`
  - Secondary actions: `Regenerate Track`, `Regenerate All`, `Seed/Recall`
  - Utility actions: `Help`, `About`
  - Global display/readouts: current seed, song length, master transport state
- Left track-control column (one row per track: Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums):
  - Small track-type icon to the left of each track name
  - Track name and color
  - Instrument selector (`Auto` or manual)
  - Activity/Density/Variation controls
  - Mute/Solo and track regenerate button
- Track icon mapping (v1 default):
  - Lead 1: lead-synth/keys icon
  - Lead 2: secondary-lead synth icon
  - Pads: pad/strings keyboard icon
  - Rhythm: rhythm-guitar or pulse-sequencer icon
  - Texture: waveform/noise-layer icon
  - Bass: bass instrument icon
  - Drums: drum-kit icon
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

## Status box (v1)

- A persistent text status box is shown at the bottom of the window, below all tracks.
- Purpose:
  - Display high-level, user-friendly information about song generation and musical structure.
  - Keep testing/debug feedback readable without overwhelming the user.
- Size/layout:
  - Width: match the MIDI grid region width.
  - Height: approximately 3-5 lines of text.
  - Overflow behavior: vertically scrollable when content exceeds visible height.
- Message behavior:
  - Show concise plain-language summaries only.
  - No timestamps.
  - No seed values.
  - No transport event logs.
  - Auto-scroll to newest message by default, with manual scrollback allowed.
- Required generation messages (on `Generate New`):
  - Song-structure rule summary:
    - section form selected (for example Single-A, subtle A/B)
    - progression family selected (for example static tonic, I-bVII, i-VII)
  - Intro rule summary:
    - intro type selected and intro length
    - key intro layer-entry decision (for example drums-only start, lead+texture start)
  - Outro rule summary:
    - outro type selected and outro length
    - layer-drop behavior (for example subtractive fade or drums-only tail)
  - Track-generation rule summary in canonical order: Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums.
    - Include short plain-language rule notes per track (for example bass = root/fifth anchor with sparse passing tones; Lead 2 = delayed entry/call-response).
  - Per-track instrument assignment in canonical order.
- Example compact 3-5 line status output:
  - `Form: Subtle A/B, 16+16 bars, progression I-bVII`
  - `Intro: Drums + Bass, 4 bars, snare enters bar 3`
  - `Bass rule: root/fifth anchor, 1 passing tone max per bar`
  - `Lead rules: Lead 1 motif-first, Lead 2 enters at bar 16 as response`
  - `Outro: Drums-only tail, 4 bars, gradual cymbal reduction`

## Help and About dialogs (v1)

- `Help` button behavior:
  - Opens a modal dialog with concise usage guidance:
    - Transport controls
    - `Generate New` vs per-track regenerate
    - Track `Mute`/`Solo`
    - Instrument cycling per track
    - MIDI grid playback/scroll behavior
  - Includes a close action and optional "do not show again" hint flag.
- `About` button behavior:
  - Opens a modal dialog with app identity and attribution basics:
    - Zudio name and purpose (personal generative music research app)
    - Version/build string
    - Credits/license summary for included sound assets
  - Includes close action and link target placeholder for full credits/licenses doc.

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

## Motorik Implementation Spec (Consolidated v1.1)

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
  - Melodic variation template probabilities (optional style flavor)
    - Core Neu!/Harmonia motorik: 45%
    - Jenny-style two-chord drive: 20%
    - Rheinita-style bright cycle: 15%
    - Theme for Great Cities-style melodic minor loop: 15%
    - Trans-Europe Express-style sequencer pulse: 5%
- Intro/Outro rules
  - Intro length probabilities:
    - 2 bars: 35%
    - 4 bars: 45%
    - 8 bars: 20%
  - Outro length probabilities:
    - 2 bars: 25%
    - 4 bars: 50%
    - 8 bars: 25%
  - Intro type probabilities:
    - Drums-only pulse intro: 20%
    - Lead only melody: 10%
    - Lead + texture: 10%
    - Drums + Bass intro: 35%
    - Drums + Bass + Texture intro: 15%
    - Full-band filtered intro: 10%
  - Outro type probabilities:
    - Drop to Drums + Bass: 35%
    - Drums-only tail: 30%
    - Full-band subtractive fade (parts drop every 1-2 bars): 25%
    - Texture-only tail after hard stop: 10%
  - Energy contour rules:
    - Intro builds only upward (do not start at max density).
    - Outro removes layers progressively (no sudden full stop unless in hard-stop variant).
    - Keep harmonic movement in intro/outro lower than in main body.

### Motorik-adjacent calibration profile (Electric Buddha set)

- Purpose:
  - Optional probability profile derived from `Time Loops`, `Dark Sun`, `Vanishing Point`, `Into The Night`, `Blakely Lab`, `Schulers Dream 05`.
  - Use as a secondary preset for more melodic/ambient Motorik-adjacent generation.
- Tempo family weights:
  - Fast drive (132-150 BPM): 45%
  - Mid motorik (116-126 BPM): 40%
  - Slow cruise (92-108 BPM): 15%
- Intro family weights:
  - Fast lock-in intro (1-2 bars): 50%
  - Medium intro (4 bars): 35%
  - Long atmospheric intro (8-12 bars): 15%
- Outro family weights:
  - Short subtractive (2-4 bars): 60%
  - Medium subtractive/tail (4-8 bars): 30%
  - Extended atmospheric tail (8+ bars): 10%
- Form/section weights:
  - 3-6 macro blocks (standard mode): 70%
  - 7-10 micro-variation blocks (long-form mode): 30%
- Track-writing emphasis:
  - Bass: root/fifth anchor default; passing tones sparse and boundary-aware.
  - Lead 1: motif-first with mutations every 8-16 bars.
  - Lead 2: delayed response role, lower density than Lead 1.
  - Rhythm: pulse continuity lane, low syncopation.
  - Pads: slow harmonic bed with low chord-change rate.
  - Texture: boundary events and late-stage atmosphere, avoid continuous clutter.
- Instrument/effect implications (for later effects phase):
  - Drums/Bass: tighter space and mild saturation as default.
  - Leads: tempo-locked echo with moderate width.
  - Pads/Texture: wider space and longer tails with controlled low-end.

### Classic calibration profile (Neu! + Harmonia + Cluster)

- Purpose:
  - Optional stricter profile aligned to classic Motorik corpus (`Hallogallo`, `Fur Immer`, `Neuschnee`, `Seeland`, `Wave Mother`, `Deluxe`, `Walky-Talky`, `Monza`, `Breitengrad 20`, `Hollywood`).
- Tempo family weights:
  - Fast drive equivalent (double-time 132-152 / half-time ~66-76): 50%
  - Mid motorik (116-126): 30%
  - Slow motorik-adjacent (85-108): 20%
- Intro family weights:
  - Short lock-in (1-4 bars): 25%
  - Medium intro (4-8 bars): 40%
  - Long build (8-32 bars): 35%
- Outro family weights:
  - Short subtractive (2-4 bars): 55%
  - Medium subtractive/tail (4-8 bars): 35%
  - Extended tail (8+ bars): 10%
- Bass-writing weights:
  - Anchor ostinato (root/fifth, 1-2 bar): 65%
  - Anchor + sparse passing tones: 25%
  - Melodic/stepwise bass: 10%
- Lead-entry and density weights:
  - Lead 1 entry <=8 bars: 20%
  - Lead 1 entry 9-16 bars: 45%
  - Lead 1 entry >16 bars: 35%
  - Lead 2 entry bar 8: 35%
  - Lead 2 entry bar 16: 45%
  - Lead 2 entry >16 bars: 20%
  - Lead 2 remains response-role at lower density than Lead 1.
- Rhythm-writing weights:
  - Strict pulse rhythm (continuous subdivision lock): 60%
  - Pulse + light accent variation: 30%
  - Sparse/atmospheric rhythm: 10%
- Melodic-part defaults (from `Neuschnee`, `Deluxe`, `Hollywood` focused pass):
  - Lead 1 conservative/repetition-first: 60%
  - Lead 1 melodic/contour-active: 30%
  - Lead 1 sparse/atmospheric: 10%
  - Lead 2 density target: 30-55% of Lead 1 event density.
  - Lead 2 response mode weights:
    - off-beat response: 50%
    - interval complement: 35%
    - sparse unison punctuation: 15%
  - Pad mode weights:
    - long-hold static bed: 55%
    - slow-shift bed: 35%
    - motion-rich bed: 10%
- Form defaults:
  - Favor long continuity windows and low harmonic churn.
  - Prefer timbral/rhythmic evolution over progression complexity.

### Creator melodic profile extension (Electric Buddha set)

- Lead 1 interval behavior weights:
  - repeated/pedal motion: 45%
  - stepwise (1-2 semitone): 20%
  - mid leaps (3-5 semitone): 15%
  - large leap accents (6+ semitone): 20%
- Lead 1 density mode weights:
  - low density: 30%
  - medium density: 45%
  - high density: 25%
- Lead 2 mode weights:
  - sparse off-beat punctuations: 45%
  - short answering phrases: 35%
  - interval-shadow counterline: 20%
  - hard cap: Lead 2 <=55% of Lead 1 event density.
- Pads mode weights:
  - static/long-hold bed: 60%
  - slow-shift bed: 30%
  - motion-rich bed: 10%
  - when Lead 1 enters high-leap mode, reduce pad re-voicing rate in that window.

### Scale and hook rules (Lead 1 / Lead 2)

- Default scale pool for Motorik and Motorik-adjacent generation:
  - Natural Minor (Aeolian): 40%
  - Dorian: 25%
  - Major (Ionian): 20%
  - Minor Pentatonic: 10%
  - Major Pentatonic: 5%
- Lead 1 hook construction:
  - Use a 5-note subset of the active scale for most motifs.
  - Degree priority:
    - Minor-family modes: 1, 2, b3, 5, b7
    - Major-family modes: 1, 2, 3, 5, 6
  - Add one mode color tone occasionally (for example Dorian 6) as a signature note event.
- Lead 1 interval profile for hooks:
  - repeated tone (0): 25-40%
  - step movement (1-2 semitones): 30-45%
  - small leaps (3-5): 15-25%
  - large leaps (6+): 5-12%
  - after a large leap, reverse direction in 1-2 notes (target 70%).
- Lead 2 countermelody scale policy:
  - Always use the same parent scale/mode as Lead 1.
  - Use a simpler subset (often pentatonic-biased) to reduce clashes.
  - Prefer complementary interval targets (3rd/6th/octave) and contrary/oblique motion.
  - Avoid continuous parallel lockstep with Lead 1.
- Scale simplification fallback:
  - If density/clash checks fail, switch current Lead 1 phrase window to pentatonic subset for 8-16 bars.

### Melody-harmony coherence rules

- Shared harmonic source of truth:
  - Lead 1 and Lead 2 must read from the same active chord map used by Pads and Bass.
  - No independent lead scale/mode selection outside the active chord window.
- Strong-beat chord-tone policy:
  - On strong beats (1 and 3), require chord tones with these targets:
    - Lead 1: 70-85%
    - Lead 2: 80-90%
- Weak-beat tension policy:
  - Non-chord tones are mostly allowed on weak beats/offbeats.
  - Resolve non-chord tension to nearest chord tone within 1-2 notes (<=1 bar).
- Chord-window note pools:
  - For each chord window:
    - Primary pool: chord tones
    - Secondary pool: scale-compatible non-chord tones
    - Avoid pool: high-clash tones for that chord
  - Weighted note selection:
    - Lead 1: Primary 65%, Secondary 30%, Avoid 5%
    - Lead 2: Primary 75%, Secondary 22%, Avoid 3%
- Phrase landing stability:
  - Phrase-end notes should land on stable tones (root/third/fifth) >=80% of phrase endings.
- Vertical interval safety (Lead 1 vs Lead 2 overlap):
  - Prefer consonant overlap intervals (3rd/6th/octave).
  - Dissonant overlaps are brief passing events (<1 beat), not sustained.
- Chord-change revalidation:
  - At every chord boundary, re-check held lead notes.
  - Keep held notes only if common-tone or quickly resolving; otherwise remap to nearest allowed tone.
- Auto-repair pass:
  - After phrase generation, run harmonic clash detection and repair by nearest allowed tone with minimal contour change.

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
    - Intro behavior:
      - In drums-only intro, use kick+hat first; snare enters by bar 2 or 3.
      - Allow one pickup fill in final intro bar (35% chance).
    - Outro behavior:
      - Reduce cymbal/hat density first, then remove snare ghost accents.
      - Last bar may end with kick-only pulse (40% chance).
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
    - Intro behavior:
      - If Bass is active in intro, use root-heavy anchor with minimal passing tones.
    - Outro behavior:
      - Shift to longer note values and fewer attacks in final 2-4 bars.
- Rhythm
  - Writing rules:
    - 1-2 bar ostinato, repeat-first behavior
    - 8th/16th pulse bias, minimal syncopation
    - Single-note or dyad-centric voicing
    - No riff-like fills; only accent/timbre shifts
    - Intro behavior:
      - Usually absent in first half of intro (75%); enters late to increase momentum.
    - Outro behavior:
      - Drop before bass and drums in most seeds.
- Lead 1
  - Writing rules:
    - Motif-first behavior, 2-6 note motifs
    - Phrase length 1-2 bars
    - Mostly stepwise/small intervals
    - One changed note/rhythm event every 4-8 bars
    - No high-density run longer than 2 bars
    - Intro behavior:
      - Suppress in intro by default; optional short pickup motif in last intro bar (20%).
    - Outro behavior:
      - End 1-2 bars before final stop unless in full-band subtractive fade type.
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
    - Intro/outro behavior:
      - Never active during intro.
      - Drop before Lead 1 in outro (default).
- Pads
  - Writing rules:
    - Sustained harmonic bed with slower motion than Lead 1/Lead 2/Rhythm
    - Chord-change ceiling: 1-2 functional changes per 16 bars
    - Progression shape: loop-first, linear/modal movement, avoid circle-of-fifths behavior
    - Intro behavior:
      - Optional low-level pad bed only in full-band filtered intro type.
    - Outro behavior:
      - Hold final chord tone through layer drop, then release before texture tail.
- Texture
  - Event probabilities:
    - Event chance per 8 bars: 35%
    - Event chance at boundary: 70%
  - Writing rules:
    - Sparse transitions only (swell/noise/tail)
    - Mostly non-harmonic to avoid tonal clutter
    - Intro/outro behavior:
      - Intro: reserve for low-level swell or filtered noise only.
      - Outro: highest probability track to remain after rhythmic parts stop.

### Intro/Outro layer order rules

- Intro layer add order (when active):
  - Rhythm-section intros (`Drums-only`, `Drums + Bass`, `Drums + Bass + Texture`, `Full-band filtered`):
    - Drums -> Bass -> Pads -> Rhythm -> Lead 1 -> Texture -> Lead 2
  - Lead-centric intros (`Lead only melody`, `Lead + texture`):
    - Lead 1 -> Texture -> Drums -> Bass -> Pads -> Rhythm -> Lead 2
- Outro layer drop order (default): Lead 2 -> Lead 1 -> Rhythm -> Pads -> Bass -> Drums -> Texture
- Entry/exit timing jitter:
  - Per-track boundary jitter up to +/- 1 beat (40% chance) for less mechanical transitions.
- Variation lock:
  - Intro and outro must still obey selected key and mood profile.
  - No new progression family may be introduced only in outro.

### Song-inspired melodic variation rules

- Jenny-style two-chord drive (motorik-safe)
  - Harmony: prioritize two-chord alternation with very high repetition.
  - Rhythm: steady pulse with minimal fill behavior.
  - Lead behavior: repetitive short motif with small rhythmic mutation.
- Rheinita-style bright cycle (melodic variant)
  - Harmony: allow 4-chord bright major-mode cycle (for example F-C-G-D family movement).
  - Bass: keep ostinato character even when harmony cycles.
  - Lead behavior: brighter hook line and slightly higher note density than core mode.
- Theme for Great Cities-style melodic minor loop
  - Harmony: minor/modal loop with recurring hook-friendly center.
  - Bass: repeated arpeggio/anchor figure with occasional step approach.
  - Lead behavior: delayed-entry melodic hooks and repeating phrases.
- Trans-Europe Express-style sequencer pulse
  - Tempo tendency: lower-mid motorik tempo pocket (~103-120).
  - Harmony: minimal harmonic movement, sequence-first construction.
  - Rhythm behavior: machine-tight grid with controlled micro-variation.
- Mother Sky/Cluster-Hollywood-derived additions
  - Allow long static-vamp windows in selected seeds.
  - Increase texture and timbre evolution while keeping chord-change rate low.

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

### Apple DLS fallback presets (prototype safety net)

- If curated assets are missing, use Apple DLS (General MIDI) presets:
  - Lead 1: GM 82, 87, 88
  - Lead 2: GM 83, 86, 63
  - Pads: GM 90, 91, 96
  - Rhythm: GM 82 or 91 with short gate
  - Texture: GM 93, 94, 95
  - Bass: GM 39, 40, 35
  - Drums kit families available: Standard (0), Room (8), Power (16), Electronic (24), Jazz (32)
  - Preferred v1 drum pair in GM-first mode: Electronic (24) + Power (16)

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

## Motorik Title Generator (v1)

- Behavior
  - On `Generate New`, generate a new Motorik-inspired song title.
  - On per-track `Regenerate`, keep the current title unchanged.
  - Titles are seed-deterministic (same seed/settings => same title).
- Output format
  - Typical length: 1-3 words.
  - Preferred style: short, pulse-oriented, slightly cryptic.
  - Language mix: English + occasional Germanic styling allowed.

### Title word banks

- User-supplied words (always included)
  - Ausfart, Koln, Alles, Klar, Dinger, Forest, Zorvaak, Pile, Driver, Elektronischer, Fluss, Nonstop, Buzzkill, Pulse, Vibe, Mother, Jenny, Two, Chord, Rotter, Musik, Kosmiche, ElektroJazz, Lager, Men, Speed, Sound, Pure, Drive
  - Mittelwerk, Detroit, Tunnel, Bomb, Nordhausen, Von Neumann, Schuler, Waters, Von Braun, Panzinger, Panks, Dieter
  - Dark, Light, Moon, Night, Sun, Stars, Exit, Airport, Jetlag, Sick, River, Lake, Road, Glass, Fast
  - Ausgang, Ausfahrt, Flughafen, Jetlag, Krank, Fluss, See, Strasse, Tunnel, Glas, Geschwindigkeit, Tempo, Schnell, Licht, Dunkel, Nacht, Mond, Sonne, Sterne
- Place/scene words
  - Koln, Dusseldorf, Berlin, Ruhr, Autobahn, Tunnel, Nordhausen, Detroit, Forest, Flughafen, Ausgang, Ausfahrt, Strasse, See, Fluss
- Motion/energy words
  - Drive, Pulse, Drift, Flow, Run, Loop, Roll, Counter, Motor, Velocity, Nonstop, Speed, Fast, Schnell, Tempo, Geschwindigkeit, Exit
- Texture/tone words
  - Chrome, Static, Neon, Halo, Tape, Glass, Glas, Metal, Buzz, Klang, Kosmiche, Elektronischer, Light, Dark, Licht, Dunkel, Night, Nacht, Moon, Mond, Sun, Sonne, Stars, Sterne
- Music-structure words
  - Chord, Pattern, Sequence, Ostinato, Motif, Echo, Signal, Flux, Phase
- Verified musician-name words (from Neu!/Harmonia/Kraftwerk + related motorik acts)
  - Klaus, Dinger, Michael, Rother, Thomas, Hans, Lampe
  - Roedelius, Dieter, Moebius
  - Ralf, Hutter, Florian, Schneider, Karl, Bartos, Wolfgang, Flur
- Rearranged title words (from referenced tracks/albums; not exact copies)
  - Hallo, Immer, Neu, Deluxe, Monza, Hollywood, Express, Europe, Endlos, Dynamik, Weiter

### Generation patterns (weighted)

- `Place + Motion` (22%)
- `Texture + Motion` (20%)
- `Name + Motion` (14%)
- `MusicWord + Motion` (14%)
- `Adj + Noun` (12%)
- `Three-word cinematic` (10%)
- `Phonetic parody blend` (8%)

### Post-processing rules

- Avoid exact known song titles; require at least one token change/reorder.
- Avoid repeating the same first token in consecutive generated titles.
- Cap punctuation and symbols (letters/spaces only in v1).
- Keep phonetic punch: prefer hard consonants and short vowels for one-word titles.

### Example generated titles (additional)

- Mittelwerk Pulse
- Detroit Driftline
- Neon Nordhausen
- Klaus in Tunnel
- Von Braun Drive
- Schuler Signal
- Rother Flux
- Bomb Pattern
- Flur Motor
- Panzinger Echo

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

- Should style be a single selector (Motorik, Cosmic, Ambient) or a blend slider?
- Should lead generation be optional by default for more sparse ambient output?
- Should each track permit independent length/polymeter, or all parts share one loop length in v1?

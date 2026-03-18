# Zudio Prototype Direction

## Core musical model

Zudio should be oriented around visible, regenerable song parts instead of a purely passive ambient generator.

- Track parts
  - Lead 1
  - Lead 2
  - Pads
  - Rhythm
  - Texture
  - Bass
  - Drums
- Global musical controls
  - Tempo — user-settable BPM or `Auto` (generator chooses)
  - Key — user-settable key or `Auto` (generator chooses)
  - Mood (instead of scale)
  - Style (Motorik only in v1; other styles are post-v1)

## Product intent

- Keep the motorik-first aesthetic, but allow more direct composition and arrangement control.
- Make the structure of the piece legible on screen at all times.
- Let users shape each part independently while preserving coherent overall output.

## Interaction concept (v1)

- A multi-lane timeline or pattern grid with one lane per part: Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums.
- Per-track controls for instrument selection, mute/solo, and regenerate.
- Global controls always visible: Style (locked to Motorik in v1), Mood, Tempo, Key.
- Primary action: `Generate` creates a full song state across all tracks using current global controls.
- Global transport includes:
  - `Previous` (left arrow)
  - `Play` (green arrow)
  - `Stop` (red square)
  - `Next` (right arrow)
- One-click regenerate options:
  - Regenerate single track
  - Regenerate all tracks while preserving style/mood/tempo/key

## Design (v1 layout and UX structure)

- Screen layout is organized into three vertical zones below a global top bar:
  - Left: track rows with track-level controls
  - Middle: DAW-like grid/piano-roll visualization surface (display only cannot be edited)
  - Right: per-track effect placeholders (disabled in v1)
  - Bottom: full-width text status box below all track rows
- Top global bar contains:
  - Upper-left logo lockup: use image asset `/assets/images/logo/zudio-logo.png` (transparent PNG), not text rendering
  - Logo scaling behavior:
    - preserve aspect ratio
    - fit height target ~56 px on standard desktop window
    - allow responsive range ~44-72 px based on window size
    - center the logo within the left header column width
  - Transport: `Previous` (left arrow), `Play` (green arrow), `Stop` (red square), `Next` (right arrow)
  - Primary action: `Generate`
  - Title section (top-center):
    - Generated song title
    - Tempo
    - Key
    - Mood
    - Style
  - Global selectors: `Style`, `Mood`, `Tempo`, `Key`
  - Secondary actions: `Regenerate Track`, `Regenerate All`
  - Utility actions: `Help`, `About`
  - Global display/readouts: song length (derived from `totalBars` and `tempo`: `totalBars * 4 * 60 / tempo` seconds, displayed as m:ss)

### Key selector behavior

- Control type: dropdown/picker showing all 12 chromatic keys plus an `Auto` option.
- Key list (display order): `Auto`, `C`, `C#`, `D`, `Eb`, `E`, `F`, `F#`, `G`, `Ab`, `A`, `Bb`, `B`
- Default state on first launch: `Auto`
- When set to `Auto`: the generator selects the key on each `Generate New` using the Motorik key-center probability table (E 30%, A 20%, D 15%, G 10%, C 10%, B 8%, F# 7%). After generation the selector still displays `Auto`; the generated key is shown in the title readout area only.
- When the user selects a specific key: that key is stored as the locked key. All subsequent `Generate New` and `Regenerate All` calls use this key. Per-track `Regenerate` also uses the current locked key.
- Changing the key selector does not automatically trigger a new generation; the new value takes effect on the next `Generate New` or `Regenerate All`.
- The locked key persists across multiple `Generate New` calls until the user switches back to `Auto` or selects a different key.

### Tempo selector behavior

- Control type: numeric stepper or direct entry field, integer BPM, range 20–200 BPM, plus an `Auto` option.
- Default state on first launch: `Auto`
- When set to `Auto`: the generator selects the tempo on each `Generate New` using the Motorik tempo probability table (126–154 BPM range with default 138 BPM). After generation the selector still displays `Auto`; the generated tempo is shown in the title readout area only.
- When the user enters a specific BPM value: that value is stored as the locked tempo. All subsequent `Generate New` and `Regenerate All` calls use this tempo. Per-track `Regenerate` also uses the current locked tempo.
- Valid range: 20–200 BPM. Values outside this range are clamped silently to the nearest bound.
- Changing the tempo selector does not automatically trigger a new generation; the new value takes effect on the next `Generate New` or `Regenerate All`.
- The locked tempo persists across multiple `Generate New` calls until the user switches back to `Auto` or changes the value.
- Song length readout updates immediately when the tempo value changes (even before generating) since it is derived from `totalBars * 4 * 60 / tempo`.

- Left track-control column (one row per track: Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums):
  - Small track-type icon to the left of each track name
  - Track name and color
  - Instrument selector (`Auto` or manual)
  - Mute/Solo and track regenerate button
- Track family color mapping (v1):
  - Lead 1 + Lead 2: red family
  - Pads + Rhythm + Texture: blue family
  - Bass: purple family
  - Drums: yellow family
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
  - Visualization only: no note editing, note drawing, drag, erase, or velocity editing
- Right effects column:
  - Per-track effect character controls (`Space`, `Echo`, `Delay`) shown but disabled in v1
  - No functional effect editing in v1
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
  - Where practical, include relevant generation rule references in status output as:
    - rule ID (for example `B-002`)
    - brief plain-language explanation of how that rule was applied
- Required generation messages (on `Generate New`):
  - Song-structure rule summary:
    - section form selected (for example Single-A, subtle A/B)
    - progression family selected (for example static tonic, I-bVII, i-VII)
    - per-section bar counts
    - per-section chord sequence shown as:
      - proper chord names using standard notation (for example Em  D  Em  D)
      - chord names use root note + type suffix: major = root only (e.g. G), minor = m (e.g. Em), dominant 7th = 7 (e.g. D7), minor 7th = m7 (e.g. Am7), sus2 = sus2 (e.g. Asus2), power = 5 (e.g. E5)
      - no Nashville/numeric notation (no i-bVII or 1-b7 notation) in user-facing status
  - Intro rule summary:
    - intro type selected and intro length
    - key intro layer-entry decision (for example drums-only start, lead+texture start)
  - Outro rule summary:
    - outro type selected and outro length
    - layer-drop behavior (for example subtractive fade or drums-only tail)
  - Track-generation rule summary in UI order: Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums.
    - Include short plain-language rule notes per track (for example bass = root/fifth anchor with sparse passing tones; Lead 2 = delayed entry/call-response).
  - Per-track instrument assignment in UI order.
- Example status output:
  - `SONG    My Song Title`
  - `STR-002 Subtle A/B, intro: 16 bars, A section: 48 bars, B section: 32 bars, outro: 16 bars`
  - `INT-002 Intro: 16 bars, drums-only entry → sparse from bar 2`
  - `OUT-002 Outro: 16 bars, sparse/low-intensity drop`
  - `Chords  Em  G  D  Bm`
  - `GBL-001 E Dorian, 138 BPM, minor_loop_i_VII`
  - `DRM-001 4-on-the-floor kick, closed-hat grid, snare beat 3`
  - `BAS-001 Root anchor beat 1, chord tones beat 3, syncopation`
  - `PAD-001 Open 4-note sustained voicing, chord-window duration`
  - `PAD-003 Pulsed re-attack every 4–8 bars within chord window`
  - `LD1-001 Motif-first, chord tones 80%, scale tensions 20%`
  - `LD2-001 Counter-response, density ≤55% of Lead 1`
  - `RHY-001 8th-note ostinato, alternating root/fifth per chord`
  - `RHY-003 Syncopated Motorik (3+3+2 feel), root/fifth alternation`
  - `TEX-001 Boundary-weighted sparse atmosphere, scale tensions`
- Rule numbering convention:
  - STR-001: Single-A, STR-002: Subtle A/B, STR-003: Moderate A/B, STR-004: Moderate A/B/A'
  - INT-001: 8-bar intro, INT-002: 16-bar intro
  - OUT-001: 8-bar outro, OUT-002: 16-bar outro
  - GBL, DRM, BAS, LD1, LD2, TEX: single rule each in v1 (always 001)
  - PAD: PAD-001 (sustained), PAD-002 (power voicing), PAD-003 (pulsed), PAD-004 (sparse intro/outro)
  - RHY: RHY-001 (8th pulse), RHY-002 (quarter note), RHY-003 (syncopated Motorik)
  - Multiple rules shown when more than one variant is used across chord windows/sections

## Help and About dialogs (v1)

- `Help` button behavior:
  - Opens a modal dialog with concise usage guidance:
    - Transport controls
    - `Generate New` vs per-track regenerate
    - Track `Mute`/`Solo`
    - Instrument cycling per track
    - MIDI grid playback/scroll behavior
  - Includes a close action and optional "do not show again" hint flag.
  - Default Help text:
    - `Zudio generates Motorik-inspired music using MIDI tracks.`
    - `Use Generate New to create a full song, then Play/Stop to audition it.`
    - `Use M and S on each track to isolate parts, and the lightning bolt to regenerate one track.`
    - `Use instrument cycle controls to audition alternate MIDI sounds.`
    - `The center grid shows generated MIDI notes and scrolls during playback.`
- `About` button behavior:
  - Opens a modal dialog with app identity and attribution basics:
    - Zudio name and purpose (personal generative music research app)
    - Version/build string
    - Credits/license summary for included sound assets
  - Includes close action and link target placeholder for full credits/licenses doc.
  - Default About text:
    - `Zudio`
    - `Personal generative music research prototype for native macOS.`
    - `Version: 0.1 (prototype)`
    - `Audio engine: Apple AVAudioEngine with Apple DLS/General MIDI playback.`
    - `V1 scope: Motorik style only.`

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
    - Electronic kit
    - Rock kit
- UX simplification:
  - Show one default instrument per track when `Generate` is pressed.
  - Allow optional manual override per track.
  - Keep an `Auto` mode that reselects instruments during regeneration.

## Instrument cycling behavior (v1)

- Each track row includes an instrument-cycle control next to the instrument name.
- Pressing the control advances to the next instrument in that track's candidate list.
- Cycling wraps from the last candidate back to the first.
- On change, playback switches to the new instrument at the next bar boundary (or immediately if transport is stopped).
- UI always shows the active instrument name after each change.
- In `Auto` mode, track regeneration chooses from the same per-track candidate list using weighted probabilities.

## MIDI lane behavior (v1)

- `Generate New` regenerates MIDI notes for all active tracks and redraws all lanes.
- Per-track regenerate redraws only that track lane while preserving others.
- During playback, lanes scroll with the playhead like a DAW timeline.
- If a track is muted, its MIDI lane is greyed out.
- If any track is soloed, non-solo lanes are greyed out and excluded from audio output.
- MIDI lanes are display-only and do not support direct note editing.
- Per-track state storage (authoritative):
  - The song state holds a separate array of MIDI events for each track: `trackEvents[trackIndex]` where trackIndex matches the fixed track order (Lead1=0, Lead2=1, Pads=2, Rhythm=3, Texture=4, Bass=5, Drums=6).
  - `Generate New` runs the full generation pipeline and replaces all seven `trackEvents` arrays.
  - Per-track `Regenerate` re-runs only that track's generation step using the current `GlobalMusicalFrame` and the fixed `SongStructure`/chord plan from the last full `Generate New`. It does not re-run steps 1 or 2. If the user has changed the Key or Tempo selector since the last full generate, those new locked values are NOT applied by per-track regenerate — they only take effect on the next full `Generate New`. Per-track regenerate always reads key, mode, tempo, totalBars, and progressionFamily from the stored `SongState.frame`, which is the frame produced by the last full generate. Only `trackEvents[trackIndex]` is replaced; all other arrays are untouched.
  - The playback engine always reads from `trackEvents[trackIndex]` at render time. Swapping one track's array while others remain unchanged is the complete implementation of per-track regenerate — no re-running of other tracks, no re-deriving of the global frame.
  - If playback is running when per-track regenerate is triggered, the new events for that track take effect at the next bar boundary (do not interrupt mid-bar).
- Playback behavior (v1 authoritative):
  - Pressing `Play` starts playback from the beginning of the generated song.
  - The song plays once through to the end (intro → main sections → outro) and then stops. There is no looping.
  - When playback reaches the final bar, the audio engine stops and the playhead returns to bar 1.
  - Pressing `Stop` stops playback immediately (hard stop, no fade). The playhead returns to bar 1.
  - `Previous` and `Next` are disabled placeholders in v1 and perform no action.
  - All tracks share one timeline length. There is no per-track independent length or polymeter in v1; all tracks are the same number of bars.

## Track effects approach (post-v1 placeholder)

> **POST-V1 ONLY — do not implement in v1.** This section is reference and planning material. The v1 feature lock excludes all effect editing controls.

- Effect editing is excluded from v1.
- Keep this as a post-v1 design placeholder so naming and routing are ready.
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
- Generation output is MIDI data:
  - Each track generation step writes MIDI notes/events aligned to the current song structure, key, mode, and section plan.
  - Playback renders those generated MIDI events through the selected General MIDI instrument/kit.
- Use a fixed generation order so dependencies are stable:
  - 1. Global musical frame (style, mood, tempo, key center, scale/mode, totalBars) — key and tempo come from the locked selector values if set; otherwise drawn from the probability tables
  - 2. Song structure and chord plan (bars, sections, per-section chords)
  - 3. Tonal-governance map (section note pools + chord-window pitch-class masks)
  - 4. Drums groove plan (Apache family + section intensity)
  - 5. Bass anchor plan (from key/mode + section chords)
  - 6. Pads harmonic-bed plan (explicit chord voicing layer)
  - 7. Lead layer plan (Lead 1 motif + Lead 2 counter-response)
  - 8. Rhythm ostinato plan (pulse embellishment)
  - 9. Texture-event plan (sparse atmosphere embellishment)
  - 10. Collision/density simplification pass
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
  - Starter MIDI phrases must be remapped to current key/mode/chord map before rendering:
    - transposition-only is allowed only if all notes remain in active section note pool
    - otherwise apply nearest-allowed-note remap per event with contour-preservation bias
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

## MIDI note generation algorithm

### Scope and fundamental rule

Every non-drum track (Bass, Pads, Lead 1, Lead 2, Rhythm, Texture) generates output as a sequence of MIDI note events. All pitch values for these tracks must be derived from the global key and active mode using the formula below. No non-drum track may hardcode absolute MIDI note numbers in its generation logic. This guarantees that a user key change or a new `Generate New` automatically transposes all tracks correctly without special-casing.

Drums are entirely key-independent. Drum tracks use fixed GM kit note numbers and do not participate in key, mode, or chord-window logic at any point.

### Global musical frame (generation step 1 output)

Step 1 of the generation pipeline produces a `GlobalMusicalFrame` record. Every subsequent step reads from this record. Its fields:

- `key`: one of `C`, `C#`, `D`, `Eb`, `E`, `F`, `F#`, `G`, `Ab`, `A`, `Bb`, `B` — value is the locked key selector value if set, otherwise drawn from the Motorik key-center probability table
- `mode`: one of `Ionian`, `Dorian`, `Mixolydian`, `Aeolian`, `MinorPentatonic`, `MajorPentatonic`
- `tempo`: integer BPM — value is the locked tempo selector value if set (range 20–200), otherwise drawn from the Motorik tempo probability table
- `mood`: one of `Bright`, `Deep`, `Dream`, `Free`
- `progressionFamily`: one of `static_tonic`, `two_chord_I_bVII`, `minor_loop_i_VII`, `minor_loop_i_VI`, `modal_cadence_bVI_bVII_I`
- `totalBars`: integer — the total length of the song in bars, shared by all tracks

`totalBars` is derived during step 1 from a randomly selected target duration. Selection rules (authoritative):

1. Draw `targetDurationSeconds` from a triangular distribution: minimum 210 s (3:30), peak 285 s (4:45), maximum 390 s (6:30). In the absence of a triangular-distribution primitive, use: draw uniformly from 210–390 s, then bias toward 285 s by averaging the draw with 285 s.
2. If form is `Moderate A/B`, add 20 s to the draw (clamped to 390 s maximum) to allow room for both A and B sections to be at least 32 bars.
3. Compute:

```
totalBars = round((targetDurationSeconds * tempo) / 60 / 4) * 4
```

The result is rounded to the nearest multiple of 4 bars so that all section boundaries fall on clean bar counts. All tracks must generate exactly `totalBars` bars of MIDI events — no more, no fewer. `totalBars` is authoritative for the entire pipeline in the same way `key` is: no track may use a different bar count or infer it independently.

### Song structure specification (generation step 2 output)

Step 2 produces a `SongStructure` record containing an ordered list of sections and a chord plan. This record must be complete before any track-specific generation (steps 4–9) begins.

#### Intro and outro length selection

Draw `introLength` from the intro length probabilities (2/4/8 bars) and `outroLength` from the outro length probabilities (2/4/8 bars). Both values are multiples of 2.

```
bodyLength = totalBars - introLength - outroLength
```

Minimum `bodyLength` is 32 bars. If `bodyLength` < 32 after the initial draw, reduce `outroLength` by one step (8→4 or 4→2) and recalculate. If still < 32 with `outroLength` at 2, reduce `introLength` by one step. These adjustments ensure at least two 16-bar sections always fit in the body.

#### Form and body section bar counts

All drawn section lengths are multiples of 16 bars. B absorbs whatever remains after subtracting A (and A' where applicable) from `bodyLength`; B is therefore not guaranteed to be a multiple of 16, but will always be >= 32 bars after the clamping rules below are applied. This matches real Motorik practice where a long-drive B section simply runs to the outro without a fixed internal grid.

The section lengths below were calibrated against the analyzed corpus: the Drumscribe reference MIDI (~32-bar buildup / ~96-bar drive at 130 BPM), the Electric Buddha set (3–6 macro blocks of 16–32 bars each), and classic reference tracks (Hallogallo, Fur Immer, Neuschnee, Deluxe).

**Single-A (45%)**
- Layout: intro | A | outro
- A = `bodyLength` bars (entire body is one section; no formal break)
- Intensity evolves through three internal sub-phases. Sub-phase lengths rounded to nearest 16 bars:
  - Phase 1 `low`: first 25% of A
  - Phase 2 `medium`: middle 50% of A
  - Phase 3 `high`: final 25% of A
  - These sub-phases are internal intensity guidance for drum pattern selection and track density — they are not formal section boundaries and do not appear in `SongStructure.sections`
- This form matches the Hallogallo/Fur Immer long-form model and the Electric Buddha long-form blocks

**Subtle A/B (40%)**
- Layout: intro | A | B | outro
- A section length is drawn from this probability table (independent of `bodyLength`):
  - 32 bars: 25% — short buildup before a long drive (Drumscribe-style ~32 A / ~96 B)
  - 48 bars: 35% — medium split, most common in 4–5 minute pieces
  - 64 bars: 30% — near-equal halves, appropriate for 5+ minute pieces
  - 80 bars: 10% — long A before a shorter B, used in extended builds
- B = `bodyLength − A`. If B < 32, reduce A by 16 and recalculate. If A has been reduced to 32 and B is still < 32, set A = B = `floor(bodyLength / 32) × 16` (nearest equal split)
- A and B share the same key, mode, and `progressionFamily`
- B starting intensity = A ending intensity ± 1 step (clamped: never below `low`, never above `high`)
- At least one of Lead 1, Pads, or Bass must change its density profile at the A→B boundary

**Moderate A/B (15%)**
- Layout: intro | A | B | outro — or intro | A | B | A' | outro for the reprise variant
- A section length:
  - 32 bars: 30% — punchy setup before main development
  - 48 bars: 40% — most common
  - 64 bars: 25% — longer setup for extended pieces
  - 80 bars: 5% — rare
- Reprise variant (A' return): probability 30%. A' = 16 bars (50%) or 32 bars (50%). B = `bodyLength − A − A'`
- Without reprise: B = `bodyLength − A`. In both cases B minimum 32 bars; reduce A by 16 if needed
- A and B share the same key and `progressionFamily`
- B starting intensity = A ending intensity + 1 step (max `high`)
- Lead 1 shifts from motif-first to solo-phrase behavior in B
- Mode may shift at the A→B boundary (probability 50%): allowed pairs are `Aeolian→Dorian`, `Ionian→Mixolydian`, or `Dorian→Aeolian` only. No other mid-song mode changes in v1
- A' (reprise, if used): restores A's mode and intensity level; Lead 1 returns to motif-first behavior

#### SongSection record fields

Each entry in `SongStructure.sections`:
- `startBar`: 0-indexed bar number within the full song (song starts at bar 0)
- `lengthBars`: number of bars in this section
- `label`: one of `intro`, `A`, `B`, `outro`
- `intensity`: one of `low`, `medium`, `high` — derived as follows (authoritative):
  - `intro`: always `low`
  - `outro`: always `low`
  - Single-A body: the A section does not receive a single intensity value; its intensity is read from the sub-phase position at render time (low → medium → high arc). Store the section intensity as `medium` as a neutral default; the actual drum/track selection uses the sub-phase position directly.
  - Subtle A/B — A section: draw from (`low`: 20%, `medium`: 80%)
  - Subtle A/B — B section: A-ending intensity ±1 step (clamped low/high; see form rules above)
  - Moderate A/B — A section: draw from (`low`: 10%, `medium`: 90%)
  - Moderate A/B — B section: A-ending intensity +1 step (max `high`)
  - Moderate A/B — A' reprise (if present): same intensity as A section
- `mode`: active mode for this section (matches `GlobalMusicalFrame.mode` except in Moderate A/B where B may differ)

#### Chord plan

The chord plan is a list of `ChordWindow` entries covering all bars 0 through `totalBars−1`. Rules:
- `startBar` and `lengthBars` are always multiples of 4
- No chord window may cross a section boundary
- The intro and outro each have exactly one chord window spanning their full length
- Main section chord window lengths are set by `progressionFamily`:
  - `static_tonic`: one chord window per section (entire section is one chord)
  - `two_chord_I_bVII`: alternating tonic and bVII windows, 8–16 bars each
  - `minor_loop_i_VII` or `minor_loop_i_VI`: alternating i and VII/VI windows, 8–12 bars each
  - `modal_cadence_bVI_bVII_I`: repeating 3-chord groups of 8 bars each (bVI → bVII → I)
- Each `ChordWindow` stores: `startBar`, `lengthBars`, `chordRoot` (degree string in key), `chordType`, and the three pitch-class sets (`chordTones`, `scaleTensions`, `avoidTones`) derived from the chord type and active section mode

### Mood-to-mode mapping

Authoritative mapping used when mood is chosen and mode is not explicitly overridden:

- Bright → primary: Ionian (major), secondary: Mixolydian
- Deep → Aeolian (natural minor)
- Dream → Dorian
- Free → Aeolian note pool with weak tonal gravity; suppress strong V-I cadence weight

### Key semitone table

Maps key name to semitone offset from C (0-indexed, chromatic):

- C = 0, C#/Db = 1, D = 2, D#/Eb = 3, E = 4, F = 5
- F#/Gb = 6, G = 7, G#/Ab = 8, A = 9, A#/Bb = 10, B = 11

### Degree string to semitone table

Degree strings are used in starter JSON pattern files and in internal generation. Each degree is a fixed chromatic interval above the chord or key root, regardless of mode.

- "1" = 0 semitones
- "b2" = 1
- "2" = 2
- "b3" = 3
- "3" = 4
- "4" = 5
- "#4" / "b5" = 6
- "5" = 7
- "b6" = 8
- "6" = 9
- "b7" = 10
- "7" = 11

### Mode interval tables

Each mode's available scale degrees as semitones above root. Notes outside this set are non-scale tones.

- Ionian (major): 0, 2, 4, 5, 7, 9, 11
- Dorian: 0, 2, 3, 5, 7, 9, 10
- Mixolydian: 0, 2, 4, 5, 7, 9, 10
- Aeolian (natural minor): 0, 2, 3, 5, 7, 8, 10
- Minor Pentatonic: 0, 3, 5, 7, 10
- Major Pentatonic: 0, 2, 4, 7, 9

### MIDI note number formula

```
midiNote = 60 + keySemitone + degreeSemitone + (oct * 12)
```

- `60` is MIDI middle C (C4). This is the reference base.
- `keySemitone` comes from the key semitone table.
- `degreeSemitone` comes from the degree string table.
- `oct` is the integer octave offset stored in the pattern event or chosen by the generator (negative = lower register, positive = higher register).
- The result must be clamped to the track's register range (see register boundaries in V1 execution parameters).

Worked examples:

- Key E, degree "1", oct -2: 60 + 4 + 0 − 24 = **40** (E2)
- Key E, degree "5", oct -2: 60 + 4 + 7 − 24 = **47** (B2)
- Key E, degree "b7", oct -2: 60 + 4 + 10 − 24 = **50** (D3)
- Key A, degree "1", oct -2: 60 + 9 + 0 − 24 = **45** (A2)
- Key A, degree "b3", oct 0: 60 + 9 + 3 + 0 = **72** (C5)
- Key D, degree "5", oct -1: 60 + 2 + 7 − 12 = **57** (A3)

### Chord-window note pool construction (generation step 3 output)

For each chord window in the song structure, three pitch-class sets are built. All non-drum tracks validate note choices against these sets.

Chord tones by chord type (semitone intervals from chord root):

- Major triad: 0, 4, 7
- Minor triad: 0, 3, 7
- Sus2: 0, 2, 7
- Sus4: 0, 5, 7
- Add9: 0, 4, 7, 14 (pitch class: 0, 4, 7, 2)
- Dominant 7th: 0, 4, 7, 10
- Minor 7th: 0, 3, 7, 10

Derived sets:

- `chordTones`: the intervals above for the active chord type, expressed as pitch classes (mod 12).
- `scaleTensions`: all mode semitones (from the mode interval table) not already in `chordTones`.
- `avoidTones`: chromatic semitones not present in the active mode at all. These are disallowed on strong beats for all non-drum tracks.

All three sets are pitch-class sets (mod 12), not absolute MIDI notes, so they apply at any octave.

### Chord root MIDI note derivation

The chord root is the progression family's root degree resolved through the key semitone table and MIDI formula, then placed in the appropriate register for the track. Example: in key E (semitone 4), Aeolian mode, progression `i-VII` — the VII chord root is the bVII degree (semitone 10 = D). The chord root pitch class is `(4 + 10) mod 12 = 2` (D). Each track then constructs its notes relative to this chord root at its own octave register.

### Step grid resolution

All pattern events (starter JSON files and generated output) use a 16-step-per-bar grid:

- 1 bar = 16 steps. Each step = one sixteenth note in 4/4.
- `step` field: 0-based index within the pattern. 0–15 for 1-bar patterns, 0–31 for 2-bar patterns.
- `len` field: note duration in steps.
- Beat positions within a bar: beat 1 = step 0, beat 2 = step 4, beat 3 = step 8, beat 4 = step 12.
- Strong beats (1 and 3) = steps 0 and 8. Used for chord-tone enforcement rules.
- Eighth-note offbeats = steps 2, 6, 10, 14. Sixteenth-note offbeats = odd steps (1, 3, 5, 7, 9, 11, 13, 15).

At render time, step index converts to seconds:

```
secondsPerStep = (60.0 / tempo) / 4.0
eventTimeSeconds = stepIndex * secondsPerStep
```

### GM drum note mapping

Drum patterns use these fixed MIDI note numbers. These are the only numbers the drum generator emits. They are used for both audio playback and lane visualization.

Core groove voices:
- Kick (bass drum): 36
- Acoustic snare: 38
- Closed hi-hat: 42
- Open hi-hat: 46
- Pedal hi-hat: 44
- Ride cymbal: 51
- Crash cymbal 1: 49

Fill and accent voices:
- Side stick: 37
- Hi-mid tom: 48
- Low-mid tom: 47
- High floor tom: 43
- Low floor tom: 41
- High tom: 50
- Ride bell: 53
- Crash cymbal 2: 57

Default v1 active voices (core motorik groove): kick 36, snare 38, closed hat 42, open hat 46, ride 51, crash 49, hi-mid tom 48, low-mid tom 47. Side stick and additional crashes are available for variation events.

---

## Motorik Implementation Spec

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
  - Harmonic movement profile probabilities:
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
  - Use as an in-v1 secondary generation profile for more melodic/ambient Motorik-adjacent output while remaining inside the v1 `Motorik` style scope.
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
  - Strict pulse rhythm (continuous subdivision lock): 25%
  - Pulse + light accent variation: 45%
  - Sparse/atmospheric rhythm: 30%
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
    - long-hold static bed: 35%
    - slow-shift bed: 45%
    - motion-rich bed: 20%
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
  - low density: 40%
  - medium density: 45%
  - high density: 15%
- Lead 2 mode weights:
  - sparse off-beat punctuations: 45%
  - short answering phrases: 35%
  - interval-shadow counterline: 20%
  - hard cap: Lead 2 <=55% of Lead 1 event density.
- Pads mode weights:
  - static/long-hold bed: 35%
  - slow-shift bed: 45%
  - motion-rich bed: 20%
  - when Lead 1 enters high-leap mode, reduce pad re-voicing rate in that window.

### Implementation consistency contract (for code generation)

- Purpose:
  - This section (`Scale and hook rules` through `V1 execution parameters`) defines probability weights and numeric defaults used to tune generation.
- Precedence:
  - If any value here conflicts with the `Rule ID Catalog (MIDI-derived v1)`, the Rule ID Catalog is authoritative.
  - If there is any conflict with `V1 Feature Lock`, the feature lock is authoritative for scope.
- Interpretation:
  - `must`, `disallowed`, `always`, and `never` are hard constraints.
  - percentages, ranges, and weights are probabilistic defaults (tunable) and not hard guarantees per bar.
  - style examples and song-inspired variants are vocabulary sources, not literal structure copies.

### Scale and hook rules (Lead 1 / Lead 2)

- Default scale pool for Motorik and Motorik-adjacent generation:
  - Natural Minor (Aeolian): 35%
  - Dorian: 20%
  - Mixolydian: 20%
  - Major (Ionian): 15%
  - Minor Pentatonic: 7%
  - Major Pentatonic: 3%
  - Interpretation:
    - This pool is a lead-writing default for phrase material and does not override section key/mode selected by tonal governance rules.
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

### Cross-track tonal-governance rules (strict)

- Global tonal lock:
  - Every section has exactly one active parent scale/mode and one active chord map.
  - All pitched tracks (`Bass`, `Pads`, `Rhythm`, `Lead 1`, `Lead 2`) must draw notes from this section map.
  - Mode changes are section-boundary events only; mid-section mode swaps are disallowed in v1.
- Chord-window pitch-class masks:
  - For each chord window, build allowed sets:
    - `Chord tones` (highest priority)
    - `Scale-compatible tensions` (secondary priority)
    - `Avoid tones` (disallowed on strong beats)
  - Any imported starter MIDI phrase is projected into this mask before playback.
- Track-specific note-pool quotas (per 4-bar window):
  - Bass:
    - chord tones >=85%
    - scale tensions <=15%
    - non-scale tones 0% (except explicit pickup rule, max 1 event resolving within <=1 beat)
  - Rhythm:
    - chord tones >=80%
    - scale tensions <=20%
    - non-scale tones 0%
  - Pads:
    - chord tones >=90%
    - scale tensions <=10%
    - non-scale tones 0%
  - Lead 1:
    - chord tones target 65-85% (already style-dependent)
    - scale tensions allowed with timed resolution
    - non-scale tones <=5%, weak-beat only, mandatory rapid resolution
  - Lead 2:
    - chord tones >=80%
    - scale tensions <=20%
    - non-scale tones <=2%, weak-beat only, mandatory rapid resolution
- Strong-beat enforcement:
  - On beats 1/3 (and equivalent section anchors), `Bass`, `Pads`, and `Rhythm` must land on chord tones.
  - `Lead 2` strong beats prefer chord tones unless explicitly marked as passing response.
- Mood-consistency guard:
  - If song mood chooses minor-family mode, major-third emphasis events are constrained to brief passing/borrowed usage.
  - If song mood chooses major-family mode, minor-third emphasis events are constrained similarly.
  - If section mode is Mixolydian, treat `b7` as stable but keep major-third/minor-third polarity consistent with major-family behavior.
  - This prevents simultaneous contradictory major/minor coloration across bass vs lead layers.
- Bass-vs-Lead2 conflict resolver (priority rule):
  - If `Bass` and `Lead 2` form a high-clash interval on a strong beat:
    - keep bass note
    - remap Lead 2 to nearest allowed consonant target (3rd/6th/octave or chord tone)
    - if no clean remap within 2 semitones, suppress the Lead 2 event.
- Starter phrase adaptation rules:
  - Phrase ingestion pipeline:
    - detect source phrase intervals/rhythm
    - map notes to scale degrees against source local center
    - remap degrees into target section chord window
    - preserve rhythm first, contour second, exact interval last
  - For cross-style starter sources (for example Silly Love Songs-derived patterns), harmonic identity is never copied verbatim; only rhythmic/contour vocabulary is retained.
- Validation gate before render:
  - Reject and regenerate any 4-bar window if:
    - any supporting track (`Bass`, `Pads`, `Rhythm`) violates note-pool quotas
    - more than two strong-beat bass/lead2 clashes remain after repair
    - mixed major/minor third coloration exceeds the mood-consistency threshold.

### Core musical behavior

- Drums
  - Primary drum asset (use this for code generation):
    - `/assets/midi/motorik/drums/drum-patterns-v1.json`
    - This is the authoritative drum pattern library. Load and use directly. Do not parse the raw MIDI file at runtime.
  - Reference MIDI file (do not load at runtime):
    - `/assets/midi/motorik/drums/Drumscribe - Motorik - MIDI.mid`
    - Source material only. It was analysed to produce `drum-patterns-v1.json`. 139 bars at 130 BPM, TPQ=480. The file is highly repetitive (two main groove variants across 64 two-bar blocks) and is not suitable for direct runtime use.
  - Pattern library contents (`drum-patterns-v1.json`):
    - 14 named patterns, each covering exactly 1 bar (16 steps)
    - Each event has: `step` (0-15), `note` (GM MIDI note), `vel` (0-127), `len` (always 1 for drums)
    - Pattern IDs and families:
      - Core (repeating groove): `drum_core_a` (medium intensity), `drum_core_b` (high intensity, extra kick at step 10)
      - Sparse: `drum_sparse` (low intensity, minimal), `drum_intro_kickhat` (kick+hat only, no snare — intro bar 1), `drum_outro_reduce`, `drum_outro_kickonly`
      - Accent variants: `drum_section_start` (crash on beat 1), `drum_ride` (ride cymbal replaces hat), `drum_open_hat_lift`
      - Fills (replace one bar at boundary): `drum_fill_short_tom`, `drum_fill_snare_run`, `drum_fill_snare_roll`, `drum_fill_tom_run`, `drum_fill_crash_climax`
  - How the generator uses these patterns:
    - The generator selects a base groove pattern for each section and loops it for the section's bar count.
    - At section or phrase boundaries, substitute one bar with a fill pattern (subject to fill probability rules below).
    - For the first bar of a new section, substitute `drum_section_start` instead of the regular groove (adds the crash accent).
    - For intro (all intro types that include drums): the normal pattern-family probability table is suspended for the intro section. Use this fixed sequence instead:
      - Bar 1: `drum_intro_kickhat` (kick + closed hat only, no snare)
      - Bar 2: `drum_sparse` (snare enters)
      - Bar 3 onward (if intro is 4 or 8 bars): `drum_sparse` or `drum_core_a` depending on whether intro type is low-energy (sparse) or building (core_a)
      - Final intro bar: 35% chance of a pickup fill substitution (draw fill length from the fill length weights)
      - Resume normal pattern-family probability selection at bar 1 of the A section
    - For outro, step down: core → `drum_sparse` → `drum_outro_reduce` → `drum_outro_kickonly` (40%) or full stop.
  - Pattern selection by song section intensity:
    - Low intensity sections: `drum_sparse`
    - Medium intensity sections: `drum_core_a`
    - High intensity sections: `drum_core_b`, optionally `drum_ride` or `drum_open_hat_lift` for contrast
  - Pattern family probabilities and within-family selection (authoritative):
    - Core motorik pulse (55%): use `drum_core_a` for the first 8-bar phrase of a section; switch to `drum_core_b` for the next 8-bar phrase; alternate every 8 bars thereafter. Reset to `drum_core_a` at each section boundary.
    - Accent variation (30%): select randomly at each 4-bar phrase window — `drum_ride` (40%), `drum_open_hat_lift` (40%), `drum_core_b` with velocity +12 above normal range (20%).
    - Sparse variant (15%): use `drum_sparse` exclusively for the full phrase window.
  - Structural rules:
    - Kick: syncopated motorik pattern (not plain 4-on-floor). Core A: steps 0, 2, 6, 8, 14. Core B: steps 0, 2, 6, 8, 10, 14.
    - Snare: beats 2 and 4 (steps 4 and 12) in all non-sparse patterns
    - Hat/cymbal: 8th-note positions (steps 2, 4, 6, 8, 10, 12, 14) with closed hat; open hat or ride for accent variants
    - Fill limit: maximum 1 fill per 16 bars (any length)
    - Fill placement weights (where within the 16-bar window the fill lands):
      - section-boundary lead-in: 60%
      - 8-bar phrase boundary: 30%
      - other bars: 10%
    - Fill length weights:
      - 1 beat (4 steps): 60%
      - 2 beats (8 steps): 30%
      - 1 bar (16 steps): 10%
    - A 1-bar fill replaces the entire bar with a fill pattern from the library. A 1-beat or 2-beat fill occupies the final steps of a bar (tail-end fill) and the remaining steps use the regular groove pattern.
    - Section intensity model:
      - low: 20%
      - medium: 55%
      - high: 25%
    - Intensity velocity ranges (0-127):
      - low: kick 92-106, snare 84-100, hats 62-86
      - medium: kick 104-118, snare 96-112, hats 72-100
      - high: kick 112-124, snare 104-120, hats 82-108
    - Cymbal/hat lane behavior:
      - closed hat is default drive lane
      - open-hat lift at phrase/section transitions
      - ride for sustained medium/high glide sections
      - crash accents mainly at phrase/section starts
    - Variation policy:
      - keep kick/snare backbone stable
      - vary hats/accents/ghost details first
      - one notable variation event every 8 bars by default
    - Intro behavior:
      - In drums-only intro, use kick+hat first; snare enters by bar 2 or 3.
      - Allow one pickup fill in final intro bar (35% chance).
    - Outro behavior:
      - Reduce cymbal/hat density first, then remove snare ghost accents.
      - Last bar may end with kick-only pulse (40% chance).
- Bass
  - Pattern family probabilities:
    - Root/fifth anchor: 60%
    - Anchor + sparse passing tone: 25%
    - Sparse long-note anchor: 10%
    - Light syncopated anchor variant: 5%
  - Writing rules:
    - Phrase length: 1-2 bars
    - Repetition target: 70-90% repeated cells per 16 bars
    - Passing tones: max 1-2 per bar, weak-beat biased, resolve within <=1 bar
    - Register: low-mid lane, minimal octave jumping
    - Preferred register lane: MIDI 40-64 (default center 45-57); allow brief dips below this only for section accents
    - Strong-beat note targets:
      - root: 60-75%
      - fifth: 15-30%
      - other chord tones: 5-15%
    - Note-pool policy by chord window:
      - Primary: root/fifth/octave
      - Secondary: third and scale-step approaches
      - Avoid: non-resolving chromatic tones on strong beats
    - Variation policy:
      - one micro-variation event per 8 bars by default
      - use rest-shift, note-length change, or single-note approach into next bar root
      - Layered-bass policy:
        - Support two bass pattern layers:
          - layer A (intro/core anchor)
          - layer B (variation layer entering later)
        - Use only one active bass layer at a time in v1 render output, but allow section-level switching between A and B.
        - Layer switch should occur at section boundaries or 4/8-bar boundaries with a short pickup if needed.
    - Drum-bass lock policy:
      - Kick-lock onset targets:
        - strict mode: 75-90% of bass onsets align to kick grid points
        - variation mode: 60-75%
      - Avoid placing new bass onsets directly on core snare backbeats (2/4) except intentional accents.
      - Bass attack density follows drum intensity state (low/medium/high).
      - After drum fills, bass response event weights:
        - downbeat root re-anchor: 60%
        - short approach into root: 30%
        - octave accent: 10%
      - When drum lane shifts to ride/open-hat lift, allow slight temporary bass subdivision lift without changing harmonic anchor role.
      - Align major drum+bass variations to 8/16-bar boundaries; avoid simultaneous high-complexity changes in the same 4-bar window.
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
    - Sparsity/variety policy:
      - Do not run the same continuous subdivision density for more than 4 bars.
      - Require a rhythm-density change every 2-4 bars (for example hit-count reduction, gate change, or accent relocation).
      - Keep at least 20-45% silent steps in active rhythm bars.
      - Prefer rhythm to be sparser than drums in most sections.
      - Allow short local fill gestures at section boundaries (for example half-bar pickup), then return to sparse pulse role.
    - Embellishment constraints:
      - Rhythm is a pulse enhancer, not a harmonic lead.
      - Keep rhythm event density below drum transient density.
      - If rhythm masks Lead 1 range, thin notes or shorten note gates.
    - Intro behavior:
      - Usually absent in first half of intro (75%); enters late to increase momentum.
    - Outro behavior:
      - Drop before bass and drums in most seeds.
- Lead 1
  - Writing rules:
    - Motif-first behavior, 2-6 note motifs
    - Micro-motif length 1-2 bars; macro solo phrase blocks must be 4-8 bars
    - Mostly stepwise/small intervals
    - One changed note/rhythm event every 4-8 bars
    - No high-density run longer than 2 bars
    - Anti-fragment rule:
      - Do not emit isolated 1-2 note fragment phrases as a full lead statement.
      - A phrase block must contain at least one 3+ note statement cell.
      - 1-2 note cells are allowed only as pickups, echoes, or cadential punctuation.
    - Repetition/variation floor:
      - Exact 1-bar repetition max: 2 consecutive bars.
      - In any 8-bar lead window, require >=3 variation events chosen from:
        - rhythmic displacement
        - note-length change
        - interval expansion/compression
        - diatonic sequence copy (model/copy)
        - contour inversion fragment
        - extension or truncation of previous motif
    - Rest-space policy:
      - Target 25-45% silent steps in active lead bars.
      - Force at least one breath event every 4 bars:
        - either a half-bar rest
        - or one full silent bar in each 8-bar phrase block.
      - Avoid dense opening lead blocks; first active lead phrase should prioritize space over note count.
    - Phrase-shape policy (solo musicality):
      - Use statement -> answer -> development -> cadence behavior over each 8-bar phrase.
      - Statement/answer should share contour identity but differ in rhythm or ending tone.
      - Development section should increase rhythmic activity or register by a small amount.
      - Cadence section should simplify and land on stable chord tone.
    - Hook-identity model:
      - Create one primary hook cell per section (target 3-7 notes, usually 4-6).
      - Require hook restatement every 4-8 bars in transformed form, not exact copy.
      - Transform operations (weighted):
        - rhythmic displacement: 30%
        - ending-tone change on same contour: 25%
        - interval expansion/compression: 20%
        - sequence up/down scale degree: 15%
        - contour inversion fragment: 10%
      - Identity floor:
        - keep at least two anchor events unchanged across transformed restatements:
          - either same opening interval
          - or same rhythmic accent position
          - or same cadence target degree
    - Solo-journey arc (section-scale):
      - For 16-bar lead windows, use 4x4-bar arc:
        - bars 1-4: low/medium density statement
        - bars 5-8: answer with mild variation
        - bars 9-12: development (slightly wider range or denser rhythm)
        - bars 13-16: resolution and cadence simplification
      - Peak policy:
        - one clear intensity peak per 16 bars (register or density, not both maxed at once)
        - after peak bar, force de-intensification within next 1-2 bars
      - Motif memory:
        - reuse at least one transformed hook from prior section to preserve song identity.
    - Register/contour policy:
      - Keep most notes within a stable lane; allow one controlled high-point per 8 bars.
      - After a large leap (>=6 semitones), recover by opposite-direction motion within 1-2 notes.
      - Avoid repeated peak-note hammering (>3 hits) without an intervening contour change.
    - Intro behavior:
      - Suppress in intro by default; optional short pickup motif in last intro bar (20%).
    - Outro behavior:
      - End 1-2 bars before final stop unless in full-band subtractive fade type.
    - Embellishment constraints:
      - Lead 1 is melodic foreground but must not mask pad chord identity.
      - If high-density Lead 1 persists >2 bars, reduce density or shorten notes.
- Lead 2
  - Entry timing probabilities:
    - Enter at bar 8: 60%
    - Enter at bar 16: 40%
  - Writing rules:
    - 30-55% of Lead 1 event density
    - Secondary response role, not co-lead
    - Counter-hook policy:
      - Build from Lead 1 hook anchors (rhythmic echo, interval complement, or delayed answer).
      - Do not introduce an independent long-form hook when Lead 1 is active.
      - In 8-bar windows, at least 60% of Lead 2 phrases must begin after Lead 1 phrase onset (call/response feel).
    - Response-mode probabilities:
      - Off-beat echo response: 50%
      - Interval complement (3rd/6th/octave): 35%
      - Sparse unison punctuation: 15%
  - Intro/outro behavior:
    - Never active during intro.
    - Drop before Lead 1 in outro (default).
  - Embellishment constraints:
    - Lead 2 is always subordinate to Lead 1.
    - Keep Lead 2 at 30-55% of Lead 1 event density.
    - If Lead 1 is high-density, force Lead 2 into low-density response mode.
  - Role-handoff and doubling rules:
    - If Lead 1 is absent for a section, Lead 2 may temporarily assume Lead 1 role (foreground melody) for that section.
    - When role-handoff is active, the 55% density cap is suspended. Lead 2 adopts Lead 1's medium-density profile and may use longer phrase spans. The 30-55% subordinate range does not apply during role-handoff.
    - When Lead 1 returns, Lead 2 must transition back to response role within 1-2 bars, after which the 55% cap re-applies.
    - Allow brief doubling windows where Lead 2 and Rhythm (or Lead 1) play the same motif in unison/octave for emphasis.
    - Doubling windows are limited:
      - typical length: 1-4 bars
      - extended jam mode: up to 8 bars
    - After a doubling window, require divergence (call/response or complementary contour) for at least 2 bars.
- Pads
  - Writing rules:
    - Sustained harmonic bed with slower motion than Lead 1/Lead 2/Rhythm
    - Chord-change ceiling: 1-2 functional changes per 16 bars
    - Progression shape: loop-first, linear/modal movement, avoid circle-of-fifths behavior
    - Pads must follow the section chord plan (no independent progression path).
    - Chord complexity policy (Motorik-first):
      - Triads (major/minor): 65%
      - Sus/add colors (sus2/sus4/add9): 20%
      - 7th chords: 10%
      - 9th/11th colors: 5%
      - Diminished/altered colors: <=2%, transition-only
    - Substitution policy:
      - Functional-jazz substitutions are off by default in Motorik mode.
      - Only mild modal substitutions are allowed when tonal center remains stable.
    - Voicing density:
      - Use 2-4 note voicings by default.
      - Re-voice less often than Lead 1 motif mutation cadence (target every 8-16 bars).
    - Rhythm-shape policy:
      - Limit continuous whole-note pad behavior to <=4 bars typical, <=8 bars maximum (rare). (Same as rule P-001.)
      - After any 4-8 bar whole-note stretch, switch to a different pad rhythm template for at least 2-4 bars.
      - Alternate pad rhythmic templates over time (hold, half-bar re-voice, add/sus pulse) to avoid static bed monotony.
      - In busier sections, keep pad rhythm simple but not permanently static.
    - If Lead 1 activity is high, reduce pad re-voicing and keep stable shell voicings.
    - Intro behavior:
      - Optional low-level pad bed only in full-band filtered intro type.
    - Outro behavior:
      - Hold final chord tone through layer drop, then release before texture tail.
- Texture
  - Event probabilities:
    - Event chance per 8 bars: 50%
    - Event chance at boundary: 80%
  - Writing rules:
    - Sparse transitions only (swell/noise/tail)
    - Mostly non-harmonic to avoid tonal clutter
    - Cadence policy:
      - Allow repeated texture accents across sections if separated by a short cooldown (typically >=2 bars).
      - Do not place texture events in every bar; aim for selective punctuation behavior.
    - Embellishment constraints:
      - Texture must remain sparser than Rhythm and Lead 2.
      - If arrangement feels busy, simplify/remove Texture before altering Lead 1.
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
- L.A. Woman-style Mixolydian drive
  - Harmony: major-center vamp with `bVII` color and low chord-churn behavior.
  - Mode basis: Mixolydian-centered note pool (for example A center with D-major note material).
  - Drums/bass feel: steady four-on-floor drive with simple but evolving bass ostinato.
  - Bass behavior: repeated 1-5-b7-family anchors plus occasional scalar connectors; avoid over-melodic wandering.
  - Lead interplay: Lead 1 guitar-like foreground phrases; Lead 2 keyboard response phrases in lower density call/response role.
  - Section-role evolution:
    - Lead 2 may become temporary Lead 1 in sections where guitar lead drops out.
    - Later sections may use keyboard-guitar doubling (same motif) for jam-style lift before returning to differentiated roles.
  - Cohesion guard: if Bass emphasizes major-family center tones, Lead 2 must stay in same section mode pool (no conflicting minor-family overlays).
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
- Drums (v1 only): Electronic Kit 45%, Rock Kit 55%

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
  - Electronic Kit
  - Rock Kit

### Apple DLS General MIDI presets (v1 core sound source)

- V1 uses Apple DLS (General MIDI) as the default sound source for all tracks:
  - Lead 1: GM 82 (`Saw Wave`), GM 87 (`5th Saw Wave`), GM 88 (`Bass & Lead`)
  - Lead 2: GM 63 (`Synth Brass 1`), GM 83 (`Syn. Calliope`), GM 64 (`Synth Brass 2`)
  - Pads: GM 90 (`Warm Pad`), GM 91 (`Polysynth`), GM 96 (`Sweep Pad`)
  - Rhythm: GM 29 (`Electric Muted Guitar`), GM 85 (`Charang`), GM 91 (`Polysynth`) with short gate
  - Texture: GM 94 (`Metallic Pad`), GM 93 (`Bowed Glass`), GM 95 (`Halo Pad`)
  - Bass: GM 39 (`Synth Bass 1`), GM 40 (`Synth Bass 2`), GM 35 (`Electric Bass Pick`)
- Drums kits for v1: Electronic (24) + Power (16)
  - Mapping note: `Rock Kit` = GM/GS `Power` kit (16).
  - Default choice rule:
    - Start with `Rock Kit` (Power 16) for Motorik generation.
    - If style profile is electronic-leaning, start with `Electronic` (24).
- Sample-based instrument libraries are out of scope for v1.
- 0.75+ may evaluate higher-quality GM soundfonts (for example GeneralUser GS) while keeping the same MIDI generation flow.
- Implementation instruction (authoritative):
  - Use only the mappings above for baseline v1 code generation.
  - Treat these as the required instrument families for generated tracks.
  - Only switch within these listed candidates when user cycles instrument choices.
- Audition-only pool (not baseline; use only if quality checks fail):
  - Lead synth alternates: GM 81, 84, 86
  - Bass alternates: GM 33, 34, 36
  - Guitar alternates: GM 25-32
  - Piano/EP alternates: GM 1, 2, 3, 5, 6
  - Organ alternates: GM 17-21
  - Additional drum kits (audition only): Standard (0), Room (8), Jazz (32)
- Audition-only policy:
  - These presets are for manual listening tests and 0.75 sound-quality gate only.
  - They are excluded from default v1 random generation unless explicitly enabled in a debug/test mode.

### Effects probabilities (character presets, post-v1 only)

> **POST-V1 ONLY — do not implement in v1.**

- Scope note:
  - Effects are non-functional placeholders in v1 and these probabilities are excluded from v1 code generation.
  - Keep this section only for post-v1 planning.

- Drums: tight 60%, roomy 25%, gritty 15%
- Bass: focused 65%, warm 25%, saturated 10%
- Rhythm: dry pulse 35%, echo pulse 50%, wide pulse 15%
- Pads/Texture: deep space 55%, wide haze 35%, filtered air 10%
- Leads: echo-forward 50%, dry-forward 30%, saturated echo 20%

### Randomization guardrails

- Seeded determinism
  - Same seed + same controls => same result.
  - PRNG algorithm: implement a `SeededRNG` struct using **SplitMix64** (a well-known 64-bit algorithm, roughly 10 lines of Swift). Do not use Swift's `SystemRandomNumberGenerator` or `arc4random` — these are not seedable and will break determinism.
  - Seed lifecycle:
    - On `Generate New`: generate a new random 64-bit integer seed using any available entropy source (e.g. `UInt64.random(in:)` called once). Store this as the current `globalSeed`.
    - On per-track `Regenerate`: derive a new sub-seed for that track only (see below). Do not change `globalSeed` or the sub-seeds of any other track.
  - Per-track sub-seed derivation:
    - Each track has a fixed numeric index (Lead1=0, Lead2=1, Pads=2, Rhythm=3, Texture=4, Bass=5, Drums=6).
    - Derive each track's RNG seed as: `trackSeed = splitmix64(globalSeed XOR (trackIndex * 0x9e3779b97f4a7c15))`.
    - On per-track regenerate, generate a new 64-bit entropy value for that track only and store it as an override: `trackOverride[trackIndex] = UInt64.random(in:)`. All other tracks continue using their globalSeed-derived sub-seeds unchanged.
    - At render time, each track's RNG is initialised from its override seed if one exists, otherwise from its derived sub-seed.
  - Seed visibility:
    - The seed is not shown in the main UI.
    - In debug/test mode, the status box may print the current `globalSeed` as a plain integer (e.g. `Seed: 14829301847263`) to allow reproducible test runs. This is the only place the seed value appears.
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
  - Key changes are disabled in v1 base generation; keep one key center per section plan.

### Chord voicing specification

#### Aesthetic philosophy

Motorik and krautrock keyboard parts are characteristically sparse, open, and modal. Simple triads in open position — not close-stacked chords — are the default. The goal is resonance and space, not harmonic density. Keep voicings lean so that rhythm and texture carry the energy rather than harmonic complexity. Chord changes happen slowly (every 4–16 bars), which means voice leading quality matters more than chord variety.

#### The fundamental voicing rule: no thirds in the low register

Never place a minor third or major third as the lowest interval of any pad voicing in the low-to-mid register. Thirds below MIDI 60 (middle C) sound acoustically muddy and indistinct. The lowest interval in any pad voicing must be a perfect fourth (5 semitones), perfect fifth (7 semitones), or octave (12 semitones). Thirds belong in the middle and upper voices only.

#### Pad chord root placement

The chord root for pads should sit in the range MIDI 48–60 (C3–C4). This allows the voicing to spread upward into the pad register (MIDI 48–84) while keeping the root grounded. Do not place the pad chord root below MIDI 48 — that is the bass register and creates muddy overlap with the bass track.

#### Default open voicing template (major and minor triads)

The standard voicing for both major and minor triads is a four-note open spread: root, then a fifth above, then an octave above the root, then the third (major or minor) above the octave. Expressed as semitone offsets from the chord root:

- Major triad open: 0, +7, +12, +16 (root — fifth — octave — major third)
- Minor triad open: 0, +7, +12, +15 (root — fifth — octave — minor third)

This places the defining interval (the third, which tells the ear major vs. minor) at the top of the voicing where it sings clearly, while the bass register carries only the stable fifth and octave. This is the single most important voicing template; it should be used for the large majority of pad events.

Example in key E, minor chord (Aeolian i chord), chord root at E3 (MIDI 52):
- 52 + 0 = 52 (E3, root)
- 52 + 7 = 59 (B3, fifth)
- 52 + 12 = 64 (E4, octave)
- 52 + 15 = 67 (G4, minor third one octave up)

All four notes are within the pad register range (48–84). ✓

#### Alternative voicing: root + fifth only (power/drone voicing)

In sections where maximum harmonic openness or modal ambiguity is desired, use only root and fifth (0, +7 or 0, +7, +12 with octave doubling). This is deliberately neither major nor minor — the lead melody or bass line defines the quality. Use this:
- Over a drone or static-tonic section where the mood should feel suspended
- When the melody note would clash with the third of a full triad
- As a variant to break up repeated full-triad voicings over long sections

#### Voice leading between chords

When the chord changes, apply these rules to choose the voicing of the new chord:

- **Common tone rule**: identify any notes that the two chords share (as pitch classes, mod 12). Keep those notes in place — same MIDI pitch, no movement. Do not re-voice a shared note to a different octave just for variety.
- **Minimal motion rule**: voices that must move should move by the smallest available interval. Prefer half-step (1 semitone) and whole-step (2 semitone) movement. A third or fourth leap is acceptable. A fifth or larger leap should only happen in the bass voice or when there is no smaller path.
- **Use inversions**: choose the inversion of the new chord whose MIDI notes are physically closest to the current voicing. Do not default to root position on every chord. A first inversion or second inversion voicing that minimises movement is preferable to root position that requires large leaps.
- **Avoid parallel fifths and octaves**: do not move two voices in the same direction by a perfect fifth or octave simultaneously. This hollows out the texture. One voice holds while the other moves, or they move in contrary motion.

Practical approach: when the next chord change arrives, look at the target chord's available voicings (root position, first inversion, second inversion, open spread) and pick the one whose notes are nearest to the current notes. The voice leading smoothness of the transition is more important than which inversion sounds "correct" in isolation.

#### Sus2 — the primary Motorik color chord

Sus2 replaces the third with the major second (whole step above the root). It is neither major nor minor, has no directional pull, and sits indefinitely without demanding resolution. This makes it the most stylistically appropriate color chord for Motorik-style pads.

Voicing: 0, +7, +12, +14 (root — fifth — octave — major second)

Use sus2 in these contexts:
- As a substitute for a major triad on a stable, long-held chord where you want a wistful, floating quality
- When the melody note is the second/ninth and a full major triad would clash with it
- Over pedal tones and drone sections where harmonic ambiguity is the intent
- Alternating slowly between sus2 and the parent major chord on the same root (e.g. hold E — B — E — F#, then move F# down to E — B — E — E) creates gentle internal motion within a static harmonic field

Sus2 should be the first flourish chord considered in any section. Probability guide: in a 16-bar section, 1–2 chord events may use sus2 where a plain major triad is the underlying harmony.

#### Sus4 — tension with implied resolution

Sus4 replaces the third with the perfect fourth. The fourth sits a half step above the fifth, creating an audible tension that the ear wants to resolve downward to the major third.

Voicing: 0, +7, +12, +17 (root — fifth — octave — perfect fourth)

Use sus4 only where you intend and deliver the resolution:
- Immediately before a return to the major triad on the same root (Esus4 → E major)
- On the chord one step before the phrase landing point, to add gentle forward momentum
- As a bar-level ornament: hold sus4 for the first half of a slow chord, resolve to major triad in the second half

Do not use sus4 on a chord that is going to sit unchanged for 4+ bars — the unresolved tension becomes uncomfortable over time. Do not use sus4 on the tonic chord at the end of a section when a feeling of rest is the intent.

Probability guide: sus4 events are rare — no more than 1 per 8-bar window, and only where a resolution follows.

#### Add9 — shimmer on stable chords

Add9 keeps the full major or minor triad and adds the major second (ninth) as a color note above the third. The chord retains its clear major or minor identity; the ninth adds warmth and shimmer.

Voicing (major add9): 0, +7, +12, +16, +26
- Root — fifth — octave — major third — major ninth (two octaves above root + 2)
- Or more compactly: 0, +7, +16, +26 (omit octave doubling for a lighter texture)

Critical rule: the ninth must sit above the third in the voicing. Never place the ninth adjacent to the root in the low register (e.g. root at 0, ninth at +2, third at +4 — this sounds like a harsh dissonant cluster). Always: root low, third somewhere in the middle, ninth on top.

Use add9 in these contexts:
- On the tonic (i or I) chord of a stable section where the ninth is diatonic to the mode
- On the IV chord for additional warmth
- As a slow variation: move a long-held major triad into add9 by adding the ninth voice above it, creating movement without a chord change

Do not use add9 on the vii chord (diminished quality with a ninth added sounds unruly) or on any chord where the ninth is a chromatic (out-of-mode) note.

Probability guide: add9 can appear 1–2 times per section on stable tonic or IV-type chords.

#### Dominant 7th and minor 7th — sustained color, non-resolving

In Motorik and modal contexts, 7th chords do not resolve. They are sustained color chords, not functional harmony leading toward a tonic.

Dominant 7th voicing (shell — omit the fifth, which adds no information):
- 0, +4, +10 (root — major third — minor seventh) — A-voicing
- Or: 0, +10, +16 (root — minor seventh — major third an octave up) — B-voicing
- The defining sound is the tritone between the third and seventh (+4 and +10, an interval of 6 semitones). This is the color. Keep both in the voicing.

Minor 7th voicing (shell):
- 0, +3, +10 (root — minor third — minor seventh) — A-voicing
- Or: 0, +10, +15 (root — minor seventh — minor third an octave up) — B-voicing

Use 7th chords in these contexts:
- Dominant 7th: as a color variant of a major chord in Mixolydian sections (the b7 is diatonic to Mixolydian; a G chord in G Mixolydian is naturally a G7). Very characteristic of the Motorik sound in major-mode sections.
- Minor 7th: as the tonic chord in Dorian sections (Dm7 is the natural tonic of D Dorian, not just a flourish). Also appropriate on the ii chord of any major-mode section.
- Keep 7th chords sustained and static. Let the tone ring rather than re-voicing frequently.

Do not use the major 7th chord type in v1 Motorik generation. The major 7th interval (half step below the octave) clashing with the root creates a romantic, jazz-adjacent sound that is not characteristic of the Motorik aesthetic.

Probability guide: 7th chords are appropriate 1–2 times per section in the right mode context (Dorian tonic Dm7 freely; dominant 7th in Mixolydian sections freely; elsewhere sparingly).

#### Quartal voicings — maximum modal ambiguity

Stacking perfect fourths instead of thirds (e.g. D-G-C or A-D-G) produces a floating, unresolved sound with no clear major or minor quality. Useful for the most abstract or drone-like sections.

Quartal voicing example (three-note): 0, +5, +10 (root — fourth — minor seventh)

Use sparingly — one chord event per section at most. Apply where maximum harmonic ambiguity is the goal, or as a transitional voicing between two diatonic chords.

#### Voicing probability summary (Pads, v1 Motorik)

Per 16-bar section:
- Plain major or minor triad in open spread voicing: 70% of chord events
- Sus2 substitution: 15%
- Add9 (on stable tonic/IV chords only): 8%
- Dominant or minor 7th (mode-appropriate): 5%
- Sus4 (with resolution): 2%
- Quartal voicing: occasional, up to 1 event per section

#### Chord voicing validation before render

Before emitting a pad chord voicing as MIDI events:
- Confirm no note falls below MIDI 48 (pad register minimum)
- Confirm no two adjacent notes in the voicing are less than 3 semitones apart in the low register (below MIDI 60) — if they are, remove or move the lower of the two
- Confirm the voicing notes are within the active chord-window note pool (chordTones + scaleTensions only; no avoidTones)
- If a voicing note is an avoidTone on a strong beat, remap it to the nearest chordTone

### V1 execution parameters (now defined)

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
  - Bass: MIDI 40-64
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
- Starter content assets (v1, codegen input)
  - Manifest:
    - `/assets/midi/motorik/starters/starter-pack-manifest-v1.json`
  - Drums:
    - `/assets/midi/motorik/drums/drum-patterns-v1.json` (primary — use this)
    - `/assets/midi/motorik/drums/Drumscribe - Motorik - MIDI.mid` (reference only, do not load at runtime)
  - Bass:
    - `/assets/midi/motorik/starters/bass-starters-v1.json`
  - Pads:
    - `/assets/midi/motorik/starters/pads-starters-v1.json`
  - Lead 1:
    - `/assets/midi/motorik/starters/lead1-starters-v1.json`
    - `/assets/midi/motorik/starters/lead1-solo-starters-v2.json` (preferred for longer/more developed solos)
  - Lead 2:
    - `/assets/midi/motorik/starters/lead2-starters-v1.json`
  - Rhythm:
    - `/assets/midi/motorik/starters/rhythm-starters-v1.json`
  - Texture:
    - `/assets/midi/motorik/starters/texture-starters-v1.json`
  - Cross-style reference section library:
    - `/assets/midi/motorik/starters/silly-love-songs-derived-v1.json`
    - Source MIDI:
      - `/assets/midi/references/wings-silly-love-songs/Wings - Silly Love Songs.mid`
  - Interpretation:
    - These assets are starter seeds only; generator must still apply section, density, intro/outro, and conflict rules before rendering final MIDI.
    - For Lead 1, prefer v2 phrase starters when generating section-length solos; use v1 motifs as micro-cells for mutation.
    - The Silly Love Songs-derived set is arrangement/rhythm vocabulary only (especially drums+bass lock, section signaling, and electric-piano rhythm comp behavior); do not clone its harmonic identity directly.
- Mood-to-scale mapping (implementation defaults)
  - Bright: Ionian (major) primary, Mixolydian secondary.
  - Deep: Aeolian (natural minor).
  - Dream: Dorian.
  - Free: hybrid note-pool with weak tonal gravity (avoid strong V-I cadence behavior).

## Rule ID Catalog (MIDI-derived v1)

This catalog enumerates the current MIDI-derived generation rules with stable IDs for implementation and testing.

### Global rules that describe the overall song generation
G-001 - Generate in section blocks (intro, A, B, bridge, outro) on 4/8/16-bar boundaries.
G-002 - Use section-aware arrangement changes rather than static loop-only generation.
G-003 - Permit jam-style continuity with controlled role evolution across long sections.
G-004 - Use structure templates from reference MIDI as arrangement vocabulary, not as literal copies.

### Tonal rules that define key/mode, note pools, and harmonic coherence
T-001 - One parent key/mode per section; all pitched tracks must obey it.
T-002 - Build chord-window note pools: chord tones, scale tensions, avoid tones.
T-003 - Enforce strong-beat chord-tone targets for support tracks.
T-004 - Enforce mood-consistency guard for major/minor coloration across tracks.
T-005 - Treat Mixolydian b7 as stable while keeping major-family third polarity.
T-006 - Starter MIDI must be remapped into current key/mode/chord pools before render.
T-007 - If transposition alone leaves out-of-pool notes, apply nearest-allowed-note remap with contour bias.

### Drum rules
D-001 - Keep motorik-compatible pulse continuity; vary accents/hats/fills before changing core groove identity.
D-002 - Use section-intensity drum variants (intro sparse, drive, lift, bridge sparse) for form signaling.

### Bass rules
B-001 - Keep drum+bass lock as primary rhythmic anchor.
B-002 - Bass strong-beat note targets: root 60-75%, fifth 15-30%, other chord tones 5-15%.
B-003 - Bass non-scale tones disallowed except explicit short pickup with rapid resolution.
B-004 - Use layered bass model: layer A (intro/core), layer B (later variation), one active layer at a time.
B-005 - Bass layer switches only at section or 4/8-bar boundaries (optionally with pickup).

### Pad rules
P-001 - Limit continuous whole-note pad behavior to typical <=4 bars, rare max 8 bars.
P-002 - After long hold blocks, rotate to a different pad rhythm template for 2-4 bars.
P-003 - Keep pads harmonically authoritative but rhythmically adaptive in busier sections.

### Rhythm rules
R-001 - Rhythm must stay sparser than drums in most sections.
R-002 - Do not keep identical subdivision density for more than 4 bars.
R-003 - Maintain 20-45% silence in active rhythm bars.
R-004 - Allow short local fill gestures near boundaries, then return to sparse pulse role.
R-005 - Use fast guitar-chug variants (plain, fill, break) as selectable rhythmic vocabulary.

### Lead 1 rules
L1-001 - Use phrase arc: statement -> answer -> development -> cadence over section windows.
L1-002 - Avoid dense opening lead blocks; first active lead phrase prioritizes space.
L1-003 - Keep transformed hook identity across sections (rhythm/interval/cadence anchors).

### Lead 2 rules
L2-001 - Default role is response/counterline at 30-55% of Lead 1 density.
L2-002 - Lead 2 may temporarily assume Lead 1 role when Lead 1 is absent in a section.
L2-003 - When Lead 1 returns, Lead 2 transitions back to response role within 1-2 bars.
L2-004 - Lead 2 may use Hallogallo-derived motif variants as counterline vocabulary.

### Texture rules
X-001 - Reuse texture accents across sections with cooldown (typically >=2 bars).
X-002 - Do not place texture events in every bar; use selective punctuation behavior.
X-003 - Keep texture sparse and boundary-weighted (intro swells, transition accents, tail).

### Interplay rules for cross-track behavior
I-001 - Bass-vs-Lead2 conflict priority: keep bass, remap Lead 2 to consonant target, else suppress.
I-002 - Allow controlled doubling windows (Lead2+Rhythm or keyboard+guitar) in unison/octave.
I-003 - Doubling window length: typical 1-4 bars, extended jam up to 8 bars.
I-004 - After doubling, require at least 2 bars of divergence (call/response or complementary contour).

### Asset rules for starter material usage
A-001 - silly-love-songs-derived-v1.json is rhythmic/arrangement vocabulary only; do not clone harmonic identity.
A-002 - Use Hallogallo tab-derived bass/rhythm/lead2 variants as motif and pulse vocabulary.
A-003 - Use Super16-derived rhythm and structure templates for fast guitar-driven sections and controlled drop bars.

### Quality rules for validation and regeneration
Q-001 - Reject/regenerate 4-bar windows that violate note-pool quotas for Bass/Pads/Rhythm.
Q-002 - Reject/regenerate windows with >2 unresolved strong-beat Bass/Lead2 clashes.
Q-003 - Reject/regenerate windows exceeding mood-consistency major/minor coloration threshold.
Q-004 - Run final harmonic auto-repair pass before MIDI render commit.

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
  - Zen, Zoetrope, Zeitgeist, Zietgiest, Zeno, Zug, Zoo, Neon Highway
  - 1977, '85, No. 7, Part 1, Part 2
- Place/scene words
  - Koln, Dusseldorf, Berlin, Ruhr, Autobahn, Tunnel, Nordhausen, Detroit, Forest, Flughafen, Ausgang, Ausfahrt, Strasse, See, Fluss
- Motion/energy words
  - Drive, Pulse, Drift, Flow, Run, Loop, Roll, Counter, Motor, Velocity, Nonstop, Speed, Fast, Schnell, Tempo, Geschwindigkeit, Exit
- Texture/tone words
  - Chrome, Static, Neon, Halo, Tape, Glass, Glas, Metal, Buzz, Klang, Kosmiche, Elektronischer, Light, Dark, Licht, Dunkel, Night, Nacht, Moon, Mond, Sun, Sonne, Stars, Sterne, Zen, Zeitgeist
- Music-structure words
  - Chord, Pattern, Sequence, Ostinato, Motif, Echo, Signal, Flux, Phase
- Verified musician-name words (from Neu!/Harmonia/Kraftwerk + related motorik acts)
  - Klaus, Dinger, Michael, Rother, Thomas, Hans, Lampe
  - Roedelius, Dieter, Moebius
  - Ralf, Hutter, Florian, Schneider, Karl, Bartos, Wolfgang, Flur
- Rearranged title words (from referenced tracks/albums; not exact copies)
  - Hallo, Immer, Neu, Deluxe, Monza, Hollywood, Express, Europe, Endlos, Dynamik, Weiter

### Additional Z-lexicon suggestions (real + faux Germanic)

- Approved additions:
  - Zentrale
  - Zignal

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
- Cap punctuation and symbols (letters/spaces preferred in v1; allow only approved numeric tokens: `1977`, `'85`, `No. 7`, `Part 1`, `Part 2`).
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

## AVAudioEngine playback architecture (v1)

### Chosen approach: AVAudioEngine + AVAudioUnitSampler with manual event scheduling

Do not use `AVAudioSequencer` in v1. It does not support the per-track runtime event-swap that per-track `Regenerate` during live playback requires. Use a manual scheduling loop against the audio engine's `AVAudioTime` timeline instead.

### Engine setup

- Create one `AVAudioUnitSampler` node per track (7 total: Lead1, Lead2, Pads, Rhythm, Texture, Bass, Drums).
- Load the Apple DLS General MIDI soundfont into each sampler at startup via `loadSoundBankInstrument(at:program:bankMSB:bankLSB:)`.
- Connect all sampler output nodes to `AVAudioEngine.mainMixerNode`.
- Start the engine once at app launch. Do not stop or restart it between songs; stopping and restarting introduces audible glitches and setup latency.

### MIDI channel assignment (v1)

- Lead 1: channel 0
- Lead 2: channel 1
- Pads: channel 2
- Rhythm: channel 3
- Texture: channel 4
- Bass: channel 5
- Drums: channel 9 (GM drums channel, required by Apple DLS)

### Playback timeline and step timer

On `Play`, record the absolute start host time: `playbackStartHostTime = mach_absolute_time()`.

Derived values (recomputed from `tempo` on each step tick):
```
secondsPerBeat = 60.0 / tempo
secondsPerStep = secondsPerBeat / 4.0    // one 16th note
secondsPerBar  = secondsPerBeat * 4.0
```

Elapsed playback time at any moment: `elapsedSeconds = hostTimeToSeconds(mach_absolute_time() - playbackStartHostTime)`.

Current bar: `currentBar = Int(elapsedSeconds / secondsPerBar)`.

Run a high-priority `DispatchQueue` step timer at 16th-note resolution:
- Fire every `secondsPerStep` seconds (use a `DispatchSourceTimer` on a `DispatchQueue` with `.userInteractive` QoS).
- On each tick, compute the target step index and scan `trackEvents[trackIndex]` for all events whose `stepIndex` matches that step.
- For each matching event, schedule `noteOn` via the sampler at the computed `AVAudioTime`, then schedule a corresponding `noteOff` at `eventTime + durationSteps × secondsPerStep`.

### Per-track event swap during playback (bar-boundary rule)

When per-track `Regenerate` fires while playback is running:
1. Compute `nextBarStartStep = (currentBar + 1) × 16`.
2. Run track generation off the main thread. At 138 BPM one bar is 1.74 seconds; generation completes well within this window.
3. At the step tick that lands on `nextBarStartStep`, atomically replace `trackEvents[trackIndex]` with the new array.
4. Cancel any future scheduled events for that track that were pre-queued beyond `nextBarStartStep`. Do not cancel note-off events for notes already sounding (let them decay naturally).
5. The step timer then reads from the new array starting at `nextBarStartStep`. All other tracks are unaffected.

### Instrument cycling during playback

When the user cycles the instrument on a track while the transport is running, the new GM program is loaded at the next bar boundary using the same bar-boundary mechanism as above. In-flight notes on the old program finish their scheduled note-off.

### Mute and solo

- **Mute**: set `AVAudioUnitSampler` output volume to 0. Continue dispatching MIDI events to keep the track in sync; the audio is simply silent. Unmuting restores volume immediately and the track resumes in phase.
- **Solo**: mute all non-soloed tracks using the same volume-zero approach.

### Stop and end of song

- On `Stop` (user button): cancel the step timer, send a note-off for every sounding note on every channel, set the UI playhead to bar 0, reset `playbackStartHostTime`.
- On song end (step timer detects `currentBar >= totalBars`): execute the same procedure as `Stop`. Display the playhead at bar 1 (1-indexed in the UI, bar 0 internally).

## Swift data model sketch (v1)

These are the authoritative Swift type names. Generated code must use them verbatim for consistency across the codebase.

```swift
// Track index constants — use these named values, never raw integers
let kTrackLead1   = 0
let kTrackLead2   = 1
let kTrackPads    = 2
let kTrackRhythm  = 3
let kTrackTexture = 4
let kTrackBass    = 5
let kTrackDrums   = 6

// Enumerations
enum Mode: String, CaseIterable {
    case Ionian, Dorian, Mixolydian, Aeolian, MinorPentatonic, MajorPentatonic
}
enum Mood: String, CaseIterable { case Bright, Deep, Dream, Free }
enum SectionLabel: String { case intro, A, B, outro }
enum SectionIntensity: String { case low, medium, high }
enum ChordType: String {
    case major, minor, sus2, sus4, add9, dom7, min7, quartal, power
}
enum ProgressionFamily: String {
    case static_tonic
    case two_chord_I_bVII
    case minor_loop_i_VII
    case minor_loop_i_VI
    case modal_cadence_bVI_bVII_I
}

// One MIDI note event, step-addressed
struct MIDIEvent {
    let stepIndex: Int       // absolute step in the full song (bar × 16 + step-within-bar)
    let note: UInt8          // MIDI note number 0–127
    let velocity: UInt8      // MIDI velocity 0–127
    let durationSteps: Int   // gate length in steps (1 step = one 16th note)
}

// Generation step 1 output
struct GlobalMusicalFrame {
    let key: String          // "C" | "C#" | "D" | "Eb" | "E" | "F" | "F#" | "G" | "Ab" | "A" | "Bb" | "B"
    let mode: Mode
    let tempo: Int           // BPM
    let mood: Mood
    let progressionFamily: ProgressionFamily
    let totalBars: Int       // shared by all tracks; authoritative
}

// One entry in the chord plan
struct ChordWindow {
    let startBar: Int
    let lengthBars: Int
    let chordRoot: String        // degree string in key ("1", "b7", "b6", etc.)
    let chordType: ChordType
    let chordTones: Set<Int>     // pitch classes mod 12
    let scaleTensions: Set<Int>  // pitch classes mod 12
    let avoidTones: Set<Int>     // pitch classes mod 12
}

// One section in the arranged song
struct SongSection {
    let startBar: Int
    let lengthBars: Int
    let label: SectionLabel
    let intensity: SectionIntensity
    let mode: Mode           // usually matches GlobalMusicalFrame.mode;
                             // may differ for Moderate A/B B-section
}

// Generation step 2 output
struct SongStructure {
    let sections: [SongSection]
    let chordPlan: [ChordWindow]
}

// Tonal governance map (generation step 3 output)
// One entry per chord window; covers the full song timeline
struct TonalGovernanceEntry {
    let chordWindow: ChordWindow     // the window this entry governs
    let sectionLabel: SectionLabel   // which section this window belongs to
    let sectionMode: Mode            // active mode for this window (from SongSection.mode)
}

typealias TonalGovernanceMap = [TonalGovernanceEntry]
// Lookup helper: given a bar index, find the entry whose chordWindow contains that bar.
// All tracks call this at render time to get the active chordTones/scaleTensions/avoidTones.

// Complete song state (held in memory while the song is loaded)
struct SongState {
    let frame: GlobalMusicalFrame
    let structure: SongStructure
    let tonalMap: TonalGovernanceMap  // step 3 output; all tracks query this at render time
    let trackEvents: [[MIDIEvent]]    // indexed by kTrackLead1…kTrackDrums
    let globalSeed: UInt64
    var trackOverrides: [Int: UInt64] // trackIndex → override seed set by per-track Regenerate
    let title: String
}

// SplitMix64 PRNG — implement exactly this algorithm
struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
```

## Constraints for v1

- Prioritize musical coherence over infinite flexibility.
- Keep controls shallow and meaningful; avoid DAW-level complexity in first prototype.
- Effect controls should read as musical character, not studio engineering parameters.
- No seed/session recall UI in v1 (debug/test mode may add this later).

## V1 Feature Lock

- Included:
  - `Generate New` button
  - Global transport: `Previous` (disabled placeholder in v1), `Play` (green arrow), `Stop` (red square), `Next` (disabled placeholder in v1)
  - Global selectors: `Style` (locked to `Motorik` in v1), `Tempo`, `Mood`, `Key`
  - Header logo image: `/assets/images/logo/zudio-logo.png` (upper-left)
  - `Help` and `About` dialogs
  - Per-track `Mute` and `Solo` buttons
  - Per-track `Regenerate` button
  - MIDI lane visualization and playback scrolling
  - Right-side effects controls shown as disabled placeholders
  - Motorik core and Motorik-adjacent generation profiles under the single v1 `Motorik` style
  - Track set/order: Lead 1, Lead 2, Pads, Rhythm, Texture, Bass, Drums
- Excluded from v1:
  - Direct note editing in the piano-roll/grid view
  - Effect editing controls
  - Evolution mode (continuous morphing playback)

## Post-v1 Note

- Implementation rule: ignore all post-v1 sections when generating v1 code.
- Post-v1 content is reference material only and must not expand v1 scope.
- This does not exclude the Motorik-adjacent calibration profiles defined above; those profiles are part of v1 generation behavior.

## Post-1.0 Evolution Mode (continuous play)

> **POST-V1 ONLY — do not implement in v1.**

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

- ~~Should style be a single selector (Motorik, Cosmic, Ambient) or a blend slider?~~ Resolved: single selector for v1, locked to Motorik. Blend sliders are post-v1.
- ~~Should lead generation be optional by default for more sparse ambient output?~~ Resolved: Lead 1 and Lead 2 are always generated in v1. The user can mute individual tracks after generation if a sparser result is wanted. Making lead generation optional by default adds UI state complexity that is out of scope for v1.
- ~~Should each track permit independent length/polymeter, or all parts share one loop length in v1?~~ Resolved: all tracks share one loop length in v1. No polymeter.
